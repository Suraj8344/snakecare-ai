from __future__ import annotations

import logging
import time
from collections.abc import Awaitable, Callable
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from starlette.responses import Response

logger = logging.getLogger(__name__)


def register_middleware(app: FastAPI) -> None:
    @app.middleware("http")
    async def request_context(
        request: Request, call_next: Callable[[Request], Awaitable[Response]]
    ) -> Response:
        request_id = request.headers.get("X-Request-ID", str(uuid4()))[:128]
        request.state.request_id = request_id
        started = time.perf_counter()
        try:
            response = await call_next(request)
        except Exception as exc:
            # This middleware sits inside CORSMiddleware. Converting an
            # unexpected exception here ensures the response still travels
            # through CORS, so browsers receive the real 500 instead of a
            # misleading "No Access-Control-Allow-Origin" network error.
            logger.exception(
                "unexpected_request_failure",
                extra={
                    "request_id": request_id,
                    "method": request.method,
                    "path": request.url.path,
                    "exception_type": type(exc).__name__,
                },
            )
            response = JSONResponse(
                {
                    "type": "about:blank",
                    "title": "Internal server error",
                    "status": 500,
                    "detail": "The server could not complete the request. Please try again.",
                    "instance": request.url.path,
                    "request_id": request_id,
                },
                status_code=500,
                media_type="application/problem+json",
            )
        response.headers["X-Request-ID"] = request_id
        logger.info(
            "request_completed",
            extra={
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "status_code": response.status_code,
                "duration_ms": round((time.perf_counter() - started) * 1000, 2),
            },
        )
        return response
