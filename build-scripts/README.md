# AIBA POS — build va tarqatish

## 📦 Hodimlarga qanday jo'natiladi

### 🍎 macOS (`.dmg`)

**Build**: Mac'da terminal'dan:
```bash
cd pos-terminal
flutter build macos --release
```
Keyin `build-scripts/build-macos.sh` skripti bilan DMG yasaladi.

**Hodim ishlatishi**:
1. Telegram'dan `AIBA-POS-macOS.dmg`ni yuklab olsin
2. DMG'ni **double-click** qilib ochsin
3. Ilova ikonkasini `Applications`ga **tortib qo'ysin**
4. Launchpad'dan **AIBA POS** ni ochsin
5. Birinchi marta: "Ochib bo'lmaydi" chiqishi mumkin →
   **System Settings → Privacy & Security → Open Anyway**

### 🪟 Windows (`.zip`)

**Build**: bitta Windows kompyuter kerak. PowerShell'da:
```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\build-windows.ps1
```
Bu skript o'zi Flutter yuklab oladi, klonlaydi, build qiladi va `Desktop`ga
`AIBA-POS-Windows.zip` yasab qo'yadi.

**Hodim ishlatishi**:
1. Telegram'dan `AIBA-POS-Windows.zip`ni yuklab olsin
2. ZIP ustiga **o'ng tugma → Extract All** (yechib olsin)
3. Papkani **`C:\AIBA-POS`** yoki `Program Files`ga ko'chirsin
4. Ichida **`aiba_pos_terminal.exe`** — shortcut yaratib Desktop'ga chiqarsin
5. Birinchi ishga tushirganda Windows Defender ogohlantirish berishi mumkin:
   **"More info" → "Run anyway"**

### 🤖 Android APK

GitLab pipeline'dan avto yaratiladi (Pipelines → build-android → ▶️).
Telegram'ga tashlab yuboriladi, hodim `.apk`ni telefonda ochib install qiladi
(avval **Settings → Security → Install unknown apps** ruxsat berish kerak).

---

## 🔌 Birinchi ishga tushirish (barcha platformalar)

Ilova ochilganda **Serverning IP/URL manzilini so'raydi**. Misol:
```
https://pos.milli-grill.uz
```
Yoki lokal server bo'lsa:
```
http://192.168.1.100:8006
```

Keyin **login**:
- **Terminal kodi**: T1
- **Xodim kodi**: 101
- **PIN**: 0000
