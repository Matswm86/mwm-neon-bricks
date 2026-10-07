"""MWM Neon Bricks parts for worlds 2-6 and the new elements (Blender 4.5, background mode).

Extends nb_parts.py. Same axes: X right, Z up, play plane at Y = PLANE_Y facing -Y.
Godot <-> Blender: g2b(x, y, z) = (x + 5.4, -z - 0.2, y).
"""

import math

import bmesh
import bpy

import nb_parts as P

HEX = dict(P.HEX)
HEX.update(
    {
        "mint": "#4DFF9A",  # v2: greener than v1 #3DFFB0 so it never reads as the player's cyan
        "elec": "#3D7BFF",  # world 2 accent
        "red": "#FF3B30",  # world 4 accent
        "amber": "#FFB23D",  # world 4 lamps
        "gold": "#FFD27A",  # world 6 ring beads, card rim
        "warm_white": "#FFF4D6",
        "ghost_line": "#FFF4D6",
    }
)
P.HEX.update(HEX)


def g2b(x, y, z):
    return (x + 5.4, -z - 0.2, y)


def lin(h):
    return P.lin(h)


# ---- materials ---------------------------------------------------------------
def mat_emit_a(name, color, strength, alpha):
    return P.mat_pbr(name, "#000000", rough=0.5, emit=color, emit_str=strength, alpha=alpha)


def mat_flat(name, color):
    """Unshaded flat silhouette colour (Godot: unshaded albedo)."""
    return P.mat_emit(name, color, 1.0)


def mat_paddle_body_v2():
    # QA fix: lit blue-steel shell instead of near-black gunmetal (DESIGN 13.2)
    return P.mat_pbr("paddle_body", "#4A5578", rough=0.32, metal=0.35, coat=1.0, emit="#263052", emit_str=1.0)


# ---- shapes ------------------------------------------------------------------
def circle_pts(r, n=32, cx=0.0, cz=0.0, a0=0.0):
    return [(cx + r * math.cos(a0 + 2 * math.pi * i / n), cz + r * math.sin(a0 + 2 * math.pi * i / n)) for i in range(n)]


def perimeter(pts):
    segs, total = [], 0.0
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        d = math.dist(a, b)
        segs.append((a, b, d))
        total += d
    return segs, total


def point_at(segs, s):
    for a, b, d in segs:
        if s <= d:
            t = s / d if d else 0
            return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
        s -= d
    return segs[-1][1]


def dashed_loop(name, pts, y, radius, mat, n_dash=16, duty=0.55):
    segs, total = perimeter(pts)
    objs = []
    step = total / n_dash
    for k in range(n_dash):
        s0 = k * step
        sub = [point_at(segs, s0 + step * duty * j / 4) for j in range(5)]
        objs.append(P.tube_loop(f"{name}_d{k}", sub, y, radius, mat, closed=False))
    return objs


def box(name, sx, sy, sz, mat, loc=(0, 0, 0), bevel=0.01):
    ob = P.rounded_box(name, sx, sy, sz, bevel, mat, segments=2)
    ob.location = loc
    return ob


def ring(name, r, tube, y, mat, n=48):
    return P.tube_loop(name, circle_pts(r, n), y, tube, mat, closed=True)


# ---- bricks (mock copies of the in-game types) ------------------------------
BW, BH, BD = P.BRICK_W, P.BRICK_H, P.BRICK_D
FRONT = -BD / 2


def _body(name, color):
    body = P.rounded_box(name, BW, BD, BH, 0.07, P.mat_brick(HEX[color]))
    rim = P.tube_loop(f"{name}_rim", P.rrect_points(BW - 0.12, BH - 0.12, 0.05), FRONT - 0.004, 0.012, P.mat_emit(f"rim_{color}", HEX[color], 6.0))
    return [body, rim]


def dot(name, x, z, r=0.07):
    d = P.uv_sphere(name, r, P.mat_pbr("dot", HEX["dot"], rough=0.2, emit=HEX["dot"], emit_str=3.0), seg=16, rings=8)
    d.scale = (1, 0.6, 1)
    d.location = (x, FRONT - 0.01, z)
    return d


def brick_triple(color, name="triple"):
    parts = _body(name, color)
    for x, z in ((-0.16, -0.07), (0.16, -0.07), (0.0, 0.09)):
        parts.append(dot(f"{name}_dot", x, z, 0.06))
    return P.to_mesh_and_join(parts, name)


