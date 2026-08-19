from dataclasses import dataclass

from app.modules.snakebite_emergency.domain import Consciousness, Symptom, Urgency
from app.modules.snakebite_emergency.schemas import EmergencyCreate

RULESET_VERSION = "snakecare-safety-rules-v1"
GUIDANCE_VERSION = "WHO-SEARO-MOHFW-2016"
ASSESSMENT_NOTICE = (
    "Emergency decision support only. This is not a diagnosis, snake identification, "
    "or substitute for immediate assessment by trained health professionals."
)

FIRST_AID_STEPS = [
    "Move away from the snake and do not try to catch or kill it.",
    "Remove rings, anklets, shoes, or other tight items before swelling increases.",
    "Keep the person completely still; splint the bitten limb without restricting blood flow.",
    "Carry the person and arrange transport to a health facility without delay.",
    "If vomiting or very drowsy, place the person on their side and monitor breathing.",
]

ACTIONS_TO_AVOID = [
    "Do not use a tight tourniquet or tight band.",
    "Do not cut, burn, wash aggressively, or suck the bite wound.",
    "Do not apply ice, chemicals, electric shock, black stones, herbs, or traditional remedies.",
    "Do not give alcohol and do not delay transport while trying home treatments.",
    "Do not give antivenom outside a properly equipped health facility.",
]

CRITICAL_SYMPTOMS = {
    Symptom.BREATHING_DIFFICULTY: "Breathing difficulty can indicate life-threatening paralysis.",
    Symptom.DROOPING_EYELIDS: "Drooping eyelids can be an early neurotoxic paralysis sign.",
    Symptom.DIFFICULTY_SPEAKING_OR_SWALLOWING: (
        "Difficulty speaking or swallowing can indicate progressive paralysis."
    ),
    Symptom.WEAKNESS_OR_PARALYSIS: "Weakness or paralysis can progress to breathing failure.",
    Symptom.DROWSINESS_OR_CONFUSION: "Drowsiness or confusion is an altered-consciousness sign.",
    Symptom.COLLAPSE_OR_SEIZURE: "Collapse or seizure requires immediate resuscitation capability.",
    Symptom.SPONTANEOUS_BLEEDING: "Spontaneous bleeding can indicate systemic envenoming.",
}

HIGH_RISK_SYMPTOMS = {
    Symptom.RAPIDLY_SPREADING_SWELLING: (
        "Rapidly spreading swelling can indicate severe local envenoming."
    ),
    Symptom.DARK_URINE: "Dark urine can be associated with blood, muscle, or kidney injury.",
    Symptom.REDUCED_URINE: "Reduced urine can indicate kidney or circulation complications.",
    Symptom.REPEATED_VOMITING: "Repeated vomiting increases airway and dehydration risk.",
    Symptom.BLURRED_OR_DOUBLE_VISION: "Visual disturbance can be a neurotoxic warning sign.",
    Symptom.SEVERE_LOCAL_PAIN: "Severe local pain requires urgent clinical assessment.",
    Symptom.ABDOMINAL_PAIN: "Abdominal pain after suspected snakebite requires urgent review.",
}


@dataclass(frozen=True)
class AssessmentResult:
    urgency: Urgency
    explanation: list[str]
    immediate_actions: list[str]


class SnakebiteDecisionEngine:
    def assess(self, payload: EmergencyCreate) -> AssessmentResult:
        selected = set(payload.symptoms)
        critical_reasons = [
            reason for symptom, reason in CRITICAL_SYMPTOMS.items() if symptom in selected
        ]
        high_risk_reasons = [
            reason for symptom, reason in HIGH_RISK_SYMPTOMS.items() if symptom in selected
        ]
        vitals = payload.vitals
        if vitals.consciousness is not Consciousness.ALERT:
            critical_reasons.append(
                "Reduced responsiveness can signal airway, breathing, or circulation danger."
            )
        if vitals.oxygen_saturation is not None and vitals.oxygen_saturation < 94:
            critical_reasons.append("Oxygen saturation below 94% requires immediate medical care.")
        if vitals.systolic_bp is not None and vitals.systolic_bp < 90:
            critical_reasons.append("Systolic blood pressure below 90 may indicate shock.")
        if vitals.respiratory_rate is not None and not 10 <= vitals.respiratory_rate <= 30:
            critical_reasons.append("The reported breathing rate is severely abnormal.")
        if vitals.pulse_bpm is not None and not 50 <= vitals.pulse_bpm <= 130:
            high_risk_reasons.append("The reported pulse is markedly abnormal.")

        if critical_reasons:
            return AssessmentResult(
                urgency=Urgency.CRITICAL,
                explanation=critical_reasons,
                immediate_actions=[
                    (
                        "Call local emergency services now and state that this is a "
                        "suspected snakebite."
                    ),
                    (
                        "Arrange immediate transport to a hospital capable of airway "
                        "support and antivenom."
                    ),
                    "Keep the person still, monitor breathing, and do not let them walk or drive.",
                ],
            )
        if high_risk_reasons:
            return AssessmentResult(
                urgency=Urgency.HIGH_RISK,
                explanation=high_risk_reasons,
                immediate_actions=[
                    "Call 112 and arrange immediate safe transport to a hospital.",
                    "Keep the person and bitten limb still; do not let the person walk or drive.",
                    (
                        "Watch continuously for breathing difficulty, weakness, "
                        "bleeding, or drowsiness."
                    ),
                ],
            )
        return AssessmentResult(
            urgency=Urgency.URGENT_ASSESSMENT,
            explanation=[
                "No listed danger sign was reported, but serious effects may be delayed or missed."
            ],
            immediate_actions=[
                "Go to a health facility immediately for observation and clinical assessment.",
                "Keep the person and bitten limb still and use assisted transport.",
                "Repeat the symptom check if anything changes while help is being arranged.",
            ],
        )
