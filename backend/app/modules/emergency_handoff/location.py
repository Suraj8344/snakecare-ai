from __future__ import annotations

import logging

import httpx

from app.core.config import Settings

logger = logging.getLogger(__name__)


class NearestPlaceResolver:
    """Best-effort reverse geocoding; coordinates remain the source of truth."""

    def __init__(
        self,
        settings: Settings,
        transport: httpx.AsyncBaseTransport | None = None,
    ) -> None:
        self._enabled = settings.reverse_geocoding_enabled
        self._url = settings.reverse_geocoding_url
        self._timeout = settings.reverse_geocoding_timeout_seconds
        self._transport = transport

    async def resolve(self, latitude: float, longitude: float) -> str | None:
        if not self._enabled:
            return None
        try:
            async with httpx.AsyncClient(
                timeout=self._timeout,
                transport=self._transport,
            ) as client:
                response = await client.get(
                    self._url,
                    params={
                        "lat": latitude,
                        "lon": longitude,
                        "format": "jsonv2",
                        "zoom": 18,
                        "addressdetails": 1,
                    },
                    headers={
                        "Accept-Language": "en",
                        "User-Agent": "SnakeCareAI/0.1 emergency-handoff",
                    },
                )
            response.raise_for_status()
            label = response.json().get("display_name")
            if not isinstance(label, str) or not label.strip():
                return None
            return label.strip()[:300]
        except (httpx.HTTPError, TypeError, ValueError) as exc:
            logger.info(
                "reverse_geocoding_unavailable",
                extra={"exception_type": type(exc).__name__},
            )
            return None
