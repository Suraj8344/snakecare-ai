"""Create snakebite emergency decision-support cases."""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "20260806_0007"
down_revision: str | None = "20260806_0006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "snakebite_emergencies",
        sa.Column(
            "owner_user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("occurred_at", sa.DateTime(timezone=True)),
        sa.Column("patient_age_years", sa.Integer()),
        sa.Column("bite_site", sa.String(32), nullable=False),
        sa.Column("symptoms", sa.JSON(), nullable=False),
        sa.Column("symptom_notes", sa.Text()),
        sa.Column("voice_transcript", sa.Text()),
        sa.Column("latitude", sa.Float()),
        sa.Column("longitude", sa.Float()),
        sa.Column("location_accuracy_m", sa.Float()),
        sa.Column("location_label", sa.String(300)),
        sa.Column("pulse_bpm", sa.Integer()),
        sa.Column("respiratory_rate", sa.Integer()),
        sa.Column("oxygen_saturation", sa.Integer()),
        sa.Column("systolic_bp", sa.Integer()),
        sa.Column("diastolic_bp", sa.Integer()),
        sa.Column("temperature_c", sa.Float()),
        sa.Column("consciousness", sa.String(32), nullable=False),
        sa.Column("photo_storage_key", sa.String(160), unique=True),
        sa.Column("photo_original_filename", sa.String(255)),
        sa.Column("photo_content_type", sa.String(80)),
        sa.Column("photo_size_bytes", sa.BigInteger()),
        sa.Column("photo_sha256", sa.String(64)),
        sa.Column("urgency", sa.String(32), nullable=False),
        sa.Column("explanation", sa.JSON(), nullable=False),
        sa.Column("immediate_actions", sa.JSON(), nullable=False),
        sa.Column("first_aid_steps", sa.JSON(), nullable=False),
        sa.Column("actions_to_avoid", sa.JSON(), nullable=False),
        sa.Column("ruleset_version", sa.String(80), nullable=False),
        sa.Column("guidance_version", sa.String(80), nullable=False),
        sa.Column("assessment_notice", sa.String(500), nullable=False),
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
        sa.CheckConstraint(
            "urgency IN ('critical','high_risk','urgent_assessment')",
            name="ck_snakebite_emergencies_urgency",
        ),
        sa.CheckConstraint(
            "consciousness IN ('alert','responds_to_voice','responds_to_pain','unresponsive')",
            name="ck_snakebite_emergencies_consciousness",
        ),
        sa.CheckConstraint(
            "patient_age_years IS NULL OR patient_age_years BETWEEN 0 AND 120",
            name="ck_snakebite_emergencies_age",
        ),
    )
    op.create_index(
        "ix_snakebite_emergencies_owner_user_id",
        "snakebite_emergencies",
        ["owner_user_id"],
    )
    op.create_index(
        "ix_snakebite_emergencies_occurred_at",
        "snakebite_emergencies",
        ["occurred_at"],
    )
    op.create_index(
        "ix_snakebite_emergencies_urgency",
        "snakebite_emergencies",
        ["urgency"],
    )
    op.create_index(
        "ix_snakebite_emergencies_owner_created",
        "snakebite_emergencies",
        ["owner_user_id", "created_at"],
    )
    op.create_index(
        "ix_snakebite_emergencies_owner_urgency",
        "snakebite_emergencies",
        ["owner_user_id", "urgency"],
    )


def downgrade() -> None:
    op.drop_table("snakebite_emergencies")
