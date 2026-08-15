from __future__ import annotations

from typing import Any, Protocol

from app.core.logging import get_logger

logger = get_logger(__name__)


class Reranker(Protocol):
    async def rerank(self, query: str, documents: list[dict[str, Any]], top_k: int) -> list[dict[str, Any]]: ...


class CohereReranker:
    def __init__(self) -> None:
        from cohere import AsyncClientV2

        self._client = AsyncClientV2(api_key="")  # injected via settings on first call
        self._model = ""

    async def rerank(self, query: str, documents: list[dict[str, Any]], top_k: int) -> list[dict[str, Any]]:
        from app.core.config import settings

        if not settings.COHERE_API_KEY:
            return documents[:top_k]
        if self._model != settings.COHERE_RERANK_MODEL or not self._client._api_key:
            from cohere import AsyncClientV2

            self._client = AsyncClientV2(api_key=settings.COHERE_API_KEY)
            self._model = settings.COHERE_RERANK_MODEL

        resp = await self._client.rerank(
            model=settings.COHERE_RERANK_MODEL,
            query=query,
            documents=[d.get("text", "") for d in documents],
            top_n=top_k,
            return_documents=True,
        )
        ordered: list[dict[str, Any]] = []
        for result in resp.results:
            doc = dict(documents[result.index])
            doc["score"] = result.relevance_score
            ordered.append(doc)
        return ordered


class BGEReranker:
    def __init__(self) -> None:
        from sentence_transformers import CrossEncoder

        self._model: CrossEncoder | None = None

    def _ensure_model(self) -> None:
        from app.core.config import settings

        if self._model is None:
            from sentence_transformers import CrossEncoder

            self._model = CrossEncoder(settings.BGE_RERANK_MODEL)

    async def rerank(self, query: str, documents: list[dict[str, Any]], top_k: int) -> list[dict[str, Any]]:
        import asyncio

        self._ensure_model()
        pairs = [(query, d.get("text", "")) for d in documents]
        scores = await asyncio.to_thread(self._model.predict, pairs)
        ranked = sorted(zip(documents, scores), key=lambda pair: float(pair[1]), reverse=True)
        for doc, score in ranked:
            doc["score"] = float(score)
        return [doc for doc, _ in ranked[:top_k]]


class NoopReranker:
    async def rerank(self, query: str, documents: list[dict[str, Any]], top_k: int) -> list[dict[str, Any]]:
        return documents[:top_k]


_reranker: Reranker | None = None


def get_reranker() -> Reranker:
    global _reranker
    if _reranker is None:
        from app.core.config import settings

        if settings.RERANKER_PROVIDER == "cohere":
            _reranker = CohereReranker()
        elif settings.RERANKER_PROVIDER == "bge":
            _reranker = BGEReranker()
        else:
            _reranker = NoopReranker()
        logger.info("Reranker initialized: %s", settings.RERANKER_PROVIDER)
    return _reranker
