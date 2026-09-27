extends RefCounted
## Persistent progress: coin wallet, upgrade levels, garage (owned + equipped
## vehicles), best score, chosen runner and track, plus (v9) settings, the
## top-10 high scores, missions, fragments + ability upgrades, the artifact
## collection and cosmetics (trails / auras). Saved to user://.

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

## Permanent ability upgrades, paid with FRAGMENTS (purple shards on the track).
const FRAG_UPGRADES := [
	{"id": "dash_power", "name": "DASH POWER", "desc": "Longer, faster dash", "unit": "s", "vals": [0.45, 0.52, 0.6, 0.68, 0.76, 0.85], "color": Color(1.0, 0.35, 0.75)},
	{"id": "grapple_range", "name": "GRAPPLE RANGE", "desc": "Hook anchors from further away", "unit": " m", "vals": [44, 50, 56, 62, 70, 80], "color": Color(0.4, 1.0, 0.6)},
	{"id": "air_control", "name": "AIR CONTROL", "desc": "Snappier lane changes in the air", "unit": "%", "vals": [100, 115, 130, 145, 160, 180], "color": Color(0.45, 0.75, 1.0)},
	{"id": "style_keep", "name": "STYLE MEMORY", "desc": "Your style chain lasts longer", "unit": "s", "vals": [2.2, 2.6, 3.0, 3.4, 3.8, 4.4], "color": Color(1.0, 0.55, 0.95)},
	{"id": "energy_boost", "name": "ENERGY CELLS", "desc": "Energy pickups also give a shield", "unit": "s", "vals": [0, 1, 2, 3, 4, 5], "color": Color(0.35, 0.95, 1.0)},
	{"id": "start_boost", "name": "HEAD START", "desc": "Start each run with a boost", "unit": " m", "vals": [0, 150, 250, 350, 450, 600], "color": Color(1.0, 0.8, 0.25)},
]
const FRAG_COSTS := [10, 25, 45, 70, 100]

## Cosmetics: [id, name, price in coins, colour A, colour B]
const TRAILS := [
	["neon", "NEON", 0, Color(1.0, 0.4, 0.85), Color(0.3, 0.9, 1.0)],
	["ice", "ICE", 800, Color(0.7, 0.95, 1.0), Color(0.3, 0.55, 1.0)],
	["fire", "FIRE", 1500, Color(1.0, 0.85, 0.2), Color(1.0, 0.2, 0.05)],
	["toxic", "TOXIC", 1500, Color(0.6, 1.0, 0.2), Color(0.1, 0.6, 0.3)],
	["gold", "GOLD RUSH", 3000, Color(1.0, 0.9, 0.5), Color(1.0, 0.6, 0.1)],
	["void", "VOID", 3500, Color(0.6, 0.3, 1.0), Color(0.05, 0.0, 0.2)],
	["rainbow", "RAINBOW", 6000, Color(1.0, 0.3, 0.3), Color(0.3, 0.4, 1.0)],
]
const AURAS := [
	["none", "NONE", 0, Color(0, 0, 0), Color(0, 0, 0)],
	["sparkle", "SPARKLE", 1200, Color(1.0, 0.95, 0.6), Color(1.0, 0.6, 0.9)],
	["storm", "STORM", 2500, Color(0.5, 0.8, 1.0), Color(0.9, 0.95, 1.0)],
	["blaze", "BLAZE", 2500, Color(1.0, 0.5, 0.1), Color(1.0, 0.9, 0.3)],
	["petal", "PETALS", 3000, Color(1.0, 0.7, 0.85), Color(1.0, 0.95, 0.95)],
	["shadow", "SHADOW", 5000, Color(0.3, 0.1, 0.5), Color(0.8, 0.2, 1.0)],
]

## Rare artifacts: one-of-a-kind finds for the permanent collection.
const ARTIFACTS := [
	["crown", "NEON CROWN", Color(1.0, 0.8, 0.25)], ["lantern", "DAWN LANTERN", Color(1.0, 0.5, 0.3)],
	["deck", "GOLDEN DECK", Color(1.0, 0.75, 0.2)], ["umbrella", "RAIN UMBRELLA", Color(0.4, 0.6, 1.0)],
	["coin", "FIRST COIN", Color(1.0, 0.85, 0.4)], ["shell", "HARBOR PEARL", Color(0.9, 0.95, 1.0)],
	["fan", "SAKURA FAN", Color(1.0, 0.6, 0.8)], ["ticket", "GOLDEN TICKET", Color(1.0, 0.9, 0.3)],
	["piston", "TURBO PISTON", Color(1.0, 0.45, 0.15)], ["cassette", "LOST MIXTAPE", Color(0.7, 0.4, 1.0)],
	["sneaker", "SKY SNEAKER", Color(0.3, 0.95, 1.0)], ["gem", "STYLE GEM", Color(1.0, 0.35, 0.75)],
]

