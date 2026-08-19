from typing import Annotated

from fastapi import Depends, Request

from app.api.dependencies import DatabaseSession
from app.modules.snakebite_emergency.engine import SnakebiteDecisionEngine
from app.modules.snakebite_emergency.repository import (
    SqlAlchemySnakebiteEmergencyRepository,
)
from app.modules.snakebite_emergency.service import SnakebiteEmergencyService
from app.modules.snakebite_emergency.storage import EmergencyPhotoStorage


def get_snakebite_emergency_service(
    request: Request, session: DatabaseSession
) -> SnakebiteEmergencyService:
    settings = request.app.state.settings
    return SnakebiteEmergencyService(
        repository=SqlAlchemySnakebiteEmergencyRepository(session),
        storage=EmergencyPhotoStorage(settings.snakebite_photo_storage_path),
        engine=SnakebiteDecisionEngine(),
        max_photo_bytes=settings.snakebite_photo_max_upload_bytes,
    )


SnakebiteEmergencyServiceDependency = Annotated[
    SnakebiteEmergencyService, Depends(get_snakebite_emergency_service)
]