def brick_glider(color, name="glider"):
    parts = _body(name, color)
    m = P.mat_pbr("chev", HEX["dot"], emit=HEX["dot"], emit_str=3.0)
    for s in (-1, 1):
        x0 = s * 0.30
        pts = [(x0 - s * 0.06, 0.11), (x0 + s * 0.05, 0.0), (x0 - s * 0.06, -0.11)]
        parts.append(P.tube_loop(f"{name}_chev", pts, FRONT - 0.008, 0.02, m, closed=False))
    return P.to_mesh_and_join(parts, name)


def brick_nova(color, name="nova"):
    parts = _body(name, color)
    st = P.flat_shape(f"{name}_star", P.star_points(0.15, 0.045, n=4), FRONT - 0.006, 0.012, P.mat_pbr("nova_star", HEX["star"], emit=HEX["star"], emit_str=4.0))
    parts.append(st)
    return P.to_mesh_and_join(parts, name)


def brick_switch(active="A", name="switch"):
    """Bryter: dark steel body (no rim tube, never breaks), domed button with power symbol,
    set marks: square (A) on the left, round dot (B) on the right; the solid set's mark is lit."""
    body = P.rounded_box(name, BW, BD, BH, 0.07, P.mat_pbr("switch_body", "#3A4052", rough=0.3, metal=0.8))
    parts = [body]
    btn = P.cylinder_y(f"{name}_btn", 0.15, 0.06, P.mat_pbr("switch_btn", "#1A1C26", rough=0.25, metal=0.3, coat=1.0), verts=32)
    btn.location = (0, FRONT - 0.03, 0)
    parts.append(btn)
    lit = P.mat_pbr("switch_ring", HEX["warm_white"], emit=HEX["warm_white"], emit_str=3.5)
    parts.append(ring(f"{name}_bezel", 0.165, 0.014, FRONT - 0.035, P.mat_pbr("switch_bezel", "#C9CED8", rough=0.2, metal=1.0), n=40))
    # power symbol: ring open at the top + bar
    arc = [(0.085 * math.cos(math.radians(a)), 0.085 * math.sin(math.radians(a))) for a in range(120, 421, 15)]
    parts.append(P.tube_loop(f"{name}_arc", arc, FRONT - 0.065, 0.016, lit, closed=False))
    parts.append(P.tube_loop(f"{name}_bar", [(0, 0.02), (0, 0.12)], FRONT - 0.065, 0.016, lit, closed=False))
    dark = P.mat_pbr("switch_mark_off", "#4A4F60", rough=0.4, metal=0.5)
    sq = box(f"{name}_mA", 0.09, 0.03, 0.09, lit if active == "A" else dark, (-0.33, FRONT - 0.01, 0), 0.008)
    rd = P.cylinder_y(f"{name}_mB", 0.05, 0.03, lit if active == "B" else dark, verts=20)
    rd.location = (0.33, FRONT - 0.01, 0)
    parts += [sq, rd]
    return P.to_mesh_and_join(parts, name)


