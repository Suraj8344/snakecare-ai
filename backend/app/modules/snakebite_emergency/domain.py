from enum import StrEnum


class Symptom(StrEnum):
    BREATHING_DIFFICULTY = "breathing_difficulty"
    DROOPING_EYELIDS = "drooping_eyelids"
    BLURRED_OR_DOUBLE_VISION = "blurred_or_double_vision"
    DIFFICULTY_SPEAKING_OR_SWALLOWING = "difficulty_speaking_or_swallowing"
    WEAKNESS_OR_PARALYSIS = "weakness_or_paralysis"
    DROWSINESS_OR_CONFUSION = "drowsiness_or_confusion"
    COLLAPSE_OR_SEIZURE = "collapse_or_seizure"
    SPONTANEOUS_BLEEDING = "spontaneous_bleeding"
    RAPIDLY_SPREADING_SWELLING = "rapidly_spreading_swelling"
    SEVERE_LOCAL_PAIN = "severe_local_pain"
    REPEATED_VOMITING = "repeated_vomiting"
    DARK_URINE = "dark_urine"
    REDUCED_URINE = "reduced_urine"
    ABDOMINAL_PAIN = "abdominal_pain"
    NONE_OBSERVED = "none_observed"


class BiteSite(StrEnum):
    HAND = "hand"
    ARM = "arm"
    FOOT = "foot"
    LEG = "leg"
    HEAD_OR_NECK = "head_or_neck"
    TORSO = "torso"
    UNKNOWN = "unknown"


class Consciousness(StrEnum):
    ALERT = "alert"
    RESPONDS_TO_VOICE = "responds_to_voice"
    RESPONDS_TO_PAIN = "responds_to_pain"
    UNRESPONSIVE = "unresponsive"


class Urgency(StrEnum):
    CRITICAL = "critical"
    HIGH_RISK = "high_risk"
    URGENT_ASSESSMENT = "urgent_assessment"


class EmergencyError(Exception):
    status_code = 400
    title = "Snakebite emergency request failed"
    detail = "The snakebite emergency request could not be completed."


class InvalidEmergencyPhoto(EmergencyError):
    status_code = 415
    title = "Invalid emergency photo"
    detail = "Upload one PNG or JPEG image no larger than the configured limit."


class EmergencyNotFound(EmergencyError):
    status_code = 404
    title = "Emergency case not found"
    detail = "The emergency case was not found or is not available to this account."


class EmergencyStorageFailure(EmergencyError):
    status_code = 503
    title = "Emergency photo storage unavailable"
    detail = "The private photo store is temporarily unavailable."
