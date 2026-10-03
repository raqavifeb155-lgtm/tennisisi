#!/usr/bin/env bash
# Builds the web version into build/web (served by Vercel as a static site).
# Downloads Godot + web export templates on first run.
#
#   tools/build_web.sh            # tests + export
#   tools/build_web.sh --autoplay # also runs the 40-point bot simulation
set -euo pipefail

GODOT_VERSION="4.4.1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="${GODOT_CACHE:-$HOME/.cache/godot-build}"
GODOT="$CACHE/Godot_v${GODOT_VERSION}-stable_linux.x86_64"
TEMPLATES="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
BASE_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"

mkdir -p "$CACHE"
if [ ! -x "$GODOT" ]; then
	curl -sSL -o "$CACHE/godot.zip" "$BASE_URL/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
	unzip -oq "$CACHE/godot.zip" -d "$CACHE"
fi
if [ ! -f "$TEMPLATES/web_nothreads_release.zip" ]; then
	curl -sSL -o "$CACHE/templates.tpz" "$BASE_URL/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
	mkdir -p "$TEMPLATES"
	unzip -oj "$CACHE/templates.tpz" "templates/web_*" "templates/version.txt" -d "$TEMPLATES" >/dev/null
fi

cd "$ROOT"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . -s tests/run_tests.gd
if [ "${1:-}" = "--autoplay" ]; then
	"$GODOT" --headless --path . --fixed-fps 60 -- --autoplay --points=40 | tail -8
fi
mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html
echo "Built: build/web"
