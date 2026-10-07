"""Render a world mock frame for MWM Neon Bricks worlds 1-6, 1080x1920 (DESIGN section 11).

blender -b -P docs/mockups/src/world_mock.py -- <world 1-6> <out.png> [vista]
"vista" hides gameplay objects and renders at 50% for the ball-contrast measurement.
All vista placements are written in GODOT coordinates (x right, y up, z toward the camera,
play plane z = 0, screen bottom y = 0, x 540 px = x 0) and converted with g2b().
"""

import math
import random
import sys
from pathlib import Path

import bpy
import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
import nb_parts as P  # noqa: E402
import nb_parts_w26 as Q  # noqa: E402
import nb_sky  # noqa: E402
import nb_worlds as NW  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
WID = int(argv[0]) if argv else 2
OUT = argv[1] if len(argv) > 1 else f"/tmp/world{WID}.png"
VISTA = len(argv) > 2 and argv[2] == "vista"
WD = NW.WORLDS[WID]
g2b = Q.g2b
random.seed(WID)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
try:
    sc.render.engine = "BLENDER_EEVEE_NEXT"
except TypeError as e:
    print(e)
sc.render.resolution_x, sc.render.resolution_y = 1080, 1920
sc.render.resolution_percentage = 50 if VISTA else 100
sc.eevee.taa_render_samples = 16 if VISTA else 48
sc.view_settings.view_transform = "Standard"
sc.view_settings.look = "None"

# ---- world background (radiance only; the visible sky is the far plane below) ----
w = bpy.data.worlds.new("sky")
sc.world = w
w.use_nodes = True
bgn = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
bgn.inputs["Color"].default_value = P.lin(WD["psm_horizon"])
bgn.inputs["Strength"].default_value = 0.35

# ---- camera (identical to world1_mock) ----
cam = bpy.data.cameras.new("cam")
cam.lens = 45
cam.sensor_fit = "HORIZONTAL"
cam.sensor_width = 36
cam.clip_end = 3000
D = 13.5
co = bpy.data.objects.new("cam", cam)
sc.collection.objects.link(co)
EYE = 6.2
co.location = (5.4, P.PLANE_Y - D, EYE)
cam.shift_y = (9.6 - EYE) / 10.8
co.rotation_euler = (math.radians(90), 0, 0)
sc.camera = co
CAM_Y = co.location.y

# ---- sky: far plane carrying the numpy port of sky.gdshader v2 ----
SKY_Y = 600.0
dist = SKY_Y - CAM_Y
TX0, TX1, TY0, TY1 = -0.62, 0.62, -0.06, 1.12
PPT = 1350.0 * (0.5 if VISTA else 1.0)
nx, ny = int((TX1 - TX0) * PPT), int((TY1 - TY0) * PPT)
tx, ty = np.meshgrid(np.linspace(TX0, TX1, nx), np.linspace(TY0, TY1, ny))
skyc = nb_sky.sky(WID, tx, ty, PPT)
img = bpy.data.images.new("skyimg", nx, ny, alpha=False, float_buffer=True)
rgba = np.concatenate([skyc, np.ones((ny, nx, 1), np.float32)], axis=2)
img.pixels.foreach_set(rgba.ravel())
sky_m = bpy.data.materials.new("sky")
sky_m.use_nodes = True
nt = sky_m.node_tree
nt.nodes.clear()
it = nt.nodes.new("ShaderNodeTexImage")
it.image = img
it.interpolation = "Linear"
em = nt.nodes.new("ShaderNodeEmission")
em.inputs["Strength"].default_value = 1.0
mo = nt.nodes.new("ShaderNodeOutputMaterial")
nt.links.new(it.outputs["Color"], em.inputs["Color"])
nt.links.new(em.outputs[0], mo.inputs["Surface"])
bpy.ops.mesh.primitive_plane_add(size=1, location=(5.4 + (TX0 + TX1) / 2 * dist, SKY_Y, EYE + (TY0 + TY1) / 2 * dist), rotation=(math.radians(90), 0, 0))
skyp = bpy.context.active_object
skyp.scale = ((TX1 - TX0) * dist, (TY1 - TY0) * dist, 1)
skyp.data.materials.append(sky_m)


