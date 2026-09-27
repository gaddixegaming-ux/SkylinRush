extends Node3D
## Enemies that interact with the runner (they hold their position relative
## to the runner instead of scrolling with the road):
##   ENFORCER - chases you after a stumble; stumble again while he's close = caught
##   BOMBER   - flies ahead and drops falling blocks into the lanes
##   HUNTER   - locks a red laser onto your lane, then fires down it (dodge!)
##   RIVAL    - a rival runner who races alongside and steals the coins in her lane
##   BLOCKER  - a sled-bot that slides in front of you to force a lane change
##   TITAN    - mini-boss: a giant mech that retreats ahead of you and slams
##              shockwaves down the lanes for 20 s (the MECH CHASE)

const RigScript := preload("res://characters/character_rig.gd")
const LW := 2.5
const RED := Color(1.0, 0.18, 0.12)

var g            # main.gd
var w            # world.gd
var chaser: Node3D
var chaser_on := 0.0
var bombers: Array = []   # [node, t, x_target]
var hunters: Array = []   # [node, state, t, lane, beam]
var rival: Node3D = null
var rival_t := 0.0
var rival_lane := 1
var rival_stolen := 0
var blocker: Node3D = null
var blocker_t := 0.0
var titan: Node3D = null
var titan_t := 0.0
var titan_next := 0.0
var waves: Array = []     # titan shockwaves: [node, lane, t]
var solo_t := 0.0         # drones spawned outside an event leave after this
var _anim := 0.0


func setup(game, world) -> void:
	g = game
	w = world
	chaser = _build_enforcer()
	chaser.visible = false
	add_child(chaser)


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
	if rival:
		rival.queue_free()
		rival = null
	if blocker:
		blocker.queue_free()
		blocker = null
	if titan:
		titan.queue_free()
		titan = null
	for wv in waves:
		wv[0].queue_free()
	waves.clear()
	chaser_on = 0.0
	chaser.visible = false


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
	return not bombers.is_empty() or not hunters.is_empty() or rival != null or blocker != null or titan != null


# ------------------------------------------------------------ spawning
func stumble() -> void:
	chaser_on = 5.0
	chaser.visible = true
	chaser.position = Vector3(g.player.position.x, 0, 9.0)


func is_chasing() -> bool:
	return chaser_on > 0.0


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


func add_rival() -> void:
	if rival != null:
		return
	var idx: int = 1 + randi() % (RigScript.count() - 1)
	if idx == g.char_idx:
		idx = 1 + (idx % (RigScript.count() - 1))
	rival = Node3D.new()
	add_child(rival)
	var rig := RigScript.new()
	rival.add_child(rig)
	rig.setup(idx)
	rig.set_props(false)
	rival.set_meta("rig", rig)
	# glowing purple ghost look so she reads as an enemy
	for mi in rig.model.find_children("*", "MeshInstance3D", true, false):
		var m: StandardMaterial3D = mi.material_override
		if m:
			m.rim_enabled = true
			m.rim = 1.0
			m.emission_enabled = true
			m.emission = Color(0.6, 0.2, 1.0)
			m.emission_energy_multiplier = 0.6
	var tag: MeshInstance3D = w._box(rival, Vector3(0.9, 0.22, 0.05), Vector3(0, 2.35, 0), w.mat(Color(0.7, 0.3, 1.0), Color(0.7, 0.3, 1.0), 3.0), false)
	tag.set_meta("tag", true)
	rival_lane = 1 if g.player.lane <= 0 else -1
	rival.position = Vector3(rival_lane * LW, 0, 6.0)
	rival_t = 18.0
	rival_stolen = 0


func add_blocker() -> void:
	if blocker != null:
		return
	blocker = _build_blocker()
	blocker.position = Vector3(g.player.position.x, 0, -70.0)
	add_child(blocker)
	blocker_t = 7.0


func start_titan() -> void:
	if titan != null:
		return
	titan = _build_titan()
	titan.position = Vector3(0, 7.0, -90.0)
	add_child(titan)
	titan_t = 20.0
	titan_next = 2.5


