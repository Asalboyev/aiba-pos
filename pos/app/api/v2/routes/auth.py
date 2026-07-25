from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException

from app.core.security import create_access_token, verify_pin
from app.dependencies.auth import Principal, get_principal
from app.models import Restaurant, Shift, StaffUser, Terminal
from app.schemas.auth import TerminalLoginIn

router = APIRouter(tags=["auth"])


def _restaurant_public(r: Restaurant) -> dict:
    """Adminka chek sozlamalarini o'zgartirsa, terminal shu endpoint orqali
    yangi qiymatlarni oladi va chekni ular bilan chop etadi.
    """
    return {
        "id": str(r.id),
        "name": r.name,
        "code": r.code,
        "legal_name": r.legal_name,
        "inn": r.inn,
        "address": r.address,
        "receipt_logo_url": r.receipt_logo_url,
        "receipt_header": r.receipt_header,
        "receipt_footer": r.receipt_footer,
        "receipt_phone": r.receipt_phone,
        "receipt_show_qr": r.receipt_show_qr,
        "receipt_show_mxik": r.receipt_show_mxik,
        "receipt_paper_width": r.receipt_paper_width,
    }


@router.get("/restaurant/me")
async def get_my_restaurant(principal: Principal = Depends(get_principal)):
    """Terminal token bilan o'z restoranini olib, chek sozlamalarini yangilaydi."""
    if not principal.restaurant_id:
        raise HTTPException(status_code=401, detail="Missing restaurant context")
    r = await Restaurant.filter(id=principal.restaurant_id, is_active=True).first()
    if not r:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    return _restaurant_public(r)


@router.post("/auth/login")
async def login(data: TerminalLoginIn):
    """Terminal + staff login → scoped JWT.

    The token is pinned to one restaurant + terminal + staff role, so the
    terminal can only ever read/write its own restaurant's data. cloud-os
    creates the terminal codes and staff PINs (access control lives there).
    """
    terminal = await Terminal.filter(code=data.terminal_code, is_active=True).first()
    if not terminal:
        raise HTTPException(status_code=404, detail="Terminal not found")

    restaurant = await Restaurant.filter(id=terminal.restaurant_id, is_active=True).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found or inactive")

    staff = await StaffUser.filter(restaurant_id=restaurant.id, code=data.staff_code, is_active=True).first()
    if not staff or not verify_pin(data.pin, staff.pin_hash):
        raise HTTPException(status_code=401, detail="Invalid staff code or PIN")

    shift = None
    if data.open_shift:
        shift = await Shift.filter(terminal_id=terminal.id, status="open").first()
        if not shift:
            shift = await Shift.create(
                restaurant=restaurant,
                terminal=terminal,
                opened_by=staff,
                status="open",
                opening_cash=Decimal(str(data.opening_cash)),
            )

    claims = {
        "sub": str(staff.id),
        "restaurant_id": str(restaurant.id),
        "terminal_id": str(terminal.id),
        "role": staff.role,
    }
    if shift:
        claims["shift_id"] = str(shift.id)

    return {
        "access_token": create_access_token(claims),
        "token_type": "bearer",
        "restaurant": {
            "id": str(restaurant.id),
            "name": restaurant.name,
            "code": restaurant.code,
            "legal_name": restaurant.legal_name,
            "inn": restaurant.inn,
            "address": restaurant.address,
            # Chek sozlamalari — kassir ilova o'z chekini shu bo'yicha chop etadi.
            "receipt_logo_url": restaurant.receipt_logo_url,
            "receipt_header": restaurant.receipt_header,
            "receipt_footer": restaurant.receipt_footer,
            "receipt_phone": restaurant.receipt_phone,
            "receipt_show_qr": restaurant.receipt_show_qr,
            "receipt_show_mxik": restaurant.receipt_show_mxik,
            "receipt_paper_width": restaurant.receipt_paper_width,
        },
        "terminal": {
            "id": str(terminal.id),
            "name": terminal.name,
            "code": terminal.code,
            "fiscal_terminal_id": terminal.fiscal_terminal_id,
        },
        "staff": {"id": str(staff.id), "name": staff.full_name, "role": staff.role},
        "shift_id": str(shift.id) if shift else None,
    }
