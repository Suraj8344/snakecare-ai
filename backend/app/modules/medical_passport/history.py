"""Deterministic source display. No external provider or generated medical claims."""

from typing import Any


def history_sections(record: dict[str, Any], question: str = "") -> list[dict[str, str]]:
    sections = []
    fields = {
        "allergies": ("Allergies", ("allerg", "reaction")),
        "conditions": ("Conditions", ("condition", "disease", "diagnos")),
        "medications": (
            "Recorded medications (verify current use)",
            ("medic", "drug", "dose", "dosage", "frequency"),
        ),
        "surgeries": ("Surgeries", ("surg", "operation", "procedure")),
        "family_history": ("Family history", ("family", "heredit")),
    }
    query = question.strip().lower()
    matched = [key for key, (_, words) in fields.items() if any(w in query for w in words)]
    if not query or query == "history" or any(
        word in query for word in ("summary", "summarise", "summarize")
    ):
        matched = list(fields)
    # A question is a section filter, never a diagnosis/treatment instruction.
    if query and not matched:
        return [
            {
                "title": "Question not supported",
                "source": "Scope notice",
                "text": (
                    "This record viewer supports summary, allergies, conditions, medications, "
                    "surgeries and family history. It does not generate clinical answers "
                    "or infer unrecorded facts."
                ),
            }
        ]
    for key in matched:
        title, _ = fields[key]
        items = record.get(key, [])
        lines = []
        for item in items:
            parts = [
                f"{k.replace('_', ' ')}: {v}"
                for k, v in item.items()
                if k != "id" and v is not None and str(v).strip()
            ]
            lines.append("; ".join(parts))
        sections.append(
            {
                "title": title,
                "source": f"Medical Passport / {key}",
                "text": "\n".join(lines)
                if lines
                else "Not recorded. This does not confirm absence.",
            }
        )
    return sections
