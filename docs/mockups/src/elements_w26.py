"""Element sheet for worlds 2-6 + GLB export (DESIGN section 12).

blender -b -P docs/mockups/src/elements_w26.py -- <raw_out.png> <labels.json> <models_dir>
"""

import json
import math
import sys
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view

sys.path.insert(0, str(Path(__file__).parent))
import nb_parts as P  # noqa: E402
import nb_parts_w26 as Q  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :]
OUT, LABELS, MODELS = argv[0], argv[1], Path(argv[2])

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE_NEXT"
sc.render.resolution_x, sc.render.resolution_y = 2048, 1700
sc.eevee.taa_render_samples = 48
sc.view_settings.view_transform = "Standard"
w = bpy.data.worlds.new("bg")
sc.world = w
w.use_nodes = True
bgn = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
bgn.inputs["Color"].default_value = P.lin("#140B33")

items = []


def put(ob, x, z, label, s=1.15):
    ob.location = (x, 0.0, z)
    ob.scale = (s, s, s)
    items.append((ob, label))
    return ob


# row A: new bricks
put(Q.brick_triple("hotpink", name="type_triple"), 1.2, 9.4, "Triple: 3 dots")
put(Q.brick_glider("tangerine", name="type_glider"), 2.9, 9.4, "Glider: chevrons")
put(Q.brick_nova("violet", name="type_nova"), 4.6, 9.4, "Nova: 4-point star")
put(Q.brick_switch("A", name="type_switch_a"), 6.3, 9.4, "Switch, set A solid")
put(Q.brick_switch("B", name="type_switch_b"), 8.0, 9.4, "Switch, set B solid")
# row B: ghosts
put(Q.brick_ghost("A", "coral", True, name="type_ghost_a"), 1.2, 7.6, "Ghost A solid: square corners")
put(Q.brick_ghost("A", "coral", False, name="ghost_a_phased"), 3.5, 7.6, "Ghost A phased: 30%")
put(Q.brick_ghost("B", "hotpink", True, name="type_ghost_b"), 5.8, 7.6, "Ghost B solid: round dots")
put(Q.brick_ghost("B", "hotpink", False, name="ghost_b_phased"), 8.1, 7.6, "Ghost B phased: 30%")
# row C: portals + capsules
put(Q.portal(1, name="type_portal_1"), 1.2, 5.7, "Portal pair 1: one spiral", s=1.0)
put(Q.portal(2, name="type_portal_2"), 3.0, 5.7, "Portal pair 2: spiral + star", s=1.0)
for k, kind in enumerate(("saktetid", "skjoldnett", "bredvinge", "neonpuls")):
    put(Q.capsule(kind), 4.9 + k * 1.75, 5.7, f"Capsule {kind}: " + {"saktetid": "cassette", "skjoldnett": "net + plus", "bredvinge": "winged paddle", "neonpuls": "paddle + arcs"}[kind], s=1.0)
# row D: bosses
put(Q.boss_lastebilen(24, 17, name="type_boss_l20"), 1.9, 3.7, "Boss L20 Lastebilen", s=1.0)
put(Q.boss_krystallhjertet(24, 20, name="type_boss_l25"), 5.6, 3.7, "Boss L25 Krystallhjertet", s=1.0)
put(Q.boss_neonnova(36, 25, name="type_boss_l30"), 9.3, 3.7, "Boss L30 Neonnova", s=1.0)
# row E: paddle before / after
old = put(P.make_paddle(2.8, name="paddle_old"), 2.4, 1.9, "Paddle v1: dark shell", s=1.0)
put(Q.paddle_v2(2.8, name="paddle_vanlig"), 6.4, 1.9, "Paddle v2: lit blue-steel face", s=1.0)
pl = Q.paddle_v2(4.0, name="paddle_lett")
pl.location = (30, 0, 0)

cam = bpy.data.cameras.new("cam")
cam.type = "ORTHO"
cam.ortho_scale = 12.4
co = bpy.data.objects.new("cam", cam)
sc.collection.objects.link(co)
co.location = (5.6, -20.0, 5.7 + 20 * math.tan(math.radians(10)))
co.rotation_euler = (math.radians(80), 0, 0)
sc.camera = co


def area(name, loc, rot, energy, color, size):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy, ld.color, ld.size = energy, color, size
    lo = bpy.data.objects.new(name, ld)
    lo.location, lo.rotation_euler = loc, rot
    sc.collection.objects.link(lo)


