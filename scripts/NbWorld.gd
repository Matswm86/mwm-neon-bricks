class_name NbWorld
extends Node3D

## The 3D scene (DESIGN sections 6-7): synthwave vista, arena frame, bricks
## in one MultiMesh, paddle, ball with halo and trail, net, Komet capsules,
## break shards. It only draws: NbPlay owns the NbSim and calls sync() and
## the fx_* functions. Logic px map to the play plane (z = 0) with
## 1 px = 0.01 m; the screen bottom is world y 0 and x 540 is world x 0.

const PX := NbBalance.PX_TO_M
const CYAN := Color(0.180, 0.902, 1.0)
const SUN := Color(1.000, 0.788, 0.235)
const HOTPINK := Color(1.000, 0.180, 0.533)
const SKY_TOP := Color(0.043, 0.024, 0.188)
const PALM := Color(0.071, 0.024, 0.122)
const WALL_RAIL := Color(0.082, 0.071, 0.169)
const TRAIL_POINTS: int = 12
const TRAIL_LEN_PX: float = 150.0
const KOMET_TRAIL_GAIN: float = 2.5
const SPARK_R: float = 0.38

var camera: Camera3D
var drift_on: bool = true
var cam_pivot: Node3D
var env: Environment

var _vw: float = 1080.0
var _vh: float = 1920.0
var _less_motion: bool = false
var _t: float = 0.0

# Camera motion state
var _sweep_t: float = 99.0
var _push_t: float = -1.0
var _push_target: Vector3 = Vector3.ZERO
var _shake_t: float = 0.0
var _shake_px: float = 0.0
var _shake_len: float = 0.0

# Vista and frame
var _sky_mat: ShaderMaterial
var _tubes: Array[MeshInstance3D] = []
var _tube_mat: Array[StandardMaterial3D] = []
var _tube_glow: Array[float] = [0.0, 0.0, 0.0]
var _game_nodes: Array[Node3D] = []

# Bricks
var _bricks_mmi: MultiMeshInstance3D
var _brick_mat: ShaderMaterial
var _brick_xf: Array[Transform3D] = []
var _brick_squash: PackedFloat32Array = PackedFloat32Array()
var _brick_fade: PackedFloat32Array = PackedFloat32Array()
var _restored: PackedInt32Array = PackedInt32Array()
var _assist_glow: int = -1

# Paddle / ball / net / capsules
var _paddle_root: Node3D
var _paddle: Node3D
var _paddle_light: StandardMaterial3D
var _paddle_light_e: float = 7.0
var _paddle_squash_t: float = 99.0
var _touch_glow_t: float = 99.0
var _paddle_w_px: float = 0.0
var _ball: MeshInstance3D
var _halo: MeshInstance3D
var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _trail_mat: StandardMaterial3D
var _hist: Array[Vector2] = []
var _sparks: MultiMeshInstance3D
var _net: MeshInstance3D
var _net_mat: ShaderMaterial
var _net_ripple_t: float = 9.0
var _pip_out_t: float = 9.0
var _capsule_scene: PackedScene = preload("res://assets/models/capsule_komet.glb")
var _capsule_nodes: Array[Node3D] = []

# FX pools
var _shards: Array[GPUParticles3D] = []
var _shard_i: int = 0
var _puffs: Array[MeshInstance3D] = []
var _puff_t: PackedFloat32Array = PackedFloat32Array()
var _puff_i: int = 0
var _halo_tex: GradientTexture2D


func _ready() -> void:
	_build_environment()
	_build_camera()
	_build_vista()
	_build_frame()
	_build_gameplay()
	_build_fx()
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()


static func to_world(p: Vector2, z: float = 0.0) -> Vector3:
	return Vector3((p.x - 540.0) * PX, (NbBalance.DESIGN_H - p.y) * PX, z)


