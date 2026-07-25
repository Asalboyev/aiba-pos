# AIBA POS — Mijozga o'rnatish qo'llanmasi

Real mijozga E-POS Communicator bilan ulash uchun bosqichma-bosqich yo'riqnoma.
Hozir barcha kod tayyor, faqat mijozning haqiqiy ma'lumotlari bilan almashtirish
va qayta build qilish qoladi.

---

## 1. Mijozdan olinadigan ma'lumotlar

| Nima | Kimda | Nima uchun kerak |
|---|---|---|
| **E-POS TOKEN** | E-POS Systems'dan (mijoz kassa qurilmasi ro'yxatdan o'tganda beriladi, format: `XXXXX...` 20 belgi) | Har chek so'roviga qo'shiladi (`token` maydoni) |
| **Kompaniya INN** (STIR) | Mijozning yuridik hujjatlaridan (9 raqamli) | E-POS uni chekka joylashtiradi (`companyINN`) |
| **Kompaniya to'liq nomi** | Yuridik hujjatlardan | Chekda ko'rinadi (`companyName`) |
| **Yuridik manzil** | Yuridik hujjatlardan | Chekda ko'rinadi (`companyAddress`) |
| **Mahsulot MXIK/IKPU kodlari** | Har mahsulot uchun **soliq.uz**dagi rasmiy 17 raqamli MXIK kodi | Chekda majburiy (`classCode`) |
| **Mahsulot packageCode** | Har mahsulot uchun (o'lchov birligi kodi) | `packageCode` — E-POS majburiy |
| **Fiscal terminal ID** | E-POS Communicator o'zi hisoblaydi (`getFiscalsList` metodi bilan) | Optional — bir necha kassa bo'lsa |
| **Kassa PC IP** | Agar backend alohida serverda ishlasa | E-POS Communicator qayerda | 

**Muhim:** E-POS Communicator o'zi mijoz **kompyuterida** o'rnatilgan bo'ladi (agar mijoz haqiqiy fiskal moduldan foydalansa). U `http://localhost:8347/uzpos` da tinglaydi. Agar backend ham o'sha kompyuterda bo'lsa — hech nima kerak emas. Agar backend boshqa serverda bo'lsa — kassa PC IP'si va port 8347 tarmoqda ochiq bo'lishi kerak, `EPOS_API_URL` esa `http://<kassa-pc-ip>:8347/uzpos` bo'ladi.

---

## 2. `pos/.env` faylini yangilash

Fayl: [pos/.env](.env)

```bash
# --- Fiscal ---
FISCAL_PROVIDER=epos                                      # mock EMAS!
FISCAL_VERIFY_BASE=https://ofd.soliq.uz/check

# --- E-POS Communicator ---
EPOS_API_URL=http://localhost:8347/uzpos                  # kassa PC'dagi E-POS Communicator
# Yoki boshqa serverda ishlasa:
# EPOS_API_URL=http://192.168.1.10:8347/uzpos
EPOS_TOKEN=<MIJOZ_TOKENI_SHUNGA>                          # E-POS Systems'dan olingan
EPOS_PORT=3448                                            # openZreport uchun (default 3448)
```

---

## 3. Restoran rekvizitlarini DB'da yangilash

Kod: DB update bilan qilinadi (hozircha adminka orqali `Restaurant` CRUD tayyor emas).

```bash
docker exec aiba-pos-db psql -U aiba_pos -d aiba_pos -c "
UPDATE pos_restaurants
   SET legal_name = '<MIJOZ YURIDIK NOMI>',
       inn        = '<9-RAQAMLI-INN>',
       address    = '<YURIDIK MANZIL>'
 WHERE code       = 'DEMO';   -- yoki mijozning restoran kodi
"
```

Yoki **adminka** orqali qo'lda ([http://localhost:8006/admin](http://localhost:8006/admin) → Restoran tanlash → tez orada Restoran tahrirlash tugmasi qo'shiladi).

---

## 4. Mahsulotlarni real MXIK bilan yangilash

Har mahsulotning `mxik_code`, `package_code`, `vat_percent` real qiymatlari qo'yiladi.

**Ikkita yo'l:**

