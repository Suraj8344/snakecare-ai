"""Create private Medical Reports metadata."""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "20260806_0006"
down_revision: str | None = "20260806_0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "medical_reports",
        sa.Column(
            "owner_user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("category", sa.String(40), nullable=False, server_default="other"),
        sa.Column("report_date", sa.Date()),
        sa.Column("provider_name", sa.String(200)),
        sa.Column("notes", sa.Text()),
        sa.Column("original_filename", sa.String(255), nullable=False),
        sa.Column("storage_key", sa.String(160), nullable=False, unique=True),
        sa.Column("content_type", sa.String(80), nullable=False),
        sa.Column("size_bytes", sa.BigInteger(), nullable=False),
        sa.Column("sha256", sa.String(64), nullable=False),
        sa.Column("status", sa.String(24), nullable=False, server_default="processing"),
        sa.Column("extracted_text", sa.Text()),
        sa.Column("ocr_engine", sa.String(80)),
        sa.Column("ocr_confidence", sa.String(24)),
        sa.Column("automated_summary", sa.Text()),
        sa.Column("summary_method", sa.String(80)),
        sa.Column("summary_generated_at", sa.DateTime(timezone=True)),
        sa.Column("processing_error", sa.String(500)),
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
            "category IN ('lab_result','prescription','imaging','discharge_summary',"
            "'vaccination','insurance','surgery','other')",
            name="ck_medical_reports_category",
        ),
        sa.CheckConstraint(
            "status IN ('processing','ready','failed')",
            name="ck_medical_reports_status",
        ),
        sa.CheckConstraint("size_bytes > 0", name="ck_medical_reports_size"),
    )
    for column in (
        "owner_user_id",
        "category",
        "report_date",
        "content_type",
        "sha256",
        "status",
    ):
        op.create_index(f"ix_medical_reports_{column}", "medical_reports", [column])
    op.create_index(
        "ix_medical_reports_owner_date",
        "medical_reports",
        ["owner_user_id", "report_date"],
    )
    op.create_index(
        "ix_medical_reports_owner_category",
        "medical_reports",
        ["owner_user_id", "category"],
    )
    op.create_index(
        "ix_medical_reports_owner_status",
        "medical_reports",
        ["owner_user_id", "status"],
    )


def downgrade() -> None:
    op.drop_table("medical_reports")
