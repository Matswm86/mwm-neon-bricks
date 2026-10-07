class_name NbPieces
extends Node3D

## World 4-6 pieces that do not live in the brick MultiMesh (DESIGN 12):
## ghosts A / B (one transparent MultiMesh, cross-faded phase), portal pairs
## (one MultiMesh of shader quads) and the GLB bosses of levels 20, 25 and
## 30 with their health notches (one small MultiMesh). NbWorld binds them to
## a level and syncs them every frame; nothing here allocates per frame.

const BOSS_SCENES: Dictionary = {
	"lastebilen": "res://assets/models/boss_lastebilen.glb",
	"krystallhjertet": "res://assets/models/boss_krystallhjertet.glb",
	"neonnova": "res://assets/models/boss_neonnova.glb",
}
## Core centre inside the 2.92 x 0.96 m box (DESIGN 12.6); the GLB origin
## is the core centre.
const CORE_OFFSET: Dictionary = {"lastebilen": Vector2(-0.46, 0.06)}
const NOTCH_R: float = 0.355
const NOTCH_DARK := Color(0.165, 0.133, 0.220)
const IMPLODE_S: float = 0.4

## Brick index -> ghost slot (-1 = not a ghost).
var ghost_slot: PackedInt32Array = PackedInt32Array()
## Boss drawn by a GLB (its brick MultiMesh instance is hidden).
var boss_model_on: bool = false

var _ghosts: MultiMeshInstance3D
var _ghost_mat: ShaderMaterial
var _ghost_phase: PackedFloat32Array = PackedFloat32Array()
var _ghost_index: PackedInt32Array = PackedInt32Array()
var _portals: MultiMeshInstance3D
var _portal_mat: ShaderMaterial
var _portal_pop: PackedFloat32Array = PackedFloat32Array()
var _boss_root: Node3D
var _boss_node: Node3D
var _boss_ring: StandardMaterial3D
var _boss_ring_e: float = 4.0
var _notches: MultiMeshInstance3D
var _notch_hp: int = -1
var _boss_accent: Color = Color(1, 1, 1)
var _boss_core: Vector2 = Vector2.ZERO
var _boss_squash_t: float = 99.0
var _roar_t: float = 99.0
var _dead_t: float = -1.0
var _warn_t: float = 99.0
var _warn_spikes: int = 0
var _less_motion: bool = false
var _boss_cache: Dictionary = {}


func build(brick_mesh: Mesh) -> void:
	_ghosts = MultiMeshInstance3D.new()
	_ghost_mat = ShaderMaterial.new()
	_ghost_mat.shader = preload("res://shaders/ghost.gdshader")
	_ghost_mat.render_priority = 1
	_ghosts.material_override = _ghost_mat
	_ghosts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var gm := MultiMesh.new()
	gm.transform_format = MultiMesh.TRANSFORM_3D
	gm.use_colors = true
	gm.use_custom_data = true
	gm.mesh = brick_mesh
	_ghosts.multimesh = gm
	add_child(_ghosts)
	_portals = MultiMeshInstance3D.new()
	_portal_mat = ShaderMaterial.new()
	_portal_mat.shader = preload("res://shaders/portal.gdshader")
	_portal_mat.render_priority = 1
	_portals.material_override = _portal_mat
	_portals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := MultiMesh.new()
	pm.transform_format = MultiMesh.TRANSFORM_3D
	pm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(0.86, 0.86)
	pm.mesh = q
	_portals.multimesh = pm
	add_child(_portals)
	_boss_root = Node3D.new()
	add_child(_boss_root)
	_notches = MultiMeshInstance3D.new()
	var nm := MultiMesh.new()
	nm.transform_format = MultiMesh.TRANSFORM_3D
	nm.use_colors = true
	var bx := BoxMesh.new()
	bx.size = Vector3(0.032, 0.075, 0.03)
	nm.mesh = bx
	_notches.multimesh = nm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	_notches.material_override = mat
	_notches.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_boss_root.add_child(_notches)


func set_less_motion(on: bool) -> void:
	_less_motion = on
	_portal_mat.set_shader_parameter("less_motion", 1.0 if on else 0.0)


