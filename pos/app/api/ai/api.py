from fastapi import APIRouter

from app.api.ai import tool

ai_router = APIRouter()
ai_router.include_router(tool.router)
