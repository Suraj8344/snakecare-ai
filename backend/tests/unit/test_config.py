import pytest
from pydantic import ValidationError

from app.core.config import Settings


def test_normalizes_managed_postgres_url_to_asyncpg() -> None:
    settings = Settings(database_url="postgresql://localhost/snakecare")
    assert settings.database_url == "postgresql+asyncpg://localhost/snakecare"


def test_rejects_unsupported_database_driver() -> None:
    with pytest.raises(ValidationError):
        Settings(database_url="postgresql+psycopg://localhost/snakecare")


def test_production_flag() -> None:
    settings = Settings(
        environment="production",
        firebase_project_id="snakecare-production",
        jwt_secret="production-secret-that-is-longer-than-thirty-two-characters",
    )
    assert settings.is_production is True
