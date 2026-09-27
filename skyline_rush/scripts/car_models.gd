extends RefCounted
## Vehicles from res://models/cars_src.glb (a kit of 7 untextured vehicles made
## of box / cylinder parts): 3 cars, a minibus, a coach and 2 box trucks.
## Each part is classified (paint, glass, tyre, hub, light, trim, cargo) and
## every vehicle is merged into ONE flat-shaded, vertex-coloured mesh for the
## curved-world shader (world_vc.gdshader) - one draw call per vehicle, and it
## bends with the road. Liveries: plain paint, two-tone, taxi, police, and
## delivery trucks carrying the town's brands.
##
## Vertex data (see world_vc.gdshader): COLOR.rgb albedo, COLOR.a glow / 8,
## UV2 = (roughness, metallic), UV = (beat pulse, rim; negative = red hazard rim).

const SRC := "res://models/cars_src.glb"
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
const PAINTS := [
	Color(0.85, 0.1, 0.12), Color(0.1, 0.32, 0.9), Color(0.97, 0.97, 0.98), Color(0.08, 0.08, 0.1),
	Color(0.1, 0.62, 0.38), Color(0.98, 0.55, 0.08), Color(0.55, 0.2, 0.75), Color(0.95, 0.75, 0.1),
	Color(0.35, 0.8, 0.95), Color(0.95, 0.4, 0.6), Color(0.55, 0.57, 0.62), Color(0.45, 0.25, 0.15),
]

