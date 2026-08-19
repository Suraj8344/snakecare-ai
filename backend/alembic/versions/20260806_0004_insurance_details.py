"""Add patient-reported insurance details to Medical Passports."""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260806_0004"
down_revision: str | None = "20260806_0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    columns = (
        sa.Column("insurance_provider", sa.String(160)),
        sa.Column("insurance_policy_number", sa.String(120)),
        sa.Column("insurance_member_id", sa.String(120)),
        sa.Column("insurance_group_number", sa.String(120)),
        sa.Column("insurance_plan_name", sa.String(160)),
        sa.Column("insurance_valid_through", sa.Date()),
        sa.Column("insurance_emergency_phone", sa.String(32)),
    )
    for column in columns:
        op.add_column("medical_passports", column)


def downgrade() -> None:
    for column in (
        "insurance_emergency_phone",
        "insurance_valid_through",
        "insurance_plan_name",
        "insurance_group_number",
        "insurance_member_id",
        "insurance_policy_number",
        "insurance_provider",
    ):
        op.drop_column("medical_passports", column)
