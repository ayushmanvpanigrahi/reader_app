from fastapi import APIRouter, Depends

from app.api.deps import get_current_user_id
from app.core.config import settings
from app.core.security import create_access_token
from app.models.schemas import TokenRequest, TokenResponse

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/token", response_model=TokenResponse)
async def issue_token(request: TokenRequest) -> TokenResponse:
    token = create_access_token(subject=request.user_id)
    return TokenResponse(
        access_token=token,
        expires_in_seconds=settings.JWT_EXPIRES_MINUTES * 60,
    )


@router.get("/me")
async def me(user_id: str = Depends(get_current_user_id)) -> dict[str, str]:
    return {"user_id": user_id}
