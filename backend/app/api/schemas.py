from typing import Literal

from pydantic import BaseModel


class ServiceStatus(BaseModel):
    service: str
    status: Literal["ok", "ready"]
    version: str
