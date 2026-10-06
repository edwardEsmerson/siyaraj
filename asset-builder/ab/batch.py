"""Vertex batch prediction: `--batch` queues requests here, `ab batch submit/status/fetch/wait` runs them.

Batch costs ~50% of live and has its own capacity (no 429s), but takes minutes to hours. Queue entries
keep the command's argv; fetch writes the raws and re-runs those commands, which then only clean (free)."""
import base64
import fcntl
import functools
import hashlib
import json
import os
import shutil
import subprocess
import sys
import threading
import time
import uuid
from pathlib import Path

from .pixel import ROOT

DIR = ROOT / "out" / "batch"
QUEUE = DIR / "queue.jsonl"
JOBS = DIR / "jobs.json"
DISCOUNT = 0.5
DONE = {"JOB_STATE_SUCCEEDED", "JOB_STATE_PARTIALLY_SUCCEEDED", "JOB_STATE_FAILED", "JOB_STATE_CANCELLED",
        "JOB_STATE_EXPIRED"}
GCLOUD = shutil.which("gcloud") or str(Path("~/google-cloud-sdk/bin/gcloud").expanduser())
_models_lock = threading.Lock()
PREFIX = os.environ.get("AB_JOB_PREFIX", "character-art-" + hashlib.sha256(str(ROOT).encode()).hexdigest()[:8])


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + ".tmp")
    temp.write_text(data)
    temp.replace(path)


def locked(fn):
    @functools.wraps(fn)
    def inner(*args, **kwargs):
        DIR.mkdir(parents=True, exist_ok=True)
        with (DIR / "state.lock").open("a") as handle:
            fcntl.flock(handle, fcntl.LOCK_EX)
            return fn(*args, **kwargs)
    return inner


def short(gen, model):
    return {v: k for k, v in gen.MODELS.items()}.get(model, model)


def note_model(raw, model):
    """Remember which model drew a raw (run dir models.json), for sheet labels."""
    with _models_lock:
        path = raw.parent / "models.json"
        made = json.loads(path.read_text()) if path.exists() else {}
        made[raw.name] = model
        atomic_write(path, json.dumps(made, indent=1))


def made_by(raw):
    path = raw.parent / "models.json"
    return json.loads(path.read_text()).get(raw.name, "pro") if path.exists() else "pro"


def price(gen, item):
    return DISCOUNT * gen.price_inr(item["model"], item["size"])


def bucket(gen):
    return os.environ.get("AB_BUCKET") or f"gs://{os.environ.get('GOOGLE_CLOUD_PROJECT', gen.DEFAULT_PROJECT)}-ab-batch"


def storage(*args, quiet=False):
    return subprocess.run([GCLOUD, "storage", *map(str, args)], check=True, text=True,
                          capture_output=quiet).stdout


def read_queue():
    return [json.loads(l) for l in QUEUE.read_text().splitlines() if l.strip()] if QUEUE.exists() else []


def read_jobs():
    return json.loads(JOBS.read_text()) if JOBS.exists() else []


def write_jobs(jobs):
    DIR.mkdir(parents=True, exist_ok=True)
    atomic_write(JOBS, json.dumps(jobs, indent=1))


def write_queue(items):
    atomic_write(QUEUE, "".join(json.dumps(i) + "\n" for i in items))


