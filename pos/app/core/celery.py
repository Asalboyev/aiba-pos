import asyncio

from celery import Celery, signals
from celery.schedules import crontab
from tortoise import Tortoise

from app.core.config import settings
from app.core.logging import logger

celery_app = Celery("aiba-pos", broker=settings.CELERY_BROKER_URL, backend=settings.CELERY_RESULT_BACKEND)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone=settings.TIMEZONE,
    enable_utc=True,
    task_track_started=True,
    task_acks_late=True,
    broker_connection_retry_on_startup=True,
    result_expires=6 * 3600,
    task_default_queue="pos",
    include=["app.tasks.fiscal"],
    beat_schedule={
        # Re-submit any fiscal cheque still pending/failed (e.g. created while
        # offline, or when the OFD was down). This is what makes an offline
        # sale eventually become a legal fiscal cheque.
        "retry-pending-fiscal": {
            "task": "app.tasks.fiscal.retry_pending_fiscal",
            "schedule": crontab(minute="*/1"),
            "options": {"queue": "pos"},
        },
    },
)

_loop = None


def get_or_create_loop():
    global _loop
    if _loop is not None and not _loop.is_closed():
        return _loop
    try:
        loop = asyncio.get_running_loop()
        return loop
    except RuntimeError:
        pass
    _loop = asyncio.new_event_loop()
    asyncio.set_event_loop(_loop)
    return _loop


def run_async(coro):
    """Safely run async code inside a sync Celery task."""
    global _loop
    loop = get_or_create_loop()
    try:
        return loop.run_until_complete(coro)
    except RuntimeError as e:
        if "attached to a different loop" in str(e) or "closed" in str(e).lower():
            logger.warning(f"Loop issue, reinitializing: {e}")
            try:
                if _loop and not _loop.is_closed():
                    _loop.run_until_complete(Tortoise.close_connections())
            except Exception:
                pass
            _loop = asyncio.new_event_loop()
            asyncio.set_event_loop(_loop)
            from app.core.database import TORTOISE_ORM

            _loop.run_until_complete(Tortoise.init(config=TORTOISE_ORM))
            return _loop.run_until_complete(coro)
        raise


async def ensure_tortoise_initialized():
    try:
        from tortoise import connections

        if connections.get("default"):
            return
    except Exception:
        pass
    from app.core.database import TORTOISE_ORM

    await Tortoise.init(config=TORTOISE_ORM)


@signals.worker_process_init.connect
def on_worker_init(**kwargs):
    global _loop
    _loop = asyncio.new_event_loop()
    asyncio.set_event_loop(_loop)
    from app.core.database import TORTOISE_ORM

    _loop.run_until_complete(Tortoise.init(config=TORTOISE_ORM))
    # Idempotent — ensures tables exist even if the web service hasn't booted yet.
    _loop.run_until_complete(Tortoise.generate_schemas(safe=True))
    logger.info("✅ Tortoise ORM initialized in Celery worker")


@signals.worker_process_shutdown.connect
def on_worker_shutdown(**kwargs):
    global _loop
    if _loop:
        try:
            if not _loop.is_closed():
                _loop.run_until_complete(Tortoise.close_connections())
        except Exception as e:  # noqa: BLE001
            logger.error(f"Cleanup error: {e}")
        finally:
            try:
                _loop.close()
            except Exception:
                pass
            _loop = None
