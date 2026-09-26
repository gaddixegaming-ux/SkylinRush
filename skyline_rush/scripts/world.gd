extends Node3D
## Procedural sky-road world: neon track tiles (with holes), obstacles, gold,
## portals and decorative scenery (clouds, speaker towers, set pieces).
## The player stays at z = 0 and everything here scrolls towards +z.

const WORLD_SHADER := preload("res://shaders/world.gdshader")
const PORTAL_SHADER := preload("res://shaders/portal.gdshader")
const BEAM_SHADER := preload("res://shaders/beam.gdshader")
const WORLD_VC := preload("res://shaders/world_vc.gdshader")
const BATCH_KEYS := ["box", "sphere", "cyl", "pipe", "cone"]
const ThemesScript := preload("res://scripts/themes.gd")
const WEAK := ["jump", "crate", "drone", "pop_spikes", "drop"]
const SOLID := ["car", "speaker", "crate", "platform", "rail", "pop_wall", "drop"]

const LANE_WIDTH := 2.5
const TILE := 4.0
const HOLE_LEN := 8.0
const ROW_SPAWN_Z := -235.0
const SPAWN_Z := -205.0
const DESPAWN_Z := 14.0

const PINK := Color(1.0, 0.3, 0.75)
const CYAN := Color(0.3, 0.9, 1.0)
const GOLD := Color(1.0, 0.75, 0.2)

var objects: Node3D      # gameplay things (obstacles, coins, portals, holes)
var scenery: Node3D      # visual only
var holes: Array = []
var pulsers: Array = []  # woofer cones that pump with the beat
var spinners: Array = [] # [node, axis, speed]
var bobbers: Array = []  # [node, base_y, amp, freq, phase]
var themes
var theme := 0
var last_theme := -1
var side_cursor := [0.0, 0.0]
var over_cursor := 0.0
var far_cursor := 0.0
var prop_cursor := [0.0, 0.0]
var tunnel_rows := 0
var _t := 0.0

var spawn_rows := false
var difficulty := 0.0
var speed := 16.0
var rows_spawned := 0
var platform_rows := 0
var wall_rows := 0
var wall_side := 1

var row_cursor := 0.0
var tile_cursor := 0.0
var tile_index := 0
var pipe_cursor := 0.0
var cloud_cursor := 0.0
var tower_cursor := 0.0
var big_cursor := 0.0

var _mats := {}
var _meshes := {}
## Batching: while `batching` is on, static scenery primitives are collected and
## merged into ONE vertex-coloured mesh per parent node (flush_batches). This
## cuts draw calls from thousands to a few hundred.
var batching := false
var _pending: Array = []
var _prim_key := {}
var _prim_cache := {}
var vc_mat: ShaderMaterial


func _ready() -> void:
	themes = ThemesScript.new(self)
	objects = Node3D.new()
	add_child(objects)
	scenery = Node3D.new()
	add_child(scenery)
	# endless sea of clouds far below
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1400, 1400)
	pm.subdivide_width = 40
	pm.subdivide_depth = 60
	sea.mesh = pm
	sea.material_override = mat(Color(0.93, 0.74, 0.95), Color(1.0, 0.7, 0.95), 0.25, 1.0, 0.0, 0.0)
	sea.position = Vector3(0, -36, -300)
	sea.extra_cull_margin = 200.0
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)


# ============================================================ lifecycle
## first_row: distance to the first obstacle row (longer after a warp).
func reset(with_rows: bool, first_row := 45.0) -> void:
	for c in objects.get_children():
		c.free()
	for c in scenery.get_children():
		c.free()
	holes.clear()
	qpipes.clear()
	pulsers.clear()
	spinners.clear()
	bobbers.clear()
	last_theme = theme
	side_cursor = [26.0, 24.0]
	over_cursor = 20.0
	far_cursor = 10.0
	prop_cursor = [14.0, 8.0]
	tunnel_rows = 0
	safe_lane = 0
	prev_row_z = 0.0
	prev_safe = 0
	board_rows = 2
	spawn_rows = with_rows
	rows_spawned = 0
	platform_rows = 0
	wall_rows = 0
	row_cursor = -first_row
	tile_cursor = 24.0
	pipe_cursor = 24.0
	cloud_cursor = 30.0
	tower_cursor = 10.0
	big_cursor = -20.0
	fill()


func scroll(dz: float) -> void:
	for c in objects.get_children():
		c.position.z += dz
		if c.position.z - float(c.get_meta("half", 0.0)) > DESPAWN_Z:
			c.queue_free()
	for c in scenery.get_children():
		c.position.z += dz
		if c.position.z - float(c.get_meta("half", 0.0)) > DESPAWN_Z:
			c.queue_free()
	row_cursor += dz
	tile_cursor += dz
	pipe_cursor += dz
	cloud_cursor += dz
	tower_cursor += dz
	big_cursor += dz
	side_cursor[0] += dz
	side_cursor[1] += dz
	over_cursor += dz
	far_cursor += dz
	prop_cursor[0] += dz
	prop_cursor[1] += dz
	holes = holes.filter(func(h): return is_instance_valid(h) and not h.is_queued_for_deletion())
	qpipes = qpipes.filter(func(h): return is_instance_valid(h) and not h.is_queued_for_deletion())
	fill()


func update_fx(delta: float, beat: float) -> void:
	var alive := []
	for p in pulsers:
		if is_instance_valid(p):
			p.scale = Vector3(1.0 + beat * 0.12, 1.0 + beat * 1.4, 1.0 + beat * 0.12)
			alive.append(p)
	pulsers = alive
	var alive_s := []
	for s in spinners:
		if is_instance_valid(s[0]):
			s[0].rotate(s[1], s[2] * delta)
			alive_s.append(s)
	spinners = alive_s
	_t += delta
	var alive_b := []
	for b in bobbers:
		if is_instance_valid(b[0]):
			b[0].position.y = b[1] + sin(_t * b[3] + b[4]) * b[2]
			alive_b.append(b)
	bobbers = alive_b


func fill() -> void:
	while row_cursor > ROW_SPAWN_Z:
		var gap := randf_range(16.0, 24.0) + speed * 0.35
		gap += _spawn_row(row_cursor, gap)
		row_cursor -= gap
	batching = true
	if theme != last_theme and last_theme >= 0:
		themes.gate(SPAWN_Z, theme)
	last_theme = theme
	var sky: bool = themes.is_sky(theme)
	while tile_cursor > SPAWN_Z:
		_spawn_tile(tile_cursor)
		tile_cursor -= TILE
	while pipe_cursor > SPAWN_Z:
		if sky:
			_spawn_pipes(pipe_cursor)
		pipe_cursor -= 16.0
	for i in 2:
		while side_cursor[i] > SPAWN_Z:
			side_cursor[i] -= themes.side(side_cursor[i], -1.0 if i == 0 else 1.0, theme)
	for i in 2:
		while prop_cursor[i] > SPAWN_Z:
			prop_cursor[i] -= themes.props(prop_cursor[i], -1.0 if i == 0 else 1.0, theme)
	while over_cursor > SPAWN_Z:
		over_cursor -= themes.overhead(over_cursor, theme)
	while far_cursor > SPAWN_Z:
		far_cursor -= themes.far(far_cursor, theme)
	while cloud_cursor > SPAWN_Z:
		_spawn_clouds(cloud_cursor)
		cloud_cursor -= randf_range(7.0, 12.0)
	while tower_cursor > SPAWN_Z:
		if theme == 0:
			_spawn_tower(tower_cursor)
		tower_cursor -= randf_range(24.0, 38.0)
	while big_cursor > SPAWN_Z:
		if theme == 0:
			_spawn_big(big_cursor)
		big_cursor -= randf_range(45.0, 70.0)
	batching = false
	flush_batches()


# ============================================================ gameplay rows
## Every row has a guaranteed "safe lane" that is always passable (clear,
## jumpable or slidable). A gold coin trail leads from the previous row's safe
## lane into this one, so following the coins never gets you killed.
const TRAPS := {1: "pop_wall", 3: "pop_spikes", 4: "drop", 5: "pop_wall", 6: "pop_spikes", 7: "pop_wall", 8: "pop_spikes"}
const POWERS := ["magnet", "shield", "springs", "double"]
const POWER_COL := {"magnet": Color(1.0, 0.35, 0.4), "shield": Color(0.3, 0.9, 1.0), "springs": Color(0.4, 1.0, 0.55), "double": Color(1.0, 0.8, 0.2)}
var safe_lane := 0
var prev_row_z := 0.0
var prev_safe := 0
var board_rows := 0
var qpipes: Array = []
const VEH_THEME := {2: "skate", 5: "hover", 8: "moto"}


