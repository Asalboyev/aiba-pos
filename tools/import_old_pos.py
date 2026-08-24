# -*- coding: utf-8 -*-
"""Eski POS (Access .mdb) → AIBA POS: ombor kartochkalari + tex-karta.

Foydalanish:
    python3 import_old_pos.py <restaurant_id> --mdb <fayl.mdb> --token <JWT> [--dry]
    # yoki muhit o'zgaruvchilari: POS_MDB, POS_TOKEN, POS_API

Manba jadvallar (mdb-export bilan CSV'ga chiqarилган):
  tovar   — masalliq/tovar kartochkalari (nom, birlik, narx)
  bluda   — taomlar (nomi bo'yicha pos.products bilan bog'lanadi)
  kalkul1 — tex-karta qatorlari (bluda_art → tovar_art, netto kg/dona)
  koreshok — kunlik savdo yig'indisi (savdo, karta/QR, keldi-ketdi, xato chek)
  spisanie + tipbozor — eski spisaniyelar (taom bo'yicha, sanasi bilan)

Hamma yozuv POS API orqali kiritiladi — hisob-kitob mantiqi backendда qoladi.
"""
import csv
import json
import subprocess
import sys
import urllib.error
import urllib.request

import os

MDB = os.environ.get("POS_MDB", "")
API = os.environ.get("POS_API", "http://127.0.0.1:18001/api/v2/pos")

UNITS = {
    "кг": "kg", "1кг": "kg", "кг.": "kg", "kg": "kg",
    "гр": "gr", "г": "gr", "грамм": "gr",
    "литр": "l", "л": "l", "1л": "l", "l": "l",
    "мл": "ml",
    "шт": "dona", "1шт": "dona", "шт.": "dona", "dona": "dona",
    "порц": "porsiya", "пор": "porsiya", "порция": "porsiya",
    "уп": "quti", "упак": "quti", "ящик": "quti",
}


def unit_of(raw: str) -> str:
    u = (raw or "").strip().lower().strip('"')
    return UNITS.get(u, "dona" if not u else UNITS.get(u.rstrip("."), "dona"))


def export(table: str) -> list[dict]:
    out = subprocess.run(["mdb-export", MDB, table], capture_output=True, text=True, check=True)
    return list(csv.DictReader(out.stdout.splitlines()))


def iso_date(v: str | None) -> str | None:
    """Access sanasi → ISO. `05/29/26 00:00:00` va `2026-05-29 ...` ikkisi ham."""
    t = (v or "").strip().strip('"')
    if not t:
        return None
    if t[:4].isdigit() and "-" in t[:8]:
        return t[:10]
    head = t.split(" ")[0]
    parts = head.split("/")
    if len(parts) == 3:
        m, d, y = parts
        y = int(y)
        y += 2000 if y < 70 else 1900 if y < 100 else 0
        return f"{y:04d}-{int(m):02d}-{int(d):02d}"
    return None


def num(v) -> float:
    try:
        return float(str(v).strip().strip('"') or 0)
    except ValueError:
        return 0.0


class Api:
    def __init__(self, token: str, rid: str):
        self.token, self.rid = token, rid

    def call(self, path: str, data=None, method=None):
        req = urllib.request.Request(
            f"{API}/restaurants/{self.rid}{path}",
            data=json.dumps(data).encode() if data is not None else None,
            headers={"Authorization": f"Bearer {self.token}", "Content-Type": "application/json"},
            method=method,
        )
        try:
            return json.load(urllib.request.urlopen(req))
        except urllib.error.HTTPError as e:
            raise RuntimeError(f"{e.code} {e.read().decode()[:200]}") from e


def arg(flag: str, default: str = "") -> str:
    return sys.argv[sys.argv.index(flag) + 1] if flag in sys.argv else default


