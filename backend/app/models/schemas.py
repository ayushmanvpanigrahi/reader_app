from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

QueryMode = Literal["single", "selected", "all"]
ScopeKind = Literal["single_book", "multi_selected_books", "all_books", "highlight_explainer"]
FileFormat = Literal["pdf", "epub"]


class TokenRequest(BaseModel):
    user_id: str = Field(..., min_length=1)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in_seconds: int


class ChatRequest(BaseModel):
    query: str = Field(..., min_length=1)
    mode: QueryMode = "single"
    book_ids: list[str] = Field(default_factory=list)
    session_id: str = "default"
    user_id: str = Field(..., min_length=1)


class ResumeRequest(BaseModel):
    thread_id: str = Field(..., min_length=1)
    approved: bool
    user_id: str = Field(..., min_length=1)


class ExplainHighlightRequest(BaseModel):
    selected_text: str = Field(..., min_length=1)
    book_id: str = Field(..., min_length=1)
    chapter: str = ""
    surrounding_context: str = ""
    user_id: str = Field(..., min_length=1)
    session_id: str = "highlight-default"


class IngestResponse(BaseModel):
    task_id: str
    status: str = "queued"


class IngestStatus(BaseModel):
    task_id: str
    status: Literal["queued", "processing", "completed", "failed"]
    progress: float = 0.0
    error: str | None = None
    chunks_indexed: int = 0
    book_id: str | None = None
    created_at: datetime


class Citation(BaseModel):
    title: str
    chapter: str
    page: int
    score: float | None = None


class SocraticAnchor(BaseModel):
    reflection_question: str
    analogy: str
    takeaway: str


class HighlightExplanation(BaseModel):
    simple_meaning: str
    author_context: str
    memory_anchor: SocraticAnchor


class AgentRunResult(BaseModel):
    thread_id: str
    answer: str
    citations: list[Citation] = Field(default_factory=list)
    grounded: bool = True
    unsupported_claims: list[str] = Field(default_factory=list)
    hitl_pending: bool = False
    usage: dict[str, int] = Field(default_factory=dict)
