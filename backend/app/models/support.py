from sqlalchemy import Column, ForeignKey, String, Text, UniqueConstraint
from sqlalchemy.orm import relationship

from app.db.base_class import Base, TimestampMixin


class SupportThread(Base, TimestampMixin):
    tenant_id = Column(ForeignKey("user.id", ondelete="CASCADE"), nullable=False, index=True)
    manager_id = Column(ForeignKey("user.id", ondelete="CASCADE"), nullable=False, index=True)

    tenant = relationship("User", foreign_keys=[tenant_id], back_populates="support_threads")
    manager = relationship("User", foreign_keys=[manager_id], back_populates="managed_support_threads")
    messages = relationship(
        "SupportMessage",
        back_populates="thread",
        cascade="all, delete-orphan",
    )

    __table_args__ = (
        UniqueConstraint("tenant_id", "manager_id", name="uq_support_thread_tenant_manager"),
    )


class SupportMessage(Base, TimestampMixin):
    content = Column(Text, nullable=False, default="")
    photo_url = Column(String, nullable=True)

    thread_id = Column(ForeignKey("supportthread.id", ondelete="CASCADE"), nullable=False, index=True)
    sender_id = Column(ForeignKey("user.id", ondelete="RESTRICT"), nullable=False, index=True)

    thread = relationship("SupportThread", back_populates="messages")
    sender = relationship("User", back_populates="sent_support_messages")
