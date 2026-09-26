extends Node3D
## The runner: an original neon fox with headphones.
## Movement states: run, jump / double jump, dash-jump, air dash (forward or
## sideways barrel roll), wall run, grapple swing, phase, ground slam.
## Feel: spring-damped lanes, coyote time, jump buffer, variable jump height,
## squash & stretch. floor_y and curve are supplied by main every frame.

const RigScript := preload("res://characters/character_rig.gd")
const VehScript := preload("res://scripts/vehicles.gd")

signal jumped(kind: String)
signal landed(impact: float, was_slam: bool)
signal slid
signal grapple_released

const LANE_WIDTH := 2.5
const GRAVITY := 52.0
const FALL_MULT := 1.45
const JUMP_CUT_MULT := 2.2
const JUMP_VELOCITY := 16.0
const DOUBLE_JUMP_VELOCITY := 14.5
const DASH_JUMP_VELOCITY := 19.0
const WALL_JUMP_VELOCITY := 15.0
const SLAM_VELOCITY := -46.0
const SLIDE_TIME := 0.7
const COYOTE := 0.12
const JUMP_BUFFER := 0.15
const LANE_K := 340.0
const WALL_X := 4.72
const WALL_Y := 1.3
const AIR_DASH_TIME := 0.28
const SKY_JUMP_VELOCITY := 25.0
const SKY_TAP_WINDOW := 0.32
## quarter-pipe (skate park): inner edge, radius
const QP_EDGE := 4.45
const QP_R := 3.0
const TRICK_UP := 0.42
const TRICK_AIR := 1.05

var lane := 0
var prev_lane := 0
var lane_change_time := 10.0
var x_vel := 0.0
var vy := 0.0
var floor_y := 0.0
var grounded := true
var coyote_t := 0.0
var buffer_t := 0.0
var jump_held := false
var can_double := true
var slam_pending := false
var slamming := false
var slide_timer := 0.0
var flip := 0.0
var anim_t := 0.0
var dead := false
var fell := false
var squash := Vector3.ONE
var cam_dip := 0.0
var glow := 0.0
var glow_target := 0.0
var glow_color := Color(1, 0.35, 0.75)
var curve := Vector2.ZERO

var dash_t := 0.0
var air_dash_t := 0.0
var air_dash_dir := 0
var air_dash_ready := true
var wall_side := 0
var wall_t := 0.0
var anchor: Node3D = null
var rope_len := 0.0
var grap_y0 := 0.0
var grap_z0 := -30.0
var phase_t := 0.0
var cores: Array = []
var boarding := false
var rig = null
var char_idx := 0
var jump_serial := 0
var last_jump_kind := ""
var stumble_t := 0.0
var grinding := false
var vehicle := ""          # "", "skate", "hover", "moto"
var veh_node: Node3D = null
var veh_variant := -1
var sky_ready := true      # set by main from the SKY JUMP cooldown
var tap_t := 10.0          # time since the last ground jump (double-tap window)
var trick_t := -1.0        # quarter-pipe trick timer (-1 = none)
var trick_side := 0
var trick_x0 := 0.0
var trick_p1 := Vector2.ZERO
var trick_spin := 0.0

var model: Node3D
var body_pivot: Node3D
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var tail: Node3D
var shield_bubble: MeshInstance3D
var aura_bubble: MeshInstance3D
var trail: CPUParticles3D
var rope: MeshInstance3D
var orbit_root: Node3D
var orbit_meshes: Array = []
var body_mats: Array[StandardMaterial3D] = []
var all_mats: Array[StandardMaterial3D] = []


func _ready() -> void:
	_build_model()
	_build_effects()


func reset() -> void:
	lane = 0
	prev_lane = 0
	lane_change_time = 10.0
	x_vel = 0.0
	position = Vector3.ZERO
	vy = 0.0
	floor_y = 0.0
	grounded = true
	can_double = true
	slam_pending = false
	slamming = false
	slide_timer = 0.0
	flip = 0.0
	dead = false
	fell = false
	glow = 0.0
	glow_target = 0.0
	dash_t = 0.0
	air_dash_t = 0.0
	air_dash_ready = true
	wall_side = 0
	anchor = null
	rope.visible = false
	phase_t = 0.0
	set_phase_visual(false)
	model.rotation = Vector3.ZERO
	model.position = Vector3.ZERO
	model.scale = Vector3.ONE
	set_cores([])
	set_aura(false)
	set_vehicle("")
	trick_t = -1.0
	tap_t = 10.0


