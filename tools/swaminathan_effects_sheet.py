"""Contact sheet of Swaminathan's packaged effect frames -> docs/screenshots/swaminathan/effects-sheet.png

~/ml/bin/python tools/swaminathan_effects_sheet.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "assets/sprites/swaminathan/effects"
OUT = ROOT / "docs/screenshots/swaminathan/effects-sheet.png"

rows = []
for folder in sorted(p for p in GAME.iterdir() if p.is_dir()):
    frames = [Image.open(p).convert("RGBA") for p in sorted(folder.glob("[0-9][0-9].png"))]
    if frames:
        rows.append((folder.name, frames))
# Tall effects (bolts, pillars) are laid on their side so the sheet stays readable.
rows = [(n, [f.transpose(Image.Transpose.ROTATE_270) if f.height > 3 * f.width else f for f in fs]) for n, fs in rows]
scale = 2
width = max(sum(f.width * scale + 16 for f in fs) for _, fs in rows) + 180
height = sum(max(f.height for f in fs) * scale + 24 for _, fs in rows) + 16
sheet = Image.new("RGBA", (width, height), (41, 30, 50, 255))
draw = ImageDraw.Draw(sheet)
y = 12
for name, frames in rows:
    draw.text((8, y + 4), f"{name} ({len(frames)})", fill=(255, 212, 88, 255))
    x = 170
    for frame in frames:
        big = frame.resize((frame.width * scale, frame.height * scale), Image.Resampling.NEAREST)
        sheet.alpha_composite(big, (x, y))
        x += big.width + 16
    y += max(f.height for f in frames) * scale + 24
OUT.parent.mkdir(parents=True, exist_ok=True)
sheet.save(OUT)
print(OUT)
