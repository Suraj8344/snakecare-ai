from __future__ import annotations

import asyncio
import json
import time
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any, cast
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen
from uuid import NAMESPACE_URL, UUID, uuid5

from sqlalchemy import select

from app.core.config import get_settings
from app.infrastructure.database.session import Database
from app.modules.auth.models import User  # noqa: F401
from app.modules.hospital_coordination.domain import FacilityDataSource
from app.modules.hospital_coordination.models import (
    HospitalCapability,
    HospitalFacility,
)

OVERPASS_URLS = (
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
)
PUNE_BOUNDS = (18.3613738, 73.6945071, 18.6813738, 74.0145071)
SOURCE_ATTRIBUTION = "OpenStreetMap contributors, ODbL 1.0"


@dataclass(frozen=True, slots=True)
class ImportedFacility:
    id: UUID
    name: str
    address: str
    latitude: float
    longitude: float
    phone: str | None
    source_url: str


def overpass_query(bounds: tuple[float, float, float, float]) -> str:
    south, west, north, east = bounds
    return (
        "[out:json][timeout:90];"
        f'nwr["amenity"="hospital"]({south},{west},{north},{east});'
        "out center tags;"
    )


def pune_tiles() -> list[tuple[float, float, float, float]]:
    south, west, north, east = PUNE_BOUNDS
    latitude_step = (north - south) / 3
    longitude_step = (east - west) / 3
    return [
        (
            south + row * latitude_step,
            west + column * longitude_step,
            south + (row + 1) * latitude_step,
            west + (column + 1) * longitude_step,
        )
        for row in range(3)
        for column in range(3)
    ]


def fetch_payload() -> dict[str, Any]:
    elements: list[dict[str, Any]] = []
    failed_tiles: list[tuple[float, float, float, float]] = []
    for bounds in pune_tiles():
        try:
            elements.extend(_fetch_tile(bounds))
        except RuntimeError:
            failed_tiles.append(bounds)
    if not elements:
        raise RuntimeError("No Pune hospital map tiles could be downloaded")
    return {"elements": elements, "failed_tiles": failed_tiles}


def _fetch_tile(
    bounds: tuple[float, float, float, float],
    *,
    depth: int = 0,
) -> list[dict[str, Any]]:
    query = quote(overpass_query(bounds))
    last_error: Exception | None = None
    for endpoint in OVERPASS_URLS:
        request = Request(
            f"{endpoint}?data={query}",
            headers={"User-Agent": "SnakeCareAI/0.1"},
        )
        try:
            with urlopen(request, timeout=30) as response:  # noqa: S310
                payload = cast(dict[str, Any], json.loads(response.read().decode("utf-8")))
                return cast(list[dict[str, Any]], payload.get("elements", []))
        except (HTTPError, URLError, TimeoutError) as error:
            last_error = error
            time.sleep(1)
    if depth < 1:
        elements: list[dict[str, Any]] = []
        for smaller_bounds in _split_bounds(bounds):
            elements.extend(_fetch_tile(smaller_bounds, depth=depth + 1))
        return elements
    raise RuntimeError(f"Unable to download Pune map tile: {bounds}") from last_error


def _split_bounds(
    bounds: tuple[float, float, float, float],
) -> list[tuple[float, float, float, float]]:
    south, west, north, east = bounds
    middle_latitude = (south + north) / 2
    middle_longitude = (west + east) / 2
    return [
        (south, west, middle_latitude, middle_longitude),
        (south, middle_longitude, middle_latitude, east),
        (middle_latitude, west, north, middle_longitude),
        (middle_latitude, middle_longitude, north, east),
    ]


def parse_facilities(payload: dict[str, Any]) -> list[ImportedFacility]:
    facilities: dict[UUID, ImportedFacility] = {}
    for element in payload.get("elements", []):
        tags = element.get("tags") or {}
        name = _clean(tags.get("name"), 240)
        element_type = element.get("type")
        element_id = element.get("id")
        center = element.get("center") or element
        latitude = center.get("lat")
        longitude = center.get("lon")
        if not name or element_type not in {"node", "way", "relation"}:
            continue
        if element_id is None or latitude is None or longitude is None:
            continue
        source_url = f"https://www.openstreetmap.org/{element_type}/{element_id}"
        stable_id = uuid5(NAMESPACE_URL, source_url)
        facilities[stable_id] = ImportedFacility(
            id=stable_id,
            name=name,
            address=_address(tags, source_url),
            latitude=float(latitude),
            longitude=float(longitude),
            phone=_clean(tags.get("contact:phone") or tags.get("phone"), 32),
            source_url=source_url,
        )
    return sorted(facilities.values(), key=lambda value: value.name.casefold())


async def import_facilities(payload: dict[str, Any]) -> tuple[int, int]:
    database = Database(get_settings().database_url)
    facilities = parse_facilities(payload)
    now = datetime.now(UTC)
    created = 0
    updated = 0
    async with database.session_factory() as session:
        ids = [facility.id for facility in facilities]
        existing = {
            item.id: item
            for item in await session.scalars(
                select(HospitalFacility).where(HospitalFacility.id.in_(ids))
            )
        }
        capabilities = {
            item.hospital_id: item
            for item in await session.scalars(
                select(HospitalCapability).where(HospitalCapability.hospital_id.in_(ids))
            )
        }
        for imported in facilities:
            facility = existing.get(imported.id)
            if facility is None:
                facility = HospitalFacility(id=imported.id)
                session.add(facility)
                created += 1
            else:
                updated += 1
            facility.hfr_id = None
            facility.name = imported.name
            facility.address = imported.address
            facility.city = "Pune"
            facility.state = "Maharashtra"
            facility.latitude = imported.latitude
            facility.longitude = imported.longitude
            facility.emergency_phone = imported.phone
            facility.directions_url = imported.source_url
            facility.data_source = FacilityDataSource.UNVERIFIED.value
            facility.source_updated_at = now
            facility.is_active = True

        await session.flush()
        for imported in facilities:
            capability = capabilities.get(imported.id)
            if capability is None:
                capability = HospitalCapability(hospital_id=imported.id)
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
        await session.commit()
    await database.dispose()
    return created, updated


def _address(tags: dict[str, Any], source_url: str) -> str:
    full = _clean(tags.get("addr:full"), 1000)
    if full:
        return full
    parts = [
        _clean(tags.get("addr:housenumber"), 100),
        _clean(tags.get("addr:street"), 240),
        _clean(tags.get("addr:suburb"), 240),
        _clean(tags.get("addr:city"), 120),
        _clean(tags.get("addr:postcode"), 20),
    ]
    address = ", ".join(value for value in parts if value)
    return address or f"Pune location recorded at {source_url}"


def _clean(value: Any, maximum: int) -> str | None:
    if not isinstance(value, str):
        return None
    cleaned = " ".join(value.split()).strip()
    return cleaned[:maximum] or None


async def main() -> None:
    payload = await asyncio.to_thread(fetch_payload)
    created, updated = await import_facilities(payload)
    failed_tiles = len(payload.get("failed_tiles", []))
    print(
        f"Pune hospital import complete: {created} created, {updated} updated. "
        f"{failed_tiles} of 9 map tiles were unavailable. "
        f"Source: {SOURCE_ATTRIBUTION}. All imported records are unverified."
    )


if __name__ == "__main__":
    asyncio.run(main())
