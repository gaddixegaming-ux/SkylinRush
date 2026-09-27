extends RefCounted
## Track / town themes. Each theme dresses the road (tile style), the sides
## (buildings + props), the space over the road and the distant skyline.
## 0 is the original sky-road; 1-7 are the towns.

const NAMES := [
	"SKY ROADS", "LANTERN FESTIVAL", "SKATE PARK", "NEON RAIN ALLEY",
	"NEON MARKET", "HOVER HARBOR", "SAKURA HEIGHTS", "CANDY CARNIVAL", "TURBO HIGHWAY",
]
const ACCENT := [
	Color(1.0, 0.3, 0.75), Color(1.0, 0.32, 0.3), Color(0.3, 0.7, 1.0), Color(0.85, 0.3, 1.0),
	Color(0.3, 0.95, 1.0), Color(0.4, 1.0, 0.8), Color(1.0, 0.55, 0.78), Color(1.0, 0.75, 0.3), Color(1.0, 0.5, 0.15),
]
const STREET := {
	1: {"deck": Color(0.52, 0.48, 0.64), "deck2": Color(0.56, 0.51, 0.67), "dash": Color(1.0, 0.9, 0.7), "dash_e": 0.4,
		"curb": Color(0.97, 0.86, 0.82), "walk": Color(0.96, 0.8, 0.72), "ground": Color(0.92, 0.78, 0.66), "rough": 0.8, "metal": 0.0},
	2: {"deck": Color(0.8, 0.72, 0.6), "deck2": Color(0.77, 0.7, 0.58), "dash": Color(0.72, 0.45, 0.95), "dash_e": 0.3,
		"curb": Color(0.7, 0.66, 0.6), "walk": Color(0.78, 0.72, 0.6), "ground": Color(0.62, 0.72, 0.5), "rough": 0.9, "metal": 0.0},
	3: {"deck": Color(0.1, 0.1, 0.17), "deck2": Color(0.12, 0.11, 0.19), "dash": Color(0.5, 0.6, 1.0), "dash_e": 1.8,
		"curb": Color(0.2, 0.2, 0.28), "walk": Color(0.15, 0.14, 0.21), "ground": Color(0.07, 0.07, 0.12), "rough": 0.05, "metal": 0.7},
	4: {"deck": Color(0.27, 0.26, 0.33), "deck2": Color(0.29, 0.28, 0.35), "dash": Color(1.0, 1.0, 1.0), "dash_e": 0.6,
		"curb": Color(0.86, 0.8, 0.92), "walk": Color(0.55, 0.5, 0.63), "ground": Color(0.38, 0.34, 0.46), "rough": 0.55, "metal": 0.1},
	6: {"deck": Color(0.74, 0.7, 0.72), "deck2": Color(0.7, 0.66, 0.69), "dash": Color(1.0, 0.75, 0.86), "dash_e": 0.35,
		"curb": Color(0.42, 0.6, 0.38), "walk": Color(0.82, 0.77, 0.73), "ground": Color(0.55, 0.72, 0.45), "rough": 0.85, "metal": 0.0},
	7: {"deck": Color(0.8, 0.54, 0.4), "deck2": Color(0.72, 0.47, 0.35), "dash": Color(1.0, 0.9, 0.5), "dash_e": 1.2,
		"curb": Color(0.95, 0.3, 0.36), "walk": Color(0.96, 0.86, 0.76), "ground": Color(0.78, 0.55, 0.66), "rough": 0.7, "metal": 0.0},
}
const PINK := Color(1.0, 0.3, 0.75)
const CYAN := Color(0.3, 0.9, 1.0)
const GOLD := Color(1.0, 0.75, 0.2)
const TILE := 4.0

var w  # the world node


func _init(world) -> void:
	w = world


func is_sky(t: int) -> bool:
	return t == 0 or t == 5


# ============================================================ helpers
func node(pos: Vector3, half: float) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.set_meta("half", half)
	w.scenery.add_child(n)
	return n


func M(albedo: Color, emission := Color(0, 0, 0), energy := 0.0, rough := 0.7, metal := 0.0, rim := 0.15, pulse := 0.0) -> ShaderMaterial:
	return w.mat(albedo, emission, energy, rough, metal, rim, pulse)


func G(c: Color, energy := 2.5, pulse := 0.0) -> ShaderMaterial:
	return w.mat(c, c, energy, 0.4, 0.0, 0.0, pulse)


