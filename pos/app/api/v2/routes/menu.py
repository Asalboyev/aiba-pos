from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.api.helpers import require_manager
from app.core.config import settings
from app.core.logging import logger
from app.dependencies.auth import Principal, get_principal, resolve_restaurant_id
from app.models import Category, Product, StockMovement
from app.schemas.menu import CategoryIn, ProductIn

router = APIRouter(tags=["menu"])


async def _validate_against_epos(mxik: Optional[str], package_code: Optional[str]) -> None:
    """Adminka'da mahsulot saqlanishidan oldin MXIK+packageCode ni E-POS bilan
    tekshirib olamiz. Chek yaratishda "IKPU не найдены" yoki "Неправильный код
    единицы измерения" xatosining oldini oladi.

    Faqat FISCAL_PROVIDER=epos bo'lganda tekshiriladi. E-POS'da tekshiruv metodi
    yo'q bo'lsa (NO_SUCH_METHOD_AVAILABLE) tekshiruv o'tkazib yuboriladi (soft-fail).
    """
    if settings.FISCAL_PROVIDER != "epos" or not mxik:
        return
    try:
        from app.services.fiscal import get_provider

        provider = get_provider("epos")
        # 1. IKPU'ning umumiy strukturasi (17 raqam) allaqachon schema'da tekshirilgan
        # 2. E-POS 'onlineLabelValidation' yoki 'labelValidation' orqali tekshirish
        import httpx

        async with httpx.AsyncClient(timeout=8.0) as c:
            resp = await c.post(settings.EPOS_API_URL, json={
                "token": settings.EPOS_TOKEN,
                "method": "onlineLabelValidation",
                "classCode": mxik,
                "label": "",
            })
        data = resp.json() if resp.status_code < 400 else {}
        msg = data.get("message", "")
        if data.get("error"):
            m = msg if isinstance(msg, str) else str(msg)
            # NO_SUCH_METHOD => tekshiruv o'tkazib yuboriladi (E-POS eski versiya)
            if "NO_SUCH_METHOD" in m or "not implemented" in m.lower():
                logger.info("E-POS validation method unavailable, skipping check")
                return
            # IKPU bazada yo'q — aniq xato
            if "не найден" in m or "ИКПУ" in m or "IKPU" in m or "classCode" in m:
                raise HTTPException(400, detail=f"MXIK '{mxik}' E-POS bazasida yo'q — tasnif.soliq.uz'dan tekshiring")
    except HTTPException:
        raise
    except Exception as e:  # noqa: BLE001
        # E-POS erishib bo'lmasa (tarmoq / servis o'chirilgan) — bloklaymaymiz
        logger.warning(f"E-POS validation skipped (unreachable): {e}")


def _product_dict(p: Product) -> dict:
    return {
        "id": str(p.id),
        "category_id": str(p.category_id) if p.category_id else None,
        "name": p.name,
        "sku": p.sku,
        "price": str(p.price),
        "mxik_code": p.mxik_code,
        "package_code": p.package_code,
        "vat_percent": str(p.vat_percent),
        "unit": p.unit,
        "image_url": p.image_url,
        "is_active": p.is_active,
        "marking_required": p.marking_required,
        "track_stock": p.track_stock,
        "stock_qty": str(p.stock_qty),
        "low_stock_threshold": str(p.low_stock_threshold),
    }


def _category_dict(c: Category) -> dict:
    return {
        "id": str(c.id),
        "name": c.name,
        "sort_order": c.sort_order,
        "image_url": c.image_url,
        "is_active": c.is_active,
    }


@router.get("/menu/categories")
async def list_categories(restaurant_id: Optional[str] = None, principal: Principal = Depends(get_principal)):
    rid = resolve_restaurant_id(principal, restaurant_id)
    cats = await Category.filter(restaurant_id=rid, is_active=True).order_by("sort_order", "name")
    return [_category_dict(c) for c in cats]


