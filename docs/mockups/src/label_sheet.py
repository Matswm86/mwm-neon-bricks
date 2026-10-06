"""Crop the element render and add labels. python3 label_sheet.py <raw.png> <labels.json> <out.png>"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FONT = str(Path(__file__).resolve().parents[3] / "assets/fonts/Fredoka.ttf")
raw = Image.open(sys.argv[1]).convert("RGB")
labels = json.load(open(sys.argv[2]))
x0, y0, x1, y1 = 40, 300, 1800, 1480
im = raw.crop((x0, y0, x1, y1))
d = ImageDraw.Draw(im)
f = ImageFont.truetype(FONT, 23)
offs = {"Net": 70, "Paddle": 64, "Ball": 70, "Komet": 70}
for it in labels:
    lab = it["label"]
    dy = next((v for k, v in offs.items() if lab.startswith(k)), 62)
    if lab.startswith("Ball") or lab.startswith("Komet"):
        dy = 78
    x, y = it["x"] - x0, it["y"] - y0 + dy
    # long labels on the brick-type row get two lines
    if lab.startswith("Net") and "0 charges" not in lab:
        x += 222
    if "#" in lab:
        lines = lab.split(" ")
    else:
        words = lab.split(": ")
        lines = [words[0]] + (words[1].split(", ") if len(words) > 1 else [])
        if lines[0] == "Double hit once":
            lines = ["Double, hit once", "one dot + crack"]
    for i, ln in enumerate(lines):
        w = d.textlength(ln, font=f)
        d.text((x - w / 2, y + i * 32), ln, font=f, fill=(244, 240, 255))
im.save(sys.argv[3])
print(im.size)