func box(p: Node3D, size: Vector3, pos: Vector3, m: Material, shadow := false, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = w._box(p, size, pos, m, shadow)
	mi.rotation = rot
	return mi


func cyl(p: Node3D, r: float, h: float, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	return w._cyl(p, r, h, pos, m, rot, false)


func sph(p: Node3D, r: float, pos: Vector3, m: Material, sq := 1.0) -> MeshInstance3D:
	var mi: MeshInstance3D = w._sphere(p, r, pos, m, false)
	mi.scale.y *= sq
	return mi


func cone(p: Node3D, r: float, h: float, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = w._mi(p, w._mesh("cone"), pos, m, false)
	mi.rotation = rot
	mi.scale = Vector3(r, h, r)
	return mi


## Real point lights are expensive: at most MAX_LIGHTS in the scenery at once
## (the emissive glow still shows everywhere).
const MAX_LIGHTS := 10


func light(p: Node3D, pos: Vector3, c: Color, energy := 2.0, rng := 7.0) -> void:
	if w.lite:
		return  # mobile: emissive glow only, no real lights
	if w.get_tree().get_nodes_in_group("scene_light").size() >= MAX_LIGHTS:
		return
	var l := OmniLight3D.new()
	l.add_to_group("scene_light")
	l.position = pos
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.5
	l.shadow_enabled = false
	p.add_child(l)


func pick(a: Array):
	return a[randi() % a.size()]


# ============================================================ road tiles
func build_tile(n: Node3D, t: int, idx: int) -> void:
	if t == 0:
		_tile_sky(n, idx)
		return
	if t == 5:
		_tile_harbor(n, idx)
		return
	if t == 8:
		_highway_tile(n, idx)
		return
	var s: Dictionary = STREET[t]
	var deck: Color = s["deck"] if idx % 2 == 0 else s["deck2"]
	box(n, Vector3(8.4, 0.5, TILE), Vector3(0, -0.25, 0), M(deck, Color.BLACK, 0.0, s["rough"], s["metal"], 0.03), false)
	_ground(n, s["ground"])
	var curb := M(s["curb"], Color.BLACK, 0.0, 0.7)
	var walk := M(s["walk"], Color.BLACK, 0.0, s["rough"] + 0.1, s["metal"] * 0.5)
	for sd in [-1.0, 1.0]:
		box(n, Vector3(0.35, 0.28, TILE), Vector3(sd * 4.37, 0.03, 0), curb)
		box(n, Vector3(3.2, 0.26, TILE), Vector3(sd * 6.1, 0.0, 0), walk)
	if t in [1, 2, 4, 6, 7]:
		grass_verge(n, t)
	if idx % 2 == 0:
		var dm: Material = w.mat(s["dash"], s["dash"], s["dash_e"], 0.5)
		box(n, Vector3(0.12, 0.03, 2.2), Vector3(-1.25, 0.015, 0), dm)
		box(n, Vector3(0.12, 0.03, 2.2), Vector3(1.25, 0.015, 0), dm)
	match t:
		1:
			if idx % 3 == 0:
				box(n, Vector3(3.2, 0.02, 0.12), Vector3(6.1, 0.14, 1.0), M(Color(0.85, 0.65, 0.6)))
				box(n, Vector3(3.2, 0.02, 0.12), Vector3(-6.1, 0.14, 1.0), M(Color(0.85, 0.65, 0.6)))
		2:
			if randf() < 0.18:
				var c: Color = pick([Color(1, 0.45, 0.75), Color(0.4, 0.75, 1), Color(1, 0.85, 0.3), Color(0.6, 0.9, 0.5)])
				var d := cyl(n, randf_range(0.6, 1.4), 0.02, Vector3(randf_range(-3, 3), 0.012, randf_range(-1, 1)), M(c, Color.BLACK, 0, 0.9))
				d.scale.x *= randf_range(1.0, 2.2)
		3:
			var joint := M(Color(0.05, 0.05, 0.09), Color.BLACK, 0.0, 0.3)
			box(n, Vector3(8.4, 0.01, 0.06), Vector3(0, 0.005, 1.0), joint)
			box(n, Vector3(8.4, 0.01, 0.06), Vector3(0, 0.005, -1.0), joint)
		4:
			box(n, Vector3(0.55, 0.02, TILE), Vector3(-3.9, 0.012, 0), G(PINK, 2.2, 0.6))
			box(n, Vector3(0.06, 0.03, TILE), Vector3(-3.58, 0.015, 0), G(Color(1, 0.9, 0.95), 1.5))
		6:
			for sd in [-1.0, 1.0]:
				box(n, Vector3(0.5, 0.05, TILE), Vector3(sd * 4.0, 0.01, 0), M(Color(0.45, 0.62, 0.35), Color.BLACK, 0, 0.95))
			for k in 3:
				box(n, Vector3(0.12, 0.01, 0.08), Vector3(randf_range(-3.5, 3.5), 0.006, randf_range(-1.8, 1.8)), M(Color(1, 0.75, 0.85)), false, Vector3(0, randf() * TAU, 0))
		7:
			var plank := M(Color(0.45, 0.28, 0.22), Color.BLACK, 0.0, 0.9)
			box(n, Vector3(8.4, 0.01, 0.07), Vector3(0, 0.005, 0.0), plank)
			var bulb: Color = [Color(1, 0.85, 0.4), Color(1, 0.4, 0.5), Color(0.5, 0.9, 1)][idx % 3]
			for sd in [-1.0, 1.0]:
				sph(n, 0.13, Vector3(sd * 4.37, 0.25, 0), G(bulb, 4.0, 1.0))


## Land on both sides of the road, flush with the base of the buildings (y = 0)
## so nothing beside the road floats.
func _ground(n: Node3D, c: Color) -> void:
	var gm := M(c, Color.BLACK, 0.0, 0.95, 0.0, 0.0)
	for sd in [-1.0, 1.0]:
		box(n, Vector3(76.0, 0.6, TILE), Vector3(sd * 42.2, -0.32, 0), gm)


func _tile_sky(n: Node3D, idx: int) -> void:
	var deck_c := Color(0.2, 0.12, 0.33) if idx % 2 == 0 else Color(0.24, 0.15, 0.38)
	box(n, Vector3(8.4, 0.5, TILE), Vector3(0, -0.25, 0), M(deck_c, Color.BLACK, 0.0, 0.35, 0.35, 0.05), true)
	box(n, Vector3(6.4, 0.9, TILE), Vector3(0, -0.95, 0), M(Color(0.34, 0.24, 0.5), Color.BLACK, 0.0, 0.5, 0.4, 0.2))
	var rail := G(PINK, 2.5, 0.8)
	box(n, Vector3(0.3, 0.35, TILE), Vector3(-4.25, 0.12, 0), rail)
	box(n, Vector3(0.3, 0.35, TILE), Vector3(4.25, 0.12, 0), rail)
	if idx % 2 == 0:
		var dash := G(CYAN, 1.6)
		box(n, Vector3(0.12, 0.03, 2.2), Vector3(-1.25, 0.015, 0), dash)
		box(n, Vector3(0.12, 0.03, 2.2), Vector3(1.25, 0.015, 0), dash)
	if idx % 4 == 0:
		var side_l := G(CYAN, 3.0, 1.0)
		box(n, Vector3(0.05, 0.25, 1.2), Vector3(-3.21, -0.95, 0), side_l)
		box(n, Vector3(0.05, 0.25, 1.2), Vector3(3.21, -0.95, 0), side_l)


func _tile_harbor(n: Node3D, idx: int) -> void:
	var deck := Color(0.93, 0.91, 0.96) if idx % 2 == 0 else Color(0.9, 0.88, 0.94)
	box(n, Vector3(8.4, 0.5, TILE), Vector3(0, -0.25, 0), M(deck, Color.BLACK, 0.0, 0.25, 0.2, 0.25), true)
	box(n, Vector3(7.0, 0.7, TILE), Vector3(0, -0.8, 0), M(Color(0.75, 0.78, 0.9), Color.BLACK, 0.0, 0.3, 0.5, 0.2))
	var cols := [Color(0.3, 0.95, 1.0), Color(0.4, 1.0, 0.6), Color(1.0, 0.45, 0.8)]
	for i in 3:
		box(n, Vector3(0.14, 0.06, TILE), Vector3(-3.9 + i * 0.2, 0.03, 0), G(cols[i], 2.5, 0.8))
		box(n, Vector3(0.14, 0.06, TILE), Vector3(3.9 - i * 0.2, 0.03, 0), G(cols[i], 2.5, 0.8))
	box(n, Vector3(0.35, 0.4, TILE), Vector3(-4.3, 0.15, 0), M(Color(0.95, 0.95, 1.0), Color.BLACK, 0.0, 0.2, 0.3, 0.3))
	box(n, Vector3(0.35, 0.4, TILE), Vector3(4.3, 0.15, 0), M(Color(0.95, 0.95, 1.0), Color.BLACK, 0.0, 0.2, 0.3, 0.3))
	if idx % 2 == 0:
		box(n, Vector3(0.12, 0.03, 2.2), Vector3(-1.25, 0.015, 0), G(Color(0.4, 0.8, 1.0), 1.4))
		box(n, Vector3(0.12, 0.03, 2.2), Vector3(1.25, 0.015, 0), G(Color(0.4, 0.8, 1.0), 1.4))
	if idx % 3 == 0:
		cone(n, 0.5, 1.0, Vector3(-2.5, -1.5, 0), G(CYAN, 3.0, 1.0), Vector3(PI, 0, 0))
		cone(n, 0.5, 1.0, Vector3(2.5, -1.5, 0), G(CYAN, 3.0, 1.0), Vector3(PI, 0, 0))


# ============================================================ side dressing
## Spawns something at z on one side, returns spacing to the next one.
func side(z: float, s: float, t: int) -> float:
	if t in [1, 4, 6] and randf() < 0.07:
		return plaza(z, s, t)
	match t:
		1: return _festival_side(z, s)
		2: return _skate_side(z, s)
		3: return _rain_side(z, s)
		4: return _market_side(z, s)
		5: return _harbor_side(z, s)
		6: return _sakura_side(z, s)
		7: return _carnival_side(z, s)
		8: return _highway_side(z, s)
	return 30.0


func overhead(z: float, t: int) -> float:
	match t:
		1: _lantern_string(z, 6.8, [Color(1.0, 0.32, 0.3), Color(1.0, 0.45, 0.35)], false)
		2: _pennants(z)
		3: _lantern_string(z, 6.2, [Color(1.0, 0.25, 0.3), Color(1.0, 0.5, 0.2)], true)
		4: _power_lines(z)
		5: _light_ring(z)
		6: _torii(z, 1.0)
		7: _bulb_string(z)
		8: return _highway_over(z)
		0: return sky_overhead(z)
		_: return 40.0
	match t:
		1: return randf_range(9.0, 13.0)
		2: return randf_range(22.0, 30.0)
		3: return randf_range(10.0, 14.0)
		4: return randf_range(14.0, 18.0)
		5: return randf_range(28.0, 40.0)
		6: return randf_range(30.0, 40.0)
	return randf_range(9.0, 12.0)


func far(z: float, t: int) -> float:
	var s := -1.0 if randf() < 0.5 else 1.0
	if not w.lite:
		far_extras(z - randf_range(0.0, 10.0), t)
	match t:
		1: _festival_far(z, s)
		2: _skate_far(z, s)
		3: _rain_far(z, s)
		4: _market_far(z, s)
		5: _harbor_far(z, s)
		6: _sakura_far(z, s)
		7: _carnival_far(z, s)
		8: _highway_far(z, s)
		_: return 60.0
	return randf_range(22.0, 40.0)


## Big welcome arch where one theme hands over to the next.
func gate(z: float, t: int) -> void:
	var n := node(Vector3(0, 0, z), 2.0)
	var a: Color = ACCENT[t]
	if t == 6:
		_torii(z, 1.5)
		return
	var body := M(Color(0.2, 0.16, 0.28), Color.BLACK, 0.0, 0.4, 0.5, 0.3)
	for sd in [-1.0, 1.0]:
		box(n, Vector3(1.2, 11.0, 1.2), Vector3(sd * 6.2, 5.5, 0), body, true)
		box(n, Vector3(1.3, 0.25, 1.3), Vector3(sd * 6.2, 3.0, 0), G(a, 3.0, 1.0))
		box(n, Vector3(1.3, 0.25, 1.3), Vector3(sd * 6.2, 7.0, 0), G(a, 3.0, 1.0))
		w._beam(n, Vector3(sd * 6.2, 11.0, 0), 0.6, 30.0, a, 0.3)
	box(n, Vector3(14.0, 1.6, 1.4), Vector3(0, 10.6, 0), body, true)
	box(n, Vector3(13.0, 0.9, 0.05), Vector3(0, 10.6, 0.72), G(a, 3.5, 1.2))
	for i in 7:
		sph(n, 0.25, Vector3(-4.5 + i * 1.5, 9.6, 0.6), G(Color(1, 1, 1), 4.0, 1.0))


# ---------------------------------------------------------------- buildings
func _shophouse(z: float, s: float, o: Dictionary) -> float:
	var q := {"colors": o["colors"], "night": o.get("night", false), "roof": o.get("roof", "flat"),
		"floors": [o.get("fmin", 2), o.get("fmax", 4)], "lanterns": o.get("lanterns", false), "ac": o.get("ac", false),
		"neon": o.get("night", false)}
	if o.has("roof_c"):
		q["roof_c"] = o["roof_c"]
	if o.has("signs"):
		q["signs"] = o["signs"]
	if o.get("night", false):
		q["words"] = ["RAMEN", "BAR", "HOTEL", "NOODLES", "KARAOKE", "TEA", "SUSHI", "ARCADE"]
		q["awnings"] = [[Color(0.2, 0.15, 0.25), Color(0.35, 0.2, 0.4)], [Color(0.5, 0.1, 0.2), Color(0.2, 0.1, 0.15)]]
	return facade_building(z, s, q)


## Street NPCs were removed from the game; kept as a no-op so callers stay simple.
func _person(_p: Node3D, _pos: Vector3, _facing: float) -> void:
	return


func _lamp(p: Node3D, pos: Vector3, s: float, lamp_c: Color, pole_c: Color, lit := false) -> void:
	var pole := M(pole_c, Color.BLACK, 0.0, 0.4, 0.6)
	cyl(p, 0.1, 5.2, pos + Vector3(0, 2.6, 0), pole)
	box(p, Vector3(1.6, 0.1, 0.1), pos + Vector3(-s * 0.7, 5.1, 0), pole, false, Vector3(0, 0, s * 0.25))
	sph(p, 0.28, pos + Vector3(-s * 1.4, 4.85, 0), G(lamp_c, 3.0 if lit else 1.0), 0.7)
	if lit:
		light(p, pos + Vector3(-s * 1.4, 4.3, 0), lamp_c, 2.5, 9.0)


func _car_decor(p: Node3D, pos: Vector3) -> void:
	# a parked car from the vehicle kit (random type + livery, no hazard rim)
	var CM := preload("res://scripts/car_models.gd")
	var type: String = ["taxi", "sedan", "hatch", "taxi"][randi() % 4]
	var r: Array = w.car_instance(p, pos, type, CM.random_livery(type), false, randf_range(-0.2, 0.2))
	if r[0] == null:
		box(p, Vector3(1.7, 0.6, 3.8), pos + Vector3(0, 0.55, 0), M(Color(0.9, 0.9, 0.95)), true)


# ---------------------------------------------------------------- 1 lantern festival
func _festival_side(z: float, s: float) -> float:
	var r := randf()
	if r < 0.72:
		var sp := _shophouse(z, s, {"colors": [Color(1.0, 0.72, 0.78), Color(0.78, 0.72, 1.0), Color(0.65, 0.9, 0.85), Color(1.0, 0.82, 0.62), Color(0.62, 0.8, 1.0)],
			"sign": pick(["vertical", "panel"]), "lanterns": randf() < 0.5, "fmin": 2, "fmax": 4, "signs": [Color(1, 0.35, 0.35), Color(0.3, 0.75, 0.6), Color(1, 0.8, 0.3)]})
		return sp
	var n := node(Vector3(s * 6.3, 0.12, z), 3.0)
	if r < 0.86:
		# market stall with umbrella
		var uc: Color = pick([Color(1, 0.4, 0.45), Color(0.4, 0.75, 0.6), Color(1, 0.8, 0.4)])
		cyl(n, 0.05, 2.4, Vector3(0, 1.2, 0), M(Color(0.3, 0.3, 0.3)))
		cone(n, 1.4, 0.7, Vector3(0, 2.6, 0), M(uc, uc, 0.1, 0.8))
		box(n, Vector3(1.4, 0.8, 1.6), Vector3(0, 0.4, 0), M(Color(0.75, 0.55, 0.4)))
		for k in 4:
			sph(n, 0.14, Vector3(randf_range(-0.5, 0.5), 0.9, randf_range(-0.6, 0.6)), M(pick([Color(1, 0.4, 0.2), Color(1, 0.8, 0.2), Color(0.5, 0.9, 0.3)])))
	else:
		_lamp(n, Vector3(s * -1.5, 0, 0), s, Color(1, 0.9, 0.7), Color(0.25, 0.4, 0.6))
		_car_decor(n, Vector3(s * -1.2, 0, -3.0))
	return randf_range(3.0, 6.0)


func _lantern_string(z: float, y: float, cols: Array, night: bool) -> void:
	var n := node(Vector3(0, 0, z), 1.0)
	var wire := M(Color(0.2, 0.2, 0.25))
	var span := 15.0
	var count := 9
	var zz := randf_range(-1.5, 1.5)
	for i in count:
		var t := float(i) / (count - 1)
		var x := -span * 0.5 + span * t
		var yy := y - 1.4 * sin(t * PI)
		var c: Color = cols[i % cols.size()]
		sph(n, 0.32, Vector3(x, yy - 0.45, zz * t), G(c, 1.6 if night else 1.0, 0.6), 1.3)
		cyl(n, 0.18, 0.08, Vector3(x, yy - 0.02, zz * t), M(Color(0.95, 0.75, 0.2)))
		box(n, Vector3(0.04, 0.3, 0.04), Vector3(x, yy - 0.95, zz * t), M(Color(0.95, 0.75, 0.2)))
		if i < count - 1:
			var t2 := float(i + 1) / (count - 1)
			var a := Vector3(x, yy, zz * t)
			var b := Vector3(-span * 0.5 + span * t2, y - 1.4 * sin(t2 * PI), zz * t2)
			var seg := box(n, Vector3((b - a).length(), 0.03, 0.03), (a + b) * 0.5, wire)
			seg.rotation.z = atan2(b.y - a.y, b.x - a.x)
	if night and randf() < 0.5:
		light(n, Vector3(0, y - 1.8, 0), cols[0], 2.0, 9.0)


func _festival_far(z: float, s: float) -> void:
	var n := node(Vector3(s * randf_range(22.0, 60.0), 0, z), 10.0)
	if randf() < 0.14:
		# observation needle tower
		var m := M(Color(0.85, 0.85, 0.95), Color.BLACK, 0, 0.4, 0.2, 0.3)
		cyl(n, 1.6, 50.0, Vector3(0, 25.0, 0), m)
		cyl(n, 4.0, 3.0, Vector3(0, 44.0, 0), m)
		cyl(n, 4.2, 0.4, Vector3(0, 45.0, 0), G(Color(0.6, 0.85, 1.0), 1.5))
		cyl(n, 0.4, 16.0, Vector3(0, 58.0, 0), m)
		return
	for k in randi_range(1, 3):
		var h := randf_range(14.0, 40.0)
		var wd := randf_range(6.0, 11.0)
		var c: Color = pick([Color(0.75, 0.82, 1.0), Color(0.95, 0.8, 0.9), Color(0.85, 0.95, 1.0), Color(1.0, 0.9, 0.75)])
		var off := Vector3(randf_range(-8, 8), 0, randf_range(-10, 10))
		box(n, Vector3(wd, h, wd), off + Vector3(0, h * 0.5, 0), M(c, Color.BLACK, 0, 0.5, 0.1, 0.35))
		for f in int(h / 4.0):
			box(n, Vector3(wd + 0.05, 0.4, wd + 0.05), off + Vector3(0, f * 4.0 + 2.5, 0), M(c.darkened(0.15), Color(0.6, 0.8, 1.0), 0.15, 0.2, 0.4))


# ---------------------------------------------------------------- 2 skate park
func _skate_side(z: float, s: float) -> float:
	if w.qpipe_near(z, s):
		# the quarter-pipe fills the edge: only trees further out
		var nq := node(Vector3(s * randf_range(14.0, 20.0), 0, z), 4.0)
		gtree(nq, Vector3.ZERO, _tree_for(2), randf_range(5.0, 8.0))
		return randf_range(6.0, 10.0)
	var r := randf()
	if r < 0.22:
		_ramp(z, s)
		return randf_range(10.0, 14.0)
	if r < 0.52:
		return skate_extra(z, s)
	if r < 0.72:
		var n := node(Vector3(s * randf_range(9.0, 16.0), 0, z), 4.0)
		gtree(n, Vector3.ZERO, _tree_for(2), randf_range(5.0, 8.0))
		if randf() < 0.5:
			gtree(n, Vector3(s * randf_range(2.5, 5.0), 0, randf_range(-2, 2)), _tree_for(2), randf_range(4.0, 7.0))
		return randf_range(4.0, 8.0)
	if r < 0.85:
		var n2 := node(Vector3(s * 7.4, 0, z - 3.0), 3.5)
		box(n2, Vector3(0.4, 1.6, 7.0), Vector3(0, 0.8, 0), M(Color(0.8, 0.78, 0.75)), true)
		for k in 5:
			var c: Color = pick([Color(1, 0.4, 0.7), Color(0.3, 0.8, 0.9), Color(1, 0.85, 0.3), Color(0.5, 0.9, 0.4), Color(0.6, 0.4, 1.0)])
			var d := cyl(n2, randf_range(0.3, 0.8), 0.05, Vector3(-s * 0.21, randf_range(0.4, 1.3), randf_range(-3, 3)), M(c, c, 0.15, 0.8), Vector3(0, 0, PI / 2))
			d.scale.z *= randf_range(1.0, 2.5)
		return 8.0
	var n3 := node(Vector3(s * 7.0, 0, z), 2.0)
	_lamp(n3, Vector3.ZERO, s, Color(1, 0.95, 0.8), Color(0.3, 0.3, 0.35))
	cyl(n3, 0.35, 0.9, Vector3(0.5, 0.45, 1.0), M(Color(0.35, 0.45, 0.4), Color.BLACK, 0, 0.5, 0.5))
	return randf_range(5.0, 8.0)


func _ramp(z: float, s: float) -> void:
	# quarter-pipe rising away from the road, graffiti side panel, deck + railing
	var n := node(Vector3(s * randf_range(8.5, 11.0), 0, z - 4.0), 5.0)
	var rl := randf_range(6.0, 9.0)
	var rr := 3.6
	var skin: Color = pick([Color(0.3, 0.55, 0.9), Color(0.55, 0.4, 0.85), Color(0.25, 0.7, 0.75)])
	var surf := M(skin, Color.BLACK, 0, 0.6, 0.0, 0.25)
	var segs := 7
	for i in segs:
		var a := (float(i) + 0.5) / segs * (PI * 0.5)
		var pos := Vector3(s * rr * sin(a), rr - rr * cos(a), 0)
		box(n, Vector3(rr * PI * 0.5 / segs + 0.08, 0.18, rl), pos, surf, true, Vector3(0, 0, s * a))
	box(n, Vector3(0.3, rr, rl), Vector3(s * (rr + 0.15), rr * 0.5, 0), M(skin.darkened(0.35)), true)
	var panel := M(Color(0.95, 0.9, 0.8))
	box(n, Vector3(rr, rr * 0.9, 0.2), Vector3(s * rr * 0.62, rr * 0.45, rl * 0.5), panel, true)
	for k in 6:
		var c: Color = pick([Color(1, 0.4, 0.7), Color(0.3, 0.8, 0.9), Color(1, 0.85, 0.3), Color(0.5, 0.9, 0.4), Color(0.6, 0.4, 1.0)])
		var d := cyl(n, randf_range(0.35, 0.8), 0.05, Vector3(s * randf_range(0.8, rr), randf_range(0.5, rr * 0.8), rl * 0.5 + 0.12), M(c, c, 0.2, 0.7), Vector3(PI / 2, 0, 0))
		d.scale.x *= randf_range(1.0, 1.8)
	box(n, Vector3(1.6, 0.15, rl), Vector3(s * (rr + 0.8), rr, 0), M(Color(0.6, 0.45, 0.3)))
	var rail := M(Color(0.2, 0.2, 0.22), Color.BLACK, 0, 0.4, 0.6)
	for k in 3:
		box(n, Vector3(0.08, 1.2, 0.08), Vector3(s * (rr + 1.5), rr + 0.6, -rl * 0.5 + k * rl * 0.5), rail)
	box(n, Vector3(0.06, 0.06, rl), Vector3(s * (rr + 1.5), rr + 1.2, 0), rail)
	box(n, Vector3(0.12, 0.12, rl), Vector3(0, 0.06, 0), M(Color(0.85, 0.85, 0.9), Color.BLACK, 0, 0.3, 0.8))


func _tree(p: Node3D, pos: Vector3, sc: float, cols: Array) -> void:
	cyl(p, 0.3 * sc, 2.5 * sc, pos + Vector3(0, 1.25 * sc, 0), M(Color(0.45, 0.32, 0.22)))
	for k in 5:
		var c: Color = pick(cols)
		sph(p, randf_range(1.1, 1.6) * sc, pos + Vector3(randf_range(-1, 1) * sc, (2.8 + randf_range(0, 1.2)) * sc, randf_range(-1, 1) * sc), M(c, Color.BLACK, 0, 0.9, 0, 0.35))


func _pennants(z: float) -> void:
	var n := node(Vector3(0, 0, z), 1.0)
	for sd in [-1.0, 1.0]:
		cyl(n, 0.1, 7.0, Vector3(sd * 7.5, 3.5, 0), M(Color(0.3, 0.3, 0.35)))
	for i in 14:
		var t := float(i) / 13.0
		var x := -7.5 + 15.0 * t
		var y := 6.8 - 1.2 * sin(t * PI)
		var c: Color = [Color(1, 0.4, 0.6), Color(0.3, 0.75, 1), Color(1, 0.85, 0.3), Color(0.5, 0.9, 0.5)][i % 4]
		cone(n, 0.3, 0.7, Vector3(x, y - 0.35, 0), M(c, c, 0.2, 0.8), Vector3(PI, 0, 0))


func _skate_far(z: float, s: float) -> void:
	var n := node(Vector3(s * randf_range(24.0, 50.0), 0, z), 14.0)
	if randf() < 0.55:
		var m := M(Color(1.0, 0.85, 0.25), Color(1.0, 0.7, 0.1), 0.3, 0.4, 0.3, 0.3)
		var t: MeshInstance3D = w._torus(n, 9.0, 9.6, Vector3(0, 0, 0), m, Vector3(PI / 2, randf_range(-0.6, 0.6), 0))
		t.scale = Vector3(1.4, 1.0, 1.0)
		for k in 4:
			cyl(n, 0.25, 9.0, Vector3(-9.0 + k * 6.0, 4.5, 0), M(Color(0.95, 0.85, 0.5)))
	else:
		sph(n, randf_range(8.0, 14.0), Vector3(0, -2.0, 0), M(Color(0.45, 0.72, 0.4), Color.BLACK, 0, 0.95, 0, 0.3), 0.45)
		gtree(n, Vector3(randf_range(-4, 4), 2.0, 0), _tree_for(2), 9.0)


# ---------------------------------------------------------------- 3 neon rain alley
func _rain_side(z: float, s: float) -> float:
	if randf() < 0.82:
		return _shophouse(z, s, {"colors": [Color(0.2, 0.16, 0.22), Color(0.26, 0.2, 0.24), Color(0.18, 0.18, 0.26)],
			"night": true, "roof": "tile", "roof_c": Color(0.1, 0.1, 0.14), "sign": pick(["vertical", "vertical", "panel"]),
			"lanterns": true, "plants": true, "awning": false, "fmin": 2, "fmax": 3,
			"signs": [Color(1.0, 0.25, 0.7), Color(0.35, 0.55, 1.0), Color(0.75, 0.35, 1.0), Color(1.0, 0.45, 0.35)]})
	var n := node(Vector3(s * 7.0, 0.12, z), 2.0)
	for k in 6:
		var hgt := randf_range(3.0, 5.5)
		cyl(n, 0.06, hgt, Vector3(randf_range(-0.8, 0.8), hgt * 0.5, randf_range(-1, 1)), M(Color(0.2, 0.45, 0.3)))
	var ring_c: Color = pick([Color(1, 0.3, 0.7), Color(0.4, 0.6, 1)])
	w._torus(n, 0.7, 0.85, Vector3(-s * 0.8, 3.2, 0), G(ring_c, 3.5, 0.5), Vector3(0, PI / 2, 0))
	light(n, Vector3(-s * 1.5, 3.0, 0), ring_c, 2.0, 7.0)
	return randf_range(3.0, 5.0)


func _rain_far(z: float, s: float) -> void:
	var n := node(Vector3(s * randf_range(30.0, 70.0), 0, z), 20.0)
	var rock := M(Color(0.1, 0.13, 0.22), Color.BLACK, 0, 0.9, 0, 0.25)
	var hgt := randf_range(35.0, 70.0)
	cone(n, randf_range(12.0, 20.0), hgt, Vector3(0, hgt * 0.5 - 5.0, 0), rock)
	if randf() < 0.45:
		_pagoda(n, Vector3(0, hgt * 0.55, 0), 1.0, Color(0.9, 0.3, 1.0), true)


func _pagoda(p: Node3D, pos: Vector3, sc: float, glow: Color, night: bool) -> void:
	var body := M(Color(0.15, 0.12, 0.18), Color.BLACK, 0, 0.6)
	var roof := M(Color(0.12, 0.14, 0.2), Color.BLACK, 0, 0.5, 0.3)
	for i in 4:
		var wdt := (7.0 - i * 1.3) * sc
		var y := pos.y + i * 3.2 * sc
		box(p, Vector3(wdt * 0.7, 2.6 * sc, wdt * 0.7), Vector3(pos.x, y + 1.3 * sc, pos.z), body)
		box(p, Vector3(wdt * 0.66, 1.4 * sc, wdt * 0.02), Vector3(pos.x, y + 1.4 * sc, pos.z + wdt * 0.36), G(Color(1.0, 0.7, 0.4), 2.0 if night else 0.4))
		box(p, Vector3(wdt * 1.25, 0.35 * sc, wdt * 1.25), Vector3(pos.x, y + 2.75 * sc, pos.z), roof)
		box(p, Vector3(wdt * 1.3, 0.08 * sc, wdt * 1.3), Vector3(pos.x, y + 2.58 * sc, pos.z), G(glow, 3.0 if night else 0.8, 0.5))
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				cone(p, 0.25 * sc, 1.0 * sc, Vector3(pos.x + cx * wdt * 0.62, y + 3.1 * sc, pos.z + cz * wdt * 0.62), roof, Vector3(cz * 0.5, 0, -cx * 0.5))
	cyl(p, 0.15 * sc, 4.0 * sc, Vector3(pos.x, pos.y + 14.5 * sc, pos.z), G(glow, 2.0))


# ---------------------------------------------------------------- 4 neon market
func _market_side(z: float, s: float) -> float:
	var shop := randf()
	if shop < 0.17:
		return coffee_shop(z, s)
	if shop < 0.31:
		return barber_shop(z, s)
	if shop < 0.39:
		return food_cart(z, s)
	return facade_building(z, s, {"colors": [Color(0.55, 0.45, 0.65), Color(0.85, 0.55, 0.7), Color(0.5, 0.6, 0.75), Color(0.95, 0.72, 0.6), Color(0.62, 0.78, 0.7)],
		"floors": [3, 5], "neon": true, "ac": true, "depth": 7.0,
		"words": ["NOODLES", "GAMES", "ARCADE", "SUSHI", "PHONES", "KARAOKE", "BOBA", "HOTEL", "MANGA", "PIZZA", "RAMEN", "TECH"],
		"signs": [CYAN, PINK, Color(0.6, 0.45, 1.0), Color(1, 0.8, 0.3)]})


func _power_lines(z: float) -> void:
	var n := node(Vector3(0, 0, z), 1.0)
	var pole := M(Color(0.35, 0.28, 0.25), Color.BLACK, 0, 0.8)
	for sd in [-1.0, 1.0]:
		cyl(n, 0.14, 8.5, Vector3(sd * 5.6, 4.25, 0), pole)
		box(n, Vector3(1.6, 0.12, 0.12), Vector3(sd * 5.6, 8.0, 0), pole)
		sph(n, 0.3, Vector3(sd * 5.6, 5.2, 0.25), G(Color(1, 0.3, 0.3), 2.0), 1.2)
	var wire := M(Color(0.1, 0.1, 0.12))
	for k in 3:
		var y := 7.9 - k * 0.35
		for i in 6:
			var t0 := float(i) / 6.0
			var t1 := float(i + 1) / 6.0
			var a := Vector3(-5.6 + 11.2 * t0, y - 0.9 * sin(t0 * PI), 0)
			var b := Vector3(-5.6 + 11.2 * t1, y - 0.9 * sin(t1 * PI), 0)
			var seg := box(n, Vector3((b - a).length(), 0.035, 0.035), (a + b) * 0.5, wire)
			seg.rotation.z = atan2(b.y - a.y, b.x - a.x)


func _market_far(z: float, s: float) -> void:
	var n := node(Vector3(s * randf_range(28.0, 60.0), 0, z), 15.0)
	var c: Color = pick([Color(0.95, 0.65, 0.8), Color(0.8, 0.6, 0.9), Color(0.7, 0.65, 0.95)])
	var hgt := randf_range(25.0, 55.0)
	box(n, Vector3(9.0, hgt, 9.0), Vector3(0, hgt * 0.5, 0), M(c, Color.BLACK, 0, 0.6, 0, 0.5))
	box(n, Vector3(6.0, hgt * 0.4, 6.0), Vector3(3.0, hgt + hgt * 0.2 - 4.0, 2.0), M(c.lightened(0.1), Color.BLACK, 0, 0.6, 0, 0.5))
	box(n, Vector3(9.1, 0.6, 9.1), Vector3(0, hgt * 0.7, 0), G(CYAN, 1.5, 0.5))


# ---------------------------------------------------------------- 5 hover harbor
func _harbor_side(z: float, s: float) -> float:
	var r := randf()
	var white := M(Color(0.95, 0.95, 1.0), Color.BLACK, 0, 0.25, 0.2, 0.35)
	if r < 0.4:
		var n := node(Vector3(s * randf_range(9.0, 22.0), randf_range(-2.0, 6.0), z), 6.0)
		var rad := randf_range(3.0, 5.5)
		cyl(n, rad, 0.8, Vector3.ZERO, white)
		cyl(n, rad * 1.02, 0.15, Vector3(0, 0.35, 0), G(pick([CYAN, Color(0.4, 1, 0.6), PINK]), 3.0, 0.8))
		cyl(n, rad * 0.7, 0.3, Vector3(0, -0.5, 0), M(Color(0.6, 0.62, 0.75), Color.BLACK, 0, 0.3, 0.6))
		for k in 3:
			var a := TAU * k / 3.0
			cone(n, 0.5, 1.4, Vector3(cos(a) * rad * 0.5, -1.2, sin(a) * rad * 0.5), G(CYAN, 4.0, 1.0), Vector3(PI, 0, 0))
		if randf() < 0.5:
			cyl(n, 1.0, 3.0, Vector3(0, 1.9, 0), M(Color(0.3, 0.8, 0.7), Color.BLACK, 0, 0.3, 0.2, 0.4))
			sph(n, 1.0, Vector3(0, 3.4, 0), G(Color(1, 0.85, 0.4), 1.5))
		w.bobbers.append([n, n.position.y, 0.5, randf_range(0.8, 1.4), randf() * TAU])
		return randf_range(8.0, 14.0)
	if r < 0.7:
		var n2 := node(Vector3(s * randf_range(6.5, 9.0), -6.0, z), 2.0)
		cyl(n2, 0.9, 10.0, Vector3(0, 5.0, 0), white)
		for k in 3:
			cyl(n2, 0.95, 0.25, Vector3(0, 6.5 + k * 1.1, 0), G(Color(1.0, 0.25, 0.3), 3.0, 1.0))
		sph(n2, 0.9, Vector3(0, 10.2, 0), white)
		return randf_range(6.0, 10.0)
	if r < 0.85:
		# crane
		var n3 := node(Vector3(s * randf_range(14.0, 24.0), -10.0, z), 12.0)
		var steel := M(Color(0.95, 0.45, 0.35), Color.BLACK, 0, 0.5, 0.4)
		var hgt := randf_range(26.0, 36.0)
		for cx in [-0.8, 0.8]:
			for cz in [-0.8, 0.8]:
				box(n3, Vector3(0.2, hgt, 0.2), Vector3(cx, hgt * 0.5, cz), steel)
		for k in int(hgt / 2.5):
			box(n3, Vector3(1.8, 0.12, 0.12), Vector3(0, k * 2.5, 0.8), steel, false, Vector3(0, 0, 0.8 if k % 2 == 0 else -0.8))
		var arm := Node3D.new()
		arm.position = Vector3(0, hgt, 0)
		arm.rotation.y = randf_range(-1.0, 1.0) + (PI if s > 0 else 0.0)
		n3.add_child(arm)
		box(arm, Vector3(22.0, 0.8, 0.8), Vector3(7.0, 0, 0), steel)
		box(arm, Vector3(3.0, 2.0, 2.0), Vector3(-4.0, -0.5, 0), M(Color(0.3, 0.3, 0.35)))
		box(arm, Vector3(0.05, 8.0, 0.05), Vector3(15.0, -4.0, 0), M(Color(0.2, 0.2, 0.2)))
		box(arm, Vector3(2.0, 1.4, 2.0), Vector3(15.0, -8.5, 0), M(Color(0.95, 0.8, 0.3)))
		w.spinners.append([arm, Vector3(0, 1, 0), 0.08])
		return randf_range(18.0, 26.0)
	var n4 := node(Vector3(s * randf_range(16.0, 26.0), 0, z), 8.0)
	_capsule_pod(n4, s)
	return randf_range(10.0, 16.0)


func _capsule_pod(n: Node3D, s: float) -> void:
	n.position.y = randf_range(4.0, 9.0)
	var body := M(Color(0.95, 0.98, 1.0), Color.BLACK, 0, 0.2, 0.2, 0.4)
	var c := sph(n, 1.5, Vector3.ZERO, body)
	c.scale = Vector3(1.6, 1.0, 3.2)
	sph(n, 1.1, Vector3(0, 0.5, -1.5), M(Color(0.3, 0.8, 0.8), Color(0.2, 0.6, 0.8), 0.4, 0.1, 0.5, 0.5), 0.7)
	var ring: MeshInstance3D = w._torus(n, 2.3, 2.5, Vector3.ZERO, G(Color(0.4, 1.0, 0.6), 3.0, 0.8), Vector3.ZERO)
	ring.scale = Vector3(1.0, 1.0, 1.6)
	w.bobbers.append([n, n.position.y, 0.6, randf_range(0.6, 1.1), randf() * TAU])


func _light_ring(z: float) -> void:
	var n := node(Vector3(0, 0, z), 1.0)
	var c: Color = pick([CYAN, Color(0.4, 1.0, 0.6), PINK])
	w._torus(n, 6.2, 6.5, Vector3(0, 2.0, 0), G(c, 3.0, 1.0), Vector3(PI / 2, 0, 0))
	for k in 6:
		var a := TAU * k / 6.0
		sph(n, 0.3, Vector3(cos(a) * 6.35, 2.0 + sin(a) * 6.35, 0), G(Color.WHITE, 4.0, 1.0))


func _harbor_far(z: float, s: float) -> void:
	var n := node(Vector3(s * randf_range(30.0, 70.0), -20.0, z), 15.0)
	var hgt := randf_range(40.0, 75.0)
	var c: Color = pick([Color(0.95, 0.85, 0.95), Color(0.85, 0.95, 1.0), Color(1.0, 0.9, 0.8)])
	cyl(n, randf_range(4.0, 7.0), hgt, Vector3(0, hgt * 0.5, 0), M(c, Color.BLACK, 0, 0.3, 0.2, 0.45))
	for k in int(hgt / 6.0):
		var sc: Color = [CYAN, Color(0.4, 1, 0.6), PINK, Color(1, 0.8, 0.3)][k % 4]
		cyl(n, randf_range(4.2, 7.2), 0.5, Vector3(0, k * 6.0 + 3.0, 0), G(sc, 1.8, 0.4))
	sph(n, 5.0, Vector3(0, hgt, 0), M(c, Color.BLACK, 0, 0.3, 0.2, 0.45), 0.6)
	w._beam(n, Vector3(0, hgt, 0), 1.0, 40.0, CYAN, 0.25)


# ---------------------------------------------------------------- 6 sakura heights
func _sakura_side(z: float, s: float) -> float:
	var r := randf()
	if r < 0.42:
		var n := node(Vector3(s * randf_range(8.0, 13.0), 0, z), 4.0)
		if randf() < 0.4:
			_blossom_tree(n, Vector3.ZERO, randf_range(1.0, 1.6))
		else:
			gtree(n, Vector3.ZERO, _tree_for(6), randf_range(5.0, 8.0))
		return randf_range(4.0, 7.0)
	if r < 0.75:
		var wd := randf_range(7.0, 10.0)
		var n2 := node(Vector3(s * 12.5, 0, z - wd * 0.5), wd)
		var wall := M(Color(0.96, 0.94, 0.9), Color.BLACK, 0, 0.9, 0, 0.2)
		var beam := M(Color(0.3, 0.2, 0.16), Color.BLACK, 0, 0.8)
		var roof := M(Color(0.2, 0.3, 0.33), Color.BLACK, 0, 0.5, 0.2, 0.2)
		box(n2, Vector3(6.0, 3.4, wd), Vector3(0, 1.9, 0), wall, true)
		box(n2, Vector3(6.4, 0.5, wd + 0.4), Vector3(0, 0.25, 0), M(Color(0.5, 0.45, 0.42)))
		for k in int(wd / 1.6) + 1:
			box(n2, Vector3(0.1, 3.4, 0.18), Vector3(-s * 3.02, 1.9, -wd * 0.5 + k * 1.6), beam)
		box(n2, Vector3(0.1, 0.2, wd), Vector3(-s * 3.02, 3.0, 0), beam)
		box(n2, Vector3(0.05, 1.6, wd * 0.5), Vector3(-s * 3.05, 1.7, 0), w.mat(Color(1.0, 0.92, 0.75), Color(1.0, 0.8, 0.5), 0.5, 0.8))
		box(n2, Vector3(4.6, 0.3, wd + 1.4), Vector3(-s * 1.7, 4.2, 0), roof, true, Vector3(0, 0, s * 0.5))
		box(n2, Vector3(4.6, 0.3, wd + 1.4), Vector3(s * 1.7, 4.2, 0), roof, true, Vector3(0, 0, -s * 0.5))
		box(n2, Vector3(0.4, 0.4, wd + 1.6), Vector3(0, 5.3, 0), roof)
		return wd + randf_range(2.0, 5.0)
	var n3 := node(Vector3(s * 6.4, 0.12, z), 1.5)
	var stone := M(Color(0.62, 0.62, 0.6), Color.BLACK, 0, 0.95)
	box(n3, Vector3(0.7, 0.3, 0.7), Vector3(0, 0.15, 0), stone)
	cyl(n3, 0.14, 1.0, Vector3(0, 0.8, 0), stone)
	box(n3, Vector3(0.6, 0.55, 0.6), Vector3(0, 1.55, 0), stone)
	box(n3, Vector3(0.45, 0.35, 0.62), Vector3(0, 1.55, 0), G(Color(1.0, 0.75, 0.4), 2.0, 0.3))
	cone(n3, 0.55, 0.45, Vector3(0, 2.05, 0), stone)
	for k in 5:
		var hgt := randf_range(3.0, 6.0)
		cyl(n3, 0.07, hgt, Vector3(s * randf_range(1.0, 2.2), hgt * 0.5, randf_range(-1, 1)), M(Color(0.45, 0.7, 0.35)))
	return randf_range(4.0, 7.0)


func _blossom_tree(p: Node3D, pos: Vector3, sc: float) -> void:
	var bark := M(Color(0.3, 0.2, 0.2))
	cyl(p, 0.3 * sc, 3.0 * sc, pos + Vector3(0, 1.5 * sc, 0), bark)
	box(p, Vector3(0.25, 2.0, 0.25) * sc, pos + Vector3(0.6 * sc, 3.3 * sc, 0), bark, false, Vector3(0, 0, -0.6))
	box(p, Vector3(0.25, 2.0, 0.25) * sc, pos + Vector3(-0.6 * sc, 3.3 * sc, 0.2), bark, false, Vector3(0, 0, 0.6))
	for k in 6:
		var c: Color = pick([Color(1.0, 0.75, 0.85), Color(1.0, 0.85, 0.92), Color(0.98, 0.65, 0.8)])
		sph(p, randf_range(1.0, 1.5) * sc, pos + Vector3(randf_range(-1.6, 1.6) * sc, (3.8 + randf_range(0, 1.4)) * sc, randf_range(-1.2, 1.2) * sc), M(c, c, 0.12, 0.9, 0, 0.45))


func _torii(z: float, sc: float) -> void:
	var n := node(Vector3(0, 0, z), 1.0)
	var red := M(Color(0.9, 0.22, 0.18), Color(0.6, 0.1, 0.05), 0.15, 0.6)
	var black := M(Color(0.08, 0.07, 0.08))
	var half := 5.4 * sc
	for sd in [-1.0, 1.0]:
		cyl(n, 0.4 * sc, 7.5 * sc, Vector3(sd * half, 3.75 * sc, 0), red)
		cyl(n, 0.5 * sc, 0.5 * sc, Vector3(sd * half, 0.25 * sc, 0), black)
	box(n, Vector3(half * 2.0 + 1.2, 0.5 * sc, 0.5 * sc), Vector3(0, 6.2 * sc, 0), red, true)
	box(n, Vector3(half * 2.0 + 3.0, 0.45 * sc, 0.8 * sc), Vector3(0, 7.6 * sc, 0), red, true)
	box(n, Vector3(half * 2.0 + 3.4, 0.25 * sc, 0.9 * sc), Vector3(0, 7.95 * sc, 0), black)
	box(n, Vector3(0.4 * sc, 1.4 * sc, 0.3 * sc), Vector3(0, 6.9 * sc, 0), black)
	sph(n, 0.35, Vector3(-half + 1.0, 5.4 * sc, 0.4), G(Color(1.0, 0.7, 0.4), 2.5), 1.3)
	sph(n, 0.35, Vector3(half - 1.0, 5.4 * sc, 0.4), G(Color(1.0, 0.7, 0.4), 2.5), 1.3)


func _sakura_far(z: float, s: float) -> void:
	var n := node(Vector3(s * randf_range(35.0, 75.0), -4.0, z), 20.0)
	var hgt := randf_range(30.0, 60.0)
	var rad := randf_range(18.0, 28.0)
	cone(n, rad, hgt, Vector3(0, hgt * 0.5, 0), M(Color(0.55, 0.55, 0.75), Color.BLACK, 0, 0.9, 0, 0.3))
	cone(n, rad * 0.32, hgt * 0.32, Vector3(0, hgt * 0.84, 0), M(Color(0.98, 0.97, 1.0), Color.BLACK, 0, 0.8, 0, 0.4))
	if randf() < 0.3:
		_pagoda(n, Vector3(rad * 0.4, 0, rad * 0.4), 0.9, Color(1.0, 0.6, 0.7), false)


# ---------------------------------------------------------------- 7 candy carnival
func _carnival_side(z: float, s: float) -> float:
	var r := randf()
	var n := node(Vector3(s * randf_range(7.5, 12.0), 0, z), 4.0)
	if r < 0.35:
		# striped tent
		var a: Color = pick([Color(1, 0.35, 0.4), Color(0.35, 0.6, 1.0), Color(0.6, 0.35, 0.9), Color(1, 0.65, 0.2)])
		var rad := randf_range(2.2, 3.4)
		for k in 6:
			var c := a if k % 2 == 0 else Color(0.98, 0.96, 0.92)
			var seg := cyl(n, rad, 0.45, Vector3(0, 0.25 + k * 0.45, 0), M(c, c, 0.05, 0.8))
			seg.scale.x = rad
		cone(n, rad * 1.15, 2.2, Vector3(0, 3.8, 0), M(a, a, 0.1, 0.8))
		cone(n, rad * 0.6, 1.2, Vector3(0, 4.9, 0), M(Color(0.98, 0.96, 0.92)))
		cyl(n, 0.05, 1.2, Vector3(0, 6.0, 0), M(Color(0.9, 0.8, 0.3)))
		box(n, Vector3(0.6, 0.35, 0.02), Vector3(0, 6.4, 0.3), G(Color(1, 0.85, 0.3), 1.5))
		light(n, Vector3(-s * rad, 1.5, 0), Color(1, 0.7, 0.4), 1.5, 7.0)
		return randf_range(7.0, 10.0)
	if r < 0.55:
		for k in randi_range(4, 8):
			var c2: Color = pick([Color(1, 0.4, 0.5), Color(0.4, 0.8, 1), Color(1, 0.85, 0.3), Color(0.6, 1, 0.5), Color(0.8, 0.5, 1)])
			var bp := Vector3(randf_range(-0.8, 0.8), randf_range(3.5, 5.0), randf_range(-0.8, 0.8))
			sph(n, 0.45, bp, M(c2, c2, 0.3, 0.2, 0, 0.6), 1.2)
			box(n, Vector3(0.02, bp.y - 1.0, 0.02), Vector3(bp.x * 0.3, (bp.y - 1.0) * 0.5 + 1.0, bp.z * 0.3), M(Color.WHITE))
		box(n, Vector3(1.4, 1.0, 1.0), Vector3(0, 0.5, 0), M(Color(0.95, 0.5, 0.6)))
		w.bobbers.append([n, 0.0, 0.2, 1.2, randf() * TAU])
		return randf_range(4.0, 6.0)
	if r < 0.78:
		# giant lollipop
		var hgt := randf_range(4.0, 7.0)
		cyl(n, 0.15, hgt, Vector3(0, hgt * 0.5, 0), M(Color(0.98, 0.96, 0.95)))
		var cols := [Color(1, 0.35, 0.5), Color(0.98, 0.95, 0.9), Color(0.5, 0.8, 1.0), Color(1, 0.85, 0.3)]
		var base: Color = pick(cols)
		cyl(n, 1.6, 0.3, Vector3(0, hgt + 1.4, 0), M(base, base, 0.2, 0.3, 0, 0.5), Vector3(PI / 2, 0, 0))
		for k in 3:
			w._torus(n, 0.4 + k * 0.4, 0.55 + k * 0.4, Vector3(0, hgt + 1.4, 0.16), M(Color(0.98, 0.95, 0.92), Color.BLACK, 0, 0.3), Vector3(PI / 2, 0, 0))
		return randf_range(4.0, 7.0)
	# candy cane + lamp
	var red := M(Color(1, 0.25, 0.3), Color.BLACK, 0, 0.3, 0, 0.4)
	var wht := M(Color(0.98, 0.96, 0.95), Color.BLACK, 0, 0.3, 0, 0.4)
	for k in 8:
		cyl(n, 0.3, 0.6, Vector3(0, 0.3 + k * 0.6, 0), red if k % 2 == 0 else wht)
	w._torus(n, 0.9, 1.5, Vector3(-s * 0.6, 4.8, 0), red, Vector3(PI / 2, 0, 0))
	_lamp(n, Vector3(-s * 1.5, 0, 2.0), s, Color(1, 0.85, 0.5), Color(0.9, 0.3, 0.35), true)
	return randf_range(5.0, 8.0)


func _bulb_string(z: float) -> void:
	var n := node(Vector3(0, 0, z), 1.0)
	for i in 13:
		var t := float(i) / 12.0
		var x := -7.0 + 14.0 * t
		var y := 6.6 - 1.1 * sin(t * PI)
		var c: Color = [Color(1, 0.85, 0.4), Color(1, 0.4, 0.5), Color(0.5, 0.9, 1), Color(0.7, 1, 0.5)][i % 4]
		sph(n, 0.16, Vector3(x, y, 0), G(c, 4.5, 1.2))
	for i in 6:
		var t0 := float(i) / 6.0
		var t1 := float(i + 1) / 6.0
		var a := Vector3(-7.0 + 14.0 * t0, 6.7 - 1.1 * sin(t0 * PI), 0)
		var b := Vector3(-7.0 + 14.0 * t1, 6.7 - 1.1 * sin(t1 * PI), 0)
		var seg := box(n, Vector3((b - a).length(), 0.03, 0.03), (a + b) * 0.5, M(Color(0.15, 0.12, 0.15)))
		seg.rotation.z = atan2(b.y - a.y, b.x - a.x)


func _carnival_far(z: float, s: float) -> void:
	var n := node(Vector3(s * randf_range(28.0, 55.0), 0, z), 18.0)
	if randf() < 0.5:
		# ferris wheel
		var wheel := Node3D.new()
		wheel.position = Vector3(0, 18.0, 0)
		wheel.rotation.y = s * 0.6
		n.add_child(wheel)
		var rim := G(Color(1, 0.6, 0.8), 2.2, 1.0)
		var spin := Node3D.new()
		wheel.add_child(spin)
		w._torus(spin, 13.5, 14.0, Vector3.ZERO, rim, Vector3(PI / 2, 0, 0))
		w._torus(spin, 6.0, 6.4, Vector3.ZERO, G(Color(0.5, 0.9, 1.0), 2.0, 1.0), Vector3(PI / 2, 0, 0))
		for k in 12:
			var a := TAU * k / 12.0
			box(spin, Vector3(0.15, 14.0, 0.15), Vector3(cos(a) * 7.0, sin(a) * 7.0, 0), M(Color(0.95, 0.95, 1.0)), false, Vector3(0, 0, a - PI / 2))
			var cab: Color = [Color(1, 0.4, 0.5), Color(1, 0.85, 0.3), Color(0.4, 0.8, 1), Color(0.6, 1, 0.5)][k % 4]
			box(spin, Vector3(1.4, 1.4, 1.4), Vector3(cos(a) * 14.2, sin(a) * 14.2, 0), M(cab, cab, 0.4))
		w.spinners.append([spin, Vector3(0, 0, 1), 0.25])
		for sd in [-1.0, 1.0]:
			box(wheel, Vector3(0.6, 20.0, 0.6), Vector3(sd * 5.0, -8.0, 0), M(Color(0.9, 0.9, 0.95)), false, Vector3(0, 0, sd * 0.25))
	else:
		var m := G(Color(1.0, 0.4, 0.6), 1.2, 0.5)
		w._torus(n, 8.0, 8.6, Vector3(0, 9.0, 0), m, Vector3(PI / 2, s * 0.8, 0))
		for k in 5:
			cyl(n, 0.3, 10.0, Vector3(-12.0 + k * 6.0, 5.0, 0), M(Color(0.9, 0.85, 0.95)))
		box(n, Vector3(30.0, 0.6, 1.2), Vector3(0, 10.0, 0), m)


# ================================================================ v6 additions
const V := preload("res://scripts/vehicles.gd")
const MT := preload("res://scripts/model_tools.gd")

var _tree_parts = null
var _text_cache := {}


## 5 x 7 LED pixel font for the signs (built as one mesh per string, so the
## text bends with the curved world like everything else).
const GLYPHS := {
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"], "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
	"C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"], "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"], "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
	"G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"], "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
	"I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"], "J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
	"K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"], "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
	"M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"], "N": ["10001", "10001", "11001", "10101", "10011", "10001", "10001"],
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"], "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
	"Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"], "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"], "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
	"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"], "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
	"W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"], "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
	"Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"], "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
	"0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"], "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
	"2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"], "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
	"4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"], "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
	"6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"], "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
	"8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"], "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
	".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"], "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
	">": ["01000", "00100", "00010", "00001", "00010", "00100", "01000"], "<": ["00010", "00100", "01000", "10000", "01000", "00100", "00010"],
	"^": ["00100", "01110", "10101", "00100", "00100", "00100", "00100"], "!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
}


