class_name NbVista
extends Node3D

## The world behind the field glass (DESIGN 7d and 11): one sky quad, one
## floor plane and one prop group per world, built once and switched by
## set_world(). Every prop list is one MultiMeshInstance3D (one draw call
## per mesh surface); only the group of the current world is visible, so a
## world costs its own props only (DESIGN 11.7: vista 6-9 draw calls).

const PALM := Color(0.071, 0.024, 0.122)
const AMBER := Color(1.000, 0.698, 0.239)
const GOLD := Color(1.000, 0.824, 0.478)
const MINT := Color(0.302, 1.000, 0.604)

var sky_mat: ShaderMaterial
var sea_mat: ShaderMaterial
var world_id: int = 0
var _sky_keys: Dictionary = {}
var _sea_keys: Dictionary = {}
var _groups: Array[Node3D] = []
var _less_motion: bool = false
var _anim_mats: Array[ShaderMaterial] = []
var _ring: Node3D
var _halo_tex: Texture2D


## halo_tex: the shared radial gradient (lamp pools, mist cards).
func build(halo_tex: Texture2D) -> void:
	_halo_tex = halo_tex
	_build_sky_and_floor()
	for w: int in 6:
		var g := Node3D.new()
		g.name = "World%d" % (w + 1)
		g.visible = false
		add_child(g)
		_groups.append(g)
	_build_w1(_groups[0])
	_build_w2(_groups[1])
	_build_w3(_groups[2])
	_build_w4(_groups[3])
	_build_w5(_groups[4])
	_build_w6(_groups[5])
	set_process(false)


func set_world(w: int) -> void:
	world_id = clampi(w, 1, 6)
	var look: Dictionary = NbWorldLook.get_look(world_id)
	var sky: Dictionary = look["sky"]
	for k: String in _sky_keys:
		sky_mat.set_shader_parameter(k, sky.get(k, _sky_keys[k]))
	var fl: Dictionary = look["floor"]
	for k: String in _sea_keys:
		sea_mat.set_shader_parameter(k, fl.get(k, _sea_keys[k]))
	for i: int in _groups.size():
		_groups[i].visible = i == world_id - 1
	set_process(world_id == 6 and not _less_motion)


func set_less_motion(on: bool) -> void:
	_less_motion = on
	sea_mat.set_shader_parameter("less_motion", 1.0 if on else 0.0)
	for m: ShaderMaterial in _anim_mats:
		m.set_shader_parameter("less_motion", 1.0 if on else 0.0)
	set_process(world_id == 6 and not on)


## World 6 ring gate: 0.02 rev/min around z, parallax only.
func _process(delta: float) -> void:
	if _ring:
		_ring.rotate_z(TAU * 0.02 / 60.0 * delta)


# ---------------------------------------------------------------- shared


func _build_sky_and_floor() -> void:
	var sky := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1000.0, 900.0)
	sky.mesh = q
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/sky.gdshader")
	sky_mat.set_shader_parameter("nebula_tex", preload("res://assets/textures/nebula_512.png"))
	sky.material_override = sky_mat
	for u: Dictionary in RenderingServer.get_shader_parameter_list(sky_mat.shader.get_rid()):
		var n: String = u["name"]
		if n != "nebula_tex":
			_sky_keys[n] = RenderingServer.shader_get_parameter_default(sky_mat.shader.get_rid(), n)
	sky.position = Vector3(0.0, 380.0, -420.0)
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sky)
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1400.0, 410.0)
	sea.mesh = pm
	sea_mat = ShaderMaterial.new()
	sea_mat.shader = preload("res://shaders/sea.gdshader")
	sea.material_override = sea_mat
	for u: Dictionary in RenderingServer.get_shader_parameter_list(sea_mat.shader.get_rid()):
		var n: String = u["name"]
		if n != "less_motion":
			_sea_keys[n] = RenderingServer.shader_get_parameter_default(sea_mat.shader.get_rid(), n)
	sea.position = Vector3(0.0, 0.0, -195.0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)


