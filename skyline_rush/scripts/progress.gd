extends RefCounted
## Persistent progress: coin wallet, upgrade levels, garage (owned + equipped
## vehicles), best score, chosen runner and track. Saved to user://.

const V := preload("res://scripts/vehicles.gd")
const SAVE_PATH := "user://skyline_rush.cfg"
const MAX_LEVEL := 5
const COSTS := [250, 600, 1200, 2400, 4200]

## id, name, what it does, and the value for each level 0..5
const UPGRADES := [
	{"id": "magnet", "name": "COIN MAGNET", "desc": "Magnet power-up lasts longer", "unit": "s", "vals": [8, 10, 12, 14, 17, 20], "color": Color(1.0, 0.4, 0.45)},
	{"id": "shield", "name": "SHIELD", "desc": "Shield power-up lasts longer", "unit": "s", "vals": [8, 10, 12, 14, 17, 20], "color": Color(0.35, 0.9, 1.0)},
	{"id": "springs", "name": "SPRING SHOES", "desc": "Super-jump power-up lasts longer", "unit": "s", "vals": [8, 10, 12, 14, 17, 20], "color": Color(0.4, 1.0, 0.55)},
	{"id": "double", "name": "2X SCORE", "desc": "Double score + coins lasts longer", "unit": "s", "vals": [10, 13, 16, 20, 24, 30], "color": Color(1.0, 0.8, 0.25)},
	{"id": "dash", "name": "DASH  [Q]", "desc": "Shorter dash cooldown", "unit": "s", "vals": [3.0, 2.6, 2.2, 1.9, 1.6, 1.3], "color": Color(1.0, 0.35, 0.75)},
	{"id": "sky", "name": "SKY JUMP  [SPACE x2]", "desc": "Shorter sky-jump cooldown", "unit": "s", "vals": [7.0, 6.0, 5.2, 4.5, 3.8, 3.0], "color": Color(0.4, 1.0, 0.6)},
	{"id": "ride", "name": "RIDE TIME", "desc": "How long a vehicle lasts", "unit": "s", "vals": [20, 25, 30, 36, 43, 52], "color": Color(0.35, 0.8, 1.0)},
	{"id": "armor", "name": "VEHICLE ARMOR", "desc": "Hits your ride can take", "unit": " hits", "vals": [1, 1, 2, 2, 3, 3], "color": Color(1.0, 0.6, 0.3)},
]

var wallet := 0
var best := 0
var char_idx := 1
var track := 0
var levels := {}
var owned := {}     # type -> Array[int]
var equipped := {}  # type -> int


func _init() -> void:
	for u in UPGRADES:
		levels[u["id"]] = 0
	for t in V.TYPES:
		owned[t] = [0]
		equipped[t] = 0


func level(id: String) -> int:
	return int(levels.get(id, 0))


func value(id: String) -> float:
	for u in UPGRADES:
		if u["id"] == id:
			return float(u["vals"][level(id)])
	return 0.0


func upgrade_cost(id: String) -> int:
	var l := level(id)
	return -1 if l >= MAX_LEVEL else COSTS[l]


func buy_upgrade(id: String) -> bool:
	var c := upgrade_cost(id)
	if c < 0 or wallet < c:
		return false
	wallet -= c
	levels[id] = level(id) + 1
	save()
	return true


func is_owned(type: String, i: int) -> bool:
	return i in owned[type]


func buy_vehicle(type: String, i: int) -> bool:
	if is_owned(type, i):
		return true
	var c := V.price(type, i)
	if wallet < c:
		return false
	wallet -= c
	owned[type].append(i)
	equipped[type] = i
	save()
	return true


func equip(type: String, i: int) -> bool:
	if not is_owned(type, i):
		return false
	equipped[type] = i
	save()
	return true


func load_file() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	best = int(cfg.get_value("game", "best", 0))
	char_idx = int(cfg.get_value("game", "char", 1))
	track = int(cfg.get_value("game", "track", 0))
	wallet = int(cfg.get_value("game", "wallet", 0))
	for u in UPGRADES:
		levels[u["id"]] = clampi(int(cfg.get_value("upgrades", u["id"], 0)), 0, MAX_LEVEL)
	for t in V.TYPES:
		var o: Array = cfg.get_value("garage", t + "_owned", [0])
		owned[t] = o.filter(func(x): return int(x) >= 0 and int(x) < V.variant_count(t))
		if not 0 in owned[t]:
			owned[t].append(0)
		equipped[t] = int(cfg.get_value("garage", t + "_equipped", 0))
		if not is_owned(t, equipped[t]):
			equipped[t] = 0


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "best", best)
	cfg.set_value("game", "char", char_idx)
	cfg.set_value("game", "track", track)
	cfg.set_value("game", "wallet", wallet)
	for u in UPGRADES:
		cfg.set_value("upgrades", u["id"], level(u["id"]))
	for t in V.TYPES:
		cfg.set_value("garage", t + "_owned", owned[t])
		cfg.set_value("garage", t + "_equipped", equipped[t])
	cfg.save(SAVE_PATH)
