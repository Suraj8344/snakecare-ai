from typing import Annotated

from fastapi import Depends

from app.api.dependencies import DatabaseSession
from app.modules.hospital_coordination.repository import SqlAlchemyHospitalCoordinationRepository
from app.modules.hospital_dashboard.repository import SqlAlchemyHospitalDashboardRepository
from app.modules.hospital_dashboard.service import HospitalDashboardService


def get_hospital_dashboard_service(session: DatabaseSession) -> HospitalDashboardService:
    return HospitalDashboardService(
        repository=SqlAlchemyHospitalDashboardRepository(session),
        coordination_repository=SqlAlchemyHospitalCoordinationRepository(session),
    )


HospitalDashboardServiceDependency = Annotated[
    HospitalDashboardService, Depends(get_hospital_dashboard_service)
]