# ============================================================ controls
func move(dir: int) -> void:
	if dead:
		return
	var nl := clampi(lane + dir, -1, 1)
	if nl != lane:
		prev_lane = lane
		lane = nl
		lane_change_time = 0.0


func bounce_back() -> void:
	var cur := lane
	lane = prev_lane
	prev_lane = cur
	x_vel *= -0.6
	lane_change_time = 10.0
	stumble_t = 0.45
	squash = Vector3(1.25, 0.8, 1.25)


func press_jump() -> void:
	if dead:
		return
	jump_held = true
	if anchor != null:
		release_grapple(true)
		return
	if wall_side != 0:
		end_wall(true)
		return
	if trick_t >= 0.0:
		return
	if grounded or coyote_t > 0.0:
		if dash_t > 0.0:
			_do_jump("dash_jump")
		else:
			_do_jump("jump")
		tap_t = 0.0
	elif tap_t < SKY_TAP_WINDOW and sky_ready:
		# double-tap SPACE: the SKY JUMP ability
		_do_jump("sky")
	elif can_double and not (vy < 0.0 and position.y - floor_y < 0.7):
		_do_jump("double")
	else:
		buffer_t = JUMP_BUFFER


func release_jump() -> void:
	jump_held = false


func press_slide() -> void:
	if dead:
		return
	if wall_side != 0:
		end_wall(false)
		return
	if grounded:
		slide_timer = SLIDE_TIME
		slid.emit()


func slam(power: bool) -> void:
	vy = SLAM_VELOCITY if power else -38.0
	slamming = power
	slam_pending = true
	air_dash_t = 0.0
	flip = 0.0


func launch(v: float) -> void:
	vy = v
	grounded = false
	can_double = true
	air_dash_ready = true
	flip = 0.001
	squash = Vector3(0.75, 1.3, 0.75)


func air_dash(dir: int) -> void:
	air_dash_t = AIR_DASH_TIME
	air_dash_dir = dir
	air_dash_ready = false
	vy = maxf(vy, 0.0)
	flip = 0.0
	if dir != 0:
		move(dir)
		x_vel = dir * 30.0


func start_wall(side: int) -> void:
	wall_side = side
	wall_t = 3.0
	if lane != side:
		prev_lane = lane
		lane = side
	vy = 0.0
	grounded = false
	can_double = true
	air_dash_ready = true
	slide_timer = 0.0
	flip = 0.0


func end_wall(jump: bool) -> void:
	if wall_side == 0:
		return
	var side := wall_side
	wall_side = 0
	lane = side
	if jump:
		# kick off the wall towards the middle
		prev_lane = side
		lane = 0
		lane_change_time = 0.0
		vy = WALL_JUMP_VELOCITY
		x_vel = -side * 12.0
		flip = 0.001
		jumped.emit("wall_jump")
	else:
		vy = 3.0


func start_grapple(a: Node3D) -> void:
	anchor = a
	grap_y0 = position.y
	grap_z0 = minf(a.position.z, -2.0)
	rope.visible = true
	wall_side = 0
	air_dash_t = 0.0
	slide_timer = 0.0
	grounded = false
	can_double = true
	air_dash_ready = true


func release_grapple(boost: bool) -> void:
	if anchor == null:
		return
	anchor = null
	rope.visible = false
	vy = 15.0 if boost else 12.0
	can_double = true
	air_dash_ready = true
	flip = 0.001
	squash = Vector3(0.8, 1.25, 0.8)
	grapple_released.emit()


func die(from_fall: bool) -> void:
	dead = true
	fell = from_fall
	anchor = null
	rope.visible = false
	wall_side = 0
	if not from_fall:
		vy = 9.0
		grounded = false
	if rig != null:
		rig.die(from_fall)


## 0 = built-in fox, 1+ = Mixamo characters (see characters/character_rig.gd)
func set_character(idx: int) -> void:
	if rig != null:
		rig.queue_free()
		rig = null
	char_idx = idx
	body_pivot.visible = idx == 0
	if idx > 0:
		rig = RigScript.new()
		model.add_child(rig)
		rig.setup(idx)


