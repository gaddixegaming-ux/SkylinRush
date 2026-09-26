extends SceneTree
## Dev tool: renders every runner on every vehicle (and the trimmed trees /
## boards) so the rider poses can be checked.
## xvfb-run godot --rendering-method gl_compatibility -s res://tools/render_ride.gd -- side
const Rig := preload("res://characters/character_rig.gd")
const V := preload("res://scripts/vehicles.gd")
func _initialize() -> void:
	var view := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "side"
	var root := Node3D.new()
	get_root().add_child(root)
	await process_frame
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 40
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-35, 50, 0)
	root.add_child(l)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.68)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.6
	root.add_child(env)
	var rigs := []
	var kinds := ["moto", "hover", "skate"]
	for k in 3:
		for c in range(1, 6):
			var m := Node3D.new()
			m.position = Vector3(0, k * 2.4, (c - 3) * 3.0)
			root.add_child(m)
			var veh := V.build(kinds[k], c % 3)
			m.add_child(veh)
			var rig := Rig.new()
			m.add_child(rig)
			rig.setup(c)
			rig.set_props(false)
			rigs.append([rig, kinds[k], veh])
	match view:
		"side":
			cam.position = Vector3(19, 3.2, 0)
			cam.look_at(Vector3(0, 2.6, 0))
		"front":
			cam.position = Vector3(3, 3.5, -19)
			cam.look_at(Vector3(0, 2.6, 0))
		"back":
			cam.position = Vector3(-4, 4.5, 18)
			cam.look_at(Vector3(0, 2.6, 0))
	for i in 4:
		for r in rigs:
			r[0].ride_pose(r[1], r[2], 0.0, 0.0, 0.016)
			r[0].rotation.y = 1.45 if r[1] == "skate" else 0.0
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tools/shots")
	get_root().get_texture().get_image().save_png("res://tools/shots/ride_%s.png" % view)
	quit()
