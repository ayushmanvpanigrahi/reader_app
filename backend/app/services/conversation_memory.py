from __future__ import annotations

import json
from collections import defaultdict, deque

from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)

# Hard cap on stored turns per session (much larger than what is injected into
# the prompt, so the last few turns survive a prompt-window change).
_MAX_TURNS = 40


class ConversationMemory:
    """Per-session chat memory for RAG conversation context.

    Backed by Redis when CHECKPOINTER=redis (shared across instances — the
    scalable path), otherwise an in-memory ring buffer per process.
    """

    def __init__(self) -> None:
        self._redis = None
        self._redis_failed = False
        self._rings: dict[str, deque[dict[str, str]]] = defaultdict(
            lambda: deque(maxlen=_MAX_TURNS)
        )
        if settings.CHECKPOINTER == "redis" and settings.REDIS_URL:
            try:
                import redis.asyncio as aioredis

                self._redis = aioredis.from_url(
                    settings.REDIS_URL,
                    encoding="utf-8",
                    decode_responses=True,
                )
            except Exception as exc:  # pragma: no cover
                logger.warning("Conversation memory falling back to in-memory: %s", exc)
                self._redis = None

    def _key(self, session_id: str) -> str:
        return f"conv:{session_id}"

    async def add_turn(self, session_id: str, role: str, content: str) -> None:
        if not session_id or not content:
            return
        entry = json.dumps({"role": role, "content": content}, ensure_ascii=False)
        if self._redis is not None and not self._redis_failed:
            try:
                key = self._key(session_id)
                async with self._redis.pipeline(transaction=True) as pipe:
                    pipe.rpush(key, entry)
                    pipe.ltrim(key, -_MAX_TURNS, -1)
                    await pipe.execute()
                return
            except Exception as exc:  # noqa: BLE001 - degrade to in-memory
                logger.warning("Redis conversation memory failed, degrading: %s", exc)
                self._redis_failed = True
        self._rings[session_id].append({"role": role, "content": content})

    async def recent_turns(self, session_id: str, max_turns: int) -> list[dict[str, str]]:
        if not session_id or max_turns <= 0:
            return []
        if self._redis is not None and not self._redis_failed:
            try:
                key = self._key(session_id)
                entries = await self._redis.lrange(key, -max_turns, -1)
                turns: list[dict[str, str]] = []
                for raw in entries:
                    try:
                        parsed = json.loads(raw)
                        if isinstance(parsed, dict):
                            turns.append(
                                {
                                    "role": str(parsed.get("role", "user"))[:16],
                                    "content": str(parsed.get("content", "")),
                                }
                            )
                    except (json.JSONDecodeError, TypeError):
                        continue
                return turns
            except Exception as exc:  # noqa: BLE001
                logger.warning("Redis conversation memory read failed, degrading: %s", exc)
                self._redis_failed = True
        ring = self._rings.get(session_id)
        if not ring:
            return []
        return list(ring)[-max_turns:]

    async def clear(self, session_id: str) -> None:
        if self._redis is not None and not self._redis_failed:
            try:
                await self._redis.delete(self._key(session_id))
                return
            except Exception as exc:  # noqa: BLE001
                logger.warning("Redis conversation memory clear failed: %s", exc)
                self._redis_failed = True
        self._rings.pop(session_id, None)

    async def dispose(self) -> None:
        if self._redis is not None:
            try:
                await self._redis.aclose()
            except Exception:  # noqa: BLE001
                pass
            self._redis = None


_memory: ConversationMemory | None = None


def get_conversation_memory() -> ConversationMemory:
    global _memory
    if _memory is None:
        _memory = ConversationMemory()
    return _memory


def format_history_block(turns: list[dict[str, str]]) -> str:
    """Render turns as a compact 'Previous conversation' block (or empty)."""
    if not turns:
        return ""
    lines = ["Previous conversation:"]
    for turn in turns:
        who = "User" if turn.get("role") == "user" else "Assistant"
        lines.append(f"{who}: {turn.get('content', '')}")
    return "\n".join(lines) + "\n\n"