func set_props(on: bool) -> void:
	if rig != null:
		rig.set_props(on)


## Mounts a vehicle from the garage ("" = on foot).
func set_vehicle(type: String, variant := 0) -> void:
	if type == vehicle and variant == veh_variant and (type == "" or veh_node != null):
		return
	if veh_node != null:
		veh_node.queue_free()
		veh_node = null
	vehicle = type
	veh_variant = variant if type != "" else -1
	boarding = type == "skate"
	grinding = false
	model.position = Vector3.ZERO
	if type != "":
		veh_node = VehScript.build(type, variant)
		model.add_child(veh_node)
	if rig != null and type == "":
		rig.set_riding("")
	body_pivot.position = Vector3.ZERO


## Kept for the old skateboard code paths.
func set_board(on: bool) -> void:
	set_vehicle("skate", 0 if veh_variant < 0 else veh_variant) if on else set_vehicle("")


## Swerve into a skate-park quarter-pipe: ride up, spin a 360 in the air and
## land in the middle lane.
func start_trick(side: int) -> void:
	trick_t = 0.0
	trick_side = side
	trick_x0 = position.x
	trick_spin = 0.0
	wall_side = 0
	anchor = null
	rope.visible = false
	slide_timer = 0.0
	dash_t = 0.0
	air_dash_t = 0.0
	grounded = false
	vy = 0.0
	prev_lane = lane
	lane = 0
	jump_serial += 1
	last_jump_kind = "jump"


func is_tricking() -> bool:
	return trick_t >= 0.0


func _tick_trick(delta: float) -> void:
	trick_t += delta
	var sd := float(trick_side)
	var roll := 0.0
	if trick_t < TRICK_UP:
		var u := trick_t / TRICK_UP
		if u < 0.3:
			position.x = lerpf(trick_x0, sd * QP_EDGE, u / 0.3)
			position.y = 0.0
		else:
			var a := (u - 0.3) / 0.7 * PI * 0.47
			position.x = sd * (QP_EDGE + QP_R * sin(a))
			position.y = QP_R * (1.0 - cos(a))
			roll = a
		trick_p1 = Vector2(position.x, position.y)
		model.rotation.z = lerpf(model.rotation.z, -sd * roll, 0.6)
	else:
		var v := clampf((trick_t - TRICK_UP) / TRICK_AIR, 0.0, 1.0)
		var e := v * v * (3.0 - 2.0 * v)
		position.x = lerpf(trick_p1.x, 0.0, e)
		position.y = trick_p1.y * (1.0 - v) + 4.0 * 4.2 * v * (1.0 - v)
		model.rotation.z = -sd * PI * 0.47 * (1.0 - smoothstep(0.0, 0.45, v))
		trick_spin = TAU * smoothstep(0.08, 0.85, v)
		if v >= 1.0:
			trick_t = -1.0
			position.x = 0.0
			position.y = floor_y
			x_vel = 0.0
			vy = 0.0
			grounded = true
			can_double = true
			air_dash_ready = true
			lane_change_time = 10.0
			trick_spin = 0.0
			model.rotation = Vector3.ZERO
			squash = Vector3(1.25, 0.75, 1.25)
			landed.emit(18.0, false)
			return
	model.rotation.x = 0.0
	model.rotation.y = trick_spin


func revive() -> void:
	dead = false
	fell = false
	vy = 0.0
	if position.y < 0.0:
		position.y = 3.0
	grounded = false
	model.rotation = Vector3.ZERO
	squash = Vector3(0.7, 1.3, 0.7)


func set_shield(on: bool) -> void:
	shield_bubble.visible = on


func set_aura(on: bool) -> void:
	aura_bubble.visible = on


func set_phase_visual(on: bool) -> void:
	for m in all_mats:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if on else BaseMaterial3D.TRANSPARENCY_DISABLED
		m.albedo_color.a = 0.35 if on else 1.0
	aura_bubble.visible = on
	if rig != null:
		for mi in rig.model.find_children("*", "MeshInstance3D", true, false):
			var m: StandardMaterial3D = mi.material_override
			if m:
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if on else BaseMaterial3D.TRANSPARENCY_DISABLED
				m.albedo_color.a = 0.4 if on else 1.0


