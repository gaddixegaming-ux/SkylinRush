extends Node3D
## A playable Mixamo character: loads the model, shares the baked animation
## library (retargeted by bone name + hip height), picks the right clip from
## the runner's state, and builds the character's lobby props.

const LIB := preload("res://characters/animations.res")
const SCALE := 1.85  # models are ~1 m tall; the runner is ~1.85 m

## 0 is the built-in fox (no rig). Textures: drop  characters/textures/<tex>.png/.jpg
const CHARACTERS := [
	{"name": "FOX", "hobby": "Built-in runner"},
	{"name": "HOOPS", "hobby": "Dribbling", "model": "res://characters/source/Medium_Run.fbx",
		"anims": ["hobby_dribble"], "tex": "hoops", "color": Color(1.0, 0.55, 0.25), "prop": "ball"},
	{"name": "ROCKY", "hobby": "Punching bag", "model": "res://characters/source/Punching_Bag.fbx",
		"anims": ["hobby_punch"], "tex": "rocky", "color": Color(0.9, 0.3, 0.35), "prop": "bag"},
	{"name": "PIXEL", "hobby": "Gaming", "model": "res://characters/source/Gaming.fbx",
		"anims": ["hobby_gaming"], "tex": "pixel", "color": Color(0.6, 0.45, 1.0), "prop": "gaming"},
	{"name": "ACE", "hobby": "Golf", "model": "res://characters/source/Golf_Drive.fbx",
		"anims": ["hobby_golf", "hobby_golf_bad"], "tex": "ace", "color": Color(0.4, 0.8, 0.5), "prop": "golf"},
	{"name": "CHILL", "hobby": "Leaning on a wall, listening to music", "model": "res://characters/source/Leaning_On_A_Wall.fbx",
		"anims": ["hobby_lean"], "tex": "chill", "color": Color(0.3, 0.8, 0.9), "prop": "wall"},
]

var def: Dictionary
var model: Node3D
var skel: Skeleton3D
var ap: AnimationPlayer
var props: Node3D
var cur := ""
var hobby_i := 0
var hobby_t := 0.0
var last_jump := -1
var ball: MeshInstance3D
var t := 0.0
var skel_basis := Basis()  # skeleton space -> Mixamo model space (rotation only)
var riding := ""
var attached: Array = []  # bone-attached props (golf club, headphones)
var pose_offset := Vector3.ZERO

## Riding poses. Rotations (degrees, X/Y/Z euler) in Mixamo model space:
## +Z = forward, +Y = up, +X = the character's left. Each bone's rotation is
## applied on top of what it inherits from its parent.
const POSES := {
	"moto": {
		"Spine": Vector3(14, 0, 0), "Spine1": Vector3(6, 0, 0), "Neck": Vector3(-10, 0, 0), "Head": Vector3(-8, 0, 0),
		"LeftUpLeg": Vector3(-78, 0, 9), "RightUpLeg": Vector3(-78, 0, -9),
		"LeftLeg": Vector3(88, 0, 0), "RightLeg": Vector3(88, 0, 0),
		"LeftFoot": Vector3(-12, 0, 0), "RightFoot": Vector3(-12, 0, 0),
		"LeftArm": Vector3(28, -68, 0), "RightArm": Vector3(28, 68, 0),
		"LeftForeArm": Vector3(0, -18, 0), "RightForeArm": Vector3(0, 18, 0),
	},
	"hover": {
		"Spine": Vector3(6, 0, 0), "Neck": Vector3(-4, 0, 0),
		"LeftUpLeg": Vector3(-72, 0, 7), "RightUpLeg": Vector3(-72, 0, -7),
		"LeftLeg": Vector3(80, 0, 0), "RightLeg": Vector3(80, 0, 0),
		"LeftFoot": Vector3(-8, 0, 0), "RightFoot": Vector3(-8, 0, 0),
		"LeftArm": Vector3(34, -62, 0), "RightArm": Vector3(34, 62, 0),
		"LeftForeArm": Vector3(0, -22, 0), "RightForeArm": Vector3(0, 22, 0),
	},
	# sideways stance: the rig itself is turned 90 degrees on the board
	"skate": {
		"Hips": Vector3(0, -20, 0), "Spine": Vector3(8, 18, 0), "Spine1": Vector3(0, 12, 0), "Head": Vector3(0, -55, 0),
		"LeftUpLeg": Vector3(-28, 0, 16), "RightUpLeg": Vector3(-28, 0, -16),
		"LeftLeg": Vector3(46, 0, 0), "RightLeg": Vector3(46, 0, 0),
		"LeftFoot": Vector3(-16, 0, -8), "RightFoot": Vector3(-16, 0, 8),
		"LeftArm": Vector3(0, -12, -52), "RightArm": Vector3(0, 12, 52),
		"LeftForeArm": Vector3(0, -20, 0), "RightForeArm": Vector3(0, 20, 0),
	},
}


