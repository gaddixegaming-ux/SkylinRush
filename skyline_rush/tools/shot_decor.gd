extends SceneTree
## Dev tool: a close-up line-up of the v9 signs, logos, balloons and ambience.
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
	for i in 10:
		await process_frame
	main.start_zone = 4
	main._start_game()
	main.grace = 9999.0
	for i in 20:
		await process_frame
	main._set_paused(true)
	main.hud.show_pause(false)
	main.hud.hud.visible = false
	var th = main.world.themes
	var w = main.world
	for c in w.objects.get_children():
		c.queue_free()
	# row of logos on pole signs down the left, A-frames on the right
	w.batching = true
	for i in 10:
		var n := Node3D.new()
		n.position = Vector3(-4.4 + (i % 5) * 2.2, 0, -9.0 - (i / 5) * 5.0)
		w.scenery.add_child(n)
		var b: Array = th.BRANDS[i]
		th.logo(n, b[1], Vector3(0, 2.0 + (i / 5) * 1.3, 0), 1.3, b[2], b[3], 0.6)
		th.text(n, b[0], Vector3(0, 1.0 + (i / 5) * 1.3, 0), th._fit_px(b[0], 2.0, 0.011), Color.WHITE, 2.0)
	for i in 3:
		var n2 := Node3D.new()
		n2.position = Vector3(4.2, 0.13, -12.0 - i * 9.0)
		w.scenery.add_child(n2)
		th.aframe_sign(n2, 1.0, false) if i != 1 else th.pole_sign(n2, -1.0, false)
	th.billboard(-70.0, 1.0, false, true)
	w.batching = false
	w.flush_batches()
	await _shot("decor_signs")
	# sky: balloons, blimp, flock, kite, turbine
	w.batching = true
	for i in 3:
		th.hot_air_balloon(-60.0 - i * 25.0, -1.0 if i % 2 == 0 else 1.0)
	th.blimp(-110.0, 1.0, false)
	th.bird_flock(-50.0, 1.0)
	th.kite(-40.0, -1.0)
	th.wind_turbine(-120.0, 1.0)
	w.batching = false
	w.flush_batches()
	main.cam.rotation.x += 0.25
	await _shot("decor_sky")
	quit()
