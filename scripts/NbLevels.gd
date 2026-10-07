class_name NbLevels
extends RefCounted

## Levels 1-30 (worlds 1-6), exactly as GDD 15.7 and 16.7, with the numbers
## of the level tables GDD 15.6 / 16.5 and the data format of GDD 15.8 / 16.8. Rows run from r0
## (top, y 340) down; missing rows are empty. Codes: G glass, D double,
## T triple, N nova, M glider, C chrome, K boss anchor (top-left of 3 x 2),
## + boss body, S switch, A / B ghost set A / B, O magnet, 1 / 2 portal pair;
## lowercase = carrier, holding the next kind of `carriers` in reading
## order. vanlig_net 0 = unlimited. boss pairs are [Lett, Vanlig]; boss
## "model" picks the GLB of the world 4-6 bosses (DESIGN 12.6).

const WORLD_NAMES: Array[String] = [
	"Neonstranda", "Rutenettbyen", "Arkadehallen", "Nattveien", "Krystallgrotta", "Stjerneporten"
]
## Endless levels ("Neonveien", GDD 16.9) use ids ENDLESS_BASE + k.
const ENDLESS_BASE: int = 1000
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
	# ---- World 4 Nattveien
	{
		"id": 16,
		"world": 4,
		"name": "Bryteren",
		"rows":
		[
			"..........",
			"GGGGGGGGGG",
			"ABABABABAB",
			"BABABABABA",
			"GGNGGGGNGG",
			"..........",
			"..S....S..",
			"..........",
			".g..GG..g.",
		],
		"carriers": ["komet", "ekko"],
		"bonus_pool": ["komet", "ekko", "bredvinge"],
		"lett_speed": 550.0,
		"vanlig_speed": 830.0,
		"vanlig_paddle": 260.0,
		"vanlig_net": 3,
	},
	{
		"id": 17,
		"world": 4,
		"name": "Skyggemarsj",
		"rows":
		[
			"..........",
			".GGGGGGGG.",
			".AAAAAAAA.",
			".SBBNNBBS.",
			".AAAAAAAA.",
			".GgGGGGgG.",
		],
		"carriers": ["ekko", "komet"],
		"bonus_pool": ["komet", "ekko", "bredvinge"],
		"march": {"rows": [1, 5], "floor_y": 1000.0},
		"lett_speed": 550.0,
		"vanlig_speed": 830.0,
		"vanlig_paddle": 260.0,
		"vanlig_net": 3,
	},
	{
		"id": 18,
		"world": 4,
		"name": "Saktetid",
		"rows":
		[
			"..........",
			"GGGGGGGGGG",
			"GNGABBAGNG",
			"GGGBAABGGG",
			".GGGNNGGG.",
			"..........",
			"...S..S...",
			"..........",
			"M...gg...M",
		],
		"carriers": ["saktetid"],
		"bonus_pool": ["komet", "ekko", "bredvinge"],
		"lett_speed": 550.0,
		"vanlig_speed": 830.0,
		"vanlig_paddle": 260.0,
		"vanlig_net": 3,
	},
	{
		"id": 19,
		"world": 4,
		"name": "Filskifte",
		"rows":
		[
			"..........",
			"GGGGGGGGGG",
			"GNGGDDGGNG",
			"ABABABABAB",
			"..........",
			"...S..S...",
			"..........",
			".M..gg..M.",
			"..........",
			"M........M",
		],
		"carriers": ["saktetid", "ekko"],
		"bonus_pool": ["komet", "ekko", "bredvinge", "saktetid"],
		"lett_speed": 550.0,
		"vanlig_speed": 830.0,
		"vanlig_paddle": 260.0,
		"vanlig_net": 3,
	},
	{
		"id": 20,
		"world": 4,
		"name": "Lastebilen",
		"rows":
		[
			"..........",
			"..GGGGGG..",
			".NGBBBBGN.",
			"..........",
			"...K++....",
			"...+++....",
			".AAAAAAAA.",
			"S........S",
			"..g.GG.g..",
		],
		"carriers": ["ekko", "komet"],
		"bonus_pool": ["komet", "ekko", "saktetid"],
		"boss":
		{
			"hp": [12, 14],
			"speed": [70.0, 110.0],
			"minions": false,
			"on_phase": ["shield_up", "shield_up"],
			"model": "lastebilen",
		},
		"lett_speed": 550.0,
		"vanlig_speed": 830.0,
		"vanlig_paddle": 260.0,
		"vanlig_net": 0,
	},
	# ---- World 5 Krystallgrotta
	{
		"id": 21,
		"world": 5,
		"name": "Ormehull",
		"rows":
		[
			"........1.",
			"GGGGGGGGGG",
			"GGNGGGGNGG",
			"DGGGDDGGGD",
			"GGGGGGGGGG",
			"..........",
			"..........",
			".1......g.",
			"..g.......",
		],
		"carriers": ["komet", "ekko"],
		"bonus_pool": ["komet", "ekko", "saktetid"],
		"lett_speed": 560.0,
		"vanlig_speed": 860.0,
		"vanlig_paddle": 240.0,
		"vanlig_net": 3,
	},
	{
		"id": 22,
		"world": 5,
		"name": "Krystallbuer",
		"rows":
		[
			"1........2",
			".GGGGGGGG.",
			".GNGTTGNG.",
			".GGGGGGGG.",
			"..........",
			"M...MM...M",
			"..........",
			"..2....1..",
			".g.M..M.g.",
		],
		"carriers": ["ekko", "komet"],
		"bonus_pool": ["komet", "ekko", "bredvinge", "saktetid"],
		"lett_speed": 560.0,
		"vanlig_speed": 860.0,
		"vanlig_paddle": 240.0,
		"vanlig_net": 3,
	},
	{
		"id": 23,
		"world": 5,
		"name": "Skjoldnett",
		"rows":
		[
			".........1",
			".GGGGGGGG.",
			"GDGGNNGGDG",
			"GGAABBAAGG",
			".GGGGGGGG.",
			"..........",
			"1..S..S...",
			"..........",
			"..g....g..",
		],
		"carriers": ["skjoldnett"],
		"bonus_pool": ["komet", "ekko", "skjoldnett", "saktetid"],
		"lett_speed": 560.0,
		"vanlig_speed": 860.0,
		"vanlig_paddle": 240.0,
		"vanlig_net": 3,
	},
	{
		"id": 24,
		"world": 5,
		"name": "Labyrint",
		"rows":
		[
			"..........",
			"..GAAAAG..",
			"..NBBBBN..",
			"..GAAAAG..",
			"..TGGGGT..",
			"..........",
			"..........",
			"1.S....S.1",
			"..........",
			"...g..g...",
		],
		"carriers": ["skjoldnett", "ekko"],
		"bonus_pool": ["komet", "ekko", "neonpuls", "skjoldnett"],
		"march": {"rows": [1, 4], "floor_y": 700.0},
		"lett_speed": 560.0,
		"vanlig_speed": 860.0,
		"vanlig_paddle": 240.0,
		"vanlig_net": 3,
	},
	{
		"id": 25,
		"world": 5,
		"name": "Krystallhjertet",
		"rows":
		[
			"..........",
			"...K++....",
			"...+++....",
			"..........",
			"GGDGGGGDGG",
			"GNGGTTGGNG",
			"..........",
			".1......1.",
			"..g....g..",
		],
		"carriers": ["ekko", "komet"],
		"bonus_pool": ["komet", "ekko", "neonpuls", "skjoldnett"],
		"boss":
		{
			"hp": [18, 24],
			"speed": [0.0, 0.0],
			"minions": true,
			"on_phase": ["jump", "jump"],
			"jump": [[1, 6], [1, 1]],
			"model": "krystallhjertet",
		},
		"lett_speed": 560.0,
		"vanlig_speed": 860.0,
		"vanlig_paddle": 240.0,
		"vanlig_net": 0,
	},
	# ---- World 6 Stjerneporten
	{
		"id": 26,
		"world": 6,
		"name": "Magneten",
		"rows":
		[
			"..........",
			"GGGGGGGGGG",
			"GGGOGGOGGG",
			"GNGGGGGGNG",
			"GGGGOOGGGG",
			".GGGGGGGG.",
			"..........",
			"..g....g..",
		],
		"carriers": ["komet", "ekko"],
		"bonus_pool": ["komet", "ekko", "neonpuls", "saktetid"],
		"lett_speed": 570.0,
		"vanlig_speed": 880.0,
		"vanlig_paddle": 240.0,
		"vanlig_net": 3,
	},
	{
		"id": 27,
		"world": 6,
		"name": "Dobbelmarsj",
		"rows":
		[
			"..........",
			".GGNGGNGG.",
			".GOGGGGOG.",
			"..........",
			"..........",
			"..TGGGGT..",
			"..GNggNG..",
			"..GGGGGG..",
		],
		"carriers": ["ekko", "neonpuls"],
		"bonus_pool": ["komet", "ekko", "bredvinge", "neonpuls"],
		"march":
		[
			{"rows": [1, 2], "floor_y": 600.0, "dir": 1},
			{"rows": [5, 7], "floor_y": 1000.0, "dir": -1},
		],
		"lett_speed": 570.0,
		"vanlig_speed": 880.0,
		"vanlig_paddle": 240.0,
		"vanlig_net": 3,
	},
	{
		"id": 28,
		"world": 6,
		"name": "Stjernestorm",
		"rows":
		[
			"1........2",
			"GGGGGGGGGG",
			"GAAOGGOBBG",
			"GBBGNNGAAG",
			".GGGGGGGG.",
			"..........",
			"...S..S...",
			".2......1.",
			".g.M..M.g.",
		],
		"carriers": ["komet", "skjoldnett"],
		"bonus_pool": ["komet", "ekko", "neonpuls", "saktetid", "skjoldnett"],
		"lett_speed": 570.0,
		"vanlig_speed": 880.0,
		"vanlig_paddle": 240.0,
		"vanlig_net": 3,
	},
	{
		"id": 29,
		"world": 6,
		"name": "Siste port",
		"rows":
		[
			"..........",
			"..GAAAAG..",
			"..NBOOBN..",
			"..GAAAAG..",
			"..DGGGGD..",
			"..........",
			"..........",
			"..........",
			"1.S....S.1",
			".gM....Mg.",
		],
		"carriers": ["ekko", "neonpuls"],
		"bonus_pool": ["komet", "ekko", "bredvinge", "neonpuls", "saktetid", "skjoldnett"],
		"march": {"rows": [1, 4], "floor_y": 760.0},
		"lett_speed": 570.0,
		"vanlig_speed": 880.0,
		"vanlig_paddle": 240.0,
		"vanlig_net": 3,
	},
	{
		"id": 30,
		"world": 6,
		"name": "Neonnova",
		"rows":
		[
			"..........",
			"...K++....",
			".O.+++..O.",
			".GNGGGGNG.",
			".GGTGGTGG.",
			".DGGGGGGD.",
			"..........",
			"1..g..g..1",
		],
		"carriers": ["neonpuls", "ekko"],
		"bonus_pool": ["komet", "ekko", "bredvinge", "neonpuls", "saktetid"],
		"boss":
		{
			"hp": [26, 32],
			"speed": [0.0, 0.0],
			"minions": false,
			"on_phase": ["minions", "minions+nova_ring"],
			"model": "neonnova",
		},
		"march": {"rows": [1, 5], "floor_y": 800.0},
		"lett_speed": 570.0,
		"vanlig_speed": 880.0,
		"vanlig_paddle": 240.0,
		"vanlig_net": 0,
	},
]

