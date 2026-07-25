from tortoise import fields

from app.models.base import BaseModel


class StockMovement(BaseModel):
    """Har ombor harakati uchun bitta yozuv (kirim / chiqim / sotuv).

    Menejer real vaqtda hisobot ko'ra oladi: qachon kim nima olib keldi,
    qanday sabab bilan yozib qo'ydi, qaysi chekda sotildi.

    Sotuv paytida avtomatik yaratiladi (create_order -> _adjust_stock_on_sale).
    Menejer +Kirim / +Chiqim tugmasidan qo'lda ham qo'shadi.
    """

    restaurant = fields.ForeignKeyField("models.Restaurant", related_name="stock_movements", index=True)
    product = fields.ForeignKeyField("models.Product", related_name="stock_movements", index=True)
    # in  — kirim (diler yetkazdi, +qty)
    # out — chiqim (sindi, muddati o'tdi, xodim yedi, boshqa; -qty)
    # sale — sotuv (avtomatik, order bilan bog'langan; -qty)
    # revert — sotuvni qaytarish (refund/cancel; +qty)
    type = fields.CharField(max_length=10)
    qty = fields.DecimalField(max_digits=14, decimal_places=3)
    # in dan keyingi qoldiq — hisobot va tekshirish uchun (real vaqtdagi snapshot)
    stock_after = fields.DecimalField(max_digits=14, decimal_places=3, default=0)
    reason = fields.CharField(max_length=40, null=True)
    note = fields.CharField(max_length=255, null=True)
    # Kim qildi (menejer/kassir) — sotuv paytida kassirning staff_id
    staff = fields.ForeignKeyField("models.StaffUser", related_name="stock_movements", null=True)
    # Sotuv bo'lsa qaysi buyurtma
    order = fields.ForeignKeyField("models.Order", related_name="stock_movements", null=True)
    # Kirimda diler nakladnoy raqami
    supplier = fields.CharField(max_length=120, null=True)
    doc_number = fields.CharField(max_length=60, null=True)

    class Meta:
        table = "pos_stock_movements"


class Category(BaseModel):
    restaurant = fields.ForeignKeyField("models.Restaurant", related_name="categories")
    name = fields.CharField(max_length=120)
    sort_order = fields.IntField(default=0)
    is_active = fields.BooleanField(default=True)
    image_url = fields.CharField(max_length=500, null=True)

    class Meta:
        table = "pos_categories"


class Product(BaseModel):
    restaurant = fields.ForeignKeyField("models.Restaurant", related_name="products")
    category = fields.ForeignKeyField("models.Category", related_name="products", null=True)
    name = fields.CharField(max_length=200)
    sku = fields.CharField(max_length=60, null=True)
    price = fields.DecimalField(max_digits=14, decimal_places=2)
    # MXIK / IKPU — 17-digit national catalog code (tasnif.soliq.uz). Required
    # on a fiscal cheque, so it lives on the product.
    mxik_code = fields.CharField(max_length=20, null=True)
    # Optional packaging / marking code (qadoq belgisi) for marked goods.
    package_code = fields.CharField(max_length=40, null=True)
    vat_percent = fields.DecimalField(max_digits=5, decimal_places=2, default=12)
    unit = fields.CharField(max_length=20, default="dona")
    is_active = fields.BooleanField(default=True)
    image_url = fields.CharField(max_length=500, null=True)
    # E-POS majburiy markirovkani talab qiladigan mahsulotlar uchun (alkogol,
    # sigareta, suv shishalari va h.k.). True bo'lsa buyurtma yaratishda har
    # bir dona uchun DataMatrix label majburiy — aks holda 400 xato qaytadi
    # (kassir "Fiskal: xato" bilan aldanishning oldi olinadi).
    marking_required = fields.BooleanField(default=False)

    # --- Ombor / inventar ---
    # True bo'lsa: mahsulot ombor'da hisoblanadi (Cola, alkogol, shishadagi ichimlik)
    # False bo'lsa: cheksiz (palov, manti, choy — tayyor ovqat, retseptdan pishiriladi)
    track_stock = fields.BooleanField(default=False)
    # Hozirgi qoldiq (agar track_stock=true bo'lsa)
    stock_qty = fields.DecimalField(max_digits=14, decimal_places=3, default=0)
    # Ogohlantirish chegarasi — qoldiq shundan kam bo'lsa adminka'da qizil chip
    low_stock_threshold = fields.DecimalField(max_digits=14, decimal_places=3, default=10)

    class Meta:
        table = "pos_products"
