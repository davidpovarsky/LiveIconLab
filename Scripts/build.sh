#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
PAYLOAD="$BUILD/Payload"
APP="$PAYLOAD/LiveIconLab.app"
IPA="$BUILD/LiveIconLab-unsigned.ipa"
HOOK="$BUILD/LiveIconHook.dylib"

rm -rf "$BUILD"
mkdir -p "$APP"

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
CLANG="$(xcrun --sdk iphoneos --find clang)"
CLANGXX="$(xcrun --sdk iphoneos --find clang++)"

TARGET="arm64-apple-ios17.0"

echo "SDK: $SDK"
echo "Target: $TARGET"

"$CLANG" \
  -fobjc-arc \
  -target "$TARGET" \
  -isysroot "$SDK" \
  -framework Foundation \
  -framework UIKit \
  "$ROOT/App/main.m" \
  -o "$APP/LiveIconLab"

cp "$ROOT/App/Info.plist" "$APP/Info.plist"

python3 "$ROOT/Scripts/generate_icons.py" "$APP"

for icon in \
  Icon-20@2x.png \
  Icon-29@2x.png \
  Icon-40@2x.png \
  Icon-76.png \
  Icon-76@2x.png \
  Icon-83.5@2x.png \
  Icon-1024.png
do
  test -s "$APP/$icon"
done

alternate_count="$(find "$APP" -maxdepth 1 -type f -name 'ClockFrame*.png' | wc -l | tr -d ' ')"
if [ "$alternate_count" != "72" ]; then
  echo "Expected 72 alternate icon PNGs, found $alternate_count" >&2
  exit 1
fi

plutil -lint "$APP/Info.plist"
plutil -extract 'CFBundleIcons~ipad.CFBundleAlternateIcons' xml1 -o - "$APP/Info.plist" >/dev/null
plutil -convert binary1 "$APP/Info.plist"

"$CLANGXX" \
  -fobjc-arc \
  -target "$TARGET" \
  -isysroot "$SDK" \
  -dynamiclib \
  -framework Foundation \
  "$ROOT/SpringBoard/LiveIconHook.mm" \
  -Wl,-install_name,@rpath/LiveIconHook.dylib \
  -o "$HOOK"

(
  cd "$BUILD"
  /usr/bin/zip -qry "$(basename "$IPA")" Payload
)

{
  echo "LiveIconLab build"
  echo "Bundle ID: com.goldcreative.liveiconlab"
  echo "Runtime target: iPadOS 27"
  echo "Mach-O target: $TARGET"
  echo "SDK: $SDK"
  echo
  echo "App binary:"
  file "$APP/LiveIconLab"
  echo
  echo "Primary icons:"
  ls -lh "$APP"/Icon*.png
  echo
  echo "Alternate clock frames:"
  echo "$alternate_count PNG files across 12 alternate icons"
  echo
  echo "Hook binary:"
  file "$HOOK"
  echo
  echo "IPA:"
  ls -lh "$IPA"
} | tee "$BUILD/build-manifest.txt"

echo
echo "Built:"
echo "  $IPA"
echo "  $HOOK"
