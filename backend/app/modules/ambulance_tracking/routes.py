from datetime import UTC, datetime
from typing import Any, Literal
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Response
from pydantic import AwareDatetime, BaseModel, Field
from sqlalchemy import false, or_, select
from sqlalchemy.exc import IntegrityError

from app.api.dependencies import DatabaseSession
from app.modules.ambulance_tracking.models import DriverRegistration, TrackingTrip
from app.modules.auth.dependencies import CurrentUser
from app.modules.hospital_coordination.models import HospitalFacility

router = APIRouter(prefix="/ambulance-tracking", tags=["ambulance-tracking"])
TERMINAL = {"completed", "cancelled"}


class RegistrationInput(BaseModel):
    hospital_id: UUID
    driver_name: str = Field(min_length=2, max_length=120, pattern=r".*\S.*")
    vehicle_number: str = Field(min_length=3, max_length=32, pattern=r".*\S.*")
    verification_reference: str = Field(min_length=3, max_length=120, pattern=r".*\S.*")


class ReviewInput(BaseModel):
    status: Literal["approved", "rejected", "revoked"]


class TripInput(BaseModel):
    hospital_id: UUID
    latitude: float = Field(ge=-90, le=90, allow_inf_nan=False)
    longitude: float = Field(ge=-180, le=180, allow_inf_nan=False)
    share_pickup_consent: Literal[True]


class AssignmentInput(BaseModel):
    driver_id: UUID


class StatusInput(BaseModel):
    status: Literal["en_route", "onboard", "completed", "cancelled"]


class LocationInput(BaseModel):
    latitude: float = Field(ge=-90, le=90, allow_inf_nan=False)
    longitude: float = Field(ge=-180, le=180, allow_inf_nan=False)
    accuracy_m: float = Field(ge=0, le=1000, allow_inf_nan=False)
    captured_at: AwareDatetime


def utc(value: datetime) -> datetime:
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)


async def commit(session: DatabaseSession) -> None:
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(
            409, "An active trip or driver registration already exists. Refresh."
        ) from exc


async def hospital(session: DatabaseSession, hospital_id: UUID) -> HospitalFacility:
    result = await session.get(HospitalFacility, hospital_id)
    if result is None or not result.is_active or result.managed_by_user_id is None:
        raise HTTPException(404, "Hospital must be active and managed by a verified authority.")
    return result


def can_manage(user: CurrentUser, facility: HospitalFacility) -> bool:
    return user.role == "government_admin" or (
        user.role == "hospital_admin" and facility.managed_by_user_id == user.id
    )


def driver_view(item: DriverRegistration) -> dict[str, Any]:
    return {
        key: getattr(item, key)
        for key in (
            "id",
            "hospital_id",
            "driver_name",
            "vehicle_number",
            "status",
            "verification_reference",
        )
    }


def trip_view(
    trip: TrackingTrip, driver: DriverRegistration | None, user_id: UUID
) -> dict[str, Any]:
    data = {
        key: getattr(trip, key)
        for key in (
            "id",
            "hospital_id",
            "driver_id",
            "status",
            "pickup_latitude",
            "pickup_longitude",
            "latitude",
            "longitude",
            "accuracy_m",
            "captured_at",
            "received_at",
            "created_at",
        )
    }
    data["is_patient"] = trip.patient_id == user_id
    data["is_driver"] = driver is not None and driver.user_id == user_id
    data["driver_name"] = driver.driver_name if driver else None
    data["vehicle_number"] = driver.vehicle_number if driver else None
    age = (datetime.now(UTC) - utc(trip.captured_at)).total_seconds() if trip.captured_at else None
    data["location_stale"] = age is None or age > 60 or trip.status in TERMINAL
    return data


@router.get("/hospitals")
async def hospitals(
    session: DatabaseSession, user: CurrentUser, search: str = Query(default="", max_length=120)
) -> list[dict[str, Any]]:
    del user
    rows = await session.scalars(
        select(HospitalFacility)
        .where(
            HospitalFacility.is_active.is_(True),
            HospitalFacility.managed_by_user_id.is_not(None),
            HospitalFacility.name.ilike(f"%{search}%"),
        )
        .order_by(HospitalFacility.name)
        .limit(100)
    )
    return [{"id": h.id, "name": h.name, "address": h.address} for h in rows]