static func count() -> int:
	return CHARACTERS.size()


func setup(idx: int) -> void:
	def = CHARACTERS[idx]
	scale = Vector3.ONE * SCALE
	model = (load(def["model"]) as PackedScene).instantiate()
	model.rotation.y = PI  # Mixamo faces +Z, the runner faces -Z
	add_child(model)
	for n in model.find_children("*", "AnimationPlayer", true, false):
		n.queue_free()
	skel = model.find_children("*", "Skeleton3D", true, false)[0]
	ap = AnimationPlayer.new()
	model.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", _retarget_library())
	var rel := Transform3D()
	var n: Node = skel
	while n != model and n != null:
		if n is Node3D:
			rel = (n as Node3D).transform * rel
		n = n.get_parent()
	skel_basis = rel.basis.orthonormalized()
	_apply_material()
	_build_props()


## Shared clips, with the hip height scaled to this skeleton (feet stay planted).
func _retarget_library() -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var hips_y := skel.get_bone_rest(skel.find_bone("mixamorig_Hips")).origin.y
	for n in LIB.get_animation_list():
		var a: Animation = LIB.get_animation(n).duplicate(true)
		var k := hips_y / float(a.get_meta("src_hips_y", hips_y))
		if absf(k - 1.0) > 0.001:
			for tr in a.get_track_count():
				if a.track_get_type(tr) == Animation.TYPE_POSITION_3D:
					for i in a.track_get_key_count(tr):
						a.track_set_key_value(tr, i, a.track_get_key_value(tr, i) * k)
		lib.add_animation(n, a)
	return lib


func _apply_material() -> void:
	var tex: Texture2D = null
	for ext in ["png", "jpg", "jpeg", "webp"]:
		var p := "res://characters/textures/%s.%s" % [def["tex"], ext]
		if ResourceLoader.exists(p):
			tex = load(p)
			break
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := StandardMaterial3D.new()
		m.roughness = 0.75
		m.rim_enabled = true
		m.rim = 0.3
		if tex:
			m.albedo_texture = tex
		else:
			# placeholder until the texture is supplied
			m.albedo_color = def["color"]
		mi.material_override = m


func has(n: String) -> bool:
	return ap.has_animation(n)


func play(n: String, blend := 0.12, spd := 1.0, restart := false) -> void:
	if not ap.has_animation(n):
		n = "run" if ap.has_animation("run") else ap.get_animation_list()[0]
	if n != cur or restart:
		ap.play(n, blend)
		if restart:
			ap.seek(0.0, true)
		cur = n
	ap.speed_scale = spd


# ============================================================ lobby
func play_hobby(delta: float) -> void:
	set_riding("")
	t += delta
	var list: Array = def["anims"].filter(func(x): return ap.has_animation(x))
	if list.is_empty():
		list = ["hobby_lean"]  # fallback until the character's own clip is added
	hobby_t += delta
	var a: Animation = ap.get_animation(list[hobby_i % list.size()])
	if list.size() > 1 and hobby_t > a.length * 2.0:
		hobby_t = 0.0
		hobby_i += 1
	play(list[hobby_i % list.size()], 0.3)
	rotation.y = 0.0
	if ball:
		_update_ball()


