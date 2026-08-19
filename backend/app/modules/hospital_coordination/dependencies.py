from typing import Annotated

from fastapi import Depends

from app.api.dependencies import DatabaseSession
from app.modules.hospital_coordination.engine import HospitalRecommendationEngine
from app.modules.hospital_coordination.repository import (
    SqlAlchemyHospitalCoordinationRepository,
)
from app.modules.hospital_coordination.service import HospitalCoordinationService
from app.modules.snakebite_emergency.repository import (
    SqlAlchemySnakebiteEmergencyRepository,
)


def get_hospital_coordination_service(
    session: DatabaseSession,
) -> HospitalCoordinationService:
    return HospitalCoordinationService(
        repository=SqlAlchemyHospitalCoordinationRepository(session),
        emergency_repository=SqlAlchemySnakebiteEmergencyRepository(session),
        engine=HospitalRecommendationEngine(),
    )


HospitalCoordinationServiceDependency = Annotated[
    HospitalCoordinationService, Depends(get_hospital_coordination_service)
]
