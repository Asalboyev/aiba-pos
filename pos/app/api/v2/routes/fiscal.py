from fastapi import APIRouter, Depends, HTTPException

from app.api.helpers import get_scoped_order
from app.core.config import settings
from app.dependencies.auth import Principal, get_principal, require_service, resolve_restaurant_id
from app.models import FiscalReceipt

router = APIRouter(tags=["fiscal"])


def _receipt_dict(r: FiscalReceipt) -> dict:
    return {
        "id": str(r.id),
        "order_id": str(r.order_id),
        "status": r.status,
        "provider": r.provider,
        "operation": r.operation,
        "fiscal_sign": r.fiscal_sign,
        "fiscal_id": r.fiscal_id,
        "qr_url": r.qr_url,
        "retries": r.retries,
        "last_error": r.last_error,
        "sent_at": r.sent_at.isoformat() if r.sent_at else None,
    }


@router.get("/fiscal/receipt")
async def get_by_order(order_id: str, principal: Principal = Depends(get_principal)):
    order = await get_scoped_order(principal, order_id)
    receipt = await FiscalReceipt.filter(order_id=order.id).order_by("-created_at").first()
    if not receipt:
        raise HTTPException(status_code=404, detail="No fiscal receipt for this order")
    return _receipt_dict(receipt)


@router.post("/fiscal/receipts/{receipt_id}/retry")
async def retry(receipt_id: str, principal: Principal = Depends(get_principal)):
    receipt = await FiscalReceipt.filter(id=receipt_id).first()
    if not receipt:
        raise HTTPException(status_code=404, detail="Receipt not found")
    resolve_restaurant_id(principal, str(receipt.restaurant_id))  # scope guard
    from app.tasks.fiscal import submit_fiscal_receipt

    submit_fiscal_receipt.delay(str(receipt.id))
    return {"status": "requeued", "receipt_id": str(receipt.id)}


# --- E-POS Communicator debug endpoints (admin/service only) ---

@router.get("/fiscal/epos/health", dependencies=[Depends(require_service)])
async def epos_health():
    """E-POS Communicator servisi bilan aloqa borligini tekshiradi (checkStatus)."""
    from app.services.fiscal import get_provider

    provider = get_provider("epos")
    ok, err, raw = await provider.check_status()
    return {"provider": "epos", "url": settings.EPOS_API_URL, "ok": ok, "error": err, "raw": raw}


@router.get("/fiscal/epos/shift-status", dependencies=[Depends(require_service)])
async def epos_shift_status():
    """E-POS'da Z-report ochiqmi tekshiradi (getZReportsStatus)."""
    from app.services.fiscal import get_provider

    provider = get_provider("epos")
    is_open, err, raw = await provider.shift_status()
    return {"is_open": is_open, "error": err, "raw": raw}
