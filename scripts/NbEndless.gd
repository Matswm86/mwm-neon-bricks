class_name NbEndless
extends RefCounted

## Endless generator "Neonveien" v3 (GDD 16.9). Endless level k = 1, 2, 3 ...
## is deterministic for a given save: the same k and the same cleared list
## give the same map. Returns a level dictionary in the NbLevels format.

const TEMPLATES: Array[String] = ["full", "checker", "stripes", "diamond", "pyramid", "frame"]
const MAX_TRIES: int = 20
const LINT_X: Array[float] = [140.0, 340.0, 540.0, 740.0, 940.0]
const LINT_MAX_DEG: float = 55.0
## Level that first shows an element (GDD 16.9 rule 2).
const INTRO: Dictionary = {
	"T": 6,
	"M": 7,
	"bredvinge": 8,
	"C": 9,
	"march": 11,
	"neonpuls": 13,
	"ghost": 16,
	"saktetid": 18,
	"portal": 21,
	"skjoldnett": 23,
	"O": 26,
	"march2": 27,
}
const BOSS_MODELS: Array[String] = ["lastebilen", "krystallhjertet", "neonnova"]

static var _cache: Dictionary = {}
static var _cache_key: String = ""


## Endless level k for the current save (NeonBricks.cleared when present).
static func level(k: int) -> Dictionary:
	var cleared: Array = []
	var ml: SceneTree = Engine.get_main_loop() as SceneTree
	if ml and ml.root.has_node("NeonBricks"):
		cleared = ml.root.get_node("NeonBricks").cleared
	var key: String = str(cleared)
	if key != _cache_key:
		_cache.clear()
		_cache_key = key
	if not _cache.has(k):
		_cache[k] = generate(maxi(1, k), cleared)
	return _cache[k]


static func clear_cache() -> void:
	_cache.clear()
	_cache_key = ""


static func allowed(what: String, cleared: Array) -> bool:
	if not INTRO.has(what):
		return true
	return cleared.has(int(INTRO[what]))


static func generate(k: int, cleared: Array) -> Dictionary:
	var base_seed: int = hash("neon_bricks_endless_" + str(k))
	for attempt: int in MAX_TRIES:
		var rng := RandomNumberGenerator.new()
		rng.seed = base_seed + attempt
		var lv: Dictionary = _build(k, cleared, rng, "")
		if _valid(lv):
			return lv
	var fb := RandomNumberGenerator.new()
	fb.seed = base_seed
	return _build(k, cleared, fb, "pyramid")


