from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass, field

from app.core.logging import get_logger

logger = get_logger(__name__)

RATE_LIMIT_COOLDOWN_SECONDS = 60.0


@dataclass
class ProviderConfig:
    id: str
    name: str
    base_url: str
    api_key: str = ""
    chat_model: str = ""
    embedding_model: str = ""
    priority: int = 0
    healthy: bool = True
    cooldown_until: float = 0.0
    last_error: str = ""

    @property
    def supports_embeddings(self) -> bool:
        return bool(self.embedding_model)

    def in_cooldown(self, now: float | None = None) -> bool:
        return self.cooldown_until > (now if now is not None else time.time())


class ProviderRegistry:
    """Per-user, in-memory registry of OpenAI-compatible providers.

    The Flutter app syncs every provider it knows (base URL + key + chat and
    embedding model) here once per session. Every chat / ingest / highlight
    request then resolves providers through this registry, so a provider that
    exhausts its free quota is marked unhealthy and the next one is picked
    automatically. Lives in memory only (this is a single-user free setup).
    """

    def __init__(self) -> None:
        self._providers: dict[str, list[ProviderConfig]] = {}
        self._cursor: dict[str, int] = {}
        self._events: dict[str, list[dict]] = {}
        self._lock = asyncio.Lock()

    async def sync(self, user_id: str, providers: list[dict]) -> None:
        async with self._lock:
            previous = {p.id: p for p in self._providers.get(user_id, [])}
            merged: list[ProviderConfig] = []
            for raw in providers:
                cfg = ProviderConfig(
                    id=str(raw.get("id", "")),
                    name=str(raw.get("name", raw.get("id", ""))),
                    base_url=str(raw.get("base_url", "")).rstrip("/"),
                    api_key=str(raw.get("api_key", "")),
                    chat_model=str(raw.get("chat_model", "")),
                    embedding_model=str(raw.get("embedding_model", "")),
                    priority=int(raw.get("priority", 0) or 0),
                )
                prev = previous.get(cfg.id)
                if prev is not None:
                    cfg.healthy = prev.healthy
                    cfg.cooldown_until = prev.cooldown_until
                merged.append(cfg)
            self._providers[user_id] = merged
            self._cursor[user_id] = 0
        self.emit(user_id, {"type": "providers_synced", "data": {"count": len(merged)}})

    def list(self, user_id: str) -> list[dict]:
        return [
            {
                "id": p.id,
                "name": p.name,
                "base_url": p.base_url,
                "chat_model": p.chat_model,
                "embedding_model": p.embedding_model,
                "priority": p.priority,
                "healthy": p.healthy,
                "cooldown_until": p.cooldown_until,
                "last_error": p.last_error,
            }
            for p in self._providers.get(user_id, [])
        ]

    def has_providers(self, user_id: str) -> bool:
        return bool(self._providers.get(user_id))

    def chat_candidates(self, user_id: str, preferred_id: str | None = None) -> list[ProviderConfig]:
        return self._candidates(user_id, preferred_id, need_embedding=False)

    def embed_candidates(self, user_id: str, preferred_id: str | None = None) -> list[ProviderConfig]:
        return self._candidates(user_id, preferred_id, need_embedding=True)

    def _candidates(
        self,
        user_id: str,
        preferred_id: str | None,
        *,
        need_embedding: bool,
    ) -> list[ProviderConfig]:
        providers = self._providers.get(user_id, [])
        if not providers:
            return []
        now = time.time()
        healthy = [p for p in providers if p.healthy and not p.in_cooldown(now)]
        if need_embedding:
            healthy = [p for p in healthy if p.supports_embeddings]
        if not healthy:
            return []
        healthy.sort(key=lambda p: (0 if p.id == preferred_id else 1, p.priority, p.name))
        cursor = self._cursor.get(user_id, 0)
        rotated = healthy[cursor:] + healthy[:cursor]
        self._cursor[user_id] = (cursor + 1) % len(healthy)
        return rotated

    def mark_failed(self, user_id: str, provider_id: str, reason: str) -> None:
        for p in self._providers.get(user_id, []):
            if p.id == provider_id:
                p.healthy = False
                p.cooldown_until = time.time() + RATE_LIMIT_COOLDOWN_SECONDS
                p.last_error = reason[:300]
                break
        self.emit(
            user_id,
            {"type": "provider_failed", "data": {"provider_id": provider_id, "reason": reason[:300]}},
        )

    def mark_success(self, user_id: str, provider_id: str) -> None:
        for p in self._providers.get(user_id, []):
            if p.id == provider_id:
                p.healthy = True
                p.cooldown_until = 0.0
                p.last_error = ""
                break

    def emit(self, user_id: str, event: dict) -> None:
        self._events.setdefault(user_id, []).append(event)

    def drain_events(self, user_id: str) -> list[dict]:
        return self._events.pop(user_id, [])


_registry: ProviderRegistry | None = None


def get_provider_registry() -> ProviderRegistry:
    global _registry
    if _registry is None:
        _registry = ProviderRegistry()
    return _registry
