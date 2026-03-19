from fastapi import FastAPI
from app.db.session import engine


app = FastAPI()

@app.get("/")
def root():
    return {"message": "Upkeep API running"}

@app.get("/test-db")
def test_db():
    return {"status": "DB connected"}