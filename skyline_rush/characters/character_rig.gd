extends Node3D
## A playable Mixamo character: loads the model, shares the baked animation
## library (retargeted by bone name + hip height), picks the right clip from
## the runner's state, and builds the character's lobby props.

const LIB := preload("res://characters/animations.res")
const SCALE := 1.85  # models are ~1 m tall; the runner is ~1.85 m

## 0 is the retired built-in fox (no rig, not selectable). Textures: drop  characters/textures/<tex>.png/.jpg
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
# lobby prop simulation
var bag_pivot: Node3D
var bag_ang := 0.0
var bag_vel := 0.0
var bag_hit_t := 0.0
var bag_min_z := 0.0
var golf_ball: MeshInstance3D
var golf_tee: MeshInstance3D
var club_tip: Node3D
var tip_prev := Vector3.ZERO
var tip_low := Vector3(0, 99, 0)
var ball_vel := Vector3.ZERO
var ball_flying := 0.0
var bean: MeshInstance3D
var fitted := false
var push_t := 0.0
var stride_speed := 0.0  # ground speed (m/s) the run clip covers at 1x

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
	if def["prop"] == "ball" and not ap.has_animation("hobby_dribble"):
		_dribble(delta)
		return
	set_riding("")
	t += delta
	if bag_pivot:
		_update_bag(delta)
	if golf_ball:
		_update_golf(delta)
	if bean and not fitted and t > 0.4:
		_fit_bean()
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
		_update_ball_clip(delta)


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
			golf_tee = _cyl(props, 0.008, 0.05, Vector3(0.05, 0.035, -0.28), _mat(Color(1, 1, 1)))
			golf_ball = _sphere(props, 0.022, Vector3(0.05, 0.075, -0.28), _mat(Color(1, 1, 1)))
			var flag := _cyl(props, 0.005, 0.5, Vector3(-0.55, 0.25, -0.5), _mat(Color(0.9, 0.9, 0.9)))
			flag.name = "FlagPole"
			_box(props, Vector3(0.14, 0.09, 0.01), Vector3(-0.48, 0.45, -0.5), _mat(Color(1, 0.25, 0.25)))
			var att := _attach("mixamorig_RightHand")
			if att:
				_cyl(att, 0.006, 0.55, Vector3(0, 0.3, 0), _mat(Color(0.8, 0.8, 0.85)))
				_box(att, Vector3(0.05, 0.03, 0.08), Vector3(0, 0.57, 0.02), _mat(Color(0.2, 0.2, 0.25)))
				club_tip = Node3D.new()
				club_tip.position = Vector3(0, 0.57, 0.02)
				att.add_child(club_tip)
		"bag":
			# punch bag at fist height on a pendulum (swung by the punches)
			var frame := _mat(Color(0.25, 0.25, 0.3))
			bag_min_z = -0.42
			for x in [-0.42, 0.42]:
				_box(props, Vector3(0.05, 1.25, 0.05), Vector3(x, 0.625, -0.62), frame)
				_box(props, Vector3(0.2, 0.03, 0.3), Vector3(x, 0.015, -0.62), frame)
			_box(props, Vector3(0.9, 0.05, 0.05), Vector3(0, 1.25, -0.62), frame)
			_box(props, Vector3(0.05, 0.05, 0.3), Vector3(0, 1.25, -0.5), frame)
			bag_pivot = Node3D.new()
			bag_pivot.position = Vector3(0, 1.22, -0.42)
			props.add_child(bag_pivot)
			_cyl(bag_pivot, 0.004, 0.2, Vector3(0, -0.1, 0), _mat(Color(0.6, 0.6, 0.65)))
			_cyl(bag_pivot, 0.1, 0.03, Vector3(0, -0.21, 0), _mat(Color(0.15, 0.12, 0.14)))
			_cyl(bag_pivot, 0.11, 0.5, Vector3(0, -0.46, 0), _mat(Color(0.8, 0.15, 0.2)))
			_cyl(bag_pivot, 0.112, 0.05, Vector3(0, -0.36, 0), _mat(Color(0.95, 0.95, 0.95)))
			_cyl(bag_pivot, 0.1, 0.03, Vector3(0, -0.72, 0), _mat(Color(0.15, 0.12, 0.14)))
			_box(props, Vector3(1.4, 0.02, 1.2), Vector3(0, 0.01, -0.2), _mat(Color(0.2, 0.3, 0.6)))
		"gaming":
			bean = _sphere(props, 0.28, Vector3(0, 0.1, 0.1), _mat(Color(0.35, 0.3, 0.8)))
			bean.scale.y = 0.4
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


