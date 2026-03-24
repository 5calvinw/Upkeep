import enum
from sqlalchemy import Column, String, Text, Enum, ForeignKey
from sqlalchemy.orm import relationship
from app.db.base_class import Base, TimestampMixin


class TicketStatus(str, enum.Enum):
    OPENED = "opened"
    ACKNOWLEDGED = "acknowledged"
    IN_PROGRESS = "in_progress"
    RESOLVED = "resolved"
    CLOSED = "closed"


class TicketCategory(str, enum.Enum):
    PLUMBING = "plumbing"
    ELECTRICAL = "electrical"
    HVAC = "hvac"
    STRUCTURAL = "structural"
    OTHER = "other"


class TicketUrgency(str, enum.Enum):
    LOW = "low"
    NORMAL = "normal"
    URGENT = "urgent"


class MaintenanceRequest(Base, TimestampMixin):
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=False)
    category = Column(Enum(TicketCategory), nullable=False, index=True)
    urgency = Column(Enum(TicketUrgency), nullable=False, index=True)
    status = Column(Enum(TicketStatus), default=TicketStatus.OPENED, nullable=False, index=True)
    photo_url = Column(String(512), nullable=True)

    tenant_id = Column(ForeignKey("user.id", ondelete="RESTRICT"), nullable=False, index=True)
    unit_id = Column(ForeignKey("propertyunit.id", ondelete="RESTRICT"), nullable=False, index=True)

    # Relationships
    tenant = relationship("User", back_populates="requests")
    unit = relationship("PropertyUnit", back_populates="requests")
    messages = relationship("Message", back_populates="ticket", cascade="all, delete-orphan")
    audit_logs = relationship("AuditLog", back_populates="ticket", cascade="all, delete-orphan")
