from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import pytest

from app.modules.hospital_coordination.engine import HospitalRecommendationEngine
from app.modules.hospital_coordination.models import (
    HospitalAvailability,
    HospitalCapability,
    HospitalFacility,
)


def facility(name: str, latitude: float) -> HospitalFacility:
    return HospitalFacility(
        id=uuid4(),
        name=name,
        address="Test address",
        latitude=latitude,
        longitude=73.8567,
        data_source="government_verified",
        source_updated_at=datetime.now(UTC),
        is_active=True,
    )


def capability(hospital_id: UUID, *, ready: bool) -> HospitalCapability:
    return HospitalCapability(
        hospital_id=hospital_id,
        emergency_24x7=ready,
        snakebite_trained_staff=ready,
        can_administer_antivenom=ready,
        icu=ready,
        ventilator=ready,
        dialysis=False,
        blood_bank=ready,
        data_source="government_verified",
        verified_at=datetime.now(UTC),
    )


def availability(hospital_id: UUID, status: str, *, fresh: bool) -> HospitalAvailability:
    now = datetime.now(UTC)
    return HospitalAvailability(
        hospital_id=hospital_id,
        antivenom_status=status,
        antivenom_vials=12,
        emergency_beds=2,
        icu_beds=1,
        ventilators=1,
        data_source="hospital_reported",
        recorded_at=now - timedelta(minutes=5),
        expires_at=now + timedelta(minutes=20) if fresh else now - timedelta(minutes=1),
    )


def test_ready_hospital_outranks_closer_unprepared_facility() -> None:
    engine = HospitalRecommendationEngine()
    close = facility("Close clinic", 18.521)
    ready = facility("Ready hospital", 18.55)
    ranked = engine.rank(
        [
            (close, capability(close.id, ready=False), None),
            (
                ready,
                capability(ready.id, ready=True),
                availability(ready.id, "available", fresh=True),
            ),
        ],
        latitude=18.5204,
        longitude=73.8567,
        urgency="critical",
        max_distance_km=250,
    )
    assert ranked[0].facility.name == "Ready hospital"
    assert ranked[0].score_components["fresh antivenom status"] == 25
    assert any("antivenom available" in reason for reason in ranked[0].reasons)


def test_expired_availability_is_not_scored_as_current() -> None:
    engine = HospitalRecommendationEngine()
    hospital = facility("Stale hospital", 18.53)
    ranked = engine.rank(
        [
            (
                hospital,
                capability(hospital.id, ready=True),
                availability(hospital.id, "available", fresh=False),
            )
        ],
        latitude=18.5204,
        longitude=73.8567,
        urgency="high_risk",
        max_distance_km=250,
    )
    assert "fresh antivenom status" not in ranked[0].score_components
    assert any("expired" in warning for warning in ranked[0].warnings)


def test_haversine_distance_is_explainable_and_bounded() -> None:
    distance = HospitalRecommendationEngine.distance_km(18.5204, 73.8567, 18.5204, 73.8567)
    assert distance == pytest.approx(0)


def test_unverified_facility_has_explicit_identity_warning() -> None:
    engine = HospitalRecommendationEngine()
    hospital = facility("Map-listed hospital", 18.53)
    hospital.data_source = "unverified"
    ranked = engine.rank(
        [(hospital, capability(hospital.id, ready=False), None)],
        latitude=18.5204,
        longitude=73.8567,
        urgency="high_risk",
        max_distance_km=250,
    )
    assert any("not registry verified" in warning for warning in ranked[0].warnings)
