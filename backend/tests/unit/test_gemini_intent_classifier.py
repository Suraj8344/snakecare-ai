import json

import httpx
import pytest
from pydantic import SecretStr

from app.core.config import Settings
from app.modules.emergency_handoff.domain import OperatorQuestion
from app.modules.emergency_handoff.gemini import GeminiIntentClassifier


def classifier(handler: httpx.MockTransport) -> GeminiIntentClassifier:
    settings = Settings(
        environment="test",
        database_url="sqlite+aiosqlite:///:memory:",
        gemini_enabled=True,
        gemini_api_key=SecretStr("test-key"),
        gemini_model="gemini-test",
    )
    return GeminiIntentClassifier(settings, transport=handler)


@pytest.mark.asyncio
async def test_classifies_only_an_allow_list_intent() -> None:
    def respond(request: httpx.Request) -> httpx.Response:
        assert request.headers["x-goog-api-key"] == "test-key"
        request_body = json.loads(request.content)
        assert "responseSchema" in request_body["generationConfig"]
        return httpx.Response(
            200,
            json={
                "candidates": [
                    {
                        "content": {
                            "parts": [
                                {"text": '{"intent":"location","confidence":0.94}'}
                            ]
                        }
                    }
                ]
            },
        )

    result = await classifier(httpx.MockTransport(respond)).classify(
        "Provide the rendezvous point for the response team."
    )
    assert result.question is OperatorQuestion.LOCATION
    assert result.confidence == 0.94


@pytest.mark.asyncio
async def test_uses_safe_local_fallback_for_invalid_model_response() -> None:
    transport = httpx.MockTransport(
        lambda _: httpx.Response(
            200,
            json={
                "candidates": [
                    {"content": {"parts": [{"text": '{"intent":"diagnose"}'}]}}
                ]
            },
        )
    )
    result = await classifier(transport).classify("What treatment should I give?")
    assert result.question is OperatorQuestion.OUT_OF_SCOPE
    assert result.model == "local_safety_fallback"


@pytest.mark.asyncio
async def test_local_fallback_recognizes_patient_location() -> None:
    transport = httpx.MockTransport(lambda _: httpx.Response(429, json={}))
    result = await classifier(transport).classify(
        "What is the nearest place and coordinates?"
    )
    assert result.question is OperatorQuestion.LOCATION
    assert result.model == "local_safety_fallback"


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "transcript",
    [
        "Tell me about the patient name",
        "Could you please tell me the name of the patient?",
        "Hey, what is your name?",
        "Identify the patient for me",
    ],
)
async def test_clear_identity_paraphrases_use_deterministic_match(
    transcript: str,
) -> None:
    def remote_should_not_be_called(_: httpx.Request) -> httpx.Response:
        raise AssertionError("clear patient identity phrases must be handled locally")

    result = await classifier(
        httpx.MockTransport(remote_should_not_be_called)
    ).classify(transcript)

    assert result.question is OperatorQuestion.IDENTITY
    assert result.confidence == 0.95
    assert result.model == "local_safety_fallback"


@pytest.mark.asyncio
async def test_classifies_product_questions_as_out_of_scope() -> None:
    transport = httpx.MockTransport(
        lambda _: httpx.Response(
            200,
            json={
                "candidates": [
                    {
                        "content": {
                            "parts": [
                                {
                                    "text": (
                                        '{"intent":"out_of_scope",'
                                        '"confidence":0.98}'
                                    )
                                }
                            ]
                        }
                    }
                ]
            },
        )
    )
    result = await classifier(transport).classify("Does this app really work?")
    assert result.question is OperatorQuestion.OUT_OF_SCOPE
    assert result.confidence == 0.98
