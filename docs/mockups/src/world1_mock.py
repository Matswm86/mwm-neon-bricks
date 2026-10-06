"""Render the world 1 (Neonstranda) gameplay mock, 1080x1920.

blender -b -P docs/mockups/src/world1_mock.py -- <out.png> [less_motion]
Level 4 "Krompilarer" mid-play: glass, double, chrome, carrier, a falling Komet capsule.
"""

import math
import random
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).parent))
import nb_parts as P  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = argv[0] if argv else "/tmp/world1_raw.png"

random.seed(4)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene

# ---- render settings -------------------------------------------------------
try:
    sc.render.engine = "BLENDER_EEVEE_NEXT"
except TypeError as e:
    print(e)
sc.render.resolution_x, sc.render.resolution_y = 1080, 1920
sc.render.resolution_percentage = 100
sc.eevee.taa_render_samples = 48
try:
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
except TypeError as e:
    print("look", e)
sc.view_settings.exposure = 0.0

# ---- world sky (sunset gradient + stars) -----------------------------------
w = bpy.data.worlds.new("sky")
sc.world = w
w.use_nodes = True
nt = w.node_tree
nt.nodes.clear()
tc = nt.nodes.new("ShaderNodeTexCoord")
sep = nt.nodes.new("ShaderNodeSeparateXYZ")
ramp = nt.nodes.new("ShaderNodeValToRGB")
cr = ramp.color_ramp
cr.elements[0].position = 0.0
cr.elements[0].color = P.lin(P.HEX["horizon"])
cr.elements[1].position = 0.55
cr.elements[1].color = P.lin(P.HEX["sky_top"])
e = cr.elements.new(0.06)
e.color = P.lin(P.HEX["sky_low"])
e = cr.elements.new(0.22)
e.color = P.lin(P.HEX["sky_mid"])
vor = nt.nodes.new("ShaderNodeTexVoronoi")
vor.inputs["Scale"].default_value = 180.0
lt = nt.nodes.new("ShaderNodeMath")
lt.operation = "LESS_THAN"
lt.inputs[1].default_value = 0.035
hz = nt.nodes.new("ShaderNodeMath")
hz.operation = "GREATER_THAN"
hz.inputs[1].default_value = 0.12
stars = nt.nodes.new("ShaderNodeMath")
stars.operation = "MULTIPLY"
starc = nt.nodes.new("ShaderNodeMath")
starc.operation = "MULTIPLY"
starc.inputs[1].default_value = 0.6
add = nt.nodes.new("ShaderNodeMix")
add.data_type = "RGBA"
add.blend_type = "ADD"
add.inputs["Factor"].default_value = 1.0
bg = nt.nodes.new("ShaderNodeBackground")
bg.inputs["Strength"].default_value = 1.0
out = nt.nodes.new("ShaderNodeOutputWorld")
nt.links.new(tc.outputs["Generated"], sep.inputs[0])
nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
nt.links.new(tc.outputs["Generated"], vor.inputs["Vector"])
nt.links.new(vor.outputs["Distance"], lt.inputs[0])
nt.links.new(sep.outputs["Z"], hz.inputs[0])
nt.links.new(lt.outputs[0], stars.inputs[0])
nt.links.new(hz.outputs[0], stars.inputs[1])
nt.links.new(stars.outputs[0], starc.inputs[0])
nt.links.new(ramp.outputs["Color"], add.inputs["A"])
nt.links.new(starc.outputs[0], add.inputs["B"])
nt.links.new(add.outputs["Result"], bg.inputs["Color"])
nt.links.new(bg.outputs[0], out.inputs[0])

