extends RefCounted
## Vehicles from res://models/cars_src.glb (a kit of 7 untextured vehicles made
## of box / cylinder parts): 3 cars, a minibus, a coach and 2 box trucks.
## Each part is classified (paint, glass, tyre, hub, lights, trim, cargo) and
## every vehicle is merged into ONE flat-shaded mesh drawn with
## shaders/car_kit.gdshader, which "textures" it procedurally: clear-coat
## metallic paint with flakes, door seams, handles and road grime, tinted
## reflective glass, tyre tread, chrome hubs, lamp lenses, number plates and the
## livery artwork (taxi checkers, police / ambulance / school bus / fire truck
## stripes, racing stripes). Lettering (TAXI, POLICE, brand names...) is baked
## into the mesh as LED-pixel quads. One draw call per vehicle, bent with the road.
##
## Vertex data: see car_kit.gdshader.

const SRC := "res://models/cars_src.glb"
const SHADER := preload("res://shaders/car_kit.gdshader")
const ThemesScript := preload("res://scripts/themes.gd")
enum { M_PAINT, M_GLASS, M_TYRE, M_HUB, M_HEAD, M_TAIL, M_TRIM, M_PLATE, M_CHROME, M_CARGO, M_SIGN, M_INK }
const LIVERY_CODE := {"paint": 0, "two": 0, "taxi": 1, "taxi_green": 1, "police": 2, "ambulance": 3, "school": 4,
	"fire": 5, "sport": 6, "icecream": 7, "citybus": 8, "brand": 0, "delivery": 0}
## type -> [x range in the source file, target width in metres, kind]
const TYPES := {
	"sedan": [Vector2(-14.0, -7.8), 1.95, "car"],
	"taxi": [Vector2(-7.8, -2.8), 1.95, "car"],
	"hatch": [Vector2(-2.8, 2.6), 1.95, "car"],
	"minibus": [Vector2(2.6, 8.2), 2.25, "van"],
	"coach": [Vector2(8.2, 14.3), 2.3, "coach"],
	"truck": [Vector2(14.3, 20.5), 2.3, "truck"],
	"truck2": [Vector2(20.5, 27.5), 2.3, "truck"],
}
## Real-world car paints; the first NEUTRALS are the common ones in traffic
## (silver, white, black, greys), then the colours.
const PAINTS := [
	Color(0.62, 0.64, 0.67), Color(0.9, 0.9, 0.89), Color(0.05, 0.05, 0.06), Color(0.24, 0.25, 0.27),
	Color(0.95, 0.94, 0.9), Color(0.42, 0.44, 0.47),
	Color(0.5, 0.05, 0.06), Color(0.08, 0.14, 0.32), Color(0.1, 0.24, 0.16), Color(0.72, 0.66, 0.52),
	Color(0.14, 0.3, 0.6), Color(0.42, 0.27, 0.15), Color(0.8, 0.33, 0.07), Color(0.45, 0.58, 0.7),
	Color(0.75, 0.1, 0.1), Color(0.3, 0.12, 0.3),
]
const NEUTRALS := 6

static var _parts := {}      # type -> Array of [mesh faces (PackedVector3Array), transform, role]
static var _meshes := {}     # livery key -> [ArrayMesh, AABB]
static var _loaded := false
static var _mat: ShaderMaterial


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
	return _mat