## LED-pixel text facing +Z, centred on pos. `px` is the size of one pixel.
func text(p: Node3D, s: String, pos: Vector3, px: float, c: Color, energy := 2.0, rot := Vector3.ZERO) -> MeshInstance3D:
	var key := "%s|%.3f" % [s, px]
	if not _text_cache.has(key):
		_text_cache[key] = _led_mesh(s, px * 4.0)
	var mi: MeshInstance3D = w._mi(p, _text_cache[key], pos, G(c, energy), false)
	mi.rotation = rot
	return mi


func _led_mesh(s: String, u: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := s.length() * 6 - 1
	var x0 := -cols * u * 0.5
	var y0 := 3.5 * u
	var d := u * 0.5
	var sz := u * 0.86
	for ci in s.length():
		var g: Array = GLYPHS.get(s[ci], [])
		for row in g.size():
			var line: String = g[row]
			for col in 5:
				if line[col] != "1":
					continue
				var cx := x0 + (ci * 6 + col) * u
				var cy := y0 - row * u
				_quad(st, Vector3(cx, cy - sz, d), Vector3(cx + sz, cy - sz, d), Vector3(cx + sz, cy, d), Vector3(cx, cy, d), Vector3(0, 0, 1))
				_quad(st, Vector3(cx, cy, 0), Vector3(cx, cy, d), Vector3(cx + sz, cy, d), Vector3(cx + sz, cy, 0), Vector3(0, 1, 0))
				_quad(st, Vector3(cx, cy - sz, d), Vector3(cx, cy - sz, 0), Vector3(cx + sz, cy - sz, 0), Vector3(cx + sz, cy - sz, d), Vector3(0, -1, 0))
				_quad(st, Vector3(cx, cy - sz, 0), Vector3(cx, cy - sz, d), Vector3(cx, cy, d), Vector3(cx, cy, 0), Vector3(-1, 0, 0))
				_quad(st, Vector3(cx + sz, cy - sz, d), Vector3(cx + sz, cy - sz, 0), Vector3(cx + sz, cy, 0), Vector3(cx + sz, cy, d), Vector3(1, 0, 0))
	return st.commit()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.add_vertex(v)


## A tree from the trimmed tree sheet (falls back to the old shape trees).
## kind: oak, sakura, pine, palm, gold, birch, spruce, red, bamboo, bonsai
func gtree(p: Node3D, pos: Vector3, kind: String, height: float) -> void:
	if _tree_parts == null:
		_tree_parts = V.trees()
	var i := V.tree_index(kind)
	if _tree_parts.is_empty() or i < 0 or i >= _tree_parts.size():
		_tree(p, pos, height / 5.0, [Color(0.35, 0.72, 0.35), Color(0.45, 0.8, 0.4)])
		return
	var part: Dictionary = _tree_parts[i]
	var size: Vector3 = part["size"]
	var s := height / maxf(size.y, 0.001)
	var mi := MeshInstance3D.new()
	mi.mesh = part["mesh"]
	mi.material_override = MT.world_material(part["material"])
	mi.position = pos
	mi.scale = Vector3.ONE * s
	mi.rotation.y = randf() * TAU
	mi.extra_cull_margin = 60.0
	p.add_child(mi)


func _tree_for(t: int) -> String:
	match t:
		1: return pick(["oak", "gold", "birch", "bonsai"])
		2: return pick(["oak", "oak", "birch", "gold", "palm"])
		3: return pick(["bamboo", "bamboo", "red"])
		4: return pick(["bonsai", "oak", "palm"])
		5: return pick(["palm", "spruce", "sakura"])
		6: return pick(["sakura", "sakura", "red", "pine", "bamboo"])
		7: return pick(["gold", "red", "sakura", "palm"])
		8: return pick(["palm", "palm", "pine", "oak"])
	return "oak"


# ---------------------------------------------------------------- street furniture
## Sidewalk props for the towns (x ~ 5 - 7.5): lamps, benches, bins, hydrants,
## planters, bus stops, vending machines... Returns spacing to the next one.
func props(z: float, s: float, t: int) -> float:
	if t == 0:
		return sky_side(z, s)
	if t == 5:
		return 40.0
	if t == 2 and w.qpipe_near(z, s):
		return 6.0
	var night: bool = t == 3 or t == 7
	var n := node(Vector3(s * 5.35, 0.13, z), 1.5)
	var r := randf()
	if t == 8:
		_highway_lamp(n, s)
		return randf_range(16.0, 22.0)
	var r2 := randf()
	if r2 < 0.06 and t in [3, 4, 7, 1]:
		arcade_corner(n, s)
		return randf_range(6.0, 9.0)
	elif r2 < 0.14 and t in [1, 2, 4, 6, 7]:
		topiary(n, Vector3(s * 0.6, 0, 0))
		return randf_range(4.0, 7.0)
	elif r2 < 0.2:
		aframe_sign(n, s, night)
		return randf_range(5.0, 8.0)
	elif r2 < 0.17 and t != 6:
		pole_sign(n, s, night)
		return randf_range(9.0, 13.0)
	elif r2 < 0.25:
		flower_bed(n, s)
		return randf_range(5.0, 8.0)
	if r < 0.36:
		var styles := {1: [Color(1, 0.92, 0.75), Color(0.2, 0.35, 0.3)], 2: [Color(1, 0.97, 0.85), Color(0.3, 0.3, 0.35)],
			3: [Color(1.0, 0.4, 0.8), Color(0.12, 0.12, 0.16)], 4: [Color(0.4, 0.95, 1.0), Color(0.25, 0.22, 0.3)],
			6: [Color(1.0, 0.8, 0.55), Color(0.2, 0.16, 0.14)], 7: [Color(1, 0.85, 0.5), Color(0.9, 0.3, 0.35)]}
		var st: Array = styles.get(t, [Color(1, 0.95, 0.8), Color(0.3, 0.3, 0.35)])
		street_lamp(n, Vector3.ZERO, s, st[0], st[1], night or t == 4)
	elif r < 0.52:
		bench(n, Vector3(s * 0.5, 0, 0), s)
		if randf() < 0.5:
			trash_bin(n, Vector3(s * 0.4, 0, 1.4))
	elif r < 0.64:
		planter(n, Vector3(s * 0.7, 0, 0), t)
	elif r < 0.72:
		hydrant(n, Vector3(s * -0.2, 0, 0))
	elif r < 0.82 and t != 6:
		vending(n, Vector3(s * 1.6, 0, 0), s, pick([Color(0.9, 0.2, 0.25), Color(0.2, 0.5, 0.95), Color(0.15, 0.7, 0.4)]))
	elif r < 0.9 and t != 6:
		bus_stop(n, s)
		return randf_range(10.0, 14.0)
	else:
		trash_bin(n, Vector3(s * 0.4, 0, 0))
		if randf() < 0.6:
			_person(n, Vector3(s * 0.9, 0, -0.8), s * PI * 0.5 + randf_range(-1, 1))
	return randf_range(5.0, 9.0)


func street_lamp(p: Node3D, pos: Vector3, s: float, lamp_c: Color, pole_c: Color, lit: bool) -> void:
	var pole := M(pole_c, Color.BLACK, 0.0, 0.4, 0.6)
	cyl(p, 0.14, 0.4, pos + Vector3(0, 0.2, 0), pole)
	cyl(p, 0.07, 5.0, pos + Vector3(0, 2.7, 0), pole)
	box(p, Vector3(1.4, 0.08, 0.08), pos + Vector3(-s * 0.65, 5.1, 0), pole)
	box(p, Vector3(0.55, 0.14, 0.34), pos + Vector3(-s * 1.3, 5.02, 0), pole)
	box(p, Vector3(0.48, 0.04, 0.28), pos + Vector3(-s * 1.3, 4.94, 0), G(lamp_c, 4.0 if lit else 1.6))
	# little banner on the pole
	box(p, Vector3(0.04, 0.9, 0.5), pos + Vector3(s * 0.05, 3.6, 0.28), M(lamp_c.darkened(0.2), lamp_c, 0.3))
	if lit:
		light(p, pos + Vector3(-s * 1.3, 4.4, 0), lamp_c, 2.2, 9.0)


func bench(p: Node3D, pos: Vector3, s: float) -> void:
	var wood := M(Color(0.62, 0.42, 0.28), Color.BLACK, 0, 0.8)
	var iron := M(Color(0.15, 0.15, 0.18), Color.BLACK, 0, 0.4, 0.6)
	box(p, Vector3(0.45, 0.06, 1.6), pos + Vector3(0, 0.45, 0), wood)
	box(p, Vector3(0.06, 0.4, 1.6), pos + Vector3(s * 0.22, 0.72, 0), wood, false, Vector3(0, 0, -s * 0.15))
	for zz in [-0.7, 0.7]:
		box(p, Vector3(0.45, 0.45, 0.06), pos + Vector3(0, 0.22, zz), iron)


func trash_bin(p: Node3D, pos: Vector3) -> void:
	cyl(p, 0.26, 0.8, pos + Vector3(0, 0.4, 0), M(Color(0.25, 0.45, 0.35), Color.BLACK, 0, 0.5, 0.3))
	cyl(p, 0.29, 0.08, pos + Vector3(0, 0.82, 0), M(Color(0.2, 0.2, 0.22)))


func hydrant(p: Node3D, pos: Vector3) -> void:
	var red := M(Color(0.9, 0.15, 0.15), Color.BLACK, 0, 0.4, 0.2)
	cyl(p, 0.14, 0.6, pos + Vector3(0, 0.3, 0), red)
	sph(p, 0.15, pos + Vector3(0, 0.62, 0), red)
	cyl(p, 0.06, 0.4, pos + Vector3(0, 0.42, 0), red, Vector3(0, 0, PI / 2))


func planter(p: Node3D, pos: Vector3, t: int) -> void:
	box(p, Vector3(1.0, 0.55, 1.0), pos + Vector3(0, 0.27, 0), M(Color(0.6, 0.55, 0.5), Color.BLACK, 0, 0.9))
	box(p, Vector3(0.9, 0.05, 0.9), pos + Vector3(0, 0.56, 0), M(Color(0.3, 0.22, 0.15)))
	gtree(p, pos + Vector3(0, 0.55, 0), _tree_for(t), randf_range(2.2, 3.4))


func vending(p: Node3D, pos: Vector3, s: float, c: Color) -> void:
	box(p, Vector3(0.8, 1.9, 1.0), pos + Vector3(0, 0.95, 0), M(c, Color.BLACK, 0, 0.4, 0.2), true)
	box(p, Vector3(0.04, 1.1, 0.7), pos + Vector3(-s * 0.41, 1.2, 0), w.mat(Color(0.8, 0.95, 1.0), Color(0.6, 0.9, 1.0), 1.4, 0.1))
	for k in 3:
		for j in 3:
			box(p, Vector3(0.05, 0.14, 0.12), pos + Vector3(-s * 0.43, 0.8 + k * 0.32, -0.2 + j * 0.2), G(pick([Color(1, 0.4, 0.3), Color(0.3, 0.8, 1), Color(1, 0.9, 0.3)]), 1.2))
	box(p, Vector3(0.05, 0.25, 0.7), pos + Vector3(-s * 0.42, 1.78, 0), G(Color.WHITE, 2.0))


func bus_stop(p: Node3D, s: float) -> void:
	var frame := M(Color(0.85, 0.87, 0.9), Color.BLACK, 0, 0.3, 0.6)
	var glass: Material = w.mat(Color(0.6, 0.8, 0.95), Color(0.3, 0.5, 0.7), 0.15, 0.05, 0.3, 0.6)
	for zz in [-1.6, 1.6]:
		box(p, Vector3(0.08, 2.5, 0.08), Vector3(s * 0.9, 1.25, zz), frame)
		box(p, Vector3(0.08, 2.5, 0.08), Vector3(s * 1.8, 1.25, zz), frame)
	box(p, Vector3(1.3, 0.1, 3.5), Vector3(s * 1.35, 2.52, 0), frame)
	box(p, Vector3(0.04, 1.9, 3.2), Vector3(s * 1.82, 1.3, 0), glass)
	box(p, Vector3(0.05, 1.2, 0.9), Vector3(s * 1.78, 1.3, -1.0), G(Color(1.0, 0.55, 0.3), 1.5))
	bench(p, Vector3(s * 1.45, 0, 0.5), s)
	box(p, Vector3(0.1, 0.5, 0.5), Vector3(s * 0.3, 2.8, 1.8), G(Color(0.2, 0.6, 1.0), 1.5))
	text(p, "BUS", Vector3(s * 0.3, 2.8, 2.06), 0.012, Color.WHITE)
	cyl(p, 0.05, 2.6, Vector3(s * 0.3, 1.3, 1.8), frame)


## A blade sign sticking out of a facade, readable from the road.
func blade_sign(p: Node3D, pos: Vector3, s: float, label: String, bg: Color, fg: Color, lit: bool) -> void:
	var wlen := label.length() * 0.42 + 0.6
	box(p, Vector3(0.08, 0.08, 0.8), pos + Vector3(0, 0.5, 0), M(Color(0.2, 0.2, 0.22)))
	box(p, Vector3(wlen, 0.8, 0.12), pos + Vector3(-s * wlen * 0.5, 0, 0), M(bg, bg, 0.6 if lit else 0.15, 0.5))
	box(p, Vector3(wlen + 0.1, 0.06, 0.14), pos + Vector3(-s * wlen * 0.5, 0.42, 0), G(fg, 2.0))
	box(p, Vector3(wlen + 0.1, 0.06, 0.14), pos + Vector3(-s * wlen * 0.5, -0.42, 0), G(fg, 2.0))
	text(p, label, pos + Vector3(-s * wlen * 0.5, -0.02, 0.08), 0.011, fg, 2.5 if lit else 1.5)


# ---------------------------------------------------------------- neon market shops
func coffee_shop(z: float, s: float, night := false) -> float:
	var wd := randf_range(7.5, 9.0)
	var n := node(Vector3(s * 11.0, 0, z - wd * 0.5), wd)
	var dp := 6.2
	var fx := -s * dp * 0.5
	var wall_c: Color = pick([Color(0.55, 0.38, 0.28), Color(0.95, 0.9, 0.82), Color(0.3, 0.45, 0.4)])
	var floors := randi_range(2, 4)
	var h := 3.4 + (floors - 1) * 3.0
	box(n, Vector3(dp, h, wd), Vector3(0, h * 0.5, 0), M(wall_c, Color.BLACK, 0, 0.85, 0, 0.2), true)
	box(n, Vector3(dp + 0.3, 0.3, wd + 0.2), Vector3(0, h + 0.15, 0), M(wall_c.darkened(0.35)))
	# big warm shop window + door
	var warm: Material = w.mat(Color(1.0, 0.85, 0.6), Color(1.0, 0.72, 0.4), 1.6 if night else 0.9, 0.2)
	box(n, Vector3(0.06, 2.1, wd * 0.55), Vector3(fx - s * 0.02, 1.3, -wd * 0.12), warm)
	box(n, Vector3(0.08, 2.2, 1.0), Vector3(fx - s * 0.03, 1.1, wd * 0.33), M(Color(0.35, 0.22, 0.15)))
	box(n, Vector3(0.1, 0.12, wd * 0.6), Vector3(fx - s * 0.05, 2.4, -wd * 0.12), M(Color(0.2, 0.14, 0.1)))
	# counter + espresso machine seen through the window
	box(n, Vector3(0.6, 1.0, wd * 0.4), Vector3(fx + s * 0.7, 0.5, -wd * 0.12), M(Color(0.4, 0.26, 0.16)))
	box(n, Vector3(0.4, 0.45, 0.6), Vector3(fx + s * 0.7, 1.22, -wd * 0.2), M(Color(0.8, 0.8, 0.85), Color.BLACK, 0, 0.2, 0.8))
	# striped awning
	for k in 8:
		var c := Color(0.35, 0.2, 0.12) if k % 2 == 0 else Color(0.98, 0.94, 0.86)
		box(n, Vector3(1.9, 0.1, wd * 0.9 / 8.0), Vector3(fx - s * 0.9, 2.95, -wd * 0.45 + (k + 0.5) * wd * 0.9 / 8.0), M(c), false, Vector3(0, 0, s * 0.33))
	# giant cup sign on the roof edge + name board
	var cup := Node3D.new()
	cup.position = Vector3(fx - s * 0.2, h + 1.3, 0)
	n.add_child(cup)
	cyl(cup, 0.75, 1.3, Vector3.ZERO, M(Color(0.98, 0.97, 0.95), Color.BLACK, 0, 0.3))
	cyl(cup, 0.8, 0.12, Vector3(0, 0.66, 0), M(Color(0.35, 0.2, 0.12)))
	cyl(cup, 0.76, 0.35, Vector3(0, 0.1, 0), G(Color(0.55, 0.3, 0.15), 0.6))
	w._torus(cup, 0.3, 0.42, Vector3(0, 0, 0.78), M(Color(0.98, 0.97, 0.95)), Vector3(0, 0, PI / 2))
	for k in 3:
		var st := cyl(cup, 0.07, 0.6, Vector3(-0.3 + k * 0.3, 1.1 + (k % 2) * 0.15, 0), w.mat(Color(1, 1, 1), Color(1, 1, 1), 0.8, 0.9))
		st.rotation.z = 0.25 * (k - 1)
	w.bobbers.append([cup, cup.position.y, 0.08, 1.5, randf() * TAU])
	blade_sign(n, Vector3(fx - s * 0.1, 3.8, wd * 0.45), s, "COFFEE", Color(0.3, 0.18, 0.1), Color(1.0, 0.85, 0.55), true)
	# terrace: table, chairs, umbrella, chalkboard
	var tn := Node3D.new()
	tn.position = Vector3(fx - s * 2.3, 0.13, -wd * 0.1)
	n.add_child(tn)
	cyl(tn, 0.45, 0.05, Vector3(0, 0.75, 0), M(Color(0.95, 0.95, 0.95)))
	cyl(tn, 0.05, 0.75, Vector3(0, 0.37, 0), M(Color(0.2, 0.2, 0.22)))
	for k in 2:
		var cz := -0.75 if k == 0 else 0.75
		box(tn, Vector3(0.4, 0.05, 0.4), Vector3(0, 0.45, cz), M(Color(0.3, 0.2, 0.15)))
		box(tn, Vector3(0.4, 0.45, 0.05), Vector3(0, 0.68, cz + (0.2 if k == 1 else -0.2)), M(Color(0.3, 0.2, 0.15)))
	cyl(tn, 0.03, 2.2, Vector3(0, 1.1, 0), M(Color(0.9, 0.9, 0.9)))
	cone(tn, 1.3, 0.5, Vector3(0, 2.3, 0), M(Color(0.3, 0.55, 0.4)))
	var cb := box(tn, Vector3(0.05, 0.9, 0.6), Vector3(-s * 0.2, 0.5, 1.7), M(Color(0.12, 0.12, 0.12)))
	cb.rotation.z = s * 0.15
	text(tn, "LATTE", Vector3(-s * 0.26, 0.6, 1.7), 0.006, Color(1, 1, 0.9), 1.0, Vector3(0, -s * PI * 0.5, 0))
	if night:
		light(n, Vector3(fx - s * 1.5, 2.0, 0), Color(1.0, 0.75, 0.45), 2.2, 8.0)
	_upper_windows(n, fx, s, wd, floors, 3.4, 3.0, night)
	return wd + randf_range(0.3, 1.0)


func barber_shop(z: float, s: float, night := false) -> float:
	var wd := randf_range(6.5, 8.0)
	var n := node(Vector3(s * 11.0, 0, z - wd * 0.5), wd)
	var dp := 6.0
	var fx := -s * dp * 0.5
	var wall_c: Color = pick([Color(0.2, 0.25, 0.4), Color(0.9, 0.9, 0.92), Color(0.55, 0.15, 0.18)])
	var floors := randi_range(2, 4)
	var h := 3.4 + (floors - 1) * 3.0
	box(n, Vector3(dp, h, wd), Vector3(0, h * 0.5, 0), M(wall_c, Color.BLACK, 0, 0.85, 0, 0.2), true)
	box(n, Vector3(dp + 0.3, 0.3, wd + 0.2), Vector3(0, h + 0.15, 0), M(wall_c.darkened(0.35)))
	var win: Material = w.mat(Color(0.75, 0.9, 1.0), Color(0.7, 0.9, 1.0), 1.2 if night else 0.5, 0.1)
	box(n, Vector3(0.06, 2.0, wd * 0.55), Vector3(fx - s * 0.02, 1.3, -wd * 0.1), win)
	box(n, Vector3(0.08, 2.2, 1.0), Vector3(fx - s * 0.03, 1.1, wd * 0.34), M(Color(0.12, 0.12, 0.15)))
	# barber chair + mirror inside
	box(n, Vector3(0.6, 0.5, 0.6), Vector3(fx + s * 0.9, 0.55, -wd * 0.1), M(Color(0.7, 0.1, 0.12), Color.BLACK, 0, 0.3, 0.2))
	box(n, Vector3(0.15, 0.7, 0.6), Vector3(fx + s * 1.15, 1.0, -wd * 0.1), M(Color(0.7, 0.1, 0.12), Color.BLACK, 0, 0.3, 0.2))
	box(n, Vector3(0.05, 1.0, 1.4), Vector3(fx + s * 2.8, 1.5, -wd * 0.1), w.mat(Color(0.85, 0.9, 1.0), Color(0.6, 0.7, 0.8), 0.4, 0.05, 0.9))
	# spinning barber pole
	var pole := Node3D.new()
	pole.position = Vector3(fx - s * 0.35, 1.6, wd * 0.12)
	n.add_child(pole)
	cyl(pole, 0.2, 0.15, Vector3(0, 0.95, 0), M(Color(0.85, 0.85, 0.9), Color.BLACK, 0, 0.2, 0.8))
	cyl(pole, 0.2, 0.15, Vector3(0, -0.95, 0), M(Color(0.85, 0.85, 0.9), Color.BLACK, 0, 0.2, 0.8))
	var spin := Node3D.new()
	pole.add_child(spin)
	cyl(spin, 0.16, 1.75, Vector3.ZERO, G(Color(1, 1, 1), 1.2))
	for k in 6:
		var band := box(spin, Vector3(0.34, 0.1, 0.06), Vector3(0, -0.75 + k * 0.3, 0.14), G(Color(0.95, 0.1, 0.12) if k % 2 == 0 else Color(0.15, 0.3, 0.95), 1.5))
		band.rotation.z = 0.5
		var band2 := box(spin, Vector3(0.34, 0.1, 0.06), Vector3(0, -0.6 + k * 0.3, -0.14), G(Color(0.15, 0.3, 0.95) if k % 2 == 0 else Color(0.95, 0.1, 0.12), 1.5))
		band2.rotation.z = -0.5
	w.spinners.append([spin, Vector3(0, 1, 0), 3.0])
	# awning + sign with scissors
	box(n, Vector3(1.6, 0.1, wd * 0.8), Vector3(fx - s * 0.8, 2.85, 0), M(Color(0.15, 0.2, 0.45)), false, Vector3(0, 0, s * 0.3))
	box(n, Vector3(0.12, 0.8, wd * 0.7), Vector3(fx - s * 0.08, 3.6, 0), M(Color(0.1, 0.1, 0.12)))
	var lab := text(n, "BARBER", Vector3(fx - s * 0.16, 3.62, 0), 0.016, Color(1, 1, 1), 2.0, Vector3(0, -s * PI * 0.5, 0))
	lab.scale.x = 1.0
	blade_sign(n, Vector3(fx - s * 0.1, 4.6, -wd * 0.4), s, "BARBER", Color(0.95, 0.95, 0.97), Color(0.9, 0.12, 0.15), night)
	# scissors icon
	var sc := Node3D.new()
	sc.position = Vector3(fx - s * 0.2, 4.6, wd * 0.2)
	n.add_child(sc)
	for k in 2:
		var bl := box(sc, Vector3(0.08, 0.7, 0.06), Vector3(0, 0, 0), G(Color(0.9, 0.9, 1.0), 1.5))
		bl.rotation.z = 0.45 if k == 0 else -0.45
		w._torus(sc, 0.08, 0.14, Vector3(0.18 if k == 0 else -0.18, -0.4, 0), G(Color(0.9, 0.15, 0.2), 1.5), Vector3(PI / 2, 0, 0))
	if night:
		light(n, Vector3(fx - s * 1.5, 2.0, 0), Color(0.7, 0.85, 1.0), 2.0, 8.0)
	bench(n, Vector3(fx - s * 1.4, 0.13, -wd * 0.35), s)
	_upper_windows(n, fx, s, wd, floors, 3.4, 3.0, night)
	return wd + randf_range(0.3, 1.0)


func _upper_windows(n: Node3D, fx: float, s: float, wd: float, floors: int, base: float, fh: float, night: bool) -> void:
	var trim := M(Color(0.96, 0.94, 0.9))
	var glass_day: Material = w.mat(Color(0.45, 0.62, 0.8), Color(0.3, 0.45, 0.65), 0.12, 0.08, 0.5, 0.5)
	var glass_lit: Material = w.mat(Color(1.0, 0.82, 0.52), Color(1.0, 0.82, 0.52), 1.8, 0.2)
	var front := Vector3(-s, 0, 0)
	var fc := Vector3(fx, 0, 0)
	var cols := maxi(2, int((wd - 1.0) / 2.2))
	var deco := {"lintel": true, "lintel_m": M(Color(0.3, 0.25, 0.25))}
	for f in range(1, floors):
		var y := base + (f - 1) * fh + 1.5
		box(n, Vector3(0.22, 0.18, wd + 0.05), Vector3(fx - s * 0.1, base + (f - 1) * fh, 0), trim)
		for k in cols:
			var u := (-wd * 0.5 + 1.1 + k * (wd - 2.2) / maxf(1.0, cols - 1)) * -s
			var d := deco.duplicate()
			d["flowers"] = randf() < 0.3
			window(n, fc, front, u, y, 1.0, 1.4, trim, glass_lit if (night and randf() < 0.6) else glass_day, d)
	# rooftop: water tank / antenna / AC
	var h := base + (floors - 1) * fh
	var rr := randf()
	if rr < 0.35:
		cyl(n, 0.8, 1.4, Vector3(s * 1.0, h + 1.3, 0), M(Color(0.55, 0.4, 0.3)))
		cone(n, 0.9, 0.5, Vector3(s * 1.0, h + 2.25, 0), M(Color(0.35, 0.3, 0.3)))
		for k in 4:
			box(n, Vector3(0.08, 0.7, 0.08), Vector3(s * 1.0 + (0.5 if k % 2 == 0 else -0.5), h + 0.5, 0.5 if k < 2 else -0.5), M(Color(0.3, 0.3, 0.3)))
	elif rr < 0.65:
		cyl(n, 0.04, 3.0, Vector3(s * 0.8, h + 1.8, wd * 0.3), M(Color(0.3, 0.3, 0.35)))
		sph(n, 0.12, Vector3(s * 0.8, h + 3.3, wd * 0.3), G(Color(1, 0.2, 0.2), 3.0, 1.0))
	else:
		box(n, Vector3(1.2, 0.8, 1.2), Vector3(s * 0.5, h + 0.7, -wd * 0.2), M(Color(0.85, 0.85, 0.88), Color.BLACK, 0, 0.4, 0.3))


func food_cart(z: float, s: float) -> float:
	var n := node(Vector3(s * 7.2, 0.13, z), 2.0)
	var c: Color = pick([Color(1.0, 0.4, 0.35), Color(0.3, 0.7, 0.95), Color(1.0, 0.75, 0.25)])
	box(n, Vector3(1.2, 1.0, 2.2), Vector3(0, 0.75, 0), M(c, Color.BLACK, 0, 0.4, 0.2), true)
	box(n, Vector3(1.25, 0.08, 2.3), Vector3(0, 1.27, 0), M(Color(0.9, 0.9, 0.92), Color.BLACK, 0, 0.3, 0.6))
	for k in 2:
		cyl(n, 0.3, 0.1, Vector3(s * 0.62, 0.3, -0.7 + k * 1.4), M(Color(0.1, 0.1, 0.12)), Vector3(0, 0, PI / 2))
	for zz in [-1.0, 1.0]:
		cyl(n, 0.03, 1.3, Vector3(0, 1.9, zz), M(Color(0.3, 0.3, 0.3)))
	for k in 6:
		var sc := Color(1, 1, 1) if k % 2 == 0 else c
		box(n, Vector3(1.6, 0.06, 0.4), Vector3(0, 2.6, -1.0 + k * 0.4), M(sc, sc, 0.1), false, Vector3(0, 0, 0))
	box(n, Vector3(0.1, 0.4, 1.6), Vector3(-s * 0.66, 1.55, 0), G(Color(1, 0.95, 0.8), 1.5))
	text(n, pick(["RAMEN", "TACOS", "BOBA", "DUMPLING", "HOT DOG"]), Vector3(-s * 0.72, 1.55, 0), 0.008, Color(0.9, 0.2, 0.2), 1.2, Vector3(0, -s * PI * 0.5, 0))
	light(n, Vector3(-s * 1.2, 1.9, 0), Color(1.0, 0.8, 0.5), 1.4, 6.0)
	_person(n, Vector3(-s * 1.3, 0, 0.5), s * PI * 0.5)
	return randf_range(4.0, 6.0)


# ---------------------------------------------------------------- skate park extras
func skate_extra(z: float, s: float) -> float:
	var r := randf()
	if r < 0.2:
		# fun box with ledge + rail
		var n := node(Vector3(s * 10.5, 0, z - 3.0), 3.5)
		box(n, Vector3(2.4, 0.7, 5.0), Vector3(0, 0.35, 0), M(Color(0.72, 0.72, 0.75), Color.BLACK, 0, 0.8), true)
		for zz in [-2.5, 2.5]:
			box(n, Vector3(2.4, 0.08, 1.6), Vector3(0, 0.35, zz + (0.7 if zz > 0 else -0.7)), M(Color(0.65, 0.65, 0.68)), false, Vector3(0.42 * signf(zz), 0, 0))
		box(n, Vector3(0.1, 0.1, 5.0), Vector3(s * 1.2, 0.72, 0), M(Color(1, 0.8, 0.2), Color.BLACK, 0, 0.3, 0.8))
		cyl(n, 0.05, 5.0, Vector3(0, 1.1, 0), M(Color(0.85, 0.85, 0.9), Color.BLACK, 0, 0.2, 0.9), Vector3(PI / 2, 0, 0))
		for zz in [-2.2, 2.2]:
			cyl(n, 0.04, 0.4, Vector3(0, 0.9, zz), M(Color(0.3, 0.3, 0.35)))
		return 8.0
	if r < 0.38:
		# stair set with a handrail
		var n2 := node(Vector3(s * 11.0, 0, z - 2.0), 3.0)
		for k in 5:
			box(n2, Vector3(4.0, 0.3, 0.7), Vector3(s * 0.0, 0.15 + k * 0.3, -1.4 + k * 0.7), M(Color(0.75, 0.73, 0.7)), true)
		box(n2, Vector3(4.0, 1.5, 3.0), Vector3(0, 0.75, -3.2), M(Color(0.72, 0.7, 0.68)), true)
		var hr := box(n2, Vector3(0.08, 0.08, 4.0), Vector3(0, 1.8, -0.4), M(Color(1, 0.35, 0.5), Color.BLACK, 0, 0.3, 0.6))
		hr.rotation.x = 0.4
		return 7.0
	if r < 0.56:
		# bleachers with a crowd
		var n3 := node(Vector3(s * 12.0, 0, z - 4.0), 4.5)
		for k in 4:
			box(n3, Vector3(1.0, 0.4, 8.0), Vector3(s * k * 0.9, 0.2 + k * 0.45, 0), M(Color(0.3, 0.55, 0.9) if k % 2 == 0 else Color(0.9, 0.9, 0.95)), true)
			for j in 4:
				if randf() < 0.6:
					_person(n3, Vector3(s * k * 0.9, 0.4 + k * 0.45, -3.0 + j * 2.0 + randf_range(-0.4, 0.4)), -s * PI * 0.5)
		return 10.0
	if r < 0.8:
		# graffiti wall with a big tag
		var n4 := node(Vector3(s * 9.0, 0, z - 4.0), 4.5)
		box(n4, Vector3(0.4, 3.0, 8.0), Vector3(0, 1.5, 0), M(Color(0.85, 0.83, 0.8)), true)
		for k in 8:
			var c: Color = pick([Color(1, 0.3, 0.6), Color(0.2, 0.8, 0.95), Color(1, 0.85, 0.2), Color(0.45, 0.95, 0.35), Color(0.6, 0.35, 1.0)])
			var d := cyl(n4, randf_range(0.4, 1.0), 0.05, Vector3(-s * 0.21, randf_range(0.6, 2.5), randf_range(-3.5, 3.5)), M(c, c, 0.2, 0.7), Vector3(0, 0, PI / 2))
			d.scale.z *= randf_range(1.0, 2.2)
		text(n4, pick(["SKATE", "SHRED", "GRIND", "RUSH", "OLLIE"]), Vector3(-s * 0.24, 1.6, 0), 0.03, pick([Color(1, 0.3, 0.6), Color(0.2, 0.8, 0.95), Color(1, 0.85, 0.2)]), 1.2, Vector3(0, -s * PI * 0.5, 0))
		return 10.0
	# food truck
	var n6 := node(Vector3(s * 11.0, 0, z - 3.0), 3.5)
	var c2: Color = pick([Color(1, 0.55, 0.2), Color(0.3, 0.75, 0.95), Color(0.95, 0.35, 0.5)])
	box(n6, Vector3(2.4, 2.6, 5.5), Vector3(0, 1.6, 0), M(c2, Color.BLACK, 0, 0.4, 0.2), true)
	box(n6, Vector3(0.05, 1.0, 2.6), Vector3(-s * 1.22, 2.0, -0.5), w.mat(Color(1, 0.9, 0.7), Color(1, 0.8, 0.5), 1.0, 0.2))
	box(n6, Vector3(1.2, 0.08, 2.8), Vector3(-s * 1.7, 2.7, -0.5), M(Color(0.95, 0.95, 0.95)), false, Vector3(0, 0, s * 0.3))
	text(n6, "SNACKS", Vector3(-s * 1.25, 3.2, -0.5), 0.014, Color(1, 1, 1), 1.6, Vector3(0, -s * PI * 0.5, 0))
	for wz in [-1.8, 1.8]:
		for wx in [-1.1, 1.1]:
			cyl(n6, 0.4, 0.3, Vector3(wx, 0.4, wz), M(Color(0.1, 0.1, 0.12)), Vector3(0, 0, PI / 2))
	return 9.0


# ---------------------------------------------------------------- 8 turbo highway (moto)
func _highway_tile(n: Node3D, idx: int) -> void:
	var asphalt := Color(0.2, 0.2, 0.23) if idx % 2 == 0 else Color(0.21, 0.21, 0.24)
	box(n, Vector3(8.4, 0.5, TILE), Vector3(0, -0.25, 0), M(asphalt, Color.BLACK, 0.0, 0.85, 0.0, 0.02))
	_ground(n, Color(0.55, 0.5, 0.35))
	# shoulders + solid yellow / white edge lines
	for sd in [-1.0, 1.0]:
		box(n, Vector3(2.2, 0.48, TILE), Vector3(sd * 5.3, -0.24, 0), M(Color(0.28, 0.28, 0.3), Color.BLACK, 0.0, 0.9))
		box(n, Vector3(0.14, 0.02, TILE), Vector3(sd * 4.05, 0.012, 0), G(Color(1.0, 0.8, 0.15) if sd < 0 else Color(0.95, 0.95, 0.95), 0.5))
		# guard rail
		box(n, Vector3(0.1, 0.32, TILE), Vector3(sd * 6.45, 0.62, 0), M(Color(0.8, 0.82, 0.85), Color.BLACK, 0, 0.25, 0.8))
		if idx % 2 == 0:
			box(n, Vector3(0.12, 0.7, 0.12), Vector3(sd * 6.5, 0.35, 0), M(Color(0.5, 0.5, 0.52), Color.BLACK, 0, 0.4, 0.6))
			box(n, Vector3(0.05, 0.1, 0.12), Vector3(sd * 6.38, 0.62, 0.0), G(Color(1.0, 0.6, 0.1), 3.0))
	if idx % 2 == 0:
		var dm := G(Color(0.95, 0.95, 0.95), 0.5)
		box(n, Vector3(0.14, 0.02, 2.2), Vector3(-1.25, 0.012, 0), dm)
		box(n, Vector3(0.14, 0.02, 2.2), Vector3(1.25, 0.012, 0), dm)


func _highway_lamp(n: Node3D, s: float) -> void:
	var pole := M(Color(0.55, 0.57, 0.6), Color.BLACK, 0, 0.3, 0.7)
	n.position.x = s * 7.2
	cyl(n, 0.12, 8.0, Vector3(0, 4.0, 0), pole)
	box(n, Vector3(2.8, 0.1, 0.1), Vector3(-s * 1.35, 7.9, 0), pole, false, Vector3(0, 0, s * 0.08))
	box(n, Vector3(0.8, 0.12, 0.3), Vector3(-s * 2.6, 7.75, 0), pole)
	box(n, Vector3(0.7, 0.04, 0.25), Vector3(-s * 2.6, 7.68, 0), G(Color(1.0, 0.8, 0.5), 4.0))


func _highway_side(z: float, s: float) -> float:
	var r := randf()
	if r < 0.3:
		var n := node(Vector3(s * randf_range(9.0, 14.0), 0, z), 3.0)
		gtree(n, Vector3.ZERO, pick(["palm", "palm", "pine", "oak"]), randf_range(6.0, 9.0))
		if randf() < 0.5:
			gtree(n, Vector3(s * randf_range(2.0, 4.0), 0, randf_range(-2, 2)), "palm", randf_range(5.0, 8.0))
		return randf_range(5.0, 9.0)
	if r < 0.5:
		# billboard
		var n2 := node(Vector3(s * randf_range(11.0, 15.0), 0, z), 3.0)
		var pole := M(Color(0.4, 0.4, 0.42), Color.BLACK, 0, 0.4, 0.6)
		cyl(n2, 0.25, 7.0, Vector3(0, 3.5, 0), pole)
		var bb := Node3D.new()
		bb.position = Vector3(0, 8.5, 0)
		bb.rotation.y = -s * 0.5
		n2.add_child(bb)
		var ad: Array = pick([["SKYLINE COLA", Color(0.9, 0.15, 0.2)], ["TURBO FUEL", Color(1.0, 0.55, 0.1)], ["NEO BANK", Color(0.2, 0.5, 1.0)], ["RUSH  FM  99.1", Color(0.7, 0.3, 1.0)], ["FOX BURGERS", Color(1.0, 0.75, 0.1)]])
		box(bb, Vector3(8.0, 3.4, 0.3), Vector3.ZERO, M(Color(0.15, 0.15, 0.17)), true)
		box(bb, Vector3(7.6, 3.0, 0.05), Vector3(0, 0, 0.17), M(ad[1], ad[1], 0.5, 0.6))
		text(bb, ad[0], Vector3(0, 0.2, 0.22), 0.03, Color(1, 1, 1), 1.5)
		box(bb, Vector3(7.6, 0.3, 0.06), Vector3(0, -1.2, 0.2), G(Color(1, 1, 1), 1.0))
		return randf_range(18.0, 28.0)
	if r < 0.62:
		# gas station
		var n3 := node(Vector3(s * 15.0, 0, z - 6.0), 7.0)
		box(n3, Vector3(8.0, 0.4, 12.0), Vector3(0, 5.0, 0), M(Color(0.95, 0.95, 0.95)), true)
		box(n3, Vector3(8.1, 0.4, 12.1), Vector3(0, 4.7, 0), G(Color(1.0, 0.45, 0.1), 1.2))
		for zz in [-4.0, 4.0]:
			box(n3, Vector3(0.5, 5.0, 0.5), Vector3(0, 2.5, zz), M(Color(0.9, 0.9, 0.92)))
			box(n3, Vector3(0.8, 1.6, 0.6), Vector3(-s * 1.5, 0.8, zz * 0.5), M(Color(0.9, 0.2, 0.2)))
		box(n3, Vector3(6.0, 3.5, 5.0), Vector3(s * 5.0, 1.75, 0), M(Color(0.85, 0.85, 0.8)), true)
		text(n3, "GAS", Vector3(-s * 1.0, 5.6, 6.1), 0.04, Color(1, 0.5, 0.1), 2.0)
		light(n3, Vector3(0, 4.0, 0), Color(1, 0.9, 0.8), 2.0, 12.0)
		return randf_range(22.0, 30.0)
	if r < 0.8:
		# roadside houses / diner
		var n4 := node(Vector3(s * randf_range(14.0, 18.0), 0, z - 4.0), 5.0)
		var c: Color = pick([Color(0.95, 0.85, 0.7), Color(0.75, 0.85, 0.95), Color(0.95, 0.75, 0.75)])
		box(n4, Vector3(6.0, 3.5, 8.0), Vector3(0, 1.75, 0), M(c), true)
		box(n4, Vector3(6.6, 0.3, 8.6), Vector3(0, 3.6, 0), M(c.darkened(0.4)))
		box(n4, Vector3(0.05, 1.4, 5.0), Vector3(-s * 3.02, 1.6, 0), w.mat(Color(1, 0.85, 0.6), Color(1, 0.8, 0.5), 0.6, 0.2))
		blade_sign(n4, Vector3(-s * 3.0, 4.5, 3.0), s, "DINER", Color(0.9, 0.2, 0.3), Color(1, 1, 0.9), true)
		return randf_range(12.0, 18.0)
	var n5 := node(Vector3(s * randf_range(10.0, 13.0), 0, z), 2.0)
	# traffic sign
	cyl(n5, 0.06, 2.6, Vector3(0, 1.3, 0), M(Color(0.6, 0.6, 0.62)))
	var sign_c: Color = pick([Color(0.1, 0.5, 0.25), Color(0.95, 0.75, 0.1), Color(0.85, 0.15, 0.15)])
	box(n5, Vector3(1.2, 1.2, 0.06), Vector3(0, 2.8, 0), M(sign_c, sign_c, 0.3), false, Vector3(0, 0, PI / 4))
	gtree(n5, Vector3(s * 2.5, 0, 1.0), "oak", randf_range(4.0, 6.0))
	return randf_range(6.0, 10.0)


func _highway_over(z: float) -> float:
	var n := node(Vector3(0, 0, z), 1.5)
	var steel := M(Color(0.55, 0.57, 0.6), Color.BLACK, 0, 0.3, 0.7)
	if randf() < 0.25:
		# overpass bridge
		box(n, Vector3(40.0, 1.4, 6.0), Vector3(0, 9.0, 0), M(Color(0.7, 0.7, 0.68)), true)
		box(n, Vector3(40.0, 0.7, 0.3), Vector3(0, 10.1, 3.0), M(Color(0.8, 0.8, 0.78)))
		for sd in [-1.0, 1.0]:
			box(n, Vector3(1.5, 9.0, 4.0), Vector3(sd * 9.0, 4.5, 0), M(Color(0.68, 0.68, 0.66)), true)
		for k in 6:
			box(n, Vector3(0.5, 0.2, 0.2), Vector3(-10.0 + k * 4.0, 8.25, 2.9), G(Color(1.0, 0.8, 0.5), 3.0))
		return randf_range(90.0, 130.0)
	# green gantry sign
	for sd in [-1.0, 1.0]:
		box(n, Vector3(0.35, 8.2, 0.35), Vector3(sd * 7.0, 4.1, 0), steel)
	box(n, Vector3(14.4, 0.3, 0.3), Vector3(0, 7.9, 0), steel)
	box(n, Vector3(14.4, 0.3, 0.3), Vector3(0, 7.3, 0), steel)
	var ex: Array = pick([["EXIT 42  NEO CITY", "->"], ["SKY PORT  3 KM", "^"], ["HARBOR  EXIT 9", "->"], ["DOWNTOWN", "<-"]])
	box(n, Vector3(6.0, 1.8, 0.1), Vector3(-3.2, 7.6, 0.2), M(Color(0.05, 0.4, 0.2), Color(0.05, 0.3, 0.15), 0.3, 0.5))
	box(n, Vector3(6.1, 1.9, 0.05), Vector3(-3.2, 7.6, 0.14), G(Color(1, 1, 1), 0.8))
	text(n, ex[0], Vector3(-3.2, 7.75, 0.28), 0.012, Color(1, 1, 1), 1.2)
	text(n, ex[1], Vector3(-3.2, 7.2, 0.28), 0.018, Color(1, 1, 1), 1.2)
	box(n, Vector3(3.6, 1.4, 0.1), Vector3(3.6, 7.6, 0.2), M(Color(0.1, 0.3, 0.7), Color(0.1, 0.2, 0.5), 0.3, 0.5))
	text(n, "MOTO LANE", Vector3(3.6, 7.6, 0.28), 0.011, Color(1, 1, 1), 1.2)
	return randf_range(60.0, 90.0)


func _highway_far(z: float, s: float) -> void:
	var n := node(Vector3(s * randf_range(30.0, 70.0), 0, z), 15.0)
	if randf() < 0.35:
		var hgt := randf_range(25.0, 55.0)
		cone(n, randf_range(18.0, 30.0), hgt, Vector3(0, hgt * 0.5 - 4.0, 0), M(Color(0.55, 0.38, 0.45), Color.BLACK, 0, 0.9, 0, 0.3))
		return
	for k in randi_range(2, 4):
		var h := randf_range(20.0, 60.0)
		var wd := randf_range(6.0, 10.0)
		var off := Vector3(randf_range(-8, 8), 0, randf_range(-10, 10))
		var c: Color = pick([Color(0.35, 0.3, 0.45), Color(0.45, 0.35, 0.5), Color(0.28, 0.25, 0.38)])
		box(n, Vector3(wd, h, wd), off + Vector3(0, h * 0.5, 0), M(c, Color.BLACK, 0, 0.5, 0.2, 0.3))
		for f in int(h / 3.5):
			if randf() < 0.5:
				box(n, Vector3(wd + 0.05, 0.3, wd * 0.6), off + Vector3(0, f * 3.5 + 2.0, 0), G(Color(1.0, 0.75, 0.4), 1.0))
		sph(n, 0.4, off + Vector3(0, h + 0.5, 0), G(Color(1, 0.2, 0.2), 3.0, 1.0))


# ================================================================ v7 detailed buildings
## One box on a facade. `c` = a point on the wall surface at ground level,
## `nrm` = the wall's outward normal (±X or +Z). u = along the wall, d = out of it.
func fbox(p: Node3D, c: Vector3, nrm: Vector3, u: float, y: float, d: float, su: float, sy: float, sd: float, m: Material, sh := false) -> MeshInstance3D:
	var t := Vector3(-nrm.z, 0, nrm.x)
	var size := Vector3(absf(nrm.x) * sd + absf(t.x) * su, sy, absf(nrm.z) * sd + absf(t.z) * su)
	return box(p, size, c + t * u + nrm * d + Vector3(0, y, 0), m, sh)


func window(p: Node3D, c: Vector3, nrm: Vector3, u: float, y: float, w: float, h: float, trim: Material, glass: Material, deco: Dictionary) -> void:
	fbox(p, c, nrm, u, y, 0.02, w, h, 0.06, glass)
	fbox(p, c, nrm, u, y + h * 0.5 + 0.05, 0.06, w + 0.2, 0.1, 0.14, trim)   # head
	fbox(p, c, nrm, u - w * 0.5 - 0.05, y, 0.06, 0.1, h + 0.1, 0.12, trim)   # jambs
	fbox(p, c, nrm, u + w * 0.5 + 0.05, y, 0.06, 0.1, h + 0.1, 0.12, trim)
	fbox(p, c, nrm, u, y - h * 0.5 - 0.06, 0.1, w + 0.3, 0.1, 0.24, trim)    # sill
	fbox(p, c, nrm, u, y, 0.05, 0.05, h, 0.05, trim)                            # mullion
	fbox(p, c, nrm, u, y + h * 0.12, 0.05, w, 0.05, 0.05, trim)                 # transom
	if deco.get("lintel", false):
		fbox(p, c, nrm, u, y + h * 0.5 + 0.2, 0.08, w + 0.4, 0.16, 0.16, deco["lintel_m"])
	if deco.get("shutters", false):
		for sd in [-1.0, 1.0]:
			fbox(p, c, nrm, u + sd * (w * 0.5 + 0.34), y, 0.05, 0.42, h + 0.05, 0.05, deco["shutter_m"])
			for k in 4:
				fbox(p, c, nrm, u + sd * (w * 0.5 + 0.34), y - h * 0.35 + k * h * 0.23, 0.08, 0.36, 0.04, 0.03, trim)
	if deco.get("flowers", false):
		fbox(p, c, nrm, u, y - h * 0.5 - 0.25, 0.2, w + 0.1, 0.24, 0.3, M(Color(0.55, 0.32, 0.2)))
		for k in 4:
			var fc: Color = pick([Color(1, 0.4, 0.5), Color(1, 0.85, 0.3), Color(0.95, 0.55, 1.0), Color(1, 1, 1)])
			var tt := Vector3(-nrm.z, 0, nrm.x)
			sph(p, 0.13, c + tt * (u - w * 0.4 + k * w * 0.27) + nrm * 0.25 + Vector3(0, y - h * 0.5 - 0.05, 0), M(fc, Color.BLACK, 0, 0.9))
		for k in 3:
			var tt2 := Vector3(-nrm.z, 0, nrm.x)
			sph(p, 0.15, c + tt2 * (u - w * 0.3 + k * w * 0.3) + nrm * 0.2 + Vector3(0, y - h * 0.5 - 0.1, 0), M(Color(0.3, 0.6, 0.3), Color.BLACK, 0, 0.9))
	if deco.get("ac", false):
		fbox(p, c, nrm, u + w * 0.2, y - h * 0.5 - 0.55, 0.3, 0.8, 0.55, 0.55, M(Color(0.9, 0.9, 0.92), Color.BLACK, 0, 0.4, 0.3))
		fbox(p, c, nrm, u + w * 0.2, y - h * 0.5 - 0.55, 0.58, 0.45, 0.4, 0.02, M(Color(0.35, 0.35, 0.4)))


## Detailed town building (cartoon-realistic). o keys: colors, trims, floors
## [min,max], night, roof ("flat"/"tile"), roof_c, awnings, signs, words,
## lanterns, neon, depth.
func facade_building(z: float, s: float, o: Dictionary) -> float:
	var wd := randf_range(6.5, 9.0)
	var dp: float = o.get("depth", randf_range(6.5, 8.0))
	var fl: Array = o.get("floors", [2, 4])
	var floors := randi_range(fl[0], fl[1])
	var gh := 3.8
	var fh := 3.1
	var h := gh + (floors - 1) * fh
	var n := node(Vector3(s * (7.9 + dp * 0.5), 0, z - wd * 0.5), wd)
	var night: bool = o.get("night", false)
	var wall_c: Color = pick(o["colors"])
	var trim_c: Color = pick(o.get("trims", [Color(0.97, 0.95, 0.9), wall_c.lightened(0.45)]))
	var wall := M(wall_c, Color.BLACK, 0, 0.85, 0, 0.12)
	var trim := M(trim_c, Color.BLACK, 0, 0.6, 0, 0.1)
	var dark := M(wall_c.darkened(0.45), Color.BLACK, 0, 0.7)
	var stone := M(Color(0.62, 0.6, 0.58), Color.BLACK, 0, 0.9)
	var glass_day: Material = w.mat(Color(0.45, 0.62, 0.8), Color(0.3, 0.45, 0.65), 0.12, 0.08, 0.5, 0.5)
	var lit_c := Color(1.0, 0.82, 0.52)
	var glass_lit: Material = w.mat(lit_c, lit_c, 1.8, 0.2)
	var front := Vector3(-s, 0, 0)
	var fc := Vector3(-s * dp * 0.5, 0, 0)
	var endn := Vector3(0, 0, 1)
	var ec := Vector3(0, 0, wd * 0.5)
	# body, plinth, corner pilasters
	box(n, Vector3(dp, h, wd), Vector3(0, h * 0.5, 0), wall, true)
	box(n, Vector3(dp + 0.12, 0.5, wd + 0.12), Vector3(0, 0.25, 0), stone)
	for zz in [-wd * 0.5 + 0.22, wd * 0.5 - 0.22]:
		fbox(n, fc, front, zz * -s, h * 0.5, 0.06, 0.44, h, 0.16, trim)
	for xx in [-dp * 0.5 + 0.22, dp * 0.5 - 0.22]:
		fbox(n, ec, endn, xx, h * 0.5, 0.06, 0.44, h, 0.16, trim)
	# floor bands + cornice + parapet
	for f in range(1, floors):
		var y := gh + (f - 1) * fh
		fbox(n, fc, front, 0, y, 0.1, wd + 0.1, 0.2, 0.22, trim)
		fbox(n, ec, endn, 0, y, 0.1, dp + 0.1, 0.2, 0.22, trim)
	var roof: String = o.get("roof", "flat")
	if roof == "flat":
		box(n, Vector3(dp + 0.5, 0.3, wd + 0.5), Vector3(0, h + 0.05, 0), dark)
		box(n, Vector3(dp + 0.3, 0.18, wd + 0.3), Vector3(0, h - 0.25, 0), trim)
		for sd in [-1.0, 1.0]:
			box(n, Vector3(0.25, 0.7, wd), Vector3(sd * (dp * 0.5 - 0.05), h + 0.5, 0), wall)
			box(n, Vector3(0.35, 0.1, wd + 0.1), Vector3(sd * (dp * 0.5 - 0.05), h + 0.88, 0), trim)
		for sd in [-1.0, 1.0]:
			box(n, Vector3(dp, 0.7, 0.25), Vector3(0, h + 0.5, sd * (wd * 0.5 - 0.05)), wall)
			box(n, Vector3(dp + 0.1, 0.1, 0.35), Vector3(0, h + 0.88, sd * (wd * 0.5 - 0.05)), trim)
		_roof_props(n, s, dp, wd, h, night)
	else:
		var rc: Color = o.get("roof_c", Color(0.25, 0.28, 0.35))
		var rm := M(rc, Color.BLACK, 0, 0.6, 0.15)
		box(n, Vector3(dp * 0.62, 0.22, wd + 0.9), Vector3(-dp * 0.24, h + 1.0, 0), rm, true, Vector3(0, 0, 0.5))
		box(n, Vector3(dp * 0.62, 0.22, wd + 0.9), Vector3(dp * 0.24, h + 1.0, 0), rm, true, Vector3(0, 0, -0.5))
		box(n, Vector3(0.3, 0.3, wd + 1.0), Vector3(0, h + 1.72, 0), M(rc.darkened(0.3)))
		box(n, Vector3(dp, 1.6, 0.2), Vector3(0, h + 0.7, wd * 0.5 - 0.1), wall)
		for k in int(wd / 0.9):
			box(n, Vector3(0.08, 0.1, 0.5), Vector3(-s * (dp * 0.5 + 0.25), h + 0.45, -wd * 0.5 + 0.45 + k * 0.9), rm)
	# ---- ground floor storefront
	var sw := wd * 0.58
	var su := wd * 0.12 * -s
	var shop_glass: Material = w.mat(Color(1.0, 0.86, 0.6), Color(1.0, 0.75, 0.45), 1.6 if night else 0.35, 0.1)
	fbox(n, fc, front, su, 1.55, 0.02, sw, 2.3, 0.06, shop_glass)
	for k in int(sw / 1.2) + 1:
		fbox(n, fc, front, su - sw * 0.5 + k * sw / int(sw / 1.2), 1.55, 0.06, 0.1, 2.4, 0.1, dark)
	fbox(n, fc, front, su, 2.75, 0.06, sw + 0.2, 0.14, 0.14, dark)
	fbox(n, fc, front, su, 0.45, 0.07, sw + 0.2, 0.4, 0.12, dark)
	# a peek inside: counter + shelves (not in lite / mobile mode)
	fbox(n, fc, front, su, 0.55, -0.9, sw * 0.8, 1.0, 0.6, M(Color(0.55, 0.38, 0.25)))
	for k in (0 if w.lite else 3):
		fbox(n, fc, front, su, 1.0 + k * 0.5, -2.0, sw * 0.9, 0.06, 0.5, M(Color(0.8, 0.8, 0.82)))
		for j in 5:
			fbox(n, fc, front, su - sw * 0.35 + j * sw * 0.18, 1.12 + k * 0.5, -2.0, 0.18, 0.2, 0.18, M(pick([Color(1, 0.4, 0.3), Color(0.3, 0.7, 1), Color(1, 0.85, 0.3), Color(0.5, 0.9, 0.5)])))
	# door
	var du := (wd * 0.5 - 1.0) * -s
	fbox(n, fc, front, du, 1.25, 0.05, 1.3, 2.6, 0.12, dark)
	fbox(n, fc, front, du, 1.15, 0.09, 1.0, 2.25, 0.06, M(Color(0.45, 0.28, 0.18)))
	fbox(n, fc, front, du, 1.5, 0.12, 0.6, 1.0, 0.03, glass_day if not night else glass_lit)
	fbox(n, fc, front, du + 0.35 * -s, 1.1, 0.15, 0.06, 0.25, 0.06, M(Color(0.9, 0.8, 0.4), Color.BLACK, 0, 0.3, 0.9))
	for sd in [-1.0, 1.0]:
		fbox(n, fc, front, du + sd * 0.85, 2.3, 0.18, 0.18, 0.3, 0.2, G(Color(1.0, 0.85, 0.55), 2.5 if night else 1.0))
	if night:
		light(n, fc + front * 1.2 + Vector3(0, 2.4, 0), Color(1.0, 0.8, 0.5), 1.4, 6.0)
	# awning with stripes + valance
	var aw: Array = o.get("awnings", [[Color(0.9, 0.25, 0.3), Color(0.98, 0.95, 0.9)], [Color(0.2, 0.5, 0.85), Color(0.98, 0.95, 0.9)], [Color(0.2, 0.6, 0.4), Color(0.98, 0.95, 0.9)], [Color(0.95, 0.6, 0.15), Color(0.3, 0.2, 0.15)]])
	var ac: Array = pick(aw)
	var strips: int = 4 if w.lite else 8
	for k in strips:
		var am := M(ac[k % 2], Color.BLACK, 0, 0.8)
		var zz := su - sw * 0.5 - 0.1 + (k + 0.5) * (sw + 0.2) / strips
		box(n, Vector3(1.7, 0.08, (sw + 0.2) / strips + 0.01), fc + front * 0.8 + Vector3(0, 3.05, 0) + Vector3(0, 0, zz * -s), am, false, Vector3(0, 0, s * 0.35))
		box(n, Vector3(0.05, 0.3, (sw + 0.2) / strips + 0.01), fc + front * 1.62 + Vector3(0, 2.62, zz * -s), am)
	# sign board with LED text
	var words: Array = o.get("words", ["SHOP", "CAFE", "BAKERY", "BOOKS", "FLOWERS", "TOYS", "DELI", "MUSIC", "SHOES", "TEA"])
	var sg_c: Color = pick(o.get("signs", [Color(0.95, 0.35, 0.4), Color(0.25, 0.7, 0.9), Color(1, 0.8, 0.3)]))
	var shop_word: String = pick(words)
	if randf() < 0.12:
		shop_word = pick(["ARCADE", "GAMES"])
		# arcade: cabinets glowing behind the shop window
		for k in 3:
			var az := su + (-sw * 0.3 + k * sw * 0.3) * 1.0
			arcade_cabinet(n, fc + front * -1.4 + Vector3(0, 0, az), -s * PI * 0.5)
	fbox(n, fc, front, su, 3.45, 0.12, sw * 0.8, 0.6, 0.16, M(Color(0.12, 0.1, 0.14)))
	fbox(n, fc, front, su, 3.45, 0.15, sw * 0.8 + 0.1, 0.68, 0.1, G(sg_c, 1.6 if night else 0.8))
	text(n, shop_word, fc + front * 0.25 + Vector3(0, 3.45, su), 0.012, Color(1, 1, 1), 2.2, Vector3(0, -s * PI * 0.5, 0))
	if o.get("lanterns", false):
		for k in 2:
			var lz := -wd * 0.25 + k * wd * 0.5
			sph(n, 0.33, fc + front * 1.3 + Vector3(0, 3.0, lz), G(Color(1.0, 0.3, 0.25), 2.5 if night else 0.9), 1.25)
			cyl(n, 0.18, 0.08, fc + front * 1.3 + Vector3(0, 3.42, lz), M(Color(0.9, 0.7, 0.2)))
	# ---- upper floors
	var deco_base := {"lintel_m": dark, "shutter_m": M(pick([Color(0.2, 0.45, 0.35), Color(0.55, 0.25, 0.2), Color(0.25, 0.35, 0.6), Color(0.95, 0.95, 0.9)]))}
	var cols := maxi(2, int((wd - 1.0) / 2.2))
	var shutters := randf() < 0.4
	for f in range(1, floors):
		var y := gh + (f - 1) * fh + 1.55
		var balcony: bool = randf() < (0.1 if w.lite else 0.3)
		for k in cols:
			var u := (-wd * 0.5 + 1.1 + k * (wd - 2.2) / maxf(1.0, cols - 1)) * -s
			var lit := night and randf() < 0.6
			var deco := deco_base.duplicate()
			var rich: bool = not w.lite  # lite (mobile): plain windows
			deco["lintel"] = rich and randf() < 0.5
			deco["shutters"] = rich and shutters and not balcony
			deco["flowers"] = rich and not balcony and randf() < 0.25
			deco["ac"] = rich and o.get("ac", false) and randf() < 0.3
			window(n, fc, front, u, y, 1.05, 1.45, trim, glass_lit if lit else glass_day, deco)
		if balcony:
			var bw := wd * 0.7
			fbox(n, fc, front, 0, y - 0.95, 0.55, bw, 0.14, 1.1, trim)
			fbox(n, fc, front, 0, y - 0.28, 1.05, bw, 0.06, 0.08, dark)
			for k in int(bw / 0.28):
				fbox(n, fc, front, -bw * 0.5 + 0.14 + k * 0.28, y - 0.6, 1.05, 0.04, 0.62, 0.04, dark)
			for k in 3:
				sph(n, 0.28, fc + front * 0.5 + Vector3(0, y - 0.62, (-bw * 0.3 + k * bw * 0.3)), M(Color(0.3, 0.6, 0.32), Color.BLACK, 0, 0.9))
		# end-wall windows (the side you see while approaching)
		for k in 2:
			var eu := -dp * 0.25 + k * dp * 0.5
			var lit2 := night and randf() < 0.5
			window(n, ec, endn, eu, y, 0.95, 1.35, trim, glass_lit if lit2 else glass_day, deco_base)
	# ---- stairs and walkways
	var stairs: String = o.get("stairs", "")
	if stairs == "fire" or (stairs == "" and floors >= 3 and randf() < 0.35):
		fire_escape(n, dp, wd, gh, fh, maxi(floors, 3))
	elif stairs == "gallery" or (stairs == "" and floors >= 2 and randf() < 0.22):
		gallery_walkway(n, s, dp, wd, gh, trim)
	# drain pipe + wall lamp on the end wall
	fbox(n, ec, endn, dp * 0.5 - 0.35, h * 0.5, 0.12, 0.12, h, 0.12, M(Color(0.45, 0.45, 0.5), Color.BLACK, 0, 0.4, 0.6))
	if o.get("neon", false):
		var nc: Color = pick([PINK, CYAN, Color(0.7, 0.4, 1.0), Color(1.0, 0.6, 0.2)])
		fbox(n, fc, front, 0, h - 0.15, 0.15, wd * 0.95, 0.08, 0.06, G(nc, 3.0, 0.5))
		fbox(n, ec, endn, 0, h - 0.15, 0.15, dp * 0.95, 0.08, 0.06, G(nc, 3.0, 0.5))
	if o.get("blade", true) and floors >= 2:
		blade_sign(n, fc + Vector3(0, gh + 1.2, wd * 0.36 * -s), s, pick(words), Color(0.1, 0.08, 0.14), sg_c, night)
	return wd + randf_range(0.2, 0.8)


func _roof_props(n: Node3D, s: float, dp: float, wd: float, h: float, night: bool) -> void:
	var r := randf()
	var metal := M(Color(0.6, 0.62, 0.66), Color.BLACK, 0, 0.35, 0.7)
	if r < 0.3:
		var tp := Vector3(s * dp * 0.15, h, -wd * 0.15)
		for k in 4:
			box(n, Vector3(0.1, 1.4, 0.1), tp + Vector3(0.5 if k % 2 == 0 else -0.5, 0.7, 0.5 if k < 2 else -0.5), metal)
		cyl(n, 0.85, 1.6, tp + Vector3(0, 2.2, 0), M(Color(0.55, 0.38, 0.28), Color.BLACK, 0, 0.8))
		cone(n, 0.95, 0.6, tp + Vector3(0, 3.3, 0), M(Color(0.35, 0.25, 0.22)))
		for k in 3:
			cyl(n, 0.87, 0.06, tp + Vector3(0, 1.6 + k * 0.5, 0), metal)
	elif r < 0.55:
		for k in randi_range(2, 3):
			var p := Vector3(s * randf_range(-1.5, 2.0), h, randf_range(-wd * 0.3, wd * 0.3))
			box(n, Vector3(1.1, 0.8, 1.0), p + Vector3(0, 0.4, 0), M(Color(0.88, 0.88, 0.9), Color.BLACK, 0, 0.4, 0.3))
			cyl(n, 0.35, 0.05, p + Vector3(0, 0.82, 0), M(Color(0.3, 0.3, 0.35)))
		cyl(n, 0.04, 3.0, Vector3(s * 1.0, h + 1.5, wd * 0.3), metal)
		sph(n, 0.1, Vector3(s * 1.0, h + 3.05, wd * 0.3), G(Color(1, 0.2, 0.2), 3.0, 1.0))
	elif r < 0.78:
		# stair hut + skylight
		box(n, Vector3(1.8, 2.2, 2.0), Vector3(s * 1.2, h + 1.1, -wd * 0.2), M(Color(0.8, 0.78, 0.75)), true)
		box(n, Vector3(2.0, 0.15, 2.2), Vector3(s * 1.2, h + 2.25, -wd * 0.2), M(Color(0.35, 0.35, 0.4)))
		box(n, Vector3(1.4, 0.5, 1.6), Vector3(-s * 1.0, h + 0.3, wd * 0.2), w.mat(Color(0.5, 0.7, 0.85), Color(0.4, 0.6, 0.8), 0.3 if not night else 1.2, 0.1, 0.4))
	else:
		# roof garden
		box(n, Vector3(dp * 0.6, 0.4, wd * 0.5), Vector3(0, h + 0.2, 0), M(Color(0.5, 0.35, 0.25)))
		box(n, Vector3(dp * 0.58, 0.05, wd * 0.48), Vector3(0, h + 0.42, 0), M(Color(0.35, 0.6, 0.3), Color.BLACK, 0, 0.9))
		for k in 4:
			sph(n, randf_range(0.35, 0.6), Vector3(randf_range(-dp * 0.25, dp * 0.25), h + 0.8, randf_range(-wd * 0.2, wd * 0.2)), M(pick([Color(0.3, 0.6, 0.3), Color(0.4, 0.7, 0.35), Color(1, 0.6, 0.7)]), Color.BLACK, 0, 0.9))
		bench(n, Vector3(0, h + 0.1, -wd * 0.2), s)


# ============================================================ v9: signs, logos, balloons, ambience
## Fictional brands: [name, logo, main colour, accent colour]
const BRANDS := [
	["SKY CAFE", "cup", Color(0.55, 0.32, 0.2), Color(1.0, 0.85, 0.6)],
	["BURGER BLAST", "burger", Color(0.95, 0.35, 0.15), Color(1.0, 0.85, 0.25)],
	["PIZZA ORBIT", "pizza", Color(0.9, 0.2, 0.2), Color(1.0, 0.8, 0.3)],
	["NEON BEATS", "note", Color(0.55, 0.3, 1.0), Color(0.4, 0.95, 1.0)],
	["LOVE FM 99", "heart", Color(1.0, 0.3, 0.55), Color(1.0, 0.85, 0.9)],
	["STAR MART", "star", Color(0.2, 0.45, 0.95), Color(1.0, 0.85, 0.2)],
	["FROSTY", "icecream", Color(0.4, 0.8, 1.0), Color(1.0, 0.7, 0.85)],
	["DONUT HOLE", "donut", Color(1.0, 0.55, 0.75), Color(0.6, 0.35, 0.2)],
	["FIZZ COLA", "soda", Color(0.85, 0.1, 0.15), Color(1.0, 1.0, 1.0)],
	["VOLT ENERGY", "bolt", Color(0.15, 0.15, 0.2), Color(0.6, 1.0, 0.2)],
]
const SLOGANS := ["OPEN", "SALE", "HOT", "NEW", "FRESH", "24H", "50% OFF", "WELCOME"]


## LED pixel size so `label` fits in `width` metres.
func _fit_px(label: String, width: float, max_px: float) -> float:
	return minf(max_px, width / maxf(1.0, label.length() * 24.0))


## 3D logo made of primitives, facing +Z, about `sc` metres tall, centred on pos.
func logo(p: Node3D, kind: String, pos: Vector3, sc: float, c: Color, c2: Color, glow := 0.6) -> void:
	var m := M(c, c, glow, 0.4, 0.1, 0.3)
	var m2 := M(c2, c2, glow, 0.4, 0.1, 0.3)
	var wh := M(Color(0.97, 0.96, 0.94), Color(1, 1, 1), glow * 0.5, 0.5)
	match kind:
		"cup":
			cyl(p, 0.28 * sc, 0.55 * sc, pos + Vector3(0, -0.05 * sc, 0), wh)
			cyl(p, 0.29 * sc, 0.12 * sc, pos + Vector3(0, 0.0, 0), m)
			box(p, Vector3(0.08, 0.3, 0.08) * sc, pos + Vector3(0.33 * sc, -0.02 * sc, 0), wh)
			box(p, Vector3(0.14, 0.06, 0.08) * sc, pos + Vector3(0.3 * sc, 0.11 * sc, 0), wh)
			box(p, Vector3(0.14, 0.06, 0.08) * sc, pos + Vector3(0.3 * sc, -0.15 * sc, 0), wh)
			cyl(p, 0.45 * sc, 0.05 * sc, pos + Vector3(0, -0.34 * sc, 0), wh)
			for k in 3:
				var st := box(p, Vector3(0.05, 0.28, 0.05) * sc, pos + Vector3((k - 1) * 0.13 * sc, 0.42 * sc, 0), m2)
				st.rotation.z = 0.35 * (1 if k % 2 == 0 else -1)
		"burger":
			sph(p, 0.4 * sc, pos + Vector3(0, 0.12 * sc, 0), M(Color(0.95, 0.65, 0.25)), 0.55)
			box(p, Vector3(0.84, 0.07, 0.84) * sc, pos + Vector3(0, -0.02 * sc, 0), M(Color(1.0, 0.8, 0.1)), false, Vector3(0, 0.78, 0))
			cyl(p, 0.43 * sc, 0.1 * sc, pos + Vector3(0, -0.08 * sc, 0), M(Color(0.4, 0.2, 0.1)))
			cyl(p, 0.44 * sc, 0.04 * sc, pos + Vector3(0, -0.15 * sc, 0), M(Color(0.35, 0.8, 0.25)))
			cyl(p, 0.4 * sc, 0.12 * sc, pos + Vector3(0, -0.24 * sc, 0), M(Color(0.95, 0.65, 0.25)))
			for k in 4:
				sph(p, 0.03 * sc, pos + Vector3((k - 1.5) * 0.12 * sc, 0.26 * sc, 0.28 * sc), wh)
		"pizza":
			var wedge := cone(p, 0.42 * sc, 0.9 * sc, pos, M(Color(1.0, 0.8, 0.35)), Vector3(0, 0, PI))
			wedge.scale.z *= 0.12
			box(p, Vector3(0.9, 0.12, 0.12) * sc, pos + Vector3(0, 0.45 * sc, 0), M(Color(0.85, 0.55, 0.25)))
			for pp in [Vector2(-0.12, 0.2), Vector2(0.14, 0.12), Vector2(0.0, -0.1)]:
				cyl(p, 0.07 * sc, 0.04 * sc, pos + Vector3(pp.x * sc, pp.y * sc, 0.06 * sc), M(Color(0.8, 0.15, 0.1)), Vector3(PI / 2, 0, 0))
		"note":
			sph(p, 0.17 * sc, pos + Vector3(-0.12 * sc, -0.3 * sc, 0), m, 0.8)
			box(p, Vector3(0.06, 0.7, 0.06) * sc, pos + Vector3(0.03 * sc, 0.05 * sc, 0), m)
			box(p, Vector3(0.28, 0.08, 0.06) * sc, pos + Vector3(0.15 * sc, 0.36 * sc, 0), m, false, Vector3(0, 0, -0.4))
		"heart":
			sph(p, 0.22 * sc, pos + Vector3(-0.15 * sc, 0.1 * sc, 0), m)
			sph(p, 0.22 * sc, pos + Vector3(0.15 * sc, 0.1 * sc, 0), m)
			box(p, Vector3(0.42, 0.42, 0.3) * sc, pos + Vector3(0, -0.08 * sc, 0), m, false, Vector3(0, 0, PI / 4))
		"star":
			for k in 5:
				var arm := box(p, Vector3(0.14, 0.42, 0.1) * sc, pos, m)
				arm.rotation.z = TAU * k / 5.0
				arm.position = pos + Vector3(-sin(TAU * k / 5.0), cos(TAU * k / 5.0), 0) * 0.2 * sc
			sph(p, 0.14 * sc, pos, m2)
		"icecream":
			cone(p, 0.2 * sc, 0.55 * sc, pos + Vector3(0, -0.2 * sc, 0), M(Color(0.85, 0.6, 0.3)), Vector3(0, 0, PI))
			sph(p, 0.2 * sc, pos + Vector3(0, 0.12 * sc, 0), m2)
			sph(p, 0.17 * sc, pos + Vector3(0, 0.36 * sc, 0), M(Color(0.98, 0.95, 0.9)))
			sph(p, 0.05 * sc, pos + Vector3(0, 0.55 * sc, 0), M(Color(0.9, 0.1, 0.2)))
		"donut":
			for k in 10:
				var a := TAU * k / 10.0
				sph(p, 0.14 * sc, pos + Vector3(cos(a), sin(a), 0) * 0.27 * sc, m if k % 2 == 0 else M(c.darkened(0.1)))
			for k in 5:
				var a2 := TAU * k / 5.0 + 0.3
				box(p, Vector3(0.08, 0.025, 0.03) * sc, pos + Vector3(cos(a2), sin(a2), 0.9) * 0.27 * sc, m2, false, Vector3(0, 0, a2))
		"soda":
			cyl(p, 0.16 * sc, 0.55 * sc, pos + Vector3(0, -0.1 * sc, 0), m)
			cone(p, 0.16 * sc, 0.2 * sc, pos + Vector3(0, 0.27 * sc, 0), m)
			cyl(p, 0.06 * sc, 0.12 * sc, pos + Vector3(0, 0.42 * sc, 0), wh)
			box(p, Vector3(0.34, 0.16, 0.34) * sc, pos + Vector3(0, -0.1 * sc, 0), wh)
		"bolt":
			box(p, Vector3(0.14, 0.5, 0.1) * sc, pos + Vector3(0.07 * sc, 0.18 * sc, 0), m2, false, Vector3(0, 0, -0.45))
			box(p, Vector3(0.14, 0.5, 0.1) * sc, pos + Vector3(-0.07 * sc, -0.18 * sc, 0), m2, false, Vector3(0, 0, -0.45))
			box(p, Vector3(0.36, 0.1, 0.1) * sc, pos, m2)


## Sidewalk A-frame board: "OPEN", "SALE"... with a little logo on top.
func aframe_sign(p: Node3D, s: float, night: bool) -> void:
	var b: Array = pick(BRANDS)
	var frame := M(Color(0.35, 0.22, 0.14), Color.BLACK, 0.0, 0.8)
	var board := M(Color(0.08, 0.1, 0.09), Color.BLACK, 0.0, 0.9)
	for zz in [-0.18, 0.18]:
		var pn := box(p, Vector3(0.7, 1.1, 0.05), Vector3(s * 0.2, 0.55, zz), board)
		pn.rotation.x = 0.17 * signf(zz)
	box(p, Vector3(0.78, 0.06, 0.45), Vector3(s * 0.2, 1.1, 0), frame)
	var sl: String = pick(SLOGANS)
	text(p, sl, Vector3(s * 0.2, 0.75, 0.24), _fit_px(sl, 0.6, 0.011), Color(1, 1, 1), 1.5 if night else 1.0, Vector3(0.17, 0, 0))
	logo(p, b[1], Vector3(s * 0.2, 1.42, 0), 0.5, b[2], b[3], 0.8 if night else 0.3)


## Roadside logo sign on a pole (fast-food style), lit at night.
func pole_sign(p: Node3D, s: float, night: bool) -> void:
	var b: Array = pick(BRANDS)
	var pole := M(Color(0.55, 0.57, 0.62), Color.BLACK, 0.0, 0.3, 0.7)
	cyl(p, 0.12, 5.6, Vector3(s * 1.4, 2.8, 0), pole)
	var c: Color = b[2]
	var panel := M(c.darkened(0.15), c, 0.35 if night else 0.12, 0.4)
	box(p, Vector3(2.3, 1.6, 0.35), Vector3(s * 1.4, 6.3, 0), panel)
	box(p, Vector3(2.4, 0.1, 0.4), Vector3(s * 1.4, 7.12, 0), G(b[3], 2.5))
	box(p, Vector3(2.4, 0.1, 0.4), Vector3(s * 1.4, 5.48, 0), G(b[3], 2.5))
	logo(p, b[1], Vector3(s * 1.4, 6.45, 0.35), 1.1, b[3], Color(1, 1, 1), 1.2 if night else 0.5)
	text(p, b[0], Vector3(s * 1.4, 5.8, 0.2), _fit_px(b[0], 2.1, 0.011), Color(1, 1, 1), 2.5 if night else 1.5)
	if night:
		light(p, Vector3(s * 1.4, 6.2, 1.5), b[3], 1.4, 7.0)


## Flower bed along the kerb.
func flower_bed(p: Node3D, s: float) -> void:
	box(p, Vector3(0.8, 0.3, 2.4), Vector3(s * 0.4, 0.15, 0), M(Color(0.55, 0.45, 0.38), Color.BLACK, 0, 0.9))
	box(p, Vector3(0.7, 0.05, 2.3), Vector3(s * 0.4, 0.31, 0), M(Color(0.3, 0.5, 0.2)))
	var cols := [Color(1, 0.35, 0.5), Color(1, 0.85, 0.2), Color(0.7, 0.45, 1), Color(1, 1, 1), Color(1, 0.55, 0.2)]
	for k in 9:
		var fc: Color = cols[randi() % cols.size()]
		sph(p, 0.11, Vector3(s * 0.4 + randf_range(-0.25, 0.25), 0.42, -1.0 + k * 0.25), M(fc, fc, 0.15))


## Big billboard on tall posts beyond the first row of buildings.
func billboard(z: float, s: float, night: bool, tall := false) -> void:
	var b: Array = pick(BRANDS)
	var n := node(Vector3(s * randf_range(17.0, 24.0), 0, z), 6.0)
	var steel := M(Color(0.4, 0.4, 0.45), Color.BLACK, 0.0, 0.4, 0.7)
	# in dense towns the board stands high enough to clear the rooftops
	var h := randf_range(17.0, 21.0) if tall else randf_range(11.0, 15.0)
	for xx in [-2.5, 2.5]:
		box(n, Vector3(0.35, h, 0.35), Vector3(xx, h * 0.5, 0), steel)
	box(n, Vector3(8.4, 0.2, 1.0), Vector3(0, h - 0.1, 0.4), steel)
	var c: Color = b[2]
	box(n, Vector3(8.4, 3.8, 0.3), Vector3(0, h + 1.8, 0), M(c.darkened(0.2), c, 0.25 if night else 0.08, 0.5))
	box(n, Vector3(8.6, 0.15, 0.35), Vector3(0, h + 3.75, 0), G(b[3], 2.0))
	box(n, Vector3(8.6, 0.15, 0.35), Vector3(0, h - 0.15, 0), G(b[3], 2.0))
	logo(n, b[1], Vector3(-2.6, h + 1.8, 0.3), 2.8, b[3], Color(1, 1, 1), 1.0 if night else 0.4)
	text(n, b[0], Vector3(1.3, h + 2.3, 0.2), _fit_px(b[0], 5.0, 0.03), Color(1, 1, 1), 2.8 if night else 1.8)
	var sl: String = pick(SLOGANS)
	text(n, sl, Vector3(1.3, h + 1.0, 0.2), _fit_px(sl, 4.0, 0.022), b[3], 2.8 if night else 1.8)
	for xx in [-3.0, 0.0, 3.0]:
		box(n, Vector3(0.3, 0.2, 0.5), Vector3(xx, h, 0.8), G(Color(1, 0.95, 0.8), 3.0))


## Hot-air balloon drifting (bobbing) far over the town.
func hot_air_balloon(z: float, s: float) -> void:
	var n := node(Vector3(s * randf_range(26.0, 75.0), randf_range(20.0, 46.0), z), 10.0)
	var palettes := [[Color(1.0, 0.3, 0.35), Color(1.0, 0.85, 0.25)], [Color(0.3, 0.55, 1.0), Color(1.0, 1.0, 1.0)],
		[Color(0.55, 0.9, 0.35), Color(1.0, 0.55, 0.2)], [Color(0.75, 0.35, 1.0), Color(1.0, 0.6, 0.85)],
		[Color(1.0, 0.55, 0.15), Color(0.2, 0.25, 0.6)], [Color(0.2, 0.85, 0.85), Color(1.0, 0.35, 0.6)]]
	var pal: Array = pick(palettes)
	var r := randf_range(3.2, 4.6)
	var a := M(pal[0], pal[0], 0.1, 0.6)
	var b := M(pal[1], pal[1], 0.1, 0.6)
	# envelope: coloured gores approximated by stacked bands
	for k in 7:
		var t := float(k) / 6.0
		var yy := r * (0.9 - t * 1.7)
		var rad := r * sqrt(maxf(0.02, 1.0 - pow(0.9 - t * 1.7, 2.0) * 0.9))
		cyl(n, rad, r * 0.26, Vector3(0, yy, 0), a if k % 2 == 0 else b)
	sph(n, r * 0.62, Vector3(0, r * 0.95, 0), a, 0.6)
	cone(n, r * 0.45, r * 0.8, Vector3(0, -r * 0.95, 0), b, Vector3(PI, 0, 0))
	var rope := M(Color(0.3, 0.25, 0.2))
	for k in 4:
		var ang := TAU * k / 4.0 + 0.78
		box(n, Vector3(0.05, r * 0.7, 0.05), Vector3(cos(ang) * 0.5, -r * 1.55, sin(ang) * 0.5), rope)
	box(n, Vector3(1.2, 0.9, 1.2), Vector3(0, -r * 1.95, 0), M(Color(0.55, 0.35, 0.2), Color.BLACK, 0, 0.9))
	box(n, Vector3(1.25, 0.12, 1.25), Vector3(0, -r * 1.95 + 0.45, 0), M(Color(0.35, 0.22, 0.12)))
	sph(n, 0.25, Vector3(0, -r * 1.35, 0), G(Color(1.0, 0.6, 0.2), 4.0))
	w.bobbers.append([n, n.position.y, randf_range(0.8, 1.6), randf_range(0.25, 0.45), randf() * TAU])


## A flock of birds circling high up (one spinning node - cheap).
func bird_flock(z: float, s: float) -> void:
	var n := node(Vector3(s * randf_range(10.0, 45.0), randf_range(22.0, 34.0), z), 12.0)
	var flock := Node3D.new()
	n.add_child(flock)
	var bm := M(Color(0.12, 0.1, 0.14))
	for k in randi_range(5, 9):
		var ang := randf() * TAU
		var rr := randf_range(4.0, 9.0)
		var p := Vector3(cos(ang) * rr, randf_range(-1.5, 1.5), sin(ang) * rr)
		for sd in [-1.0, 1.0]:
			var wing := box(flock, Vector3(0.7, 0.05, 0.22), p + Vector3(sd * 0.3, 0.1, 0), bm)
			wing.rotation = Vector3(0, -ang, sd * 0.45)
	w.spinners.append([flock, Vector3(0, 1, 0), randf_range(0.3, 0.6) * (1 if randf() < 0.5 else -1)])
	w.bobbers.append([n, n.position.y, 1.2, 0.5, randf() * TAU])


## Kite on a long string anchored behind the buildings.
func kite(z: float, s: float) -> void:
	var n := node(Vector3(s * randf_range(14.0, 30.0), randf_range(16.0, 26.0), z), 4.0)
	var c: Color = pick([Color(1, 0.3, 0.4), Color(0.3, 0.7, 1), Color(1, 0.85, 0.2), Color(0.6, 1, 0.4), Color(0.8, 0.4, 1)])
	var d := box(n, Vector3(1.6, 1.6, 0.05), Vector3.ZERO, M(c, c, 0.2, 0.6), false, Vector3(0, 0, PI / 4))
	d.scale.y = 1.6
	box(n, Vector3(0.05, 2.2, 0.06), Vector3.ZERO, M(Color(0.3, 0.2, 0.1)))
	for k in 5:
		box(n, Vector3(0.25, 0.12, 0.03), Vector3(sin(k * 1.3) * 0.3, -1.6 - k * 0.55, 0), M(Color.WHITE if k % 2 == 0 else c))
	var st := box(n, Vector3(0.02, n.position.y * 1.1, 0.02), Vector3(-s * 3.0, -n.position.y * 0.5, 0), M(Color(0.9, 0.9, 0.9)))
	st.rotation.z = s * 0.2
	w.bobbers.append([n, n.position.y, 0.7, 1.1, randf() * TAU])


## Advertising blimp with a lit banner.
func blimp(z: float, s: float, night: bool) -> void:
	var n := node(Vector3(s * randf_range(30.0, 70.0), randf_range(34.0, 50.0), z), 14.0)
	var b: Array = pick(BRANDS)
	var hull := M(Color(0.85, 0.86, 0.9), Color.BLACK, 0.0, 0.35, 0.3)
	var body := sph(n, 3.0, Vector3.ZERO, hull)
	body.scale = Vector3(3.0, 3.0, 9.0)
	for sd in [-1.0, 1.0]:
		box(n, Vector3(0.15, 2.4, 2.2), Vector3(sd * 1.1, 1.4, -8.0), M(b[2]), false, Vector3(0, 0, sd * 0.5))
	box(n, Vector3(0.15, 2.8, 2.4), Vector3(0, 2.2, -8.0), M(b[2]))
	box(n, Vector3(1.4, 1.0, 3.0), Vector3(0, -3.3, 0.5), M(Color(0.3, 0.3, 0.35)))
	var side := -s
	box(n, Vector3(0.12, 2.2, 9.0), Vector3(side * 3.02, 0.2, 0), M(b[2].darkened(0.1), b[2], 0.4 if night else 0.1))
	text(n, b[0], Vector3(side * 3.1, 0.3, 0), _fit_px(b[0], 8.0, 0.03), Color(1, 1, 1), 3.0 if night else 1.5, Vector3(0, side * PI / 2, 0))
	w.bobbers.append([n, n.position.y, 1.5, 0.2, randf() * TAU])


## Wind turbine on the hills (blades spin on one node).
func wind_turbine(z: float, s: float) -> void:
	var n := node(Vector3(s * randf_range(35.0, 80.0), 0, z), 10.0)
	var wh := M(Color(0.95, 0.95, 0.97), Color.BLACK, 0.0, 0.4, 0.2)
	var h := randf_range(24.0, 32.0)
	cyl(n, 0.7, h, Vector3(0, h * 0.5, 0), wh)
	box(n, Vector3(1.2, 1.2, 2.6), Vector3(0, h, -0.4), wh)
	var rotor := Node3D.new()
	rotor.position = Vector3(0, h, 1.0)
	n.add_child(rotor)
	sph(rotor, 0.6, Vector3.ZERO, wh)
	for k in 3:
		var blade := box(rotor, Vector3(0.9, 11.0, 0.2), Vector3.ZERO, wh)
		blade.rotation.z = TAU * k / 3.0
		blade.position = Vector3(-sin(TAU * k / 3.0), cos(TAU * k / 3.0), 0) * 5.5
	w.spinners.append([rotor, Vector3(0, 0, 1), randf_range(0.6, 1.2)])


## Harbour lighthouse with a sweeping beam.
func lighthouse(z: float, s: float) -> void:
	var n := node(Vector3(s * randf_range(40.0, 70.0), -4.0, z), 10.0)
	for k in 6:
		cyl(n, 3.0 - k * 0.3, 4.0, Vector3(0, 2.0 + k * 4.0, 0), M(Color(0.95, 0.2, 0.2) if k % 2 == 0 else Color(0.97, 0.97, 0.97)))
	cyl(n, 1.6, 2.5, Vector3(0, 26.0, 0), G(Color(1.0, 0.95, 0.7), 4.0))
	cone(n, 2.0, 2.0, Vector3(0, 28.2, 0), M(Color(0.2, 0.2, 0.25)))
	var head := Node3D.new()
	head.position = Vector3(0, 26.0, 0)
	n.add_child(head)
	var beam: MeshInstance3D = w._beam(head, Vector3.ZERO, 1.5, 60.0, Color(1.0, 0.95, 0.7), 0.25)
	beam.rotation.z = PI / 2
	beam.position = Vector3(30.0, 0, 0)
	w.spinners.append([head, Vector3(0, 1, 0), 0.8])


## Town plaza: fountain + flower beds + benches + a couple of trees.
func plaza(z: float, s: float, t: int) -> float:
	var n := node(Vector3(s * 11.5, 0, z - 5.0), 6.0)
	var stone := M(Color(0.82, 0.8, 0.76), Color.BLACK, 0, 0.8)
	box(n, Vector3(9.0, 0.12, 10.0), Vector3(0, 0.06, 0), M(Color(0.75, 0.72, 0.68), Color.BLACK, 0, 0.9))
	cyl(n, 2.4, 0.6, Vector3(0, 0.3, 0), stone)
	cyl(n, 2.1, 0.08, Vector3(0, 0.58, 0), w.mat(Color(0.35, 0.65, 0.95), Color(0.3, 0.6, 1.0), 0.4, 0.05, 0.3, 0.6))
	cyl(n, 0.35, 1.8, Vector3(0, 1.2, 0), stone)
	cyl(n, 1.0, 0.25, Vector3(0, 2.1, 0), stone)
	for k in 6:
		var a := TAU * k / 6.0
		var jet := box(n, Vector3(0.06, 1.2, 0.06), Vector3(cos(a) * 0.7, 2.6, sin(a) * 0.7), w.mat(Color(0.7, 0.9, 1.0), Color(0.5, 0.8, 1.0), 1.2, 0.1, 0.0, 0.3), false)
		jet.rotation = Vector3(sin(a) * 0.4, 0, -cos(a) * 0.4)
	sph(n, 0.3, Vector3(0, 2.4, 0), w.mat(Color(0.8, 0.95, 1.0), Color(0.6, 0.9, 1.0), 1.5, 0.1))
	for zz in [-3.8, 3.8]:
		bench(n, Vector3(-3.0, 0.12, zz), 1.0)
	var fb := Node3D.new()
	fb.position = Vector3(3.2, 0, 0)
	n.add_child(fb)
	flower_bed(fb, 1.0)
	gtree(n, Vector3(3.5, 0.12, -3.8), _tree_for(t), 4.0)
	gtree(n, Vector3(3.5, 0.12, 3.8), _tree_for(t), 4.5)
	return 13.0


## Extra atmosphere in the far layer, per map (kept sparse for performance).
func far_extras(z: float, t: int) -> void:
	var s := -1.0 if randf() < 0.5 else 1.0
	var night: bool = t == 3 or t == 7
	var r := randf()
	match t:
		0:
			if r < 0.25: hot_air_balloon(z, s)
			elif r < 0.37: bird_flock(z, s)
			elif r < 0.45: blimp(z, s, false)
			elif r < 0.85: sky_setpiece(z)
		1:
			if r < 0.22: hot_air_balloon(z, s)
			elif r < 0.4: billboard(z, s, false, true)
			elif r < 0.52: kite(z, s)
			elif r < 0.6: bird_flock(z, s)
		2:
			if r < 0.2: hot_air_balloon(z, s)
			elif r < 0.4: kite(z, s)
			elif r < 0.55: billboard(z, s, false)
			elif r < 0.62: bird_flock(z, s)
		3:
			if r < 0.35: billboard(z, s, true, true)
			elif r < 0.47: blimp(z, s, true)
		4:
			if r < 0.4: billboard(z, s, false, true)
			elif r < 0.52: blimp(z, s, false)
		5:
			if r < 0.22: hot_air_balloon(z, s)
			elif r < 0.34: lighthouse(z, s)
			elif r < 0.46: wind_turbine(z, s)
			elif r < 0.58: bird_flock(z, s)
			elif r < 0.66: kite(z, s)
		6:
			if r < 0.25: hot_air_balloon(z, s)
			elif r < 0.42: bird_flock(z, s)
			elif r < 0.5: kite(z, s)
		7:
			if r < 0.3: hot_air_balloon(z, s)
			elif r < 0.5: billboard(z, s, true)
			elif r < 0.58: blimp(z, s, true)
		8:
			if r < 0.3: billboard(z, s, false)
			elif r < 0.48: wind_turbine(z, s)
			elif r < 0.56: hot_air_balloon(z, s)


# ============================================================ v9: stairs, walkways, arcade, greenery
## Iron fire-escape zig-zag on the end wall you see while approaching.
func fire_escape(n: Node3D, dp: float, wd: float, gh: float, fh: float, floors: int) -> void:
	var iron := M(Color(0.18, 0.18, 0.22), Color.BLACK, 0, 0.5, 0.6)
	var zf := wd * 0.5 + 0.65
	var run := dp * 0.42
	for f in range(1, floors):
		var y := gh + (f - 1) * fh - 0.1
		box(n, Vector3(dp * 0.7, 0.08, 1.2), Vector3(0, y, zf), iron)
		box(n, Vector3(dp * 0.7, 0.05, 0.05), Vector3(0, y + 1.0, zf + 0.58), iron)
		for k in 7:
			box(n, Vector3(0.04, 1.0, 0.04), Vector3(-dp * 0.35 + k * dp * 0.7 / 6.0, y + 0.5, zf + 0.58), iron)
		if f < floors - 1:
			# stair flight up to the next landing, alternating direction
			var dir := 1.0 if f % 2 == 0 else -1.0
			var ang := atan2(fh, run)
			var flight := box(n, Vector3(sqrt(run * run + fh * fh), 0.06, 0.7), Vector3(0, y + fh * 0.5, zf - 0.15), iron)
			flight.rotation.z = dir * ang
			for k in 8:
				var t := (k + 0.5) / 8.0
				box(n, Vector3(0.24, 0.04, 0.7), Vector3(dir * (-run * 0.5 + run * t), y + fh * t, zf - 0.15), iron)
			var rail := box(n, Vector3(sqrt(run * run + fh * fh), 0.04, 0.04), Vector3(0, y + fh * 0.5 + 0.9, zf + 0.2), iron)
			rail.rotation.z = dir * ang
	# drop ladder to the street
	for k in 6:
		box(n, Vector3(0.5, 0.04, 0.04), Vector3(dp * 0.28, gh - 0.4 - k * 0.45, zf + 0.5), iron)
	for sd in [-1.0, 1.0]:
		box(n, Vector3(0.04, gh - 0.4, 0.04), Vector3(dp * 0.28 + sd * 0.25, (gh - 0.4) * 0.5, zf + 0.5), iron)


## First-floor gallery walkway over the sidewalk + a stair down to the street.
func gallery_walkway(n: Node3D, s: float, dp: float, wd: float, gh: float, trim: Material) -> void:
	var fx := -s * (dp * 0.5 + 0.7)
	var deck := M(Color(0.5, 0.36, 0.26), Color.BLACK, 0, 0.8)
	var rail := M(Color(0.95, 0.95, 0.95), Color.BLACK, 0, 0.4, 0.3)
	box(n, Vector3(1.4, 0.14, wd - 0.4), Vector3(fx, gh, 0), deck, true)
	box(n, Vector3(0.06, 0.06, wd - 0.4), Vector3(fx - s * 0.68, gh + 1.0, 0), rail)
	for k in int((wd - 0.4) / 0.45):
		box(n, Vector3(0.04, 1.0, 0.04), Vector3(fx - s * 0.68, gh + 0.5, -wd * 0.5 + 0.4 + k * 0.45), rail)
	for zz in [-wd * 0.5 + 0.4, wd * 0.5 - 0.4]:
		box(n, Vector3(0.14, gh, 0.14), Vector3(fx - s * 0.6, gh * 0.5, zz), trim)
	# stair flight along the facade, down to the street at the near end
	var run := 3.4
	var st := box(n, Vector3(0.9, 0.08, sqrt(run * run + gh * gh)), Vector3(fx + s * 0.1, gh * 0.5, wd * 0.5 + run * 0.5 - 0.2), deck)
	st.rotation.x = atan2(gh, run)
	for k in 10:
		var t := (k + 0.5) / 10.0
		box(n, Vector3(0.9, 0.05, 0.3), Vector3(fx + s * 0.1, gh * (1.0 - t), wd * 0.5 - 0.2 + run * t), deck)
	var sr := box(n, Vector3(0.04, 0.04, sqrt(run * run + gh * gh)), Vector3(fx - s * 0.35, gh * 0.5 + 0.9, wd * 0.5 + run * 0.5 - 0.2), rail)
	sr.rotation.x = atan2(gh, run)
	for k in 3:
		sph(n, 0.25, Vector3(fx, gh + 0.3, -wd * 0.3 + k * wd * 0.3), M(Color(0.3, 0.6, 0.32), Color.BLACK, 0, 0.9))


## Arcade cabinet for the sidewalk (or inside an arcade shop).
func arcade_cabinet(p: Node3D, pos: Vector3, facing: float) -> void:
	var col: Color = pick([Color(0.9, 0.2, 0.3), Color(0.2, 0.4, 0.95), Color(0.1, 0.1, 0.12), Color(0.95, 0.75, 0.1), Color(0.6, 0.25, 0.85)])
	var body := M(col, Color.BLACK, 0, 0.4, 0.3)
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = facing
	p.add_child(n)
	box(n, Vector3(0.75, 1.8, 0.75), Vector3(0, 0.9, 0), body, true)
	var scr := box(n, Vector3(0.6, 0.5, 0.05), Vector3(0, 1.35, 0.33), G(pick([Color(0.3, 1.0, 0.8), Color(1.0, 0.4, 0.8), Color(0.4, 0.7, 1.0)]), 2.5, 0.6))
	scr.rotation.x = -0.25
	box(n, Vector3(0.7, 0.25, 0.1), Vector3(0, 1.85, 0.33), G(pick([Color(1.0, 0.85, 0.3), Color(1.0, 0.3, 0.4), Color(0.4, 1.0, 0.5)]), 3.0, 0.4))
	box(n, Vector3(0.75, 0.08, 0.35), Vector3(0, 1.02, 0.5), M(col.darkened(0.3)))
	cyl(n, 0.03, 0.15, Vector3(-0.15, 1.12, 0.5), M(Color(0.1, 0.1, 0.1)))
	sph(n, 0.05, Vector3(-0.15, 1.2, 0.5), M(Color(1, 0.2, 0.2)))
	for k in 3:
		cyl(n, 0.04, 0.03, Vector3(0.05 + k * 0.1, 1.07, 0.5), G([Color(1, 0.3, 0.3), Color(0.3, 0.8, 1), Color(1, 0.9, 0.3)][k], 2.0))


## Claw machine: glass box of plushies with the claw on top.
func claw_machine(p: Node3D, pos: Vector3) -> void:
	var frame := M(Color(1.0, 0.45, 0.7), Color.BLACK, 0, 0.35, 0.2)
	box(p, Vector3(1.0, 0.9, 1.0), pos + Vector3(0, 0.45, 0), frame, true)
	box(p, Vector3(0.95, 1.1, 0.95), pos + Vector3(0, 1.45, 0), w.mat(Color(0.7, 0.9, 1.0), Color(0.5, 0.8, 1.0), 0.25, 0.05, 0.3, 0.6))
	box(p, Vector3(1.05, 0.3, 1.05), pos + Vector3(0, 2.15, 0), G(Color(1.0, 0.85, 0.3), 2.0, 0.5))
	for k in 6:
		var c: Color = pick([Color(1, 0.6, 0.7), Color(0.6, 0.85, 1), Color(1, 0.9, 0.5), Color(0.7, 1, 0.6)])
		sph(p, 0.16, pos + Vector3(randf_range(-0.3, 0.3), 1.05, randf_range(-0.3, 0.3)), M(c, c, 0.1))
	box(p, Vector3(0.04, 0.4, 0.04), pos + Vector3(0.15, 1.8, 0.1), M(Color(0.7, 0.7, 0.75), Color.BLACK, 0, 0.2, 0.9))
	for sd in [-1.0, 1.0]:
		box(p, Vector3(0.03, 0.18, 0.03), pos + Vector3(0.15 + sd * 0.07, 1.55, 0.1), M(Color(0.7, 0.7, 0.75), Color.BLACK, 0, 0.2, 0.9), false, Vector3(0, 0, sd * 0.4))


## Sidewalk mini-arcade: two cabinets + a claw machine.
func arcade_corner(n: Node3D, s: float) -> void:
	arcade_cabinet(n, Vector3(s * 1.3, 0, -0.5), -s * PI * 0.5)
	arcade_cabinet(n, Vector3(s * 1.3, 0, 0.35), -s * PI * 0.5)
	claw_machine(n, Vector3(s * 1.4, 0, 1.5))


## Topiary: shaped hedges in stone planters (ball, cone, spiral, cube, bunny).
func topiary(p: Node3D, pos: Vector3) -> void:
	var g := M(pick([Color(0.2, 0.5, 0.25), Color(0.25, 0.55, 0.22), Color(0.18, 0.45, 0.3)]), Color.BLACK, 0, 0.9)
	box(p, Vector3(0.8, 0.5, 0.8), pos + Vector3(0, 0.25, 0), M(Color(0.85, 0.82, 0.76), Color.BLACK, 0, 0.8))
	match randi() % 5:
		0:
			cyl(p, 0.06, 0.6, pos + Vector3(0, 0.8, 0), M(Color(0.4, 0.28, 0.18)))
			sph(p, 0.45, pos + Vector3(0, 1.4, 0), g)
		1:
			cone(p, 0.42, 1.6, pos + Vector3(0, 1.3, 0), g)
		2:
			for k in 3:
				sph(p, 0.4 - k * 0.1, pos + Vector3(0, 0.85 + k * 0.55, 0), g, 0.8)
		3:
			box(p, Vector3(0.7, 0.8, 0.7), pos + Vector3(0, 0.9, 0), g)
		4:
			sph(p, 0.35, pos + Vector3(0, 0.85, 0), g)
			sph(p, 0.24, pos + Vector3(0, 1.3, 0.1), g)
			for sd in [-1.0, 1.0]:
				sph(p, 0.08, pos + Vector3(sd * 0.1, 1.62, 0.05), g, 2.6)


## Grass verge along the kerb with a few tufts (drawn per road tile).
func grass_verge(n: Node3D, t: int) -> void:
	var gc: Color = {1: Color(0.42, 0.66, 0.32), 2: Color(0.45, 0.72, 0.35), 4: Color(0.36, 0.6, 0.35), 6: Color(0.48, 0.72, 0.36), 7: Color(0.5, 0.75, 0.4)}.get(t, Color(0.42, 0.66, 0.32))
	var gm := M(gc, Color.BLACK, 0.0, 0.95)
	var tuft := M(gc.darkened(0.15), Color.BLACK, 0.0, 0.95)
	for sd in [-1.0, 1.0]:
		box(n, Vector3(0.6, 0.04, TILE), Vector3(sd * 4.9, 0.15, 0), gm)
		for k in 2:
			var tz := randf_range(-1.8, 1.8)
			var tx: float = sd * randf_range(4.7, 5.1)
			for j in 3:
				cone(n, 0.06, 0.35, Vector3(tx + (j - 1) * 0.07, 0.3, tz + randf_range(-0.05, 0.05)), tuft, Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)))
		if randf() < 0.25:
			var fc: Color = pick([Color(1, 0.4, 0.6), Color(1, 0.9, 0.3), Color(0.8, 0.6, 1), Color(1, 1, 1)])
			sph(n, 0.07, Vector3(sd * randf_range(4.7, 5.1), 0.25, randf_range(-1.8, 1.8)), M(fc, fc, 0.2))