# ---- node helpers for the floor shader ----
class NB:
    def __init__(self, nt):
        self.nt = nt

    def math(self, op, a, b=None, clamp=False):
        n = self.nt.nodes.new("ShaderNodeMath")
        n.operation = op
        n.use_clamp = clamp
        for i, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                n.inputs[i].default_value = v
            else:
                self.nt.links.new(v, n.inputs[i])
        return n.outputs[0]

    def mixc(self, f, a, b):
        n = self.nt.nodes.new("ShaderNodeMix")
        n.data_type = "RGBA"
        n.clamp_factor = True
        for key, v in (("Factor", f), ("A", a), ("B", b)):
            sock = n.inputs[key] if key == "Factor" else next(s for s in n.inputs if s.name == key and s.type == "RGBA")
            if isinstance(v, (int, float)):
                sock.default_value = v
            elif isinstance(v, tuple):
                sock.default_value = v
            else:
                self.nt.links.new(v, sock)
        return next(s for s in n.outputs if s.type == "RGBA")

    def addc(self, a, b, f):
        n = self.nt.nodes.new("ShaderNodeMix")
        n.data_type = "RGBA"
        n.blend_type = "ADD"
        n.clamp_factor = False
        fs = n.inputs["Factor"]
        if isinstance(f, (int, float)):
            fs.default_value = f
        else:
            self.nt.links.new(f, fs)
        A = next(s for s in n.inputs if s.name == "A" and s.type == "RGBA")
        B = next(s for s in n.inputs if s.name == "B" and s.type == "RGBA")
        for sock, v in ((A, a), (B, b)):
            if isinstance(v, tuple):
                sock.default_value = v
            else:
                self.nt.links.new(v, sock)
        return next(s for s in n.outputs if s.type == "RGBA")

    def smooth(self, a, b, x):
        n = self.nt.nodes.new("ShaderNodeMapRange")
        n.interpolation_type = "SMOOTHSTEP"
        n.inputs["From Min"].default_value = a
        n.inputs["From Max"].default_value = b
        self.nt.links.new(x, n.inputs["Value"])
        return n.outputs["Result"]


def unshaded_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Strength"].default_value = 1.0
    mo = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs[0], mo.inputs["Surface"])
    return m, nt, em


# ---- floor (sea.gdshader v2: grid | checker | road | lattice) ----
F = WD["floor"]
fm, fnt, fem = unshaded_mat("floor")
nb = NB(fnt)
tc = fnt.nodes.new("ShaderNodeTexCoord")
sep = fnt.nodes.new("ShaderNodeSeparateXYZ")
fnt.links.new(tc.outputs["Object"], sep.inputs[0])
gx = nb.math("SUBTRACT", sep.outputs["X"], 5.4)  # Godot x
gz = sep.outputs["Y"]  # depth (Godot -z)


def lines_of(u, width):
    fr = nb.math("FRACT", nb.math("ADD", u, 0.5))
    dd = nb.math("ABSOLUTE", nb.math("SUBTRACT", fr, 0.5))
    return nb.math("LESS_THAN", dd, width)


per = F["period"]
mode = F["mode"]
if mode == "lattice":
    u = nb.math("DIVIDE", nb.math("ADD", gx, gz), per)
    v = nb.math("DIVIDE", nb.math("SUBTRACT", gx, gz), per)
else:
    u = nb.math("DIVIDE", gx, per)
    v = nb.math("DIVIDE", gz, per)
lines = nb.math("MAXIMUM", lines_of(u, F["width"]), lines_of(v, F["width"]))
far = nb.math("SUBTRACT", 1.0, nb.math("DIVIDE", gz, 260.0), clamp=True)
lg = nb.math("MULTIPLY", nb.math("MULTIPLY", lines, far), F["gain"])
base = P.lin(F["base"])
col = base
if mode == "checker":
    cu = nb.math("FLOOR", u)
    cv = nb.math("FLOOR", v)
    par = nb.math("FLOORED_MODULO", nb.math("ADD", cu, cv), 2.0)
    col = nb.mixc(par, base, P.lin(F["base2"]))
if mode == "road":
    ax = nb.math("ABSOLUTE", gx)
    on_road = nb.math("LESS_THAN", ax, 7.0)
    col = nb.mixc(on_road, base, P.lin("#06040A"))
    lg = nb.math("MULTIPLY", lg, nb.math("SUBTRACT", 1.0, on_road))
    # lane dashes at |x| = 3.5 (amber), 6 m period, 50% duty; edge lines at |x| = 7 (red)
    dash_x = nb.math("LESS_THAN", nb.math("ABSOLUTE", nb.math("SUBTRACT", ax, 3.5)), 0.12)
    dash_z = nb.math("LESS_THAN", nb.math("FRACT", nb.math("DIVIDE", gz, 6.0)), 0.5)
    dash = nb.math("MULTIPLY", nb.math("MULTIPLY", dash_x, dash_z), far)
    edge = nb.math("MULTIPLY", nb.math("LESS_THAN", nb.math("ABSOLUTE", nb.math("SUBTRACT", ax, 7.0)), 0.15), far)
    col = nb.addc(col, P.lin(F["dash"]), nb.math("MULTIPLY", dash, 0.9))
    col = nb.addc(col, P.lin(F["edge"]), nb.math("MULTIPLY", edge, 0.8))
