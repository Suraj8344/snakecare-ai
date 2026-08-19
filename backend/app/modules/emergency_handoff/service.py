from copy import deepcopy
from datetime import UTC, datetime
from uuid import UUID

from app.modules.auth.models import User
from app.modules.emergency_handoff.domain import (
    EmergencyNotFoundError,
    HandoffConflictError,
    HandoffNotFoundError,
    HandoffStatus,
    OperatorQuestion,
    ResponseStatus,
)
from app.modules.emergency_handoff.gemini import GeminiIntentClassifier
from app.modules.emergency_handoff.gemini_tts import GeminiSpeechSynthesizer
from app.modules.emergency_handoff.location import NearestPlaceResolver
from app.modules.emergency_handoff.models import EmergencyHandoff, EmergencyHandoffEvent
from app.modules.emergency_handoff.repository import SqlAlchemyEmergencyHandoffRepository
from app.modules.emergency_handoff.schemas import (
    HandoffCreate,
    SimulatedAnswer,
    SimulatedQuestion,
    VoiceAssistantAnswer,
    VoiceAssistantQuestion,
)
from app.modules.emergency_handoff.summary import (
    answer_operator_question,
    build_structured_summary,
)


class EmergencyHandoffService:
    def __init__(
        self,
        repository: SqlAlchemyEmergencyHandoffRepository,
        intent_classifier: GeminiIntentClassifier,
        speech_synthesizer: GeminiSpeechSynthesizer,
        place_resolver: NearestPlaceResolver,
    ) -> None:
        self.repository = repository
        self.intent_classifier = intent_classifier
        self.speech_synthesizer = speech_synthesizer
        self.place_resolver = place_resolver

    async def create(self, user: User, payload: HandoffCreate) -> EmergencyHandoff:
        emergency = await self.repository.get_emergency_owned(payload.emergency_id, user.id)
        if emergency is None:
            raise EmergencyNotFoundError
        passport = await self.repository.get_passport(user.id)
        structured_summary = build_structured_summary(user, emergency, passport)
        location = structured_summary["emergency"]["location"]
        if (
            payload.consent_location
            and not location["missing"]
            and not location["value"].get("label")
        ):
            location["value"]["label"] = await self.place_resolver.resolve(
                emergency.latitude,
                emergency.longitude,
            )
            if location["value"]["label"]:
                location["source"] = "patient_location_plus_openstreetmap_nearest_place"
        handoff = EmergencyHandoff(
            owner_user_id=user.id,
            emergency_id=emergency.id,
            simulation_only=True,
            status=HandoffStatus.PREPARED.value,
            response_status=ResponseStatus.UNKNOWN.value,
            countdown_seconds=payload.countdown_seconds,
            consent_identity=payload.consent_identity,
            consent_location=payload.consent_location,
            consent_emergency_summary=payload.consent_emergency_summary,
            consent_medical_passport=payload.consent_medical_passport,
            consent_voice_assistance=payload.consent_voice_assistance,
            structured_summary=structured_summary,
        )
        self.repository.add(handoff)
        handoff.events.append(
            EmergencyHandoffEvent(
                actor_user_id=user.id,
                event_type="handoff_prepared",
                outcome="success",
                safe_details={
                    "simulation_only": True,
                    "countdown_seconds": payload.countdown_seconds,
                },
                message="Consent captured; no external service contacted.",
            )
        )
        await self.repository.commit()
        await self.repository.refresh(handoff)
        return handoff

    async def list(self, user: User) -> tuple[list[EmergencyHandoff], int]:
        return await self.repository.list_owned(user.id)

    async def get(self, user: User, handoff_id: UUID) -> EmergencyHandoff:
        handoff = await self.repository.get_owned(handoff_id, user.id)
        if handoff is None:
            raise HandoffNotFoundError
        return handoff

    async def start_countdown(self, user: User, handoff_id: UUID) -> EmergencyHandoff:
        handoff = await self.get(user, handoff_id)
        # Treat retries as successful. This prevents a rapid double-click or a
        # lost HTTP response from turning a successfully started countdown into
        # a confusing 409 on the next request.
        if handoff.status == HandoffStatus.COUNTDOWN_ACTIVE.value:
            return handoff
        # MANUAL_CALL_REQUESTED is retained for rows created before manual call
        # intent became an audit-only event. Those handoffs remain eligible for
        # the local rehearsal.
        if handoff.status not in {
            HandoffStatus.PREPARED.value,
            HandoffStatus.MANUAL_CALL_REQUESTED.value,
        }:
            raise HandoffConflictError
        handoff.status = HandoffStatus.COUNTDOWN_ACTIVE.value
        handoff.response_status = ResponseStatus.CONFIRMED.value
        handoff.countdown_started_at = datetime.now(UTC)
        self._event(
            handoff,
            user,
            "countdown_started",
            {"seconds": handoff.countdown_seconds},
        )
        return await self._save(handoff)

    async def record_no_response(self, user: User, handoff_id: UUID) -> EmergencyHandoff:
        handoff = await self.get(user, handoff_id)
        if handoff.status == HandoffStatus.SIMULATION_ACTIVE.value:
            return handoff
        if handoff.status != HandoffStatus.COUNTDOWN_ACTIVE.value:
            raise HandoffConflictError
        handoff.status = HandoffStatus.SIMULATION_ACTIVE.value
        handoff.response_status = ResponseStatus.NO_RESPONSE.value
        self._event(
            handoff,
            user,
            "no_response_recorded",
            {"consciousness_inference": "unknown", "automatic_call": False},
            "No response is not evidence of unconsciousness.",
        )
        return await self._save(handoff)

    async def cancel(self, user: User, handoff_id: UUID) -> EmergencyHandoff:
        handoff = await self.get(user, handoff_id)
        if handoff.status not in {
            HandoffStatus.PREPARED.value,
            HandoffStatus.COUNTDOWN_ACTIVE.value,
            HandoffStatus.MANUAL_CALL_REQUESTED.value,
        }:
            raise HandoffConflictError
        handoff.status = HandoffStatus.CANCELLED.value
        handoff.cancelled_at = datetime.now(UTC)
        self._event(handoff, user, "handoff_cancelled", {"external_contact": False})
        return await self._save(handoff)

    async def record_manual_call_intent(
        self, user: User, handoff_id: UUID
    ) -> EmergencyHandoff:
        handoff = await self.get(user, handoff_id)
        if handoff.status == HandoffStatus.CANCELLED.value:
            raise HandoffConflictError
        # Opening the human-controlled dialler is independent of the rehearsal
        # state machine. Record it for audit without blocking countdown,
        # cancellation, or simulation actions.
        handoff.manual_call_requested_at = datetime.now(UTC)
        self._event(
            handoff,
            user,
            "manual_call_intent",
            {"number": "112", "automatic_call": False, "erss_transmission": False},
            "SnakeCare recorded intent only; the device dialler remains human-controlled.",
        )
        return await self._save(handoff)

    async def simulate(
        self, user: User, handoff_id: UUID, payload: SimulatedQuestion
    ) -> SimulatedAnswer:
        handoff = await self.get(user, handoff_id)
        if handoff.status in {HandoffStatus.CANCELLED.value, HandoffStatus.PREPARED.value}:
            raise HandoffConflictError
        if payload.question is OperatorQuestion.LOCATION:
            await self._ensure_location_label(handoff)
        answer = answer_operator_question(handoff.structured_summary, payload.question)
        handoff.status = HandoffStatus.SIMULATION_ACTIVE.value
        self._event(
            handoff,
            user,
            "operator_question_simulated",
            {
                "question": payload.question.value,
                "source": answer.source,
                "missing": answer.missing,
                "external_contact": False,
            },
            answer.answer,
        )
        await self._save(handoff)
        return answer

    async def voice_assistant(
        self,
        user: User,
        handoff_id: UUID,
        payload: VoiceAssistantQuestion,
    ) -> VoiceAssistantAnswer:
        handoff = await self.get(user, handoff_id)
        if handoff.status in {HandoffStatus.CANCELLED.value, HandoffStatus.PREPARED.value}:
            raise HandoffConflictError
        if not handoff.consent_voice_assistance:
            raise HandoffConflictError

        classified = await self.intent_classifier.classify(payload.transcript)
        if (
            classified.question is OperatorQuestion.OUT_OF_SCOPE
            or classified.confidence < 0.6
        ):
            deterministic = SimulatedAnswer(
                question=classified.question,
                answer=(
                    "That question is outside this emergency handoff assistant's scope. "
                    "Please ask a direct question about the patient's identity, location, "
                    "reported symptoms, incident time, consciousness, allergies, medicines, "
                    "callback number, emergency contact, or language."
                ),
                source="voice_assistant_policy",
                missing=True,
            )
        else:
            if classified.question is OperatorQuestion.LOCATION:
                await self._ensure_location_label(handoff)
            deterministic = answer_operator_question(
                handoff.structured_summary,
                classified.question,
            )
        speech_audio = await self.speech_synthesizer.synthesize(deterministic.answer)
        answer = VoiceAssistantAnswer(
            question=deterministic.question,
            answer=deterministic.answer,
            source=deterministic.source,
            missing=deterministic.missing,
            confidence=classified.confidence,
            model=classified.model,
            audio_base64=speech_audio.wav_base64 if speech_audio else None,
            audio_mime_type="audio/wav" if speech_audio else None,
            audio_model=speech_audio.model if speech_audio else None,
        )
        handoff.status = HandoffStatus.SIMULATION_ACTIVE.value
        self._event(
            handoff,
            user,
            "gemini_intent_classified",
            {
                "question": classified.question.value,
                "confidence": round(classified.confidence, 3),
                "model": classified.model,
                "raw_transcript_stored": False,
                "answer_generated_by_ai": False,
                "speech_audio_generated": speech_audio is not None,
                "external_contact": False,
            },
            "Gemini classified the question; SnakeCare produced a source-bound answer.",
        )
        await self._save(handoff)
        return answer

    async def _ensure_location_label(self, handoff: EmergencyHandoff) -> None:
        """Best-effort enrichment for handoffs created before labels were stored."""
        if not handoff.consent_location:
            return
        location = handoff.structured_summary.get("emergency", {}).get("location", {})
        value = location.get("value")
        if not isinstance(value, dict) or value.get("label"):
            return
        latitude = value.get("latitude")
        longitude = value.get("longitude")
        if not isinstance(latitude, (int, float)) or not isinstance(
            longitude, (int, float)
        ):
            return
        label = await self.place_resolver.resolve(float(latitude), float(longitude))
        if not label:
            return

        # JSON columns do not reliably detect nested in-place changes. Assign a
        # copied document so SQLAlchemy persists the enrichment for later calls.
        summary = deepcopy(handoff.structured_summary)
        summary_location = summary["emergency"]["location"]
        summary_location["value"]["label"] = label
        summary_location["source"] = (
            "patient_location_plus_openstreetmap_nearest_place"
        )
        handoff.structured_summary = summary

    def _event(
        self,
        handoff: EmergencyHandoff,
        user: User,
        event_type: str,
        details: dict[str, object],
        message: str | None = None,
    ) -> None:
        handoff.events.append(
            EmergencyHandoffEvent(
                actor_user_id=user.id,
                event_type=event_type,
                outcome="success",
                safe_details=details,
                message=message,
            )
        )

    async def _save(self, handoff: EmergencyHandoff) -> EmergencyHandoff:
        await self.repository.commit()
        await self.repository.refresh(handoff)
        return handoff
