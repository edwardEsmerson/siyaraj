"""Compose the in-engine C2 screenshots into a labeled review sheet."""
from pathlib import Path
from PIL import Image, ImageDraw

directory = Path(__file__).resolve().parents[1] / "docs/screenshots/siya"
shots = sorted(directory.glob("[0-9][0-9]-*.png"))
sheet = Image.new("RGB", (1600, ((len(shots) + 3) // 4) * 204), "#171b25")
draw = ImageDraw.Draw(sheet)
for index, path in enumerate(shots):
    x, y = (index % 4) * 400, (index // 4) * 204
    with Image.open(path) as shot:
        shot.thumbnail((384, 176), Image.Resampling.NEAREST)
        sheet.paste(shot, (x + (400 - shot.width) // 2, y + 4))
    draw.text((x + 8, y + 185), path.stem, fill="white")
sheet.save(directory / "review-sheet.png")
print(directory / "review-sheet.png")
