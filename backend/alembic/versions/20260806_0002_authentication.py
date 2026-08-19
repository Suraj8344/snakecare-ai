"""Create authentication and RBAC tables."""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "20260806_0002"
down_revision: str | None = "20260806_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("firebase_uid", sa.String(128), nullable=False),
        sa.Column("email", sa.String(320)),
        sa.Column("email_verified", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("phone_number", sa.String(32)),
        sa.Column("display_name", sa.String(160)),
        sa.Column("role", sa.String(32), nullable=False, server_default="patient"),
        sa.Column("status", sa.String(16), nullable=False, server_default="active"),
        sa.Column("last_login_at", sa.DateTime(timezone=True)),
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
            "role IN ('patient','doctor','hospital_admin','government_admin')",
            name="ck_users_role",
        ),
        sa.CheckConstraint("status IN ('active','disabled')", name="ck_users_status"),
        sa.UniqueConstraint("firebase_uid"),
        sa.UniqueConstraint("email"),
        sa.UniqueConstraint("phone_number"),
    )
    for column in ("firebase_uid", "email", "phone_number"):
        op.create_index(f"ix_users_{column}", "users", [column])

    op.create_table(
        "refresh_sessions",
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("token_hash", sa.String(64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True)),
        sa.Column("replaced_by_hash", sa.String(64)),
        sa.Column("client_fingerprint", sa.String(64)),
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
        sa.UniqueConstraint("token_hash"),
    )
    for column in ("user_id", "token_hash", "expires_at", "revoked_at"):
        op.create_index(f"ix_refresh_sessions_{column}", "refresh_sessions", [column])

    op.create_table(
        "auth_audit_events",
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
        ),
        sa.Column("event_type", sa.String(64), nullable=False),
        sa.Column("outcome", sa.String(16), nullable=False),
        sa.Column("request_id", sa.String(128)),
        sa.Column(
            "details",
            sa.JSON().with_variant(postgresql.JSONB(), "postgresql"),
            nullable=False,
            server_default="{}",
        ),
        sa.Column("message", sa.Text()),
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
    )
    for column in ("user_id", "event_type", "request_id"):
        op.create_index(f"ix_auth_audit_events_{column}", "auth_audit_events", [column])


def downgrade() -> None:
    op.drop_table("auth_audit_events")
    op.drop_table("refresh_sessions")
    op.drop_table("users")
