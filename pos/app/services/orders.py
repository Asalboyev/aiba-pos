from decimal import Decimal
from typing import Optional

from fastapi import HTTPException

from app.core.config import settings
from app.core.logging import logger
from app.dependencies.auth import Principal
from app.models import (
    FiscalReceipt,
    Order,
    OrderItem,
    Payment,
    Product,
    Restaurant,
    Shift,
    StaffUser,
    Terminal,
)
from app.utils.timezone import now

CENT = Decimal("0.01")


def _d(value) -> Decimal:
    return Decimal(str(value or 0))


def _money(value) -> str:
    # Tortoise DecimalField normalizes in-memory values (70000.00 -> 7E+4);
    # re-quantize to a stable fixed-point string for the API/terminal.
    return str(Decimal(str(value or 0)).quantize(CENT))


def _qty(value) -> str:
    return str(Decimal(str(value or 0)).quantize(Decimal("0.001")))


async def create_order(*, restaurant: Restaurant, terminal: Terminal, principal: Principal, data, shift: Optional[Shift] = None):
    """Create an order (with items + payments). Idempotent on client_uuid.

    Returns (order, created: bool). If the order is fully paid, it is marked
    paid and a fiscal receipt is created + queued for the OFD.
    """
    if data.client_uuid:
        existing = await Order.filter(restaurant_id=restaurant.id, client_uuid=data.client_uuid).first()
        if existing:
            return existing, False

    # Fiscal chek E-POS/Multikassa'ga jo'natilishi mumkin (async), shuning uchun
    # oldindan majburiy maydonlar tekshiriladi — kassir "Fiskal: xato" bilan
    # aldanmasligi uchun. Xato darrov 400 sifatida qaytadi va buyurtma umuman
    # yaratilmaydi (client_uuid ham band qilinmaydi).
    if settings.FISCAL_PROVIDER == "epos":
        for it in data.items:
            if not it.name or not it.name.strip():
                raise HTTPException(400, detail="Item name is required")
            if _d(it.price) <= 0:
                raise HTTPException(400, detail=f"Item '{it.name}': price must be > 0")
            if _d(it.qty) <= 0:
                raise HTTPException(400, detail=f"Item '{it.name}': qty must be > 0")

    subtotal = Decimal("0")
    rows = []
    for it in data.items:
        product = None
        mxik = it.mxik_code
        vat = it.vat_percent
        package_code = it.package_code
        marking_required = False
        if it.product_id:
            product = await Product.filter(id=it.product_id, restaurant_id=restaurant.id).first()
            if product:
                mxik = mxik or product.mxik_code
                package_code = package_code or product.package_code
                marking_required = product.marking_required
                if vat is None:
                    vat = product.vat_percent
        # Fallback: agar mahsulot topilmasa, MXIK bo'yicha ushbu restoran menyusidan izlab package_code'ni olamiz
        if not package_code and mxik:
            match = await Product.filter(restaurant_id=restaurant.id, mxik_code=mxik).first()
            if match:
                package_code = match.package_code
                marking_required = marking_required or match.marking_required
                if vat is None:
                    vat = match.vat_percent

        # E-POS majburiy tekshiruvlar — oldindan aniqlab 400 qaytaramiz,
        # aks holda backend fiscal_receipt yaratib abadiy `failed` bo'lib qolar edi.
        if settings.FISCAL_PROVIDER == "epos":
            if not mxik:
                raise HTTPException(400, detail=f"Item '{it.name}': mxik_code is required (17-digit IKPU from tasnif.soliq.uz)")
            if not (mxik.isdigit() and len(mxik) == 17):
                raise HTTPException(400, detail=f"Item '{it.name}': mxik_code must be exactly 17 digits, got '{mxik}'")
            if not package_code:
                raise HTTPException(400, detail=f"Item '{it.name}': package_code is required")
            if marking_required and not it.label:
                raise HTTPException(
                    400,
                    detail=f"Item '{it.name}': marking (DataMatrix label) is required — scan the code on the product",
                )

        if vat is None:
            vat = Decimal("12")
        line_total = (_d(it.price) * _d(it.qty)).quantize(CENT)
        subtotal += line_total
        rows.append((it, product, mxik, package_code, vat, line_total))

    discount = _d(data.discount)
    total = subtotal - discount
    if total < 0:
        total = Decimal("0")

    waiter = None
    if data.waiter_staff_id:
        waiter = await StaffUser.filter(id=data.waiter_staff_id, restaurant_id=restaurant.id).first()
    elif principal.staff_id:
        waiter = await StaffUser.filter(id=principal.staff_id).first()

    order = await Order.create(
        restaurant=restaurant,
        terminal=terminal,
        shift=shift,
        waiter=waiter,
        client_uuid=data.client_uuid,
        table_no=data.table_no,
        note=data.note,
        subtotal=subtotal.quantize(CENT),
        discount=discount.quantize(CENT),
        total=total.quantize(CENT),
        status="open",
    )
    order.number = (data.number or "").strip()[:40] or order.id.hex[:8].upper()
    await order.save(update_fields=["number", "updated_at"])

    for it, product, mxik, package_code, vat, line_total in rows:
        await OrderItem.create(
            order=order,
            product=product,
            name=it.name,
            qty=_d(it.qty),
            price=_d(it.price),
            total=line_total,
            mxik_code=mxik,
            package_code=package_code,
            label=it.label,
            barcode=it.barcode,
            vat_percent=_d(vat),
        )

    paid = Decimal("0")
    for p in (data.payments or []):
        await Payment.create(order=order, method=p.method, amount=_d(p.amount))
        paid += _d(p.amount)

    if data.payments and total > 0 and paid >= total:
        await mark_paid(order)

    return order, True


