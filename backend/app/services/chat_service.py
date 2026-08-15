from __future__ import annotations

import json
from typing import Any, AsyncGenerator

from langgraph.types import Command

from app.agents.graph import get_compiled_graph
from app.core.config import settings
from app.core.logging import get_logger
from app.models.schemas import ChatRequest, ExplainHighlightRequest, ResumeRequest
from app.services import provider_context

logger = get_logger(__name__)


def _config(thread_id: str, user_id: str) -> dict[str, Any]:
    return {"configurable": {"thread_id": thread_id, "user_id": user_id}}


def _initial_state(request: ChatRequest | ExplainHighlightRequest) -> dict[str, Any]:
    state: dict[str, Any] = {
        "query": request.query if isinstance(request, ChatRequest) else f"Explain this highlighted passage: {request.selected_text}",
        "mode": request.mode if isinstance(request, ChatRequest) else "single",
        "book_ids": request.book_ids if isinstance(request, ChatRequest) else [request.book_id],
        "user_id": request.user_id,
        "session_id": request.session_id,
        "retrieval_attempts": 0,
        "hitl_needed": False,
    }

    if isinstance(request, ChatRequest) and request.mode == "selected" and len(request.book_ids) > 2:
        state["hitl_needed"] = True
        state["hitl_reason"] = f"Multi-book summarisation across {len(request.book_ids)} books requires approval before a costly generation pass."

    if isinstance(request, ExplainHighlightRequest):
        state["highlight_text"] = request.selected_text
        state["surrounding_context"] = request.surrounding_context
        state["book_id"] = request.book_id
        state["chapter"] = request.chapter
        state["hitl_needed"] = False

    return state


def _dump(event: dict[str, Any]) -> str:
    return json.dumps(event, ensure_ascii=False)


async def _yield_with_provider_events(agen: AsyncGenerator[dict[str, Any], None]):
    """Yield provider switch events before each graph event so the UI sees
    which provider actually served the request."""
    async for event in agen:
        for prov_event in provider_context.drain_events():
            yield prov_event
        yield event
    for prov_event in provider_context.drain_events():
        yield prov_event


async def run_chat(request: ChatRequest) -> AsyncGenerator[dict[str, Any], None]:
    graph = get_compiled_graph()
    config = _config(request.session_id, request.user_id)
    state = _initial_state(request)

    async for event in _yield_with_provider_events(graph.astream(state, config=config, stream_mode="custom")):
        yield event

    snapshot = await graph.aget_state(config)
    interrupted = bool(snapshot.next)
    if interrupted:
        yield {"type": "hitl_pending", "data": {"reason": snapshot.values.get("hitl_reason")}}
        return

    final = snapshot.values
    yield {
        "type": "done",
        "data": {
            "citations": final.get("citations", []),
            "grounded": final.get("grounded", True),
            "unsupported_claims": final.get("unsupported_claims", []),
            "usage": final.get("usage", {}),
        },
    }


async def run_highlight(request: ExplainHighlightRequest) -> AsyncGenerator[dict[str, Any], None]:
    graph = get_compiled_graph()
    config = _config(request.session_id, request.user_id)
    state = _initial_state(request)

    async for event in _yield_with_provider_events(graph.astream(state, config=config, stream_mode="custom")):
        yield event

    snapshot = await graph.aget_state(config)
    final = snapshot.values
    yield {
        "type": "done",
        "data": {
            "highlight": {
                "simple_meaning": _extract_section(final.get("generated_answer", ""), "Section A"),
                "author_context": _extract_section(final.get("generated_answer", ""), "Section B"),
                "memory_anchor": final.get("socratic_output", {}),
            },
            "citations": final.get("citations", []),
        },
    }


async def resume_thread(request: ResumeRequest) -> AsyncGenerator[dict[str, Any], None]:
    graph = get_compiled_graph()
    config = _config(request.thread_id, request.user_id)

    async for event in _yield_with_provider_events(graph.astream(Command(resume=request.approved), config=config, stream_mode="custom")):
        yield event

    snapshot = await graph.aget_state(config)
    if snapshot.next:
        yield {"type": "hitl_pending", "data": {"reason": "Additional approval required."}}
        return

    final = snapshot.values
    yield {
        "type": "done",
        "data": {
            "citations": final.get("citations", []),
            "grounded": final.get("grounded", True),
            "usage": final.get("usage", {}),
        },
    }


def _extract_section(answer: str, section_name: str) -> str:
    lines = answer.split("---")
    for block in lines:
        if section_name.lower() in block.lower():
            cleaned = block.strip()
            first_line = cleaned.splitlines()[0] if cleaned.splitlines() else ""
            for prefix in ("Section A", "Section B", "Section C"):
                if first_line.startswith(prefix):
                    cleaned = "\n".join(cleaned.splitlines()[1:]).strip()
                    return cleaned
            return cleaned
    return ""
