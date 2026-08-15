import json

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from fastapi.responses import JSONResponse
from sse_starlette.sse import EventSourceResponse

from app.api.deps import get_current_user_id
from app.core.config import settings
from app.models.schemas import IngestResponse, IngestStatus
from app.services.ingest_service import enqueue_ingest, get_task

router = APIRouter(prefix="/ingest", tags=["ingest"])


@router.post("", response_model=IngestResponse, status_code=status.HTTP_202_ACCEPTED)
async def ingest_file(
    file: UploadFile = File(...),
    title: str | None = Form(default=None),
    author: str | None = Form(default=None),
    user_id: str = Depends(get_current_user_id),
) -> IngestResponse:
    allowed = {"pdf", "epub"}
    suffix = file.filename.rsplit(".", 1)[-1].lower() if file.filename else ""
    if suffix not in allowed:
        return JSONResponse(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            content={"detail": f"Unsupported file type '{suffix}'. Allowed: pdf, epub."},
        )

    task = await enqueue_ingest(
        user_id=user_id,
        filename=file.filename or "untitled",
        file_reader=file.file,
        title=title,
        author=author,
    )
    return IngestResponse(task_id=task.task_id)


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
