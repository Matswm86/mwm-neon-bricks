class_name NbLevels
extends RefCounted

## Levels 1-15 (worlds 1-3), exactly as GDD 15.7, with the numbers of the
## level table GDD 15.6 and the data format of GDD 15.8. Rows run from r0
## (top, y 340) down; missing rows are empty. Codes: G glass, D double,
## T triple, N nova, M glider, C chrome, K boss anchor (top-left of 3 x 2),
## + boss body; lowercase = carrier, holding the next kind of `carriers` in
## reading order. vanlig_net 0 = unlimited. boss pairs are [Lett, Vanlig].

const WORLD_NAMES: Array[String] = ["Neonstranda", "Rutenettbyen", "Arkadehallen"]
const LEVELS_PER_WORLD: int = 5

const LEVELS: Array[Dictionary] = [
	# ---- World 1 Neonstranda (net unlimited in both settings)
	{
		"id": 1,
		"world": 1,
		"name": "Første lys",
		"rows":
		[
			"..........",
			"..........",
			"..........",
			".GGGGGGGG.",
			"GGGGGGGGGG",
			".GGgGGgGG.",
			"..GGGGGG..",
		],
		"carriers": ["komet"],
		"bonus_pool": ["komet"],
		"lett_speed": 520.0,
		"vanlig_speed": 720.0,
		"vanlig_paddle": 280.0,
		"vanlig_net": 0,
	},
	{
		"id": 2,
		"world": 1,
		"name": "To prikker",
		"rows":
		[
			"..........",
			"..........",
			".GGGGGGGG.",
			"GDDGGGGDDG",
			"GDDGGGGDDG",
			"GGGGggGGGG",
			".GG....GG.",
			"..GGGGGG..",
		],
		"carriers": ["komet"],
		"bonus_pool": ["komet"],
		"lett_speed": 520.0,
		"vanlig_speed": 720.0,
		"vanlig_paddle": 280.0,
		"vanlig_net": 0,
	},
	{
		"id": 3,
		"world": 1,
		"name": "Supernova",
		"rows":
		[
			"..........",
			"..........",
			"GGGGGGGGGG",
			"GGNGGGGNGG",
			"GGGGGGGGGG",
			"GDGGNNGGDG",
			"GGGGGGGGGG",
			"..g....g..",
		],
		"carriers": ["komet"],
		"bonus_pool": ["komet"],
		"lett_speed": 520.0,
		"vanlig_speed": 720.0,
		"vanlig_paddle": 280.0,
		"vanlig_net": 0,
	},
	{
		"id": 4,
		"world": 1,
		"name": "Ekko",
		"rows":
		[
			"..........",
			"..........",
			"DDDDDDDDDD",
			"GGNGGGGNGG",
			"GGGGDDGGGG",
			".GGGGGGGG.",
			"..........",
			"..gG..Gg..",
		],
		"carriers": ["ekko"],
		"bonus_pool": ["komet", "ekko"],
		"lett_speed": 520.0,
		"vanlig_speed": 720.0,
		"vanlig_paddle": 280.0,
		"vanlig_net": 0,
	},
	{
		"id": 5,
		"world": 1,
		"name": "Solkjernen",
		"rows":
		[
			"..........",
			"...K++....",
			"...+++....",
			"..........",
			".GGGGGGGG.",
			".DDGNNGDD.",
			"..........",
			"..gGGGGg..",
		],
		"carriers": ["ekko", "komet"],
		"bonus_pool": ["komet", "ekko"],
		"boss": {"hp": [10, 14], "speed": [60.0, 90.0], "minions": false},
		"lett_speed": 520.0,
		"vanlig_speed": 720.0,
		"vanlig_paddle": 280.0,
		"vanlig_net": 0,
	},
	# ---- World 2 Rutenettbyen (charged net on 6-9 in Vanlig)
	{
		"id": 6,
		"world": 2,
		"name": "Trekant",
		"rows":
		[
			"..........",
			"..........",
			"....TT....",
			"...TNNT...",
			"..TGGGGT..",
			".TGGNNGGT.",
			"TGGGGGGGGT",
			"..t....t..",
		],
		"carriers": ["komet", "ekko"],
		"bonus_pool": ["komet", "ekko"],
		"lett_speed": 530.0,
		"vanlig_speed": 760.0,
		"vanlig_paddle": 280.0,
		"vanlig_net": 3,
	},
	{
		"id": 7,
		"world": 2,
		"name": "Rushtid",
		"rows":
		[
			"..........",
			"GGGGGGGGGG",
			"GNGGTTGGNG",
			"GGGGGGGGGG",
			"..........",
			".M...M...m",
			"..........",
			"m...M...M.",
		],
		"carriers": ["ekko", "komet"],
		"bonus_pool": ["komet", "ekko"],
		"lett_speed": 530.0,
		"vanlig_speed": 760.0,
		"vanlig_paddle": 280.0,
		"vanlig_net": 3,
	},
	{
		"id": 8,
		"world": 2,
		"name": "Vingene",
		"rows":
		[
			"..........",
			"GGGGGGGGGG",
			"GTGGNNGGTG",
			"GNGGGGGGNG",
			".GGGDDGGG.",
			"..........",
			".M..gg..M.",
		],
		"carriers": ["bredvinge"],
		"bonus_pool": ["komet", "ekko", "bredvinge"],
		"lett_speed": 530.0,
		"vanlig_speed": 760.0,
		"vanlig_paddle": 280.0,
		"vanlig_net": 3,
	},
	{
		"id": 9,
		"world": 2,
		"name": "Gatelys",
		"rows":
		[
			"..........",
			"GGGGGGGGGG",
			"GNGGTTGGNG",
			"GGGGGGGGGG",
			"..........",
			"..C....C..",
			"..........",
			".g.M..M.g.",
		],
		"carriers": ["bredvinge", "komet"],
		"bonus_pool": ["komet", "ekko", "bredvinge"],
		"lett_speed": 530.0,
		"vanlig_speed": 760.0,
		"vanlig_paddle": 280.0,
		"vanlig_net": 3,
	},
	{
		"id": 10,
		"world": 2,
		"name": "Nattaxi",
		"rows":
		[
			"..........",
			"...K++....",
			"...+++....",
			"..........",
			"..........",
			"GTGGNNGGTG",
			".GGGGGGGG.",
			"..........",
			".g..GG..g.",
		],
		"carriers": ["bredvinge", "ekko"],
		"bonus_pool": ["komet", "ekko", "bredvinge"],
		"boss": {"hp": [14, 16], "speed": [80.0, 120.0], "minions": true},
		"lett_speed": 530.0,
		"vanlig_speed": 760.0,
		"vanlig_paddle": 280.0,
		"vanlig_net": 0,
	},
	# ---- World 3 Arkadehallen (charged net on 11-14 in Vanlig)
	{
		"id": 11,
		"world": 3,
		"name": "Invasjon",
		"rows":
		[
			"..........",
			"..GGGGGG..",
			"..GNGGNG..",
			"..TGGGGT..",
			"..GGGGGG..",
			"..GgGGgG..",
		],
		"carriers": ["ekko", "komet"],
		"bonus_pool": ["komet", "ekko", "bredvinge"],
		"march": {"rows": [1, 5], "floor_y": 1000.0},
		"lett_speed": 540.0,
		"vanlig_speed": 800.0,
		"vanlig_paddle": 260.0,
		"vanlig_net": 3,
	},
	{
		"id": 12,
		"world": 3,
		"name": "Kjedereaksjon",
		"rows":
		[
			"..........",
			".GNGGGGNG.",
			".GGTNNTGG.",
			".NGGGGGGN.",
			".GGGTTGGG.",
			".GGgGGgGG.",
		],
		"carriers": ["komet", "ekko"],
		"bonus_pool": ["komet", "ekko", "bredvinge"],
		"march": {"rows": [1, 5], "floor_y": 1000.0},
		"lett_speed": 540.0,
		"vanlig_speed": 800.0,
		"vanlig_paddle": 260.0,
		"vanlig_net": 3,
	},
	{
		"id": 13,
		"world": 3,
		"name": "Neonpuls",
		"rows":
		[
			"..........",
			"TGGGGGGGGT",
			"GGNGTTGNGG",
			"TGGGGGGGGT",
			"GGGGNNGGGG",
			"DDGGGGGGDD",
			"..........",
			"M...nn...M",
		],
		"carriers": ["neonpuls"],
		"bonus_pool": ["komet", "ekko", "neonpuls"],
		"lett_speed": 540.0,
		"vanlig_speed": 800.0,
		"vanlig_paddle": 260.0,
		"vanlig_net": 3,
	},
	{
		"id": 14,
		"world": 3,
		"name": "Flipper",
		"rows":
		[
			"..........",
			"..TGNNGT..",
			"..GGGGGG..",
			"..GNTTNG..",
			"..GGGGGG..",
			"..DGGGGD..",
			"C...M....C",
			"..........",
			".gC.GG.Cg.",
		],
		"carriers": ["ekko", "neonpuls"],
		"bonus_pool": ["komet", "ekko", "bredvinge", "neonpuls"],
		"march": {"rows": [1, 5], "floor_y": 900.0},
		"lett_speed": 540.0,
		"vanlig_speed": 800.0,
		"vanlig_paddle": 260.0,
		"vanlig_net": 3,
	},
	{
		"id": 15,
		"world": 3,
		"name": "Arkadekongen",
		"rows":
		[
			"..........",
			"...K++....",
			".T.+++..T.",
			".GNGGGGNG.",
			".GGGTTGGG.",
			".DGGGGGGD.",
			"..........",
			"..gGNNGg..",
		],
		"carriers": ["neonpuls", "ekko"],
		"bonus_pool": ["komet", "ekko", "bredvinge", "neonpuls"],
		"boss": {"hp": [20, 30], "speed": [0.0, 0.0], "minions": true},
		"march": {"rows": [1, 5], "floor_y": 800.0},
		"lett_speed": 540.0,
		"vanlig_speed": 800.0,
		"vanlig_paddle": 260.0,
		"vanlig_net": 0,
	},
]

