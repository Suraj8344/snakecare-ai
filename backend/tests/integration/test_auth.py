from __future__ import annotations

import json
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from datetime import UTC, datetime, timedelta
from io import BytesIO
from tempfile import TemporaryDirectory

import fitz
import pytest
from httpx import ASGITransport, AsyncClient
from PIL import Image

from app.core.config import Settings
from app.infrastructure.database.base import Base
from app.main import create_app
from app.modules.auth.domain import VerifiedIdentity


class FakeIdentityVerifier:
    async def verify(self, id_token: str) -> VerifiedIdentity:
        email = (
            "admin@example.gov"
            if id_token == "admin-token-with-valid-length"
            else f"{id_token[:16]}@example.com"
        )
        return VerifiedIdentity(
            firebase_uid=id_token,
            email=email,
            email_verified=True,
            phone_number=None,
            display_name="Test User",
        )


@asynccontextmanager
async def auth_client() -> AsyncIterator[AsyncClient]:
    with TemporaryDirectory() as report_storage:
        settings = Settings(
            environment="test",
            database_url="sqlite+aiosqlite:///:memory:",
            jwt_secret="test-secret-that-is-longer-than-thirty-two-characters",
            bootstrap_government_admin_emails=["admin@example.gov"],
            report_storage_path=report_storage,
        )
        app = create_app(settings)
        async with app.router.lifespan_context(app):
            app.state.identity_verifier = FakeIdentityVerifier()
            async with app.state.database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with AsyncClient(
                transport=ASGITransport(app=app), base_url="http://test"
            ) as client:
                yield client


async def exchange(client: AsyncClient, token: str) -> dict[str, object]:
    response = await client.post("/api/v1/auth/session", json={"firebase_id_token": token})
    assert response.status_code == 201, response.text
    return response.json()


def png_photo() -> bytes:
    output = BytesIO()
    Image.new("RGB", (20, 20), "white").save(output, format="PNG")
    return output.getvalue()


@pytest.mark.asyncio
async def test_browser_authentication_preflight_is_allowed() -> None:
    settings = Settings(
        environment="test",
        database_url="sqlite+aiosqlite:///:memory:",
        cors_origins=["http://localhost:8080"],
    )
    app = create_app(settings)
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        for method in ("POST", "PUT", "PATCH", "DELETE"):
            response = await client.options(
                "/api/v1/medical-passport/me",
                headers={
                    "Origin": "http://localhost:8080",
                    "Access-Control-Request-Method": method,
                    "Access-Control-Request-Headers": "content-type,authorization",
                },
            )
            assert response.status_code == 200
            assert response.headers["access-control-allow-origin"] == "http://localhost:8080"


