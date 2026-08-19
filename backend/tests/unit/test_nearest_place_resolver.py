import httpx
import pytest

from app.core.config import Settings
from app.modules.emergency_handoff.location import NearestPlaceResolver


def resolver(transport: httpx.MockTransport) -> NearestPlaceResolver:
    settings = Settings(
        environment="test",
        database_url="sqlite+aiosqlite:///:memory:",
        reverse_geocoding_enabled=True,
    )
    return NearestPlaceResolver(settings, transport=transport)


@pytest.mark.asyncio
async def test_resolves_nearest_place_without_changing_coordinates() -> None:
    def respond(request: httpx.Request) -> httpx.Response:
        assert request.url.params["lat"] == "18.5204"
        assert request.url.params["lon"] == "73.8567"
        return httpx.Response(200, json={"display_name": "Shaniwar Wada, Pune"})

    label = await resolver(httpx.MockTransport(respond)).resolve(18.5204, 73.8567)
    assert label == "Shaniwar Wada, Pune"


@pytest.mark.asyncio
async def test_returns_none_when_reverse_geocoder_is_unavailable() -> None:
    transport = httpx.MockTransport(lambda _: httpx.Response(503, json={}))
    assert await resolver(transport).resolve(18.5204, 73.8567) is None
