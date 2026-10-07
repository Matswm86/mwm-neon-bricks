class_name NbMeshes
extends RefCounted

## Small mesh helpers. The brick MultiMesh uses only the bevelled body
## surface of brick_glass.glb (300 triangles); rim tube, dots and stars are
## painted by shaders/brick.gdshader, so a full field stays light (DESIGN 7e).

static var _brick_body: Mesh


static func brick_body() -> Mesh:
	if _brick_body:
		return _brick_body
	var ps: PackedScene = load("res://assets/models/brick_glass.glb")
	var n: Node = ps.instantiate()
	var src: Mesh = _find_mesh(n)
	var am := ArrayMesh.new()
	if src:
		var arrays: Array = src.surface_get_arrays(0)
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	n.free()
	_brick_body = am
	return am


static func _find_mesh(n: Node) -> Mesh:
	if n is MeshInstance3D:
		return (n as MeshInstance3D).mesh
	for c: Node in n.get_children():
		var m: Mesh = _find_mesh(c)
		if m:
			return m
	return null


## Rounded box: a grid on each face projected onto the rounded shape
## (core = box shrunk by r; point = core clamp + normal * r).
static func rounded_box(size: Vector3, r: float, seg: int) -> ArrayMesh:
	var h: Vector3 = size * 0.5
	var inner: Vector3 = h - Vector3(r, r, r)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Each face: normal axis, u axis, v axis.
	var faces: Array = [
		[Vector3.RIGHT, Vector3.BACK, Vector3.UP],
		[Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.BACK, Vector3.LEFT, Vector3.UP],
		[Vector3.FORWARD, Vector3.RIGHT, Vector3.UP],
	]
	for f: Array in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var us: PackedFloat32Array = _coords(absf(u.dot(h)), r, seg)
		var vs: PackedFloat32Array = _coords(absf(v.dot(h)), r, seg)
		var nd: float = absf(n.dot(h))
		for j: int in vs.size() - 1:
			for i: int in us.size() - 1:
				var q: Array[Vector3] = [
					n * nd + u * us[i] + v * vs[j],
					n * nd + u * us[i + 1] + v * vs[j],
					n * nd + u * us[i + 1] + v * vs[j + 1],
					n * nd + u * us[i] + v * vs[j + 1],
				]
				for idx: int in [0, 1, 2, 0, 2, 3]:
					var p: Vector3 = q[idx]
					var c: Vector3 = p.clamp(-inner, inner)
					var dn: Vector3 = (p - c).normalized()
					st.set_normal(dn)
					st.add_vertex(c + dn * r)
	return st.commit()


static func _coords(half: float, r: float, seg: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k: int in seg + 1:
		out.append(-half + r * float(k) / float(seg))
	for k: int in range(seg - 1, -1, -1):
		out.append(half - r * float(k) / float(seg))
	return out


## Drops the cached mesh (tests call it before quitting, so no resource is
## reported as leaked at exit).
static func clear_cache() -> void:
	_brick_body = null
