from __future__ import annotations

import asyncio
from typing import Sequence

import httpx

from app.core.logging import get_logger
from app.services import provider_context

logger = get_logger(__name__)


class NoEmbeddingProviderError(RuntimeError):
    """Raised when no provider with an embedding model is available."""


class OpenAICompatibleEmbeddings:
    def __init__(self) -> None:
        self._client = httpx.AsyncClient(timeout=60.0)
        self._lock = asyncio.Lock()

    async def embed(self, texts: Sequence[str]) -> list[list[float]]:
        endpoints = provider_context.embed_endpoints()
        if not endpoints:
            raise NoEmbeddingProviderError("No embedding-capable provider configured.")

        last_error: str | None = None
        for ep in endpoints:
            try:
                vectors = await self._embed_once(ep, texts)
                provider_context.emit_provider_used(ep.provider_name, ep.model, kind="embedding")
                return vectors
            except httpx.HTTPStatusError as exc:
                last_error = f"{ep.provider_name or ep.base_url}: HTTP {exc.response.status_code}: {exc.response.text[:300]}"
                self._switch_away(ep, last_error)
            except httpx.HTTPError as exc:
                last_error = f"{ep.provider_name or ep.base_url}: {exc}"
                self._switch_away(ep, last_error)
        raise NoEmbeddingProviderError(f"All embedding providers failed. Last error: {last_error}")

    async def _embed_once(self, ep: provider_context.Endpoint, texts: Sequence[str]) -> list[list[float]]:
        url = f"{ep.base_url.rstrip('/')}/embeddings"
        headers = {"Content-Type": "application/json"}
        if ep.api_key:
            headers["Authorization"] = f"Bearer {ep.api_key}"

        vectors: list[list[float]] = []
        for batch_start in range(0, len(texts), 64):
            batch = texts[batch_start : batch_start + 64]
            payload = {"model": ep.model, "input": list(batch)}
            async with self._lock:
                resp = await self._client.post(url, json=payload, headers=headers)
            resp.raise_for_status()
            data = resp.json()["data"]
            data.sort(key=lambda item: item["index"])
            vectors.extend([item["embedding"] for item in data])
        return vectors

    def _switch_away(self, ep: provider_context.Endpoint, reason: str) -> None:
        logger.warning("Embedding provider %s failed, switching away: %s", ep.provider_name or ep.provider_id, reason)
        provider_context.mark_failed(ep.provider_id, reason)

    async def aclose(self) -> None:
        await self._client.aclose()


_embeddings: OpenAICompatibleEmbeddings | None = None


def get_embeddings() -> OpenAICompatibleEmbeddings:
    global _embeddings
    if _embeddings is None:
        _embeddings = OpenAICompatibleEmbeddings()
    return _embeddings


async def embed_texts(texts: Sequence[str]) -> list[list[float]]:
    return await get_embeddings().embed(texts)
