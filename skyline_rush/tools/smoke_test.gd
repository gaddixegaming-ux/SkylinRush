extends SceneTree
## Dev tool: runs the real game, pokes the menus, plays every track with an
## autopilot and saves screenshots to res://tools/shots.
##   xvfb-run godot --rendering-method gl_compatibility --resolution 1600x900 -s res://tools/smoke_test.gd
##   (add -- quick for a short headless logic run)

var main
var shots := true
var frames := 0


func _initialize() -> void:
	var quick := "quick" in OS.get_cmdline_user_args()
	shots = not quick and DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute("res://tools/shots")
	main = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	await _wait(3.0)
	await _shot("menu")
	# every runner's lobby
	for i in main.RigScript.count() - 1:
		main._select_char(1)
		await _wait(1.2)
		await _shot("room_%d" % main.char_idx)
		print("lobby %d  visible=%s" % [main.char_idx, main.lobby.rooms.get(main.char_idx, main).visible])
	main._select_char(1)
	# garage + upgrades
	main.prog.wallet = 50000
	main._open_panel("garage")
	await _wait(0.4)
	await _shot("garage_skate")
	main._garage_item(3)
	main._garage_tab("hover")
	main._garage_item(2)
	await _wait(0.4)
	await _shot("garage_hover")
	main._garage_tab("moto")
	main._garage_item(4)
	await _wait(0.4)
	await _shot("garage_moto")
	main._open_panel("upgrades")
	main._buy_upgrade("magnet")
	main._buy_upgrade("armor")
	main._buy_upgrade("armor")
	await _wait(0.3)
	await _shot("upgrades")
	main._open_panel("")
	main.hud.toggle_controls()
	await _wait(0.3)
	await _shot("controls")
	main.hud.toggle_controls()
	var tracks := range(9) if not quick else [0, 2, 4, 8]
	for t in tracks:
		main.start_zone = t
		main._start_game()
		main.grace = 9999.0
		var secs := 5.0 if not quick else 4.0
		var el := 0.0
		var shot_done := false
		while el < secs:
			_autopilot()
			main.grace = 9999.0
			await process_frame
			el += minf(main.get_process_delta_time(), 0.05)
			if el > 4.5 and not shot_done:
				shot_done = true
				await _shot("track_%d" % t)
		print("track %d  dist=%d  coins=%d  vehicle=%s  state=%d" % [t, main.distance, main.gold, main.player.vehicle, main.state])
		if t == 2:
			await _test_trick()
		if t == 0:
			await _test_hole()
			await _test_bus()
		if t == 4:
			await _test_powers()
		if t == 8:
			main.player.press_slide()
			await _wait(0.25)
			print("moto slide  sliding=%s  lay=%.2f" % [main.player.is_sliding(), main.player.model.rotation.z])
			await _shot("moto_slide")
	# skyway camera: put the runner on a sky-highway
	main.start_zone = 1
	main._start_game()
	main.grace = 9999.0
	main.world._spawn_platform(12.0, 52.0)
	main.player.position.y = 6.2
	main.player.vy = 0.0
	await _wait(1.5)
	await _shot("skyway")
	await _test_v9()
	# death + game over
	main.grace = 0.0
	main._crash("WIPED OUT")
	await _wait(1.6)
	await _shot("game_over")
	print("high scores: %d  top=%d" % [main.prog.scores.size(), int(main.prog.scores[0]["score"]) if not main.prog.scores.is_empty() else -1])
	main._enter_menu()
	await _wait(0.5)
	await _test_panels()
	print("SMOKE OK  wallet=%d best=%d" % [main.prog.wallet, main.prog.best])
	quit()