func _local_bone(bn: String) -> Vector3:
	var bi := skel.find_bone(bn)
	if bi < 0:
		return Vector3.ZERO
	return to_local(skel.global_transform * skel.get_bone_global_pose(bi).origin)


## Pendulum punch bag: a fist reaching the bag knocks it away.
func _update_bag(delta: float) -> void:
	bag_hit_t -= delta
	for hn in ["mixamorig_RightHand", "mixamorig_LeftHand"]:
		var h := _local_bone(hn)
		bag_min_z = minf(bag_min_z, h.z)
		var bag_front := bag_pivot.position.z + 0.11
		if bag_hit_t <= 0.0 and h.z < bag_front + 0.07 and absf(h.x) < 0.35 and h.y > 0.3 and h.y < 1.15:
			bag_vel += 2.6
			bag_hit_t = 0.28
	# settle the bag where the fists actually reach
	if t > 1.5 and t < 1.6:
		bag_pivot.position.z = bag_min_z - 0.05
	bag_vel += (-26.0 * bag_ang - 2.2 * bag_vel) * delta
	bag_ang = clampf(bag_ang + bag_vel * delta, -0.6, 0.8)
	bag_pivot.rotation.x = bag_ang


## Golf: the club head knocks the ball off the tee; it flies and comes back.
## The tee is placed where the club head moves fastest near the ground
## (learned during the first swing), so the contact always lines up.


func _update_golf(delta: float) -> void:
	if club_tip == null:
		return
	var tip := to_local(club_tip.global_transform.origin)
	var prev := tip_prev
	var vel := (tip - tip_prev) / maxf(delta, 0.001)
	tip_prev = tip
	var spd := vel.length()
	if ball_flying > 0.0:
		ball_flying -= delta
		ball_vel.y -= 5.0 * delta
		golf_ball.position += ball_vel * delta
		if golf_ball.position.y < 0.02:
			golf_ball.position.y = 0.02
			ball_vel *= Vector3(0.6, -0.35, 0.6)
		if ball_flying <= 0.0:
			golf_ball.position = golf_tee.position + Vector3(0, 0.04, 0)
		return
	golf_ball.position = golf_tee.position + Vector3(0, 0.04, 0)
	# impact = the club head sweeping down through ball height at speed
	if prev.y > 0.1 and tip.y <= 0.1 and vel.y < 0.0 and spd > 1.5:
		golf_tee.position = Vector3(tip.x, 0.035, tip.z)
		golf_ball.position = golf_tee.position + Vector3(0, 0.04, 0)
		var dir := Vector3(vel.x, 0.0, vel.z).normalized()
		ball_vel = dir * 3.2 + Vector3(0, 2.4, 0)
		ball_flying = 1.8


## Bean bag fitted under the gamer's hips so her legs never sink into it.
func _fit_bean() -> void:
	fitted = true
	var hip := _local_bone("mixamorig_Hips")
	var top := maxf(hip.y - 0.05, 0.08)
	bean.scale = Vector3(1.0, top / 0.56, 1.0)
	bean.position = Vector3(hip.x, top * 0.5, hip.z + 0.12)