func _spawn_row(z: float, gap: float) -> float:
	if not spawn_rows:
		return 0.0
	rows_spawned += 1
	platform_rows = maxi(0, platform_rows - 1)
	wall_rows = maxi(0, wall_rows - 1)
	var from_lane := safe_lane
	var extra := 0.0

	# ---- set pieces
	if rows_spawned % 15 == 0 and platform_rows == 0 and wall_rows == 0:
		_spawn_portal(z)
		_guide(from_lane, from_lane, z, "portal")
		return 6.0
	if rows_spawned > 6 and rows_spawned % 11 == 6 and platform_rows == 0 and wall_rows == 0:
		_spawn_platform(z, 52.0)
		platform_rows = 3
	elif rows_spawned > 3 and rows_spawned % 7 == 3 and wall_rows == 0 and platform_rows == 0:
		wall_side = -1 if randf() < 0.5 else 1
		if theme == 2:
			_spawn_qpipe(z + 6.0, wall_side, 56.0)
			wall_rows = 3
		else:
			_spawn_wall_section(z + 6.0, wall_side, 48.0)
			wall_rows = 2
	elif rows_spawned > 5 and platform_rows == 0 and wall_rows == 0 and themes.is_sky(theme) and randf() < 0.09 + difficulty * 0.09:
		var big := speed > 24.0 and randf() < 0.5
		_guide(from_lane, from_lane, z, "hole")
		return _spawn_hole(z, 3 if big else 2, big)

	# pick this row's safe lane: never more than one lane away from the last
	var new_safe := clampi(from_lane + (randi() % 3 - 1), -1, 1)
	var tunnel_lane := 0
	if rows_spawned > 8 and rows_spawned % 19 == 9 and platform_rows == 0 and wall_rows == 0:
		tunnel_lane = -1 if randf() < 0.5 else 1
		if new_safe == tunnel_lane:
			new_safe = 0
		_spawn_tunnel(z, tunnel_lane)
		extra = 8.0
	safe_lane = new_safe

	# under a sky-highway the ground stays clear (you may drop into any lane)
	if platform_rows > 0 and rows_spawned % 11 != 6:
		_guide(from_lane, new_safe, z, "")
		_coin_line((new_safe + 1 + randi() % 2) % 3 - 1, z - 4.0, z - gap + 6.0)
		return 0.0

	var safe_type := ""
	var r0 := randf()
	if theme == 2 and r0 < 0.45:
		safe_type = "rail" if r0 < 0.25 else "kicker"
	elif r0 < 0.28:
		safe_type = "jump"
	elif r0 < 0.46:
		safe_type = "slide"

	var types: Array[String] = ["", "", ""]
	var empty_p := 0.35 - difficulty * 0.2
	for i in 3:
		var lane := i - 1
		if lane == new_safe:
			types[i] = safe_type
			continue
		if lane == tunnel_lane and tunnel_lane != 0:
			continue
		var t := ""
		if wall_rows > 0 and lane == wall_side and randf() < 0.75:
			t = ["car", "speaker", "crate"][randi() % 3]
		elif TRAPS.has(theme) and rows_spawned > 4 and randf() < 0.22:
			t = TRAPS[theme]
		elif randf() >= empty_p:
			var r := randf()
			if r < 0.16:
				t = "jump"
			elif r < 0.3:
				t = "slide"
			elif r < 0.52:
				t = "car"
			elif r < 0.7:
				t = "speaker"
			elif r < 0.86:
				t = "crate"
			elif rows_spawned > 8:
				t = "drone"
			else:
				t = "crate"
		types[i] = t

	for i in 3:
		var lane := i - 1
		match types[i]:
			"jump": _spawn_amp(lane, z)
			"slide": _spawn_laser(lane, z)
			"car":
				_spawn_car(lane, z)
				# gold on the roof: jump up and run over the traffic
				if randf() < 0.5:
					for k in 3:
						_coin(lane, z + 1.4 - k * 1.4, 2.35)
			"speaker": _spawn_speaker(lane, z)
			"crate": _spawn_crate(lane, z)
			"drone":
				_spawn_drone(lane, z)
				_set_drone_path(objects.get_child(objects.get_child_count() - 1), lane, new_safe)
			"rail": _spawn_rail(lane, z)
			"kicker": _spawn_kicker(lane, z)
			"pop_wall", "pop_spikes", "drop": _spawn_trap(lane, z, types[i])
			_:
				if lane != new_safe and lane != tunnel_lane and randf() < 0.08:
					_spawn_pad(lane, z)
		if types[i] == "jump" and lane != new_safe and randf() < 0.5:
			_coin_arc(lane, z, 1.6)
		elif types[i] == "" and lane != new_safe and lane != tunnel_lane and randf() < 0.55:
			# an extra gold line through an empty lane
			_coin_line(lane, z + 6.0, z - 6.0)
	_guide(from_lane, new_safe, z, safe_type)

	# extra gold in the open stretch after this row (endless-runner style)
	if randf() < 0.6:
		var cl := randi() % 3 - 1
		if cl == new_safe:
			cl = clampi(cl + (1 if randf() < 0.5 else -1), -1, 1)
		if cl != new_safe:
			_coin_line(cl, z - 5.0, z - gap * 0.55)
	# vehicle zones: a glowing ride token every few rows gives your ride back
	if VEH_THEME.has(theme):
		board_rows -= 1
		if board_rows <= 0:
			board_rows = 9
			_spawn_vehicle_token(new_safe, z - gap * 0.5, VEH_THEME[theme])
	# power-ups: some in the running lane, some up high for the sky jump
	if randf() < 0.16:
		_spawn_power(Vector3(new_safe * LANE_WIDTH, 1.2, z - gap * 0.5), POWERS[randi() % POWERS.size()])
	elif randf() < 0.14:
		_spawn_power(Vector3((randi() % 3 - 1) * LANE_WIDTH, randf_range(5.0, 6.0), z - gap * 0.5), POWERS[randi() % POWERS.size()])
	return extra


## Floating ride token (skateboard / hover / moto icon in a ring).
func _spawn_vehicle_token(lane: int, z: float, vtype: String) -> void:
	var n := _obj("vehicle", lane, z, 1.0)
	n.set_meta("vtype", vtype)
	n.position.y = 1.3
	var c: Color = {"skate": Color(1.0, 0.45, 0.75), "hover": Color(0.35, 0.9, 1.0), "moto": Color(1.0, 0.6, 0.2)}[vtype]
	var icon := Node3D.new()
	n.add_child(icon)
	var body := mat(c.lightened(0.2), c, 1.5, 0.3, 0.3, 0.8, 0.0, Color.WHITE)
	var wh := mat(Color(0.1, 0.1, 0.12), Color.BLACK, 0.0, 0.5)
	match vtype:
		"skate":
			var d := _box(icon, Vector3(0.36, 0.06, 1.0), Vector3.ZERO, body, false)
			d.rotation.x = 0.4
			for wz in [-0.32, 0.32]:
				_cyl(icon, 0.07, 0.4, Vector3(0, -0.1 - wz * 0.4, wz), mat(Color(0.3, 1.0, 0.8), Color(0.3, 1.0, 0.8), 2.0), Vector3(0, 0, PI / 2), false)
		"hover":
			var hb := _sphere(icon, 0.35, Vector3.ZERO, body, false)
			hb.scale = Vector3(0.7, 0.4, 1.4)
			_torus(icon, 0.25, 0.33, Vector3(0, -0.2, 0.3), mat(Color(0.4, 1.4, 1.8), Color(0.4, 1.0, 1.0), 3.0))
			_torus(icon, 0.25, 0.33, Vector3(0, -0.2, -0.3), mat(Color(0.4, 1.4, 1.8), Color(0.4, 1.0, 1.0), 3.0))
		"moto":
			var mb := _box(icon, Vector3(0.3, 0.3, 0.9), Vector3(0, 0.1, 0), body, false)
			mb.rotation.x = 0.1
			for wz in [-0.42, 0.42]:
				_cyl(icon, 0.22, 0.12, Vector3(0, -0.12, wz), wh, Vector3(0, 0, PI / 2), false)
	spinners.append([icon, Vector3(0, 1, 0), 2.0])
	_torus(n, 0.95, 1.05, Vector3.ZERO, mat(Color.WHITE, c, 3.0, 0.4, 0, 0, 1.0), Vector3(PI / 2, 0, 0))
	bobbers.append([n, 1.3, 0.15, 3.0, randf() * TAU])
	_beam(n, Vector3(0, -1.3, 0), 0.4, 6.0, c, 0.35)


func _coin_line(lane: int, z0: float, z1: float) -> void:
	var cz := z0
	while cz > z1:
		_coin(lane, cz, 1.0)
		cz -= 2.2


## Coin trail: from the previous row (prev_row_z, prev_safe lane) to this row z,
## sliding across lanes in the gap, then through this row's obstacle correctly.
func _guide(from_lane: int, to_lane: int, z: float, kind: String) -> void:
	var start := prev_row_z - 3.5 if prev_row_z < 0.0 else z + 16.0
	var end := z + 4.5
	var cz := start
	var span := maxf(1.0, start - end)
	while cz > end:
		var t := (start - cz) / span
		var x := lerpf(from_lane, to_lane, smoothstep(0.25, 0.75, t)) * LANE_WIDTH
		var c := _coin(0, cz, 1.0)
		c.position.x = x
		cz -= 2.4
	var lx := to_lane * LANE_WIDTH
	match kind:
		"jump":
			_coin_arc(to_lane, z, 1.6)
		"slide":
			for k in 4:
				_coin(to_lane, z + 2.2 - k * 1.5, 0.55)
		"rail":
			for k in 3:
				_coin(to_lane, z + 13.5 - k * 1.4, 1.2 + k * 0.45)
			var rz := z + 9.0
			while rz > z - 9.5:
				_coin(to_lane, rz, 2.2)
				rz -= 2.0
		"kicker":
			for k in 7:
				var tt := float(k) / 6.0
				_coin(to_lane, z - 1.0 - tt * 14.0, 1.2 + sin(tt * PI) * 4.5)
		"hole", "portal":
			for k in 3:
				_coin(to_lane, z + 2.0 - k * 2.0, 1.0)
		_:
			for k in 3:
				_coin(to_lane, z + 2.0 - k * 2.0, 1.0)
	prev_row_z = z
	prev_safe = to_lane
	var _unused := lx


func _set_drone_path(d: Node3D, lane: int, safe: int) -> void:
	# drones patrol between their lane and a neighbour that is NOT the safe lane
	var opts := []
	for nb in [lane - 1, lane + 1]:
		if nb >= -1 and nb <= 1 and nb != safe:
			opts.append(nb)
	if opts.is_empty():
		d.set_meta("cx", lane * LANE_WIDTH)
		d.set_meta("amp", 0.0)
	else:
		var nb: int = opts[randi() % opts.size()]
		d.set_meta("cx", (lane + nb) * 0.5 * LANE_WIDTH)
		d.set_meta("amp", LANE_WIDTH * 0.5)


func _gap_coins(z: float, gap: float) -> void:
	if randf() < 0.25:
		return
	var start := z - 5.0
	var end := z - gap + 5.0
	var style := randf()
	var lane_a := randi() % 3 - 1
	var lane_b := clampi(lane_a + ([-1, 1][randi() % 2]), -1, 1)
	var cz := start
	var i := 0
	var count := int((start - end) / 2.2)
	while cz > end:
		var t := float(i) / maxf(1.0, count)
		if style < 0.6:
			_coin(lane_a, cz, 1.0)
		elif style < 0.85:
			var x := lerpf(lane_a, lane_b, smoothstep(0.3, 0.7, t))
			var c := _coin(0, cz, 1.0)
			c.position.x = x * LANE_WIDTH
		else:
			_coin(lane_a, cz, 1.0 + 1.6 * sin(t * PI))
		cz -= 2.2
		i += 1


func _obj(kind: String, lane: int, z: float, half := 1.0) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(lane * LANE_WIDTH, 0.0, z)
	n.set_meta("kind", kind)
	n.set_meta("half", half)
	objects.add_child(n)
	return n


## Hazard look: every obstacle that can end a run gets a glowing red-orange
## silhouette (fresnel rim) and a red danger line on the road in front of it,
## so it never blends into the scenery whatever the town's colours are.
const HAZ_RIM := Color(1.0, 0.22, 0.12)


func hz(albedo: Color, emission := Color.BLACK, energy := 0.0, rough := 0.55, metal := 0.1) -> ShaderMaterial:
	return mat(albedo, emission, energy, rough, metal, 1.1, 0.0, HAZ_RIM)


func _danger_line(n: Node3D, front_z: float, width := 2.1) -> void:
	_box(n, Vector3(width, 0.03, 0.22), Vector3(0, 0.03, front_z + 0.35), mat(Color(1.0, 0.15, 0.1), Color(1.0, 0.12, 0.06), 3.5, 0.5, 0, 0, 1.5), false)
	_box(n, Vector3(width, 0.025, 0.7), Vector3(0, 0.02, front_z + 0.85), mat(Color(0.25, 0.02, 0.02), Color(1.0, 0.1, 0.05), 0.6), false)


func _stripes(n: Node3D, size: Vector3, pos: Vector3, count: int) -> void:
	var yl := mat(Color(1.0, 0.82, 0.1), Color(1.0, 0.7, 0.05), 1.2, 0.5)
	var bk := hz(Color(0.08, 0.07, 0.09))
	_box(n, size, pos, bk)
	for k in count:
		var st := _box(n, Vector3(size.x / count * 0.45, size.y * 1.3, 0.02), pos + Vector3(-size.x * 0.5 + (k + 0.5) * size.x / count, 0, size.z * 0.5 + 0.01), yl, false)
		st.rotation.z = 0.6