def main() -> None:
    global MDB
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    rid = sys.argv[1]
    dry = "--dry" in sys.argv
    MDB = arg("--mdb", MDB)
    token = arg("--token", os.environ.get("POS_TOKEN", ""))
    if not MDB or not token:
        sys.exit("--mdb va --token (yoki POS_MDB / POS_TOKEN) kerak")
    api = Api(token, rid)

    # ── 1. Ombor kartochkalari (tovar) ────────────────────────────────────────
    tovar = [r for r in export("tovar") if (r.get("del") or "n").strip('"') != "y"]
    have = {(i.get("sku") or ""): i for i in api.call("/stock/items")["items"]}
    by_art: dict[str, str] = {}
    created = updated = 0
    for r in tovar:
        art = (r.get("tovar_art") or "").strip()
        name = (r.get("tovar_name") or "").strip().strip('"')
        if not art or not name:
            continue
        body = {
            "name": name[:200],
            "unit": unit_of(r.get("edin_izmer")),
            "sku": art,
            "avg_cost": num(r.get("zena")),
        }
        if art in have:
            if not dry:
                api.call(f"/stock/items/{have[art]['id']}", body, method="PATCH")
            by_art[art] = have[art]["id"]
            updated += 1
        else:
            if dry:
                by_art[art] = f"dry-{art}"
            else:
                by_art[art] = api.call("/stock/items", body)["id"]
            created += 1
    print(f"1. OMBOR: {created} yangi kartochka, {updated} yangilandi (jami tovar {len(tovar)})")

    # ── 2. Tex-karta (kalkul1) ────────────────────────────────────────────────
    bluda = [r for r in export("bluda") if (r.get("del") or "n").strip('"') != "y"]
    art_name = {(r.get("bluda_art") or "").strip(): (r.get("bluda_naz") or "").strip().strip('"')
                for r in bluda}
    products = {p["name"]: p["id"] for p in api.call("/products?include_inactive=false")}

    lines: dict[str, list[dict]] = {}
    skipped_item = skipped_dish = 0
    for r in export("kalkul1"):
        if (r.get("del") or "n").strip('"') == "y":
            continue
        b_art = (r.get("bluda_art") or "").strip()
        t_art = (r.get("tovar_art") or "").strip()
        qty = num(r.get("netto")) or num(r.get("brutto"))
        if qty <= 0:
            continue
        name = art_name.get(b_art)
        pid = products.get(name) if name else None
        if not pid:
            skipped_dish += 1
            continue
        item_id = by_art.get(t_art)
        if not item_id:
            skipped_item += 1
            continue
        lines.setdefault(pid, []).append({"item_id": item_id, "qty": round(qty, 4)})

    saved = 0
    for pid, ls in lines.items():
        # Bir taomда bitta masalliq bir necha marta kelsa — qo'shib yuboramiz.
        merged: dict[str, float] = {}
        for l in ls:
            merged[l["item_id"]] = merged.get(l["item_id"], 0.0) + l["qty"]
        if not dry:
            api.call(f"/recipes/{pid}",
                     {"lines": [{"item_id": k, "qty": round(v, 4)} for k, v in merged.items()]},
                     method="PUT")
        saved += 1
    print(f"2. TEX-KARTA: {saved} taomga saqlandi "
          f"(taom topilmadi: {skipped_dish} qator, masalliq topilmadi: {skipped_item} qator)")

    # ── 3. Kunlik savdo (koreshok) → «Savdo kiritish» ─────────────────────────
    # Eski POS'da bitta-bitta chek saqlanmagan — kunlik yig'indi (korешok)
    # saqlangan: savdo, karta/QR turlari, keldi-ketdi, xato cheklar.
    CARD_COLS = ("uzkard", "humo", "click", "payme", "uzum",
                 "yandexdost", "uzumdost", "woltdost")
    days = 0
    for r in export("koreshok"):
        date = iso_date(r.get("data"))
        total = num(r.get("savdo"))
        if not date or total <= 0:
            continue
        card = sum(num(r.get(c)) for c in CARD_COLS)
        card = min(card, total)
        parts = [f"{c}={int(num(r.get(c)))}" for c in CARD_COLS if num(r.get(c)) > 0]
        for extra in ("keldiketdi", "oshibkacheka", "zakup", "shtat"):
            if num(r.get(extra)) > 0:
                parts.append(f"{extra}={int(num(r.get(extra)))}")
        if not dry:
            api.call("/manual-sales", {
                "sale_date": date,
                "product_name": "Kunlik savdo (eski POS)",
                "qty": 1,
                "price": total,
                "total": total,
                "cash": total - card,
                "card": card,
                "note": "; ".join(parts) or None,
            })
        days += 1
    print(f"3. SAVDO KIRITISH: {days} kunlik savdo yozuvi (koreshok)")

    # ── 4. Spisaniye (eski, tarixiy) ──────────────────────────────────────────
    # Eski POS TAOM'ni spisaniye qilgan (masalliq emas), shuning uchun bu
    # yozuvlar jurnalga tarixiy holda tushadi — joriy ombor qoldig'iga tegmaydi.
    tip = {(r.get("tipbozor_id") or "").strip(): r for r in export("tipbozor")}
    wo = 0
    for r in export("spisanie"):
        b_art = (r.get("bluda_art") or "").strip()
        qty = num(r.get("tovar_miqdor"))
        if qty <= 0:
            continue
        t = tip.get((r.get("tipbozor_id") or "").strip(), {})
        date = iso_date(t.get("data"))
        name = art_name.get(b_art) or f"art {b_art}"
        if not dry:
            api.call("/stock/writeoff", {
                "imported": True,
                "product_id": products.get(name),
                "product_name": name[:200],
                "qty": qty,
                "total": num(r.get("tovar_summa")),
                "reason": (t.get("prim") or "").strip() or "Eski POS spisaniyesi",
                "note": "Eski POS'dan import",
                "date": date,
            })
        wo += 1
    print(f"4. SPISANIYE: {wo} tarixiy yozuv (taom bo'yicha, ombor qoldig'iga tegmaydi)")

    if not dry:
        d = api.call("/stock/items")
        print(f"   ombor: {len(d['items'])} kartochka · qiymat {d['total_value']}")
        rec = api.call("/recipes")
        withc = [x for x in rec["items"] if int(x["lines"] or 0) > 0]
        print(f"   tex-karta bor: {len(withc)} / {len(rec['items'])} taom")


if __name__ == "__main__":
    main()
