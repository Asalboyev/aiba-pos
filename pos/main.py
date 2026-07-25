import asyncio
import os
from contextlib import asynccontextmanager
from pathlib import Path

from dotenv import load_dotenv
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from tortoise import Tortoise
from tortoise.contrib.fastapi import register_tortoise

from app.api.ai import ai_router
from app.api.internal import internal_router
from app.api.v2 import api_router as api_router_v2
from app.core.config import settings
from app.core.database import TORTOISE_ORM
from app.core.health import router as health_router
from app.core.logging import logger

load_dotenv()


def initialize_sentry():
    if not settings.SENTRY_DSN:
        return
    try:
        import sentry_sdk
        from sentry_sdk.integrations.fastapi import FastApiIntegration

        sentry_sdk.init(dsn=settings.SENTRY_DSN, integrations=[FastApiIntegration()], enable_tracing=True)
        logger.info("✅ Sentry initialized")
    except Exception as e:  # noqa: BLE001
        logger.warning(f"Sentry init skipped: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info(f"🚀 Starting {settings.APP_NAME} v{settings.APP_VERSION}")
    initialize_sentry()
    yield
    await Tortoise.close_connections()
    logger.info("🛑 DB connections closed")


app = FastAPI(title=settings.APP_NAME, version=settings.APP_VERSION, description="AIBA POS API", lifespan=lifespan)

_REQUEST_TIMEOUT_SECONDS = float(os.getenv("REQUEST_TIMEOUT_SECONDS", "60"))


@app.middleware("http")
async def _request_timeout(request: Request, call_next):
    timeout = 5.0 if request.url.path.startswith("/health") else _REQUEST_TIMEOUT_SECONDS
    try:
        return await asyncio.wait_for(call_next(request), timeout=timeout)
    except asyncio.TimeoutError:
        return JSONResponse(
            {"detail": "request timed out", "path": request.url.path}, status_code=status.HTTP_504_GATEWAY_TIMEOUT
        )


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# generate_schemas=True → CREATE TABLE IF NOT EXISTS on boot. Greenfield
# service, so no hand-authored migration is needed to run. Aerich can take
# over later (config in pyproject.toml) for incremental schema changes.
register_tortoise(app, config=TORTOISE_ORM, generate_schemas=True, add_exception_handlers=True)

Tortoise.init_models(["app.models"], "models")

app.include_router(api_router_v2, prefix="/api/v2")
app.include_router(internal_router, prefix="/api/internal/admin", include_in_schema=False)
app.include_router(ai_router, prefix="/api/ai")
app.include_router(health_router)

# Yuklangan rasmlar va boshqa statik fayllar shu yerdan xizmat qilinadi.
# Ex: POST /api/v2/uploads/image → {"url": "/static/uploads/abc123.webp"}
#     GET  /static/uploads/abc123.webp → rasm
_static_dir = Path(__file__).parent / "app" / "static"
(_static_dir / "uploads").mkdir(parents=True, exist_ok=True)
app.mount("/static", StaticFiles(directory=_static_dir), name="static")


@app.get("/admin", include_in_schema=False)
async def admin_page():
    """Single-file web admin (login = AIBA_SERVICE_SECRET)."""
    from pathlib import Path

    from fastapi.responses import FileResponse

    return FileResponse(Path(__file__).parent / "app" / "static" / "admin.html")