async def add_payments(order: Order, payments) -> Order:
    paid_already = sum((p.amount for p in await Payment.filter(order_id=order.id)), Decimal("0"))
    for p in payments:
        await Payment.create(order=order, method=p.method, amount=_d(p.amount))
        paid_already += _d(p.amount)
    if order.status != "paid" and paid_already >= order.total and order.total > 0:
        await mark_paid(order)
    return order


async def mark_paid(order: Order) -> None:
    order.status = "paid"
    order.paid_at = now()
    await order.save(update_fields=["status", "paid_at", "updated_at"])
    await _update_shift_totals(order)
    await _adjust_stock_on_sale(order)
    await create_and_enqueue_fiscal(order)


async def _adjust_stock_on_sale(order: Order) -> None:
    """Sotilgan mahsulotlarning ombor qoldig'ini kamaytiradi va har biriga
    StockMovement(type=sale) yozadi.

    track_stock=false bo'lgan mahsulotlar (palov, choy, ovqat) e'tibordan
    chetda qoladi — cheksiz sifatida hisoblanadi.
    """
    from app.models import StockMovement

    items = await OrderItem.filter(order_id=order.id)
    for item in items:
        if not item.product_id:
            continue
        product = await Product.filter(id=item.product_id).first()
        if not product or not product.track_stock:
            continue
        qty = _d(item.qty)
        product.stock_qty = _d(product.stock_qty) - qty
        await product.save(update_fields=["stock_qty", "updated_at"])
        await StockMovement.create(
            restaurant_id=order.restaurant_id,
            product_id=product.id,
            type="sale",
            qty=qty,
            stock_after=product.stock_qty,
            reason="sale",
            staff_id=order.waiter_id,
            order_id=order.id,
        )


async def _update_shift_totals(order: Order) -> None:
    if not order.shift_id:
        return
    shift = await Shift.filter(id=order.shift_id).first()
    if not shift or shift.status != "open":
        return
    pays = await Payment.filter(order_id=order.id)
    cash = sum((p.amount for p in pays if p.method == "cash"), Decimal("0"))
    card = sum((p.amount for p in pays if p.method in ("card", "qr")), Decimal("0"))
    shift.total_cash = _d(shift.total_cash) + cash
    shift.total_card = _d(shift.total_card) + card
    shift.total_sales = _d(shift.total_sales) + _d(order.total)
    shift.orders_count = (shift.orders_count or 0) + 1
    await shift.save()


