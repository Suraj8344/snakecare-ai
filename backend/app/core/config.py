from __future__ import annotations

from functools import lru_cache
from typing import Literal

from pydantic import Field, RedisDsn, SecretStr, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=("../.env", ".env"),
        env_prefix="SNAKECARE_",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = "SnakeCare AI API"
    environment: Literal["local", "test", "staging", "production"] = "local"
    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"] = "INFO"
    api_v1_prefix: str = "/api/v1"
    database_url: str = "postgresql+asyncpg://snakecare:snakecare@localhost:5432/snakecare"
    redis_enabled: bool = False
    redis_url: RedisDsn = RedisDsn("redis://localhost:6379/0")
    cors_origins: list[str] = Field(default_factory=list)
    jwt_secret: SecretStr = SecretStr("local-development-secret-change-me")
    jwt_issuer: str = "snakecare-api"
    jwt_audience: str = "snakecare-clients"
    access_token_minutes: int = Field(default=15, ge=5, le=60)
    refresh_token_days: int = Field(default=30, ge=1, le=90)
    firebase_project_id: str | None = None
    firebase_credentials_path: str | None = None
    gemini_enabled: bool = False
    gemini_api_key: SecretStr | None = None
    gemini_model: str = "gemini-3.6-flash"
    gemini_tts_model: str = "gemini-3.1-flash-tts-preview"
    gemini_tts_voice: str = "Kore"
    gemini_timeout_seconds: float = Field(default=10.0, ge=2.0, le=30.0)
    gemini_tts_timeout_seconds: float = Field(default=30.0, ge=5.0, le=60.0)
    reverse_geocoding_enabled: bool = True
    reverse_geocoding_url: str = "https://nominatim.openstreetmap.org/reverse"
    reverse_geocoding_timeout_seconds: float = Field(default=4.0, ge=1.0, le=10.0)
    bootstrap_government_admin_emails: list[str] = Field(default_factory=list)
    report_storage_path: str = "./var/reports"
    report_max_upload_bytes: int = Field(default=10_485_760, ge=1_048_576, le=52_428_800)
    report_max_pdf_pages: int = Field(default=25, ge=1, le=100)
    snakebite_photo_storage_path: str = "./var/snakebite-photos"
    snakebite_photo_max_upload_bytes: int = Field(default=8_388_608, ge=1_048_576, le=20_971_520)

    @field_validator("database_url")
    @classmethod
    def require_async_driver(cls, value: str) -> str:
        # Managed PostgreSQL providers commonly expose a standard
        # ``postgresql://`` connection string. SQLAlchemy's async engine needs
        # the asyncpg driver explicitly, so normalize provider URLs here.
        if value.startswith("postgresql://"):
            value = value.replace("postgresql://", "postgresql+asyncpg://", 1)
        if not value.startswith(("postgresql+asyncpg://", "sqlite+aiosqlite://")):
            raise ValueError("database_url must use asyncpg (or aiosqlite in tests)")
        return value

    @field_validator("bootstrap_government_admin_emails")
    @classmethod
    def normalize_bootstrap_emails(cls, value: list[str]) -> list[str]:
        return sorted({email.strip().lower() for email in value if email.strip()})

    @model_validator(mode="after")
    def validate_production_secrets(self) -> Settings:
        if self.is_production:
            secret = self.jwt_secret.get_secret_value()
            known_defaults = {
                "local-development-secret-change-me",
                "change-me",
                "changeme",
                "secret",
            }
            if len(secret) < 32 or secret.strip().lower() in known_defaults:
                raise ValueError("production jwt_secret must contain at least 32 characters")
            if not self.firebase_project_id:
                raise ValueError("production requires firebase_project_id")
        return self

    @property
    def is_production(self) -> bool:
        return self.environment == "production"


@lru_cache
def get_settings() -> Settings:
    return Settings()
