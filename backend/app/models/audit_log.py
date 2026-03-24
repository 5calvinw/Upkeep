from datetime import datetime, timezone
from sqlalchemy import Column, DateTime, String, ForeignKey
from sqlalchemy import Enum as SAEnum
from sqlalchemy.orm import relationship
from app.db.base_class import Base
from app.models.ticket import TicketStatus


class AuditLog(Base):
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    ticket_id = Column(ForeignKey("maintenancerequest.id", ondelete="CASCADE"), nullable=False, index=True)
    actor_id = Column(ForeignKey("user.id", ondelete="RESTRICT"), nullable=False, index=True)

    from_status = Column(SAEnum(TicketStatus), nullable=True)
    to_status = Column(SAEnum(TicketStatus), nullable=False)
    note = Column(String(512), nullable=True)

    # Relationships
    ticket = relationship("MaintenanceRequest", back_populates="audit_logs")
    actor = relationship("User", back_populates="audit_actions")