@router.get("/menu/products")
async def list_products(
    restaurant_id: Optional[str] = None,
    category_id: Optional[str] = None,
    include_inactive: bool = False,
    principal: Principal = Depends(get_principal),
):
    rid = resolve_restaurant_id(principal, restaurant_id)
    q = Product.filter(restaurant_id=rid)
    # Terminals only ever sell active products; the admin UI (service) may
    # list deactivated ones to re-enable or audit them.
    if not (include_inactive and principal.is_service):
        q = q.filter(is_active=True)
    if category_id:
        q = q.filter(category_id=category_id)
    products = await q.order_by("name")
    return [_product_dict(p) for p in products]


@router.post("/menu/categories")
async def create_category(data: CategoryIn, principal: Principal = Depends(get_principal)):
    require_manager(principal)
    rid = resolve_restaurant_id(principal, data.restaurant_id)
    cat = await Category.create(
        restaurant_id=rid,
        name=data.name,
        sort_order=data.sort_order,
        is_active=data.is_active,
        image_url=data.image_url,
    )
    return _category_dict(cat)


@router.patch("/menu/categories/{category_id}")
async def update_category(category_id: str, data: CategoryIn, principal: Principal = Depends(get_principal)):
    require_manager(principal)
    rid = resolve_restaurant_id(principal, data.restaurant_id)
    cat = await Category.filter(id=category_id, restaurant_id=rid).first()
    if not cat:
        raise HTTPException(404, detail="Category not found")
    cat.name = data.name
    cat.sort_order = data.sort_order
    cat.is_active = data.is_active
    cat.image_url = data.image_url
    await cat.save()
    return _category_dict(cat)


@router.post("/menu/products")
async def create_product(data: ProductIn, principal: Principal = Depends(get_principal)):
    require_manager(principal)
    rid = resolve_restaurant_id(principal, data.restaurant_id)
    if data.category_id:
        cat = await Category.filter(id=data.category_id, restaurant_id=rid).first()
        if not cat:
            raise HTTPException(status_code=400, detail="Category not found in this restaurant")
    await _validate_against_epos(data.mxik_code, data.package_code)
    product = await Product.create(
        restaurant_id=rid,
        category_id=data.category_id,
        name=data.name,
        sku=data.sku,
        price=data.price,
        mxik_code=data.mxik_code,
        package_code=data.package_code,
        vat_percent=data.vat_percent,
        unit=data.unit,
        is_active=data.is_active,
        image_url=data.image_url,
        marking_required=data.marking_required,
        track_stock=data.track_stock,
        stock_qty=data.stock_qty,
        low_stock_threshold=data.low_stock_threshold,
    )
    return _product_dict(product)


@router.patch("/menu/products/{product_id}")
async def update_product(product_id: str, data: ProductIn, principal: Principal = Depends(get_principal)):
    require_manager(principal)
    rid = resolve_restaurant_id(principal, data.restaurant_id)
    product = await Product.filter(id=product_id, restaurant_id=rid).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    # MXIK/packageCode o'zgargan bo'lsa E-POS'ga tekshirtiramiz
    if data.mxik_code != product.mxik_code or data.package_code != product.package_code:
        await _validate_against_epos(data.mxik_code, data.package_code)
    product.name = data.name
    product.price = data.price
    product.category_id = data.category_id
    product.sku = data.sku
    product.mxik_code = data.mxik_code
    product.package_code = data.package_code
    product.vat_percent = data.vat_percent
    product.unit = data.unit
    product.is_active = data.is_active
    product.image_url = data.image_url
    product.marking_required = data.marking_required
    product.track_stock = data.track_stock
    product.low_stock_threshold = data.low_stock_threshold
    # stock_qty ni to'g'ridan-to'g'ri PATCH orqali o'zgartirilmaydi — faqat
    # stock/in yoki stock/out endpointlari orqali (audit log uchun).
    await product.save()
    return _product_dict(product)


# ============================================================
# Ombor / Inventar
# ============================================================


class StockAdjustIn(BaseModel):
    qty: Decimal = Field(gt=0)  # har doim musbat, type: in/out ga qarab minus/plus qilinadi
    reason: Optional[str] = Field(default=None, max_length=40)
    note: Optional[str] = Field(default=None, max_length=255)
    supplier: Optional[str] = Field(default=None, max_length=120)
    doc_number: Optional[str] = Field(default=None, max_length=60)


