extends Camera3D
## Dynamic chase camera.
## - spring follow with lateral lag, look-ahead into the world curve
## - spring "kicks" (position + roll impulses) for jumps, landings, dashes, hits
## - context framing: wall-run tilt, grapple pull-back, slam look-down,
##   time-shift push-in, phase warp, flow-driven FOV
## - trauma shake, high-speed vibration, menu orbit + swoop-in, death cam

enum Mode { MENU, PLAY, DEAD }

var mode: Mode = Mode.MENU
var trauma := 0.0
var fov_punch := 0.0
var roll := 0.0
var t := 0.0
var orbit := 2.4
var swoop := 1.0
var base_pos := Vector3(4, 2.5, -5)
var look_pos := Vector3(0, 1.3, -10)
var kick_pos := Vector3.ZERO
var kick_vel := Vector3.ZERO
var roll_kick := 0.0
var roll_kick_vel := 0.0
var noise := FastNoiseLite.new()
var ground_ref := 0.0


func _ready() -> void:
	noise.frequency = 0.9
	fov = 70.0
	position = base_pos


func add_trauma(a: float) -> void:
	trauma = minf(1.0, trauma + a)


func punch_fov(a: float) -> void:
	fov_punch += a


## Positional impulse (springs back). +z pulls the camera back, -y dips it.
func kick(v: Vector3) -> void:
	kick_vel += v * 14.0


func kick_roll(a: float) -> void:
	roll_kick_vel += a * 14.0


func start_play() -> void:
	mode = Mode.PLAY
	swoop = 1.0
	ground_ref = 0.0


