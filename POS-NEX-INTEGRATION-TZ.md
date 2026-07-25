# AIBA POS × Nex — Integratsiya TZ (Texnik topshiriq)

> **Maqsad**: AIBA POS sistemasini AIBA Nex platformasining bir moduli qilib
> qo'shish. Foydalanuvchi `next.aiba.uz`'ga kirsa, sidebar'dan **"POS"**
> punktini bosib, restoran/do'kon adminka'sini shu joyda ochadi.
>
> **Auditoriya**: Ushbu hujjat Claude Code (yoki boshqa dasturchi) tomonidan
> **bir o'qishda tushunilishi va boshlash uchun** yozilgan. Har nima
> aniq — pathlar, komandalar, kod misollari.

---

## 1. Loyihalar joylashuvi (lokal)

```
~/Desktop/aiba/
├── nex/                            ← Katta sistema (AIBA Cloud)
│   ├── frontend/                   React + Vite + TS + Tailwind + Radix
│   │   ├── src/
│   │   │   ├── app/layout/         nav-config.ts, tab-routes.tsx
│   │   │   ├── modules/            har bir modul alohida papka
│   │   │   │   ├── warehouse/      ← namunaviy modul (pattern)
│   │   │   │   ├── companies/
│   │   │   │   ├── tasks/
│   │   │   │   └── ...
│   │   │   ├── shared/api/         axios client, X-Tenant, JWT
│   │   │   └── main.tsx
│   │   └── package.json            dev port: 5181
│   └── backend/                    Rust + axum BFF
│       └── crates/                 dev port: 18001
│
└── aiba-pos/                       ← Bizni POS sistema
    ├── pos/                        FastAPI + Tortoise + Celery + Redis + PostgreSQL
    │   ├── app/                    prod port: 8006
    │   │   ├── api/v2/             terminal uchun API (JWT scope=tenant)
    │   │   ├── api/internal/       adminka uchun API (JWT role=admin)
    │   │   ├── static/admin.html   ← hozirgi adminka (vanilla HTML+JS)
    │   │   └── models/             Restaurant, Product, Order, StockMovement...
    │   └── docker-compose.yml
    ├── pos-terminal/               Flutter (macOS + Windows + Android)
    └── nextcloud-server/           ← BEKOR: cloud-os plugini (endi Nex ichida)
```

**Server URL'lari** (prod):

| Loyha | URL |
|---|---|
| Nex frontend | `https://next.aiba.uz` |
| Nex backend | `https://next.aiba.uz/api/v2` (nginx orqali) |
| **POS API** | `https://pos.milli-grill.uz` (yoki `https://<sizniki>`) |
| POS adminka | `https://pos.milli-grill.uz/admin` |

---

## 2. Nex modul patterni (mavjud)

Nex'da har bir modul quyidagi tarkibda:

```
src/modules/<name>/
├── page.tsx            asosiy sahifa (default export)
├── <name>-api.ts       axios so'rovlar
├── detail-page.tsx     (agar detal sahifa bo'lsa)
└── docs/pages/         qo'llanma (uz/uz_Cyrl/ru/en) — MUST HAVE
```

**Registratsiya joyi**:

1. **Sidebar/menu** — `src/app/layout/nav-config.ts`
   ```ts
   { key: "pos", title: "POS Kassa", labelKey: "nav.pos",
     desc: "Restoran / do'kon kassasi", icon: "Store", to: "/pos", slug: "pos" }
   ```

2. **Route** — `src/app/layout/tab-routes.tsx`
   ```tsx
   const PosPage = lazy(() => import("@/modules/pos/page").then((m) => ({ default: m.PosPage })));
   // <Route path="/pos/*" element={<PosPage />} />
   ```

3. **URL state** — barcha filter/page/tab URL'da yashaydi (`useUrlState`)

---

## 3. Integratsiya strategiyasi — 3 bosqich

### Bosqich 1 — Iframe moduli (1-2 kun) 🚀

**Maqsad**: POS bugun Nex ichida ishlasin. Kod deyarli o'zgarmaydi.

Yaratamiz: `nex/frontend/src/modules/pos/page.tsx`

