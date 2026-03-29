from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.deps import get_db, get_current_user, require_manager, require_tenant
from app.models.ticket import MaintenanceRequest, TicketStatus
from app.models.audit_log import AuditLog
from app.models.message import Message
from app.models.user import User, UserRole
from app.schemas.ticket import (
    TicketCreate, TicketOut, TicketStatusUpdate, TicketDetailOut,
    AuditLogOut, MessageCreate, MessageOut,
)

router = APIRouter(prefix="/tickets", tags=["tickets"])

# Valid next states for each current state — enforces no skipping
NEXT_STATE: dict[TicketStatus, TicketStatus] = {
    TicketStatus.OPENED: TicketStatus.ACKNOWLEDGED,
    TicketStatus.ACKNOWLEDGED: TicketStatus.IN_PROGRESS,
    TicketStatus.IN_PROGRESS: TicketStatus.RESOLVED,
    TicketStatus.RESOLVED: TicketStatus.CLOSED,
}

# Which role can advance each transition
TRANSITION_ROLE: dict[TicketStatus, UserRole] = {
    TicketStatus.OPENED: UserRole.MANAGER,       # OPENED → ACKNOWLEDGED
    TicketStatus.ACKNOWLEDGED: UserRole.MANAGER,  # ACKNOWLEDGED → IN_PROGRESS
    TicketStatus.IN_PROGRESS: UserRole.MANAGER,   # IN_PROGRESS → RESOLVED
    TicketStatus.RESOLVED: UserRole.TENANT,        # RESOLVED → CLOSED
}


def _ticket_to_detail(ticket: MaintenanceRequest) -> dict:
    data = {
        "id": ticket.id,
        "title": ticket.title,
        "description": ticket.description,
        "category": ticket.category,
        "urgency": ticket.urgency,
        "status": ticket.status,
        "photo_url": ticket.photo_url,
        "tenant_id": ticket.tenant_id,
        "unit_id": ticket.unit_id,
        "created_at": ticket.created_at,
        "updated_at": ticket.updated_at,
        "tenant_name": ticket.tenant.full_name if ticket.tenant else "",
        "unit_number": ticket.unit.unit_number if ticket.unit else "",
        "property_name": ticket.unit.property.name if ticket.unit and ticket.unit.property else "",
    }
    return data


@router.post("", response_model=TicketOut, status_code=status.HTTP_201_CREATED)
def create_ticket(
    body: TicketCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_tenant),
):
    if current_user.unit_id is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Tenant is not assigned to a unit")

    ticket = MaintenanceRequest(
        title=body.title,
        description=body.description,
        category=body.category,
        urgency=body.urgency,
        photo_url=body.photo_url,
        tenant_id=current_user.id,
        unit_id=current_user.unit_id,
    )
    db.add(ticket)
    db.flush()

    audit = AuditLog(
        ticket_id=ticket.id,
        actor_id=current_user.id,
        from_status=None,
        to_status=TicketStatus.OPENED,
    )
    db.add(audit)
    db.commit()
    db.refresh(ticket)
    return ticket


@router.get("", response_model=list[TicketDetailOut])
def list_tickets(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role == UserRole.TENANT:
        tickets = db.query(MaintenanceRequest).filter(
            MaintenanceRequest.tenant_id == current_user.id
        ).order_by(MaintenanceRequest.created_at.desc()).all()
    else:
        tickets = db.query(MaintenanceRequest).order_by(MaintenanceRequest.created_at.desc()).all()

    return [_ticket_to_detail(t) for t in tickets]


@router.get("/{ticket_id}", response_model=TicketDetailOut)
def get_ticket(
    ticket_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ticket = db.get(MaintenanceRequest, ticket_id)
    if ticket is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ticket not found")

    # Tenants can only view their own tickets
    if current_user.role == UserRole.TENANT and ticket.tenant_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    return _ticket_to_detail(ticket)


@router.patch("/{ticket_id}/status", response_model=TicketOut)
def advance_status(
    ticket_id: UUID,
    body: TicketStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ticket = db.get(MaintenanceRequest, ticket_id)
    if ticket is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ticket not found")

    if ticket.status == TicketStatus.CLOSED:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Ticket is already closed")

    expected_next = NEXT_STATE[ticket.status]
    if body.status != expected_next:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Invalid transition. Expected next state: {expected_next.value}",
        )

    required_role = TRANSITION_ROLE[ticket.status]
    if current_user.role != required_role:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Only a {required_role.value} can perform this transition",
        )

    # Tenants can only act on their own tickets
    if current_user.role == UserRole.TENANT and ticket.tenant_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    prev_status = ticket.status
    ticket.status = body.status

    audit = AuditLog(
        ticket_id=ticket.id,
        actor_id=current_user.id,
        from_status=prev_status,
        to_status=body.status,
        note=body.note,
    )
    db.add(audit)
    db.commit()
    db.refresh(ticket)
    return ticket


@router.get("/{ticket_id}/audit", response_model=list[AuditLogOut])
def get_audit_log(
    ticket_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ticket = db.get(MaintenanceRequest, ticket_id)
    if ticket is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ticket not found")

    if current_user.role == UserRole.TENANT and ticket.tenant_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    logs = (
        db.query(AuditLog)
        .filter(AuditLog.ticket_id == ticket_id)
        .order_by(AuditLog.created_at.asc())
        .all()
    )
    return [
        AuditLogOut(
            id=log.id,
            from_status=log.from_status,
            to_status=log.to_status,
            note=log.note,
            actor_id=log.actor_id,
            actor_name=log.actor.full_name if log.actor else "",
            created_at=log.created_at,
        )
        for log in logs
    ]


@router.get("/{ticket_id}/messages", response_model=list[MessageOut])
def list_messages(
    ticket_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ticket = db.get(MaintenanceRequest, ticket_id)
    if ticket is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ticket not found")

    if current_user.role == UserRole.TENANT and ticket.tenant_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    messages = (
        db.query(Message)
        .filter(Message.ticket_id == ticket_id)
        .order_by(Message.created_at.asc())
        .all()
    )
    return [
        MessageOut(
            id=m.id,
            content=m.content,
            photo_url=m.photo_url,
            sender_id=m.sender_id,
            sender_name=m.sender.full_name if m.sender else "",
            created_at=m.created_at,
        )
        for m in messages
    ]


@router.post("/{ticket_id}/messages", response_model=MessageOut, status_code=status.HTTP_201_CREATED)
def create_message(
    ticket_id: UUID,
    body: MessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ticket = db.get(MaintenanceRequest, ticket_id)
    if ticket is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ticket not found")

    if current_user.role == UserRole.TENANT and ticket.tenant_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    msg = Message(
        content=body.content,
        photo_url=body.photo_url,
        ticket_id=ticket_id,
        sender_id=current_user.id,
    )
    db.add(msg)
    db.commit()
    db.refresh(msg)

    return MessageOut(
        id=msg.id,
        content=msg.content,
        photo_url=msg.photo_url,
        sender_id=msg.sender_id,
        sender_name=current_user.full_name,
        created_at=msg.created_at,
    )