func _spawn_amp(lane: int, z: float) -> void:
	# low barrier -> JUMP. Yellow/black stripes = "jump me".
	var n := _obj("jump", lane, z)
	n.set_meta("box", AABB(Vector3(-0.95, 0.0, -0.25), Vector3(1.9, 0.8, 0.5)))
	if theme == 8:
		# concrete jersey barrier
		var con := hz(Color(0.78, 0.76, 0.74))
		_box(n, Vector3(2.2, 0.35, 0.6), Vector3(0, 0.18, 0), con)
		_box(n, Vector3(2.2, 0.45, 0.32), Vector3(0, 0.56, 0), con)
		_stripes(n, Vector3(2.22, 0.22, 0.33), Vector3(0, 0.62, 0), 6)
	else:
		_box(n, Vector3(2.2, 0.5, 0.5), Vector3(0, 0.25, 0), hz(Color(0.2, 0.14, 0.28)))
		_stripes(n, Vector3(2.22, 0.26, 0.52), Vector3(0, 0.62, 0), 7)
		for x in [-0.8, 0.8]:
			_box(n, Vector3(0.14, 0.14, 0.14), Vector3(x, 0.84, 0), mat(Color(1, 0.3, 0.15), Color(1, 0.2, 0.05), 5.0, 0.4, 0, 0, 2.0), false)
	_danger_line(n, 0.25)


func _spawn_laser(lane: int, z: float) -> void:
	# laser gate -> SLIDE under the red beams
	var n := _obj("slide", lane, z)
	n.set_meta("box", AABB(Vector3(-0.95, 1.25, -0.2), Vector3(1.9, 1.55, 0.4)))
	var metal := hz(Color(0.22, 0.2, 0.28), Color.BLACK, 0.0, 0.3, 0.7)
	_box(n, Vector3(0.22, 2.8, 0.22), Vector3(-1.15, 1.4, 0), metal)
	_box(n, Vector3(0.22, 2.8, 0.22), Vector3(1.15, 1.4, 0), metal)
	_stripes(n, Vector3(2.55, 0.26, 0.28), Vector3(0, 2.75, 0), 8)
	var beam := mat(Color(1, 0.2, 0.2), Color(1.0, 0.1, 0.1), 7.0, 0.5, 0.0, 0.0, 1.0)
	for y in [1.4, 1.75, 2.1]:
		_box(n, Vector3(2.1, 0.08, 0.08), Vector3(0, y, 0), beam)
	# translucent red "curtain" so the blocked height is obvious
	_box(n, Vector3(2.1, 0.8, 0.02), Vector3(0, 1.75, 0), mat(Color(0.5, 0.02, 0.05), Color(1, 0.1, 0.1), 0.8), false)
	_box(n, Vector3(0.3, 1.0, 0.3), Vector3(-1.15, 1.8, 0), mat(Color(0.2, 0.15, 0.3), Color(1, 0.2, 0.2), 2.0))
	_box(n, Vector3(0.3, 1.0, 0.3), Vector3(1.15, 1.8, 0), mat(Color(0.2, 0.15, 0.3), Color(1, 0.2, 0.2), 2.0))
	# "slide" chevrons pointing down on both posts
	var ch := mat(Color.WHITE, Color(1, 0.9, 0.3), 2.5)
	for sd in [-1.15, 1.15]:
		for k in 2:
			var c1 := _box(n, Vector3(0.05, 0.3, 0.06), Vector3(sd - 0.07, 0.75 - k * 0.3, 0.13), ch, false)
			c1.rotation.z = 0.7
			var c2 := _box(n, Vector3(0.05, 0.3, 0.06), Vector3(sd + 0.07, 0.75 - k * 0.3, 0.13), ch, false)
			c2.rotation.z = -0.7
	_danger_line(n, 0.2)


func _spawn_car(lane: int, z: float) -> void:
	# traffic -> dodge, or jump onto its roof
	var n := _obj("car", lane, z, 2.3)
	n.set_meta("box", AABB(Vector3(-0.9, 0.0, -2.1), Vector3(1.8, 1.55, 4.2)))
	var cols := [Color(0.9, 0.12, 0.15), Color(0.1, 0.35, 0.95), Color(0.98, 0.7, 0.05), Color(0.1, 0.1, 0.12), Color(0.95, 0.95, 0.97), Color(0.1, 0.65, 0.4)]
	var body_c: Color = cols[randi() % cols.size()]
	var body := hz(body_c, Color.BLACK, 0.0, 0.25, 0.5)
	_box(n, Vector3(1.95, 0.7, 4.4), Vector3(0, 0.6, 0), body)
	_box(n, Vector3(2.0, 0.25, 4.2), Vector3(0, 0.2, 0), hz(Color(0.08, 0.07, 0.1)))
	_box(n, Vector3(1.65, 0.55, 2.2), Vector3(0, 1.2, 0.25), mat(Color(0.1, 0.12, 0.2), Color(0.3, 0.4, 0.7), 0.25, 0.1, 0.8, 0.5, 0.0, HAZ_RIM))
	_box(n, Vector3(1.66, 0.08, 2.0), Vector3(0, 1.51, 0.25), body)
	var head := mat(Color(1, 1, 0.95), Color(1, 0.95, 0.85), 5.0)
	_box(n, Vector3(0.45, 0.16, 0.05), Vector3(-0.6, 0.66, 2.21), head)
	_box(n, Vector3(0.45, 0.16, 0.05), Vector3(0.6, 0.66, 2.21), head)
	var tail := mat(Color(1, 0.1, 0.1), Color(1, 0.05, 0.05), 5.0)
	_box(n, Vector3(0.5, 0.14, 0.05), Vector3(-0.6, 0.7, -2.21), tail)
	_box(n, Vector3(0.5, 0.14, 0.05), Vector3(0.6, 0.7, -2.21), tail)
	var wheel := mat(Color(0.06, 0.05, 0.08))
	for wx in [-0.95, 0.95]:
		for wz in [-1.4, 1.4]:
			_cyl(n, 0.36, 0.3, Vector3(wx, 0.36, wz), wheel, Vector3(0, 0, PI / 2))
	_danger_line(n, 2.2)


func _spawn_speaker(lane: int, z: float) -> void:
	# tall block -> must change lane
	var n := _obj("speaker", lane, z, 1.2)
	n.set_meta("box", AABB(Vector3(-0.95, 0.0, -1.0), Vector3(1.9, 3.4, 2.0)))
	if theme == 8:
		# truck trailer
		n.set_meta("box", AABB(Vector3(-0.95, 0.0, -3.0), Vector3(1.9, 3.4, 6.0)))
		n.set_meta("half", 3.3)
		var tc: Color = [Color(0.95, 0.95, 0.97), Color(0.9, 0.3, 0.1), Color(0.2, 0.45, 0.8)][randi() % 3]
		_box(n, Vector3(2.2, 2.7, 5.2), Vector3(0, 1.95, -0.4), hz(tc, Color.BLACK, 0.0, 0.4, 0.2))
		_box(n, Vector3(2.1, 1.6, 1.3), Vector3(0, 1.3, 2.6), hz(Color(0.85, 0.15, 0.15), Color.BLACK, 0.0, 0.3, 0.4))
		_box(n, Vector3(1.9, 0.6, 0.05), Vector3(0, 1.75, 3.26), mat(Color(0.1, 0.15, 0.25), Color(0.3, 0.4, 0.6), 0.3, 0.1, 0.8))
		_stripes(n, Vector3(2.22, 0.3, 0.05), Vector3(0, 0.8, 2.85), 6)
		for wz in [-2.2, -1.2, 2.4]:
			for wx in [-1.0, 1.0]:
				_cyl(n, 0.42, 0.3, Vector3(wx, 0.42, wz), mat(Color(0.06, 0.05, 0.08)), Vector3(0, 0, PI / 2))
		_danger_line(n, 3.3)
		return
	_box(n, Vector3(2.2, 3.4, 2.2), Vector3(0, 1.7, 0), hz(Color(0.16, 0.12, 0.22)))
	_box(n, Vector3(2.26, 0.12, 2.26), Vector3(0, 3.4, 0), mat(Color(1, 0.25, 0.2), Color(1, 0.2, 0.1), 3.0, 0.5, 0, 0, 1.5))
	_stripes(n, Vector3(2.26, 0.3, 2.26), Vector3(0, 0.2, 0), 8)
	_woofer(n, Vector3(0, 2.45, 1.11), 0.62, Vector3(PI / 2, 0, 0), Color(1, 0.3, 0.2))
	_woofer(n, Vector3(0, 1.25, 1.11), 0.6, Vector3(PI / 2, 0, 0), Color(1, 0.55, 0.1))
	_danger_line(n, 1.1)


func _spawn_orb(lane: int, z: float) -> void:
	var n := _obj("orb", lane, z)
	n.position.y = 1.1
	_sphere(n, 0.38, Vector3.ZERO, mat(CYAN, CYAN, 4.0, 0.2, 0.0, 1.0, 1.0, Color(1, 1, 1)))
	var ring := _torus(n, 0.55, 0.62, Vector3.ZERO, mat(Color.WHITE, PINK, 3.0), Vector3(PI / 2, 0, 0))
	spinners.append([ring, Vector3(0, 1, 0), 3.0])


func _coin(lane: int, z: float, y: float) -> Node3D:
	var n := _obj("coin", lane, z, 0.5)
	n.position.y = y
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh("coin")
	mi.material_override = mat(Color(1.0, 0.78, 0.2), Color(1.0, 0.6, 0.1), 0.3, 0.2, 0.9, 0.9, 0.2, Color(1, 1, 0.8))
	mi.rotation.x = PI / 2
	mi.extra_cull_margin = 60.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	return n


func _coin_arc(lane: int, z: float, height: float) -> void:
	for i in range(-2, 3):
		var t := float(i) / 2.5
		_coin(lane, z - i * 1.7, 1.0 + height * (1.0 - t * t))


func _spawn_portal(z: float) -> void:
	var n := _obj("portal", 0, z, 1.0)
	n.set_meta("hit", false)
	var cy := 2.2
	var ring_m := mat(Color(0.8, 0.95, 1.0), CYAN, 3.5, 0.3, 0.3, 0.0, 1.5)
	_torus(n, 4.7, 5.3, Vector3(0, cy, 0), ring_m, Vector3(PI / 2, 0, 0))
	_torus(n, 5.35, 5.55, Vector3(0, cy, 0), mat(Color(0.3, 0.2, 0.4), PINK, 2.0), Vector3(PI / 2, 0, 0))
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(9.6, 9.6)
	q.mesh = qm
	var pm := ShaderMaterial.new()
	pm.shader = PORTAL_SHADER
	pm.set_shader_parameter("color", CYAN)
	q.material_override = pm
	q.position = Vector3(0, cy, 0)
	q.extra_cull_margin = 60.0
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(q)
	var cab := mat(Color(0.85, 0.82, 0.92), Color.BLACK, 0.0, 0.4, 0.4, 0.2)
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		var p := Vector3(cos(a) * 5.9, sin(a) * 5.9 + cy, 0)
		_box(n, Vector3(1.3, 1.3, 1.0), p, cab)
		_woofer(n, p + Vector3(0, 0, 0.51), 0.45, Vector3(PI / 2, 0, 0), [PINK, CYAN][i % 2])
	for lane in [-1, 0, 1]:
		for k in 4:
			_coin(lane, z + 4.5 - k * 3.0, 1.0)


