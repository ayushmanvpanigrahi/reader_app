import json

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from fastapi.responses import JSONResponse
from sse_starlette.sse import EventSourceResponse

from app.api.deps import get_current_user_id
from app.core.config import settings
from app.models.schemas import BookIndexInfo, IngestResponse, IngestStatus
from app.rag.vectorstore import get_vector_store
from app.services import provider_context
from app.services.ingest_service import enqueue_ingest, get_task

router = APIRouter(prefix="/ingest", tags=["ingest"])


@router.post("", response_model=IngestResponse, status_code=status.HTTP_202_ACCEPTED)
async def ingest_file(
    file: UploadFile = File(...),
    title: str | None = Form(default=None),
    author: str | None = Form(default=None),
    provider_id: str | None = Form(default=None),
    user_id: str = Depends(get_current_user_id),
) -> IngestResponse:
    allowed = {"pdf", "epub"}
    suffix = file.filename.rsplit(".", 1)[-1].lower() if file.filename else ""
    if suffix not in allowed:
        return JSONResponse(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            content={"detail": f"Unsupported file type '{suffix}'. Allowed: pdf, epub."},
        )

    provider_context.bind_request(user_id=user_id, provider_id=provider_id)

    # Read the file bytes BEFORE returning. Starlette closes UploadFile once the
    # response is sent, so a background task reading `file.file` afterwards fails
    # with "I/O operation on closed file" — the cause of every failed ingest.
    content = await file.read()

    task = await enqueue_ingest(
        user_id=user_id,
        filename=file.filename or "untitled",
        content=content,
        title=title,
        author=author,
    )
    return IngestResponse(task_id=task.task_id)


@router.get("/books", response_model=list[BookIndexInfo])
async def list_indexed_books(user_id: str = Depends(get_current_user_id)) -> list[BookIndexInfo]:
    """Server-side truth for which books are indexed for this user."""
    books = await get_vector_store().list_books(user_id)
    return [
        BookIndexInfo(
            book_id=b["book_id"],
            title=b.get("title") or "",
            chunks=b.get("chunks") or 0,
            embedded=bool(b.get("embedded")),
        )
        for b in books
    ]


@router.get("/status/{task_id}", response_model=IngestStatus)
async def ingest_status(task_id: str, user_id: str = Depends(get_current_user_id)) -> IngestStatus:
    task = get_task(task_id)
    if task is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found.")
    return IngestStatus(
        task_id=task.task_id,
        status=task.status,
        progress=task.progress,
        error=task.error,
        chunks_indexed=task.chunks_indexed,
        book_id=task.book_id,
        created_at=task.created_at,
    )
