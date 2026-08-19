"""Verify the seeded local review API without exposing its temporary token."""

from __future__ import annotations

import sqlite3
from uuid import UUID

import httpx

from app.modules.auth.domain import UserRole
from app.modules.auth.tokens import TokenService


def main() -> None:
    connection = sqlite3.connect("var/snakecare-review3.db")
    row = connection.execute(
        "SELECT id FROM users WHERE role = 'government_admin' LIMIT 1"
    ).fetchone()
    connection.close()
    if row is None:
        raise RuntimeError("Government review user is missing")
    token, _ = TokenService(
        secret="local-review-secret-with-more-than-thirty-two-characters",
        issuer="snakecare-api",
        audience="snakecare-clients",
        access_minutes=15,
        refresh_days=30,
    ).issue_access_token(UUID(row[0]), UserRole.GOVERNMENT_ADMIN)
    response = httpx.get(
        "http://127.0.0.1:8001/api/v1/hospital-coordination/facilities",
        params={"city": "Pune", "limit": 50},
        headers={"Authorization": f"Bearer {token}"},
        timeout=10,
    )
    response.raise_for_status()
    payload = response.json()
    print(f"API Pune hospitals: {payload['total']}")
    print(f"First hospital: {payload['items'][0]['name']}")


if __name__ == "__main__":
    main()
