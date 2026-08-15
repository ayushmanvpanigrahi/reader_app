from __future__ import annotations

import asyncio
import hashlib
import math
import re
import uuid
from typing import Any, Sequence

from qdrant_client import AsyncQdrantClient
from qdrant_client.models import (
    Distance,
    FieldCondition,
    Filter,
    Fusion,
    FusionQuery,
    MatchValue,
    PayloadSchemaType,
    PointStruct,
    PointVectors,
    Prefetch,
    SparseIndexParams,
    SparseVector,
    SparseVectorParams,
    VectorParams,
)

from app.core.config import settings
from app.core.logging import get_logger
from app.rag.embeddings import NoEmbeddingProviderError, get_embeddings
from app.services import provider_context

logger = get_logger(__name__)

DENSE_VECTOR_NAME = "dense"
SPARSE_VECTOR_NAME = "bm25"

# Every filter in this store uses exact-match keyword conditions on these keys.
# Qdrant raises "Index required but not found" on filtered queries when no
# payload index exists, so each key needs a KEYWORD index.
PAYLOAD_INDEX_KEYS = ("user_id", "book_id", "chapter")

_TOKEN_RE = re.compile(r"[a-z0-9_]+")


class BM25SparseEncoder:
    def __init__(self, max_index: int = 2**28) -> None:
        self._max_index = max_index
        self._doc_freq: dict[int, int] = {}
        self._total_docs = 0
        self._lock = asyncio.Lock()

    @staticmethod
    def _tokenize(text: str) -> list[str]:
        return _TOKEN_RE.findall(text.lower())

    def _hash(self, token: str) -> int:
        return int(hashlib.blake2b(token.encode(), digest_size=4).hexdigest(), 16) % self._max_index

    async def add_documents(self, texts: Sequence[str]) -> None:
        async with self._lock:
            for text in texts:
                unique = {self._hash(t) for t in self._tokenize(text)}
                for idx in unique:
                    self._doc_freq[idx] = self._doc_freq.get(idx, 0) + 1
                self._total_docs += 1

    def _idf(self, idx: int) -> float:
        df = self._doc_freq.get(idx, 1)
        return math.log((self._total_docs + 1) / (df + 0.5)) + 1.0

    async def encode(self, text: str, *, as_query: bool) -> SparseVector:
        tokens = self._tokenize(text)
        term_counts: dict[int, int] = {}
        for t in tokens:
            idx = self._hash(t)
            term_counts[idx] = term_counts.get(idx, 0) + 1

        if not term_counts:
            return SparseVector(indices=[], values=[])

        max_tf = max(term_counts.values())
        indices: list[int] = []
        values: list[float] = []
        for idx, tf in term_counts.items():
            idf = self._idf(idx) if as_query else 1.0
            indices.append(idx)
            values.append((0.5 + 0.5 * tf / max_tf) * idf)
        return SparseVector(indices=indices, values=values)


_bm25: BM25SparseEncoder | None = None


def get_bm25_encoder() -> BM25SparseEncoder:
    global _bm25
    if _bm25 is None:
        _bm25 = BM25SparseEncoder()
    return _bm25


