"""Contact sheet per biome from tools/world_shots.gd output: one row per direction, one column per camera spot
(the last column of forest and palace is the boss arena).

~/ml/bin/python tools/world_sheet.py [shot dir]   ->  <shot dir>/<biome>-sheet.png
"""
import re
import sys
from collections import defaultdict
from pathlib import Path

from PIL import Image, ImageDraw

SHOTS = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "docs/screenshots/world"
LABEL = 24

rows = defaultdict(lambda: defaultdict(dict))
for path in sorted(SHOTS.glob("*.png")):
    match = re.fullmatch(r"(forest|river|palace)-(.+)-(\d+)\.png", path.name)
    if match:
        rows[match[1]][match[2]][int(match[3])] = path

for biome, directions in rows.items():
    columns = max(n for spots in directions.values() for n in spots)
    CELL = (640, 360) if columns <= 4 else (480, 270)
    sheet = Image.new("RGB", (CELL[0] * columns, (CELL[1] + LABEL) * len(directions)), (16, 16, 16))
    draw = ImageDraw.Draw(sheet)
    for row, (direction, spots) in enumerate(sorted(directions.items())):
        top = row * (CELL[1] + LABEL)
        draw.text((8, top + 6), f"{biome} / {direction}", fill=(240, 240, 240))
        for n, path in spots.items():
            shot = Image.open(path).convert("RGB").resize(CELL, Image.Resampling.LANCZOS)
            sheet.paste(shot, ((n - 1) * CELL[0], top + LABEL))
    out = SHOTS / f"{biome}-sheet.png"
    sheet.save(out)
    print("saved", out)