def _movement_dict(m: StockMovement) -> dict:
    return {
        "id": str(m.id),
        "product_id": str(m.product_id),
        "type": m.type,
        "qty": str(m.qty),
        "stock_after": str(m.stock_after),
        "reason": m.reason,
        "note": m.note,
        "staff_id": str(m.staff_id) if m.staff_id else None,
        "order_id": str(m.order_id) if m.order_id else None,
        "supplier": m.supplier,
        "doc_number": m.doc_number,
        "created_at": m.created_at.isoformat(),
    }


@router.post("/menu/products/{product_id}/stock/in")
async def stock_in(product_id: str, data: StockAdjustIn, principal: Principal = Depends(get_principal)):
    """Kirim — diler mahsulot yetkazganda qoldiqni oshiradi."""
    require_manager(principal)
    product = await Product.filter(id=product_id).first()
    if not product:
        raise HTTPException(404, detail="Product not found")
    if not product.track_stock:
        raise HTTPException(400, detail="Product is not tracked in stock (enable track_stock first)")
    product.stock_qty = Decimal(str(product.stock_qty)) + data.qty
    await product.save(update_fields=["stock_qty", "updated_at"])
    m = await StockMovement.create(
        restaurant_id=product.restaurant_id,
        product_id=product.id,
        type="in",
        qty=data.qty,
        stock_after=product.stock_qty,
        reason=data.reason or "supplier",
        note=data.note,
        staff_id=principal.staff_id,
        supplier=data.supplier,
        doc_number=data.doc_number,
    )
    return {"product": _product_dict(product), "movement": _movement_dict(m)}


@router.post("/menu/products/{product_id}/stock/out")
async def stock_out(product_id: str, data: StockAdjustIn, principal: Principal = Depends(get_principal)):
    """Chiqim / write-off — sindi, muddati o'tdi, xodim yedi va h.k."""
    require_manager(principal)
    product = await Product.filter(id=product_id).first()
    if not product:
        raise HTTPException(404, detail="Product not found")
    if not product.track_stock:
        raise HTTPException(400, detail="Product is not tracked in stock")
    new_qty = Decimal(str(product.stock_qty)) - data.qty
    if new_qty < 0:
        raise HTTPException(
            400,
            detail=f"Not enough stock: current {product.stock_qty}, requested {data.qty}",
        )
    product.stock_qty = new_qty
    await product.save(update_fields=["stock_qty", "updated_at"])
    m = await StockMovement.create(
        restaurant_id=product.restaurant_id,
        product_id=product.id,
        type="out",
        qty=data.qty,
        stock_after=product.stock_qty,
        reason=data.reason or "writeoff",
        note=data.note,
        staff_id=principal.staff_id,
    )
    return {"product": _product_dict(product), "movement": _movement_dict(m)}


@router.get("/menu/products/{product_id}/stock/movements")
async def stock_movements(
    product_id: str,
    limit: int = 100,
    principal: Principal = Depends(get_principal),
):
    """Bitta mahsulotning ombor harakati tarixi (yangi birinchi)."""
    product = await Product.filter(id=product_id).first()
    if not product:
        raise HTTPException(404, detail="Product not found")
    resolve_restaurant_id(principal, str(product.restaurant_id))
    rows = (
        await StockMovement.filter(product_id=product_id)
        .order_by("-created_at")
        .limit(min(limit, 500))
    )
    return {"product_id": product_id, "movements": [_movement_dict(m) for m in rows]}


@router.get("/menu/stock/overview")
async def stock_overview(
    restaurant_id: Optional[str] = None,
    principal: Principal = Depends(get_principal),
):
    """Barcha ombor'dagi mahsulotlar ro'yxati + qoldiqlar (Ombor tab uchun)."""
    rid = resolve_restaurant_id(principal, restaurant_id)
    products = await Product.filter(restaurant_id=rid, track_stock=True, is_active=True).order_by("name")
    out = []
    for p in products:
        low = Decimal(str(p.stock_qty)) <= Decimal(str(p.low_stock_threshold))
        out.append({
            **_product_dict(p),
            "low_stock": low,
        })
    return {"products": out}
