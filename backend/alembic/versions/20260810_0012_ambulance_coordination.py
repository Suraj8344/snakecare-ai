"""Add ambulance identities, fleet, dispatches, location, and timeline."""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "20260810_0012"
down_revision: str | None = "20260809_0011"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.drop_constraint("ck_users_role", "users", type_="check")
    op.create_check_constraint(
        "ck_users_role",
        "users",
        "role IN ('patient','doctor','hospital_admin','ambulance_crew',"
        "'ambulance_dispatcher','government_admin')",
    )
    op.add_column("users", sa.Column("ambulance_employee_id", sa.String(64)))
    op.create_index(
        "ix_users_ambulance_employee_id",
        "users",
        ["ambulance_employee_id"],
        unique=True,
    )
    op.create_check_constraint(
        "ck_users_ambulance_employee_role",
        "users",
        "ambulance_employee_id IS NULL OR role IN "
        "('ambulance_crew','ambulance_dispatcher')",
    )

    op.create_table(
        "ambulance_vehicles",
        sa.Column("registration_number", sa.String(32), nullable=False),
        sa.Column("service_name", sa.String(160), nullable=False),
        sa.Column("vehicle_type", sa.String(32), nullable=False),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("verified_by_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.ForeignKeyConstraint(["verified_by_user_id"], ["users.id"], ondelete="RESTRICT"),
        sa.UniqueConstraint("registration_number"),
    )
    op.create_index("ix_ambulance_vehicles_status", "ambulance_vehicles", ["status"])

    op.create_table(
        "ambulance_dispatches",
        sa.Column("owner_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("emergency_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("hospital_id", postgresql.UUID(as_uuid=True)),
        sa.Column("hospital_pre_alert_id", postgresql.UUID(as_uuid=True)),
        sa.Column("ambulance_id", postgresql.UUID(as_uuid=True)),
        sa.Column("crew_user_id", postgresql.UUID(as_uuid=True)),
        sa.Column("status", sa.String(32), nullable=False),
        sa.Column("pickup_latitude", sa.Float(), nullable=False),
        sa.Column("pickup_longitude", sa.Float(), nullable=False),
        sa.Column("pickup_label", sa.String(300)),
        sa.Column("patient_share_consent", sa.Boolean(), nullable=False),
        sa.Column("requested_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("assigned_at", sa.DateTime(timezone=True)),
        sa.Column("accepted_at", sa.DateTime(timezone=True)),
        sa.Column("patient_onboard_at", sa.DateTime(timezone=True)),
        sa.Column("arrived_hospital_at", sa.DateTime(timezone=True)),
        sa.Column("completed_at", sa.DateTime(timezone=True)),
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.ForeignKeyConstraint(["owner_user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["emergency_id"], ["snakebite_emergencies.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["hospital_id"], ["hospital_facilities.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(
            ["hospital_pre_alert_id"], ["hospital_pre_alerts.id"], ondelete="SET NULL"
        ),
        sa.ForeignKeyConstraint(["ambulance_id"], ["ambulance_vehicles.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["crew_user_id"], ["users.id"], ondelete="SET NULL"),
    )
    dispatch_indexes = (
        "owner_user_id",
        "emergency_id",
        "hospital_id",
        "hospital_pre_alert_id",
        "ambulance_id",
        "crew_user_id",
        "status",
    )
    for column in dispatch_indexes:
        op.create_index(f"ix_ambulance_dispatches_{column}", "ambulance_dispatches", [column])
    op.create_index(
        "uq_ambulance_active_emergency",
        "ambulance_dispatches",
        ["emergency_id"],
        unique=True,
        postgresql_where=sa.text("status NOT IN ('completed','cancelled')"),
    )

    op.create_table(
        "ambulance_location_updates",
        sa.Column("dispatch_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("actor_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("latitude", sa.Float(), nullable=False),
        sa.Column("longitude", sa.Float(), nullable=False),
        sa.Column("accuracy_m", sa.Float()),
        sa.Column("recorded_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.ForeignKeyConstraint(["dispatch_id"], ["ambulance_dispatches.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"], ondelete="RESTRICT"),
    )
    op.create_index(
        "ix_ambulance_location_dispatch_recorded",
        "ambulance_location_updates",
        ["dispatch_id", "recorded_at"],
    )

    op.create_table(
        "ambulance_timeline_events",
        sa.Column("dispatch_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("actor_user_id", postgresql.UUID(as_uuid=True)),
        sa.Column("event_type", sa.String(64), nullable=False),
        sa.Column(
            "details",
            sa.JSON().with_variant(postgresql.JSONB(astext_type=sa.Text()), "postgresql"),
            nullable=False,
        ),
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.ForeignKeyConstraint(["dispatch_id"], ["ambulance_dispatches.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"], ondelete="SET NULL"),
    )
    op.create_index(
        "ix_ambulance_timeline_dispatch_created",
        "ambulance_timeline_events",
        ["dispatch_id", "created_at"],
    )


def downgrade() -> None:
    op.drop_table("ambulance_timeline_events")
    op.drop_table("ambulance_location_updates")
    op.drop_table("ambulance_dispatches")
    op.drop_table("ambulance_vehicles")
    op.drop_constraint("ck_users_ambulance_employee_role", "users", type_="check")
    op.execute(
        "UPDATE users SET role = 'patient', ambulance_employee_id = NULL "
        "WHERE role IN ('ambulance_crew','ambulance_dispatcher')"
    )
    op.drop_index("ix_users_ambulance_employee_id", table_name="users")
    op.drop_column("users", "ambulance_employee_id")
    op.drop_constraint("ck_users_role", "users", type_="check")
    op.create_check_constraint(
        "ck_users_role",
        "users",
        "role IN ('patient','doctor','hospital_admin','government_admin')",
    )
