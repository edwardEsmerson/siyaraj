"""Background removal, Pixel Snapper cleanup, canvas placement and preview sheets."""
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
HOLE = (255, 0, 255)  # placeholder colour for transparent pixels while snapping


def remove_background(image, tol=40, step=6, single=False):
    """Cut out whatever flat-ish background the model actually drew.

    The model often ignores the requested key (muted green, grey, white, a fake
    checkerboard, a soft gradient), so we measure the real border colours instead
    of trusting the prompt. `single` keeps only the dominant border colour, for
    layers whose art runs off the edges (else the art itself counts as background).
    Returns (RGBA image, report).
    """
    rgb = np.ascontiguousarray(np.array(image.convert("RGB")))
    h, w = rgb.shape[:2]
    ring = np.concatenate([rgb[:4].reshape(-1, 3), rgb[-4:].reshape(-1, 3),
                           rgb[:, :4].reshape(-1, 3), rgb[:, -4:].reshape(-1, 3)]).astype(int)

    # Dominant border colours (two for a checkerboard, one otherwise).
    _, inverse, counts = np.unique(ring // 32, axis=0, return_inverse=True, return_counts=True)
    inverse = inverse.ravel()
    seeds, covered = [], 0
    for cluster in np.argsort(-counts)[:4]:
        seeds.append(ring[inverse == cluster].mean(0))
        covered += counts[cluster]
        if single or covered >= 0.9 * len(ring):
            break
    distance = np.min([np.abs(rgb.astype(int) - s).max(axis=2) for s in seeds], axis=0)
    near = (distance <= tol).astype(np.uint8)

    # 1) Pixels close to a border colour and connected to the border.
    _, labels = cv2.connectedComponents(near, connectivity=4)
    edge_labels = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    background = np.isin(labels, edge_labels[edge_labels > 0])

    # 2) Floating-range flood fill from the border catches smooth gradients/vignettes.
    mask = np.zeros((h + 2, w + 2), np.uint8)
    flags = 4 | cv2.FLOODFILL_MASK_ONLY | (1 << 8)
    for y, x in [(0, x) for x in range(0, w, 16)] + [(h - 1, x) for x in range(0, w, 16)] + \
                [(y, 0) for y in range(0, h, 16)] + [(y, w - 1) for y in range(0, h, 16)]:
        if near[y, x] and not mask[y + 1, x + 1]:
            cv2.floodFill(rgb, mask, (x, y), 0, (step,) * 3, (step,) * 3, flags)
    background |= mask[1:-1, 1:-1].astype(bool)

    # 3) Enclosed holes (between arm and body) that closely match the background.
    tight = ((distance <= tol // 2) & ~background).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(tight, connectivity=4)
    holes = [i for i in range(1, count) if stats[i, cv2.CC_STAT_AREA] >= 400]
    if holes:
        background |= np.isin(labels, holes)

    rgba = np.dstack([rgb, np.where(background, 0, 255).astype(np.uint8)])
    border_bg = np.concatenate([background[0], background[-1], background[:, 0], background[:, -1]]).mean()
    box = Image.fromarray(rgba).getchannel("A").getbbox()
    report = {
        "bg_colours": ["%02x%02x%02x" % tuple(int(c) for c in s) for s in seeds],
        "border_clean": round(float(border_bg), 3),
        "holes_removed": len(holes),
        "foreground_px": int((~background).sum()),
    }
    problems = []
    if box is None:
        problems.append("nothing left after background removal")
    elif min(box[0], box[1], w - box[2], h - box[3]) == 0:
        problems.append("art touches the image edge (clipped, or background not removed)")
    greys = [s for s in seeds if np.ptp(s) < 20]
    if len(seeds) == 2 and len(greys) == 2 and min(counts[np.argsort(-counts)[:2]]) > 0.25 * len(ring):
        problems.append("fake transparency checkerboard background (grey parts of the art may be lost)")
    elif border_bg < 0.97 or len(seeds) > 2:
        problems.append("messy background (scene/gradient bleed) — check the cutout")
    report["problems"] = problems
    return Image.fromarray(rgba), report


def snapper():
    for candidate in (os.environ.get("PIXEL_SNAPPER_BIN"), ROOT / "bin/pixel-snapper",
                      shutil.which("spritefusion-pixel-snapper")):
        if candidate and Path(candidate).is_file():
            return str(candidate)
    raise SystemExit("Pixel Snapper missing: run `bash setup.sh` in asset-builder/")


def snap(cutout, px=None, colours=32, palette=None):
    """Snap AI 'pixel art' to its real grid and palette. Returns a native-resolution RGBA image."""
    data = np.array(cutout.convert("RGBA"))
    transparent = bool((data[:, :, 3] < 128).any())
    data[data[:, :, 3] < 128] = (*HOLE, 255)  # snapper sees transparency as a flat colour
    data[:, :, 3] = 255
    with tempfile.TemporaryDirectory() as tmp:
        src, dst = Path(tmp, "in.png"), Path(tmp, "out.png")
        Image.fromarray(data).save(src)
        extra = ["%02x%02x%02x" % HOLE] if transparent else []
        argv = [snapper(), str(src), str(dst), str(len(palette or []) + len(extra) if palette else colours + len(extra))]
        if px:
            argv += ["--pixel-size", str(px)]
        if palette:
            argv += ["--palette", ",".join([*palette, *extra])]
        subprocess.run(argv, check=True, capture_output=True, text=True)
        out = np.array(Image.open(dst).convert("RGBA"))
    hole = np.abs(out[:, :, :3].astype(int) - HOLE).max(axis=2) <= 60
    hole &= transparent
    out[hole] = 0
    out[~hole, 3] = 255
    return Image.fromarray(out)


def resize_art(image, scale, colours=32):
    """Resample snapped art to a new size: alpha-weighted area average, then re-quantise so it stays crisp."""
    data = np.array(image.convert("RGBA")).astype(np.float32)
    alpha = data[:, :, 3] / 255
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    rgb = cv2.resize(data[:, :, :3] * alpha[:, :, None], size, interpolation=cv2.INTER_AREA)
    alpha = cv2.resize(alpha, size, interpolation=cv2.INTER_AREA)
    rgb = rgb / np.maximum(alpha, 1e-6)[:, :, None]
    out = np.dstack([np.clip(rgb, 0, 255), np.where(alpha >= 0.5, 255, 0)]).astype(np.uint8)
    opaque = out[:, :, 3] > 0
    flat = Image.fromarray(out[:, :, :3]).quantize(colours, method=Image.Quantize.MEDIANCUT, kmeans=2)
    out[opaque, :3] = np.array(flat.convert("RGB"))[opaque]
    out[~opaque] = 0
    return Image.fromarray(out)


def trim(image):
    box = image.getchannel("A").getbbox()
    return image.crop(box) if box else image


def place(art, canvas, anchor):
    """Put trimmed art on a canvas with its bottom-centre at `anchor` (feet on the ground line).

    Never rescales. Returns (image, problem or None)."""
    art = trim(art)
    w, h = canvas
    x = anchor[0] - art.width // 2
    y = anchor[1] - art.height
    problem = None
    if art.width > w or art.height > h:
        problem = f"art is {art.width}x{art.height}, canvas is {w}x{h}: use a bigger --canvas"
    x = max(0, min(x, w - art.width))
    y = max(0, min(y, h - art.height))
    result = Image.new("RGBA", (max(w, art.width), max(h, art.height)))
    result.paste(art, (x, y))
    return result, problem


def anchor_of(image, mode="feet"):
    x0, y0, x1, y1 = image.getchannel("A").getbbox()
    return ((x0 + x1) // 2, y1 if mode == "feet" else (y0 + y1) // 2)


def colours_of(image):
    data = np.array(image.convert("RGBA"))
    used = np.unique(data[data[:, :, 3] > 0][:, :3], axis=0)
    return ["%02x%02x%02x" % tuple(int(v) for v in c) for c in used]


def on_colour(image, colour, size=None):
    """Flatten RGBA art onto a solid colour, optionally nearest-upscaled (for model references)."""
    base = Image.new("RGBA", image.size, (*colour, 255))
    base.alpha_composite(image.convert("RGBA"))
    if size:
        base = base.resize(size, Image.Resampling.NEAREST)
    return base.convert("RGB")


def checker(size, cell=8):
    image = Image.new("RGBA", size, "#3a3646")
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill="#46414f")
    return image


def contact_sheet(images, labels, out, scale=3, columns=None):
    images = [im.convert("RGBA") for im in images]
    cw = max(im.width for im in images) * scale
    ch = max(im.height for im in images) * scale
    columns = columns or min(len(images), 5)
    rows = (len(images) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * cw, rows * (ch + 20)), "#1b1622")
    draw = ImageDraw.Draw(sheet)
    for i, (im, label) in enumerate(zip(images, labels)):
        tile = checker(im.size)
        tile.alpha_composite(im)
        tile = tile.resize((im.width * scale, im.height * scale), Image.Resampling.NEAREST)
        x, y = (i % columns) * cw, (i // columns) * (ch + 20)
        sheet.paste(tile.convert("RGB"), (x, y))
        draw.text((x + 4, y + ch + 4), label, fill="#ffd34f")
    sheet.save(out)


def strip(frames, out, padding=0):
    w, h = frames[0].size
    sheet = Image.new("RGBA", (len(frames) * (w + padding), h))
    for i, frame in enumerate(frames):
        sheet.paste(frame, (i * (w + padding), 0))
    sheet.save(out)


def gif(frames, out, ms=120, scale=3):
    tiles = []
    for frame in frames:
        tile = checker(frame.size)
        tile.alpha_composite(frame)
        tiles.append(tile.convert("RGB").resize((frame.width * scale, frame.height * scale), Image.Resampling.NEAREST))
    tiles[0].save(out, save_all=True, append_images=tiles[1:], duration=ms, loop=0, disposal=2)
