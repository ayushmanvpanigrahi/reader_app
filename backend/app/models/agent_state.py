from typing import Any, TypedDict


class ChunkDoc(TypedDict, total=False):
    chunk_id: str
    user_id: str
    book_id: str
    title: str
    author: str
    chapter: str
    page_number: int
    chunk_index: int
    text: str


class CitationDict(TypedDict):
    title: str
    chapter: str
    page: int
    score: float


class SocraticOutputDict(TypedDict, total=False):
    reflection_question: str
    analogy: str
    takeaway: str


class AgentState(TypedDict, total=False):
    # Request context
    query: str
    mode: str
    book_ids: list[str]
    user_id: str
    session_id: str

    # Router output
    scope: str

    # Highlight explainer inputs
    highlight_text: str
    surrounding_context: str
    book_id: str
    chapter: str

    # Retrieval
    retrieved_docs: list[ChunkDoc]
    retrieval_attempts: int
    rewritten_query: str

    # Grading / CRAG
    graded_docs: list[dict[str, Any]]
    relevance_avg: float

    # Generation
    generated_answer: str
    citations: list[CitationDict]

    # Self-RAG
    grounded: bool
    unsupported_claims: list[str]

    # Socratic memory anchor
    socratic_output: SocraticOutputDict

    # HITL
    hitl_needed: bool
    hitl_approved: bool | None
    hitl_reason: str | None

    # Diagnostics
    raw_input: dict[str, Any]
    error: str | None
