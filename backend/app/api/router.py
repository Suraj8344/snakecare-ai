from fastapi import APIRouter

from app.api.routes.health import router as health_router
from app.modules.auth.routes import router as auth_router
from app.modules.emergency_handoff.routes import router as emergency_handoff_router
from app.modules.hospital_coordination.routes import router as hospital_coordination_router
from app.modules.hospital_dashboard.routes import router as hospital_dashboard_router
from app.modules.medical_passport.routes import router as medical_passport_router
from app.modules.medical_reports.routes import router as medical_reports_router
from app.modules.snakebite_emergency.routes import router as snakebite_emergency_router

api_router = APIRouter()
api_router.include_router(health_router, tags=["operations"])
api_router.include_router(auth_router)
api_router.include_router(emergency_handoff_router)
api_router.include_router(hospital_coordination_router)
api_router.include_router(hospital_dashboard_router)
api_router.include_router(medical_passport_router)
api_router.include_router(medical_reports_router)
api_router.include_router(snakebite_emergency_router)
