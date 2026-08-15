import asyncio

from fastapi import APIRouter, Depends, status

from app.api.deps import get_current_user_id
from app.core.logging import get_logger
from app.models.schemas import (
    ProviderBackfillRequest,
    ProviderInfo,
    ProviderSyncRequest,
    ProviderSyncResponse,
)
from app.rag.vectorstore import get_vector_store
from app.services import provider_context
from app.services.provider_registry import get_provider_registry

logger = get_logger(__name__)

router = APIRouter(prefix="/providers", tags=["providers"])


@router.post("/sync", response_model=ProviderSyncResponse)
async def sync_providers(
    request: ProviderSyncRequest,
    user_id: str = Depends(get_current_user_id),
) -> ProviderSyncResponse:
    await get_provider_registry().sync(user_id, [p.model_dump() for p in request.providers])
    return ProviderSyncResponse(synced=len(request.providers))


@router.get("", response_model=list[ProviderInfo])
async def list_providers(user_id: str = Depends(get_current_user_id)) -> list[ProviderInfo]:
    return [ProviderInfo(**item) for item in get_provider_registry().list(user_id)]


@router.post("/backfill", status_code=status.HTTP_202_ACCEPTED)
async def backfill_embeddings(
    request: ProviderBackfillRequest,
    user_id: str = Depends(get_current_user_id),
) -> dict[str, str]:
    provider_context.bind_request(user_id=user_id)
    asyncio.create_task(_run_backfill(user_id, request.book_id))
    return {"status": "started"}


async def _run_backfill(user_id: str, book_id: str | None) -> None:
    try:
        count = await get_vector_store().backfill_missing_dense(user_id, book_id)
        logger.info("Backfill done: user=%s book=%s chunks=%d", user_id, book_id, count)
    except Exception as exc:  # noqa: BLE001 - background job, never crash
        logger.warning("Backfill failed: user=%s book=%s: %s", user_id, book_id, exc)
    finally:
        provider_context.reset_request()
