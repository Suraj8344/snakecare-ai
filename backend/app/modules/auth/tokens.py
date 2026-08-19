from __future__ import annotations

import hashlib
import secrets
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import jwt

from app.modules.auth.domain import InvalidCredentialsError, UserRole


@dataclass(frozen=True, slots=True)
class AccessPrincipal:
    user_id: UUID
    role: UserRole


class TokenService:
    def __init__(
        self,
        *,
        secret: str,
        issuer: str,
        audience: str,
        access_minutes: int,
        refresh_days: int,
    ) -> None:
        self._secret = secret
        self._issuer = issuer
        self._audience = audience
        self.access_lifetime = timedelta(minutes=access_minutes)
        self.refresh_lifetime = timedelta(days=refresh_days)

    def issue_access_token(self, user_id: UUID, role: UserRole) -> tuple[str, datetime]:
        now = datetime.now(UTC)
        expires_at = now + self.access_lifetime
        token = jwt.encode(
            {
                "sub": str(user_id),
                "role": role.value,
                "type": "access",
                "iat": now,
                "exp": expires_at,
                "iss": self._issuer,
                "aud": self._audience,
                "jti": str(uuid4()),
            },
            self._secret,
            algorithm="HS256",
        )
        return token, expires_at

    def decode_access_token(self, token: str) -> AccessPrincipal:
        try:
            claims = jwt.decode(
                token,
                self._secret,
                algorithms=["HS256"],
                issuer=self._issuer,
                audience=self._audience,
                options={"require": ["sub", "role", "type", "iat", "exp", "jti"]},
            )
            if claims["type"] != "access":
                raise InvalidCredentialsError
            return AccessPrincipal(user_id=UUID(claims["sub"]), role=UserRole(claims["role"]))
        except (jwt.PyJWTError, KeyError, ValueError) as exc:
            raise InvalidCredentialsError from exc

    @staticmethod
    def new_refresh_token() -> str:
        return secrets.token_urlsafe(48)

    @staticmethod
    def hash_token(token: str) -> str:
        return hashlib.sha256(token.encode("utf-8")).hexdigest()

    @staticmethod
    def fingerprint(value: str | None) -> str | None:
        if not value:
            return None
        return hashlib.sha256(value.encode("utf-8")).hexdigest()
