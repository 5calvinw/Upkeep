import os
import uuid

from fastapi import FastAPI, UploadFile, File, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import inspect, text
from app.api.router import api_router
from app.core.deps import get_current_user
from app.db import base  # noqa — registers all models with SQLAlchemy
from app.db.base_class import Base
from app.db.session import engine

Base.metadata.create_all(bind=engine)


def ensure_ticket_photo_urls_schema() -> None:
    inspector = inspect(engine)
    columns = {column["name"] for column in inspector.get_columns("maintenancerequest")}
    if "photo_urls" in columns:
        return

    with engine.begin() as connection:
        if connection.dialect.name == "postgresql":
            connection.execute(text("ALTER TABLE maintenancerequest ADD COLUMN photo_urls JSON"))
            connection.execute(text("""
                UPDATE maintenancerequest
                SET photo_urls = CASE
                    WHEN photo_url IS NULL OR photo_url = '' THEN '[]'::json
                    ELSE json_build_array(photo_url)
                END
                WHERE photo_urls IS NULL
            """))
            connection.execute(text("ALTER TABLE maintenancerequest ALTER COLUMN photo_urls SET DEFAULT '[]'::json"))
            connection.execute(text("UPDATE maintenancerequest SET photo_urls = '[]'::json WHERE photo_urls IS NULL"))
            connection.execute(text("ALTER TABLE maintenancerequest ALTER COLUMN photo_urls SET NOT NULL"))
        else:
            connection.execute(text("ALTER TABLE maintenancerequest ADD COLUMN photo_urls TEXT DEFAULT '[]'"))
            connection.execute(text("""
                UPDATE maintenancerequest
                SET photo_urls = CASE
                    WHEN photo_url IS NULL OR photo_url = '' THEN '[]'
                    ELSE '["' || photo_url || '"]'
                END
                WHERE photo_urls IS NULL OR photo_urls = ''
            """))


ensure_ticket_photo_urls_schema()

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

app = FastAPI(title="Upkeep API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")
app.include_router(api_router)


@app.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    current_user=Depends(get_current_user),
):
    ext = os.path.splitext(file.filename or "photo")[1] or ".jpg"
    filename = f"{uuid.uuid4()}{ext}"
    path = os.path.join(UPLOAD_DIR, filename)
    content = await file.read()
    with open(path, "wb") as f:
        f.write(content)
    return {"url": f"http://localhost:8000/uploads/{filename}"}


@app.get("/")
def root():
    return {"message": "Upkeep API running"}
