from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.deps import get_db, require_manager
from app.core.security import create_invite_token
from app.models.property import PropertyUnit
from app.models.user import User
from app.schemas.user import InviteToken

router = APIRouter(prefix="/units", tags=["units"])


@router.post("/{unit_id}/invite", response_model=InviteToken)
def generate_invite(
    unit_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_manager),
):
    """Manager-only: generate a 7-day invite token for a specific unit."""
    unit = db.get(PropertyUnit, unit_id)
    if unit is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Unit not found")

    token = create_invite_token(unit_id)
    return InviteToken(invite_token=token)
