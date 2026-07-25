from fastapi import APIRouter

from app.api.internal.routes import admin, seed

internal_router = APIRouter()
internal_router.include_router(admin.public_router)
internal_router.include_router(admin.router)
internal_router.include_router(seed.router)