## Brick ramps, top occupied row first (DESIGN 11.5). None uses the player
## cyan.
const SUN := Color(1.000, 0.788, 0.235)
const TANGERINE := Color(1.000, 0.541, 0.239)
const CORAL := Color(1.000, 0.353, 0.373)
const HOTPINK := Color(1.000, 0.180, 0.533)
const MAGENTA := Color(0.839, 0.227, 0.976)
const VIOLET := Color(0.541, 0.361, 1.000)
const MINT := Color(0.302, 1.000, 0.604)
const RAMPS: Array = [
	[SUN, TANGERINE, CORAL, HOTPINK, MAGENTA],
	[HOTPINK, CORAL, TANGERINE, SUN],
	[SUN, CORAL, HOTPINK, VIOLET],
	[CORAL, TANGERINE, SUN, HOTPINK],
	[MINT, VIOLET, MAGENTA, HOTPINK],
	[VIOLET, MAGENTA, HOTPINK, SUN],
]
const CHROME: Color = Color(0.788, 0.808, 0.847)
## Boss body: a deep amber slab in every world (placeholder).
const BOSS: Color = Color(1.000, 0.520, 0.160)
const SWITCH: Color = Color(0.227, 0.251, 0.322)
## Notch accent per boss model (DESIGN 12.6).
const BOSS_ACCENT: Dictionary = {
	"lastebilen": Color(1.000, 0.698, 0.239),
	"krystallhjertet": Color(0.302, 1.000, 0.604),
	"neonnova": Color(0.839, 0.227, 0.976),
}


static func count() -> int:
	return LEVELS.size()


static func world_count() -> int:
	return ceili(float(LEVELS.size()) / float(LEVELS_PER_WORLD))


static func get_level(id: int) -> Dictionary:
	if id > ENDLESS_BASE:
		return NbEndless.level(id - ENDLESS_BASE)
	for lv: Dictionary in LEVELS:
		if int(lv["id"]) == id:
			return lv
	return LEVELS[0]


static func has_level(id: int) -> bool:
	return id >= 1 and id <= LEVELS.size()


static func world_of(id: int) -> int:
	if id > ENDLESS_BASE:
		return int(get_level(id)["world"])
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
		# Rows of only switches or portals take no ramp step.
		var bricks: String = s.replace(".", "").replace("+", "").replace("S", "")
		if bricks.replace("1", "").replace("2", "") == "":
			continue
		out[r] = ramp[mini(step, ramp.size() - 1)]
		step += 1
	return out


## Colour of one cell for thumbnails and the brick MultiMesh.
static func cell_color(code: String, row_color: Color) -> Color:
	if code == "C":
		return CHROME
	if code == "S":
		return SWITCH
	if code == "K" or code == "+":
		return BOSS
	return row_color