func set_cores(list: Array) -> void:
	cores = list.duplicate()
	var cols := {"shield": Color(0.35, 0.9, 1.0), "surge": Color(1.0, 0.35, 0.75), "gold": Color(1.0, 0.8, 0.25),
		"magnet": Color(1.0, 0.35, 0.4), "slowmo": Color(0.65, 0.55, 1.0), "double": Color(1.0, 0.8, 0.2)}
	for i in orbit_meshes.size():
		var mi: MeshInstance3D = orbit_meshes[i]
		mi.visible = i < cores.size()
		if mi.visible:
			var m: StandardMaterial3D = mi.material_override
			m.albedo_color = cols[cores[i]]
			m.emission = cols[cores[i]]
	shield_bubble.visible = cores.has("shield")


func is_sliding() -> bool:
	return slide_timer > 0.0 and grounded


func is_grappling() -> bool:
	return anchor != null


func get_hitbox() -> AABB:
	var h := 0.9 if is_sliding() else 1.8
	return AABB(Vector3(position.x - 0.3, position.y, -0.3), Vector3(0.6, h, 0.6))


func bend(p: Vector3) -> Vector3:
	var d := minf(p.z, 0.0)
	return p + Vector3(curve.x * d * d, curve.y * d * d, 0.0)


func _do_jump(kind: String) -> void:
	slide_timer = 0.0
	buffer_t = 0.0
	coyote_t = 0.0
	grounded = false
	match kind:
		"double":
			vy = DOUBLE_JUMP_VELOCITY
			can_double = false
			flip = 0.001
		"dash_jump":
			vy = DASH_JUMP_VELOCITY
			flip = 0.001
		"sky":
			vy = SKY_JUMP_VELOCITY
			can_double = true
			air_dash_ready = true
			flip = 0.001
			tap_t = 10.0
		_:
			vy = JUMP_VELOCITY
	squash = Vector3(0.8, 1.25, 0.8)
	jump_serial += 1
	last_jump_kind = kind
	jumped.emit(kind)


