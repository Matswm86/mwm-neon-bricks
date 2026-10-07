"""Pacing sim for MWM Neon Bricks, action pass 2026-10-06 (design aid, not game code).

Extends tools/clear_time_sim.py with: Triple, Nova chains, Glider, marching blocks,
mini-boss, Ekko, Bredvinge, Neonpuls, combo-drop capsules, progress speed ramp and the
finale helper. Reports clear time AND pacing: breaks per second, longest gap between
breaks, and how long the last 3 bricks take.

Usage:
  python3 tools/action_sim.py            # baseline (old world 1) + new levels 1-15
  python3 tools/action_sim.py --runs 40  # fewer runs, faster
  python3 tools/action_sim.py --levels 1 2 3

The paddle bot hits every ball it can reach (tracks at up to 2500 px/s, random contact
offset up to 60% of the half width) and moves toward a falling capsule while the ball
rises. Real players are slower; treat times as floors. Nets are unlimited in the sim.
"""

import argparse
import math
import random
import statistics

FL, FR, FT = 40.0, 1040.0, 280.0
PADDLE_Y, PADDLE_H = 1420.0, 36.0
PTOP = PADDLE_Y - PADDLE_H / 2
NET_Y = 1540.0
CELL_W, CELL_H, GX, GY = 100.0, 52.0, 40.0, 340.0
BW, BH = 92.0, 44.0
R = 22.0
DT = 1 / 60
SIN20 = math.sin(math.radians(20))
SIN6 = math.sin(math.radians(6))

# ------------------------------------------------------------------ level data
# Old world 1 (GDD 6.4 as shipped in the slice), old rules.
OLD = {
    1: dict(
        rows=["..........", "..........", "..........", "..........", ".GGGGGGGG.", "..GGGGGG.."],
        carriers=[],
    ),
    2: dict(
        rows=["..........", "..........", "..........", ".GDDGGDDG.", ".GDDGGDDG.", "..GGGGGG.."],
        carriers=[],
    ),
    3: dict(
        rows=["..........", "..........", "GGGGGGGGGG", "GGDDGGDDGG", "GGGGGGGGGG", "..g....g.."],
        carriers=["komet"],
    ),
    4: dict(
        rows=[
            "..........",
            "..........",
            "GGGGGGGGGG",
            ".GGGGGGGG.",
            "..........",
            "C...CC...C",
            "..........",
            "..dD..Dd..",
        ],
        carriers=["komet"],
    ),
    5: dict(
        rows=[
            "..........",
            "..........",
            "..GGGGGG..",
            ".GGGGGGGG.",
            "..........",
            ".DDDDDDDD.",
            "..........",
            "..GgGGgG..",
        ],
        carriers=["komet"],
    ),
}
for _v in OLD.values():
    _v.update(lett=520, vanlig=680, paddle=280, bonus=[])

W1 = dict(lett=520, vanlig=720, paddle=280)
W2 = dict(lett=530, vanlig=760, paddle=280)
W3 = dict(lett=540, vanlig=800, paddle=260)

