"""Create patient Medical Passport tables."""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "20260806_0003"
down_revision: str | None = "20260806_0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def identifiers() -> list[sa.Column[object]]:
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
        "medical_passports",
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("full_name", sa.String(160)),
        sa.Column("date_of_birth", sa.Date()),
        sa.Column("biological_sex", sa.String(20), nullable=False, server_default="not_disclosed"),
        sa.Column("blood_group", sa.String(10), nullable=False, server_default="unknown"),
        sa.Column("height_cm", sa.Numeric(5, 2)),
        sa.Column("weight_kg", sa.Numeric(6, 2)),
        sa.Column("preferred_language", sa.String(50)),
        sa.Column("organ_donor", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        *identifiers(),
        sa.CheckConstraint("version >= 1", name="ck_medical_passports_version"),
        sa.CheckConstraint(
            "height_cm IS NULL OR (height_cm >= 30 AND height_cm <= 275)",
            name="ck_medical_passports_height",
        ),
        sa.CheckConstraint(
            "weight_kg IS NULL OR (weight_kg >= 1 AND weight_kg <= 700)",
            name="ck_medical_passports_weight",
        ),
        sa.CheckConstraint(
            "biological_sex IN ('female','male','intersex','unknown','not_disclosed')",
            name="ck_medical_passports_sex",
        ),
        sa.CheckConstraint(
            "blood_group IN ('A+','A-','B+','B-','AB+','AB-','O+','O-','unknown')",
            name="ck_medical_passports_blood_group",
        ),
        sa.UniqueConstraint("user_id"),
    )
    op.create_index("ix_medical_passports_user_id", "medical_passports", ["user_id"])

    child_specs = {
        "passport_allergies": [
            sa.Column("allergen", sa.String(120), nullable=False),
            sa.Column("reaction", sa.String(250)),
            sa.Column("severity", sa.String(16), nullable=False, server_default="unknown"),
            sa.CheckConstraint(
                "severity IN ('mild','moderate','severe','unknown')",
                name="ck_passport_allergies_severity",
            ),
        ],
        "passport_conditions": [
            sa.Column("name", sa.String(160), nullable=False),
            sa.Column("status", sa.String(16), nullable=False, server_default="active"),
            sa.Column("diagnosed_on", sa.Date()),
            sa.Column("notes", sa.Text()),
            sa.CheckConstraint(
                "status IN ('active','resolved','unknown')", name="ck_passport_conditions_status"
            ),
        ],
        "passport_medications": [
            sa.Column("name", sa.String(160), nullable=False),
            sa.Column("dosage", sa.String(80)),
            sa.Column("frequency", sa.String(80)),
            sa.Column("route", sa.String(60)),
            sa.Column("notes", sa.Text()),
        ],
        "passport_emergency_contacts": [
            sa.Column("name", sa.String(160), nullable=False),
            sa.Column("relationship", sa.String(80), nullable=False),
            sa.Column("phone_number", sa.String(32), nullable=False),
            sa.Column("priority", sa.Integer(), nullable=False, server_default="1"),
            sa.CheckConstraint(
                "priority >= 1 AND priority <= 5", name="ck_passport_contacts_priority"
            ),
        ],
    }
    for table, columns in child_specs.items():
        op.create_table(
            table,
            sa.Column(
                "passport_id",
                postgresql.UUID(as_uuid=True),
                sa.ForeignKey("medical_passports.id", ondelete="CASCADE"),
                nullable=False,
            ),
            *columns,
            *identifiers(),
        )
        op.create_index(f"ix_{table}_passport_id", table, ["passport_id"])

    op.create_table(
        "passport_access_grants",
        sa.Column(
            "patient_user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "grantee_user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True)),
        *identifiers(),
        sa.UniqueConstraint("patient_user_id", "grantee_user_id", name="uq_passport_grant_pair"),
        sa.CheckConstraint(
            "patient_user_id <> grantee_user_id", name="ck_passport_grant_distinct_users"
        ),
    )
    for column in ("patient_user_id", "grantee_user_id", "expires_at", "revoked_at"):
        op.create_index(f"ix_passport_access_grants_{column}", "passport_access_grants", [column])

    op.create_table(
        "passport_access_events",
        sa.Column(
            "actor_user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
        ),
        sa.Column(
            "patient_user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
        ),
        sa.Column("action", sa.String(40), nullable=False),
        sa.Column("outcome", sa.String(16), nullable=False),
        sa.Column("request_id", sa.String(128)),
        *identifiers(),
    )
    for column in ("actor_user_id", "patient_user_id", "action", "request_id"):
        op.create_index(f"ix_passport_access_events_{column}", "passport_access_events", [column])


def downgrade() -> None:
    for table in (
        "passport_access_events",
        "passport_access_grants",
        "passport_emergency_contacts",
        "passport_medications",
        "passport_conditions",
        "passport_allergies",
        "medical_passports",
    ):
        op.drop_table(table)
