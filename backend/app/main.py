from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.router import api_router
from app.core.config import Settings, get_settings
from app.core.errors import register_exception_handlers
from app.core.logging import configure_logging
from app.core.middleware import register_middleware
from app.infrastructure.database.session import Database
from app.modules.auth.firebase import FirebaseIdentityVerifier
from app.modules.auth.tokens import TokenService


def create_app(settings: Settings | None = None) -> FastAPI:
    resolved = settings or get_settings()
    configure_logging(resolved.log_level)

    @asynccontextmanager
    async def lifespan(app: FastAPI):  # type: ignore[no-untyped-def]
        app.state.database = Database(resolved.database_url)
        app.state.settings = resolved
        app.state.identity_verifier = FirebaseIdentityVerifier(
            project_id=resolved.firebase_project_id,
            credentials_path=resolved.firebase_credentials_path,
        )
        app.state.token_service = TokenService(
            secret=resolved.jwt_secret.get_secret_value(),
            issuer=resolved.jwt_issuer,
            audience=resolved.jwt_audience,
            access_minutes=resolved.access_token_minutes,
            refresh_days=resolved.refresh_token_days,
        )
        app.state.bootstrap_admin_emails = set(resolved.bootstrap_government_admin_emails)
        yield
        await app.state.database.dispose()

    app = FastAPI(
        title=resolved.app_name,
        version="0.1.0",
        description=(
            "Secure SnakeCare foundation with patient-owned medical data; "
            "no diagnostic or treatment API is active."
        ),
        docs_url="/docs" if not resolved.is_production else None,
        redoc_url="/redoc" if not resolved.is_production else None,
        lifespan=lifespan,
    )
    register_middleware(app)
    if resolved.cors_origins:
        # Add CORS last so it wraps request-context middleware as well. This
        # keeps CORS headers on unexpected error responses and prevents the
        # browser from hiding the real backend error behind a CORS message.
        app.add_middleware(
            CORSMiddleware,
            allow_origins=resolved.cors_origins,
            allow_credentials=True,
            allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
            allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
        )
    register_exception_handlers(app)
    app.include_router(api_router, prefix=resolved.api_v1_prefix)
    return app


app = create_app()