# ============================================================ v9: Sky Roads beautification
## Overhead pieces for Sky Roads: neon ring gates, star arches, lantern pairs.
func sky_overhead(z: float) -> float:
	var n := node(Vector3(0, 0, z), 2.0)
	var r := randf()
	var cols := [Color(1.0, 0.4, 0.8), Color(0.35, 0.9, 1.0), Color(0.7, 0.5, 1.0), Color(1.0, 0.8, 0.35)]
	if r < 0.4:
		var c: Color = pick(cols)
		w._torus(n, 6.4, 6.9, Vector3(0, 1.0, 0), G(c, 3.0, 1.0))
		for k in 12:
			var a := PI * k / 11.0
			sph(n, 0.22, Vector3(cos(a) * 7.2, 1.0 + sin(a) * 7.2, 0), G(Color(1, 1, 1), 4.0, 1.0))
	elif r < 0.7:
		for k in 15:
			var a := PI * k / 14.0
			var c2: Color = cols[k % cols.size()]
			sph(n, 0.32, Vector3(cos(a) * 6.5, 0.8 + sin(a) * 6.0, 0), G(c2, 3.5, 0.8))
		for sd in [-1.0, 1.0]:
			cyl(n, 0.2, 1.2, Vector3(sd * 6.5, 0.2, 0), M(Color(0.9, 0.85, 1.0)))
	else:
		for sd in [-1.0, 1.0]:
			cyl(n, 0.1, 4.5, Vector3(sd * 4.6, 2.25, 0), M(Color(0.85, 0.8, 0.95), Color.BLACK, 0, 0.3, 0.6))
			var c3: Color = pick(cols)
			sph(n, 0.45, Vector3(sd * 4.6, 4.8, 0), G(c3, 3.0, 1.0), 1.3)
			cyl(n, 0.3, 0.1, Vector3(sd * 4.6, 5.45, 0), M(Color(0.95, 0.85, 0.5)))
	return randf_range(28.0, 42.0)


