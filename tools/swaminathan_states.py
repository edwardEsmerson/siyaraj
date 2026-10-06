"""Derive Swaminathan's eleven head-state sprites from the approved ten-headed state 10.

~/ml/bin/python tools/swaminathan_states.py

Reads asset-builder/sprites/swaminathan-full/sprite.png and writes
  asset-builder/sprites/swaminathan-full/states/state_10.png .. state_00.png  (tool canvas)
  assets/sprites/swaminathan-states/state_10.png .. state_00.png              (game export)
and prints the HEAD_OFFSETS for scripts/bosses/ravan/ravan_body.gd.

Heads are severed right to left, so state n keeps heads 0..n-1. Each head is segmented with a
watershed seeded on its face, crown and the upper part of its neck; the neck is cut at a fixed point
(CUT_DIST below its gold ring) and the stump gets a flesh-coloured cap. Nothing is regenerated, so the
body, pose and remaining heads are pixel-identical in every state. The hand-measured constants below
belong to the approved state 10; re-measure them if that sprite ever changes.
"""
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "asset-builder/sprites/swaminathan-full"
GAME = ROOT / "assets/sprites/swaminathan-states"

# Crown jewel of each head, left to right (art px in sprite.png). The face centre is 28 px below.
JEWELS = [(186.3, 311.3), (230.1, 291.0), (271.5, 274.8), (309.4, 264.7), (348.3, 258.3),
          (392.3, 254.4), (439.2, 264.0), (480.4, 276.6), (524.3, 292.7), (570.5, 311.3)]
FACE_DROP = 28
# Where each neck heads from its ring toward the body, and how far below the ring it is cut.
AXIS_END = [(250, 392), (277, 378), (293, 375), (323, 375), (350, 382), (377, 382), (407, 378), (433, 375),
            (470, 382), (500, 392)]
CUT_DIST = [34, 32, 30, 28, 28, 28, 28, 30, 32, 34]
# Game export: feet midway between the two feet, at the bottom centre of a 464 x 384 canvas.
FEET = (376, 615)
EXPORT = (FEET[0] - 232, FEET[1] - 384, FEET[0] + 232, FEET[1])

OUTLINE = (46, 4, 56)
FLESH, FLESH_HI, FLESH_LO = (172, 20, 98), (250, 57, 135), (115, 11, 75)


def faces():
    return [(int(round(x + 1)), int(round(y + FACE_DROP))) for x, y in JEWELS]


def rings(a):
    """Centre of the gold ring at the base of each head."""
    r, g, b, al = [a[..., i].astype(int) for i in range(4)]
    gold = (al > 0) & (r > 170) & (g > 90) & (b < 140) & (r - b > 100)
    out = []
    for x, y in JEWELS:
        x, y = int(x), int(y)
        window = np.zeros_like(gold)
        window[y + 38:y + 72, x - 28:x + 22] = gold[y + 38:y + 72, x - 28:x + 22]
        n, _, stats, centres = cv2.connectedComponentsWithStats(window.astype(np.uint8), connectivity=8)
        out.append(np.array(centres[1 + int(np.argmax(stats[1:, 4]))], float))
    return out


def cuts(ring):
    out = []
    for k in range(10):
        u = np.array(AXIS_END[k], float) - ring[k]
        u /= np.linalg.norm(u)
        out.append((ring[k] + u * CUT_DIST[k], u))
    return out


def segment(a, ring, cut):
    """Label map: 1..10 for each head (face, crown, upper neck), 20 for the body and background."""
    h, w = a.shape[:2]
    opaque = a[..., 3] > 0
    barrier = np.zeros((h, w), np.uint8)
    for c, u in cut:
        n = np.array([-u[1], u[0]])
        p, q = (c + n * 14).round().astype(int), (c - n * 14).round().astype(int)
        cv2.line(barrier, (int(p[0]), int(p[1])), (int(q[0]), int(q[1])), 1, 2)
    _, comp = cv2.connectedComponents((opaque & (barrier == 0)).astype(np.uint8), connectivity=4)
    upper = np.isin(comp, list({int(comp[y, x]) for x, y in faces()}))
    markers = np.full((h, w), 20, np.int32)
    markers[upper] = 0
    for k, (x, y) in enumerate(faces()):
        jx, jy = int(round(JEWELS[k][0])), int(round(JEWELS[k][1]))
        cv2.circle(markers, (x, y), 5, k + 1, -1)
        cv2.line(markers, (jx, jy - 12), (jx, y), k + 1, 3)
        cv2.line(markers, (jx - 9, jy + 2), (jx + 9, jy + 2), k + 1, 2)
        c, u = cut[k]
        e = (c - u * 3).round().astype(int)
        r = ring[k].round().astype(int)
        cv2.line(markers, (int(r[0]), int(r[1])), (int(e[0]), int(e[1])), k + 1, 2)
    markers[~upper] = 20
    grey = np.full((h, w, 3), 150, np.uint8)
    grey[opaque] = a[opaque][:, :3]
    raw = cv2.watershed(np.ascontiguousarray(grey[..., ::-1]), markers)
    labels = raw.copy()
    for y, x in zip(*np.nonzero(raw == -1)):
        near = [v for v in raw[max(y - 1, 0):y + 2, max(x - 1, 0):x + 2].ravel() if 1 <= v <= 10]
        labels[y, x] = max(set(near), key=near.count) if near and upper[y, x] else 20
    labels[~upper] = 20
    # Crown finials and other specks that only touch a head diagonally go to the nearest head.
    n, comp, stats, _ = cv2.connectedComponentsWithStats(opaque.astype(np.uint8), connectivity=4)
    heads = (labels >= 1) & (labels <= 10)
    for i in range(1, n):
        speck = comp == i
        if stats[i, 4] >= 200 or (heads & speck).any():
            continue
        ys, xs = np.nonzero(speck)
        best = min((np.min((hy[:, None] - ys) ** 2 + (hx[:, None] - xs) ** 2), k)
                   for k in range(1, 11) for hy, hx in [np.nonzero(labels == k)])
        if best[0] <= 25:
            labels[speck] = best[1]
    return labels