## v9 systems: style chain, route fork, pickups, shortcut, events, enemies, missions.
func _test_v9() -> void:
	main.start_zone = 4
	main._start_game()
	main.grace = 9999.0
	await _wait(0.5)
	# ---- style chain
	for k in ["jump", "slide", "dash", "wall", "grapple", "airdash", "slam", "trick", "close", "sky", "smash", "grind", "qpipe", "dodge"]:
		main._style_move(k)
	print("style: tier=%d mult=x%d chain=%s" % [main.style.tier, main.style.mult(), main.style.chain_text()])
	await _wait(0.2)
	await _shot("style_meter")
	var before: int = main.style.mult()
	main.style.broken()
	print("style broken: x%d -> x%d" % [before, main.style.mult()])
	# ---- route fork: take the HIGH route, then the UNDERPASS
	main.world.allow_tunnels = false
	for want in ["high", "under"]:
		main.world.force_fork = true
		main.world.rows_since_fork = 99
		var lane := -1 if want == "high" else 1
		var seen := false
		var el := 0.0
		var shot := false
		while el < 28.0 and not seen:
			main.grace = 9999.0
			if main.player.lane != lane and main.player.grounded:
				main._on_dir(signi(lane - main.player.lane))
			await process_frame
			el += minf(main.get_process_delta_time(), 0.05)
			for o in main.world.objects.get_children():
				if o.get_meta("kind") == "fork_sign" and o.position.z > -40.0 and o.position.z < -20.0 and not shot:
					shot = true
					await _shot("fork_" + want)
			if main.route == want:
				seen = true
		print("route %s reached=%s  y=%.1f  after %.1fs" % [want, seen, main.player.position.y, el])
		await _wait(1.0)
		await _shot("route_" + want)
		await _wait(4.0)
	main.world.allow_tunnels = true
	# ---- pickups
	var p: Vector3 = main.player.position
	for c in ["energy", "fragment", "key", "artifact"]:
		main.world._spawn_pickup(Vector3(p.x, 1.2, -2.0), c)
		await _wait(0.25)
	print("pickups: frags=%d keys=%d artifacts=%s" % [main.run_frags, main.run_keys, main.run_artifacts])
	# ---- shortcut gate (uses the key)
	var d0: float = main.distance
	main.world._spawn_shortcut(-12.0, main.player.lane)
	await _wait(2.0)
	print("shortcut: keys=%d  distance +%d" % [main.run_keys, int(main.distance - d0)])
	# ---- every random event
	for id in main.EventsScript.EVENTS.keys():
		main.events.start(id)
		main.grace = 9999.0
		var el2 := 0.0
		while el2 < 3.5:
			main.grace = 9999.0
			_autopilot()
			await process_frame
			el2 += minf(main.get_process_delta_time(), 0.05)
		print("event %-10s active=%s dark=%.2f speed=%.2f grav=%.2f enemies=%s" % [id, main.events.current == id, main.events.dark,
			main.events.speed_mult(), main.player.grav_mult, main.enemies.any_active()])
		await _shot("event_" + id)
		main.events.t = 0.05
		await _wait(0.3)
	main.enemies.clear()
	# ---- enemies outside events
	main.enemies.add_rival()
	main.enemies.add_blocker()
	main.enemies.add_hunter()
	main.enemies.solo_t = 6.0
	var el3 := 0.0
	while el3 < 4.0:
		main.grace = 9999.0
		await process_frame
		el3 += minf(main.get_process_delta_time(), 0.05)
	await _shot("enemies")
	print("enemies: rival=%s blocker=%s hunters=%d chasing=%s" % [main.enemies.rival != null, main.enemies.blocker != null, main.enemies.hunters.size(), main.enemies.is_chasing()])
	main.enemies.clear()
	# ---- missions
	var w0: int = main.prog.wallet
	var info: Dictionary = main.prog.mission_info(main.prog.missions[0])
	var done: Array = main.prog.mission_event(info["stat"], int(info["target"]), bool(info["per_run"]))
	print("mission '%s' done=%d  wallet +%d  active=%d" % [info["text"], done.size(), main.prog.wallet - w0, main.prog.missions.size()])


func _test_panels() -> void:
	main.prog.wallet = 50000
	main.prog.fragments = 200
	for pn in ["customize", "records", "settings", "upgrades"]:
		main._open_panel(pn)
		await _wait(0.3)
		await _shot("panel_" + pn)
	main.hud.sub_tab["records"] = "missions"
	main._open_panel("records")
	await _wait(0.3)
	await _shot("panel_records_missions")
	main.hud.sub_tab["records"] = "collection"
	main._open_panel("records")
	await _wait(0.3)
	await _shot("panel_records_collection")
	main.hud.sub_tab["upgrades"] = "frags"
	main._open_panel("upgrades")
	main._buy_frag_upgrade("dash_power")
	await _wait(0.3)
	await _shot("panel_upgrades_frags")
	main._open_panel("customize")
	main._pick_cosmetic("trail", "fire")
	main._pick_cosmetic("aura", "sparkle")
	await _wait(0.5)
	await _shot("panel_customize_bought")
	main._open_panel("settings")
	main._change_setting("quality", "ultra")
	main._change_setting("gi", true)
	await _wait(0.2)
	print("panels ok: trail=%s aura=%s dash_lvl=%d quality=%s ssao=%s ssil=%s" % [main.prog.trail, main.prog.aura,
		main.prog.frag_level("dash_power"), main.prog.settings["quality"], main.env.ssao_enabled, main.env.ssil_enabled])
	main._change_setting("quality", "high")
	main._open_panel("")


