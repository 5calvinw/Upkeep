from collections import Counter
from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_
from sqlalchemy.orm import Session, joinedload, selectinload

from app.core.deps import get_db, get_current_user, require_manager, require_tenant
from app.models.property import PropertyUnit
from app.models.ticket import MaintenanceRequest, TicketStatus
from app.models.audit_log import AuditLog
from app.models.message import Message
from app.models.user import User, UserRole
from app.schemas.ticket import (
    TicketCreate, TicketOut, TicketStatusUpdate, TicketDetailOut,
    AuditLogOut, MessageCreate, MessageOut, TicketAnalyticsSummaryOut,
    CategoryCountOut, RecurringIssueOut, NotificationOut, ManagerAuditLogOut,
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


SLA_LIMITS: dict[str, tuple[timedelta, timedelta]] = {
    "low": (timedelta(hours=48), timedelta(days=7)),
    "normal": (timedelta(hours=24), timedelta(days=3)),
    "urgent": (timedelta(hours=6), timedelta(hours=24)),
}


def _as_utc(dt: datetime | None) -> datetime | None:
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _minutes_between(start: datetime | None, end: datetime | None) -> int | None:
    start = _as_utc(start)
    end = _as_utc(end)
    if start is None or end is None:
        return None
    return max(0, int((end - start).total_seconds() // 60))


def _first_audit_at(ticket: MaintenanceRequest, target: TicketStatus) -> datetime | None:
    matching = [
        log.created_at
        for log in ticket.audit_logs
        if log.to_status == target
    ]
    return min(matching) if matching else None


def _sla_insights(ticket: MaintenanceRequest) -> dict:
    created_at = _as_utc(ticket.created_at)
    acknowledged_at = _first_audit_at(ticket, TicketStatus.ACKNOWLEDGED)
    resolved_at = _first_audit_at(ticket, TicketStatus.RESOLVED)
    closed_at = _first_audit_at(ticket, TicketStatus.CLOSED)

    response_minutes = _minutes_between(created_at, acknowledged_at)
    resolution_minutes = _minutes_between(created_at, resolved_at)
    closure_minutes = _minutes_between(created_at, closed_at)

    acknowledge_limit, resolve_limit = SLA_LIMITS.get(
        ticket.urgency.value,
        SLA_LIMITS["normal"],
    )
    now = datetime.now(timezone.utc)
    elapsed = now - created_at if created_at else timedelta(0)

    ack_breached = (
        acknowledged_at is not None
        and created_at is not None
        and _as_utc(acknowledged_at) - created_at > acknowledge_limit
    ) or (
        acknowledged_at is None
        and ticket.status == TicketStatus.OPENED
        and elapsed > acknowledge_limit
    )
    resolution_breached = (
        resolved_at is not None
        and created_at is not None
        and _as_utc(resolved_at) - created_at > resolve_limit
    ) or (
        resolved_at is None
        and ticket.status not in (TicketStatus.RESOLVED, TicketStatus.CLOSED)
        and elapsed > resolve_limit
    )

    is_breached = bool(ack_breached or resolution_breached)
    if resolved_at is not None and resolution_breached:
        sla_status = "Resolved Late"
    elif is_breached:
        sla_status = "SLA Breached"
    elif (
        resolved_at is None
        and created_at is not None
        and elapsed >= resolve_limit * 0.8
    ) or (
        acknowledged_at is None
        and created_at is not None
        and elapsed >= acknowledge_limit * 0.8
    ):
        sla_status = "Approaching SLA Limit"
    else:
        sla_status = "On Track"

    return {
        "sla_status": sla_status,
        "response_time_minutes": response_minutes,
        "resolution_time_minutes": resolution_minutes,
        "closure_time_minutes": closure_minutes,
        "is_sla_breached": is_breached,
    }


def _recurring_issue_map(
    db: Session,
    property_id: UUID | None = None,
) -> dict[tuple[UUID, object], int]:
    since = datetime.now(timezone.utc) - timedelta(days=30)
    query = db.query(MaintenanceRequest).filter(
        MaintenanceRequest.created_at >= since,
    )
    if property_id is not None:
        query = query.join(PropertyUnit).filter(PropertyUnit.property_id == property_id)
    tickets = query.all()
    counts: Counter[tuple[UUID, object]] = Counter(
        (ticket.unit_id, ticket.category) for ticket in tickets
    )
    return {key: count for key, count in counts.items() if count >= 3}


def _recurring_insights(
    ticket: MaintenanceRequest,
    recurring_counts: dict[tuple[UUID, object], int] | None,
) -> dict:
    count = (recurring_counts or {}).get((ticket.unit_id, ticket.category), 0)
    unit_number = ticket.unit.unit_number if ticket.unit else ""
    category = ticket.category.value.replace("_", " ")
    message = None
    if count >= 3:
        message = (
            f"Recurring issue detected: Unit {unit_number or ticket.unit_id} "
            f"has {count} {category} reports in the last 30 days."
        )
    return {
        "is_recurring_issue": count >= 3,
        "recurring_issue_count": count,
        "recurring_issue_message": message,
    }


def _ticket_to_detail(
    ticket: MaintenanceRequest,
    db: Session | None = None,
    recurring_counts: dict[tuple[UUID, object], int] | None = None,
) -> dict:
    if recurring_counts is None and db is not None:
        recurring_counts = _recurring_issue_map(db)

    photo_urls = ticket.photo_urls or ([ticket.photo_url] if ticket.photo_url else [])
    data = {
        "id": ticket.id,
        "title": ticket.title,
        "description": ticket.description,
        "category": ticket.category,
        "urgency": ticket.urgency,
        "status": ticket.status,
        "photo_url": photo_urls[0] if photo_urls else None,
        "photo_urls": photo_urls,
        "is_private": ticket.is_private,
        "tenant_id": ticket.tenant_id,
        "unit_id": ticket.unit_id,
        "created_at": ticket.created_at,
        "updated_at": ticket.updated_at,
        "tenant_name": ticket.tenant.full_name if ticket.tenant else "",
        "unit_number": ticket.unit.unit_number if ticket.unit else "",
        "property_name": ticket.unit.property.name if ticket.unit and ticket.unit.property else "",
    }
    data.update(_sla_insights(ticket))
    data.update(_recurring_insights(ticket, recurring_counts))
    return data


def _tenant_property_id(db: Session, tenant: User):
    if tenant.unit_id is None:
        return None

    unit = db.get(PropertyUnit, tenant.unit_id)
    return unit.property_id if unit else None


def _tenant_can_view_ticket(db: Session, ticket: MaintenanceRequest, tenant: User) -> bool:
    if ticket.tenant_id == tenant.id:
        return True

    property_id = _tenant_property_id(db, tenant)
    if property_id is None or ticket.is_private or ticket.unit is None:
        return False

    return ticket.unit.property_id == property_id


def _ensure_ticket_visible_to_user(
    db: Session,
    ticket: MaintenanceRequest,
    current_user: User,
) -> None:
    if current_user.role == UserRole.TENANT and not _tenant_can_view_ticket(
        db,
        ticket,
        current_user,
    ):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")


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
        photo_url=body.photo_urls[0] if body.photo_urls else None,
        photo_urls=body.photo_urls,
        is_private=body.is_private,
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
    property_id: UUID | None = None,
):
    recurring_counts = _recurring_issue_map(db, property_id=property_id)
    if current_user.role == UserRole.TENANT:
        tickets = db.query(MaintenanceRequest).filter(
            MaintenanceRequest.tenant_id == current_user.id
        ).order_by(MaintenanceRequest.created_at.desc()).all()
    else:
        query = db.query(MaintenanceRequest).options(
            selectinload(MaintenanceRequest.tenant),
            selectinload(MaintenanceRequest.unit).selectinload(PropertyUnit.property),
            selectinload(MaintenanceRequest.audit_logs),
        )
        if property_id is not None:
            query = query.join(PropertyUnit).filter(PropertyUnit.property_id == property_id)
        tickets = query.order_by(MaintenanceRequest.created_at.desc()).all()

    return [_ticket_to_detail(t, recurring_counts=recurring_counts) for t in tickets]


@router.get("/active", response_model=list[TicketDetailOut])
def list_active_tickets(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    property_id: UUID | None = None,
):
    recurring_counts = _recurring_issue_map(db, property_id=property_id)
    if current_user.role == UserRole.TENANT:
        tenant_property_id = _tenant_property_id(db, current_user)
        if tenant_property_id is None:
            return []

        tickets = (
            db.query(MaintenanceRequest)
            .join(MaintenanceRequest.unit)
            .filter(
                MaintenanceRequest.status != TicketStatus.CLOSED,
                PropertyUnit.property_id == tenant_property_id,
                or_(
                    MaintenanceRequest.tenant_id == current_user.id,
                    MaintenanceRequest.is_private.is_(False),
                ),
            )
            .order_by(MaintenanceRequest.created_at.desc())
            .all()
        )
    else:
        query = db.query(MaintenanceRequest).options(
            selectinload(MaintenanceRequest.tenant),
            selectinload(MaintenanceRequest.unit).selectinload(PropertyUnit.property),
            selectinload(MaintenanceRequest.audit_logs),
        ).filter(
            MaintenanceRequest.status != TicketStatus.CLOSED,
        )
        if property_id is not None:
            query = query.join(PropertyUnit).filter(PropertyUnit.property_id == property_id)
        tickets = query.order_by(MaintenanceRequest.created_at.desc()).all()

    return [_ticket_to_detail(t, recurring_counts=recurring_counts) for t in tickets]


@router.get("/analytics/summary", response_model=TicketAnalyticsSummaryOut)
def get_analytics_summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_manager),
    property_id: UUID | None = None,
):
    query = db.query(MaintenanceRequest).options(
        selectinload(MaintenanceRequest.tenant),
        selectinload(MaintenanceRequest.unit).selectinload(PropertyUnit.property),
        selectinload(MaintenanceRequest.audit_logs),
    )
    if property_id is not None:
        query = query.join(PropertyUnit).filter(PropertyUnit.property_id == property_id)
    tickets = query.order_by(MaintenanceRequest.created_at.desc()).all()
    recurring_counts = _recurring_issue_map(db, property_id=property_id)
    insights = [_ticket_to_detail(ticket, recurring_counts=recurring_counts) for ticket in tickets]

    response_times = [
        item["response_time_minutes"]
        for item in insights
        if item["response_time_minutes"] is not None
    ]
    resolution_times = [
        item["resolution_time_minutes"]
        for item in insights
        if item["resolution_time_minutes"] is not None
    ]
    category_counts = Counter(ticket.category for ticket in tickets)
    recurring_issues = []
    for (unit_id, category), count in recurring_counts.items():
        sample = next(
            (
                ticket for ticket in tickets
                if ticket.unit_id == unit_id and ticket.category == category
            ),
            None,
        )
        unit_number = sample.unit.unit_number if sample and sample.unit else ""
        category_text = category.value.replace("_", " ")
        recurring_issues.append(
            RecurringIssueOut(
                unit_id=unit_id,
                unit_number=unit_number,
                category=category,
                count=count,
                message=(
                    f"Recurring issue detected: Unit {unit_number or unit_id} "
                    f"has {count} {category_text} reports in the last 30 days."
                ),
            )
        )

    return TicketAnalyticsSummaryOut(
        total_tickets=len(tickets),
        open_tickets=sum(1 for ticket in tickets if ticket.status != TicketStatus.CLOSED),
        resolved_tickets=sum(1 for ticket in tickets if ticket.status == TicketStatus.RESOLVED),
        closed_tickets=sum(1 for ticket in tickets if ticket.status == TicketStatus.CLOSED),
        average_response_time_minutes=(
            int(sum(response_times) / len(response_times)) if response_times else None
        ),
        average_resolution_time_minutes=(
            int(sum(resolution_times) / len(resolution_times)) if resolution_times else None
        ),
        sla_breach_count=sum(1 for item in insights if item["is_sla_breached"]),
        most_common_categories=[
            CategoryCountOut(category=category, count=count)
            for category, count in category_counts.most_common(5)
        ],
        recurring_issue_count=len(recurring_issues),
        recurring_issues=recurring_issues,
    )