# ---- camera: perpendicular to the play plane, plane fills the frame --------
cam_d = cam = bpy.data.cameras.new("cam")
cam.lens = 45
cam.sensor_fit = "HORIZONTAL"
cam.sensor_width = 36
cam.clip_end = 2000
D = 5.4 * cam.lens / 18.0  # distance at which 10.8 m fills the width
co = bpy.data.objects.new("cam", cam)
sc.collection.objects.link(co)
EYE_Z = 6.2  # eye height above the sea = horizon line; lens shift keeps the plane framed
co.location = (5.4, P.PLANE_Y - D, EYE_Z)
cam.shift_y = (9.6 - EYE_Z) / 10.8  # Blender shift is a fraction of the sensor-fit width
co.rotation_euler = (math.radians(90), 0, 0)
sc.camera = co

# ---- vista: sun, sea grid, ridges, palms -----------------------------------
# sun: far disc with sliced lower half (shader mask)
sun_m = bpy.data.materials.new("sun")
sun_m.use_nodes = True
snt = sun_m.node_tree
snt.nodes.clear()
s_tc = snt.nodes.new("ShaderNodeTexCoord")
s_sep = snt.nodes.new("ShaderNodeSeparateXYZ")
s_map = snt.nodes.new("ShaderNodeMapRange")
s_map.inputs["From Min"].default_value = -1.0
s_map.inputs["From Max"].default_value = 1.0
s_ramp = snt.nodes.new("ShaderNodeValToRGB")
s_ramp.color_ramp.elements[0].color = P.lin(P.HEX["hotpink"])
s_ramp.color_ramp.elements[1].position = 0.85
s_ramp.color_ramp.elements[1].color = P.lin(P.HEX["sun"])
e = s_ramp.color_ramp.elements.new(0.5)
e.color = P.lin(P.HEX["tangerine"])
# slices: below z < 0.15 cut gaps, gap grows downward
s_mul = snt.nodes.new("ShaderNodeMath")
s_mul.operation = "MULTIPLY"
s_mul.inputs[1].default_value = 9.0
s_fr = snt.nodes.new("ShaderNodeMath")
s_fr.operation = "FRACT"
s_gap = snt.nodes.new("ShaderNodeMapRange")  # gap width by height
s_gap.inputs["From Min"].default_value = 0.45
s_gap.inputs["From Max"].default_value = -1.0
s_gap.inputs["To Min"].default_value = 0.0
s_gap.inputs["To Max"].default_value = 0.7
s_cmp = snt.nodes.new("ShaderNodeMath")
s_cmp.operation = "GREATER_THAN"
s_em = snt.nodes.new("ShaderNodeEmission")
s_em.inputs["Strength"].default_value = 1.4
s_tr = snt.nodes.new("ShaderNodeBsdfTransparent")
s_mix = snt.nodes.new("ShaderNodeMixShader")
s_out = snt.nodes.new("ShaderNodeOutputMaterial")
snt.links.new(s_tc.outputs["Object"], s_sep.inputs[0])
snt.links.new(s_sep.outputs["Z"], s_map.inputs["Value"])
snt.links.new(s_map.outputs["Result"], s_ramp.inputs["Fac"])
snt.links.new(s_ramp.outputs["Color"], s_em.inputs["Color"])
snt.links.new(s_sep.outputs["Z"], s_mul.inputs[0])
snt.links.new(s_mul.outputs[0], s_fr.inputs[0])
snt.links.new(s_sep.outputs["Z"], s_gap.inputs["Value"])
snt.links.new(s_fr.outputs[0], s_cmp.inputs[0])
snt.links.new(s_gap.outputs["Result"], s_cmp.inputs[1])
snt.links.new(s_cmp.outputs[0], s_mix.inputs["Fac"])
snt.links.new(s_tr.outputs[0], s_mix.inputs[1])
snt.links.new(s_em.outputs[0], s_mix.inputs[2])
snt.links.new(s_mix.outputs[0], s_out.inputs["Surface"])
try:
    sun_m.surface_render_method = "BLENDED"
except (AttributeError, TypeError):
    pass