```tsx
import { useEffect, useMemo, useRef } from "react";
import { useAuth } from "@/shared/auth/hooks";

// POS backend URL — env orqali
const POS_URL = import.meta.env.VITE_POS_URL || "https://pos.milli-grill.uz";

export function PosPage() {
  const { token, tenant } = useAuth();
  const iframeRef = useRef<HTMLIFrameElement>(null);

  // POS admin.html'ga tokenni URL orqali beramiz — u localStorage'ga saqlaydi
  const src = useMemo(() => {
    const url = new URL(`${POS_URL}/admin`);
    if (token) url.searchParams.set("nex_token", token);
    if (tenant) url.searchParams.set("tenant", tenant);
    return url.toString();
  }, [token, tenant]);

  return (
    <div className="h-full w-full">
      <iframe
        ref={iframeRef}
        src={src}
        className="h-full w-full border-0"
        title="POS Adminka"
        allow="clipboard-read; clipboard-write"
      />
    </div>
  );
}
```

**POS tomonida** (`pos/app/static/admin.html`) — URL'dan token o'qib login o'tkazish:

```js
// admin.html — DOMContentLoaded
const urlToken = new URLSearchParams(location.search).get('nex_token');
if (urlToken && !localStorage.getItem('aiba_pos_admin_token')) {
  // Nex JWT'ni POS backend'ga jo'natib, POS admin JWT'ga almashtirish
  fetch('/api/internal/admin/nex-exchange', {
    method: 'POST',
    headers: { 'Authorization': 'Bearer ' + urlToken }
  }).then(r => r.json()).then(d => {
    localStorage.setItem('aiba_pos_admin_token', d.access_token);
    location.reload();
  });
}
```

**POS backend** yangi endpoint (`pos/app/api/internal/routes/admin.py`):

```python
@router.post("/nex-exchange")
async def nex_token_exchange(request: Request):
    """Nex JWT'ni validate qilib, POS admin JWT beramiz."""
    auth = request.headers.get("Authorization", "").removeprefix("Bearer ").strip()
    payload = verify_nex_jwt(auth)  # Nex'ning public key'i bilan
    # payload'dan tenant → restaurant_id mapping
    restaurant = await Restaurant.filter(nex_tenant=payload["tenant"]).first()
    if not restaurant:
        raise HTTPException(404, "Restoran topilmadi")
    admin_token = create_admin_token(restaurant_id=str(restaurant.id))
    return {"access_token": admin_token}
```

**Vazifalar** (Bosqich 1):
- [ ] `nex/frontend/src/modules/pos/page.tsx` — iframe komponent
- [ ] `nav-config.ts`'ga "POS Kassa" punkti (icon: `Store`)
- [ ] `tab-routes.tsx`'ga `/pos/*` marshrut
- [ ] POS `admin.html`'ga URL-token handler
- [ ] POS backend'ga `/api/internal/admin/nex-exchange` endpoint
- [ ] Nex JWT public key'ini POS'ga o'rnatish (env: `NEX_JWT_PUBKEY`)
- [ ] `pos_restaurants` jadvaliga `nex_tenant VARCHAR(80) UNIQUE` maydon
- [ ] Adminka HTML'da `X-Frame-Options` headerni next.aiba.uz'ga ruxsat berish
- [ ] Nex'da `VITE_POS_URL` env

**Yakunda**: `https://next.aiba.uz/pos` ochilsa — POS adminka to'liq ishlaydi, alohida login yo'q.

---

### Bosqich 2 — Native React modul (5-7 kun) 🎨

Iframe ishlab turgan holida, asta-sekin POS admin'ni React'ga ko'chiramiz.

**Papka tuzilishi**:

```
nex/frontend/src/modules/pos/
├── page.tsx                    ← asosiy router (Sotuv/Ombor/Sozlamalar tab'lari)
├── pos-api.ts                  ← axios: menu, orders, stock
├── dashboard/
│   └── page.tsx                bugungi savdo, cheklar, top mahsulot
├── orders/
│   ├── page.tsx                cheklar ro'yxati
│   └── detail-page.tsx         chek ichi
├── products/
│   ├── page.tsx                mahsulotlar + kategoriyalar
│   ├── product-form.tsx        modal
│   └── category-rail.tsx       tepadagi chip'lar
├── stock/
│   └── page.tsx                ombor kirim/chiqim
├── staff/
│   └── page.tsx                xodimlar (Nex user bilan link)
├── terminals/
│   └── page.tsx                POS terminallar
├── settings/
│   ├── page.tsx                chek sozlamalari + parol
│   └── receipt-preview.tsx     jonli chek preview
└── docs/pages/
    ├── 010-intro.uz.md
    ├── 020-products.uz.md
    └── ... (4 til, har biri)
```

**API qatlami** (`pos-api.ts`):

