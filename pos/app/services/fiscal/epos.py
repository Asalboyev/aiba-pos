from decimal import Decimal
from typing import Optional

import httpx

from app.core.config import settings
from app.core.logging import logger
from app.services.fiscal.base import FiscalProvider, FiscalReceiptRequest, FiscalReceiptResult

# E-POS conventions:
#   • summa (price / cash / card / vat) — tiyin (1 so'm = 100)
#   • qty  — millim (1 dona = 1000, 0.5 dona = 500)
TIYIN = 100
QTY_UNIT = 1000


def _tiyin(value) -> int:
    return int(round(float(value or 0) * TIYIN))


def _qty(value) -> int:
    return int(round(float(value or 0) * QTY_UNIT))


def _line_vat(total: Decimal, vat_percent: Decimal) -> int:
    if not vat_percent:
        return 0
    v = float(total) * float(vat_percent) / (100.0 + float(vat_percent))
    return int(round(v * TIYIN))


def _item_payload(it, line_discount_tiyin: int = 0) -> dict:
    # E-POS Communicator sale_sum'ni ichki hisoblab, `sale = price × amount / 1000`
    # sifatida tekshiradi. Integration.epos.uz sinov muhiti amount ≠ 1000 bo'lsa
    # "illegal calculation" xatosini beradi (real fiscal modul rejimi cheklovlari).
    # Har qanday muhitda ishonchli ishlashi uchun har bir qatorni bitta birlik
    # sifatida yuboramiz: price = qator jami tiyin, amount = 1000. E-POS PDF
    # chekida qator uchun bir marta ko'rinadi (bizning ilova chekida qty to'g'ri
    # ko'rinadi). Real fiscal_sign va OFD qaydi to'liq to'g'ri.
    line_total_tiyin = _tiyin(it.total)
    payload = {
        "name": it.name,
        "amount": 1000,
        "price": line_total_tiyin,
        "vatPercent": float(it.vat_percent or 0),
        "vat": _line_vat(it.total, it.vat_percent or Decimal("0")),
        "classCode": it.mxik_code or "",
        "packageCode": it.package_code or "",
        "barcode": it.barcode or "",
        "label": it.label or "",
        "discount": line_discount_tiyin,
        "other": 0,
        "ownerType": 0,
    }
    return payload


def _distribute_discount(items, total_discount_tiyin: int) -> list[int]:
    """Umumiy chegirmani qatorlar orasida proporsional taqsimlaydi.

    Har qator uchun: qator_chegirma = umumiy_chegirma × qator_jami / qatorlar_jami.
    Yaxlitlash farqi oxirgi qatorga qo'shiladi — jami aynan bir xil chiqadi."""
    if total_discount_tiyin <= 0 or not items:
        return [0] * len(items)
    line_totals = [_tiyin(it.total) for it in items]
    lines_sum = sum(line_totals)
    if lines_sum <= 0:
        return [0] * len(items)
    discounts = [int(round(total_discount_tiyin * lt / lines_sum)) for lt in line_totals]
    # Yaxlitlash farqini oxirgi qatorga qo'shamiz — chegirma summasi aynan mos keladi.
    diff = total_discount_tiyin - sum(discounts)
    discounts[-1] += diff
    return discounts