sun_dist = 600.0
cam_y = co.location.y
px_per_rad = 960.0 / (9.6 / D)  # vertical px per radian near centre
sun_r = 300.0 / px_per_rad * (sun_dist - cam_y)
bpy.ops.mesh.primitive_circle_add(vertices=96, radius=1.0, fill_type="NGON", location=(5.4, sun_dist, EYE_Z + 0.02 * sun_r), rotation=(math.radians(90), 0, 0))
sun = bpy.context.active_object
sun.scale = (sun_r, sun_r, sun_r)
sun.data.materials.append(sun_m)

# horizon haze band (hides the sun's cut edge)
haze = P.mat_pbr("haze", "#000000", emit=P.HEX["hotpink"], emit_str=1.2, alpha=0.35)
bpy.ops.mesh.primitive_plane_add(size=1, location=(5.4, sun_dist - 5, EYE_Z), rotation=(math.radians(90), 0, 0))
hb = bpy.context.active_object
hb.scale = (3000, 6, 1)
hb.data.materials.append(haze)

# sea: dark glossy plane with emissive grid
sea_m = P.mat_pbr("sea", P.HEX["sea"], rough=0.08, metal=0.0)
snt = sea_m.node_tree
b = next(n for n in snt.nodes if n.type == "BSDF_PRINCIPLED")
g_tc = snt.nodes.new("ShaderNodeTexCoord")
g_sep = snt.nodes.new("ShaderNodeSeparateXYZ")
lines = []
for axis, period in (("X", 3.0), ("Y", 3.0)):
    m1 = snt.nodes.new("ShaderNodeMath")
    m1.operation = "DIVIDE"
    m1.inputs[1].default_value = period
    fr = snt.nodes.new("ShaderNodeMath")
    fr.operation = "PINGPONG"
    fr.inputs[1].default_value = 0.5
    lt2 = snt.nodes.new("ShaderNodeMath")
    lt2.operation = "LESS_THAN"
    lt2.inputs[1].default_value = 0.025
    snt.links.new(g_sep.outputs[axis], m1.inputs[0])
    snt.links.new(m1.outputs[0], fr.inputs[0])
    snt.links.new(fr.outputs[0], lt2.inputs[0])
    lines.append(lt2)
mx = snt.nodes.new("ShaderNodeMath")
mx.operation = "MAXIMUM"
snt.links.new(g_tc.outputs["Object"], g_sep.inputs[0])
snt.links.new(lines[0].outputs[0], mx.inputs[0])
snt.links.new(lines[1].outputs[0], mx.inputs[1])
# fade lines with distance (object Y)
fade = snt.nodes.new("ShaderNodeMapRange")
fade.inputs["From Min"].default_value = 0.0
fade.inputs["From Max"].default_value = 260.0
fade.inputs["To Min"].default_value = 1.1
fade.inputs["To Max"].default_value = 0.0
snt.links.new(g_sep.outputs["Y"], fade.inputs["Value"])
gm = snt.nodes.new("ShaderNodeMath")
gm.operation = "MULTIPLY"
snt.links.new(mx.outputs[0], gm.inputs[0])
snt.links.new(fade.outputs["Result"], gm.inputs[1])
b.inputs["Emission Color"].default_value = P.lin(P.HEX["magenta"])
snt.links.new(gm.outputs[0], b.inputs["Emission Strength"])
bpy.ops.mesh.primitive_plane_add(size=1, location=(5.4, 0, 0))
sea = bpy.context.active_object
sea.data.materials.append(sea_m)
# keep object coords in metres: scale mesh, not object
for v in sea.data.vertices:
    v.co.x *= 1600
    v.co.y *= 1200
for v in sea.data.vertices:
    v.co.y += 600 - 40

# ridges: wireframe hills on the horizon
bpy.ops.mesh.primitive_grid_add(x_subdivisions=60, y_subdivisions=6, size=1, location=(5.4, 330, 0))
rg = bpy.context.active_object
for v in rg.data.vertices:
    v.co.x *= 900
    v.co.y *= 120
    side = abs(v.co.x) / 450.0
    v.co.z = max(0.0, (math.sin(v.co.x * 0.03) * 0.5 + 0.6 + random.random() * 0.4) * 40 * side * (0.5 - v.co.y / 240))
