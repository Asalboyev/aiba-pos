# AIBA POS — Biznes protsess (restoran ishi)

Restoran ochilishidan yopilgunicha barcha ish jarayonlari. Har rol uchun vazifa,
har vaqt uchun harakat.

---

## 1. Rollar va vazifalar

```
┌─────────────────────────────────────────────────────────┐
│  RESTORAN EGASI / DIREKTOR                              │
│  • Restoran ro'yxatdan o'tkazish                        │
│  • E-POS Systems'da fiskal modul olish                  │
│  • Diler bilan shartnoma (mahsulot yetkazib berish)     │
│  • Bosh menejer tayinlash                               │
│  • Oylik moliyaviy hisobot                              │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  MENEJER                                                │
│  • AIBA POS adminka'sida ishlaydi                       │
│  • Mahsulot menyu qo'shish/tahrirlash                   │
│  • Xodim (kassir/ofitsiant) yaratish                    │
│  • Terminal (kassa) yaratish                            │
│  • Kun oxiri hisobotlarni ko'rish                       │
│  • Chegirma va aksiyalar boshqarishi                    │
│  • Xato cheklarni retry qilish                          │
└─────────────────────────────────────────────────────────┘
                          ↓
┌────────────────────────────┬────────────────────────────┐
│  KASSIR                    │  OFITSIANT                 │
│  • Kassa PC'da ishlaydi    │  • Android tablet          │
│  • AIBA POS kassir ilovada │  • Mijoz stolida zakaz     │
│  • Smena ochish/yopish     │    oladi                   │
│  • Zakaz qabul qilish      │  • Kassa PC bilan sync     │
│  • Pul olish (naqd/karta)  │  • Kassirga jo'natadi      │
│  • Chek chiqarish          │                            │
└────────────────────────────┴────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  OSHPAZ / BARMAN                                        │
│  • Chek chiqmaganda o'zi ko'rmaydi                      │
│  • Kelib chiqadigan buyurtmalarni tayyorlaydi           │
│  • (Kelajakda: kuxonya ekranga ko'rinadigan qilamiz)    │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Restoran ochish — birinchi kun (bir marta)

### Ish kuni −7 kun: Tayyorgarlik
- [ ] E-POS Systems'da ro'yxatdan o'tish → EPOS_TOKEN olish
- [ ] Fiskal modul + Windows kassa PC sotib olish
- [ ] 2D USB barkod skaner sotib olish (agar shishadagi ichimlik/alkogol/sigareta sotilsa)
- [ ] 80mm ESC/POS chek printer (tarmoq yoki USB)
- [ ] UPS (uzluksiz elektr manbai) — 500K–1M so'm
- [ ] Ehtiyot mobil internet (USB modem yoki hotspot)
- [ ] Diler bilan shartnoma (mahsulot yetkazib berish)

### Ish kuni −3 kun: Texnik o'rnatish
- [ ] Windows kassa PC'ga E-POS Communicator o'rnatish
- [ ] Fiskal modulni USB orqali ulash + test
- [ ] AIBA POS backend'ni ishga tushirish (`docker compose up -d`)
- [ ] Adminka'ga kirish, restoran rekvizitlarini kiritish (INN, address, name)
- [ ] `.env`da `EPOS_TOKEN` mijoznikiga o'zgartirish

### Ish kuni −2 kun: Menyu tayyorlash (menejerning katta ishi)
- [ ] tasnif.soliq.uz'dan barcha mahsulotlar MXIK va packageCode yozib olish
- [ ] Adminka → Mahsulotlar → har birini qo'shish:
  - Nomi, narxi, kategoriya
  - MXIK (17 raqam)
  - packageCode
  - VAT %
  - **Markirovka toggle** (shishadagi ichimlik, alkogol → YOQIB, ovqat → O'CHIRIB)
- [ ] Kategoriyalar tuzish (Taomlar, Ichimliklar, Bar, Desertlar, ...)

### Ish kuni −1 kun: Xodim va terminal
- [ ] Adminka → Xodimlar → barcha kassir/menejerlarni qo'shish (kod + PIN)
- [ ] Adminka → Terminallar → har fizik kassa uchun terminal yaratish (T1, T2)
- [ ] Kassa PC'ga AIBA POS Terminal ilovani o'rnatish (`.exe`)
- [ ] Ilovaga Base URL, Terminal kodi, Printer IP kiritish
- [ ] Test buyurtma qilib fiscal chek keladimi tekshirish

### Ish kuni 0: Ochilish 🎉
Kassir smenani ochadi, mijozlar keladi, sotuv boshlanadi.

---

## 3. Kunlik operatsiya

### 08:00 — Smena boshi (kassir)

```
1. Kassa PC'ni yoqadi
   ↓
