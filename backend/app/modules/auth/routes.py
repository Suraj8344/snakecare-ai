from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Request, status

from app.modules.auth.dependencies import AuthServiceDependency, CurrentUser
from app.modules.auth.schemas import (
    LogoutRequest,
    RefreshRequest,
    RoleUpdateRequest,
    SessionExchangeRequest,
    SessionResponse,
    UserView,
)
from app.modules.auth.service import IssuedSession

router = APIRouter(prefix="/auth", tags=["authentication"])


def _fingerprint(request: Request) -> str:
    client = request.client.host if request.client else "unknown"
    return f"{client}|{request.headers.get('user-agent', 'unknown')}"


def _session_response(issued: IssuedSession) -> SessionResponse:
    return SessionResponse(
        access_token=issued.access_token,
        refresh_token=issued.refresh_token,
        access_expires_at=issued.access_expires_at,
        user=UserView.model_validate(issued.user),
    )


@router.post("/session", response_model=SessionResponse, status_code=status.HTTP_201_CREATED)
async def exchange_session(
    payload: SessionExchangeRequest, request: Request, service: AuthServiceDependency
) -> SessionResponse:
    issued = await service.exchange_firebase_token(
        payload.firebase_id_token,
        request_id=getattr(request.state, "request_id", None),
        fingerprint=_fingerprint(request),
    )
    return _session_response(issued)


@router.post("/refresh", response_model=SessionResponse)
async def refresh_session(
    payload: RefreshRequest, request: Request, service: AuthServiceDependency
) -> SessionResponse:
    issued = await service.refresh(
        payload.refresh_token,
        request_id=getattr(request.state, "request_id", None),
        fingerprint=_fingerprint(request),
    )
    return _session_response(issued)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    payload: LogoutRequest,
    request: Request,
    service: AuthServiceDependency,
    current_user: CurrentUser,
) -> None:
    await service.logout(
        payload.refresh_token,
        user_id=current_user.id,
        request_id=getattr(request.state, "request_id", None),
    )


@router.get("/me", response_model=UserView)
async def me(current_user: CurrentUser) -> UserView:
    return UserView.model_validate(current_user)


@router.get("/users", response_model=list[UserView])
async def list_users(service: AuthServiceDependency, current_user: CurrentUser) -> list[UserView]:
    users = await service.list_users(current_user)
    return [UserView.model_validate(user) for user in users]


@router.patch("/users/{user_id}/role", response_model=UserView)
async def update_role(
    user_id: UUID,
    payload: RoleUpdateRequest,
    request: Request,
    service: AuthServiceDependency,
    current_user: CurrentUser,
) -> UserView:
    user = await service.change_role(
        actor=current_user,
        target_user_id=user_id,
        new_role=payload.role,
        hospital_employee_id=payload.hospital_employee_id,
        request_id=getattr(request.state, "request_id", None),
    )
    return UserView.model_validate(user)
