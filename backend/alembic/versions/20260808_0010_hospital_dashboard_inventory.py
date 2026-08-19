"""Add hospital dashboard claims, inbox decisions, and approved antivenom inventory."""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "20260808_0010"
down_revision: str | None = "20260808_0009"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("hospital_pre_alerts", sa.Column("response_note", sa.String(500)))
    op.add_column(
        "hospital_pre_alerts", sa.Column("responded_by_user_id", postgresql.UUID(as_uuid=True))
    )
    op.add_column("hospital_pre_alerts", sa.Column("responded_at", sa.DateTime(timezone=True)))
    op.create_foreign_key(
        "fk_pre_alert_responder",
        "hospital_pre_alerts",
        "users",
        ["responded_by_user_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index(
        "ix_hospital_pre_alerts_responded_by_user_id",
        "hospital_pre_alerts",
        ["responded_by_user_id"],
    )
    op.add_column(
        "hospital_resource_requests",
        sa.Column("responded_by_user_id", postgresql.UUID(as_uuid=True)),
    )
    op.add_column(
        "hospital_resource_requests", sa.Column("responded_at", sa.DateTime(timezone=True))
    )
    op.create_foreign_key(
        "fk_resource_request_responder",
        "hospital_resource_requests",
        "users",
        ["responded_by_user_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index(
        "ix_hospital_resource_requests_responded_by_user_id",
        "hospital_resource_requests",
        ["responded_by_user_id"],
    )

    op.create_table(
        "hospital_claim_requests",
        sa.Column("facility_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("requester_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("verification_method", sa.String(40), nullable=False),
        sa.Column("evidence_reference", sa.String(500), nullable=False),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("reviewer_user_id", postgresql.UUID(as_uuid=True)),
        sa.Column("review_note", sa.String(500)),
        sa.Column("reviewed_at", sa.DateTime(timezone=True)),
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.ForeignKeyConstraint(["facility_id"], ["hospital_facilities.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["requester_user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reviewer_user_id"], ["users.id"], ondelete="SET NULL"),
    )
    op.create_index(
        "ix_hospital_claim_requests_facility_id", "hospital_claim_requests", ["facility_id"]
    )
    op.create_index(
        "ix_hospital_claim_requests_requester_user_id",
        "hospital_claim_requests",
        ["requester_user_id"],
    )
    op.create_index(
        "ix_hospital_claim_requests_reviewer_user_id",
        "hospital_claim_requests",
        ["reviewer_user_id"],
    )
    op.create_index("ix_hospital_claim_requests_status", "hospital_claim_requests", ["status"])
    op.create_index(
        "ix_hospital_claim_facility_status", "hospital_claim_requests", ["facility_id", "status"]
    )
    op.create_index(
        "uq_hospital_claim_pending_facility",
        "hospital_claim_requests",
        ["facility_id"],
        unique=True,
        postgresql_where=sa.text("status = 'pending'"),
    )

    op.create_table(
        "antivenom_boxes",
        sa.Column("facility_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("created_by_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("box_serial", sa.String(120), nullable=False),
        sa.Column("product_name", sa.String(240), nullable=False),
        sa.Column("manufacturer", sa.String(240), nullable=False),
        sa.Column("batch_number", sa.String(120), nullable=False),
        sa.Column("expiry_date", sa.Date(), nullable=False),
        sa.Column("initial_vials", sa.Integer(), nullable=False),
        sa.Column("available_vials", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("qr_token_hash", sa.String(64), nullable=False),
        sa.Column("depleted_at", sa.DateTime(timezone=True)),
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.ForeignKeyConstraint(["facility_id"], ["hospital_facilities.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["created_by_user_id"], ["users.id"], ondelete="RESTRICT"),
        sa.UniqueConstraint("facility_id", "box_serial", name="uq_antivenom_box_facility_serial"),
        sa.UniqueConstraint("qr_token_hash"),
    )
    op.create_index("ix_antivenom_boxes_facility_id", "antivenom_boxes", ["facility_id"])
    op.create_index(
        "ix_antivenom_boxes_created_by_user_id", "antivenom_boxes", ["created_by_user_id"]
    )
    op.create_index("ix_antivenom_boxes_batch_number", "antivenom_boxes", ["batch_number"])
    op.create_index("ix_antivenom_boxes_expiry_date", "antivenom_boxes", ["expiry_date"])
    op.create_index("ix_antivenom_boxes_status", "antivenom_boxes", ["status"])
    op.create_index(
        "ix_antivenom_boxes_qr_token_hash", "antivenom_boxes", ["qr_token_hash"], unique=True
    )
    op.create_index(
        "ix_antivenom_box_facility_status_expiry",
        "antivenom_boxes",
        ["facility_id", "status", "expiry_date"],
    )

    op.create_table(
        "antivenom_depletion_requests",
        sa.Column("box_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("facility_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("scanned_by_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("requested_used_vials", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("reviewer_user_id", postgresql.UUID(as_uuid=True)),
        sa.Column("review_note", sa.String(500)),
        sa.Column("reviewed_at", sa.DateTime(timezone=True)),
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.ForeignKeyConstraint(["box_id"], ["antivenom_boxes.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["facility_id"], ["hospital_facilities.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["scanned_by_user_id"], ["users.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["reviewer_user_id"], ["users.id"], ondelete="SET NULL"),
    )
    for column in ("box_id", "facility_id", "scanned_by_user_id", "status", "reviewer_user_id"):
        op.create_index(
            f"ix_antivenom_depletion_requests_{column}", "antivenom_depletion_requests", [column]
        )
    op.create_index(
        "ix_depletion_facility_status", "antivenom_depletion_requests", ["facility_id", "status"]
    )
    op.create_index(
        "uq_depletion_pending_box",
        "antivenom_depletion_requests",
        ["box_id"],
        unique=True,
        postgresql_where=sa.text("status = 'pending'"),
    )

    op.create_table(
        "hospital_audit_events",
        sa.Column("facility_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("actor_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("event_type", sa.String(80), nullable=False),
        sa.Column("entity_id", postgresql.UUID(as_uuid=True)),
        sa.Column(
            "details",
            sa.JSON().with_variant(postgresql.JSONB(astext_type=sa.Text()), "postgresql"),
            nullable=False,
        ),
        sa.Column("note", sa.Text()),
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.ForeignKeyConstraint(["facility_id"], ["hospital_facilities.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"], ondelete="RESTRICT"),
    )
    for column in ("facility_id", "actor_user_id", "event_type"):
        op.create_index(f"ix_hospital_audit_events_{column}", "hospital_audit_events", [column])
    op.create_index(
        "ix_hospital_audit_facility_created", "hospital_audit_events", ["facility_id", "created_at"]
    )


def downgrade() -> None:
    op.drop_table("hospital_audit_events")
    op.drop_table("antivenom_depletion_requests")
    op.drop_table("antivenom_boxes")
    op.drop_table("hospital_claim_requests")
    op.drop_index(
        "ix_hospital_resource_requests_responded_by_user_id",
        table_name="hospital_resource_requests",
    )
    op.drop_constraint(
        "fk_resource_request_responder", "hospital_resource_requests", type_="foreignkey"
    )
    op.drop_column("hospital_resource_requests", "responded_at")
    op.drop_column("hospital_resource_requests", "responded_by_user_id")
    op.drop_index("ix_hospital_pre_alerts_responded_by_user_id", table_name="hospital_pre_alerts")
    op.drop_constraint("fk_pre_alert_responder", "hospital_pre_alerts", type_="foreignkey")
    op.drop_column("hospital_pre_alerts", "responded_at")
    op.drop_column("hospital_pre_alerts", "responded_by_user_id")
    op.drop_column("hospital_pre_alerts", "response_note")
