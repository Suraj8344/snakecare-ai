from __future__ import annotations

from pathlib import Path
from uuid import uuid4

from app.modules.medical_reports.domain import ReportStorageFailure


class LocalReportStorage:
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
            raise ReportStorageFailure from exc
        return key

    def path_for(self, key: str) -> Path:
        target = (self.root / key).resolve()
        self._assert_contained(target)
        if not target.is_file():
            raise ReportStorageFailure
        return target

    def delete(self, key: str) -> None:
        target = (self.root / key).resolve()
        self._assert_contained(target)
        target.unlink(missing_ok=True)

    def _assert_contained(self, target: Path) -> None:
        if target.parent != self.root:
            raise ReportStorageFailure
