#!/usr/bin/env python3
"""Generates the placeholder sound effects procedurally (no third-party assets).

    python3 tools/gen_sfx.py
"""
import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
random.seed(7)


def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s / peak * 0.9)) * 32767)) for s in samples)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


def lowpass(x, a):
    y, out = 0.0, []
    for s in x:
        y += a * (s - y)
        out.append(y)
    return out


def highpass(x, a):
    lp = lowpass(x, a)
    return [s - l for s, l in zip(x, lp)]


def noise(n):
    return [random.uniform(-1, 1) for _ in range(n)]


def env(n, attack, decay):
    out = []
    for i in range(n):
        t = i / RATE
        a = min(1.0, t / attack) if attack > 0 else 1.0
        out.append(a * math.exp(-t / decay))
    return out


def tone(n, f, decay, phase=0.0):
    return [math.sin(2 * math.pi * f * i / RATE + phase) * math.exp(-(i / RATE) / decay) for i in range(n)]


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] if i < len(t) else 0.0 for t in tracks) for i in range(n)]


def scale(x, k):
    return [s * k for s in x]


def racket_hit(n_sec, body_f, crack):
    n = int(RATE * n_sec)
    e = env(n, 0.0005, 0.018)
    click = [a * b for a, b in zip(highpass(noise(n), 0.25), e)]
    body = tone(n, body_f, 0.035)
    ring = tone(n, body_f * 2.7, 0.02)
    strings = tone(n, 1650, 0.012)
    return mix(scale(click, crack), scale(body, 0.9), scale(ring, 0.25), scale(strings, 0.2))


def main():
    os.makedirs(OUT, exist_ok=True)
    write("hit.wav", racket_hit(0.16, 430, 0.8))
    # Perfect: lower, fuller body + a short sub thump
    n = int(RATE * 0.22)
    thump = [math.sin(2 * math.pi * (110 - 40 * i / n) * i / RATE) * math.exp(-(i / RATE) / 0.05) for i in range(n)]
    write("hit_perfect.wav", mix(racket_hit(0.22, 380, 1.1), scale(thump, 0.8)))

    n = int(RATE * 0.12)
    e = env(n, 0.001, 0.02)
    write("bounce.wav", mix(scale(tone(n, 190, 0.03), 1.0), scale(tone(n, 340, 0.018), 0.4),
                            [a * b * 0.5 for a, b in zip(lowpass(noise(n), 0.2), e)]))

    n = int(RATE * 0.3)
    e = env(n, 0.005, 0.08)
    write("net.wav", [a * b for a, b in zip(lowpass(noise(n), 0.08), e)])

    n = int(RATE * 0.22)
    whoosh_env = [math.sin(math.pi * i / n) ** 2 for i in range(n)]
    band = highpass(lowpass(noise(n), 0.12), 0.02)
    write("swing.wav", [a * b for a, b in zip(band, whoosh_env)])

    n = int(RATE * 0.5)
    write("point.wav", mix(tone(n, 660, 0.15), [0.0] * int(RATE * 0.09) + tone(n, 990, 0.2)))
    n = int(RATE * 0.4)
    write("miss.wav", mix(tone(n, 220, 0.12), [0.0] * int(RATE * 0.08) + tone(n, 165, 0.15)))


if __name__ == "__main__":
    main()