def brick_ghost(set_id="A", color="hotpink", solid=True, name="ghost"):
    """Skygge. Solid: candy body + white dashed outline + corner marks.
    Phased: dashed outline + marks only at 30% (Godot: alpha 0.30)."""
    parts = []
    a = 1.0 if solid else 0.30
    if solid:
        parts.append(P.rounded_box(name, BW, BD, BH, 0.07, P.mat_brick(HEX[color])))
    else:
        parts.append(P.rounded_box(name, BW, BD * 0.5, BH, 0.07, P.mat_pbr("ghost_haze", "#000000", emit=HEX[color], emit_str=0.6, alpha=0.08)))
    lm = mat_emit_a(f"ghost_line_{int(a * 100)}", HEX["ghost_line"], 3.0, a)
    if solid:  # dark keyline under the dashes: 3:1+ against any candy fill
        km = P.mat_pbr("ghost_key", "#1A0614", rough=0.6)
        parts += dashed_loop(f"{name}_kl", P.rrect_points(BW - 0.16, BH - 0.16, 0.04), FRONT - 0.002, 0.020, km, n_dash=12, duty=0.47)
    parts += dashed_loop(f"{name}_dl", P.rrect_points(BW - 0.16, BH - 0.16, 0.04), FRONT - 0.010, 0.011, lm, n_dash=12, duty=0.45)
    hw, hh = (BW - 0.10) / 2 - 0.05, (BH - 0.10) / 2 - 0.04
    for sx in (-1, 1):
        for sz in (-1, 1):
            if set_id == "A" and solid:
                kp = [(sx * hw, sz * (hh - 0.11)), (sx * hw, sz * hh), (sx * (hw - 0.13), sz * hh)]
                parts.append(P.tube_loop(f"{name}_ck", kp, FRONT - 0.004, 0.040, km, closed=False))
            if set_id == "B" and solid:
                dk = P.uv_sphere(f"{name}_ck", 0.065, km, seg=12, rings=6)
                dk.scale = (1, 0.5, 1)
                dk.location = (sx * (hw - 0.02), FRONT - 0.004, sz * (hh - 0.02))
                parts.append(dk)
            if set_id == "A":
                pts = [(sx * hw, sz * (hh - 0.11)), (sx * hw, sz * hh), (sx * (hw - 0.13), sz * hh)]
                parts.append(P.tube_loop(f"{name}_c", pts, FRONT - 0.012, 0.028, lm, closed=False))
            else:
                d = P.uv_sphere(f"{name}_c", 0.05, lm, seg=12, rings=6)
                d.scale = (1, 0.5, 1)
                d.location = (sx * (hw - 0.02), FRONT - 0.012, sz * (hh - 0.02))
                parts.append(d)
    return P.to_mesh_and_join(parts, name)


def portal(pair=1, name="portal"):
    """Ormehull: dark hole disc r 0.40 m (= 40 px logic radius), bright ring, spiral arm(s);
    pair 2 adds a 5-point star in the centre."""
    col = "#9CFFC8" if pair == 1 else HEX["gold"]
    hole = P.cylinder_y(f"{name}_hole", 0.40, 0.04, P.mat_pbr("portal_hole", "#05020C", rough=0.2, coat=1.0), verts=40)
    hole.location = (0, -0.02, 0)
    parts = [hole]
    parts.append(ring(f"{name}_ring", 0.40, 0.03, -0.05, P.mat_emit(f"portal_ring{pair}", col, 4.0)))
    arm_m = P.mat_emit(f"portal_arm{pair}", col, 2.5)
    arms = 1 if pair == 1 else 2
    for k in range(arms):
        pts = []
        for i in range(40):
            th = i / 39 * 2.6 * math.pi
            r = (0.05 if pair == 1 else 0.15) + (0.30 if pair == 1 else 0.20) * i / 39
            a = th + k * math.pi
            pts.append((r * math.cos(a), r * math.sin(a)))
        parts.append(P.tube_loop(f"{name}_arm{k}", pts, -0.05, 0.014, arm_m, closed=False))
    if pair == 2:
        parts.append(P.flat_shape(f"{name}_star", P.star_points(0.14, 0.06), -0.06, 0.012, P.mat_emit("portal_star", HEX["gold"], 4.0)))
    return P.to_mesh_and_join(parts, name)


