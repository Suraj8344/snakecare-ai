"""Create hospital recommendation and coordination foundation."""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "20260808_0008"
down_revision: str | None = "20260806_0007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _identity_columns() -> list[sa.Column[object]]:
    return [
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
    ]


def upgrade() -> None:
    op.create_table(
        "hospital_facilities",
        sa.Column("hfr_id", sa.String(100), unique=True),
        sa.Column("name", sa.String(240), nullable=False),
        sa.Column("address", sa.Text(), nullable=False),
        sa.Column("city", sa.String(120)),
        sa.Column("state", sa.String(120)),
        sa.Column("latitude", sa.Float(), nullable=False),
        sa.Column("longitude", sa.Float(), nullable=False),
        sa.Column("emergency_phone", sa.String(32)),
        sa.Column("directions_url", sa.String(500)),
        sa.Column("data_source", sa.String(40), nullable=False),
        sa.Column("source_updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        *_identity_columns(),
    )
    op.create_index("ix_hospital_facilities_hfr_id", "hospital_facilities", ["hfr_id"])
    op.create_index("ix_hospital_facilities_name", "hospital_facilities", ["name"])
    op.create_index("ix_hospital_facilities_city", "hospital_facilities", ["city"])
    op.create_index("ix_hospital_facilities_state", "hospital_facilities", ["state"])
    op.create_index(
        "ix_hospital_facilities_location", "hospital_facilities", ["latitude", "longitude"]
    )
    op.create_index(
        "ix_hospital_facilities_active_name", "hospital_facilities", ["is_active", "name"]
    )

    op.create_table(
        "hospital_capabilities",
        sa.Column(
            "hospital_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("hospital_facilities.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
        ),
        sa.Column("emergency_24x7", sa.Boolean(), nullable=False),
        sa.Column("snakebite_trained_staff", sa.Boolean(), nullable=False),
        sa.Column("can_administer_antivenom", sa.Boolean(), nullable=False),
        sa.Column("icu", sa.Boolean(), nullable=False),
        sa.Column("ventilator", sa.Boolean(), nullable=False),
        sa.Column("dialysis", sa.Boolean(), nullable=False),
        sa.Column("blood_bank", sa.Boolean(), nullable=False),
        sa.Column("data_source", sa.String(40), nullable=False),
        sa.Column("verified_at", sa.DateTime(timezone=True), nullable=False),
        *_identity_columns(),
    )
    op.create_index(
        "ix_hospital_capabilities_hospital_id", "hospital_capabilities", ["hospital_id"]
    )

    op.create_table(
        "hospital_availability_snapshots",
        sa.Column(
            "hospital_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("hospital_facilities.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("antivenom_status", sa.String(32), nullable=False),
        sa.Column("antivenom_vials", sa.Integer()),
        sa.Column("emergency_beds", sa.Integer()),
        sa.Column("icu_beds", sa.Integer()),
        sa.Column("ventilators", sa.Integer()),
        sa.Column("data_source", sa.String(40), nullable=False),
        sa.Column("recorded_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        *_identity_columns(),
    )
    op.create_index(
        "ix_hospital_availability_snapshots_hospital_id",
        "hospital_availability_snapshots",
        ["hospital_id"],
    )
    op.create_index(
        "ix_hospital_availability_snapshots_recorded_at",
        "hospital_availability_snapshots",
        ["recorded_at"],
    )
    op.create_index(
        "ix_hospital_availability_snapshots_expires_at",
        "hospital_availability_snapshots",
        ["expires_at"],
    )
    op.create_index(
        "ix_hospital_availability_recent",
        "hospital_availability_snapshots",
        ["hospital_id", "recorded_at"],
    )

    op.create_table(
        "hospital_recommendations",
        sa.Column(
            "owner_user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "emergency_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("snakebite_emergencies.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "hospital_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("hospital_facilities.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("rank", sa.Integer(), nullable=False),
        sa.Column("distance_km", sa.Float(), nullable=False),
        sa.Column("score", sa.Float(), nullable=False),
        sa.Column("score_components", sa.JSON(), nullable=False),
        sa.Column("reasons", sa.JSON(), nullable=False),
        sa.Column("warnings", sa.JSON(), nullable=False),
        sa.Column("ruleset_version", sa.String(80), nullable=False),
        sa.Column("availability_recorded_at", sa.DateTime(timezone=True)),
        *_identity_columns(),
    )
    for column in ("owner_user_id", "emergency_id", "hospital_id"):
        op.create_index(
            f"ix_hospital_recommendations_{column}", "hospital_recommendations", [column]
        )
    op.create_index(
        "ix_hospital_recommendations_owner_created",
        "hospital_recommendations",
        ["owner_user_id", "created_at"],
    )

    op.create_table(
        "hospital_pre_alerts",
        sa.Column(
            "owner_user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "emergency_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("snakebite_emergencies.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "hospital_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("hospital_facilities.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("shared_payload", sa.JSON(), nullable=False),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("notice", sa.String(500), nullable=False),
        *_identity_columns(),
    )
    for column in ("owner_user_id", "emergency_id", "hospital_id", "status", "expires_at"):
        op.create_index(f"ix_hospital_pre_alerts_{column}", "hospital_pre_alerts", [column])
    op.create_index(
        "ix_hospital_pre_alerts_hospital_status",
        "hospital_pre_alerts",
        ["hospital_id", "status"],
    )

    op.create_table(
        "hospital_resource_requests",
        sa.Column(
            "owner_user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "pre_alert_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("hospital_pre_alerts.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "hospital_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("hospital_facilities.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("antivenom_readiness", sa.Boolean(), nullable=False),
        sa.Column("emergency_bed", sa.Boolean(), nullable=False),
        sa.Column("icu_readiness", sa.Boolean(), nullable=False),
        sa.Column("ventilator_readiness", sa.Boolean(), nullable=False),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("response_note", sa.String(500)),
        *_identity_columns(),
    )
    for column in ("owner_user_id", "pre_alert_id", "hospital_id", "status", "expires_at"):
        op.create_index(
            f"ix_hospital_resource_requests_{column}",
            "hospital_resource_requests",
            [column],
        )
    op.create_index(
        "ix_resource_requests_hospital_status",
        "hospital_resource_requests",
        ["hospital_id", "status"],
    )


def downgrade() -> None:
    op.drop_table("hospital_resource_requests")
    op.drop_table("hospital_pre_alerts")
    op.drop_table("hospital_recommendations")
    op.drop_table("hospital_availability_snapshots")
    op.drop_table("hospital_capabilities")
    op.drop_table("hospital_facilities")
