from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import get_google_web_client_id
from app.core.deps import get_db
from app.core.security import create_access_token, verify_password
from app.models.user import User
from app.schemas.user import GoogleLogin, Token, UserLogin

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=Token)
def login(body: UserLogin, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == body.email).first()
    if not user or not verify_password(body.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    token = create_access_token(user.id, user.role)
    return Token(access_token=token)


@router.post("/google", response_model=Token)
def login_with_google(body: GoogleLogin, db: Session = Depends(get_db)):
    google_web_client_id = get_google_web_client_id()
    if not google_web_client_id:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google login is not configured",
        )

    try:
        from google.auth.transport import requests as google_requests
        from google.oauth2 import id_token as google_id_token
    except ModuleNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google login dependency is not installed",
        )

    try:
        payload = google_id_token.verify_oauth2_token(
            body.id_token,
            google_requests.Request(),
            google_web_client_id,
        )
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired Google identity token",
        )

    email = payload.get("email")
    email_verified = payload.get("email_verified")
    if not email or email_verified is not True:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Google account email is missing or unverified",
        )

    user = db.query(User).filter(User.email == email).first()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "code": "google_account_not_registered",
                "message": "No Upkeep account exists for this Google email",
                "email": email,
            },
        )

    token = create_access_token(user.id, user.role)
    return Token(access_token=token)
