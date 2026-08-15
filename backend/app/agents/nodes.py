from __future__ import annotations

from typing import Any

from langgraph.types import StreamWriter, interrupt

from app.agents.llm import LLMError, get_llm
from app.agents.prompts import (
    HALLUCINATION_CHECKER_PROMPT,
    HIGHLIGHT_EXPLAINER_MEMORY_ANCHOR_PROMPT,
    MULTI_BOOK_COMPARATIVE_RAG_SYSTEM_PROMPT,
    RELEVANCE_GRADER_PROMPT,
    SINGLE_BOOK_RAG_SYSTEM_PROMPT,
)
from app.core.config import settings
from app.core.logging import get_logger
from app.models.agent_state import AgentState
from app.rag.reranker import get_reranker
from app.rag.vectorstore import get_vector_store

logger = get_logger(__name__)


async def query_router_node(state: AgentState, writer: StreamWriter) -> AgentState:
    if state.get("highlight_text"):
        scope = "highlight_explainer"
    elif state.get("mode") == "selected" and len(state.get("book_ids") or []) > 1:
        scope = "multi_selected_books"
    elif state.get("mode") == "all" or not state.get("book_ids"):
        scope = "all_books"
    else:
        scope = "single_book"

    writer({"type": "scope", "data": scope})
    return {"scope": scope}


async def hybrid_retrieval_node(state: AgentState, writer: StreamWriter) -> AgentState:
    store = get_vector_store()
    user_id = state["user_id"]
    query = state.get("rewritten_query") or state["query"]
    scope = state["scope"]

    book_ids: list[str] | None = None
    chapter: str | None = None
    if scope == "single_book":
        book_ids = (state.get("book_ids") or [])[:1]
    elif scope == "multi_selected_books":
        book_ids = state.get("book_ids") or None
    elif scope == "highlight_explainer":
        book_ids = [state["book_id"]] if state.get("book_id") else None
        chapter = state.get("chapter") or None

    docs = await store.hybrid_search(
        user_id=user_id,
        query=query,
        book_ids=book_ids,
        chapter=chapter,
    )

    if not docs:
        writer({"type": "status", "data": "No passages found for this scope."})
        return {"retrieved_docs": [], "graded_docs": [], "relevance_avg": 0.0}

    reranker = get_reranker()
    docs = await reranker.rerank(query, docs, top_k=settings.RERANK_TOP_K)
    writer({"type": "retrieved", "data": len(docs)})
    return {"retrieved_docs": docs, "graded_docs": docs}


async def relevance_grader_node(state: AgentState, writer: StreamWriter) -> AgentState:
    llm = get_llm()
    question = state.get("rewritten_query") or state["query"]
    docs = state.get("retrieved_docs") or []

    graded: list[dict[str, Any]] = []
    for doc in docs:
        prompt = RELEVANCE_GRADER_PROMPT.format(question=question, passage=doc.get("text", "")[:2500])
        try:
            verdict = await llm.complete_json(
                messages=[{"role": "user", "content": prompt}],
                temperature=0.0,
            )
            score = max(0.0, min(1.0, float(verdict.get("score", 0.0))))
        except (LLMError, ValueError, TypeError):
            score = doc.get("_score", 0.0)

        doc["relevance"] = score
        doc["relevance_reason"] = verdict.get("reasoning", "") if "verdict" in locals() else ""
        graded.append(doc)

    graded = [d for d in graded if d.get("relevance", 0.0) >= settings.RELEVANCE_THRESHOLD]
    avg = sum(d.get("relevance", 0.0) for d in graded) / len(graded) if graded else 0.0
    writer({"type": "status", "data": f"Relevance gate: {len(graded)}/{len(docs)} passages passed (avg {avg:.2f})."})
    return {"graded_docs": graded, "relevance_avg": avg}


async def query_rewriter_node(state: AgentState, writer: StreamWriter) -> AgentState:
    attempts = state.get("retrieval_attempts", 0) + 1
    llm = get_llm()
    try:
        rewritten = (
            await llm.complete(
                messages=[
                    {
                        "role": "system",
                        "content": "You rewrite a reader's question to improve retrieval recall while preserving intent. Return ONLY the rewritten question, no extra text.",
                    },
                    {
                        "role": "user",
                        "content": f"Original: {state['query']}\nNo good passages found. Rewrite for better search:",
                    },
                ],
                temperature=0.2,
            )
        ).strip()
    except LLMError:
        rewritten = state["query"]

    writer({"type": "status", "data": f"Retry {attempts}: query rewritten."})
    return {"rewritten_query": rewritten, "retrieval_attempts": attempts}


async def hitl_checkpoint_node(state: AgentState, writer: StreamWriter) -> AgentState:
    if not state.get("hitl_needed"):
        return {}

    decision = interrupt(
        {
            "reason": state.get("hitl_reason") or "Expensive operation requires approval.",
            "user_id": state["user_id"],
        }
    )
    approved = bool(decision)
    writer({"type": "hitl", "data": {"approved": approved}})
    return {"hitl_approved": approved}