func update_cam(delta: float, player, speed_factor: float, extra_fov: float, curve: Vector2, cs: Dictionary) -> void:
	t += delta
	var p: Vector3 = player.position
	var target_pos: Vector3
	var target_look: Vector3
	var rate := 6.0
	var target_roll := 0.0
	var fov_mod := 0.0

	match mode:
		Mode.MENU:
			var lobby: bool = player.char_idx != 0
			var rad := 4.3 if lobby else 6.0
			orbit = (2.2 + sin(t * 0.3) * 0.22) if lobby else (2.55 + sin(t * 0.25) * 0.45)
			target_pos = p + Vector3(sin(orbit) * rad, (1.7 if lobby else 2.3) + sin(t * 0.4) * 0.2, cos(orbit) * rad)
			# lobby: frame the character on the right third of the screen
			target_look = p + (Vector3(0.9, 1.05, 1.1) if lobby else Vector3(0, 1.4, 0))
			rate = 3.0
		Mode.PLAY:
			var dip: float = player.cam_dip
			# follow the surface you stand on (sky-highways, roofs) almost fully,
			# but damp ordinary jumps so the view doesn't bob
			var fl: float = maxf(0.0, cs.get("floor", 0.0))
			ground_ref = lerpf(ground_ref, fl, 1.0 - exp(-3.0 * delta))
			var above := maxf(0.0, p.y - ground_ref)
			var hy := ground_ref * 0.95 + above * 0.5
			target_pos = Vector3(p.x * 0.72, 3.5 + hy + dip, 6.9 + speed_factor * 1.6 + hy * 0.3)
			# look ahead into the curve of the road
			target_look = Vector3(p.x * 0.85 + curve.x * 400.0, 1.2 + hy * 0.9 + above * 0.2 + dip * 0.5 + curve.y * 150.0, -12.0)
			fov_mod += hy * 1.2
			var tr: int = cs.get("trick", 0)
			if tr != 0:
				target_pos.x = p.x * 0.35 - tr * 1.2
				target_pos.y = 3.6 + p.y * 0.7
				target_pos.z += 1.2
				target_look = Vector3(p.x * 0.6, 1.0 + p.y * 0.8, -10.0)
				target_roll += tr * 0.12
				rate = 9.0
			var wall: int = cs.get("wall", 0)
			if wall != 0:
				target_pos.x = p.x * 0.45 - wall * 0.9
				target_pos.y = 2.4 + p.y * 0.3
				target_pos.z -= 0.8
				target_roll += wall * 0.3
			if cs.get("grapple") != null:
				var gp: Vector3 = cs["grapple"]
				target_pos += Vector3(0, 1.6, 2.2)
				target_look = target_look.lerp(gp, 0.4)
				rate = 4.0
			if cs.get("slam", false):
				target_pos.y += 1.4
				target_pos.z -= 0.6
				target_look = Vector3(p.x * 0.85, p.y - 2.0, -5.0)
				fov_mod -= 6.0
			if cs.get("shift", false):
				target_pos.z -= 1.0
				target_pos.y -= 0.35
				fov_mod += sin(t * 9.0) * 1.2
			if cs.get("phase", false):
				fov_mod += 4.0 + sin(t * 30.0) * 1.5
			if cs.get("air", false):
				target_pos.y += 0.4
			if swoop > 0.0:
				swoop = maxf(0.0, swoop - delta * 0.9)
				var e := swoop * swoop * (3.0 - 2.0 * swoop)
				var a := lerpf(0.0, orbit, e)
				var rad := lerpf(6.8, 6.0, e)
				var orbit_pos := p + Vector3(sin(a) * rad, lerpf(3.3, 2.3, e), cos(a) * rad)
				target_pos = orbit_pos.lerp(target_pos, 1.0 - e)
				target_look = (p + Vector3(0, 1.4, 0)).lerp(target_look, 1.0 - e)
				rate = 14.0
			target_roll += clampf(-player.x_vel * 0.012, -0.14, 0.14) - curve.x * 45.0
		Mode.DEAD:
			target_pos = p + Vector3(3.0, 2.4, 4.8)
			if player.fell:
				target_pos = Vector3(p.x + 2.0, 4.5, 5.0)
			target_look = p + Vector3(0, 0.8, 0)
			rate = 3.0
			orbit += delta * 0.4
			target_pos = p + Vector3(sin(orbit) * 4.5 + 1.5, 2.4, cos(orbit) * 4.5 + 2.0) if not player.fell else target_pos

	# smoothed base position (lateral faster than vertical)
	var k_xz := 1.0 - exp(-rate * 1.2 * delta)
	var k_y := 1.0 - exp(-rate * 0.8 * delta)
	base_pos.x = lerpf(base_pos.x, target_pos.x, k_xz)
	base_pos.z = lerpf(base_pos.z, target_pos.z, k_xz)
	base_pos.y = lerpf(base_pos.y, target_pos.y, k_y)

	# spring kicks (underdamped -> a little overshoot for punchy feel)
	var steps := maxi(1, ceili(delta / 0.008))
	var h := delta / steps
	for _i in steps:
		var acc := -170.0 * kick_pos - 14.0 * kick_vel
		kick_vel += acc * h
		kick_pos += kick_vel * h
		var racc := -150.0 * roll_kick - 13.0 * roll_kick_vel
		roll_kick_vel += racc * h
		roll_kick += roll_kick_vel * h

	position = base_pos + kick_pos
	look_pos = look_pos.lerp(target_look, 1.0 - exp(-10.0 * delta))
	var to := look_pos + kick_pos * 0.3 - position
	if to.length() > 0.01 and absf(to.normalized().y) < 0.98:
		look_at(look_pos + kick_pos * 0.3)

	roll = lerpf(roll, target_roll, 1.0 - exp(-6.0 * delta))
	rotate_object_local(Vector3(0, 0, 1), roll + roll_kick)

	# trauma shake + high-speed vibration
	trauma = maxf(0.0, trauma - delta * 1.5)
	var sh := trauma * trauma
	var vib := maxf(0.0, speed_factor - 0.55) * 0.012 if mode == Mode.PLAY else 0.0
	if sh > 0.0 or vib > 0.0:
		rotate_object_local(Vector3.RIGHT, noise.get_noise_2d(t * 40.0, 0.0) * (0.07 * sh + vib))
		rotate_object_local(Vector3.UP, noise.get_noise_2d(0.0, t * 40.0) * (0.07 * sh + vib))
		rotate_object_local(Vector3.FORWARD, noise.get_noise_2d(t * 40.0, 50.0) * 0.1 * sh)
	h_offset = noise.get_noise_2d(t * 25.0, 100.0) * 0.35 * sh
	v_offset = noise.get_noise_2d(100.0, t * 25.0) * 0.35 * sh

	# FOV: base + speed + effects + punches + context
	fov_punch = lerpf(fov_punch, 0.0, 1.0 - exp(-4.0 * delta))
	var base := 62.0 if mode == Mode.MENU else 70.0
	if mode == Mode.DEAD:
		base = 55.0
	var ft := base + speed_factor * 18.0 + extra_fov + fov_punch + fov_mod
	fov = lerpf(fov, clampf(ft, 45.0, 115.0), 1.0 - exp(-6.0 * delta))
