extends SceneTree
## Dev tool: a grind rail and a warp tunnel spawned right in front of the runner.
var main


func _shot(name: String) -> void:
	for i in 4:
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
	main.start_zone = 2
	main._start_game()
	main.grace = 9999.0
	main.world.allow_tunnels = false
	var t := 0.0
	while t < 1.0:
		await process_frame
		t += minf(main.get_process_delta_time(), 0.05)
	for c in main.world.objects.get_children():
		if c.position.z > -60.0:
			c.queue_free()
	main.world._spawn_rail(-1, -24.0)
	main.world._spawn_tunnel(-12.0, 1)
	main._set_paused(true)
	main.hud.show_pause(false)
	await _shot("feat_rail_tunnel")
	var cam: Camera3D = main.cam
	cam.set_process(false)
	cam.position = Vector3(6.0, 4.0, -4.0)
	cam.look_at(Vector3(-1.0, 1.0, -16.0))
	await _shot("feat_side")
	for c in main.world.objects.get_children():
		if c.get_meta("kind") == "tunnel":
			c.visible = false
	cam.position = Vector3(1.5, 2.2, -6.0)
	cam.look_at(Vector3(-2.5, 0.8, -16.0))
	await _shot("feat_rail_close")
	main.env.glow_enabled = false
	await _shot("feat_rail_noglow")
	main.hud.post_rect.visible = false
	await _shot("feat_rail_nopost")
	quit()