## breather: every 5th k (d halved, net unlimited).
static func _build(k: int, cleared: Array, rng: RandomNumberGenerator, force: String) -> Dictionary:
	var d: float = minf(1.0, float(k - 1) / 30.0)
	var breather: bool = k % 5 == 0
	if breather:
		d *= 0.5
	var boss: bool = k % 10 == 0
	var n: int = 4 + roundi(4.0 * d)
	var top: int = 2
	var low: int = mini(top + n - 1, 9)
	n = low - top + 1
	var grid: Array = []
	for r: int in 12:
		var row: Array[String] = []
		row.resize(10)
		row.fill(".")
		grid.append(row)
	# Template, left half, 10% removed, mirrored.
	var tpl: String = force if force != "" else TEMPLATES[rng.randi() % TEMPLATES.size()]
	var cells: Array[Vector2i] = []
	for i: int in n:
		for c: int in 5:
			if _template_has(tpl, i, c, n):
				cells.append(Vector2i(top + i, c))
	var remove: int = roundi(cells.size() * 0.1)
	for i: int in remove:
		if cells.size() > 1:
			cells.remove_at(rng.randi() % cells.size())
	# Brick types (rule 5), mirrored cells copy the left cell.
	var chrome_ok: bool = allowed("C", cleared) and force == ""
	var magnet_ok: bool = allowed("O", cleared) and force == ""
	var triple_ok: bool = allowed("T", cleared) and force == ""
	var magnets: int = 0
	var novas: int = 0
	for cell: Vector2i in cells:
		var code: String = "G"
		if force == "":
			var lowest: bool = cell.x == low
			if chrome_ok and not lowest and rng.randf() < 0.05 + 0.10 * d:
				code = "C"
			elif magnet_ok and not lowest and cell.x <= 8 and magnets < 4 and rng.randf() < 0.04:
				code = "O"
				magnets += 2
			elif triple_ok and rng.randf() < 0.10 * d:
				code = "T"
			elif rng.randf() < 0.20 + 0.15 * d:
				code = "D"
			elif novas < 6 and rng.randf() < 0.08:
				code = "N"
				novas += 2
		grid[cell.x][cell.y] = code
		grid[cell.x][9 - cell.y] = code
	var lv: Dictionary = {
		"id": NbLevels.ENDLESS_BASE + k,
		"world": 1 + (k - 1) % 6,
		"name": "Neonveien %d" % k,
		"endless": k,
		"lett_speed": 570.0,
		"vanlig_speed": minf(880.0 + 10.0 * floorf(k / 5.0), 960.0),
		"vanlig_paddle": 240.0,
		"vanlig_net": 0 if breather else 3,
	}
	# Level mechanic (rule 6), one roll.
	var u_m: float = rng.randf()
	# GDD 16.9 rule 6 (changed 2026-10-07): the mirrored templates are 10
	# columns wide, so a march roll trims the formation to the central 8
	# columns (c1-c8, still mirrored) and the "at most 8 wide" rule can pass.
	var march_ok: bool = allowed("march", cleared) and force == "" and not boss
	var two_ok: bool = march_ok and allowed("march2", cleared) and u_m < 0.15 and n >= 2
	if march_ok and u_m < 0.40 and _width(grid) > 8:
		for r: int in range(top, low + 1):
			grid[r][0] = "."
			grid[r][9] = "."
	if boss:
		for r: int in 2:
			for c: int in 3:
				grid[r][3 + c] = "K" if r == 0 and c == 0 else "+"
		var hp_v: int = mini(20 + k / 5, 40)
		var hp_l: int = mini(12 + k / 10, 40)
		var acts: Array[String] = ["minions", "minions"]
		if cleared.has(30) and k % 20 == 0:
			acts = ["minions", "minions+nova_ring"]
		lv["boss"] = {
			"hp": [hp_l, hp_v],
			"speed": [0.0, 0.0],
			"minions": false,
			"on_phase": acts,
			"model": BOSS_MODELS[(k / 10 - 1) % BOSS_MODELS.size()],
		}
		lv["march"] = {"rows": [0, low], "floor_y": 800.0}
	elif two_ok:
		var split: int = top + n / 2 - 1
		var lower_top: float = NbBalance.GRID_Y + NbBalance.CELL_H * float(split + 1) + 4.0
		lv["march"] = [
			{"rows": [top, split], "floor_y": lower_top, "dir": 1},
			{"rows": [split + 1, low], "floor_y": 1000.0, "dir": -1},
		]
	elif march_ok and u_m < 0.40:
		lv["march"] = {"rows": [top, low], "floor_y": 1000.0}
	elif allowed("M", cleared) and u_m < 0.60 and force == "":
		for c: int in 10:
			if grid[low][c] != ".":
				grid[low][c] = "M"
	# Switch + ghosts (rule 7) and portals (rule 8), separate rolls.
	var ghost_roll: float = rng.randf()
	var portal_roll: float = rng.randf()
	if not boss and force == "":
		if allowed("ghost", cleared) and ghost_roll < 0.30 and low + 2 <= 11 and n >= 3:
			for r: int in [top + 1, top + 2]:
				for c: int in 10:
					if grid[r][c] != ".":
						grid[r][c] = "A" if (r + c) % 2 == 0 else "B"
			grid[low + 2][3] = "S"
			grid[low + 2][6] = "S"
		if allowed("portal", cleared) and portal_roll < 0.25 and low + 2 <= 11:
			if _portal_ok(grid, 0, 1) and _portal_ok(grid, low + 2, 8):
				grid[0][1] = "1"
				grid[low + 2][8] = "1"
	# Carriers (rule 9): lower half of the formation, random allowed kinds.
	var kinds: Array[String] = ["komet", "ekko"]
	for pk: String in ["bredvinge", "neonpuls", "saktetid", "skjoldnett"]:
		if allowed(pk, cleared):
			kinds.append(pk)
	var mid: int = top + n / 2
	var cand: Array[Vector2i] = []
	for r: int in range(mid, low + 1):
		for c: int in 10:
			if grid[r][c] in ["G", "D", "T", "N", "M", "A", "B", "O"]:
				cand.append(Vector2i(r, c))
	var n_car: int = 2 + floori(2.0 * d)
	var chosen: Array[Vector2i] = []
	for i: int in n_car:
		if cand.is_empty():
			break
		chosen.append(cand.pop_at(rng.randi() % cand.size()))
	chosen.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool: return a.x * 10 + a.y < b.x * 10 + b.y
	)
	var carriers: Array[String] = []
	for cell: Vector2i in chosen:
		grid[cell.x][cell.y] = String(grid[cell.x][cell.y]).to_lower()
		carriers.append(kinds[rng.randi() % kinds.size()])
	lv["carriers"] = carriers
	lv["bonus_pool"] = kinds
	var rows: Array = []
	for r: int in 12:
		rows.append("".join(PackedStringArray(grid[r])))
	while rows.size() > 1 and String(rows[rows.size() - 1]) == "..........":
		rows.pop_back()
	lv["rows"] = rows
	return lv