## Lite (mobile) mode turns the fake environment reflections off.
static func set_reflections(on: bool) -> void:
	material().set_shader_parameter("reflections", 1.0 if on else 0.0)


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var ps: PackedScene = load(SRC)
	if ps == null:
		return
	var sc: Node3D = ps.instantiate()
	var items := []
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		var t := _global_xf(mi, sc)
		var b: AABB = t * mi.get_aabb()
		items.append([mi, t, b])
	for type in TYPES:
		var r: Vector2 = TYPES[type][0]
		var mine := items.filter(func(it): return it[2].get_center().x >= r.x and it[2].get_center().x < r.y)
		# the biggest boxes are the bodywork; trucks have a cab + a cargo box
		var body_vol := 0.0
		for it in mine:
			body_vol = maxf(body_vol, it[2].get_volume())
		var body_x := 0.0
		for it in mine:
			if it[2].get_volume() == body_vol:
				body_x = it[2].get_center().x
		var parts := []
		for it in mine:
			var mi: MeshInstance3D = it[0]
			var b: AABB = it[2]
			var name: String = mi.name
			var role := "trim"
			var is_cyl := name.begins_with("Cylinder")
			if it[2].get_volume() >= body_vol * 0.2:
				role = "cargo" if (TYPES[type][2] == "truck" and b.size.z > 6.0) else "paint"
			elif is_cyl and b.size.y >= 0.9:
				role = "tyre"
			elif is_cyl:
				role = "light"
			elif name in ["Cube_038"]:
				role = "taxisign"
			elif TYPES[type][2] == "truck" and b.size.y < 0.8 and b.get_center().y > 2.5:
				role = "paint"  # cab roof spoiler
			elif b.size.x > 3.0 and b.size.y > 1.0 and b.size.y < 2.0:
				role = "glass"  # window band
			elif b.size.x < 0.8 and b.size.y > 3.0:
				role = "skip"   # coach side windows: slanted slabs that stick out; painted in the shader instead
			elif b.size.x > 3.0 and b.size.y < 1.0:
				role = "bumper"
			elif absf(b.get_center().x - body_x) > 1.4:
				role = "mirror"
			parts.append([mi.mesh, it[1], role])
		_parts[type] = parts
	sc.free()