static var _parts := {}      # type -> Array of [mesh faces (PackedVector3Array), transform, role]
static var _meshes := {}     # livery key -> [ArrayMesh, AABB]
static var _loaded := false


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
				role = "glass"  # coach side windows
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
##   livery: "paint:<i>", "two:<i>:<j>", "taxi", "police", "brand:<i>" (trucks)
static func mesh(type: String, livery: String, hazard: bool, brand_col := Color(0.9, 0.2, 0.2)) -> Array:
	_load()
	var key := "%s|%s|%s|%s" % [type, livery, hazard, brand_col.to_html()]
	if _meshes.has(key):
		return _meshes[key]
	if not _parts.has(type) or _parts[type].is_empty():
		return [null, AABB()]
	var paint := PAINTS[0]
	var paint2 := Color(-1, 0, 0)
	var lv := livery.split(":")
	match lv[0]:
		"paint":
			paint = PAINTS[int(lv[1]) % PAINTS.size()]
		"two":
			paint = PAINTS[int(lv[1]) % PAINTS.size()]
			paint2 = PAINTS[int(lv[2]) % PAINTS.size()]
		"taxi":
			paint = Color(1.0, 0.78, 0.05)
		"police":
			paint = Color(0.97, 0.97, 0.98)
			paint2 = Color(0.05, 0.08, 0.2)
		"brand":
			paint = PAINTS[int(lv[1]) % PAINTS.size()]
	var rim := -1.0 if hazard else 0.12
	# bounds of the whole vehicle (source units)
	var full := AABB()
	var first := true
	for p in _parts[type]:
		if p[2] == "taxisign" and lv[0] != "taxi":
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
	var st_v := PackedVector3Array()
	var st_n := PackedVector3Array()
	var st_c := PackedColorArray()
	var st_uv := PackedVector2Array()
	var st_uv2 := PackedVector2Array()
	var add_tri := func(a: Vector3, b: Vector3, c: Vector3, col: Color, rough: float, metal: float, rr: float) -> void:
		var nrm := (b - a).cross(c - a).normalized()
		for v in [a, b, c]:
			st_v.append(v)
			st_n.append(nrm)
			st_c.append(col)
			st_uv.append(Vector2(0.0, rr))
			st_uv2.append(Vector2(rough, metal))
	for p in _parts[type]:
		var role: String = p[2]
		if role == "taxisign" and lv[0] != "taxi":
			continue
		var faces: PackedVector3Array = (p[0] as Mesh).get_faces()
		var xf: Transform3D = p[1]
		var pb: AABB = xf * (p[0] as Mesh).get_aabb()
		# mirrors: shrink them back against the body side
		var anchor := Vector3.ZERO
		if role == "mirror":
			var side := signf(pb.get_center().x - body_cx)
			anchor = Vector3(body_cx + side * body_w * 0.5, pb.get_center().y, pb.get_center().z)
		for i in range(0, faces.size(), 3):
			var va := xf * faces[i]
			var vb := xf * faces[i + 1]
			var vc := xf * faces[i + 2]
			if role == "mirror":
				va = anchor + (va - anchor) * 0.4
				vb = anchor + (vb - anchor) * 0.4
				vc = anchor + (vc - anchor) * 0.4
			var a := (va - origin) * sc
			var b := (vb - origin) * sc
			var c := (vc - origin) * sc
			var nrm := (b - a).cross(c - a).normalized()
			var cy := (a.y + b.y + c.y) / 3.0 / sc + origin.y
			var col := paint
			var rough := 0.22
			var metal := 0.55
			var rr := rim
			match role:
				"paint":
					# cars: the upper band that isn't roof reads as the windows
					if TYPES[type][2] == "car" and cy > body_mid and absf(nrm.y) < 0.75:
						col = Color(0.08, 0.1, 0.16)
						rough = 0.05
						metal = 0.8
					elif paint2.r >= 0.0 and (cy > body_mid if lv[0] == "two" else cy < full.position.y + full.size.y * 0.35):
						col = paint2
				"cargo":
					col = Color(0.95, 0.95, 0.96) if lv[0] != "brand" else brand_col
					rough = 0.5
					metal = 0.1
				"glass":
					col = Color(0.08, 0.11, 0.18)
					rough = 0.05
					metal = 0.8
				"tyre":
					# dark rubber, with a chrome hub in the middle of the side faces
					var cc := (a + b + c) / 3.0
					var wc := (pb.get_center() - origin) * sc
					var rad := Vector2(cc.y - wc.y, cc.z - wc.z).length()
					if absf(nrm.x) > 0.7 and rad < pb.size.y * sc * 0.28:
						col = Color(0.8, 0.82, 0.86)
						rough = 0.15
						metal = 0.95
					else:
						col = Color(0.05, 0.05, 0.06)
						rough = 0.8
						metal = 0.0
					rr = 0.0
				"light":
					col = Color(1.0, 0.95, 0.8, 5.0 / 8.0)
					rough = 0.3
					metal = 0.0
					rr = 0.0
				"taxisign":
					col = Color(1.0, 0.9, 0.3, 3.0 / 8.0)
					rr = 0.0
				"bumper":
					col = Color(0.12, 0.12, 0.14)
					rough = 0.4
					metal = 0.4
				"mirror":
					col = paint.darkened(0.2)
			if role != "light" and role != "taxisign":
				col.a = 0.0  # COLOR.a is glow / 8 in world_vc
			add_tri.call(a, b, c, col, rough, metal, rr)
	# extras: tail lights, number plates, police light bar
	var size := full.size * sc
	var ext := func(center: Vector3, half: Vector3, col: Color, rough := 0.4, metal := 0.0, rr := 0.0) -> void:
		var p := [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1),
			Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]
		var v := []
		for q in p:
			v.append(center + q * half)
		for f in [[0, 2, 1], [0, 3, 2], [4, 5, 6], [4, 6, 7], [0, 1, 5], [0, 5, 4], [3, 7, 6], [3, 6, 2], [0, 4, 7], [0, 7, 3], [1, 2, 6], [1, 6, 5]]:
			add_tri.call(v[f[0]], v[f[1]], v[f[2]], col, rough, metal, rr)
	var back := -size.z * 0.5
	var front := size.z * 0.5
	for sd in [-1.0, 1.0]:
		ext.call(Vector3(sd * size.x * 0.36, size.y * 0.42, back - 0.01), Vector3(size.x * 0.1, size.y * 0.045, 0.03), Color(1.0, 0.08, 0.06, 4.0 / 8.0))
	ext.call(Vector3(0, size.y * 0.22, back - 0.02), Vector3(0.28, 0.08, 0.02), Color(0.96, 0.96, 0.9, 0.0))
	ext.call(Vector3(0, size.y * 0.22, front + 0.02), Vector3(0.28, 0.08, 0.02), Color(0.96, 0.96, 0.9, 0.0))
	if lv[0] == "police":
		ext.call(Vector3(-0.25, size.y + 0.07, 0.0), Vector3(0.22, 0.07, 0.12), Color(1.0, 0.1, 0.1, 6.0 / 8.0))
		ext.call(Vector3(0.25, size.y + 0.07, 0.0), Vector3(0.22, 0.07, 0.12), Color(0.1, 0.3, 1.0, 6.0 / 8.0))
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


## A random livery for a vehicle type.
static func random_livery(type: String) -> String:
	var kind: String = TYPES[type][2]
	if type == "taxi":
		return "taxi" if randf() < 0.7 else "paint:%d" % (randi() % PAINTS.size())
	if kind == "car" and randf() < 0.12:
		return "police"
	if kind == "truck":
		return "brand:%d" % (randi() % PAINTS.size())
	if randf() < 0.25:
		return "two:%d:%d" % [randi() % PAINTS.size(), randi() % PAINTS.size()]
	return "paint:%d" % (randi() % PAINTS.size())