async def answer_generator_node(state: AgentState, writer: StreamWriter) -> AgentState:
    llm = get_llm()
    scope = state["scope"]
    docs = state.get("graded_docs") or state.get("retrieved_docs") or []
    question = state.get("rewritten_query") or state["query"]

    context_blocks = []
    for i, doc in enumerate(docs, 1):
        context_blocks.append(
            f"[{i}] (Book: {doc.get('title','?')} | Chapter: {doc.get('chapter','?')} | Page {doc.get('page_number','?')})\n{doc.get('text','')}"
        )
    context = "\n\n".join(context_blocks) or "No retrieved passages."

    if scope == "highlight_explainer":
        system_prompt = HIGHLIGHT_EXPLAINER_MEMORY_ANCHOR_PROMPT.format(
            selected_text=state.get("highlight_text", ""),
            surrounding_context=state.get("surrounding_context", ""),
            title=(docs[0].get("title", "Unknown") if docs else "Unknown"),
            chapter=state.get("chapter") or (docs[0].get("chapter", "?") if docs else "?"),
            page_number=(docs[0].get("page_number", 1) if docs else 1),
        )
        messages = [{"role": "user", "content": system_prompt}]
    elif scope == "multi_selected_books":
        book_list = ", ".join(state.get("book_ids") or [])
        system_prompt = MULTI_BOOK_COMPARATIVE_RAG_SYSTEM_PROMPT.format(
            book_count=len(state.get("book_ids") or []) or 2,
            book_list=book_list,
            context=context,
            question=question,
        )
        messages = [{"role": "system", "content": system_prompt}]
    else:
        system_prompt = SINGLE_BOOK_RAG_SYSTEM_PROMPT.format(context=context, question=question)
        messages = [{"role": "system", "content": system_prompt}]

    usage: dict[str, int] = {}

    def on_token(token: str) -> None:
        writer({"type": "token", "data": token})

    def on_usage(u: dict[str, Any]) -> None:
        usage.update(
            {
                "prompt_tokens": u.get("prompt_tokens", 0),
                "completion_tokens": u.get("completion_tokens", 0),
                "total_tokens": u.get("total_tokens", 0),
            }
        )

    answer = await llm.stream_complete(messages=messages, on_token=on_token, on_usage=on_usage)

    citations = [
        {
            "title": d.get("title", ""),
            "chapter": d.get("chapter", ""),
            "page": d.get("page_number", 1),
            "score": float(d.get("relevance", d.get("_score", 0.0))),
        }
        for d in docs[: settings.RERANK_TOP_K]
    ]
    writer({"type": "usage", "data": usage})
    return {"generated_answer": answer, "citations": citations, "usage": usage}


async def hallucination_checker_node(state: AgentState, writer: StreamWriter) -> AgentState:
    llm = get_llm()
    docs = state.get("graded_docs") or state.get("retrieved_docs") or []
    answer = state.get("generated_answer", "")

    context = "\n\n".join(
        f"({d.get('title','?')} | Chapter: {d.get('chapter','?')} | Page {d.get('page_number','?')})\n{d.get('text','')}"
        for d in docs
    )
    if not context.strip():
        return {"grounded": False, "unsupported_claims": ["No grounding passages available."]}

    prompt = HALLUCINATION_CHECKER_PROMPT.format(context=context, answer=answer[:4000])
    try:
        verdict = await llm.complete_json(messages=[{"role": "user", "content": prompt}], temperature=0.0)
        grounded = bool(verdict.get("grounded", True))
        claims = [str(c) for c in verdict.get("unsupported_claims", [])]
    except (LLMError, ValueError, TypeError):
        grounded = True
        claims = []

    writer({"type": "status", "data": "Grounded" if grounded else "Hallucination risk detected."})
    return {"grounded": grounded, "unsupported_claims": claims}


async def socratic_memory_anchor_node(state: AgentState, writer: StreamWriter) -> AgentState:
    llm = get_llm()
    answer = state.get("generated_answer", "")

    prompt = f"""You are a memory expert. Based on the explanation below, create a compact memory anchor:
- reflection_question: one Socratic question connecting the idea to the reader's life
- analogy: one vivid real-world analogy
- takeaway: one crisp sentence

Return JSON ONLY: {{"reflection_question": "...", "analogy": "...", "takeaway": "..."}}

Explanation:
{answer[:2500]}"""

    try:
        anchor = await llm.complete_json(messages=[{"role": "user", "content": prompt}], temperature=0.5)
        anchor = {
            "reflection_question": str(anchor.get("reflection_question", "")),
            "analogy": str(anchor.get("analogy", "")),
            "takeaway": str(anchor.get("takeaway", "")),
        }
    except (LLMError, ValueError, TypeError):
        anchor = {"reflection_question": "", "analogy": "", "takeaway": ""}

    writer({"type": "anchor", "data": anchor})
    return {"socratic_output": anchor}


def route_after_hitl(state: AgentState) -> str:
    if state.get("hitl_needed") and not state.get("hitl_approved"):
        return "declined"
    return "approved"


def route_after_checker(state: AgentState) -> str:
    scope = state.get("scope")
    if state.get("grounded", True):
        if scope == "highlight_explainer":
            return "socratic"
        return "done"
    return "rewrite"


def route_after_grader(state: AgentState) -> str:
    docs = state.get("graded_docs") or []
    attempts = state.get("retrieval_attempts", 0)
    if not docs and attempts < settings.RETRIEVAL_MAX_ATTEMPTS:
        return "rewrite"
    return "generate"
