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
		if t == 4:
			await _test_powers()
	# skyway camera: put the runner on a sky-highway
	main.start_zone = 1
	main._start_game()
	main.grace = 9999.0
	main.world._spawn_platform(12.0, 52.0)
	main.player.position.y = 6.2
	main.player.vy = 0.0
	await _wait(1.5)
	await _shot("skyway")
	# death + game over
	main.grace = 0.0
	main._crash("WIPED OUT")
	await _wait(1.6)
	await _shot("game_over")
	main._enter_menu()
	await _wait(0.5)
	print("SMOKE OK  wallet=%d best=%d" % [main.prog.wallet, main.prog.best])
	quit()


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
		if not k in ["jump", "slide", "car", "speaker", "crate", "drone", "pop_wall", "pop_spikes", "drop"]:
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
