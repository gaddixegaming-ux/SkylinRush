extends SceneTree
## Dev tool: close-up of a building with a fire escape, one with a gallery walkway,
## arcade corner + topiary + model cars.
func _initialize() -> void:
	var main = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	for i in 10:
		await process_frame
	if main.splash:
		main.splash.get_parent().queue_free()
		main.splash = null
	main.start_zone = 4
	main._start_game()
	main.grace = 9999.0
	for i in 5:
		await process_frame
	main._set_paused(true)
	main.hud.show_pause(false)
	main.hud.hud.visible = false
	var w = main.world
	var th = w.themes
	for c in w.objects.get_children():
		c.queue_free()
	w.batching = true
	var o := {"colors": [Color(0.9, 0.55, 0.45)], "floors": [4, 4], "stairs": "fire"}
	th.facade_building(-14.0, 1.0, o)
	var o2 := {"colors": [Color(0.55, 0.75, 0.9)], "floors": [3, 3], "stairs": "gallery"}
	th.facade_building(-12.0, -1.0, o2)
	var n := Node3D.new()
	n.position = Vector3(5.35, 0.13, -8.0)
	w.scenery.add_child(n)
	th.arcade_corner(n, 1.0)
	for k in 3:
		th.topiary(n, Vector3(-0.6, 0, -4.0 - k * 1.6))
	w.batching = false
	w.flush_batches()
	w._spawn_car(0, -16.0)
	w._spawn_car(1, -26.0)
	w._spawn_big_vehicle(-1, -30.0, false)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://tools/shots/build_closeup.png")
	quit()