func _test_trick() -> void:
	main.world._spawn_qpipe(8.0, -1, 56.0)
	main.player.lane = -1
	main.player.position.x = -2.5
	await _wait(0.1)
	main._on_dir(-1)
	print("trick started: ", main.player.is_tricking())
	var t := 0.0
	var took := 0
	while t < 2.2:
		await process_frame
		t += minf(main.get_process_delta_time(), 0.05)
		if t > 0.32 and took == 0:
			took = 1
			await _shot("trick_ramp")
		if t > 0.85 and took == 1:
			took = 2
			await _shot("trick_air")
	print("trick done: tricking=%s x=%.2f lane=%d" % [main.player.is_tricking(), main.player.position.x, main.player.lane])


func _test_hole() -> void:
	main.grace = 0.0
	var hl: float = main.world._spawn_hole(-40.0, 2, false)
	print("hole spawned len ", hl)
	await _wait(1.0)
	await _shot("hole")
	main.grace = 9999.0


## Bus ramps and parked buses must be climbable, never an unfair death.
func _test_bus() -> void:
	for case in ["ramp", "ramp_side", "jump_back"]:
		main.start_zone = 0
		main._start_game()
		main.grace = 0.0
		var w = main.world
		for c in w.objects.get_children():
			c.queue_free()
		await process_frame
		var lane := -1 if case == "ramp_side" else 0
		main.player.lane = lane
		main.player.position.x = lane * 2.5
		w._spawn_bus(0, -45.0, false, case != "jump_back")
		for c in w.objects.get_children():
			c.set_meta("test", true)
		var maxy := 0.0
		var did := false
		var el := 0.0
		while el < 3.0 and main.state == main.State.PLAYING:
			for c in w.objects.get_children():
				if not c.has_meta("test") and c.get_meta("kind") != "coin" and c.position.z > -80.0:
					c.queue_free()
			var bus = null
			var rmp = null
			for c in w.objects.get_children():
				if c.has_meta("test") and c.get_meta("kind") == "bus":
					bus = c
				if c.has_meta("test") and c.get_meta("kind") == "ramp":
					rmp = c
			if not did and case == "ramp_side" and rmp != null and rmp.position.z + 3.0 > 3.0:
				did = true
				main._on_dir(1)
			if not did and case == "jump_back" and bus != null and bus.position.z + (bus.get_meta("box") as AABB).end.z > -main.speed * 0.42:
				did = true
				main.player.press_jump()
			maxy = maxf(maxy, main.player.position.y)
			await process_frame
			el += minf(main.get_process_delta_time(), 0.05)
		var kinds := []
		for c in w.objects.get_children():
			if c.has_meta("test") and c.get_meta("kind") == "bus":
				kinds.append("%.1fm" % (c.get_meta("box") as AABB).size.y)
		print("bus %-10s alive=%s  max_y=%.2f  roof=%s" % [case, main.state == main.State.PLAYING, maxy, kinds])
	main.grace = 9999.0


func _test_powers() -> void:
	for p in ["magnet", "shield", "springs", "double"]:
		main.world._spawn_power(Vector3(main.player.position.x, 1.2, -3.0), p)
		await _wait(0.25)
	print("powers: ", main.pw)
	await _shot("powers")


## Keeps to the lane with the fewest obstacles ahead; jumps / slides as needed.
func _autopilot() -> void:
	var p = main.player
	var best: int = p.lane
	var danger := {-1: 0.0, 0: 0.0, 1: 0.0}
	var need := ""
	for obj in main.world.objects.get_children():
		var k: String = obj.get_meta("kind")
		if not k in ["jump", "slide", "car", "speaker", "crate", "drone", "pop_wall", "pop_spikes", "drop", "bus"]:
			continue
		var z: float = obj.position.z
		if z > 1.0 or z < -30.0:
			continue
		var lane := clampi(roundi(obj.position.x / 2.5), -1, 1)
		danger[lane] += 1.0 if k in ["jump", "slide"] else 3.0
		if lane == p.lane and z > -9.0:
			if k == "jump":
				need = "jump"
			elif k == "slide":
				need = "slide"
	for l in [0, -1, 1]:
		if danger[l] < danger[best] - 0.5 and absi(l - p.lane) == 1:
			best = l
	if best != p.lane:
		main._on_dir(signi(best - p.lane))
	elif need == "jump" and p.grounded:
		p.press_jump()
		p.release_jump()
	elif need == "slide" and p.grounded:
		p.press_slide()


## Waits `s` seconds of GAME time (frames are clamped to 0.05 s by main).
func _wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await process_frame
		t += minf(main.get_process_delta_time(), 0.05)


func _shot(name: String) -> void:
	if not shots:
		return
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://tools/shots/%s.png" % name)
