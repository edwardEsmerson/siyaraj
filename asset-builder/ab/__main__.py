"""Siyaraj asset builder. Run from asset-builder/:  ~/ml/bin/python -m ab <command> -h"""
import argparse
import concurrent.futures as cf
import importlib.util
import io
import json
import os
import shutil
import sys
from pathlib import Path

from PIL import Image

from . import pixel, prompts

ROOT = pixel.ROOT
OUT = ROOT / "out"
SPRITES = ROOT / "sprites"
POSES = ROOT / "poses"
SIDE = {"1K": 1024, "2K": 2048, "4K": 4096}

# Canonical scale: 1 game unit = 2 art px. Art is authored for 1080p; the game viewport is 960x540,
# so Godot draws every sprite at scale 0.5 (pixel-perfect on 1080p+ screens). Role sizes are the
# subject's LONGEST side in art px, derived from the gameplay colliders (player 24x40 units -> 80).
ROLES = {"hero": 80, "enemy": 88, "brute": 136, "flyer": 80, "boss": 200, "big-boss": 280,
         "prop": 40, "pickup": 24}


def nanobanana():
    path = Path(os.environ.get("NANO_BANANA_SCRIPT", "~/nanobanana/gen.py")).expanduser()
    spec = importlib.util.spec_from_file_location("nanobanana_gen", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def png_bytes(image):
    buffer = io.BytesIO()
    image.save(buffer, "PNG")
    return buffer.getvalue()


def ref_bytes(path, key):
    """User reference -> PNG bytes; transparency is flattened onto the run's key colour."""
    with Image.open(path) as image:
        image = image.convert("RGBA")
    image.thumbnail((2048, 2048))
    return png_bytes(pixel.on_colour(image, prompts.KEYS[key]))


def load_sprite(name):
    folder = SPRITES / name
    if not (folder / "meta.json").is_file():
        raise SystemExit(f"no approved sprite '{name}' (have: {', '.join(sorted(p.name for p in SPRITES.iterdir()))})")
    meta = json.loads((folder / "meta.json").read_text())
    return meta, Image.open(folder / "sprite.png").convert("RGBA")


def sprite_ref(name, key):
    """Approved sprite as the model sees it: native art, nearest-upscaled onto the run's key colour."""
    meta, image = load_sprite(name)
    side = SIDE[meta["size"]]
    return png_bytes(pixel.on_colour(image, prompts.KEYS[key], (side, side * image.height // image.width)))


def canvas_for(art, mode):
    """Square canvas with room for limbs/props to swing in later keyframes."""
    side = -(-int(max(art.size) * 1.5) // 16) * 16
    return (side, side), (side // 2, side - side // 16) if mode == "feet" else (side // 2, side // 2)


def clean_sprite(raw, mode="feet", palette=None, px=None, target=None, canvas=None, anchor=None):
    """Cut out, snap to the pixel grid, and place on the canvas. Without `px`, the grid is chosen so the
    subject's longest side becomes `target` art px, however big the model happened to draw it."""
    cut, report = pixel.remove_background(raw)
    if px is None:
        box = cut.getchannel("A").getbbox()
        px = max(box[2] - box[0], box[3] - box[1]) / target if box else 16
    art = pixel.trim(pixel.snap(cut, px=px, palette=palette))
    if target and abs(max(art.size) / target - 1) > 0.15:  # model drew at the wrong grid: resample to size
        art = pixel.trim(pixel.resize_art(art, target / max(art.size)))
    if canvas is None:
        canvas, anchor = canvas_for(art, mode)
    if mode == "center":
        anchor = (anchor[0], anchor[1] + art.height // 2)
    placed, problem = pixel.place(art, canvas, anchor)
    return placed, report["problems"] + ([problem] if problem else []), art, px


def run_jobs(a, jobs, process):
    """Generate every job in parallel (cached raws are reused), clean, and retry once on problems."""
    gen = nanobanana()
    print(f"~Rs{gen.spent_inr():.0f} spent so far; {sum(not j['raw'].exists() for j in jobs)} new request(s) "
          f"with {a.model}, {a.jobs} at a time", flush=True)

    def one(job):
        for attempt in range(a.retry + 1):
            if not job["raw"].exists():
                try:
                    data = generate(gen, a, job)
                except gen.Blocked as e:
                    return job, None, [str(e)]
                job["raw"].write_bytes(data)
            with Image.open(job["raw"]) as raw:
                result, problems = process(job, raw.convert("RGB"))
            if not problems or attempt == a.retry:
                return job, result, problems
            print(f"  {job['id']}: {problems[0]} -> regenerating", flush=True)
            job["raw"].rename(job["raw"].with_suffix(".rejected.png"))
        return job, result, problems

    results = {}
    with cf.ThreadPoolExecutor(a.jobs) as pool:
        for job, result, problems in pool.map(one, jobs):
            flag = "  !! " + "; ".join(problems) if problems else ""
            print(f"  {job['id']} done{flag}", flush=True)
            results[job["id"]] = (result, problems)
    print(f"~Rs{gen.spent_inr():.0f} spent so far")
    return results


def generate(gen, a, job):
    log = lambda m: print(f"  {job['id']}:{m}", flush=True)
    try:
        return gen.generate(job["prompt"], job["refs"], a.model, a.size, job.get("aspect", "1:1"),
                            attempts=4 if a.fallback else 8, log=log)[0]
    except Exception as e:  # rate-limited past all retries -> optional cheaper model with separate capacity
        if not a.fallback or getattr(e, "code", None) != 429:
            raise
        log(f" still rate-limited, falling back to {a.fallback}")
        return gen.generate(job["prompt"], job["refs"], a.fallback, a.size, job.get("aspect", "1:1"), log=log)[0]


def prepare(run, only, total):
    """Make the run dir; --only N,M deletes those raws so they regenerate."""
    run.mkdir(parents=True, exist_ok=True)
    ids = [f"{i:02}" for i in range(1, total + 1)]
    for i in only or []:
        (run / f"{int(i):02}.raw.png").unlink(missing_ok=True)
    return ids


def labels(results):
    return [f"{i}{' !' if p else ''}" for i, (_, p) in results.items()]


# ---------------------------------------------------------------- commands

def cmd_sprite(a):
    target = a.height or ROLES[a.role]
    a.size = a.size or ("4K" if target > 150 else "2K")
    grid = max(4, round(0.65 * SIDE[a.size] / target))  # what we ask the model to draw at
    run = OUT / a.name
    refs, roles = [], []
    for r in a.ref:
        refs.append(ref_bytes(r, a.key))
        roles.append(f"design reference for this new subject ({Path(r).stem}) - take its look, translate it to pixel art")
    for s in [s for s in a.style if s != "none"]:
        refs.append(sprite_ref(s, a.key))
        roles.append(f"an approved Siyaraj sprite ({s}) - match its pixel style, outline, shading and pixel-block "
                     "size only, NOT its identity")
    prompt = prompts.sprite(a.brief, a.key, roles, grid)
    ids = prepare(run, a.only, a.n)
    (run / "prompt.txt").write_text(prompt)
    jobs = [{"id": i, "prompt": prompt, "refs": refs, "raw": run / f"{i}.raw.png"} for i in ids]

    frames = {}

    def process(job, raw):
        image, problems = clean_sprite(raw, a.anchor, target=target)[:2]
        frames[job["id"]] = {"canvas": list(image.size), "anchor": list(pixel.anchor_of(image, a.anchor))}
        image.save(run / f"{job['id']}.png")
        return image, problems

    results = run_jobs(a, jobs, process)
    meta = {"name": a.name, "brief": a.brief, "key": a.key, "role": a.role, "target": target, "size": a.size,
            "anchor_mode": a.anchor, "candidates": frames}
    (run / "run.json").write_text(json.dumps(meta, indent=2))
    pixel.contact_sheet([r for r, _ in results.values() if r], labels(results), run / "sheet.png")
    print(f"review {run / 'sheet.png'}  then:  python -m ab pick {a.name} <NN>")


def cmd_pick(a):
    run = OUT / a.name
    meta = json.loads((run / "run.json").read_text())
    name = a.as_ or a.name
    dest = SPRITES / name
    dest.mkdir(parents=True, exist_ok=True)
    shutil.copy(run / f"{int(a.id):02}.png", dest / "sprite.png")
    meta["name"] = name
    meta.update(meta.pop("candidates")[f"{int(a.id):02}"])
    (dest / "meta.json").write_text(json.dumps(meta, indent=2))
    print(f"approved -> {dest}")


def read_poses(a):
    poses = list(a.pose)
    source = a.poses or (a.anim if (POSES / f"{a.anim}.txt").exists() and not poses else None)
    if source:
        path = Path(source) if Path(source).is_file() else POSES / f"{source}.txt"
        poses += [l.strip() for l in path.read_text().splitlines() if l.strip() and not l.startswith("#")]
    if not poses:
        raise SystemExit(f"no poses: pass them as arguments, --poses FILE, or add poses/{a.anim}.txt")
    return poses


def cmd_frames(a):
    meta, base = load_sprite(a.name)
    a.size = a.size or meta["size"]
    key = meta["key"]
    canvas, anchor, mode = meta["canvas"], meta["anchor"], meta.get("anchor_mode", "feet")
    px = SIDE[a.size] / canvas[0]  # the model redraws at the scale of the upscaled reference it is shown
    poses = read_poses(a)
    run = OUT / a.name / a.anim
    ids = prepare(run, a.only, len(poses))
    refs = [sprite_ref(a.name, key)]
    roles = []
    for r in a.ref:
        refs.append(ref_bytes(r, key))
        roles.append("a pose guide only - copy the body position, not the look")
    palette = None if a.free_palette else pixel.colours_of(base)
    base_h = pixel.trim(base).height
    jobs = [{"id": i, "pose": pose, "raw": run / f"{i}.raw.png", "refs": refs,
             "prompt": prompts.frame(a.name, meta["brief"], pose, key, roles)} for i, pose in zip(ids, poses)]
    (run / "poses.txt").write_text("\n".join(poses) + "\n")

    def process(job, raw):
        image, problems, art, _ = clean_sprite(raw, mode, palette, px=px, canvas=canvas, anchor=anchor)
        drift = art.height / base_h - 1
        if abs(drift) > a.drift and not a.no_drift_check:
            problems.append(f"size drift {drift:+.0%} vs approved sprite (crouch/stretch poses can be fine)")
        image.save(run / f"{job['id']}.png")
        return image, problems

    results = run_jobs(a, jobs, process)
    frames = [r for r, _ in results.values() if r]
    if frames and len({f.size for f in frames}) > 1:  # a pose outgrew the canvas: pad all, keep feet/left aligned
        size = (max(f.width for f in frames), max(f.height for f in frames))
        for i, (frame, id_) in enumerate(zip(frames, [k for k, (r, _) in results.items() if r])):
            padded = Image.new("RGBA", size)
            padded.paste(frame, (0, size[1] - frame.height))
            frames[i] = padded
            padded.save(run / f"{id_}.png")
    if frames:
        pixel.strip(frames, run / "strip.png")
        pixel.gif(frames, run / "preview.gif", ms=1000 // a.fps)
        pixel.contact_sheet([base] + frames, ["approved"] + labels(results), run / "sheet.png", columns=6)
    print(f"review {run / 'sheet.png'} and preview.gif  then:  python -m ab keep {a.name} {a.anim}")


def cmd_keep(a):
    run = OUT / a.name / a.anim
    dest = SPRITES / a.name / a.anim
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    frames = sorted(p for p in run.glob("[0-9][0-9].png"))
    for p in frames + [run / "strip.png", run / "preview.gif", run / "poses.txt"]:
        shutil.copy(p, dest / p.name)
    print(f"kept {len(frames)} frames -> {dest}")


def cmd_texture(a):
    run = OUT / "textures" / a.name
    aspect = "1:1" if a.mode == "tile" else a.aspect
    refs = [ref_bytes(r, a.key) for r in a.ref]
    roles = [f"style/content reference ({Path(r).stem})" for r in a.ref]
    prompt = prompts.texture(a.brief, a.key, roles, a.mode)
    ids = prepare(run, a.only, a.n)
    (run / "prompt.txt").write_text(prompt)
    jobs = [{"id": i, "prompt": prompt, "refs": refs, "aspect": aspect, "raw": run / f"{i}.raw.png"} for i in ids]

    def process(job, raw):
        problems = []
        chunk = 1 if a.mode == "tile" else a.chunk
        if a.mode == "tile":
            target = (a.tile, a.tile)
        else:
            target = (round(raw.width * a.height / raw.height) // chunk, a.height // chunk)
        source = raw
        if a.mode == "cutout":
            source, report = pixel.remove_background(raw)
            problems = [p for p in report["problems"] if "touches the image edge" not in p]
        native = pixel.snap(source, px=raw.height / target[1], colours=a.colours)
        native = native.resize(target, Image.Resampling.NEAREST)  # absorb the snapper's +-few px
        native = native.resize((target[0] * chunk, target[1] * chunk), Image.Resampling.NEAREST)
        if a.mode != "cutout":
            native.putalpha(255)
        native.save(run / f"{job['id']}.png")
        repeat = (3, 3) if a.mode == "tile" else (2, 1)
        preview = Image.new("RGBA", (native.width * repeat[0], native.height * repeat[1]))
        for x in range(repeat[0]):
            for y in range(repeat[1]):
                preview.paste(native, (x * native.width, y * native.height))
        preview.save(run / f"{job['id']}-tiled.png")
        return native, problems

    run_jobs(a, jobs, process)
    print(f"review {run}/NN-tiled.png (seams!)  keep one with:  cp {run}/NN.png textures/<area>/{a.name}.png")


def symmetric(art):
    """Mirror the top-left quarter into all four corners: identical corners, straight seams."""
    w, h = art.size
    q = art.crop((0, 0, (w + 1) // 2, (h + 1) // 2))
    out = Image.new("RGBA", (q.width * 2, q.height * 2))
    out.paste(q, (0, 0))
    out.paste(q.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (q.width, 0))
    bottom = q.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    out.paste(bottom, (0, q.height))
    out.paste(bottom.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (q.width, q.height))
    return out


def nine_slice(art, corner):
    """Corners kept, a `corner`-long edge segment from the middle of each side, flat centre:
    a (3*corner)^2 texture for Godot's StyleBoxTexture with texture_margin = corner."""
    w, h = art.size
    c = corner
    out = Image.new("RGBA", (3 * c, 3 * c))
    mx, my = (w - c) // 2, (h - c) // 2
    for (sx, dx, ww) in [(0, 0, c), (mx, c, c), (w - c, 2 * c, c)]:
        for (sy, dy, hh) in [(0, 0, c), (my, c, c), (h - c, 2 * c, c)]:
            out.paste(art.crop((sx, sy, sx + ww, sy + hh)), (dx, dy))
    return out


def stretch_nine(nine, corner, size):
    """Draw a nine-slice at `size` the way Godot does (edges/centre stretched), for previews."""
    c, w, h = corner, *size
    out = Image.new("RGBA", size)
    xs = [(0, c, 0, c), (c, 2 * c, c, w - c), (2 * c, 3 * c, w - c, w)]
    ys = [(0, c, 0, c), (c, 2 * c, c, h - c), (2 * c, 3 * c, h - c, h)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            if dx1 > dx0 and dy1 > dy0:
                part = nine.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.Resampling.NEAREST)
                out.paste(part, (dx0, dy0))
    return out


def cmd_ui(a):
    """UI art is drawn at 1 texel = 1 game unit (the chunky density of the parallax layers), so
    StyleBoxTexture / TextureRect use it at scale 1 with no extra scaling."""
    run = OUT / "ui" / a.name
    refs = [ref_bytes(r, a.key) for r in a.ref]
    roles = [f"style reference ({Path(r).stem}) - match its palette and pixel style only" for r in a.ref]
    for s in [s for s in a.style if s != "none"]:
        refs.append(sprite_ref(s, a.key))
        roles.append(f"an approved Siyaraj sprite ({s}) - match its palette, outline and shading only")
    prompt = prompts.ui(a.brief, a.key, roles, a.kind)
    ids = prepare(run, a.only, a.n)
    (run / "prompt.txt").write_text(prompt)
    jobs = [{"id": i, "prompt": prompt, "refs": refs, "raw": run / f"{i}.raw.png"} for i in ids]
    corner = a.corner or a.px // 4
    previews = {}

    def process(job, raw):
        cut, report = pixel.remove_background(raw)
        box = cut.getchannel("A").getbbox()
        px = max(box[2] - box[0], box[3] - box[1]) / a.px if box else 16
        art = pixel.trim(pixel.snap(cut, px=px, colours=a.colours))
        if abs(max(art.size) / a.px - 1) > 0.15:
            art = pixel.trim(pixel.resize_art(art, a.px / max(art.size), a.colours))
        problems = report["problems"]
        if a.kind == "frame":
            art = symmetric(art)
            nine = nine_slice(art, corner)
            nine.save(run / f"{job['id']}-nine.png")
            # In-game sizes: a menu panel, a wide button, a small hint box.
            shots = [stretch_nine(nine, corner, s) for s in [(300, 180), (200, 34), (140, 60)]]
            preview = Image.new("RGBA", (300 + 16 + 200, 180))
            preview.paste(shots[0], (0, 0))
            preview.paste(shots[1], (316, 0))
            preview.paste(shots[2], (316, 60))
            previews[job["id"]] = preview
        else:
            previews[job["id"]] = art
        art.save(run / f"{job['id']}.png")
        return art, problems

    results = run_jobs(a, jobs, process)
    shown = [previews[i] for i, (r, _) in results.items() if r]
    pixel.contact_sheet(shown, labels(results), run / "sheet.png", columns=1 if a.kind == "frame" else None)
    print(f"review {run / 'sheet.png'}  keep one with:  cp {run}/NN{'-nine' if a.kind == 'frame' else ''}.png "
          f"../assets/ui/{a.name}.png  (frame: texture_margin {corner})")


def cmd_clean(a):
    for path in a.images:
        with Image.open(path) as raw:
            raw = raw.convert("RGB")
        source = raw if a.keep_bg else pixel.remove_background(raw)[0]
        out = Path(path).with_suffix(".clean.png")
        pixel.trim(pixel.snap(source, px=a.px)).save(out)
        print(out)


def cmd_ls(a):
    for folder in sorted(p for p in SPRITES.iterdir() if (p / "meta.json").exists()):
        meta = json.loads((folder / "meta.json").read_text())
        anims = [p.name for p in sorted(folder.iterdir()) if p.is_dir()]
        art = pixel.trim(Image.open(folder / "sprite.png")).size
        print(f"{folder.name:22} {meta.get('role', '?'):8} art {art[0]}x{art[1]} canvas {meta['canvas'][0]}x{meta['canvas'][1]} "
              f"{meta['key']:7} "
              f"anims: {', '.join(anims) or '-'}")


def cmd_doctor(a):
    print("snapper:", pixel.snapper())
    gen = nanobanana()
    print("generator:", gen.__file__, f"| spent ~Rs{gen.spent_inr():.0f} of Rs{gen.BUDGET_INR:.0f}")
    adc = Path("~/.config/gcloud/application_default_credentials.json").expanduser()
    print("gcloud ADC:", "ok" if adc.exists() else "MISSING -> gcloud auth application-default login")


def parser():
    p = argparse.ArgumentParser(prog="python -m ab", description=__doc__)
    sub = p.add_subparsers(dest="command", required=True)

    def gen_flags(c, n=None):
        if n:
            c.add_argument("-n", type=int, default=n, help="number of candidates")
        c.add_argument("--model", default="pro", help="pro | flash | full model id")
        c.add_argument("--fallback", default=None, help="model to use when still rate-limited, e.g. flash")
        c.add_argument("--jobs", type=int, default=3, help="parallel requests")
        c.add_argument("--retry", type=int, default=1, help="auto-regenerate outputs with problems this many times")
        c.add_argument("--only", type=lambda s: s.split(","), help="regenerate just these ids, e.g. 2,4")
        c.add_argument("-r", "--ref", action="append", default=[], help="reference image (repeatable)")

    c = sub.add_parser("sprite", help="design a new character/enemy/boss/prop: N candidates")
    c.add_argument("name")
    c.add_argument("brief")
    c.add_argument("--style", nargs="*", default=["siya"], help="approved sprites to copy pixel style from (or none)")
    c.add_argument("--role", default="hero", choices=ROLES, help="canonical size: " +
                   ", ".join(f"{k} {v}px" for k, v in ROLES.items()))
    c.add_argument("--height", type=int, help="override: longest side of the subject in art px")
    c.add_argument("--size", choices=SIDE, help="generation resolution (default 2K, 4K above 150px)")
    c.add_argument("--key", default="green", choices=prompts.KEYS, help="background key; avoid the subject's colours")
    c.add_argument("--anchor", default="feet", choices=["feet", "center"], help="center for flyers")
    gen_flags(c, 4)
    c.set_defaults(func=cmd_sprite)

    c = sub.add_parser("pick", help="approve a candidate into sprites/")
    c.add_argument("name")
    c.add_argument("id")
    c.add_argument("--as", dest="as_", help="save under a different sprite name")
    c.set_defaults(func=cmd_pick)

    c = sub.add_parser("frames", help="keyframes for an approved sprite, one request per pose")
    c.add_argument("name")
    c.add_argument("anim", help="animation name; poses/<anim>.txt is used if no poses are given")
    c.add_argument("pose", nargs="*", help="pose descriptions, one per frame")
    c.add_argument("--poses", help="pose file (one per line) or name in poses/")
    c.add_argument("--fps", type=int, default=8)
    c.add_argument("--size", choices=SIDE, help="defaults to the sprite's size")
    c.add_argument("--free-palette", action="store_true", help="don't lock colours to the approved sprite")
    c.add_argument("--drift", type=float, default=0.18, help="height change that counts as a problem")
    c.add_argument("--no-drift-check", action="store_true")
    gen_flags(c)
    c.set_defaults(func=cmd_frames)

    c = sub.add_parser("keep", help="copy reviewed frames into sprites/<name>/<anim>/")
    c.add_argument("name")
    c.add_argument("anim")
    c.set_defaults(func=cmd_keep)

    c = sub.add_parser("texture", help="tileable texture or parallax layer for maps")
    c.add_argument("name")
    c.add_argument("brief")
    c.add_argument("--mode", default="tile", choices=["tile", "layer", "cutout"],
                   help="tile: seamless square; layer: opaque parallax; cutout: parallax shapes with transparency")
    c.add_argument("--tile", type=int, default=128, help="tile size in art px (128 = 64 game units)")
    c.add_argument("--height", type=int, default=1080, help="layer height in art px (1080 = full screen)")
    c.add_argument("--chunk", type=int, default=2, help="art px per background pixel (backgrounds are chunkier)")
    c.add_argument("--aspect", default="21:9", help="layer aspect: 16:9, 21:9 ...")
    c.add_argument("--colours", type=int, default=24)
    c.add_argument("--size", default="2K", choices=SIDE)
    c.add_argument("--key", default="magenta", choices=prompts.KEYS)
    gen_flags(c, 2)
    c.set_defaults(func=cmd_texture)

    c = sub.add_parser("ui", help="UI frame (9-slice) or icon at 1 texel = 1 game unit")
    c.add_argument("name")
    c.add_argument("brief")
    c.add_argument("--kind", default="frame", choices=["frame", "icon"])
    c.add_argument("--px", type=int, default=64, help="longest side in game units (= texels)")
    c.add_argument("--corner", type=int, help="frame: 9-slice corner/margin size (default px/4)")
    c.add_argument("--style", nargs="*", default=["siya"], help="approved sprites to copy palette from (or none)")
    c.add_argument("--colours", type=int, default=16)
    c.add_argument("--size", default="2K", choices=SIDE)
    c.add_argument("--key", default="green", choices=prompts.KEYS)
    gen_flags(c, 4)
    c.set_defaults(func=cmd_ui)

    c = sub.add_parser("clean",help="cut out + pixel-snap any existing image(s), no generation")
    c.add_argument("images", nargs="+")
    c.add_argument("--px", type=float, default=16)
    c.add_argument("--keep-bg", action="store_true")
    c.set_defaults(func=cmd_clean)

    sub.add_parser("ls", help="list approved sprites and their animations").set_defaults(func=cmd_ls)
    sub.add_parser("doctor", help="check tools, auth and spend").set_defaults(func=cmd_doctor)
    return p


def main():
    a = parser().parse_args()
    a.func(a)


if __name__ == "__main__":
    sys.exit(main())