## HOOPS: procedural dribble (low stance, bouncing hand, guard arm, sway).
func _dribble(delta: float) -> void:
	set_riding("pose")
	t += delta
	rotation.y = 0.0
	var u := absf(sin(t * PI * 2.2))
	var sway := sin(t * 1.3)
	_apply_pose({
		"Hips": Vector3(0, 12 * sway, 0), "Spine": Vector3(20, -6 * sway, 0), "Spine1": Vector3(6, 0, 0),
		"Neck": Vector3(-10, 0, 0), "Head": Vector3(-8, 10 * sway, 0),
		"LeftUpLeg": Vector3(-36 - 4 * u, 0, 12), "RightUpLeg": Vector3(-28 - 4 * u, 0, -12),
		"LeftLeg": Vector3(52 + 6 * u, 0, 0), "RightLeg": Vector3(44 + 6 * u, 0, 0),
		"LeftFoot": Vector3(-16, 0, 0), "RightFoot": Vector3(-14, 0, 0),
		"RightArm": Vector3(18 + 18 * (1.0 - u), 32, 60 - 12 * u), "RightForeArm": Vector3(0, 25 + 40 * u, 0),
		"RightHand": Vector3(-35 * u, 0, 0),
		"LeftArm": Vector3(18, -58, -40), "LeftForeArm": Vector3(0, -75, 0),
	})
	_snap_feet(0.0, ["mixamorig_LeftToeBase", "mixamorig_RightToeBase", "mixamorig_LeftFoot", "mixamorig_RightFoot"])
	if ball:
		_update_ball()


## Moves the rig so the lowest of these bones touches `ground` (parent space).
func _snap_feet(ground: float, bones: Array) -> void:
	var par := get_parent() as Node3D
	var inv := par.global_transform.affine_inverse()
	var low := INF
	for bn in bones:
		var bi := skel.find_bone(bn)
		if bi >= 0:
			low = minf(low, (inv * (skel.global_transform * skel.get_bone_global_pose(bi)).origin).y)
	if low < INF:
		position.y += ground + 0.02 - low


func _update_ball() -> void:
	var hi := skel.find_bone("mixamorig_RightHand")
	var hand: Vector3 = (skel.global_transform * skel.get_bone_global_pose(hi)).origin
	var local := to_local(hand)
	var bounce := absf(sin(t * PI * 2.2))
	ball.position = Vector3(local.x, lerpf(0.07, maxf(local.y - 0.08, 0.1), bounce), local.z)


## Dribble clip: the ball rides the right hand on the push-down, leaves it at
## the bottom of the stroke, bounces off the floor and meets the hand again at
## the top (air time learned from the clip's own rhythm).
var drib_air := -1.0
var drib_tair := 0.45
var drib_prev_y := 0.0
var drib_prev_v := 0.0
var drib_rel_y := 0.3
var drib_rel_t := 0.0

