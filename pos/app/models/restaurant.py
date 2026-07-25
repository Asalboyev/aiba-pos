from tortoise import fields

from app.models.base import BaseModel


class Restaurant(BaseModel):
    """A single restaurant / cafeteria (a tenant).

    `company_id` links to the cloud-os companies registry (Nextcloud) so
    access control and the AI chat can join POS data to a known company.
    """

    company_id = fields.UUIDField(null=True, index=True)
    name = fields.CharField(max_length=200)
    code = fields.CharField(max_length=50, unique=True)
    legal_name = fields.CharField(max_length=255, null=True)
    inn = fields.CharField(max_length=20, null=True)
    address = fields.CharField(max_length=255, null=True)
    timezone = fields.CharField(max_length=64, default="Asia/Tashkent")
    is_active = fields.BooleanField(default=True)
    # --- Chek sozlamalari (chekda nima chiqadi) ---
    receipt_logo_url = fields.CharField(max_length=500, null=True)
    receipt_header = fields.CharField(max_length=500, null=True)   # yuqorida ko'rinadigan matn
    receipt_footer = fields.CharField(max_length=500, null=True)   # pastda ko'rinadigan matn ("Rahmat!")
    receipt_phone = fields.CharField(max_length=40, null=True)
    receipt_show_qr = fields.BooleanField(default=True)
    receipt_show_mxik = fields.BooleanField(default=True)          # MXIK kodni har qatorda ko'rsatish
    receipt_paper_width = fields.IntField(default=80)              # 58 yoki 80 (mm)

    class Meta:
        table = "pos_restaurants"


class AdminAccount(BaseModel):
    """Web adminka'ga kirish uchun akkaunt. Bir necha menejer bo'lishi mumkin.
    Login endpoint avval DB'da tekshiradi, agar hech kim yo'q bo'lsa .env'dagi
    default'ga qaytadi (bir marta kirish uchun)."""

    username = fields.CharField(max_length=60, unique=True)
    password_hash = fields.CharField(max_length=255)
    display_name = fields.CharField(max_length=120, null=True)
    is_active = fields.BooleanField(default=True)

    class Meta:
        table = "pos_admin_accounts"


class Terminal(BaseModel):
    restaurant = fields.ForeignKeyField("models.Restaurant", related_name="terminals")
    name = fields.CharField(max_length=120)
    code = fields.CharField(max_length=60, unique=True)  # terminal login code
    # Provider-side cash-register / terminal id (virtual kassa).
    fiscal_terminal_id = fields.CharField(max_length=120, null=True)
    is_active = fields.BooleanField(default=True)

    class Meta:
        table = "pos_terminals"


class StaffUser(BaseModel):
    restaurant = fields.ForeignKeyField("models.Restaurant", related_name="staff")
    # Nextcloud user id (cloud-os identity) — set when access is managed from cloud-os.
    cloud_user_id = fields.CharField(max_length=120, null=True, index=True)
    full_name = fields.CharField(max_length=200)
    code = fields.CharField(max_length=60)  # short login code (e.g. employee no.)
    pin_hash = fields.CharField(max_length=255)
    role = fields.CharField(max_length=20, default="cashier")
    is_active = fields.BooleanField(default=True)

    class Meta:
        table = "pos_staff"
        unique_together = (("restaurant", "code"),)