# ---------------------------------------------------------------- build


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY_TOP
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.10, 0.05, 0.30)
	psm.sky_horizon_color = Color(0.85, 0.25, 0.45)
	psm.ground_bottom_color = Color(0.03, 0.02, 0.08)
	psm.ground_horizon_color = Color(0.55, 0.15, 0.35)
	psm.sun_angle_max = 0.0
	sky.sky_material = psm
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.0
	for i: int in 7:
		env.set_glow_level(i, 1.0 if i in [1, 2, 3] else 0.0)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color(0.85, 0.9, 1.0)
	key.light_energy = 1.1
	key.shadow_enabled = false
	key.rotation_degrees = Vector3(-38.0, -12.0, 0.0)
	add_child(key)


func _build_camera() -> void:
	cam_pivot = Node3D.new()
	cam_pivot.position = Vector3(0.0, 9.3, 0.0)
	add_child(cam_pivot)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_FRUSTUM
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.near = NbBalance.CAM_NEAR
	camera.far = 1500.0
	camera.position = _cam_rest_local()
	cam_pivot.add_child(camera)
	camera.current = true


func _cam_rest_local() -> Vector3:
	return Vector3(0.0, NbBalance.EYE_HEIGHT - cam_pivot.position.y, NbBalance.CAM_DIST)


func _on_resize() -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	_vw = s.x
	_vh = s.y
	_apply_frustum()


## Lens shift, not tilt (DESIGN 6a): 1 logic px stays 1 screen px on the play
## plane; the screen bottom stays at world y 0 so taller screens add sky.
func _apply_frustum() -> void:
	var k: float = NbBalance.CAM_NEAR / NbBalance.CAM_DIST
	camera.size = _vw * PX * k
	var centre_y: float = _vh * PX * 0.5
	camera.frustum_offset = Vector2(0.0, (centre_y - NbBalance.EYE_HEIGHT) * k)


## Screen px offset of the 1080 x 1920 design frame inside the viewport.
func frame_offset() -> Vector2:
	return Vector2((_vw - NbBalance.DESIGN_W) * 0.5, _vh - NbBalance.DESIGN_H)