```ts
import { apiClient } from "@/shared/api/client";

// POS backend uchun alohida axios instance yoki qo'shimcha baseURL
const posApi = apiClient.create({
  baseURL: `${import.meta.env.VITE_POS_URL}/api/internal/admin`,
});

export function useProducts(restaurantId: string) {
  return useQuery({
    queryKey: ["pos", "products", restaurantId],
    queryFn: () => posApi.get(`/products?restaurant_id=${restaurantId}`).then(r => r.data),
  });
}

// ... orders, stock, categories, settings — hammasi TanStack Query bilan
```

**URL state** — `useUrlState('cat', null)` orqali kategoriya filtri, `useUrlState('page', 1)` sahifa. Multi-tab shell tabiiy ishlashi uchun.

**Style** — Radix UI komponentlari (Dialog, Tabs, DropdownMenu, Toast) + Tailwind. `admin.html`'dagi CSS'ni `@/components/ui` pattern'iga o'girish.

**Vazifalar** (Bosqich 2, har bir ekran alohida sprint):
- [ ] Sprint 2.1 — Dashboard + Products
- [ ] Sprint 2.2 — Orders (cheklar tarixi + detal)
- [ ] Sprint 2.3 — Stock (ombor kirim/chiqim/write-off)
- [ ] Sprint 2.4 — Staff + Terminals
- [ ] Sprint 2.5 — Settings (chek + parol)
- [ ] Sprint 2.6 — Qo'llanma (docs/pages/) — 4 tilda

---

### Bosqich 3 — To'liq birlashish (2-3 hafta) 🔗

Uzoq muddat: POS'ni Nex ekosistemasiga chuqur bog'lash.

- **Xodimlar**: `pos_staff` jadvalini olib tashlab, Nex'ning `users` bilan bevosita bog'lash
- **Kompaniyalar**: `pos_restaurants.nex_tenant` — Nex'ning tenant'ini takrorlaydi, bir joyda boshqariladi
- **Yagona backend**: POS'ning Rust'ga port qilish (agar Nex jamoasi xohlasa) yoki FastAPI sifatida qoldirib, Nex backend'i orqali proksilash
- **Cascade events**: Nex'ning event bus'iga POS voqealarini ulash (masalan: sotuvdan keyin `sale.completed` → buxgalteriya modulini yangilaydi)

---

## 4. Autentifikatsiya oqimi

```
┌────────────────────────────────────────────────────────────────────┐
│ Foydalanuvchi                                                       │
│    │                                                                │
│    │  1. Nex'ga login                                               │
│    ▼                                                                │
│  Nex Frontend (next.aiba.uz)                                        │
│    │                                                                │
│    │  2. JWT (audience: aiba, tenant: milli_grill)                  │
│    │  3. Sidebar → POS                                              │
│    ▼                                                                │
│  Nex modules/pos/page.tsx (iframe → POS admin.html?nex_token=…)     │
│    │                                                                │
│    │  4. admin.html JS: /api/internal/admin/nex-exchange            │
│    │     Header: Authorization: Bearer <Nex JWT>                    │
│    ▼                                                                │
│  POS FastAPI backend                                                │
│    │                                                                │
│    │  5. Nex JWT'ni verify (Nex public key bilan)                   │
│    │  6. payload.tenant → Restaurant.nex_tenant qidiruv             │
│    │  7. POS admin JWT yaratish (role=admin, restaurant_id=…)       │
│    │                                                                │
│    ▼                                                                │
│  admin.html: token localStorage'ga, keyingi so'rovlarga Bearer      │
└────────────────────────────────────────────────────────────────────┘
```

**Muhim**: POS Terminal ilovasi (Flutter) — bu oqimga aloqasiz.
Terminal to'g'ridan-to'g'ri POS API'ga `/api/v2/auth/login`
(kod+PIN) orqali kiradi. O'zgarmaydi.

---

## 5. Deployment

### POS backend server (mavjud)

```
https://pos.milli-grill.uz      → Docker Compose (aiba-pos/pos/)
                                   nginx reverse-proxy
                                   SSL: Let's Encrypt
```

### Nex frontend — hech nima o'zgarmaydi

Faqat env qo'shiladi:
```
VITE_POS_URL=https://pos.milli-grill.uz
```

### Nex backend — kelajakda (bosqich 3)

Hozircha aloqa yo'q. Bosqich 3'da POS API'ni proksilash uchun Nex backend'da yangi route:
```
GET/POST /api/v2/pos/* → https://pos.milli-grill.uz/api/internal/admin/*
```

---

## 6. Repo va CI/CD