### A) Adminka orqali (tavsiya)
1. [http://localhost:8006/admin](http://localhost:8006/admin) → `admin` / `aiba2026`
2. Mahsulotlar tab → har birini ochib MXIK, package_code, VAT yangilanadi
3. Yangi mahsulotlar ham shu yerda qo'shiladi

### B) SQL orqali (bulk)
```bash
docker exec aiba-pos-db psql -U aiba_pos -d aiba_pos -c "
UPDATE pos_products SET mxik_code='<REAL_IKPU>', package_code='<REAL_PKG>', vat_percent=12
 WHERE restaurant_id=(SELECT id FROM pos_restaurants WHERE code='DEMO')
   AND name='Palov';
-- har mahsulot uchun takrorlanadi
"
```

**MXIK kodni qayerdan olish:** [tasnif.soliq.uz](https://tasnif.soliq.uz) — mahsulot nomi bo'yicha qidiriladi. 17 raqam.

**packageCode:** E-POS `getPackages` metodi orqali IKPU uchun ruxsat berilgan o'lchov birligi kodlari olinadi (yoki tasnif.soliq.uz). Ovqat uchun odatda `dona` (`1506556`), `porsiya`, `kg`, `litr`.

---

## 5. Fiskal xizmatga ulanishni tekshirish

Konteynerlarni qayta yuklab:

```bash
cd /Users/akhror/Desktop/aiba/aiba-pos/pos
docker compose up -d --build pos pos-celery-worker pos-celery-beat
```

Health tekshirish (E-POS bilan aloqa borligini bilish):

```bash
# 1. Backend jonli
curl http://localhost:8006/health

# 2. E-POS Communicator bilan aloqa
curl -H "X-Service-Secret: dev-service-secret" \
     http://localhost:8006/api/v2/fiscal/epos/health
# Kutilayotgan: {"ok": true, "raw": {"error": false, "message": "OK!"}}

# 3. Z-report ochiqmi
curl -H "X-Service-Secret: dev-service-secret" \
     http://localhost:8006/api/v2/fiscal/epos/shift-status
# Kutilayotgan: {"is_open": true}
```

Agar Z-report yopiq bo'lsa (`isOpen: false`) — kassir smenani ochganda **avtomatik** ochiladi (`POST /api/v2/shifts/open` E-POS `openZreport` chaqiradi).

---

## 6. Backend'ni qayta build qilish

Har kod o'zgartirilganda:

```bash
cd /Users/akhror/Desktop/aiba/aiba-pos/pos
docker compose up -d --build
```

Faqat `pos` + celery restart (DB va Redis'ga tegilmasin):
```bash
docker compose up -d --build pos pos-celery-worker pos-celery-beat
```

To'liq stack'ni to'xtatish:
```bash
docker compose down
```

Log'larni ko'rish:
```bash
docker logs -f aiba-pos               # web server
docker logs -f aiba-pos-celery-worker # fiscal chek jo'natish
docker logs -f aiba-pos-celery-beat   # har daqiqada pending retry
```

DB'ga kirish:
```bash
docker exec -it aiba-pos-db psql -U aiba_pos -d aiba_pos
```

---

## 7. Flutter kassir ilovasini build qilish

### macOS uchun (dev)
```bash
cd /Users/akhror/Desktop/aiba/aiba-pos/pos-terminal
flutter clean
flutter pub get
dart run build_runner build
flutter run -d macos --release
```

### Windows kassa uchun (prod)
Windows kompyuterda:
```bash
cd pos-terminal
flutter pub get
dart run build_runner build
flutter build windows --release
# → build\windows\x64\runner\Release\aiba_pos_terminal.exe
```
Qayerda hosil bo'lgan `.exe` va yonidagi `.dll` fayllarni bir papkaga ko'chirib, kassa PC'da ishlatiladi.

### Android tablet uchun
```bash
cd pos-terminal
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```
APK'ni tabletga o'rnatiladi.

### Ilova birinchi ochilishida
1. **⚙️ Sozlamalar** (yuqori o'ng burchak)
2. **Base URL:** `http://<server-ip>:8006` (masalan `http://192.168.1.20:8006`)
3. **Terminal kodi:** mijoz terminalining kodi (masalan `T1`, `T2`)
4. **Printer IP** — ESC/POS printer IP'si (agar tarmoq printer bo'lsa) yoki **USB printer** toggle (USB bo'lsa)
5. **Saqlash**
6. Login: staff kodi + PIN

---

## 8. Kassir, terminal, restoran yaratish (mijoz uchun)

Adminkada ([http://localhost:8006/admin](http://localhost:8006/admin), `admin` / `aiba2026`):

1. **Restoran** — mijoz kompaniyasi (INN, address, legal_name)
2. **Terminallar** — har fizik kassa uchun bittadan (kod: `T1`, `T2`; fiscal_terminal_id agar bir necha fiskal modul bo'lsa)
3. **Xodimlar** — kassirlar (kod: `101`, `102`; PIN)
4. **Kategoriyalar + Mahsulotlar** — MXIK/package_code/VAT bilan

Yoki API orqali (script bilan bulk):
```bash
SECRET=dev-service-secret
BASE=http://localhost:8006

curl -X POST $BASE/api/internal/admin/restaurants \
  -H "X-Service-Secret: $SECRET" -H 'Content-Type: application/json' \
  -d '{"name":"Mijoz Restorani","code":"MIJOZ1","inn":"123456789","address":"Toshkent"}'
```

---

## 9. Kutilishi mumkin bo'lgan xatolar va yechimlari

| Xato | Sabab | Yechim |
|---|---|---|
| `ZReport zakryt` / `smena yopiq` | Kassa smenasini yopib qo'yishgan | Kassir smenani qaytadan ochsin (login qilib "smenani ochish" toggle bilan) yoki: `POST /api/v2/shifts/open` |
| `Коды ИКПУ не найдены` | MXIK kodi bazada yo'q (yo notug'ri, yo o'zgargan) | tasnif.soliq.uz'dan tekshirib, mahsulotning MXIK'ini yangilash |
| `Неправильный код единицы измерения` | packageCode noto'g'ri | E-POS `getPackages` metodi orqali IKPU uchun ruxsat berilgan kodni olish |
| `Поле маркировки не может быть пустым` | Bu mahsulot markirovka (dori, sigareta, kir yuvish poroshoki, elektronika) — `label` majburiy | Kassir barkodni skanerlaydi, u `label`ga tushishi kerak (Flutter ilovada hozircha bu qo'shilmagan — kelajakda barcode skaner integratsiya) |
| `illegal calculation` | E-POS payload'da price/amount hisoblash noto'g'ri | Kod `epos.py`da to'g'irlangan (har item = 1 birlik, price = qator jami). Agar takroran chiqsa — Postman namunasi bilan solishtir |
| `DUPLICATE_EXTERNAL_ID` | Chek allaqachon jo'natilgan (retry) | Kod avtomatik `checkReceiptIfExists` chaqirib eski chekni topadi — muammo emas |
| `request error: Name or service not known` | DNS/tarmoq muammosi (`integration.epos.uz` yoki mijoz IP'siga chiqmaydi) | Tarmoqni tekshirish, `curl http://<epos-host>:8347/uzpos` — javob keladimi |
| `HTTP 504` (backend timeout) | E-POS 60+ soniya javob bermayapti | E-POS Communicator kompyuterini restart qilish, servis holatini tekshirish |
| Backend cold start'da `IntegrityError: pos_restaurants` | Bir marta build'da web + celery race qiladi | Docker o'zi restart qiladi — 2-urinishda o'tadi. Yo'l bo'yicha: `main.py:72`'da `generate_schemas=True`'ni faqat web'ga qoldirish |

---

## 10. Debug/Log ko'rish uchun buyruqlar

Fiskal chek DB'da:
```bash
docker exec aiba-pos-db psql -U aiba_pos -d aiba_pos -c "
SELECT o.number, o.total, r.status, r.fiscal_sign, r.retries, r.last_error
  FROM pos_fiscal_receipts r
  JOIN pos_orders o ON r.order_id=o.id
 ORDER BY r.created_at DESC LIMIT 20;
"
```

Bitta chekni qo'lda qayta jo'natish:
```bash
SECRET=dev-service-secret
curl -X POST -H "X-Service-Secret: $SECRET" \
  http://localhost:8006/api/v2/fiscal/receipts/<RECEIPT_UUID>/retry
```

Barcha `pending`/`failed` cheklarni qayta jo'natish (celery beat har daqiqada avtomatik qiladi):
```bash
# Ichkaridan kelayotgan Celery task shu ishni qiladi:
docker exec aiba-pos-celery-worker celery -A app.core.celery.celery_app \
  call app.tasks.fiscal.retry_pending_fiscal
```

E-POS ga to'g'ridan-to'g'ri health check:
```bash
curl -X POST http://<epos-ip>:8347/uzpos \
  -H 'Content-Type: application/json' \
  -d '{"token":"<TOKEN>","method":"checkStatus"}'
```

---

## 11. Ishlab chiqarish uchun xavfsizlik

1. **JWT_SECRET_KEY** ni tasodifiy uzun stringga o'zgartirish (`openssl rand -hex 32`)
2. **AIBA_SERVICE_SECRET** ni ham (Nextcloud plugin bilan mos)
3. **POS_ADMIN_PASSWORD** — kuchli parol
4. **CORS** — hozir `allow_origins=["*"]`, prod'da mijoz domenlariga cheklash ([main.py:63](main.py))
5. **Postgres port** (`5436`) — internet'dan yopiq bo'lsin (faqat container tarmog'i)
6. **HTTPS** — nginx/caddy reverse proxy orqali (`http://` emas)

---

## 12. Markirovka mahsulotlar (dori, sigareta, alkogol, suv)

Endi to'liq qo'llab-quvvatlanadi:

1. **Adminka'da mahsulotni yaratayotganda / tahrirlayotganda** — `marking_required: true` yoqiladi (dori, sigareta, alkogol, suv shishalari uchun)
2. **Adminka MXIK'ni saqlashda avtomatik E-POS'ga tekshiradi** (`onlineLabelValidation`) — noto'g'ri IKPU chiqmaydi
3. **Kassir ilova**: markirovka mahsulot ustida `qr_code_scanner` ikonkasi ko'rinadi (to'q sariq)
4. **Bosilganda** — DataMatrix skanerlash dialog ochiladi
5. USB skaner keyboard emulator sifatida DataMatrix matnini kiritadi + Enter yuboradi → savatga qo'shiladi
6. **Backend har buyurtma yaratishda validatsiya qiladi**:
   - MXIK bo'sh yoki 17 raqam emas → 400 xato ("mxik_code must be exactly 17 digits")
   - Markirovka mahsulotga label yo'q → 400 xato ("scan the code on the product")
   - E-POS'ga umuman bormaydi, chek yaratilmaydi, kassir aldanmaydi

**2D skaner turi:** Har 2D USB skaner (yoki Bluetooth) mos keladi. Test qilingan turi: HENEX H120, ODM, GlobalPos GP-9600B.

## 13. Nima qilib bo'lmadi (kelajak)

- **Multi-payment split** (naqd + karta bir chekda) — data model tayyor, UI yo'q
- **Token refresh** — JWT muddati tugasa qayta login kerak
- **Nextcloud plugin** — alohida Nextcloud instance ishga tushirilmagan, faqat plugin kodi tayyor
- **`getPackages` metodini adminka'da ishlatish** — hozir MXIK bilan `onlineLabelValidation` chaqiriladi, packageCode variantlarini avtomatik taklif qilish qo'shilishi mumkin

---

## Qisqacha checklist

- [ ] Mijozdan: E-POS TOKEN, INN, kompaniya nomi, manzil, IKPU'lar
- [ ] `.env`da `FISCAL_PROVIDER=epos`, `EPOS_TOKEN=...`, `EPOS_API_URL=...`
- [ ] DB'da restoran INN + address yangilangan
- [ ] Har mahsulot IKPU + packageCode + VAT to'g'ri
- [ ] `docker compose up -d --build`
- [ ] `curl /api/v2/fiscal/epos/health` → `ok: true`
- [ ] Adminkada Terminal + Xodim yaratilgan
- [ ] Flutter ilovada Base URL to'g'ri
- [ ] Test buyurtma → fiscal_sign va QR keladi
- [ ] Printer IP yoki USB → chek chiqadi
