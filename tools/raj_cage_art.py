"""Package Raj's cage art from asset-builder into assets/sprites/raj-cage/.

    ~/ml/bin/python tools/raj_cage_art.py

Sources: asset-builder/sprites/raj-cage (approved closed cage, open/01 door-open keyframe,
back/01 interior keyframe) and sprites/raj-cage-chain. The cage is split into a back layer
(dark interior, back bars, floor plate) and front layers (bars, door, dome and base, with the
floor cut out) so Raj can sit between them. All layers share one canvas whose bottom centre is
the cage anchor; raj_cage.gd draws them at scale 0.5.
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
AB = ROOT / "asset-builder" / "sprites"
OUT = ROOT / "assets" / "sprites" / "raj-cage"
ANCHOR = (232, 435)            # approved sprite anchor (base bottom centre)
BOX = (102, 127, 362, 435)     # shared crop, symmetric about the anchor
FLOOR_TOP, RIM_TOP = 377, 273  # first floor row; top of the dome rim band
BACK_STRETCH = 51              # the interior keyframe came out this many px taller


def load(path):
    return np.array(Image.open(path).convert("RGBA"))


def lum(a):
    return (a[..., 0].astype(int) * 3 + a[..., 1].astype(int) * 6 + a[..., 2].astype(int)) // 10


def floor_mask(a, x0, x1):
    """Brown floor pixels, flood-filled between the bars from two seed rows."""
    l = lum(a)
    brown = (a[..., 3] > 0) & (l >= 50) & (l < 125)
    brown[:FLOOR_TOP] = False
    brown[:, :x0] = False
    brown[:, x1:] = False
    mask = np.zeros_like(brown)
    stack = [(y, x) for y in (385, 388) for x in range(x0, x1) if brown[y, x]]
    while stack:
        y, x = stack.pop()
        if mask[y, x] or not brown[y, x]:
            continue
        mask[y, x] = True
        stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    return mask


def cut_back_edge(a, mask):
    """Also drop the floor's dark back outline where it stands against empty space."""
    dark = (a[..., 3] > 0) & (lum(a) < 50)
    for x in np.where(mask.any(axis=0))[0]:
        top = np.argmax(mask[:, x])
        y = top - 1
        while y > top - 7 and dark[y, x]:
            y -= 1
        if a[y, x, 3] == 0:
            mask[y + 1:top, x] = True
    return mask


def save(a, name):
    Image.fromarray(a).crop(BOX).save(OUT / name)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    closed = load(AB / "raj-cage" / "sprite.png")
    opened = load(AB / "raj-cage" / "open" / "01.png")
    back_src = load(AB / "raj-cage" / "back" / "01.png")

    mask = cut_back_edge(closed, floor_mask(closed, 170, 292))
    front = closed.copy()
    front[mask] = 0
    save(front, "front_closed.png")

    # Open cage: same floor outline; left of the doorway the door panel hangs in front of
    # it (flood between its bars), from the doorway rightwards only bar columns survive.
    columns = np.where(mask.any(axis=0))[0]
    bottoms = np.array([np.max(np.where(mask[:, x])[0]) for x in columns])
    front = opened.copy()
    door = floor_mask(opened, 170, 208)
    front[door] = 0
    for x in range(208, 293):
        if opened[370, x, 3] == 0:
            front[373:int(np.interp(x, columns, bottoms)) + 1, x] = 0
    save(front, "front_open.png")

    # Back layer: the interior keyframe, with the extra bar rows taken out of the middle so
    # its rim band and floor line up with the approved cage.
    back = np.zeros_like(closed)
    split = 330
    back[RIM_TOP:split] = back_src[RIM_TOP - BACK_STRETCH:split - BACK_STRETCH]
    back[split:] = back_src[split:]
    save(back, "back.png")

    chain = AB / "raj-cage-chain" / "sprite.png"
    if chain.exists():
        save_chain(Image.open(chain).convert("RGBA"))


def save_chain(image):
    """Crop a whole number of link periods so the strip tiles vertically."""
    left, top, right, bottom = image.getchannel("A").getbbox()
    a = np.array(image.crop((left, top + 8, right, bottom - 8))).astype(int)
    height = a.shape[0]
    best, period = None, None
    for candidate in range(8, height // 2):
        error = np.abs(a[candidate:] - a[:-candidate]).mean()
        if best is None or error < best * 0.9:
            best, period = error, candidate
    repeats = max(1, (height - period) // period)
    strip = a[:period * repeats].astype(np.uint8)
    if strip.shape[1] % 2:
        strip = np.pad(strip, ((0, 0), (0, 1), (0, 0)))
    Image.fromarray(strip).save(OUT / "chain.png")
    print(f"chain: period {period}px x{repeats}, seam error {best:.1f}")


if __name__ == "__main__":
    main()
