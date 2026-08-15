from typing import Any

from langgraph.checkpoint.base import BaseCheckpointSaver
from langgraph.checkpoint.memory import InMemorySaver

from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)


def build_checkpointer() -> BaseCheckpointSaver:
    if settings.CHECKPOINTER == "redis":
        try:
            from langgraph.checkpoint.redis import RedisSaver

            saver = RedisSaver.from_conn_string(settings.REDIS_URL)
            logger.info("Using Redis checkpointer: %s", settings.REDIS_URL)
            return saver
        except Exception as exc:  # pragma: no cover
            logger.warning("Redis checkpointer unavailable (%s), falling back to InMemory", exc)
    return InMemorySaver()


def build_usage_checkpointer() -> BaseCheckpointSaver:
    return InMemorySaver()


_saver: BaseCheckpointSaver | None = None


def get_checkpointer() -> BaseCheckpointSaver:
    global _saver
    if _saver is None:
        _saver = build_checkpointer()
    return _saver
