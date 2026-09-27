extends Node3D
## Enemies that interact with the runner (they hold their position relative
## to the runner instead of scrolling with the road):
##   BOMBER   - flies ahead and drops falling blocks into the lanes
##   HUNTER   - locks a red laser onto your lane, then fires down it (dodge!)
##   BLOCKER  - a sled-bot that slides in front of you to force a lane change

const LW := 2.5
const RED := Color(1.0, 0.18, 0.12)

var g            # main.gd
var w            # world.gd
var bombers: Array = []   # [node, t, x_target]
var hunters: Array = []   # [node, state, t, lane, beam]
var blocker: Node3D = null
var blocker_t := 0.0
var solo_t := 0.0         # drones spawned outside an event leave after this
var _anim := 0.0


func setup(game, world) -> void:
	g = game
	w = world


func clear() -> void:
	solo_t = 0.0
	for b in bombers:
		b[0].queue_free()
	bombers.clear()
	for h in hunters:
		h[0].queue_free()
		if is_instance_valid(h[4]):
			h[4].queue_free()
	hunters.clear()
	if blocker:
		blocker.queue_free()
		blocker = null


func _drones_leave() -> void:
	for b in bombers:
		b[0].queue_free()
	bombers.clear()
	for h in hunters:
		h[0].queue_free()
		if is_instance_valid(h[4]):
			h[4].queue_free()
	hunters.clear()


func any_active() -> bool:
	return not bombers.is_empty() or not hunters.is_empty() or blocker != null


# ------------------------------------------------------------ spawning
func add_bomber() -> void:
	var n := _build_bomber()
	n.position = Vector3(0, 8.5, -60.0)
	add_child(n)
	bombers.append([n, 1.2, 0.0])


func add_hunter() -> void:
	var n := _build_hunter()
	n.position = Vector3(0, 6.0, -60.0)
	add_child(n)
	hunters.append([n, "track", 2.0, 0, null])


func add_blocker() -> void:
	if blocker != null:
		return
	blocker = _build_blocker()
	blocker.position = Vector3(g.player.position.x, 0, -70.0)
	add_child(blocker)
	blocker_t = 7.0


# ------------------------------------------------------------ update
func tick(delta: float, dz: float) -> void:
	_anim += delta
	var p = g.player
	if solo_t > 0.0:
		solo_t -= delta
		if solo_t <= 0.0:
			_drones_leave()
	# ---- bombers: drift over the lanes, drop blocks ahead of the runner
	for b in bombers.duplicate():
		var n: Node3D = b[0]
		n.position.z = lerpf(n.position.z, -34.0, 1.0 - exp(-1.5 * delta))
		b[1] -= delta
		if b[1] <= 0.0:
			b[1] = randf_range(1.6, 2.4)
			var lane: int = p.lane if randf() < 0.55 else randi() % 3 - 1
			b[2] = lane * LW
			w.drop_block(lane, -26.0)
			g.audio.play("grapple", 0.5, -4.0)
		n.position.x = lerpf(n.position.x, b[2], 1.0 - exp(-3.0 * delta))
		n.rotation.z = sin(_anim * 3.0) * 0.1
		for r in n.get_meta("rotors"):
			r.rotate_y(delta * 30.0)
	# ---- hunters: track -> lock (red laser on your lane) -> fire -> cool down
	for h in hunters.duplicate():
		var n: Node3D = h[0]
		n.position.z = lerpf(n.position.z, -20.0, 1.0 - exp(-1.5 * delta))
		h[2] -= delta
		match h[1]:
			"track":
				n.position.x = lerpf(n.position.x, p.position.x, 1.0 - exp(-3.0 * delta))
				if h[2] <= 0.0:
					h[1] = "lock"
					h[2] = 1.2
					h[3] = p.lane
					h[4] = _laser(h[3], false)
					g.audio.play("deny", 1.6, -2.0)
					g.hud.popup("LOCKED ON!  MOVE!", RED, 36)
			"lock":
				n.position.x = lerpf(n.position.x, h[3] * LW, 1.0 - exp(-8.0 * delta))
				if is_instance_valid(h[4]):
					h[4].visible = int(_anim * 14.0) % 2 == 0
				if h[2] <= 0.0:
					if is_instance_valid(h[4]):
						h[4].queue_free()
					h[4] = _laser(h[3], true)
					h[1] = "fire"
					h[2] = 0.35
					g.audio.play("shock", 1.4, -2.0)
					g.cam.add_trauma(0.25)
					g.fx.burst(Vector3(h[3] * LW, 0.5, -2.0), RED, 18, 9.0, 0.2, 0.5)
					if p.lane == h[3] and p.position.y < 2.6 and not p.is_grappling():
						g.enemy_hit("ZAPPED BY A HUNTER")
					else:
						g.enemy_dodged("HUNTER")
			"fire":
				if h[2] <= 0.0:
					if is_instance_valid(h[4]):
						h[4].queue_free()
					h[1] = "track"
					h[2] = randf_range(2.2, 3.4)
	# ---- blocker: slides in front of you, then brakes towards you
	if blocker != null:
		blocker_t -= delta
		var bz := -16.0 if blocker_t > 2.0 else blocker.position.z + (22.0 * delta)
		blocker.position.z = lerpf(blocker.position.z, bz, 1.0 - exp(-2.5 * delta)) if blocker_t > 2.0 else bz
		if blocker_t > 2.0:
			blocker.position.x = move_toward(blocker.position.x, p.lane * LW, 3.2 * delta)
		blocker.position.y = 0.25 + sin(_anim * 6.0) * 0.08
		if absf(blocker.position.z) < 1.0 and absf(blocker.position.x - p.position.x) < 1.2 and p.position.y < 1.7:
			if p.dash_t > 0.0 or p.air_dash_t > 0.0 or p.slamming:
				g.enemy_smashed(blocker.position, "BLOCKER")
				blocker.queue_free()
				blocker = null
			else:
				g.enemy_hit("BLOCKED")
				if blocker:
					blocker.queue_free()
					blocker = null
		elif blocker.position.z > 8.0:
			blocker.queue_free()
			blocker = null