## Mission templates: [id, text (%d = target), stat, targets per tier, reward coins, reward fragments, per-run?]
const MISSIONS := [
	["coins_run", "Collect %d coins in one run", "coins", [60, 150, 300, 600], 300, 3, true],
	["dist_run", "Run %d m in one run", "dist", [800, 1500, 3000, 5000], 300, 3, true],
	["score_run", "Score %d in one run", "score", [3000, 10000, 30000, 80000], 400, 4, true],
	["style5", "Reach STYLE x%d", "style", [3, 5, 10, 10], 400, 5, true],
	["walls", "Wall-run %d times", "wall", [5, 15, 30, 60], 250, 3, false],
	["grapples", "Grapple %d times", "grapple", [3, 10, 25, 50], 250, 3, false],
	["high", "Take the HIGH ROUTE %d times", "high", [1, 3, 8, 15], 350, 4, false],
	["under", "Take the UNDERPASS %d times", "under", [1, 3, 8, 15], 250, 2, false],
	["smash", "Smash %d obstacles", "smash", [5, 20, 50, 120], 250, 3, false],
	["frags", "Collect %d fragments", "frag", [5, 20, 50, 120], 300, 0, false],
	["events", "Survive %d random events", "event", [1, 3, 8, 20], 350, 4, false],
	["hunter", "Dodge %d HUNTER strikes", "dodge", [2, 6, 15, 30], 300, 3, false],
	["boss", "Escape the MECH CHASE %d times", "boss", [1, 2, 5, 10], 500, 6, false],
	["keys", "Open %d SHORTCUTS with keys", "shortcut", [1, 2, 5, 10], 400, 4, false],
]

const DEFAULT_SETTINGS := {
	"music": 0.8, "sfx": 0.9, "quality": "high", "ao": true, "gi": true, "auto_perf": true,
	"shake": 1.0, "touch": false, "fps_counter": false,
}

var wallet := 0
var best := 0
var char_idx := 1
var track := 0
var levels := {}
var owned := {}     # type -> Array[int]
var equipped := {}  # type -> int
var fragments := 0
var frag_levels := {}
var artifacts: Array = []          # ids found
var scores: Array = []             # top 10: {score, dist, runner, track, date}
var missions: Array = []           # 3 active: {tpl, tier, progress}
var mission_tiers := {}            # template id -> next tier
var stats := {}                    # lifetime counters
var settings := DEFAULT_SETTINGS.duplicate()
var trails_owned: Array = ["neon"]
var auras_owned: Array = ["none"]
var trail := "neon"
var aura := "none"


func _init() -> void:
	for u in UPGRADES:
		levels[u["id"]] = 0
	for t in V.TYPES:
		owned[t] = [0]
		equipped[t] = 0
	for u in FRAG_UPGRADES:
		frag_levels[u["id"]] = 0
	_fill_missions()


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


# ------------------------------------------------------------ fragments
func frag_level(id: String) -> int:
	return int(frag_levels.get(id, 0))


func frag_value(id: String) -> float:
	for u in FRAG_UPGRADES:
		if u["id"] == id:
			return float(u["vals"][frag_level(id)])
	return 0.0


func frag_cost(id: String) -> int:
	var l := frag_level(id)
	return -1 if l >= MAX_LEVEL else FRAG_COSTS[l]


func buy_frag_upgrade(id: String) -> bool:
	var c := frag_cost(id)
	if c < 0 or fragments < c:
		return false
	fragments -= c
	frag_levels[id] = frag_level(id) + 1
	save()
	return true


# ------------------------------------------------------------ cosmetics
static func cosmetic(list: Array, id: String) -> Array:
	for c in list:
		if c[0] == id:
			return c
	return list[0]


func buy_cosmetic(kind: String, id: String) -> bool:
	var list: Array = TRAILS if kind == "trail" else AURAS
	var owned_list: Array = trails_owned if kind == "trail" else auras_owned
	if not id in owned_list:
		var c: int = cosmetic(list, id)[2]
		if wallet < c:
			return false
		wallet -= c
		owned_list.append(id)
	if kind == "trail":
		trail = id
	else:
		aura = id
	save()
	return true