static func _template_has(tpl: String, i: int, c: int, n: int) -> bool:
	match tpl:
		"checker":
			return (i + c) % 2 == 0
		"stripes":
			return i % 2 == 0
		"diamond":
			var m: float = float(n - 1) * 0.5
			return absf(float(i) - m) / maxf(1.0, m) + float(4 - c) / 5.0 <= 1.0
		"pyramid":
			return c >= 4 - i
		"frame":
			return i == 0 or i == n - 1 or c == 0
	return true


static func _width(grid: Array) -> int:
	var lo: int = 10
	var hi: int = -1
	for r: int in 12:
		for c: int in 10:
			if grid[r][c] != ".":
				lo = mini(lo, c)
				hi = maxi(hi, c)
	return hi - lo + 1 if hi >= 0 else 0


## GDD 16.4 rule 2: no chrome, switch or portal in the 8 neighbours.
static func _portal_ok(grid: Array, r: int, c: int) -> bool:
	if grid[r][c] != ".":
		return false
	for dr: int in [-1, 0, 1]:
		for dc: int in [-1, 0, 1]:
			var rr: int = r + dr
			var cc: int = c + dc
			if (dr != 0 or dc != 0) and rr >= 0 and rr < 12 and cc >= 0 and cc < 10:
				if grid[rr][cc] in ["C", "S", "1", "2"]:
					return false
	return true


## GDD 16.9 rule 10: breakable 20-48, chrome at most 20% of filled cells,
## every fixed breakable cell reachable (16.4 rule 1).
static func _valid(lv: Dictionary) -> bool:
	var breakable: int = 0
	var chrome: int = 0
	var filled: int = 0
	for s: String in lv["rows"]:
		for ch: String in s:
			if ch in [".", "+", "1", "2"]:
				continue
			filled += 1
			if ch == "C" or ch == "S":
				chrome += 1 if ch == "C" else 0
			else:
				breakable += 1
	if breakable < 20 or breakable > 48:
		return false
	if float(chrome) > 0.2 * float(filled):
		return false
	return lint(lv).is_empty()


## Map rule 1 (GDD 16.4), the same test as tools/action_sim.py: every
## breakable cell that does not move is reachable from the paddle line by a
## straight or one-wall bank shot within 55 degrees; chrome, switches and
## portal circles block. Returns the unreachable cells as "r,c".
static func lint(lv: Dictionary) -> PackedStringArray:
	var sim := NbSim.new()
	sim.setup(lv, false)
	var out := PackedStringArray()
	var blockers: Array[Rect2] = []
	for b: NbSim.Brick in sim.bricks:
		if not b.breakable():
			blockers.append(b.rect)
	var y: float = sim.paddle_top() - 4.0 - NbBalance.BALL_RADIUS
	var r: float = NbBalance.BALL_RADIUS
	for b: NbSim.Brick in sim.bricks:
		if not b.breakable() or b.march or b.vx != 0.0 or b.boss:
			continue
		var c: Vector2 = b.center()
		var ok: bool = false
		for px: float in LINT_X:
			var from := Vector2(px, y)
			if _deg(c - from) <= LINT_MAX_DEG and sim._clear_path(from, c, blockers):
				ok = true
				break
			for wall: float in [NbBalance.FIELD_LEFT + r, NbBalance.FIELD_RIGHT - r]:
				var mx: float = 2.0 * wall - c.x
				if is_equal_approx(mx, px):
					continue
				var kk: float = (wall - px) / (mx - px)
				if kk <= 0.0 or kk >= 1.0:
					continue
				var wp := Vector2(wall, y + (c.y - y) * kk)
				if (
					_deg(wp - from) <= LINT_MAX_DEG
					and sim._clear_path(from, wp, blockers)
					and sim._clear_path(wp, c, blockers)
				):
					ok = true
					break
			if ok:
				break
		if not ok:
			out.append("%d,%d" % [b.row, b.col])
	return out


static func _deg(v: Vector2) -> float:
	return absf(rad_to_deg(atan2(v.x, -v.y)))
