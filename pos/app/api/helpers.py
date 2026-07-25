from typing import Optional

from fastapi import HTTPException

from app.dependencies.auth import Principal, resolve_restaurant_id
from app.models import Order, Restaurant, Terminal


async def get_restaurant(principal: Principal, restaurant_id: Optional[str]) -> Restaurant:
    rid = resolve_restaurant_id(principal, restaurant_id)
    restaurant = await Restaurant.filter(id=rid, is_active=True).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    return restaurant


async def resolve_terminal(principal: Principal, restaurant: Restaurant, terminal_id: Optional[str] = None) -> Terminal:
    if principal.terminal_id:
        terminal = await Terminal.filter(id=principal.terminal_id, restaurant_id=restaurant.id).first()
    elif terminal_id:
        terminal = await Terminal.filter(id=terminal_id, restaurant_id=restaurant.id).first()
    else:
        terminal = None
    if not terminal:
        raise HTTPException(status_code=400, detail="Terminal not resolved (terminal_id required for service calls)")
    return terminal


async def get_scoped_order(principal: Principal, order_id: str) -> Order:
    order = await Order.filter(id=order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    # Raises 403 if a terminal token tries to touch another restaurant's order.
    resolve_restaurant_id(principal, str(order.restaurant_id))
    return order


def require_manager(principal: Principal) -> None:
    if not (principal.is_service or principal.role == "manager"):
        raise HTTPException(status_code=403, detail="Manager role required")