NEW = {
    # ---- World 1 Neonstranda (net unlimited in both settings)
    1: dict(
        W1,
        carriers=["komet"],
        bonus=["komet"],
        rows=[
            "..........",
            "..........",
            "..........",
            ".GGGGGGGG.",
            "GGGGGGGGGG",
            ".GGgGGgGG.",
            "..GGGGGG..",
        ],
    ),
    2: dict(
        W1,
        carriers=["komet"],
        bonus=["komet"],
        rows=[
            "..........",
            "..........",
            ".GGGGGGGG.",
            "GDDGGGGDDG",
            "GDDGGGGDDG",
            "GGGGggGGGG",
            ".GG....GG.",
            "..GGGGGG..",
        ],
    ),
    3: dict(
        W1,
        carriers=["komet"],
        bonus=["komet"],
        rows=[
            "..........",
            "..........",
            "GGGGGGGGGG",
            "GGNGGGGNGG",
            "GGGGGGGGGG",
            "GDGGNNGGDG",
            "GGGGGGGGGG",
            "..g....g..",
        ],
    ),
    4: dict(
        W1,
        carriers=["ekko"],
        bonus=["komet", "ekko"],
        rows=[
            "..........",
            "..........",
            "DDDDDDDDDD",
            "GGNGGGGNGG",
            "GGGGDDGGGG",
            ".GGGGGGGG.",
            "..........",
            "..gG..Gg..",
        ],
    ),
    5: dict(
        W1,
        carriers=["ekko", "komet"],
        bonus=["komet", "ekko"],
        boss=dict(hp=(10, 14), speed=(60, 90), minions=False),
        rows=[
            "..........",
            "...K++....",
            "...+++....",
            "..........",
            ".GGGGGGGG.",
            ".DDGNNGDD.",
            "..........",
            "..gGGGGg..",
        ],
    ),
    # ---- World 2 Rutenettbyen
    6: dict(
        W2,
        carriers=["komet", "ekko"],
        bonus=["komet", "ekko"],
        rows=[
            "..........",
            "..........",
            "....TT....",
            "...TNNT...",
            "..TGGGGT..",
            ".TGGNNGGT.",
            "TGGGGGGGGT",
            "..t....t..",
        ],
    ),
    7: dict(
        W2,
        carriers=["ekko", "komet"],
        bonus=["komet", "ekko"],
        rows=[
            "..........",
            "GGGGGGGGGG",
            "GNGGTTGGNG",
            "GGGGGGGGGG",
            "..........",
            ".M...M...m",
            "..........",
            "m...M...M.",
        ],
    ),
    8: dict(
        W2,
        carriers=["bredvinge"],
        bonus=["komet", "ekko", "bredvinge"],
        rows=[
            "..........",
            "GGGGGGGGGG",
            "GTGGNNGGTG",
            "GNGGGGGGNG",
            ".GGGDDGGG.",
            "..........",
            ".M..gg..M.",
        ],
    ),
    9: dict(
        W2,
        carriers=["bredvinge", "komet"],
        bonus=["komet", "ekko", "bredvinge"],
        rows=[
            "..........",
            "GGGGGGGGGG",
            "GNGGTTGGNG",
            "GGGGGGGGGG",
            "..........",
            "..C....C..",
            "..........",
            ".g.M..M.g.",
        ],
    ),
    10: dict(
        W2,
        carriers=["bredvinge", "ekko"],
        bonus=["komet", "ekko", "bredvinge"],
        boss=dict(hp=(14, 20), speed=(80, 120), minions=True),
        rows=[
            "..........",
            "...K++....",
            "...+++....",
            "..........",
            "..........",
            "GTGGNNGGTG",
            ".GGGGGGGG.",
            "..........",
            ".g..GG..g.",
        ],
    ),
    # ---- World 3 Arkadehallen
    11: dict(
        W3,
        carriers=["ekko", "komet"],
        bonus=["komet", "ekko", "bredvinge"],
        march=dict(rows=(1, 5), speed=(40, 70), step=26, floor_y=1000),
        rows=[
            "..........",
            "..GGGGGG..",
            "..GNGGNG..",
            "..TGGGGT..",
            "..GGGGGG..",
            "..GgGGgG..",
        ],
    ),
    12: dict(
        W3,
        carriers=["komet", "ekko"],
        bonus=["komet", "ekko", "bredvinge"],
        march=dict(rows=(1, 5), speed=(40, 70), step=26, floor_y=1000),
        rows=[
            "..........",
            ".GNGGGGNG.",
            ".GGTNNTGG.",
            ".NGGGGGGN.",
            ".GGGTTGGG.",
            ".GGgGGgGG.",
        ],
    ),
    13: dict(
        W3,
        carriers=["neonpuls"],
        bonus=["komet", "ekko", "neonpuls"],
        rows=[
            "..........",
            "TGGGGGGGGT",
            "GGNGTTGNGG",
            "TGGGGGGGGT",
            "GGGGNNGGGG",
            "DDGGGGGGDD",
            "..........",
            "M...nn...M",
        ],
    ),
    14: dict(
        W3,
        carriers=["ekko", "neonpuls"],
        bonus=["komet", "ekko", "bredvinge", "neonpuls"],
        march=dict(rows=(1, 5), speed=(40, 70), step=26, floor_y=900),
        rows=[
            "..........",
            "..TGNNGT..",
            "..GGGGGG..",
            "..GNTTNG..",
            "..GGGGGG..",
            "..DGGGGD..",
            "C...M....C",
            "..........",
            ".gC.GG.Cg.",
        ],
    ),
    15: dict(
        W3,
        carriers=["neonpuls", "ekko"],
        bonus=["komet", "ekko", "bredvinge", "neonpuls"],
        boss=dict(hp=(20, 30), speed=(0, 0), minions=True),
        march=dict(rows=(1, 5), speed=(40, 70), step=26, floor_y=800),
        rows=[
            "..........",
            "...K++....",
            ".T.+++..T.",
            ".GNGGGGNG.",
            ".GGGTTGGG.",
            ".DGGGGGGD.",
            "..........",
            "..gGNNGg..",
        ],
    ),
}

