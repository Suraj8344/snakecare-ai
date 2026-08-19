from uuid import UUID

from fastapi import APIRouter, status

from app.modules.auth.dependencies import CurrentUser
from app.modules.hospital_coordination.schemas import AvailabilityView
from app.modules.hospital_dashboard.dependencies import HospitalDashboardServiceDependency
from app.modules.hospital_dashboard.schemas import (
    AntivenomBoxCreate,
    AntivenomBoxCreated,
    AvailabilityPublish,
    ClaimCreate,
    ClaimView,
    DashboardInbox,
    DecisionInput,
    DepletionRequestView,
    DepletionScanCreate,
    InboxDecision,
)

router = APIRouter(prefix="/hospital-dashboard", tags=["hospital-dashboard"])


@router.post("/claims", response_model=ClaimView, status_code=status.HTTP_201_CREATED)
async def submit_claim(
    payload: ClaimCreate, service: HospitalDashboardServiceDependency, current_user: CurrentUser
) -> ClaimView:
    return await service.submit_claim(current_user, payload)


@router.get("/claims/me", response_model=list[ClaimView])
async def my_claims(
    service: HospitalDashboardServiceDependency, current_user: CurrentUser
) -> list[ClaimView]:
    return await service.claims_for_actor(current_user)


@router.get("/claims/pending", response_model=list[ClaimView])
async def pending_claims(
    service: HospitalDashboardServiceDependency, current_user: CurrentUser
) -> list[ClaimView]:
    return await service.pending_claims(current_user)


@router.post("/claims/{claim_id}/decision", response_model=ClaimView)
async def decide_claim(
    claim_id: UUID,
    payload: DecisionInput,
    service: HospitalDashboardServiceDependency,
    current_user: CurrentUser,
) -> ClaimView:
    return await service.decide_claim(current_user, claim_id, payload)


@router.get("/me", response_model=DashboardInbox)
async def dashboard(
    service: HospitalDashboardServiceDependency, current_user: CurrentUser
) -> DashboardInbox:
    return await service.dashboard(current_user)


@router.post("/pre-alerts/{alert_id}/decision")
async def decide_pre_alert(
    alert_id: UUID,
    payload: InboxDecision,
    service: HospitalDashboardServiceDependency,
    current_user: CurrentUser,
) -> dict[str, object]:
    return await service.decide_pre_alert(current_user, alert_id, payload)


@router.post("/resource-requests/{request_id}/decision")
async def decide_resource_request(
    request_id: UUID,
    payload: InboxDecision,
    service: HospitalDashboardServiceDependency,
    current_user: CurrentUser,
) -> dict[str, object]:
    return await service.decide_resource_request(current_user, request_id, payload)


@router.post("/availability", response_model=AvailabilityView, status_code=status.HTTP_201_CREATED)
async def publish_availability(
    payload: AvailabilityPublish,
    service: HospitalDashboardServiceDependency,
    current_user: CurrentUser,
) -> AvailabilityView:
    return await service.publish_availability(current_user, payload)


@router.post(
    "/antivenom-boxes", response_model=AntivenomBoxCreated, status_code=status.HTTP_201_CREATED
)
async def register_box(
    payload: AntivenomBoxCreate,
    service: HospitalDashboardServiceDependency,
    current_user: CurrentUser,
) -> AntivenomBoxCreated:
    return await service.register_box(current_user, payload)


@router.post(
    "/antivenom-scans", response_model=DepletionRequestView, status_code=status.HTTP_201_CREATED
)
async def scan_box(
    payload: DepletionScanCreate,
    service: HospitalDashboardServiceDependency,
    current_user: CurrentUser,
) -> DepletionRequestView:
    return DepletionRequestView.model_validate(await service.scan_box(current_user, payload))


@router.post("/antivenom-depletions/{request_id}/decision", response_model=DepletionRequestView)
async def decide_depletion(
    request_id: UUID,
    payload: DecisionInput,
    service: HospitalDashboardServiceDependency,
    current_user: CurrentUser,
) -> DepletionRequestView:
    return DepletionRequestView.model_validate(
        await service.decide_depletion(current_user, request_id, payload)
    )
