from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from decimal import Decimal
from typing import Optional


@dataclass
class FiscalItem:
    name: str
    qty: Decimal
    price: Decimal  # unit price
    total: Decimal
    vat_percent: Decimal
    mxik_code: Optional[str] = None  # MXIK / IKPU (17-digit) — E-POS calls this classCode
    package_code: Optional[str] = None  # unit-of-measure / package code from getPackages
    barcode: Optional[str] = None
    label: Optional[str] = None  # marking code (dori, sigareta, elektronika) — E-POS majburiy


@dataclass
class FiscalReceiptRequest:
    receipt_id: str  # our FiscalReceipt.id — sent as externalID (idempotency)
    order_number: str
    items: list[FiscalItem]
    cash: Decimal = Decimal("0")
    card: Decimal = Decimal("0")
    terminal_fiscal_id: Optional[str] = None
    operation: str = "sale"  # sale / refund / advance
    # Fiscal chek talab qiladigan kompaniya rekvizitlari (E-POS majburiy)
    company_name: Optional[str] = None
    company_inn: Optional[str] = None
    company_address: Optional[str] = None
    staff_name: Optional[str] = None
    # Umumiy chegirma (so'm) — E-POS payloadida qatorlar orasida
    # proporsional taqsimlanadi (chunki har qator `discount` maydonini talab qiladi).
    discount: Decimal = Decimal("0")
    # Refund uchun asl chek ma'lumoti (E-POS `refundInfo`)
    refund_of: Optional[dict] = None  # {terminalId, receiptSeq, dateTime, fiscalSign}


@dataclass
class FiscalReceiptResult:
    success: bool
    fiscal_sign: Optional[str] = None  # ФП / fiskal belgi
    fiscal_id: Optional[str] = None  # provider-side receipt id
    qr_url: Optional[str] = None  # customer verification URL
    raw_response: dict = field(default_factory=dict)
    error: Optional[str] = None


class FiscalProvider(ABC):
    """Interface every virtual-cash-register provider must implement.

    Implementations: MockFiscalProvider (sandbox), MultikassaProvider, and
    later RegosProvider / EposProvider. The POS service only ever talks to
    this interface, so swapping providers is a config change.
    """

    name: str = "base"

    @abstractmethod
    async def register_receipt(self, req: FiscalReceiptRequest) -> FiscalReceiptResult:
        ...
