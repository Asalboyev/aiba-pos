#!/usr/bin/env bash
# =====================================================================
# AIBA POS — macOS build + DMG paket
# =====================================================================
# Ishlatilishi: macOS terminal'da loyiha ildizidan
#   ./build-scripts/build-macos.sh
#
# Chiqish: ~/Desktop/AIBA-POS-macOS.dmg
# =====================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
APP_DIR="$REPO_DIR/pos-terminal/build/macos/Build/Products/Release"
OUT_DMG="$HOME/Desktop/AIBA-POS-macOS.dmg"

echo "=================================================="
echo "  AIBA POS — macOS build"
echo "=================================================="

# Flutter tekshirish
if ! command -v flutter >/dev/null 2>&1; then
    echo "[XATO] Flutter o'rnatilmagan. https://flutter.dev/docs/get-started/install/macos"
    exit 1
fi

echo "[1/3] Flutter build (5-10 daqiqa)..."
cd "$REPO_DIR/pos-terminal"
flutter config --enable-macos-desktop >/dev/null
flutter pub get
flutter build macos --release

echo "[2/3] .app tayyor: $APP_DIR/aiba_pos_terminal.app"

echo "[3/3] DMG yasalyapti..."
TMP_DIR="$(mktemp -d)"
cp -R "$APP_DIR/aiba_pos_terminal.app" "$TMP_DIR/"
ln -s /Applications "$TMP_DIR/Applications"
rm -f "$OUT_DMG"
hdiutil create -volname "AIBA POS" -srcfolder "$TMP_DIR" -ov -format UDZO "$OUT_DMG" >/dev/null
rm -rf "$TMP_DIR"

SIZE=$(du -h "$OUT_DMG" | cut -f1)
echo ""
echo "=================================================="
echo "  TAYYOR!"
echo "=================================================="
echo "  Fayl:  $OUT_DMG"
echo "  Hajmi: $SIZE"
echo ""
echo "  Endi shu DMG'ni Telegram'ga tashlang."
echo "  Hodim double-click qilib, ilovani /Applications'ga tortadi."
echo "=================================================="
