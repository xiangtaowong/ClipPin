#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/dist"
OUTPUT_BIN="$OUTPUT_DIR/ClipPin"
RELEASE_BIN="$ROOT_DIR/.build/release/ClipPin"

cd "$ROOT_DIR"

echo "Building release binary..."
swift build -c release

mkdir -p "$OUTPUT_DIR"
cp "$RELEASE_BIN" "$OUTPUT_BIN"

echo "Stripping symbols..."
strip -x "$OUTPUT_BIN"

echo ""
echo "Optimized binary: $OUTPUT_BIN"
stat -f "Size: %z bytes" "$OUTPUT_BIN"