# ---- capsules ------------------------------------------------------------------
def capsule(kind, name=None):
    name = name or f"capsule_{kind}"
    w, h = 1.12, 0.56
    body = P.extrude_profile(name, P.stadium_points(w, h), 0.30, P.mat_pbr("capsule_body", "#140F2E", rough=0.15, coat=1.0, emit="#2EE6FF", emit_str=0.25), bevel=0.05)
    rim = P.tube_loop(f"{name}_rim", P.stadium_points(w - 0.08, h - 0.08, 10), -0.155, 0.016, P.mat_emit("capsule_rim", HEX["cyan"], 6.0))
    ic = P.mat_emit("capsule_icon", "#FFFFFF", 6.0)
    parts = [body, rim]
    y = -0.16
    if kind == "saktetid":
        # cassette: rounded window outline + two reels with 3 spokes
        parts.append(P.tube_loop(f"{name}_case", P.rrect_points(0.62, 0.30, 0.06), y, 0.014, ic))
        for cx in (-0.14, 0.14):
            parts.append(P.tube_loop(f"{name}_reel", circle_pts(0.075, 20, cx), y, 0.013, ic))
            for k in range(3):
                a = math.radians(90 + k * 120)
                parts.append(P.tube_loop(f"{name}_sp", [(cx, 0), (cx + 0.06 * math.cos(a), 0.06 * math.sin(a))], y, 0.011, ic, closed=False))
        parts.append(P.tube_loop(f"{name}_tape", [(-0.14, -0.075), (0.14, -0.075)], y, 0.010, ic, closed=False))
    elif kind == "skjoldnett":
        # net: line + zigzag, plus sign above
        parts.append(P.tube_loop(f"{name}_line", [(-0.34, -0.04), (0.34, -0.04)], y, 0.016, ic, closed=False))
        zz = [(-0.34 + i * 0.085, -0.04 if i % 2 == 0 else -0.14) for i in range(9)]
        parts.append(P.tube_loop(f"{name}_zz", zz, y, 0.010, ic, closed=False))
        parts.append(box(f"{name}_p1", 0.16, 0.01, 0.045, ic, (0, y, 0.10)))
        parts.append(box(f"{name}_p2", 0.045, 0.01, 0.16, ic, (0, y, 0.10)))
    elif kind == "bredvinge":
        parts.append(P.extrude_profile(f"{name}_pad", P.stadium_points(0.30, 0.09), 0.01, ic, bevel=0.005))
        parts[-1].location = (0, y, -0.02)
        for s in (-1, 1):
            parts.append(P.flat_shape(f"{name}_w", [(s * 0.16, 0.0), (s * 0.40, 0.14), (s * 0.34, -0.04)], y, 0.01, ic))
    elif kind == "neonpuls":
        parts.append(P.extrude_profile(f"{name}_pad", P.stadium_points(0.36, 0.09), 0.01, ic, bevel=0.005))
        parts[-1].location = (0, y, -0.12)
        for k, r in enumerate((0.10, 0.17, 0.24)):
            arc = [(r * math.cos(math.radians(a)), -0.10 + r * math.sin(math.radians(a))) for a in range(40, 141, 10)]
            parts.append(P.tube_loop(f"{name}_arc{k}", arc, y, 0.013, ic, closed=False))
    return P.to_mesh_and_join(parts, name)


# ---- paddle v2 (QA fix: lit body) ------------------------------------------------
def paddle_v2(width=2.8, name="paddle"):
    h = 0.36
    body = P.extrude_profile(name, P.stadium_points(width, h), 0.36, mat_paddle_body_v2(), bevel=0.05)
    # face plate: slightly lighter inset panel inside the light loop, gives the body a lit face
    plate = P.extrude_profile(f"{name}_plate", P.stadium_points(width - 0.22, h - 0.20, 10), 0.02, P.mat_pbr("paddle_plate", "#6A7AA6", rough=0.28, metal=0.3, coat=1.0, emit="#2E3C66", emit_str=1.0), bevel=0.008)
    plate.location = (0, -0.18, 0)
    strip = P.tube_loop(f"{name}_strip", P.stadium_points(width - 0.10, h - 0.12, 10), -0.185, 0.022, P.mat_emit("paddle_light", HEX["paddle_light"], 7.0))
    caps = []
    cap_m = P.mat_emit("paddle_cap", "#E8FDFF", 8.0)
    for s in (-1, 1):
        c = P.uv_sphere(f"{name}_cap", 0.07, cap_m, seg=16, rings=8)
        c.scale = (1, 0.5, 1)
        c.location = (s * (width / 2 - 0.18), -0.19, 0)
        caps.append(c)
    return P.to_mesh_and_join([body, plate, strip, *caps], name)


def paddle_underglow(width=2.8, name="paddle_glow"):
    """Additive soft cyan quad behind the paddle on the field glass (Godot: 1 quad, additive)."""
    m = P.mat_pbr("paddle_glow", "#000000", emit=HEX["cyan"], emit_str=0.5, alpha=0.08)
    ob = P.extrude_profile(name, P.stadium_points(width + 0.5, 0.9, 12), 0.005, m, bevel=0.002)
    return ob