static func unshaded(c: Color, gain: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r * gain, c.g * gain, c.b * gain)
	return m


static func lit(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


## Mesh of a GLB with its surface materials replaced by name
## (look-up by the stable material names of DESIGN 12.8).
static func glb_mesh(path: String, mats: Dictionary) -> Mesh:
	var ps: PackedScene = load(path)
	var n: Node = ps.instantiate()
	var src: Mesh = _find_mesh(n)
	n.free()
	var m: Mesh = src.duplicate() as Mesh
	for s: int in m.get_surface_count():
		var sm: Material = m.surface_get_material(s)
		if sm and mats.has(sm.resource_name):
			m.surface_set_material(s, mats[sm.resource_name])
	return m


static func _find_mesh(n: Node) -> Mesh:
	if n is MeshInstance3D:
		return (n as MeshInstance3D).mesh
	for c: Node in n.get_children():
		var f: Mesh = _find_mesh(c)
		if f:
			return f
	return null


func _multi(
	parent: Node3D, mesh: Mesh, xfs: Array[Transform3D], cols: Array = [], mat: Material = null
) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not cols.is_empty()
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i: int in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		if not cols.is_empty():
			mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if mat:
		mmi.material_override = mat
	parent.add_child(mmi)
	return mmi


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _additive(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.albedo_texture = _halo_tex
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# ---------------------------------------------------------------- worlds


## World 1 Neonstranda: three palm silhouettes (positions from the mock).
func _build_w1(g: Node3D) -> void:
	var palm_mat := unshaded(PALM)
	palm_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh: Mesh = glb_mesh("res://assets/models/palm_silhouette.glb", {"palm": palm_mat})
	var xfs: Array[Transform3D] = []
	for p: Array in [
		[-11.9, -40.2, 26.0, 1.0], [13.1, -44.2, 19.0, -1.0], [17.6, -70.2, 14.0, -1.0]
	]:
		var s: float = float(p[2]) / 25.3
		var b := Basis().scaled(Vector3(s * float(p[3]), s, s))
		xfs.append(Transform3D(b, Vector3(float(p[0]), 0.0, float(p[1]))))
	_multi(g, mesh, xfs)


## World 2 Rutenettbyen: three skyline layers with a static window shader,
## four vertical neon strips (never rings or chevrons: portal / glider cues).
func _build_w2(g: Node3D) -> void:
	var tower: Mesh = glb_mesh("res://assets/models/prop_city_tower.glb", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var layers: Array = [
		[-110.0, Vector2(8, 30), Color(0.047, 0.086, 0.220), 0.30],
		[-180.0, Vector2(18, 50), Color(0.039, 0.071, 0.188), 0.25],
		[-280.0, Vector2(30, 78), Color(0.031, 0.063, 0.157), 0.20],
	]
	for li: int in layers.size():
		var lay: Array = layers[li]
		var xfs: Array[Transform3D] = []
		var x: float = -150.0
		while x < 150.0:
			var w: float = rng.randf_range(9.0, 20.0)
			var hr: Vector2 = lay[1]
			var cx: float = x + w * 0.5
			var h: float = rng.randf_range(hr.x, hr.y) * (0.6 + 0.4 * minf(1.0, absf(cx) / 50.0))
			var sx: float = w / 14.0
			var sy: float = h / 53.6
			xfs.append(
				Transform3D(Basis().scaled(Vector3(sx, sy, 1.0)), Vector3(cx, 20.0 * sy, lay[0]))
			)
			x += w + rng.randf_range(1.0, 6.0)
		var wm := ShaderMaterial.new()
		wm.shader = preload("res://shaders/windows.gdshader")
		wm.set_shader_parameter("body", lay[2])
		wm.set_shader_parameter("density", lay[3])
		wm.set_shader_parameter("layer", float(li))
		_multi(g, tower, xfs, [], wm)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.45
	cyl.bottom_radius = 0.45
	cyl.height = 1.0
	cyl.radial_segments = 8
	cyl.rings = 1
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.vertex_color_use_as_albedo = true
	var pink := Color(1.000, 0.180, 0.533) * 2.4
	var blue := Color(0.239, 0.482, 1.000) * 2.4
	var xfs2: Array[Transform3D] = []
	var cols: Array = []
	for s: Array in [
		[-38.0, 9.0, 9.0, pink],
		[-12.0, 14.0, 7.0, blue],
		[21.0, 11.0, 10.0, pink],
		[44.0, 16.0, 8.0, blue]
	]:
		var h2: float = float(s[2])
		var b2 := Basis().scaled(Vector3(1.0, h2, 1.0))
		xfs2.append(Transform3D(b2, Vector3(float(s[0]), float(s[1]) + h2 * 0.5, -105.5)))
		cols.append(s[3])
	_multi(g, cyl, xfs2, cols, sm)


## World 3 Arkadehallen: two rows of cabinets facing the centre line, a
## ceiling truss with 14 gold bulbs that breathe (a sine, never on/off).
func _build_w3(g: Node3D) -> void:
	var screen := StandardMaterial3D.new()
	screen.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen.vertex_color_use_as_albedo = true
	var mesh: Mesh = glb_mesh(
		"res://assets/models/prop_arcade_cabinet.glb",
		{
			"cab_body": lit(Color(0.043, 0.024, 0.071), 0.0, 0.6),
			"cab_marquee": unshaded(Color(1.000, 0.882, 0.302), 1.4),
			"cab_screen": screen,
		}
	)
	var xfs: Array[Transform3D] = []
	var cols: Array = []
	for k: int in 7:
		for side: float in [-1.0, 1.0]:
			var rot: float = deg_to_rad(55.0 if side < 0.0 else -55.0)
			var b := Basis(Vector3.UP, rot).scaled(Vector3.ONE * 2.8)
			xfs.append(Transform3D(b, Vector3(side * (7.0 + 0.9 * k), 0.0, -10.0 - 8.0 * k)))
			var c: Color = (
				Color(1.000, 0.239, 0.431)
				if (k + int(side > 0.0)) % 2 == 0
				else Color(0.239, 0.482, 1.000)
			)
			cols.append(c * 1.4)
	_multi(g, mesh, xfs, cols)
	# Lit metal read as a grey slab in the capture; the mock's truss is dark.
	var truss := unshaded(Color(0.102, 0.063, 0.125))
	_box(g, Vector3(30.0, 1.0, 0.8), Vector3(5.0, 42.6, -30.0), truss)
	var bulb := SphereMesh.new()
	bulb.radius = 0.38
	bulb.height = 0.76
	bulb.radial_segments = 10
	bulb.rings = 5
	var bm := ShaderMaterial.new()
	bm.shader = preload("res://shaders/bulb.gdshader")
	bm.set_shader_parameter("col", Color(1.000, 0.882, 0.302))
	bm.set_shader_parameter("gain", 3.0)
	_anim_mats.append(bm)
	var bx: Array[Transform3D] = []
	for k: int in 14:
		bx.append(Transform3D(Basis(), Vector3(-8.6 + 2.1 * k, 41.7, -29.4)))
	_multi(g, bulb, bx, [], bm)


## World 4 Nattveien: 32 lamp posts, amber pools on the road, four
## UV-scrolled light streaks, the overpass deck with 14 lamps in the sky
## band (outside the glass).
func _build_w4(g: Node3D) -> void:
	var post: Mesh = glb_mesh(
		"res://assets/models/prop_lamp_post.glb",
		{
			"pole": lit(Color(0.071, 0.039, 0.086), 0.3, 0.6),
			"lamp_head": unshaded(AMBER, 1.6),
		}
	)
	var xfs: Array[Transform3D] = []
	var pools: Array[Transform3D] = []
	for k: int in 16:
		for side: float in [-1.0, 1.0]:
			var b := Basis() if side < 0.0 else Basis(Vector3.UP, PI)
			var z: float = -20.0 - 24.0 * k
			xfs.append(Transform3D(b, Vector3(side * 9.0, 4.5, z)))
			if k < 8:
				var pb := (
					Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3(8.0, 12.0, 1.0))
				)
				pools.append(Transform3D(pb, Vector3(side * 6.6, 0.03, z)))
	_multi(g, post, xfs)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	_multi(g, quad, pools, [], _additive(Color(AMBER.r, AMBER.g, AMBER.b, 0.18)))
	var sq := QuadMesh.new()
	sq.size = Vector2(0.12, 420.0)
	var st := ShaderMaterial.new()
	st.shader = preload("res://shaders/streak.gdshader")
	_anim_mats.append(st)
	var sx: Array[Transform3D] = []
	var scol: Array = []
	var tail := Color(1.000, 0.231, 0.188) * 1.6
	var head := Color(1.000, 0.902, 0.784) * 1.6
	for s: Array in [[3.1, tail, 1.0], [3.9, tail, 1.0], [-3.1, head, -1.0], [-3.9, head, -1.0]]:
		var b := Basis(Vector3.RIGHT, -PI * 0.5)
		sx.append(Transform3D(b, Vector3(float(s[0]), 0.6, -224.0)))
		var c: Color = s[1]
		# Alpha carries the scroll direction: 1 away from the camera, 0 toward.
		scol.append(Color(c.r, c.g, c.b, 1.0 if float(s[2]) > 0.0 else 0.0))
	_multi(g, sq, sx, scol, st)
	_box(
		g,
		Vector3(120.0, 3.0, 6.0),
		Vector3(0.0, 55.0, -45.0),
		lit(Color(0.055, 0.031, 0.071), 0.0, 0.7)
	)
	var lamp := BoxMesh.new()
	lamp.size = Vector3(1.2, 0.35, 0.4)
	var lx: Array[Transform3D] = []
	for k: int in 14:
		lx.append(Transform3D(Basis(), Vector3(-19.5 + 3.0 * k, 53.3, -41.9)))
	_multi(g, lamp, lx, [], unshaded(AMBER, 3.0))


## World 5 Krystallgrotta: crystal clusters (violet and mint), the rock
## ceiling with 10 stalactites (mint tips) in the sky band, two mist cards.
func _build_w5(g: Node3D) -> void:
	var vio := lit(Color(0.165, 0.102, 0.502), 0.0, 0.1)
	vio.emission_enabled = true
	vio.emission = Color(0.290, 0.173, 0.690)
	vio.emission_energy_multiplier = 0.9
	vio.clearcoat_enabled = true
	vio.clearcoat = 1.0
	var mint := lit(Color(0.055, 0.227, 0.173), 0.0, 0.1)
	mint.emission_enabled = true
	mint.emission = Color(0.118, 0.478, 0.322)
	mint.emission_energy_multiplier = 0.9
	mint.clearcoat_enabled = true
	mint.clearcoat = 1.0
	var path := "res://assets/models/prop_crystal_cluster.glb"
	var mv: Mesh = glb_mesh(path, {"crystal_vio": vio})
	var mm: Mesh = glb_mesh(path, {"crystal_vio": mint})
	var xv: Array[Transform3D] = []
	var xm: Array[Transform3D] = []
	var spots: Array = [
		[-12.0, -16.0, 0.9, 0],
		[12.5, -20.0, 1.0, 1],
		[-30.0, -60.0, 3.3, 1],
		[34.0, -70.0, 3.5, 0],
		[-70.0, -150.0, 6.0, 0],
		[80.0, -160.0, 6.5, 1],
	]
	for s: Array in spots:
		var sc: float = float(s[2])
		var xf := Transform3D(
			Basis().scaled(Vector3.ONE * sc), Vector3(float(s[0]), 0.25 * sc, float(s[1]))
		)
		if int(s[3]) == 0:
			xv.append(xf)
		else:
			xm.append(xf)
	_multi(g, mv, xv)
	_multi(g, mm, xm)
	var ceil := lit(Color(0.027, 0.063, 0.102), 0.0, 0.8)
	ceil.emission_enabled = true
	ceil.emission = Color(0.043, 0.165, 0.149)
	ceil.emission_energy_multiplier = 0.8
	_box(g, Vector3(90.0, 10.0, 4.0), Vector3(0.0, 50.0, -30.0), ceil)
	var rock := lit(Color(0.027, 0.063, 0.102), 0.0, 0.8)
	var stal: Mesh = glb_mesh(
		"res://assets/models/prop_stalactite.glb", {"rock": rock, "stal_tip": unshaded(MINT, 3.0)}
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var st: Array[Transform3D] = []
	for k: int in 10:
		var sy: float = rng.randf_range(1.6, 3.0) / 2.56
		var x: float = -7.0 + 3.0 * k + rng.randf_range(-0.5, 0.5)
		st.append(
			Transform3D(Basis().scaled(Vector3(1.0, sy, 1.0)), Vector3(x, 45.2 - 1.25 * sy, -29.0))
		)
	_multi(g, stal, st)
	var card := QuadMesh.new()
	card.size = Vector2(160.0, 3.5)
	var mist := _additive(Color(0.106, 0.165, 0.290, 0.3))
	mist.albedo_texture = null
	var cx: Array[Transform3D] = [
		Transform3D(Basis(), Vector3(0.0, 1.5, -35.0)),
		Transform3D(Basis(), Vector3(0.0, 3.0, -70.0))
	]
	_multi(g, card, cx, [], mist)


## World 6 Stjerneporten: the ring gate framing the field and a planet with
## a gold-lit crescent (nebula and gate light are in the sky shader). The
## planet sits at x 60 (not DESIGN's first 104) so the gear never covers it.
func _build_w6(g: Node3D) -> void:
	var body := lit(Color(0.165, 0.102, 0.353), 0.7, 0.25)
	body.emission_enabled = true
	body.emission = Color(0.353, 0.173, 0.690)
	body.emission_energy_multiplier = 0.9
	var gate: Mesh = glb_mesh(
		"res://assets/models/prop_ring_gate.glb",
		{"gate_body": body, "gate_bead": unshaded(GOLD, 1.6)}
	)
	_ring = Node3D.new()
	_ring.position = Vector3(0.0, 27.6, -120.0)
	g.add_child(_ring)
	var gi := MeshInstance3D.new()
	gi.mesh = gate
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.add_child(gi)
	var planet := SphereMesh.new()
	planet.radius = 23.0
	planet.height = 46.0
	planet.radial_segments = 32
	planet.rings = 16
	var pm := lit(Color(0.227, 0.110, 0.416), 0.0, 0.7)
	pm.emission_enabled = true
	pm.emission = Color(0.071, 0.031, 0.157)
	pm.emission_energy_multiplier = 0.5
	var p := MeshInstance3D.new()
	p.mesh = planet
	p.material_override = pm
	p.position = Vector3(60.0, 367.0, -400.0)
	g.add_child(p)
	var lit_s := SphereMesh.new()
	lit_s.radius = 23.2
	lit_s.height = 46.4
	lit_s.radial_segments = 32
	lit_s.rings = 16
	var t := MeshInstance3D.new()
	t.mesh = lit_s
	t.material_override = unshaded(GOLD, 1.6)
	t.position = Vector3(55.0, 370.0, -406.0)
	g.add_child(t)
