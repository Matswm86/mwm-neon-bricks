"""Pacing sim for MWM Neon Bricks, levels 1-30 (design aid, not game code).

v2 (2026-10-06): Triple, Nova chains, Glider, marching blocks, mini-boss, Ekko,
Bredvinge, Neonpuls, combo-drop capsules, progress speed ramp, finale helper.
v3 (2026-10-07, GDD section 16): worlds 4-6 with Switch + Ghost, Portal pairs,
Magnet, Saktetid, Skjoldnett, two march blocks, boss phase actions (shield_up,
jump, minions, nova_ring). Also models paddle english (GDD 4.3) and the game
bot's hold rule (NbPlay.bot_target), which v2 left out: with english on, the
level 10 gap matches tests/levels_test.gd. Marches never move into a piece
outside the block (the builder's rule in NbSim, now GDD 16.2.6).

Usage:
  python3 tools/action_sim.py --skip-old            # levels 1-30
  python3 tools/action_sim.py --skip-old --levels 16 17 --runs 40
  python3 tools/action_sim.py --skip-old --levels 10 --diag   # where the gaps are
  python3 tools/action_sim.py --no-english          # v2 numbers (GDD 15.6)

The paddle bot hits every ball it can reach (tracks at up to 2500 px/s, random
contact offset up to 60% of the half width) and moves toward a falling capsule
while the ball rises. Real players are slower; treat times as floors. Nets are
unlimited in the sim. Flags GAP>10 (Vanlig longest-gap median) and RUN>300.
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
        boss=dict(hp=(14, 16), speed=(80, 120), minions=True),  # GDD 16.6: Vanlig 20 -> 16
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

# ---- Worlds 4-6 (GDD section 16). Same map format; new codes:
# S switch (never breaks), A / B ghost set A / B, O magnet (2 hits),
# 1 / 2 portal pair 1 / 2 (not bricks). Lowercase = carrier as before.
W4 = dict(lett=550, vanlig=830, paddle=260)
W5 = dict(lett=560, vanlig=860, paddle=240)
W6 = dict(lett=570, vanlig=880, paddle=240)

NEW.update(
    {
        # ---- World 4 Nattveien
        16: dict(
            W4,
            carriers=["komet", "ekko"],
            bonus=["komet", "ekko", "bredvinge"],
            rows=[
                "..........",
                "GGGGGGGGGG",
                "ABABABABAB",
                "BABABABABA",
                "GGNGGGGNGG",
                "..........",
                "..S....S..",
                "..........",
                ".g..GG..g.",
            ],
        ),
        17: dict(
            W4,
            carriers=["ekko", "komet"],
            bonus=["komet", "ekko", "bredvinge"],
            march=[dict(rows=(1, 5), floor_y=1000)],
            rows=[
                "..........",
                ".GGGGGGGG.",
                ".AAAAAAAA.",
                ".SBBNNBBS.",
                ".AAAAAAAA.",
                ".GgGGGGgG.",
            ],
        ),
        18: dict(
            W4,
            carriers=["saktetid"],
            bonus=["komet", "ekko", "bredvinge"],
            rows=[
                "..........",
                "GGGGGGGGGG",
                "GNGABBAGNG",
                "GGGBAABGGG",
                ".GGGNNGGG.",
                "..........",
                "...S..S...",
                "..........",
                "M...gg...M",
            ],
        ),
        19: dict(
            W4,
            carriers=["saktetid", "ekko"],
            bonus=["komet", "ekko", "bredvinge", "saktetid"],
            rows=[
                "..........",
                "GGGGGGGGGG",
                "GNGGDDGGNG",
                "ABABABABAB",
                "..........",
                "...S..S...",
                "..........",
                ".M..gg..M.",
                "..........",
                "M........M",
            ],
        ),
        20: dict(
            W4,
            carriers=["ekko", "komet"],
            bonus=["komet", "ekko", "saktetid"],
            boss=dict(
                hp=(12, 14), speed=(70, 110), minions=False, on_phase=["shield_up", "shield_up"]
            ),
            rows=[
                "..........",
                "..GGGGGG..",
                ".NGBBBBGN.",
                "..........",
                "...K++....",
                "...+++....",
                ".AAAAAAAA.",
                "S........S",
                "..g.GG.g..",
            ],
        ),
        # ---- World 5 Krystallgrotta
        21: dict(
            W5,
            carriers=["komet", "ekko"],
            bonus=["komet", "ekko", "saktetid"],
            rows=[
                "........1.",
                "GGGGGGGGGG",
                "GGNGGGGNGG",
                "DGGGDDGGGD",
                "GGGGGGGGGG",
                "..........",
                "..........",
                ".1......g.",
                "..g.......",
            ],
        ),
        22: dict(
            W5,
            carriers=["ekko", "komet"],
            bonus=["komet", "ekko", "bredvinge", "saktetid"],
            rows=[
                "1........2",
                ".GGGGGGGG.",
                ".GNGTTGNG.",
                ".GGGGGGGG.",
                "..........",
                "M...MM...M",
                "..........",
                "..2....1..",
                ".g.M..M.g.",
            ],
        ),
        23: dict(
            W5,
            carriers=["skjoldnett"],
            bonus=["komet", "ekko", "skjoldnett", "saktetid"],
            rows=[
                ".........1",
                ".GGGGGGGG.",
                "GDGGNNGGDG",
                "GGAABBAAGG",
                ".GGGGGGGG.",
                "..........",
                "1..S..S...",
                "..........",
                "..g....g..",
            ],
        ),
        24: dict(
            W5,
            carriers=["skjoldnett", "ekko"],
            bonus=["komet", "ekko", "neonpuls", "skjoldnett"],
            march=[dict(rows=(1, 4), floor_y=700)],
            rows=[
                "..........",
                "..GAAAAG..",
                "..NBBBBN..",
                "..GAAAAG..",
                "..TGGGGT..",
                "..........",
                "..........",
                "1.S....S.1",
                "..........",
                "...g..g...",
            ],
        ),
        25: dict(
            W5,
            carriers=["ekko", "komet"],
            bonus=["komet", "ekko", "neonpuls", "skjoldnett"],
            boss=dict(
                hp=(18, 24),
                speed=(0, 0),
                minions=True,
                on_phase=["jump", "jump"],
                jump=[(1, 6), (1, 1)],
            ),
            rows=[
                "..........",
                "...K++....",
                "...+++....",
                "..........",
                "GGDGGGGDGG",
                "GNGGTTGGNG",
                "..........",
                ".1......1.",
                "..g....g..",
            ],
        ),
        # ---- World 6 Stjerneporten
        26: dict(
            W6,
            carriers=["komet", "ekko"],
            bonus=["komet", "ekko", "neonpuls", "saktetid"],
            rows=[
                "..........",
                "GGGGGGGGGG",
                "GGGOGGOGGG",
                "GNGGGGGGNG",
                "GGGGOOGGGG",
                ".GGGGGGGG.",
                "..........",
                "..g....g..",
            ],
        ),
        27: dict(
            W6,
            carriers=["ekko", "neonpuls"],
            bonus=["komet", "ekko", "bredvinge", "neonpuls"],
            march=[dict(rows=(1, 2), floor_y=600, dir=1), dict(rows=(5, 7), floor_y=1000, dir=-1)],
            rows=[
                "..........",
                ".GGNGGNGG.",
                ".GOGGGGOG.",
                "..........",
                "..........",
                "..TGGGGT..",
                "..GNggNG..",
                "..GGGGGG..",
            ],
        ),
        28: dict(
            W6,
            carriers=["komet", "skjoldnett"],
            bonus=["komet", "ekko", "neonpuls", "saktetid", "skjoldnett"],
            rows=[
                "1........2",
                "GGGGGGGGGG",
                "GAAOGGOBBG",
                "GBBGNNGAAG",
                ".GGGGGGGG.",
                "..........",
                "...S..S...",
                ".2......1.",
                ".g.M..M.g.",
            ],
        ),
        29: dict(
            W6,
            carriers=["ekko", "neonpuls"],
            bonus=["komet", "ekko", "bredvinge", "neonpuls", "saktetid", "skjoldnett"],
            march=[dict(rows=(1, 4), floor_y=760)],
            rows=[
                "..........",
                "..GAAAAG..",
                "..NBOOBN..",
                "..GAAAAG..",
                "..DGGGGD..",
                "..........",
                "..........",
                "..........",
                "1.S....S.1",
                ".gM....Mg.",
            ],
        ),
        30: dict(
            W6,
            carriers=["neonpuls", "ekko"],
            bonus=["komet", "ekko", "bredvinge", "neonpuls", "saktetid"],
            boss=dict(
                hp=(26, 32), speed=(0, 0), minions=False, on_phase=["minions", "minions+nova_ring"]
            ),
            march=[dict(rows=(1, 5), floor_y=800)],
            rows=[
                "..........",
                "...K++....",
                ".O.+++..O.",
                ".GNGGGGNG.",
                ".GGTGGTGG.",
                ".DGGGGGGD.",
                "..........",
                "1..g..g..1",
            ],
        ),
    }
)
NET_UNLIMITED = {1, 2, 3, 4, 5, 10, 15, 20, 25, 30}

HP = {"G": 1, "D": 2, "T": 3, "N": 1, "M": 1, "C": -1, "S": -1, "A": 1, "B": 1, "O": 2}
ENGLISH = (0.05, 0.10)  # Lett, Vanlig (GDD 4.3); NbSim applies it, the v2 sim did not
BOT_HOLD_PX = 120.0  # NbPlay.bot_target: hold still once the ball is this close
SWITCH_COOLDOWN = 0.5
GHOST_FLIP_S = (7.0, 7.0)  # no flip for this long -> ghosts flip by themselves (GDD 16.2.1)
GHOST_FLIP_PHASED_S = 3.0  # same, when every brick left is a phased ghost
PORTAL_MAX_HOPS = 3  # portal uses allowed between two paddle / breakable touches
PORTAL_R, PORTAL_EXIT, PORTAL_CD = 40.0, 60.0, 0.4
MAGNET_RADIUS = 170.0
MAGNET_TURN = (45.0, 70.0)  # deg/s
SAKTE = (0.75, 0.65)
SAKTE_S = 10.0
MINION_CELLS = [(2, d) for d in range(-1, 4)]
NOVA_RING_CELLS = (
    [(2, d) for d in range(-1, 4)]
    + [(0, -1), (0, 3), (1, -1), (1, 3)]
    + [(-1, d) for d in range(-1, 4)]
)
NOVA_RING_MAX = 6

# ------------------------------------------------------------------ rule sets
OLD_RULES = dict(
    time_ramp=True, progress_ramp=0.0, combo_drop=0, finale=0, combo_win=0.0, english=False
)


def new_rules(easy, english=True):
    return dict(
        time_ramp=False,
        progress_ramp=0.0 if easy else 0.15,
        combo_drop=6 if easy else 8,
        finale=4 if easy else 3,
        combo_win=3.0 if easy else 2.0,
        english=english,
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
        "mid",
        "hx",
        "hy",
        "r",
        "c",
    )

    def __init__(self, x, y, w, h, code, hp, carrier):
        self.x, self.y, self.w, self.h = x, y, w, h
        self.hx, self.hy = x, y
        self.code, self.hp, self.maxhp, self.carrier = code, hp, hp, carrier
        self.alive, self.mover, self.vx, self.boss, self.march = True, False, 0.0, False, False
        self.mid, self.r, self.c = -1, 0, 0

    def cx(self):
        return self.x + self.w / 2

    def cy(self):
        return self.y + self.h / 2


class Ball:
    __slots__ = ("x", "y", "vx", "vy", "echo", "life", "pcd", "hops")

    def __init__(self, x, y, vx, vy, echo=False, life=0.0):
        self.x, self.y, self.vx, self.vy, self.echo, self.life = x, y, vx, vy, echo, life
        self.pcd = 0.0
        self.hops = 0


def cell_xy(r, c):
    return GX + c * CELL_W + (CELL_W - BW) / 2, GY + r * CELL_H + (CELL_H - BH) / 2


def rects_hit(ax, ay, aw, ah, bx, by, bw, bh):
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by


class Sim:
    def __init__(self, lv, easy, rules, seed):
        self.rnd = random.Random(seed)
        self.lv, self.easy, self.rules = lv, easy, rules
        self.ei = 0 if easy else 1
        self.base = lv["lett"] if easy else lv["vanlig"]
        self.pw0 = 400.0 if easy else float(lv["paddle"])
        self.pw = self.pw0
        self.grid = {}
        self.movers = []
        self.all = []
        self.portals = []
        boss_cfg = lv.get("boss")
        march = lv.get("march")
        if isinstance(march, dict):
            march = [march]
        self.blocks = [
            dict(
                rows=m["rows"],
                floor_y=m["floor_y"],
                dir=m.get("dir", 1),
                speed=m.get("speed", (40, 70))[self.ei],
                step=m.get("step", 26),
            )
            for m in (march or [])
        ]
        ci = 0
        for r, row in enumerate(lv["rows"]):
            for c, ch in enumerate(row):
                if ch in ".+":
                    continue
                x, y = cell_xy(r, c)
                if ch in "12":
                    self.portals.append([ch, x + BW / 2, y + BH / 2])
                    continue
                if ch == "K":
                    b = Brick(
                        x, y, 3 * CELL_W - 8, 2 * CELL_H - 8, "K", boss_cfg["hp"][self.ei], None
                    )
                    b.boss = True
                    sp = boss_cfg["speed"][self.ei]
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
                b.r, b.c = r, c
                for i, blk in enumerate(self.blocks):
                    if blk["rows"][0] <= r <= blk["rows"][1]:
                        b.mover, b.march, b.mid = True, True, i
                        if b.boss:
                            b.vx = 0.0
                if b.mover:
                    self.movers.append(b)
                else:
                    self.grid[(r, c)] = b
                self.all.append(b)
        self.boss_cfg = boss_cfg
        self.boss_phase = 0
        self.jump_i = 0
        self.ghost_a = True  # set A solid at start
        self.toggle_t = 3.0
        self.toggles = 0
        self.start_left = sum(1 for b in self.all if b.hp > 0)
        self.left = self.start_left
        self.t = 3.0
        a = math.radians(self.rnd.choice([-1, 1]) * self.rnd.uniform(10, 20))
        self.px, self.pvx = 540.0, 0.0
        self.balls = [Ball(540.0, PTOP - 4 - R, math.sin(a), -math.cos(a))]
        self.off = self.rnd.uniform(-0.6, 0.6)
        self.komet, self.komet_t = 0, 0.0
        self.wide_t = 0.0
        self.slow_t = 0.0
        self.puls = []
        self.caps = []
        self.novas = []
        self.last_break = self.t
        self.assist_clock = self.t
        self.aim_next = False
        self.combo, self.combo_t, self.max_combo, self.bonus_i = 0, -9.0, 0, 0
        self.breaks = []
        self.caught = 0
        self.kinds = {}
        self.dropped = 0
        self.t_left3 = None
        self.home_tg = None

    # -------------------------------------------------------------- helpers
    def solid(self, b):
        """Alive and solid right now (phased ghosts are not)."""
        if not b.alive:
            return False
        if b.code in "AB" and self.finale_on():
            return True  # GDD 16.2.1: finale makes every ghost left solid for good
        if b.code == "A":
            return self.ghost_a
        if b.code == "B":
            return not self.ghost_a
        return True

    def finale_on(self):
        f = self.rules["finale"]
        return bool(f) and self.left <= f and self.start_left >= 10

    def target(self, b):
        return self.solid(b) and b.hp > 0

    def speed(self):
        s = self.base
        if self.rules["time_ramp"] and not self.easy:
            s *= min(1 + 0.02 * int((self.t - 3) / 15), 1.15)
        broken = 1 - self.left / self.start_left
        s *= 1 + self.rules["progress_ramp"] * broken
        if self.slow_t > 0:
            s *= SAKTE[self.ei]
        return max(300.0, min(1000.0, s))

    def candidates(self, x, y):
        out = []
        c0, c1 = int((x - R - GX) // CELL_W), int((x + R - GX) // CELL_W)
        r0, r1 = int((y - R - GY) // CELL_H), int((y + R - GY) // CELL_H)
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                b = self.grid.get((r, c))
                if b is not None and self.solid(b):
                    out.append(b)
        for b in self.movers:
            if self.solid(b):
                out.append(b)
        return out

    @staticmethod
    def overlap(b, x, y):
        cx = min(max(x, b.x), b.x + b.w)
        cy = min(max(y, b.y), b.y + b.h)
        return (x - cx) ** 2 + (y - cy) ** 2 < R * R

    def drop(self, x, y, kind):
        if len(self.caps) >= 3:
            return False
        if kind == "skjoldnett" and (self.easy or self.lv["id"] in NET_UNLIMITED):
            kind = "bredvinge"  # GDD 16.2.4: resolved when the capsule spawns
        self.caps.append([x, y, kind])
        self.dropped += 1
        return True

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
            if self.drop(self.balls[0].x, self.balls[0].y, kind):
                self.bonus_i += 1

    # -------------------------------------------------------------- switch + ghost
    def toggle(self):
        self.ghost_a = not self.ghost_a
        self.toggle_t = self.t
        self.toggles += 1
        # A ghost that turns solid around a ball breaks at once (GDD 16.2.1).
        for b in self.all:
            if (
                b.code in "AB"
                and self.solid(b)
                and b.hp > 0
                and any(self.overlap(b, bl.x, bl.y) for bl in self.balls)
            ):
                self.damage(b, 1)

    def ghost_auto(self):
        if (
            self.left <= 0
            or self.finale_on()
            or not any(b.code in "AB" and b.alive for b in self.all)
        ):
            return
        all_phased = not any(self.target(b) for b in self.all)
        wait = GHOST_FLIP_PHASED_S if all_phased else GHOST_FLIP_S[self.ei]
        if self.t - self.toggle_t >= wait:
            self.toggle()

    # -------------------------------------------------------------- boss
    def boss_offset(self, b):
        return (b.x - b.hx, b.y - b.hy) if b.march else (0.0, 0.0)

    def spawn_cells(self, b, cells, code, cap):
        ox, oy = self.boss_offset(b)
        if b.march:
            r0, c0 = b.r, b.c
        else:
            r0 = int((b.y - GY) // CELL_H)
            c0 = int((b.x - GX) // CELL_W)
        placed = 0
        for dr, dc in cells:
            if placed >= cap:
                break
            r, c = r0 + dr, c0 + dc
            if not (0 <= c < 10 and 0 <= r < 12):
                continue
            hx, hy = cell_xy(r, c)
            x, y = hx + ox, hy + oy
            if any(o.alive and rects_hit(x, y, BW, BH, o.x, o.y, o.w, o.h) for o in self.all):
                continue
            if any(
                rects_hit(x, y, BW, BH, p[1] - BW / 2, p[2] - BH / 2, BW, BH) for p in self.portals
            ):
                continue
            # GDD 16.2.7: never spawn right above a chrome, switch or portal (unreachable pocket)
            if any(
                o.alive and o.hp < 0 and rects_hit(x, y + CELL_H, BW, BH, o.x, o.y, o.w, o.h)
                for o in self.all
            ) or any(
                rects_hit(x, y + CELL_H, BW, BH, p[1] - BW / 2, p[2] - BH / 2, BW, BH)
                for p in self.portals
            ):
                continue
            nb = Brick(x, y, BW, BH, code, 1, None)
            nb.hx, nb.hy, nb.r, nb.c = hx, hy, r, c
            if any(self.overlap(nb, bl.x, bl.y) for bl in self.balls):
                continue
            if b.march:
                nb.mover, nb.march, nb.mid = True, True, b.mid
                self.movers.append(nb)
            else:
                self.grid[(r, c)] = nb
            self.all.append(nb)
            self.left += 1
            self.start_left += 1
            placed += 1

    def boss_hit(self, b):
        mx = b.maxhp
        phase = 0 if b.hp > 2 * mx // 3 else (1 if b.hp > mx // 3 else 2)
        while self.boss_phase < phase and b.hp > 0:
            self.boss_phase += 1
            b.vx *= 1.25
            if self.drop(b.cx(), b.y + b.h, self.lv["bonus"][self.bonus_i % len(self.lv["bonus"])]):
                self.bonus_i += 1
            acts = list(self.boss_cfg.get("on_phase", ["", ""]))
            act = acts[self.boss_phase - 1] if self.boss_phase - 1 < len(acts) else ""
            acts = act.split("+")
            if self.boss_cfg.get("minions") or "minions" in acts:
                self.spawn_cells(b, MINION_CELLS, "G", 4)
            if "nova_ring" in acts:
                self.spawn_cells(b, NOVA_RING_CELLS, "N", NOVA_RING_MAX)
            if "shield_up" in acts and not self.ghost_a:
                self.toggle()
            if "jump" in acts:
                spots = self.boss_cfg["jump"]
                r, c = spots[self.jump_i % len(spots)]
                self.jump_i += 1
                b.x, b.y = cell_xy(r, c)
                b.hx, b.hy, b.r, b.c = b.x, b.y, r, c

    def on_break(self, b):
        b.alive = False
        self.left -= 1
        self.breaks.append((self.t, self.left))
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
            if self.target(b):
                if b.boss:
                    hit = abs(b.cx() - x) <= b.w / 2 + 60 and abs(b.cy() - y) <= b.h / 2 + 34
                else:
                    hit = abs(b.cx() - x) <= 110 and abs(b.cy() - y) <= 60
                if hit:
                    if b.code == "N" and b.hp == 1:
                        b.alive = False
                        self.left -= 1
                        self.breaks.append((self.t, self.left))
                        self.last_break = self.assist_clock = self.t
                        if self.left <= 3 and self.t_left3 is None:
                            self.t_left3 = self.t
                        self.combo_tick()
                        if b.carrier:
                            self.drop(b.cx(), b.y + b.h, b.carrier)
                        self.novas.append((self.t + 0.5, b.cx(), b.cy()))
                    else:
                        self.damage(b, 1)

    def clear_path(self, x0, y0, x1, y1):
        # Chrome, switches and portals block; breakable bricks never do.
        n = max(1, int(math.hypot(x1 - x0, y1 - y0) // 10))
        hard = [b for b in self.all if b.alive and b.hp < 0]
        for i in range(1, n):
            x = x0 + (x1 - x0) * i / n
            y = y0 + (y1 - y0) * i / n
            for b in hard:
                if self.overlap(b, x, y):
                    return False
            for p in self.portals:
                if (x - p[1]) ** 2 + (y - p[2]) ** 2 < (PORTAL_R + R) ** 2:
                    return False
        return True

    def aim_point(self, x, y, direct_only=False):
        live = sorted(
            (b for b in self.all if self.target(b)),
            key=lambda b: (b.cx() - x) ** 2 + (b.cy() - y) ** 2,
        )
        if not live:  # only phased ghosts left: aim at a switch (GDD 4.4 rule 5)
            live = sorted(
                (b for b in self.all if b.alive and b.code == "S"),
                key=lambda b: (b.cx() - x) ** 2 + (b.cy() - y) ** 2,
            )
        for b in live:
            if (
                self.clear_path(x, y, b.cx(), b.cy())
                or b.code == "S"
                and self.clear_path(x, y, b.cx(), b.y + b.h + R)
            ):
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
        self.kinds[kind] = self.kinds.get(kind, 0) + 1
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
            while len(self.balls) > 3:
                self.balls.pop(1)
        elif kind == "bredvinge":
            self.wide_t = 20.0 if self.easy else 15.0
        elif kind == "neonpuls":
            self.puls = [self.t + i * 1.0 for i in range(6)]
        elif kind == "saktetid":
            self.slow_t = SAKTE_S
        # skjoldnett: +1 net charge; the sim nets are unlimited, so no effect here

    def pulse(self):
        lo, hi = self.px - self.pw / 2, self.px + self.pw / 2
        for c in range(10):
            cx0, cx1 = GX + c * CELL_W, GX + (c + 1) * CELL_W
            if cx1 < lo or cx0 > hi:
                continue
            best = None
            for b in self.all:
                if (
                    self.target(b)
                    and b.x < cx1
                    and b.x + b.w > cx0
                    and (best is None or b.y > best.y)
                ):
                    best = b
            if best is not None:
                self.damage(best, 1)

    # -------------------------------------------------------------- movers
    def blocked(self, x, y, w, h, skip):
        """Rect hits an alive piece not in `skip` (phased ghosts count) or a portal cell."""
        for o in self.all:
            if o.alive and not skip(o) and rects_hit(x, y, w, h, o.x, o.y, o.w, o.h):
                return True
        for p in self.portals:
            if rects_hit(x, y, w, h, p[1] - BW / 2, p[2] - BH / 2, BW, BH):
                return True
        return False

    def march_hits(self, mem, mid, dx, dy):
        return any(
            self.blocked(b.x + dx, b.y + dy, b.w, b.h, lambda o: o.march and o.mid == mid)
            for b in mem
        )

    def move_movers(self):
        for mid, blk in enumerate(self.blocks):
            mem = [b for b in self.movers if b.march and b.mid == mid and b.alive]
            if not mem:
                continue
            dx = blk["dir"] * blk["speed"] * DT
            lo = min(b.x for b in mem)
            hi = max(b.x + b.w for b in mem)
            rev = False
            if lo + dx < FL + 4:
                dx, rev = FL + 4 - lo, True
            elif hi + dx > FR - 4:
                dx, rev = FR - 4 - hi, True
            elif self.march_hits(mem, mid, dx, 0):
                dx, rev = 0.0, True
            for b in mem:
                b.x += dx
            if rev:
                blk["dir"] *= -1
                low = max(b.y + b.h for b in mem)
                st = blk["step"]
                if low + st <= blk["floor_y"] and not self.march_hits(mem, mid, 0, st):
                    for b in mem:
                        b.y += st
        for b in self.movers:
            if not b.alive or b.march or b.vx == 0:
                continue
            b.x += b.vx * DT
            hit = b.x < FL + 4 or b.x + b.w > FR - 4
            if not hit:
                hit = self.blocked(b.x, b.y, b.w, b.h, lambda o, b=b: o is b)
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
                    if (
                        b.code == "S"
                        and self.t - self.toggle_t >= SWITCH_COOLDOWN
                        and not self.finale_on()
                    ):
                        self.toggle()
                    continue
                bl.hops = 0
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
                if hit_mover:
                    for b2 in self.movers:
                        if self.solid(b2) and self.overlap(b2, bl.x, bl.y):
                            bl.y = b2.y + b2.h + R + 1 if bl.vy > 0 else b2.y - R - 1
        # GDD 4.2 corner case: still inside a solid piece -> push out along the shortest axis
        for b in self.candidates(bl.x, bl.y):
            if b.hp < 0 and self.overlap(b, bl.x, bl.y):
                pushes = [
                    (bl.x - (b.x - R), 0),
                    ((b.x + b.w + R) - bl.x, 1),
                    (bl.y - (b.y - R), 2),
                    ((b.y + b.h + R) - bl.y, 3),
                ]
                d, k = min(pushes)
                if k == 0:
                    bl.x, bl.vx = b.x - R, -abs(bl.vx)
                elif k == 1:
                    bl.x, bl.vx = b.x + b.w + R, abs(bl.vx)
                elif k == 2:
                    bl.y, bl.vy = b.y - R, -abs(bl.vy)
                else:
                    bl.y, bl.vy = b.y + b.h + R, abs(bl.vy)
        # portals (GDD 16.2.3)
        if bl.pcd <= 0 and bl.hops < PORTAL_MAX_HOPS:
            for p in self.portals:
                if (bl.x - p[1]) ** 2 + (bl.y - p[2]) ** 2 < PORTAL_R**2:
                    q = next(o for o in self.portals if o[0] == p[0] and o is not p)
                    n = math.hypot(bl.vx, bl.vy) or 1
                    bl.x = q[1] + bl.vx / n * PORTAL_EXIT
                    bl.y = q[2] + bl.vy / n * PORTAL_EXIT
                    bl.x = max(FL + R, min(FR - R, bl.x))
                    bl.y = max(FT + R, bl.y)
                    bl.pcd = PORTAL_CD
                    bl.hops += 1
                    break
        # paddle
        reach = self.pw / 2 + (22 if self.easy else 13)
        if bl.vy > 0 and PTOP - 4 <= bl.y + R <= PTOP + 24 and abs(bl.x - self.px) <= reach:
            rel = max(-1.0, min(1.0, (bl.x - self.px) / reach))
            mx = 55 if self.easy else 60
            a = math.radians(rel * mx)
            fin = (
                self.rules["finale"] and self.left <= self.rules["finale"] and self.start_left >= 10
            )
            aimed = False
            if (self.aim_next or fin) and not bl.echo:
                tg = self.aim_point(bl.x, bl.y)
                if tg is not None:
                    a = math.atan2(tg[0] - bl.x, -(tg[1] - bl.y))
                    a = max(-math.radians(mx), min(math.radians(mx), a))
                    aimed = True
                self.aim_next = False
            bl.vx, bl.vy = math.sin(a), -math.cos(a)
            if not aimed and self.rules.get("english"):
                bl.vx += self.pvx * ENGLISH[self.ei] / max(1.0, sp)
                n = math.hypot(bl.vx, bl.vy)
                bl.vx, bl.vy = bl.vx / n, bl.vy / n
                if bl.vy > -0.01:
                    bl.vy = -0.01
                    bl.vx = math.copysign(math.sqrt(1 - 0.0001), bl.vx)
            if abs(bl.vx) < SIN6:
                bl.vx = math.copysign(SIN6, bl.vx if bl.vx else 1)
                bl.vy = -math.sqrt(1 - bl.vx * bl.vx)
            bl.y = PTOP - 4 - R
            bl.hops = 0
            if not bl.echo:
                self.off = self.rnd.uniform(-0.6, 0.6)
        if bl.vy > 0 and bl.y + R >= NET_Y:
            if bl.echo:
                bl.life = -1
            else:
                bl.y, bl.vy = NET_Y - R, -abs(bl.vy)

    def magnet(self, bl):
        best, bd = None, MAGNET_RADIUS**2
        for b in self.all:
            if b.alive and b.code == "O":
                d = (b.cx() - bl.x) ** 2 + (b.cy() - bl.y) ** 2
                if 1.0 < d < bd:
                    best, bd = b, d
        if best is None:
            return
        want = math.atan2(best.cx() - bl.x, -(best.cy() - bl.y))
        cur = math.atan2(bl.vx, -bl.vy)
        d = (want - cur + math.pi) % (2 * math.pi) - math.pi
        turn = math.radians(MAGNET_TURN[self.ei]) * DT
        a = cur + max(-turn, min(turn, d))
        bl.vx, bl.vy = math.sin(a), -math.cos(a)

    def frame(self):
        self.t += DT
        sp = self.speed()
        self.wide_t = max(0.0, self.wide_t - DT)
        self.slow_t = max(0.0, self.slow_t - DT)
        tgt_w = self.pw0 * ((1.3 if self.easy else 1.5) if self.wide_t > 0 else 1.0)
        self.pw = min(560.0, tgt_w)
        # paddle bot (same as NbPlay.bot_target: hold still once the ball is close)
        main = self.balls[0]
        falling = [b for b in self.balls[1:] if b.vy > 0]
        if main.vy > 0:
            want = main.x - self.off * self.pw / 2
            above = PTOP - (main.y + R)
            if above < BOT_HOLD_PX and abs(self.px - want) < self.pw * 0.25:
                tx = self.px
            else:
                tx = want
        elif falling:
            tx = max(falling, key=lambda b: b.y).x
        elif self.caps:
            tx = max(self.caps, key=lambda c: c[1])[0]
        else:
            tx = main.x
        prev = self.px
        self.px += max(-2500 * DT, min(2500 * DT, tx - self.px))
        self.px = max(FL + self.pw / 2, min(FR - self.pw / 2, self.px))
        self.pvx = (self.px - prev) / DT
        self.move_movers()
        steps = max(1, math.ceil(sp * DT / 8))
        for bl in self.balls:
            bl.pcd -= DT
            for _ in range(steps):
                self.ball_step(bl, sp, DT / steps)
            n = math.hypot(bl.vx, bl.vy) or 1
            bl.vx, bl.vy = bl.vx / n, bl.vy / n
            self.magnet(bl)
            if abs(bl.vy) < SIN20:
                bl.vy = math.copysign(SIN20, bl.vy if bl.vy else -1)
                bl.vx = math.copysign(math.sqrt(1 - SIN20 * SIN20), bl.vx if bl.vx else 1)
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
        due = [n for n in self.novas if n[0] <= self.t]
        self.novas = [n for n in self.novas if n[0] > self.t]
        for _, x, y in due:
            self.nova_fire(x, y)
        while self.puls and self.puls[0] <= self.t:
            self.puls.pop(0)
            self.pulse()
        self.ghost_auto()
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

    def run(self, cap=900.0):
        while self.left > 0 and self.t < cap:
            self.frame()
        marks = [(3.0, self.start_left)] + self.breaks
        gap, gap_at, gap_left = 0.0, 3.0, self.start_left
        for i in range(len(marks) - 1):
            g = marks[i + 1][0] - marks[i][0]
            if g > gap:
                gap, gap_at, gap_left = g, marks[i][0], marks[i][1]
        end = self.t - self.t_left3 if self.t_left3 is not None else 0.0
        return dict(
            t=self.t,
            bps=len(self.breaks) / max(1.0, self.t - 3.0),
            gap=gap,
            gap_at=gap_at,
            gap_left=gap_left,
            end=end,
            caps=self.caught,
            combo=self.max_combo,
            bricks=self.start_left,
            toggles=self.toggles,
            cleared=self.left <= 0,
        )


def lint(lid, lv):
    """GDD 16.4 map rules: every breakable cell reachable from the paddle line by a
    straight or one-wall-bank shot (ghosts counted solid, other breakables never
    block); portal pairs complete; nothing in the shell square; max row r9."""
    out = []
    sim = Sim(dict(lv, id=lid), False, new_rules(False), 0)
    for b in sim.all:
        if b.hp <= 0 or b.mover:
            continue
        ok = False
        for px in (140.0, 340.0, 540.0, 740.0, 940.0):
            x, y = px, PTOP - 4 - R
            if sim.clear_path(x, y, b.cx(), b.cy()):
                ang = math.degrees(math.atan2(b.cx() - x, -(b.cy() - y)))
                if abs(ang) <= 55:
                    ok = True
                    break
            for wall in (FL + R, FR - R):
                mx = 2 * wall - b.cx()
                k = (wall - x) / (mx - x) if mx != x else -1
                if 0 < k < 1:
                    wy = y + (b.cy() - y) * k
                    ang = math.degrees(math.atan2(wall - x, -(wy - y)))
                    if (
                        abs(ang) <= 55
                        and sim.clear_path(x, y, wall, wy)
                        and sim.clear_path(wall, wy, b.cx(), b.cy())
                    ):
                        ok = True
            if ok:
                break
        if not ok:
            out.append(f"L{lid} r{b.r} c{b.c} {b.code} unreachable")
    rows = lv["rows"]
    for r, row in enumerate(rows):
        for c, ch in enumerate(row):
            if ch not in "12":
                continue
            for dr in (-1, 0, 1):
                for dc in (-1, 0, 1):
                    rr, cc = r + dr, c + dc
                    if (
                        (dr or dc)
                        and 0 <= rr < len(rows)
                        and 0 <= cc < 10
                        and rows[rr][cc] in "CS12"
                    ):
                        out.append(f"L{lid} portal r{r} c{c} has {rows[rr][cc]} next to it")
    for ch in "12":
        n = sum(row.count(ch) for row in lv["rows"])
        if n not in (0, 2):
            out.append(f"L{lid} portal {ch} appears {n} times")
    if len(lv["rows"]) > 10 and lv["rows"][10:] != ["." * 10] * (len(lv["rows"]) - 10):
        out.append(f"L{lid} pieces below r9")
    return out


TARGET_GAP_S = 10.0  # GDD 15.10: Vanlig longest-gap median under 10 s
TARGET_CAP_S = 300.0  # GDD 15.10: no run over 300 s


def report(name, table, ids, rules_fn, runs, diag=False):
    bad = []
    for easy in (True, False):
        st = "Lett" if easy else "Vanlig"
        for i in ids:
            lv = dict(table[i], id=i)
            res = [Sim(lv, easy, rules_fn(easy), s).run() for s in range(runs)]

            def med(k, res=res):
                return statistics.median(r[k] for r in res)

            ts = sorted(r["t"] for r in res)
            p90 = ts[int(0.9 * len(ts))]
            flag = ""
            if not easy and med("gap") >= TARGET_GAP_S:
                flag += " GAP>10"
            if ts[-1] > TARGET_CAP_S:
                flag += " RUN>300"
            if flag:
                bad.append(f"{st} L{i}{flag}")
            print(
                f"{name} {st:6} L{i:<2} bricks {res[0]['bricks']:>2}  median {med('t'):5.0f}s  p90 {p90:4.0f}s  "
                f"max {ts[-1]:4.0f}s  breaks/s {med('bps'):.2f}  longest gap {med('gap'):4.1f}s  "
                f"last-3 {med('end'):4.1f}s ({100 * med('end') / med('t'):3.0f}%)  caps {med('caps'):.0f}  "
                f"max combo {med('combo'):.0f}{flag}"
            )
            if diag:
                worst = sorted(res, key=lambda r: -r["gap"])[: max(1, runs // 4)]
                print(
                    "      longest gaps: "
                    + ", ".join(
                        f"{r['gap']:.1f}s at t={r['gap_at']:.0f} ({r['gap_left']} left)"
                        for r in worst
                    )
                )
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=80)
    ap.add_argument("--levels", type=int, nargs="*")
    ap.add_argument("--skip-old", action="store_true")
    ap.add_argument("--no-english", action="store_true", help="v2 behaviour: no paddle english")
    ap.add_argument("--diag", action="store_true", help="print where the longest gaps happen")
    a = ap.parse_args()
    if not a.skip_old:
        report(
            "OLD",
            OLD,
            a.levels and [i for i in a.levels if i in OLD] or sorted(OLD),
            lambda e: OLD_RULES,
            a.runs,
        )
    problems = [m for i in (a.levels or sorted(NEW)) for m in lint(i, NEW[i])]
    print("map lint: " + ("OK" if not problems else "; ".join(problems)))
    eng = not a.no_english
    bad = report("NEW", NEW, a.levels or sorted(NEW), lambda e: new_rules(e, eng), a.runs, a.diag)
    print("pacing targets: " + ("ALL MET" if not bad else "MISSED: " + "; ".join(bad)))


if __name__ == "__main__":
    main()
