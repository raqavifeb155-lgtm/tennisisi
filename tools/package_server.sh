#!/usr/bin/env bash
# Packs the web build into a ready-to-upload server kit: dist/tennis-hostkey.zip
#   tennis/web/            the game (+ .gz copies of the big files, served by nginx gzip_static)
#   tennis/install.sh      first install (nginx + HTTPS) or update, decides by itself
#   tennis/nginx-tennis.conf
#   tennis/README-HOSTKEY.md   step-by-step instructions (Russian)
# Run tools/build_web.sh first.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/dist"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

[ -f "$ROOT/build/web/index.html" ] || { echo "No build/web: run tools/build_web.sh first" >&2; exit 1; }
mkdir -p "$STAGE/tennis/web" "$OUT"
cp -r "$ROOT/build/web/." "$STAGE/tennis/web/"
for f in "$STAGE"/tennis/web/*.{wasm,pck,js}; do
	[ -f "$f" ] && gzip -9 -k -n "$f"
done
cp "$ROOT/deploy/deploy.sh" "$STAGE/tennis/install.sh"
cp "$ROOT/deploy/nginx-tennis.conf" "$STAGE/tennis/"
cp "$ROOT/deploy/README-HOSTKEY.md" "$STAGE/tennis/"
chmod +x "$STAGE/tennis/install.sh"
rm -f "$OUT/tennis-hostkey.zip"
(cd "$STAGE" && zip -qr "$OUT/tennis-hostkey.zip" tennis)
echo "Built: $OUT/tennis-hostkey.zip ($(du -h "$OUT/tennis-hostkey.zip" | cut -f1))"
