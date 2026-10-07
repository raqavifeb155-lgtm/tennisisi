#!/usr/bin/env python3
"""Turns a raw sound (any format ffmpeg reads) into a game-ready OGG in assets/sfx/.

    # a seamless background loop: 60 s cut from 0:20, its tail crossfaded into its head
    python tools/prep_audio.py loop  sea.mp3  amb_clay  --start 20 --length 60
    # two layers in one loop (no extra memory): city + light rain 6 dB under it
    python tools/prep_audio.py loop  city.mp3 amb_grass --start 45 --mix rain.mp3:14:-6
    # a one-shot (a bell, a horn): trimmed, faded out at the end
    python tools/prep_audio.py shot  bell.mp3 amb_grass_bell --length 14

Why it matters on the web: the export plays sounds as Web Audio samples, so the
browser keeps every sound fully decoded in memory (48 kHz float32). A 4-minute stereo
file is ~90 MB on a phone; a 60 s mono loop is ~11 MB. Loops are therefore short and
mono (width comes from positioned one-shots), and everything is levelled to one
loudness so the volumes in scripts/sfx.gd mean the same thing for every location.

Needs ffmpeg in PATH and numpy.
"""
import argparse
import os
import re
import subprocess
import sys
import tempfile

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")
TARGET_LUFS = {"loop": -23.0, "shot": -20.0}


def decode(path: str, start: float, length: float, channels: int, lowpass: float = 0.0, highpass: float = 0.0) -> np.ndarray:
	cmd = ["ffmpeg", "-v", "error", "-ss", str(start), "-i", path]
	if length > 0:
		cmd += ["-t", str(length)]
	filters = []
	if lowpass > 0:  # far away: the air and the buildings take the highs
		filters.append("lowpass=f=%d,lowpass=f=%d" % (lowpass, lowpass))
	if highpass > 0:
		filters.append("highpass=f=%d,highpass=f=%d" % (highpass, highpass))
	if filters:
		cmd += ["-af", ",".join(filters)]
	cmd += ["-ac", str(channels), "-ar", str(RATE), "-f", "f32le", "-"]
	raw = subprocess.run(cmd, check=True, capture_output=True).stdout
	return np.frombuffer(raw, dtype=np.float32).reshape(-1, channels).copy()


def loudness(x: np.ndarray) -> float:
	"""Integrated loudness (EBU R128) measured by ffmpeg."""
	with tempfile.NamedTemporaryFile(suffix=".f32", delete=False) as f:
		f.write(x.astype(np.float32).tobytes())
		tmp = f.name
	try:
		r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-f", "f32le", "-ar", str(RATE),
			"-ac", str(x.shape[1]), "-i", tmp, "-af", "ebur128", "-f", "null", "-"],
			capture_output=True, text=True)
	finally:
		os.remove(tmp)
	m = re.findall(r"I:\s+(-?[\d.]+) LUFS", r.stderr)
	return float(m[-1]) if m else -70.0


def seamless(x: np.ndarray, length_s: float, fade_s: float) -> np.ndarray:
	"""A loop of length_s: the audio just after the loop point is crossfaded into the
	start, so the last sample flows into the first exactly as the source did."""
	n = int(length_s * RATE)
	f = int(fade_s * RATE)
	if len(x) < n + f:
		sys.exit("source too short: need %.1f s from --start, have %.1f s" % ((n + f) / RATE, len(x) / RATE))
	out = x[:n].copy()
	t = np.linspace(0.0, 1.0, f, dtype=np.float32)[:, None]
	# equal-power: ambience is uncorrelated noise, a linear fade would dip in the middle
	out[:f] = x[:f] * np.sin(t * np.pi / 2) + x[n:n + f] * np.cos(t * np.pi / 2)
	return out


