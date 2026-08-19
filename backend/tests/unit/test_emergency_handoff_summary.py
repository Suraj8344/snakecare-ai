from uuid import uuid4

from app.modules.auth.models import User
from app.modules.emergency_handoff.domain import OperatorQuestion, ResponseStatus
from app.modules.emergency_handoff.summary import (
    answer_operator_question,
    build_structured_summary,
)
from app.modules.medical_passport.models import MedicalPassport, PassportAllergy
from app.modules.snakebite_emergency.models import SnakebiteEmergency


def make_summary(*, with_location: bool = True) -> dict[str, object]:
    user = User(
        id=uuid4(),
        firebase_uid="firebase-test-user",
        email="patient@example.com",
        email_verified=True,
        phone_number=None,
        display_name="Test Patient",
        role="patient",
        status="active",
    )
    emergency = SnakebiteEmergency(
        id=uuid4(),
        owner_user_id=user.id,
        bite_site="leg",
        symptoms=["blurred_or_double_vision"],
        latitude=18.5204 if with_location else None,
        longitude=73.8567 if with_location else None,
        consciousness="alert",
        urgency="high_risk",
        explanation=[],
        immediate_actions=[],
        first_aid_steps=[],
        actions_to_avoid=[],
        ruleset_version="test-rules",
        guidance_version="test-guidance",
        assessment_notice="Not a diagnosis.",
    )
    passport = MedicalPassport(
        id=uuid4(),
        user_id=user.id,
        full_name="Test Patient",
        blood_group="O+",
        biological_sex="not_disclosed",
        organ_donor=False,
        version=1,
        allergies=[PassportAllergy(allergen="Penicillin", severity="high")],
        conditions=[],
        medications=[],
        emergency_contacts=[],
        surgeries=[],
        family_history=[],
    )
    return build_structured_summary(user, emergency, passport)


def test_summary_is_source_labelled_and_simulation_only() -> None:
    summary = make_summary()
    assert summary["simulation_only"] is True
    assert summary["identity"]["name"]["source"] == "verified_identity_or_patient_passport"
    assert summary["emergency"]["location"]["missing"] is False
    assert summary["medical_passport"]["allergies"]["value"] == ["Penicillin"]


def test_unknown_data_is_not_invented() -> None:
    summary = make_summary(with_location=False)
    answer = answer_operator_question(summary, OperatorQuestion.LOCATION)
    assert answer.missing is True
    assert "unknown" in answer.answer.lower()


def test_location_answer_includes_place_and_coordinates() -> None:
    summary = make_summary()
    summary["emergency"]["location"]["value"]["label"] = "Shaniwar Wada, Pune"
    answer = answer_operator_question(summary, OperatorQuestion.LOCATION)
    assert "Shaniwar Wada, Pune" in answer.answer
    assert "18.520400, 73.856700" in answer.answer


def test_no_response_is_distinct_from_consciousness() -> None:
    summary = make_summary()
    assert ResponseStatus.NO_RESPONSE.value == "no_response"
    consciousness = answer_operator_question(summary, OperatorQuestion.CONSCIOUSNESS)
    assert consciousness.answer.endswith("alert")
    assert "unconscious" not in consciousness.answer.lower()


def test_operator_questions_are_an_explicit_allow_list() -> None:
    assert set(OperatorQuestion) == {
        OperatorQuestion.OUT_OF_SCOPE,
        OperatorQuestion.IDENTITY,
        OperatorQuestion.LOCATION,
        OperatorQuestion.SYMPTOMS,
        OperatorQuestion.INCIDENT_TIME,
        OperatorQuestion.CONSCIOUSNESS,
        OperatorQuestion.ALLERGIES,
        OperatorQuestion.MEDICINES,
        OperatorQuestion.CALLBACK,
        OperatorQuestion.EMERGENCY_CONTACT,
        OperatorQuestion.LANGUAGE,
    }
