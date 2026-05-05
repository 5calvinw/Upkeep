import os
from pathlib import Path
from dotenv import load_dotenv

# Load `backend/.env` first, then allow repo-root `.env` as a fallback.
_BACKEND_DIR = Path(__file__).resolve().parents[2]
_BACKEND_ENV = _BACKEND_DIR / ".env"
_REPO_ENV = _BACKEND_DIR.parent / ".env"

if _BACKEND_ENV.exists():
    load_dotenv(_BACKEND_ENV)
if _REPO_ENV.exists():
    load_dotenv(_REPO_ENV, override=False)
if not _BACKEND_ENV.exists() and not _REPO_ENV.exists():
    load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
JWT_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", "60"))
INVITE_EXPIRE_DAYS = int(os.getenv("INVITE_EXPIRE_DAYS", "7"))
GOOGLE_WEB_CLIENT_ID = os.getenv("GOOGLE_WEB_CLIENT_ID")


def get_google_web_client_id() -> str:
    """Read lazily so restarted processes and env edits are reflected safely."""
    return (os.getenv("GOOGLE_WEB_CLIENT_ID") or "").strip()