col = nb.addc(col, P.lin(F["line"]), lg)
# reflection streak of the motif (x gaussian, grows with distance)
sx = nb.math("EXPONENT", nb.math("DIVIDE", nb.math("MULTIPLY", nb.math("MULTIPLY", gx, gx), -1.0), 18.0))
sz = nb.smooth(20.0, 380.0, gz)
col = nb.addc(col, P.lin(F["streak"]), nb.math("MULTIPLY", nb.math("MULTIPLY", sx, sz), 0.22))
hz = nb.math("MULTIPLY", nb.smooth(60.0, 400.0, gz), 0.8)
col = nb.mixc(hz, col, P.lin(F["haze"]))
fnt.links.new(col, fem.inputs["Color"])
bpy.ops.mesh.primitive_plane_add(size=1, location=(5.4, 0, 0))
flo = bpy.context.active_object
for vv in flo.data.vertices:
    vv.co.x *= 1600
    vv.co.y = vv.co.y * 1200 + 560
flo.data.materials.append(fm)

# ---- world props (Godot coordinates) ----
props = []


def place(ob, gx_, gy_, gz_, s=1.0, rot_z=0.0):
    ob.location = g2b(gx_, gy_, gz_)
    ob.scale = (s, s, s)
    ob.rotation_euler[2] += rot_z
    props.append(ob)
    return ob


def windows_mat(name, body, lit, cell_w=3.0, cell_h=3.6, density=0.35, lit_gain=1.0):
    """Unshaded tower with a lit window grid (Godot: windows.gdshader, no texture)."""
    m, nt, em_ = unshaded_mat(name)
    n = NB(nt)
    tco = nt.nodes.new("ShaderNodeTexCoord")
    sp_ = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tco.outputs["Object"], sp_.inputs[0])
    cx_ = n.math("FLOOR", n.math("DIVIDE", sp_.outputs["X"], cell_w))
    cz_ = n.math("FLOOR", n.math("DIVIDE", sp_.outputs["Z"], cell_h))
    fx = n.math("FRACT", n.math("DIVIDE", sp_.outputs["X"], cell_w))
    fz = n.math("FRACT", n.math("DIVIDE", sp_.outputs["Z"], cell_h))
    inx = n.math("MULTIPLY", n.math("GREATER_THAN", fx, 0.25), n.math("LESS_THAN", fx, 0.75))
    inz = n.math("MULTIPLY", n.math("GREATER_THAN", fz, 0.3), n.math("LESS_THAN", fz, 0.7))
    h = n.math("FRACT", n.math("MULTIPLY", n.math("SINE", n.math("ADD", n.math("MULTIPLY", cx_, 127.1), n.math("MULTIPLY", cz_, 311.7))), 43758.5453))
    on = n.math("MULTIPLY", n.math("MULTIPLY", inx, inz), n.math("LESS_THAN", h, density))
    c_ = n.mixc(on, P.lin(body), tuple(v * lit_gain if i < 3 else 1.0 for i, v in enumerate(P.lin(lit))))
    nt.links.new(c_, em_.inputs["Color"])
    return m


def hdr(h, k):
    r, g, b, _ = P.lin(h)
    return (r * k, g * k, b * k, 1.0)


def emit_lin(name, h, k):
    m, nt, em_ = unshaded_mat(name)
    em_.inputs["Color"].default_value = hdr(h, k)
    return m


