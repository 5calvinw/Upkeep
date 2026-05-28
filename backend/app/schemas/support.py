from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class SupportMessageCreate(BaseModel):
    content: str = ""
    photo_url: str | None = None


class SupportMessageOut(BaseModel):
    id: UUID
    content: str
    photo_url: str | None = None
    sender_id: UUID
    sender_name: str = ""
    created_at: datetime

    model_config = {"from_attributes": True}


class SupportContactOut(BaseModel):
    tenant_id: UUID
    tenant_name: str
    tenant_email: str
    unit_id: UUID | None = None
    unit_number: str = ""
    property_id: UUID
    property_name: str
    last_message: str = ""
    last_message_at: datetime | None = None
