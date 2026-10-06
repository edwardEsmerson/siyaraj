"""Siyaraj asset builder. Run from asset-builder/:  ~/ml/bin/python -m ab <command> -h"""
import argparse
import concurrent.futures as cf
import contextlib
import fcntl
import importlib.util
import io
import json
import os
import shutil
import sys
import time
from pathlib import Path

from PIL import Image, ImageDraw

from . import batch, pixel, prompts

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


def resolve_size(a, default):
    if a.batch and a.size not in (None, "1K"):
        raise SystemExit("Vertex image batches support 1K only; omit --size or use --size 1K")
    a.size = "1K" if a.batch else (a.size or default)
    return a.size


def ref_bytes(path, key, size="2K"):
    """User reference -> PNG bytes; transparency is flattened onto the run's key colour."""
    with Image.open(path) as image:
        image = image.convert("RGBA")
    image.thumbnail((SIDE[size], SIDE[size]))
    return png_bytes(pixel.on_colour(image, prompts.KEYS[key]))


def load_sprite(name):
    folder = SPRITES / name
    if not (folder / "meta.json").is_file():
        raise SystemExit(f"no approved sprite '{name}' (have: {', '.join(sorted(p.name for p in SPRITES.iterdir()))})")
    meta = json.loads((folder / "meta.json").read_text())
    return meta, Image.open(folder / "sprite.png").convert("RGBA")


