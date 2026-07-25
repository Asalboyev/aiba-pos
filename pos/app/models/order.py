from tortoise import fields

from app.models.base import BaseModel


class Shift(BaseModel):
    restaurant = fields.ForeignKeyField("models.Restaurant", related_name="shifts")
    terminal = fields.ForeignKeyField("models.Terminal", related_name="shifts")
    opened_by = fields.ForeignKeyField("models.StaffUser", related_name="opened_shifts", null=True)
    opened_at = fields.DatetimeField(auto_now_add=True)
    closed_at = fields.DatetimeField(null=True)
    status = fields.CharField(max_length=20, default="open")
    opening_cash = fields.DecimalField(max_digits=14, decimal_places=2, default=0)
    total_cash = fields.DecimalField(max_digits=14, decimal_places=2, default=0)
    total_card = fields.DecimalField(max_digits=14, decimal_places=2, default=0)
    total_sales = fields.DecimalField(max_digits=14, decimal_places=2, default=0)
    orders_count = fields.IntField(default=0)

    class Meta:
        table = "pos_shifts"


class Order(BaseModel):
    restaurant = fields.ForeignKeyField("models.Restaurant", related_name="orders")
    terminal = fields.ForeignKeyField("models.Terminal", related_name="orders")
    shift = fields.ForeignKeyField("models.Shift", related_name="orders", null=True)
    waiter = fields.ForeignKeyField("models.StaffUser", related_name="orders", null=True)
    # Idempotency key generated on the offline terminal. A re-sent order with
    # the same (restaurant, client_uuid) returns the existing row instead of
    # creating a duplicate — the backbone of safe offline→online sync.
    client_uuid = fields.CharField(max_length=64, null=True, index=True)
    number = fields.CharField(max_length=40, null=True)
    table_no = fields.CharField(max_length=20, null=True)
    status = fields.CharField(max_length=20, default="open")
    subtotal = fields.DecimalField(max_digits=14, decimal_places=2, default=0)
    discount = fields.DecimalField(max_digits=14, decimal_places=2, default=0)
    total = fields.DecimalField(max_digits=14, decimal_places=2, default=0)
    note = fields.CharField(max_length=255, null=True)
    paid_at = fields.DatetimeField(null=True)

    class Meta:
        table = "pos_orders"
        unique_together = (("restaurant", "client_uuid"),)


class OrderItem(BaseModel):
    order = fields.ForeignKeyField("models.Order", related_name="items")
    product = fields.ForeignKeyField("models.Product", related_name="order_items", null=True)
    name = fields.CharField(max_length=200)
    qty = fields.DecimalField(max_digits=12, decimal_places=3, default=1)
    price = fields.DecimalField(max_digits=14, decimal_places=2)
    total = fields.DecimalField(max_digits=14, decimal_places=2)
    mxik_code = fields.CharField(max_length=20, null=True)
    package_code = fields.CharField(max_length=40, null=True)  # E-POS unit-of-measure code
    label = fields.CharField(max_length=255, null=True)  # marking code (dori/sigareta)
    barcode = fields.CharField(max_length=64, null=True)
    vat_percent = fields.DecimalField(max_digits=5, decimal_places=2, default=12)

    class Meta:
        table = "pos_order_items"


class Payment(BaseModel):
    order = fields.ForeignKeyField("models.Order", related_name="payments")
    method = fields.CharField(max_length=20)  # cash / card / qr
    amount = fields.DecimalField(max_digits=14, decimal_places=2)

    class Meta:
        table = "pos_payments"
