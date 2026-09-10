from app.modules.medical_passport.history import history_sections


def test_missing_records_do_not_claim_absence():
    sections = history_sections({})
    assert len(sections) == 5
    assert all("Not recorded" in s["text"] for s in sections)


def test_summary_excludes_contact_and_insurance_fields():
    sections = history_sections(
        {
            "insurance_policy_number": "secret",
            "emergency_contacts": [{"phone_number": "secret"}],
            "allergies": [{"allergen": "Example", "id": "private-id"}],
        }
    )
    assert "secret" not in str(sections)
    assert "private-id" not in str(sections)
    assert "Example" in sections[0]["text"]


def test_unsupported_question_does_not_generate_treatment():
    assert (
        history_sections({}, "What treatment should I give?")[0]["title"]
        == "Question not supported"
    )