def sprite_ref(name, key, size=None):
    """Approved sprite as the model sees it: native art, nearest-upscaled onto the run's key colour."""
    meta, image = load_sprite(name)
    side = SIDE[size or meta["size"]]
    return png_bytes(pixel.on_colour(image, prompts.KEYS[key], (side, side * image.height // image.width)))


def canvas_for(art, mode):
    """Square canvas with room for limbs/props to swing in later keyframes."""
    side = -(-int(max(art.size) * 1.5) // 16) * 16
    return (side, side), (side // 2, side - side // 16) if mode == "feet" else (side // 2, side // 2)


def clean_sprite(raw, mode="feet", palette=None, px=None, target=None, canvas=None, anchor=None, key=None):
    """Cut out, snap to the pixel grid, and place on the canvas. Without `px`, the grid is chosen so the
    subject's longest side becomes `target` art px, however big the model happened to draw it."""
    cut, report = pixel.remove_background(raw, key=key)
    if px is None:
        box = cut.getchannel("A").getbbox()
        px = max(box[2] - box[0], box[3] - box[1]) / target if box else 16
    art = pixel.trim(pixel.snap(cut, px=px, palette=palette))
    if target and abs(max(art.size) / target - 1) > 0.15:  # model drew at the wrong grid: resample to size
        art = pixel.trim(pixel.resize_art(art, target / max(art.size)))
    if canvas is None:
        canvas, anchor = canvas_for(art, mode)
    placed, problem = pixel.place_registered([art], canvas, anchor, mode)[:2]
    placed = placed[0]
    return placed, report["problems"] + ([problem] if problem else []), art, px


def run_jobs(a, jobs, process):
    """Generate every job in parallel (cached raws are reused), clean, and retry once on problems.
    --split alternates candidates between models; --batch queues missing raws instead of generating."""
    gen = nanobanana()
    lanes = [gen.MODELS.get(m, m) for m in (a.split.split(",") if a.split else [a.model])]
    for i, job in enumerate(jobs):
        job["model"] = lanes[i % len(lanes)]
    pending = [j for j in jobs if not j["raw"].exists()]
    if a.batch:
        a.retry = 0  # cleaning only: a regenerate would be another batch round
        if pending:
            batch.enqueue(gen, a, pending)
        jobs = [j for j in jobs if j["raw"].exists()]
    print(f"~Rs{gen.spent_inr():.0f} spent so far; {len(pending) * (not a.batch)} new request(s) "
          f"with {', '.join(batch.short(gen, m) for m in lanes)}, {a.jobs} at a time", flush=True)

    def one(job):
        for attempt in range(a.retry + 1):
            if not job["raw"].exists():
                try:
                    data, model = generate(gen, a, job)
                except Exception as e:
                    return job, None, [str(e)]
                job["raw"].write_bytes(data)
                batch.note_model(job["raw"], batch.short(gen, model))
            with Image.open(job["raw"]) as raw:
                result, problems = process(job, raw.convert("RGB"))
            if not problems or attempt == a.retry:
                return job, result, problems
            print(f"  {job['id']}: {problems[0]} -> regenerating", flush=True)
            job["raw"].rename(job["raw"].with_suffix(".rejected.png"))
        return job, result, problems

    results, a.made = {}, {}
    with cf.ThreadPoolExecutor(a.jobs) as pool:
        for job, result, problems in pool.map(one, jobs):
            flag = "  !! " + "; ".join(problems) if problems else ""
            print(f"  {job['id']} done{flag}", flush=True)
            results[job["id"]] = (result, problems)
            a.made[job["id"]] = batch.made_by(job["raw"])
    print(f"~Rs{gen.spent_inr():.0f} spent so far")
    return results


@contextlib.contextmanager
def live_slot():
    """Bound live API concurrency across builder commands in this worktree."""
    folder = OUT / "live-slots"
    folder.mkdir(parents=True, exist_ok=True)
    count = max(1, int(os.environ.get("AB_LIVE_SLOTS", "3")))
    handle = None
    while handle is None:
        for n in range(count):
            candidate = (folder / f"{n}.lock").open("a")
            try:
                fcntl.flock(candidate, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                candidate.close()
                continue
            handle = candidate
            break
        if handle is None:
            time.sleep(0.2)
    try:
        yield
    finally:
        handle.close()


def generate(gen, a, job):
    with live_slot():
        return generate_in_slot(gen, a, job)


def generate_in_slot(gen, a, job):
    """-> (image bytes, model id that made it)."""
    log = lambda m: print(f"  {job['id']}:{m}", flush=True)
    try:
        return gen.generate(job["prompt"], job["refs"], job["model"], a.size, job.get("aspect", "1:1"),
                            attempts=a.primary_attempts if a.fallback else a.api_attempts, log=log)[0], job["model"]
    except Exception as e:  # rate-limited past all retries -> optional cheaper model with separate capacity
        if not a.fallback or getattr(e, "code", None) != 429:
            raise
        log(f" still rate-limited, falling back to {a.fallback}")
        model = gen.MODELS.get(a.fallback, a.fallback)
        return gen.generate(job["prompt"], job["refs"], model, a.size, job.get("aspect", "1:1"),
                            attempts=a.api_attempts, log=log)[0], model


def prepare(run, only, total):
    """Make the run dir; --only N,M deletes those raws so they regenerate."""
    run.mkdir(parents=True, exist_ok=True)
    ids = [f"{i:02}" for i in range(1, total + 1)]
    for i in only or []:
        if not 1 <= int(i) <= total:
            raise SystemExit(f"--only ID {i} is outside 1..{total}")
        (run / f"{int(i):02}.raw.png").unlink(missing_ok=True)
    return ids


def labels(results, a):
    """Sheet labels for the candidates that produced an image: id, model if not pro, ! on problems."""
    made = getattr(a, "made", {})
    return [f"{i}{' ' + made[i] if made.get(i, 'pro') != 'pro' else ''}{' !' if p else ''}"
            for i, (r, p) in results.items() if r]


# ---------------------------------------------------------------- commands

def cmd_sprite(a):
    target = a.height or ROLES[a.role]
    resolve_size(a, "4K" if target > 150 else "2K")
    grid = max(4, round(0.65 * SIDE[a.size] / target))  # what we ask the model to draw at
    run = OUT / a.name
    refs, roles = [], []
    for r in a.ref:
        refs.append(ref_bytes(r, a.key, a.size))
        roles.append(f"design reference for this new subject ({Path(r).stem}) - take its look, translate it to pixel art")
    for s in [s for s in a.style if s != "none"]:
        refs.append(sprite_ref(s, a.key, a.size))
        roles.append(f"an approved Siyaraj sprite ({s}) - match its pixel style, outline, shading and pixel-block "
                     "size only, NOT its identity")
    prompt = prompts.sprite(a.brief, a.key, roles, grid, a.view, a.subject)
    ids = prepare(run, a.only, a.n)
    (run / "prompt.txt").write_text(prompt)
    jobs = [{"id": i, "prompt": prompt, "refs": refs, "raw": run / f"{i}.raw.png"} for i in ids]

    frames = {}

    def process(job, raw):
        image, problems, art, px = clean_sprite(raw, a.anchor, target=target, key=prompts.KEYS[a.key])
        frames[job["id"]] = {"canvas": list(image.size), "anchor": list(pixel.anchor_of(image, a.anchor)),
                             "art_dimensions": list(art.size), "generation_pixel_size": px,
                             "problems": problems}
        image.save(run / f"{job['id']}.png")
        return image, problems

    results = run_jobs(a, jobs, process)
    meta = {"name": a.name, "brief": a.brief, "key": a.key, "role": a.role, "target": target, "size": a.size,
            "anchor_mode": a.anchor, "candidates": frames}
    (run / "run.json").write_text(json.dumps(meta, indent=2))
    meta.update(view=a.view, subject=a.subject)
    (run / "run.json").write_text(json.dumps(meta, indent=2))
    if any(r for r, _ in results.values()):
        pixel.contact_sheet([r for r, _ in results.values() if r], labels(results, a), run / "sheet.png")
    print(f"review {run / 'sheet.png'}  then:  python -m ab pick {a.name} <NN>")


def cmd_pick(a):
    run = OUT / a.name
    meta = json.loads((run / "run.json").read_text())
    name = a.as_ or a.name
    dest = SPRITES / name
    dest.mkdir(parents=True, exist_ok=True)
    shutil.copy(run / f"{int(a.id):02}.png", dest / "sprite.png")
    meta["name"] = name
    meta["candidate_id"] = f"{int(a.id):02}"
    meta["model"] = batch.made_by(run / f"{int(a.id):02}.raw.png")
    meta.update(meta.pop("candidates")[f"{int(a.id):02}"])
    (dest / "meta.json").write_text(json.dumps(meta, indent=2))
    from . import cast
    cast.record_approval(name, candidate=f"{int(a.id):02}")
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
    resolve_size(a, meta["size"])
    key = meta["key"]
    canvas, anchor, mode = meta["canvas"], meta["anchor"], meta.get("anchor_mode", "feet")
    px = SIDE[a.size] / canvas[0]  # the model redraws at the scale of the upscaled reference it is shown
    poses = read_poses(a)
    if a.fps <= 0 or (a.durations and (len(a.durations) != len(poses) or any(v <= 0 for v in a.durations))):
        raise SystemExit("FPS must be positive; --durations must have one positive value per pose")
    run = OUT / a.name / a.anim
    ids = prepare(run, a.only, len(poses))
    refs = [sprite_ref(a.name, key, a.size)]
    roles = []
    for r in a.ref:
        refs.append(ref_bytes(r, key, a.size))
        roles.append("a pose guide only - copy the body position, not the look")
    palette = None if a.free_palette else pixel.colours_of(base)
    base_h = pixel.trim(base).height
    jobs = [{"id": i, "pose": pose, "raw": run / f"{i}.raw.png", "refs": refs,
             "prompt": prompts.frame(a.name, meta["brief"], pose, key, roles,
                                     meta.get("view", "right-profile"), meta.get("subject", "full-body"),
                                     f"Use fixed {px:.2f} by {px:.2f} source-pixel blocks. The reference's upright "
                                     f"subject height is {round(base_h * px)} pixels on a {SIDE[a.size]} pixel canvas. "
                                     "Keep that camera distance and body proportions. Do not zoom in to fill the frame.")}
            for i, pose in zip(ids, poses)]
    (run / "poses.txt").write_text("\n".join(poses) + "\n")

    def process(job, raw):
        cut, report = pixel.remove_background(raw, key=prompts.KEYS[key])
        art = pixel.trim(pixel.snap_fixed(cut, px=px, palette=palette))
        problems = list(report["problems"])
        if raw.width != SIDE[a.size]:
            problems.append(f"expected {a.size} raw width {SIDE[a.size]}, got {raw.width}")
        drift = art.height / base_h - 1
        if abs(drift) > a.drift and not a.no_drift_check:
            problems.append(f"size drift {drift:+.0%} vs approved sprite (crouch/stretch poses can be fine)")
        return art, problems

    results = run_jobs(a, jobs, process)
    art = [r for r, _ in results.values() if r]
    frames = []
    run_meta = {"name": a.name, "animation": a.anim, "size": a.size,
                "view": meta.get("view", "right-profile"), "subject": meta.get("subject", "full-body"),
                "anchor_mode": mode, "fps": a.fps, "loop": a.loop, "poses": poses,
                "expected_frames": len(poses), "free_palette": a.free_palette,
                "durations": a.durations or [1.0] * len(poses),
                "frames": [i for i, (r, _) in results.items() if r],
                "problems": {i: p for i, (_, p) in results.items() if p}}
    run_meta["models"] = getattr(a, "made", {})
    run_meta["grid"] = {"mode": "uniform", "source_pixel_spacing": px}
    if art:
        base_origin = pixel.anchor_of(base, mode)
        offset = (base_origin[0] - anchor[0], base_origin[1] - anchor[1])
        frames, _, padded_canvas, padded_anchor = pixel.place_registered(art, canvas, anchor, mode, offset)
        run_meta.update(canvas=list(padded_canvas), anchor=list(padded_anchor))
        for id_, frame in zip(run_meta["frames"], frames):
            frame.save(run / f"{id_}.png")
    (run / "meta.json").write_text(json.dumps(run_meta, indent=2))
    if frames:
        pixel.strip(frames, run / "strip.png")
        pixel.gif(frames, run / "preview.gif", ms=[round(1000 * run_meta["durations"][int(i) - 1] / a.fps)
                                                   for i in run_meta["frames"]], loop=a.loop == "loop")
        pixel.contact_sheet([base] + frames, ["approved"] + labels(results, a), run / "sheet.png", columns=6)
    print(f"review {run / 'sheet.png'} and preview.gif  then:  python -m ab keep {a.name} {a.anim}")


def cmd_keep(a):
    run = OUT / a.name / a.anim
    meta = json.loads((run / "meta.json").read_text())
    ids = [f"{i:02}" for i in range(1, meta["expected_frames"] + 1)]
    if meta["frames"] != ids or any(not (run / f"{i}.png").is_file() for i in ids):
        raise SystemExit("cannot keep incomplete animation; fetch or regenerate missing frame IDs first")
    for i in ids:
        with Image.open(run / f"{i}.png") as im:
            if list(im.size) != meta["canvas"]:
                raise SystemExit(f"frame {i} canvas differs from metadata")
    dest = SPRITES / a.name / a.anim
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    frames = sorted(p for p in run.glob("[0-9][0-9].png"))
    for p in frames + [run / "strip.png", run / "preview.gif", run / "poses.txt", run / "meta.json"]:
        shutil.copy(p, dest / p.name)
    for filename in ("source-sheet.png", "prompt.txt"):
        if (run / filename).exists():
            shutil.copy(run / filename, dest / filename)
    from . import cast
    cast.record_approval(a.name, animation=a.anim)
    print(f"kept {len(frames)} frames -> {dest}")


def cmd_texture(a):
    resolve_size(a, "2K")
    run = OUT / "textures" / a.name
    aspect = {"tile": "1:1", "cap": "21:9", "fringe": "21:9", "concept": "16:9", "piece": "1:1", "props": "1:1"}.get(a.mode, a.aspect)
    refs = [ref_bytes(r, a.key, a.size) for r in a.ref]
    roles = [f"style/content reference ({Path(r).stem})" for r in a.ref]
    prompt = prompts.texture(a.brief, a.key, roles, a.mode)
    ids = prepare(run, a.only, a.n)
    (run / "prompt.txt").write_text(prompt)
    jobs = [{"id": i, "prompt": prompt, "refs": refs, "aspect": aspect, "raw": run / f"{i}.raw.png"} for i in ids]
    previews = {}

    def process(job, raw):
        problems = []
        if a.mode in ("piece", "props"):
            return isolated(a, run, job, raw, previews)
        chunk = 1 if a.mode in ("tile", "cap", "fringe") else a.chunk
        if a.mode == "tile":
            target = (a.tile, a.tile)
        else:
            target = (round(raw.width * a.height / raw.height) // chunk, a.height // chunk)
        source, px = raw, raw.height / target[1]
        if a.mode in ("cutout", "cap", "fringe"):
            source, report = pixel.remove_background(raw, single=True)
            problems = [p for p in report["problems"] if "touches the image edge" not in p and "messy" not in p]
        if a.mode in ("cap", "fringe"):  # keep just the band (full width), sized to --cap-height
            box = source.getchannel("A").getbbox()
            if not box:
                return None, ["no strip found"]
            source = source.crop((0, box[1], source.width, box[3]))
            px = source.height / a.cap_height
            target = (round(source.width / px), a.cap_height)
        native = pixel.snap(source, px=px, colours=a.colours)
        native = native.resize(target, Image.Resampling.NEAREST)  # absorb the snapper's +-few px
        native = native.resize((target[0] * chunk, target[1] * chunk), Image.Resampling.NEAREST)
        if a.mode not in ("cutout", "cap", "fringe"):
            native.putalpha(255)
        native.save(run / f"{job['id']}.png")
        if a.mode == "concept":
            previews[job["id"]] = native
            return native, problems
        axes = [0, 1] if a.mode == "tile" else [0]
        problems += [f"visible seam across {'xy'[ax]} edges" for ax in axes if pixel.seam(native, ax)]
        repeat = (3, 3) if a.mode == "tile" else (3, 1) if a.mode in ("cap", "fringe") else (2, 1)
        preview = Image.new("RGBA", (native.width * repeat[0], native.height * repeat[1]))
        for x in range(repeat[0]):
            for y in range(repeat[1]):
                preview.paste(native, (x * native.width, y * native.height))
        preview.save(run / f"{job['id']}-tiled.png")
        previews[job["id"]] = preview
        return native, problems

    results = run_jobs(a, jobs, process)
    if a.mode == "concept":
        shown = [previews[i] for i, (r, _) in results.items() if r]
        pixel.contact_sheet([im.resize((960, 540)) for im in shown], labels(results, a), run / "sheet.png", scale=1,
                            columns=2)
        print(f"review {run / 'sheet.png'}")
    elif a.mode in ("tile", "cap", "fringe", "piece", "props"):
        shown = [previews[i] for i, (r, _) in results.items() if r]
        strip = a.mode in ("cap", "fringe", "props")
        pixel.contact_sheet(shown, labels(results, a), run / "sheet.png", scale=2 if strip else 1,
                            columns=1 if strip else None)
        print(f"review {run / 'sheet.png'} (seams!)  keep one with:  cp {run}/NN.png textures/<area>/{a.name}.png")
    else:
        print(f"review {run}/NN-tiled.png (seams!)  keep one with:  cp {run}/NN.png textures/<area>/{a.name}.png")


def isolated(a, run, job, raw, previews):
    """piece: one object, longest side --piece art px. props: a sheet drawn at --sheet art px tall, split into
    one PNG per prop (NN-pK.png), each trimmed so its bottom row is where it stands."""
    import cv2
    import numpy as np
    cut, report = pixel.remove_background(raw)
    problems = report["problems"]
    box = cut.getchannel("A").getbbox()
    if not box:
        return None, problems or ["nothing found"]
    if a.mode == "piece":
        art = cut.crop(box)
        px = max(art.size) / a.piece
        art = pixel.snap(art, px=px, colours=a.colours)
        art = art.resize((max(1, round(art.width * a.piece / max(art.size))),
                          max(1, round(art.height * a.piece / max(art.size)))), Image.Resampling.NEAREST)
        art.save(run / f"{job['id']}.png")
        previews[job["id"]] = art
        return art, problems
    px = raw.height / a.sheet
    art = pixel.snap(cut, px=px, colours=a.colours)
    art = art.resize((round(raw.width / px), a.sheet), Image.Resampling.NEAREST)
    alpha = (np.array(art.getchannel("A")) > 0).astype(np.uint8)
    grown = cv2.dilate(alpha, np.ones((5, 5), np.uint8))  # keep flames/tassels with their prop
    count, labels_, stats, _ = cv2.connectedComponentsWithStats(grown, connectivity=8)
    for old in run.glob(f"{job['id']}-p*.png"):
        old.unlink()
    k = 0
    for i in sorted(range(1, count), key=lambda i: (stats[i][1] // 64, stats[i][0])):
        x, y, w, h, area = stats[i]
        if area < 30:
            continue
        mask = (labels_[y:y + h, x:x + w] == i) & (alpha[y:y + h, x:x + w] > 0)
        part = np.array(art.crop((x, y, x + w, y + h)))
        part[~mask] = 0
        prop = Image.fromarray(part)
        prop = prop.crop(prop.getchannel("A").getbbox())
        k += 1
        prop.save(run / f"{job['id']}-p{k:02}.png")
    art.save(run / f"{job['id']}.png")
    previews[job["id"]] = art
    return art, problems + ([] if k else ["no props found"])


def blend(left, right, seed=0, step=4):
    """Transition tile: `left` fill on the left, `right` on the right, split by a ragged boundary.
    The boundary is a closed random walk (same x at top and bottom) and the left/right edges are untouched,
    so A A AB B B tiles seamlessly whenever A and B do."""
    import numpy as np
    rng = np.random.default_rng(seed)
    a, b = np.array(left.convert("RGBA")), np.array(right.convert("RGBA").resize(left.size, Image.Resampling.NEAREST))
    h, w = a.shape[:2]
    rows = h // step
    walk = np.cumsum(rng.integers(-1, 2, rows)).astype(float)
    walk -= np.linspace(0, walk[-1], rows)  # close the loop
    edge = (w // 2 + np.round(walk - walk.mean()) * step).clip(w // 4, 3 * w // 4)
    mask = np.zeros((h, w), bool)
    for r in range(rows):
        mask[r * step:(r + 1) * step, int(edge[r]):] = True
    for _ in range(rows):  # loose clumps either side of the boundary
        r, d = rng.integers(rows), rng.integers(-4, 4) * step
        x = int(edge[r] + d)
        if w // 8 < x < 7 * w // 8:
            mask[r * step:(r + 1) * step, x:x + step] = d < 0
    return Image.fromarray(np.where(mask[..., None], b, a))


def cmd_blend(a):
    left, right = Image.open(a.left), Image.open(a.right)
    tile = blend(left, right, a.seed)
    name = f"{Path(a.left).stem}__{Path(a.right).stem}"
    out = Path(a.left).parent / f"{name}.png" if a.keep else OUT / "textures" / "blend" / f"{name}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    tile.save(out)
    w, h = tile.size
    preview = Image.new("RGBA", (w * 5, h * 2))
    for i, part in enumerate([left, left, tile, right, right]):
        for y in range(2):
            preview.paste(part.convert("RGBA").resize((w, h)), (i * w, y * h))
    preview.save(out.with_name(f"{name}-preview.png"))
    print(f"wrote {out} (+ -preview.png: A A AB B B)" + ("" if a.keep else "  keep with --keep, or try --seed N"))


def board_area(area):
    """Mock side view of one area: each cap on a platform of each fill, then a long floor of the fills
    chained through their transition tiles."""
    d = ROOT / "textures" / area
    files = sorted(d.glob("*.png"))
    caps = [Image.open(f).convert("RGBA") for f in files if f.stem.endswith("-cap")]
    blends = {tuple(f.stem.split("__")): Image.open(f).convert("RGBA") for f in files if "__" in f.stem}
    fills = {f.stem: Image.open(f).convert("RGBA") for f in files
             if "__" not in f.stem and not f.stem.endswith("-cap") and Image.open(f).size[0] == Image.open(f).size[1]}
    if not fills:
        return None
    t = next(iter(fills.values())).width
    board = Image.new("RGBA", (max(len(fills), 4) * (3 * t + 64) + 64, 3 * t + 64 + 2 * t), "#2a2035")

    def platform(fill, cap, x, y, w, h):
        for tx in range(x, x + w, t):
            for ty in range(y, y + h, t):
                board.alpha_composite(fill.crop((0, 0, min(t, x + w - tx), min(t, y + h - ty))), (tx, ty))
        if cap:  # walking surface sits a third of the way down the cap
            for cx in range(x, x + w, cap.width):
                board.alpha_composite(cap.crop((0, 0, min(cap.width, x + w - cx), cap.height)),
                                      (cx, y - cap.height // 3))

    for i, (name, fill) in enumerate(fills.items()):
        x = 64 + i * (3 * t + 64)
        platform(fill, caps[i % len(caps)] if caps else None, x, t, 3 * t, t // 2)  # thin 32-unit platform
        platform(fill, caps[(i + 1) % len(caps)] if caps else None, x + t // 2, 2 * t, 2 * t, t + t // 2)
    x, y, names = 0, board.height - t, list(fills)
    for name, nxt in zip(names, names[1:] + [None]):  # floor: A A [A__B] B B ...
        for part in [fills[name]] * 2 + ([blends[(name, nxt)]] if (name, nxt) in blends else []):
            board.alpha_composite(part, (x, y))
            x += t
    if caps:
        for cx in range(0, x, caps[0].width):
            board.alpha_composite(caps[0].crop((0, 0, min(caps[0].width, x - cx), caps[0].height)), (cx, y - caps[0].height // 3))
    return board.crop((0, 0, max(board.width, x), board.height))


def cmd_board(a):
    areas = a.areas or sorted(p.name for p in (ROOT / "textures").iterdir() if p.is_dir())
    boards = [(area, b) for area in areas if (b := board_area(area))]
    width = max(b.width for _, b in boards)
    out = Image.new("RGB", (width, sum(b.height + 24 for _, b in boards)), "#1b1622")
    draw, y = ImageDraw.Draw(out), 0
    for area, b in boards:
        draw.text((8, y + 6), area, fill="#ffd34f")
        out.paste(b.convert("RGB"), (0, y + 24))
        y += b.height + 24
    path = OUT / "textures" / "board.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    out.save(path)
    print(f"wrote {path} (1 px = 1 art px, i.e. the 1080p game view)")


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
    """Corners kept, a `corner`-long edge segment from the middle of each side, centre flattened to the
    interior's main colour: a (3*corner)^2 texture for Godot's StyleBoxTexture with texture_margin = corner
    and axis_stretch TILE_FIT (edge ornaments repeat instead of smearing)."""
    w, h = art.size
    c = corner
    out = Image.new("RGBA", (3 * c, 3 * c))
    mx, my = (w - c) // 2, (h - c) // 2
    for (sx, dx, ww) in [(0, 0, c), (mx, c, c), (w - c, 2 * c, c)]:
        for (sy, dy, hh) in [(0, 0, c), (my, c, c), (h - c, 2 * c, c)]:
            out.paste(art.crop((sx, sy, sx + ww, sy + hh)), (dx, dy))
    inner = art.crop((c, c, w - c, h - c)).convert("RGBA")
    fill = max(inner.getcolors(inner.width * inner.height))[1]
    out.paste(Image.new("RGBA", (c, c), fill), (c, c))
    px = out.load()  # snapping leaves near-identical fill shades that show up once the fill is recoloured
    for y in range(out.height):
        for x in range(out.width):
            if px[x, y][3] and max(abs(a - b) for a, b in zip(px[x, y][:3], fill[:3])) <= 8:
                px[x, y] = fill
    return out


def tile_fit(part, length, axis):
    """Repeat `part` along one axis a whole number of times, stretched to fit (Godot TILE_FIT)."""
    size = part.size[axis]
    count = max(1, round(length / size))
    strip = Image.new("RGBA", (size * count, part.height) if axis == 0 else (part.width, size * count))
    for i in range(count):
        strip.paste(part, (i * size, 0) if axis == 0 else (0, i * size))
    target = (length, part.height) if axis == 0 else (part.width, length)
    return strip.resize(target, Image.Resampling.NEAREST)


def stretch_nine(nine, corner, size):
    """Draw a nine-slice at `size` the way Godot's TILE_FIT does, for previews."""
    c, w, h = corner, *size
    out = Image.new("RGBA", size)
    xs = [(0, 0, c), (c, c, w - c), (2 * c, w - c, w)]
    ys = [(0, 0, c), (c, c, h - c), (2 * c, h - c, h)]
    for sx, dx0, dx1 in xs:
        for sy, dy0, dy1 in ys:
            if dx1 > dx0 and dy1 > dy0:
                part = nine.crop((sx, sy, sx + c, sy + c))
                part = tile_fit(part, dx1 - dx0, 0) if sx == c else part
                part = tile_fit(part, dy1 - dy0, 1) if sy == c else part
                out.paste(part, (dx0, dy0))
    return out


def cmd_ui(a):
    """UI art is drawn at 1 texel = 1 game unit (the chunky density of the parallax layers), so
    StyleBoxTexture / TextureRect use it at scale 1 with no extra scaling."""
    resolve_size(a, "2K")
    run = OUT / "ui" / a.name
    refs = [ref_bytes(r, a.key, a.size) for r in a.ref]
    roles = [f"style reference ({Path(r).stem}) - match its palette and pixel style only" for r in a.ref]
    for s in [s for s in a.style if s != "none"]:
        refs.append(sprite_ref(s, a.key, a.size))
        roles.append(f"an approved Siyaraj sprite ({s}) - match its palette, outline and shading only")
    prompt = prompts.ui(a.brief, a.key, roles, a.kind)
    ids = prepare(run, a.only, a.n)
    (run / "prompt.txt").write_text(prompt)
    jobs = [{"id": i, "prompt": prompt, "refs": refs, "raw": run / f"{i}.raw.png"} for i in ids]
    corner = a.corner or a.px // 4
    previews, margins = {}, {}

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
            c = min(corner, (min(art.size) - 1) // 2)  # wide/short frames get a smaller margin
            margins[job["id"]] = c
            nine = nine_slice(art, c)
            nine.save(run / f"{job['id']}-nine.png")
            # In-game sizes: a menu panel, a wide button, a small hint box.
            tall = max(34, 2 * c + 4)
            shots = [stretch_nine(nine, c, s) for s in [(300, 180), (200, tall), (140, max(60, tall))]]
            preview = Image.new("RGBA", (300 + 16 + 200, 180))
            preview.paste(shots[0], (0, 0))
            preview.paste(shots[1], (316, 0))
            preview.paste(shots[2], (316, tall + 16))
            previews[job["id"]] = preview
        else:
            previews[job["id"]] = art
        art.save(run / f"{job['id']}.png")
        return art, problems

    results = run_jobs(a, jobs, process)
    shown = [previews[i] for i, (r, _) in results.items() if r]
    names = [f"{l}  margin {margins[l[:2]]}" if l[:2] in margins else l for l in labels(results, a)]
    pixel.contact_sheet(shown, names, run / "sheet.png", columns=1 if a.kind == "frame" else None)
    if margins:
        (run / "margins.json").write_text(json.dumps(margins, indent=2))
    print(f"review {run / 'sheet.png'}  keep one with:  cp {run}/NN{'-nine' if a.kind == 'frame' else ''}.png "
          f"../assets/ui/{a.name}.png" + ("  (texture_margin per candidate: margins.json)" if margins else ""))


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
    batch.doctor(gen)


def parser():
    p = argparse.ArgumentParser(prog="python -m ab", description=__doc__)
    sub = p.add_subparsers(dest="command", required=True)

    def gen_flags(c, n=None):
        if n:
            c.add_argument("-n", type=int, default=n, help="number of candidates")
        c.add_argument("--model", default="pro", help="pro | flash | full model id")
        c.add_argument("--split", help="alternate candidates between models, e.g. pro,flash (both capacity pools)")
        c.add_argument("--fallback", default=None, help="model to use when still rate-limited, e.g. flash")
        c.add_argument("--batch", action="store_true", help="queue missing raws for `ab batch submit` (~50%% price)")
        c.add_argument("--jobs", type=int, default=3, help="parallel requests")
        c.add_argument("--api-attempts", type=int, choices=range(1, 9), default=4,
                       help="capacity/server attempts per model (1..8, default 4)")
        c.add_argument("--primary-attempts", type=int, choices=range(1, 9), default=2,
                       help="primary attempts before fallback (1..8, default 2)")
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
    c.add_argument("--view", default="right-profile", choices=prompts.VIEWS)
    c.add_argument("--subject", default="full-body", choices=prompts.SUBJECTS)
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
    c.add_argument("--loop", choices=["loop", "once", "hold", "none"], default="loop")
    c.add_argument("--durations", type=lambda s: [float(v) for v in s.split(",")],
                   help="frame durations in units of 1/fps, comma separated")
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
    c.add_argument("--mode", default="tile", choices=["tile", "cap", "fringe", "piece", "props", "layer", "cutout", "concept"],
                   help="tile: seamless square fill; cap: platform top-edge strip (transparent); layer: opaque "
                        "parallax; cutout: parallax shapes with transparency; concept: 16:9 mock level screen; fringe: strip "
                        "hung under platforms; piece: one isolated object; props: sheet split into one PNG per prop")
    c.add_argument("--tile", type=int, default=128, help="tile size in art px (128 = 64 game units)")
    c.add_argument("--height", type=int, default=1080, help="layer height in art px (1080 = full screen)")
    c.add_argument("--chunk", type=int, default=2, help="art px per background pixel (backgrounds are chunkier)")
    c.add_argument("--cap-height", type=int, default=32, help="cap/fringe strip height in art px (32 = 16 game units)")
    c.add_argument("--piece", type=int, default=80, help="piece: longest side in art px")
    c.add_argument("--sheet", type=int, default=256, help="props: the sheet's height in art px (sets prop scale)")
    c.add_argument("--aspect", default="21:9", help="layer aspect: 16:9, 21:9 ...")
    c.add_argument("--colours", type=int, default=24)
    c.add_argument("--size", choices=SIDE)
    c.add_argument("--key", default="magenta", choices=prompts.KEYS)
    gen_flags(c, 2)
    c.set_defaults(func=cmd_texture)

    c = sub.add_parser("blend", help="transition tile between two kept fills (A on the left, B on the right)")
    c.add_argument("left")
    c.add_argument("right")
    c.add_argument("--seed", type=int, default=0, help="different boundary shape")
    c.add_argument("--keep", action="store_true", help="write next to the left fill as A__B.png")
    c.set_defaults(func=cmd_blend)

    c = sub.add_parser("board", help="mock side view of kept textures per area -> out/textures/board.png")
    c.add_argument("areas", nargs="*", help="textures/<area> folders (default all)")
    c.set_defaults(func=cmd_board)

    c = sub.add_parser("ui", help="UI frame (9-slice) or icon at 1 texel = 1 game unit")
    c.add_argument("name")
    c.add_argument("brief")
    c.add_argument("--kind", default="frame", choices=["frame", "icon"])
    c.add_argument("--px", type=int, default=64, help="longest side in game units (= texels)")
    c.add_argument("--corner", type=int, help="frame: 9-slice corner/margin size (default px/4)")
    c.add_argument("--style", nargs="*", default=["none"], help="approved sprites to copy palette from (default none: refs leak into UI art)")
    c.add_argument("--colours", type=int, default=16)
    c.add_argument("--size", choices=SIDE)
    c.add_argument("--key", default="green", choices=prompts.KEYS)
    gen_flags(c, 4)
    c.set_defaults(func=cmd_ui)

    c = sub.add_parser("clean",help="cut out + pixel-snap any existing image(s), no generation")
    c.add_argument("images", nargs="+")
    c.add_argument("--px", type=float, default=16)
    c.add_argument("--keep-bg", action="store_true")
    c.set_defaults(func=cmd_clean)

    sub.add_parser("ls", help="list approved sprites and their animations").set_defaults(func=cmd_ls)
    sub.add_parser("doctor", help="check tools, auth, spend and batch jobs").set_defaults(func=cmd_doctor)

    c = sub.add_parser("batch", help="Vertex batch jobs for commands run with --batch")
    bsub = c.add_subparsers(dest="action", required=True)
    b = bsub.add_parser("submit", help="upload the queue and start one batch job per model")
    b.add_argument("--model", help="run every queued request on this model instead (pro | flash)")
    bsub.add_parser("status", help="queue size and job states")
    bsub.add_parser("fetch", help="write finished results to their raws and re-run the commands (clean only)")
    b = bsub.add_parser("wait", help="poll until jobs finish, then fetch")
    b.add_argument("--every", type=int, default=60, help="seconds between polls")
    bsub.add_parser("clear", help="drop everything queued (not submitted)")
    c.set_defaults(func=lambda a: (batch.fetch_and_clean if a.action == "fetch" else getattr(batch, a.action))(a, nanobanana()))
    from . import cast
    cast.add_parser(sub)
    return p


def main():
    a = parser().parse_args()
    a.func(a)


if __name__ == "__main__":
    sys.exit(main())
