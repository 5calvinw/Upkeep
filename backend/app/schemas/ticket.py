from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field
from app.models.ticket import TicketStatus, TicketCategory, TicketUrgency


class TicketCreate(BaseModel):
    title: str
    description: str
    category: TicketCategory
    urgency: TicketUrgency
    photo_urls: list[str] = Field(default_factory=list)
    is_private: bool = False


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
    photo_url: str | None = None
    photo_urls: list[str] = Field(default_factory=list)
    is_private: bool = False
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
    actor_name: str = ""
    created_at: datetime

    model_config = {"from_attributes": True}


class MessageCreate(BaseModel):
    content: str = ""
    photo_url: str | None = None


class MessageOut(BaseModel):
    id: UUID
    content: str
    photo_url: str | None = None
    sender_id: UUID
    sender_name: str = ""
    created_at: datetime

    model_config = {"from_attributes": True}


class TicketDetailOut(TicketOut):
    tenant_name: str = ""
    unit_number: str = ""
    property_name: str = ""
    sla_status: str = "On Track"
    response_time_minutes: int | None = None
    resolution_time_minutes: int | None = None
    closure_time_minutes: int | None = None
    is_sla_breached: bool = False
    is_recurring_issue: bool = False
    recurring_issue_count: int = 0
    recurring_issue_message: str | None = None


class CategoryCountOut(BaseModel):
    category: TicketCategory
    count: int


class RecurringIssueOut(BaseModel):
    unit_id: UUID
    unit_number: str = ""
    category: TicketCategory
    count: int
    message: str


class TicketAnalyticsSummaryOut(BaseModel):
    total_tickets: int
    open_tickets: int
    resolved_tickets: int
    closed_tickets: int
    average_response_time_minutes: int | None = None
    average_resolution_time_minutes: int | None = None
    sla_breach_count: int
    most_common_categories: list[CategoryCountOut] = Field(default_factory=list)
    recurring_issue_count: int
    recurring_issues: list[RecurringIssueOut] = Field(default_factory=list)
