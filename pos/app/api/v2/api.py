from fastapi import APIRouter

from app.api.v2.routes import auth, fiscal, menu, orders, reports, shifts, sync, uploads

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(menu.router)
api_router.include_router(orders.router)
api_router.include_router(sync.router)
api_router.include_router(shifts.router)
api_router.include_router(fiscal.router)
api_router.include_router(reports.router)
api_router.include_router(uploads.router)