STATUS_DISPLAY: dict[TicketStatus, str] = {
    TicketStatus.OPENED: "Opened",
    TicketStatus.ACKNOWLEDGED: "Acknowledged",
    TicketStatus.IN_PROGRESS: "In Progress",
    TicketStatus.RESOLVED: "Resolved",
    TicketStatus.CLOSED: "Closed",
}


@router.get("/notifications", response_model=list[NotificationOut])
def get_dashboard_notifications(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_manager),
    property_id: UUID | None = None,
    limit: int = 50,
):
    ticket_id_query = db.query(MaintenanceRequest.id)
    if property_id is not None:
        ticket_id_query = ticket_id_query.join(PropertyUnit).filter(
            PropertyUnit.property_id == property_id,
        )
    visible_ids = [row[0] for row in ticket_id_query.all()]
    if not visible_ids:
        return []

    audits = (
        db.query(AuditLog)
        .options(joinedload(AuditLog.actor), joinedload(AuditLog.ticket))
        .filter(
            AuditLog.ticket_id.in_(visible_ids),
            AuditLog.actor_id != current_user.id,
            AuditLog.to_status != TicketStatus.OPENED,
        )
        .order_by(AuditLog.created_at.desc())
        .limit(limit)
        .all()
    )

    msgs = (
        db.query(Message)
        .options(joinedload(Message.sender), joinedload(Message.ticket))
        .filter(
            Message.ticket_id.in_(visible_ids),
            Message.sender_id != current_user.id,
        )
        .order_by(Message.created_at.desc())
        .limit(limit)
        .all()
    )

    items: list[dict] = []
    for a in audits:
        status_label = STATUS_DISPLAY.get(a.to_status, a.to_status.value)
        items.append({
            "ticket_id": a.ticket_id,
            "ticket_title": a.ticket.title,
            "actor_name": a.actor.full_name if a.actor else "",
            "body": f"Status updated to {status_label}",
            "created_at": a.created_at,
        })
    for m in msgs:
        items.append({
            "ticket_id": m.ticket_id,
            "ticket_title": m.ticket.title,
            "actor_name": m.sender.full_name if m.sender else "",
            "body": m.content or "",
            "created_at": m.created_at,
        })

    items.sort(key=lambda x: x["created_at"], reverse=True)
    return items[:limit]