func bind(sim: NbSim) -> void:
	# Ghosts.
	ghost_slot.resize(sim.bricks.size())
	ghost_slot.fill(-1)
	_ghost_index = PackedInt32Array()
	for i: int in sim.bricks.size():
		if sim.bricks[i].ghost != 0:
			ghost_slot[i] = _ghost_index.size()
			_ghost_index.append(i)
	var gm: MultiMesh = _ghosts.multimesh
	gm.instance_count = _ghost_index.size()
	_ghost_phase.resize(_ghost_index.size())
	for k: int in _ghost_index.size():
		var b: NbSim.Brick = sim.bricks[_ghost_index[k]]
		_ghost_phase[k] = 0.0 if sim.solid(b) else 1.0
		gm.set_instance_color(k, b.color.srgb_to_linear())
		gm.set_instance_transform(k, Transform3D(Basis(), NbWorld.to_world(b.center())))
	_ghosts.visible = not _ghost_index.is_empty()
	_warn_t = 99.0
	# Portals.
	var pm: MultiMesh = _portals.multimesh
	pm.instance_count = sim.portals.size()
	_portal_pop.resize(sim.portals.size())
	_portal_pop.fill(99.0)
	for k: int in sim.portals.size():
		var p: NbSim.Portal = sim.portals[k]
		pm.set_instance_transform(k, Transform3D(Basis(), NbWorld.to_world(p.pos, 0.02)))
		pm.set_instance_custom_data(k, Color(float(p.pair), 0.0, 0.0, 0.0))
	_portals.visible = not sim.portals.is_empty()
	# Boss model.
	_bind_boss(sim)


func _bind_boss(sim: NbSim) -> void:
	if _boss_node:
		_boss_node.visible = false
		_boss_node = null
	boss_model_on = false
	_boss_root.visible = false
	_dead_t = -1.0
	_roar_t = 99.0
	_boss_squash_t = 99.0
	_notch_hp = -1
	var model: String = String(sim.level.get("boss", {}).get("model", ""))
	if sim.boss_index < 0 or not BOSS_SCENES.has(model):
		return
	if not _boss_cache.has(model):
		var ps: PackedScene = load(BOSS_SCENES[model])
		var n: Node3D = ps.instantiate()
		_boss_root.add_child(n)
		_boss_cache[model] = n
	_boss_node = _boss_cache[model]
	_boss_node.visible = true
	_boss_ring = null
	var mi: MeshInstance3D = _find_mi(_boss_node)
	if mi:
		for s: int in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(s)
			if m is StandardMaterial3D and m.resource_name == "core_ring":
				_boss_ring = (m as StandardMaterial3D).duplicate()
				_boss_ring_e = _boss_ring.emission_energy_multiplier
				mi.set_surface_override_material(s, _boss_ring)
	_boss_core = CORE_OFFSET.get(model, Vector2.ZERO)
	_boss_accent = NbLevels.BOSS_ACCENT.get(model, Color(1, 1, 1))
	var b: NbSim.Brick = sim.bricks[sim.boss_index]
	var nm: MultiMesh = _notches.multimesh
	nm.instance_count = b.max_hp
	for k: int in b.max_hp:
		# 12 o'clock, clockwise, each pointing outward.
		var a: float = -TAU * float(k) / float(b.max_hp)
		var dir := Vector2(-sin(a), cos(a))
		var xf := Transform3D(Basis(Vector3.BACK, a), Vector3(dir.x, dir.y, 0.0) * NOTCH_R)
		xf.origin.z = 0.27
		nm.set_instance_transform(k, xf)
	_notches.position = Vector3.ZERO
	boss_model_on = true
	_boss_root.visible = true


