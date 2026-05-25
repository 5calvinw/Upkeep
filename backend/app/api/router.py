from fastapi import APIRouter
from app.api import auth, users, units, tickets, properties

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(properties.router)
api_router.include_router(units.router)
api_router.include_router(tickets.router)
