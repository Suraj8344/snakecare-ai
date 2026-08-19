from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, File, Form, UploadFile, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import FileResponse
from pydantic import ValidationError

from app.modules.auth.dependencies import CurrentUser
from app.modules.snakebite_emergency.dependencies import (
    SnakebiteEmergencyServiceDependency,
)
from app.modules.snakebite_emergency.schemas import (
    EmergencyCreate,
    EmergencyList,
    EmergencyView,
)

router = APIRouter(prefix="/snakebite-emergencies", tags=["snakebite-emergencies"])


@router.post("", response_model=EmergencyView, status_code=status.HTTP_201_CREATED)
async def create_emergency(
    service: SnakebiteEmergencyServiceDependency,
    current_user: CurrentUser,
    payload: Annotated[str, Form()],
    photo: Annotated[UploadFile | None, File()] = None,
) -> EmergencyView:
    try:
        case_input = EmergencyCreate.model_validate_json(payload)
    except ValidationError as exc:
        safe_errors = exc.errors(include_context=False, include_url=False)
        raise RequestValidationError(safe_errors) from exc
    photo_content = await photo.read() if photo else None
    emergency = await service.create(
        current_user,
        case_input,
        photo_filename=photo.filename if photo else None,
        photo_content=photo_content,
    )
    return EmergencyView.model_validate(emergency)


@router.get("", response_model=EmergencyList)
async def list_emergencies(
    service: SnakebiteEmergencyServiceDependency,
    current_user: CurrentUser,
) -> EmergencyList:
    items, total = await service.list(current_user)
    return EmergencyList(items=[EmergencyView.model_validate(item) for item in items], total=total)


@router.get("/{emergency_id}", response_model=EmergencyView)
async def get_emergency(
    emergency_id: UUID,
    service: SnakebiteEmergencyServiceDependency,
    current_user: CurrentUser,
) -> EmergencyView:
    return EmergencyView.model_validate(await service.get(current_user, emergency_id))


@router.get("/{emergency_id}/photo", response_class=FileResponse)
async def get_emergency_photo(
    emergency_id: UUID,
    service: SnakebiteEmergencyServiceDependency,
    current_user: CurrentUser,
) -> FileResponse:
    emergency, path = await service.photo_path(current_user, emergency_id)
    return FileResponse(
        path,
        media_type=emergency.photo_content_type,
        filename=emergency.photo_original_filename or "snakebite-photo",
    )
