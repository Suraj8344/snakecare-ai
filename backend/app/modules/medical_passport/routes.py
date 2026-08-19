from uuid import UUID

from fastapi import APIRouter, Request, status

from app.modules.auth.dependencies import CurrentUser
from app.modules.medical_passport.dependencies import MedicalPassportServiceDependency
from app.modules.medical_passport.schemas import (
    GrantCreate,
    GrantView,
    PassportUpdate,
    PassportView,
)

router = APIRouter(tags=["medical-passport"])


def request_id(request: Request) -> str | None:
    return getattr(request.state, "request_id", None)


@router.get("/medical-passport/me", response_model=PassportView)
async def get_own_passport(
    service: MedicalPassportServiceDependency, current_user: CurrentUser
) -> PassportView:
    return PassportView.model_validate(await service.get_own(current_user))


@router.put("/medical-passport/me", response_model=PassportView)
async def update_own_passport(
    payload: PassportUpdate,
    service: MedicalPassportServiceDependency,
    current_user: CurrentUser,
) -> PassportView:
    return PassportView.model_validate(await service.update_own(current_user, payload))


@router.get("/medical-passports/{patient_id}", response_model=PassportView)
async def read_patient_passport(
    patient_id: UUID,
    request: Request,
    service: MedicalPassportServiceDependency,
    current_user: CurrentUser,
) -> PassportView:
    passport = await service.read_patient(current_user, patient_id, request_id(request))
    return PassportView.model_validate(passport)


@router.get("/medical-passport/access-grants", response_model=list[GrantView])
async def list_access_grants(
    service: MedicalPassportServiceDependency, current_user: CurrentUser
) -> list[GrantView]:
    return [GrantView.model_validate(item) for item in await service.list_grants(current_user)]


@router.post(
    "/medical-passport/access-grants",
    response_model=GrantView,
    status_code=status.HTTP_201_CREATED,
)
async def create_access_grant(
    payload: GrantCreate,
    request: Request,
    service: MedicalPassportServiceDependency,
    current_user: CurrentUser,
) -> GrantView:
    grant = await service.grant_access(current_user, payload, request_id(request))
    return GrantView.model_validate(grant)


@router.delete(
    "/medical-passport/access-grants/{grant_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def revoke_access_grant(
    grant_id: UUID,
    request: Request,
    service: MedicalPassportServiceDependency,
    current_user: CurrentUser,
) -> None:
    await service.revoke_grant(current_user, grant_id, request_id(request))
