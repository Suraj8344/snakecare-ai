from __future__ import annotations

from typing import Annotated

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.api.dependencies import DatabaseSession
from app.modules.auth.domain import InvalidCredentialsError
from app.modules.auth.models import User
from app.modules.auth.repository import SqlAlchemyAuthRepository
from app.modules.auth.service import AuthService

bearer = HTTPBearer(auto_error=False)


def get_auth_service(request: Request, session: DatabaseSession) -> AuthService:
    return AuthService(
        repository=SqlAlchemyAuthRepository(session),
        identity_verifier=request.app.state.identity_verifier,
        tokens=request.app.state.token_service,
        bootstrap_admin_emails=request.app.state.bootstrap_admin_emails,
    )


AuthServiceDependency = Annotated[AuthService, Depends(get_auth_service)]


async def get_current_user(
    request: Request,
    service: AuthServiceDependency,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
) -> User:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise InvalidCredentialsError
    principal = request.app.state.token_service.decode_access_token(credentials.credentials)
    user = await service.current_user(principal.user_id)
    if user.role != principal.role.value:
        raise InvalidCredentialsError
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]