## Floating mini-islands beside the Sky Road with a lamp, a bench, flowers.
func sky_side(z: float, s: float) -> float:
	var n := node(Vector3(s * randf_range(7.0, 10.0), randf_range(-1.2, 0.8), z), 3.0)
	var rock := M(Color(0.55, 0.42, 0.62), Color.BLACK, 0, 0.9)
	var grass := M(Color(0.55, 0.9, 0.7), Color.BLACK, 0, 0.9)
	var r := randf_range(1.6, 2.4)
	cyl(n, r, 0.4, Vector3(0, -0.2, 0), grass)
	cone(n, r * 0.95, r * 1.6, Vector3(0, -0.4 - r * 0.8, 0), rock, Vector3(PI, 0, 0))
	match randi() % 4:
		0:
			street_lamp(n, Vector3(0, 0, 0), s, Color(1.0, 0.85, 1.0), Color(0.85, 0.8, 0.95), true)
			bench(n, Vector3(s * 0.7, 0, 0.6), s)
		1:
			gtree(n, Vector3.ZERO, pick(["sakura", "gold", "oak"]), randf_range(2.8, 4.0))
			for k in 6:
				var fc: Color = pick([Color(1, 0.5, 0.8), Color(1, 0.9, 0.4), Color(0.7, 0.6, 1)])
				sph(n, 0.1, Vector3(randf_range(-r * 0.7, r * 0.7), 0.1, randf_range(-r * 0.7, r * 0.7)), M(fc, fc, 0.2))
		2:
			topiary(n, Vector3.ZERO)
			topiary(n, Vector3(s * 0.9, 0, 0.9))
		3:
			# little glowing crystal cluster
			for k in 4:
				var gc: Color = pick([Color(0.5, 0.9, 1.0), Color(1.0, 0.5, 0.9), Color(0.7, 0.6, 1.0)])
				var cr := cone(n, 0.25, randf_range(0.8, 1.6), Vector3(randf_range(-0.6, 0.6), 0.5, randf_range(-0.6, 0.6)), G(gc, 2.0, 0.6))
				cr.rotation = Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	w.bobbers.append([n, n.position.y, 0.25, 0.6, randf() * TAU])
	return randf_range(9.0, 16.0)


