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
        # Check if already seeded — fill in missing properties/units
        existing_manager = db.query(User).filter(User.email == "manager@upkeep.com").first()
        if existing_manager:
            properties_seeded = []
            units_seeded = []

            def ensure_property(name, address):
                prop = db.query(Property).filter(
                    Property.name == name, Property.manager_id == existing_manager.id
                ).first()
                if prop is None:
                    prop = Property(name=name, address=address, manager_id=existing_manager.id)
                    db.add(prop)
                    db.flush()
                    print(f"  + Added property: {name}")
                return prop

            def ensure_unit(property_id, unit_number):
                unit = db.query(PropertyUnit).filter(
                    PropertyUnit.property_id == property_id,
                    PropertyUnit.unit_number == unit_number,
                ).first()
                if unit is None:
                    unit = PropertyUnit(unit_number=unit_number, property_id=property_id)
                    db.add(unit)
                    db.flush()
                    print(f"    + Added unit: {unit_number}")
                return unit

            p1 = ensure_property("Silkwood Apartments", "123 Elm Street, Jakarta")
            p2 = ensure_property("Greenfield Residences", "45 Maple Avenue, Bandung")
            p3 = ensure_property("The Pinnacle Tower", "88 Skyline Drive, Surabaya")
            u1 = ensure_unit(p1.id, "402A")
            u2 = ensure_unit(p2.id, "12B")
            u3 = ensure_unit(p3.id, "501")
            db.commit()

            all_units = [u1, u2, u3]
            all_labels = [
                f"{p1.name} — Unit {u1.unit_number}",
                f"{p2.name} — Unit {u2.unit_number}",
                f"{p3.name} — Unit {u3.unit_number}",
            ]
            print("Database already seeded. Generated invite tokens:")
            for u, label in zip(all_units, all_labels):
                fresh = create_invite_token(u.id)
                hard = create_hard_seeded_invite_token(u.id)
                print(f"  {label}:")
                print(f"    Fresh: {fresh}")
                print(f"    Hard:  {hard}")
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

        # ── Properties + Units ──────────────────────────────────────────────
        prop1 = Property(
            name="Silkwood Apartments",
            address="123 Elm Street, Jakarta",
            manager_id=manager.id,
        )
        db.add(prop1)
        db.flush()

        prop2 = Property(
            name="Greenfield Residences",
            address="45 Maple Avenue, Bandung",
            manager_id=manager.id,
        )
        db.add(prop2)
        db.flush()

        prop3 = Property(
            name="The Pinnacle Tower",
            address="88 Skyline Drive, Surabaya",
            manager_id=manager.id,
        )
        db.add(prop3)
        db.flush()

        unit1 = PropertyUnit(
            unit_number="402A",
            property_id=prop1.id,
        )
        unit2 = PropertyUnit(
            unit_number="12B",
            property_id=prop2.id,
        )
        unit3 = PropertyUnit(
            unit_number="501",
            property_id=prop3.id,
        )
        db.add_all([unit1, unit2, unit3])
        db.flush()

        tenant = User(
            email="calvin@upkeep.com",
            hashed_password=hash_password("password123"),
            full_name="Calvin Wu",
            role=UserRole.TENANT,
            unit_id=unit1.id,
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
            unit_id=unit1.id,
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

        invite_urls = []
        hard_invite_urls = []
        for u, label in [
            (unit1, f"{prop1.name} — Unit {unit1.unit_number}"),
            (unit2, f"{prop2.name} — Unit {unit2.unit_number}"),
            (unit3, f"{prop3.name} — Unit {unit3.unit_number}"),
        ]:
            tok = create_invite_token(u.id)
            hard_tok = create_hard_seeded_invite_token(u.id)
            invite_urls.append((label, tok, f"http://localhost:3000/register?token={tok}"))
            hard_invite_urls.append((label, hard_tok, f"http://localhost:3000/register?token={hard_tok}"))

        print("Seeded successfully!")
        print()
        print(f"  Manager:  manager@upkeep.com / password123")
        print(f"  Tenant:   calvin@upkeep.com  / password123")
        print(f"  Ticket ID: {ticket.id}")
        print(f"  Properties: Silkwood Apartments, Greenfield Residences, The Pinnacle Tower")
        print()
        print("  Fresh Invite Tokens:")
        for label, tok, url in invite_urls:
            print(f"    {label}: {tok}")
        print()
        print("  Hard-Seeded Invite Tokens:")
        for label, tok, url in hard_invite_urls:
            print(f"    {label}: {tok}")
        print()
        print(f"  Visit: /tickets/{ticket.id}")

    except Exception as e:
        db.rollback()
        raise e
    finally:
        db.close()


if __name__ == "__main__":
    seed()
