"""Package Swaminathan's attack effect art and register his collar for the head row.

~/ml/bin/python tools/swaminathan_effects.py            # effects -> assets/sprites/swaminathan/effects/
~/ml/bin/python tools/swaminathan_effects.py --collars  # also record collar points in cast_manifest.json

Effects: each approved asset-builder/sprites/swami-<name>/ (sprite.png plus its kept animation
frames) is registered on its anchor, cropped to the union of its frames and written as
assets/sprites/swaminathan/effects/<name>/NN.png. effects_frames.tres gathers them as one
SpriteFrames (one animation per effect) with each pivot, in art px, in its `pivots` metadata.
scripts/bosses/ravan/ravan_fx.gd loads it; everything is placed at scale 0.5.

Collars: for every kept body animation frame of asset-builder/sprites/swaminathan, the top
centre of the gold collar (where the necks leave the torso) is measured and stored, relative
to the feet anchor in art px, as attachment.collar_from_anchor_px in the cast manifest; `ab cast
export` copies it to assets/sprites/swaminathan/cast_meta.json for ravan_body.gd.
"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "asset-builder/sprites"
GAME = ROOT / "assets/sprites/swaminathan/effects"
MANIFEST = ROOT / "asset-builder/cast_manifest.json"

# name: (pivot, fps, loop, kept animation folder or None)
#   pivot: center = sprite centre, feet = bottom centre (on the floor), left = left end, centre line
EFFECTS = {
    "fire-splash": ("feet", 10, False, "splash"),
    "homing-orb": ("center", 10, True, "flicker"),
    "spread-shot": ("center", 10, True, "flicker"),
    "roar-ring": ("center", 10, False, "expand"),
    "shockwave": ("feet", 10, True, "roll"),
    "lightning-bolt": ("feet", 16, True, "crackle"),
    "lightning-flash": ("feet", 12, False, "flash"),
    "lightning-mark": ("feet", 8, True, "crackle"),
    "fury-pillar": ("feet", 10, True, "burn"),
    "fury-stripe": ("feet", 8, True, "smoulder"),
    "charge-halo": ("center", 8, True, "spin"),
    "safe-lane": ("feet", 4, True, None),
    "mouth-flash": ("center", 14, False, "fade"),
    "neck": ("left", 1, False, None),
    "neck-stump": ("left", 1, False, None),
}
# One-shot effects start on their kept frames; the approved base is their last frame.
BASE_LAST = {"fire-splash", "roar-ring", "lightning-flash", "mouth-flash"}
# Until an effect has kept animation frames, it flickers between exact pixel variants of its base.
VARIANTS = {
    "fire-splash": ["mirror"], "homing-orb": ["flip"], "spread-shot": ["flip"], "roar-ring": ["rot90", "rot180"],
    "lightning-bolt": ["mirror"], "lightning-flash": ["mirror"], "lightning-mark": ["mirror"],
}
# Stray pixels a generation added below the effect (rows at or below this are cleared).
CLEAR_BELOW = {"homing-orb": 45, "lightning-mark": 134}
# Seamless strips (asset-builder/textures/swaminathan/<file>.png) built into long beams.
STREAMS = {"fire-breath": ("fire-stream", 700, 6, 10)}


def frames_of(name, anim):
    src = SPRITES / f"swami-{name}"
    meta = json.loads((src / "meta.json").read_text())
    base = Image.open(src / "sprite.png").convert("RGBA")
    if name in CLEAR_BELOW:
        base.paste((0, 0, 0, 0), (0, CLEAR_BELOW[name], base.width, base.height))
    frames = [(base, meta["anchor"])]
    folder = src / anim if anim else None
    if folder and (folder / "meta.json").exists():
        kept = json.loads((folder / "meta.json").read_text())
        for path in sorted(folder.glob("[0-9][0-9].png")):
            frames.append((Image.open(path).convert("RGBA"), kept["anchor"]))
    elif name in VARIANTS:
        # Variants turn about the art's own centre so they stay registered.
        box = base.getbbox()
        for kind in VARIANTS[name]:
            art = base.crop(box)
            art = {"mirror": Image.Transpose.FLIP_LEFT_RIGHT, "flip": Image.Transpose.FLIP_TOP_BOTTOM,
                   "rot90": Image.Transpose.ROTATE_90, "rot180": Image.Transpose.ROTATE_180}[kind]
            turned = base.crop(box).transpose(art)
            layer = Image.new("RGBA", base.size)
            layer.paste(turned, (box[0] + (box[2] - box[0] - turned.width) // 2, box[1] + (box[3] - box[1] - turned.height) // 2))
            frames.append((layer, meta["anchor"]))
    if name in BASE_LAST and len(frames) > 1:
        frames = frames[1:] + frames[:1]
    return frames


def package(name, pivot_mode, frames):
    # Common canvas around the shared anchor, then crop to the union of the art.
    left = max(a[0] for _, a in frames)
    top = max(a[1] for _, a in frames)
    right = max(im.width - a[0] for im, a in frames)
    bottom = max(im.height - a[1] for im, a in frames)
    canvas = (left + right, top + bottom)
    placed = []
    for im, a in frames:
        layer = Image.new("RGBA", canvas)
        layer.paste(im, (left - a[0], top - a[1]))
        placed.append(layer)
    box = None
    for layer in placed:
        b = layer.getbbox()
        if b:
            box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    box = (box[0] - 1, box[1] - 1, box[2] + 1, box[3] + 1)
    anchor = (left - box[0], top - box[1])
    width, height = box[2] - box[0], box[3] - box[1]
    if pivot_mode == "left":
        pivot = (0, height // 2 if name.startswith("neck") else anchor[1])
    elif pivot_mode == "feet":
        pivot = (anchor[0], height - 1)
    else:
        pivot = anchor
    out = GAME / name
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("[0-9][0-9].png"):
        old.unlink()
    for n, layer in enumerate(placed, 1):
        layer.crop(box).save(out / f"{n:02}.png")
    return {"pivot": pivot, "count": len(placed), "size": (width, height)}


def stream(name, source, length, count):
    """A long beam from a horizontally seamless strip: scrolled per frame, tapered to a point at
    the mouth (left) and to a rounded tongue at the far end, with the outline closed again."""
    tile = Image.open(ROOT / "asset-builder/textures/swaminathan" / f"{source}.png").convert("RGBA")
    box = tile.getbbox()
    a = np.array(tile.crop((0, box[1], tile.width, box[3])))
    height, width = a.shape[:2]
    dark = a[a[..., 3] > 0][np.argmin(a[a[..., 3] > 0][:, :3].sum(axis=1))]
    x = np.arange(length)
    half = np.minimum(1.0, 0.12 + 0.88 * x / 110.0) * height / 2
    tip = np.clip((x - (length - 80)) / 80.0, 0, 1)
    half = half * np.sqrt(1 - tip ** 2)
    y = np.abs(np.arange(height)[:, None] - (height - 1) / 2)
    out = GAME / name
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("[0-9][0-9].png"):
        old.unlink()
    for n in range(count):
        frame = a[:, (x - round(width * n / count)) % width].copy()
        frame[y > half[None, :]] = 0
        solid = frame[..., 3] > 0
        pad = np.pad(solid, 1)
        edge = solid & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
        frame[edge] = dark
        Image.fromarray(frame).save(out / f"{n + 1:02}.png")
    return {"pivot": (0, height // 2), "count": count, "size": (length, height)}


def write_frames(packed):
    textures, anims = [], []
    for name, info in packed.items():
        ids = []
        for n in range(1, info["count"] + 1):
            id_ = f"{name}_{n:02}"
            textures.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/swaminathan/effects/{name}/{n:02}.png" id="{id_}"]')
            ids.append(id_)
        frames = ", ".join('{"duration": 1.0, "texture": ExtResource("%s")}' % i for i in ids)
        anims.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %.1f}' % (frames, str(info["loop"]).lower(), name, info["fps"]))
    pivots = ", ".join('"%s": Vector2(%d, %d)' % (n, *i["pivot"]) for n, i in packed.items())
    text = [f'[gd_resource type="SpriteFrames" load_steps={len(textures) + 1} format=3]', "", *textures, "",
            "[resource]", "animations = [" + ",\n".join(anims) + "]", "metadata/pivots = {" + pivots + "}", ""]
    (GAME / "effects_frames.tres").write_text("\n".join(text))


def collar(image):
    """Top centre of the gold collar: the upper of the two largest gold parts (collar, belt)."""
    a = np.array(image).astype(int)
    r, g, b, al = (a[..., i] for i in range(4))
    gold = (al > 0) & (r > 170) & (g > 90) & (b < 140) & (r - b > 100)
    n, _, stats, centres = cv2.connectedComponentsWithStats(gold.astype(np.uint8), connectivity=8)
    parts = [k for k in sorted(range(1, n), key=lambda k: -stats[k, 4])[:2] if stats[k, 4] > 60]
    k = min(parts, key=lambda k: stats[k, 1])
    return float(centres[k][0]), float(stats[k, 1])


def record_collars():
    body = SPRITES / "swaminathan"
    collars = {}
    for folder in sorted(p for p in body.iterdir() if (p / "meta.json").exists()):
        anchor = json.loads((folder / "meta.json").read_text())["anchor"]
        points = []
        for path in sorted(folder.glob("[0-9][0-9].png")):
            x, y = collar(Image.open(path).convert("RGBA"))
            points.append([round(x - anchor[0], 1), round(y - anchor[1] + 6, 1)])
        collars[folder.name] = points
    # Re-read right before writing: other tools share the manifest.
    manifest = json.loads(MANIFEST.read_text())
    manifest["subjects"]["swaminathan"]["attachment"]["collar_from_anchor_px"] = collars
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n")
    for anim, points in collars.items():
        print(f"collar {anim}: {points}")


def main():
    packed = {}
    for name, (pivot_mode, fps, loop, anim) in EFFECTS.items():
        if not (SPRITES / f"swami-{name}" / "sprite.png").exists():
            print(f"missing swami-{name}")
            continue
        info = package(name, pivot_mode, frames_of(name, anim))
        info.update(fps=fps, loop=loop)
        packed[name] = info
        print(f"{name}: {info['count']} frames {info['size']} pivot {info['pivot']}")
    for name, (source, length, count, fps) in STREAMS.items():
        if (ROOT / "asset-builder/textures/swaminathan" / f"{source}.png").exists():
            info = stream(name, source, length, count)
            info.update(fps=fps, loop=True)
            packed[name] = info
            print(f"{name}: {info['count']} frames {info['size']} pivot {info['pivot']}")
    write_frames(packed)
    if "--collars" in sys.argv:
        record_collars()


if __name__ == "__main__":
    main()
