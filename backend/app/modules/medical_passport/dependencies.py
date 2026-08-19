from typing import Annotated

from fastapi import Depends

from app.api.dependencies import DatabaseSession
from app.modules.medical_passport.repository import SqlAlchemyMedicalPassportRepository
from app.modules.medical_passport.service import MedicalPassportService


def get_medical_passport_service(session: DatabaseSession) -> MedicalPassportService:
    return MedicalPassportService(SqlAlchemyMedicalPassportRepository(session))


MedicalPassportServiceDependency = Annotated[
    MedicalPassportService, Depends(get_medical_passport_service)
]
