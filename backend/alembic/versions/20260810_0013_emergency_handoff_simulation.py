"""Add safety-gated emergency handoff simulation."""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "20260810_0013"
down_revision: str | None = "20260810_0012"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "emergency_handoffs",
        sa.Column("owner_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("emergency_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("simulation_only", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("status", sa.String(32), nullable=False),
        sa.Column("response_status", sa.String(24), nullable=False),
        sa.Column("countdown_seconds", sa.Integer(), nullable=False),
        sa.Column("consent_identity", sa.Boolean(), nullable=False),
        sa.Column("consent_location", sa.Boolean(), nullable=False),
        sa.Column("consent_emergency_summary", sa.Boolean(), nullable=False),
        sa.Column("consent_medical_passport", sa.Boolean(), nullable=False),
        sa.Column("consent_voice_assistance", sa.Boolean(), nullable=False),
        sa.Column(
            "structured_summary",
            sa.JSON().with_variant(postgresql.JSONB(astext_type=sa.Text()), "postgresql"),
            nullable=False,
        ),
        sa.Column("countdown_started_at", sa.DateTime(timezone=True)),
        sa.Column("cancelled_at", sa.DateTime(timezone=True)),
        sa.Column("manual_call_requested_at", sa.DateTime(timezone=True)),
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.ForeignKeyConstraint(["owner_user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["emergency_id"], ["snakebite_emergencies.id"], ondelete="CASCADE"
        ),
        sa.CheckConstraint(
            "countdown_seconds >= 10 AND countdown_seconds <= 30",
            name="ck_emergency_handoffs_countdown",
        ),
        sa.CheckConstraint("simulation_only = true", name="ck_emergency_handoffs_simulation"),
    )
    op.create_index("ix_emergency_handoffs_owner_user_id", "emergency_handoffs", ["owner_user_id"])
    op.create_index("ix_emergency_handoffs_emergency_id", "emergency_handoffs", ["emergency_id"])
    op.create_index("ix_emergency_handoffs_status", "emergency_handoffs", ["status"])
    op.create_index(
        "ix_emergency_handoffs_owner_created",
        "emergency_handoffs",
        ["owner_user_id", "created_at"],
    )

    op.create_table(
        "emergency_handoff_events",
        sa.Column("handoff_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("actor_user_id", postgresql.UUID(as_uuid=True)),
        sa.Column("event_type", sa.String(64), nullable=False),
        sa.Column("outcome", sa.String(24), nullable=False),
        sa.Column(
            "safe_details",
            sa.JSON().with_variant(postgresql.JSONB(astext_type=sa.Text()), "postgresql"),
            nullable=False,
            server_default=sa.text("'{}'"),
        ),
        sa.Column("message", sa.Text()),
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.ForeignKeyConstraint(["handoff_id"], ["emergency_handoffs.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"], ondelete="SET NULL"),
    )
    op.create_index(
        "ix_emergency_handoff_events_handoff_id", "emergency_handoff_events", ["handoff_id"]
    )
    op.create_index(
        "ix_emergency_handoff_events_actor_user_id",
        "emergency_handoff_events",
        ["actor_user_id"],
    )
    op.create_index(
        "ix_emergency_handoff_events_event_type", "emergency_handoff_events", ["event_type"]
    )
    op.create_index(
        "ix_emergency_handoff_events_handoff_created",
        "emergency_handoff_events",
        ["handoff_id", "created_at"],
    )


def downgrade() -> None:
    op.drop_table("emergency_handoff_events")
    op.drop_table("emergency_handoffs")