# ============================================================ update
func tick(delta: float, speed: float, running: bool) -> void:
	lane_change_time += delta
	orbit_root.rotate_y(delta * 3.0)
	if dead:
		vy -= GRAVITY * delta
		position.y += vy * delta
		if not fell and position.y <= floor_y:
			position.y = floor_y
			vy = 0.0
			grounded = true
		if rig != null:
			model.rotation = model.rotation.lerp(Vector3.ZERO, 1.0 - exp(-8.0 * delta))
			rig.ap.speed_scale = 1.0
		else:
			model.rotation.x = lerpf(model.rotation.x, 1.45, 1.0 - exp(-6.0 * delta))
			model.rotation.z = lerpf(model.rotation.z, 0.3, 1.0 - exp(-6.0 * delta))
			if not grounded:
				model.rotation.y += delta * 6.0
		trail.emitting = false
		return

	tap_t += delta
	if trick_t >= 0.0:
		_tick_trick(delta)
		_animate(delta, speed, running)
		return
	dash_t = maxf(0.0, dash_t - delta)
	phase_t = maxf(0.0, phase_t - delta)
	stumble_t = maxf(0.0, stumble_t - delta)
	if anchor != null and not is_instance_valid(anchor):
		release_grapple(false)

	# ---- lateral: critically damped spring
	var target := lane * LANE_WIDTH
	if wall_side != 0:
		target = wall_side * WALL_X
	elif anchor != null:
		target = anchor.position.x
	var k := LANE_K * (2.5 if air_dash_t > 0.0 else 1.0)
	var steps := maxi(1, ceili(delta / 0.008))
	var h := delta / steps
	for _i in steps:
		var acc := k * (target - position.x) - 2.0 * sqrt(k) * x_vel
		x_vel += acc * h
		position.x += x_vel * h

	buffer_t -= delta
	coyote_t -= delta
	slide_timer = maxf(0.0, slide_timer - delta)

	# ---- vertical
	if anchor != null:
		# reel in along an arc: rise towards the anchor as it approaches
		var dz := anchor.position.z
		var s := clampf(1.0 - dz / grap_z0, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - smoothstep(0.0, 0.9, s), 2.0)
		var ty := lerpf(grap_y0, anchor.position.y - 2.2, e) + sin(s * PI) * 0.8
		var ny := lerpf(position.y, ty, 1.0 - exp(-14.0 * delta))
		vy = (ny - position.y) / maxf(delta, 0.001)
		position.y = ny
		grounded = false
		if dz > -0.4:
			release_grapple(false)
	elif wall_side != 0:
		wall_t -= delta
		position.y = lerpf(position.y, WALL_Y, 1.0 - exp(-12.0 * delta))
		vy = 0.0
		grounded = false
		if wall_t <= 0.0:
			end_wall(false)
	elif air_dash_t > 0.0:
		air_dash_t -= delta
		vy = maxf(vy - GRAVITY * 0.1 * delta, 0.0)
		position.y += vy * delta
	else:
		var g := GRAVITY
		if vy < 0.0:
			g *= FALL_MULT
		elif not jump_held:
			g *= JUMP_CUT_MULT
		vy -= g * delta
		var prev_y := position.y
		position.y += vy * delta
		# crossing test (not a thin band) so fast slams / low FPS can't tunnel through
		if position.y <= floor_y and vy <= 0.0 and prev_y >= floor_y - 0.3 and floor_y > -50.0:
			var impact := -vy
			position.y = floor_y
			vy = 0.0
			if not grounded:
				grounded = true
				can_double = true
				air_dash_ready = true
				flip = 0.0
				var sq := clampf(impact * 0.012, 0.08, 0.35)
				squash = Vector3(1.0 + sq, 1.0 - sq * 0.85, 1.0 + sq)
				var was_slam := slamming
				slamming = false
				landed.emit(impact, was_slam)
				if slam_pending and grounded:
					slam_pending = false
					if not was_slam:
						slide_timer = SLIDE_TIME
						slid.emit()
				if buffer_t > 0.0 and grounded:
					_do_jump("jump")
		elif position.y > floor_y + 0.05:
			if grounded:
				coyote_t = COYOTE
			grounded = false
	if grounded:
		coyote_t = COYOTE

	_animate(delta, speed, running)
	_update_rope()


