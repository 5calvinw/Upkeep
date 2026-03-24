from uuid import UUID
from pydantic import BaseModel, EmailStr
from app.models.user import UserRole


# --- Auth ---

class UserLogin(BaseModel):
    email: EmailStr
    password: str


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class InviteToken(BaseModel):
    invite_token: str


class TokenData(BaseModel):
    user_id: UUID
    role: UserRole


# --- User ---

class UserRegister(BaseModel):
    """Used by tenant to self-register via a manager-issued invite token."""
    invite_token: str
    email: EmailStr
    password: str
    full_name: str


class UserOut(BaseModel):
    id: UUID
    email: EmailStr
    full_name: str
    role: UserRole
    unit_id: UUID | None = None

    model_config = {"from_attributes": True}


class UserPasswordChange(BaseModel):
    current_password: str
    new_password: str
