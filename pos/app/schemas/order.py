from decimal import Decimal
from typing import List, Optional

from pydantic import BaseModel


class OrderItemIn(BaseModel):
    product_id: Optional[str] = None
    name: str
    qty: Decimal = Decimal("1")
    price: Decimal
    mxik_code: Optional[str] = None
    package_code: Optional[str] = None
    label: Optional[str] = None
    barcode: Optional[str] = None
    vat_percent: Optional[Decimal] = None


class PaymentIn(BaseModel):
    method: str  # cash / card / qr
    amount: Decimal


class OrderIn(BaseModel):
    client_uuid: Optional[str] = None  # idempotency key from the terminal
    # Terminal-generated daily order number (e.g. "T1-7") — assigned at
    # checkout so the printed receipt has it even when offline.
    number: Optional[str] = None
    table_no: Optional[str] = None
    waiter_staff_id: Optional[str] = None
    note: Optional[str] = None
    discount: Decimal = Decimal("0")
    items: List[OrderItemIn]
    payments: List[PaymentIn] = []
    # For service (cloud-os) calls that aren't scoped by a terminal token:
    restaurant_id: Optional[str] = None
    terminal_id: Optional[str] = None
    shift_id: Optional[str] = None


class PayIn(BaseModel):
    payments: List[PaymentIn]


class SyncPushIn(BaseModel):
    orders: List[OrderIn]


class OpenShiftIn(BaseModel):
    opening_cash: Decimal = Decimal("0")
    restaurant_id: Optional[str] = None
    terminal_id: Optional[str] = None


class CloseShiftIn(BaseModel):
    shift_id: Optional[str] = None
