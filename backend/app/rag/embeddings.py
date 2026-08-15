from __future__ import annotations

import asyncio
from typing import Sequence

import httpx

from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)


class OpenAICompatibleEmbeddings:
    def __init__(self) -> None:
        self._client = httpx.AsyncClient(timeout=60.0)
        self._lock = asyncio.Lock()

    @property
    def _headers(self) -> dict[str, str]:
        headers = {"Content-Type": "application/json"}
        if settings.OPENAI_API_KEY:
            headers["Authorization"] = f"Bearer {settings.OPENAI_API_KEY}"
        return headers

    async def embed(self, texts: Sequence[str]) -> list[list[float]]:
        url = f"{settings.OPENAI_BASE_URL or 'https://api.openai.com/v1'}/embeddings"
        vectors: list[list[float]] = []
        for batch_start in range(0, len(texts), 64):
            batch = texts[batch_start : batch_start + 64]
            payload = {"model": settings.EMBEDDING_MODEL, "input": list(batch)}
            async with self._lock:
                resp = await self._client.post(url, json=payload, headers=self._headers)
            resp.raise_for_status()
            data = resp.json()["data"]
            data.sort(key=lambda item: item["index"])
            vectors.extend([item["embedding"] for item in data])
        return vectors

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
