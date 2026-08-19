from __future__ import annotations

import asyncio
from logging.config import fileConfig

from sqlalchemy import pool
from sqlalchemy.ext.asyncio import async_engine_from_config

from alembic import context
from app.core.config import get_settings
from app.infrastructure.database.base import Base
from app.infrastructure.database.models import SystemMetadata  # noqa: F401
from app.modules.auth.models import AuthAuditEvent, RefreshSession, User  # noqa: F401
from app.modules.emergency_handoff import models as emergency_handoff_models  # noqa: F401
from app.modules.hospital_coordination import models as hospital_models  # noqa: F401
from app.modules.hospital_dashboard import models as hospital_dashboard_models  # noqa: F401
from app.modules.medical_passport import models as medical_passport_models  # noqa: F401
from app.modules.medical_reports import models as medical_report_models  # noqa: F401
from app.modules.snakebite_emergency import models as snakebite_models  # noqa: F401

config = context.config
if config.config_file_name:
    fileConfig(config.config_file_name)

config.set_main_option("sqlalchemy.url", get_settings().database_url)
target_metadata = Base.metadata


def run_migrations_offline() -> None:
    context.configure(
        url=config.get_main_option("sqlalchemy.url"),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection: object) -> None:
    context.configure(connection=connection, target_metadata=target_metadata, compare_type=True)
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_async_migrations())
