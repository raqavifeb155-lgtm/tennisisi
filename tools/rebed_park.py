#!/usr/bin/env python3
"""Rebuilds the park / club bed (assets/sfx/amb_park.ogg, 10.10.2026) without the helicopter.

    python tools/rebed_park.py

The old bed ("City Traffic (Outdoor)", Pixabay 6414) carried a helicopter for 25 of its 36 s;
tools/dechop_bed.py levelled its wobble but the owner still heard the drone (a flattened rotor
buzz, tonal lines that move with the pitch), in the club and on the New York map, which both play
this bed. A bed that long cannot lose the seconds, so the park now has a bed of its own made of
one that never had a helicopter: the London city (amb_grass.ogg, 60 s, broadband traffic, no
tonal drone). The loop is rotated by 27 s (its join is seamless, so it stays seamless in the
middle) and the highs above 7 kHz are taken down a little: this is the city across the river,
not the street. Same loudness as the source. Needs ffmpeg and numpy.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prep_audio as pa  # noqa: E402

SHIFT_S = 27.0
LOWPASS = 7000


def main() -> None:
	src = os.path.join(pa.OUT, "amb_grass.ogg")
	x = pa.decode(src, 0.0, 0.0, 1, lowpass=LOWPASS)
	lufs = pa.loudness(pa.decode(src, 0.0, 0.0, 1))
	y = np.roll(x, -int(SHIFT_S * pa.RATE), axis=0)
	y -= y.mean()
	y *= 10 ** ((lufs - pa.loudness(y)) / 20.0)
	peak = float(np.abs(y).max())
	if peak > 0.97:
		y *= 0.97 / peak
	dst = pa.encode(y, "amb_park", 3.0)
	print("%s: %.1f s, %.1f LUFS, %d KB" % (os.path.basename(dst), len(y) / pa.RATE, pa.loudness(y), os.path.getsize(dst) // 1024))


if __name__ == "__main__":
	main()
