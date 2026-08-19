from __future__ import annotations

import json
import logging
from dataclasses import dataclass

import httpx
from pydantic import BaseModel, Field, ValidationError

from app.core.config import Settings
from app.modules.emergency_handoff.domain import OperatorQuestion

logger = logging.getLogger(__name__)


class _IntentPayload(BaseModel):
    intent: OperatorQuestion
    confidence: float = Field(ge=0.0, le=1.0)


@dataclass(frozen=True)
class ClassifiedQuestion:
    question: OperatorQuestion
    confidence: float
    model: str


class GeminiIntentClassifier:
    """Classify a transcript without allowing a model to generate medical facts."""

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
        self._model = settings.gemini_model
        self._timeout = settings.gemini_timeout_seconds
        self._transport = transport

    @property
    def configured(self) -> bool:
        return self._enabled and bool(self._api_key)

    async def classify(self, transcript: str) -> ClassifiedQuestion:
        # Prefer deterministic recognition for clear emergency-fact phrases.
        # This prevents a remote model from rejecting harmless paraphrases
        # such as "tell me about the patient name" as conversational text.
        local_match = self._classify_locally(transcript)
        if local_match.question is not OperatorQuestion.OUT_OF_SCOPE:
            return local_match

        if not self.configured:
            return local_match

        allowed = [question.value for question in OperatorQuestion]
        payload = {
            "systemInstruction": {
                "parts": [
                    {
                        "text": (
                            "Classify a caller's question for an emergency handoff "
                            "rehearsal. Return exactly one allowed intent. Do not "
                            "answer the question, infer "
                            "a diagnosis, or add medical information. Recognize natural, "
                            "indirect, polite, and grammatically imperfect paraphrases of "
                            "the listed emergency facts. Use out_of_scope for product "
                            "questions, greetings, commands, opinions, or statements that "
                            "do not request a listed emergency fact. Never force an "
                            "out-of-scope statement into the closest emergency intent."
                        )
                    }
                ]
            },
            "contents": [
                {
                    "role": "user",
                    "parts": [{"text": transcript}],
                }
            ],
            "generationConfig": {
                "temperature": 0,
                "responseMimeType": "application/json",
                "responseSchema": {
                    "type": "OBJECT",
                    "properties": {
                        "intent": {"type": "STRING", "enum": allowed},
                        "confidence": {"type": "NUMBER"},
                    },
                    "required": ["intent", "confidence"],
                },
            },
        }
        url = (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            f"{self._model}:generateContent"
        )
        try:
            async with httpx.AsyncClient(
                timeout=self._timeout,
                transport=self._transport,
            ) as client:
                response = await client.post(
                    url,
                    headers={"x-goog-api-key": self._api_key or ""},
                    json=payload,
                )
            response.raise_for_status()
            body = response.json()
            raw_text = body["candidates"][0]["content"]["parts"][0]["text"]
            parsed = _IntentPayload.model_validate(json.loads(raw_text))
        except (
            httpx.HTTPError,
            KeyError,
            IndexError,
            TypeError,
            ValueError,
            ValidationError,
        ) as exc:
            logger.warning(
                "gemini_intent_classification_failed",
                extra={"model": self._model, "exception_type": type(exc).__name__},
            )
            return self._classify_locally(transcript)

        return ClassifiedQuestion(
            question=parsed.intent,
            confidence=parsed.confidence,
            model=self._model,
        )

    @staticmethod
    def _classify_locally(transcript: str) -> ClassifiedQuestion:
        """Keep the rehearsal available when the preview AI endpoint is unavailable."""
        text = " ".join(transcript.lower().split())
        rules: tuple[tuple[OperatorQuestion, tuple[str, ...]], ...] = (
            (
                OperatorQuestion.LOCATION,
                (
                    "where is",
                    "where are",
                    "location",
                    "address",
                    "nearest place",
                    "coordinates",
                    "where did it happen",
                    "where should",
                ),
            ),
            (
                OperatorQuestion.IDENTITY,
                (
                    "patient name",
                    "patient's name",
                    "name of patient",
                    "name of the patient",
                    "person's name",
                    "victim name",
                    "your name",
                    "tell me the name",
                    "who is the patient",
                    "identify the patient",
                    "patient identity",
                ),
            ),
            (
                OperatorQuestion.SYMPTOMS,
                (
                    "symptom",
                    "what happened",
                    "medical condition",
                    "current condition",
                    "how is the patient",
                    "how are they feeling",
                    "what are they feeling",
                ),
            ),
            (
                OperatorQuestion.INCIDENT_TIME,
                ("incident time", "when did", "when was", "bite time"),
            ),
            (
                OperatorQuestion.CONSCIOUSNESS,
                ("conscious", "awake", "responsive", "unconscious"),
            ),
            (
                OperatorQuestion.ALLERGIES,
                ("allergy", "allergies", "allergic", "reaction to"),
            ),
            (
                OperatorQuestion.MEDICINES,
                ("medicine", "medication", "drug", "tablets", "prescription"),
            ),
            (
                OperatorQuestion.CALLBACK,
                ("callback", "phone number", "contact number", "call back"),
            ),
            (
                OperatorQuestion.EMERGENCY_CONTACT,
                ("emergency contact", "family contact", "relative"),
            ),
            (
                OperatorQuestion.LANGUAGE,
                ("language", "speak which", "preferred language", "can they speak"),
            ),
        )
        for question, phrases in rules:
            if any(phrase in text for phrase in phrases):
                return ClassifiedQuestion(
                    question=question,
                    confidence=0.95,
                    model="local_safety_fallback",
                )
        return ClassifiedQuestion(
            question=OperatorQuestion.OUT_OF_SCOPE,
            confidence=0.99,
            model="local_safety_fallback",
        )
