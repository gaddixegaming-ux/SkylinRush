extends RefCounted
## Vehicle catalog for the garage + model builder.
##  skate : the 10 boards trimmed out of models/skateboard.glb
##  hover : models/scooter.glb (purple) turned into a hover-scooter, 8 paints
##  moto  : models/scooter_1.glb (orange) motor-scooter, 8 paints
## Each built model is a Node3D facing -Z, base at y = 0, with metadata the
## rider uses: "seat" (hip point), "grip" (hands), "feet" (foot height),
## "stand" (true = rider stands on it, like a skateboard).

const MT := preload("res://scripts/model_tools.gd")
const VEH_SHADER := preload("res://shaders/vehicle.gdshader")

const TYPES := ["skate", "hover", "moto"]
const TYPE_NAME := {"skate": "SKATEBOARD", "hover": "HOVER SCOOTER", "moto": "MOTO SCOOTER"}
const TYPE_ZONE := {"skate": "SKATE PARK", "hover": "HOVER HARBOR", "moto": "TURBO HIGHWAY"}
const BOARD_NAMES := ["VENOM", "GHOST", "RED X", "TIDAL", "NEBULA", "DUNE", "BOLT", "PHANTOM", "FANG", "GALAXY"]
## Paint jobs: target hue (-1 = keep the original), saturation, brightness.
const PAINTS := [
	{"name": "FACTORY", "hue": -1.0, "sat": 1.0, "val": 1.0},
	{"name": "CRIMSON", "hue": 0.0, "sat": 1.1, "val": 1.0},
	{"name": "OCEAN", "hue": 0.58, "sat": 1.1, "val": 1.0},
	{"name": "TOXIC", "hue": 0.3, "sat": 1.15, "val": 1.05},
	{"name": "SUNSET", "hue": 0.07, "sat": 1.1, "val": 1.05},
	{"name": "BUBBLEGUM", "hue": 0.9, "sat": 0.9, "val": 1.1},
	{"name": "GOLD RUSH", "hue": 0.13, "sat": 1.2, "val": 1.15},
	{"name": "STEALTH", "hue": -1.0, "sat": 0.1, "val": 0.4},
]
const PAINT_PRICES := [0, 300, 300, 450, 600, 800, 1500, 1200]
const BOARD_PRICES := [0, 150, 250, 250, 400, 400, 600, 800, 1000, 1500]
const BASE_HUE := {"hover": 0.74, "moto": 0.09}
const FILES := {"skate": "res://models/skateboard.glb", "hover": "res://models/scooter.glb", "moto": "res://models/scooter_1.glb"}
const TREE_FILE := "res://models/trees.glb"
## tree order in the sheet: oak, sakura, pine, palm, maple(yellow),
## birch, blue spruce, red maple, bamboo, bonsai
const TREE_KINDS := ["oak", "sakura", "pine", "palm", "gold", "birch", "spruce", "red", "bamboo", "bonsai"]


static func variant_count(type: String) -> int:
	return BOARD_NAMES.size() if type == "skate" else PAINTS.size()


static func variant_name(type: String, i: int) -> String:
	return BOARD_NAMES[i] if type == "skate" else PAINTS[i]["name"]


static func price(type: String, i: int) -> int:
	return BOARD_PRICES[i] if type == "skate" else PAINT_PRICES[i]


## Swatch colour for the garage list.
static func swatch(type: String, i: int) -> Color:
	if type == "skate":
		return [Color(0.55, 0.9, 0.2), Color(0.9, 0.9, 0.95), Color(0.95, 0.2, 0.25), Color(0.2, 0.75, 0.9), Color(0.55, 0.3, 1.0),
			Color(0.75, 0.65, 0.5), Color(0.25, 0.4, 1.0), Color(0.85, 0.85, 0.8), Color(0.9, 0.15, 0.3), Color(0.45, 0.35, 1.0)][i]
	var p: Dictionary = PAINTS[i]
	if p["hue"] < 0.0:
		return Color.from_hsv(BASE_HUE[type], 0.75 * p["sat"], 0.9 * p["val"])
	return Color.from_hsv(p["hue"], 0.8, 0.95)


static func build(type: String, variant: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Vehicle"
	match type:
		"skate":
			_build_skate(root, variant)
		"hover":
			_build_scooter(root, "hover", variant)
		"moto":
			_build_scooter(root, "moto", variant)
	root.set_meta("type", type)
	return root


# ---------------------------------------------------------------- skateboard
static func _build_skate(root: Node3D, variant: int) -> void:
	var boards := MT.split(FILES["skate"], Basis(), 0.25, true)
	var length := 1.15
	if boards.is_empty():
		_proc_board(root, swatch("skate", variant))
		root.set_meta("deck", 0.2)
	else:
		var b: Dictionary = boards[variant % boards.size()]
		var size: Vector3 = b["size"]
		var s := length / size.z
		var mi := MeshInstance3D.new()
		mi.mesh = b["mesh"]
		mi.scale = Vector3.ONE * s
		mi.material_override = _paint(b["material"], -1.0, 1.0, 1.0, 0.25)
		root.add_child(mi)
		root.set_meta("deck", size.y * s)
	root.set_meta("stand", true)
	root.set_meta("seat", Vector3(0, float(root.get_meta("deck")), 0))
	# under-glow so the board reads on any road
	var glow := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.28, 0.01, length * 0.8)
	glow.mesh = bm
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = swatch("skate", variant) * 1.8
	glow.material_override = gm
	glow.position.y = 0.03
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glow)