if WID == 2:
    # Skyline: three depth layers of stepped towers with lit window grids (tops stay below t.y 0.27).
    layers = [(-110.0, "#0C1638", 0.30, (8, 30)), (-180.0, "#0A1230", 0.25, (18, 50)), (-280.0, "#081028", 0.2, (30, 78))]
    for zl, body, dens, (hmin, hmax) in layers:
        mat = windows_mat(f"win{zl}", body, "#C08028", cell_w=1.6, cell_h=2.0, density=dens, lit_gain=1.5)
        x = -150.0
        while x < 150.0:
            wdt = random.uniform(9, 20)
            hgt = random.uniform(hmin, hmax) * (0.6 + 0.4 * min(1.0, abs(x) / 50.0))
            t = Q.tower(f"tw{zl}_{x:.0f}", wdt, hgt, 8.0, mat, crown=random.random() < 0.3, steps=random.choice((0, 1, 2)))
            place(t, x, 0.0, zl)
            x += wdt + random.uniform(1.0, 6.0)
    # neon signs: plain vertical strips on tower faces (no ring, arrow or chevron: those shapes
    # are gameplay cues - portal, glider - and must never appear in a vista)
    for k, (gx_, gy_, hgt, colr) in enumerate(((-38.0, 9.0, 9.0, "#FF2E88"), (-12.0, 14.0, 7.0, "#3D7BFF"), (21.0, 11.0, 10.0, "#FF2E88"), (44.0, 16.0, 8.0, "#3D7BFF"))):
        sm = emit_lin(f"sign{k}", colr, 2.4)
        sg = P.tube_loop(f"sign{k}", [(0, 0), (0, hgt)], 0, 0.45, sm, closed=False)
        sg.location = g2b(gx_, gy_, -105.5)

if WID == 3:
    body_m = P.mat_pbr("cab_body", "#0B0612", rough=0.6)
    mq_m = emit_lin("cab_mq", "#FFE14D", 1.4)
    scr_a = emit_lin("cab_scr_a", "#FF3D6E", 1.4)
    scr_b = emit_lin("cab_scr_b", "#3D7BFF", 1.4)
    for side in (-1, 1):
        for k in range(7):
            cab = Q.cabinet(f"cab{side}{k}", body_m, mq_m, scr_a if (k + (side > 0)) % 2 else scr_b)
            cab.rotation_euler = (0, 0, math.radians(-90 * side + 35 * side))
            place(cab, side * (7.0 + k * 0.9), 0.0, -10.0 - k * 8.0, s=2.8)
    # ceiling truss with a row of marquee bulbs in the sky band (top-band signature)
    truss_m = P.mat_pbr("truss", "#1A1020", rough=0.5, metal=0.6)
    tr = P.rounded_box("truss", 30.0, 0.8, 1.0, 0.1, truss_m, segments=1)
    tr.location = g2b(5.0, 42.6, -30.0)
    bulb_m = emit_lin("bulb", "#FFE14D", 3.0)
    for k in range(14):
        b = P.uv_sphere(f"bulb{k}", 0.38, bulb_m, seg=12, rings=6)
        b.location = g2b(-8.6 + k * 2.1, 41.7, -29.4)
    # back wall pixel stars are in the sky shader (square stars)

if WID == 4:
    pole_m = P.mat_pbr("pole", "#120A16", rough=0.5, metal=0.6)
    head_m = emit_lin("lamp_head", "#FFB23D", 1.6)
    pool_m = P.mat_pbr("pool", "#000000", emit="#FFB23D", emit_str=0.6, alpha=0.18)
    for side in (-1, 1):
        for k in range(16):
            z = -20.0 - k * 24.0
            lp = Q.lamp_post(f"lp{side}{k}", pole_m, head_m)
            lp.rotation_euler = (0, 0, math.radians(180 if side > 0 else 0))
            place(lp, side * 9.0, 0.0, z)
            if k < 8:
                bpy.ops.mesh.primitive_plane_add(size=1, location=g2b(side * 7.0, 0.02, z))
                pl = bpy.context.active_object
                pl.scale = (4.0, 6.0, 1)
                pl.data.materials.append(pool_m)
    # overpass deck crossing the sky band (top-band signature), amber lamps under it
    deck_m = P.mat_pbr("deck", "#0E0812", rough=0.7, metal=0.2)
    deck = P.rounded_box("overpass", 120.0, 6.0, 3.0, 0.3, deck_m, segments=1)
    deck.location = g2b(0.0, 55.0, -45.0)
    lamp_m = emit_lin("deck_lamp", "#FFB23D", 3.0)
    for k in range(14):
        lb = P.rounded_box(f"dl{k}", 1.2, 0.4, 0.35, 0.1, lamp_m, segments=1)
        lb.location = g2b(-19.5 + k * 3.0, 53.3, -41.9)
    # light streaks: tail lights (red) right lane, head lights (warm white) left lane
    for xs_, colr in ((3.1, "#FF3B30"), (3.9, "#FF3B30"), (-3.1, "#FFE6C8"), (-3.9, "#FFE6C8")):
        st_m = emit_lin(f"streak{xs_}", colr, 1.6)
        st = P.tube_loop(f"streak{xs_}", [(0, 0), (0, 1)], 0, 0.06, st_m, closed=False)
        st.location = g2b(xs_, 0.6, -14.0)
        cu = st.data
        cu.splines[0].points[0].co = (0, 0, 0, 1)
        cu.splines[0].points[1].co = (0, 420, 0, 1)

