import hmac

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.core.config import settings
from app.core.security import create_access_token, hash_pin, verify_pin
from app.dependencies.auth import require_service
from app.models import AdminAccount, Restaurant, StaffUser, Terminal

router = APIRouter(dependencies=[Depends(require_service)], tags=["admin"])

# Login stays outside the service-secret guard — it's how the web adminka
# obtains its admin JWT in the first place.
public_router = APIRouter(tags=["admin"])


class AdminLoginIn(BaseModel):
    username: str
    password: str


@public_router.post("/login")
async def admin_login(data: AdminLoginIn):
    """Adminka'ga kirish — avval DB'da AdminAccount qidiradi, agar hech kim yo'q
    bo'lsa .env'dagi default (bir marta kirish uchun) bilan tekshiradi.

    Bu bir marta DB'ga admin qo'shilsa, .env parol ishlamaydi — barcha loginlar
    faqat DB orqali. Bu xavfsizlik uchun to'g'ri.
    """
    acc = await AdminAccount.filter(username=data.username, is_active=True).first()
    if acc:
        if not verify_pin(data.password, acc.password_hash):
            raise HTTPException(status_code=401, detail="Login yoki parol noto'g'ri")
    else:
        # DB'da hech kim yo'q — .env fallback (default admin/aiba2026)
        has_any_admin = await AdminAccount.exists()
        if has_any_admin:
            raise HTTPException(status_code=401, detail="Login yoki parol noto'g'ri")
        user_ok = hmac.compare_digest(data.username, settings.ADMIN_USERNAME)
        pass_ok = hmac.compare_digest(data.password, settings.ADMIN_PASSWORD)
        if not (user_ok and pass_ok):
            raise HTTPException(status_code=401, detail="Login yoki parol noto'g'ri")
    token = create_access_token(
        {"sub": acc.username if acc else "admin", "role": "admin"},
        expires_minutes=60 * 24,
    )
    return {
        "access_token": token,
        "token_type": "bearer",
        "username": acc.username if acc else settings.ADMIN_USERNAME,
    }


class ChangePasswordIn(BaseModel):
    current_password: str
    new_username: Optional[str] = None
    new_password: Optional[str] = None


@router.post("/change-password")
async def change_password(data: ChangePasswordIn):
    """Adminka username va/yoki parolini o'zgartiradi. Birinchi marta chaqirilsa
    DB'da hech kim yo'q bo'lsa yangi AdminAccount yaratadi (.env default'ini
    almashtiradi). Keyingi safar shu account'ni yangilaydi."""
    acc = await AdminAccount.filter(is_active=True).first()
    if acc:
        # Mavjud parolni tekshirish
        if not verify_pin(data.current_password, acc.password_hash):
            raise HTTPException(400, detail="Amaldagi parol noto'g'ri")
    else:
        # DB'da hech kim yo'q — .env parolini talab qilamiz
        if not hmac.compare_digest(data.current_password, settings.ADMIN_PASSWORD):
            raise HTTPException(400, detail="Amaldagi parol noto'g'ri")
        acc = await AdminAccount.create(
            username=settings.ADMIN_USERNAME,
            password_hash=hash_pin(settings.ADMIN_PASSWORD),
        )
    if data.new_username:
        u = data.new_username.strip()
        if not u:
            raise HTTPException(400, detail="Foydalanuvchi nomi bo'sh bo'lmasin")
        if len(u) < 3 or len(u) > 60:
            raise HTTPException(400, detail="Foydalanuvchi nomi 3-60 belgi bo'lishi kerak")
        # Boshqa akkaunt shu nom bilan bo'lmasligi
        other = await AdminAccount.filter(username=u).exclude(id=acc.id).first()
        if other:
            raise HTTPException(409, detail="Bunday foydalanuvchi nomi allaqachon bor")
        acc.username = u
    if data.new_password:
        if len(data.new_password) < 4:
            raise HTTPException(400, detail="Parol kamida 4 belgi bo'lishi kerak")
        acc.password_hash = hash_pin(data.new_password)
    await acc.save()
    return {"username": acc.username, "updated": True}


class RestaurantIn(BaseModel):
    name: str
    code: str
    company_id: Optional[str] = None
    legal_name: Optional[str] = None
    inn: Optional[str] = None
    address: Optional[str] = None


class RestaurantPatch(BaseModel):
    name: Optional[str] = None
    legal_name: Optional[str] = None
    inn: Optional[str] = None
    address: Optional[str] = None
    is_active: Optional[bool] = None
    # Chek sozlamalari
    receipt_logo_url: Optional[str] = None
    receipt_header: Optional[str] = None
    receipt_footer: Optional[str] = None
    receipt_phone: Optional[str] = None
    receipt_show_qr: Optional[bool] = None
    receipt_show_mxik: Optional[bool] = None
    receipt_paper_width: Optional[int] = None


class TerminalIn(BaseModel):
    name: str
    code: str
    fiscal_terminal_id: Optional[str] = None


class StaffIn(BaseModel):
    full_name: str
    code: str
    pin: str
    role: str = "cashier"
    cloud_user_id: Optional[str] = None


class StaffPatch(BaseModel):
    full_name: Optional[str] = None
    role: Optional[str] = None
    pin: Optional[str] = None  # set = reset PIN
    is_active: Optional[bool] = None


class TerminalPatch(BaseModel):
    name: Optional[str] = None
    fiscal_terminal_id: Optional[str] = None
    is_active: Optional[bool] = None


# ---- Restaurants (tenants) ----


