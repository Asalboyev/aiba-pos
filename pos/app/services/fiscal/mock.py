import hashlib

from app.core.config import settings
from app.services.fiscal.base import FiscalProvider, FiscalReceiptRequest, FiscalReceiptResult


class MockFiscalProvider(FiscalProvider):
    """Sandbox provider — returns a deterministic, well-formed fiscal sign +
    QR without contacting any external service.

    This makes the whole sale → fiscal cheque flow testable end-to-end with
    zero credentials. The shape of the result matches what a real OFD
    returns (a numeric fiscal sign + a soliq.uz verification URL), so the
    terminal, receipt printing and reports all work as they will in prod.
    """

    name = "mock"

    async def register_receipt(self, req: FiscalReceiptRequest) -> FiscalReceiptResult:
        digest = hashlib.sha256(req.receipt_id.encode("utf-8")).hexdigest()
        # 16-digit numeric fiscal sign, like a real ФП.
        fiscal_sign = str(int(digest[:16], 16)).zfill(16)[:16]
        fiscal_id = "MOCK-" + digest[:12].upper()
        qr_url = f"{settings.FISCAL_VERIFY_BASE}?fp={fiscal_sign}&s={int(req.cash + req.card)}"
        return FiscalReceiptResult(
            success=True,
            fiscal_sign=fiscal_sign,
            fiscal_id=fiscal_id,
            qr_url=qr_url,
            raw_response={
                "provider": "mock",
                "operation": req.operation,
                "order_number": req.order_number,
                "items": len(req.items),
            },
        )
