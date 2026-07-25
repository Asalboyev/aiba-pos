from fastapi import APIRouter
from tortoise import connections

router = APIRouter()


@router.get("/health")
async def health():
    return {"status": "ok"}


@router.get("/health/ready")
async def ready():
    try:
        conn = connections.get("default")
        await conn.execute_query("SELECT 1")
        return {"status": "ready", "db": "ok"}
    except Exception as e:  # noqa: BLE001
        return {"status": "degraded", "db": str(e)}
