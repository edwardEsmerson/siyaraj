"""Vertex batch prediction: `--batch` queues requests here, `ab batch submit/status/fetch/wait` runs them.

Batch costs ~50% of live and has its own capacity (no 429s), but takes minutes to hours. Queue entries
keep the command's argv; fetch writes the raws and re-runs those commands, which then only clean (free)."""
import base64
import hashlib
import json
import os
import shutil
import subprocess
import sys
import threading
import time
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


def short(gen, model):
    return {v: k for k, v in gen.MODELS.items()}.get(model, model)


def note_model(raw, model):
    """Remember which model drew a raw (run dir models.json), for sheet labels."""
    with _models_lock:
        path = raw.parent / "models.json"
        made = json.loads(path.read_text()) if path.exists() else {}
        made[raw.name] = model
        path.write_text(json.dumps(made, indent=1))


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
    JOBS.write_text(json.dumps(jobs, indent=1))


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
    with open(QUEUE, "a") as f:
        f.writelines(json.dumps(i) + "\n" for i in new)
    queue = read_queue()
    print(f"queued {len(new)} request(s), ~Rs{sum(price(gen, i) for i in new):.0f} at batch price"
          f"{f' ({len(jobs) - len(new)} already queued/in flight)' if len(jobs) > len(new) else ''}; "
          f"queue: {len(queue)} (~Rs{sum(price(gen, i) for i in queue):.0f}).  Run: python -m ab batch submit",
          flush=True)


def request(item, gs, label):
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


def submit(a, gen):
    queue = read_queue()
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
    jobs, stamp = read_jobs(), time.strftime("%Y%m%d-%H%M%S")
    for model in dict.fromkeys(i["model"] for i in queue):
        items = [i for i in queue if i["model"] == model]
        tag = f"{stamp}-{short(gen, model)}"
        (DIR / tag).mkdir(parents=True, exist_ok=True)
        lines = [json.dumps({"request": request(i, gs, f"r{n}")}) for n, i in enumerate(items)]
        (DIR / tag / "requests.jsonl").write_text("\n".join(lines) + "\n")
        storage("cp", DIR / tag / "requests.jsonl", f"{gs}/{tag}/requests.jsonl", quiet=True)
        job = gen.client().batches.create(model=model, src=f"{gs}/{tag}/requests.jsonl",
                                          config={"dest": f"{gs}/{tag}/out", "display_name": f"ab-{tag}"})
        c = sum(price(gen, i) for i in items)
        gen._ledger(c)  # charged up front at batch price; failures are refunded on fetch
        jobs.append({"name": job.name, "tag": tag, "model": model, "cost": round(c, 2), "fetched": False,
                     "state": job.state.name if job.state else "?", "items": items})
        write_jobs(jobs)
        print(f"submitted {len(items)} x {short(gen, model)} as {job.name} (~Rs{c:.0f})")
    QUEUE.write_text("")
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
        job["error"] = str(remote.error.message) if remote.error else ""
        if job["state"] in DONE:
            done.append(job)
    write_jobs(jobs)
    return done


def status(a, gen):
    queue, jobs = read_queue(), read_jobs()
    print(f"queue: {len(queue)} request(s), ~Rs{sum(price(gen, i) for i in queue):.0f}")
    refresh(gen, jobs)
    for job in [j for j in jobs if not j["fetched"]] or jobs[-3:]:
        print(f"{job['tag']:24} {len(job['items']):3} x {short(gen, job['model']):5} {job['state'].removeprefix('JOB_STATE_')}"
              f"{'  ' + job.get('stats', '') if job.get('stats') else ''}{'  fetched' if job['fetched'] else ''}"
              f"{'  ' + job['error'] if job.get('error') else ''}")


def fetch(a, gen):
    jobs = read_jobs()
    done, gs, reruns = refresh(gen, jobs), bucket(gen), {}
    if not done:
        print("nothing finished yet" if any(not j["fetched"] for j in jobs) else "nothing to fetch")
    for job in done:
        local = DIR / job["tag"]
        rows = []
        try:
            storage("cp", "-r", f"{gs}/{job['tag']}/out", local, quiet=True)
        except subprocess.CalledProcessError:
            print(f"  {job['tag']}: no output files ({job['state']} {job.get('error', '')})")
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
            if not item or "done" in item:
                item = next((i for i in by_print.get(fingerprint(req), []) if "done" not in i), None)
            if not item:
                continue
            data = image_of(row.get("response"))
            if data:
                Path(item["raw"]).write_bytes(data)
                note_model(Path(item["raw"]), short(gen, job["model"]))
                item["done"] = True
            else:
                item["error"] = str(row.get("status") or "no image")[:300]
        failed = [i for i in items if "done" not in i]
        for i in failed:
            print(f"  failed: {i['raw']}: {i.get('error', 'no result')}")
        if failed:
            gen._ledger(-sum(price(gen, i) for i in failed))  # not billed: refund the up-front estimate
        job["fetched"] = True
        write_jobs(jobs)
        print(f"{job['tag']}: {len(items) - len(failed)} image(s) written, {len(failed)} failed")
        for i in items:
            reruns[json.dumps([i["cwd"], i["argv"]])] = (i["cwd"], i["argv"])
    for cwd, argv in reruns.values():  # all raws cached -> cleaning only; failed ones go back on the queue
        print(f"re-running: python -m ab {' '.join(argv)}", flush=True)
        subprocess.run([sys.executable, "-m", "ab", *argv], cwd=cwd)


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
    fetch(a, gen)


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