@pytest.mark.asyncio
async def test_unexpected_error_response_keeps_cors_headers() -> None:
    settings = Settings(
        environment="test",
        database_url="sqlite+aiosqlite:///:memory:",
        cors_origins=["http://localhost:8080"],
    )
    app = create_app(settings)

    @app.get("/test-unexpected-error")
    async def unexpected_error() -> None:
        raise RuntimeError("test failure")

    transport = ASGITransport(app=app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get(
            "/test-unexpected-error",
            headers={"Origin": "http://localhost:8080"},
        )

    assert response.status_code == 500
    assert response.headers["access-control-allow-origin"] == "http://localhost:8080"
    assert response.json()["detail"] == (
        "The server could not complete the request. Please try again."
    )


@pytest.mark.asyncio
async def test_patient_session_refresh_and_replay_protection() -> None:
    async with auth_client() as client:
        session = await exchange(client, "patient-token-with-valid-length")
        assert session["user"]["role"] == "patient"
        headers = {"Authorization": f"Bearer {session['access_token']}"}
        me = await client.get("/api/v1/auth/me", headers=headers)
        assert me.status_code == 200

        refresh = await client.post(
            "/api/v1/auth/refresh", json={"refresh_token": session["refresh_token"]}
        )
        assert refresh.status_code == 200
        replay = await client.post(
            "/api/v1/auth/refresh", json={"refresh_token": session["refresh_token"]}
        )
        assert replay.status_code == 401


@pytest.mark.asyncio
async def test_verified_existing_user_is_promoted_when_added_to_bootstrap_allowlist() -> None:
    settings = Settings(
        environment="test",
        database_url="sqlite+aiosqlite:///:memory:",
        jwt_secret="test-secret-that-is-longer-than-thirty-two-characters",
    )
    app = create_app(settings)
    async with app.router.lifespan_context(app):
        app.state.identity_verifier = FakeIdentityVerifier()
        async with app.state.database.engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            first_session = await exchange(client, "admin-token-with-valid-length")
            assert first_session["user"]["role"] == "patient"

            app.state.bootstrap_admin_emails.add("admin@example.gov")
            promoted_session = await exchange(client, "admin-token-with-valid-length")

    assert promoted_session["user"]["role"] == "government_admin"


@pytest.mark.asyncio
async def test_government_admin_can_assign_role() -> None:
    async with auth_client() as client:
        patient = await exchange(client, "patient-token-with-valid-length")
        admin = await exchange(client, "admin-token-with-valid-length")
        admin_headers = {"Authorization": f"Bearer {admin['access_token']}"}
        response = await client.patch(
            f"/api/v1/auth/users/{patient['user']['id']}/role",
            headers=admin_headers,
            json={"role": "doctor"},
        )
        assert response.status_code == 200
        assert response.json()["role"] == "doctor"

        patient_headers = {"Authorization": f"Bearer {patient['access_token']}"}
        forbidden = await client.get("/api/v1/auth/users", headers=patient_headers)
        # A role change immediately invalidates the old role-bearing access token.
        assert forbidden.status_code == 401


@pytest.mark.asyncio
async def test_retired_ambulance_roles_cannot_be_assigned() -> None:
    async with auth_client() as client:
        patient = await exchange(client, "retired-role-patient-valid-token")
        admin = await exchange(client, "admin-token-with-valid-length")
        response = await client.patch(
            f"/api/v1/auth/users/{patient['user']['id']}/role",
            headers={"Authorization": f"Bearer {admin['access_token']}"},
            json={"role": "ambulance_crew"},
        )
        assert response.status_code == 422


@pytest.mark.asyncio
async def test_government_admin_assigns_verified_hospital_employee_identity() -> None:
    async with auth_client() as client:
        employee = await exchange(client, "hospital-employee-valid-token")
        admin = await exchange(client, "admin-token-with-valid-length")
        admin_headers = {"Authorization": f"Bearer {admin['access_token']}"}

        missing_id = await client.patch(
            f"/api/v1/auth/users/{employee['user']['id']}/role",
            headers=admin_headers,
            json={"role": "hospital_admin"},
        )
        assert missing_id.status_code == 422

        assigned = await client.patch(
            f"/api/v1/auth/users/{employee['user']['id']}/role",
            headers=admin_headers,
            json={
                "role": "hospital_admin",
                "hospital_employee_id": " pune-01/emp-1024 ",
            },
        )
        assert assigned.status_code == 200, assigned.text
        assert assigned.json()["role"] == "hospital_admin"
        assert assigned.json()["hospital_employee_id"] == "PUNE-01/EMP-1024"

        users = await client.get("/api/v1/auth/users", headers=admin_headers)
        managed_employee = next(
            user for user in users.json() if user["id"] == employee["user"]["id"]
        )
        assert managed_employee["hospital_employee_id"] == "PUNE-01/EMP-1024"


@pytest.mark.asyncio
async def test_patient_updates_passport_with_conflict_protection() -> None:
    async with auth_client() as client:
        session = await exchange(client, "passport-patient-token-valid-length")
        headers = {"Authorization": f"Bearer {session['access_token']}"}
        initial = await client.get("/api/v1/medical-passport/me", headers=headers)
        assert initial.status_code == 200
        assert initial.json()["data_provenance"] == "patient_reported"

        payload = {
            "version": initial.json()["version"],
            "full_name": "Patient Example",
            "date_of_birth": "1995-05-10",
            "biological_sex": "not_disclosed",
            "blood_group": "O+",
            "height_cm": 170,
            "weight_kg": 65,
            "preferred_language": "English",
            "organ_donor": False,
            "insurance_provider": "Example Health Insurance",
            "insurance_policy_number": "POL-12345",
            "insurance_member_id": "MEM-98765",
            "insurance_group_number": "GRP-42",
            "insurance_plan_name": "Emergency Plus",
            "insurance_valid_through": "2030-12-31",
            "insurance_emergency_phone": "+18005550199",
            "allergies": [{"allergen": "Peanuts", "reaction": "Swelling", "severity": "severe"}],
            "conditions": [],
            "medications": [],
            "emergency_contacts": [
                {
                    "name": "Emergency Person",
                    "relationship": "Parent",
                    "phone_number": "+919876543210",
                    "priority": 1,
                }
            ],
            "surgeries": [
                {
                    "procedure": "Appendectomy",
                    "performed_on": "2020-02-10",
                    "hospital": "Example Hospital",
                    "notes": None,
                }
            ],
            "family_history": [
                {
                    "relationship": "Father",
                    "condition": "Hypertension",
                    "notes": None,
                }
            ],
        }
        updated = await client.put("/api/v1/medical-passport/me", headers=headers, json=payload)
        assert updated.status_code == 200, updated.text
        assert updated.json()["version"] == 2
        assert updated.json()["blood_group"] == "O+"
        assert updated.json()["insurance_provider"] == "Example Health Insurance"
        assert updated.json()["insurance_member_id"] == "MEM-98765"
        assert updated.json()["health_id"]
        assert updated.json()["surgeries"][0]["procedure"] == "Appendectomy"
        assert updated.json()["family_history"][0]["condition"] == "Hypertension"
        assert updated.json()["allergies"][0]["allergen"] == "Peanuts"

        stale = await client.put("/api/v1/medical-passport/me", headers=headers, json=payload)
        assert stale.status_code == 409


@pytest.mark.asyncio
async def test_patient_controls_clinician_read_access() -> None:
    async with auth_client() as client:
        patient = await exchange(client, "grant-patient-token-valid-length")
        doctor = await exchange(client, "doctor-identity-token-valid-length")
        admin = await exchange(client, "admin-token-with-valid-length")
        admin_headers = {"Authorization": f"Bearer {admin['access_token']}"}
        role_change = await client.patch(
            f"/api/v1/auth/users/{doctor['user']['id']}/role",
            headers=admin_headers,
            json={"role": "doctor"},
        )
        assert role_change.status_code == 200
        doctor = await exchange(client, "doctor-identity-token-valid-length")
        doctor_headers = {"Authorization": f"Bearer {doctor['access_token']}"}
        patient_headers = {"Authorization": f"Bearer {patient['access_token']}"}

        denied = await client.get(
            f"/api/v1/medical-passports/{patient['user']['id']}",
            headers=doctor_headers,
        )
        assert denied.status_code == 403

        await client.get("/api/v1/medical-passport/me", headers=patient_headers)
        grant = await client.post(
            "/api/v1/medical-passport/access-grants",
            headers=patient_headers,
            json={
                "grantee_email": doctor["user"]["email"],
                "expires_at": "2030-01-01T00:00:00Z",
            },
        )
        assert grant.status_code == 201, grant.text
        allowed = await client.get(
            f"/api/v1/medical-passports/{patient['user']['id']}",
            headers=doctor_headers,
        )
        assert allowed.status_code == 200

        revoked = await client.delete(
            f"/api/v1/medical-passport/access-grants/{grant.json()['id']}",
            headers=patient_headers,
        )
        assert revoked.status_code == 204


def sample_lab_pdf() -> bytes:
    document = fitz.open()
    page = document.new_page()
    page.insert_text(
        (72, 72),
        "Laboratory blood test result. Hemoglobin 13.5 g/dL. Platelets 250000. "
        "Review this report with a qualified clinician.",
    )
    content = document.tobytes()
    document.close()
    return content


@pytest.mark.asyncio
async def test_patient_uploads_searches_downloads_and_deletes_report() -> None:
    async with auth_client() as client:
        patient = await exchange(client, "reports-patient-token-valid-length")
        other = await exchange(client, "reports-other-user-token-valid-length")
        headers = {"Authorization": f"Bearer {patient['access_token']}"}
        other_headers = {"Authorization": f"Bearer {other['access_token']}"}
        pdf = sample_lab_pdf()

        uploaded = await client.post(
            "/api/v1/medical-reports",
            headers=headers,
            data={
                "title": "Annual blood work",
                "report_date": "2026-08-01",
                "provider_name": "Example Diagnostics",
            },
            files={"file": ("blood-work.pdf", pdf, "application/pdf")},
        )
        assert uploaded.status_code == 201, uploaded.text
        report = uploaded.json()
        assert report["category"] == "lab_result"
        assert report["status"] == "ready"
        assert "Hemoglobin" in report["extracted_text"]
        assert report["summary_method"] == "local-extractive-v1"

        searched = await client.get(
            "/api/v1/medical-reports?q=hemoglobin&category=lab_result",
            headers=headers,
        )
        assert searched.status_code == 200
        assert searched.json()["total"] == 1

        timeline = await client.get("/api/v1/medical-reports/timeline", headers=headers)
        assert timeline.status_code == 200
        assert timeline.json()[0]["id"] == report["id"]

        denied = await client.get(f"/api/v1/medical-reports/{report['id']}", headers=other_headers)
        assert denied.status_code == 404

        downloaded = await client.get(
            f"/api/v1/medical-reports/{report['id']}/file", headers=headers
        )
        assert downloaded.status_code == 200
        assert downloaded.content == pdf

        deleted = await client.delete(f"/api/v1/medical-reports/{report['id']}", headers=headers)
        assert deleted.status_code == 204
        missing = await client.get(f"/api/v1/medical-reports/{report['id']}", headers=headers)
        assert missing.status_code == 404


@pytest.mark.asyncio
async def test_report_upload_rejects_unsupported_content() -> None:
    async with auth_client() as client:
        patient = await exchange(client, "invalid-report-user-token-valid-length")
        response = await client.post(
            "/api/v1/medical-reports",
            headers={"Authorization": f"Bearer {patient['access_token']}"},
            data={"title": "Unsafe upload"},
            files={"file": ("payload.txt", b"not a medical report", "text/plain")},
        )
        assert response.status_code == 422


@pytest.mark.asyncio
async def test_patient_creates_explainable_snakebite_emergency() -> None:
    async with auth_client() as client:
        patient = await exchange(client, "snakebite-patient-token-valid-length")
        other = await exchange(client, "snakebite-other-token-valid-length")
        headers = {"Authorization": f"Bearer {patient['access_token']}"}
        other_headers = {"Authorization": f"Bearer {other['access_token']}"}
        photo = png_photo()
        payload = {
            "patient_age_years": 30,
            "bite_site": "foot",
            "symptoms": ["breathing_difficulty", "rapidly_spreading_swelling"],
            "voice_transcript": "Breathing is becoming difficult.",
            "latitude": 18.5204,
            "longitude": 73.8567,
            "location_accuracy_m": 12.5,
            "vitals": {
                "pulse_bpm": 138,
                "oxygen_saturation": 91,
                "consciousness": "alert",
            },
        }
        created = await client.post(
            "/api/v1/snakebite-emergencies",
            headers=headers,
            data={"payload": json.dumps(payload)},
            files={"photo": ("bite.png", photo, "image/png")},
        )
        assert created.status_code == 201, created.text
        emergency = created.json()
        assert emergency["urgency"] == "critical"
        assert emergency["photo_available"] is True
        assert emergency["voice_transcript"] == payload["voice_transcript"]
        assert emergency["ruleset_version"] == "snakecare-safety-rules-v1"
        assert any("Breathing difficulty" in item for item in emergency["explanation"])
        assert any("tourniquet" in item for item in emergency["actions_to_avoid"])

        listed = await client.get("/api/v1/snakebite-emergencies", headers=headers)
        assert listed.status_code == 200
        assert listed.json()["total"] == 1

        denied = await client.get(
            f"/api/v1/snakebite-emergencies/{emergency['id']}",
            headers=other_headers,
        )
        assert denied.status_code == 404

        downloaded = await client.get(
            f"/api/v1/snakebite-emergencies/{emergency['id']}/photo",
            headers=headers,
        )
        assert downloaded.status_code == 200
        assert downloaded.content == photo


@pytest.mark.asyncio
async def test_snakebite_emergency_rejects_contradictory_symptoms_and_bad_photo() -> None:
    async with auth_client() as client:
        patient = await exchange(client, "snakebite-invalid-token-valid-length")
        headers = {"Authorization": f"Bearer {patient['access_token']}"}
        contradictory = await client.post(
            "/api/v1/snakebite-emergencies",
            headers=headers,
            data={"payload": json.dumps({"symptoms": ["none_observed", "breathing_difficulty"]})},
        )
        assert contradictory.status_code == 422

        invalid_photo = await client.post(
            "/api/v1/snakebite-emergencies",
            headers=headers,
            data={"payload": json.dumps({"symptoms": ["none_observed"]})},
            files={"photo": ("fake.png", b"not-an-image", "image/png")},
        )
        assert invalid_photo.status_code == 415


@pytest.mark.asyncio
async def test_hospital_recommendation_pre_alert_and_resource_request() -> None:
    async with auth_client() as client:
        patient = await exchange(client, "coordination-patient-token-valid-length")
        admin = await exchange(client, "admin-token-with-valid-length")
        patient_headers = {"Authorization": f"Bearer {patient['access_token']}"}
        admin_headers = {"Authorization": f"Bearer {admin['access_token']}"}
        now = datetime.now(UTC)

        facility_response = await client.post(
            "/api/v1/hospital-coordination/facilities",
            headers=admin_headers,
            json={
                "hfr_id": "TEST-HFR-001",
                "name": "Verified Snakebite Centre",
                "address": "1 Health Road, Pune",
                "city": "Pune",
                "state": "Maharashtra",
                "latitude": 18.5304,
                "longitude": 73.8567,
                "emergency_phone": "+912000000000",
                "directions_url": "https://maps.google.com/?q=18.5304,73.8567",
                "data_source": "government_verified",
                "source_updated_at": now.isoformat(),
                "capabilities": {
                    "emergency_24x7": True,
                    "snakebite_trained_staff": True,
                    "can_administer_antivenom": True,
                    "icu": True,
                    "ventilator": True,
                    "dialysis": True,
                    "blood_bank": True,
                    "data_source": "government_verified",
                    "verified_at": now.isoformat(),
                },
            },
        )
        assert facility_response.status_code == 201, facility_response.text
        hospital = facility_response.json()

        stock = await client.post(
            f"/api/v1/hospital-coordination/facilities/{hospital['id']}/availability",
            headers=admin_headers,
            json={
                "antivenom_status": "available",
                "antivenom_vials": 20,
                "emergency_beds": 4,
                "icu_beds": 2,
                "ventilators": 2,
                "data_source": "hospital_reported",
                "recorded_at": now.isoformat(),
                "expires_at": (now + timedelta(minutes=30)).isoformat(),
            },
        )
        assert stock.status_code == 201, stock.text

        emergency_response = await client.post(
            "/api/v1/snakebite-emergencies",
            headers=patient_headers,
            data={
                "payload": json.dumps(
                    {
                        "symptoms": ["breathing_difficulty"],
                        "latitude": 18.5204,
                        "longitude": 73.8567,
                    }
                )
            },
        )
        assert emergency_response.status_code == 201
        emergency = emergency_response.json()

        recommended = await client.post(
            "/api/v1/hospital-coordination/recommendations",
            headers=patient_headers,
            json={"emergency_id": emergency["id"]},
        )
        assert recommended.status_code == 200, recommended.text
        recommendation = recommended.json()["items"][0]
        assert recommendation["hospital"]["id"] == hospital["id"]
        assert recommendation["hospital"]["availability"]["antivenom_status"] == "available"
        assert recommendation["score_components"]["fresh antivenom status"] == 25

        alert = await client.post(
            "/api/v1/hospital-coordination/pre-alerts",
            headers=patient_headers,
            json={
                "emergency_id": emergency["id"],
                "hospital_id": hospital["id"],
                "share_symptoms": True,
                "share_vitals": True,
                "share_location": True,
            },
        )
        assert alert.status_code == 201, alert.text
        assert alert.json()["status"] == "pending"
        assert "symptoms" in alert.json()["shared_payload"]

        resource = await client.post(
            "/api/v1/hospital-coordination/resource-requests",
            headers=patient_headers,
            json={
                "pre_alert_id": alert.json()["id"],
                "antivenom_readiness": True,
                "emergency_bed": True,
                "icu_readiness": True,
                "ventilator_readiness": True,
            },
        )
        assert resource.status_code == 201, resource.text
        assert resource.json()["status"] == "pending"


@pytest.mark.asyncio
async def test_hospital_claim_and_approved_antivenom_box_depletion() -> None:
    async with auth_client() as client:
        manager = await exchange(client, "hospital-manager-token-valid-length")
        patient = await exchange(client, "hospital-ambulance-patient-valid-token")
        admin = await exchange(client, "admin-token-with-valid-length")
        patient_headers = {"Authorization": f"Bearer {patient['access_token']}"}
        admin_headers = {"Authorization": f"Bearer {admin['access_token']}"}
        role_change = await client.patch(
            f"/api/v1/auth/users/{manager['user']['id']}/role",
            headers=admin_headers,
            json={
                "role": "hospital_admin",
                "hospital_employee_id": "TEST-HOSPITAL-EMP-001",
            },
        )
        assert role_change.status_code == 200
        manager = await exchange(client, "hospital-manager-token-valid-length")
        manager_headers = {"Authorization": f"Bearer {manager['access_token']}"}
        now = datetime.now(UTC)

        facility = await client.post(
            "/api/v1/hospital-coordination/facilities",
            headers=admin_headers,
            json={
                "hfr_id": None,
                "name": "Claimed Pune Hospital",
                "address": "2 Health Road, Pune",
                "city": "Pune",
                "state": "Maharashtra",
                "latitude": 18.5204,
                "longitude": 73.8567,
                "emergency_phone": "+912011111111",
                "data_source": "unverified",
                "source_updated_at": now.isoformat(),
                "capabilities": {
                    "emergency_24x7": False,
                    "snakebite_trained_staff": False,
                    "can_administer_antivenom": False,
                    "icu": False,
                    "ventilator": False,
                    "dialysis": False,
                    "blood_bank": False,
                    "data_source": "unverified",
                    "verified_at": now.isoformat(),
                },
            },
        )
        assert facility.status_code == 201, facility.text

        claim = await client.post(
            "/api/v1/hospital-dashboard/claims",
            headers=manager_headers,
            json={
                "facility_id": facility.json()["id"],
                "verification_method": "hfr_or_official_documents",
                "evidence_reference": "TEST-HFR-EVIDENCE-001",
            },
        )
        assert claim.status_code == 201, claim.text
        assert claim.json()["status"] == "pending"

        approved_claim = await client.post(
            f"/api/v1/hospital-dashboard/claims/{claim.json()['id']}/decision",
            headers=admin_headers,
            json={"approve": True, "note": "Test verification completed"},
        )
        assert approved_claim.status_code == 200, approved_claim.text
        assert approved_claim.json()["status"] == "approved"

        emergency = await client.post(
            "/api/v1/snakebite-emergencies",
            headers=patient_headers,
            data={
                "payload": json.dumps(
                    {
                        "symptoms": ["rapidly_spreading_swelling"],
                        "latitude": 18.5204,
                        "longitude": 73.8567,
                    }
                )
            },
        )
        assert emergency.status_code == 201, emergency.text
        alert = await client.post(
            "/api/v1/hospital-coordination/pre-alerts",
            headers=patient_headers,
            json={
                "emergency_id": emergency.json()["id"],
                "hospital_id": facility.json()["id"],
                "share_symptoms": True,
                "share_vitals": True,
                "share_location": True,
            },
        )
        assert alert.status_code == 201, alert.text
        box = await client.post(
            "/api/v1/hospital-dashboard/antivenom-boxes",
            headers=manager_headers,
            json={
                "box_serial": "BOX-001",
                "product_name": "Test Polyvalent Antivenom",
                "manufacturer": "Test Manufacturer",
                "batch_number": "BATCH-001",
                "expiry_date": "2030-12-31",
                "initial_vials": 10,
            },
        )
        assert box.status_code == 201, box.text
        assert box.json()["available_vials"] == 10
        assert len(box.json()["qr_token"]) >= 32

        scanned = await client.post(
            "/api/v1/hospital-dashboard/antivenom-scans",
            headers=manager_headers,
            json={"qr_token": box.json()["qr_token"]},
        )
        assert scanned.status_code == 201, scanned.text
        assert scanned.json()["status"] == "pending"

        before_approval = await client.get("/api/v1/hospital-dashboard/me", headers=manager_headers)
        assert before_approval.status_code == 200, before_approval.text
        assert before_approval.json()["boxes"][0]["available_vials"] == 10

        approved = await client.post(
            f"/api/v1/hospital-dashboard/antivenom-depletions/{scanned.json()['id']}/decision",
            headers=manager_headers,
            json={"approve": True, "note": "Box confirmed empty"},
        )
        assert approved.status_code == 200, approved.text
        assert approved.json()["status"] == "approved"

        dashboard = await client.get("/api/v1/hospital-dashboard/me", headers=manager_headers)
        assert dashboard.status_code == 200, dashboard.text
        assert dashboard.json()["boxes"][0]["available_vials"] == 0
        assert dashboard.json()["boxes"][0]["status"] == "depleted"
        assert dashboard.json()["availability"]["antivenom_status"] == "out_of_stock"

        replay = await client.post(
            f"/api/v1/hospital-dashboard/antivenom-depletions/{scanned.json()['id']}/decision",
            headers=manager_headers,
            json={"approve": True},
        )
        assert replay.status_code == 409
