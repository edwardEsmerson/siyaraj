#!/usr/bin/env python3
"""Run every Godot regression script; script errors also fail the run."""
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
GODOT = os.environ.get("GODOT_BIN", "godot")
LOGS = ROOT / ".godot" / "checks"


def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    checks = sorted((ROOT / "tests").glob("*_check.gd"))
    failed = []
    for check in checks:
        command = [GODOT, "--headless", "--fixed-fps", "60", "--path", str(ROOT),
                   "--script", "res://tests/" + check.name]
        try:
            result = subprocess.run(command, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True,
                                    encoding="utf-8", errors="replace", timeout=180)
            output = result.stdout
            passed = (result.returncode == 0
                      and not re.search(r"SCRIPT ERROR:|ERROR:", output)
                      and re.search(r"PASS|0 failure\(s\)", output))
        except subprocess.TimeoutExpired as error:
            output = (error.stdout or b"").decode("utf-8", errors="replace") + "\nTIMEOUT\n"
            passed = False
        except OSError as error:
            print(f"Cannot run Godot: {error}. Set GODOT_BIN to its executable.")
            return 1
        (LOGS / (check.stem + ".log")).write_text(output, encoding="utf-8")
        print(f"{'PASS' if passed else 'FAIL'} {check.name}", flush=True)
        if not passed:
            failed.append(check.name)
            print(output[-6000:], flush=True)
    print(f"{len(checks) - len(failed)}/{len(checks)} checks passed. Logs: {LOGS}")
    return 1 if failed or not checks else 0


if __name__ == "__main__":
    sys.exit(main())