def neck_span(a, c, u):
    n = np.array([-u[1], u[0]])
    inside = [s for s in np.arange(-14, 14.5, 0.5) if a[tuple((c + n * s + u * 1.5).round().astype(int)[::-1])][3] > 0]
    return (min(inside), max(inside)) if inside else (-6.0, 6.0)


def cap(out, a, c, u):
    """A flesh-coloured ellipse across the cut end of a neck, outlined like the rest of the sprite."""
    n = np.array([-u[1], u[0]])
    lo, hi = neck_span(a, c, u)
    mid = c + n * (lo + hi) / 2 + u
    rw, rh = (hi - lo) / 2 + 0.3, 3.2
    for y in range(int(mid[1]) - 16, int(mid[1]) + 17):
        for x in range(int(mid[0]) - 16, int(mid[0]) + 17):
            p = np.array([x, y], float) - mid
            if (p @ n / rw) ** 2 + (p @ u / rh) ** 2 > 1.0:
                continue
            inner = (p @ n / (rw - 1.6)) ** 2 + (p @ u / (rh - 1.3)) ** 2 if rw > 2 else 9
            shine = ((p @ n + rw * 0.25) / (rw * 0.35)) ** 2 + (p @ u + 0.5) ** 2
            colour = OUTLINE if inner > 1 else FLESH_HI if shine <= 1 else FLESH_LO if p @ u > 0.6 else FLESH
            out[y, x] = (*colour, 255)


def state(a, labels, ring, cut, count):
    out = a.copy()
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    keep = (labels >= 1) & (labels <= count)
    for k in range(count, 10):
        out[labels == k + 1] = 0
        # Clear whatever is left of the neck above the cut (edge pixels the watershed gave the body).
        c, u = cut[k]
        n = np.array([-u[1], u[0]])
        lo, hi = neck_span(a, c, u)
        along = (xx - c[0]) * u[0] + (yy - c[1]) * u[1]
        across = (xx - c[0]) * n[0] + (yy - c[1]) * n[1]
        reach = np.linalg.norm(ring[k] - c) + 6
        out[(along < -0.5) & (along > -reach) & (across > lo - 4) & (across < hi + 4) & ~keep] = 0
    for k in range(count, 10):
        cap(out, a, *cut[k])
    # Drop crumbs the removed heads left behind: keep only the figure itself.
    _, comp, stats, _ = cv2.connectedComponentsWithStats((out[..., 3] > 0).astype(np.uint8), connectivity=8)
    main = 1 + int(np.argmax(stats[1:, 4]))
    out[(comp != main) & (comp != 0)] = 0
    return out


def main():
    a = np.array(Image.open(SOURCE / "sprite.png").convert("RGBA"))
    ring = rings(a)
    cut = cuts(ring)
    labels = segment(a, ring, cut)
    (SOURCE / "states").mkdir(exist_ok=True)
    GAME.mkdir(parents=True, exist_ok=True)
    for count in range(11):
        image = Image.fromarray(state(a, labels, ring, cut, count))
        image.save(SOURCE / f"states/state_{count:02d}.png")
        image.crop(EXPORT).save(GAME / f"state_{count:02d}.png")
    offsets = ", ".join(f"Vector2({(x - FEET[0]) / 2:g}, {(y - FEET[1]) / 2:g})" for x, y in faces())
    print(f"canvas {EXPORT[2] - EXPORT[0]}x{EXPORT[3] - EXPORT[1]}, feet at bottom centre")
    print(f"HEAD_OFFSETS = [{offsets}]")


if __name__ == "__main__":
    main()
