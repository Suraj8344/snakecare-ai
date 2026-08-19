from httpx import AsyncClient


async def test_health_is_public_and_returns_version(client: AsyncClient) -> None:
    response = await client.get("/api/v1/health", headers={"X-Request-ID": "test-request"})
    assert response.status_code == 200
    assert response.json() == {
        "service": "snakecare-api",
        "status": "ok",
        "version": "0.1.0",
    }
    assert response.headers["X-Request-ID"] == "test-request"
