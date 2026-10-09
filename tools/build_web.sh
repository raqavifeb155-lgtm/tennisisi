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
"$GODOT" --headless --path . --fixed-fps 60 -s tests/input_test.gd | grep -E "INPUT TEST|labels|outcomes"
"$GODOT" --headless --path . -s tests/audio_test.gd | grep -E "FAIL|AUDIO TEST"
if [ "${1:-}" = "--autoplay" ]; then
	"$GODOT" --headless --path . --fixed-fps 60 -- --autoplay --points=40 | tail -8
fi
mkdir -p build/web
rm -f build/web/index.*.pck
"$GODOT" --headless --path . --export-release "Web" build/web/index.html

# Music and location sounds are left out of the game pack (export_presets.cfg,
# exclude_filter) and downloaded by the game after the start (Sfx.is_lazy).
rm -rf build/web/sfx && mkdir -p build/web/sfx
cp assets/sfx/amb_*.ogg assets/sfx/music_*.ogg assets/sfx/birds.ogg build/web/sfx/

# The club's model pack (stream H) is left out of the game pack too (export_presets.cfg) and
# served as models/club_props.<version>.glb: the version is in the file's name, so a browser
# may keep it for good (ClubPack downloads it after the start; until then the club shows
# simple forms made in code).
rm -rf build/web/models && mkdir -p build/web/models
PACK_V=$(grep -o 'VERSION := "[0-9a-f]*"' scripts/club/world/club_pack_info.gd | grep -o '[0-9a-f]\{10\}')
cp assets/club/models/club_props.glb "build/web/models/club_props.$PACK_V.glb"
# The academy's house pack (HousePack) goes the same way: models/academy_props.<version>.glb.
HOUSE_V=$(grep -o 'VERSION := "[0-9a-f]*"' scripts/academy/house/house_pack_info.gd | grep -o '[0-9a-f]\{10\}')
cp assets/academy/models/academy_props.glb "build/web/models/academy_props.$HOUSE_V.glb"

# The game pack carries its content in its name: a browser may keep it for good, and a
# new build is a new name, so a cached old pack can never come back after an update.
H=$(sha256sum build/web/index.pck | cut -c1-10)
mv build/web/index.pck "build/web/index.$H.pck"
sed -i "s/\"index.pck\":/\"index.$H.pck\":/; s/\"executable\":\"index\",/\"executable\":\"index\",\"mainPack\":\"index.$H.pck\",/" build/web/index.html
grep -q "\"mainPack\":\"index.$H.pck\"" build/web/index.html || { echo "index.html: mainPack not set" >&2; exit 1; }
echo "Built: build/web (pack index.$H.pck, $(ls build/web/sfx | wc -l) sounds in sfx/, club models $PACK_V)"
