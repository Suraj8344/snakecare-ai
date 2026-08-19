import base64
import json

import httpx
import pytest
from pydantic import SecretStr

from app.core.config import Settings
from app.modules.emergency_handoff.gemini_tts import GeminiSpeechSynthesizer


def synthesizer(handler: httpx.MockTransport) -> GeminiSpeechSynthesizer:
    settings = Settings(
        environment="test",
        database_url="sqlite+aiosqlite:///:memory:",
        gemini_enabled=True,
        gemini_api_key=SecretStr("test-key"),
        gemini_tts_model="gemini-tts-test",
        gemini_tts_voice="Kore",
    )
    return GeminiSpeechSynthesizer(settings, transport=handler)


@pytest.mark.asyncio
async def test_wraps_gemini_pcm_as_browser_playable_wav() -> None:
    pcm = b"\x00\x00\x01\x00"

    def respond(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/v1beta/interactions"
        assert request.headers["x-goog-api-key"] == "test-key"
        body = json.loads(request.content)
        assert body["model"] == "gemini-tts-test"
        assert body["generation_config"]["speech_config"][0]["voice"] == "Kore"
        assert "Do not add, remove, paraphrase" in body["input"]
        assert "Verified answer" in body["input"]
        return httpx.Response(
            200,
            json={"output_audio": {"data": base64.b64encode(pcm).decode()}},
        )

    result = await synthesizer(httpx.MockTransport(respond)).synthesize(
        "Verified answer"
    )

    assert result is not None
    wav = base64.b64decode(result.wav_base64)
    assert wav.startswith(b"RIFF")
    assert wav[8:12] == b"WAVE"
    assert wav.endswith(pcm)


@pytest.mark.asyncio
async def test_returns_none_when_audio_service_is_unavailable() -> None:
    transport = httpx.MockTransport(lambda _: httpx.Response(400, json={}))
    result = await synthesizer(transport).synthesize("Verified answer")
    assert result is None


@pytest.mark.asyncio
async def test_falls_back_to_generate_content_audio() -> None:
    pcm = b"\x00\x00\x02\x00"

    def respond(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/v1beta/interactions":
            return httpx.Response(404, json={})
        assert request.url.path.endswith("gemini-tts-test:generateContent")
        body = json.loads(request.content)
        config = body["generationConfig"]
        assert config["responseModalities"] == ["AUDIO"]
        assert (
            config["speechConfig"]["voiceConfig"]["prebuiltVoiceConfig"][
                "voiceName"
            ]
            == "Kore"
        )
        return httpx.Response(
            200,
            json={
                "candidates": [
                    {
                        "content": {
                            "parts": [
                                {
                                    "inlineData": {
                                        "data": base64.b64encode(pcm).decode()
                                    }
                                }
                            ]
                        }
                    }
                ]
            },
        )

    result = await synthesizer(httpx.MockTransport(respond)).synthesize(
        "Verified answer"
    )

    assert result is not None
    assert base64.b64decode(result.wav_base64).endswith(pcm)
