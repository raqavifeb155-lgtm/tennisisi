#!/usr/bin/env python3
"""Cuts racket hits out of a match recording into assets/sfx/hit_real_<n>.wav.

    # the audio track only (the owner allowed the sound, nothing else):
    yt-dlp -f bestaudio -x --audio-format wav -o match.%(ext)s https://www.youtube.com/watch?v=WyojGU0VlQ0
    python tools/cut_hits.py match.wav            # writes the takes into assets/sfx
    python tools/cut_hits.py match.wav --out DIR  # or somewhere else, to listen first

Where the takes come from: the video's hour is one 79.4 s clip repeated (the correlation of
two repeats is 0.99), so the unique material is the first 80 s; the clicks below are the
cleanest strokes in it. Each stroke in that recording is a click of ~10 ms followed by a
room reflection ~40..90 ms later and the player's grunt and breath. So a take is only
the click and its body: it starts 4 ms before the peak and ends 6 ms before the
reflection (40..110 ms in all), with a 2 ms fade in and a cosine fade out, lows under
250 Hz cut (crowd hum). The level is matched to the first three takes (Pixabay): the same
peak (-1 dB) and the same energy in a 105 ms window, through a soft limiter.

Needs ffmpeg in PATH and numpy.
"""
import argparse
import os
import subprocess
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")
PEAK_DB = -1.0        # as hit_real_1..3
TARGET_RMS_DB = -19.0  # energy in 105 ms from the peak (hit_real_1..3: -19.9, -18.0, -18.0)

# (name, time of the click in the video (s), group). Groups: sfx.gd plays "power" for
# serves and flat shots, "spin" for topspin, "soft" for slices, drops and lobs.
TAKES = [
	("hit_real_4", 29.2994, "power"),
	("hit_real_5", 34.1779, "power"),
	("hit_real_6", 36.9367, "power"),
	("hit_real_7", 84.1427, "power"),
	("hit_real_8", 61.4266, "spin"),
	("hit_real_9", 62.9745, "spin"),
	("hit_real_10", 69.4815, "spin"),
	("hit_real_11", 40.0811, "spin"),
	("hit_real_12", 67.1287, "soft"),
	("hit_real_13", 88.9326, "soft"),
]


def ms(v: float) -> int:
	return int(round(v * RATE / 1000.0))


def decode(path: str) -> np.ndarray:
	raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
		check=True, capture_output=True).stdout
	return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def biquad_hp(x: np.ndarray, fc: float, q: float) -> np.ndarray:
	w = 2.0 * np.pi * fc / RATE
	al = np.sin(w) / (2.0 * q)
	c = np.cos(w)
	b0, b1, b2 = (1 + c) / 2, -(1 + c), (1 + c) / 2
	a0, a1, a2 = 1 + al, -2 * c, 1 - al
	b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
	y = np.zeros_like(x)
	x1 = x2 = y1 = y2 = 0.0
	for i in range(len(x)):
		v = b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2, x1, y2, y1 = x1, x[i], y1, v
		y[i] = v
	return y


def highpass(x: np.ndarray, fc: float, order: int) -> np.ndarray:
	qs = {2: [0.7071], 4: [0.5412, 1.3066]}[order]  # Butterworth
	for q in qs:
		x = biquad_hp(x, fc, q)
	return x


def rms_db(x: np.ndarray) -> float:
	return 10 * np.log10(float(np.mean(x ** 2)) + 1e-12)


