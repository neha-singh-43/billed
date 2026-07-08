#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Prefer a universal (Apple Silicon + Intel) binary so the .app runs on any Mac.
# Multi-arch builds need full Xcode (xcbuild); fall back to a native-arch build
# when only the Command Line Tools are installed.
UNIVERSAL_FLAGS=(-c release --product Billed --arch arm64 --arch x86_64)
NATIVE_FLAGS=(-c release --product Billed)

if swift build "${UNIVERSAL_FLAGS[@]}" 2>/dev/null; then
    BUILD_FLAGS=("${UNIVERSAL_FLAGS[@]}")
    echo "Built universal binary (arm64 + x86_64)."
else
    echo "Universal build unavailable (needs full Xcode); building for this Mac's"
    echo "architecture only. Install Xcode to produce an Intel-compatible build."
    swift build "${NATIVE_FLAGS[@]}"
    BUILD_FLAGS=("${NATIVE_FLAGS[@]}")
fi

BIN_DIR="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)"
BIN="$BIN_DIR/Billed"
APP="$ROOT/.build/Billed.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"

rm -rf "$APP"
mkdir -p "$MACOS" "$RES"
cp "$BIN" "$MACOS/Billed"
cp scripts/Info.plist "$CONTENTS/Info.plist"

# Ad-hoc sign so the bundle has a stable identity. This is NOT notarization:
# users still need to clear the quarantine flag on first launch (see README).
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "Built $APP"
echo "Run: open $APP"
