"""MWM Neon Bricks look-dev parts for Blender 4.5 (run inside Blender, background mode).

Logic px (1080x1920 portrait) map to metres: 1 px = 0.01 m.
World axes: X right, Z up, play plane faces the camera at -Y.
Logic (px, py) -> world (px*0.01, PLANE_Y, (1920-py)*0.01).
"""

import math

import bmesh
import bpy

PX = 0.01
PLANE_Y = -0.20  # centre plane of bricks, ball and paddle

# ---- palette (hex) -------------------------------------------------------
HEX = {
    # shared brick ramp
    "sun": "#FFC93C",
    "tangerine": "#FF8A3D",
    "coral": "#FF5A5F",
    "hotpink": "#FF2E88",
    "magenta": "#D63AF9",
    "violet": "#8A5CFF",
    "cyan": "#2EE6FF",
    "mint": "#3DFFB0",
    # fixed elements
    "chrome": "#C9CED8",
    "chrome_stripe": "#9AA1B0",
    "bolt": "#5E6472",
    "dot": "#FFF4D6",
    "star": "#FFE7A0",
    "paddle_body": "#1C1A33",
    "paddle_light": "#2EE6FF",
    "ball": "#FFFFFF",
    "net": "#2EE6FF",
    "wall_tube": "#FF2E88",
    "wall_rail": "#15122B",
    "field": "#0B0820",
    # world 1 vista
    "sky_top": "#0B0630",
    "sky_mid": "#3A0E5C",
    "sky_low": "#C2186B",
    "horizon": "#FF7A3D",
    "sea": "#07041A",
    "grid": "#2EE6FF",
    "palm": "#12061F",
    "ridge": "#FF2E88",
}


def lin(h: str) -> tuple:
    h = h.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i : i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (out[0], out[1], out[2], 1.0)


def logic_to_world(px: float, py: float, y: float = PLANE_Y) -> tuple:
    return (px * PX, y, (1920 - py) * PX)


# ---- materials -------------------------------------------------------------
def _bsdf(mat):
    return next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def mat_pbr(name, color, rough=0.2, metal=0.0, emit=None, emit_str=0.0, coat=0.0, alpha=1.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = _bsdf(m)
    b.inputs["Base Color"].default_value = lin(color)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = lin(emit)
        b.inputs["Emission Strength"].default_value = emit_str
    if coat:
        b.inputs["Coat Weight"].default_value = coat
        b.inputs["Coat Roughness"].default_value = 0.05
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except (AttributeError, TypeError):
            m.blend_method = "BLEND"
    return m


def mat_emit(name, color, strength):
    """Unshaded-style emitter (Godot: unshaded + emission energy)."""
    return mat_pbr(name, "#000000", rough=0.5, emit=color, emit_str=strength)


def mat_brick(color):
    # Glossy candy: coloured base, clear coat, low self-emission so it reads in the dark.
    return mat_pbr(f"brick_{color}", color, rough=0.18, coat=1.0, emit=color, emit_str=0.45)


def mat_chrome():
    m = bpy.data.materials.get("brick_chrome")
    if m:
        return m
    m = mat_pbr("brick_chrome", HEX["chrome"], rough=0.22, metal=1.0)
    nt = m.node_tree
    b = _bsdf(m)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = 7.0
    frac = nt.nodes.new("ShaderNodeMath")
    frac.operation = "FRACT"
    gt = nt.nodes.new("ShaderNodeMath")
    gt.operation = "GREATER_THAN"
    gt.inputs[1].default_value = 0.5
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = lin(HEX["chrome"])
    mix.inputs["B"].default_value = lin(HEX["chrome_stripe"])
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    nt.links.new(sep.outputs["X"], add.inputs[0])
    nt.links.new(sep.outputs["Z"], add.inputs[1])
    nt.links.new(add.outputs[0], mul.inputs[0])
    nt.links.new(mul.outputs[0], frac.inputs[0])
    nt.links.new(frac.outputs[0], gt.inputs[0])
    nt.links.new(gt.outputs[0], mix.inputs["Factor"])
    nt.links.new(mix.outputs["Result"], b.inputs["Base Color"])
    return m


# ---- mesh helpers ----------------------------------------------------------
def _link(obj, coll=None):
    (coll or bpy.context.scene.collection).objects.link(obj)
    return obj


def rounded_box(name, sx, sy, sz, bevel, mat, segments=4):
    """Box sx (x) by sy (depth) by sz (z), rounded edges."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= sx
        v.co.y *= sy
        v.co.z *= sz
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=segments, profile=0.5, affect="EDGES")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    ob.data.materials.append(mat)
    return _link(ob)


def stadium_points(w, h, n=12):
    r = h / 2
    pts = []
    cx = w / 2 - r
    for i in range(n + 1):
        a = -math.pi / 2 + math.pi * i / n
        pts.append((cx + r * math.cos(a), r * math.sin(a)))
    for i in range(n + 1):
        a = math.pi / 2 + math.pi * i / n
        pts.append((-cx + r * math.cos(a), r * math.sin(a)))
    return pts


def rrect_points(w, h, r, n=4):
    pts = []
    corners = [(w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)]
    for cx, cz, a0 in corners:
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((cx + r * math.cos(a), cz + r * math.sin(a)))
    return pts


def extrude_profile(name, pts, depth, mat, bevel=0.04, segs=4):
    """2D profile in (x, z), extruded along Y (depth centred on 0), rounded."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    front = [bm.verts.new((x, -depth / 2, z)) for x, z in pts]
    back = [bm.verts.new((x, depth / 2, z)) for x, z in pts]
    bm.faces.new(front[::-1])
    bm.faces.new(back)
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    rim = [e for e in bm.edges if abs(e.verts[0].co.y - e.verts[1].co.y) < 1e-6]
    bmesh.ops.bevel(bm, geom=rim, offset=bevel, segments=segs, profile=0.5, affect="EDGES")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    ob.data.materials.append(mat)
    return _link(ob)


def tube_loop(name, pts, y, radius, mat, closed=True):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 3
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for p, (x, z) in zip(sp.points, pts):
        p.co = (x, y, z, 1.0)
    sp.use_cyclic_u = closed
    ob = bpy.data.objects.new(name, cu)
    ob.data.materials.append(mat)
    return _link(ob)


def to_mesh_and_join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    return ob


def star_points(r_out, r_in, n=5, rot=90):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + 180 * i / n)
        pts.append((r * math.cos(a), r * math.sin(a)))
    return pts


