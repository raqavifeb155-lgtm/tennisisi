#!/usr/bin/env python3
"""Draws the start-up logo, assets/brand/splash.png (Godot's boot splash and the
loading screen use it):  python tools/make_splash.py

A tennis ball and TENNISISI in gold on a transparent background; the background
colour comes from project.godot (application/boot_splash/bg_color), the same dark as
the loading screen, so the splash, the loader and the menu flow into each other.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "brand", "splash.png")
S = 3                      # drawn 3x, scaled down: smooth edges
W, H = 900, 420
GOLD = (255, 217, 64, 255)
BALL = (214, 240, 77, 255)
SEAM = (250, 252, 240, 255)
SUB = (255, 255, 255, 150)
FONT = "C:/Windows/Fonts/bahnschrift.ttf"


def font(size: int, weight: str) -> ImageFont.FreeTypeFont:
	f = ImageFont.truetype(FONT, size * S)
	try:
		f.set_variation_by_name(weight)
	except Exception:
		pass
	return f


def main() -> None:
	img = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	# The ball: a disc with the two curved seams of a tennis ball.
	cx, cy, r = W * S // 2, 120 * S, 70 * S
	d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=BALL)
	seams = Image.new("RGBA", img.size, (0, 0, 0, 0))
	sd = ImageDraw.Draw(seams)
	for side in (-1, 1):
		pts = []
		for i in range(41):
			t = -1.0 + 2.0 * i / 40
			y = cy + t * r * 0.92
			x = cx + side * (r * 1.02 - math.sqrt(max(0.0, 1.0 - t * t)) * r * 0.55)
			pts.append((x, y))
		sd.line(pts, fill=SEAM, width=7 * S, joint="curve")
	mask = Image.new("L", img.size, 0)
	ImageDraw.Draw(mask).ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
	img.paste(seams, (0, 0), Image.composite(seams.getchannel("A"), Image.new("L", img.size, 0), mask))
	title = font(118, "Bold")
	text = "TENNISISI"
	tw = d.textlength(text, font=title)
	d.text(((W * S - tw) / 2, 212 * S), text, font=title, fill=GOLD)
	sub = font(34, "SemiLight")
	t2 = "теннис-рогалик"
	sw = d.textlength(t2, font=sub)
	d.text(((W * S - sw) / 2, 352 * S), t2, font=sub, fill=SUB)
	os.makedirs(os.path.dirname(OUT), exist_ok=True)
	img.resize((W, H), Image.LANCZOS).save(OUT)
	print("saved", os.path.normpath(OUT))


if __name__ == "__main__":
	main()