class QdrantHybridStore:
    def __init__(self) -> None:
        self._client = AsyncQdrantClient(
            url=settings.QDRANT_URL,
            api_key=settings.QDRANT_API_KEY or None,
            timeout=30.0,
        )
        self._embeddings = get_embeddings()
        self._bm25 = get_bm25_encoder()
        self._dense_size: dict[str, int] = {}
        self._payload_indexed: set[str] = set()

    def _collection_name(self, user_id: str) -> str:
        safe_user = hashlib.sha1(user_id.encode()).hexdigest()[:12]
        return f"{settings.COLLECTION_PREFIX}_{safe_user}"

    async def _ensure_payload_indexes(self, user_id: str) -> None:
        """Create KEYWORD payload indexes for every filtered key.

        Idempotent — once created for a collection, later calls are no-ops.
        Tolerates "index already exists" so it can run against collections
        created before this fix.
        """
        name = self._collection_name(user_id)
        for key in PAYLOAD_INDEX_KEYS:
            try:
                await self._client.create_payload_index(
                    collection_name=name,
                    field_name=key,
                    field_schema=PayloadSchemaType.KEYWORD,
                    wait=False,
                )
            except Exception as exc:  # noqa: BLE001 - index already present is fine
                logger.debug("Payload index for %s.%s already present: %s", name, key, exc)
        self._payload_indexed.add(name)

    async def _ensure_collection(self, user_id: str, vector_size: int) -> None:
        name = self._collection_name(user_id)
        if not await self._client.collection_exists(name):
            await self._client.create_collection(
                collection_name=name,
                vectors_config={
                    DENSE_VECTOR_NAME: VectorParams(size=vector_size, distance=Distance.COSINE),
                },
                sparse_vectors_config={
                    SPARSE_VECTOR_NAME: SparseVectorParams(index=SparseIndexParams(on_disk=True)),
                },
            )
            self._dense_size[user_id] = vector_size
        await self._ensure_payload_indexes(user_id)

    async def _prepare(self, user_id: str) -> bool:
        """True if the user's collection exists (payload indexes ensured).

        Covers collections created before this fix that still lack the
        keyword indexes required for filtered queries/scrolls.
        """
        name = self._collection_name(user_id)
        if not await self._client.collection_exists(name):
            return False
        if name not in self._payload_indexed:
            await self._ensure_payload_indexes(user_id)
        return True

    async def _collection_dense_size(self, user_id: str) -> int | None:
        cached = self._dense_size.get(user_id)
        if cached is not None:
            return cached
        name = self._collection_name(user_id)
        if not await self._client.collection_exists(name):
            return None
        try:
            col = await self._client.get_collection(name)
            vecs = col.config.params.vectors
            if isinstance(vecs, dict):
                dv = vecs.get(DENSE_VECTOR_NAME)
                if dv is not None:
                    size = dv.size
                    self._dense_size[user_id] = size
                    return size
        except Exception as exc:  # noqa: BLE001 - unknown server errors should not crash search
            logger.warning("Could not inspect collection %s: %s", name, exc)
        return None

    async def index_chunks(self, chunks: list[dict[str, Any]]) -> int:
        if not chunks:
            return 0
        user_id = chunks[0]["user_id"]
        texts = [c["text"] for c in chunks]

        sparse_vectors = [await self._bm25.encode(t, as_query=False) for t in texts]
        await self._bm25.add_documents(texts)

        dense_vectors: list[list[float]] | None = None
        dense_model = ""
        try:
            dense_vectors = await self._embeddings.embed(texts, kind="passage")
            dense_model = provider_context.embed_model_hint()
            dim = len(dense_vectors[0])
            collection_dim = await self._collection_dense_size(user_id)
            if collection_dim is not None and collection_dim != dim:
                logger.warning(
                    "Dense dim %d does not match collection dim %d for user %s — indexing sparse-only.",
                    dim,
                    collection_dim,
                    user_id,
                )
                dense_vectors = None
        except NoEmbeddingProviderError:
            logger.warning("No embedding provider available — indexing sparse-only for user %s", user_id)
        except Exception as exc:  # noqa: BLE001 - never let embedding failure block indexing
            logger.warning("Embedding failed for user %s — indexing sparse-only: %s", user_id, exc)
            dense_vectors = None

        dense_dim = len(dense_vectors[0]) if dense_vectors else settings.EMBEDDING_DIM
        await self._ensure_collection(user_id, dense_dim)

        points = []
        for i, chunk in enumerate(chunks):
            vector: dict[str, Any] = {SPARSE_VECTOR_NAME: sparse_vectors[i]}
            if dense_vectors is not None:
                vector[DENSE_VECTOR_NAME] = dense_vectors[i]
            payload = dict(chunk)
            payload["embedded"] = dense_vectors is not None
            payload["embedded_models"] = [dense_model] if dense_vectors is not None else []
            points.append(
                PointStruct(
                    id=_stable_chunk_id(user_id, chunks[i]),
                    vector=vector,
                    payload=payload,
                )
            )

        await self._client.upsert(collection_name=self._collection_name(user_id), points=points)
        logger.info(
            "Indexed %d chunks for user %s (dense=%s)",
            len(points),
            user_id,
            dense_vectors is not None,
        )
        return len(points)

    async def hybrid_search(
        self,
        *,
        user_id: str,
        query: str,
        book_ids: list[str] | None = None,
        chapter: str | None = None,
        dense_top_k: int = settings.DENSE_TOP_K,
        sparse_top_k: int = settings.SPARSE_TOP_K,
        final_top_k: int = settings.FUSION_TOP_K,
    ) -> list[dict[str, Any]]:
        sparse_vec = await self._bm25.encode(query, as_query=True)

        collection_name = self._collection_name(user_id)
        if not await self._prepare(user_id):
            logger.debug("No collection for user %s — returning empty search", user_id)
            return []

        conditions = [FieldCondition(key="user_id", match=MatchValue(value=user_id))]
        if book_ids:
            conditions.append(FieldCondition(key="book_id", match=MatchValue(value=book_ids[0])))
        if chapter:
            conditions.append(FieldCondition(key="chapter", match=MatchValue(value=chapter)))
        search_filter = Filter(must=conditions) if conditions else None

        dense_vec: list[float] | None = None
        try:
            collection_dim = await self._collection_dense_size(user_id)
            if collection_dim is not None:
                candidate = (await self._embeddings.embed([query], kind="query"))[0]
                if len(candidate) == collection_dim:
                    dense_vec = candidate
        except (NoEmbeddingProviderError, Exception):  # noqa: BLE001 - fall back to sparse search
            dense_vec = None

        if dense_vec is not None:
            response = await self._client.query_points(
                collection_name=collection_name,
                prefetch=[
                    Prefetch(
                        query=dense_vec,
                        using=DENSE_VECTOR_NAME,
                        filter=search_filter,
                        limit=dense_top_k,
                    ),
                    Prefetch(
                        query=sparse_vec,
                        using=SPARSE_VECTOR_NAME,
                        filter=search_filter,
                        limit=sparse_top_k,
                    ),
                ],
                query=FusionQuery(fusion=Fusion.RRF),
                limit=final_top_k,
                with_payload=True,
            )
        else:
            response = await self._client.query_points(
                collection_name=collection_name,
                query=sparse_vec,
                using=SPARSE_VECTOR_NAME,
                query_filter=search_filter,
                limit=final_top_k,
                with_payload=True,
            )

        docs: list[dict[str, Any]] = []
        for hit in response.points:
            payload = dict(hit.payload or {})
            payload["_score"] = hit.score
            docs.append(payload)
        return docs

    async def backfill_missing_dense(self, user_id: str, book_id: str | None = None) -> int:
        """Re-embed chunks that lack the current embedding model's dense vector.

        Points indexed while no embedding provider was available are stored
        sparse-only (`embedded: false`); once a provider with an embedding model
        is synced, call this to attach dense vectors without re-uploading the
        file.
        """
        name = self._collection_name(user_id)
        if not await self._prepare(user_id):
            return 0

        endpoints = provider_context.embed_endpoints()
        if not endpoints:
            raise NoEmbeddingProviderError("No embedding-capable provider configured.")
        model = endpoints[0].model

        probe = await self._embeddings.embed(["backfill probe"], kind="passage")
        dim = len(probe[0])
        collection_dim = await self._collection_dense_size(user_id)
        if collection_dim is not None and collection_dim != dim:
            raise NoEmbeddingProviderError(
                f"Embedding dim {dim} does not match collection dim {collection_dim}; "
                "switch to a matching embedding model to enable semantic search."
            )

        must = [FieldCondition(key="user_id", match=MatchValue(value=user_id))]
        if book_id:
            must.append(FieldCondition(key="book_id", match=MatchValue(value=book_id)))
        search_filter = Filter(must=must)

        pending: list[dict[str, Any]] = []
        next_offset: Any = None
        while True:
            page = await self._client.scroll(
                collection_name=name,
                scroll_filter=search_filter,
                limit=1000,
                offset=next_offset,
                with_payload=True,
                with_vectors=False,
            )
            points, next_offset = page
            for point in points:
                payload = point.payload or {}
                if model not in (payload.get("embedded_models") or []):
                    pending.append({"id": point.id, "text": payload.get("text", "")})
            if next_offset is None or not points:
                break

        if not pending:
            return 0

        backfilled = 0
        for start in range(0, len(pending), 64):
            batch = pending[start : start + 64]
            texts = [p["text"] for p in batch]
            vectors = await self._embeddings.embed(texts, kind="passage")
            await self._client.update_vectors(
                collection_name=name,
                points=[
                    PointVectors(
                        id=p["id"],
                        vector={DENSE_VECTOR_NAME: vec},
                    )
                    for p, vec in zip(batch, vectors, strict=True)
                ],
            )
            await self._client.set_payload(
                collection_name=name,
                payload={"embedded": True, "embedded_models": [model]},
                points=[p["id"] for p in batch],
            )
            backfilled += len(batch)

        logger.info("Backfilled dense vectors for %d chunks (user=%s book=%s)", backfilled, user_id, book_id)
        return backfilled

    async def list_books(self, user_id: str) -> list[dict[str, Any]]:
        """Aggregate per-book stats from the user's collection (server-side truth)."""
        name = self._collection_name(user_id)
        if not await self._prepare(user_id):
            return []

        books: dict[str, dict[str, Any]] = {}
        next_offset: Any = None
        while True:
            page = await self._client.scroll(
                collection_name=name,
                scroll_filter=Filter(
                    must=[FieldCondition(key="user_id", match=MatchValue(value=user_id))]
                ),
                limit=1000,
                offset=next_offset,
                with_payload=True,
                with_vectors=False,
            )
            points, next_offset = page
            for point in points:
                payload = point.payload or {}
                book_id = payload.get("book_id") or ""
                if not book_id:
                    continue
                entry = books.setdefault(
                    book_id,
                    {
                        "book_id": book_id,
                        "title": payload.get("title") or "",
                        "chunks": 0,
                        "embedded": False,
                    },
                )
                entry["chunks"] += 1
                if payload.get("embedded"):
                    entry["embedded"] = True
            if next_offset is None or not points:
                break

        return list(books.values())

    async def delete_book(self, user_id: str, book_id: str) -> None:
        name = self._collection_name(user_id)
        if not await self._prepare(user_id):
            return
        await self._client.delete(
            collection_name=name,
            points_selector=Filter(must=[FieldCondition(key="book_id", match=MatchValue(value=book_id))]),
        )


def _stable_chunk_id(user_id: str, chunk: dict[str, Any]) -> str:
    raw = f"{user_id}|{chunk['book_id']}|{chunk['chunk_index']}|{chunk['chapter']}"
    return str(uuid.UUID(bytes=hashlib.sha256(raw.encode()).digest()[:16]))


_store: QdrantHybridStore | None = None


def get_vector_store() -> QdrantHybridStore:
    global _store
    if _store is None:
        _store = QdrantHybridStore()
    return _store