## Brick ramps, top occupied row first (DESIGN 2c). World 1 is the designed
## ramp: sun, tangerine, coral, hotpink, magenta. Worlds 2 and 3 are
## PLACEHOLDERS until graphic-designer delivers (GDD 15.8): world 2 cool
## city neon, world 3 arcade rainbow. None of them uses the player cyan.
const RAMPS: Array = [
	[
		Color(1.000, 0.788, 0.235),
		Color(1.000, 0.541, 0.239),
		Color(1.000, 0.353, 0.373),
		Color(1.000, 0.180, 0.533),
		Color(0.839, 0.227, 0.976),
	],
	[
		Color(0.700, 1.000, 0.300),
		Color(0.300, 1.000, 0.620),
		Color(0.300, 0.560, 1.000),
		Color(0.560, 0.400, 1.000),
		Color(1.000, 0.300, 0.700),
	],
	[
		Color(1.000, 0.260, 0.260),
		Color(1.000, 0.560, 0.160),
		Color(1.000, 0.900, 0.220),
		Color(0.380, 0.950, 0.360),
		Color(0.360, 0.560, 1.000),
	],
]
const CHROME: Color = Color(0.788, 0.808, 0.847)
## Boss body: a deep amber slab in every world (placeholder).
const BOSS: Color = Color(1.000, 0.520, 0.160)