static func _proc_board(root: Node3D, c: Color) -> void:
	_box(root, Vector3(0.3, 0.05, 0.95), Vector3(0, 0.15, 0), _flat(c))
	_box(root, Vector3(0.3, 0.05, 0.25), Vector3(0, 0.19, -0.56), _flat(c), Vector3(0.35, 0, 0))
	_box(root, Vector3(0.3, 0.05, 0.25), Vector3(0, 0.19, 0.56), _flat(c), Vector3(-0.35, 0, 0))
	for z in [-0.35, 0.35]:
		for x in [-0.13, 0.13]:
			_box(root, Vector3(0.06, 0.1, 0.1), Vector3(x, 0.05, z), _flat(Color(0.3, 1.0, 0.8), 2.0))


# ---------------------------------------------------------------- scooters
static func _build_scooter(root: Node3D, type: String, variant: int) -> void:
	var length := 2.05 if type == "moto" else 2.0
	# the scooters face -X in the file -> yaw them to face -Z
	var w := MT.whole(FILES[type], -PI / 2.0, length)
	var p: Dictionary = PAINTS[variant % PAINTS.size()]
	var h := 1.0
	var model := Node3D.new()
	root.add_child(model)
	if w.is_empty():
		h = _proc_scooter(model, type, swatch(type, variant))
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = w["mesh"]
		mi.transform = w["xform"]
		var shift: float = 0.0 if p["hue"] < 0.0 else float(p["hue"]) - float(BASE_HUE[type])
		mi.material_override = _paint(w["material"], shift, p["sat"], p["val"], 0.2)
		model.add_child(mi)
		h = (w["size"] as Vector3).y
	root.set_meta("stand", false)
	# rider anchor points, measured on the models (fractions of height / length)
	root.set_meta("seat", Vector3(0, h * 0.60, length * 0.13))
	root.set_meta("grip", Vector3(0, h * 0.86, -length * 0.3))
	root.set_meta("feet", h * 0.27)
	root.set_meta("height", h)
	var accent := swatch(type, variant)
	if type == "hover":
		# repulsor pads + light cones instead of touching the road
		var pad_m := StandardMaterial3D.new()
		pad_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pad_m.albedo_color = Color(0.4, 1.4, 1.8)
		for z in [-length * 0.36, length * 0.3]:
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.2
			tm.outer_radius = 0.3
			ring.mesh = tm
			ring.material_override = pad_m
			ring.position = Vector3(0, 0.05, z)
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			model.add_child(ring)
			var cone := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.22
			cm.bottom_radius = 0.02
			cm.height = 0.34
			cone.mesh = cm
			var cmat := StandardMaterial3D.new()
			cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			cmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			cmat.albedo_color = Color(0.3, 0.9, 1.0, 0.18)
			cone.material_override = cmat
			cone.position = Vector3(0, -0.14, z)
			cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			model.add_child(cone)
	else:
		# headlight + tail light glow
		_box(model, Vector3(0.22, 0.08, 0.04), Vector3(0, h * 0.55, -length * 0.5), _flat(Color(1.0, 0.95, 0.8), 3.0))
		_box(model, Vector3(0.2, 0.06, 0.04), Vector3(0, h * 0.62, length * 0.5), _flat(Color(1.0, 0.15, 0.2), 3.0))
	# neon under-glow in the paint colour
	var ug := MeshInstance3D.new()
	var um := BoxMesh.new()
	um.size = Vector3(0.35, 0.01, length * 0.7)
	ug.mesh = um
	var ugm := StandardMaterial3D.new()
	ugm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ugm.albedo_color = accent * 1.6
	ug.material_override = ugm
	ug.position.y = 0.02
	ug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(ug)
	root.set_meta("body", model)


## Simple stand-in if the glb is missing. Returns the height.
static func _proc_scooter(p: Node3D, type: String, c: Color) -> float:
	var body := _flat(c)
	var dark := _flat(Color(0.12, 0.1, 0.15))
	var white := _flat(Color(0.92, 0.92, 0.96))
	_box(p, Vector3(0.5, 0.3, 1.5), Vector3(0, 0.35, 0.1), body)
	_box(p, Vector3(0.45, 0.14, 0.7), Vector3(0, 0.6, 0.3), dark)
	_box(p, Vector3(0.42, 0.55, 0.25), Vector3(0, 0.62, -0.62), white, Vector3(-0.35, 0, 0))
	_box(p, Vector3(0.7, 0.05, 0.05), Vector3(0, 0.9, -0.62), dark)
	if type == "moto":
		for z in [-0.7, 0.7]:
			var wheel := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.12
			tm.outer_radius = 0.26
			wheel.mesh = tm
			wheel.material_override = dark
			wheel.rotation.z = PI / 2
			wheel.position = Vector3(0, 0.26, z)
			p.add_child(wheel)
	return 1.0


static func _paint(src: Material, hue_shift: float, sat: float, val: float, rim: float) -> Material:
	var tex: Texture2D = null
	if src is BaseMaterial3D:
		tex = (src as BaseMaterial3D).albedo_texture
	if tex == null:
		return src
	var m := ShaderMaterial.new()
	m.shader = VEH_SHADER
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("hue_shift", hue_shift)
	m.set_shader_parameter("sat_mult", sat)
	m.set_shader_parameter("val_mult", val)
	m.set_shader_parameter("rim", rim)
	return m


static func _flat(c: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


static func _box(p: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


# ---------------------------------------------------------------- trees
## Returns the trimmed tree pieces [{mesh, material, size}], or [] if missing.
static func trees() -> Array:
	return MT.split(TREE_FILE)


static func tree_index(kind: String) -> int:
	return TREE_KINDS.find(kind)
