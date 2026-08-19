from pathlib import Path
from uuid import uuid4

from app.modules.snakebite_emergency.domain import EmergencyStorageFailure


class EmergencyPhotoStorage:
    def __init__(self, root: str) -> None:
        self.root = Path(root).resolve()
        self.root.mkdir(parents=True, exist_ok=True)

    def save(self, content: bytes, extension: str) -> str:
        key = f"{uuid4().hex}{extension}"
        target = (self.root / key).resolve()
        self._assert_contained(target)
        try:
            target.write_bytes(content)
        except OSError as exc:
            raise EmergencyStorageFailure from exc
        return key

    def path_for(self, key: str) -> Path:
        target = (self.root / key).resolve()
        self._assert_contained(target)
        if not target.is_file():
            raise EmergencyStorageFailure
        return target

    def delete(self, key: str) -> None:
        target = (self.root / key).resolve()
        self._assert_contained(target)
        target.unlink(missing_ok=True)

    def _assert_contained(self, target: Path) -> None:
        if target.parent != self.root:
            raise EmergencyStorageFailure