if WID == 5:
    vio_m = P.mat_pbr("crystal_vio", "#2A1A80", rough=0.1, coat=1.0, emit="#4A2CB0", emit_str=0.9)
    mint_m = P.mat_pbr("crystal_mint", "#0E3A2C", rough=0.1, coat=1.0, emit="#1E7A52", emit_str=0.9)
    for (gx_, gz_, s_, sd, mat) in ((-12.0, -16.0, 3.5, 1, vio_m), (12.5, -20.0, 4.0, 2, mint_m), (-30.0, -60.0, 13.0, 3, mint_m), (34.0, -70.0, 14.0, 4, vio_m), (-70.0, -150.0, 24.0, 5, vio_m), (80.0, -160.0, 26.0, 6, mint_m)):
        cl = Q.crystal_cluster(f"cc{sd}", s_, mat, None, seed=sd)
        place(cl, gx_, 0.0, gz_)
    # ceiling rock + short stalactites inside the sky band (top-band signature)
    rock_m = P.mat_pbr("rock", "#07101A", rough=0.9, emit="#0B2A26", emit_str=0.8)
    tip_m = emit_lin("stal_tip", "#4DFF9A", 3.0)
    rk = P.rounded_box("ceiling", 90.0, 4.0, 10.0, 1.0, rock_m, segments=1)
    rk.location = g2b(0.0, 50.0, -30.0)
    for k in range(10):
        h = random.uniform(1.6, 3.0)
        stl = Q.stalactite(f"stal{k}", h, h * 0.30, rock_m, tip_m)
        stl.location = g2b(-7.0 + k * 3.0 + random.uniform(-0.5, 0.5), 45.2 - h / 2, -29.0)
    # mist cards
    mist_m = P.mat_pbr("mist", "#000000", emit="#1B2A4A", emit_str=1.0, alpha=0.30)
    for gz_, gy_ in ((-35.0, 1.5), (-70.0, 3.0)):
        bpy.ops.mesh.primitive_plane_add(size=1, location=g2b(0.0, gy_, gz_), rotation=(math.radians(90), 0, 0))
        mc = bpy.context.active_object
        mc.scale = (160.0, 3.5, 1)
        mc.data.materials.append(mist_m)

if WID == 6:
    ring_m = P.mat_pbr("gate_body", "#2A1A5A", rough=0.25, metal=0.7, emit="#5A2CB0", emit_str=0.9)
    bead_m = emit_lin("gate_bead", "#FFD27A", 1.6)
    gate = Q.ring_gate("ring_gate", 40.0, ring_m, bead_m, n_seg=24)
    gate.location = g2b(0.0, 27.6, -120.0)
    # ringed planet top-right in the sky band (top-band signature)
    pm_ = P.mat_pbr("planet", "#3A1C6A", rough=0.6, emit="#120828", emit_str=0.5)
    pl = P.uv_sphere("planet", 23.0, pm_, seg=48, rings=24)
    pl.location = g2b(104.0, 367.0, -400.0)
    # gold terminator: a thin bright crescent lamp on the lit side
    cr_m = emit_lin("planet_lit", "#FFD27A", 1.6)
    cres = P.uv_sphere("planet_lit", 23.2, cr_m, seg=48, rings=24)
    cres.location = g2b(104.0 - 5.0, 367.0 + 3.0, -400.0 - 6.0)