@locked
def enqueue(gen, a, jobs):
    """Append jobs (missing raws) to the queue, skipping any already queued or in flight."""
    (DIR / "refs").mkdir(parents=True, exist_ok=True)
    busy = {i["raw"] for i in read_queue()} | {i["raw"] for j in read_jobs() if not j["fetched"] for i in j["items"]}
    argv, skip = [], False
    for arg in sys.argv[1:]:  # re-running must not delete raws again
        if not skip and not arg.startswith("--only"):
            argv.append(arg)
        skip = arg == "--only"
    new = []
    for job in jobs:
        if str(job["raw"]) in busy:
            continue
        refs = []
        for data in job["refs"]:
            name = f"{hashlib.sha1(data).hexdigest()[:20]}.png"
            if not (DIR / "refs" / name).exists():
                (DIR / "refs" / name).write_bytes(data)
            refs.append(name)
        new.append({"raw": str(job["raw"]), "model": job["model"], "size": a.size, "aspect": job.get("aspect", "1:1"),
                    "prompt": job["prompt"], "refs": refs, "argv": argv, "cwd": os.getcwd()})
    write_queue(read_queue() + new)
    queue = read_queue()
    print(f"queued {len(new)} request(s), ~Rs{sum(price(gen, i) for i in new):.0f} at batch price"
          f"{f' ({len(jobs) - len(new)} already queued/in flight)' if len(jobs) > len(new) else ''}; "
          f"queue: {len(queue)} (~Rs{sum(price(gen, i) for i in queue):.0f}).  Run: python -m ab batch submit",
          flush=True)


def request(item, gs, label):
    if item["size"] != "1K":
        raise ValueError("Vertex image batches support 1K only; re-prepare this request at 1K")
    parts = [{"fileData": {"fileUri": f"{gs}/refs/{r}", "mimeType": "image/png"}} for r in item["refs"]]
    return {"contents": [{"role": "user", "parts": parts + [{"text": item["prompt"]}]}],
            "generationConfig": {"responseModalities": ["TEXT", "IMAGE"],
                                 "imageConfig": {"aspectRatio": item["aspect"], "imageSize": item["size"]}},
            "labels": {"ab": label}}


def fingerprint(req):
    """All string values of a request except labels: identical requests are interchangeable."""
    out = []
    walk = lambda v: (out.append(v) if isinstance(v, str) else [walk(x) for x in v] if isinstance(v, list)
                      else [walk(x) for k, x in v.items() if k != "labels"] if isinstance(v, dict) else None)
    walk(req)
    return "\n".join(sorted(out))


def image_of(response):
    parts = [p for c in (response or {}).get("candidates", []) for p in (c.get("content") or {}).get("parts", [])]
    data = [(p.get("inlineData") or p.get("inline_data") or {}).get("data") for p in parts if not p.get("thought")]
    data = [d for d in data if d]
    return base64.b64decode(data[-1]) if data else None