def cut(src: np.ndarray, t: float):
	"""One take: (samples, length in ms, where the reflection was or None)."""
	p0 = int(t * RATE)
	lo = p0 - ms(1.5)
	p = lo + int(np.argmax(np.abs(src[lo:p0 + ms(1.5)])))
	ctx = src[p - ms(200):p + ms(300)]
	c = ms(200)
	# the reflection: the next peak of the highs (> 1.5 kHz) at 40 % of the click's, 20..130 ms on
	hi = np.abs(highpass(ctx[c - ms(30):c + ms(140)], 1500.0, 4))
	click = hi[ms(30) - ms(2):ms(30) + ms(2)].max()
	win = hi[ms(30) + ms(20):ms(30) + ms(130)]
	refl = None
	for i in range(ms(3), len(win) - ms(3)):
		if win[i] >= 0.4 * click and win[i] == win[i - ms(3):i + ms(3) + 1].max():
			refl = 20.0 + i * 1000.0 / RATE
			break
	end = 110.0 if refl is None else min(110.0, max(40.0, refl - 6.0))
	seg = highpass(ctx, 250.0, 2)[c - ms(4):c + ms(end)].copy()
	n = len(seg)
	fi = ms(2)
	seg[:fi] *= np.sin(np.linspace(0, np.pi / 2, fi)) ** 2
	fo = ms(min(40.0, end * 0.5))
	seg[n - fo:] *= np.cos(np.linspace(0, np.pi / 2, fo)) ** 2
	return seg, n * 1000.0 / RATE, refl


def soft_limit(y: np.ndarray, knee: float = 0.5) -> np.ndarray:
	a = np.abs(y)
	over = a > knee
	out = a.copy()
	out[over] = knee + (1 - knee) * np.tanh((a[over] - knee) / (1 - knee))
	return np.sign(y) * out


def level(seg: np.ndarray) -> np.ndarray:
	"""Peak at PEAK_DB, energy in 105 ms at TARGET_RMS_DB (soft-limited; gain capped at +6 dB)."""
	peak = 10 ** (PEAK_DB / 20)
	pk = int(np.abs(seg).argmax())

	def window(y: np.ndarray) -> np.ndarray:
		w = np.zeros(ms(105))
		part = y[max(0, pk - ms(5)):pk + ms(100)]
		w[:len(part)] = part
		return w

	best = seg / np.abs(seg).max() * peak
	lo, hi = 0.0, 6.0
	for _ in range(30):  # the gain (dB) that lands on the target after limiting
		mid = (lo + hi) / 2
		y = soft_limit(seg / np.abs(seg).max() * 10 ** (mid / 20))
		y = y / np.abs(y).max() * peak
		if rms_db(window(y)) < TARGET_RMS_DB:
			lo = mid
		else:
			hi = mid
		best = y
	return best


def write_wav(path: str, y: np.ndarray) -> None:
	with wave.open(path, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(RATE)
		w.writeframes((np.clip(y, -1, 1) * 32767).astype(np.int16).tobytes())


def centroid(y: np.ndarray) -> float:
	pk = int(np.abs(y).argmax())
	w = y[max(0, pk - ms(3)):pk + ms(50)]
	sp = np.abs(np.fft.rfft(w * np.hanning(len(w))))
	f = np.fft.rfftfreq(len(w), 1.0 / RATE)
	return float((sp * f).sum() / sp.sum())


def main() -> None:
	ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	ap.add_argument("src", help="the match audio (any format ffmpeg reads)")
	ap.add_argument("--out", default=OUT, help="where to write (default assets/sfx)")
	a = ap.parse_args()
	os.makedirs(a.out, exist_ok=True)
	src = decode(a.src)
	for name, t, group in TAKES:
		seg, length, refl = cut(src, t)
		y = level(seg)
		write_wav(os.path.join(a.out, name + ".wav"), y)
		pk = int(np.abs(y).argmax())
		w = np.zeros(ms(105))
		part = y[max(0, pk - ms(5)):pk + ms(100)]
		w[:len(part)] = part
		print("%s  %-5s t=%.4f  %3.0f ms  reflection %s  peak %.1f dB  rms105 %.1f dB  centroid %.0f Hz"
			% (name, group, t, length, "-" if refl is None else "%.0f ms" % refl,
			20 * np.log10(np.abs(y).max()), rms_db(w), centroid(y)))


if __name__ == "__main__":
	main()