static func _global_xf(n: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D()
	var c: Node = n
	while c != null and c != root:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


static func types_of(kind: String) -> Array:
	return TYPES.keys().filter(func(k): return TYPES[k][2] == kind)


## Returns [ArrayMesh, AABB] for a vehicle type + livery.
##   livery: "paint:<i>", "two:<i>:<j>", "sport:<i>", "taxi", "taxi_green", "police",
##           "ambulance", "icecream", "school", "citybus:<i>", "fire", "brand:<i>" (trucks)
static func mesh(type: String, livery: String, hazard: bool, brand_col := Color(0.9, 0.2, 0.2), brand_name := "") -> Array:
	_load()
	var key := "%s|%s|%s|%s|%s" % [type, livery, hazard, brand_col.to_html(), brand_name]
	if _meshes.has(key):
		return _meshes[key]
	if not _parts.has(type) or _parts[type].is_empty():
		return [null, AABB()]
	var lv := livery.split(":")
	if lv.size() < 2:
		lv.append("0")
	var paint := PAINTS[0]
	var paint2 := Color(-1, 0, 0)
	var words := ""
	var bar := false        # roof light bar (police / ambulance / fire)
	match lv[0]:
		"paint", "sport":
			paint = PAINTS[int(lv[1]) % PAINTS.size()]
		"two", "citybus":
			paint = PAINTS[int(lv[1]) % PAINTS.size()]
			if lv.size() > 2:
				paint2 = PAINTS[int(lv[2]) % PAINTS.size()]
		"taxi":
			paint = Color(0.96, 0.7, 0.04)
			words = "TAXI"
		"taxi_green":
			paint = Color(0.2, 0.55, 0.25)
			words = "TAXI"
		"police":
			paint = Color(0.97, 0.97, 0.98)
			words = "POLICE"
			bar = true
		"ambulance":
			paint = Color(0.98, 0.98, 0.96)
			words = "AMBULANCE"
			bar = true
		"icecream":
			paint = Color(1.0, 0.75, 0.85)
			words = "ICE CREAM"
		"school":
			paint = Color(0.96, 0.66, 0.05)
			words = "SCHOOL BUS"
		"fire":
			paint = Color(0.72, 0.05, 0.05)
			words = "FIRE DEPT"
			bar = true
		"brand", "delivery":
			paint = PAINTS[int(lv[1]) % PAINTS.size()]
			words = brand_name
	var liv: int = LIVERY_CODE.get(lv[0], 0)
	var rim := -1.0 if hazard else 0.1
	# bounds of the whole vehicle (source units)
	var full := AABB()
	var first := true
	for p in _parts[type]:
		if p[2] == "taxisign" and lv[0] != "taxi" and lv[0] != "taxi_green":
			continue
		var b: AABB = p[1] * (p[0] as Mesh).get_aabb()
		full = b if first else full.merge(b)
		first = false
	# scale to the bodywork's width (the wing mirrors stick out a lot)
	var body_w := 0.0
	var body_cx := full.get_center().x
	for p in _parts[type]:
		if p[2] == "paint" or p[2] == "cargo":
			var pbb: AABB = p[1] * (p[0] as Mesh).get_aabb()
			if pbb.size.x > body_w:
				body_w = pbb.size.x
				body_cx = pbb.get_center().x
	var width: float = TYPES[type][1]
	var sc: float = width / maxf(body_w, 0.01)
	full.position.x = body_cx - body_w * 0.5
	full.size.x = body_w
	var origin := Vector3(full.get_center().x, full.position.y, full.get_center().z)
	var body_mid := full.position.y + full.size.y * 0.55
	var size := full.size * sc
	# height of the bodywork itself (the taxi roof sign doesn't count)
	var bh := 0.0
	for p in _parts[type]:
		if p[2] == "paint" or p[2] == "cargo":
			var pbb: AABB = p[1] * (p[0] as Mesh).get_aabb()
			bh = maxf(bh, (pbb.end.y - origin.y) * sc)
	# UV2.x = livery + 10 * length(dm) (+ 5000 when the shader paints bus windows)
	var uv2 := Vector2(liv + 10.0 * roundf(size.z * 10.0) + (5000.0 if type == "coach" else 0.0), bh)
	var st_v := PackedVector3Array()
	var st_n := PackedVector3Array()
	var st_c := PackedColorArray()
	var st_uv := PackedVector2Array()
	var st_uv2 := PackedVector2Array()
	# triangles are wound the Godot way (clockwise seen from the front), so
	# the outward normal is (c - a) x (b - a)
	var add_tri := func(a: Vector3, b: Vector3, c: Vector3, col: Color, id: int, rr: float) -> void:
		var nrm := (c - a).cross(b - a).normalized()
		for v in [a, b, c]:
			st_v.append(v)
			st_n.append(nrm)
			st_c.append(col)
			st_uv.append(Vector2(id, rr))
			st_uv2.append(uv2)
	var side_faces: Array = []  # centres of the side bodywork faces (to put lettering on)
	for p in _parts[type]:
		var role: String = p[2]
		if role == "skip" or (role == "taxisign" and lv[0] != "taxi" and lv[0] != "taxi_green"):
			continue
		var faces: PackedVector3Array = (p[0] as Mesh).get_faces()
		var xf: Transform3D = p[1]
		var pb: AABB = xf * (p[0] as Mesh).get_aabb()
		# mirrors: shrink them back against the body side
		var anchor := Vector3.ZERO
		if role == "mirror":
			var sd := signf(pb.get_center().x - body_cx)
			anchor = Vector3(body_cx + sd * body_w * 0.5, pb.get_center().y, pb.get_center().z)
		var front_light: bool = role == "light" and pb.get_center().z > full.get_center().z
		# mirrored parts (negative scale in the kit) have their winding reversed
		var mirrored := xf.basis.determinant() < 0.0
		for i in range(0, faces.size(), 3):
			var va := xf * faces[i]
			var vb := xf * faces[i + 1] if not mirrored else xf * faces[i + 2]
			var vc := xf * faces[i + 2] if not mirrored else xf * faces[i + 1]
			if role == "mirror":
				va = anchor + (va - anchor) * 0.4
				vb = anchor + (vb - anchor) * 0.4
				vc = anchor + (vc - anchor) * 0.4
			var a := (va - origin) * sc
			var b := (vb - origin) * sc
			var c := (vc - origin) * sc
			var nrm := (c - a).cross(b - a).normalized()
			var cy := (a.y + b.y + c.y) / 3.0 / sc + origin.y
			var col := Color(paint, 0.0)
			var id := M_PAINT
			var rr := rim
			match role:
				"paint":
					# cars: the upper band that isn't the roof is the glasshouse
					if TYPES[type][2] == "car" and cy > body_mid and absf(nrm.y) < 0.75:
						id = M_GLASS
					elif paint2.r >= 0.0 and cy > body_mid:
						col = Color(paint2, 0.0)
				"cargo":
					id = M_CARGO
					col = Color(0.95, 0.95, 0.96, 0.0) if lv[0] != "brand" else Color(brand_col, 0.0)
					if lv[0] == "fire":
						col = Color(paint, 0.0)
				"glass":
					id = M_GLASS
				"tyre":
					var cc := (a + b + c) / 3.0
					var wc := (pb.get_center() - origin) * sc
					var rad := Vector2(cc.y - wc.y, cc.z - wc.z).length()
					id = M_HUB if (absf(nrm.x) > 0.7 and rad < pb.size.y * sc * 0.28) else M_TYRE
					rr = 0.0
				"light":
					id = M_HEAD if front_light else M_TAIL
					rr = 0.0
				"taxisign":
					id = M_SIGN
					col = Color(1.0, 0.95, 0.7, 2.5 / 8.0)
					rr = 0.0
				"bumper":
					id = M_TRIM
				"mirror":
					id = M_PAINT
			add_tri.call(a, b, c, col, id, rr)
			if (role == "paint" or role == "cargo") and absf(nrm.x) > 0.6:
				side_faces.append((a + b + c) / 3.0)
	# ---- extras: tail lights, plates, grille, light bars, fire ladder, lettering
	var ext := func(center: Vector3, half: Vector3, col: Color, id: int) -> void:
		var q := [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1),
			Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]
		var v := []
		for k in q:
			v.append(center + k * half)
		for f in [[0, 2, 1], [0, 3, 2], [4, 5, 6], [4, 6, 7], [0, 1, 5], [0, 5, 4], [3, 7, 6], [3, 6, 2], [0, 4, 7], [0, 7, 3], [1, 2, 6], [1, 6, 5]]:
			add_tri.call(v[f[0]], v[f[2]], v[f[1]], col, id, 0.0)
	var back := -size.z * 0.5
	var front := size.z * 0.5
	for sd in [-1.0, 1.0]:
		ext.call(Vector3(sd * size.x * 0.36, size.y * 0.42, back - 0.01), Vector3(size.x * 0.1, size.y * 0.045, 0.03), Color(0.9, 0.05, 0.03, 0.0), M_TAIL)
	ext.call(Vector3(0, size.y * 0.2, back - 0.02), Vector3(0.28, 0.08, 0.02), Color(0.95, 0.95, 0.9, 0.0), M_PLATE)
	ext.call(Vector3(0, size.y * 0.2, front + 0.02), Vector3(0.28, 0.08, 0.02), Color(0.95, 0.95, 0.9, 0.0), M_PLATE)
	ext.call(Vector3(0, size.y * 0.32, front + 0.015), Vector3(size.x * 0.25, size.y * 0.05, 0.02), Color(0.1, 0.1, 0.1, 0.0), M_CHROME)
	if bar:
		var roof := size.y + 0.07
		if lv[0] == "fire" or lv[0] == "ambulance":
			roof = size.y + 0.07
		ext.call(Vector3(-0.28, roof, size.z * (0.28 if lv[0] != "police" else 0.0)), Vector3(0.24, 0.07, 0.13), Color(1.0, 0.1, 0.08, 6.0 / 8.0), M_SIGN)
		ext.call(Vector3(0.28, roof, size.z * (0.28 if lv[0] != "police" else 0.0)), Vector3(0.24, 0.07, 0.13), Color(0.1, 0.3, 1.0, 6.0 / 8.0) if lv[0] != "fire" else Color(1.0, 0.1, 0.08, 6.0 / 8.0), M_SIGN)
	if lv[0] == "fire":
		# ladder on the roof of the fire truck
		for sd in [-1.0, 1.0]:
			ext.call(Vector3(sd * 0.45, size.y + 0.12, -size.z * 0.1), Vector3(0.05, 0.05, size.z * 0.38), Color(0.8, 0.8, 0.82, 0.0), M_CHROME)
		for k in 9:
			ext.call(Vector3(0, size.y + 0.12, -size.z * 0.45 + k * size.z * 0.1), Vector3(0.45, 0.03, 0.03), Color(0.8, 0.8, 0.82, 0.0), M_CHROME)
	if lv[0] == "icecream":
		# giant cone on the roof
		ext.call(Vector3(0, size.y + 0.25, 0.0), Vector3(0.18, 0.25, 0.18), Color(0.85, 0.6, 0.3, 0.0), M_CARGO)
		ext.call(Vector3(0, size.y + 0.62, 0.0), Vector3(0.28, 0.2, 0.28), Color(1.0, 0.6, 0.8, 1.0 / 8.0), M_SIGN)
	# lettering on both sides (and on the taxi roof sign)
	if words != "":
		# on the doors / lower bodywork (below the windows); trucks: on the cargo box
		var kind: String = TYPES[type][2]
		var h_txt := bh * (0.44 if kind == "car" else (0.6 if kind == "truck" else 0.46))
		if lv[0] == "police":
			h_txt = bh * 0.3
		elif lv[0] == "ambulance":
			h_txt = bh * 0.41
		var px := minf(0.0085 if kind == "car" else (0.04 if kind == "truck" else 0.012), size.z * 0.55 / maxf(1.0, words.length() * 24.0))
		var ink := Color(0.05, 0.05, 0.08, 0.0) if lv[0] in ["taxi", "taxi_green", "school", "icecream"] else Color(0.95, 0.95, 0.98, 0.25 / 8.0)
		if lv[0] == "police" or lv[0] == "ambulance":
			ink = Color(0.97, 0.97, 1.0, 0.2 / 8.0)
		if lv[0] == "brand":
			ink = Color(1.0, 1.0, 1.0, 0.4 / 8.0)
		var tz := -size.z * 0.05 if TYPES[type][2] != "truck" else -size.z * 0.18
		# sit the letters just proud of the actual side panel at that spot
		var half_x := size.x * 0.5
		for fc in side_faces:
			if absf(fc.y - h_txt) < 0.35 and absf(fc.z - tz) < size.z * 0.3:
				half_x = maxf(half_x, absf(fc.x))
		for sd in [-1.0, 1.0]:
			_text(words, Vector3(sd * (half_x + 0.015), h_txt, tz), sd, px, ink, add_tri)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = st_v
	arr[Mesh.ARRAY_NORMAL] = st_n
	arr[Mesh.ARRAY_COLOR] = st_c
	arr[Mesh.ARRAY_TEX_UV] = st_uv
	arr[Mesh.ARRAY_TEX_UV2] = st_uv2
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var bb := AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size)
	_meshes[key] = [am, bb]
	return _meshes[key]


