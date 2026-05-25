from uuid import UUID

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.deps import get_db, require_manager
from app.models.user import User

router = APIRouter(prefix="/properties", tags=["properties"])


class PropertyOut(BaseModel):
    id: UUID
    name: str
    address: str

    model_config = {"from_attributes": True}


@router.get("", response_model=list[PropertyOut])
def list_properties(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_manager),
):
    return current_user.managed_properties
