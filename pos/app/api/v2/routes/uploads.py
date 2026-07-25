import hashlib
import io
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from PIL import Image, ImageOps

from app.api.helpers import require_manager
from app.dependencies.auth import Principal, get_principal

router = APIRouter(tags=["uploads"])

# Rasm fayllar shu papkaga yoziladi. Static fayl serve `/static/uploads/*`
# orqali chiqadi (main.py'da mount qilinadi).
UPLOAD_ROOT = Path("/app/app/static/uploads")
UPLOAD_ROOT.mkdir(parents=True, exist_ok=True)

MAX_BYTES = 5 * 1024 * 1024  # 5 MB
ALLOWED_MIME = {"image/jpeg", "image/png", "image/webp", "image/gif"}
# Kartochka uchun yetarli maksimal o'lcham (yuqori DPI ekranlar uchun)
MAX_DIMENSION = 1024


@router.post("/uploads/image")
async def upload_image(
    file: UploadFile = File(...),
    principal: Principal = Depends(get_principal),
):
    """Bitta rasm yuklaydi, resize qilib WebP formatida saqlaydi, URL qaytaradi.

    - Faqat menejer/service yuklashi mumkin
    - JPEG/PNG/WebP/GIF qabul qilinadi
    - Maks 5 MB
    - Avtomatik 1024x1024 gacha resize
    - EXIF orientation avtomatik to'g'irlanadi
    - Content-hash bilan takror yuklashda bir xil fayl qayta yozilmaydi
    """
    require_manager(principal)
    if file.content_type not in ALLOWED_MIME:
        raise HTTPException(400, detail=f"Ruxsat berilmagan format: {file.content_type}")

    raw = await file.read()
    if len(raw) > MAX_BYTES:
        raise HTTPException(400, detail=f"Rasm 5 MB dan katta ({len(raw)//1024} KB)")

    # Pillow bilan ochib, resize + WebP formatiga o'girish
    try:
        img = Image.open(io.BytesIO(raw))
        img = ImageOps.exif_transpose(img)  # EXIF Orientation
        if img.mode not in ("RGB", "RGBA"):
            img = img.convert("RGB")
        img.thumbnail((MAX_DIMENSION, MAX_DIMENSION), Image.Resampling.LANCZOS)
    except Exception as e:  # noqa: BLE001
        raise HTTPException(400, detail=f"Rasm o'qib bo'lmadi: {e}")

    out_buf = io.BytesIO()
    img.save(out_buf, format="WEBP", quality=85, method=6)
    out_bytes = out_buf.getvalue()

    # Content-hash asosidagi fayl nomi — bir xil rasm 2 marta yuklansa
    # yagona URL qaytadi (deduplication).
    digest = hashlib.sha256(out_bytes).hexdigest()[:16]
    filename = f"{digest}.webp"
    path = UPLOAD_ROOT / filename
    if not path.exists():
        path.write_bytes(out_bytes)

    return {
        "url": f"/static/uploads/{filename}",
        "size": len(out_bytes),
        "width": img.width,
        "height": img.height,
    }
