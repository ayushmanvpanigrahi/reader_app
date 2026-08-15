from __future__ import annotations

from contextvars import ContextVar
from dataclasses import dataclass

from app.core.config import settings
from app.services.provider_registry import ProviderConfig, get_provider_registry

_user_id_var: ContextVar[str | None] = ContextVar("provider_user_id", default=None)
_chat_pref_var: ContextVar[str | None] = ContextVar("provider_chat_pref", default=None)
_embed_pref_var: ContextVar[str | None] = ContextVar("provider_embed_pref", default=None)
_pinned_var: ContextVar[ProviderConfig | None] = ContextVar("provider_pinned", default=None)


@dataclass(frozen=True)
class Endpoint:
    base_url: str
    api_key: str
    model: str
    provider_id: str | None = None
    provider_name: str = ""


def bind_request(
    *,
    user_id: str,
    provider_id: str | None = None,
    embedding_provider_id: str | None = None,
) -> None:
    _user_id_var.set(user_id)
    _chat_pref_var.set(provider_id)
    _embed_pref_var.set(embedding_provider_id)


def reset_request() -> None:
    _user_id_var.set(None)
    _chat_pref_var.set(None)
    _embed_pref_var.set(None)
    _pinned_var.set(None)


def user_id() -> str | None:
    return _user_id_var.get()


def pin_provider(config: ProviderConfig) -> None:
    _pinned_var.set(config)


def unpin_provider() -> None:
    _pinned_var.set(None)


def _to_endpoint(cfg: ProviderConfig, *, embedding: bool) -> Endpoint:
    model = cfg.embedding_model if embedding else cfg.chat_model
    return Endpoint(
        base_url=cfg.base_url,
        api_key=cfg.api_key,
        model=model,
        provider_id=cfg.id,
        provider_name=cfg.name,
    )


def chat_endpoints() -> list[Endpoint]:
    pinned = _pinned_var.get()
    if pinned is not None:
        ep = _to_endpoint(pinned, embedding=False)
        if ep.model:
            return [ep]

    uid = _user_id_var.get()
    if uid:
        candidates = get_provider_registry().chat_candidates(uid, _chat_pref_var.get())
        if candidates:
            return [_to_endpoint(c, embedding=False) for c in candidates]

    return [
        Endpoint(
            base_url=(settings.OPENAI_BASE_URL or "https://api.openai.com/v1").rstrip("/"),
            api_key=settings.OPENAI_API_KEY,
            model=settings.CHAT_MODEL,
        )
    ]


def fast_chat_endpoints() -> list[Endpoint]:
    """Endpoints that serve settings.FAST_CHAT_MODEL, for internal LLM calls."""
    if not settings.FAST_CHAT_MODEL:
        return []
    uid = _user_id_var.get()
    if uid:
        for cfg in get_provider_registry().all(uid):
            if cfg.chat_model == settings.FAST_CHAT_MODEL and cfg.base_url and cfg.api_key:
                return [_to_endpoint(cfg, embedding=False)]
    return []


def internal_chat_endpoints() -> list[Endpoint]:
    """Preferred chain for non-visible LLM calls: fast model first (when
    configured), then the normal chat endpoints, deduplicated."""
    merged = fast_chat_endpoints() + chat_endpoints()
    seen: set[tuple[str, str]] = set()
    out: list[Endpoint] = []
    for ep in merged:
        key = (ep.base_url, ep.model)
        if key in seen:
            continue
        seen.add(key)
        out.append(ep)
    return out


def embed_endpoints() -> list[Endpoint]:
    pinned = _pinned_var.get()
    if pinned is not None and pinned.embedding_model:
        return [_to_endpoint(pinned, embedding=True)]

    uid = _user_id_var.get()
    if uid:
        candidates = get_provider_registry().embed_candidates(uid, _embed_pref_var.get())
        if candidates:
            return [_to_endpoint(c, embedding=True) for c in candidates]

    if settings.EMBEDDING_MODEL and settings.OPENAI_API_KEY:
        return [
            Endpoint(
                base_url=(settings.OPENAI_BASE_URL or "https://api.openai.com/v1").rstrip("/"),
                api_key=settings.OPENAI_API_KEY,
                model=settings.EMBEDDING_MODEL,
            )
        ]
    return []


def embed_model_hint() -> str:
    endpoints = embed_endpoints()
    return endpoints[0].model if endpoints else ""


def mark_failed(provider_id: str | None, reason: str) -> None:
    uid = _user_id_var.get()
    if provider_id and uid:
        get_provider_registry().mark_failed(uid, provider_id, reason)


def mark_success(provider_id: str | None) -> None:
    uid = _user_id_var.get()
    if provider_id and uid:
        get_provider_registry().mark_success(uid, provider_id)


def emit_provider_used(provider_name: str, model: str, *, kind: str) -> None:
    uid = _user_id_var.get()
    if uid:
        get_provider_registry().emit(
            uid,
            {"type": "provider_used", "data": {"kind": kind, "provider": provider_name, "model": model}},
        )


def drain_events() -> list[dict]:
    uid = _user_id_var.get()
    if not uid:
        return []
    return get_provider_registry().drain_events(uid)
