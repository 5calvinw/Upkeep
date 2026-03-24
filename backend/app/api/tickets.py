from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.deps import get_db, get_current_user, require_manager, require_tenant
from app.models.ticket import MaintenanceRequest, TicketStatus
from app.models.audit_log import AuditLog
from app.models.user import User, UserRole
from app.schemas.ticket import TicketCreate, TicketOut, TicketStatusUpdate, AuditLogOut

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


@router.get("", response_model=list[TicketOut])
def list_tickets(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role == UserRole.TENANT:
        return db.query(MaintenanceRequest).filter(
            MaintenanceRequest.tenant_id == current_user.id
        ).order_by(MaintenanceRequest.created_at.desc()).all()

    # Manager sees all tickets
    return db.query(MaintenanceRequest).order_by(MaintenanceRequest.created_at.desc()).all()


@router.get("/{ticket_id}", response_model=TicketOut)
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

    return ticket


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

    return ticket.audit_logs
