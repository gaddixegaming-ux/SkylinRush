extends Node3D
## Menu lobbies: every runner hangs out in their own detailed place.
##  1 HOOPS - outdoor basketball court at sunset
##  2 ROCKY - boxing gym hall
##  3 PIXEL - cosy bedroom at night (toys, books, desk, fairy lights)
##  4 ACE   - golf course
##  5 CHILL - neon rooftop at night
## Built in a local frame where the menu camera looks from +Z towards -Z,
## then turned to face the real camera. Glossy floors + a reflection probe.

const V := preload("res://scripts/vehicles.gd")
const MT := preload("res://scripts/model_tools.gd")
const CAM_YAW := 2.2  # menu camera orbit angle (camera_rig.gd)

## sky mood per lobby: [top, horizon, sun colour, sun energy, ambient]
const SKY := {
	1: [Color(0.25, 0.3, 0.7), Color(1.0, 0.6, 0.4), Color(1.0, 0.75, 0.55), 1.2, 0.9],
	2: [Color(0.3, 0.35, 0.5), Color(0.75, 0.7, 0.7), Color(1.0, 0.95, 0.9), 0.6, 0.7],
	3: [Color(0.03, 0.04, 0.12), Color(0.15, 0.12, 0.35), Color(0.6, 0.6, 1.0), 0.2, 0.45],
	4: [Color(0.25, 0.55, 1.0), Color(0.8, 0.92, 1.0), Color(1.0, 0.97, 0.9), 1.3, 1.0],
	5: [Color(0.02, 0.02, 0.08), Color(0.3, 0.12, 0.35), Color(0.6, 0.5, 1.0), 0.2, 0.4],
}

var rooms := {}
var themes
var _mats := {}
var blinkers: Array = []
var _t := 0.0


func setup(t) -> void:
	themes = t
	for i in range(1, 6):
		var r := Node3D.new()
		r.rotation.y = CAM_YAW
		r.visible = false
		add_child(r)
		rooms[i] = r
		match i:
			1: _court(r)
			2: _gym(r)
			3: _bedroom(r)
			4: _golf(r)
			5: _rooftop(r)


func show_for(idx: int) -> bool:
	for k in rooms:
		rooms[k].visible = k == idx
	return rooms.has(idx)


func _process(delta: float) -> void:
	_t += delta
	for b in blinkers:
		if is_instance_valid(b[0]):
			var m: StandardMaterial3D = b[0]
			m.emission_energy_multiplier = b[1] * (0.6 + 0.4 * sin(_t * b[2] + b[3]))