# ---- bosses (3 x 2 cells = 2.92 x 0.96 m hit box) ------------------------------------
def core_ring(name, hp_max, hp_left, accent, x=0.0, z=0.0, y=-0.30):
    parts = []
    disc = P.cylinder_y(f"{name}_coredisc", 0.30, 0.05, P.mat_pbr("core_disc", "#140F2E", rough=0.15, coat=1.0), verts=40)
    disc.location = (x, y + 0.02, z)
    parts.append(disc)
    rg = ring(f"{name}_corering", 0.24, 0.035, y - 0.02, P.mat_emit("core_ring", HEX["warm_white"], 4.0))
    rg.location = (x, 0, z)
    parts.append(rg)
    on = P.mat_emit(f"notch_{accent}", HEX[accent], 4.0)
    off = P.mat_pbr("notch_off", "#2A2238", rough=0.5)
    for i in range(hp_max):
        a = math.pi / 2 - 2 * math.pi * i / hp_max
        nb = box(f"{name}_n{i}", 0.032, 0.03, 0.075, on if i < hp_left else off, (x + 0.355 * math.cos(a), y - 0.01, z + 0.355 * math.sin(a)), 0.006)
        nb.rotation_euler = (0, -(a - math.pi / 2), 0)
        parts.append(nb)
    return parts


def boss_lastebilen(hp_max=24, hp_left=17, name="boss_lastebilen"):
    """Level 20: a lorry seen from the side. Trailer box + cab, wheels, amber marker lamps."""
    body_m = P.mat_pbr("truck_body", HEX["red"], rough=0.18, coat=1.0, emit=HEX["red"], emit_str=0.35)
    trailer = P.rounded_box(name, 1.95, 0.40, 0.74, 0.07, body_m)
    trailer.location = (-0.46, 0, 0.08)
    parts = [trailer]
    cab_pts = [(0.56, -0.30), (1.46, -0.30), (1.46, 0.10), (1.30, 0.34), (0.56, 0.34)]
    cab = P.extrude_profile(f"{name}_cab", cab_pts, 0.40, P.mat_pbr("truck_cab", "#C9CED8", rough=0.22, metal=1.0), bevel=0.05)
    parts.append(cab)
    win = P.flat_shape(f"{name}_win", [(0.98, 0.10), (1.36, 0.10), (1.24, 0.28), (0.98, 0.28)], -0.21, 0.01, P.mat_pbr("truck_win", "#140F2E", rough=0.05, coat=1.0))
    parts.append(win)
    ribm = P.mat_pbr("truck_rib", "#FFFFFF", rough=0.3, metal=1.0)
    for k, x in enumerate((-1.30, -1.12, 0.20, 0.38)):
        parts.append(box(f"{name}_rib{k}", 0.025, 0.02, 0.62, ribm, (x, -0.21, 0.08)))
    lamp = P.mat_emit("truck_lamp", HEX["amber"], 5.0)
    for k in range(6):
        l = P.uv_sphere(f"{name}_lamp{k}", 0.035, lamp, seg=10, rings=5)
        l.location = (-1.32 + k * 0.34, -0.21, 0.42)
        parts.append(l)
    tyre = P.mat_pbr("tyre", "#0C0A12", rough=0.7)
    hub = P.mat_pbr("hub", "#C9CED8", rough=0.2, metal=1.0)
    for x in (-1.15, -0.85, 0.85, 1.20):
        t = P.cylinder_y(f"{name}_tyre", 0.17, 0.10, tyre, verts=24)
        t.location = (x, -0.16, -0.31)
        h = P.cylinder_y(f"{name}_hub", 0.07, 0.11, hub, verts=12)
        h.location = (x, -0.17, -0.31)
        parts += [t, h]
    parts += core_ring(name, hp_max, hp_left, "amber", x=-0.46, z=0.06, y=-0.23)
    return P.to_mesh_and_join(parts, name)


def boss_krystallhjertet(hp_max=24, hp_left=20, name="boss_krystallhjertet"):
    """Level 25: a faceted crystal heart-gem with the core ring inside; mint facet edges."""
    gem_m = P.mat_pbr("gem", HEX["violet"], rough=0.08, coat=1.0, emit=HEX["violet"], emit_str=0.7)
    pts = [(-1.40, 0.0), (-0.95, 0.42), (0.95, 0.42), (1.40, 0.0), (0.95, -0.42), (-0.95, -0.42)]
    gem = P.extrude_profile(name, pts, 0.42, gem_m, bevel=0.03, segs=1)
    parts = [gem]
    edge = P.mat_emit("gem_edge", HEX["mint"], 5.0)
    y = -0.22
    for a, b in [((-1.40, 0.0), (-0.55, 0.0)), ((0.55, 0.0), (1.40, 0.0)), ((-0.95, 0.42), (-0.55, 0.0)), ((-0.95, -0.42), (-0.55, 0.0)), ((0.95, 0.42), (0.55, 0.0)), ((0.95, -0.42), (0.55, 0.0))]:
        parts.append(P.tube_loop(f"{name}_e", [a, b], y, 0.014, edge, closed=False))
    parts.append(P.tube_loop(f"{name}_out", pts, y, 0.016, edge, closed=True))
    for s in (-1, 1):
        sp = P.flat_shape(f"{name}_spike", [(s * 1.30, 0.18), (s * 1.46, 0.46), (s * 1.12, 0.30)], y, 0.04, edge)
        parts.append(sp)
    parts += core_ring(name, hp_max, hp_left, "mint", y=-0.25)
    return P.to_mesh_and_join(parts, name)


