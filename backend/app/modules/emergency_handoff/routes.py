from uuid import UUID

from fastapi import APIRouter, status

from app.modules.auth.dependencies import CurrentUser
from app.modules.emergency_handoff.dependencies import EmergencyHandoffServiceDependency
from app.modules.emergency_handoff.schemas import (
    HandoffCreate,
    HandoffList,
    HandoffView,
    SimulatedAnswer,
    SimulatedQuestion,
    VoiceAssistantAnswer,
    VoiceAssistantQuestion,
)

router = APIRouter(prefix="/emergency-handoffs", tags=["emergency-handoff-simulation"])


@router.post("", response_model=HandoffView, status_code=status.HTTP_201_CREATED)
async def create_handoff(
    payload: HandoffCreate,
    service: EmergencyHandoffServiceDependency,
    current_user: CurrentUser,
) -> HandoffView:
    return HandoffView.model_validate(await service.create(current_user, payload))


@router.get("", response_model=HandoffList)
async def list_handoffs(
    service: EmergencyHandoffServiceDependency, current_user: CurrentUser
) -> HandoffList:
    items, total = await service.list(current_user)
    return HandoffList(items=[HandoffView.model_validate(item) for item in items], total=total)


@router.get("/{handoff_id}", response_model=HandoffView)
async def get_handoff(
    handoff_id: UUID,
    service: EmergencyHandoffServiceDependency,
    current_user: CurrentUser,
) -> HandoffView:
    return HandoffView.model_validate(await service.get(current_user, handoff_id))


@router.post("/{handoff_id}/countdown", response_model=HandoffView)
async def start_countdown(
    handoff_id: UUID,
    service: EmergencyHandoffServiceDependency,
    current_user: CurrentUser,
) -> HandoffView:
    return HandoffView.model_validate(await service.start_countdown(current_user, handoff_id))


@router.post("/{handoff_id}/no-response", response_model=HandoffView)
async def no_response(
    handoff_id: UUID,
    service: EmergencyHandoffServiceDependency,
    current_user: CurrentUser,
) -> HandoffView:
    return HandoffView.model_validate(await service.record_no_response(current_user, handoff_id))


@router.post("/{handoff_id}/cancel", response_model=HandoffView)
async def cancel_handoff(
    handoff_id: UUID,
    service: EmergencyHandoffServiceDependency,
    current_user: CurrentUser,
) -> HandoffView:
    return HandoffView.model_validate(await service.cancel(current_user, handoff_id))


@router.post("/{handoff_id}/manual-call-intent", response_model=HandoffView)
async def manual_call_intent(
    handoff_id: UUID,
    service: EmergencyHandoffServiceDependency,
    current_user: CurrentUser,
) -> HandoffView:
    return HandoffView.model_validate(
        await service.record_manual_call_intent(current_user, handoff_id)
    )


@router.post("/{handoff_id}/simulate", response_model=SimulatedAnswer)
async def simulate_question(
    handoff_id: UUID,
    payload: SimulatedQuestion,
    service: EmergencyHandoffServiceDependency,
    current_user: CurrentUser,
) -> SimulatedAnswer:
    return await service.simulate(current_user, handoff_id, payload)


@router.post("/{handoff_id}/voice-assistant", response_model=VoiceAssistantAnswer)
async def voice_assistant_question(
    handoff_id: UUID,
    payload: VoiceAssistantQuestion,
    service: EmergencyHandoffServiceDependency,
    current_user: CurrentUser,
) -> VoiceAssistantAnswer:
    return await service.voice_assistant(current_user, handoff_id, payload)
