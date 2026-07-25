from typing import Optional

from fastapi import APIRouter, Depends

from app.api.helpers import get_restaurant, resolve_terminal
from app.api.v2.routes.menu import _product_dict
from app.dependencies.auth import Principal, get_principal, resolve_restaurant_id
from app.models import Category, Product, Shift
from app.schemas.order import SyncPushIn
from app.services.orders import create_order, serialize_order
from app.utils.timezone import now

router = APIRouter(tags=["sync"])


@router.get("/sync/pull")
async def pull(restaurant_id: Optional[str] = None, principal: Principal = Depends(get_principal)):
    """Everything an offline terminal needs to refresh its local cache:
    menu (categories + products). Call on login and periodically."""
    rid = resolve_restaurant_id(principal, restaurant_id)
    cats = await Category.filter(restaurant_id=rid, is_active=True).order_by("sort_order", "name")
    products = await Product.filter(restaurant_id=rid, is_active=True).order_by("name")
    return {
        "server_time": now().isoformat(),
        "restaurant_id": str(rid),
        "categories": [{"id": str(c.id), "name": c.name, "sort_order": c.sort_order} for c in cats],
        "products": [_product_dict(p) for p in products],
    }


@router.post("/sync/push")
async def push(data: SyncPushIn, principal: Principal = Depends(get_principal)):
    """Batch-upload orders queued offline. Idempotent per client_uuid, so it
    is safe to re-send the whole queue after a flaky connection."""
    results = []
    for o in data.orders:
        try:
            restaurant = await get_restaurant(principal, o.restaurant_id)
            terminal = await resolve_terminal(principal, restaurant, o.terminal_id)
            shift_id = principal.shift_id or o.shift_id
            shift = await Shift.filter(id=shift_id, restaurant_id=restaurant.id).first() if shift_id else None
            order, created = await create_order(
                restaurant=restaurant, terminal=terminal, principal=principal, data=o, shift=shift
            )
            results.append(
                {
                    "client_uuid": o.client_uuid,
                    "order_id": str(order.id),
                    "created": created,
                    "status": order.status,
                    "fiscal": (await serialize_order(order)).get("fiscal"),
                }
            )
        except Exception as e:  # noqa: BLE001
            results.append({"client_uuid": o.client_uuid, "error": str(e)})
    return {"results": results}