| Repo | Nima uchun |
|---|---|
| `gitlab.aiba.uz/milli-grill/pos` | POS backend + Flutter terminal + adminka |
| `github.com/Asalboyev/aiba-pos` | Public mirror + GitHub Actions (Windows/macOS build) |
| `nex/frontend` (Nex GitLab) | Nex UI — pos modulini shu yerga qo'shamiz |
| `nex/backend` (Nex GitLab) | Nex Rust API — bosqich 3'da o'zgaradi |

**Build**: POS ilovalar allaqachon GitHub Actions'da avto build:
- macOS: `AIBA-POS-macOS.dmg`
- Windows: `AIBA-POS-Windows.zip`

**Bosqich 1 tarqatish**:
1. POS backend'da yangi endpoint push → prod deploy
2. Nex frontend'da yangi modul + nav — commit → Nex'ning odatiy deploy oqimi

---

## 7. Muvaffaqiyat mezoni (Acceptance Criteria)

### Bosqich 1 tugagach:

- [ ] `next.aiba.uz` login → sidebar'da **POS Kassa** paydo bo'ladi
- [ ] Bosilsa, tab'ning ichida (iframe) POS adminka to'liq ishlaydi
- [ ] Alohida login talab qilinmaydi (Nex login SSO)
- [ ] Restoran kontekst avtomatik topiladi (Nex tenant → POS restaurant)
- [ ] Mahsulot, kategoriya, chek, ombor, sozlamalar — hammasi ishlaydi
- [ ] Flutter terminal ilovasi shu holicha ishlashi (regression yo'q)

### Bosqich 2 tugagach:

- [ ] Iframe yo'qoladi — native React modul
- [ ] URL state ishlaydi: `/pos/products?cat=xxx&page=2` yangilash ham tab'ni saqlab qoladi
- [ ] Nex sidebar/topbar/style bilan to'liq mos
- [ ] Qo'llanma 4 tilda (`uz`, `uz_Cyrl`, `ru`, `en`)
- [ ] Barcha API'lar TanStack Query orqali (cache, invalidate)

---

## 8. Xavflar va cheklovlar

1. **CORS/Iframe**: POS `admin.html` `X-Frame-Options: ALLOWALL` yoki
   `Content-Security-Policy: frame-ancestors https://next.aiba.uz`
   header bermasa, iframe'da yuklanmaydi.

2. **JWT signing**: Nex JWT'ni verify qilish uchun uni public key
   POS backend'da bo'lishi kerak. Best practice — Nex'da JWKS endpoint,
   POS undan fetch qilib cache qilsin.

3. **Tenant mapping**: Hozircha `pos_restaurants` va Nex `tenants` alohida
   ID'lar. `nex_tenant` maydonini qo'lda to'ldirish kerak (yoki avtomatik
   provisioning oqimi qurish).

4. **Multi-restaurant**: Nex tenant'da bir nechta restoran bo'lishi mumkin —
   iframe'da qaysi restoran ochilishini tanlash UI kerak (dropdown).

5. **Rust vs Python**: POS FastAPI, Nex Rust. Uzoq muddatda bir stack'ga
   birlashtirish yoki API gateway orqali abstraksiya masalasi ochiq qoladi.

---

## 9. Vaqt smetasi (bosqich bo'yicha)

| Bosqich | Muddat | Kim | Natija |
|---|---|---|---|
| **1 — Iframe** | 1-2 kun | 1 dasturchi | Nex ichida POS ishlaydi |
| **2 — Native** | 5-7 kun (parallel sprint'lar) | 1-2 dasturchi | To'la mos React modul |
| **3 — Deep** | 2-3 hafta | POS + Nex jamoasi | Ekosistema |

---

## 10. Boshlash yo'riqnomasi (Claude Code uchun)

Yangi sessiyada quyidagi buyruqni bering:

```
Menda AIBA POS loyhasi bor (~/Desktop/aiba/aiba-pos/) va uni AIBA Nex 
platformasiga (~/Desktop/aiba/nex/) modul qilib qo'shishim kerak.

To'liq TZ shu yerda: ~/Desktop/aiba/aiba-pos/POS-NEX-INTEGRATION-TZ.md

Iltimos, o'qib chiq va Bosqich 1 (Iframe modul)ni boshla.
```

Claude Code TZ'ni o'qiydi va to'g'ri path'larda kod yozadi.

---

**Hujjat versiyasi**: 1.0
**Sana**: 2026-07-25
**Muallif**: AIBA POS jamoasi (Claude Code yordamida)
