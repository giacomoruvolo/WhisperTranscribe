#!/bin/bash

APP_NAME="WhisperTranscribe"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$SCRIPT_DIR/$APP_NAME.xcodeproj"
BUILD_DIR="$SCRIPT_DIR/build"
DMG_PATH="$SCRIPT_DIR/Whisper.dmg"
STAGING="$SCRIPT_DIR/dmg_staging"

echo "╔══════════════════════════════════════════════╗"
echo "║        WhisperTranscribe — Builder           ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

if ! command -v xcodebuild &>/dev/null; then
  echo "❌ Xcode non trovato."
  exit 1
fi
echo "✓ $(xcodebuild -version | head -1)"

echo "→ Pulizia build precedente..."
rm -rf "$BUILD_DIR/Release"
rm -f "$DMG_PATH"
mkdir -p "$BUILD_DIR"

echo "→ Compilazione in corso..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR/Release" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_ENTITLEMENTS="" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=NO \
  GCC_TREAT_WARNINGS_AS_ERRORS=NO \
  build 2>&1 | tee "$BUILD_DIR/build.log" | grep -E "error:|Build FAILED|Build succeeded|Linking" | head -40

APP_PATH=$(find "$BUILD_DIR" -name "$APP_NAME.app" -type d 2>/dev/null | head -1)

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
  echo ""
  echo "❌ Build fallita. Errori:"
  grep "error:" "$BUILD_DIR/build.log" | head -20
  exit 1
fi

echo "✓ Build completata: $APP_PATH"

# Firma ad-hoc DOPO il build
echo "→ Firma ad-hoc..."
codesign --force --deep --sign - \
  --options runtime \
  "$APP_PATH" 2>&1
echo "  ✓ Firmata"

# Verifica firma
codesign --verify --deep --strict "$APP_PATH" 2>&1 && echo "  ✓ Firma valida" || echo "  ⚠ Verifica firma fallita"

echo "→ Rimozione quarantena..."
xattr -cr "$APP_PATH" 2>/dev/null || true

echo "→ Creo DMG (finestra con drag-to-Applications)..."
VOLNAME="WhisperTranscribe"
TMP_DMG="$SCRIPT_DIR/.tmp_whisper.dmg"
rm -rf "$STAGING"; rm -f "$TMP_DMG"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/WhisperTranscribe.app"

# Ri-firma anche la copia nel staging
codesign --force --deep --sign - "$STAGING/WhisperTranscribe.app" 2>/dev/null || true
xattr -cr "$STAGING/WhisperTranscribe.app" 2>/dev/null || true

# Alias verso /Applications (la freccia di destra)
ln -s /Applications "$STAGING/Applications"

# Crea un DMG SCRIVIBILE per poterne impostare il layout della finestra
hdiutil create \
  -volname "$VOLNAME" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDRW \
  "$TMP_DMG" >/dev/null 2>&1

# Monta il DMG scrivibile
MOUNT_DIR="/Volumes/$VOLNAME"
hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1 || true
hdiutil attach "$TMP_DMG" -readwrite -noverify -noautoopen >/dev/null 2>&1
sleep 2

# Imposta layout finestra: icona app a sinistra, Applicazioni a destra
osascript << APPLESCRIPTEOF
tell application "Finder"
    tell disk "$VOLNAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 800, 480}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 120
        set position of item "WhisperTranscribe.app" of container window to {150, 180}
        set position of item "Applications" of container window to {450, 180}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPTEOF
sync

# Smonta e converti in sola lettura compresso
hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1
sleep 1
rm -f "$DMG_PATH"
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null 2>&1
rm -f "$TMP_DMG"
rm -rf "$STAGING"

if [ -f "$DMG_PATH" ]; then
  SIZE=$(du -sh "$DMG_PATH" | cut -f1)
  echo ""
  echo "╔══════════════════════════════════════════════════╗"
  echo "║  ✅ Successo!  →  Whisper.dmg ($SIZE)           ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""
  open "$SCRIPT_DIR"
else
  echo "❌ Creazione DMG fallita"
  exit 1
fi