wf = rg.modifiers.new("wf", "WIREFRAME")
wf.thickness = 0.5
rg.data.materials.append(P.mat_emit("ridge", P.HEX["ridge"], 2.5))

# palms (silhouettes) left and right, behind the play plane
pl = P.make_palm(26, lean=1, name="palm_l")
pl.location = (-6.5, 40, 0)
pr = P.make_palm(19, lean=-1, name="palm_r")
pr.location = (18.5, 44, 0)
pr2 = P.make_palm(14, lean=-1, name="palm_r2")
pr2.location = (23.0, 70, 0)

# ---- arena frame -----------------------------------------------------------
field_m = P.mat_pbr("field", "#000000", rough=1.0, alpha=0.72)
next(n for n in field_m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Specular IOR Level"].default_value = 0.0
bpy.ops.mesh.primitive_plane_add(size=1, location=(5.4, 0.12, (1920 - 990) * P.PX), rotation=(math.radians(90), 0, 0))
fld = bpy.context.active_object
fld.scale = (10.0, 14.2, 1)
fld.data.materials.append(field_m)

rail_m = P.mat_pbr("rail", P.HEX["wall_rail"], rough=0.45, metal=0.6)
tube_m = P.mat_emit("wall_tube", P.HEX["wall_tube"], 6.0)
z_top, z_bot = (1920 - 280) * P.PX, (1920 - 1700) * P.PX
for x0, x1 in ((0.0, 0.40), (10.40, 10.80)):
    r = P.rounded_box("rail", x1 - x0, 0.40, z_top - z_bot + 0.4, 0.06, rail_m)
    r.location = ((x0 + x1) / 2, P.PLANE_Y, (z_top + z_bot) / 2 + 0.2)
    xt = x1 if x0 == 0 else x0
    t = P.tube_loop("wtube", [(xt, z_bot + 0.1), (xt, z_top)], P.PLANE_Y - 0.22, 0.03, tube_m, closed=False)
top = P.rounded_box("rail_top", 10.8, 0.40, 0.40, 0.06, rail_m)
top.location = (5.4, P.PLANE_Y, z_top + 0.2)
P.tube_loop("ttube", [(0.4, z_top), (10.4, z_top)], P.PLANE_Y - 0.22, 0.03, tube_m, closed=False)
# rail end caps (small cyan lamps)
for x in (0.2, 10.6):
    c = P.uv_sphere("railcap", 0.12, P.mat_emit("railcap", P.HEX["cyan"], 6.0))
    c.location = (x, P.PLANE_Y - 0.2, z_bot + 0.05)

# ---- level 4 "Krompilarer" mid-play ---------------------------------------
rows = {
    2: "GGGGGGGGGG",
    3: ".GGGGGGGG.",
    5: "C...CC...C",
    7: "..dD..Dd..",
}
row_col = {2: "sun", 3: "tangerine", 5: None, 7: "hotpink"}
broken = {(2, 3), (2, 4), (3, 4), (3, 5), (7, 3)}
half = {(7, 2)}  # carrier double already hit once (one dot left)
for r, s in rows.items():
    for c, ch in enumerate(s):
        if ch == "." or (r, c) in broken:
            continue
        x, y = 90 + 100 * c, 366 + 52 * r
        if ch == "C":
            ob = P.make_brick("chrome", name=f"b{r}{c}")
        elif ch in "Dd":
            ob = P.make_brick("double", row_col[r], hits_left=1 if (r, c) in half else 2, carrier=ch == "d", name=f"b{r}{c}")
        else:
            ob = P.make_brick("glass", row_col[r], carrier=ch == "g", name=f"b{r}{c}")
        ob.location = P.logic_to_world(x, y)

# shards from the brick just broken at (3,5): small emissive triangles
shard_m = P.mat_emit("shard", P.HEX["tangerine"], 7.0)
bx, by = 90 + 500, 366 + 156
for i in range(24):
    a = random.uniform(0, 2 * math.pi)
    d = random.uniform(10, 120)
    s = random.uniform(0.04, 0.09)
    tri = P.flat_shape("shard", [(0, s), (s * 0.8, -s * 0.6), (-s * 0.7, -s * 0.5)], 0, 0.01, shard_m)
    tri.location = P.logic_to_world(bx + math.cos(a) * d * 1.3, by + math.sin(a) * d * 0.7, P.PLANE_Y - random.uniform(0.1, 1.2))
    tri.rotation_euler = (random.uniform(0, 3), random.uniform(0, 3), random.uniform(0, 3))
# ball + short trail
ball = P.make_ball()
bxy = (655, 880)
ball.location = P.logic_to_world(*bxy)
halo = P.make_ball_halo()
halo.location = ball.location
# trail: one tapered additive ribbon (Godot: a 12-point ribbon mesh, unshaded additive)
tdir = (-0.55, 0.85)
L = 150.0
tm = P.mat_pbr("trail", "#000000", emit=P.HEX["cyan"], emit_str=3.0, alpha=0.55)
nx, ny = 0.85, 0.55
pts = [(bxy[0] + nx * 20, bxy[1] + ny * 20), (bxy[0] + tdir[0] * L, bxy[1] + tdir[1] * L), (bxy[0] - nx * 20, bxy[1] - ny * 20)]
rib = P.flat_shape("trail", [(x * P.PX, (1920 - y) * P.PX) for x, y in pts], P.PLANE_Y + 0.05, 0.01, tm)

# falling Komet capsule from the broken carrier at (7,3)
cap = P.make_capsule()
cap.location = P.logic_to_world(390, 1130)
cap.rotation_euler = (0, math.radians(-12), 0)

# paddle (Vanlig world 1: 280 px) and net
pad = P.make_paddle(2.8)
pad.location = P.logic_to_world(470, 1420)
net = P.make_net(0.4, 10.4)
net.location = (0, P.PLANE_Y, (1920 - 1540) * P.PX)

# ---- lights ----------------------------------------------------------------
def area(name, loc, rot, energy, color, size):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy = energy
    ld.color = color
    ld.size = size
    lo = bpy.data.objects.new(name, ld)
    lo.location = loc
    lo.rotation_euler = rot
    sc.collection.objects.link(lo)
    return lo


# key: soft cool-white from above-front (gives the top-bevel highlight on bricks)
area("key", (3.0, -9.0, 22.0), (math.radians(35), math.radians(-10), 0), 2600, (0.85, 0.9, 1.0), 6.0)
# warm sunset fill from below (horizon colour on the lower bevels)
area("fill", (5.4, -6.0, -4.0), (math.radians(140), 0, 0), 900, (1.0, 0.45, 0.35), 10.0)

# ---- compositor bloom ------------------------------------------------------
sc.use_nodes = True
ct = sc.node_tree
ct.nodes.clear()
rl = ct.nodes.new("CompositorNodeRLayers")
gl = ct.nodes.new("CompositorNodeGlare")
gl.glare_type = "BLOOM"
for k, v in (("Threshold", 0.9), ("Strength", 0.6), ("Size", 0.6)):
    if k in gl.inputs:
        gl.inputs[k].default_value = v
try:
    gl.quality = "HIGH"
except (AttributeError, TypeError):
    pass
co_out = ct.nodes.new("CompositorNodeComposite")
ct.links.new(rl.outputs["Image"], gl.inputs["Image"])
ct.links.new(gl.outputs["Image"], co_out.inputs["Image"])

sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).parent / "world1_mock.blend"))
print("WROTE", OUT)
