"""2D overlays on the Blender render: home disc, zone check, win card.

python3 docs/mockups/src/overlay.py <raw_render.png> <out_dir>
Writes world1_mock.png, world1_zones.png, wincard_mock.png.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

INK = (36, 33, 29)
WHITE = (255, 255, 255)
CARD = (255, 248, 238)  # warm white card
CARD_EDGE = (143, 131, 113)
SUN = (255, 201, 60)
TANGERINE = (255, 138, 61)
CYAN = (46, 230, 255)
SS = 3  # supersample factor for smooth vector shapes


def big(img):
    return img.resize((img.width * SS, img.height * SS), Image.LANCZOS)


def small(img, size):
    return img.resize(size, Image.LANCZOS)


def disc(d, cx, cy, r, fill, ring=None, ring_w=0):
    s = SS
    if ring:
        d.ellipse([(cx - r) * s, (cy - r) * s, (cx + r) * s, (cy + r) * s], fill=ring)
        r2 = r - ring_w
        d.ellipse([(cx - r2) * s, (cy - r2) * s, (cx + r2) * s, (cy + r2) * s], fill=fill)
    else:
        d.ellipse([(cx - r) * s, (cy - r) * s, (cx + r) * s, (cy + r) * s], fill=fill)


def poly(d, pts, fill):
    d.polygon([(x * SS, y * SS) for x, y in pts], fill=fill)


def house(d, cx, cy, size, col):
    h = size
    poly(d, [(cx, cy - h * 0.5), (cx + h * 0.52, cy - h * 0.02), (cx - h * 0.52, cy - h * 0.02)], col)
    d.rectangle([(cx - h * 0.36) * SS, (cy - h * 0.05) * SS, (cx + h * 0.36) * SS, (cy + h * 0.5) * SS], fill=col)
    d.rectangle([(cx - h * 0.11) * SS, (cy + h * 0.15) * SS, (cx + h * 0.11) * SS, (cy + h * 0.5) * SS], fill=CARD)


def home_disc(d):
    # same size and place as the MWM Play shell disc (dia 136, centre 104,104, 5 px ink ring)
    disc(d, 104, 104, 68, WHITE, ring=INK, ring_w=5)
    house(d, 104, 106, 68, INK)


def star(d, cx, cy, r_out, r_in, col):
    import math

    pts = []
    for i in range(10):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(-90 + 36 * i)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    poly(d, pts, col)


def replay_icon(d, cx, cy, r, col, w=16):
    import math

    s = SS
    start, end = 40, 300  # PIL angles grow clockwise on screen
    d.arc([(cx - r) * s, (cy - r) * s, (cx + r) * s, (cy + r) * s], start=start, end=end, fill=col, width=w * s)
    a = math.radians(end)
    ex, ey = cx + r * math.cos(a), cy + r * math.sin(a)
    tx, ty = -math.sin(a), math.cos(a)  # clockwise tangent
    nx, ny = math.cos(a), math.sin(a)
    poly(d, [(ex + tx * 30, ey + ty * 30), (ex - tx * 4 + nx * 26, ey - ty * 4 + ny * 26), (ex - tx * 4 - nx * 26, ey - ty * 4 - ny * 26)], col)


def map_icon(d, cx, cy, col):
    # three level dots joined by a road: the map
    s = SS
    pts = [(cx - 44, cy + 34), (cx, cy - 6), (cx + 44, cy - 38)]
    d.line([(x * s, y * s) for x, y in pts], fill=col, width=12 * s)
    for x, y in pts:
        disc(d, x, y, 17, col)


def next_icon(d, cx, cy, col):
    poly(d, [(cx - 30, cy - 46), (cx + 42, cy), (cx - 30, cy + 46)], col)


def main():
    raw = Path(sys.argv[1])
    out = Path(sys.argv[2])
    base = Image.open(raw).convert("RGB")
    W, H = base.size

    # 1. gameplay mock with the stand-alone home disc
    im = big(base)
    d = ImageDraw.Draw(im)
    home_disc(d)
    mock = small(im, (W, H))
    mock.save(out / "world1_mock.png")

    # 2. zone check
    z = mock.convert("RGBA")
    ov = Image.new("RGBA", z.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(ov)
    od.rectangle([0, 0, 232, 232], outline=(255, 255, 255, 255), width=4, fill=(255, 255, 255, 40))
    od.rectangle([0, 960, 1080, 1664], outline=(80, 255, 120, 255), width=4, fill=(80, 255, 120, 30))
    od.rectangle([0, 1664, 1080, 1920], outline=(255, 60, 60, 255), width=4, fill=(255, 60, 60, 60))
    od.rectangle([40, 280, 1040, 1700], outline=(255, 230, 0, 255), width=2)
    z = Image.alpha_composite(z, ov).convert("RGB")
    z.save(out / "world1_zones.png")

    # 3. win card: scene dimmed to 45%, warm white card, star, three icon discs at y 1300
    dim = Image.blend(base, Image.new("RGB", base.size, (10, 6, 24)), 0.55).filter(ImageFilter.GaussianBlur(3))
    im = big(dim)
    d = ImageDraw.Draw(im)
    home_disc(d)
    s = SS
    # card with soft shadow (drawn as a darker offset rect)
    d.rounded_rectangle([110 * s, 560 * s, 970 * s, 1470 * s], radius=56 * s, fill=(6, 3, 16))
    d.rounded_rectangle([100 * s, 540 * s, 980 * s, 1450 * s], radius=56 * s, fill=CARD, outline=CARD_EDGE, width=4 * s)
    # star burst: sun-yellow star with ink outline (shape, not colour, carries "done")
    star(d, 540, 820, 196, 84, INK)
    star(d, 540, 822, 180, 74, SUN)
    # tiny model placeholder of the level picture is rendered in-engine; mark the slot
    for i, x in enumerate(range(400, 700, 60)):
        d.rounded_rectangle([x * s, 1060 * s, (x + 52) * s, 1086 * s], radius=6 * s, fill=(255, 138, 61) if i % 2 else (255, 201, 60), outline=INK, width=2 * s)
    # icon discs: replay (270, 200), map (540, 200), next (810, 240)
    disc(d, 270, 1300, 100, WHITE, ring=INK, ring_w=6)
    replay_icon(d, 270, 1300, 52, INK)
    disc(d, 540, 1300, 100, WHITE, ring=INK, ring_w=6)
    map_icon(d, 540, 1300, INK)
    disc(d, 810, 1300, 120, TANGERINE, ring=INK, ring_w=6)
    next_icon(d, 816, 1300, INK)
    card = small(im, (W, H))
    card.save(out / "wincard_mock.png")
    print("ok", out)


if __name__ == "__main__":
    main()