def flat_shape(name, pts, y, thick, mat):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    f = [bm.verts.new((x, y - thick / 2, z)) for x, z in pts]
    b = [bm.verts.new((x, y + thick / 2, z)) for x, z in pts]
    bm.faces.new(f[::-1])
    bm.faces.new(b)
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((f[i], f[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.data.materials.append(mat)
    return _link(ob)


def uv_sphere(name, r, mat, seg=32, rings=16):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    ob.data.materials.append(mat)
    return _link(ob)


def cylinder_y(name, r, depth, mat, verts=16):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=r, radius2=r, depth=depth)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=__import__("mathutils").Matrix.Rotation(math.pi / 2, 3, "X"))
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.data.materials.append(mat)
    return _link(ob)


# ---- game parts (all built at origin, metres) ------------------------------
BRICK_W, BRICK_H, BRICK_D = 0.92, 0.44, 0.30


def make_brick(kind, color="hotpink", hits_left=2, carrier=False, name=None):
    """kind: glass | double | chrome. Front face at y = -BRICK_D/2."""
    name = name or f"brick_{kind}"
    if kind == "chrome":
        body = rounded_box(name, BRICK_W, BRICK_D, BRICK_H, 0.05, mat_chrome())
        parts = [body]
        bolt_m = mat_pbr("bolt", HEX["bolt"], rough=0.35, metal=1.0)
        for sx in (-1, 1):
            for sz in (-1, 1):
                b = cylinder_y(f"{name}_bolt", 0.035, 0.03, bolt_m, verts=6)
                b.location = (sx * 0.36, -BRICK_D / 2 - 0.005, sz * 0.13)
                parts.append(b)
        return to_mesh_and_join(parts, name)
    col = HEX[color]
    body = rounded_box(name, BRICK_W, BRICK_D, BRICK_H, 0.07, mat_brick(col))
    parts = [body]
    rim = tube_loop(f"{name}_rim", rrect_points(BRICK_W - 0.12, BRICK_H - 0.12, 0.05), -BRICK_D / 2 - 0.004, 0.012, mat_emit(f"rim_{col}", col, 6.0))
    parts.append(rim)
    if kind == "double":
        dot_m = mat_pbr("dot", HEX["dot"], rough=0.2, emit=HEX["dot"], emit_str=3.0)
        xs = [-0.17, 0.17] if hits_left == 2 else [-0.17]
        for x in xs:
            d = uv_sphere(f"{name}_dot", 0.075, dot_m, seg=20, rings=10)
            d.scale = (1, 0.6, 1)
            d.location = (x, -BRICK_D / 2 - 0.01, 0)
            parts.append(d)
        if hits_left == 1:
            crack_m = mat_pbr("crack", "#1A0614", rough=0.6)
            cpts = [(0.08, 0.16), (0.14, 0.05), (0.10, -0.02), (0.20, -0.08), (0.17, -0.17)]
            pts = cpts + [(x + 0.02, z) for x, z in reversed(cpts)]
            parts.append(flat_shape(f"{name}_crack", pts, -BRICK_D / 2 - 0.004, 0.006, crack_m))
    if carrier:
        star_m = mat_pbr("star_inlay", HEX["star"], rough=0.2, emit=HEX["star"], emit_str=4.0)
        x0 = 0.0 if kind == "glass" else 0.17
        st = flat_shape(f"{name}_star", star_points(0.12, 0.05), -BRICK_D / 2 - 0.006, 0.012, star_m)
        st.location.x = x0
        if kind == "double":
            st.location.x = 0.0
            st.scale = (0.75, 1, 0.75)
        parts.append(st)
    return to_mesh_and_join(parts, name)


def make_paddle(width=2.8, name="paddle"):
    h = 0.36
    body_m = mat_pbr("paddle_body", HEX["paddle_body"], rough=0.25, metal=0.7, coat=1.0)
    body = extrude_profile(name, stadium_points(width, h), 0.36, body_m, bevel=0.05)
    strip = tube_loop(f"{name}_strip", stadium_points(width - 0.10, h - 0.12, 10), -0.185, 0.022, mat_emit("paddle_light", HEX["paddle_light"], 7.0))
    caps = []
    cap_m = mat_emit("paddle_cap", "#E8FDFF", 8.0)
    for s in (-1, 1):
        c = uv_sphere(f"{name}_cap", 0.07, cap_m, seg=16, rings=8)
        c.scale = (1, 0.5, 1)
        c.location = (s * (width / 2 - 0.18), -0.19, 0)
        caps.append(c)
    return to_mesh_and_join([body, strip, *caps], name)


def make_ball(name="ball"):
    return uv_sphere(name, 0.22, mat_pbr("ball", HEX["ball"], rough=0.1, emit="#FFFFFF", emit_str=9.0))


def make_ball_halo(name="ball_halo"):
    return uv_sphere(name, 0.30, mat_pbr("ball_halo", "#000000", emit=HEX["cyan"], emit_str=2.5, alpha=0.25))


def make_capsule(name="capsule_komet"):
    w, h = 1.12, 0.56
    body = extrude_profile(name, stadium_points(w, h), 0.30, mat_pbr("capsule_body", "#140F2E", rough=0.15, coat=1.0, emit="#2EE6FF", emit_str=0.25), bevel=0.05)
    rim = tube_loop(f"{name}_rim", stadium_points(w - 0.08, h - 0.08, 10), -0.155, 0.016, mat_emit("capsule_rim", HEX["cyan"], 6.0))
    icon_m = mat_emit("capsule_icon", "#FFFFFF", 6.0)
    ball = flat_shape(f"{name}_iconball", [(0.13 * math.cos(a / 24 * 6.283) + 0.16, 0.13 * math.sin(a / 24 * 6.283)) for a in range(24)], -0.16, 0.01, icon_m)
    tail = flat_shape(f"{name}_icontail", [(0.12, 0.12), (-0.36, 0.05), (-0.30, 0.0), (-0.36, -0.05), (0.12, -0.12)], -0.158, 0.008, mat_emit("capsule_tail", HEX["sun"], 4.0))
    return to_mesh_and_join([body, rim, ball, tail], name)


def make_net(x0, x1, name="net"):
    m = mat_emit("net_line", HEX["net"], 4.0)
    mm = mat_emit("net_mesh", HEX["net"], 1.2)
    top = tube_loop(f"{name}_line", [(x0, 0), (x1, 0)], 0, 0.025, m, closed=False)
    zz = []
    n = int((x1 - x0) / 0.25)
    for i in range(n + 1):
        zz.append((x0 + i * (x1 - x0) / n, 0 if i % 2 == 0 else -0.14))
    zz2 = [(x, -0.28 if z == 0 else -0.14) for x, z in zz]
    a = tube_loop(f"{name}_zz", zz, 0, 0.008, mm, closed=False)
    b = tube_loop(f"{name}_zz2", zz2, 0, 0.008, mm, closed=False)
    return to_mesh_and_join([top, a, b], name)


def make_net_pip(name="net_pip"):
    return flat_shape(name, [(0, 0.11), (0.08, 0), (0, -0.11), (-0.08, 0)], 0, 0.04, mat_emit("net_pip", "#FFFFFF", 5.0))


def make_palm(height=22.0, lean=1, name="palm"):
    m = mat_pbr("palm", HEX["palm"], rough=0.9)
    parts = []
    segs = 10
    pts_l, pts_r = [], []
    for i in range(segs + 1):
        t = i / segs
        x = lean * 3.0 * t * t
        z = height * t
        w = 0.55 * (1 - 0.45 * t)
        pts_l.append((x - w, z))
        pts_r.append((x + w, z))
    trunk = flat_shape(f"{name}_trunk", pts_l + pts_r[::-1], 0, 0.3, m)
    parts.append(trunk)
    tx, tz = lean * 3.0, height
    for k in range(9):
        a = math.radians(-160 + k * 40 + (10 if lean > 0 else -10))
        L = 7.5 if abs(math.cos(a)) > 0.3 else 5.5
        leaf = []
        n = 10
        upper, lower = [], []
        for i in range(n + 1):
            t = i / n
            droop = -2.6 * t * t
            cx = tx + math.cos(a) * L * t
            cz = tz + math.sin(a) * L * t + droop
            w = 0.9 * math.sin(math.pi * t) + 0.05
            nx, nz = -math.sin(a), math.cos(a)
            upper.append((cx + nx * w, cz + nz * w))
            lower.append((cx - nx * w * 0.6, cz - nz * w * 0.6))
        leaf = upper + lower[::-1]
        parts.append(flat_shape(f"{name}_leaf{k}", leaf, 0.05 * k, 0.1, m))
    return to_mesh_and_join(parts, name)
