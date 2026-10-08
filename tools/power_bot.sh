#!/bin/bash
# Strength measurement (v0.2 A-5, spec 3): the share of points the bot wins against one
# fixed opponent, by experience, gear and island. Trials run in parallel (tools/power_bot.gd).
#   tools/power_bot.sh [trials=20] [points=100] [stage=2] [bot-sd=0.07]
#   CONFIGS="1930:none:park 1930:none:paris" tools/power_bot.sh 20     # experience:gear:island
# Default matrix. Target: level 1 with nothing vs level 12 with 3 epics - at least 12 points.
G=${G:-/Applications/Godot441.app/Contents/MacOS/Godot}
N=${1:-20}; PTS=${2:-100}; STAGE=${3:-2}; SD=${4:-0.07}
JOBS=${JOBS:-10}
CONFIGS=${CONFIGS:-"0:none:park 1930:none:park 1930:epic3:park 0:epic3:park 1930:legend3:park"}
OUT=$(mktemp -d)
for c in $CONFIGS; do
  for s in $(seq 1 $N); do
    echo "$c $s"
  done
done | xargs -P $JOBS -L 1 bash -c '
  IFS=: read xp gear loc <<< "$1"
  $0 --headless --path . --fixed-fps 60 -s tools/power_bot.gd -- --autoplay --bot-sd='$SD' --points='$PTS' --p-stage='$STAGE' --p-xp=$xp --p-gear=$gear --p-loc=$loc --p-pkg=${PKG:-1} --p-seed=$2 2>&1 | grep "^POWER xp" > '$OUT'/${1//:/_}_$2.txt
' "$G"
echo "opponent: round $STAGE, $PTS points a trial, $N trials, bot-sd $SD"
for c in $CONFIGS; do
  IFS=: read xp gear loc <<< "$c"
  cat $OUT/${c//:/_}_*.txt | sed 's/.*won=\([0-9]*\) lost=\([0-9]*\)/\1 \2/' | awk -v xp=$xp -v gear=$gear -v loc=$loc '{w+=$1; l+=$2; n++; p=$1/($1+$2); s+=p; ss+=p*p} END {m=s/n; sd=sqrt(ss/n-m*m); printf "xp %5d  gear %-8s  island %-6s  points won %5.1f%%  (+-%.1f, %d trials)\n", xp, gear, loc, 100*w/(w+l), 100*sd/sqrt(n), n}'
done
rm -rf $OUT
