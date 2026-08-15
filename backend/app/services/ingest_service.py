from __future__ import annotations

import asyncio
import hashlib
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import BinaryIO

from app.core.config import settings
from app.core.logging import get_logger
from app.rag.document_processor import extract_epub, extract_pdf, semantic_chunk
from app.rag.vectorstore import get_vector_store

logger = get_logger(__name__)


@dataclass
class IngestTask:
    task_id: str
    status: str = "queued"
    progress: float = 0.0
    error: str | None = None
    chunks_indexed: int = 0
    book_id: str | None = None
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))


_tasks: dict[str, IngestTask] = {}


def get_task(task_id: str) -> IngestTask | None:
    return _tasks.get(task_id)


def create_book_id(filename: str, user_id: str) -> str:
    raw = f"{user_id}|{filename}|{uuid.uuid4()}"
    return f"book_{hashlib.sha256(raw.encode()).hexdigest()[:16]}"


async def enqueue_ingest(
    *,
    user_id: str,
    filename: str,
    file_reader: BinaryIO,
    title: str | None,
    author: str | None,
) -> IngestTask:
    task = IngestTask(task_id=uuid.uuid4().hex)
    _tasks[task.task_id] = task
    asyncio.create_task(_run_ingest(task, user_id, filename, file_reader, title, author))
    return task


async def _run_ingest(
    task: IngestTask,
    user_id: str,
    filename: str,
    file_reader: BinaryIO,
    title: str | None,
    author: str | None,
) -> None:
    try:
        task.status = "processing"
        task.progress = 0.05
        task.book_id = create_book_id(filename, user_id)
        book_title = title or filename.rsplit(".", 1)[0]

        content = await asyncio.to_thread(file_reader.read)

        filetype = filename.rsplit(".", 1)[-1].lower()
        if filetype == "epub":
            extracted = await asyncio.to_thread(extract_epub, content, book_title)
        else:
            extracted = await asyncio.to_thread(extract_pdf, content, book_title)

        task.progress = 0.4

        chunks = semantic_chunk(
            extracted,
            book_id=task.book_id,
            user_id=user_id,
            title=book_title,
            author=author or "",
            chunk_size=settings.CHUNK_SIZE,
            chunk_overlap=settings.CHUNK_OVERLAP,
        )

        task.progress = 0.7

        if not chunks:
            raise ValueError("No extractable text found in the uploaded document.")

        indexed = await get_vector_store().index_chunks(chunks)
        task.chunks_indexed = indexed
        task.status = "completed"
        task.progress = 1.0
        logger.info("Ingest complete: task=%s book=%s chunks=%d", task.task_id, task.book_id, indexed)
    except Exception as exc:
        task.status = "failed"
        task.error = str(exc)
        logger.exception("Ingest failed: task=%s", task.task_id)
