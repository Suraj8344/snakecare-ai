"""Hospital-approved driver memberships and private active-trip GPS."""

import sqlalchemy as sa
from alembic import op

revision = "20260908_0014"
down_revision = "20260810_0013"
branch_labels = None
depends_on = None


def common():
    return [
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    ]


def upgrade():
    op.create_table(
        "tracking_driver_registrations",
        *common(),
        sa.Column("user_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False, unique=True),
        sa.Column(
            "hospital_id", sa.Uuid(), sa.ForeignKey("hospital_facilities.id"), nullable=False
        ),
        sa.Column("driver_name", sa.String(120), nullable=False),
        sa.Column("vehicle_number", sa.String(32), nullable=False),
        sa.Column("verification_reference", sa.String(120), nullable=False),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("reviewed_by", sa.Uuid(), sa.ForeignKey("users.id")),
    )
    op.create_index(
        "ix_tracking_driver_registrations_hospital_id",
        "tracking_driver_registrations",
        ["hospital_id"],
    )
    op.create_table(
        "tracking_trips",
        *common(),
        sa.Column("patient_id", sa.Uuid(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column(
            "hospital_id", sa.Uuid(), sa.ForeignKey("hospital_facilities.id"), nullable=False
        ),
        sa.Column("driver_id", sa.Uuid(), sa.ForeignKey("tracking_driver_registrations.id")),
        sa.Column("status", sa.String(24), nullable=False),
        *[
            sa.Column(n, sa.Float())
            for n in ["pickup_latitude", "pickup_longitude", "latitude", "longitude", "accuracy_m"]
        ],
        sa.Column("captured_at", sa.DateTime(timezone=True)),
        sa.Column("received_at", sa.DateTime(timezone=True)),
    )
    for name in ["patient_id", "hospital_id"]:
        op.create_index(f"ix_tracking_trips_{name}", "tracking_trips", [name])
    for name in ["patient", "driver"]:
        op.create_index(
            f"uq_tracking_active_{name}",
            "tracking_trips",
            [f"{name}_id"],
            unique=True,
            postgresql_where=sa.text("status NOT IN ('completed','cancelled')"),
            sqlite_where=sa.text("status NOT IN ('completed','cancelled')"),
        )


def downgrade():
    op.drop_table("tracking_trips")
    op.drop_table("tracking_driver_registrations")
