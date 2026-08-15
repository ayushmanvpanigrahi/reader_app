from __future__ import annotations

import asyncio
import hashlib
import math
import re
from typing import Any, Sequence

from qdrant_client import AsyncQdrantClient
from qdrant_client.models import (
    Distance,
    FieldCondition,
    Filter,
    Fusion,
    FusionQuery,
    MatchValue,
    NamedSparseVector,
    NamedVector,
    PointStruct,
    Prefetch,
    SparseIndexParams,
    SparseVector,
    SparseVectorParams,
    VectorParams,
)

from app.core.config import settings
from app.core.logging import get_logger
from app.rag.embeddings import get_embeddings

logger = get_logger(__name__)

DENSE_VECTOR_NAME = "dense"
SPARSE_VECTOR_NAME = "bm25"

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
            if as_query:
                idf = self._idf(idx)
            else:
                idf = 1.0
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

    def _collection_name(self, user_id: str) -> str:
        safe_user = hashlib.sha1(user_id.encode()).hexdigest()[:12]
        return f"{settings.COLLECTION_PREFIX}_{safe_user}"

    async def _ensure_collection(self, user_id: str, vector_size: int) -> None:
        name = self._collection_name(user_id)
        existing = await self._client.collection_exists(name)
        if existing:
            return
        await self._client.create_collection(
            collection_name=name,
            vectors_config={
                DENSE_VECTOR_NAME: VectorParams(size=vector_size, distance=Distance.COSINE),
                SPARSE_VECTOR_NAME: SparseVectorParams(index=SparseIndexParams(on_disk=True)),
            },
        )

    async def index_chunks(self, chunks: list[dict[str, Any]]) -> int:
        if not chunks:
            return 0
        user_id = chunks[0]["user_id"]
        texts = [c["text"] for c in chunks]
        dense_vectors = await self._embeddings.embed(texts)
        sparse_vectors = [await self._bm25.encode(t, as_query=False) for t in texts]
        await self._bm25.add_documents(texts)

        await self._ensure_collection(user_id, len(dense_vectors[0]))
        points = [
            PointStruct(
                id=_stable_chunk_id(user_id, chunks[i]),
                vector={
                    DENSE_VECTOR_NAME: dense_vectors[i],
                    SPARSE_VECTOR_NAME: sparse_vectors[i],
                },
                payload=chunks[i],
            )
            for i in range(len(chunks))
        ]
        await self._client.upsert(collection_name=self._collection_name(user_id), points=points)
        logger.info("Indexed %d chunks for user %s", len(points), user_id)
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
        dense_vec = (await self._embeddings.embed([query]))[0]
        sparse_vec = await self._bm25.encode(query, as_query=True)

        conditions = [FieldCondition(key="user_id", match=MatchValue(value=user_id))]
        if book_ids:
            conditions.append(FieldCondition(key="book_id", match=MatchValue(value=book_ids[0])))
        if chapter:
            conditions.append(FieldCondition(key="chapter", match=MatchValue(value=chapter)))

        search_filter = Filter(must=conditions) if conditions else None

        response = await self._client.query_points(
            collection_name=self._collection_name(user_id),
            prefetch=[
                Prefetch(query=NamedVector(name=DENSE_VECTOR_NAME, vector=dense_vec), filter=search_filter, limit=dense_top_k),
                Prefetch(query=NamedSparseVector(name=SPARSE_VECTOR_NAME, vector=sparse_vec), filter=search_filter, limit=sparse_top_k),
            ],
            query=FusionQuery(fusion=Fusion.RRF),
            limit=final_top_k,
            with_payload=True,
        )

        docs: list[dict[str, Any]] = []
        for hit in response.points:
            payload = dict(hit.payload or {})
            payload["_score"] = hit.score
            docs.append(payload)
        return docs

    async def delete_book(self, user_id: str, book_id: str) -> None:
        await self._client.delete(
            collection_name=self._collection_name(user_id),
            points_selector=Filter(must=[FieldCondition(key="book_id", match=MatchValue(value=book_id))]),
        )


def _stable_chunk_id(user_id: str, chunk: dict[str, Any]) -> str:
    raw = f"{user_id}|{chunk['book_id']}|{chunk['chunk_index']}|{chunk['chapter']}"
    return hashlib.sha256(raw.encode()).hexdigest()


_store: QdrantHybridStore | None = None


def get_vector_store() -> QdrantHybridStore:
    global _store
    if _store is None:
        _store = QdrantHybridStore()
    return _store
