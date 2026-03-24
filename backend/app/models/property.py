import enum
from sqlalchemy import Column, String, Enum, ForeignKey
from sqlalchemy.orm import relationship
from app.db.base_class import Base, TimestampMixin

class Property(Base, TimestampMixin):
    name = Column(String(255), nullable=False, index=True)
    address = Column(String(512), nullable=False)

    #Assume each property only has one manager for now, 
    manager_id = Column(ForeignKey("user.id", ondelete="RESTRICT"), nullable=False, index=True)

    #Relationships
    manager = relationship("User", back_populates="managed_properties")
    units = relationship("PropertyUnit", back_populates="property", cascade="all, delete-orphan")

class PropertyUnit(Base, TimestampMixin):
    unit_number = Column(String(50), nullable=False, index=True)
    property_id = Column(ForeignKey("property.id", ondelete="CASCADE"), nullable=False, index=True)

    #relationships
    property = relationship("Property", back_populates="units")
    tenants = relationship("User", back_populates="unit")
    requests = relationship("MaintenanceRequest", back_populates="unit")