func _spawn_hole(z: float, tiles: int, anchor: bool) -> float:
	# snap the hole to the tile grid
	var k := ceilf((tile_cursor - (z + 3.0)) / TILE)
	var near := tile_cursor - k * TILE
	var hl := tiles * TILE
	var h := _obj("hole", 0, near, hl)
	h.set_meta("len", hl)
	holes.append(h)
	if anchor:
		_spawn_anchor(Vector3(0, 7.2, near - hl * 0.5 + 1.0))
		for i in 6:
			_coin(0, near - 1.0 - i * 2.2, 5.6 + sin(i / 5.0 * PI) * 0.8)
	else:
		var lane := safe_lane
		for i in 7:
			var t := float(i) / 6.0
			_coin(lane, near + 3.0 - t * (hl + 6.0), 1.2 + 2.0 * sin(t * PI))
	# the pit: dark walls going down, so the gap reads as a hole and not as
	# more (pink) road, with glowing red lips on both edges
	var b := Node3D.new()
	b.position = Vector3(0, 0, near - hl * 0.5)
	b.set_meta("half", hl)
	scenery.add_child(b)
	var dark := mat(Color(0.03, 0.02, 0.05), Color.BLACK, 0.0, 0.9)
	var wall := mat(Color(0.06, 0.04, 0.08), Color(0.5, 0.05, 0.1), 0.15, 0.8)
	_box(b, Vector3(8.4, 0.3, hl), Vector3(0, -9.0, 0), dark, false)
	for sd in [-1.0, 1.0]:
		_box(b, Vector3(0.3, 9.0, hl), Vector3(sd * 4.05, -4.5, 0), wall, false)
	_box(b, Vector3(8.4, 9.0, 0.3), Vector3(0, -4.5, -hl * 0.5 - 0.15), wall, false)
	_box(b, Vector3(8.4, 9.0, 0.3), Vector3(0, -4.5, hl * 0.5 + 0.15), wall, false)
	var lip := mat(Color(1.0, 0.15, 0.1), Color(1.0, 0.1, 0.05), 5.0, 0.4, 0, 0, 2.0)
	for zz in [hl * 0.5, -hl * 0.5]:
		_box(b, Vector3(8.4, 0.12, 0.25), Vector3(0, 0.02, zz), lip, false)
		for j in 5:
			_box(b, Vector3(0.12, 1.2, 0.2), Vector3(-3.2 + j * 1.6, -0.62, zz), lip, false)
	# warning beacons on both sides of the near edge
	for sd in [-1.0, 1.0]:
		_cyl(b, 0.12, 1.4, Vector3(sd * 4.4, 0.7, hl * 0.5 + 0.8), mat(Color(0.2, 0.2, 0.22)), Vector3.ZERO, false)
		_sphere(b, 0.25, Vector3(sd * 4.4, 1.5, hl * 0.5 + 0.8), mat(Color(1, 0.2, 0.1), Color(1, 0.15, 0.05), 6.0, 0.3, 0, 0, 3.0), false)
	_beam(b, Vector3(0, -9.0, 0), 3.2, 12.0, Color(1.0, 0.2, 0.15), 0.25)
	return hl


# ============================================================ track
func _spawn_tile(e: float) -> void:
	tile_index += 1
	var warn := false
	for h in holes:
		if not is_instance_valid(h):
			continue
		var near: float = h.position.z
		var hl: float = h.get_meta("len", HOLE_LEN)
		if e <= near + 0.5 and e > near - hl + 0.5:
			return
		if absf((e - TILE) - near) < 0.5 or absf((e - 2.0 * TILE) - near) < 0.5 or absf(e - (near - hl)) < 0.5:
			warn = true
	var n := Node3D.new()
	n.position = Vector3(0, 0, e - TILE * 0.5)
	n.set_meta("half", TILE * 0.5)
	scenery.add_child(n)
	themes.build_tile(n, theme, tile_index)
	if warn:
		# yellow / red chevrons across the whole road: GAP AHEAD
		var y := mat(Color(1.0, 0.85, 0.1), Color(1.0, 0.7, 0.05), 2.5, 0.5, 0, 0, 1.5)
		var r := mat(Color(1.0, 0.15, 0.1), Color(1.0, 0.1, 0.05), 3.0, 0.5, 0, 0, 2.0)
		for i in 6:
			var x := -3.4 + i * 1.36
			var c1 := _box(n, Vector3(0.8, 0.03, 0.22), Vector3(x - 0.24, 0.025, 0.6), y if i % 2 == 0 else r, false)
			c1.rotation.y = 0.7
			var c2 := _box(n, Vector3(0.8, 0.03, 0.22), Vector3(x + 0.24, 0.025, 0.6), y if i % 2 == 0 else r, false)
			c2.rotation.y = -0.7


func _spawn_pipes(e: float) -> void:
	var n := Node3D.new()
	n.position = Vector3(0, 0, e - 8.0)
	n.set_meta("half", 8.0)
	scenery.add_child(n)
	var pipe := mat(Color(0.78, 0.7, 0.9), Color.BLACK, 0.0, 0.3, 0.6, 0.3)
	var band := mat(Color(1, 1, 1), CYAN, 3.0, 0.3, 0, 0, 1.2)
	for s in [-1.0, 1.0]:
		_cyl(n, 0.36, 16.0, Vector3(s * 4.75, -0.55, 0), pipe, Vector3(PI / 2, 0, 0), false, "pipe")
		_cyl(n, 0.22, 16.0, Vector3(s * 4.45, -1.2, 0), pipe, Vector3(PI / 2, 0, 0), false, "pipe")
		_cyl(n, 0.44, 0.2, Vector3(s * 4.75, -0.55, 0), band, Vector3(PI / 2, 0, 0), false)


# ============================================================ scenery
func _spawn_clouds(z: float) -> void:
	if not themes.is_sky(theme):
		if randf() < 0.5:
			var sd := -1.0 if randf() < 0.5 else 1.0
			_cloud(Vector3(sd * randf_range(30.0, 80.0), randf_range(28.0, 45.0), z), randf_range(1.5, 2.8))
		return
	for i in randi_range(1, 3):
		var side := -1.0 if randf() < 0.5 else 1.0
		var s := randf_range(0.8, 2.2)
		var pos: Vector3
		if randf() < 0.7:
			pos = Vector3(side * (11.0 + 6.0 * s + randf_range(0.0, 35.0)), randf_range(-15.0, -4.0), z - randf_range(0, 6))
		else:
			pos = Vector3(side * randf_range(28.0, 65.0), randf_range(6.0, 24.0), z - randf_range(0, 6))
		_cloud(pos, s)
	if randf() < 0.4:
		_cloud(Vector3(randf_range(-6, 6), randf_range(-17.0, -9.0), z), randf_range(1.5, 2.6))