# ---------------------------------------------------------------- helpers
func mat(c: Color, rough := 0.7, metal := 0.0, emit := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [c.to_html(), rough, metal, emit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.rim_enabled = true
	m.rim = 0.15
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m


func glow(c: Color, e := 2.5) -> StandardMaterial3D:
	return mat(c, 0.4, 0.0, e)


func box(p: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


func cyl(p: Node3D, r: float, h: float, pos: Vector3, m: Material, rot := Vector3.ZERO, r2 := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r if r2 < 0.0 else r2
	c.height = h
	c.radial_segments = 20
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


func sph(p: Node3D, r: float, pos: Vector3, m: Material, sc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	mi.material_override = m
	mi.position = pos
	mi.scale = sc
	p.add_child(mi)
	return mi


func torus(p: Node3D, ri: float, ro: float, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = ri
	t.outer_radius = ro
	mi.mesh = t
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


func omni(p: Node3D, pos: Vector3, c: Color, e: float, rng: float, shadow := false) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = c
	l.light_energy = e
	l.omni_range = rng
	l.shadow_enabled = shadow
	p.add_child(l)


func probe(p: Node3D, size: Vector3) -> void:
	var rp := ReflectionProbe.new()
	rp.size = size
	rp.position = Vector3(0, size.y * 0.5 - 0.4, -1.0)
	rp.box_projection = true
	rp.update_mode = ReflectionProbe.UPDATE_ONCE
	rp.intensity = 0.8
	p.add_child(rp)


func tree(p: Node3D, pos: Vector3, kind: String, h: float) -> void:
	var parts: Array = V.trees()
	var i := V.tree_index(kind)
	if parts.is_empty() or i < 0:
		cyl(p, 0.2, h * 0.5, pos + Vector3(0, h * 0.25, 0), mat(Color(0.4, 0.28, 0.2)))
		sph(p, h * 0.3, pos + Vector3(0, h * 0.7, 0), mat(Color(0.3, 0.6, 0.3)))
		return
	var part: Dictionary = parts[i]
	var mi := MeshInstance3D.new()
	mi.mesh = part["mesh"]
	mi.material_override = MT.world_material(part["material"])
	mi.position = pos
	mi.scale = Vector3.ONE * (h / (part["size"] as Vector3).y)
	mi.rotation.y = randf() * TAU
	p.add_child(mi)


func person(p: Node3D, pos: Vector3, face: float, top: Color) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = face
	p.add_child(n)
	var pants := mat(Color(0.2, 0.22, 0.3))
	box(n, Vector3(0.17, 0.75, 0.2), Vector3(-0.11, 0.38, 0), pants)
	box(n, Vector3(0.17, 0.75, 0.2), Vector3(0.11, 0.38, 0), pants)
	box(n, Vector3(0.48, 0.62, 0.28), Vector3(0, 1.06, 0), mat(top))
	sph(n, 0.2, Vector3(0, 1.58, 0), mat(Color(0.95, 0.78, 0.62)))


# ---------------------------------------------------------------- 1 HOOPS: outdoor court
func _court(r: Node3D) -> void:
	var floor_m := mat(Color(0.2, 0.42, 0.75), 0.3, 0.1)
	box(r, Vector3(26, 0.1, 22), Vector3(0, -0.05, -4), floor_m)
	box(r, Vector3(6, 0.11, 7), Vector3(0, -0.04, -6.5), mat(Color(0.9, 0.45, 0.2), 0.3))
	var line := mat(Color(0.97, 0.97, 0.97), 0.4)
	for x in [-3.0, 3.0]:
		box(r, Vector3(0.08, 0.12, 7), Vector3(x, -0.03, -6.5), line)
	box(r, Vector3(6.08, 0.12, 0.08), Vector3(0, -0.03, -3.0), line)
	torus(r, 1.75, 1.83, Vector3(0, -0.03, -3.0), line)
	box(r, Vector3(26, 0.12, 0.08), Vector3(0, -0.03, 2.5), line)
	# hoop: pole, backboard, rim, net
	cyl(r, 0.14, 4.0, Vector3(0, 2.0, -10.8), mat(Color(0.2, 0.2, 0.22), 0.3, 0.7))
	box(r, Vector3(0.12, 0.12, 1.0), Vector3(0, 3.9, -10.3), mat(Color(0.2, 0.2, 0.22), 0.3, 0.7))
	box(r, Vector3(1.9, 1.15, 0.06), Vector3(0, 3.95, -9.8), mat(Color(0.95, 0.97, 1.0), 0.1, 0.1))
	box(r, Vector3(0.6, 0.46, 0.07), Vector3(0, 3.75, -9.78), mat(Color(0.9, 0.3, 0.2), 0.4))
	torus(r, 0.22, 0.25, Vector3(0, 3.4, -9.5), mat(Color(1.0, 0.4, 0.1), 0.3, 0.6))
	for k in 10:
		var a := TAU * k / 10.0
		box(r, Vector3(0.015, 0.4, 0.015), Vector3(cos(a) * 0.19, 3.2, -9.5 + sin(a) * 0.19), mat(Color(1, 1, 1)), Vector3(0.2 * sin(a), 0, -0.2 * cos(a)))
	# chain-link fence
	var fence := mat(Color(0.55, 0.58, 0.62), 0.3, 0.8)
	for k in 14:
		cyl(r, 0.05, 3.2, Vector3(-13 + k * 2.0, 1.6, -12.5), fence)
	for y in [0.1, 1.6, 3.15]:
		box(r, Vector3(26, 0.05, 0.05), Vector3(0, y, -12.5), fence)
	for k in 52:
		box(r, Vector3(0.015, 3.1, 0.015), Vector3(-13 + k * 0.5, 1.6, -12.5), fence, Vector3(0, 0, 0.5 if k % 2 else -0.5))
	# graffiti wall, bench, bleachers, lamp, trees, skyline
	box(r, Vector3(0.4, 3.0, 10.0), Vector3(-9.5, 1.5, -6.0), mat(Color(0.88, 0.85, 0.8)))
	for k in 7:
		var c: Color = [Color(1, 0.35, 0.6), Color(0.2, 0.8, 0.95), Color(1, 0.85, 0.2), Color(0.5, 0.95, 0.35)][k % 4]
		sph(r, randf_range(0.5, 1.0), Vector3(-9.28, randf_range(0.7, 2.4), -10.0 + k * 1.3), mat(c, 0.7), Vector3(0.05, 1.0, 1.6))
	themes.text(r, "HOOPS", Vector3(-9.26, 1.6, -6.0), 0.03, Color(1, 0.55, 0.15), 1.5, Vector3(0, PI / 2, 0))
	for k in 3:
		box(r, Vector3(5.0, 0.35, 0.9), Vector3(7.0, 0.2 + k * 0.45, -4.0 - k * 0.9), mat(Color(0.95, 0.95, 0.97) if k % 2 == 0 else Color(0.9, 0.4, 0.2)))
	person(r, Vector3(6.0, 0.65, -4.9), PI, Color(0.3, 0.6, 0.95))
	person(r, Vector3(7.8, 1.1, -5.8), PI, Color(0.95, 0.4, 0.4))
	for x in [-6.0, 6.0]:
		cyl(r, 0.08, 6.0, Vector3(x, 3.0, -11.8), mat(Color(0.2, 0.2, 0.22), 0.3, 0.7))
		box(r, Vector3(0.9, 0.2, 0.4), Vector3(x, 6.0, -11.6), glow(Color(1.0, 0.9, 0.7), 3.0))
		omni(r, Vector3(x, 5.5, -10.5), Color(1.0, 0.85, 0.65), 1.5, 12.0)
	tree(r, Vector3(-11.0, 0, -13.5), "oak", 7.0)
	tree(r, Vector3(10.5, 0, -13.5), "palm", 8.0)
	tree(r, Vector3(13.0, 0, -9.0), "oak", 6.0)
	_skyline(r, -30.0, false)
	sph(r, 0.12, Vector3(1.0, 0.12, -1.5), mat(Color(1.0, 0.5, 0.15), 0.6))


# ---------------------------------------------------------------- 2 ROCKY: boxing gym
func _gym(r: Node3D) -> void:
	box(r, Vector3(20, 0.1, 18), Vector3(0, -0.05, -3), mat(Color(0.18, 0.18, 0.2), 0.35, 0.1))
	box(r, Vector3(5.0, 0.12, 5.0), Vector3(0, -0.04, 0), mat(Color(0.2, 0.3, 0.6), 0.6))
	var brick := mat(Color(0.6, 0.32, 0.26), 0.9)
	var mortar := mat(Color(0.75, 0.72, 0.68), 0.9)
	box(r, Vector3(20, 7, 0.4), Vector3(0, 3.5, -11), brick)
	box(r, Vector3(0.4, 7, 16), Vector3(-10, 3.5, -3), brick)
	for k in 17:
		box(r, Vector3(20, 0.03, 0.41), Vector3(0, 0.2 + k * 0.4, -11), mortar)
		box(r, Vector3(0.41, 0.03, 16), Vector3(-10, 0.2 + k * 0.4, -3), mortar)
	# tall windows with daylight
	for x in [-6.0, 0.0, 6.0]:
		box(r, Vector3(2.4, 3.6, 0.1), Vector3(x, 4.2, -10.75), glow(Color(0.85, 0.92, 1.0), 1.4))
		box(r, Vector3(2.6, 0.12, 0.2), Vector3(x, 2.35, -10.7), mat(Color(0.2, 0.2, 0.22)))
		box(r, Vector3(0.08, 3.6, 0.15), Vector3(x, 4.2, -10.7), mat(Color(0.2, 0.2, 0.22)))
	# boxing ring
	var rz := -6.0
	box(r, Vector3(6.4, 0.9, 6.4), Vector3(4.0, 0.45, rz), mat(Color(0.12, 0.12, 0.15)))
	box(r, Vector3(6.0, 0.08, 6.0), Vector3(4.0, 0.93, rz), mat(Color(0.25, 0.35, 0.75), 0.6))
	for cx in [1.0, 7.0]:
		for cz in [rz - 3.0, rz + 3.0]:
			cyl(r, 0.1, 1.9, Vector3(cx, 1.85, cz), mat(Color(0.8, 0.8, 0.82), 0.2, 0.9))
			box(r, Vector3(0.25, 0.9, 0.25), Vector3(cx, 1.7, cz), mat(Color(0.85, 0.15, 0.15)))
	for k in 3:
		var y := 1.35 + k * 0.4
		var rc: Color = [Color(0.9, 0.15, 0.15), Color(0.95, 0.95, 0.95), Color(0.15, 0.3, 0.85)][k]
		for side in [[Vector3(4.0, y, rz - 3.0), Vector3(6.0, 0.05, 0.05)], [Vector3(4.0, y, rz + 3.0), Vector3(6.0, 0.05, 0.05)],
				[Vector3(1.0, y, rz), Vector3(0.05, 0.05, 6.0)], [Vector3(7.0, y, rz), Vector3(0.05, 0.05, 6.0)]]:
			box(r, side[1], side[0], mat(rc, 0.5))
	# banners, dumbbell rack, bench press, lockers, speed bag
	for k in 3:
		var bc: Color = [Color(0.85, 0.15, 0.2), Color(0.95, 0.75, 0.1), Color(0.15, 0.3, 0.8)][k]
		box(r, Vector3(1.4, 2.4, 0.05), Vector3(-6.0 + k * 3.0, 5.3, -10.7), mat(bc, 0.7))
	themes.text(r, "ROCKY GYM", Vector3(0, 6.6, -10.7), 0.03, Color(1.0, 0.85, 0.3), 2.0)
	box(r, Vector3(3.0, 0.1, 0.6), Vector3(-6.5, 0.9, -8.0), mat(Color(0.25, 0.25, 0.28), 0.3, 0.8))
	box(r, Vector3(3.0, 0.1, 0.6), Vector3(-6.5, 0.45, -8.0), mat(Color(0.25, 0.25, 0.28), 0.3, 0.8))
	for k in 6:
		for y in [0.55, 1.0]:
			var dx := -7.8 + k * 0.52
			cyl(r, 0.1, 0.12, Vector3(dx, y, -8.15), mat(Color(0.1, 0.1, 0.12)), Vector3(PI / 2, 0, 0))
			cyl(r, 0.1, 0.12, Vector3(dx, y, -7.85), mat(Color(0.1, 0.1, 0.12)), Vector3(PI / 2, 0, 0))
			cyl(r, 0.025, 0.3, Vector3(dx, y, -8.0), mat(Color(0.7, 0.7, 0.75), 0.2, 0.9), Vector3(PI / 2, 0, 0))
	box(r, Vector3(0.5, 0.45, 1.5), Vector3(-7.5, 0.4, -4.0), mat(Color(0.1, 0.1, 0.12), 0.5))
	cyl(r, 0.03, 2.0, Vector3(-7.5, 1.3, -4.4), mat(Color(0.7, 0.7, 0.75), 0.2, 0.9), Vector3(0, 0, PI / 2))
	for sd in [-1.0, 1.0]:
		cyl(r, 0.25, 0.08, Vector3(-7.5 + sd * 0.8, 1.3, -4.4), mat(Color(0.1, 0.1, 0.12)), Vector3(0, 0, PI / 2))
	for k in 6:
		box(r, Vector3(0.6, 2.0, 0.55), Vector3(-9.6, 1.0, -9.0 + k * 0.62), mat([Color(0.2, 0.4, 0.8), Color(0.25, 0.45, 0.85)][k % 2], 0.4, 0.5))
		box(r, Vector3(0.05, 0.3, 0.1), Vector3(-9.28, 1.4, -9.0 + k * 0.62), mat(Color(0.8, 0.8, 0.85), 0.2, 0.9))
	for k in 3:
		cyl(r, 0.35, 0.05, Vector3(-3.0 + k * 3.0, 6.8, -5.0), mat(Color(0.2, 0.2, 0.22), 0.3, 0.7))
		cyl(r, 0.3, 0.02, Vector3(-3.0 + k * 3.0, 6.77, -5.0), glow(Color(1.0, 0.95, 0.85), 4.0))
		omni(r, Vector3(-3.0 + k * 3.0, 6.3, -5.0), Color(1.0, 0.92, 0.8), 2.5, 12.0, k == 1)
	probe(r, Vector3(20, 8, 18))


# ---------------------------------------------------------------- 3 PIXEL: bedroom
func _bedroom(r: Node3D) -> void:
	# glossy wooden floor boards
	for k in 16:
		box(r, Vector3(0.6, 0.1, 12), Vector3(-6.0 + k * 0.62, -0.05, -3.0), mat([Color(0.6, 0.4, 0.26), Color(0.56, 0.37, 0.24), Color(0.63, 0.43, 0.28)][k % 3], 0.22))
	var wall := mat(Color(0.55, 0.45, 0.75), 0.85)
	box(r, Vector3(12, 4.2, 0.3), Vector3(0, 2.1, -8.5), wall)
	box(r, Vector3(0.3, 4.2, 10), Vector3(-6.0, 2.1, -3.5), wall)
	box(r, Vector3(12, 0.2, 0.35), Vector3(0, 0.1, -8.35), mat(Color(0.95, 0.95, 0.97)))
	cyl(r, 2.2, 0.03, Vector3(0, 0.01, 0), mat(Color(0.95, 0.55, 0.75), 0.9))
	cyl(r, 1.6, 0.035, Vector3(0, 0.012, 0), mat(Color(0.98, 0.85, 0.92), 0.9))
	# window with the night city
	box(r, Vector3(3.2, 2.0, 0.1), Vector3(-1.0, 2.4, -8.32), glow(Color(0.12, 0.1, 0.3), 1.0))
	for k in 14:
		box(r, Vector3(0.12, 0.12, 0.05), Vector3(-2.4 + randf() * 2.8, 1.6 + randf() * 1.5, -8.26), glow(Color(1.0, 0.85, 0.5), 2.5))
	var frame := mat(Color(0.97, 0.97, 0.97))
	box(r, Vector3(3.4, 0.12, 0.2), Vector3(-1.0, 3.45, -8.28), frame)
	box(r, Vector3(3.4, 0.12, 0.3), Vector3(-1.0, 1.35, -8.25), frame)
	box(r, Vector3(0.1, 2.0, 0.2), Vector3(-1.0, 2.4, -8.28), frame)
	# bed with blanket and pillows
	box(r, Vector3(2.4, 0.5, 3.6), Vector3(3.8, 0.35, -6.4), mat(Color(0.55, 0.38, 0.28), 0.6))
	box(r, Vector3(2.3, 0.3, 3.4), Vector3(3.8, 0.75, -6.4), mat(Color(0.97, 0.97, 1.0), 0.9))
	box(r, Vector3(2.35, 0.12, 2.4), Vector3(3.8, 0.94, -5.9), mat(Color(0.45, 0.35, 0.85), 0.9))
	for x in [3.3, 4.3]:
		sph(r, 0.35, Vector3(x, 1.05, -7.7), mat(Color(1.0, 0.8, 0.9), 0.9), Vector3(1.2, 0.5, 0.8))
	box(r, Vector3(2.5, 1.3, 0.2), Vector3(3.8, 1.0, -8.25), mat(Color(0.55, 0.38, 0.28), 0.6))
	# bookshelf full of books
	var shelf := mat(Color(0.95, 0.93, 0.9), 0.6)
	box(r, Vector3(0.4, 3.0, 2.6), Vector3(-5.6, 1.5, -5.5), shelf)
	for y in [0.4, 1.1, 1.8, 2.5]:
		box(r, Vector3(0.42, 0.06, 2.6), Vector3(-5.55, y, -5.5), shelf)
		var z := -6.7
		while z < -4.35:
			var bw := randf_range(0.06, 0.12)
			var bh := randf_range(0.42, 0.6)
			box(r, Vector3(0.3, bh, bw), Vector3(-5.5, y + 0.03 + bh * 0.5, z), mat(Color.from_hsv(randf(), 0.6, 0.85), 0.7))
			z += bw + 0.01
	# desk with monitor + RGB keyboard, chair
	box(r, Vector3(2.4, 0.08, 1.0), Vector3(-3.5, 1.0, -7.8), mat(Color(0.2, 0.2, 0.24), 0.4))
	for x in [-4.6, -2.4]:
		box(r, Vector3(0.06, 1.0, 0.9), Vector3(x, 0.5, -7.8), mat(Color(0.2, 0.2, 0.24), 0.4))
	box(r, Vector3(1.2, 0.7, 0.05), Vector3(-3.5, 1.55, -8.1), glow(Color(0.3, 0.6, 1.0), 1.8))
	box(r, Vector3(0.9, 0.04, 0.3), Vector3(-3.5, 1.06, -7.6), glow(Color(1.0, 0.3, 0.8), 2.0))
	box(r, Vector3(0.6, 0.08, 0.6), Vector3(-3.4, 0.6, -6.9), mat(Color(0.9, 0.2, 0.4), 0.5))
	box(r, Vector3(0.6, 0.8, 0.08), Vector3(-3.4, 1.0, -6.6), mat(Color(0.9, 0.2, 0.4), 0.5))
	# posters, fairy lights, lamp, plant
	for k in 3:
		var pc: Color = [Color(1.0, 0.45, 0.7), Color(0.35, 0.85, 1.0), Color(1.0, 0.8, 0.3)][k]
		box(r, Vector3(0.9, 1.2, 0.03), Vector3(1.5 + k * 1.2, 2.7, -8.33), mat(pc, 0.8, 0.0, 0.4))
		box(r, Vector3(0.6, 0.6, 0.02), Vector3(1.5 + k * 1.2, 2.8, -8.3), mat(Color(1, 1, 1), 0.8))
	for k in 24:
		var fl := glow(Color.from_hsv(float(k) / 24.0, 0.5, 1.0), 3.0)
		sph(r, 0.05, Vector3(-5.5 + k * 0.45, 3.8 - 0.15 * sin(k * 0.8), -8.3), fl)
		blinkers.append([fl, 3.0, 2.0, k * 0.7])
	cyl(r, 0.2, 0.05, Vector3(5.6, 0.03, -3.0), mat(Color(0.2, 0.2, 0.22), 0.3, 0.7))
	cyl(r, 0.03, 1.6, Vector3(5.6, 0.8, -3.0), mat(Color(0.2, 0.2, 0.22), 0.3, 0.7))
	cyl(r, 0.2, 0.35, Vector3(5.6, 1.7, -3.0), glow(Color(1.0, 0.85, 0.6), 2.0), Vector3.ZERO, 0.32)
	omni(r, Vector3(5.4, 1.8, -3.2), Color(1.0, 0.75, 0.5), 2.5, 8.0, true)
	omni(r, Vector3(-3.5, 2.0, -7.0), Color(0.4, 0.5, 1.0), 1.5, 6.0)
	omni(r, Vector3(0, 3.5, -6.0), Color(0.9, 0.5, 1.0), 1.2, 9.0)
	cyl(r, 0.3, 0.5, Vector3(-5.2, 0.25, -1.5), mat(Color(0.85, 0.5, 0.35)))
	for k in 5:
		sph(r, 0.3, Vector3(-5.2 + randf_range(-0.2, 0.2), 0.7 + k * 0.12, -1.5 + randf_range(-0.2, 0.2)), mat(Color(0.3, 0.6, 0.3)))
	# toys: teddy bear, rubik cube, toy car, ball, blocks
	var bear := mat(Color(0.7, 0.45, 0.28), 0.95)
	sph(r, 0.3, Vector3(4.5, 1.25, -7.2), bear, Vector3(1, 1.1, 0.9))
	sph(r, 0.22, Vector3(4.5, 1.7, -7.2), bear)
	for sd in [-1.0, 1.0]:
		sph(r, 0.08, Vector3(4.5 + sd * 0.16, 1.88, -7.2), bear)
		sph(r, 0.1, Vector3(4.5 + sd * 0.28, 1.25, -7.05), bear)
	var cols := [Color(1, 0.2, 0.2), Color(0.2, 0.5, 1), Color(1, 0.85, 0.1), Color(0.2, 0.8, 0.3), Color(1, 0.5, 0.1), Color(1, 1, 1)]
	for k in 9:
		box(r, Vector3(0.09, 0.09, 0.09), Vector3(2.5 + (k % 3) * 0.1, 0.05 + 0.1 * (k / 3), 1.8), mat(cols[k % 6], 0.4))
	box(r, Vector3(0.5, 0.18, 0.25), Vector3(-2.5, 0.12, 2.2), mat(Color(0.9, 0.15, 0.2), 0.3, 0.4))
	for x in [-2.65, -2.35]:
		for z in [2.1, 2.3]:
			cyl(r, 0.06, 0.04, Vector3(x, 0.06, z), mat(Color(0.1, 0.1, 0.1)), Vector3(0, 0, PI / 2))
	sph(r, 0.25, Vector3(3.0, 0.25, 0.5), mat(Color(0.2, 0.6, 1.0), 0.4))
	for k in 4:
		box(r, Vector3(0.3, 0.3, 0.3), Vector3(-3.0 + k * 0.1, 0.15 + (0.3 if k == 3 else 0.0), 0.8 + (k % 2) * 0.35), mat(cols[k], 0.5))
	probe(r, Vector3(12, 4.5, 11))


# ---------------------------------------------------------------- 4 ACE: golf course
func _golf(r: Node3D) -> void:
	box(r, Vector3(80, 0.1, 60), Vector3(0, -0.05, -20), mat(Color(0.35, 0.62, 0.3), 0.9))
	for k in 6:
		box(r, Vector3(80, 0.11, 2.5), Vector3(0, -0.045, 3.0 - k * 5.0), mat(Color(0.4, 0.7, 0.35), 0.9))
	# the green with a flag, bunker, pond
	cyl(r, 5.0, 0.12, Vector3(4.0, -0.02, -16.0), mat(Color(0.45, 0.78, 0.4), 0.8))
	cyl(r, 0.06, 0.1, Vector3(4.0, 0.03, -16.0), mat(Color(0.1, 0.1, 0.1)))
	cyl(r, 0.025, 2.4, Vector3(4.0, 1.2, -16.0), mat(Color(0.95, 0.95, 0.95)))
	box(r, Vector3(0.7, 0.45, 0.02), Vector3(4.35, 2.2, -16.0), mat(Color(0.95, 0.2, 0.2)))
	sph(r, 3.0, Vector3(-5.0, -0.2, -10.0), mat(Color(0.93, 0.85, 0.62), 0.95), Vector3(1.4, 0.1, 0.8))
	sph(r, 5.0, Vector3(-9.0, -0.1, -20.0), mat(Color(0.25, 0.5, 0.8), 0.05, 0.3), Vector3(1.5, 0.02, 0.9))
	# rolling hills + trees
	for k in 6:
		sph(r, randf_range(8, 14), Vector3(-30 + k * 12, -6, -38 - randf() * 6), mat(Color(0.3, 0.55, 0.3), 0.95), Vector3(1.5, 0.7, 1.0))
	for k in 10:
		tree(r, Vector3(-18 + k * 4.0 + randf_range(-1, 1), 0, -26 - randf() * 4), ["oak", "pine", "birch", "gold"][k % 4], randf_range(6, 10))
	tree(r, Vector3(-9.0, 0, -6.0), "oak", 7.0)
	tree(r, Vector3(10.0, 0, -7.0), "pine", 8.0)
	# clubhouse
	var ch := Node3D.new()
	ch.position = Vector3(14.0, 0, -18.0)
	r.add_child(ch)
	box(ch, Vector3(8, 3.5, 6), Vector3(0, 1.75, 0), mat(Color(0.96, 0.94, 0.88)))
	box(ch, Vector3(9, 0.3, 7), Vector3(0, 3.6, 0), mat(Color(0.3, 0.4, 0.3)))
	box(ch, Vector3(0.05, 1.6, 5.0), Vector3(-4.02, 1.5, 0), mat(Color(0.5, 0.7, 0.85), 0.1, 0.4))
	themes.text(ch, "CLUBHOUSE", Vector3(-4.1, 3.2, 0), 0.012, Color(0.2, 0.4, 0.2), 0.3, Vector3(0, -PI / 2, 0))
	# golf cart + bag
	var cart := Node3D.new()
	cart.position = Vector3(5.5, 0, -3.5)
	cart.rotation.y = 0.6
	r.add_child(cart)
	box(cart, Vector3(1.3, 0.5, 2.2), Vector3(0, 0.55, 0), mat(Color(0.95, 0.95, 0.95), 0.3))
	box(cart, Vector3(1.2, 0.08, 1.8), Vector3(0, 1.9, 0.1), mat(Color(0.2, 0.5, 0.3)))
	for x in [-0.55, 0.55]:
		for z in [-0.8, 0.8]:
			cyl(cart, 0.03, 1.35, Vector3(x, 1.25, z), mat(Color(0.3, 0.3, 0.3)))
			cyl(cart, 0.25, 0.15, Vector3(x * 1.1, 0.25, z), mat(Color(0.1, 0.1, 0.1)), Vector3(0, 0, PI / 2))
	box(cart, Vector3(1.1, 0.5, 0.4), Vector3(0, 0.95, 0.5), mat(Color(0.2, 0.3, 0.6)))
	cyl(cart, 0.2, 0.9, Vector3(0.3, 1.1, 1.1), mat(Color(0.8, 0.2, 0.2)), Vector3(0.2, 0, 0))
	omni(r, Vector3(2, 3, 2), Color(1, 0.97, 0.9), 0.6, 10.0)


# ---------------------------------------------------------------- 5 CHILL: neon rooftop
func _rooftop(r: Node3D) -> void:
	box(r, Vector3(18, 0.1, 16), Vector3(0, -0.05, -3.5), mat(Color(0.3, 0.3, 0.34), 0.2, 0.2))
	for k in 9:
		box(r, Vector3(18, 0.11, 0.04), Vector3(0, -0.04, -11 + k * 2.0), mat(Color(0.22, 0.22, 0.25), 0.5))
	var para := mat(Color(0.5, 0.5, 0.55), 0.8)
	box(r, Vector3(18, 1.1, 0.4), Vector3(0, 0.55, -11.5), para)
	box(r, Vector3(0.4, 1.1, 16), Vector3(-9.0, 0.55, -3.5), para)
	box(r, Vector3(18.2, 0.12, 0.6), Vector3(0, 1.15, -11.5), mat(Color(0.7, 0.7, 0.72)))
	# big neon sign on a frame
	var frame := mat(Color(0.2, 0.2, 0.22), 0.3, 0.8)
	for x in [-3.0, 3.0]:
		cyl(r, 0.08, 4.5, Vector3(x, 2.25, -10.5), frame)
	box(r, Vector3(6.8, 1.8, 0.2), Vector3(0, 4.2, -10.5), mat(Color(0.08, 0.06, 0.12)))
	themes.text(r, "CHILL", Vector3(0, 4.2, -10.35), 0.045, Color(1.0, 0.3, 0.8), 3.5)
	var nb := glow(Color(0.3, 0.9, 1.0), 3.0)
	box(r, Vector3(6.6, 0.06, 0.05), Vector3(0, 3.35, -10.35), nb)
	box(r, Vector3(6.6, 0.06, 0.05), Vector3(0, 5.05, -10.35), nb)
	blinkers.append([nb, 3.0, 1.3, 0.0])
	omni(r, Vector3(0, 4.0, -9.0), Color(1.0, 0.4, 0.85), 2.5, 10.0)
	# water tank, AC units, antenna, couch, speaker, plants, string lights
	var tank := Node3D.new()
	tank.position = Vector3(-6.0, 0, -8.5)
	r.add_child(tank)
	for k in 4:
		cyl(tank, 0.08, 2.0, Vector3(0.7 if k % 2 == 0 else -0.7, 1.0, 0.7 if k < 2 else -0.7), frame)
	cyl(tank, 1.1, 2.0, Vector3(0, 3.0, 0), mat(Color(0.55, 0.38, 0.28), 0.8))
	cyl(tank, 1.2, 0.8, Vector3(0, 4.3, 0), mat(Color(0.3, 0.25, 0.22)), Vector3.ZERO, 0.02)
	for k in 3:
		box(r, Vector3(1.2, 0.9, 1.0), Vector3(5.0 + k * 1.4, 0.45, -9.8), mat(Color(0.85, 0.86, 0.9), 0.4, 0.3))
		cyl(r, 0.35, 0.05, Vector3(5.0 + k * 1.4, 0.92, -9.8), mat(Color(0.2, 0.2, 0.22)))
	cyl(r, 0.05, 6.0, Vector3(7.5, 3.0, -6.0), frame)
	var ab := glow(Color(1.0, 0.1, 0.1), 5.0)
	sph(r, 0.12, Vector3(7.5, 6.05, -6.0), ab)
	blinkers.append([ab, 5.0, 4.0, 0.0])
	var couch := mat(Color(0.35, 0.3, 0.6), 0.8)
	box(r, Vector3(3.0, 0.45, 1.0), Vector3(-5.5, 0.3, -4.0), couch, Vector3(0, 0.3, 0))
	box(r, Vector3(3.0, 0.8, 0.3), Vector3(-5.8, 0.75, -4.5), couch, Vector3(0, 0.3, 0))
	box(r, Vector3(0.8, 1.2, 0.7), Vector3(3.8, 0.6, -6.5), mat(Color(0.1, 0.1, 0.12)))
	cyl(r, 0.28, 0.05, Vector3(3.8, 0.8, -6.14), mat(Color(0.2, 0.2, 0.25)), Vector3(PI / 2, 0, 0))
	for k in 30:
		var t := float(k) / 29.0
		var bl := glow(Color(1.0, 0.85, 0.5), 3.0)
		sph(r, 0.06, Vector3(-8.5 + t * 17.0, 3.2 - 0.6 * sin(t * PI), -7.0 + sin(t * 3.0) * 0.3), bl)
		if k % 3 == 0:
			blinkers.append([bl, 3.0, 1.5, k])
	for x in [-8.0, 8.0]:
		cyl(r, 0.06, 3.3, Vector3(x, 1.65, -7.0), frame)
	for k in 3:
		cyl(r, 0.35, 0.6, Vector3(-8.3, 0.3, -1.0 + k * 1.2), mat(Color(0.75, 0.45, 0.35)))
		sph(r, 0.45, Vector3(-8.3, 0.9, -1.0 + k * 1.2), mat(Color(0.25, 0.55, 0.3)))
	omni(r, Vector3(-5.0, 2.5, -4.0), Color(1.0, 0.8, 0.5), 1.5, 8.0)
	_skyline(r, -22.0, true)
	probe(r, Vector3(18, 6, 16))


## City silhouette with lit windows behind a lobby.
func _skyline(r: Node3D, z: float, night: bool) -> void:
	for k in 22:
		var x := -40.0 + k * 3.8 + randf_range(-1, 1)
		var h := randf_range(8.0, 34.0)
		var w := randf_range(3.0, 5.5)
		var zz := z - randf_range(0, 12)
		var c := Color(0.12, 0.1, 0.22) if night else Color(0.55, 0.5, 0.7)
		box(r, Vector3(w, h, w), Vector3(x, h * 0.5 - 1.0, zz), mat(c, 0.8))
		for f in int(h / 2.5):
			if randf() < (0.55 if night else 0.3):
				box(r, Vector3(w * randf_range(0.2, 0.7), 0.5, 0.05), Vector3(x + randf_range(-w * 0.2, w * 0.2), 1.5 + f * 2.5, zz + w * 0.51),
					glow(Color(1.0, 0.8, 0.5) if night else Color(0.8, 0.9, 1.0), 2.5 if night else 0.6))
		if night and randf() < 0.3:
			var bc := glow([Color(1, 0.3, 0.8), Color(0.3, 0.9, 1), Color(0.7, 0.4, 1)][randi() % 3], 3.0)
			box(r, Vector3(w + 0.1, 0.25, w + 0.1), Vector3(x, h - 1.2, zz), bc)