func set_props(on: bool) -> void:
	if props:
		props.visible = on
	for a in attached:
		if is_instance_valid(a):
			a.visible = on


func _build_props() -> void:
	props = Node3D.new()
	add_child(props)
	match def["prop"]:
		"wall":
			var brick := _mat(Color(0.75, 0.42, 0.38))
			_box(props, Vector3(1.8, 1.5, 0.12), Vector3(0, 0.75, 0.28), brick)
			for r in 7:
				_box(props, Vector3(1.8, 0.012, 0.125), Vector3(0, 0.1 + r * 0.2, 0.28), _mat(Color(0.85, 0.8, 0.75)))
			_box(props, Vector3(0.5, 0.18, 0.02), Vector3(0.45, 1.15, 0.21), _glow(Color(1.0, 0.35, 0.75)))
			_headphones()
		"golf":
			var grass := _mat(Color(0.35, 0.7, 0.35))
			_box(props, Vector3(1.4, 0.02, 1.0), Vector3(0, 0.01, -0.1), grass)
			_cyl(props, 0.008, 0.05, Vector3(0.05, 0.035, -0.28), _mat(Color(1, 1, 1)))
			_sphere(props, 0.022, Vector3(0.05, 0.075, -0.28), _mat(Color(1, 1, 1)))
			var att := _attach("mixamorig_RightHand")
			if att:
				_cyl(att, 0.006, 0.55, Vector3(0, 0.3, 0), _mat(Color(0.8, 0.8, 0.85)))
				_box(att, Vector3(0.05, 0.03, 0.08), Vector3(0, 0.57, 0.02), _mat(Color(0.2, 0.2, 0.25)))
		"bag":
			var frame := _mat(Color(0.25, 0.25, 0.3))
			_box(props, Vector3(0.06, 1.7, 0.06), Vector3(-0.45, 0.85, -0.55), frame)
			_box(props, Vector3(0.06, 1.7, 0.06), Vector3(0.45, 0.85, -0.55), frame)
			_box(props, Vector3(0.96, 0.06, 0.06), Vector3(0, 1.7, -0.55), frame)
			_cyl(props, 0.005, 0.3, Vector3(0, 1.52, -0.45), _mat(Color(0.6, 0.6, 0.65)))
			var bag := _cyl(props, 0.13, 0.62, Vector3(0, 1.05, -0.45), _mat(Color(0.8, 0.15, 0.2)))
			bag.set_meta("swing", true)
			_box(props, Vector3(1.4, 0.02, 1.2), Vector3(0, 0.01, -0.2), _mat(Color(0.2, 0.3, 0.6)))
		"gaming":
			var bean := _sphere(props, 0.32, Vector3(0, 0.12, 0.05), _mat(Color(0.35, 0.3, 0.8)))
			bean.scale.y = 0.45
			# TV + console off to the left so the lobby camera sees the gamer
			var tv := Node3D.new()
			tv.position = Vector3(-0.75, 0, -0.85)
			tv.rotation.y = -0.7
			props.add_child(tv)
			_box(tv, Vector3(0.9, 0.5, 0.05), Vector3(0, 0.62, 0), _mat(Color(0.05, 0.05, 0.08)))
			_box(tv, Vector3(0.84, 0.44, 0.02), Vector3(0, 0.62, 0.03), _glow(Color(0.35, 0.8, 1.0)))
			_box(tv, Vector3(1.0, 0.35, 0.3), Vector3(0, 0.18, 0), _mat(Color(0.2, 0.18, 0.25)))
			_box(tv, Vector3(0.2, 0.05, 0.15), Vector3(0.3, 0.37, 0.05), _glow(Color(0.4, 1.0, 0.6)))
			_box(props, Vector3(1.6, 0.02, 1.8), Vector3(0, 0.01, -0.4), _mat(Color(0.3, 0.25, 0.45)))
		"ball":
			ball = _sphere(props, 0.07, Vector3(0.2, 0.3, -0.2), _mat(Color(1.0, 0.5, 0.15)))
			_box(props, Vector3(1.6, 0.02, 1.4), Vector3(0, 0.01, -0.1), _mat(Color(0.8, 0.55, 0.35)))


