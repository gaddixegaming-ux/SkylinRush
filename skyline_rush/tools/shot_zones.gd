extends SceneTree
## Dev tool: renders one gameplay screenshot per track to res://tools/shots/zone_<n>.png
##   xvfb-run godot --rendering-method gl_compatibility --resolution 1280x720 -s res://tools/shot_zones.gd -- 7 3
var main


func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	for i in 30:
		await process_frame
	var zones: Array = []
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			zones.append(int(a))
	if zones.is_empty():
		zones = range(9)
	DirAccess.make_dir_recursive_absolute("res://tools/shots")
	for z in zones:
		main.start_zone = z
		main._start_game()
		main.grace = 9999.0
		var t := 0.0
		while t < 3.0:
			await process_frame
			t += minf(main.get_process_delta_time(), 0.05)
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("res://tools/shots/zone_%d.png" % z)
		print("shot zone ", z)
	quit()