HP = {"G": 1, "D": 2, "T": 3, "N": 1, "M": 1, "C": -1}

# ------------------------------------------------------------------ rule sets
OLD_RULES = dict(time_ramp=True, progress_ramp=0.0, combo_drop=0, finale=0, combo_win=0.0)


def new_rules(easy):
    return dict(
        time_ramp=False,
        progress_ramp=0.0 if easy else 0.15,
        combo_drop=6 if easy else 8,
        finale=4 if easy else 3,
        combo_win=3.0 if easy else 2.0,
    )


class Brick:
    __slots__ = (
        "x",
        "y",
        "w",
        "h",
        "hp",
        "maxhp",
        "code",
        "carrier",
        "alive",
        "mover",
        "vx",
        "boss",
        "march",
    )

    def __init__(self, x, y, w, h, code, hp, carrier):
        self.x, self.y, self.w, self.h = x, y, w, h
        self.code, self.hp, self.maxhp, self.carrier = code, hp, hp, carrier
        self.alive, self.mover, self.vx, self.boss, self.march = True, False, 0.0, False, False

    def cx(self):
        return self.x + self.w / 2

    def cy(self):
        return self.y + self.h / 2


class Ball:
    __slots__ = ("x", "y", "vx", "vy", "echo", "life")

    def __init__(self, x, y, vx, vy, echo=False, life=0.0):
        self.x, self.y, self.vx, self.vy, self.echo, self.life = x, y, vx, vy, echo, life