static func count() -> int:
	return LEVELS.size()


static func world_count() -> int:
	return ceili(float(LEVELS.size()) / float(LEVELS_PER_WORLD))


static func get_level(id: int) -> Dictionary:
	for lv: Dictionary in LEVELS:
		if int(lv["id"]) == id:
			return lv
	return LEVELS[0]


static func has_level(id: int) -> bool:
	return id >= 1 and id <= LEVELS.size()


static func world_of(id: int) -> int:
	return clampi((id - 1) / LEVELS_PER_WORLD + 1, 1, world_count())


## Carrier kinds of a level; older data used one `carrier_powerup` string.
static func carriers(lv: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k: Variant in lv.get("carriers", []):
		out.append(String(k))
	if out.is_empty() and String(lv.get("carrier_powerup", "")) != "":
		out.append(String(lv["carrier_powerup"]))
	return out


static func bonus_pool(lv: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k: Variant in lv.get("bonus_pool", []):
		out.append(String(k))
	return out


## Colour of every occupied row: the ramp steps once per occupied row,
## chrome rows included (matches the world 1 mock).
static func row_colors(rows: Array, world: int = 1) -> Dictionary:
	var ramp: Array = RAMPS[clampi(world - 1, 0, RAMPS.size() - 1)]
	var out: Dictionary = {}
	var step: int = 0
	for r: int in rows.size():
		var s: String = rows[r]
		if s.replace(".", "").replace("+", "") == "":
			continue
		out[r] = ramp[mini(step, ramp.size() - 1)]
		step += 1
	return out


## Colour of one cell for thumbnails and the brick MultiMesh.
static func cell_color(code: String, row_color: Color) -> Color:
	if code == "C":
		return CHROME
	if code == "K" or code == "+":
		return BOSS
	return row_color