func _build_vista() -> void:
	var sky := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1000.0, 900.0)
	sky.mesh = q
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = preload("res://shaders/sky.gdshader")
	sky.material_override = _sky_mat
	sky.position = Vector3(0.0, 380.0, -420.0)
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sky)

	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1400.0, 410.0)
	sea.mesh = pm
	var sea_mat := ShaderMaterial.new()
	sea_mat.shader = preload("res://shaders/sea.gdshader")
	sea.material_override = sea_mat
	sea.position = Vector3(0.0, 0.0, -195.0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)

	var palm_mat := StandardMaterial3D.new()
	palm_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	palm_mat.albedo_color = PALM
	palm_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var palm_mesh: Mesh = _first_mesh(preload("res://assets/models/palm_silhouette.glb"))
	# Positions from the world 1 mock (docs/mockups/src/world1_mock.py).
	var palms: Array = [
		[-11.9, -40.2, 26.0, 1.0], [13.1, -44.2, 19.0, -1.0], [17.6, -70.2, 14.0, -1.0]
	]
	for p: Array in palms:
		var mi := MeshInstance3D.new()
		mi.mesh = palm_mesh
		mi.material_override = palm_mat
		var s: float = float(p[2]) / 25.3
		mi.scale = Vector3(s * float(p[3]), s, s)
		mi.position = Vector3(float(p[0]), 0.0, float(p[1]))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _build_frame() -> void:
	# Field glass: the one large transparent surface (72% black).
	var field := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(10.0, 14.2)
	field.mesh = fq
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_color = Color(0.0, 0.0, 0.0, 0.72)
	field.material_override = fm
	field.position = to_world(Vector2(540.0, 990.0), -0.32)
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(field)

	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = WALL_RAIL
	rail_mat.metallic = 0.6
	rail_mat.roughness = 0.45
	var z_top: float = (NbBalance.DESIGN_H - 280.0) * PX
	var z_bot: float = (NbBalance.DESIGN_H - 1700.0) * PX
	var h: float = z_top - z_bot + 0.4
	for x: float in [0.2, 10.6]:
		var rail := MeshInstance3D.new()
		rail.mesh = NbMeshes.rounded_box(Vector3(0.4, h, 0.4), 0.06, 2)
		rail.material_override = rail_mat
		rail.position = Vector3(x - 5.4, (z_top + z_bot) * 0.5 + 0.2, 0.0)
		add_child(rail)
	var top := MeshInstance3D.new()
	top.mesh = NbMeshes.rounded_box(Vector3(10.8, 0.4, 0.4), 0.06, 2)
	top.material_override = rail_mat
	top.position = Vector3(0.0, z_top + 0.2, 0.0)
	add_child(top)
	# Neon tubes on the inner edges: left, right, top (each glows on a hit).
	var specs: Array = [
		[Vector3(-5.0, (z_top + z_bot + 0.1) * 0.5, 0.22), z_top - z_bot - 0.1, false],
		[Vector3(5.0, (z_top + z_bot + 0.1) * 0.5, 0.22), z_top - z_bot - 0.1, false],
		[Vector3(0.0, z_top, 0.22), 10.0, true],
	]
	for sp: Array in specs:
		var tube := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.03
		cm.bottom_radius = 0.03
		cm.height = float(sp[1])
		cm.radial_segments = 8
		cm.rings = 1
		tube.mesh = cm
		var tm := StandardMaterial3D.new()
		tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tm.albedo_color = HOTPINK * 2.2
		tube.material_override = tm
		tube.position = sp[0]
		if sp[2]:
			tube.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		add_child(tube)
		_tubes.append(tube)
		_tube_mat.append(tm)
	# Cyan end-cap lamps at the rail feet.
	var cap_mat := StandardMaterial3D.new()
	cap_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cap_mat.albedo_color = CYAN * 2.5
	for x: float in [0.2, 10.6]:
		var lamp := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.24
		sm.radial_segments = 12
		sm.rings = 6
		lamp.mesh = sm
		lamp.material_override = cap_mat
		lamp.position = Vector3(x - 5.4, z_bot + 0.05, 0.2)
		add_child(lamp)


func _build_gameplay() -> void:
	_bricks_mmi = MultiMeshInstance3D.new()
	_brick_mat = ShaderMaterial.new()
	_brick_mat.shader = preload("res://shaders/brick.gdshader")
	_bricks_mmi.material_override = _brick_mat
	_bricks_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bricks_mmi)
	_game_nodes.append(_bricks_mmi)

	_paddle_root = Node3D.new()
	add_child(_paddle_root)
	_game_nodes.append(_paddle_root)

	_ball = MeshInstance3D.new()
	_ball.mesh = _first_mesh(preload("res://assets/models/ball.glb"))
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(1.4, 1.4, 1.4)
	_ball.material_override = bm
	add_child(_ball)
	_game_nodes.append(_ball)

	_halo_tex = GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gr.add_point(0.35, Color(1, 1, 1, 0.55))
	_halo_tex.gradient = gr
	_halo_tex.fill = GradientTexture2D.FILL_RADIAL
	_halo_tex.fill_from = Vector2(0.5, 0.5)
	_halo_tex.fill_to = Vector2(1.0, 0.5)
	_halo_tex.width = 128
	_halo_tex.height = 128
	_halo = MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(1.25, 1.25)
	_halo.mesh = hq
	_halo.material_override = _additive_mat(CYAN * 0.9, _halo_tex)
	add_child(_halo)
	_game_nodes.append(_halo)

	_trail = MeshInstance3D.new()
	_trail_mesh = ImmediateMesh.new()
	_trail.mesh = _trail_mesh
	_trail_mat = StandardMaterial3D.new()
	_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_mat.vertex_color_use_as_albedo = true
	_trail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail_mat.no_depth_test = false
	_trail.material_override = _trail_mat
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)
	_game_nodes.append(_trail)

	_sparks = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := SphereMesh.new()
	sm.radius = 0.045
	sm.height = 0.09
	sm.radial_segments = 8
	sm.rings = 4
	mm.mesh = sm
	mm.instance_count = NbBalance.KOMET_BRICKS_LETT
	mm.visible_instance_count = 0
	_sparks.multimesh = mm
	var spm := StandardMaterial3D.new()
	spm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spm.albedo_color = SUN * 2.5
	_sparks.material_override = spm
	add_child(_sparks)
	_game_nodes.append(_sparks)

	_net = MeshInstance3D.new()
	var nq := QuadMesh.new()
	nq.size = Vector2(10.0, 0.6)
	_net.mesh = nq
	_net_mat = ShaderMaterial.new()
	_net_mat.shader = preload("res://shaders/net.gdshader")
	_net.material_override = _net_mat
	_net.position = to_world(Vector2(540.0, 1555.0), 0.05)
	_net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_net)
	_game_nodes.append(_net)

	for i: int in NbBalance.CAPSULE_MAX:
		var c: Node3D = _capsule_scene.instantiate()
		c.visible = false
		add_child(c)
		_capsule_nodes.append(c)
		_game_nodes.append(c)