func _update_ball() -> void:
	var hi := skel.find_bone("mixamorig_RightHand")
	var hand: Vector3 = (skel.global_transform * skel.get_bone_global_pose(hi)).origin
	var local := to_local(hand)
	var bounce := absf(sin(t * PI * 2.2))
	ball.position = Vector3(local.x, lerpf(0.07, maxf(local.y - 0.08, 0.1), bounce), local.z)


func _headphones() -> void:
	var att := _attach("mixamorig_Head")
	if att == null:
		return
	var dark := _mat(Color(0.1, 0.08, 0.12))
	_box(att, Vector3(0.2, 0.02, 0.03), Vector3(0, 0.2, 0), dark)
	for s in [-1.0, 1.0]:
		_box(att, Vector3(0.02, 0.1, 0.03), Vector3(s * 0.1, 0.15, 0), dark)
		var cup := _cyl(att, 0.04, 0.03, Vector3(s * 0.105, 0.1, 0), _glow(Color(0.3, 0.9, 1.0)))
		cup.rotation.z = PI / 2


func _attach(bone: String) -> BoneAttachment3D:
	if skel.find_bone(bone) < 0:
		return null
	var b := BoneAttachment3D.new()
	b.bone_name = bone
	skel.add_child(b)
	attached.append(b)
	return b


# ============================================================ helpers
func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	return m


func _glow(c: Color) -> StandardMaterial3D:
	var m := _mat(c)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.5
	return m