@router.get("/workspace")
async def workspace(
    session: DatabaseSession, user: CurrentUser, response: Response
) -> dict[str, Any]:
    response.headers["Cache-Control"] = "no-store"
    managed_query = select(HospitalFacility).where(HospitalFacility.is_active.is_(True))
    if user.role != "government_admin":
        managed_query = managed_query.where(
            HospitalFacility.managed_by_user_id == user.id
            if user.role == "hospital_admin"
            else HospitalFacility.id.is_(None)
        )
    managed = list(await session.scalars(managed_query))
    ids = [h.id for h in managed]
    mine = await session.scalar(
        select(DriverRegistration).where(DriverRegistration.user_id == user.id)
    )
    registrations = await session.scalars(
        select(DriverRegistration)
        .where(DriverRegistration.hospital_id.in_(ids))
        .order_by(DriverRegistration.created_at.desc())
        .limit(100)
    )
    trips = await session.scalars(
        select(TrackingTrip)
        .where(
            or_(
                TrackingTrip.patient_id == user.id,
                TrackingTrip.hospital_id.in_(ids),
                TrackingTrip.driver_id == mine.id
                if mine and mine.status == "approved"
                else false(),
            )
        )
        .order_by(TrackingTrip.created_at.desc())
        .limit(100)
    )
    result = []
    for trip in trips:
        driver = await session.get(DriverRegistration, trip.driver_id) if trip.driver_id else None
        result.append(trip_view(trip, driver, user.id))
    return {
        "registration": driver_view(mine) if mine else None,
        "managed_hospitals": [{"id": h.id, "name": h.name} for h in managed],
        "registrations": [driver_view(d) for d in registrations],
        "trips": result,
    }


@router.post("/drivers", status_code=201)
async def register(
    payload: RegistrationInput, session: DatabaseSession, user: CurrentUser
) -> dict[str, Any]:
    await hospital(session, payload.hospital_id)
    existing = await session.scalar(
        select(DriverRegistration).where(DriverRegistration.user_id == user.id).with_for_update()
    )
    if existing and existing.status not in {"rejected", "revoked"}:
        raise HTTPException(409, "Registration already exists; ask the hospital to review it.")
    if existing:
        for key, value in payload.model_dump().items():
            setattr(existing, key, value)
        existing.status = "pending"
        existing.reviewed_by = None
    else:
        existing = DriverRegistration(user_id=user.id, status="pending", **payload.model_dump())
        session.add(existing)
    await commit(session)
    return driver_view(existing)


@router.post("/drivers/{driver_id}/review")
async def review(
    driver_id: UUID, payload: ReviewInput, session: DatabaseSession, user: CurrentUser
) -> dict[str, Any]:
    driver = await session.scalar(
        select(DriverRegistration).where(DriverRegistration.id == driver_id).with_for_update()
    )
    if driver is None or not can_manage(user, await hospital(session, driver.hospital_id)):
        raise HTTPException(403, "Only this hospital's authority can review this registration.")
    if driver.user_id == user.id:
        raise HTTPException(403, "Self-approval is not allowed.")
    active = await session.scalar(
        select(TrackingTrip).where(
            TrackingTrip.driver_id == driver.id, TrackingTrip.status.not_in(TERMINAL)
        )
    )
    if active:
        raise HTTPException(409, "Complete or cancel the active trip before changing approval.")
    driver.status = payload.status
    driver.reviewed_by = user.id
    await commit(session)
    return driver_view(driver)


@router.post("/trips", status_code=201)
async def request_trip(
    payload: TripInput, session: DatabaseSession, user: CurrentUser
) -> dict[str, Any]:
    await hospital(session, payload.hospital_id)
    trip = TrackingTrip(
        patient_id=user.id,
        hospital_id=payload.hospital_id,
        pickup_latitude=payload.latitude,
        pickup_longitude=payload.longitude,
        status="requested",
    )
    session.add(trip)
    await commit(session)
    return trip_view(trip, None, user.id)