# ---- arena frame (with the 13.3 seam fix: wider top rail, side rails stop under it) ----
field_m, fgn, fge = unshaded_mat("field")
fgn.nodes.clear()
tr_ = fgn.nodes.new("ShaderNodeBsdfTransparent")
bl_ = fgn.nodes.new("ShaderNodeEmission")
bl_.inputs["Color"].default_value = (0, 0, 0, 1)
mx_ = fgn.nodes.new("ShaderNodeMixShader")
out_ = fgn.nodes.new("ShaderNodeOutputMaterial")
nbf = NB(fgn)
alpha_sock = NW.GLASS_ALPHA
FIELD_Y = 0.12
m_ = WD["motif"]
if m_["window"]:
    tcf = fgn.nodes.new("ShaderNodeTexCoord")
    spf = fgn.nodes.new("ShaderNodeSeparateXYZ")
    fgn.links.new(tcf.outputs["Object"], spf.inputs[0])
    gd = FIELD_Y - CAM_Y
    # object coords of the field plane (size 1 scaled 10 x 14.2): world x = 5.4 + ox*10, z = 9.3 + oy*14.2
    tx_ = nbf.math("DIVIDE", nbf.math("MULTIPLY", spf.outputs["X"], 10.0), gd)
    ty_ = nbf.math("DIVIDE", nbf.math("SUBTRACT", nbf.math("ADD", nbf.math("MULTIPLY", spf.outputs["Y"], 14.2), 9.3), EYE), gd)
    dx_ = nbf.math("DIVIDE", nbf.math("SUBTRACT", tx_, m_["c"][0]), m_["r"])
    dy_ = nbf.math("DIVIDE", nbf.math("SUBTRACT", ty_, m_["c"][1]), m_["r"])
    if m_["kind"] == 3:
        rr_ = nbf.math("MAXIMUM", nbf.math("DIVIDE", nbf.math("ABSOLUTE", dx_), 1.95), nbf.math("DIVIDE", nbf.math("ABSOLUTE", dy_), 1.2))
    else:
        rr_ = nbf.math("SQRT", nbf.math("ADD", nbf.math("MULTIPLY", dx_, dx_), nbf.math("MULTIPLY", dy_, dy_)))
    win = nbf.math("MULTIPLY", nbf.math("SUBTRACT", 1.0, nbf.smooth(1.03, 1.30, rr_)), nbf.smooth(0.0, 0.04, ty_))
    alpha_sock = nbf.math("ADD", NW.GLASS_ALPHA, nbf.math("MULTIPLY", win, NW.WINDOW_ALPHA - NW.GLASS_ALPHA))
if isinstance(alpha_sock, float):
    mx_.inputs["Fac"].default_value = alpha_sock
else:
    fgn.links.new(alpha_sock, mx_.inputs["Fac"])
fgn.links.new(tr_.outputs[0], mx_.inputs[1])
fgn.links.new(bl_.outputs[0], mx_.inputs[2])
fgn.links.new(mx_.outputs[0], out_.inputs["Surface"])
try:
    field_m.surface_render_method = "BLENDED"
except (AttributeError, TypeError):
    pass
bpy.ops.mesh.primitive_plane_add(size=1, location=(5.4, FIELD_Y, (1920 - 990) * P.PX), rotation=(math.radians(90), 0, 0))
fld = bpy.context.active_object
fld.scale = (10.0, 14.2, 1)
fld.data.materials.append(field_m)

rail_m = P.mat_pbr(f"rail{WID}", WD["rail"], rough=0.6, metal=0.4)
tube_m = P.mat_emit(f"tube{WID}", WD["tube"], 6.0)
z_top, z_bot = (1920 - 280) * P.PX, (1920 - 1700) * P.PX
for x0, x1 in ((0.0, 0.40), (10.40, 10.80)):
    r = P.rounded_box("rail", x1 - x0, 0.40, z_top - z_bot, 0.06, rail_m)
    r.location = ((x0 + x1) / 2, P.PLANE_Y, (z_top + z_bot) / 2)
    xt = x1 if x0 == 0 else x0
    P.tube_loop("wtube", [(xt, z_bot + 0.1), (xt, z_top)], P.PLANE_Y - 0.22, 0.03, tube_m, closed=False)
top = P.rounded_box("rail_top", 12.4, 0.40, 0.40, 0.06, rail_m)
top.location = (5.4, P.PLANE_Y, z_top + 0.2)
P.tube_loop("ttube", [(0.4, z_top), (10.4, z_top)], P.PLANE_Y - 0.22, 0.03, tube_m, closed=False)
for x in (0.2, 10.6):
    c = P.uv_sphere("railcap", 0.12, P.mat_emit("railcap", P.HEX["cyan"], 6.0))
    c.location = (x, P.PLANE_Y - 0.2, z_bot + 0.05)
# ---- gameplay per world ----
game = []
ramp = WD["ramp"]


def cell(c, r):
    return P.logic_to_world(90 + 100 * c, 366 + 52 * r)


