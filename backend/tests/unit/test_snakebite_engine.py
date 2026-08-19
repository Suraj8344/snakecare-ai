from app.modules.snakebite_emergency.domain import Consciousness, Symptom, Urgency
from app.modules.snakebite_emergency.engine import ACTIONS_TO_AVOID, SnakebiteDecisionEngine
from app.modules.snakebite_emergency.schemas import EmergencyCreate, VitalsInput


def test_breathing_difficulty_is_critical_and_explainable() -> None:
    result = SnakebiteDecisionEngine().assess(
        EmergencyCreate(symptoms=[Symptom.BREATHING_DIFFICULTY])
    )
    assert result.urgency is Urgency.CRITICAL
    assert any("Breathing difficulty" in reason for reason in result.explanation)
    assert any("emergency services" in action for action in result.immediate_actions)


def test_rapid_swelling_is_high_risk() -> None:
    result = SnakebiteDecisionEngine().assess(
        EmergencyCreate(symptoms=[Symptom.RAPIDLY_SPREADING_SWELLING])
    )
    assert result.urgency is Urgency.HIGH_RISK
    assert any("swelling" in reason.lower() for reason in result.explanation)


def test_no_observed_symptom_is_still_urgent() -> None:
    result = SnakebiteDecisionEngine().assess(EmergencyCreate(symptoms=[Symptom.NONE_OBSERVED]))
    assert result.urgency is Urgency.URGENT_ASSESSMENT
    assert "delayed" in result.explanation[0]


def test_dangerous_vitals_escalate_without_symptom_guessing() -> None:
    result = SnakebiteDecisionEngine().assess(
        EmergencyCreate(
            symptoms=[Symptom.NONE_OBSERVED],
            vitals=VitalsInput(
                oxygen_saturation=90,
                consciousness=Consciousness.RESPONDS_TO_VOICE,
            ),
        )
    )
    assert result.urgency is Urgency.CRITICAL
    assert len(result.explanation) == 2


def test_first_aid_prohibits_harmful_actions() -> None:
    combined = " ".join(ACTIONS_TO_AVOID).lower()
    assert "tourniquet" in combined
    assert "cut" in combined
    assert "suck" in combined
    assert "traditional" in combined