func _cloud(pos: Vector3, s: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.set_meta("half", 12.0 * s)
	scenery.add_child(n)
	var cols := [Color(1.0, 0.82, 0.94), Color(0.93, 0.8, 1.0), Color(1.0, 0.9, 0.97), Color(0.88, 0.76, 1.0)]
	var c: Color = cols[randi() % cols.size()]
	var m := mat(c, Color(1.0, 0.75, 0.95), 0.18, 1.0, 0.0, 0.55, 0.0, Color(1, 0.95, 1))
	for k in randi_range(4, 8):
		var r := randf_range(1.6, 3.6) * s
		var mi := _sphere(n, r, Vector3(randf_range(-4, 4) * s, randf_range(-0.8, 1.2) * s, randf_range(-3, 3) * s), m, false)
		mi.scale.y *= 0.78


func _woofer(parent: Node3D, pos: Vector3, r: float, rot: Vector3, glow: Color) -> void:
	var w := Node3D.new()
	w.position = pos
	w.rotation = rot
	parent.add_child(w)
	_cyl(w, r * 1.12, 0.1, Vector3.ZERO, mat(glow, glow, 2.5, 0.4, 0, 0, 2.0), Vector3.ZERO, false)
	var cone := Node3D.new()
	w.add_child(cone)
	_cyl(cone, r, 0.14, Vector3(0, 0.02, 0), mat(Color(0.06, 0.05, 0.09), Color.BLACK, 0.0, 0.8), Vector3.ZERO, false)
	_sphere(cone, r * 0.3, Vector3(0, 0.08, 0), mat(Color(0.8, 0.8, 0.9), Color.BLACK, 0.0, 0.2, 0.8, 0.3), false)
	pulsers.append(cone)


func _spawn_tower(z: float) -> void:
	var side := -1.0 if randf() < 0.5 else 1.0
	var n := Node3D.new()
	n.position = Vector3(side * randf_range(15.0, 36.0), randf_range(-20.0, -8.0), z)
	n.set_meta("half", 8.0)
	n.rotation = Vector3(randf_range(-0.08, 0.08), randf_range(-0.5, 0.5), randf_range(-0.12, 0.12))
	scenery.add_child(n)
	var size := randf_range(3.5, 5.5)
	var cols := [Color(0.88, 0.85, 0.94), Color(0.24, 0.19, 0.32), Color(0.96, 0.78, 0.92)]
	var body := mat(cols[randi() % cols.size()], Color.BLACK, 0.0, 0.45, 0.35, 0.25)
	var levels := randi_range(2, 5)
	for l in levels:
		var y := l * size + size * 0.5
		_box(n, Vector3(size, size, size), Vector3(0, y, 0), body, false)
		_box(n, Vector3(size + 0.1, 0.18, size + 0.1), Vector3(0, y + size * 0.5, 0), mat(PINK, PINK, 2.0, 0.4, 0, 0, 1.0), false)
		var glow: Color = [PINK, CYAN][l % 2]
		_woofer(n, Vector3(0, y, size * 0.5 + 0.01), size * 0.34, Vector3(PI / 2, 0, 0), glow)
		_woofer(n, Vector3(-side * (size * 0.5 + 0.01), y, 0), size * 0.3, Vector3(0, 0, side * PI / 2), glow)


func _spawn_big(z: float) -> void:
	var side := -1.0 if randf() < 0.5 else 1.0
	var n := Node3D.new()
	n.set_meta("half", 20.0)
	scenery.add_child(n)
	match randi() % 7:
		0: # floating ball planet with ring
			n.position = Vector3(side * randf_range(26.0, 50.0), randf_range(6.0, 22.0), z)
			var r := snappedf(randf_range(3.0, 6.0), 0.5)
			_sphere(n, r, Vector3.ZERO, mat(Color(1.0, 0.52, 0.3), Color(1.0, 0.4, 0.2), 0.2, 0.6, 0.0, 0.5, 0.0, Color(1, 0.8, 0.9)), false)
			var ring := _torus(n, r * 1.35, r * 1.5, Vector3.ZERO, mat(Color(0.9, 0.8, 1.0), PINK, 1.5), Vector3(0.5, 0, 0.3))
			spinners.append([n, Vector3(0, 1, 0), 0.2])
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		1: # microphone tower
			n.position = Vector3(side * randf_range(26.0, 44.0), randf_range(-22.0, -12.0), z)
			var metal := mat(Color(0.8, 0.78, 0.9), Color.BLACK, 0.0, 0.3, 0.8, 0.3)
			_cyl(n, 1.2, 22.0, Vector3(0, 11.0, 0), metal, Vector3.ZERO, false)
			_sphere(n, 4.6, Vector3(0, 26.0, 0), mat(Color(0.45, 0.42, 0.55), Color.BLACK, 0.0, 0.35, 0.9, 0.5), false)
			_torus(n, 4.55, 4.9, Vector3(0, 26.0, 0), mat(Color.WHITE, CYAN, 3.0, 0.4, 0, 0, 1.2), Vector3.ZERO)
			_torus(n, 3.1, 3.4, Vector3(0, 23.0, 0), mat(Color.WHITE, PINK, 2.5), Vector3.ZERO)
			_cyl(n, 2.6, 2.5, Vector3(0, 21.0, 0), metal, Vector3.ZERO, false)
		2: # giant speaker arch over the road
			n.position = Vector3(0, 3.0, z)
			var cy := 0.0
			_torus(n, 13.0, 14.0, Vector3(0, cy, 0), mat(Color(0.85, 0.82, 0.95), CYAN, 1.2, 0.3, 0.5, 0.2, 1.0), Vector3(PI / 2, 0, 0))
			var cab := mat(Color(0.25, 0.2, 0.33), Color.BLACK, 0.0, 0.4, 0.4, 0.25)
			for i in 10:
				var a := PI * i / 9.0
				var p := Vector3(cos(a) * 14.6, sin(a) * 14.6 + cy, 0)
				_box(n, Vector3(2.4, 2.4, 1.8), p, cab, false)
				_woofer(n, p + Vector3(0, 0, 0.91), 0.8, Vector3(PI / 2, 0, 0), [PINK, CYAN][i % 2])
		3: # spinning speaker cube cluster
			n.position = Vector3(side * randf_range(20.0, 40.0), randf_range(8.0, 20.0), z)
			var cab := mat(Color(0.9, 0.87, 0.96), Color.BLACK, 0.0, 0.4, 0.3, 0.25)
			for i in 4:
				var p := Vector3((i % 2) * 3.2 - 1.6, (i / 2) * 3.2 - 1.6, 0)
				_box(n, Vector3(3.1, 3.1, 3.1), p, cab, false)
				_woofer(n, p + Vector3(0, 0, 1.56), 1.0, Vector3(PI / 2, 0, 0), [PINK, CYAN][i % 2])
			spinners.append([n, Vector3(0.3, 1, 0.2).normalized(), 0.35])
		4: # giant spinning vinyl record
			n.position = Vector3(side * randf_range(34.0, 55.0), randf_range(4.0, 18.0), z)
			var rec := Node3D.new()
			rec.rotation = Vector3(randf_range(0.8, 1.3), 0, side * 0.3)
			n.add_child(rec)
			_cyl(rec, 13.0, 0.5, Vector3.ZERO, mat(Color(0.06, 0.05, 0.09), Color.BLACK, 0.0, 0.15, 0.6, 0.6, 0.0, Color(0.6, 0.5, 1.0)), Vector3.ZERO, false)
			for rr in [5.5, 7.5, 9.5, 11.5]:
				_torus(rec, rr, rr + 0.12, Vector3(0, 0.27, 0), mat(Color(0.2, 0.2, 0.3), Color(0.6, 0.4, 1.0), 1.2))
			_cyl(rec, 4.0, 0.56, Vector3.ZERO, mat(Color(1.0, 0.4, 0.75), PINK, 0.8), Vector3.ZERO, false)
			_cyl(rec, 0.5, 0.7, Vector3.ZERO, mat(Color.WHITE, CYAN, 2.0), Vector3.ZERO, false)
			spinners.append([rec, Vector3(0, 1, 0), 0.6])
		5: # floating island with a candy tree and a light beam
			n.position = Vector3(side * randf_range(18.0, 40.0), randf_range(-6.0, 6.0), z)
			var r := snappedf(randf_range(4.0, 7.0), 1.0)
			var rock := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 1.0
			cm.bottom_radius = 0.05
			cm.height = 1.0
			cm.radial_segments = 7
			rock.mesh = cm
			rock.material_override = mat(Color(0.45, 0.3, 0.55), Color.BLACK, 0.0, 0.9, 0.0, 0.3)
			rock.scale = Vector3(r, r * 1.3, r)
			rock.position.y = -r * 0.65
			rock.extra_cull_margin = 60.0
			n.add_child(rock)
			_cyl(n, r * 1.02, 0.5, Vector3(0, 0.1, 0), mat(Color(0.55, 0.95, 0.8), Color.BLACK, 0.0, 0.8, 0.0, 0.4), Vector3.ZERO, false)
			_cyl(n, 0.35, 3.0, Vector3(0, 1.8, 0), mat(Color(0.5, 0.35, 0.3)), Vector3.ZERO, false)
			var leaf: Color = [Color(1.0, 0.55, 0.8), Color(0.6, 0.9, 1.0), Color(1.0, 0.85, 0.5)][randi() % 3]
			_sphere(n, 2.0, Vector3(0, 4.2, 0), mat(leaf, leaf, 0.3, 0.9, 0.0, 0.5), false)
			_sphere(n, 1.4, Vector3(1.2, 3.4, 0.5), mat(leaf, leaf, 0.3, 0.9, 0.0, 0.5), false)
			_beam(n, Vector3(0, -40, 0), 1.2, 40.0, leaf, 0.25)
		6: # twin searchlight beams from the cloud sea
			n.position = Vector3(side * randf_range(14.0, 30.0), -30.0, z)
			var bc: Color = [PINK, CYAN, Color(0.7, 0.5, 1.0)][randi() % 3]
			var b1 := _beam(n, Vector3.ZERO, 2.5, 90.0, bc, 0.3)
			b1.rotation.z = side * 0.25
			var b2 := _beam(n, Vector3(side * 8.0, 0, -6.0), 2.0, 80.0, bc, 0.25)
			b2.rotation.z = -side * 0.15


# ============================================================ new map pieces
func _spawn_crate(lane: int, z: float) -> void:
	# breakable crates: dash / slam through them, or change lane
	var n := _obj("crate", lane, z, 1.1)
	n.set_meta("box", AABB(Vector3(-0.9, 0.0, -0.9), Vector3(1.8, 2.4, 1.8)))
	if theme == 8:
		# stacked oil barrels
		var bar := hz(Color(0.95, 0.45, 0.08), Color.BLACK, 0.0, 0.4, 0.3)
		for bx in [-0.45, 0.45]:
			for by in [0.0, 1.2]:
				_cyl(n, 0.42, 1.1, Vector3(bx, by + 0.56, 0.0), bar)
				_cyl(n, 0.44, 0.1, Vector3(bx, by + 0.8, 0.0), mat(Color.WHITE, Color.WHITE, 1.0))
		_danger_line(n, 0.9)
		return
	var body := hz(Color(0.95, 0.5, 0.15), Color.BLACK, 0.0, 0.6, 0.1)
	var edge := mat(Color(0.3, 0.15, 0.05), Color.BLACK, 0.0, 0.6)
	_box(n, Vector3(1.9, 1.15, 1.9), Vector3(0, 0.58, 0), body)
	_box(n, Vector3(1.6, 1.15, 1.6), Vector3(0.1, 1.73, 0.05), body)
	for y in [0.02, 1.15, 2.3]:
		_box(n, Vector3(1.95 if y < 2.0 else 1.65, 0.08, 1.95 if y < 2.0 else 1.65), Vector3(0, y, 0), edge, false)
	# "breakable" crack mark
	var mk := mat(Color.WHITE, Color(1, 0.95, 0.8), 2.0)
	var m1 := _box(n, Vector3(0.9, 0.1, 0.02), Vector3(0, 0.58, 0.96), mk, false)
	m1.rotation.z = 0.6
	var m2 := _box(n, Vector3(0.9, 0.1, 0.02), Vector3(0, 0.58, 0.96), mk, false)
	m2.rotation.z = -0.6
	_danger_line(n, 0.95)


func _spawn_drone(lane: int, z: float) -> void:
	# patrolling drone that sweeps across lanes: slide under, dodge, or smash it
	var n := _obj("drone", lane, z, 1.0)
	n.set_meta("box", AABB(Vector3(-0.7, 1.3, -0.5), Vector3(1.4, 1.0, 1.0)))
	n.set_meta("ph", randf() * TAU)
	n.set_meta("t", 0.0)
	var shell := hz(Color(0.12, 0.1, 0.16), Color.BLACK, 0.0, 0.3, 0.6)
	var s := _sphere(n, 0.7, Vector3(0, 1.8, 0), shell)
	s.scale = Vector3(0.8, 0.45, 0.7)
	_sphere(n, 0.24, Vector3(0, 1.8, 0.45), mat(Color(1, 0.2, 0.2), Color(1, 0.1, 0.1), 7.0, 0.3, 0.0, 0.0, 1.5))
	var ring := _torus(n, 0.85, 0.95, Vector3(0, 1.8, 0), mat(Color(1, 0.8, 0.1), Color(1, 0.6, 0.05), 3.0))
	spinners.append([ring, Vector3(0, 1, 0), 6.0])
	for x in [-0.75, 0.75]:
		var rotor := _cyl(n, 0.35, 0.04, Vector3(x, 2.25, 0), mat(Color(1, 1, 1), Color(1, 0.3, 0.2), 2.0), Vector3.ZERO, false)
		spinners.append([rotor, Vector3(0, 1, 0), 25.0])
	_beam(n, Vector3(0, 0.0, 0), 0.7, 1.8, Color(1, 0.15, 0.1), 0.5)
	# red scan spot on the road under it
	_cyl(n, 0.8, 0.02, Vector3(0, 0.03, 0), mat(Color(0.4, 0.02, 0.02), Color(1, 0.1, 0.05), 2.5, 0.5, 0, 0, 2.0), Vector3.ZERO, false)


func _spawn_pad(lane: int, z: float) -> void:
	var n := _obj("pad", lane, z, 1.5)
	n.set_meta("hit", false)
	var m := mat(CYAN, CYAN, 3.5, 0.4, 0.0, 0.0, 2.0)
	_box(n, Vector3(2.0, 0.04, 3.0), Vector3(0, 0.01, 0), mat(Color(0.1, 0.2, 0.3), CYAN, 0.6), false)
	for i in 3:
		var zz := 0.9 - i * 0.9
		var c1 := _box(n, Vector3(0.8, 0.05, 0.18), Vector3(-0.32, 0.03, zz), m, false)
		c1.rotation.y = -0.6
		var c2 := _box(n, Vector3(0.8, 0.05, 0.18), Vector3(0.32, 0.03, zz), m, false)
		c2.rotation.y = 0.6


## Power-up pickup: magnet / shield / slow-mo / 2x. Each has its own icon
## shape inside a glowing ring so they read at a glance.
func _spawn_power(pos: Vector3, ptype: String) -> void:
	var n := Node3D.new()
	n.position = pos
	n.set_meta("kind", "power")
	n.set_meta("ptype", ptype)
	n.set_meta("half", 1.0)
	objects.add_child(n)
	var c: Color = POWER_COL[ptype]
	var icon := Node3D.new()
	n.add_child(icon)
	var m := mat(c.lightened(0.25), c, 3.0, 0.25, 0.3, 0.8, 1.0, Color.WHITE)
	var wm := mat(Color.WHITE, Color.WHITE, 2.5, 0.3)
	match ptype:
		"magnet":
			var u := _torus(icon, 0.28, 0.46, Vector3(0, 0.05, 0), m, Vector3(PI / 2, 0, 0))
			u.scale = Vector3(1, 1, 1)
			_box(icon, Vector3(0.18, 0.3, 0.18), Vector3(-0.37, -0.2, 0), m, false)
			_box(icon, Vector3(0.18, 0.3, 0.18), Vector3(0.37, -0.2, 0), m, false)
			_box(icon, Vector3(0.19, 0.12, 0.19), Vector3(-0.37, -0.38, 0), wm, false)
			_box(icon, Vector3(0.19, 0.12, 0.19), Vector3(0.37, -0.38, 0), wm, false)
		"shield":
			var sh := _sphere(icon, 0.45, Vector3.ZERO, m, false)
			sh.scale = Vector3(0.42, 0.52, 0.16)
			_box(icon, Vector3(0.08, 0.5, 0.2), Vector3(0, 0, 0), wm, false)
		"springs":
			# a sneaker on a coil spring
			_box(icon, Vector3(0.5, 0.2, 0.28), Vector3(0.05, 0.22, 0), m, false)
			_box(icon, Vector3(0.24, 0.28, 0.28), Vector3(-0.1, 0.42, 0), m, false)
			_box(icon, Vector3(0.52, 0.06, 0.3), Vector3(0.05, 0.1, 0), wm, false)
			for k in 3:
				_torus(icon, 0.1, 0.16, Vector3(0.05, -0.05 - k * 0.12, 0), wm)
		"double":
			var g := _mi(icon, _mesh("gem"), Vector3.ZERO, m, false)
			g.scale = Vector3(0.4, 0.5, 0.4)
			_torus(icon, 0.5, 0.56, Vector3.ZERO, wm, Vector3(PI / 2, 0, 0))
	spinners.append([icon, Vector3(0, 1, 0), 2.2])
	var ring := _torus(n, 0.8, 0.9, Vector3.ZERO, mat(Color.WHITE, c, 3.0, 0.3, 0, 0, 1.0), Vector3(PI / 2, 0, 0))
	spinners.append([ring, Vector3(0.2, 1, 0).normalized(), 3.0])
	bobbers.append([n, pos.y, 0.18, 3.0, randf() * TAU])
	_beam(n, Vector3(0, -pos.y, 0), 0.3, pos.y + 1.0, c)


func _spawn_anchor(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	n.set_meta("kind", "anchor")
	n.set_meta("used", false)
	n.set_meta("half", 2.0)
	objects.add_child(n)
	var g := Color(0.4, 1.0, 0.6)
	_sphere(n, 0.45, Vector3.ZERO, mat(Color.WHITE, g, 4.0, 0.2, 0.0, 1.0, 1.0, Color.WHITE), false)
	var r1 := _torus(n, 0.9, 1.05, Vector3.ZERO, mat(Color.WHITE, g, 3.0, 0.3, 0.0, 0.0, 1.0), Vector3(PI / 2, 0, 0))
	var r2 := _torus(n, 1.35, 1.45, Vector3.ZERO, mat(Color(0.2, 0.3, 0.25), g, 1.5), Vector3.ZERO)
	spinners.append([r1, Vector3(0, 0, 1), 2.0])
	spinners.append([r2, Vector3(1, 0, 0), 1.3])
	_beam(n, Vector3(0, -pos.y - 4.0, 0), 0.35, pos.y + 4.0, g)


func _spawn_platform(z: float, length: float) -> void:
	# a glass sky-highway high above the road, reached by grappling the anchor
	_spawn_anchor(Vector3(0, 8.8, z + 3.0))
	var n := _obj("platform", 0, z - length * 0.5, length * 0.5)
	n.set_meta("box", AABB(Vector3(-4.2, 5.4, -length * 0.5), Vector3(8.4, 0.6, length)))
	var deck := mat(Color(0.35, 0.5, 0.85), Color(0.3, 0.5, 1.0), 0.08, 0.15, 0.5, 0.25, 0.0, Color(0.6, 1, 1))
	var rail := mat(CYAN, CYAN, 3.0, 0.4, 0.0, 0.0, 1.2)
	var under := mat(PINK, PINK, 2.0, 0.5, 0, 0, 1.0)
	var segs := int(length / TILE)
	for i in segs:
		var zz := length * 0.5 - TILE * 0.5 - i * TILE
		_box(n, Vector3(8.4, 0.6, TILE - 0.05), Vector3(0, 5.7, zz), deck)
		_box(n, Vector3(0.3, 0.5, TILE), Vector3(-4.25, 6.25, zz), rail, false)
		_box(n, Vector3(0.3, 0.5, TILE), Vector3(4.25, 6.25, zz), rail, false)
		_box(n, Vector3(6.0, 0.06, 0.4), Vector3(0, 5.37, zz), under, false)
		if i % 3 == 1:
			for x in [-3.0, 3.0]:
				_cyl(n, 0.3, 26.0, Vector3(x, -7.6, zz), mat(Color(0.7, 0.65, 0.85), Color.BLACK, 0.0, 0.3, 0.7, 0.3), Vector3.ZERO, false, "pipe")
	# reward: gold lines on top + a core and crates to smash
	for lane in [-1, 0, 1]:
		var cz := z - 4.0
		while cz > z - length + 4.0:
			var c := _coin(lane, cz, 7.0)
			c.set_meta("half", 0.5)
			cz -= 3.0
	_spawn_crate(1 if randf() < 0.5 else -1, z - length * 0.55)
	objects.get_child(objects.get_child_count() - 1).position.y = 6.0
	_spawn_power(Vector3(0, 7.2, z - length * 0.7), POWERS[randi() % POWERS.size()])


func _spawn_wall_section(z_start: float, side: int, length: float) -> void:
	var n := _obj("wall", 0, z_start - length * 0.5, length * 0.5)
	n.set_meta("side", side)
	n.set_meta("len", length)
	var x := side * 5.05
	var glass := mat(Color(0.25, 0.15, 0.45), Color(0.4, 0.2, 0.8), 0.4, 0.2, 0.5, 0.5, 0.0, Color(0.7, 0.6, 1))
	if theme == 2:
		glass = mat([Color(0.3, 0.6, 0.95), Color(0.95, 0.5, 0.7), Color(0.5, 0.85, 0.6)][randi() % 3], Color.BLACK, 0.0, 0.6, 0.0, 0.3)
	var neon := mat(Color(0.5, 0.7, 1.0), Color(0.45, 0.7, 1.0), 3.5, 0.4, 0.0, 0.0, 1.5)
	var arrow := mat(Color.WHITE, Color(1, 0.4, 0.85), 3.0, 0.4, 0, 0, 1.0)
	var segs := int(length / TILE)
	for i in segs:
		var zz := length * 0.5 - TILE * 0.5 - i * TILE
		_box(n, Vector3(0.25, 3.8, TILE - 0.1), Vector3(x, 2.2, zz), glass)
		_box(n, Vector3(0.3, 0.12, TILE), Vector3(x - side * 0.02, 0.35, zz), neon, false)
		_box(n, Vector3(0.3, 0.12, TILE), Vector3(x - side * 0.02, 4.1, zz), neon, false)
		_box(n, Vector3(0.4, 4.3, 0.3), Vector3(x, 2.15, zz + TILE * 0.5), mat(Color(0.8, 0.78, 0.9), Color.BLACK, 0.0, 0.3, 0.7), false)
		if i % 2 == 0:
			var a1 := _box(n, Vector3(0.05, 0.14, 1.1), Vector3(x - side * 0.14, 2.3, zz + 0.3), arrow, false)
			a1.rotation.x = 0.55
			var a2 := _box(n, Vector3(0.05, 0.14, 1.1), Vector3(x - side * 0.14, 1.8, zz + 0.3), arrow, false)
			a2.rotation.x = -0.55
	# gold that can only be reached by running on the wall
	var cz := length * 0.5 - 4.0
	while cz > -length * 0.5 + 3.0:
		var c := _coin(0, n.position.z + cz, 1.5)
		c.position.x = side * 4.6
		cz -= 2.6
	_spawn_power(Vector3(side * 4.6, 1.6, n.position.z - length * 0.2), POWERS[randi() % POWERS.size()])


func _beam(parent: Node3D, pos: Vector3, r: float, h: float, c: Color, strength := 0.35) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh("beam")
	var m := ShaderMaterial.new()
	m.shader = BEAM_SHADER
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("strength", strength)
	mi.material_override = m
	mi.position = pos + Vector3(0, h * 0.5, 0)
	mi.scale = Vector3(r, h, r)
	mi.extra_cull_margin = 60.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# ============================================================ warp tunnel
func _spawn_tunnel(z: float, lane: int) -> void:
	# a small ring tunnel over ONE outer lane: enter it to warp, or run past it
	var target := theme
	while target == theme:
		target = randi() % ThemesScript.NAMES.size()
	var n := _obj("tunnel", lane, z, 14.0)
	n.set_meta("target", target)
	n.set_meta("hit", false)
	var a: Color = ThemesScript.ACCENT[target]
	var shell := mat(Color(0.14, 0.1, 0.2), Color.BLACK, 0.0, 0.4, 0.5, 0.35, 0.0, a)
	# sized to fit inside its own lane (1.25 m each side) so it never covers
	# the middle road
	var cy := 1.35
	for i in 6:
		var zz := -i * 2.4
		_torus(n, 1.02, 1.18, Vector3(0, cy, zz), mat(Color(0.9, 0.9, 1.0), a if i % 2 == 0 else CYAN, 3.0, 0.3, 0.2, 0.0, 1.5), Vector3(PI / 2, 0, 0))
		for k in 5:
			var ang := PI * k / 4.0
			var p := Vector3(cos(ang) * 1.18, cy + sin(ang) * 1.18, zz - 1.2)
			var rib := _box(n, Vector3(0.14, 0.6, 2.3), p, shell, false)
			rib.rotation = Vector3(0, 0, ang)
	for sd in [-1.0, 1.0]:
		_box(n, Vector3(0.16, cy, 14.0), Vector3(sd * 1.12, cy * 0.5, -6.0), shell, false)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2.3, 2.3)
	q.mesh = qm
	var pm := ShaderMaterial.new()
	pm.shader = PORTAL_SHADER
	pm.set_shader_parameter("color", a)
	pm.set_shader_parameter("strength", 0.7)
	q.material_override = pm
	q.position = Vector3(0, cy, -0.3)
	q.extra_cull_margin = 60.0
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(q)
	# sign post: floating accent sign above the entrance
	_box(n, Vector3(2.2, 0.8, 0.2), Vector3(0, 3.4, 0.2), mat(Color(0.1, 0.08, 0.14), a, 0.5), false)
	_box(n, Vector3(2.0, 0.55, 0.05), Vector3(0, 3.4, 0.32), mat(a, a, 3.0, 0.4, 0, 0, 1.0), false)
	for i in 3:
		var c1 := _box(n, Vector3(0.9, 0.04, 0.22), Vector3(-0.32, 0.03, 7.0 - i * 2.0), mat(a, a, 3.0, 0.4, 0, 0, 1.5), false)
		c1.rotation.y = -0.6
		var c2 := _box(n, Vector3(0.9, 0.04, 0.22), Vector3(0.32, 0.03, 7.0 - i * 2.0), mat(a, a, 3.0, 0.4, 0, 0, 1.5), false)
		c2.rotation.y = 0.6
	_beam(n, Vector3(0, 4.8, 0), 0.5, 20.0, a, 0.4)


# ============================================================ skate park + traps
## Quarter-pipe along one edge of the road (skate park). Swerve into it from
## the outer lane (or press E): ride up, spin a 360 and land in the middle.
func _spawn_qpipe(z_start: float, side: int, length: float) -> void:
	var n := _obj("qpipe", 0, z_start - length * 0.5, length * 0.5)
	n.set_meta("side", side)
	qpipes.append(n)
	var was := batching
	batching = true
	_build_qpipe(n, side, length)
	batching = was
	flush_batches()


func _build_qpipe(n: Node3D, side: int, length: float) -> void:
	var sd := float(side)
	var r := 3.0
	var edge := 4.45
	var skin: Color = [Color(0.2, 0.5, 0.95), Color(0.55, 0.35, 0.95), Color(0.1, 0.7, 0.75)][randi() % 3]
	var surf := mat(skin, Color.BLACK, 0.0, 0.55, 0.0, 0.3, 0.0, Color(0.8, 0.95, 1.0))
	var stripe := mat(Color.WHITE, Color(0.9, 0.95, 1.0), 0.6)
	var steel := mat(Color(0.85, 0.87, 0.92), Color.BLACK, 0.0, 0.15, 0.95, 0.5)
	var wood := mat(Color(0.62, 0.45, 0.3), Color.BLACK, 0.0, 0.8)
	var segs := 8
	var seg_len := 4.0
	var count := int(length / seg_len)
	for i in count:
		var zz := length * 0.5 - seg_len * 0.5 - i * seg_len
		for k in segs:
			var a := (float(k) + 0.5) / segs * (PI * 0.5)
			var pos := Vector3(sd * (edge + r * sin(a)), r - r * cos(a), zz)
			_box(n, Vector3(r * PI * 0.5 / segs + 0.06, 0.16, seg_len - 0.04), pos, surf, k < 2).rotation = Vector3(0, 0, sd * a)
		# painted stripe across the curve every other segment
		if i % 2 == 0:
			for k in segs:
				var a2 := (float(k) + 0.5) / segs * (PI * 0.5)
				var p2 := Vector3(sd * (edge + (r - 0.09) * sin(a2)), r - (r - 0.09) * cos(a2), zz)
				_box(n, Vector3(r * PI * 0.5 / segs + 0.06, 0.02, 0.25), p2, stripe, false).rotation = Vector3(0, 0, sd * a2)
		# coping pipe, deck and back wall
		_cyl(n, 0.12, seg_len, Vector3(sd * (edge + r), r + 0.05, zz), steel, Vector3(PI / 2, 0, 0), false, "pipe")
		_box(n, Vector3(1.8, 0.2, seg_len), Vector3(sd * (edge + r + 0.95), r - 0.05, zz), wood)
		_box(n, Vector3(0.3, r, seg_len), Vector3(sd * (edge + r + 1.8), r * 0.5, zz), mat(skin.darkened(0.45)))
		if i % 3 == 1:
			for k in 3:
				_box(n, Vector3(0.06, 1.0, 0.06), Vector3(sd * (edge + r + 1.7), r + 0.5, zz - 1.5 + k * 1.5), steel, false)
			_box(n, Vector3(0.05, 0.05, seg_len), Vector3(sd * (edge + r + 1.7), r + 1.0, zz), steel, false)
	# graffiti on the end panel facing the runner
	var panel := mat(Color(0.95, 0.92, 0.85))
	_box(n, Vector3(r + 1.8, r, 0.2), Vector3(sd * (edge + (r + 1.8) * 0.5), r * 0.5, length * 0.5), panel)
	for k in 7:
		var c: Color = [Color(1, 0.35, 0.7), Color(0.3, 0.85, 0.95), Color(1, 0.85, 0.2), Color(0.5, 0.95, 0.4), Color(0.65, 0.4, 1.0)][k % 5]
		var d := _cyl(n, randf_range(0.3, 0.7), 0.05, Vector3(sd * randf_range(edge + 0.6, edge + r + 1.4), randf_range(0.4, r - 0.4), length * 0.5 + 0.12), mat(c, c, 0.3), Vector3(PI / 2, 0, 0), false)
		d.scale.x *= randf_range(1.0, 1.8)
	# road arrows in the outer lane: "swerve in here"
	var arrow := mat(Color(1, 0.9, 0.2), Color(1, 0.8, 0.1), 2.5, 0.5, 0, 0, 1.5)
	for k in 4:
		var az := length * 0.5 + 6.0 - k * 1.3
		var a1 := _box(n, Vector3(0.7, 0.03, 0.16), Vector3(sd * 2.3, 0.03, az - 0.22), arrow, false)
		a1.rotation.y = -sd * 0.75
		var a2 := _box(n, Vector3(0.7, 0.03, 0.16), Vector3(sd * 2.3, 0.03, az + 0.22), arrow, false)
		a2.rotation.y = sd * 0.75
	# gold on the ramp face and high over the middle lane (the trick's arc)
	var cz := length * 0.5 - 3.0
	while cz > -length * 0.5 + 3.0:
		var c1 := _coin(0, n.position.z + cz, 1.6)
		c1.position.x = sd * (edge + 1.0)
		cz -= 3.0
	for k in 6:
		var t := float(k) / 5.0
		var c2 := _coin(0, n.position.z - 4.0 - k * 2.6, 2.5 + sin(t * PI) * 3.0)
		c2.position.x = sd * lerpf(4.5, 0.5, t)


## Is there a quarter-pipe at the player (z = 0) on this side?
func qpipe_at(side: int) -> Node3D:
	for q in qpipes:
		if not is_instance_valid(q) or int(q.get_meta("side")) != side:
			continue
		var half: float = q.get_meta("half")
		if q.position.z + half > 1.0 and q.position.z - half < -4.0:
			return q
	return null


## For scenery: is a quarter-pipe near this z on side s?
func qpipe_near(z: float, s: float) -> bool:
	for q in qpipes:
		if is_instance_valid(q) and signf(float(q.get_meta("side"))) == signf(s):
			var half: float = q.get_meta("half")
			if z < q.position.z + half + 4.0 and z > q.position.z - half - 4.0:
				return true
	return false


func _spawn_rail(lane: int, z: float) -> void:
	# metal grind rail: jump on and grind (sparks + bonus on a skateboard)
	var n := _obj("rail", lane, z, 10.5)
	n.set_meta("box", AABB(Vector3(-0.3, 0.0, -10.0), Vector3(0.6, 1.0, 20.0)))
	var metal := mat(Color(0.85, 0.87, 0.95), Color.BLACK, 0.0, 0.15, 0.95, 0.5, 0.0, Color(0.7, 0.9, 1))
	var post := mat(Color(0.3, 0.3, 0.35), Color.BLACK, 0.0, 0.4, 0.7)
	for k in 5:
		_cyl(n, 0.08, 0.95, Vector3(0, 0.47, 9.4 - k * 4.7), post)
		_box(n, Vector3(0.5, 0.06, 0.3), Vector3(0, 0.03, 9.4 - k * 4.7), post, false)
	for k in 5:
		_cyl(n, 0.09, 4.0, Vector3(0, 0.98, 8.0 - k * 4.0), metal, Vector3(PI / 2, 0, 0), true, "pipe")
	_box(n, Vector3(0.24, 0.04, 20.0), Vector3(0, 1.0, 0), mat(CYAN, CYAN, 1.5, 0.4, 0, 0, 1.0), false)
	_box(n, Vector3(0.2, 0.9, 0.08), Vector3(0, 0.45, 10.0), mat(Color(1, 0.85, 0.2), Color(1, 0.6, 0.1), 1.5), false)


func _spawn_kicker(lane: int, z: float) -> void:
	# launch ramp: run over it to fly (bigger air + kickflip on a board)
	var n := _obj("kicker", lane, z, 2.0)
	n.set_meta("hit", false)
	var c: Color = [Color(1, 0.45, 0.75), Color(0.35, 0.75, 1), Color(1, 0.8, 0.3)][randi() % 3]
	var r := _box(n, Vector3(1.9, 0.12, 3.4), Vector3(0, 0.55, 0), mat(c, Color.BLACK, 0.0, 0.5, 0.1, 0.3), true)
	r.rotation.x = 0.33
	_box(n, Vector3(1.9, 1.1, 0.12), Vector3(0, 0.55, -1.55), mat(c.darkened(0.3)), false)
	_box(n, Vector3(1.95, 0.06, 0.2), Vector3(0, 1.12, -1.6), mat(Color.WHITE, Color.WHITE, 2.0), false)
	for sd in [-1.0, 1.0]:
		var side := _box(n, Vector3(0.08, 1.1, 3.2), Vector3(sd * 0.95, 0.4, 0), mat(Color(0.95, 0.92, 0.85)), false)
		side.scale.y = 0.6


func _spawn_trap(lane: int, z: float, kind: String) -> void:
	# booby trap: hidden until you get close, then it pops up / drops down.
	# A flashing warning on the road shows where it will appear.
	var n := _obj(kind, lane, z, 1.2)
	n.set_meta("trig", false)
	var warn_c := Color(1.0, 0.2, 0.25)
	match kind:
		"pop_wall":
			n.set_meta("box", AABB(Vector3(-0.95, 0.0, -0.3), Vector3(1.9, 2.5, 0.6)))
			n.set_meta("hide_y", -2.8)
			n.position.y = -2.8
			var col: Color = {1: Color(0.95, 0.3, 0.3), 5: Color(0.3, 0.9, 1.0), 7: Color(1.0, 0.5, 0.8)}.get(theme, Color(1, 0.3, 0.3))
			_box(n, Vector3(1.9, 2.4, 0.5), Vector3(0, 1.2, 0), hz(Color(0.2, 0.18, 0.24), Color.BLACK, 0.0, 0.4, 0.6))
			for k in 4:
				var st := _box(n, Vector3(0.35, 2.2, 0.05), Vector3(-0.7 + k * 0.47, 1.2, 0.27), mat(Color(1, 0.85, 0.2), Color(1, 0.7, 0.1), 0.6), false)
				st.rotation.z = 0.5
			_box(n, Vector3(1.95, 0.15, 0.55), Vector3(0, 2.45, 0), mat(col, col, 4.0, 0.4, 0, 0, 1.5), false)
		"pop_spikes":
			n.set_meta("box", AABB(Vector3(-0.95, 0.0, -0.35), Vector3(1.9, 0.85, 0.7)))
			n.set_meta("hide_y", -1.2)
			n.position.y = -1.2
			var sm := mat(Color(0.8, 0.82, 0.9), Color(1.0, 0.2, 0.3), 0.3, 0.2, 0.9, 0.4)
			if theme == 6:
				sm = mat(Color(0.5, 0.75, 0.35), Color.BLACK, 0.0, 0.7)
			_box(n, Vector3(1.9, 0.2, 0.7), Vector3(0, 0.1, 0), hz(Color(0.2, 0.2, 0.25)))
			for k in 5:
				for j in 2:
					var sp := MeshInstance3D.new()
					sp.mesh = _mesh("cone")
					sp.material_override = sm
					sp.scale = Vector3(0.16, 0.75, 0.16)
					sp.position = Vector3(-0.76 + k * 0.38, 0.55, -0.15 + j * 0.3)
					sp.extra_cull_margin = 60.0
					n.add_child(sp)
		"drop":
			n.set_meta("box", AABB(Vector3(-0.9, 0.0, -0.9), Vector3(1.8, 2.2, 1.8)))
			n.set_meta("hide_y", 16.0)
			n.position.y = 16.0
			var body := hz(Color(0.6, 0.62, 0.7), Color.BLACK, 0.0, 0.4, 0.5)
			_box(n, Vector3(1.8, 2.2, 1.8), Vector3(0, 1.1, 0), body)
			_box(n, Vector3(1.85, 0.2, 1.85), Vector3(0, 2.1, 0), mat(Color(1, 0.8, 0.2), Color(1, 0.6, 0.1), 1.0), false)
			_cyl(n, 0.5, 0.05, Vector3(0, 1.3, 0.92), mat(Color(0.3, 0.3, 0.35)), Vector3(PI / 2, 0, 0), false)
	# warning decal on the road (scrolls with the world, stays on the ground)
	var d := Node3D.new()
	d.position = Vector3(lane * LANE_WIDTH, 0.0, z)
	d.set_meta("half", 2.0)
	scenery.add_child(d)
	var wm := mat(warn_c, warn_c, 3.0, 0.4, 0.0, 0.0, 3.0)
	if kind == "drop":
		_cyl(d, 1.1, 0.02, Vector3(0, 0.02, 0), mat(Color(0.05, 0.02, 0.05), warn_c, 1.5, 0.5, 0, 0, 3.0), Vector3.ZERO, false)
		_torus(d, 1.15, 1.3, Vector3(0, 0.03, 0), wm)
	else:
		for k in 3:
			var c1 := _box(d, Vector3(0.9, 0.03, 0.2), Vector3(-0.32, 0.02, 2.4 - k * 0.9), wm, false)
			c1.rotation.y = 0.6
			var c2 := _box(d, Vector3(0.9, 0.03, 0.2), Vector3(0.32, 0.02, 2.4 - k * 0.9), wm, false)
			c2.rotation.y = -0.6
		_box(d, Vector3(1.9, 0.03, 0.15), Vector3(0, 0.02, 0.5), wm, false)


# ============================================================ destruction
func smash(obj: Node3D, fx) -> void:
	var kind: String = obj.get_meta("kind")
	var col := PINK
	if kind == "crate":
		col = Color(1.0, 0.6, 0.2)
	elif kind == "drone":
		col = Color(1.0, 0.25, 0.3)
	elif kind == "car":
		col = CYAN
	elif kind == "slide":
		col = Color(1, 0.25, 0.4)
	fx.burst(obj.position + Vector3(0, 1.0, 0), col, 18, 14.0, 0.32, 0.9)
	fx.burst(obj.position + Vector3(0, 1.0, 0), Color(1, 1, 1), 8, 9.0, 0.18, 0.6)
	obj.queue_free()


func clear_ahead(z_min: float, z_max: float, fx) -> int:
	var n := 0
	for obj in objects.get_children():
		if obj.is_queued_for_deletion():
			continue
		var kind: String = obj.get_meta("kind")
		if kind in ["jump", "slide", "car", "speaker"] and obj.position.z > z_min and obj.position.z < z_max:
			smash(obj, fx)
			n += 1
	return n


# ============================================================ helpers
func mat(albedo: Color, emission := Color(0, 0, 0), energy := 0.0, rough := 0.7, metal := 0.0,
		rim := 0.2, pulse := 0.0, rim_col := Color(1.0, 0.85, 1.0)) -> ShaderMaterial:
	var key := "%s|%s|%.2f|%.2f|%.2f|%.2f|%.2f|%s" % [albedo.to_html(), emission.to_html(), energy, rough, metal, rim, pulse, rim_col.to_html()]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = WORLD_SHADER
	m.set_shader_parameter("albedo", albedo)
	m.set_shader_parameter("emission_color", emission)
	m.set_shader_parameter("emission_energy", energy)
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("metallic", metal)
	m.set_shader_parameter("rim_strength", rim)
	m.set_shader_parameter("beat_pulse", pulse)
	m.set_shader_parameter("rim_color", rim_col)
	var glow := energy > 0.45 and emission.get_luminance() > 0.02
	var vcol := (emission if glow else albedo).srgb_to_linear()
	vcol.a = clampf(energy / 8.0, 0.0, 1.0) if glow else 0.0
	m.set_meta("vc", [vcol, rough, metal, pulse])
	_mats[key] = m
	return m


func _mesh(key: String) -> Mesh:
	if _meshes.has(key):
		return _meshes[key]
	var m: Mesh
	match key:
		"box":
			var b := BoxMesh.new()
			m = b
		"sphere":
			var s := SphereMesh.new()
			s.radius = 1.0
			s.height = 2.0
			s.radial_segments = 24
			s.rings = 12
			m = s
		"cyl":
			var c := CylinderMesh.new()
			c.top_radius = 1.0
			c.bottom_radius = 1.0
			c.height = 1.0
			c.radial_segments = 20
			c.rings = 1
			m = c
		"pipe":
			var p := CylinderMesh.new()
			p.top_radius = 1.0
			p.bottom_radius = 1.0
			p.height = 1.0
			p.radial_segments = 12
			p.rings = 16
			m = p
		"cone":
			var co := CylinderMesh.new()
			co.top_radius = 0.0
			co.bottom_radius = 1.0
			co.height = 1.0
			co.radial_segments = 16
			m = co
		"gem":
			var g := SphereMesh.new()
			g.radius = 1.0
			g.height = 2.0
			g.radial_segments = 4
			g.rings = 2
			m = g
		"beam":
			var bm := CylinderMesh.new()
			bm.top_radius = 1.0
			bm.bottom_radius = 1.0
			bm.height = 1.0
			bm.radial_segments = 16
			bm.rings = 4
			bm.cap_top = false
			bm.cap_bottom = false
			m = bm
		"coin":
			var cn := CylinderMesh.new()
			cn.top_radius = 0.42
			cn.bottom_radius = 0.42
			cn.height = 0.1
			cn.radial_segments = 20
			m = cn
	_meshes[key] = m
	if key in BATCH_KEYS:
		_prim_key[m] = key
	return m


func _mi(parent: Node3D, mesh: Mesh, pos: Vector3, m: Material, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if batching and m != null and _prim_key.has(mesh) and m.has_meta("vc"):
		# collected now, merged in flush_batches()
		mi.position = pos
		_pending.append([parent, mi, m, shadow])
		return mi
	mi.material_override = m
	mi.position = pos
	mi.extra_cull_margin = 60.0
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Low-poly copies of the primitives for merged scenery: [verts, normals, indices].
func _prim(mesh: Mesh) -> Array:
	var key: String = _prim_key[mesh]
	if _prim_cache.has(key):
		return _prim_cache[key]
	var src := mesh
	if key == "sphere":
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 14
		sm.rings = 7
		src = sm
	elif key == "cyl" or key == "pipe":
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 1.0
		cm.radial_segments = 12
		cm.rings = 1
		src = cm
	var a := src.surface_get_arrays(0)
	var out := [a[Mesh.ARRAY_VERTEX], a[Mesh.ARRAY_NORMAL], a[Mesh.ARRAY_INDEX]]
	_prim_cache[key] = out
	return out


func flush_batches() -> void:
	if _pending.is_empty():
		return
	if vc_mat == null:
		vc_mat = ShaderMaterial.new()
		vc_mat.shader = WORLD_VC
	var groups := {}
	for e in _pending:
		var p: Node3D = e[0]
		var mi: MeshInstance3D = e[1]
		if not is_instance_valid(p):
			mi.free()
			continue
		var g: Array = groups.get(p, [])
		if g.is_empty():
			g = [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedVector2Array(), PackedVector2Array(), PackedInt32Array(), false]
			groups[p] = g
		var arr := _prim(mi.mesh)
		var t: Transform3D = mi.transform
		var nb := t.basis.inverse().transposed()
		var vc: Array = (e[2] as Material).get_meta("vc")
		var col: Color = vc[0]
		var uv := Vector2(vc[3], 0.0)
		var uv2 := Vector2(vc[1], vc[2])
		var verts: PackedVector3Array = arr[0]
		var norms: PackedVector3Array = arr[1]
		var base: int = g[0].size()
		for k in verts.size():
			g[0].append(t * verts[k])
			g[1].append((nb * norms[k]).normalized())
			g[2].append(col)
			g[3].append(uv)
			g[4].append(uv2)
		for k in arr[2]:
			g[5].append(base + k)
		if e[3]:
			g[6] = true
		mi.free()
	_pending.clear()
	for p in groups:
		var g: Array = groups[p]
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = g[0]
		a[Mesh.ARRAY_NORMAL] = g[1]
		a[Mesh.ARRAY_COLOR] = g[2]
		a[Mesh.ARRAY_TEX_UV] = g[3]
		a[Mesh.ARRAY_TEX_UV2] = g[4]
		a[Mesh.ARRAY_INDEX] = g[5]
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		var bm := MeshInstance3D.new()
		bm.mesh = am
		bm.material_override = vc_mat
		bm.extra_cull_margin = 60.0
		if not g[6]:
			bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(p as Node3D).add_child(bm)


func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, shadow := true, _unused := false) -> MeshInstance3D:
	var mi := _mi(parent, _mesh("box"), pos, m, shadow)
	mi.scale = size
	return mi


func _sphere(parent: Node3D, r: float, pos: Vector3, m: Material, shadow := true) -> MeshInstance3D:
	var mi := _mi(parent, _mesh("sphere"), pos, m, shadow)
	mi.scale = Vector3(r, r, r)
	return mi


func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, m: Material, rot := Vector3.ZERO, shadow := true, key := "cyl") -> MeshInstance3D:
	var mi := _mi(parent, _mesh(key), pos, m, shadow)
	mi.rotation = rot
	mi.scale = Vector3(r, h, r)
	return mi


func _torus(parent: Node3D, inner: float, outer: float, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var key := "torus%.2f_%.2f" % [inner, outer]
	if not _meshes.has(key):
		var t := TorusMesh.new()
		t.inner_radius = inner
		t.outer_radius = outer
		t.rings = 64
		t.ring_segments = 12
		_meshes[key] = t
	var mi := _mi(parent, _meshes[key], pos, m, false)
	mi.rotation = rot
	return mi
