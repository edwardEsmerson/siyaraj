#!/usr/bin/env python3
"""Rebuild Siyaraj's original synthesized effects using only Python's stdlib."""
import math
from pathlib import Path
import random
import struct
import wave

RATE = 22050
ROOT = Path(__file__).resolve().parent.parent / "assets" / "Audio" / "sfx"
# name: duration, start/end Hz, noise amount, decay exponent
EFFECTS = {
    "jump": (0.12, 380, 900, 0.02, 1.5),
    "dash": (0.20, 240, 90, 0.75, 2.0),
    "lash": (0.14, 850, 160, 0.60, 2.0),
    "skyshot": (0.28, 700, 150, 0.65, 1.8),
    "charge": (0.60, 240, 1100, 0.04, 0.7),
    "spin": (0.40, 1000, 300, 0.30, 1.5),
    "hit": (0.13, 180, 55, 0.55, 3.0),
    "pop": (0.24, 280, 60, 0.50, 2.5),
    "tell": (0.35, 180, 480, 0.08, 0.8),
    "slam": (0.40, 110, 35, 0.65, 3.0),
    "curtain": (0.55, 160, 80, 0.85, 1.5),
    "ui": (0.065, 880, 1046, 0.0, 2.0),
}


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    for name, (duration, start, end, noise, decay) in EFFECTS.items():
        rng = random.Random(name)
        phase = 0.0
        filtered_noise = 0.0
        samples = []
        count = round(duration * RATE)
        for index in range(count):
            progress = index / (count - 1)
            phase += 2 * math.pi * (start + (end - start) * progress) / RATE
            filtered_noise = 0.55 * filtered_noise + 0.45 * rng.uniform(-1, 1)
            tone = math.sin(phase) * 0.8 + math.sin(phase * 2) * 0.2
            envelope = min(1.0, index / (RATE * 0.006)) * (1 - progress) ** decay
            flutter = 0.7 + 0.3 * math.sin(index / RATE * 2 * math.pi * 25) if name == "spin" else 1.0
            sample = 0.65 * envelope * flutter * ((1 - noise) * tone + noise * filtered_noise)
            samples.append(struct.pack("<h", round(sample * 32767)))
        with wave.open(str(ROOT / (name + ".wav")), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(RATE)
            output.writeframes(b"".join(samples))
    print(f"Generated {len(EFFECTS)} original effects in {ROOT}")


if __name__ == "__main__":
    main()