func _update_ball_clip(delta: float) -> void:
	const R := 0.07
	var hi := skel.find_bone("mixamorig_RightHand")
	var hand := to_local((skel.global_transform * skel.get_bone_global_pose(hi)).origin)
	var hv := (hand.y - drib_prev_y) / maxf(delta, 0.001)
	var palm := hand.y - R - 0.03
	var y: float
	if drib_air < 0.0:
		y = palm
		if drib_prev_v < -0.02 and hv >= -0.02:  # bottom of the stroke: let go
			drib_air = 0.0
			drib_rel_y = palm
			drib_rel_t = t
	else:
		drib_air += delta / drib_tair
		var s := minf(drib_air, 1.0)
		const SB := 0.4
		if s < SB:
			y = R + (drib_rel_y - R) * (1.0 - pow(s / SB, 2.0))
		else:
			var u := (s - SB) / (1.0 - SB)
			y = R + (palm - R) * (1.0 - pow(1.0 - u, 2.0))
		var top := drib_prev_v > 0.02 and hv <= 0.02
		if top or drib_air >= 1.3:
			if top:
				drib_tair = lerpf(drib_tair, clampf(t - drib_rel_t, 0.2, 0.9), 0.5)
			drib_air = -1.0
	ball.position = Vector3(hand.x, maxf(y, R), hand.z - 0.02)
	ball.rotation.x += delta * 6.0
	drib_prev_y = hand.y
	drib_prev_v = hv


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
	if kind == "skate" and crouch > 0.5:
		# in the air: tuck and grab the board
		pose["LeftUpLeg"] = Vector3(-70, 0, 14)
		pose["RightUpLeg"] = Vector3(-62, 0, -14)
		pose["LeftLeg"] = Vector3(105, 0, 0)
		pose["RightLeg"] = Vector3(100, 0, 0)
		pose["Spine"] = Vector3(30, 18, 0)
		pose["RightArm"] = Vector3(40, 30, 75)
		pose["RightForeArm"] = Vector3(0, 30, 0)
		pose["LeftArm"] = Vector3(-20, -20, -95)
	elif kind == "skate" and push_t > 0.0:
		# push-off: the back leg sweeps down to the road and kicks
		var k := sin(clampf(push_t / 0.55, 0.0, 1.0) * PI)
		pose["RightUpLeg"] = Vector3(-10 + 20 * k, 0, -16 - 28 * k)
		pose["RightLeg"] = Vector3(46 - 40 * k, 0, 0)
		pose["LeftUpLeg"] = Vector3(-28 - 22 * k, 0, 16)
		pose["LeftLeg"] = Vector3(46 + 38 * k, 0, 0)
		pose["Spine"] = pose["Spine"] + Vector3(10 * k, 0, 0)
		pose["RightArm"] = pose["RightArm"] + Vector3(0, 0, -25 * k)
	elif kind == "skate":
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
		var feet := ["mixamorig_LeftToeBase", "mixamorig_RightToeBase", "mixamorig_LeftFoot", "mixamorig_RightFoot"]
		if push_t > 0.0 and crouch < 0.5:
			feet = ["mixamorig_LeftToeBase", "mixamorig_LeftFoot"]  # front foot stays on the deck
		for bn in feet:
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
	if p.anchor != null:
		_swing_pose(delta)
		return
	if p.vehicle == "skate" and p.grounded and not p.grinding:
		push_t -= delta
		if push_t < -1.3:
			push_t = 0.55
	else:
		push_t = 0.0
	if p.vehicle != "" and p.veh_node != null:
		var crouch: float = 1.0 if (p.is_sliding() or not p.grounded) else clampf((1.0 - p.squash.y) * 5.0, 0.0, 0.8)
		ride_pose(p.vehicle, p.veh_node, clampf(-p.x_vel * 0.1, -1.0, 1.0), crouch, delta)
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
	elif p.wall_side != 0:
		play("run", 0.1, run_rate(speed) * 1.35)  # fast wall-run stride
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
		play("arc_right" if p.x_vel > 0.0 else "arc_left", 0.1, run_rate(speed))
	else:
		play("run", 0.15, run_rate(speed))


## Run playback rate synced to the ground speed. The Medium Run clip covers
## 2.44 x hip-height per 0.567 s cycle; the game moves much faster than a real
## run, so legs play at 42 % of the true sync (clamped) to read as fast but clean.
func run_rate(speed: float) -> float:
	if stride_speed <= 0.0:
		var hip := _local_bone("mixamorig_Hips").y * scale.y
		stride_speed = maxf(2.44 * maxf(hip, 0.5) / 0.567, 1.0)
	return clampf(speed / stride_speed * 0.42, 1.1, 2.3)


## Grapple: one arm up on the rope, the other out for balance, legs swinging.
func _swing_pose(delta: float) -> void:
	set_riding("pose")
	t += delta
	var sw := sin(t * 4.0)
	rotation.y = 0.0
	position = Vector3.ZERO
	_apply_pose({
		"Spine": Vector3(-6, 0, 0), "Head": Vector3(-12, 0, 0),
		"RightArm": Vector3(0, 10, -78), "RightForeArm": Vector3(0, 8, 0),
		"LeftArm": Vector3(10, -20, -20), "LeftForeArm": Vector3(0, -40, 0),
		"LeftUpLeg": Vector3(-25 + 25 * sw, 0, 6), "RightUpLeg": Vector3(-35 + 25 * sw, 0, -6),
		"LeftLeg": Vector3(35 - 15 * sw, 0, 0), "RightLeg": Vector3(55 - 15 * sw, 0, 0),
		"LeftFoot": Vector3(25, 0, 0), "RightFoot": Vector3(25, 0, 0),
	})


func die(from_fall: bool) -> void:
	set_riding("")
	play("jump_alt" if from_fall else "fall", 0.08, 1.0, true)
