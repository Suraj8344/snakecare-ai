from __future__ import annotations

import asyncio
import logging
from pathlib import Path
from typing import Any

import firebase_admin  # type: ignore[import-untyped]
import jwt
from firebase_admin import auth, credentials
from google.auth import exceptions as google_auth_exceptions
from google.auth.transport.requests import Request as GoogleAuthRequest
from google.oauth2 import id_token as google_id_token

from app.modules.auth.domain import InvalidCredentialsError, VerifiedIdentity

logger = logging.getLogger(__name__)


class FirebaseIdentityVerifier:
    def __init__(self, *, project_id: str | None, credentials_path: str | None) -> None:
        self._project_id = project_id
        self._credentials_path = credentials_path

    def _app(self) -> firebase_admin.App:
        try:
            return firebase_admin.get_app()
        except ValueError:
            options = {"projectId": self._project_id} if self._project_id else None
            if self._credentials_path:
                path = Path(self._credentials_path)
                if not path.is_file():
                    raise RuntimeError("Firebase credentials file is unavailable") from None
                return firebase_admin.initialize_app(credentials.Certificate(path), options)
            return firebase_admin.initialize_app(options=options)

    async def verify(self, id_token: str) -> VerifiedIdentity:
        try:
            if self._credentials_path:
                claims: dict[str, Any] = await asyncio.to_thread(
                    auth.verify_id_token,
                    id_token,
                    app=self._app(),
                    check_revoked=True,
                    clock_skew_seconds=5,
                )
            else:
                claims = await asyncio.to_thread(self._verify_with_public_certificates, id_token)
            uid = str(claims["uid"])
        except (
            ValueError,
            KeyError,
            auth.InvalidIdTokenError,
            auth.RevokedIdTokenError,
            google_auth_exceptions.GoogleAuthError,
            jwt.PyJWTError,
        ) as exc:
            unverified: dict[str, Any] = {}
            try:
                unverified = jwt.decode(
                    id_token,
                    options={
                        "verify_signature": False,
                        "verify_aud": False,
                        "verify_exp": False,
                    },
                )
            except jwt.PyJWTError:
                pass
            logger.warning(
                "firebase_id_token_rejected",
                extra={
                    "exception_type": type(exc).__name__,
                    "reason": str(exc),
                    "configured_project_id": self._project_id,
                    "token_audience": unverified.get("aud"),
                    "token_issuer": unverified.get("iss"),
                    "token_issued_at": unverified.get("iat"),
                    "token_expires_at": unverified.get("exp"),
                },
            )
            raise InvalidCredentialsError from exc
        return VerifiedIdentity(
            firebase_uid=uid,
            email=claims.get("email"),
            email_verified=bool(claims.get("email_verified", False)),
            phone_number=claims.get("phone_number"),
            display_name=claims.get("name"),
        )

    def _verify_with_public_certificates(self, token: str) -> dict[str, Any]:
        if not self._project_id:
            raise ValueError("Firebase project ID is required")
        claims = dict(
            google_id_token.verify_firebase_token(  # type: ignore[no-untyped-call]
                token,
                GoogleAuthRequest(),
                audience=self._project_id,
                clock_skew_in_seconds=5,
            )
        )
        expected_issuer = f"https://securetoken.google.com/{self._project_id}"
        if claims.get("iss") != expected_issuer:
            raise ValueError("Firebase token issuer is invalid")
        subject = str(claims.get("sub", ""))
        if not subject:
            raise ValueError("Firebase token subject is missing")
        claims.setdefault("uid", subject)
        return claims