def compress(x: np.ndarray) -> np.ndarray:
	"""A gentle compressor through ffmpeg: peaks down, the bed's body stays."""
	r = subprocess.run(["ffmpeg", "-v", "error", "-f", "f32le", "-ar", str(RATE), "-ac", str(x.shape[1]), "-i", "-",
		"-af", "acompressor=threshold=0.05:ratio=3:attack=10:release=250:makeup=1", "-f", "f32le", "-"],
		input=x.astype(np.float32).tobytes(), capture_output=True, check=True)
	return np.frombuffer(r.stdout, dtype=np.float32).reshape(-1, x.shape[1]).copy()[: len(x)]


def encode(x: np.ndarray, name: str, quality: float) -> str:
	os.makedirs(OUT, exist_ok=True)
	dst = os.path.join(OUT, name + ".ogg")
	subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", str(x.shape[1]),
		"-i", "-", "-c:a", "libvorbis", "-q:a", str(quality), dst],
		input=x.astype(np.float32).tobytes(), check=True)
	return dst


def main() -> None:
	ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	ap.add_argument("kind", choices=["loop", "shot"])
	ap.add_argument("src")
	ap.add_argument("name", help="file name in assets/sfx without .ogg, e.g. amb_clay")
	ap.add_argument("--start", type=float, default=0.0, help="seconds to skip in the source")
	ap.add_argument("--length", type=float, default=60.0, help="loop length / max one-shot length (s)")
	ap.add_argument("--fade", type=float, default=3.0, help="loop crossfade or one-shot fade-out (s)")
	ap.add_argument("--stereo", action="store_true", help="keep two channels (twice the memory)")
	ap.add_argument("--lufs", type=float, help="target loudness (default -23 loops, -20 one-shots)")
	ap.add_argument("--quality", type=float, default=3.0, help="vorbis quality, 3 is ~110 kbps stereo")
	ap.add_argument("--mix", action="append", default=[], metavar="FILE:START:DB",
		help="layer another source under this one (loops only), e.g. rain.mp3:14:-6")
	ap.add_argument("--lowpass", type=float, default=0.0, help="cut highs above this (Hz) so a close recording sounds distant")
	ap.add_argument("--compress", action="store_true", help="even out peaks (car passes, rain drops) so the bed can sit louder")
	ap.add_argument("--highpass", type=float, default=0.0, help="cut lows under this (Hz): phone speakers cannot play them, they only eat loudness")
	a = ap.parse_args()

	ch = 2 if a.stereo else 1
	if a.kind == "loop":
		need = a.length + a.fade + 0.5
		src = decode(a.src, a.start, need, ch, a.lowpass, a.highpass)
		for m in a.mix:
			path, start, db = m.rsplit(":", 2)
			layer = decode(path, float(start), need, ch, a.lowpass, a.highpass)
			n = min(len(src), len(layer))
			src = src[:n] + layer[:n] * (10 ** (float(db) / 20.0))
		x = seamless(src, a.length, a.fade)
	else:
		x = decode(a.src, a.start, a.length, ch, a.lowpass)
		f = min(int(a.fade * RATE), len(x))
		x[len(x) - f:] *= np.linspace(1.0, 0.0, f, dtype=np.float32)[:, None]
	if a.compress:
		x = compress(x)
	x -= x.mean(axis=0)  # no DC offset: it clicks when the sound starts and stops
	target = a.lufs if a.lufs is not None else TARGET_LUFS[a.kind]
	gain = 10 ** ((target - loudness(x)) / 20.0)
	x *= gain
	peak = float(np.abs(x).max())
	if peak > 0.97:  # quiet ambience is dynamic; never let the gain clip a peak
		x *= 0.97 / peak
	dst = encode(x, a.name, a.quality)
	dur = len(x) / RATE
	mem = dur * 48000 * 4 * ch / 1e6
	print("%s: %.1f s, %d ch, %.1f LUFS, file %d KB, in browser memory ~%.1f MB"
		% (os.path.basename(dst), dur, ch, loudness(x), os.path.getsize(dst) // 1024, mem))


if __name__ == "__main__":
	main()
