import asyncio
import json

from fastapi import APIRouter, Depends
from sse_starlette.sse import EventSourceResponse

from app.api.deps import get_current_user_id
from app.core.logging import get_logger
from app.models.schemas import ChatRequest
from app.services.chat_service import run_chat

logger = get_logger(__name__)

router = APIRouter(prefix="/chat", tags=["chat"])


@router.post("/stream")
async def chat_stream(
    request: ChatRequest,
    user_id: str = Depends(get_current_user_id),
) -> EventSourceResponse:
    if request.user_id != user_id:
        request.user_id = user_id

    async def event_gen():
        try:
            async for event in run_chat(request):
                yield {
                    "event": "message",
                    "data": json.dumps(event, ensure_ascii=False),
                }
        except asyncio.CancelledError:
            logger.info("Client disconnected, cancelling chat stream.")
            raise
        except Exception as exc:
            logger.exception("Chat stream failed")
            yield {
                "event": "message",
                "data": json.dumps({"type": "error", "data": {"detail": str(exc)}}),
            }

    return EventSourceResponse(event_gen(), ping=15)