func _animate(delta: float, speed: float, running: bool) -> void:
	anim_t += delta * ((8.0 + speed * 0.28) if running else 2.0)
	var swing := sin(anim_t) * 0.95 if running else sin(anim_t) * 0.05
	var target_rot := Vector3.ZERO
	if anchor != null:
		leg_l.rotation.x = sin(anim_t * 0.5) * 0.4 - 0.3
		leg_r.rotation.x = -sin(anim_t * 0.5) * 0.4 - 0.3
		arm_l.rotation = Vector3(-2.9, 0, -0.2)
		arm_r.rotation = Vector3(-2.9, 0, 0.2)
		target_rot.x = 0.25
	elif wall_side != 0:
		leg_l.rotation.x = swing * 1.1
		leg_r.rotation.x = -swing * 1.1
		arm_l.rotation = Vector3(-swing * 0.9, 0, -0.5)
		arm_r.rotation = Vector3(swing * 0.9, 0, 0.5)
		target_rot.z = wall_side * 1.15
		body_pivot.position.y = absf(sin(anim_t)) * 0.06
	elif air_dash_t > 0.0:
		leg_l.rotation.x = 0.6
		leg_r.rotation.x = 0.4
		arm_l.rotation = Vector3(0.9, 0, -0.6)
		arm_r.rotation = Vector3(0.9, 0, 0.6)
		target_rot.x = -0.7
	elif not grounded:
		leg_l.rotation.x = -1.0
		leg_r.rotation.x = 0.5
		arm_l.rotation = Vector3(-2.4, 0, -0.3)
		arm_r.rotation = Vector3(-2.4, 0, 0.3)
		body_pivot.position.y = 0.0
		if slamming:
			target_rot.x = -0.5
			arm_l.rotation = Vector3(0.3, 0, -0.9)
			arm_r.rotation = Vector3(0.3, 0, 0.9)
	else:
		leg_l.rotation.x = swing
		leg_r.rotation.x = -swing
		arm_l.rotation = Vector3(-swing * 0.9, 0, -0.15)
		arm_r.rotation = Vector3(swing * 0.9, 0, 0.15)
		body_pivot.position.y = absf(sin(anim_t)) * 0.09 if running else 0.0
		if dash_t > 0.0:
			target_rot.x = -0.45
			arm_l.rotation = Vector3(1.2, 0, -0.3)
			arm_r.rotation = Vector3(1.2, 0, 0.3)
	if is_sliding():
		target_rot.x = 1.1
	var stance := 0.0
	if veh_node != null and rig == null:
		# the built-in fox rides too
		if vehicle == "skate":
			stance = 1.2 if grinding else 1.0
			leg_l.rotation = Vector3(0.35, 0, -0.25)
			leg_r.rotation = Vector3(-0.3, 0, 0.25)
			arm_l.rotation = Vector3(0.2, 0, -1.1)
			arm_r.rotation = Vector3(-0.2, 0, 1.1)
			body_pivot.position.y = float(veh_node.get_meta("deck", 0.15)) - 0.06 + sin(anim_t * 0.3) * 0.02
		else:
			var seat: Vector3 = veh_node.get_meta("seat")
			leg_l.rotation = Vector3(1.35, 0, -0.12)
			leg_r.rotation = Vector3(1.35, 0, 0.12)
			arm_l.rotation = Vector3(1.25, 0, -0.1)
			arm_r.rotation = Vector3(1.25, 0, 0.1)
			body_pivot.position = Vector3(0, seat.y - 0.62, seat.z - 0.05)
			target_rot.x = -0.15 if vehicle == "moto" else -0.05
	elif veh_node == null and rig == null and body_pivot.position.y < -0.01:
		body_pivot.position = Vector3.ZERO
	body_pivot.rotation.y = lerpf(body_pivot.rotation.y, stance, 1.0 - exp(-12.0 * delta))
	if vehicle == "hover" and veh_node != null:
		model.position.y = 0.42 + sin(anim_t * 0.35) * 0.05

	if rig != null and anchor == null:
		target_rot.x = 0.0  # the character's own clips handle lean / slide poses
	if trick_t >= 0.0:
		_finish_anim(delta, speed, running)
		return
	if flip > 0.0:
		flip = minf(flip + delta * TAU / 0.45, TAU)
		if flip >= TAU:
			flip = 0.0
	var k := 1.0 - exp(-18.0 * delta)
	if flip > 0.0:
		model.rotation.x = target_rot.x - flip
	else:
		model.rotation.x = lerpf(model.rotation.x, target_rot.x, k)
	if air_dash_t > 0.0 and air_dash_dir != 0:
		# sideways air dash = barrel roll
		var prog := 1.0 - air_dash_t / AIR_DASH_TIME
		model.rotation.z = -air_dash_dir * TAU * prog
	elif wall_side != 0:
		model.rotation.z = lerpf(model.rotation.z, target_rot.z, k)
	else:
		model.rotation.z = lerpf(wrapf(model.rotation.z, -PI, PI), clampf(-x_vel * 0.035, -0.45, 0.45), k)
	model.rotation.y = 0.0
	_finish_anim(delta, speed, running)


func _finish_anim(delta: float, speed: float, running: bool) -> void:
	tail.rotation.y = sin(anim_t * 0.5) * 0.5
	squash = squash.lerp(Vector3.ONE, 1.0 - exp(-12.0 * delta))
	model.scale = squash
	var dip := -0.8 if is_sliding() else 0.0
	cam_dip = lerpf(cam_dip, dip, 1.0 - exp(-10.0 * delta))

	var hot := dash_t > 0.0 or air_dash_t > 0.0 or phase_t > 0.0
	glow = lerpf(glow, maxf(glow_target, 1.0 if hot else 0.0), 1.0 - exp(-10.0 * delta))
	if phase_t > 0.0:
		glow_color = Color(0.35, 0.9, 1.0)
	elif air_dash_t > 0.0 or dash_t > 0.0:
		glow_color = Color(1.0, 0.35, 0.75)
	for m in body_mats:
		m.emission = glow_color
		m.emission_energy_multiplier = glow * 1.6
	if rig != null:
		if running:
			rig.drive(self, speed, delta)
		elif veh_node != null:
			rig.ride_pose(vehicle, veh_node, 0.0, 0.0, delta)
			rig.rotation.y = 1.45 if vehicle == "skate" else 0.0
		else:
			rig.play_hobby(delta)
	trail.emitting = running and (grounded or wall_side != 0 or glow > 0.3 or anchor != null)
	trail.initial_velocity_min = speed
	trail.initial_velocity_max = speed
	trail.scale_amount_min = 0.6 + glow
	trail.scale_amount_max = 1.0 + glow * 1.5


