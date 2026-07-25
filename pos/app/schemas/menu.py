from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, Field, field_validator


class CategoryIn(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    sort_order: int = 0
    is_active: bool = True
    image_url: Optional[str] = Field(default=None, max_length=500)
    restaurant_id: Optional[str] = None  # required for service (cloud-os) calls


class ProductIn(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    price: Decimal = Field(ge=0)
    category_id: Optional[str] = None
    sku: Optional[str] = Field(default=None, max_length=60)
    mxik_code: Optional[str] = None
    package_code: Optional[str] = None
    vat_percent: Decimal = Field(default=Decimal("12"), ge=0, le=100)
    unit: str = Field(default="dona", max_length=20)
    is_active: bool = True
    image_url: Optional[str] = Field(default=None, max_length=500)
    marking_required: bool = False  # dori/sigareta/alkogol uchun DataMatrix majburiy
    # --- Ombor / inventar ---
    track_stock: bool = False
    stock_qty: Decimal = Decimal("0")   # dastlabki qoldiq (faqat create'da ishlatiladi)
    low_stock_threshold: Decimal = Decimal("10")
    restaurant_id: Optional[str] = None  # required for service (cloud-os) calls

    @field_validator("mxik_code")
    @classmethod
    def _validate_mxik(cls, v: Optional[str]) -> Optional[str]:
        if v is None or not v.strip():
            return None
        v = v.strip()
        # MXIK / IKPU — tasnif.soliq.uz milliy katalogi kodi, 17 ta raqam.
        if not (v.isdigit() and len(v) == 17):
            raise ValueError("MXIK kodi roppa-rosa 17 ta raqam bo'lishi kerak")
        return v

    @field_validator("package_code")
    @classmethod
    def _validate_package(cls, v: Optional[str]) -> Optional[str]:
        if v is None or not v.strip():
            return None
        v = v.strip()
        if len(v) > 20:
            raise ValueError("Qadoq kodi 20 belgidan oshmasligi kerak")
        return v