2. AIBA POS ilovasini ochadi
   ↓
3. PIN pad'da:
   • Terminal kodi: T1 (avtomatik)
   • Xodim kodi: 101
   • PIN: ****
   • ☑ "Kirishda smenani ochish" (yoqilgan)
   • Boshlang'ich kassa: 500000 so'm (oldingi kundan qolgan)
   • KIRISH bosadi
   ↓
4. Backend avtomatik:
   • JWT token beradi
   • Shift.create() — smena ochiladi
   • E-POS'ga openZreport chaqiradi (fiscal modul smena ochiladi)
   ↓
5. Adminka Cheklar tab'da yashil "smena ochiq" indikatori
```

### 09:00–22:00 — Kun davomi (kassir)

**Har mijoz uchun oqim:**

```
1. Mijoz stolga o'tirdi
   ↓
2. Ofitsiant zakaz oladi (planshetda) yoki mijoz kassaga kelib buyurtma beradi
   ↓
3. Kassir ilovada mahsulotlarni bosadi:
   • Palov, Manti — oddiy tanlash
   • Cola/Fanta/alkogol — dialog ochiladi:
     - 2D skaner shishaga tegiziladi
     - DataMatrix avtomatik yoziladi
     - OK bosiladi (yoki skaner o'zi Enter yuboradi)
   ↓
4. Savat to'ldiriladi, chegirma (agar bor) qo'yiladi
   ↓
5. "To'lov" bosiladi:
   • Naqd: mijozdan pul olib summani kiritadi
   • Karta: pinpad orqali (kelajakda integratsiya)
   • QR: mijoz telefonda skanerlaydi (kelajakda)
   ↓
6. Tasdiqlash:
   • Ilova zakazni backend'ga jo'natadi
   • Backend E-POS'ga sale metodini yuboradi
   • ~2 sekundda fiscal_sign + QR keladi
   ↓
7. Chek chop etiladi (80mm printer):
   • Kompaniya, sana, mahsulotlar
   • Jami, chegirma, to'lov turi
   • Fiskal QR — mijoz telefonda skanerlaydi
   ↓
8. Mijozga chek beriladi
```

**Muammolar bo'lganda:**

| Xato | Kassir nima qiladi |
|---|---|
| Internet uzilgan → "Oflayn saqlandi" | Ishni davom ettiradi, keyin ⟳ bosadi |
| Fiskal xato → "Fiskal: xato" | Menejerni chaqiradi (adminkada retry) |
| Skaner ishlamadi | Menejer manual DataMatrix kiritadi (Bekor bosmasin) |
| Printer o'chdi | Zakaz ilovada saqlangan, keyin printerni ulaydi |
| Elektr uzildi (UPS bor) | 30 daqiqa davom etadi, keyin ish to'xtaydi |

### 22:00 — Smena yopish (kassir)

```
1. Kassir "Smena" tabga o'tadi
   ↓
2. "Smenani yopish" bosadi
   • Yopiladigan naqd summasi: ekran ko'rsatadi
   • Yopiladigan karta: ekran ko'rsatadi
   • Kassir yashikdagi haqiqiy naqd hisoblab kiritadi
   • Farq bo'lsa (kam yoki ortiq) — sabab yoziladi
   ↓
3. Tasdiqlash:
   • Backend Shift.close() — smena yopiladi
   • E-POS'ga closeZreport chaqiradi
   • Fiskal modul kunlik Z-report chiqaradi (soliq.uz'ga yuboriladi)
   ↓
4. Kunlik Z-report chekada chop etiladi:
   • Umumiy savdo
   • Naqd/karta ajratilishi
   • Chek soni
   • QQS summasi
   ↓
5. Kassir smena kalitini menejerga beradi
```

### 22:30 — Menejer nazorat (kun oxiri)

```
1. Adminka'ga kiradi
   ↓
2. Dashboard tab:
   • Bugungi jami savdo
   • Cheklar soni
   • Naqd/karta ajratilishi
   • Top mahsulotlar
   ↓
3. Cheklar tab:
   • Qizil failed cheklar bormi?
     - Ha → sababni tekshiradi, retry qiladi yoki manual tuzatadi
   • Muhim ma'lumot: har chek fiscal_sign bor
   ↓
4. Xodimlar tab:
   • Kim qancha sotgan (kelajak feature)
   ↓
5. Kassa yashikda haqiqiy pul + kartadan tushgan pul = adminka jami
   Agar mos bo'lmasa — kassir bilan tushuntirish
```

---

## 4. Haftalik operatsiyalar (menejer)

### Dushanba: Ombor tekshiruvi
- Diler haftalik mahsulot yetkazib beradi (Cola, alkogol, ovqat mahsulotlari)
- Menejer har qutini qabul qiladi
- Markirovka mahsulotlar (Cola shishalar) skanerlanadi → soliq bazasida "Milli Grill omboriga qabul qilindi" deb qayd qilinadi
- Ombor daftariga miqdor yoziladi

### Chorshanba: Menyu yangilash
- Yangi mahsulot chiqarilsa (mavsumiy taom, aksiya)
- Adminka → Mahsulotlar → Yangi mahsulot
- MXIK/packageCode tasnif'dan olinadi
- Marking_required to'g'ri qo'yiladi

### Yakshanba: Haftalik hisobot
- Umumiy savdo (7 kun jami)
- Kunlik o'rtacha
- Top mahsulotlar
- Chegirma jami
- Egasiga hisobot

---

## 5. Oylik operatsiyalar (menejer + egasi)

### Oyning 1-si: Yangi oy tayyorgarlik
- O'tgan oy hisobotini yopish
- Yangi oy budjeti
- Xodim maoshlari
- Diler to'lovi

### Oyning 5-si: Soliq nazorati
- soliq.uz'da hisobot ko'rish
- Barcha cheklar OFD'da borligini tekshirish
- Har MXIK bo'yicha sotuv statistikasi

### Oyning 15-si: Inventar
- Ombor tekshiruvi (haqiqiy vs bazada)
- Chiqib ketgan mahsulotlar
- Yo'qolgan/buzilgan mahsulotlar (write-off)

### Oyning 25-si: Yangi oy zakazi
- Diler bilan yangi oy uchun mahsulot ro'yxati
- Aksiya rejalari

---

## 6. Muhim biznes qoidalari

### A. Chek berish
- **Har sotuv → chek** — istisnosiz
- Chek bo'lmagan sotuv = **jarima**
- Chek fiscal_sign bilan bo'lishi shart

### B. Chegirma qoidalari
- Menejer chegirma qanoati bilan cheklaydi (maksimal % avval kelishilgan)
- Kassir chegirmani ochiq sotib bo'lmaydi (menejer PIN kerak)
- Har chegirma sababi log'ga tushadi

### C. Qaytarish (refund)
- Mijoz mahsulotni qaytarsa (nokifoya sifat, boshqa sabab)
- Menejer roziligi bilan
- Adminka → Cheklar → chekni ochib "Refund"
- E-POS'ga refund chek yuboriladi
- Naqd qaytariladi

### D. Markirovka mahsulotlar
- **Har shisha uchun ALOHIDA skanerlash** — majburiy
- Skanersiz sotish = **jinoiy javobgarlik**
- Skaner buzilsa → menejer o'zi manual kiritadi (DataMatrix ni telefondan o'qib)
- Skanersiz kun ochilmasin

### E. Xodim ish shartlari
- Kassir 8 soatlik smena
- Har 4 soatda tanaffus
- Smena boshi/oxirida yashikdagi naqd tekshiruvi
- Xodim yashik pulini o'g'irlasa — video kuzatuv + kassir PIN log'i

---

## 7. Kelajak takomillashtirish (feature roadmap)

| Feature | Vaqt | Ustuvorlik |
|---|---|---|
| Ofitsiant Android planshet | 1 hafta | Yuqori |
| Oshpaz kuxonya ekrani (KDS) | 2 hafta | O'rta |
| Karta pinpad integratsiyasi (Arcus 2.1) | 1 hafta | Yuqori |
| QR to'lov (Click, Payme) | 1 hafta | Yuqori |
| SMS orqali chek yuborish | 3 kun | O'rta |
| Loyalty (mijoz karta, chegirma) | 2 hafta | O'rta |
| Yetkazib berish (Yandex, Wolt) | 2 hafta | Past |
| CRM (mijozlar bazasi) | 1 oy | Past |
| Kuxonya reseptlari (mahsulot xarajati) | 2 hafta | Past |
| Xodim smenasini kalendarga bog'lash | 1 hafta | Past |

---

## 8. Xato paytida javob berish

### Elektr o'chdi
1. UPS orqali 30 daqiqa davom etadi
2. Elektr qaytmasa: kassir daftar/qog'ozga zakazlarni yozadi
3. Mijozdan telefon so'raydi (chekni SMS qilish uchun)
4. Elektr qaytgach: daftardan ilovaga kiritiladi, cheklar avtomatik yuboriladi

### Internet uzildi
1. Ilova offline queue'ga saqlaydi (avtomatik)
2. Kassir ishni davom ettiradi
3. Chek "Fiskal: kutilmoqda" bilan chiqadi
4. Internet qaytgach: avtomatik sync

### Fiskal modul bloklandi
1. Sotuv **darrov to'xtatiladi**
2. E-POS Systems'ga zvonok (24/7 support)
3. Sabab: 24 soatdan ko'p chek jo'natilmadi
4. Yechim: ular remote'dan blokni ochadi (~2-6 soat)

### Kassir yashikda kam pul
1. Menejer kassir bilan gaplashadi
2. Video kuzatuvni ko'radi
3. Har chekni log'ga qarab kim/qachon sotgan
4. Jiddiy holat: politsiya

### Mijoz shikoyat qildi (chek soxta deb)
1. Chekdagi QR ni telefonda skanerlash → soliq.uz'da tekshirish
2. Agar soliq.uz'da bor → haqiqiy, muammo yo'q
3. Agar yo'q → menejer tekshiradi (ehtimol E-POS bloklangan bo'lishi mumkin)

---

## 9. Kompliyans va qonun

### Har oyda soliqqa topshiriladigan
- QQS hisobot (avtomatik OFD'dan tortiladi)
- Aksiz solig'i (alkogol, sigareta) — avtomatik
- Kirim solig'i (buxgalter)

### Har chek uchun majburiy ma'lumot (bizning ilova avtomatik qiladi):
- Kompaniya INN, nomi, manzili
- Sotgan xodim ismi
- Har qator uchun MXIK
- Har markirovka mahsulot uchun DataMatrix
- QQS % va summasi
- Umumiy summa, to'lov turi

### Buzilgan mahsulot (write-off)
- Alkogol/sigareta bo'lsa: soliq bazasida "yo'q qilindi" deb qayd qilinadi
- Ovqat: menejer daftariga yozadi

---

## 10. Yakuniy checklist — mijozga topshirish

- [ ] Backend `.env`da real EPOS_TOKEN
- [ ] Adminka'da restoran rekvizitlari (INN, address, legal_name)
- [ ] Barcha menyu MXIK/packageCode/marking_required to'g'ri kiritilgan
- [ ] Kassir/menejer yaratilgan
- [ ] Terminal T1 yaratilgan
- [ ] Kassa PC'da AIBA POS Terminal ochilgan
- [ ] Base URL, Terminal kodi, Printer IP kiritilgan
- [ ] Test buyurtma qilingan → fiscal_sign kelgan → soliq.uz'da ko'ringan
- [ ] Chek printer ishlashi tekshirilgan
- [ ] Menejerga adminka'dagi barcha tab'lar ko'rsatilgan
- [ ] Kassirga ilovaning barcha tugmalari ko'rsatilgan
- [ ] Elektr uzilsa nima qilish kerakligi tushuntirilgan
- [ ] UPS + mobil internet mavjud
- [ ] 2D skaner sozlangan (markirovka mahsulotlari uchun)
- [ ] E-POS Systems support telefon raqami menejerga berilgan
- [ ] AIBA POS support (siz) telefon raqami menejerga berilgan
