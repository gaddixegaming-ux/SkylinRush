extends SceneTree
## Bakes every Mixamo FBX in res://characters/source into ONE shared
## AnimationLibrary (res://characters/animations.res):
##  - renames clips to game names
##  - removes forward/sideways root motion (runner stays in place, keeps bounce)
##  - sets looping for cycles
##  - stores the source hip height so each character can be scaled on load
## Run:  godot --headless -s res://tools/bake_animations.gd
## (Re-run after adding new FBX files, e.g. Dribble.fbx / Run_Forward.fbx.)

const NAMES := {
	"Medium_Run": ["run", true], "Run_Forward": ["run_fast", true],
	"Running_Arc": ["arc_right", true], "Running_Arc_1": ["arc_left", true],
	"Running_Jump": ["jump", false], "Jump_1": ["jump2", false], "Jump": ["jump_alt", false],
	"Running_Slide": ["slide", false], "Dash": ["dash", true], "Soccer_Tackle": ["tackle", false],
	"Fall_Flat_1": ["fall", false], "Sweep_Fall": ["trip", false],
	"Leaning_On_A_Wall": ["hobby_lean", true], "Golf_Drive": ["hobby_golf", true],
	"Golf_Bad_Shot": ["hobby_golf_bad", true], "Punching_Bag": ["hobby_punch", true],
	"Gaming": ["hobby_gaming", true], "Dribble": ["hobby_dribble", true],
}
const KEEP_ROOT_MOTION := ["fall", "trip"]  # keep their forward topple, still centred


func _find(n: Node, cls: String):
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var r = _find(c, cls)
		if r:
			return r
	return null


func _initialize() -> void:
	var lib := AnimationLibrary.new()
	var d := DirAccess.open("res://characters/source")
	for f in d.get_files():
		if not f.ends_with(".fbx"):
			continue
		var base := f.get_basename()
		if not NAMES.has(base):
			print("skip (unknown clip name): ", f)
			continue
		var ps: PackedScene = load("res://characters/source/" + f)
		var inst: Node = ps.instantiate()
		var ap: AnimationPlayer = _find(inst, "AnimationPlayer")
		var sk: Skeleton3D = _find(inst, "Skeleton3D")
		if ap == null or sk == null:
			print("no animation/skeleton in ", f)
			inst.free()
			continue
		var src: Animation = ap.get_animation(ap.get_animation_list()[0])
		var a: Animation = src.duplicate(true)
		var info: Array = NAMES[base]
		var name: String = info[0]
		a.loop_mode = Animation.LOOP_LINEAR if info[1] else Animation.LOOP_NONE
		var hip := sk.find_bone("mixamorig_Hips")
		a.set_meta("src_hips_y", sk.get_bone_rest(hip).origin.y)
		for t in a.get_track_count():
			if a.track_get_type(t) != Animation.TYPE_POSITION_3D:
				continue
			var kc := a.track_get_key_count(t)
			if kc < 2:
				var v0: Vector3 = a.track_get_key_value(t, 0)
				a.track_set_key_value(t, 0, Vector3(0.0, v0.y, 0.0))
				continue
			var first: Vector3 = a.track_get_key_value(t, 0)
			var last: Vector3 = a.track_get_key_value(t, kc - 1)
			var t0 := a.track_get_key_time(t, 0)
			var t1 := a.track_get_key_time(t, kc - 1)
			for k in kc:
				var v: Vector3 = a.track_get_key_value(t, k)
				var fr := (a.track_get_key_time(t, k) - t0) / maxf(t1 - t0, 0.0001)
				if name in KEEP_ROOT_MOTION:
					v.x -= first.x
					v.z -= first.z
					v.z *= 0.35
				else:
					# remove the linear drift, keep the per-step sway/bob
					v.x -= first.x + (last.x - first.x) * fr
					v.z -= first.z + (last.z - first.z) * fr
				a.track_set_key_value(t, k, v)
		lib.add_animation(name, a)
		print("baked %-16s <- %-20s %.2fs loop=%s" % [name, f, a.length, info[1]])
		inst.free()
	var err := ResourceSaver.save(lib, "res://characters/animations.res")
	print("saved animations.res (", lib.get_animation_list().size(), " clips) err=", err)
	quit()
