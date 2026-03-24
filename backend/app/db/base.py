# Import all models here so SQLAlchemy registers them with Base before create_all is called.
from app.db.base_class import Base  # noqa
from app.models.user import User  # noqa
from app.models.property import Property, PropertyUnit  # noqa
from app.models.ticket import MaintenanceRequest  # noqa
from app.models.message import Message  # noqa
from app.models.audit_log import AuditLog  # noqa
