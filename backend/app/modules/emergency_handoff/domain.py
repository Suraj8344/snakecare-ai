from enum import StrEnum


class HandoffStatus(StrEnum):
    PREPARED = "prepared"
    COUNTDOWN_ACTIVE = "countdown_active"
    CANCELLED = "cancelled"
    MANUAL_CALL_REQUESTED = "manual_call_requested"
    SIMULATION_ACTIVE = "simulation_active"


class ResponseStatus(StrEnum):
    UNKNOWN = "unknown"
    CONFIRMED = "confirmed"
    NO_RESPONSE = "no_response"


class OperatorQuestion(StrEnum):
    OUT_OF_SCOPE = "out_of_scope"
    IDENTITY = "identity"
    LOCATION = "location"
    SYMPTOMS = "symptoms"
    INCIDENT_TIME = "incident_time"
    CONSCIOUSNESS = "consciousness"
    ALLERGIES = "allergies"
    MEDICINES = "medicines"
    CALLBACK = "callback"
    EMERGENCY_CONTACT = "emergency_contact"
    LANGUAGE = "language"


class HandoffError(Exception):
    status_code = 400
    title = "Emergency handoff error"
    detail = "The emergency handoff request could not be completed."


class HandoffNotFoundError(HandoffError):
    status_code = 404
    title = "Emergency handoff not found"
    detail = "The requested emergency handoff was not found."


class EmergencyNotFoundError(HandoffError):
    status_code = 404
    title = "Emergency not found"
    detail = "The selected emergency does not belong to this account."


class HandoffConflictError(HandoffError):
    status_code = 409
    title = "Emergency handoff conflict"
    detail = "This action is not allowed in the current handoff state."


class HandoffConsentError(HandoffError):
    status_code = 422
    title = "Explicit consent required"
    detail = "All simulation disclosures must be explicitly accepted."


class VoiceAssistantUnavailableError(HandoffError):
    status_code = 503
    title = "Voice assistant unavailable"
    detail = (
        "The Gemini rehearsal assistant is unavailable. Use the allow-listed "
        "question selector or speak directly with the human emergency operator."
    )