## Big Sky Roads set pieces (floating village, rainbow, crystal spires, sky whale, waterfall garden).
func sky_setpiece(z: float) -> void:
	var s := -1.0 if randf() < 0.5 else 1.0
	match randi() % 5:
		0:
			var n := node(Vector3(s * randf_range(22.0, 40.0), randf_range(-6.0, 4.0), z), 12.0)
			cyl(n, 7.0, 1.0, Vector3(0, 0, 0), M(Color(0.55, 0.88, 0.62)))
			cone(n, 6.8, 9.0, Vector3(0, -5.0, 0), M(Color(0.5, 0.38, 0.58)), Vector3(PI, 0, 0))
			for k in 4:
				var hx := randf_range(-4.0, 4.0)
				var hz := randf_range(-4.0, 4.0)
				var wc: Color = pick([Color(1, 0.9, 0.85), Color(0.85, 0.9, 1), Color(1, 0.85, 0.95)])
				box(n, Vector3(2.0, 1.8, 2.0), Vector3(hx, 1.4, hz), M(wc))
				cone(n, 1.6, 1.3, Vector3(hx, 2.9, hz), M(pick([Color(0.9, 0.35, 0.45), Color(0.35, 0.5, 0.9), Color(0.55, 0.35, 0.8)])))
				box(n, Vector3(0.5, 0.5, 0.05), Vector3(hx, 1.5, hz + 1.02), G(Color(1.0, 0.85, 0.5), 1.5))
			gtree(n, Vector3(-4.5, 0.5, 3.5), "sakura", 4.0)
			w._beam(n, Vector3(5.0, -30.0, 0), 1.0, 30.5, Color(0.6, 0.85, 1.0), 0.45)
			w.bobbers.append([n, n.position.y, 0.6, 0.3, randf() * TAU])
		1:
			# rainbow arch over the whole road
			var n2 := node(Vector3(0, -8.0, z), 30.0)
			var rb := [Color(1, 0.3, 0.3), Color(1, 0.6, 0.2), Color(1, 0.9, 0.3), Color(0.4, 0.9, 0.4), Color(0.3, 0.6, 1), Color(0.6, 0.4, 1)]
			for k in rb.size():
				w._torus(n2, 28.0 - k * 0.9, 28.8 - k * 0.9, Vector3.ZERO, G(rb[k], 1.2, 0.2))
		2:
			var n3 := node(Vector3(s * randf_range(18.0, 34.0), -12.0, z), 8.0)
			for k in 7:
				var gc: Color = pick([Color(0.5, 0.9, 1.0), Color(1.0, 0.5, 0.9), Color(0.7, 0.6, 1.0)])
				var cr := cone(n3, randf_range(0.8, 1.6), randf_range(8.0, 18.0), Vector3(randf_range(-4, 4), 5.0, randf_range(-4, 4)), G(gc, 1.5, 0.5))
				cr.rotation = Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.25, 0.25))
		3:
			# sky whale gliding past
			var n4 := node(Vector3(s * randf_range(30.0, 55.0), randf_range(14.0, 26.0), z), 14.0)
			var skin := M(Color(0.45, 0.55, 0.95), Color(0.3, 0.4, 0.9), 0.15, 0.6)
			var belly := M(Color(0.92, 0.92, 1.0))
			var b := sph(n4, 4.0, Vector3.ZERO, skin)
			b.scale = Vector3(4.0, 3.2, 9.0)
			var bl := sph(n4, 3.6, Vector3(0, -0.9, 0.5), belly)
			bl.scale = Vector3(3.2, 2.2, 7.5)
			var tail := box(n4, Vector3(6.0, 0.4, 2.2), Vector3(0, 0.8, -10.5), skin)
			tail.rotation.x = 0.2
			for sd in [-1.0, 1.0]:
				var fin := box(n4, Vector3(4.0, 0.3, 1.6), Vector3(sd * 4.5, -1.2, 2.0), skin)
				fin.rotation = Vector3(0, sd * 0.4, sd * -0.4)
				sph(n4, 0.35, Vector3(sd * 3.3, 0.6, 6.5), M(Color(0.05, 0.05, 0.1)))
			for k in 3:
				sph(n4, 0.4 + k * 0.1, Vector3(0, 3.5 + k * 0.9, 4.0), G(Color(0.8, 0.95, 1.0), 1.5, 0.5))
			n4.rotation.y = randf_range(-0.4, 0.4)
			w.bobbers.append([n4, n4.position.y, 1.5, 0.25, randf() * TAU])
		4:
			# floating garden with a waterfall
			var n5 := node(Vector3(s * randf_range(20.0, 32.0), randf_range(2.0, 8.0), z), 8.0)
			cyl(n5, 4.5, 0.8, Vector3.ZERO, M(Color(0.55, 0.9, 0.6)))
			cone(n5, 4.3, 7.0, Vector3(0, -3.9, 0), M(Color(0.5, 0.4, 0.6)), Vector3(PI, 0, 0))
			cyl(n5, 1.6, 0.1, Vector3(-s * 1.2, 0.45, 0), w.mat(Color(0.4, 0.7, 1.0), Color(0.4, 0.7, 1.0), 0.6, 0.05, 0.3))
			w._beam(n5, Vector3(-s * 4.3, -22.0, 0), 0.9, 22.0, Color(0.55, 0.85, 1.0), 0.6)
			for k in 5:
				gtree(n5, Vector3(randf_range(-3, 3), 0.4, randf_range(-3, 3)), pick(["sakura", "gold", "oak", "birch"]), randf_range(2.5, 4.0))
			w.bobbers.append([n5, n5.position.y, 0.5, 0.35, randf() * TAU])
