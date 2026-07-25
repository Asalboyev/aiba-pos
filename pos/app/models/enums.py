from enum import Enum


class StaffRole(str, Enum):
    CASHIER = "cashier"
    WAITER = "waiter"
    MANAGER = "manager"


class OrderStatus(str, Enum):
    OPEN = "open"
    PAID = "paid"
    CANCELLED = "cancelled"


class PaymentMethod(str, Enum):
    CASH = "cash"
    CARD = "card"
    QR = "qr"


class ShiftStatus(str, Enum):
    OPEN = "open"
    CLOSED = "closed"


class FiscalStatus(str, Enum):
    PENDING = "pending"
    SENT = "sent"
    FAILED = "failed"
    NOT_REQUIRED = "not_required"


class FiscalOperation(str, Enum):
    SALE = "sale"
    REFUND = "refund"