## LED-pixel lettering flat on a side of the vehicle (sd = +1 for the +X side).
static func _text(s: String, center: Vector3, sd: float, px: float, col: Color, add_tri: Callable) -> void:
	var u := px * 4.0
	var cols := s.length() * 6 - 1
	var x0 := -cols * u * 0.5
	var y0 := 3.5 * u
	var sz := u * 0.86
	# reading direction along the side: -Z seen from +X, +Z seen from -X
	var right := Vector3(0, 0, -sd)
	for ci in s.length():
		var g: Array = ThemesScript.GLYPHS.get(s[ci], [])
		for row in g.size():
			var line: String = g[row]
			for c in 5:
				if line[c] != "1":
					continue
				var cx := x0 + (ci * 6 + c) * u
				var cy := y0 - row * u
				var p0 := center + right * cx + Vector3(0, cy - sz, 0)
				var p1 := center + right * (cx + sz) + Vector3(0, cy - sz, 0)
				var p2 := center + right * (cx + sz) + Vector3(0, cy, 0)
				var p3 := center + right * cx + Vector3(0, cy, 0)
				# clockwise as seen from outside, on both sides ("right" already
				# points along the reading direction for the side it is on)
				add_tri.call(p0, p2, p1, col, M_INK, 0.0)
				add_tri.call(p0, p3, p2, col, M_INK, 0.0)


## A random livery for a vehicle type (lots of taxis in town).
## A realistic paint index: mostly the neutral colours, sometimes a colour.
static func _pick_paint() -> int:
	return randi() % NEUTRALS if randf() < 0.6 else NEUTRALS + randi() % (PAINTS.size() - NEUTRALS)


static func random_livery(type: String) -> String:
	var kind: String = TYPES[type][2]
	var pc := PAINTS.size()
	match kind:
		"car":
			var r := randf()
			if type == "taxi":
				return "taxi" if randf() < 0.8 else "taxi_green"
			if r < 0.14:
				return "police"
			if r < 0.22:
				return "sport:%d" % _pick_paint()
			if r < 0.3:
				return "two:%d:%d" % [_pick_paint(), randi() % NEUTRALS]
			return "paint:%d" % _pick_paint()
		"van":
			return ["ambulance", "icecream", "paint:%d" % _pick_paint(), "paint:%d" % _pick_paint()][randi() % 4]
		"coach":
			return "school" if randf() < 0.35 else "citybus:%d:2" % (randi() % pc)
		"truck":
			return "fire" if randf() < 0.25 else "brand:%d" % _pick_paint()
	return "paint:%d" % _pick_paint()