static func _find_mi(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n as MeshInstance3D
	for c: Node in n.get_children():
		var f: MeshInstance3D = _find_mi(c)
		if f:
			return f
	return null


func sync(sim: NbSim, dt: float, ghost_glow: float) -> void:
	_sync_ghosts(sim, dt, ghost_glow)
	_sync_portals(dt)
	_sync_boss(sim, dt)


func _sync_ghosts(sim: NbSim, dt: float, glow_extra: float) -> void:
	if _ghost_index.is_empty():
		return
	_warn_t += dt
	var gm: MultiMesh = _ghosts.multimesh
	var step: float = dt / NbBalance.GHOST_FADE_S
	var warn: float = 0.0
	if _warn_t < NbBalance.GHOST_WARN_S and _warn_spikes > 0:
		# Two soft pulses in 1 s (2 Hz), only on the set about to turn solid.
		warn = 0.6 * maxf(0.0, sin(_warn_t * TAU * float(NbBalance.GHOST_WARN_PULSES)))
	for k: int in _ghost_index.size():
		var b: NbSim.Brick = sim.bricks[_ghost_index[k]]
		var want: float = 0.0 if sim.solid(b) else 1.0
		if _less_motion:
			_ghost_phase[k] = want
		else:
			_ghost_phase[k] = move_toward(_ghost_phase[k], want, step)
		var w: float = 1.0
		var xf := Transform3D(Basis(), NbWorld.to_world(b.center()))
		if not b.alive:
			w = 0.0
			xf = Transform3D(Basis().scaled(Vector3.ZERO), xf.origin)
		elif b.march:
			xf.basis = Basis(
				Vector3.BACK, deg_to_rad(-NbBalance.MARCH_LEAN_DEG * float(sim.lean_dir(b)))
			)
			if _less_motion:
				xf.basis = Basis()
		var g: float = glow_extra
		if want > 0.5 and warn > 0.0:
			g = maxf(g, warn)
		if b.alive and g > 0.0:
			w = 1.0 + g
		gm.set_instance_transform(k, xf)
		var set_b: float = 1.0 if b.ghost == 2 else 0.0
		gm.set_instance_custom_data(k, Color(set_b, _ghost_phase[k], 1.0 if b.carrier else 0.0, w))


## Auto-flip warning: pulses only when the limiter allowed the glow.
func fx_warn(allowed: bool) -> void:
	_warn_t = 0.0
	_warn_spikes = 1 if allowed else 0


func fx_portal(i: int) -> void:
	if i >= 0 and i < _portal_pop.size():
		_portal_pop[i] = 0.0


func _sync_portals(dt: float) -> void:
	var pm: MultiMesh = _portals.multimesh
	for k: int in _portal_pop.size():
		if _portal_pop[k] > NbBalance.PORTAL_POP_S + dt:
			continue
		_portal_pop[k] += dt
		var s: float = 1.0
		if not _less_motion and _portal_pop[k] < NbBalance.PORTAL_POP_S:
			s = 1.0 + 0.15 * sin(PI * _portal_pop[k] / NbBalance.PORTAL_POP_S)
		var xf: Transform3D = pm.get_instance_transform(k)
		pm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ONE * s), xf.origin))


func fx_boss_hit() -> void:
	_boss_squash_t = 0.0


func fx_boss_roar(glow: bool) -> void:
	if glow:
		_roar_t = 0.0


func fx_boss_dead() -> void:
	_dead_t = 0.0


func _sync_boss(sim: NbSim, dt: float) -> void:
	if not boss_model_on or sim.boss_index < 0:
		return
	var b: NbSim.Brick = sim.bricks[sim.boss_index]
	_boss_squash_t += dt
	_roar_t += dt
	var s := Vector3.ONE
	if _dead_t >= 0.0 or not b.alive:
		if _dead_t < 0.0:
			_dead_t = 0.0
		_dead_t += dt
		var k: float = 0.0 if _less_motion else clampf(1.0 - _dead_t / IMPLODE_S, 0.0, 1.0)
		s = Vector3.ONE * k
	else:
		var vis: float = sim.boss_visibility()
		if _less_motion:
			vis = 1.0 if vis > 0.5 or sim.boss_jump_state == 0 else 0.0
		s = Vector3.ONE * vis
		if not _less_motion and _boss_squash_t < NbBalance.BRICK_SQUASH_S:
			s.y *= lerpf(NbBalance.BOSS_SQUASH, 1.0, _boss_squash_t / NbBalance.BRICK_SQUASH_S)
	_boss_root.visible = s.x > 0.001
	var lean := Basis()
	if b.march and not _less_motion:
		lean = Basis(Vector3.BACK, deg_to_rad(-NbBalance.MARCH_LEAN_DEG * float(sim.lean_dir(b))))
	var c: Vector3 = NbWorld.to_world(b.center()) + Vector3(_boss_core.x, _boss_core.y, 0.0)
	_boss_root.transform = Transform3D(lean * Basis.from_scale(s), c)
	if _boss_ring:
		var e: float = _boss_ring_e
		if _roar_t < NbBalance.BOSS_ROAR_S:
			e *= 1.0 + sin(PI * _roar_t / NbBalance.BOSS_ROAR_S)
		_boss_ring.emission_energy_multiplier = e
	var hp: int = maxi(b.hp, 0)
	if hp != _notch_hp:
		_notch_hp = hp
		var nm: MultiMesh = _notches.multimesh
		for k: int in nm.instance_count:
			var lit: bool = k < hp
			nm.set_instance_color(
				k, _boss_accent.srgb_to_linear() * 4.0 if lit else NOTCH_DARK.srgb_to_linear()
			)
