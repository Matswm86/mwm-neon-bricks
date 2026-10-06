"""Element sheet render + GLB export for MWM Neon Bricks.

blender -b -P docs/mockups/src/elements.py -- <raw_out.png> <labels.json> <models_dir>
"""

import json
import math
import sys
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view

sys.path.insert(0, str(Path(__file__).parent))
import nb_parts as P  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :]
OUT, LABELS, MODELS = argv[0], argv[1], Path(argv[2])

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE_NEXT"
sc.render.resolution_x, sc.render.resolution_y = 2048, 1600
sc.eevee.taa_render_samples = 48
sc.view_settings.view_transform = "Standard"

w = bpy.data.worlds.new("bg")
sc.world = w
w.use_nodes = True
bgn = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
bgn.inputs["Color"].default_value = P.lin("#140B33")
bgn.inputs["Strength"].default_value = 1.0

labels = []
items = []


def place(ob, x, z, label):
    ob.location = (x, 0.0, z)
    items.append((ob, label))
    return ob


# row A: shared brick colours (glass)
cols = ["sun", "tangerine", "coral", "hotpink", "magenta", "violet", "cyan", "mint"]
for i, c in enumerate(cols):
    place(P.make_brick("glass", c, name=f"sw_{c}"), 1.2 + i * 1.25, 9.0, f"{c} {P.HEX[c]}")

# row B: the slice brick types
B = [
    (P.make_brick("glass", "sun", name="type_glass"), "Glass: plain slab"),
    (P.make_brick("double", "hotpink", name="type_double"), "Double: two dots"),
    (P.make_brick("double", "hotpink", hits_left=1, name="type_double_hit"), "Double hit once: one dot + crack"),
    (P.make_brick("chrome", name="type_chrome"), "Chrome: stripes + 4 bolts, no glow"),
    (P.make_brick("glass", "tangerine", carrier=True, name="type_carrier_g"), "Carrier glass: star inlay"),
    (P.make_brick("double", "hotpink", carrier=True, name="type_carrier_d"), "Carrier double"),
]
for i, (ob, lab) in enumerate(B):
    place(ob, 1.2 + i * 1.68, 7.1, lab)
    ob.scale = (1.15, 1.15, 1.15)

# row C: paddles
place(P.make_paddle(2.8, name="paddle_vanlig"), 2.4, 5.3, "Paddle Vanlig 280 px = 2.8 m")
place(P.make_paddle(4.0, name="paddle_lett"), 7.4, 5.3, "Paddle Lett 400 px = 4.0 m")

# row D: ball, Komet ball, capsule
place(P.make_ball("ball_plain"), 1.3, 3.5, "Ball r 0.22 m")
kb = place(P.make_ball("ball_komet"), 4.2, 3.5, "Komet ball: tail + spark count")
tail = P.flat_shape("komet_tail", [(0.0, 0.2), (-1.4, 0.04), (-1.5, 0.0), (-1.4, -0.04), (0.0, -0.2)], 0.05, 0.01, P.mat_pbr("komet_tail", "#000000", emit=P.HEX["sun"], emit_str=4.0, alpha=0.7))
tail.location = (4.2, 0.0, 3.5)
for k in range(8):
    a = math.radians(k * 45)
    sp = P.uv_sphere(f"spark{k}", 0.045, P.mat_emit("spark", P.HEX["sun"], 8.0), seg=10, rings=6)
    sp.location = (4.2 + math.cos(a) * 0.38, -0.05, 3.5 + math.sin(a) * 0.38)
place(P.make_capsule(), 7.2, 3.5, "Komet capsule 112x56 px")

# row E: nets
place(P.make_net(0.0, 3.6, name="net_unlimited"), 0.4, 1.6, "Net: unlimited")
n3 = place(P.make_net(0.0, 3.6, name="net_3"), 5.4, 1.6, "Net: 3 charges = 3 diamonds")
for k in (-0.35, 0.0, 0.35):
    pip = P.make_net_pip(f"pip{k}")
    pip.location = (5.4 + 1.8 + k, -0.06, 1.6)
# empty net: dashed line, no catch
dm = P.mat_pbr("net_dash", "#000000", emit=P.HEX["net"], emit_str=1.2)
for k in range(12):
    x0 = 10.4 + k * 0.3
    P.tube_loop(f"dash{k}", [(x0, 1.6), (x0 + 0.15, 1.6)], 0.0, 0.02, dm, closed=False)
