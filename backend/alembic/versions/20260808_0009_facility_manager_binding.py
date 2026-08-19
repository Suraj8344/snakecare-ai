"""Bind self-published facilities to their managing account."""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "20260808_0009"
down_revision: str | None = "20260808_0008"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "hospital_facilities",
        sa.Column("managed_by_user_id", postgresql.UUID(as_uuid=True)),
    )
    op.create_foreign_key(
        "fk_hospital_facilities_manager",
        "hospital_facilities",
        "users",
        ["managed_by_user_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index(
        "ix_hospital_facilities_managed_by_user_id",
        "hospital_facilities",
        ["managed_by_user_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_hospital_facilities_managed_by_user_id",
        table_name="hospital_facilities",
    )
    op.drop_constraint(
        "fk_hospital_facilities_manager",
        "hospital_facilities",
        type_="foreignkey",
    )
    op.drop_column("hospital_facilities", "managed_by_user_id")
