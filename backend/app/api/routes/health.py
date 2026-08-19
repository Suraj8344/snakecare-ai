from fastapi import APIRouter, HTTPException, status
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.api.dependencies import DatabaseSession
from app.api.schemas import ServiceStatus

router = APIRouter()


@router.get("/health", response_model=ServiceStatus, summary="Process liveness")
async def health() -> ServiceStatus:
    return ServiceStatus(service="snakecare-api", status="ok", version="0.1.0")


@router.get("/ready", response_model=ServiceStatus, summary="Dependency readiness")
async def ready(session: DatabaseSession) -> ServiceStatus:
    try:
        await session.execute(text("SELECT 1"))
    except SQLAlchemyError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database is not ready",
        ) from exc
    return ServiceStatus(service="snakecare-api", status="ready", version="0.1.0")
