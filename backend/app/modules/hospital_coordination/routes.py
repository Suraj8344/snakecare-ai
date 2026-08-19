from uuid import UUID

from fastapi import APIRouter, Query, status

from app.modules.auth.dependencies import CurrentUser
from app.modules.hospital_coordination.dependencies import (
    HospitalCoordinationServiceDependency,
)
from app.modules.hospital_coordination.schemas import (
    AvailabilityCreate,
    AvailabilityView,
    FacilityCreate,
    FacilityDirectoryResponse,
    FacilityView,
    PreAlertCreate,
    PreAlertView,
    RecommendationCreate,
    RecommendationResponse,
    ResourceRequestCreate,
    ResourceRequestView,
)

router = APIRouter(prefix="/hospital-coordination", tags=["hospital-coordination"])


@router.get("/facilities", response_model=FacilityDirectoryResponse)
async def list_facilities(
    service: HospitalCoordinationServiceDependency,
    current_user: CurrentUser,
    city: str = Query(default="Pune", min_length=2, max_length=120),
    search: str | None = Query(default=None, min_length=2, max_length=120),
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> FacilityDirectoryResponse:
    del current_user
    return await service.facility_directory(city=city, search=search, limit=limit, offset=offset)


@router.post("/facilities", response_model=FacilityView, status_code=status.HTTP_201_CREATED)
async def create_facility(
    payload: FacilityCreate,
    service: HospitalCoordinationServiceDependency,
    current_user: CurrentUser,
) -> FacilityView:
    return await service.create_facility(current_user, payload)


@router.post(
    "/facilities/{hospital_id}/availability",
    response_model=AvailabilityView,
    status_code=status.HTTP_201_CREATED,
)
async def record_availability(
    hospital_id: UUID,
    payload: AvailabilityCreate,
    service: HospitalCoordinationServiceDependency,
    current_user: CurrentUser,
) -> AvailabilityView:
    return await service.record_availability(current_user, hospital_id, payload)


@router.post("/recommendations", response_model=RecommendationResponse)
async def recommend_hospitals(
    payload: RecommendationCreate,
    service: HospitalCoordinationServiceDependency,
    current_user: CurrentUser,
) -> RecommendationResponse:
    return await service.recommend(current_user, payload)


@router.post("/pre-alerts", response_model=PreAlertView, status_code=status.HTTP_201_CREATED)
async def create_pre_alert(
    payload: PreAlertCreate,
    service: HospitalCoordinationServiceDependency,
    current_user: CurrentUser,
) -> PreAlertView:
    return PreAlertView.model_validate(await service.create_pre_alert(current_user, payload))


@router.get("/pre-alerts", response_model=list[PreAlertView])
async def list_pre_alerts(
    service: HospitalCoordinationServiceDependency,
    current_user: CurrentUser,
) -> list[PreAlertView]:
    return [
        PreAlertView.model_validate(value) for value in await service.list_pre_alerts(current_user)
    ]


@router.post(
    "/resource-requests",
    response_model=ResourceRequestView,
    status_code=status.HTTP_201_CREATED,
)
async def create_resource_request(
    payload: ResourceRequestCreate,
    service: HospitalCoordinationServiceDependency,
    current_user: CurrentUser,
) -> ResourceRequestView:
    return ResourceRequestView.model_validate(
        await service.create_resource_request(current_user, payload)
    )


@router.get("/resource-requests", response_model=list[ResourceRequestView])
async def list_resource_requests(
    service: HospitalCoordinationServiceDependency,
    current_user: CurrentUser,
) -> list[ResourceRequestView]:
    return [
        ResourceRequestView.model_validate(value)
        for value in await service.list_resource_requests(current_user)
    ]