# ------------------------------------------------------------ update
func tick(delta: float, dz: float) -> void:
	_anim += delta
	var p = g.player
	if solo_t > 0.0:
		solo_t -= delta
		if solo_t <= 0.0:
			_drones_leave()
	# ---- enforcer
	if chaser_on > 0.0:
		chaser_on -= delta
		var tz := 2.6 if chaser_on > 0.8 else 12.0
		chaser.position.z = lerpf(chaser.position.z, tz, 1.0 - exp(-3.0 * delta))
		chaser.position.x = lerpf(chaser.position.x, p.position.x, 1.0 - exp(-4.0 * delta))
		chaser.position.y = p.floor_y if p.floor_y > 0.0 else 0.0
		_run_pose(chaser, 14.0)
		if chaser_on <= 0.0:
			chaser.visible = false
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
	# ---- rival runner
	if rival != null:
		rival_t -= delta
		var rig = rival.get_meta("rig")
		rig.play("run", 0.12, 1.35)
		var tz := -5.0 if rival_t > 1.0 else -60.0
		rival.position.z = lerpf(rival.position.z, tz, 1.0 - exp(-1.2 * delta))
		if randf() < delta * 0.35:
			var nl := clampi(rival_lane + (1 if randf() < 0.5 else -1), -1, 1)
			if nl != p.lane:
				rival_lane = nl
		rival.position.x = lerpf(rival.position.x, rival_lane * LW, 1.0 - exp(-6.0 * delta))
		for c in w.objects.get_children():
			if c.get_meta("kind") == "coin" and not c.is_queued_for_deletion() and absf(c.position.x - rival.position.x) < 0.9 \
					and c.position.z > rival.position.z - 1.2 and c.position.z < rival.position.z + 0.8 and c.position.y < 2.5:
				g.fx.sparkle(c.position, Color(0.7, 0.3, 1.0))
				c.queue_free()
				rival_stolen += 1
		# dash into her to knock her out and win the coins back
		if absf(rival.position.x - p.position.x) < 1.2 and rival.position.z > -2.0 and (p.dash_t > 0.0 or p.air_dash_t > 0.0):
			g.rival_knocked(rival_stolen)
			g.fx.burst(rival.position + Vector3(0, 1, 0), Color(0.7, 0.3, 1.0), 24, 10.0, 0.25, 0.6)
			rival.queue_free()
			rival = null
		elif rival_t <= 0.0:
			if rival_stolen > 0:
				g.hud.popup("RIVAL GOT AWAY WITH %d COINS" % rival_stolen, Color(0.7, 0.4, 1.0), 30)
			rival.queue_free()
			rival = null
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
	# ---- titan (mini-boss)
	if titan != null:
		titan_t -= delta
		var tz := -26.0 if titan_t > 1.5 else -120.0
		titan.position.z = lerpf(titan.position.z, tz, 1.0 - exp(-1.2 * delta))
		titan.position.x = lerpf(titan.position.x, p.position.x * 0.4, 1.0 - exp(-1.0 * delta))
		titan.position.y = 6.0 + sin(_anim * 1.7) * 0.4
		for arm in titan.get_meta("arms"):
			arm.rotation.x = sin(_anim * 3.0 + arm.get_meta("ph")) * 0.4
		titan_next -= delta
		if titan_next <= 0.0 and titan_t > 2.0:
			titan_next = randf_range(1.6, 2.4)
			var lanes := [p.lane]
			if randf() < 0.5:
				lanes.append(clampi(p.lane + (1 if randf() < 0.5 else -1), -1, 1))
			for ln in lanes:
				var wv := _wave(ln)
				waves.append([wv, ln, 0.0])
			g.audio.play("shock", 0.7, -3.0)
			g.cam.add_trauma(0.2)
		if titan_t <= 0.0:
			titan.queue_free()
			titan = null
			g.titan_escaped()
	# shockwaves roll down the lane towards the runner
	for wv in waves.duplicate():
		var n: Node3D = wv[0]
		wv[2] += delta
		n.position.z += (26.0 + g.speed * 0.4) * delta
		n.scale.y = 1.0 + sin(wv[2] * 20.0) * 0.15
		if absf(n.position.z) < 0.8 and not n.get_meta("hit", false):
			n.set_meta("hit", true)
			if p.lane == wv[1] and p.position.y < 1.2 and not p.is_grappling():
				g.enemy_hit("FLATTENED BY THE TITAN")
			elif p.lane == wv[1]:
				g.enemy_dodged("TITAN")
		if n.position.z > 8.0:
			n.queue_free()
			waves.erase(wv)


## HUD markers for the threats (red rings on screen).
func markers(cam) -> Array:
	var out := []
	for h in hunters:
		if h[1] == "lock":
			var pos: Vector3 = g.player.bend(Vector3(h[3] * LW, 1.2, -9.0))
			if not cam.is_position_behind(pos):
				out.append({"pos": cam.unproject_position(pos), "color": RED, "text": "HUNTER LOCK  ·  CHANGE LANE", "big": true})
	for wv in waves:
		if wv[0].position.z < -6.0:
			var pos2: Vector3 = g.player.bend(wv[0].position + Vector3(0, 1.0, 0))
			if not cam.is_position_behind(pos2):
				out.append({"pos": cam.unproject_position(pos2), "color": Color(1.0, 0.5, 0.1), "text": "SHOCKWAVE  ·  JUMP", "big": false})
	if blocker != null and blocker.position.z < -3.0:
		var pos3: Vector3 = g.player.bend(blocker.position + Vector3(0, 2.0, 0))
		if not cam.is_position_behind(pos3):
			out.append({"pos": cam.unproject_position(pos3), "color": RED, "text": "BLOCKER  ·  DODGE OR DASH", "big": false})
	return out


# ------------------------------------------------------------ builders
func _m(c: Color, e := 0.0, rough := 0.4, metal := 0.5) -> Material:
	return w.mat(c, c if e > 0.0 else Color.BLACK, e, rough, metal, 0.6, 0.0, RED)


