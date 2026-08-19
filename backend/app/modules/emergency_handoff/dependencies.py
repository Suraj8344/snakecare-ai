from typing import Annotated

from fastapi import Depends

from app.api.dependencies import DatabaseSession
from app.core.config import Settings, get_settings
from app.modules.emergency_handoff.gemini import GeminiIntentClassifier
from app.modules.emergency_handoff.gemini_tts import GeminiSpeechSynthesizer
from app.modules.emergency_handoff.location import NearestPlaceResolver
from app.modules.emergency_handoff.repository import SqlAlchemyEmergencyHandoffRepository
from app.modules.emergency_handoff.service import EmergencyHandoffService

SettingsDependency = Annotated[Settings, Depends(get_settings)]


def get_emergency_handoff_service(
    session: DatabaseSession,
    settings: SettingsDependency,
) -> EmergencyHandoffService:
    return EmergencyHandoffService(
        SqlAlchemyEmergencyHandoffRepository(session),
        GeminiIntentClassifier(settings),
        GeminiSpeechSynthesizer(settings),
        NearestPlaceResolver(settings),
    )


EmergencyHandoffServiceDependency = Annotated[
    EmergencyHandoffService, Depends(get_emergency_handoff_service)
]
