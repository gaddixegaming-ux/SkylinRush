extends SceneTree
## Dev tool: menu / gameplay / pause / settings in the phone (portrait) layout.
##   xvfb-run godot --rendering-method gl_compatibility --resolution 540x960 -s res://tools/shot_portrait.gd -- mobile
var main


func _shot(name: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://tools/shots/%s.png" % name)
	print("shot ", name)


func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	for i in 20:
		await process_frame
	if is_instance_valid(main.splash):
		main.splash.queue_free()
	for i in 40:
		await process_frame
	await _shot("portrait_menu")
	main._open_panel("settings")
	await _shot("portrait_panel")
	main._open_panel("upgrades")
	await _shot("portrait_upgrades")
	main._open_panel("")
	main.start_zone = 0
	main._start_game()
	main.grace = 9999.0
	var t := 0.0
	while t < 4.0:
		await process_frame
		t += minf(main.get_process_delta_time(), 0.05)
	main.hud.popup("PORTRAIT TEST", Color(1, 0.8, 0.3), 44)
	await _shot("portrait_play")
	for k in 3:
		t = 0.0
		while t < 1.3:
			await process_frame
			t += minf(main.get_process_delta_time(), 0.05)
		await _shot("portrait_play%d" % k)
	main._set_paused(true)
	await _shot("portrait_pause")
	quit()
