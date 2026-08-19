from __future__ import annotations

import asyncio
from hashlib import sha256
from io import BytesIO
from pathlib import Path
from uuid import UUID

from PIL import Image, UnidentifiedImageError

from app.modules.auth.models import User
from app.modules.snakebite_emergency.domain import (
    EmergencyNotFound,
    InvalidEmergencyPhoto,
)
from app.modules.snakebite_emergency.engine import (
    ACTIONS_TO_AVOID,
    ASSESSMENT_NOTICE,
    FIRST_AID_STEPS,
    GUIDANCE_VERSION,
    RULESET_VERSION,
    SnakebiteDecisionEngine,
)
from app.modules.snakebite_emergency.models import SnakebiteEmergency
from app.modules.snakebite_emergency.repository import (
    SqlAlchemySnakebiteEmergencyRepository,
)
from app.modules.snakebite_emergency.schemas import EmergencyCreate
from app.modules.snakebite_emergency.storage import EmergencyPhotoStorage


class SnakebiteEmergencyService:
    def __init__(
        self,
        repository: SqlAlchemySnakebiteEmergencyRepository,
        storage: EmergencyPhotoStorage,
        engine: SnakebiteDecisionEngine,
        max_photo_bytes: int,
    ) -> None:
        self.repository = repository
        self.storage = storage
        self.engine = engine
        self.max_photo_bytes = max_photo_bytes

    async def create(
        self,
        actor: User,
        payload: EmergencyCreate,
        *,
        photo_filename: str | None,
        photo_content: bytes | None,
    ) -> SnakebiteEmergency:
        photo_storage_key: str | None = None
        photo_content_type: str | None = None
        photo_extension: str | None = None
        if photo_content is not None:
            if not photo_content or len(photo_content) > self.max_photo_bytes:
                raise InvalidEmergencyPhoto
            photo_content_type, photo_extension = self._detect_photo_type(photo_content)
            photo_storage_key = await asyncio.to_thread(
                self.storage.save, photo_content, photo_extension
            )

        assessment = self.engine.assess(payload)
        vitals = payload.vitals
        safe_filename = None
        if photo_storage_key:
            original = photo_filename or f"snakebite-photo{photo_extension}"
            safe_filename = original.replace("\\", "/").rsplit("/", 1)[-1][:255]

        emergency = SnakebiteEmergency(
            owner_user_id=actor.id,
            occurred_at=payload.occurred_at,
            patient_age_years=payload.patient_age_years,
            bite_site=payload.bite_site.value,
            symptoms=[symptom.value for symptom in payload.symptoms],
            symptom_notes=self._clean(payload.symptom_notes),
            voice_transcript=self._clean(payload.voice_transcript),
            latitude=payload.latitude,
            longitude=payload.longitude,
            location_accuracy_m=payload.location_accuracy_m,
            location_label=self._clean(payload.location_label),
            pulse_bpm=vitals.pulse_bpm,
            respiratory_rate=vitals.respiratory_rate,
            oxygen_saturation=vitals.oxygen_saturation,
            systolic_bp=vitals.systolic_bp,
            diastolic_bp=vitals.diastolic_bp,
            temperature_c=vitals.temperature_c,
            consciousness=vitals.consciousness.value,
            photo_storage_key=photo_storage_key,
            photo_original_filename=safe_filename,
            photo_content_type=photo_content_type,
            photo_size_bytes=len(photo_content) if photo_content else None,
            photo_sha256=sha256(photo_content).hexdigest() if photo_content else None,
            urgency=assessment.urgency.value,
            explanation=assessment.explanation,
            immediate_actions=assessment.immediate_actions,
            first_aid_steps=FIRST_AID_STEPS,
            actions_to_avoid=ACTIONS_TO_AVOID,
            ruleset_version=RULESET_VERSION,
            guidance_version=GUIDANCE_VERSION,
            assessment_notice=ASSESSMENT_NOTICE,
        )
        self.repository.add(emergency)
        try:
            await self.repository.commit()
            await self.repository.refresh(emergency)
        except Exception:
            await self.repository.rollback()
            if photo_storage_key:
                await asyncio.to_thread(self.storage.delete, photo_storage_key)
            raise
        return emergency

    async def get(self, actor: User, emergency_id: UUID) -> SnakebiteEmergency:
        emergency = await self.repository.get_owned(emergency_id, actor.id)
        if emergency is None:
            raise EmergencyNotFound
        return emergency

    async def list(self, actor: User) -> tuple[list[SnakebiteEmergency], int]:
        return await self.repository.list_owned(actor.id)

    async def photo_path(self, actor: User, emergency_id: UUID) -> tuple[SnakebiteEmergency, Path]:
        emergency = await self.get(actor, emergency_id)
        if emergency.photo_storage_key is None:
            raise EmergencyNotFound
        path = await asyncio.to_thread(self.storage.path_for, emergency.photo_storage_key)
        return emergency, path

    @staticmethod
    def _detect_photo_type(content: bytes) -> tuple[str, str]:
        try:
            with Image.open(BytesIO(content)) as image:
                image.verify()
                image_format = image.format
        except (OSError, UnidentifiedImageError, Image.DecompressionBombError) as exc:
            raise InvalidEmergencyPhoto from exc
        if image_format == "PNG" and content.startswith(b"\x89PNG\r\n\x1a\n"):
            return "image/png", ".png"
        if image_format == "JPEG" and content.startswith(b"\xff\xd8\xff"):
            return "image/jpeg", ".jpg"
        raise InvalidEmergencyPhoto

    @staticmethod
    def _clean(value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        return cleaned or None
