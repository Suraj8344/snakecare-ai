from __future__ import annotations

from typing import Protocol

from app.modules.auth.domain import VerifiedIdentity


class IdentityVerifier(Protocol):
    async def verify(self, id_token: str) -> VerifiedIdentity: ...
