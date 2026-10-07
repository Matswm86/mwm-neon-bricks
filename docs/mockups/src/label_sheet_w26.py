"""Label the worlds 2-6 element render. python3 label_sheet_w26.py <raw.png> <labels.json> <out.png>"""

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FONT = str(Path(__file__).resolve().parents[3] / "assets/fonts/Fredoka.ttf")
raw = Image.open(sys.argv[1]).convert("RGB")
labels = json.loads(Path(sys.argv[2]).read_text())
im = raw
d = ImageDraw.Draw(im)
f = ImageFont.truetype(FONT, 25)
for it in labels:
    lab = it["label"]
    dy = 105 if lab.startswith("Boss") else (80 if lab.startswith(("Portal", "Capsule", "Paddle")) else 62)
    lines = lab.split(": ")
    for i, ln in enumerate(lines):
        w = d.textlength(ln, font=f)
        d.text((it["x"] - w / 2, it["y"] + dy + i * 31), ln, font=f, fill=(244, 240, 255))
im.save(sys.argv[3])
print(im.size)
