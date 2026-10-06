class_name NbLevels
extends RefCounted

## World 1 "Neonstranda" maps, exactly as GDD 6.4, with the level table
## numbers from GDD 6.3. Rows run from r0 (top, y 340) down; missing rows are
## empty. Codes: G glass, D double, C chrome; lowercase = carrier (drops the
## level's carrier power-up). vanlig_net 0 = unlimited.

const WORLD_1: Array[Dictionary] = [
	{
		"id": 1,
		"name": "Første lys",
		"rows":
		["..........", "..........", "..........", "..........", ".GGGGGGGG.", "..GGGGGG.."],
		"carrier_powerup": "",
		"lett_speed": 520.0,
		"vanlig_speed": 680.0,
		"vanlig_paddle": 280.0,
		"vanlig_net": 0,
	},
	{
		"id": 2,
		"name": "To prikker",
		"rows":
		["..........", "..........", "..........", ".GDDGGDDG.", ".GDDGGDDG.", "..GGGGGG.."],
		"carrier_powerup": "",
		"lett_speed": 520.0,
		"vanlig_speed": 680.0,
		"vanlig_paddle": 280.0,
		"vanlig_net": 0,
	},
	{
		"id": 3,
		"name": "Kometen",
		"rows":
		["..........", "..........", "GGGGGGGGGG", "GGDDGGDDGG", "GGGGGGGGGG", "..g....g.."],
		"carrier_powerup": "komet",
		"lett_speed": 520.0,
		"vanlig_speed": 680.0,
		"vanlig_paddle": 280.0,
		"vanlig_net": 0,
	},
	{
		"id": 4,
		"name": "Krompilarer",
		"rows":
		[
			"..........",
			"..........",
			"GGGGGGGGGG",
			".GGGGGGGG.",
			"..........",
			"C...CC...C",
			"..........",
			"..dD..Dd..",
		],
		"carrier_powerup": "komet",
		"lett_speed": 520.0,
		"vanlig_speed": 680.0,
		"vanlig_paddle": 280.0,
		"vanlig_net": 0,
	},
	{
		"id": 5,
		"name": "Palmesol",
		"rows":
		[
			"..........",
			"..........",
			"..GGGGGG..",
			".GGGGGGGG.",
			"..........",
			".DDDDDDDD.",
			"..........",
			"..GgGGgG..",
		],
		"carrier_powerup": "komet",
		"lett_speed": 520.0,
		"vanlig_speed": 680.0,
		"vanlig_paddle": 280.0,
		"vanlig_net": 0,
	},
]

## World 1 brick ramp, top occupied row first (DESIGN 2c): sun, tangerine,
## coral, hotpink, magenta.
const RAMP_W1: Array[Color] = [
	Color(1.000, 0.788, 0.235),
	Color(1.000, 0.541, 0.239),
	Color(1.000, 0.353, 0.373),
	Color(1.000, 0.180, 0.533),
	Color(0.839, 0.227, 0.976),
]
const CHROME: Color = Color(0.788, 0.808, 0.847)


static func count() -> int:
	return WORLD_1.size()


static func get_level(id: int) -> Dictionary:
	for lv: Dictionary in WORLD_1:
		if int(lv["id"]) == id:
			return lv
	return WORLD_1[0]


static func has_level(id: int) -> bool:
	return id >= 1 and id <= WORLD_1.size()


## Colour of every occupied row: the ramp steps once per occupied row,
## chrome rows included (matches the world 1 mock).
static func row_colors(rows: Array) -> Dictionary:
	var out: Dictionary = {}
	var step: int = 0
	for r: int in rows.size():
		var s: String = rows[r]
		if s.replace(".", "") == "":
			continue
		out[r] = RAMP_W1[mini(step, RAMP_W1.size() - 1)]
		step += 1
	return out


## Colour of one cell for thumbnails and the brick MultiMesh.
static func cell_color(code: String, row_color: Color) -> Color:
	return CHROME if code == "C" else row_color
