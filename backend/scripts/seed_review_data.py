"""Seed the deterministic Pune hospital directory for review deployments."""

from __future__ import annotations

import asyncio
import os
from datetime import UTC, datetime
from urllib.parse import quote_plus
from uuid import NAMESPACE_URL, uuid5

from sqlalchemy import select

from app.infrastructure.database.session import Database
from app.modules.auth.models import User
from app.modules.hospital_coordination.domain import FacilityDataSource
from app.modules.hospital_coordination.models import HospitalCapability, HospitalFacility

DATABASE_URL = os.getenv(
    "SNAKECARE_DATABASE_URL",
    "sqlite+aiosqlite:///./var/snakecare-review3.db",
)
if DATABASE_URL.startswith("postgresql://"):
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://", 1)

PUNE_HOSPITALS = (
    ("Sassoon General Hospital", "Station Road, Pune", 18.5267, 73.8713),
    ("Ruby Hall Clinic", "Sassoon Road, Pune", 18.5332, 73.8766),
    ("Jehangir Hospital", "Sassoon Road, Pune", 18.5308, 73.8774),
    ("KEM Hospital Pune", "Rasta Peth, Pune", 18.5158, 73.8660),
    ("Deenanath Mangeshkar Hospital", "Erandwane, Pune", 18.5027, 73.8321),
    ("Poona Hospital and Research Centre", "Sadashiv Peth, Pune", 18.5082, 73.8440),
    ("Sahyadri Super Speciality Hospital", "Deccan Gymkhana, Pune", 18.5173, 73.8407),
    ("Bharati Hospital", "Dhankawadi, Pune", 18.4575, 73.8592),
    ("Noble Hospitals and Research Centre", "Hadapsar, Pune", 18.5074, 73.9273),
    ("Manipal Hospital Kharadi", "Kharadi, Pune", 18.5523, 73.9440),
    ("Jupiter Hospital Pune", "Baner, Pune", 18.5687, 73.7740),
    ("Aditya Birla Memorial Hospital", "Chinchwad, Pune", 18.6270, 73.7730),
)


async def main() -> None:
    database = Database(DATABASE_URL)
    now = datetime.now(UTC)
    async with database.session_factory() as session:
        for name, address, latitude, longitude in PUNE_HOSPITALS:
            identifier = uuid5(NAMESPACE_URL, f"snakecare-review:pune:{name}")
            facility = await session.get(HospitalFacility, identifier)
            if facility is None:
                facility = HospitalFacility(id=identifier)
                session.add(facility)
            facility.hfr_id = None
            facility.managed_by_user_id = None
            facility.name = name
            facility.address = address
            facility.city = "Pune"
            facility.state = "Maharashtra"
            facility.latitude = latitude
            facility.longitude = longitude
            facility.emergency_phone = None
            facility.directions_url = (
                "https://www.google.com/maps/search/?api=1&query=" + quote_plus(f"{name} Pune")
            )
            facility.data_source = FacilityDataSource.UNVERIFIED.value
            facility.source_updated_at = now
            facility.is_active = True

            capability = await session.scalar(
                select(HospitalCapability).where(
                    HospitalCapability.hospital_id == identifier
                )
            )
            if capability is None:
                capability = HospitalCapability(hospital_id=identifier)
                session.add(capability)
            capability.emergency_24x7 = False
            capability.snakebite_trained_staff = False
            capability.can_administer_antivenom = False
            capability.icu = False
            capability.ventilator = False
            capability.dialysis = False
            capability.blood_bank = False
            capability.data_source = FacilityDataSource.UNVERIFIED.value
            capability.verified_at = now

        government_user = await session.scalar(
            select(User).where(User.email == "pavan83448344@gmail.com")
        )
        if government_user is not None:
            government_user.role = "government_admin"
            government_user.hospital_employee_id = None

        hospital_user = await session.scalar(
            select(User).where(User.email == "suraj.1251130477@vit.edu")
        )
        if hospital_user is not None:
            hospital_user.role = "hospital_admin"
            hospital_user.hospital_employee_id = "PUNE-DEMO/HOSP-001"

        await session.commit()
    await database.dispose()
    print(
        f"Seeded {len(PUNE_HOSPITALS)} Pune review hospitals, "
        "one government-authority account, and one hospital-authority account."
    )


if __name__ == "__main__":
    asyncio.run(main())