items.append((None, "Net: 0 charges = dashed, no catch", (12.2, 1.6)))

# camera: front, slightly from above so bevels and depth read
cam = bpy.data.cameras.new("cam")
cam.type = "ORTHO"
cam.ortho_scale = 16.6
co = bpy.data.objects.new("cam", cam)
sc.collection.objects.link(co)
co.location = (8.0, -20.0, 5.8 + 20 * math.tan(math.radians(12)))
co.rotation_euler = (math.radians(78), 0, 0)
sc.camera = co


def area(name, loc, rot, energy, color, size):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy, ld.color, ld.size = energy, color, size
    lo = bpy.data.objects.new(name, ld)
    lo.location, lo.rotation_euler = loc, rot
    sc.collection.objects.link(lo)


# reflection card behind the camera so chrome reads as polished metal (Godot: sky radiance does this)
bpy.ops.mesh.primitive_plane_add(size=1, location=(8.0, -40.0, 12.0), rotation=(math.radians(-80), 0, 0))
rc = bpy.context.active_object
rc.scale = (60, 14, 1)
rc.data.materials.append(P.mat_emit("refl_card", "#B8C4FF", 1.2))
for t in ("SPHERE", "CUBE"):
    try:
        bpy.ops.object.lightprobe_add(type=t, location=(6.0, -1.0, 7.0))
        bpy.context.active_object.data.influence_distance = 4.0
        break
    except TypeError:
        continue
area("key", (4.0, -10.0, 16.0), (math.radians(40), math.radians(-12), 0), 3000, (0.85, 0.9, 1.0), 8.0)
area("fill", (8.0, -8.0, -6.0), (math.radians(135), 0, 0), 1200, (1.0, 0.45, 0.35), 12.0)

sc.use_nodes = True
ct = sc.node_tree
ct.nodes.clear()
rl = ct.nodes.new("CompositorNodeRLayers")
gl = ct.nodes.new("CompositorNodeGlare")
gl.glare_type = "BLOOM"
for k, v in (("Threshold", 0.9), ("Strength", 0.5), ("Size", 0.5)):
    if k in gl.inputs:
        gl.inputs[k].default_value = v
cout = ct.nodes.new("CompositorNodeComposite")
ct.links.new(rl.outputs["Image"], gl.inputs["Image"])
ct.links.new(gl.outputs["Image"], cout.inputs["Image"])

sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)

W, H = sc.render.resolution_x, sc.render.resolution_y
for it in items:
    if it[0] is None:
        x, z = it[2]
        from mathutils import Vector

        p = world_to_camera_view(sc, co, Vector((x, 0, z)))
    else:
        p = world_to_camera_view(sc, co, it[0].location)
    labels.append({"label": it[1], "x": p.x * W, "y": (1 - p.y) * H})
Path(LABELS).write_text(json.dumps(labels, indent=1))

# ---- GLB export: one clean asset per file, at origin, metres -----------------
MODELS.mkdir(parents=True, exist_ok=True)
export = {
    "brick_glass": "type_glass",
    "brick_double": "type_double",
    "brick_double_hit": "type_double_hit",
    "brick_chrome": "type_chrome",
    "brick_carrier_glass": "type_carrier_g",
    "paddle_vanlig_280": "paddle_vanlig",
    "paddle_lett_400": "paddle_lett",
    "ball": "ball_plain",
    "capsule_komet": "capsule_komet",
}
sizes = {}
for fname, oname in export.items():
    ob = bpy.data.objects[oname]
    loc, scl = ob.location.copy(), ob.scale.copy()
    ob.location = (0, 0, 0)
    ob.scale = (1, 1, 1)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.context.view_layer.update()
    dims = tuple(round(v, 3) for v in ob.dimensions)
    sizes[fname] = dims
    bpy.ops.export_scene.gltf(filepath=str(MODELS / f"{fname}.glb"), use_selection=True, export_format="GLB", export_yup=True, export_apply=True)
    ob.location, ob.scale = loc, scl
palm = P.make_palm(22, lean=1, name="palm_silhouette")
bpy.ops.object.select_all(action="DESELECT")
palm.select_set(True)
bpy.context.view_layer.update()
sizes["palm_silhouette"] = tuple(round(v, 3) for v in palm.dimensions)
bpy.ops.export_scene.gltf(filepath=str(MODELS / "palm_silhouette.glb"), use_selection=True, export_format="GLB", export_yup=True, export_apply=True)
print("SIZES", json.dumps(sizes))
bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).parent / "elements.blend"))
