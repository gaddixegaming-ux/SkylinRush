extends SceneTree
## Dev tool: renders every runner's lobby hobby at two moments (props + anims).
const Rig := preload("res://characters/character_rig.gd")
func _initialize() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	await process_frame
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 38
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-40, 40, 0)
	l.shadow_enabled = true
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
	for c in range(1, 6):
		var m := Node3D.new()
		m.position = Vector3((c - 3) * 3.2, 0, 0)
		root.add_child(m)
		var rig := Rig.new()
		m.add_child(rig)
		rig.setup(c)
		rigs.append(rig)
	cam.position = Vector3(4, 3.2, -12)
	cam.look_at(Vector3(0, 1.0, 0))
	var t := 0.0
	var times := [1.0, 2.2, 3.0, 3.3]
	for i in times.size():
		while t < times[i]:
			for r in rigs:
				r.play_hobby(1.0 / 30.0)
			await process_frame
			t += 1.0 / 30.0
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://tools/shots")
		get_root().get_texture().get_image().save_png("res://tools/shots/lobby_%d.png" % i)
	quit()
