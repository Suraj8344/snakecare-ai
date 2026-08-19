from __future__ import annotations

from collections.abc import Sequence
from typing import Any

from fastapi import FastAPI, Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.modules.auth.domain import AuthError
from app.modules.emergency_handoff.domain import HandoffError
from app.modules.hospital_coordination.domain import CoordinationError
from app.modules.hospital_dashboard.domain import HospitalDashboardError
from app.modules.medical_passport.domain import PassportError
from app.modules.medical_reports.domain import ReportError
from app.modules.snakebite_emergency.domain import EmergencyError


def problem_response(
    request: Request,
    *,
    status: int,
    title: str,
    detail: str,
    errors: Sequence[Any] | None = None,
) -> JSONResponse:
    body: dict[str, Any] = {
        "type": "about:blank",
        "title": title,
        "status": status,
        "detail": detail,
        "instance": str(request.url.path),
        "request_id": getattr(request.state, "request_id", None),
    }
    if errors is not None:
        body["errors"] = errors
    return JSONResponse(body, status_code=status, media_type="application/problem+json")


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AuthError)
    async def auth_handler(request: Request, exc: AuthError) -> JSONResponse:
        return problem_response(
            request,
            status=exc.status_code,
            title=exc.title,
            detail="The request could not be authorized.",
        )

    @app.exception_handler(RequestValidationError)
    async def validation_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
        return problem_response(
            request,
            status=422,
            title="Validation error",
            detail="The request did not satisfy the API contract.",
            errors=jsonable_encoder(
                exc.errors(),
                custom_encoder={ValueError: str},
            ),
        )

    @app.exception_handler(PassportError)
    async def passport_handler(request: Request, exc: PassportError) -> JSONResponse:
        return problem_response(
            request,
            status=exc.status_code,
            title=exc.title,
            detail=exc.detail,
        )

    @app.exception_handler(ReportError)
    async def report_handler(request: Request, exc: ReportError) -> JSONResponse:
        return problem_response(
            request,
            status=exc.status_code,
            title=exc.title,
            detail=exc.detail,
        )

    @app.exception_handler(EmergencyError)
    async def emergency_handler(request: Request, exc: EmergencyError) -> JSONResponse:
        return problem_response(
            request,
            status=exc.status_code,
            title=exc.title,
            detail=exc.detail,
        )

    @app.exception_handler(HandoffError)
    async def handoff_handler(request: Request, exc: HandoffError) -> JSONResponse:
        return problem_response(
            request,
            status=exc.status_code,
            title=exc.title,
            detail=exc.detail,
        )

    @app.exception_handler(CoordinationError)
    async def coordination_handler(request: Request, exc: CoordinationError) -> JSONResponse:
        return problem_response(
            request,
            status=exc.status_code,
            title=exc.title,
            detail=exc.detail,
        )

    @app.exception_handler(HospitalDashboardError)
    async def hospital_dashboard_handler(
        request: Request, exc: HospitalDashboardError
    ) -> JSONResponse:
        return problem_response(
            request,
            status=exc.status_code,
            title=exc.title,
            detail=exc.detail,
        )
