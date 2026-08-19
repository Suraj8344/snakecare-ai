from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

from app.modules.auth.models import User
from app.modules.emergency_handoff.domain import OperatorQuestion
from app.modules.emergency_handoff.schemas import SimulatedAnswer
from app.modules.medical_passport.models import MedicalPassport
from app.modules.snakebite_emergency.models import SnakebiteEmergency


def _field(value: Any, source: str) -> dict[str, Any]:
    missing = value is None or value == "" or value == []
    return {"value": None if missing else value, "source": source, "missing": missing}


def build_structured_summary(
    user: User,
    emergency: SnakebiteEmergency,
    passport: MedicalPassport | None,
) -> dict[str, Any]:
    identity = {
        "name": _field(
            passport.full_name if passport and passport.full_name else user.display_name,
            "verified_identity_or_patient_passport",
        ),
        "email": _field(user.email, "verified_identity"),
        "callback": _field(user.phone_number, "verified_identity"),
    }
    location_value = None
    if emergency.latitude is not None and emergency.longitude is not None:
        location_value = {
            "latitude": emergency.latitude,
            "longitude": emergency.longitude,
            "accuracy_m": emergency.location_accuracy_m,
            "label": emergency.location_label,
        }
    emergency_summary = {
        "urgency": _field(emergency.urgency, "snakecare_ruleset_output"),
        "symptoms": _field(emergency.symptoms, "patient_reported_emergency"),
        "occurred_at": _field(
            emergency.occurred_at.isoformat() if emergency.occurred_at else None,
            "patient_reported_emergency",
        ),
        "consciousness": _field(emergency.consciousness, "patient_reported_emergency"),
        "location": _field(location_value, "patient_reported_emergency"),
    }
    passport_summary = {
        "blood_group": _field(passport.blood_group if passport else None, "patient_passport"),
        "preferred_language": _field(
            passport.preferred_language if passport else None, "patient_passport"
        ),
        "allergies": _field(
            [item.allergen for item in passport.allergies] if passport else None,
            "patient_passport",
        ),
        "medicines": _field(
            [item.name for item in passport.medications] if passport else None,
            "patient_passport",
        ),
        "conditions": _field(
            [item.name for item in passport.conditions if item.status == "active"]
            if passport
            else None,
            "patient_passport",
        ),
        "emergency_contact": _field(
            {
                "name": passport.emergency_contacts[0].name,
                "phone": passport.emergency_contacts[0].phone_number,
            }
            if passport and passport.emergency_contacts
            else None,
            "patient_passport",
        ),
    }
    return {
        "prepared_at": datetime.now(UTC).isoformat(),
        "simulation_only": True,
        "identity": identity,
        "emergency": emergency_summary,
        "medical_passport": passport_summary,
        "disclosure_notice": (
            "Patient-consented simulation snapshot. No data was sent to 112 or ERSS."
        ),
    }


def answer_operator_question(
    summary: dict[str, Any], question: OperatorQuestion
) -> SimulatedAnswer:
    identity = summary["identity"]
    emergency = summary["emergency"]
    passport = summary["medical_passport"]
    mapping: dict[OperatorQuestion, tuple[dict[str, Any], str]] = {
        OperatorQuestion.IDENTITY: (identity["name"], "Patient name"),
        OperatorQuestion.LOCATION: (emergency["location"], "Emergency location"),
        OperatorQuestion.SYMPTOMS: (emergency["symptoms"], "Reported symptoms"),
        OperatorQuestion.INCIDENT_TIME: (emergency["occurred_at"], "Incident time"),
        OperatorQuestion.CONSCIOUSNESS: (emergency["consciousness"], "Reported consciousness"),
        OperatorQuestion.ALLERGIES: (passport["allergies"], "Recorded allergies"),
        OperatorQuestion.MEDICINES: (passport["medicines"], "Current medicines"),
        OperatorQuestion.CALLBACK: (identity["callback"], "Callback number"),
        OperatorQuestion.EMERGENCY_CONTACT: (
            passport["emergency_contact"],
            "Emergency contact",
        ),
        OperatorQuestion.LANGUAGE: (passport["preferred_language"], "Preferred language"),
    }
    field, label = mapping[question]
    if field["missing"]:
        return SimulatedAnswer(
            question=question,
            answer=f"{label} is unknown. The human caller must answer if possible.",
            source=field["source"],
            missing=True,
        )
    value = field["value"]
    if question is OperatorQuestion.LOCATION:
        latitude = value["latitude"]
        longitude = value["longitude"]
        coordinates = f"{latitude:.6f}, {longitude:.6f}"
        place = value.get("label")
        value = (
            f"nearest place: {place}; coordinates: {coordinates}"
            if place
            else f"coordinates: {coordinates}; nearest place is unavailable"
        )
    return SimulatedAnswer(
        question=question,
        answer=f"{label}: {value}",
        source=field["source"],
        missing=False,
    )