def add(ob, c, r, dx=0.0, lean=0.0):
    x, y, z = cell(c, r)
    ob.location = (x + dx, y, z)
    ob.rotation_euler = (0, math.radians(lean), 0)
    game.append(ob)
    return ob


def glass(color, carrier=False, name="g"):
    return P.make_brick("glass", color, carrier=carrier, name=name)


ball_xy, trail_dir, dotted = (655, 880), (-0.55, 0.85), False
capsule_kind, cap_xy = None, None
pad_w = 2.6

if WID == 1:
    rows = {2: ("GGGGGGGGGG", "sun"), 3: (".GGGGGGGG.", "tangerine"), 5: ("C...CC...C", None), 7: ("..dD..Dd..", "hotpink")}
    for r, (s, colr) in rows.items():
        for c, ch in enumerate(s):
            if ch == ".":
                continue
            if ch == "C":
                add(P.make_brick("chrome", name=f"b{r}{c}"), c, r)
            elif ch in "Dd":
                add(P.make_brick("double", colr, carrier=ch == "d", name=f"b{r}{c}"), c, r)
            else:
                add(glass(colr, name=f"b{r}{c}"), c, r)
    capsule_kind, cap_xy = "komet", (390, 1130)
    pad_w = 2.8
if WID == 2:
    for c in range(10):
        if c not in (4, 5):
            add(Q.brick_triple(ramp[0], name=f"t{c}"), c, 2)
    for c in range(1, 9):
        if c != 6:
            add(glass(ramp[1], carrier=c == 2, name=f"g3{c}"), c, 3)
    for k, c in enumerate((1, 3, 6, 8)):
        add(Q.brick_glider(ramp[2], name=f"m{c}"), c, 5, dx=0.18 if k < 2 else -0.18)
    for c in (0, 9):
        add(P.make_brick("chrome", name=f"c7{c}"), c, 7)
    for c in (2, 3, 6, 7):
        add(glass(ramp[3], name=f"g7{c}"), c, 7)
    capsule_kind, cap_xy = "bredvinge", (330, 1180)
if WID == 3:
    lean = 3.0
    dx = 0.35
    for r, colr in ((2, ramp[0]), (3, ramp[1]), (4, ramp[2]), (5, ramp[3])):
        for c in range(1, 8):
            if (r, c) in ((3, 4), (4, 3), (4, 4), (2, 6)):
                continue
            if (r, c) in ((3, 2), (4, 6), (2, 4)):
                add(Q.brick_nova(colr, name=f"n{r}{c}"), c, r, dx=dx, lean=lean)
            else:
                add(glass(colr, carrier=(r, c) == (5, 5), name=f"g{r}{c}"), c, r, dx=dx, lean=lean)
    capsule_kind, cap_xy = "neonpuls", (700, 1190)
if WID == 4:
    add(Q.brick_switch("A", name="sw0"), 0, 4)
    add(Q.brick_switch("A", name="sw9"), 9, 4)
    for c in range(1, 9):
        add(glass(ramp[0], name=f"g2{c}"), c, 2)
    for c in range(1, 9):
        add(Q.brick_ghost("A", ramp[1], solid=True, name=f"ga{c}"), c, 4)
    for c in range(1, 9):
        add(Q.brick_ghost("B", ramp[3], solid=False, name=f"gb{c}"), c, 6)
    for c in (2, 7):
        add(P.make_brick("chrome", name=f"c8{c}"), c, 8)
    capsule_kind, cap_xy = "saktetid", (430, 1190)
    dotted = True
    ball_xy = (690, 940)
if WID == 5:
    for c in range(10):
        if c in (1, 8):
            continue
        add(glass(ramp[0], name=f"g2{c}"), c, 2)
    for c in range(2, 8):
        add(P.make_brick("double", ramp[1], carrier=c == 4, name=f"d3{c}"), c, 3)
    p1 = Q.portal(1, name="p1a")
    add(p1, 1, 5)
    p1b = Q.portal(1, name="p1b")
    add(p1b, 8, 5)
    p2 = Q.portal(2, name="p2a")
    add(p2, 3, 8)
    p2b = Q.portal(2, name="p2b")
    add(p2b, 6, 8)
    for c in (0, 4, 5, 9):
        add(glass(ramp[2], name=f"g6{c}"), c, 6)
    capsule_kind, cap_xy = "skjoldnett", (250, 1200)
