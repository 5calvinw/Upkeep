from uuid import UUID
from datetime import datetime
from pydantic import BaseModel
from app.models.ticket import TicketStatus, TicketCategory, TicketUrgency


class TicketCreate(BaseModel):
    title: str
    description: str
    category: TicketCategory
    urgency: TicketUrgency
    photo_url: str | None = None


class TicketStatusUpdate(BaseModel):
    status: TicketStatus
    note: str | None = None  # optional manager note, written to audit log


class TicketOut(BaseModel):
    id: UUID
    title: str
    description: str
    category: TicketCategory
    urgency: TicketUrgency
    status: TicketStatus
    photo_url: str | None
    tenant_id: UUID
    unit_id: UUID
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class AuditLogOut(BaseModel):
    id: UUID
    from_status: TicketStatus | None
    to_status: TicketStatus
    note: str | None
    actor_id: UUID
    created_at: datetime

    model_config = {"from_attributes": True}
