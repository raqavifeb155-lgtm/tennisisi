#!/usr/bin/env python3
"""Takes the helicopter out of a bed (assets/sfx/amb_park.ogg, 09.10.2026).

    python tools/dechop_bed.py amb_park                 # rewrites assets/sfx/amb_park.ogg
    python tools/dechop_bed.py amb_park --check         # only measures, writes nothing

The park's bed ("City Traffic (Outdoor)", Pixabay 6414) carries a helicopter for 25 of its
36 seconds: its blades beat at 13..17 Hz (an 8..30 Hz wobble of the 100..450 Hz band, 15 %
deep, against 2 % in the clean seconds) and its drone sits 6..8 dB above the clean part in
that band. A bed that long cannot lose the seconds, so the sound is repaired instead:
  1. every band (40..200..400..700..1400 Hz, the bands add up to the input exactly) is
     levelled: its fast envelope (45 Hz) is divided out and its slow one (1.5 s) put back,
     which flattens the wobble and leaves the traffic's slow swells;
  2. the drone is pulled down (up to 6 dB) in 100..450 Hz wherever that band rises above
     the level of the quietest stretch, smoothly (0.4 Hz).
The work is done on three copies in a row and the middle one kept, so the loop stays seamless.
The loudness is kept (-20 LUFS: whatever the bed had). Needs ffmpeg, numpy and scipy; written
with ffmpeg's libvorbis, or with python-soundfile when ffmpeg has no Vorbis encoder (Homebrew's).
"""
import argparse
import os
import sys

import numpy as np
from scipy.signal import butter, hilbert, sosfiltfilt

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prep_audio as pa  # noqa: E402

RATE = pa.RATE


def lowpass(x: np.ndarray, fc: float, order: int = 2) -> np.ndarray:
	return sosfiltfilt(butter(order, fc, "low", fs=RATE, output="sos"), x)


def dechop(x: np.ndarray, max_cut_db: float = 6.0) -> np.ndarray:
	n = len(x)
	t = np.concatenate([x, x, x])
	edges = [40, 200, 400, 700, 1400]
	lps = [lowpass(t, f, 4) for f in edges]
	y = t - lps[-1]  # above 1.4 kHz untouched
	for i, lp in enumerate(lps):
		band = lp if i == 0 else lp - lps[i - 1]
		a = np.abs(hilbert(band))
		gain = lowpass(a, 1.5) / np.maximum(lowpass(a, 45.0), 1e-6)
		y += band * np.clip(gain, 0.35, 2.5)
	drone = sosfiltfilt(butter(4, [100, 450], "band", fs=RATE, output="sos"), y)
	db = 10 * np.log10(np.maximum(lowpass(drone ** 2, 0.4), 1e-12))
	ref = np.percentile(db[n:2 * n], 5) + 1.0  # the clean stretch
	cut = np.clip((db - ref) * 0.9, 0.0, max_cut_db)
	y = y - drone * (1.0 - 10 ** (-cut / 20))
	return y[n:2 * n]


def wobble(x: np.ndarray, lo: float, hi: float) -> float:
	"""Depth of the 8..45 Hz wobble of a band's envelope, worst 2 s window of the bed."""
	band = sosfiltfilt(butter(4, [lo, hi], "band", fs=RATE, output="sos"), x)
	env = lowpass(np.abs(hilbert(band)), 60.0)[::RATE // 200]
	best = 0.0
	for s in range(0, len(env) - 400, 100):
		e = env[s:s + 400]
		sp = np.abs(np.fft.rfft((e - e.mean()) * np.hanning(400))) / 400 * 2 / e.mean()
		f = np.fft.rfftfreq(400, 1 / 200)
		best = max(best, float(sp[(f >= 8) & (f <= 45)].max()))
	return best


def main() -> None:
	ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	ap.add_argument("name", help="bed in assets/sfx, without .ogg")
	ap.add_argument("--check", action="store_true", help="measure only")
	a = ap.parse_args()
	src = os.path.join(pa.OUT, a.name + ".ogg")
	x = pa.decode(src, 0.0, 0.0, 1)[:, 0].astype(np.float64)
	before = [wobble(x, lo, hi) for lo, hi in [(100, 200), (200, 400), (400, 800)]]
	lufs = pa.loudness(x[:, None].astype(np.float32))
	y = dechop(x)
	y -= y.mean()
	y *= 10 ** ((lufs - pa.loudness(y[:, None].astype(np.float32))) / 20.0)
	peak = float(np.abs(y).max())
	if peak > 0.97:
		y *= 0.97 / peak
	after = [wobble(y, lo, hi) for lo, hi in [(100, 200), (200, 400), (400, 800)]]
	print("wobble depth in 100-200 / 200-400 / 400-800 Hz: before %s, after %s"
		% (" ".join("%.2f" % v for v in before), " ".join("%.2f" % v for v in after)))
	if not a.check:
		try:
			dst = pa.encode(y[:, None].astype(np.float32), a.name, 3.0)
		except Exception:  # no libvorbis in this ffmpeg
			import soundfile as sf
			dst = os.path.join(pa.OUT, a.name + ".ogg")
			with sf.SoundFile(dst, "w", RATE, 1, format="OGG", subtype="VORBIS", compression_level=0.5) as f:
				f.write(y.astype(np.float32))
		print("%s: %.1f s, %.1f LUFS, %d KB" % (os.path.basename(dst), len(y) / RATE, pa.loudness(y[:, None].astype(np.float32)), os.path.getsize(dst) // 1024))


if __name__ == "__main__":
	main()