# ------------------------------------------------------------ high scores
## Adds a run to the top-10 table; returns its rank (1-based) or 0.
func add_score(sc: int, dist: int, runner: String, track: String) -> int:
	if sc <= 0:
		return 0
	var d := Time.get_date_dict_from_system()
	var e := {"score": sc, "dist": dist, "runner": runner, "track": track, "date": "%02d/%02d/%d" % [d["day"], d["month"], d["year"]]}
	scores.append(e)
	scores.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	if scores.size() > 10:
		scores.resize(10)
	var r := scores.find(e)
	return r + 1 if r >= 0 else 0


# ------------------------------------------------------------ missions
func _mission_tpl(id: String) -> Array:
	for m in MISSIONS:
		if m[0] == id:
			return m
	return MISSIONS[0]


func _fill_missions() -> void:
	var active := missions.map(func(m): return m["tpl"])
	var pool := MISSIONS.filter(func(m): return not m[0] in active)
	pool.shuffle()
	while missions.size() < 3 and not pool.is_empty():
		var m: Array = pool.pop_back()
		missions.append({"tpl": m[0], "tier": int(mission_tiers.get(m[0], 0)), "progress": 0})


func mission_info(m: Dictionary) -> Dictionary:
	var t := _mission_tpl(m["tpl"])
	var tier := mini(int(m["tier"]), t[3].size() - 1)
	var target: int = t[3][tier]
	return {"text": String(t[1]) % target, "target": target, "progress": mini(int(m["progress"]), target),
		"coins": int(t[4]) * (tier + 1), "frags": int(t[5]) * (tier + 1), "per_run": t[6], "stat": t[2]}


## Reports progress on a stat: per-run stats pass the run's value (kept as a
## max), lifetime stats pass an increment. Returns missions completed now.
func mission_event(stat: String, value: int, per_run_value := false) -> Array:
	var done := []
	for m in missions:
		var info := mission_info(m)
		if info["stat"] != stat:
			continue
		if per_run_value:
			m["progress"] = maxi(int(m["progress"]), value)
		else:
			m["progress"] = int(m["progress"]) + value
		if int(m["progress"]) >= int(info["target"]):
			done.append(info)
	if not done.is_empty():
		var keep := []
		for m in missions:
			var info := mission_info(m)
			if int(m["progress"]) >= int(info["target"]):
				wallet += info["coins"]
				fragments += info["frags"]
				mission_tiers[m["tpl"]] = int(m["tier"]) + 1
			else:
				keep.append(m)
		missions = keep
		_fill_missions()
		save()
	return done


## Per-run missions only count inside one run: reset their progress.
func start_run() -> void:
	for m in missions:
		if mission_info(m)["per_run"]:
			m["progress"] = 0


func stat_add(k: String, v := 1) -> void:
	stats[k] = int(stats.get(k, 0)) + v


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
	fragments = int(cfg.get_value("v9", "fragments", 0))
	for u in FRAG_UPGRADES:
		frag_levels[u["id"]] = clampi(int(cfg.get_value("frag_upgrades", u["id"], 0)), 0, MAX_LEVEL)
	artifacts = cfg.get_value("v9", "artifacts", [])
	scores = cfg.get_value("v9", "scores", [])
	mission_tiers = cfg.get_value("v9", "mission_tiers", {})
	stats = cfg.get_value("v9", "stats", {})
	var ms: Array = cfg.get_value("v9", "missions", [])
	missions = ms.filter(func(m): return m is Dictionary and m.has("tpl") and MISSIONS.any(func(t): return t[0] == m["tpl"]))
	_fill_missions()
	var st: Dictionary = cfg.get_value("v9", "settings", {})
	for k in DEFAULT_SETTINGS:
		if st.has(k):
			settings[k] = st[k]
	trails_owned = cfg.get_value("v9", "trails_owned", ["neon"])
	auras_owned = cfg.get_value("v9", "auras_owned", ["none"])
	trail = String(cfg.get_value("v9", "trail", "neon"))
	aura = String(cfg.get_value("v9", "aura", "none"))
	if not trail in trails_owned:
		trail = "neon"
	if not aura in auras_owned:
		aura = "none"


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
	cfg.set_value("v9", "fragments", fragments)
	for u in FRAG_UPGRADES:
		cfg.set_value("frag_upgrades", u["id"], frag_level(u["id"]))
	cfg.set_value("v9", "artifacts", artifacts)
	cfg.set_value("v9", "scores", scores)
	cfg.set_value("v9", "missions", missions)
	cfg.set_value("v9", "mission_tiers", mission_tiers)
	cfg.set_value("v9", "stats", stats)
	cfg.set_value("v9", "settings", settings)
	cfg.set_value("v9", "trails_owned", trails_owned)
	cfg.set_value("v9", "auras_owned", auras_owned)
	cfg.set_value("v9", "trail", trail)
	cfg.set_value("v9", "aura", aura)
	cfg.save(SAVE_PATH)