bpy.ops.mesh.primitive_plane_add(size=1, location=(6.0, -40.0, 12.0), rotation=(math.radians(-80), 0, 0))
rc = bpy.context.active_object
rc.scale = (60, 14, 1)
rc.data.materials.append(P.mat_emit("refl_card", "#B8C4FF", 1.2))
area("key", (4.0, -10.0, 16.0), (math.radians(40), math.radians(-12), 0), 3000, (0.85, 0.9, 1.0), 8.0)
area("fill", (6.0, -8.0, -6.0), (math.radians(135), 0, 0), 900, (1.0, 0.45, 0.35), 12.0)

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
labels = []
for ob, lab in items:
    p = world_to_camera_view(sc, co, ob.location)
    labels.append({"label": lab, "x": p.x * W, "y": (1 - p.y) * H})
Path(LABELS).write_text(json.dumps(labels, indent=1))

# ---- GLB export: element pieces + world props, origin centre, metres, Y-up ----
MODELS.mkdir(parents=True, exist_ok=True)
pole_m = P.mat_pbr("pole", "#120A16", rough=0.5, metal=0.6)
props = {
    "prop_city_tower": Q.tower("prop_city_tower", 14.0, 40.0, 8.0, P.mat_pbr("tower_body", "#0C1638", rough=0.8), crown=True, steps=2),
    "prop_arcade_cabinet": Q.cabinet("prop_arcade_cabinet", P.mat_pbr("cab_body", "#0B0612", rough=0.6), P.mat_emit("cab_marquee", "#FFE14D", 1.4), P.mat_emit("cab_screen", "#FF3D6E", 1.4)),
    "prop_lamp_post": Q.lamp_post("prop_lamp_post", pole_m, P.mat_emit("lamp_head", "#FFB23D", 1.6)),
    "prop_crystal_cluster": Q.crystal_cluster("prop_crystal_cluster", 4.0, P.mat_pbr("crystal_vio", "#2A1A80", rough=0.1, coat=1.0, emit="#4A2CB0", emit_str=0.9), None, seed=1),
    "prop_stalactite": Q.stalactite("prop_stalactite", 2.5, 0.75, P.mat_pbr("rock", "#07101A", rough=0.9, emit="#0B2A26", emit_str=0.8), P.mat_emit("stal_tip", "#4DFF9A", 3.0)),
    "prop_ring_gate": Q.ring_gate("prop_ring_gate", 40.0, P.mat_pbr("gate_body", "#2A1A5A", rough=0.25, metal=0.7, emit="#5A2CB0", emit_str=0.9), P.mat_emit("gate_bead", "#FFD27A", 1.6)),
}
# bosses for the game: core disc + ring only; notches are spawned in code per HP (DESIGN 12.6)
for fn, nm in ((Q.boss_lastebilen, "glb_boss_l20"), (Q.boss_krystallhjertet, "glb_boss_l25"), (Q.boss_neonnova, "glb_boss_l30")):
    fn(0, 0, name=nm).location = (0, 60, 0)
for o in props.values():
    o.location = (0, 50, 0)
export = {
    "brick_triple": "type_triple",
    "brick_glider": "type_glider",
    "brick_nova": "type_nova",
    "brick_switch": "type_switch_a",
    "brick_ghost_a": "type_ghost_a",
    "brick_ghost_b": "type_ghost_b",
    "portal_1": "type_portal_1",
    "portal_2": "type_portal_2",
    "capsule_saktetid": "capsule_saktetid",
    "capsule_skjoldnett": "capsule_skjoldnett",
    "capsule_bredvinge": "capsule_bredvinge",
    "capsule_neonpuls": "capsule_neonpuls",
    "boss_lastebilen": "glb_boss_l20",
    "boss_krystallhjertet": "glb_boss_l25",
    "boss_neonnova": "glb_boss_l30",
    "paddle_vanlig_280": "paddle_vanlig",
    "paddle_lett_400": "paddle_lett",
}
export.update({k: k for k in props})
info = {}
for fname, oname in export.items():
    ob = bpy.data.objects[oname]
    loc, scl = ob.location.copy(), ob.scale.copy()
    ob.location = (0, 0, 0)
    ob.scale = (1, 1, 1)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.context.view_layer.update()
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    info[fname] = {"size": [round(v, 3) for v in ob.dimensions], "tris": tris, "mats": [m.name for m in ob.data.materials]}
    bpy.ops.export_scene.gltf(filepath=str(MODELS / f"{fname}.glb"), use_selection=True, export_format="GLB", export_yup=True, export_apply=True)
    ob.location, ob.scale = loc, scl
print("INFO", json.dumps(info))
