from app.core.celery import celery_app, ensure_tortoise_initialized, run_async
from app.core.config import settings
from app.core.logging import logger
from app.utils.timezone import now


@celery_app.task(name="app.tasks.fiscal.submit_fiscal_receipt")
def submit_fiscal_receipt(receipt_id: str):
    """Register one fiscal cheque with the virtual cash register / OFD."""

    async def _run():
        await ensure_tortoise_initialized()
        from app.models import FiscalReceipt
        from app.services.fiscal import get_provider
        from app.services.orders import build_fiscal_request

        receipt = await FiscalReceipt.filter(id=receipt_id).first()
        if not receipt:
            return {"error": "receipt not found"}
        if receipt.status == "sent":
            return {"status": "already_sent"}

        req = await build_fiscal_request(receipt)
        provider = get_provider(receipt.provider)
        result = await provider.register_receipt(req)

        # Auto-recovery: E-POS "ZReport zakryt" bo'lsa smenani qayta ochib chekni
        # yana bir marta urinib ko'ramiz. Kassa unutgan yoki qo'shni sinov
        # foydalanuvchisi yopib qo'ygan holatlarga qarshi.
        if not result.success and result.error and "ZReport" in result.error and hasattr(provider, "open_shift"):
            ok, err, _ = await provider.open_shift()
            if ok:
                logger.info("🔓 E-POS Z-report auto-reopened, retrying receipt")
                result = await provider.register_receipt(req)

        if result.success:
            receipt.status = "sent"
            receipt.fiscal_sign = result.fiscal_sign
            receipt.fiscal_id = result.fiscal_id
            receipt.qr_url = result.qr_url
            receipt.raw_response = result.raw_response
            receipt.sent_at = now()
            receipt.last_error = None
            await receipt.save()
            logger.info(f"✅ fiscal cheque sent: receipt={receipt.id} sign={result.fiscal_sign}")
            return {"status": "sent", "fiscal_sign": result.fiscal_sign}

        receipt.status = "failed"
        receipt.retries = (receipt.retries or 0) + 1
        receipt.last_error = result.error
        receipt.raw_response = result.raw_response or {}
        await receipt.save()
        logger.warning(f"⚠️ fiscal cheque failed: receipt={receipt.id} err={result.error}")
        return {"status": "failed", "error": result.error, "retries": receipt.retries}

    return run_async(_run())


@celery_app.task(name="app.tasks.fiscal.retry_pending_fiscal")
def retry_pending_fiscal():
    """Re-queue every cheque still pending/failed (offline-window recovery)."""

    async def _run():
        await ensure_tortoise_initialized()
        from app.models import FiscalReceipt

        stuck = (
            await FiscalReceipt.filter(status__in=["pending", "failed"], retries__lt=settings.FISCAL_MAX_RETRIES)
            .order_by("created_at")
            .limit(200)
        )
        return [str(r.id) for r in stuck]

    ids = run_async(_run())
    for rid in ids:
        submit_fiscal_receipt.delay(rid)
    if ids:
        logger.info(f"🔁 re-queued {len(ids)} pending fiscal cheque(s)")
    return {"requeued": len(ids)}