async def authorized_trip(
    trip_id: UUID, session: DatabaseSession, user: CurrentUser
) -> tuple[TrackingTrip, DriverRegistration | None, bool]:
    trip = await session.scalar(
        select(TrackingTrip).where(TrackingTrip.id == trip_id).with_for_update()
    )
    if trip is None:
        raise HTTPException(404, "Trip not found.")
    facility = await session.get(HospitalFacility, trip.hospital_id)
    manager = facility is not None and can_manage(user, facility)
    driver = await session.get(DriverRegistration, trip.driver_id) if trip.driver_id else None
    is_driver = driver and driver.user_id == user.id and driver.status == "approved"
    if not (manager or trip.patient_id == user.id or is_driver):
        raise HTTPException(403, "This trip is not assigned to you.")
    return trip, driver, manager


@router.post("/trips/{trip_id}/assign")
async def assign(
    trip_id: UUID, payload: AssignmentInput, session: DatabaseSession, user: CurrentUser
) -> dict[str, Any]:
    trip, _, manager = await authorized_trip(trip_id, session, user)
    if not manager:
        raise HTTPException(403, "Hospital approval is required to assign a driver.")
    driver = await session.scalar(
        select(DriverRegistration)
        .where(DriverRegistration.id == payload.driver_id)
        .with_for_update()
    )
    if (
        trip.status != "requested"
        or not driver
        or driver.status != "approved"
        or (driver.hospital_id != trip.hospital_id or driver.user_id == trip.patient_id)
    ):
        raise HTTPException(409, "Select an approved driver from this hospital for a waiting trip.")
    trip.driver_id = driver.id
    trip.status = "assigned"
    await commit(session)
    return trip_view(trip, driver, user.id)


@router.post("/trips/{trip_id}/status")
async def set_status(
    trip_id: UUID, payload: StatusInput, session: DatabaseSession, user: CurrentUser
) -> dict[str, Any]:
    trip, driver, manager = await authorized_trip(trip_id, session, user)
    is_driver = driver and driver.user_id == user.id and driver.status == "approved"
    if trip.status in TERMINAL:
        raise HTTPException(409, "Trip has ended.")
    if payload.status == "cancelled":
        if not (manager or trip.patient_id == user.id):
            raise HTTPException(403, "Ask the hospital to cancel or reassign this trip.")
    elif (
        not is_driver
        or {"assigned": "en_route", "en_route": "onboard", "onboard": "completed"}.get(trip.status)
        != payload.status
    ):
        raise HTTPException(409, "Only the assigned driver can perform the next trip step.")
    trip.status = payload.status
    if trip.status in TERMINAL:
        for key in (
            "latitude",
            "longitude",
            "accuracy_m",
            "captured_at",
            "received_at",
            "pickup_latitude",
            "pickup_longitude",
        ):
            setattr(trip, key, None)
    await commit(session)
    return trip_view(trip, driver, user.id)


@router.post("/trips/{trip_id}/location")
async def update_location(
    trip_id: UUID, payload: LocationInput, session: DatabaseSession, user: CurrentUser
) -> dict[str, Any]:
    trip, driver, _ = await authorized_trip(trip_id, session, user)
    if not driver or driver.user_id != user.id or driver.status != "approved":
        raise HTTPException(403, "Only the assigned approved driver can share GPS.")
    if trip.status not in {"en_route", "onboard"}:
        raise HTTPException(409, "Start an active trip before sharing GPS.")
    now = datetime.now(UTC)
    age = (now - payload.captured_at).total_seconds()
    if (
        age < -10
        or age > 120
        or (trip.captured_at and payload.captured_at <= utc(trip.captured_at))
    ):
        raise HTTPException(422, "Location must be recent and newer than the last sample.")
    if trip.received_at and (now - utc(trip.received_at)).total_seconds() < 3:
        raise HTTPException(429, "Wait at least three seconds between updates.")
    for key, value in payload.model_dump().items():
        setattr(trip, key, value)
    trip.received_at = now
    await commit(session)
    return trip_view(trip, driver, user.id)