func _build_enforcer() -> Node3D:
	var n := Node3D.new()
	var body := _m(Color(0.15, 0.16, 0.22))
	var trim := _m(Color(1.0, 0.25, 0.2), 3.0)
	var torso: MeshInstance3D = w._box(n, Vector3(0.7, 0.8, 0.45), Vector3(0, 1.35, 0), body, true)
	torso.set_meta("part", "torso")
	w._box(n, Vector3(0.72, 0.08, 0.47), Vector3(0, 1.62, 0), trim, false)
	var head: MeshInstance3D = w._box(n, Vector3(0.45, 0.4, 0.42), Vector3(0, 2.0, 0), body, true)
	head.set_meta("part", "head")
	w._box(n, Vector3(0.4, 0.1, 0.05), Vector3(0, 2.02, -0.22), _m(Color(1, 0.2, 0.1), 6.0), false)
	w._box(n, Vector3(0.6, 0.06, 0.06), Vector3(0, 2.26, 0), trim, false)
	var legs := []
	for sd in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(sd * 0.2, 0.95, 0)
		n.add_child(leg)
		w._box(leg, Vector3(0.22, 0.95, 0.26), Vector3(0, -0.47, 0), body, true)
		w._box(leg, Vector3(0.24, 0.1, 0.34), Vector3(0, -0.92, -0.05), trim, false)
		legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(sd * 0.47, 1.65, 0)
		n.add_child(arm)
		w._box(arm, Vector3(0.18, 0.75, 0.2), Vector3(0, -0.37, 0), body, true)
		legs.append(arm)
	n.set_meta("limbs", legs)
	var l := OmniLight3D.new()
	l.light_color = RED
	l.light_energy = 1.2
	l.omni_range = 4.0
	l.position = Vector3(0, 2.0, -0.6)
	n.add_child(l)
	return n


func _run_pose(n: Node3D, rate: float) -> void:
	var limbs: Array = n.get_meta("limbs")
	for i in limbs.size():
		var ph := _anim * rate + (PI if i % 4 >= 2 else 0.0) + (PI if i % 2 == 1 else 0.0)
		limbs[i].rotation.x = sin(ph) * 0.9
	n.position.y += absf(sin(_anim * rate)) * 0.08


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


func _build_titan() -> Node3D:
	var n := Node3D.new()
	n.rotation.y = PI  # faces the runner
	n.scale = Vector3.ONE * 1.35
	var armor := _m(Color(0.22, 0.2, 0.3), 0.0, 0.35, 0.7)
	var glow := _m(RED, 5.0)
	w._box(n, Vector3(4.0, 3.0, 2.4), Vector3(0, 0, 0), armor, true)
	w._box(n, Vector3(2.4, 1.4, 1.8), Vector3(0, 2.1, 0), armor, true)
	w._box(n, Vector3(1.8, 0.3, 0.1), Vector3(0, 2.2, 0.92), glow, false)
	w._sphere(n, 0.6, Vector3(0, 0.3, 1.25), glow, false)
	w._box(n, Vector3(4.2, 0.2, 2.5), Vector3(0, 1.4, 0), _m(Color(1.0, 0.7, 0.1), 2.0), false)
	var arms := []
	for sd in [-1.0, 1.0]:
		var a := Node3D.new()
		a.position = Vector3(sd * 2.5, 1.0, 0)
		a.set_meta("ph", 0.0 if sd < 0 else PI)
		n.add_child(a)
		w._box(a, Vector3(1.0, 3.2, 1.0), Vector3(0, -1.6, 0), armor, true)
		w._box(a, Vector3(1.4, 1.0, 1.4), Vector3(0, -3.4, 0), _m(Color(0.35, 0.33, 0.4)), true)
		w._box(a, Vector3(1.45, 0.15, 1.45), Vector3(0, -3.0, 0), glow, false)
		arms.append(a)
	n.set_meta("arms", arms)
	for x in [-1.2, 1.2]:
		w._cyl(n, 0.5, 0.8, Vector3(x, -1.8, 0), _m(Color(0.3, 0.8, 1.0), 4.0), Vector3.ZERO, false)
	var l := OmniLight3D.new()
	l.light_color = RED
	l.light_energy = 3.0
	l.omni_range = 16.0
	l.position = Vector3(0, 0, 2.0)
	n.add_child(l)
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


func _wave(lane: int) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(lane * LW, 0.0, -36.0)
	add_child(n)
	var c := Color(1.0, 0.5, 0.1)
	w._box(n, Vector3(2.2, 0.9, 0.5), Vector3(0, 0.45, 0), w.mat(c, c, 5.0, 0.4, 0, 0, 0.0), false)
	w._box(n, Vector3(2.2, 0.04, 6.0), Vector3(0, 0.03, -3.0), w.mat(Color(0.3, 0.1, 0.02), c, 1.5), false)
	return n
