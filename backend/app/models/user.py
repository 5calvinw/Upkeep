import enum
from sqlalchemy import Column, String, Enum, ForeignKey
from sqlalchemy.orm import relationship
from app.db.base_class import Base, TimestampMixin

class UserRole(str, enum.Enum):
    TENANT = "tenant"
    MANAGER = "manager"

class User(Base, TimestampMixin):
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(255), nullable=False)
    role = Column(Enum(UserRole), nullable=False, index=True)

    # if role is tenant
    unit_id = Column(ForeignKey("propertyunit.id", ondelete="SET NULL"), nullable = True, index = True)
    
    # Relationships
    unit = relationship("PropertyUnit", back_populates="tenants")
    managed_properties = relationship("Property", back_populates="manager")
    requests = relationship("MaintenanceRequest", back_populates="tenant")
    sent_messages = relationship("Message", back_populates="sender")
    audit_actions = relationship("AuditLog", back_populates="actor")
