extends SceneTree
## Dev tool: the same gameplay frame (HUD hidden) for renderer / brightness comparisons.
##   xvfb-run godot --rendering-method gl_compatibility --resolution 540x960 -s res://tools/shot_bright.gd -- <tag> [zone]
var main


func _initialize() -> void:
	var tag := "x"
	var zone := 0
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		tag = a[0]
	if a.size() > 1:
		zone = int(a[1])
	main = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	for i in 20:
		await process_frame
	if is_instance_valid(main.splash):
		main.splash.queue_free()
	seed(7)
	main.start_zone = zone
	main._start_game()
	main.grace = 9999.0
	var t := 0.0
	while t < 3.0:
		await process_frame
		t += minf(main.get_process_delta_time(), 0.05)
	if a.size() > 3:
		main.env.tonemap_exposure = float(a[2])
		main.amb_mult = float(a[3])
		main._snap_zone(zone)
	if a.size() > 4:
		main.env.tonemap_mode = int(a[4])
	main._set_paused(true)
	main.hud.show_pause(false)
	main.hud.hud.visible = false
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://tools/shots/bright_%s_z%d.png" % [tag, zone])
	print("shot ", tag, "  triangles ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"  draw calls ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"  objects ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	# per-model triangle counts of the biggest meshes in view
	var tally := {}
	for mi in get_root().find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var tri := 0
		for si in mi.mesh.get_surface_count():
			var arr = mi.mesh.surface_get_arrays(si)
			var idx = arr[Mesh.ARRAY_INDEX]
			tri += (idx.size() if idx != null and idx.size() > 0 else arr[Mesh.ARRAY_VERTEX].size()) / 3
		var key: String = mi.mesh.resource_path if mi.mesh.resource_path != "" else ("%s %s at %s size %s" % [mi.mesh.get_class(), mi.name, mi.global_position.snapped(Vector3.ONE), mi.mesh.get_aabb().size.snapped(Vector3.ONE * 0.1)])
		tally[key] = tally.get(key, 0) + tri
	var keys := tally.keys()
	keys.sort_custom(func(x, y): return tally[x] > tally[y])
	var total_by_class := {}
	for k in keys:
		var c: String = k.split(" ")[0]
		total_by_class[c] = total_by_class.get(c, 0) + tally[k]
	print("   by class: ", total_by_class)
	for k in keys.slice(0, 12):
		print("   ", tally[k], "  ", k)
	quit()
