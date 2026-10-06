"""Package Khara's ladi firecracker art from asset-builder into assets/sprites/ladi/.

    ~/ml/bin/python tools/ladi_art.py

Sources (approved in asset-builder/): sprites/ladi-cracker (sprite + ash/), sprites/ladi-spark
(sputter/), sprites/ladi-pop (pop/) and textures/forest/ladi-cord.png (seamless cord strip).
Every sprite is trimmed and padded so its anchor sits at the bottom centre (cracker, ash, pop) or
the exact centre (spark) of an even-sized canvas; ladi_firecracker.gd draws them at scale 0.5.
"""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
AB = ROOT / "asset-builder"
OUT = ROOT / "assets" / "sprites" / "ladi"


def register(frames, anchor, mode):
    """Crop frames to their shared box, padded so `anchor` is the bottom/centre middle of an even canvas."""
    boxes = [f.getchannel("A").getbbox() for f in frames]
    left, top = min(b[0] for b in boxes), min(b[1] for b in boxes)
    right, bottom = max(b[2] for b in boxes), max(b[3] for b in boxes)
    ax, ay = anchor
    half_w = max(ax - left, right - ax)
    if mode == "center":
        half_h = max(ay - top, bottom - ay)
        box = (ax - half_w, ay - half_h, ax + half_w, ay + half_h)
    else:
        box = (ax - half_w, top - (ay - top) % 2, ax + half_w, ay)
    return [f.crop(box) for f in frames]


def frames_of(folder):
    return [Image.open(p).convert("RGBA") for p in sorted(folder.glob("[0-9][0-9].png"))]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    made = {}
    cracker = AB / "sprites" / "ladi-cracker"
    meta = json.loads((cracker / "meta.json").read_text())
    [image] = register([Image.open(cracker / "sprite.png").convert("RGBA")], meta["anchor"], "feet")
    made["cracker.png"] = image
    ash_meta = json.loads((cracker / "ash" / "meta.json").read_text())
    for index, image in enumerate(register(frames_of(cracker / "ash"), ash_meta["anchor"], "feet")):
        made[f"ash_{index}.png"] = image
    for name, anim, mode in (("ladi-spark", "sputter", "center"), ("ladi-pop", "pop", "feet")):
        folder = AB / "sprites" / name / anim
        anim_meta = json.loads((folder / "meta.json").read_text())
        for index, image in enumerate(register(frames_of(folder), anim_meta["anchor"], mode)):
            made[f"{name.split('-')[1]}_{index}.png"] = image
    made["cord.png"] = Image.open(AB / "textures" / "forest" / "ladi-cord.png").convert("RGBA")
    for old in OUT.glob("*.png"):
        if old.name not in made:
            old.unlink()
    for filename, image in made.items():
        image.save(OUT / filename)
        print(f"{filename}: {image.size[0]}x{image.size[1]}")


if __name__ == "__main__":
    main()
