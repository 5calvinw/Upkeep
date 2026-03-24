from uuid import UUID
from datetime import datetime
from pydantic import BaseModel


class MessageCreate(BaseModel):
    content: str


class MessageOut(BaseModel):
    id: UUID
    content: str
    ticket_id: UUID
    sender_id: UUID
    created_at: datetime

    model_config = {"from_attributes": True}