@router.get("/audit-log", response_model=list[ManagerAuditLogOut])
def get_manager_audit_log(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_manager),
    property_id: UUID | None = None,
    limit: int = Query(200, ge=1, le=500),
):
    query = (
        db.query(AuditLog)
        .join(AuditLog.ticket)
        .options(
            joinedload(AuditLog.actor),
            joinedload(AuditLog.ticket)
            .joinedload(MaintenanceRequest.unit)
            .joinedload(PropertyUnit.property),
        )
    )
    if property_id is not None:
        query = query.join(MaintenanceRequest.unit).filter(
            PropertyUnit.property_id == property_id,
        )

    logs = query.order_by(AuditLog.created_at.desc()).limit(limit).all()

    return [
        ManagerAuditLogOut(
            id=log.id,
            ticket_id=log.ticket_id,
            ticket_title=log.ticket.title if log.ticket else "",
            unit_number=log.ticket.unit.unit_number
            if log.ticket and log.ticket.unit
            else "",
            property_name=log.ticket.unit.property.name
            if log.ticket and log.ticket.unit and log.ticket.unit.property
            else "",
            from_status=log.from_status,
            to_status=log.to_status,
            note=log.note,
            actor_id=log.actor_id,
            actor_name=log.actor.full_name if log.actor else "",
            created_at=log.created_at,
        )
        for log in logs
    ]


