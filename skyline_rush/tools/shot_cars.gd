extends SceneTree
## Dev tool: line-up of every vehicle type and livery from the vehicle kit.
func _initialize() -> void:
	var W := preload("res://scripts/world.gd")
	var CM := preload("res://scripts/car_models.gd")
	var root := Node3D.new()
	get_root().add_child(root)
	var w = W.new()
	root.add_child(w)
	await process_frame
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.62, 0.75)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	root.add_child(env)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-45, 35, 0)
	l.shadow_enabled = true
	root.add_child(l)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.3, 0.3, 0.34)
	ground.material_override = gm
	root.add_child(ground)
	var rows := [["taxi", "taxi"], ["sedan", "police"], ["hatch", "sport:1"], ["taxi", "taxi_green"], ["sedan", "two:0:2"],
		["minibus", "ambulance"], ["minibus", "icecream"], ["coach", "school"], ["truck", "fire"], ["truck2", "brand:4"]]
	var nodes := []
	for i in rows.size():
		var r: Array = w.car_instance(root, Vector3((i % 5) * 3.4 - 6.8, 0, -(i / 5) * 12.0), rows[i][0], rows[i][1], false, 0.0, Color(0.2, 0.5, 0.9), "FIZZ COLA")
		nodes.append(r[0])
		print(rows[i][0], " ", rows[i][1], " size ", r[1].size)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(9, 6, 11)
	cam.look_at(Vector3(0, 0.8, -5))
	cam.current = true
	RenderingServer.global_shader_parameter_set("curve_amount", Vector2.ZERO)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://tools/shots/cars_lineup.png")
	cam.position = Vector3(11, 2.0, -9)
	cam.look_at(Vector3(2, 1.0, -9))
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://tools/shots/cars_side.png")
	# close-ups of the +X side of each vehicle, alone (lettering check)
	for i in rows.size():
		for k in nodes.size():
			nodes[k].visible = k == i
		var c: Vector3 = nodes[i].position
		var far := 5.5 if i < 5 else 10.0
		cam.position = c + Vector3(far, 1.2, 0)
		cam.look_at(c + Vector3(0, 1.0, 0))
		for k in 2:
			await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("res://tools/shots/car_%d.png" % i)
	quit()
