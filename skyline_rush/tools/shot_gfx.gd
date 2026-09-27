extends SceneTree
## Dev tool: renders the same frozen frame with AO / GI off and on (Forward+).
##   xvfb-run godot --rendering-method forward_plus --resolution 1280x720 -s res://tools/shot_gfx.gd -- 6
var main


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://tools/shots/%s.png" % name)
	print("shot ", name)


func _modes(tag: String) -> void:
	for m in [["off", false, false], ["ao", true, false], ["ao_gi", true, true]]:
		main.prog.settings["quality"] = "high"
		main.prog.settings["ao"] = m[1]
		main.prog.settings["gi"] = m[2]
		main._apply_graphics()
		await _shot("gfx_%s_%s" % [tag, m[0]])


func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	for i in 20:
		await process_frame
	var zone := 6
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			zone = int(a)
	# lobby (PIXEL's bedroom)
	main.char_idx = 2
	main._select_char(1)
	for i in 30:
		await process_frame
	main.hud.menu.visible = false
	await _modes("lobby")
	main.hud.menu.visible = true
	# gameplay
	main.start_zone = zone
	main._start_game()
	main.grace = 9999.0
	var t := 0.0
	while t < 3.0:
		await process_frame
		t += minf(main.get_process_delta_time(), 0.05)
	main._set_paused(true)
	main.hud.show_pause(false)
	main.hud.hud.visible = false
	await _modes("zone%d" % zone)
	quit()
