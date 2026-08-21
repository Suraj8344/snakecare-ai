from __future__ import annotations

import base64
import binascii
import io
import logging
import wave
from dataclasses import dataclass

import httpx

from app.core.config import Settings

logger = logging.getLogger(__name__)

_SAMPLE_RATE_HZ = 24_000
_MAX_PCM_BYTES = 5_000_000


@dataclass(frozen=True)
class SynthesizedSpeech:
    wav_base64: str
    model: str


class GeminiSpeechSynthesizer:
    """Read an already-approved answer; never generate medical content."""

    def __init__(
        self,
        settings: Settings,
        transport: httpx.AsyncBaseTransport | None = None,
    ) -> None:
        self._enabled = settings.gemini_enabled
        self._api_key = (
            settings.gemini_api_key.get_secret_value()
            if settings.gemini_api_key is not None
            else None
        )
        self._model = settings.gemini_tts_model
        self._voice = settings.gemini_tts_voice
        self._timeout = settings.gemini_tts_timeout_seconds
        self._transport = transport

    @property
    def configured(self) -> bool:
        return self._enabled and bool(self._api_key)

    async def synthesize(self, approved_text: str) -> SynthesizedSpeech | None:
        if not self.configured or not approved_text.strip():
            return None

        prompt = (
            "Synthesize speech from the transcript below. Read exactly and only "
            "the transcript. Do not add, remove, paraphrase, or explain any words.\n\n"
            f"TRANSCRIPT:\n{approved_text.strip()}"
        )
        interactions_payload: dict[str, object] = {
            "model": self._model,
            "input": prompt,
            "response_format": {"type": "audio"},
            "generation_config": {
                "speech_config": [{"voice": self._voice}],
            },
        }
        generate_content_payload: dict[str, object] = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {
                "responseModalities": ["AUDIO"],
                "speechConfig": {
                    "voiceConfig": {
                        "prebuiltVoiceConfig": {"voiceName": self._voice},
                    }
                },
            },
            "model": self._model,
        }

        try:
            async with httpx.AsyncClient(
                timeout=self._timeout,
                transport=self._transport,
            ) as client:
                pcm = await self._request_interactions(
                    client,
                    interactions_payload,
                )
                if pcm is None:
                    pcm = await self._request_generate_content(
                        client,
                        generate_content_payload,
                    )
            if pcm is None:
                raise ValueError("Gemini returned no usable audio")
            wav = self._pcm_to_wav(pcm)
        except (
            httpx.HTTPError,
            KeyError,
            TypeError,
            ValueError,
            binascii.Error,
        ) as exc:
            logger.warning(
                "gemini_speech_synthesis_failed",
                extra={"model": self._model, "exception_type": type(exc).__name__},
            )
            return None

        return SynthesizedSpeech(
            wav_base64=base64.b64encode(wav).decode("ascii"),
            model=self._model,
        )

    async def _request_interactions(
        self,
        client: httpx.AsyncClient,
        payload: dict[str, object],
    ) -> bytes | None:
        url = "https://generativelanguage.googleapis.com/v1beta/interactions"
        try:
            response = await client.post(
                url,
                headers={"x-goog-api-key": self._api_key or ""},
                json=payload,
            )
            if response.status_code in {500, 502, 503, 504}:
                response = await client.post(
                    url,
                    headers={"x-goog-api-key": self._api_key or ""},
                    json=payload,
                )
            response.raise_for_status()
            return self._decode_pcm(response.json()["output_audio"]["data"])
        except httpx.HTTPStatusError as exc:
            logger.info(
                "gemini_interactions_tts_unavailable",
                extra={
                    "model": self._model,
                    "status_code": exc.response.status_code,
                },
            )
            return None
        except (httpx.HTTPError, KeyError, TypeError, ValueError, binascii.Error) as exc:
            logger.info(
                "gemini_interactions_tts_invalid_response",
                extra={
                    "model": self._model,
                    "exception_type": type(exc).__name__,
                },
            )
            return None

    async def _request_generate_content(
        self,
        client: httpx.AsyncClient,
        payload: dict[str, object],
    ) -> bytes | None:
        url = (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            f"{self._model}:generateContent"
        )
        try:
            response = await client.post(
                url,
                headers={"x-goog-api-key": self._api_key or ""},
                json=payload,
            )
            response.raise_for_status()
            encoded = response.json()["candidates"][0]["content"]["parts"][0][
                "inlineData"
            ]["data"]
            return self._decode_pcm(encoded)
        except httpx.HTTPStatusError as exc:
            logger.warning(
                "gemini_generate_content_tts_unavailable",
                extra={
                    "model": self._model,
                    "status_code": exc.response.status_code,
                },
            )
            return None
        except (
            httpx.HTTPError,
            KeyError,
            IndexError,
            TypeError,
            ValueError,
            binascii.Error,
        ) as exc:
            logger.warning(
                "gemini_generate_content_tts_invalid_response",
                extra={
                    "model": self._model,
                    "exception_type": type(exc).__name__,
                },
            )
            return None

    @staticmethod
    def _decode_pcm(encoded_pcm: str) -> bytes:
        pcm = base64.b64decode(encoded_pcm, validate=True)
        if not pcm or len(pcm) > _MAX_PCM_BYTES:
            raise ValueError("invalid Gemini audio length")
        return pcm

    @staticmethod
    def _pcm_to_wav(pcm: bytes) -> bytes:
        output = io.BytesIO()
        with wave.open(output, "wb") as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(_SAMPLE_RATE_HZ)
            wav_file.writeframes(pcm)
        return output.getvalue()