def boss_neonnova(hp_max=36, hp_left=25, name="boss_neonnova"):
    """Level 30: dark star-core casing with a gold rim, four Nova star spikes behind the core."""
    case_m = P.mat_pbr("nova_case", "#140A2A", rough=0.12, metal=0.4, coat=1.0)
    def octo(w, h, c):
        return [(-w / 2 + c, h / 2), (w / 2 - c, h / 2), (w / 2, h / 2 - c), (w / 2, -h / 2 + c), (w / 2 - c, -h / 2), (-w / 2 + c, -h / 2), (-w / 2, -h / 2 + c), (-w / 2, h / 2 - c)]

    case = P.extrude_profile(name, octo(2.92, 0.96, 0.26), 0.40, case_m, bevel=0.04, segs=2)
    parts = [case]
    parts.append(P.tube_loop(f"{name}_rim", octo(2.80, 0.84, 0.22), -0.215, 0.024, P.mat_emit("nova_rim", HEX["gold"], 5.0)))
    spike = P.mat_emit("nova_spike", "#FFE7A0", 5.0)
    glow = P.mat_emit("nova_glow", HEX["magenta"], 2.0)
    parts.append(P.flat_shape(f"{name}_g", [(x, z * 0.40) for x, z in P.star_points(1.30, 0.26, n=4, rot=0)], -0.205, 0.01, glow))
    parts.append(P.flat_shape(f"{name}_s", [(x, z * 0.36) for x, z in P.star_points(1.22, 0.14, n=4, rot=0)], -0.215, 0.01, spike))
    parts += core_ring(name, hp_max, hp_left, "magenta", y=-0.27)
    return P.to_mesh_and_join(parts, name)


# ---- environment props ----------------------------------------------------------
def tower(name, w, h, d, mat, crown=None, steps=2):
    parts = [P.rounded_box(name, w, d, h, 0.2, mat, segments=1)]
    parts[0].location = (0, 0, h / 2)
    ww, hh = w, h
    for k in range(steps):
        ww *= 0.72
        sh = h * 0.08
        s = P.rounded_box(f"{name}_s{k}", ww, d * 0.8, sh, 0.1, mat, segments=1)
        s.location = (0, 0, hh + sh / 2)
        hh += sh
        parts.append(s)
    if crown:
        sp = P.rounded_box(f"{name}_sp", w * 0.06, d * 0.2, h * 0.18, 0.05, mat, segments=1)
        sp.location = (0, 0, hh + h * 0.09)
        parts.append(sp)
    ob = P.to_mesh_and_join(parts, name)
    return ob


def cabinet(name, mat_body, mat_marquee, mat_screen):
    """Arcade cabinet side silhouette 1.0 x 0.8 x 2.0 m (scaled up in the vista)."""
    prof = [(-0.4, 0.0), (0.4, 0.0), (0.4, 1.05), (0.15, 1.25), (0.25, 1.70), (0.4, 1.75), (0.4, 2.0), (-0.4, 2.0)]
    body = P.extrude_profile(name, prof, 1.0, mat_body, bevel=0.03, segs=2)
    body.rotation_euler = (0, 0, math.radians(90))
    mq = box(f"{name}_mq", 1.02, 0.12, 0.22, mat_marquee, (0, 0, 1.88))
    sc_ = box(f"{name}_scr", 0.80, 0.06, 0.42, mat_screen, (0, -0.32, 1.45))
    sc_.rotation_euler = (math.radians(-20), 0, 0)
    bpy.context.view_layer.update()
    return P.to_mesh_and_join([body, mq, sc_], name)


