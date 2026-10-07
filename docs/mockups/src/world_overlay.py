"""Add the home disc to a world mock render. python3 world_overlay.py <raw.png> <out.png>"""

import sys

from PIL import Image, ImageDraw

sys.path.insert(0, __file__.rsplit("/", 1)[0])
import overlay as O  # noqa: E402

raw = Image.open(sys.argv[1]).convert("RGB")
big = O.big(raw)
d = ImageDraw.Draw(big)
O.home_disc(d)
O.small(big, raw.size).save(sys.argv[2])
