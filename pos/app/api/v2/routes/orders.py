from typing import Optional

from fastapi import APIRouter, Depends, HTTPException

from app.api.helpers import get_restaurant, get_scoped_order, resolve_terminal
from app.dependencies.auth import Principal, get_principal, resolve_restaurant_id
from app.models import Shift
from app.schemas.order import OrderIn, PayIn
from app.services.orders import add_payments, create_order, mark_paid, serialize_order

router = APIRouter(tags=["orders"])


async def _resolve_shift(principal: Principal, restaurant_id, explicit_shift_id):
    shift_id = principal.shift_id or explicit_shift_id
    if not shift_id:
        return None
    return await Shift.filter(id=shift_id, restaurant_id=restaurant_id).first()


@router.post("/orders")
async def create(data: OrderIn, principal: Principal = Depends(get_principal)):
    restaurant = await get_restaurant(principal, data.restaurant_id)
    terminal = await resolve_terminal(principal, restaurant, data.terminal_id)
    shift = await _resolve_shift(principal, restaurant.id, data.shift_id)
    order, created = await create_order(
        restaurant=restaurant, terminal=terminal, principal=principal, data=data, shift=shift
    )
    return {"created": created, "order": await serialize_order(order)}


@router.get("/orders")
async def list_orders(
    restaurant_id: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = 50,
    principal: Principal = Depends(get_principal),
):
    from app.models import Order

    rid = resolve_restaurant_id(principal, restaurant_id)
    q = Order.filter(restaurant_id=rid)
    if status:
        q = q.filter(status=status)
    orders = await q.order_by("-created_at").limit(min(limit, 200))
    return [await serialize_order(o, include_items=False) for o in orders]


@router.get("/orders/{order_id}")
async def get_order(order_id: str, principal: Principal = Depends(get_principal)):
    order = await get_scoped_order(principal, order_id)
    return await serialize_order(order)


@router.post("/orders/{order_id}/pay")
async def pay_order(order_id: str, data: PayIn, principal: Principal = Depends(get_principal)):
    order = await get_scoped_order(principal, order_id)
    if order.status == "cancelled":
        raise HTTPException(status_code=400, detail="Order is cancelled")
    await add_payments(order, data.payments)
    return {"order": await serialize_order(order)}


@router.post("/orders/{order_id}/cancel")
async def cancel_order(order_id: str, principal: Principal = Depends(get_principal)):
    order = await get_scoped_order(principal, order_id)
    if order.status == "paid":
        raise HTTPException(status_code=400, detail="Cannot cancel a paid order (issue a refund instead)")
    order.status = "cancelled"
    await order.save(update_fields=["status", "updated_at"])
    return {"order": await serialize_order(order, include_items=False)}
