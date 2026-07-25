import httpx

from app.core.config import settings
from app.core.logging import logger
from app.services.fiscal.base import FiscalProvider, FiscalReceiptRequest, FiscalReceiptResult

# Tiyin multiplier — Uzbek fiscal APIs expect amounts in tiyin (1 so'm = 100).
TIYIN = 100


class MultikassaProvider(FiscalProvider):
    """Multibank Multikassa virtual cash register.

    This implements the real request *shape* (items with MXIK, VAT, amounts
    in tiyin, cash/card split) against FISCAL_API_URL with a bearer token.
    The exact field names follow the public Multikassa virtual-kassa docs and
    must be confirmed against the live contract before production — search for
    `# CONFIRM:` markers. Until FISCAL_API_URL / FISCAL_API_TOKEN are set the
    provider returns a clear error and the receipt stays `pending` (the retry
    loop will pick it up once configured), so nothing is silently lost.
    """

    name = "multikassa"

    async def register_receipt(self, req: FiscalReceiptRequest) -> FiscalReceiptResult:
        if not settings.FISCAL_API_URL or not settings.FISCAL_API_TOKEN:
            return FiscalReceiptResult(
                success=False,
                error="Multikassa not configured (set FISCAL_API_URL + FISCAL_API_TOKEN)",
            )

        payload = {
            # CONFIRM: field names against Multikassa docs.
            "terminal_id": req.terminal_fiscal_id,
            "external_id": req.receipt_id,
            "operation": req.operation,  # sale / refund
            "received_cash": int(round(float(req.cash) * TIYIN)),
            "received_card": int(round(float(req.card) * TIYIN)),
            "items": [
                {
                    "name": it.name,
                    "spic": it.mxik_code,  # MXIK / IKPU
                    "package_code": it.package_code,
                    "count": float(it.qty),
                    "price": int(round(float(it.price) * TIYIN)),
                    "amount": int(round(float(it.total) * TIYIN)),
                    "vat_percent": float(it.vat_percent),
                    "vat": int(
                        round(float(it.total) * float(it.vat_percent) / (100 + float(it.vat_percent)) * TIYIN)
                    ),
                }
                for it in req.items
            ],
        }

        headers = {
            "Authorization": f"Bearer {settings.FISCAL_API_TOKEN}",
            "Content-Type": "application/json",
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                resp = await client.post(
                    f"{settings.FISCAL_API_URL.rstrip('/')}/receipts", json=payload, headers=headers
                )
        except httpx.HTTPError as e:
            logger.warning(f"Multikassa request error: {e}")
            return FiscalReceiptResult(success=False, error=f"request error: {e}")

        if resp.status_code >= 400:
            return FiscalReceiptResult(
                success=False,
                error=f"http {resp.status_code}: {resp.text[:300]}",
                raw_response={"status": resp.status_code, "body": resp.text[:1000]},
            )

        data = resp.json()
        # CONFIRM: response field names against Multikassa docs.
        return FiscalReceiptResult(
            success=True,
            fiscal_sign=str(data.get("fiscal_sign") or data.get("fp") or ""),
            fiscal_id=str(data.get("receipt_id") or data.get("id") or ""),
            qr_url=data.get("qr_code_url") or data.get("qr"),
            raw_response=data,
        )