## HUD markers for the threats (red rings on screen).
func markers(cam) -> Array:
	var out := []
	for h in hunters:
		if h[1] == "lock":
			var pos: Vector3 = g.player.bend(Vector3(h[3] * LW, 1.2, -9.0))
			if not cam.is_position_behind(pos):
				out.append({"pos": cam.unproject_position(pos), "color": RED, "text": "HUNTER LOCK  ·  CHANGE LANE", "big": true})
	if blocker != null and blocker.position.z < -3.0:
		var pos3: Vector3 = g.player.bend(blocker.position + Vector3(0, 2.0, 0))
		if not cam.is_position_behind(pos3):
			out.append({"pos": cam.unproject_position(pos3), "color": RED, "text": "BLOCKER  ·  DODGE OR DASH", "big": false})
	return out


# ------------------------------------------------------------ builders
func _m(c: Color, e := 0.0, rough := 0.4, metal := 0.5) -> Material:
	return w.mat(c, c if e > 0.0 else Color.BLACK, e, rough, metal, 0.6, 0.0, RED)


func _build_bomber() -> Node3D:
	var n := Node3D.new()
	var shell := _m(Color(0.2, 0.18, 0.26))
	var s: MeshInstance3D = w._sphere(n, 0.9, Vector3.ZERO, shell, true)
	s.scale = Vector3(1.3, 0.5, 1.0)
	w._sphere(n, 0.28, Vector3(0, -0.2, -0.7), _m(RED, 6.0), false)
	w._box(n, Vector3(0.9, 0.5, 0.9), Vector3(0, -0.55, 0), _m(Color(1.0, 0.8, 0.1), 1.0), false)
	var rotors := []
	for x in [-1.3, 1.3]:
		for z in [-0.9, 0.9]:
			w._box(n, Vector3(0.8, 0.08, 0.1), Vector3(x * 0.6, 0.15, z * 0.6), shell, false)
			var r: MeshInstance3D = w._cyl(n, 0.5, 0.04, Vector3(x, 0.3, z), _m(Color(1, 1, 1), 1.5), Vector3.ZERO, false)
			rotors.append(r)
	n.set_meta("rotors", rotors)
	return n


func _build_hunter() -> Node3D:
	var n := Node3D.new()
	var shell := _m(Color(0.1, 0.1, 0.14), 0.0, 0.25, 0.8)
	var b: MeshInstance3D = w._sphere(n, 0.8, Vector3.ZERO, shell, true)
	b.scale = Vector3(0.9, 0.9, 1.4)
	w._sphere(n, 0.35, Vector3(0, 0, -1.0), _m(RED, 8.0), false)
	w._torus(n, 1.0, 1.12, Vector3.ZERO, _m(RED, 3.0), Vector3(PI / 2, 0, 0))
	for sd in [-1.0, 1.0]:
		var fin: MeshInstance3D = w._box(n, Vector3(1.4, 0.08, 0.6), Vector3(sd * 1.0, 0, 0.3), shell, false)
		fin.rotation.z = sd * 0.3
	return n


func _build_blocker() -> Node3D:
	var n := Node3D.new()
	var body := _m(Color(0.95, 0.5, 0.12), 0.2)
	w._box(n, Vector3(2.0, 0.4, 2.2), Vector3(0, 0.2, 0), _m(Color(0.15, 0.15, 0.2)), true)
	w._box(n, Vector3(1.8, 1.3, 0.5), Vector3(0, 1.05, 0.5), body, true)
	w._box(n, Vector3(1.9, 0.18, 0.55), Vector3(0, 1.75, 0.5), _m(RED, 4.0), false)
	w._sphere(n, 0.35, Vector3(0, 1.1, 0.78), _m(Color(1, 0.9, 0.2), 5.0), false)
	for x in [-0.8, 0.8]:
		w._cyl(n, 0.28, 0.1, Vector3(x, 0.02, -0.6), _m(Color(0.3, 0.9, 1.0), 4.0), Vector3.ZERO, false)
	return n


func _laser(lane: int, fire: bool) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(lane * LW, 0.0, -8.0)
	add_child(n)
	if fire:
		w._box(n, Vector3(1.6, 3.0, 28.0), Vector3(0, 1.5, 0), w.mat(Color(1, 0.8, 0.8), Color(1.0, 0.3, 0.2), 8.0, 0.4, 0, 0, 0.0), false)
	else:
		w._box(n, Vector3(0.12, 0.06, 28.0), Vector3(0, 0.05, 0), w.mat(RED, RED, 6.0), false)
		w._box(n, Vector3(2.0, 0.03, 28.0), Vector3(0, 0.03, 0), w.mat(Color(0.3, 0.02, 0.02), RED, 1.2), false)
	return n

