from datetime import datetime
from uuid import UUID

from sqlalchemy import DateTime, Float, ForeignKey, Index, String, text
from sqlalchemy.orm import Mapped, mapped_column

from app.infrastructure.database.base import Base, UUIDTimestampMixin


class DriverRegistration(UUIDTimestampMixin, Base):
    __tablename__ = "tracking_driver_registrations"

    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id"), unique=True)
    hospital_id: Mapped[UUID] = mapped_column(ForeignKey("hospital_facilities.id"), index=True)
    driver_name: Mapped[str] = mapped_column(String(120))
    vehicle_number: Mapped[str] = mapped_column(String(32))
    verification_reference: Mapped[str] = mapped_column(String(120))
    status: Mapped[str] = mapped_column(String(24), default="pending")
    reviewed_by: Mapped[UUID | None] = mapped_column(ForeignKey("users.id"))


class TrackingTrip(UUIDTimestampMixin, Base):
    __tablename__ = "tracking_trips"
    __table_args__ = (
        Index(
            "uq_tracking_active_patient",
            "patient_id",
            unique=True,
            postgresql_where=text("status NOT IN ('completed','cancelled')"),
            sqlite_where=text("status NOT IN ('completed','cancelled')"),
        ),
        Index(
            "uq_tracking_active_driver",
            "driver_id",
            unique=True,
            postgresql_where=text("status NOT IN ('completed','cancelled')"),
            sqlite_where=text("status NOT IN ('completed','cancelled')"),
        ),
    )

    patient_id: Mapped[UUID] = mapped_column(ForeignKey("users.id"), index=True)
    hospital_id: Mapped[UUID] = mapped_column(ForeignKey("hospital_facilities.id"), index=True)
    driver_id: Mapped[UUID | None] = mapped_column(ForeignKey("tracking_driver_registrations.id"))
    status: Mapped[str] = mapped_column(String(24), default="requested")
    pickup_latitude: Mapped[float | None] = mapped_column(Float)
    pickup_longitude: Mapped[float | None] = mapped_column(Float)
    latitude: Mapped[float | None] = mapped_column(Float)
    longitude: Mapped[float | None] = mapped_column(Float)
    accuracy_m: Mapped[float | None] = mapped_column(Float)
    captured_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    received_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