func _build_fx() -> void:
	var tri := ArrayMesh.new()
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array(
		[Vector3(0, 0.07, 0), Vector3(0.06, -0.04, 0), Vector3(-0.05, -0.035, 0)]
	)
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	tri.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var shard_mat := StandardMaterial3D.new()
	shard_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shard_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	shard_mat.vertex_color_use_as_albedo = true
	shard_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	tri.surface_set_material(0, shard_mat)
	for i: int in NbBalance.PARTICLE_POOL:
		var p := GPUParticles3D.new()
		p.amount = NbBalance.SHARDS
		p.lifetime = NbBalance.SHARD_LIFE_S
		p.one_shot = true
		p.explosiveness = 1.0
		p.emitting = false
		p.local_coords = false
		p.draw_pass_1 = tri
		p.visibility_aabb = AABB(Vector3(-3, -3, -1), Vector3(6, 6, 8))
		var pmat := ParticleProcessMaterial.new()
		pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pmat.emission_box_extents = Vector3(0.4, 0.18, 0.1)
		pmat.direction = Vector3(0.0, 0.2, 1.0)
		pmat.spread = 75.0
		pmat.initial_velocity_min = 2.0
		pmat.initial_velocity_max = 5.0
		pmat.gravity = Vector3(0.0, -6.0, 6.0)
		pmat.angle_min = 0.0
		pmat.angle_max = 360.0
		pmat.angular_velocity_min = -400.0
		pmat.angular_velocity_max = 400.0
		pmat.scale_min = 0.6
		pmat.scale_max = 1.3
		pmat.particle_flag_rotate_y = false
		p.process_material = pmat
		add_child(p)
		_shards.append(p)
	for i: int in 4:
		var puff := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.6, 1.0)
		puff.mesh = q
		puff.material_override = _additive_mat(Color(1, 1, 1), _halo_tex)
		puff.visible = false
		add_child(puff)
		_puffs.append(puff)
	_puff_t.resize(4)
	_puff_t.fill(99.0)


