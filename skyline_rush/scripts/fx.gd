extends Node3D
## Lightweight particle bursts and shockwave rings (scroll with the world).

var parts: Array = []
var rings: Array = []
var _cube: BoxMesh
var _torus: TorusMesh
var _mats := {}


func _ready() -> void:
	_cube = BoxMesh.new()
	_cube.size = Vector3.ONE
	_torus = TorusMesh.new()
	_torus.inner_radius = 0.9
	_torus.outer_radius = 1.0
	_torus.rings = 48
	_torus.ring_segments = 8


func _mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 3.0
	_mats[key] = m
	return m


func burst(pos: Vector3, color: Color, count: int, spd: float, size: float, life: float, grav := 18.0) -> void:
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = _cube
		mi.material_override = _mat(color)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = pos + Vector3(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4), randf_range(-0.4, 0.4))
		mi.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		var s := size * randf_range(0.6, 1.2)
		mi.scale = Vector3(s, s, s)
		add_child(mi)
		var v := Vector3(randf_range(-1, 1), randf_range(0.2, 1.3), randf_range(-1, 1)).normalized() * spd * randf_range(0.5, 1.0)
		var l := life * randf_range(0.7, 1.1)
		parts.append({"n": mi, "v": v, "life": l, "max": l, "g": grav, "s": s})


func sparkle(pos: Vector3, color: Color) -> void:
	burst(pos, color, 5, 5.0, 0.12, 0.35, 0.0)


func ring(pos: Vector3, color: Color, to_radius: float, dur: float, forward := 0.0, flat := false) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _torus
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation.x = 0.0 if flat else PI / 2
	mi.scale = Vector3.ONE * 0.5
	add_child(mi)
	rings.append({"n": mi, "m": m, "t": 0.0, "dur": dur, "r": to_radius, "fwd": forward})


func tick(delta: float, dz: float) -> void:
	var keep := []
	for p in parts:
		var n: MeshInstance3D = p["n"]
		p["life"] -= delta
		if p["life"] <= 0.0:
			n.queue_free()
			continue
		p["v"].y -= p["g"] * delta
		n.position += p["v"] * delta + Vector3(0, 0, dz)
		n.rotate_y(delta * 6.0)
		var k: float = p["life"] / p["max"]
		n.scale = Vector3.ONE * p["s"] * k
		keep.append(p)
	parts = keep

	var keep_r := []
	for r in rings:
		var n: MeshInstance3D = r["n"]
		r["t"] += delta
		var k: float = r["t"] / r["dur"]
		if k >= 1.0:
			n.queue_free()
			continue
		var e := 1.0 - pow(1.0 - k, 3.0)
		n.scale = Vector3.ONE * maxf(0.3, e * r["r"])
		n.position.z -= r["fwd"] * delta
		var m: StandardMaterial3D = r["m"]
		m.albedo_color.a = 1.0 - k
		keep_r.append(r)
	rings = keep_r