class Sim:
    def __init__(self, lv, easy, rules, seed):
        self.rnd = random.Random(seed)
        self.lv, self.easy, self.rules = lv, easy, rules
        self.base = lv["lett"] if easy else lv["vanlig"]
        self.pw0 = 400.0 if easy else float(lv["paddle"])
        self.pw = self.pw0
        self.grid = {}
        self.movers = []
        self.all = []
        boss_cfg = lv.get("boss")
        march = lv.get("march")
        ci = 0
        for r, row in enumerate(lv["rows"]):
            for c, ch in enumerate(row):
                if ch in ".+":
                    continue
                x = GX + c * CELL_W + (CELL_W - BW) / 2
                y = GY + r * CELL_H + (CELL_H - BH) / 2
                if ch == "K":
                    b = Brick(
                        x,
                        y,
                        3 * CELL_W - 8,
                        2 * CELL_H - 8,
                        "K",
                        boss_cfg["hp"][0 if easy else 1],
                        None,
                    )
                    b.boss = True
                    sp = boss_cfg["speed"][0 if easy else 1]
                    b.vx = sp if sp else 0.0
                    b.mover = True
                else:
                    code = ch.upper()
                    car = None
                    if ch != code:
                        car = lv["carriers"][ci % len(lv["carriers"])]
                        ci += 1
                    b = Brick(x, y, BW, BH, code, HP[code], car)
                    if code == "M":
                        b.mover = True
                        b.vx = (80.0 if easy else 120.0) * (1 if c < 5 else -1)
                if march and march["rows"][0] <= r <= march["rows"][1]:
                    b.mover = True
                    b.march = True
                    if b.boss:
                        b.vx = 0.0
                if b.mover:
                    self.movers.append(b)
                else:
                    self.grid[(r, c)] = b
                self.all.append(b)
        self.march = march
        self.march_dir = 1
        self.boss_cfg = boss_cfg
        self.boss_phase = 0
        self.start_left = sum(1 for b in self.all if b.hp > 0)
        self.left = self.start_left
        self.t = 3.0
        a = math.radians(self.rnd.choice([-1, 1]) * self.rnd.uniform(10, 20))
        self.px = 540.0
        self.balls = [Ball(540.0, PTOP - 4 - R, math.sin(a), -math.cos(a))]
        self.off = self.rnd.uniform(-0.6, 0.6)
        self.komet, self.komet_t = 0, 0.0
        self.wide_t = 0.0
        self.puls = []  # times of pending pulse waves
        self.caps = []
        self.novas = []
        self.last_break = self.t
        self.assist_clock = self.t
        self.aim_next = False
        self.combo, self.combo_t, self.max_combo, self.bonus_i = 0, -9.0, 0, 0
        self.breaks = []
        self.caught = 0
        self.dropped = 0
        self.t_left3 = None
        self.home_tg = None

    # -------------------------------------------------------------- helpers
    def speed(self):
        s = self.base
        if self.rules["time_ramp"] and not self.easy:
            s *= min(1 + 0.02 * int((self.t - 3) / 15), 1.15)
        broken = 1 - self.left / self.start_left
        s *= 1 + self.rules["progress_ramp"] * broken
        return max(300.0, min(1000.0, s))

    def candidates(self, x, y):
        out = []
        c0, c1 = int((x - R - GX) // CELL_W), int((x + R - GX) // CELL_W)
        r0, r1 = int((y - R - GY) // CELL_H), int((y + R - GY) // CELL_H)
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                b = self.grid.get((r, c))
                if b is not None and b.alive:
                    out.append(b)
        for b in self.movers:
            if b.alive:
                out.append(b)
        return out

    @staticmethod
    def overlap(b, x, y):
        cx = min(max(x, b.x), b.x + b.w)
        cy = min(max(y, b.y), b.y + b.h)
        return (x - cx) ** 2 + (y - cy) ** 2 < R * R

    def drop(self, x, y, kind):
        if sum(1 for c in self.caps) >= 3:
            return
        self.caps.append([x, y, kind])
        self.dropped += 1

    def damage(self, b, n):
        if not b.alive or b.hp < 0:
            return
        b.hp -= n
        self.combo_tick()
        if b.boss:
            self.boss_hit(b)
        if b.hp <= 0:
            self.on_break(b)

    def combo_tick(self):
        w = self.rules["combo_win"]
        if not w:
            return
        self.combo = self.combo + 1 if self.t - self.combo_t <= w else 1
        self.combo_t = self.t
        self.max_combo = max(self.max_combo, self.combo)
        n = self.rules["combo_drop"]
        if n and self.combo % n == 0 and self.lv["bonus"]:
            kind = self.lv["bonus"][self.bonus_i % len(self.lv["bonus"])]
            self.bonus_i += 1
            self.drop(self.balls[0].x, self.balls[0].y, kind)

    def boss_hit(self, b):
        mx = b.maxhp
        phase = 0 if b.hp > 2 * mx / 3 else (1 if b.hp > mx / 3 else 2)
        while self.boss_phase < phase and b.hp > 0:
            self.boss_phase += 1
            b.vx *= 1.25
            self.drop(b.cx(), b.y + b.h, self.lv["bonus"][self.bonus_i % len(self.lv["bonus"])])
            self.bonus_i += 1
            if self.boss_cfg["minions"]:
                row = int((b.y + b.h - GY) // CELL_H) + 1
                c0 = int((b.x - GX) // CELL_W)
                placed = 0
                for c in range(max(0, c0 - 1), min(10, c0 + 4)):
                    if placed >= 4 or (row, c) in self.grid and self.grid[(row, c)].alive:
                        continue
                    nb = Brick(GX + c * CELL_W + 4, GY + row * CELL_H + 4, BW, BH, "G", 1, None)
                    if any(self.overlap(nb, bl.x, bl.y) for bl in self.balls):
                        continue
                    self.grid[(row, c)] = nb
                    self.all.append(nb)
                    self.left += 1
                    self.start_left += 1
                    placed += 1

    def on_break(self, b):
        b.alive = False
        self.left -= 1
        self.breaks.append(self.t)
        self.last_break = self.t
        self.assist_clock = self.t
        if self.left <= 3 and self.t_left3 is None:
            self.t_left3 = self.t
        if b.carrier:
            self.drop(b.cx(), b.y + b.h, b.carrier)
        if b.code == "N":
            self.novas.append((self.t + 0.15, b.cx(), b.cy()))

    def nova_fire(self, x, y):
        for b in list(self.all):
            if b.alive and b.hp > 0:
                if b.boss:
                    hit = abs(b.cx() - x) <= b.w / 2 + 60 and abs(b.cy() - y) <= b.h / 2 + 34
                else:
                    hit = abs(b.cx() - x) <= 110 and abs(b.cy() - y) <= 60
                if hit:
                    if b.code == "N" and b.hp == 1:
                        b.alive = False
                        self.left -= 1
                        self.breaks.append(self.t)
                        self.last_break = self.assist_clock = self.t
                        if self.left <= 3 and self.t_left3 is None:
                            self.t_left3 = self.t
                        self.combo_tick()
                        if b.carrier:
                            self.drop(b.cx(), b.y + b.h, b.carrier)
                        self.novas.append((self.t + 0.5, b.cx(), b.cy()))
                    else:
                        self.damage(b, 1)

    def nearest(self, x, y):
        best, bd = None, 1e18
        for b in self.all:
            if b.alive and b.hp > 0:
                d = (b.cx() - x) ** 2 + (b.cy() - y) ** 2
                if d < bd:
                    best, bd = b, d
        return best

    def clear_path(self, x0, y0, x1, y1):
        # Only chrome blocks: hitting any breakable brick on the way is progress.
        n = max(1, int(math.hypot(x1 - x0, y1 - y0) // 10))
        chrome = [b for b in self.all if b.alive and b.hp < 0]
        for i in range(1, n + 1):
            x = x0 + (x1 - x0) * i / n
            y = y0 + (y1 - y0) * i / n
            for b in chrome:
                if self.overlap(b, x, y):
                    return False
        return True

    def aim_point(self, x, y, direct_only=False):
        # Nearest breakable brick in sight; else a one-wall bank shot; else None.
        live = sorted(
            (b for b in self.all if b.alive and b.hp > 0),
            key=lambda b: (b.cx() - x) ** 2 + (b.cy() - y) ** 2,
        )
        for b in live:
            if self.clear_path(x, y, b.cx(), b.cy()):
                return b.cx(), b.cy()
        if direct_only:
            return None
        for b in live:
            for wall in (FL + R, FR - R):
                mx = 2 * wall - b.cx()
                k = (wall - x) / (mx - x) if mx != x else -1
                if not 0 < k < 1:
                    continue
                wy = y + (b.cy() - y) * k
                if self.clear_path(x, y, wall, wy) and self.clear_path(wall, wy, b.cx(), b.cy()):
                    return mx, b.cy()
        return None

    def apply(self, kind):
        self.caught += 1
        if kind == "komet":
            self.komet, self.komet_t = (10, 8.0) if self.easy else (8, 6.0)
        elif kind == "ekko":
            m = self.balls[0]
            sp = math.hypot(m.vx, m.vy) or 1
            for d in (-20, 20):
                a = math.radians(d)
                vx = (m.vx * math.cos(a) - m.vy * math.sin(a)) / sp
                vy = (m.vx * math.sin(a) + m.vy * math.cos(a)) / sp
                if vy > -0.3:
                    vy = -0.6
                self.balls.append(Ball(m.x, m.y, vx, vy, True, 10.0))
            # keep max 3 balls
            while len(self.balls) > 3:
                self.balls.pop(1)
        elif kind == "bredvinge":
            self.wide_t = 20.0 if self.easy else 15.0
        elif kind == "neonpuls":
            self.puls = [self.t + i * 1.0 for i in range(6)]

    def pulse(self):
        lo, hi = self.px - self.pw / 2, self.px + self.pw / 2
        for c in range(10):
            cx0, cx1 = GX + c * CELL_W, GX + (c + 1) * CELL_W
            if cx1 < lo or cx0 > hi:
                continue
            best = None
            for b in self.all:
                if (
                    b.alive
                    and b.hp > 0
                    and b.x < cx1
                    and b.x + b.w > cx0
                    and (best is None or b.y > best.y)
                ):
                    best = b
            if best is not None:
                self.damage(best, 1)

    # -------------------------------------------------------------- movers
    def move_movers(self):
        if self.march:
            sp = self.march["speed"][0 if self.easy else 1]
            mem = [b for b in self.movers if b.march and b.alive]
            if mem:
                for b in mem:
                    b.x += self.march_dir * sp * DT
                lo = min(b.x for b in mem)
                hi = max(b.x + b.w for b in mem)
                bounce = None
                if lo < FL + 4:
                    bounce = FL + 4 - lo
                elif hi > FR - 4:
                    bounce = FR - 4 - hi
                if bounce is not None:
                    self.march_dir *= -1
                    low = max(b.y + b.h for b in mem)
                    dy = (
                        self.march["step"]
                        if low + self.march["step"] <= self.march["floor_y"]
                        else 0
                    )
                    for b in mem:
                        b.x += bounce
                        b.y += dy
        for b in self.movers:
            if not b.alive or b.march or b.vx == 0:
                continue
            b.x += b.vx * DT
            hit = b.x < FL + 4 or b.x + b.w > FR - 4
            if not hit:
                for o in self.all:
                    if (
                        o is not b
                        and o.alive
                        and o.x < b.x + b.w
                        and o.x + o.w > b.x
                        and o.y < b.y + b.h
                        and o.y + o.h > b.y
                    ):
                        hit = True
                        break
            if hit:
                b.x -= b.vx * DT
                b.vx = -b.vx

    # -------------------------------------------------------------- frame
    def ball_step(self, bl, sp, sdt):
        for axis in (0, 1):
            if axis == 0:
                bl.x += bl.vx * sp * sdt
                if bl.x < FL + R:
                    bl.x, bl.vx = FL + R, abs(bl.vx)
                elif bl.x > FR - R:
                    bl.x, bl.vx = FR - R, -abs(bl.vx)
            else:
                bl.y += bl.vy * sp * sdt
                if bl.y < FT + R:
                    bl.y, bl.vy = FT + R, abs(bl.vy)
            solid = False
            hit_mover = False
            for b in self.candidates(bl.x, bl.y):
                if not self.overlap(b, bl.x, bl.y):
                    continue
                hit_mover = hit_mover or b.mover
                if b.hp < 0:
                    solid = True
                    j = math.radians(self.rnd.uniform(-3, 3))
                    bl.vx, bl.vy = (
                        bl.vx * math.cos(j) - bl.vy * math.sin(j),
                        bl.vx * math.sin(j) + bl.vy * math.cos(j),
                    )
                    continue
                if self.komet > 0 and not bl.echo and not b.boss:
                    self.komet -= 1
                    b.hp = 1
                    self.damage(b, 1)
                    continue
                if self.komet > 0 and not bl.echo and b.boss:
                    self.komet -= 1
                    self.damage(b, 2)
                    solid = True
                    continue
                self.damage(b, 1)
                solid = True
            if solid:
                if axis == 0:
                    bl.x -= bl.vx * sp * sdt
                    bl.vx = -bl.vx
                else:
                    bl.y -= bl.vy * sp * sdt
                    bl.vy = -bl.vy
                if hit_mover:  # push out of a moving brick
                    for b2 in self.movers:
                        if b2.alive and self.overlap(b2, bl.x, bl.y):
                            bl.y = b2.y + b2.h + R + 1 if bl.vy > 0 else b2.y - R - 1
        # paddle
        if (
            bl.vy > 0
            and PTOP - 4 <= bl.y + R <= PTOP + 24
            and abs(bl.x - self.px) <= self.pw / 2 + (22 if self.easy else 13)
        ):
            reach = self.pw / 2 + (22 if self.easy else 13)
            rel = max(-1.0, min(1.0, (bl.x - self.px) / reach))
            mx = 55 if self.easy else 60
            a = math.radians(rel * mx)
            fin = (
                self.rules["finale"] and self.left <= self.rules["finale"] and self.start_left >= 10
            )
            if (self.aim_next or fin) and not bl.echo:
                tg = self.aim_point(bl.x, bl.y)
                if tg is not None:
                    a = math.atan2(tg[0] - bl.x, -(tg[1] - bl.y))
                    a = max(-math.radians(mx), min(math.radians(mx), a))
                self.aim_next = False
            bl.vx, bl.vy = math.sin(a), -math.cos(a)
            if abs(bl.vx) < SIN6:
                bl.vx = math.copysign(SIN6, bl.vx if bl.vx else 1)
                bl.vy = -math.sqrt(1 - bl.vx * bl.vx)
            bl.y = PTOP - 4 - R
            if not bl.echo:
                self.off = self.rnd.uniform(-0.6, 0.6)
        if bl.vy > 0 and bl.y + R >= NET_Y:
            if bl.echo:
                bl.life = -1
            else:
                bl.y, bl.vy = NET_Y - R, -abs(bl.vy)

    def frame(self):
        self.t += DT
        sp = self.speed()
        self.wide_t = max(0.0, self.wide_t - DT)
        tgt_w = self.pw0 * ((1.3 if self.easy else 1.5) if self.wide_t > 0 else 1.0)
        self.pw = min(560.0, tgt_w)
        # paddle bot
        main = self.balls[0]
        falling = [b for b in self.balls if b.vy > 0]
        if main.vy > 0:
            tx = main.x - self.off * self.pw / 2
        elif falling:
            f = max(falling, key=lambda b: b.y)
            tx = f.x
        elif self.caps:
            tx = max(self.caps, key=lambda c: c[1])[0]
        else:
            tx = main.x
        self.px += max(-2500 * DT, min(2500 * DT, tx - self.px))
        self.px = max(FL + self.pw / 2, min(FR - self.pw / 2, self.px))
        self.move_movers()
        steps = max(1, math.ceil(sp * DT / 8))
        for bl in self.balls:
            for _ in range(steps):
                self.ball_step(bl, sp, DT / steps)
            n = math.hypot(bl.vx, bl.vy) or 1
            bl.vx, bl.vy = bl.vx / n, bl.vy / n
            if abs(bl.vy) < SIN20:
                bl.vy = math.copysign(SIN20, bl.vy if bl.vy else -1)
                bl.vx = math.copysign(math.sqrt(1 - SIN20 * SIN20), bl.vx if bl.vx else 1)
            # finale homing while rising
            fin = (
                self.rules["finale"] and self.left <= self.rules["finale"] and self.start_left >= 10
            )
            if fin and bl.vy < 0 and not bl.echo:
                tg = (
                    self.aim_point(bl.x, bl.y, direct_only=True)
                    if self.t % 0.25 < DT
                    else self.home_tg
                )
                self.home_tg = tg
                if tg is not None:
                    want = math.atan2(tg[0] - bl.x, -(tg[1] - bl.y))
                    cur = math.atan2(bl.vx, -bl.vy)
                    turn = math.radians(40 if self.easy else 30) * DT
                    d = max(-turn, min(turn, want - cur))
                    a = cur + d
                    bl.vx, bl.vy = math.sin(a), -math.cos(a)
            if bl.echo:
                bl.life -= DT
        self.balls = [self.balls[0]] + [b for b in self.balls[1:] if b.life > 0]
        # novas
        due = [n for n in self.novas if n[0] <= self.t]
        self.novas = [n for n in self.novas if n[0] > self.t]
        for _, x, y in due:
            self.nova_fire(x, y)
        # pulses
        while self.puls and self.puls[0] <= self.t:
            self.puls.pop(0)
            self.pulse()
        # assist (old rule kept)
        assist_s = 15 if self.easy else 30
        if self.t - self.assist_clock > assist_s:
            self.aim_next = True
            self.assist_clock = self.t
        if self.komet > 0:
            self.komet_t -= DT
            if self.komet_t <= 0:
                self.komet = 0
        fall = 180.0 if self.easy else 240.0
        keep = []
        for cp in self.caps:
            cp[1] += fall * DT
            if self.easy and cp[1] > 1100:
                cp[0] += max(-400 * DT, min(400 * DT, self.px - cp[0]))
            if (
                abs(cp[0] - self.px) <= self.pw / 2 + 56 + 20
                and abs(cp[1] - PADDLE_Y) <= 18 + 28 + 20
            ):
                self.apply(cp[2])
            elif cp[1] < 1600:
                keep.append(cp)
        self.caps = keep

    def run(self):
        while self.left > 0 and self.t < 900:
            self.frame()
        b = [3.0] + self.breaks
        gaps = [b[i + 1] - b[i] for i in range(len(b) - 1)]
        end = self.t - self.t_left3 if self.t_left3 is not None else 0.0
        return dict(
            t=self.t,
            bps=len(self.breaks) / max(1.0, self.t - 3.0),
            gap=max(gaps) if gaps else 0.0,
            end=end,
            caps=self.caught,
            combo=self.max_combo,
            bricks=self.start_left,
        )


def report(name, table, ids, rules_fn, runs):
    for easy in (True, False):
        st = "Lett" if easy else "Vanlig"
        for i in ids:
            lv = table[i]
            res = [Sim(lv, easy, rules_fn(easy), s).run() for s in range(runs)]

            def med(k, res=res):
                return statistics.median(r[k] for r in res)

            ts = sorted(r["t"] for r in res)
            p90 = ts[int(0.9 * len(ts))]
            print(
                f"{name} {st:6} L{i:<2} bricks {res[0]['bricks']:>2}  median {med('t'):5.0f}s  p90 {p90:4.0f}s  "
                f"breaks/s {med('bps'):.2f}  longest gap {med('gap'):4.1f}s  last-3 {med('end'):4.1f}s "
                f"({100 * med('end') / med('t'):3.0f}%)  caps {med('caps'):.0f}  max combo {med('combo'):.0f}"
            )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=80)
    ap.add_argument("--levels", type=int, nargs="*")
    ap.add_argument("--skip-old", action="store_true")
    a = ap.parse_args()
    if not a.skip_old:
        report("OLD", OLD, a.levels or sorted(OLD), lambda e: OLD_RULES, a.runs)
    report("NEW", NEW, a.levels or sorted(NEW), new_rules, a.runs)


if __name__ == "__main__":
    main()
