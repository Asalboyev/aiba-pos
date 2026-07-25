from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException

from app.api.helpers import get_restaurant, resolve_terminal
from app.core.config import settings
from app.core.logging import logger
from app.dependencies.auth import Principal, get_principal
from app.models import Shift
from app.schemas.order import CloseShiftIn, OpenShiftIn
from app.utils.timezone import now

router = APIRouter(tags=["shifts"])

_CENT = Decimal("0.01")


def _m(value) -> str:
    return str(Decimal(str(value or 0)).quantize(_CENT))


def _shift_dict(s: Shift) -> dict:
    return {
        "id": str(s.id),
        "status": s.status,
        "restaurant_id": str(s.restaurant_id),
        "terminal_id": str(s.terminal_id),
        "opened_at": s.opened_at.isoformat() if s.opened_at else None,
        "closed_at": s.closed_at.isoformat() if s.closed_at else None,
        "opening_cash": _m(s.opening_cash),
        "total_cash": _m(s.total_cash),
        "total_card": _m(s.total_card),
        "total_sales": _m(s.total_sales),
        "orders_count": s.orders_count,
    }


async def _epos_open_hook() -> dict:
    """Agar FISCAL_PROVIDER=epos bo'lsa, E-POS'da openZreport chaqiradi.
    Xato bo'lsa smena baribir bizda ochiladi (fiscal retry kelajakda qayta uradi)."""
    if settings.FISCAL_PROVIDER != "epos":
        return {"skipped": True}
    from app.services.fiscal import get_provider

    provider = get_provider("epos")
    is_open, err, _ = await provider.shift_status()
    if is_open:
        return {"already_open": True}
    ok, err, raw = await provider.open_shift()
    if not ok:
        logger.warning(f"E-POS openZreport failed: {err}")
    return {"opened": ok, "error": err, "raw": raw}


async def _epos_close_hook() -> dict:
    if settings.FISCAL_PROVIDER != "epos":
        return {"skipped": True}
    from app.services.fiscal import get_provider

    provider = get_provider("epos")
    ok, err, raw = await provider.close_shift()
    if not ok:
        logger.warning(f"E-POS closeZreport failed: {err}")
    return {"closed": ok, "error": err, "raw": raw}


@router.post("/shifts/open")
async def open_shift(data: OpenShiftIn, principal: Principal = Depends(get_principal)):
    restaurant = await get_restaurant(principal, data.restaurant_id)
    terminal = await resolve_terminal(principal, restaurant, data.terminal_id)
    existing = await Shift.filter(terminal_id=terminal.id, status="open").first()
    if existing:
        return {"created": False, "shift": _shift_dict(existing)}
    staff_id = principal.staff_id
    shift = await Shift.create(
        restaurant=restaurant,
        terminal=terminal,
        opened_by_id=staff_id,
        status="open",
        opening_cash=data.opening_cash,
    )
    epos = await _epos_open_hook()
    return {"created": True, "shift": _shift_dict(shift), "epos": epos}


@router.get("/shifts/current")
async def current_shift(
    restaurant_id: Optional[str] = None,
    terminal_id: Optional[str] = None,
    principal: Principal = Depends(get_principal),
):
    restaurant = await get_restaurant(principal, restaurant_id)
    terminal = await resolve_terminal(principal, restaurant, terminal_id)
    shift = await Shift.filter(terminal_id=terminal.id, status="open").first()
    return {"shift": _shift_dict(shift) if shift else None}


@router.post("/shifts/close")
async def close_shift(data: CloseShiftIn, principal: Principal = Depends(get_principal)):
    shift_id = data.shift_id or principal.shift_id
    shift = await Shift.filter(id=shift_id).first() if shift_id else None
    if not shift:
        raise HTTPException(status_code=404, detail="Open shift not found")
    # Cross-restaurant guard for terminal tokens.
    if not principal.is_service and principal.restaurant_id and str(shift.restaurant_id) != principal.restaurant_id:
        raise HTTPException(status_code=403, detail="Cross-restaurant access denied")
    if shift.status == "closed":
        return {"shift": _shift_dict(shift), "z_report": _shift_dict(shift)}
    shift.status = "closed"
    shift.closed_at = now()
    await shift.save(update_fields=["status", "closed_at", "updated_at"])
    epos = await _epos_close_hook()
    return {"shift": _shift_dict(shift), "z_report": _shift_dict(shift), "epos": epos}