def lamp_post(name, pole_m, head_m):
    pole = box(f"{name}", 0.25, 0.25, 9.0, pole_m, (0, 0, 4.5), 0.05)
    arm = box(f"{name}_arm", 2.4, 0.18, 0.18, pole_m, (1.1, 0, 8.9), 0.04)
    head = box(f"{name}_head", 0.9, 0.35, 0.18, head_m, (2.1, 0, 8.75), 0.06)
    return P.to_mesh_and_join([pole, arm, head], name)


def crystal(name, h, r, mat, edge_m=None, tilt=0.0):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    n = 6
    base = [bm.verts.new((r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n), 0)) for i in range(n)]
    top = [bm.verts.new((r * 0.92 * math.cos(2 * math.pi * i / n), r * 0.92 * math.sin(2 * math.pi * i / n), h * 0.78)) for i in range(n)]
    tip = bm.verts.new((0, 0, h))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((base[i], base[j], top[j], top[i]))
        bm.faces.new((top[i], top[j], tip))
    bm.faces.new(base[::-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.data.materials.append(mat)
    bpy.context.scene.collection.objects.link(ob)
    ob.rotation_euler = (0, tilt, 0)
    parts = [ob]
    if edge_m:
        for i in range(n):
            a = 2 * math.pi * i / n
            p0 = (r * 0.92 * math.cos(a), r * 0.92 * math.sin(a), h * 0.78)
            cu = bpy.data.curves.new(f"{name}_e", "CURVE")
            cu.dimensions = "3D"
            cu.bevel_depth = r * 0.05
            sp = cu.splines.new("POLY")
            sp.points.add(1)
            sp.points[0].co = (*p0, 1)
            sp.points[1].co = (0, 0, h, 1)
            eo = bpy.data.objects.new(f"{name}_e", cu)
            eo.data.materials.append(edge_m)
            bpy.context.scene.collection.objects.link(eo)
            eo.rotation_euler = (0, tilt, 0)
            parts.append(eo)
    return P.to_mesh_and_join(parts, name)


def crystal_cluster(name, scale, mat, edge_m, seed=0):
    import random

    rnd = random.Random(seed)
    parts = []
    for k in range(7):
        h = scale * rnd.uniform(0.5, 1.0) * (1.6 if k == 0 else 1.0)
        r = h * rnd.uniform(0.12, 0.18)
        c = crystal(f"{name}_{k}", h, r, mat, edge_m, tilt=rnd.uniform(-0.5, 0.5) if k else 0.05)
        c.location = (rnd.uniform(-0.35, 0.35) * scale, rnd.uniform(-0.2, 0.2) * scale, 0)
        parts.append(c)
    return P.to_mesh_and_join(parts, name)


def ring_gate(name, R, body_m, bead_m, n_seg=24):
    parts = []
    for k in range(n_seg):
        a0 = 2 * math.pi * k / n_seg
        a1 = 2 * math.pi * (k + 0.86) / n_seg
        pts_o = [(R * 1.08 * math.cos(a0 + (a1 - a0) * i / 6), R * 1.08 * math.sin(a0 + (a1 - a0) * i / 6)) for i in range(7)]
        pts_i = [(R * 0.94 * math.cos(a1 - (a1 - a0) * i / 6), R * 0.94 * math.sin(a1 - (a1 - a0) * i / 6)) for i in range(7)]
        seg = P.flat_shape(f"{name}_s{k}", pts_o + pts_i, 0, R * 0.08, body_m)
        parts.append(seg)
        am = (a0 + a1) / 2
        b = P.uv_sphere(f"{name}_b{k}", R * 0.022, bead_m, seg=8, rings=4)
        b.location = (R * 1.01 * math.cos(am), -R * 0.05, R * 1.01 * math.sin(am))
        parts.append(b)
    return P.to_mesh_and_join(parts, name)


def stalactite(name, h, r, mat, tip_m):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=7, radius1=r, radius2=0.0, depth=h)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=__import__("mathutils").Matrix.Rotation(math.pi, 3, "X"))
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.data.materials.append(mat)
    bpy.context.scene.collection.objects.link(ob)
    tip = P.uv_sphere(f"{name}_tip", r * 0.18, tip_m, seg=10, rings=5)
    tip.location = (0, 0, -h / 2 + r * 0.1)
    return P.to_mesh_and_join([ob, tip], name)
