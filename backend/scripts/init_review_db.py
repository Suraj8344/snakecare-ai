"""Create the current portable schema for the local browser review server."""

from __future__ import annotations

import asyncio

from sqlalchemy.ext.asyncio import create_async_engine

from app.infrastructure.database import models as infrastructure_models  # noqa: F401
from app.infrastructure.database.base import Base
from app.modules.auth import models as auth_models  # noqa: F401
from app.modules.emergency_handoff import models as handoff_models  # noqa: F401
from app.modules.hospital_coordination import models as coordination_models  # noqa: F401
from app.modules.hospital_dashboard import models as dashboard_models  # noqa: F401
from app.modules.medical_passport import models as passport_models  # noqa: F401
from app.modules.medical_reports import models as report_models  # noqa: F401
from app.modules.snakebite_emergency import models as emergency_models  # noqa: F401


async def main() -> None:
    engine = create_async_engine("sqlite+aiosqlite:///./var/snakecare-review3.db")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
