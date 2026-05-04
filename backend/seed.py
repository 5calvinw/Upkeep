"""
Seed script — creates test data for local development.

Run:  python -m seed
From: backend/ directory

Creates:
  - Manager:  manager@upkeep.com / password123
  - Tenant:   calvin@upkeep.com  / password123
  - Property: Silkwood Apartments → Unit 402A
  - Ticket:   "There are bats in my attic" (ACKNOWLEDGED)
  - Messages + Audit trail
"""
from datetime import datetime, timezone

from app.db.base import *  # noqa – registers all models
from app.db.session import SessionLocal, engine
from app.db.base_class import Base
from app.models.user import User, UserRole
from app.models.property import Property, PropertyUnit
from app.models.ticket import MaintenanceRequest, TicketStatus, TicketCategory, TicketUrgency
from app.models.message import Message
from app.models.audit_log import AuditLog
from app.core.security import hash_password, create_invite_token
from app.core.config import JWT_SECRET_KEY, JWT_ALGORITHM
from jose import jwt


def create_hard_seeded_invite_token(unit_id):
    payload = {
        "unit_id": str(unit_id),
        "type": "invite",
        "seeded": True,
        "exp": datetime(2099, 1, 1, tzinfo=timezone.utc),
    }
    return jwt.encode(payload, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)

def seed():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    try:
        # Check if already seeded
        existing_manager = db.query(User).filter(User.email == "manager@upkeep.com").first()
        if existing_manager:
            existing_unit = db.query(PropertyUnit).filter(PropertyUnit.unit_number == "402A").first()
            if existing_unit is None:
                print("Database already seeded, but unit 402A not found. No invite token generated.")
                return

            invite_token = create_invite_token(existing_unit.id)
            hard_seeded_token = create_hard_seeded_invite_token(existing_unit.id)
            invite_url = f"http://localhost:3000/register?token={invite_token}"
            hard_seeded_url = f"http://localhost:3000/register?token={hard_seeded_token}"

            print("Database already seeded. Generated tokens for unit 402A:")
            print(f"  Fresh Invite Token: {invite_token}")
            print(f"  Fresh Register URL: {invite_url}")
            print(f"  Hard Invite Token:  {hard_seeded_token}")
            print(f"  Hard Register URL:  {hard_seeded_url}")
            return

        # ── Users ──────────────────────────────────────────────────────────
        manager = User(
            email="manager@upkeep.com",
            hashed_password=hash_password("password123"),
            full_name="Harizal Lim",
            role=UserRole.MANAGER,
        )
        db.add(manager)
        db.flush()

        # ── Property + Unit ────────────────────────────────────────────────
        prop = Property(
            name="Silkwood Apartments",
            address="123 Elm Street, Jakarta",
            manager_id=manager.id,
        )
        db.add(prop)
        db.flush()

        unit = PropertyUnit(
            unit_number="402A",
            property_id=prop.id,
        )
        db.add(unit)
        db.flush()

        tenant = User(
            email="calvin@upkeep.com",
            hashed_password=hash_password("password123"),
            full_name="Calvin Wu",
            role=UserRole.TENANT,
            unit_id=unit.id,
        )
        db.add(tenant)
        db.flush()

        # ── Ticket ─────────────────────────────────────────────────────────
        ticket = MaintenanceRequest(
            title="There are bats in my attic",
            description=(
                "This is where the ticket description will be placed. "
                "Lorem ipsum dolor sit amet, consectetur adipiscing elit, "
                "sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. "
                "Lorem ipsum dolor sit amet, consectetur adipiscing elit, "
                "sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. "
                "Lorem ipsum dolor sit amet, consectetur adipiscing elit, "
                "sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
            ),
            category=TicketCategory.OTHER,
            urgency=TicketUrgency.URGENT,
            status=TicketStatus.ACKNOWLEDGED,
            tenant_id=tenant.id,
            unit_id=unit.id,
        )
        db.add(ticket)
        db.flush()

        # ── Audit trail ───────────────────────────────────────────────────
        audit1 = AuditLog(
            ticket_id=ticket.id,
            actor_id=tenant.id,
            from_status=None,
            to_status=TicketStatus.OPENED,
        )
        audit2 = AuditLog(
            ticket_id=ticket.id,
            actor_id=manager.id,
            from_status=TicketStatus.OPENED,
            to_status=TicketStatus.ACKNOWLEDGED,
        )
        db.add_all([audit1, audit2])
        db.flush()

        # ── Messages ──────────────────────────────────────────────────────
        msg1 = Message(
            content="Hello I need my stuff fixed asap bro, there are literally bats flying around my attic every night.",
            ticket_id=ticket.id,
            sender_id=tenant.id,
        )
        msg2 = Message(
            content="Yes I will fix it soon okay be patient, we are scheduling a pest control team to come by this week.",
            ticket_id=ticket.id,
            sender_id=manager.id,
        )
        msg3 = Message(
            content="Hello I need my stuff fixed asap bro, they are getting louder and I can't sleep at night.",
            ticket_id=ticket.id,
            sender_id=tenant.id,
        )
        msg4 = Message(
            content="Yes I will fix it soon okay be patient, the team is confirmed for Thursday morning.",
            ticket_id=ticket.id,
            sender_id=manager.id,
        )
        db.add_all([msg1, msg2, msg3, msg4])

        db.commit()
        invite_token = create_invite_token(unit.id)
        hard_seeded_token = create_hard_seeded_invite_token(unit.id)
        invite_url = f"http://localhost:3000/register?token={invite_token}"
        hard_seeded_url = f"http://localhost:3000/register?token={hard_seeded_token}"

        print("Seeded successfully!")
        print()
        print(f"  Manager:  manager@upkeep.com / password123")
        print(f"  Tenant:   calvin@upkeep.com  / password123")
        print(f"  Ticket ID: {ticket.id}")
        print(f"  Fresh Invite Token: {invite_token}")
        print(f"  Fresh Register URL: {invite_url}")
        print(f"  Hard Invite Token:  {hard_seeded_token}")
        print(f"  Hard Register URL:  {hard_seeded_url}")
        print()
        print(f"  Visit: /tickets/{ticket.id}")

    except Exception as e:
        db.rollback()
        raise e
    finally:
        db.close()


if __name__ == "__main__":
    seed()