if WID == 6:
    boss = Q.boss_neonnova(36, 25, name="boss")
    bx, by, bz = P.logic_to_world(90 + 100 * 4.5, 366 + 52 * 3.5)
    boss.location = (bx, by, bz)
    game.append(boss)
    ring_cells = [(3, 1), (4, 1), (5, 1), (6, 1), (2, 2), (7, 2), (2, 4), (7, 4), (2, 3), (7, 3), (3, 5), (4, 5), (5, 5), (6, 5)]
    for k, (c, r) in enumerate(ring_cells):
        add(Q.brick_nova(ramp[k % 2], name=f"nr{k}"), c, r)
    for c in (0, 1, 8, 9):
        add(glass(ramp[2], name=f"g7{c}"), c, 7)
    capsule_kind, cap_xy = None, None
    ball_xy = (560, 980)

# ball + trail
ball = P.make_ball()
ball.location = P.logic_to_world(*ball_xy)
halo = P.make_ball_halo()
halo.location = ball.location
game += [ball, halo]
L_ = 150.0
if dotted:
    # Saktetid: dotted trail, 8 dots, every 22 px, shrinking
    dm = P.mat_pbr("trail_dot", "#000000", emit="#FFE6C8", emit_str=3.0, alpha=0.8)
    for k in range(1, 9):
        d_ = P.uv_sphere(f"td{k}", 0.075 * (1 - k / 10), dm, seg=10, rings=5)
        d_.location = P.logic_to_world(ball_xy[0] + trail_dir[0] * 24 * k, ball_xy[1] + trail_dir[1] * 24 * k, P.PLANE_Y + 0.05)
        game.append(d_)
else:
    tm = P.mat_pbr("trail", "#000000", emit=P.HEX["cyan"], emit_str=3.0, alpha=0.55)
    nx_, ny_ = 0.85, 0.55
    pts = [(ball_xy[0] + nx_ * 20, ball_xy[1] + ny_ * 20), (ball_xy[0] + trail_dir[0] * L_, ball_xy[1] + trail_dir[1] * L_), (ball_xy[0] - nx_ * 20, ball_xy[1] - ny_ * 20)]
    game.append(P.flat_shape("trail", [(x * P.PX, (1920 - y) * P.PX) for x, y in pts], P.PLANE_Y + 0.05, 0.01, tm))

if capsule_kind:
    cap = P.make_capsule() if capsule_kind == "komet" else Q.capsule(capsule_kind)
    cap.location = P.logic_to_world(*cap_xy)
    cap.rotation_euler = (0, math.radians(-10), 0)
    game.append(cap)

pad = Q.paddle_v2(pad_w)
pad.location = P.logic_to_world(470, 1420)
net = P.make_net(0.4, 10.4)
net.location = (0, P.PLANE_Y, (1920 - 1540) * P.PX)
game += [pad, net]
if WID in (2, 3, 5):
    for k in (-0.35, 0.0, 0.35) if WID == 5 else (-0.175, 0.175):
        pip = P.make_net_pip(f"pip{k}")
        pip.location = (5.4 + k, P.PLANE_Y - 0.06, (1920 - 1540) * P.PX)
        game.append(pip)

if VISTA:
    for ob in game:
        ob.hide_render = True


# ---- lights ----
def area(name, loc, rot, energy, color, size):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy = energy
    ld.color = color
    ld.size = size
    lo = bpy.data.objects.new(name, ld)
    lo.location = loc
    lo.rotation_euler = rot
    sc.collection.objects.link(lo)


kc = P.lin(WD["key"])[:3]
fc = P.lin(WD["fill"])[:3]
area("key", (3.0, -9.0, 22.0), (math.radians(35), math.radians(-10), 0), 2600, kc, 6.0)
area("fill", (5.4, -6.0, -4.0), (math.radians(140), 0, 0), 600, fc, 10.0)

# ---- bloom (stand-in for Godot glow levels 2-4, threshold 1.0) ----
sc.use_nodes = True
ct = sc.node_tree
ct.nodes.clear()
rl = ct.nodes.new("CompositorNodeRLayers")
gl = ct.nodes.new("CompositorNodeGlare")
gl.glare_type = "BLOOM"
for k, v in (("Threshold", 0.95), ("Strength", 0.6), ("Size", 0.6)):
    if k in gl.inputs:
        gl.inputs[k].default_value = v
cout = ct.nodes.new("CompositorNodeComposite")
ct.links.new(rl.outputs["Image"], gl.inputs["Image"])
ct.links.new(gl.outputs["Image"], cout.inputs["Image"])

sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("WROTE", OUT)
