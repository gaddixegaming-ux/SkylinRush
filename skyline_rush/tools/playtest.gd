extends SceneTree
## Dev tool: a bot plays every track for real (deaths on) and reports what
## went wrong: every death with the objects around the runner, falls through
## the floor, runners stuck between lanes, bad numbers.
##   godot --headless -s res://tools/playtest.gd -- [seconds_per_track] [track...]
##   (under xvfb it also saves a screenshot per death to res://tools/shots)

var main
var shots := false
var near_prev: Array = []
var deaths := 0
var issues := 0
var trace: Array = []      # last frames before a death: what the bot saw and did
var act := ""


func _initialize() -> void:
	shots = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute("res://tools/shots")
	main = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	await _wait(2.0)
	if is_instance_valid(main.splash):
		main._end_splash()
	var a := OS.get_cmdline_user_args()
	var secs := 60.0
	var tracks: Array = range(9)
	if a.size() > 0 and a[0].is_valid_float():
		secs = float(a[0])
	if a.size() > 1:
		tracks = []
		for i in range(1, a.size()):
			tracks.append(int(a[i]))
	for t in tracks:
		await _play(t, secs)
	print("PLAYTEST DONE  deaths=%d  issues=%d" % [deaths, issues])
	quit()


func _issue(msg: String) -> void:
	issues += 1
	print("  ISSUE: ", msg)


func _play(track: int, secs: float) -> void:
	seed(1000 + track)
	main.start_zone = track
	main._start_game()
	var el := 0.0
	var stuck_t := 0.0
	var runs := 1
	var dist_total := 0.0
	var last_dist := 0.0
	while el < secs:
		_bot()
		await process_frame
		var d := minf(main.get_process_delta_time(), 0.05)
		el += d
		var p = main.player
		# ---- sanity checks
		if is_nan(p.position.x) or is_nan(p.position.y) or is_nan(main.distance):
			_issue("NaN in player / distance")
		if main.state == main.State.PLAYING:
			if p.grounded and not p.is_grappling() and p.wall_side == 0 and not p.is_tricking() \
					and absf(p.position.x - p.lane * 2.5) > 0.3 and absf(p.x_vel) < 0.2:
				stuck_t += d
				if stuck_t > 1.0:
					_issue("track %d: runner stuck between lanes at x=%.2f lane=%d" % [track, p.position.x, p.lane])
					stuck_t = -999.0
			else:
				stuck_t = maxf(stuck_t, 0.0)
			if p.position.y > 40.0:
				_issue("track %d: runner flew to y=%.1f" % [track, p.position.y])
		# remember what was around the runner, for the death report
		if main.state == main.State.PLAYING:
			near_prev = []
			for o in main.world.objects.get_children():
				if absf(o.position.z) < 6.0 and o.has_meta("box"):
					var b: AABB = o.get_meta("box")
					near_prev.append("%s lane=%d z=%.1f top=%.1f" % [o.get_meta("kind"), roundi(o.position.x / 2.5), o.position.z, o.position.y + b.end.y])
				elif absf(o.position.z) < 6.0:
					near_prev.append("%s lane=%d z=%.1f" % [o.get_meta("kind"), roundi(o.position.x / 2.5), o.position.z])
		if main.state == main.State.PLAYING:
			var nz := 99.0
			for o in main.world.objects.get_children():
				if o.get_meta("kind") == "jump" and roundi(o.position.x / 2.5) == p.lane and o.position.z < 1.0 and -o.position.z < nz:
					nz = -o.position.z
			trace.append("t=%.2f lane=%d x=%.2f y=%.2f vy=%.1f gr=%s jumpbar=%.1f act=%s spd=%.0f" % [el, p.lane, p.position.x, p.position.y, p.vy, p.grounded, nz, act, main.speed])
			if trace.size() > 14:
				trace.pop_front()
			act = ""
		if main.state == main.State.DEAD:
			deaths += 1
			for tr in trace:
				print("      trace: ", tr)
			trace.clear()
			print("  DEATH track %d run %d at %dm: '%s'  lane=%d y=%.2f grounded=%s sliding=%s veh=%s zone=%d" % [
				track, runs, int(main.distance), main.death_title, p.lane, p.position.y, p.grounded, p.is_sliding(), p.vehicle, main.zone_idx])
			for s in near_prev:
				print("      near: ", s)
			if shots:
				await RenderingServer.frame_post_draw
				get_root().get_texture().get_image().save_png("res://tools/shots/death_t%d_%d.png" % [track, runs])
			dist_total += main.distance
			await _wait(0.6)
			runs += 1
			main.start_zone = track
			main._start_game()
		last_dist = main.distance
	dist_total += last_dist
	print("track %d: %d runs, %.0f m total, %.0f m per run, zone now %d" % [track, runs, dist_total, dist_total / runs, main.zone_idx])


## Plays like a careful human: stays in the lane whose next hard obstacle is
## farthest away, jumps / slides the soft ones, jumps holes.
func _bot() -> void:
	if main.state != main.State.PLAYING:
		return
	var p = main.player
	var hard := {-1: 999.0, 0: 999.0, 1: 999.0}
	var need := ""
	for o in main.world.objects.get_children():
		var k: String = o.get_meta("kind")
		var z: float = o.position.z
		if z > 1.5 or z < -45.0:
			continue
		var lane := clampi(roundi(o.position.x / 2.5), -1, 1)
		var ahead := -z
		match k:
			"jump", "pop_spikes":
				if lane == p.lane and ahead < 7.0 and ahead > 1.0:
					need = "jump"
			"slide":
				if lane == p.lane and ahead < 7.0 and ahead > 0.5:
					need = "slide"
			"car", "speaker", "crate", "drone", "pop_wall", "drop", "bus":
				if o.has_meta("box"):
					var b: AABB = o.get_meta("box")
					var front := -(z + b.end.z)
					if front < hard[lane] and z + b.position.z < 1.0:
						hard[lane] = maxf(front, 0.0)
	for h in main.world.holes:
		if not is_instance_valid(h):
			continue
		if -h.position.z < 5.0 and -h.position.z > 0.5:
			need = "jump"
		# over a long gap and coming down: double jump
		var far_edge: float = h.position.z - float(h.get_meta("len", 8.0))
		if h.position.z > 0.0 and far_edge < -1.0 and not p.grounded and p.vy < 0.0 and p.can_double:
			p.press_jump()
			p.release_jump()
	# hunter drone laser locked on our lane: treat the lane as blocked
	for hh in main.enemies.hunters:
		if hh[1] == "lock":
			hard[hh[3]] = 0.0
	# head for the lane whose next hard obstacle is farthest away (one step
	# at a time, through the middle lane if it isn't blocked right now)
	var target: int = p.lane
	for l in [-1, 0, 1]:
		if hard[l] > hard[target] + 3.0:
			target = l
	var best: int = p.lane
	if target != p.lane:
		var step: int = p.lane + signi(target - p.lane)
		if hard[step] > 2.0:
			best = step
	if best != p.lane:
		main._on_dir(signi(best - p.lane))
		act = "move%d" % signi(best - p.lane)
	elif need == "jump" and p.grounded:
		p.press_jump()
		p.release_jump()
		act = "JUMP"
	elif need == "slide" and p.grounded:
		main._on_slide()
		act = "slide"
	elif need != "":
		act = "want_" + need


func _wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await process_frame
		t += minf(main.get_process_delta_time(), 0.05)
