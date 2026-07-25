# =====================================================================
# AIBA POS — Windows build skripti
# =====================================================================
# Ishlatilishi (Windows PowerShell'da):
#   Set-ExecutionPolicy -Scope Process Bypass -Force
#   .\build-windows.ps1
#
# Nimalar bo'ladi:
#   1. Flutter yo'q bo'lsa — yuklab olinadi (~700 MB, faqat bir marta)
#   2. Loyiha repo'dan klon qilinadi
#   3. Windows desktop uchun release build
#   4. Barcha kerakli fayllar ZIP'ga jamlanadi: AIBA-POS-Windows.zip
#
# Chiqish: skript ishlagan papkada `AIBA-POS-Windows.zip` — shu ZIP'ni
# Telegram'ga tashlaysiz. Hodim yechib, `aiba_pos_terminal.exe` bosadi.
# =====================================================================

$ErrorActionPreference = 'Stop'
$WorkDir = "$env:USERPROFILE\aiba-build"
$FlutterDir = "$WorkDir\flutter"
$RepoDir = "$WorkDir\pos"
$RepoUrl = "https://gitlab.aiba.uz/milli-grill/pos.git"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  AIBA POS — Windows build" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# --- 1) Git tekshirish ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[XATO] Git o'rnatilmagan!" -ForegroundColor Red
    Write-Host "  Yuklab oling: https://git-scm.com/download/win"
    exit 1
}

# --- 2) Ishchi papka ---
if (-not (Test-Path $WorkDir)) {
    New-Item -ItemType Directory -Path $WorkDir | Out-Null
}
Set-Location $WorkDir

# --- 3) Flutter (yo'q bo'lsa yuklab olamiz) ---
if (-not (Test-Path "$FlutterDir\bin\flutter.bat")) {
    Write-Host "[1/4] Flutter yuklanmoqda (~700 MB)..." -ForegroundColor Yellow
    $flutterZip = "$WorkDir\flutter.zip"
    Invoke-WebRequest -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.35.5-stable.zip" -OutFile $flutterZip
    Expand-Archive -Path $flutterZip -DestinationPath $WorkDir -Force
    Remove-Item $flutterZip
    Write-Host "    Flutter tayyor." -ForegroundColor Green
} else {
    Write-Host "[1/4] Flutter mavjud." -ForegroundColor Green
}
$env:PATH = "$FlutterDir\bin;$env:PATH"

# --- 4) Repo klon/pull ---
if (-not (Test-Path $RepoDir)) {
    Write-Host "[2/4] Repo klonlanmoqda..." -ForegroundColor Yellow
    git clone $RepoUrl $RepoDir
} else {
    Write-Host "[2/4] Repo yangilanmoqda (git pull)..." -ForegroundColor Yellow
    Set-Location $RepoDir
    git pull
}

# --- 5) Build ---
Write-Host "[3/4] Windows desktop build (5-10 daqiqa)..." -ForegroundColor Yellow
Set-Location "$RepoDir\pos-terminal"
flutter config --enable-windows-desktop | Out-Null
flutter pub get
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "[XATO] Build muvaffaqiyatsiz!" -ForegroundColor Red
    exit 1
}

# --- 6) ZIP yasash ---
Write-Host "[4/4] ZIP yasalmoqda..." -ForegroundColor Yellow
$releaseDir = "$RepoDir\pos-terminal\build\windows\x64\runner\Release"
$outputZip = "$env:USERPROFILE\Desktop\AIBA-POS-Windows.zip"
if (Test-Path $outputZip) { Remove-Item $outputZip }
Compress-Archive -Path "$releaseDir\*" -DestinationPath $outputZip

$size = [math]::Round((Get-Item $outputZip).Length / 1MB, 1)
Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "  TAYYOR!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host "  Fayl: $outputZip"
Write-Host "  Hajmi: $size MB"
Write-Host ""
Write-Host "  Endi shu ZIP'ni Telegram'ga tashlang."
Write-Host "  Hodim yechib, 'aiba_pos_terminal.exe' bosadi."
Write-Host "==================================================" -ForegroundColor Green