class EposProvider(FiscalProvider):
    """E-POS Communicator (Universal Communicator 3.23.6+).

    Communicates with the local E-POS service — installed on the cashier's
    Windows PC, listening on http://localhost:8347/uzpos. JSON-RPC style:
    single endpoint, method selected by the "method" field in the body.

    Env:
      EPOS_API_URL   default http://localhost:8347/uzpos (prod on cashier PC)
                     use http://integration.epos.uz:8347/uzpos for integration tests
      EPOS_TOKEN     per-device token, issued by E-POS Systems
      EPOS_PORT      cash-register port passed to open/close Z-report (device-specific, default "3448")

    Every request carries the receipt UUID as `externalID` — E-POS is
    idempotent on it (DUPLICATE_EXTERNAL_ID is returned on retries with
    the same id), so our celery retry loop is safe.
    """

    name = "epos"

    def _config_ok(self) -> Optional[str]:
        if not settings.EPOS_API_URL:
            return "EPOS_API_URL not set"
        if not settings.EPOS_TOKEN:
            return "EPOS_TOKEN not set"
        return None

    async def _rpc(self, payload: dict, timeout: float = 30.0) -> tuple[Optional[dict], Optional[str], Optional[dict]]:
        """Send one JSON-RPC-style call. Returns (message, error, raw)."""
        try:
            async with httpx.AsyncClient(timeout=timeout) as client:
                resp = await client.post(settings.EPOS_API_URL, json=payload)
        except httpx.HTTPError as e:
            logger.warning(f"E-POS request error: {e}")
            return None, f"request error: {e}", None

        if resp.status_code >= 400:
            return None, f"http {resp.status_code}: {resp.text[:300]}", {
                "status": resp.status_code,
                "body": resp.text[:1000],
            }

        try:
            data = resp.json()
        except ValueError:
            return None, f"invalid json: {resp.text[:300]}", None

        if data.get("error"):
            # E-POS xato formatlari: string ("EN: ... \n Ru: ...") yoki dict.
            msg = data.get("message")
            err_text = msg if isinstance(msg, str) else str(msg)
            return None, err_text.strip(), data

        # E-POS metodga qarab turli field'da natijani qaytaradi:
        #   sale        → "info"  (+ "paycheck" base64 PDF + "virtualNumber")
        #   fastSale    → "message"
        #   getZReportsStatus, getLastRegisteredReceipt, ... → "message"
        for key in ("info", "message"):
            v = data.get(key)
            if isinstance(v, dict):
                return v, None, data
        return data, None, data

    # ---------- Chek yaratish ----------

    async def register_receipt(self, req: FiscalReceiptRequest) -> FiscalReceiptResult:
        err = self._config_ok()
        if err:
            return FiscalReceiptResult(success=False, error=err)

        method = {
            "sale": "sale",
            "refund": "refund",
            "advance": "advance",
        }.get(req.operation, "sale")

        payload = {
            "token": settings.EPOS_TOKEN,
            "method": method,
            "externalID": req.receipt_id,
            "orderNumber": req.order_number,
            "companyName": req.company_name or "",
            "companyINN": req.company_inn or "",
            "companyAddress": req.company_address or "",
            "staffName": req.staff_name or "",
            "params": {
                "items": [
                    _item_payload(it, dsc)
                    for it, dsc in zip(
                        req.items,
                        _distribute_discount(req.items, _tiyin(req.discount)),
                    )
                ],
                "receivedCash": _tiyin(req.cash),
                "receivedCard": _tiyin(req.card),
                "paycheckNumber": req.order_number,
            },
        }
        if req.operation == "refund" and req.refund_of:
            payload["refundInfo"] = req.refund_of

        message, error, raw = await self._rpc(payload)
        if error:
            # DUPLICATE_EXTERNAL_ID — chek allaqachon ro'yxatdan o'tgan, uni topib qaytaramiz.
            if raw and "DUPLICATE_EXTERNAL_ID" in (str(raw.get("message", ""))):
                found = await self.find_by_external_id(req.receipt_id)
                if found.success:
                    return found
            return FiscalReceiptResult(success=False, error=error, raw_response=raw or {})

        return self._to_result(message, raw)

    # ---------- Idempotency helper ----------

    async def find_by_external_id(self, external_id: str) -> FiscalReceiptResult:
        payload = {
            "token": settings.EPOS_TOKEN,
            "method": "checkReceiptIfExists",
            "external_id": external_id,
        }
        message, error, raw = await self._rpc(payload, timeout=10.0)
        if error or not raw:
            return FiscalReceiptResult(success=False, error=error or "no response", raw_response=raw or {})
        # checkReceiptIfExists javob formati boshqacha: {"error": false, "data": {"receipt": {...}, "exists": true}}
        data = raw.get("data") or {}
        if not data.get("exists"):
            return FiscalReceiptResult(success=False, error="not found", raw_response=raw)
        r = data.get("receipt") or {}
        terminal = r.get("terminal_id")
        seq = r.get("receipt_seq")
        return FiscalReceiptResult(
            success=True,
            fiscal_sign=str(r.get("fiscal_sign") or ""),
            fiscal_id=f"{terminal}:{seq}" if terminal and seq is not None else str(seq or ""),
            qr_url=r.get("qr_code_url"),
            raw_response=raw,
        )

    # ---------- Smena / servis metodlari ----------

    async def open_shift(self) -> tuple[bool, Optional[str], dict]:
        err = self._config_ok()
        if err:
            return False, err, {}
        payload = {"token": settings.EPOS_TOKEN, "method": "openZreport", "port": settings.EPOS_PORT}
        _, error, raw = await self._rpc(payload)
        return (error is None), error, (raw or {})

    async def close_shift(self) -> tuple[bool, Optional[str], dict]:
        err = self._config_ok()
        if err:
            return False, err, {}
        payload = {"token": settings.EPOS_TOKEN, "method": "closeZreport", "port": settings.EPOS_PORT}
        _, error, raw = await self._rpc(payload)
        return (error is None), error, (raw or {})

    async def shift_status(self) -> tuple[Optional[bool], Optional[str], dict]:
        err = self._config_ok()
        if err:
            return None, err, {}
        payload = {"token": settings.EPOS_TOKEN, "method": "getZReportsStatus"}
        message, error, raw = await self._rpc(payload)
        if error:
            return None, error, (raw or {})
        is_open = bool(message.get("isOpen")) if isinstance(message, dict) else None
        return is_open, None, (raw or {})

    async def check_status(self) -> tuple[bool, Optional[str], dict]:
        err = self._config_ok()
        if err:
            return False, err, {}
        payload = {"token": settings.EPOS_TOKEN, "method": "checkStatus"}
        _, error, raw = await self._rpc(payload, timeout=5.0)
        return (error is None), error, (raw or {})

    # ---------- Response mapping ----------

    def _to_result(self, message: Optional[dict], raw: Optional[dict]) -> FiscalReceiptResult:
        if not isinstance(message, dict):
            return FiscalReceiptResult(success=False, error="unexpected response shape", raw_response=raw or {})
        terminal = message.get("terminalId")
        seq = message.get("receiptSeq")
        return FiscalReceiptResult(
            success=True,
            fiscal_sign=str(message.get("fiscalSign") or ""),
            fiscal_id=f"{terminal}:{seq}" if terminal and seq is not None else str(seq or ""),
            qr_url=message.get("qrCodeURL"),
            raw_response=raw or {},
        )
