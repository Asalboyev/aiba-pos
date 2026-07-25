from tortoise import fields

from app.models.base import BaseModel


class FiscalReceipt(BaseModel):
    """A fiscal cheque registered (or to be registered) with the virtual
    cash register / OFD for a paid order.

    Created in `pending` state when an order is paid, then a Celery task
    submits it to the provider and fills in `fiscal_sign` + `qr_url`. Retries
    survive offline windows, so a sale made without internet still becomes a
    legal fiscal cheque once the connection returns.
    """

    order = fields.ForeignKeyField("models.Order", related_name="fiscal_receipts")
    restaurant = fields.ForeignKeyField("models.Restaurant", related_name="fiscal_receipts")
    terminal = fields.ForeignKeyField("models.Terminal", related_name="fiscal_receipts", null=True)

    provider = fields.CharField(max_length=40, default="mock")
    operation = fields.CharField(max_length=20, default="sale")  # sale / refund
    status = fields.CharField(max_length=20, default="pending")

    fiscal_sign = fields.CharField(max_length=120, null=True)  # ФП — fiskal belgi
    fiscal_id = fields.CharField(max_length=120, null=True)  # provider receipt id
    qr_url = fields.CharField(max_length=500, null=True)

    retries = fields.IntField(default=0)
    last_error = fields.TextField(null=True)
    raw_request = fields.JSONField(null=True)
    raw_response = fields.JSONField(null=True)
    sent_at = fields.DatetimeField(null=True)

    class Meta:
        table = "pos_fiscal_receipts"