func _update_rope() -> void:
	if anchor == null:
		return
	var a := position + Vector3(0, 2.1, 0)
	var b := bend(anchor.position)
	var d := b - a
	var l := d.length()
	if l < 0.05:
		return
	var up := d / l
	var side := up.cross(Vector3.FORWARD)
	if side.length() < 0.01:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	var fwd := side.cross(up)
	rope.global_transform = Transform3D(Basis(side * 0.05, up * l, fwd * 0.05), a + d * 0.5)


# ============================================================ model
func _build_model() -> void:
	var orange := Color(1.0, 0.5, 0.2)
	var dark_orange := Color(0.8, 0.33, 0.15)
	var white := Color(0.98, 0.95, 0.95)
	var dark := Color(0.1, 0.07, 0.12)
	var purple := Color(0.35, 0.2, 0.55)
	var pink := Color(1.0, 0.3, 0.75)
	var cyan := Color(0.3, 0.9, 1.0)

	model = Node3D.new()
	add_child(model)
	body_pivot = Node3D.new()
	model.add_child(body_pivot)

	# torso wears a purple hoodie
	_mesh(body_pivot, _capsule(0.33, 0.95), Vector3(0, 1.05, 0), purple, true)
	_mesh(body_pivot, _box(Vector3(0.5, 0.06, 0.02)), Vector3(0, 1.2, -0.33), pink, false, Vector3.ZERO, 2.5)
	_mesh(body_pivot, _sphere(0.34), Vector3(0, 1.74, 0), orange, true)                         # head
	_mesh(body_pivot, _sphere(0.2), Vector3(0, 1.64, -0.2), white, true)                          # cheeks
	_mesh(body_pivot, _cone(0.15, 0.34), Vector3(0, 1.68, -0.38), white, false, Vector3(-PI / 2, 0, 0))
	_mesh(body_pivot, _sphere(0.055), Vector3(0, 1.68, -0.56), dark)
	_mesh(body_pivot, _sphere(0.055), Vector3(-0.13, 1.82, -0.29), dark)
	_mesh(body_pivot, _sphere(0.055), Vector3(0.13, 1.82, -0.29), dark)
	_mesh(body_pivot, _cone(0.13, 0.36), Vector3(-0.19, 2.06, 0), orange, true, Vector3(0, 0, 0.3))
	_mesh(body_pivot, _cone(0.13, 0.36), Vector3(0.19, 2.06, 0), orange, true, Vector3(0, 0, -0.3))
	# headphones
	_mesh(body_pivot, _box(Vector3(0.74, 0.07, 0.1)), Vector3(0, 2.08, 0.02), dark)
	_mesh(body_pivot, _box(Vector3(0.07, 0.35, 0.1)), Vector3(-0.36, 1.92, 0.02), dark)
	_mesh(body_pivot, _box(Vector3(0.07, 0.35, 0.1)), Vector3(0.36, 1.92, 0.02), dark)
	for s in [-1.0, 1.0]:
		_mesh(body_pivot, _cyl(0.14, 0.12), Vector3(s * 0.37, 1.76, 0.0), dark, false, Vector3(0, 0, PI / 2))
		_mesh(body_pivot, _cyl(0.1, 0.13), Vector3(s * 0.38, 1.76, 0.0), cyan, false, Vector3(0, 0, PI / 2), 3.0)
	# gold backpack
	_mesh(body_pivot, _box(Vector3(0.5, 0.55, 0.28)), Vector3(0, 1.15, 0.36), Color(0.25, 0.15, 0.4), true)
	_mesh(body_pivot, _box(Vector3(0.52, 0.08, 0.3)), Vector3(0, 1.2, 0.37), Color(1, 0.75, 0.2), false, Vector3.ZERO, 2.0)

	leg_l = _limb(body_pivot, Vector3(-0.16, 0.6, 0), 0.11, 0.6, dark_orange)
	leg_r = _limb(body_pivot, Vector3(0.16, 0.6, 0), 0.11, 0.6, dark_orange)
	for leg in [leg_l, leg_r]:
		_mesh(leg, _box(Vector3(0.22, 0.14, 0.34)), Vector3(0, -0.56, -0.05), white)
		_mesh(leg, _box(Vector3(0.23, 0.04, 0.35)), Vector3(0, -0.62, -0.05), pink, false, Vector3.ZERO, 3.0)
	arm_l = _limb(body_pivot, Vector3(-0.42, 1.4, 0), 0.09, 0.55, purple)
	arm_r = _limb(body_pivot, Vector3(0.42, 1.4, 0), 0.09, 0.55, purple)

	tail = Node3D.new()
	tail.position = Vector3(0, 0.8, 0.3)
	body_pivot.add_child(tail)
	var dir := Vector3(0, cos(1.0), sin(1.0))
	_mesh(tail, _capsule(0.15, 0.85), dir * 0.42, orange, true, Vector3(1.0, 0, 0))
	_mesh(tail, _sphere(0.16), dir * 0.86, white, true)



