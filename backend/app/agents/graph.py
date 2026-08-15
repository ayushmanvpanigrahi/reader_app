from __future__ import annotations

from langgraph.graph import END, START, StateGraph

from app.agents.memory import get_checkpointer
from app.agents.nodes import (
    answer_generator_node,
    hallucination_checker_node,
    hitl_checkpoint_node,
    hybrid_retrieval_node,
    query_rewriter_node,
    query_router_node,
    relevance_grader_node,
    route_after_checker,
    route_after_grader,
    route_after_hitl,
    socratic_memory_anchor_node,
)
from app.models.agent_state import AgentState

NODE_QUERY_ROUTER = "query_router_node"
NODE_RETRIEVAL = "hybrid_retrieval_node"
NODE_HITL = "hitl_checkpoint_node"
NODE_GRADER = "relevance_grader_node"
NODE_REWRITER = "query_rewriter_node"
NODE_GENERATOR = "answer_generator_node"
NODE_CHECKER = "hallucination_checker_node"
NODE_SOCRATIC = "socratic_memory_anchor_node"
NODE_DONE = "done_node"


def _build_graph() -> StateGraph:
    graph = StateGraph(AgentState)

    graph.add_node(NODE_QUERY_ROUTER, query_router_node)
    graph.add_node(NODE_RETRIEVAL, hybrid_retrieval_node)
    graph.add_node(NODE_HITL, hitl_checkpoint_node)
    graph.add_node(NODE_GRADER, relevance_grader_node)
    graph.add_node(NODE_REWRITER, query_rewriter_node)
    graph.add_node(NODE_GENERATOR, answer_generator_node)
    graph.add_node(NODE_CHECKER, hallucination_checker_node)
    graph.add_node(NODE_SOCRATIC, socratic_memory_anchor_node)
    graph.add_node(NODE_DONE, lambda state: {"error": None})

    graph.add_edge(START, NODE_QUERY_ROUTER)
    graph.add_edge(NODE_QUERY_ROUTER, NODE_RETRIEVAL)
    graph.add_edge(NODE_RETRIEVAL, NODE_HITL)

    graph.add_conditional_edges(
        NODE_HITL,
        route_after_hitl,
        {"approved": NODE_GRADER, "declined": NODE_DONE},
    )

    graph.add_conditional_edges(
        NODE_GRADER,
        route_after_grader,
        {"rewrite": NODE_REWRITER, "generate": NODE_GENERATOR},
    )
    graph.add_edge(NODE_REWRITER, NODE_RETRIEVAL)

    graph.add_edge(NODE_GENERATOR, NODE_CHECKER)

    graph.add_conditional_edges(
        NODE_CHECKER,
        route_after_checker,
        {"rewrite": NODE_REWRITER, "socratic": NODE_SOCRATIC, "done": NODE_DONE},
    )
    graph.add_edge(NODE_SOCRATIC, NODE_DONE)
    graph.add_edge(NODE_DONE, END)

    return graph


_compiled = None


def compile_graph():
    graph = _build_graph()
    compiled = graph.compile(checkpointer=get_checkpointer())
    return compiled


def get_compiled_graph():
    global _compiled
    if _compiled is None:
        _compiled = compile_graph()
    return _compiled
