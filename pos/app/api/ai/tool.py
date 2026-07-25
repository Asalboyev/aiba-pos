from datetime import date
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.dependencies.auth import require_service
from app.models import Order, OrderItem, Payment
from app.utils.timezone import end_of_day, now, start_of_day

router = APIRouter(tags=["ai"])


@router.get("/tool", dependencies=[Depends(require_service)])
async def tool(
    action: str,
    restaurant_id: Optional[str] = None,
    date_str: Optional[str] = Query(None, alias="date"),
):
    """Single AI-tool endpoint (cloud-os AiChatController discovers + calls it).

    Returns the {error, message, data} shape the AIBA chat agent expects.
    Actions: sales_summary | order_count | top_products.
    """
    if not restaurant_id:
        return {"error": True, "message": "restaurant_id required", "data": {}}

    d = date.fromisoformat(date_str) if date_str else now().date()
    start, end = start_of_day(d), end_of_day(d)
    orders = await Order.filter(restaurant_id=restaurant_id, status="paid", paid_at__gte=start, paid_at__lte=end)
    order_ids = [o.id for o in orders]
    total = sum((o.total for o in orders), Decimal("0"))

    if action in ("sales_summary", "summary"):
        pays = await Payment.filter(order_id__in=order_ids) if order_ids else []
        cash = sum((p.amount for p in pays if p.method == "cash"), Decimal("0"))
        card = sum((p.amount for p in pays if p.method in ("card", "qr")), Decimal("0"))
        return {
            "error": False,
            "message": f"{d}: {len(orders)} ta chek, jami {total} so'm (naqd {cash}, karta {card}).",
            "data": {
                "date": d.isoformat(),
                "orders": len(orders),
                "total": str(total),
                "cash": str(cash),
                "card": str(card),
            },
        }

    if action == "order_count":
        return {
            "error": False,
            "message": f"{d}: {len(orders)} ta sotuv cheki.",
            "data": {"date": d.isoformat(), "orders": len(orders)},
        }

    if action == "top_products":
        items = await OrderItem.filter(order_id__in=order_ids) if order_ids else []
        agg: dict = {}
        for i in items:
            a = agg.setdefault(i.name, {"name": i.name, "qty": Decimal("0"), "total": Decimal("0")})
            a["qty"] += i.qty
            a["total"] += i.total
        top = sorted(agg.values(), key=lambda x: x["total"], reverse=True)[:5]
        msg = ", ".join(f"{t['name']} ({t['total']} so'm)" for t in top) or "Ma'lumot yo'q"
        return {
            "error": False,
            "message": f"{d} eng ko'p sotilgan: {msg}",
            "data": {"top": [{"name": t["name"], "qty": str(t["qty"]), "total": str(t["total"])} for t in top]},
        }

    return {"error": True, "message": f"Unknown action: {action}", "data": {}}