async def create_and_enqueue_fiscal(order: Order) -> FiscalReceipt:
    receipt = await FiscalReceipt.create(
        order=order,
        restaurant_id=order.restaurant_id,
        terminal_id=order.terminal_id,
        provider=settings.FISCAL_PROVIDER,
        operation="sale",
        status="pending",
    )
    try:
        from app.tasks.fiscal import submit_fiscal_receipt

        submit_fiscal_receipt.delay(str(receipt.id))
    except Exception as e:  # noqa: BLE001
        # Broker unreachable — the periodic retry_pending_fiscal beat task
        # will pick this receipt up. Nothing is lost.
        logger.warning(f"fiscal enqueue failed (will retry via beat): {e}")
    return receipt


async def build_fiscal_request(receipt: FiscalReceipt):
    """Barcha kompaniya rekvizitlari + qatorlar bilan FiscalReceiptRequest quradi.
    Har provider (mock/multikassa/epos) uni bir xil ko'radi."""
    from app.models import OrderItem, Payment, Restaurant, StaffUser, Terminal
    from app.services.fiscal import FiscalItem, FiscalReceiptRequest

    order = await receipt.order
    restaurant = await Restaurant.filter(id=order.restaurant_id).first()
    terminal = await Terminal.filter(id=receipt.terminal_id).first() if receipt.terminal_id else None
    staff = await StaffUser.filter(id=order.waiter_id).first() if order.waiter_id else None

    items = await OrderItem.filter(order_id=order.id)
    pays = await Payment.filter(order_id=order.id)
    cash = sum((p.amount for p in pays if p.method == "cash"), Decimal("0"))
    card = sum((p.amount for p in pays if p.method in ("card", "qr")), Decimal("0"))

    return FiscalReceiptRequest(
        receipt_id=str(receipt.id),
        order_number=order.number or order.id.hex[:8].upper(),
        items=[
            FiscalItem(
                name=i.name,
                qty=i.qty,
                price=i.price,
                total=i.total,
                vat_percent=i.vat_percent,
                mxik_code=i.mxik_code,
                package_code=i.package_code,
                label=i.label,
                barcode=i.barcode,
            )
            for i in items
        ],
        cash=cash,
        card=card,
        discount=_d(order.discount),
        terminal_fiscal_id=(terminal.fiscal_terminal_id if terminal else None),
        operation=receipt.operation,
        company_name=(restaurant.legal_name or restaurant.name) if restaurant else None,
        company_inn=(restaurant.inn if restaurant else None),
        company_address=(restaurant.address if restaurant else None),
        staff_name=(staff.full_name if staff else None),
    )


async def serialize_order(order: Order, include_items: bool = True) -> dict:
    d = {
        "id": str(order.id),
        "number": order.number,
        "status": order.status,
        "table_no": order.table_no,
        "subtotal": _money(order.subtotal),
        "discount": _money(order.discount),
        "total": _money(order.total),
        "client_uuid": order.client_uuid,
        "note": order.note,
        "restaurant_id": str(order.restaurant_id),
        "terminal_id": str(order.terminal_id),
        "shift_id": str(order.shift_id) if order.shift_id else None,
        "paid_at": order.paid_at.isoformat() if order.paid_at else None,
        "created_at": order.created_at.isoformat(),
    }
    # Fiscal status is always attached (lightweight) so list views and the
    # cloud-os dashboard can show the cheque chip without a second call.
    receipt = await FiscalReceipt.filter(order_id=order.id).order_by("-created_at").first()
    d["fiscal"] = (
        {
            "status": receipt.status,
            "provider": receipt.provider,
            "fiscal_sign": receipt.fiscal_sign,
            "fiscal_id": receipt.fiscal_id,
            "qr_url": receipt.qr_url,
            "retries": receipt.retries,
        }
        if receipt
        else None
    )
    if include_items:
        items = await OrderItem.filter(order_id=order.id)
        d["items"] = [
            {
                "id": str(i.id),
                "product_id": str(i.product_id) if i.product_id else None,
                "name": i.name,
                "qty": _qty(i.qty),
                "price": _money(i.price),
                "total": _money(i.total),
                "mxik_code": i.mxik_code,
                "vat_percent": str(i.vat_percent),
            }
            for i in items
        ]
        pays = await Payment.filter(order_id=order.id)
        d["payments"] = [{"method": p.method, "amount": _money(p.amount)} for p in pays]
    return d