func _box(p: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	p.add_child(mi)
	return mi


func _cyl(p: Node3D, r: float, h: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	p.add_child(mi)
	return mi


func _sphere(p: Node3D, r: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	mi.material_override = m
	mi.position = pos
	p.add_child(mi)
	return mi


# ============================================================ riding
## Holds the rider pose for a vehicle (kind = moto / hover / skate), or ""
## to hand the skeleton back to the animation player.
func set_riding(kind: String) -> void:
	if kind == riding:
		return
	riding = kind
	if kind == "":
		ap.active = true
		skel.reset_bone_poses()
		position = Vector3.ZERO
		rotation = Vector3.ZERO
		cur = ""
		play("run", 0.0)
	else:
		ap.active = false


## Poses the skeleton and snaps it onto the vehicle. `lean` (-1..1) leans into
## turns, `crouch` (0..1) tucks down (slides / jumps).
func ride_pose(kind: String, veh: Node3D, lean: float, crouch: float, delta: float) -> void:
	set_riding(kind)
	t += delta
	var pose: Dictionary = POSES[kind].duplicate()
	var bob := sin(t * (9.0 if kind == "skate" else 5.0)) * 0.6
	if kind == "skate":
		pose["LeftUpLeg"] = pose["LeftUpLeg"] + Vector3(-22 * crouch + bob, 0, 0)
		pose["RightUpLeg"] = pose["RightUpLeg"] + Vector3(-22 * crouch + bob, 0, 0)
		pose["LeftLeg"] = pose["LeftLeg"] + Vector3(40 * crouch, 0, 0)
		pose["RightLeg"] = pose["RightLeg"] + Vector3(40 * crouch, 0, 0)
		pose["Spine"] = pose["Spine"] + Vector3(18 * crouch, 0, lean * 10.0)
		pose["LeftArm"] = pose["LeftArm"] + Vector3(0, 0, lean * 25.0)
		pose["RightArm"] = pose["RightArm"] + Vector3(0, 0, lean * 25.0)
	else:
		pose["Spine"] = pose["Spine"] + Vector3(22 * crouch + bob, 0, -lean * 8.0)
		pose["Head"] = pose.get("Head", Vector3.ZERO) + Vector3(-14 * crouch, 0, 0)
	_apply_pose(pose)
	# snap: hips onto the seat, or feet onto the deck
	var par := get_parent() as Node3D
	var inv := par.global_transform.affine_inverse()
	if veh.get_meta("stand", false):
		var low := INF
		for bn in ["mixamorig_LeftToeBase", "mixamorig_RightToeBase", "mixamorig_LeftFoot", "mixamorig_RightFoot"]:
			var bi := skel.find_bone(bn)
			if bi >= 0:
				low = minf(low, (inv * (skel.global_transform * skel.get_bone_global_pose(bi)).origin).y)
		if low < INF:
			position.y += float(veh.get_meta("deck", 0.15)) + 0.02 - low
		position.x = 0.0
		position.z = 0.0
	else:
		var hi := skel.find_bone("mixamorig_Hips")
		var hip := inv * (skel.global_transform * skel.get_bone_global_pose(hi)).origin
		var seat: Vector3 = veh.get_meta("seat")
		position += Vector3(0, seat.y - hip.y, seat.z - hip.z)
		position.x = 0.0


func _apply_pose(pose: Dictionary) -> void:
	var n := skel.get_bone_count()
	var g := []
	g.resize(n)
	var inv_s := skel_basis.inverse()
	for b in n:
		var par := skel.get_bone_parent(b)
		var rest := skel.get_bone_rest(b)
		var pg: Basis = g[par] if par >= 0 else Basis()
		var gb: Basis = pg * rest.basis
		var bname := skel.get_bone_name(b).trim_prefix("mixamorig_")
		if pose.has(bname):
			var e: Vector3 = pose[bname] * (PI / 180.0)
			var d_model := Basis.from_euler(e)
			gb = (inv_s * d_model * skel_basis) * gb
		g[b] = gb
		skel.set_bone_pose_rotation(b, (pg.inverse() * gb).get_rotation_quaternion())
		skel.set_bone_pose_position(b, rest.origin)


# ============================================================ in-game
func drive(p, speed: float, delta: float) -> void:
	t += delta
	if p.vehicle != "" and p.veh_node != null:
		ride_pose(p.vehicle, p.veh_node, clampf(-p.x_vel * 0.08, -1.0, 1.0),
			1.0 if (p.is_sliding() or not p.grounded) else 0.0, delta)
		rotation.y = 1.45 if p.vehicle == "skate" else 0.0
		return
	set_riding("")
	rotation.y = p.body_pivot.rotation.y
	if p.jump_serial != last_jump:
		last_jump = p.jump_serial
		if not p.grounded:
			play("jump2" if p.last_jump_kind == "double" else "jump", 0.08, 1.1, true)
			return
	if p.anchor != null:
		play("jump2", 0.15, 0.6)
	elif p.stumble_t > 0.0:
		play("trip", 0.06, 1.3)
	elif p.air_dash_t > 0.0 or p.slamming:
		play("dash", 0.08)
	elif not p.grounded and p.wall_side == 0:
		if cur != "jump" and cur != "jump2":
			play("jump", 0.15, 1.0)
	elif p.is_sliding():
		play("slide", 0.08, 1.7)
	elif p.dash_t > 0.0:
		play("tackle", 0.06, 2.4)
	elif p.boarding:
		play("dash", 0.15)
	elif p.lane_change_time < 0.28 and absf(p.x_vel) > 3.0:
		play("arc_right" if p.x_vel > 0.0 else "arc_left", 0.1, clampf(speed / 18.0, 0.9, 1.6))
	else:
		play("run", 0.15, clampf(speed / 18.0, 0.9, 1.7))


func die(from_fall: bool) -> void:
	set_riding("")
	play("jump_alt" if from_fall else "fall", 0.08, 1.0, true)
