from datetime import date
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, Depends

from app.dependencies.auth import Principal, get_principal, resolve_restaurant_id
from app.models import Order, OrderItem, Payment
from app.utils.timezone import end_of_day, now, start_of_day

router = APIRouter(tags=["reports"])


@router.get("/reports/sales-summary")
async def sales_summary(
    restaurant_id: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    principal: Principal = Depends(get_principal),
):
    rid = resolve_restaurant_id(principal, restaurant_id)
    df = date.fromisoformat(date_from) if date_from else now().date()
    dt = date.fromisoformat(date_to) if date_to else df
    start, end = start_of_day(df), end_of_day(dt)

    orders = await Order.filter(restaurant_id=rid, status="paid", paid_at__gte=start, paid_at__lte=end)
    order_ids = [o.id for o in orders]
    total_sales = sum((o.total for o in orders), Decimal("0"))

    pays = await Payment.filter(order_id__in=order_ids) if order_ids else []
    cash = sum((p.amount for p in pays if p.method == "cash"), Decimal("0"))
    card = sum((p.amount for p in pays if p.method in ("card", "qr")), Decimal("0"))

    items = await OrderItem.filter(order_id__in=order_ids) if order_ids else []
    agg: dict = {}
    for i in items:
        a = agg.setdefault(i.name, {"name": i.name, "qty": Decimal("0"), "total": Decimal("0")})
        a["qty"] += i.qty
        a["total"] += i.total
    top = sorted(agg.values(), key=lambda x: x["total"], reverse=True)[:10]

    return {
        "restaurant_id": str(rid),
        "date_from": df.isoformat(),
        "date_to": dt.isoformat(),
        "orders_count": len(orders),
        "total_sales": str(total_sales),
        "total_cash": str(cash),
        "total_card": str(card),
        "top_products": [{"name": t["name"], "qty": str(t["qty"]), "total": str(t["total"])} for t in top],
    }
