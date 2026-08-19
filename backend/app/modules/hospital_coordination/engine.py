from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from math import asin, cos, radians, sin, sqrt

from app.modules.hospital_coordination.domain import FacilityDataSource, StockStatus
from app.modules.hospital_coordination.models import (
    HospitalAvailability,
    HospitalCapability,
    HospitalFacility,
)

RULESET_VERSION = "hospital-readiness-rules-v1"
RECOMMENDATION_NOTICE = (
    "Recommendations depend on reported capability and timestamped availability. "
    "Call the hospital to confirm and do not delay emergency transport while waiting."
)


@dataclass(frozen=True, slots=True)
class RankedHospital:
    facility: HospitalFacility
    capability: HospitalCapability
    availability: HospitalAvailability | None
    distance_km: float
    score: float
    score_components: dict[str, float]
    reasons: list[str]
    warnings: list[str]


class HospitalRecommendationEngine:
    def rank(
        self,
        entries: list[tuple[HospitalFacility, HospitalCapability, HospitalAvailability | None]],
        *,
        latitude: float,
        longitude: float,
        urgency: str,
        max_distance_km: float,
    ) -> list[RankedHospital]:
        now = datetime.now(UTC)
        ranked: list[RankedHospital] = []
        for facility, capability, availability in entries:
            distance = self.distance_km(latitude, longitude, facility.latitude, facility.longitude)
            if distance > max_distance_km:
                continue
            components: dict[str, float] = {
                "proximity": max(0.0, 30.0 * (1.0 - distance / max_distance_km))
            }
            reasons: list[str] = [f"Approximately {distance:.1f} km away."]
            warnings: list[str] = []
            if facility.data_source == FacilityDataSource.UNVERIFIED.value:
                warnings.append(
                    "Facility identity is from public map data and is not registry verified."
                )
            capability_points = {
                "24-hour emergency service": (capability.emergency_24x7, 10.0),
                "snakebite-trained staff": (capability.snakebite_trained_staff, 18.0),
                "antivenom administration capability": (
                    capability.can_administer_antivenom,
                    18.0,
                ),
                "ICU": (capability.icu, 7.0),
                "ventilator": (capability.ventilator, 8.0),
                "dialysis": (capability.dialysis, 4.0),
                "blood bank": (capability.blood_bank, 3.0),
            }
            for label, (present, points) in capability_points.items():
                if present:
                    components[label] = points
                    reasons.append(f"Reports {label}.")
            if urgency == "critical":
                critical_points = (8.0 if capability.icu else 0.0) + (
                    8.0 if capability.ventilator else 0.0
                )
                components["critical-care readiness"] = critical_points

            if availability is None:
                warnings.append("No current resource availability snapshot.")
            elif self.as_utc(availability.expires_at) <= now:
                warnings.append(f"Availability expired at {availability.expires_at.isoformat()}.")
            else:
                stock = StockStatus(availability.antivenom_status)
                stock_points = {
                    StockStatus.AVAILABLE: 25.0,
                    StockStatus.LOW: 8.0,
                    StockStatus.OUT_OF_STOCK: -35.0,
                    StockStatus.UNKNOWN: 0.0,
                }[stock]
                components["fresh antivenom status"] = stock_points
                if stock == StockStatus.AVAILABLE:
                    reasons.append("A current snapshot reports antivenom available.")
                elif stock == StockStatus.LOW:
                    warnings.append("A current snapshot reports low antivenom stock.")
                elif stock == StockStatus.OUT_OF_STOCK:
                    warnings.append("A current snapshot reports antivenom out of stock.")
                else:
                    warnings.append("Current antivenom stock is unconfirmed.")
            score = round(sum(components.values()), 2)
            ranked.append(
                RankedHospital(
                    facility=facility,
                    capability=capability,
                    availability=availability,
                    distance_km=round(distance, 2),
                    score=score,
                    score_components={key: round(value, 2) for key, value in components.items()},
                    reasons=reasons,
                    warnings=warnings,
                )
            )
        return sorted(ranked, key=lambda item: (-item.score, item.distance_km))

    @staticmethod
    def distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        radius_km = 6371.0088
        lat_delta = radians(lat2 - lat1)
        lon_delta = radians(lon2 - lon1)
        value = (
            sin(lat_delta / 2) ** 2
            + cos(radians(lat1)) * cos(radians(lat2)) * sin(lon_delta / 2) ** 2
        )
        return 2 * radius_km * asin(sqrt(value))

    @staticmethod
    def as_utc(value: datetime) -> datetime:
        return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)