func _additive_mat(c: Color, tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.albedo_texture = tex
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = false
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _first_mesh(ps: PackedScene) -> Mesh:
	var n: Node = ps.instantiate()
	var mi: MeshInstance3D = _find_mesh(n)
	var m: Mesh = mi.mesh if mi else null
	n.free()
	return m


func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n as MeshInstance3D
	for c: Node in n.get_children():
		var f: MeshInstance3D = _find_mesh(c)
		if f:
			return f
	return null


# ---------------------------------------------------------------- level binding


func show_gameplay(on: bool) -> void:
	for n: Node3D in _game_nodes:
		n.visible = on
	if not on:
		for c: Node3D in _capsule_nodes:
			c.visible = false
		for p: GPUParticles3D in _shards:
			p.emitting = false


func set_less_motion(on: bool) -> void:
	_less_motion = on
	_net_mat.set_shader_parameter("less_motion", 1.0 if on else 0.0)


## Builds the brick MultiMesh and paddle model for a fresh level.
func bind_level(sim: NbSim) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = NbMeshes.brick_body()
	mm.instance_count = sim.bricks.size()
	_brick_xf.clear()
	_brick_squash.resize(sim.bricks.size())
	_brick_squash.fill(99.0)
	_brick_fade.resize(sim.bricks.size())
	_brick_fade.fill(99.0)
	_restored = PackedInt32Array()
	_assist_glow = -1
	for i: int in sim.bricks.size():
		var b: NbSim.Brick = sim.bricks[i]
		var xf := Transform3D(Basis(), to_world(b.center()))
		_brick_xf.append(xf)
		mm.set_instance_transform(i, xf)
		mm.set_instance_color(i, b.color.srgb_to_linear())
		mm.set_instance_custom_data(i, _brick_custom(b, 1.0))
	_bricks_mmi.multimesh = mm
	_set_paddle(sim.paddle_half * 2.0)
	_hist.clear()
	_net_ripple_t = 9.0
	_pip_out_t = 9.0
	for c: Node3D in _capsule_nodes:
		c.visible = false


func _brick_custom(b: NbSim.Brick, w: float) -> Color:
	var kind: float = 0.0
	if b.code == "D":
		kind = 1.0
	elif b.code == "C":
		kind = 2.0
	return Color(kind, float(maxi(b.hp, 0)), 1.0 if b.carrier else 0.0, w)


func _set_paddle(w_px: float) -> void:
	if is_equal_approx(w_px, _paddle_w_px) and _paddle:
		return
	_paddle_w_px = w_px
	if _paddle:
		_paddle.queue_free()
	var path: String = "res://assets/models/paddle_lett_400.glb"
	if w_px < 340.0:
		path = "res://assets/models/paddle_vanlig_280.glb"
	var ps: PackedScene = load(path)
	_paddle = ps.instantiate()
	_paddle_root.add_child(_paddle)
	var mi: MeshInstance3D = _find_mesh(_paddle)
	_paddle_light = null
	if mi:
		for s: int in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(s)
			if m is StandardMaterial3D and m.resource_name == "paddle_light":
				_paddle_light = (m as StandardMaterial3D).duplicate()
				_paddle_light_e = _paddle_light.emission_energy_multiplier
				mi.set_surface_override_material(s, _paddle_light)


# ---------------------------------------------------------------- per frame


func sync(sim: NbSim, real_delta: float, game_delta: float) -> void:
	_t += real_delta
	_sync_paddle(sim, real_delta)
	_sync_ball(sim, game_delta)
	_sync_bricks(sim, real_delta)
	_sync_net(sim, real_delta)
	_sync_capsules(sim)
	_sync_fx(real_delta)
	_sync_tubes(real_delta)


func _sync_paddle(sim: NbSim, dt: float) -> void:
	_paddle_root.position = to_world(Vector2(sim.paddle_x, NbBalance.PADDLE_Y))
	_paddle_squash_t += dt
	var sy: float = 1.0
	if not _less_motion and _paddle_squash_t < NbBalance.PADDLE_SQUASH_S:
		var k: float = _paddle_squash_t / NbBalance.PADDLE_SQUASH_S
		sy = lerpf(NbBalance.PADDLE_SQUASH, 1.0, k)
	_paddle_root.scale = Vector3(1.0, sy, 1.0)
	_touch_glow_t += dt
	if _paddle_light:
		var g: float = 1.0
		if _touch_glow_t < NbBalance.TOUCH_GLOW_S:
			g += NbBalance.TOUCH_GLOW_GAIN
		_paddle_light.emission_energy_multiplier = _paddle_light_e * g


func _sync_ball(sim: NbSim, dt: float) -> void:
	var show: bool = sim.ball_visible
	_ball.visible = show
	_halo.visible = show
	_trail.visible = show
	var p: Vector3 = to_world(sim.ball_pos)
	_ball.position = p
	_halo.position = p + Vector3(0, 0, -0.05)
	var komet: bool = sim.komet_active()
	var hm: StandardMaterial3D = _halo.material_override
	hm.albedo_color = (SUN if komet else CYAN) * 0.9
	# Trail history (logic px), sampled each frame while moving.
	if sim.state == NbSim.State.PLAY or sim.state == NbSim.State.CLEAR:
		if dt > 0.0:
			_hist.push_front(sim.ball_pos)
			if _hist.size() > 90:
				_hist.pop_back()
	else:
		_hist.clear()
	_draw_trail(komet)
	# Komet sparks: one per brick left, orbiting (static under less motion).
	var mm: MultiMesh = _sparks.multimesh
	var n: int = sim.komet_left if komet and show else 0
	mm.visible_instance_count = n
	for i: int in n:
		var a: float = TAU * float(i) / float(maxi(n, 1))
		if not _less_motion:
			a += _t * 2.4
		mm.set_instance_transform(
			i, Transform3D(Basis(), p + Vector3(cos(a), sin(a), 0.05) * SPARK_R)
		)


func _draw_trail(komet: bool) -> void:
	_trail_mesh.clear_surfaces()
	if _hist.size() < 2:
		return
	var max_len: float = TRAIL_LEN_PX * (KOMET_TRAIL_GAIN if komet else 1.0)
	var col: Color = SUN if komet else CYAN
	var pts: Array[Vector2] = [_hist[0]]
	var acc: float = 0.0
	var step_len: float = max_len / float(TRAIL_POINTS - 1)
	var next_at: float = step_len
	for i: int in range(1, _hist.size()):
		var a: Vector2 = _hist[i - 1]
		var b: Vector2 = _hist[i]
		var seg: float = a.distance_to(b)
		while seg > 0.0 and acc + seg >= next_at and pts.size() < TRAIL_POINTS:
			var t: float = (next_at - acc) / seg
			pts.append(a.lerp(b, t))
			next_at += step_len
		acc += seg
		if pts.size() >= TRAIL_POINTS or acc >= max_len:
			break
	if pts.size() < 2:
		return
	var half_w: float = NbBalance.BALL_RADIUS * (0.9 if komet else 0.75)
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i: int in pts.size():
		var f: float = float(i) / float(pts.size() - 1)
		var dir: Vector2
		if i < pts.size() - 1:
			dir = (pts[i] - pts[i + 1]).normalized()
		else:
			dir = (pts[i - 1] - pts[i]).normalized()
		var nrm := Vector2(-dir.y, dir.x) * half_w * (1.0 - f)
		var c := Color(col.r * 2.0, col.g * 2.0, col.b * 2.0, (1.0 - f) * 0.8)
		_trail_mesh.surface_set_color(c)
		_trail_mesh.surface_add_vertex(to_world(pts[i] + nrm, -0.08))
		_trail_mesh.surface_set_color(c)
		_trail_mesh.surface_add_vertex(to_world(pts[i] - nrm, -0.08))
	_trail_mesh.surface_end()


func _sync_bricks(sim: NbSim, dt: float) -> void:
	var mm: MultiMesh = _bricks_mmi.multimesh
	if mm == null:
		return
	var flt: float = sim.restart_float()
	var restoring: bool = flt < 1.0 and not _restored.is_empty()
	for i: int in sim.bricks.size():
		var b: NbSim.Brick = sim.bricks[i]
		_brick_squash[i] += dt
		_brick_fade[i] += dt
		var xf: Transform3D = _brick_xf[i]
		var w: float = 1.0
		if not b.alive:
			if _brick_fade[i] < NbBalance.BRICK_FADE_S:
				w = 1.0 - _brick_fade[i] / NbBalance.BRICK_FADE_S
			else:
				xf = Transform3D(Basis().scaled(Vector3.ZERO), xf.origin)
				w = 0.0
		elif restoring and _restored.has(i):
			var e: float = 1.0 - pow(1.0 - flt, 3.0)
			var off: float = (1.0 - e) * -3.0
			xf = Transform3D(
				Basis().scaled(Vector3.ONE * maxf(e, 0.05)), xf.origin + Vector3(0.0, off, 0.0)
			)
		elif not _less_motion and _brick_squash[i] < NbBalance.BRICK_SQUASH_S:
			var k: float = _brick_squash[i] / NbBalance.BRICK_SQUASH_S
			xf = Transform3D(
				Basis().scaled(Vector3(1.0, lerpf(NbBalance.BRICK_SQUASH, 1.0, k), 1.0)), xf.origin
			)
		if i == _assist_glow and b.alive:
			w = 1.0 + 0.5 + 0.5 * sin(_t * TAU)
		mm.set_instance_transform(i, xf)
		mm.set_instance_custom_data(i, _brick_custom(b, w))
	if not restoring and not _restored.is_empty() and flt >= 1.0:
		_restored = PackedInt32Array()


func _sync_net(sim: NbSim, dt: float) -> void:
	_net_ripple_t += dt
	_pip_out_t += dt
	_net_mat.set_shader_parameter("ripple_t", _net_ripple_t)
	var pips: float = -1.0 if sim.net_unlimited else float(maxi(sim.net_charges, 0))
	_net_mat.set_shader_parameter("pips", pips)
	var po: float = 0.0
	if _pip_out_t < 0.3:
		po = 1.0 - _pip_out_t / 0.3
	_net_mat.set_shader_parameter("pip_out", po)


func _sync_capsules(sim: NbSim) -> void:
	for i: int in _capsule_nodes.size():
		var node: Node3D = _capsule_nodes[i]
		if i < sim.capsules.size() and sim.capsules[i].alive:
			var c: NbSim.Capsule = sim.capsules[i]
			node.visible = true
			node.position = to_world(c.pos, 0.1)
			var spin: float = 0.0 if _less_motion else c.age * TAU * 0.5
			node.rotation = Vector3(spin, 0.0, 0.0)
		else:
			node.visible = false


func _sync_fx(dt: float) -> void:
	for i: int in _puffs.size():
		_puff_t[i] += dt
		var p: MeshInstance3D = _puffs[i]
		if _puff_t[i] < NbBalance.PUFF_S:
			var k: float = _puff_t[i] / NbBalance.PUFF_S
			var m: StandardMaterial3D = p.material_override
			var c: Color = m.albedo_color
			c.a = 1.0 - k
			m.albedo_color = c
			p.scale = Vector3.ONE * (1.0 + k * 0.6)
		else:
			p.visible = false


func _sync_tubes(dt: float) -> void:
	for i: int in _tube_mat.size():
		_tube_glow[i] = maxf(0.0, _tube_glow[i] - dt)
		var g: float = 1.0 + 0.6 * (_tube_glow[i] / NbBalance.WALL_GLOW_S)
		_tube_mat[i].albedo_color = HOTPINK * 2.2 * g


## Camera: intro sweep, idle drift, push-in and shake (DESIGN 6a/6b).
func sync_camera(real_delta: float) -> void:
	_sweep_t += real_delta
	var pitch: float = 0.0
	if _sweep_t < NbBalance.INTRO_SWEEP_S:
		var k: float = _sweep_t / NbBalance.INTRO_SWEEP_S
		pitch = NbBalance.INTRO_SWEEP_DEG * pow(1.0 - k, 3.0)
	var yaw: float = 0.0
	if drift_on and not _less_motion:
		yaw = NbBalance.DRIFT_DEG * sin(_t * TAU / NbBalance.DRIFT_PERIOD_S)
	cam_pivot.rotation_degrees = Vector3(pitch, yaw, 0.0)
	var pos: Vector3 = _cam_rest_local()
	if _push_t >= 0.0 and not _less_motion:
		_push_t += real_delta
		var total: float = NbBalance.SLOWMO_S + NbBalance.SLOWMO_RETURN_S
		var back: float = 0.6
		var k2: float = 0.0
		if _push_t < total:
			k2 = _push_t / total
		elif _push_t < total + back:
			k2 = 1.0 - (_push_t - total) / back
		else:
			_push_t = -1.0
		var e: float = k2 * k2 * (3.0 - 2.0 * k2)
		var target_local: Vector3 = cam_pivot.to_local(_push_target)
		pos = pos.lerp(target_local, NbBalance.PUSH_IN * e)
	camera.position = pos
	if _shake_t < _shake_len and not _less_motion:
		_shake_t += real_delta
		var amp: float = _shake_px * PX * (1.0 - _shake_t / _shake_len)
		camera.h_offset = randf_range(-amp, amp)
		camera.v_offset = randf_range(-amp, amp)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func start_intro() -> void:
	_sweep_t = 99.0 if _less_motion else 0.0
	_push_t = -1.0
	_shake_t = 99.0


func reset_camera_fx() -> void:
	_push_t = -1.0
	_shake_t = 99.0
	_sweep_t = 99.0


# ---------------------------------------------------------------- fx events


func fx_touch() -> void:
	_touch_glow_t = 0.0


func fx_paddle_hit() -> void:
	_paddle_squash_t = 0.0


func fx_wall(side: int) -> void:
	if side >= 0 and side < _tube_glow.size():
		_tube_glow[side] = NbBalance.WALL_GLOW_S


func fx_brick_hit(i: int) -> void:
	if i >= 0 and i < _brick_squash.size():
		_brick_squash[i] = 0.0


func fx_brick_broken(sim: NbSim, i: int, glow_spike: bool) -> void:
	var b: NbSim.Brick = sim.bricks[i]
	_brick_fade[i] = 0.0 if _less_motion else 99.0
	if _assist_glow == i:
		_assist_glow = -1
	var at: Vector3 = to_world(b.center(), 0.2)
	if not _less_motion:
		var p: GPUParticles3D = _shards[_shard_i]
		_shard_i = (_shard_i + 1) % _shards.size()
		var pm: ParticleProcessMaterial = p.process_material
		pm.color = Color(b.color.r * 2.2, b.color.g * 2.2, b.color.b * 2.2)
		p.global_position = at
		p.restart()
		p.emitting = true
	if glow_spike:
		var puff: MeshInstance3D = _puffs[_puff_i]
		_puff_t[_puff_i] = 0.0
		_puff_i = (_puff_i + 1) % _puffs.size()
		puff.position = at
		var m: StandardMaterial3D = puff.material_override
		m.albedo_color = Color(b.color.r * 1.6, b.color.g * 1.6, b.color.b * 1.6, 1.0)
		puff.visible = true


func fx_net(pos: Vector2, spent: bool) -> void:
	_net_ripple_t = 0.0
	_net_mat.set_shader_parameter("ripple_x", pos.x - NbBalance.FIELD_LEFT)
	if spent:
		_pip_out_t = 0.0


func fx_assist(i: int) -> void:
	_assist_glow = i


func fx_restored(indices: PackedInt32Array) -> void:
	_restored = indices if not _less_motion else PackedInt32Array()
	for i: int in indices:
		_brick_fade[i] = 99.0


func fx_last_brick(pos: Vector2) -> void:
	if _less_motion:
		return
	_push_target = to_world(pos)
	_push_t = 0.0
	_shake_t = 0.0
	_shake_px = NbBalance.SHAKE_LAST_PX
	_shake_len = NbBalance.SHAKE_LAST_S
