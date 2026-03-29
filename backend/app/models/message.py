from sqlalchemy import Column, Text, ForeignKey, String
from sqlalchemy.orm import relationship
from app.db.base_class import Base, TimestampMixin


class Message(Base, TimestampMixin):
    content = Column(Text, nullable=False, default="")
    photo_url = Column(String, nullable=True)

    ticket_id = Column(ForeignKey("maintenancerequest.id", ondelete="CASCADE"), nullable=False, index=True)
    sender_id = Column(ForeignKey("user.id", ondelete="RESTRICT"), nullable=False, index=True)

    # Relationships
    ticket = relationship("MaintenanceRequest", back_populates="messages")
    sender = relationship("User", back_populates="sent_messages")
