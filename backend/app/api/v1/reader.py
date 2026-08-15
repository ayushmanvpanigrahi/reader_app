import asyncio
import json

from fastapi import APIRouter, Depends
from sse_starlette.sse import EventSourceResponse

from app.api.deps import get_current_user_id
from app.core.logging import get_logger
from app.models.schemas import ExplainHighlightRequest, ResumeRequest
from app.services.chat_service import resume_thread, run_highlight

logger = get_logger(__name__)

router = APIRouter(tags=["reader"])


@router.post("/reader/explain-highlight")
async def explain_highlight(
    request: ExplainHighlightRequest,
    user_id: str = Depends(get_current_user_id),
) -> EventSourceResponse:
    request.user_id = user_id

    async def event_gen():
        try:
            async for event in run_highlight(request):
                yield {
                    "event": "message",
                    "data": json.dumps(event, ensure_ascii=False),
                }
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            logger.exception("Explain-highlight stream failed")
            yield {
                "event": "message",
                "data": json.dumps({"type": "error", "data": {"detail": str(exc)}}),
            }

    return EventSourceResponse(event_gen(), ping=15)


@router.post("/chat/resume")
async def resume_chat(
    request: ResumeRequest,
    user_id: str = Depends(get_current_user_id),
) -> EventSourceResponse:
    if request.user_id != user_id:
        request.user_id = user_id

    async def event_gen():
        try:
            async for event in resume_thread(request):
                yield {
                    "event": "message",
                    "data": json.dumps(event, ensure_ascii=False),
                }
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            logger.exception("Resume stream failed")
            yield {
                "event": "message",
                "data": json.dumps({"type": "error", "data": {"detail": str(exc)}}),
            }

    return EventSourceResponse(event_gen(), ping=15)
