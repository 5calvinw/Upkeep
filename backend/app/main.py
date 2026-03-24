from fastapi import FastAPI
from app.api.router import api_router
from app.db import base  # noqa — registers all models with SQLAlchemy
from app.db.base_class import Base
from app.db.session import engine

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Upkeep API")

app.include_router(api_router)


@app.get("/")
def root():
    return {"message": "Upkeep API running"}