@router.post("/restaurants")
async def create_restaurant(data: RestaurantIn):
    if await Restaurant.filter(code=data.code).first():
        raise HTTPException(status_code=409, detail="Restaurant code already exists")
    r = await Restaurant.create(**data.model_dump())
    return {"id": str(r.id), "code": r.code, "name": r.name}


def _restaurant_dict(r: Restaurant) -> dict:
    return {
        "id": str(r.id),
        "code": r.code,
        "name": r.name,
        "legal_name": r.legal_name,
        "inn": r.inn,
        "address": r.address,
        "company_id": str(r.company_id) if r.company_id else None,
        "is_active": r.is_active,
        "receipt_logo_url": r.receipt_logo_url,
        "receipt_header": r.receipt_header,
        "receipt_footer": r.receipt_footer,
        "receipt_phone": r.receipt_phone,
        "receipt_show_qr": r.receipt_show_qr,
        "receipt_show_mxik": r.receipt_show_mxik,
        "receipt_paper_width": r.receipt_paper_width,
    }


@router.get("/restaurants")
async def list_restaurants():
    rows = await Restaurant.all().order_by("name")
    return [_restaurant_dict(r) for r in rows]


@router.get("/restaurants/{restaurant_id}")
async def get_restaurant_details(restaurant_id: str):
    r = await Restaurant.filter(id=restaurant_id).first()
    if not r:
        raise HTTPException(404, detail="Restaurant not found")
    return _restaurant_dict(r)


@router.patch("/restaurants/{restaurant_id}")
async def update_restaurant(restaurant_id: str, data: RestaurantPatch):
    r = await Restaurant.filter(id=restaurant_id).first()
    if not r:
        raise HTTPException(404, detail="Restaurant not found")
    updates = data.model_dump(exclude_unset=True)
    for k, v in updates.items():
        setattr(r, k, v)
    await r.save()
    return _restaurant_dict(r)


# ---- Terminals ----


@router.post("/restaurants/{restaurant_id}/terminals")
async def create_terminal(restaurant_id: str, data: TerminalIn):
    r = await Restaurant.filter(id=restaurant_id).first()
    if not r:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    if await Terminal.filter(code=data.code).first():
        raise HTTPException(status_code=409, detail="Terminal code already exists")
    t = await Terminal.create(
        restaurant=r, name=data.name, code=data.code, fiscal_terminal_id=data.fiscal_terminal_id
    )
    return {"id": str(t.id), "code": t.code, "name": t.name, "fiscal_terminal_id": t.fiscal_terminal_id}


@router.get("/restaurants/{restaurant_id}/terminals")
async def list_terminals(restaurant_id: str):
    rows = await Terminal.filter(restaurant_id=restaurant_id).order_by("name")
    return [
        {
            "id": str(t.id),
            "code": t.code,
            "name": t.name,
            "fiscal_terminal_id": t.fiscal_terminal_id,
            "is_active": t.is_active,
        }
        for t in rows
    ]


@router.patch("/restaurants/{restaurant_id}/terminals/{terminal_id}")
async def update_terminal(restaurant_id: str, terminal_id: str, data: TerminalPatch):
    t = await Terminal.filter(id=terminal_id, restaurant_id=restaurant_id).first()
    if not t:
        raise HTTPException(status_code=404, detail="Terminal not found")
    if data.name is not None:
        t.name = data.name
    if data.fiscal_terminal_id is not None:
        t.fiscal_terminal_id = data.fiscal_terminal_id
    if data.is_active is not None:
        t.is_active = data.is_active
    await t.save()
    return {
        "id": str(t.id),
        "code": t.code,
        "name": t.name,
        "fiscal_terminal_id": t.fiscal_terminal_id,
        "is_active": t.is_active,
    }


# ---- Staff (access) ----


@router.post("/restaurants/{restaurant_id}/staff")
async def create_staff(restaurant_id: str, data: StaffIn):
    r = await Restaurant.filter(id=restaurant_id).first()
    if not r:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    if await StaffUser.filter(restaurant_id=restaurant_id, code=data.code).first():
        raise HTTPException(status_code=409, detail="Staff code already exists in this restaurant")
    s = await StaffUser.create(
        restaurant=r,
        full_name=data.full_name,
        code=data.code,
        pin_hash=hash_pin(data.pin),
        role=data.role,
        cloud_user_id=data.cloud_user_id,
    )
    return {"id": str(s.id), "code": s.code, "full_name": s.full_name, "role": s.role}


@router.get("/restaurants/{restaurant_id}/staff")
async def list_staff(restaurant_id: str):
    rows = await StaffUser.filter(restaurant_id=restaurant_id).order_by("full_name")
    return [
        {"id": str(s.id), "code": s.code, "full_name": s.full_name, "role": s.role, "is_active": s.is_active}
        for s in rows
    ]


@router.patch("/restaurants/{restaurant_id}/staff/{staff_id}")
async def update_staff(restaurant_id: str, staff_id: str, data: StaffPatch):
    s = await StaffUser.filter(id=staff_id, restaurant_id=restaurant_id).first()
    if not s:
        raise HTTPException(status_code=404, detail="Staff not found")
    if data.full_name is not None:
        s.full_name = data.full_name
    if data.role is not None:
        s.role = data.role
    if data.pin:
        s.pin_hash = hash_pin(data.pin)
    if data.is_active is not None:
        s.is_active = data.is_active
    await s.save()
    return {"id": str(s.id), "code": s.code, "full_name": s.full_name, "role": s.role, "is_active": s.is_active}
