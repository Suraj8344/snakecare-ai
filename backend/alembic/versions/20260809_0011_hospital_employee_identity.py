"""Add server-controlled hospital employee identities."""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260809_0011"
down_revision: str | None = "20260808_0010"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("users", sa.Column("hospital_employee_id", sa.String(64)))
    op.create_index(
        "ix_users_hospital_employee_id",
        "users",
        ["hospital_employee_id"],
        unique=True,
    )
    op.create_check_constraint(
        "ck_users_hospital_employee_role",
        "users",
        "hospital_employee_id IS NULL OR role = 'hospital_admin'",
    )


def downgrade() -> None:
    op.drop_constraint("ck_users_hospital_employee_role", "users", type_="check")
    op.drop_index("ix_users_hospital_employee_id", table_name="users")
    op.drop_column("users", "hospital_employee_id")
