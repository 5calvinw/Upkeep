from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload

from app.core.deps import get_current_user, get_db, require_manager
from app.models.property import PropertyUnit
from app.models.support import SupportMessage, SupportThread
from app.models.user import User, UserRole
from app.schemas.support import (
    SupportContactOut,
    SupportMessageCreate,
    SupportMessageOut,
)

router = APIRouter(prefix="/support", tags=["support"])


def _tenant_manager_id(db: Session, tenant: User) -> UUID | None:
    if tenant.unit_id is None:
        return None

    unit = (
        db.query(PropertyUnit)
        .options(joinedload(PropertyUnit.property))
        .filter(PropertyUnit.id == tenant.unit_id)
        .first()
    )
    if unit is None or unit.property is None:
        return None
    return unit.property.manager_id


def _get_or_create_thread(db: Session, tenant: User, manager_id: UUID) -> SupportThread:
    thread = (
        db.query(SupportThread)
        .filter(
            SupportThread.tenant_id == tenant.id,
            SupportThread.manager_id == manager_id,
        )
        .first()
    )
    if thread is not None:
        return thread

    thread = SupportThread(tenant_id=tenant.id, manager_id=manager_id)
    db.add(thread)
    db.flush()
    return thread


def _message_out(message: SupportMessage) -> SupportMessageOut:
    return SupportMessageOut(
        id=message.id,
        content=message.content,
        photo_url=message.photo_url,
        sender_id=message.sender_id,
        sender_name=message.sender.full_name if message.sender else "",
        created_at=message.created_at,
    )


def _manager_tenant_query(db: Session, manager: User, property_id: UUID | None = None):
    query = (
        db.query(User)
        .join(PropertyUnit, User.unit_id == PropertyUnit.id)
        .filter(User.role == UserRole.TENANT)
        .filter(PropertyUnit.property.has(manager_id=manager.id))
        .options(joinedload(User.unit).joinedload(PropertyUnit.property))
    )
    if property_id is not None:
        query = query.filter(PropertyUnit.property_id == property_id)
    return query


def _get_manager_tenant(db: Session, manager: User, tenant_id: UUID) -> User:
    tenant = _manager_tenant_query(db, manager).filter(User.id == tenant_id).first()
    if tenant is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tenant not found for this manager",
        )
    return tenant


def _list_thread_messages(db: Session, thread: SupportThread) -> list[SupportMessageOut]:
    messages = (
        db.query(SupportMessage)
        .options(joinedload(SupportMessage.sender))
        .filter(SupportMessage.thread_id == thread.id)
        .order_by(SupportMessage.created_at.asc())
        .all()
    )
    return [_message_out(message) for message in messages]


@router.get("/contacts", response_model=list[SupportContactOut])
def list_contacts(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_manager),
    property_id: UUID | None = None,
):
    tenants = _manager_tenant_query(db, current_user, property_id=property_id).all()
    contacts: list[SupportContactOut] = []

    for tenant in tenants:
        unit = tenant.unit
        prop = unit.property if unit else None
        if prop is None:
            continue

        thread = _get_or_create_thread(db, tenant, current_user.id)
        last_message = (
            db.query(SupportMessage)
            .filter(SupportMessage.thread_id == thread.id)
            .order_by(SupportMessage.created_at.desc())
            .first()
        )
        contacts.append(
            SupportContactOut(
                tenant_id=tenant.id,
                tenant_name=tenant.full_name,
                tenant_email=tenant.email,
                unit_id=tenant.unit_id,
                unit_number=unit.unit_number if unit else "",
                property_id=prop.id,
                property_name=prop.name,
                last_message=last_message.content if last_message else "",
                last_message_at=last_message.created_at if last_message else None,
            )
        )

    db.commit()
    contacts.sort(
        key=lambda contact: (
            contact.property_name.lower(),
            contact.unit_number.lower(),
            contact.tenant_name.lower(),
        )
    )
    return contacts


@router.get("/messages", response_model=list[SupportMessageOut])
def list_tenant_messages(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != UserRole.TENANT:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Tenant access required")

    manager_id = _tenant_manager_id(db, current_user)
    if manager_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tenant is not assigned to a managed property",
        )

    thread = _get_or_create_thread(db, current_user, manager_id)
    db.commit()
    return _list_thread_messages(db, thread)


@router.post("/messages", response_model=SupportMessageOut, status_code=status.HTTP_201_CREATED)
def create_tenant_message(
    body: SupportMessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != UserRole.TENANT:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Tenant access required")

    manager_id = _tenant_manager_id(db, current_user)
    if manager_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tenant is not assigned to a managed property",
        )

    thread = _get_or_create_thread(db, current_user, manager_id)
    message = SupportMessage(
        content=body.content,
        photo_url=body.photo_url,
        thread_id=thread.id,
        sender_id=current_user.id,
    )
    db.add(message)
    db.commit()
    db.refresh(message)
    message.sender = current_user
    return _message_out(message)


@router.get("/tenants/{tenant_id}/messages", response_model=list[SupportMessageOut])
def list_manager_messages(
    tenant_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_manager),
):
    tenant = _get_manager_tenant(db, current_user, tenant_id)
    thread = _get_or_create_thread(db, tenant, current_user.id)
    db.commit()
    return _list_thread_messages(db, thread)


@router.post(
    "/tenants/{tenant_id}/messages",
    response_model=SupportMessageOut,
    status_code=status.HTTP_201_CREATED,
)
def create_manager_message(
    tenant_id: UUID,
    body: SupportMessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_manager),
):
    tenant = _get_manager_tenant(db, current_user, tenant_id)
    thread = _get_or_create_thread(db, tenant, current_user.id)
    message = SupportMessage(
        content=body.content,
        photo_url=body.photo_url,
        thread_id=thread.id,
        sender_id=current_user.id,
    )
    db.add(message)
    db.commit()
    db.refresh(message)
    message.sender = current_user
    return _message_out(message)