@locked
def submit(a, gen):
    jobs = read_jobs()
    busy = {i["raw"] for j in jobs if not j["fetched"] for i in j["items"]}
    queue = [i for i in read_queue() if i["raw"] not in busy and not Path(i["raw"]).exists()]
    write_queue(queue)
    if not queue:
        raise SystemExit("queue is empty: add --batch to a sprite/frames/texture/ui command first")
    for item in queue:
        item["model"] = gen.MODELS.get(a.model, a.model) if a.model else item["model"]
    cost = sum(price(gen, i) for i in queue)
    if gen.spent_inr() + cost > gen.BUDGET_INR:
        raise SystemExit(f"budget cap: spent ~Rs{gen.spent_inr():.0f} + ~Rs{cost:.0f} > Rs{gen.BUDGET_INR:.0f}")
    gs = bucket(gen)
    if any(i["refs"] for i in queue):
        storage("rsync", DIR / "refs", f"{gs}/refs", quiet=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    for model in dict.fromkeys(i["model"] for i in queue):
        items = [i for i in queue if i["model"] == model]
        tag = f"{PREFIX}-{stamp}-{short(gen, model)}-{uuid.uuid4().hex[:8]}"
        (DIR / tag).mkdir(parents=True, exist_ok=True)
        lines = [json.dumps({"request": request(i, gs, f"r{n}")}) for n, i in enumerate(items)]
        (DIR / tag / "requests.jsonl").write_text("\n".join(lines) + "\n")
        storage("cp", DIR / tag / "requests.jsonl", f"{gs}/{tag}/requests.jsonl", quiet=True)
        job = gen.client().batches.create(model=model, src=f"{gs}/{tag}/requests.jsonl",
                                          config={"dest": f"{gs}/{tag}/out", "display_name": f"ab-{tag}"})
        c = sum(price(gen, i) for i in items)
        gen._ledger(c)  # charged up front at batch price; failures are refunded on fetch
        jobs.append({"name": job.name, "tag": tag, "model": model, "cost": round(c, 2), "fetched": False,
                     "bucket": gs, "state": job.state.name if job.state else "?", "items": items})
        write_jobs(jobs)
        submitted = {i["raw"] for i in items}
        queue = [i for i in queue if i["raw"] not in submitted]
        write_queue(queue)  # save every successful model lane before trying the next
        print(f"submitted {len(items)} x {short(gen, model)} as {job.name} (~Rs{c:.0f})")
    print("check with: python -m ab batch status   (fetch when done, or: python -m ab batch wait)")


def refresh(gen, jobs):
    """Update the state of unfetched jobs from Vertex; -> those that finished."""
    done = []
    for job in jobs:
        if job["fetched"]:
            continue
        remote = gen.client().batches.get(name=job["name"])
        job["state"] = remote.state.name
        stats = remote.completion_stats
        job["stats"] = (f"{stats.successful_count or 0} ok, {stats.failed_count or 0} failed, "
                        f"{stats.incomplete_count or 0} pending") if stats else ""
        job["successful_count"] = stats.successful_count or 0 if stats else None
        job["error"] = str(remote.error.message) if remote.error else ""
        if job["state"] in DONE:
            done.append(job)
    write_jobs(jobs)
    return done


@locked
def status(a, gen):
    queue, jobs = read_queue(), read_jobs()
    print(f"queue: {len(queue)} request(s), ~Rs{sum(price(gen, i) for i in queue):.0f}")
    refresh(gen, jobs)
    for job in [j for j in jobs if not j["fetched"]] or jobs[-3:]:
        print(f"{job['tag']:24} {len(job['items']):3} x {short(gen, job['model']):5} {job['state'].removeprefix('JOB_STATE_')}"
              f"{'  ' + job.get('stats', '') if job.get('stats') else ''}{'  fetched' if job['fetched'] else ''}"
              f"{'  ' + job['error'] if job.get('error') else ''}")


@locked
def fetch(a, gen):
    jobs = read_jobs()
    done, reruns = refresh(gen, jobs), {}
    done += [j for j in jobs if j["fetched"] and j.get("clean_pending")]
    if not done:
        print("nothing finished yet" if any(not j["fetched"] for j in jobs) else "nothing to fetch")
    for job in done:
        gs = job.get("bucket", bucket(gen))
        local = DIR / job["tag"]
        local.mkdir(parents=True, exist_ok=True)
        rows = []
        try:
            storage("cp", "-r", f"{gs}/{job['tag']}/out", local, quiet=True)
        except subprocess.CalledProcessError:
            if job["state"] == "JOB_STATE_CANCELLED" and job.get("successful_count") == 0:
                refund = [i for i in job["items"] if not i.get("refunded") and not i.get("done")]
                if refund:
                    gen._ledger(-sum(price(gen, i) for i in refund))
                for i in refund:
                    i.update(error="cancelled before completion", refunded=True)
                job.update(fetched=True, clean_pending=False)
                write_jobs(jobs)
                print(f"  {job['tag']}: cancelled with no completed images; reservation refunded")
                continue
            job["fetch_error"] = "output download failed; retry ab batch fetch"
            write_jobs(jobs)
            print(f"  {job['tag']}: {job['fetch_error']}")
            continue
        for path in (local / "out").rglob("*.jsonl"):
            rows += [json.loads(l) for l in path.read_text().splitlines() if l.strip()]
        items = job["items"]
        by_label = {f"r{n}": i for n, i in enumerate(items)}
        by_print = {}
        for n, i in enumerate(items):
            by_print.setdefault(fingerprint(request(i, gs, f"r{n}")), []).append(i)
        for row in rows:
            req = row.get("request") or {}
            item = by_label.get((req.get("labels") or {}).get("ab"))
            if item and (item.get("done") or item.get("error")):
                continue
            if not item:
                item = next((i for i in by_print.get(fingerprint(req), [])
                             if not i.get("done") and not i.get("error")), None)
            if not item:
                continue
            data = image_of(row.get("response"))
            if data:
                raw = Path(item["raw"])
                raw.parent.mkdir(parents=True, exist_ok=True)
                temp = raw.with_suffix(".download.png")
                temp.write_bytes(data)
                from PIL import Image
                with Image.open(temp) as im:
                    im.verify()
                temp.replace(raw)
                note_model(Path(item["raw"]), short(gen, job["model"]))
                item["done"] = True
            else:
                item["error"] = str(row.get("status") or "no image")[:300]
            write_jobs(jobs)
        failed = [i for i in items if i.get("error") and not i.get("done")]
        missing = [i for i in items if not i.get("done") and not i.get("error")]
        for i in failed:
            print(f"  failed: {i['raw']}: {i.get('error', 'no result')}")
        refund = [i for i in failed if not i.get("refunded")]
        if refund:
            gen._ledger(-sum(price(gen, i) for i in refund))
            for i in refund:
                i["refunded"] = True
        job["fetched"] = not missing
        job["clean_pending"] = True
        job.pop("fetch_error", None)
        write_jobs(jobs)
        print(f"{job['tag']}: {sum(bool(i.get('done')) for i in items)} image(s) written, "
              f"{len(failed)} failed, {len(missing)} missing (retry fetch)")
        for i in items:
            argv = list(i["argv"])
            if "--batch" not in argv:
                argv.append("--batch")
            reruns[json.dumps([i["cwd"], argv])] = (i["cwd"], argv)
    # Release the state lock before cleaning subprocesses enqueue missing frames.
    # Cleaning is persisted as pending so the next fetch also resumes a crashed clean.
    return list(reruns.values())


def fetch_and_clean(a, gen):
    reruns = fetch(a, gen)
    succeeded = True
    for cwd, argv in reruns:  # all raws cached -> cleaning only; failed ones go back on the queue
        print(f"re-running: python -m ab {' '.join(argv)}", flush=True)
        succeeded &= subprocess.run([sys.executable, "-m", "ab", *argv], cwd=cwd).returncode == 0
    if succeeded and reruns:
        finish_clean()


@locked
def finish_clean():
    jobs = read_jobs()
    for job in jobs:
        if job["fetched"]:
            job["clean_pending"] = False
    write_jobs(jobs)


def wait(a, gen):
    while True:
        jobs = read_jobs()
        refresh(gen, jobs)
        running = [j for j in jobs if not j["fetched"] and j["state"] not in DONE]
        if not running:
            break
        print(time.strftime("%H:%M"), "; ".join(f"{j['tag']} {j['state'].removeprefix('JOB_STATE_')} "
                                                f"{j.get('stats', '')}" for j in running), flush=True)
        time.sleep(a.every)
    fetch_and_clean(a, gen)


@locked
def clear(a, gen):
    n = len(read_queue())
    QUEUE.unlink(missing_ok=True)
    print(f"dropped {n} queued request(s)")


def doctor(gen):
    gs = bucket(gen)
    try:
        storage("buckets", "describe", gs, quiet=True)
        print("batch bucket:", gs, "ok")
    except Exception:
        print("batch bucket:", gs, "MISSING -> ./setup.sh")
    jobs = read_jobs()
    refresh(gen, jobs)
    print(f"batch: {len(read_queue())} queued, {sum(not j['fetched'] for j in jobs)} job(s) not fetched")
    for j in [j for j in jobs if not j["fetched"]]:
        print(f"  {j['tag']} {len(j['items'])} x {short(gen, j['model'])} {j['state']} {j.get('stats', '')}")