func _build_effects() -> void:
	shield_bubble = _bubble(1.35, Color(0.35, 0.9, 1.0))
	aura_bubble = _bubble(1.55, Color(0.35, 0.9, 1.0))

	rope = MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 1.0
	rm.bottom_radius = 1.0
	rm.height = 1.0
	rm.radial_segments = 6
	rope.mesh = rm
	var ropem := StandardMaterial3D.new()
	ropem.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ropem.albedo_color = Color(0.6, 2.0, 1.0)
	rope.material_override = ropem
	rope.top_level = true
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rope.visible = false
	add_child(rope)


	orbit_root = Node3D.new()
	orbit_root.position.y = 1.1
	add_child(orbit_root)
	for i in 3:
		var om := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		sm.radial_segments = 8
		sm.rings = 4
		om.mesh = sm
		var omat := StandardMaterial3D.new()
		omat.emission_enabled = true
		omat.emission_energy_multiplier = 3.0
		om.material_override = omat
		var a := TAU * i / 3.0
		om.position = Vector3(cos(a) * 1.1, sin(a * 2.0) * 0.25, sin(a) * 1.1)
		om.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		om.visible = false
		orbit_root.add_child(om)
		orbit_meshes.append(om)

	trail = CPUParticles3D.new()
	trail.amount = 60
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.position = Vector3(0, 0.15, 0.2)
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	trail.emission_box_extents = Vector3(0.25, 0.05, 0.05)
	trail.direction = Vector3(0, 0, 1)
	trail.spread = 4.0
	trail.gravity = Vector3.ZERO
	var qm := BoxMesh.new()
	qm.size = Vector3(0.1, 0.1, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.6, 1.6, 1.6)
	qm.material = m
	trail.mesh = qm
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.4, 0.85, 0.9))
	grad.set_color(1, Color(0.3, 0.9, 1.0, 0.0))
	trail.color_ramp = grad
	add_child(trail)


func _bubble(r: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/bubble.gdshader")
	sm.set_shader_parameter("color", c)
	mi.material_override = sm
	mi.position.y = 1.05
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi


func _limb(parent: Node3D, pivot_pos: Vector3, radius: float, length: float, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	parent.add_child(pivot)
	_mesh(pivot, _capsule(radius, length), Vector3(0, -length * 0.5, 0), color, true)
	return pivot


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, glowable := false, rot := Vector3.ZERO, emit := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mat.rim_enabled = true
	mat.rim = 0.35
	mat.emission_enabled = glowable or emit > 0.0
	if emit > 0.0:
		mat.emission = color
		mat.emission_energy_multiplier = emit
	elif glowable:
		mat.emission_energy_multiplier = 0.0
		body_mats.append(mat)
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	all_mats.append(mat)
	return mi


func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	return m


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	return m


func _cone(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.01
	m.bottom_radius = r
	m.height = h
	return m


func _cyl(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	return m


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m
