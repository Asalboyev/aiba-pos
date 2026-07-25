from decimal import Decimal

from fastapi import APIRouter, Depends

from app.core.security import hash_pin
from app.dependencies.auth import require_service
from app.models import Category, Product, Restaurant, StaffUser, Terminal

router = APIRouter(dependencies=[Depends(require_service)], tags=["seed"])


@router.post("/seed-demo")
async def seed_demo():
    """Create a demo restaurant + terminal + staff + menu so the whole flow
    is testable immediately. Idempotent — safe to call repeatedly."""
    restaurant = await Restaurant.filter(code="DEMO").first()
    if not restaurant:
        restaurant = await Restaurant.create(
            name="Milli Grill", code="DEMO", inn="300000000", address="Toshkent"
        )

    terminal = await Terminal.filter(code="T1").first()
    if not terminal:
        terminal = await Terminal.create(
            restaurant=restaurant, name="Kassa 1", code="T1", fiscal_terminal_id="VK-DEMO-001"
        )

    if not await StaffUser.filter(restaurant_id=restaurant.id, code="100").first():
        await StaffUser.create(
            restaurant=restaurant, full_name="Menejer Demo", code="100", pin_hash=hash_pin("1234"), role="manager"
        )
    if not await StaffUser.filter(restaurant_id=restaurant.id, code="101").first():
        await StaffUser.create(
            restaurant=restaurant, full_name="Kassir Demo", code="101", pin_hash=hash_pin("0000"), role="cashier"
        )

    if not await Category.filter(restaurant_id=restaurant.id).exists():
        taom = await Category.create(restaurant=restaurant, name="Taomlar", sort_order=1)
        ichim = await Category.create(restaurant=restaurant, name="Ichimliklar", sort_order=2)
        demo_items = [
            (taom, "Palov", 35000, "10112001001000000"),
            (taom, "Lag'mon", 30000, "10112001002000000"),
            (taom, "Manti (6 dona)", 32000, "10112001003000000"),
            (ichim, "Cola 0.5", 10000, "10307001001000000"),
            (ichim, "Choy", 5000, "10307002001000000"),
        ]
        for cat, name, price, mxik in demo_items:
            await Product.create(
                restaurant=restaurant,
                category=cat,
                name=name,
                price=Decimal(price),
                mxik_code=mxik,
                vat_percent=Decimal("12"),
                unit="dona",
            )

    return {
        "restaurant": {"id": str(restaurant.id), "code": restaurant.code, "name": restaurant.name},
        "terminal_code": "T1",
        "login": {
            "manager": {"staff_code": "100", "pin": "1234"},
            "cashier": {"staff_code": "101", "pin": "0000"},
        },
        "try_it": "POST /api/v2/auth/login {terminal_code:'T1', staff_code:'101', pin:'0000'}",
    }
