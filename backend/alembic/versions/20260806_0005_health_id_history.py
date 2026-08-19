"""Add Health ID, surgeries, and family history."""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "20260806_0005"
down_revision: str | None = "20260806_0004"
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
    op.add_column(
        "medical_passports",
        sa.Column("health_id", postgresql.UUID(as_uuid=True), nullable=True),
    )
    if op.get_bind().dialect.name == "postgresql":
        op.execute("UPDATE medical_passports SET health_id = gen_random_uuid()")
        op.alter_column("medical_passports", "health_id", nullable=False)
    op.create_index(
        "ix_medical_passports_health_id",
        "medical_passports",
        ["health_id"],
        unique=True,
    )

    op.create_table(
        "passport_surgeries",
        sa.Column(
            "passport_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("medical_passports.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("procedure", sa.String(160), nullable=False),
        sa.Column("performed_on", sa.Date()),
        sa.Column("hospital", sa.String(160)),
        sa.Column("notes", sa.Text()),
        *identifiers(),
    )
    op.create_index("ix_passport_surgeries_passport_id", "passport_surgeries", ["passport_id"])

    op.create_table(
        "passport_family_history",
        sa.Column(
            "passport_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("medical_passports.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("relationship", sa.String(80), nullable=False),
        sa.Column("condition", sa.String(160), nullable=False),
        sa.Column("notes", sa.Text()),
        *identifiers(),
    )
    op.create_index(
        "ix_passport_family_history_passport_id",
        "passport_family_history",
        ["passport_id"],
    )


def downgrade() -> None:
    op.drop_table("passport_family_history")
    op.drop_table("passport_surgeries")
    op.drop_index("ix_medical_passports_health_id", table_name="medical_passports")
    op.drop_column("medical_passports", "health_id")