@router.get("/{ticket_id}", response_model=TicketDetailOut)
def get_ticket(
    ticket_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ticket = db.get(MaintenanceRequest, ticket_id)
    if ticket is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ticket not found")

    _ensure_ticket_visible_to_user(db, ticket, current_user)

    return _ticket_to_detail(ticket, db=db)


@router.patch("/{ticket_id}/status", response_model=TicketDetailOut)
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

    is_rejection = (
        ticket.status == TicketStatus.RESOLVED
        and body.status == TicketStatus.IN_PROGRESS
    )
    expected_next = NEXT_STATE[ticket.status]
    if body.status != expected_next and not is_rejection:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Invalid transition. Expected next state: {expected_next.value}",
        )

    required_role = UserRole.TENANT if is_rejection else TRANSITION_ROLE[ticket.status]
    if current_user.role != required_role:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Only a {required_role.value} can perform this transition",
        )

    # Tenants can only act on their own tickets, even when shared tickets are visible.
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
    return _ticket_to_detail(ticket, db=db)


@router.get("/{ticket_id}/audit", response_model=list[AuditLogOut])
def get_audit_log(
    ticket_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ticket = db.get(MaintenanceRequest, ticket_id)
    if ticket is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ticket not found")

    _ensure_ticket_visible_to_user(db, ticket, current_user)

    logs = (
        db.query(AuditLog)
        .options(joinedload(AuditLog.actor))
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

    _ensure_ticket_visible_to_user(db, ticket, current_user)

    messages = (
        db.query(Message)
        .options(joinedload(Message.sender))
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

    _ensure_ticket_visible_to_user(db, ticket, current_user)

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
