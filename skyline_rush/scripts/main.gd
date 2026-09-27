extends Node3D
## Skyline Rush - game director: state, input, abilities (Q / E / double-tap
## SPACE), power-ups, vehicles per map, flow meter, scoring, zones, economy
## (wallet, upgrades, garage) and game-feel (camera kicks, flashes). No slow motion.

const WorldScript := preload("res://scripts/world.gd")
const PlayerScript := preload("res://scripts/player.gd")
const CamScript := preload("res://scripts/camera_rig.gd")
const HudScript := preload("res://scripts/hud.gd")
const AudioScript := preload("res://scripts/audio.gd")
const FxScript := preload("res://scripts/fx.gd")
const ThemesScript := preload("res://scripts/themes.gd")
const RigScript := preload("res://characters/character_rig.gd")
const ProgressScript := preload("res://scripts/progress.gd")
const VehScript := preload("res://scripts/vehicles.gd")
const LobbyScript := preload("res://scripts/lobby.gd")
const StyleScript := preload("res://scripts/style.gd")
const EventsScript := preload("res://scripts/events.gd")
const EnemiesScript := preload("res://scripts/enemies.gd")
const TouchScript := preload("res://scripts/touch.gd")

const LANE_WIDTH := 2.5
const START_SPEED := 16.0
const MAX_SPEED := 44.0
const SPEED_GAIN := 0.3
## Stepped pacing: warm up to CRUISE_SPEED, then the speed stays constant for
## SPEED_HOLD seconds, rises a little (SPEED_STEP, eased in over a few
## seconds), and holds again - until MAX_SPEED.
const CRUISE_SPEED := 24.0
const SPEED_HOLD := 45.0
const SPEED_STEP := 2.5
const SPEED_EASE := 0.7   # m/s per second while stepping up
const MENU_SPEED := 9.0
const ZONE_LEN := 750.0

const PINK := Color(1.0, 0.35, 0.75)
const CYAN := Color(0.35, 0.9, 1.0)
const GOLD := Color(1.0, 0.8, 0.25)
const GREEN := Color(0.4, 1.0, 0.6)

## The three ability slots on the HUD.
const ABILITIES := [
	{"id": "dash", "name": "DASH", "key": "Q", "color": Color(1.0, 0.35, 0.75)},
	{"id": "hook", "name": "GRAPPLE", "key": "E", "color": Color(0.4, 1.0, 0.6)},
	{"id": "sky", "name": "SKY JUMP", "key": "SPACE x2", "color": Color(0.45, 0.75, 1.0)},
]
const DASH := 0
const HOOK := 1
const SKY := 2
const DASH_DUR := 0.45
const AIRDASH_CD := 0.6
const WALL_CD := 1.0
const SLAM_CD := 3.5
const HOOK_CD := 1.0

const POWER_NAME := {"magnet": "COIN MAGNET", "shield": "SHIELD", "springs": "SPRING SHOES", "double": "2X SCORE"}
const VEH_ZONE := {2: "skate", 5: "hover", 8: "moto"}
const VEH_SPEED := {"skate": 1.1, "hover": 1.18, "moto": 1.28}

const ZONES := [
	{"name": "SKY ROADS", "top": Color(0.42, 0.52, 0.98), "hor": Color(1.0, 0.74, 0.92), "fog": Color(0.98, 0.8, 0.96),
		"sun": Color(1.0, 0.92, 0.95), "sun_e": 1.2, "amb": 1.0, "stars": 0.0, "ground": Color(0.6, 0.4, 0.8), "fog_d": 0.011, "plight": 0.0, "fx": "motes", "wet": false},
	{"name": "LANTERN FESTIVAL", "top": Color(0.3, 0.62, 1.0), "hor": Color(0.86, 0.93, 1.0), "fog": Color(0.86, 0.9, 1.0),
		"sun": Color(1.0, 0.95, 0.85), "sun_e": 1.35, "amb": 1.1, "stars": 0.0, "ground": Color(0.8, 0.75, 0.7), "fog_d": 0.009, "plight": 0.0, "fx": "confetti", "wet": false},
	{"name": "SKATE PARK", "top": Color(0.15, 0.55, 1.0), "hor": Color(0.72, 0.9, 1.0), "fog": Color(0.8, 0.91, 1.0),
		"sun": Color(1.0, 0.97, 0.88), "sun_e": 1.2, "amb": 0.95, "stars": 0.0, "ground": Color(0.8, 0.85, 0.7), "fog_d": 0.007, "plight": 0.0, "fx": "none", "wet": false},
	{"name": "NEON RAIN ALLEY", "top": Color(0.02, 0.03, 0.1), "hor": Color(0.15, 0.22, 0.5), "fog": Color(0.14, 0.18, 0.42),
		"sun": Color(0.5, 0.6, 1.0), "sun_e": 0.35, "amb": 0.55, "stars": 0.0, "ground": Color(0.05, 0.06, 0.15), "fog_d": 0.02, "plight": 1.3, "fx": "rain", "wet": true},
	{"name": "NEON MARKET", "top": Color(0.42, 0.5, 0.95), "hor": Color(0.98, 0.75, 0.9), "fog": Color(0.88, 0.76, 0.95),
		"sun": Color(1.0, 0.85, 0.9), "sun_e": 1.0, "amb": 0.95, "stars": 0.0, "ground": Color(0.5, 0.4, 0.6), "fog_d": 0.011, "plight": 0.3, "fx": "sparks", "wet": false},
	{"name": "HOVER HARBOR", "top": Color(0.3, 0.42, 0.85), "hor": Color(1.0, 0.78, 0.58), "fog": Color(1.0, 0.8, 0.68),
		"sun": Color(1.0, 0.78, 0.55), "sun_e": 1.3, "amb": 1.0, "stars": 0.0, "ground": Color(0.8, 0.6, 0.7), "fog_d": 0.01, "plight": 0.0, "fx": "none", "wet": false},
	{"name": "SAKURA HEIGHTS", "top": Color(0.5, 0.62, 1.0), "hor": Color(1.0, 0.86, 0.9), "fog": Color(1.0, 0.88, 0.93),
		"sun": Color(1.0, 0.93, 0.9), "sun_e": 1.2, "amb": 1.05, "stars": 0.0, "ground": Color(0.7, 0.75, 0.6), "fog_d": 0.01, "plight": 0.0, "fx": "petals", "wet": false},
	{"name": "CANDY CARNIVAL", "top": Color(0.22, 0.18, 0.5), "hor": Color(1.0, 0.55, 0.5), "fog": Color(0.9, 0.55, 0.62),
		"sun": Color(1.0, 0.65, 0.55), "sun_e": 0.8, "amb": 0.8, "stars": 0.4, "ground": Color(0.45, 0.3, 0.45), "fog_d": 0.013, "plight": 0.8, "fx": "sparks", "wet": false},
	{"name": "TURBO HIGHWAY", "top": Color(0.2, 0.22, 0.55), "hor": Color(1.0, 0.6, 0.38), "fog": Color(0.98, 0.66, 0.52),
		"sun": Color(1.0, 0.75, 0.55), "sun_e": 1.15, "amb": 0.9, "stars": 0.1, "ground": Color(0.45, 0.32, 0.3), "fog_d": 0.008, "plight": 0.2, "fx": "none", "wet": false},
]
const ZONE_LOOKAHEAD := 215.0

enum State { MENU, PLAYING, PAUSED, DEAD }

var state: State = State.MENU
var world
var player
var cam
var hud
var audio
var fx
var prog
var speed_lines: CPUParticles3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var stars_mat: StandardMaterial3D
var planet: Node3D

var speed := START_SPEED
var speed_target := CRUISE_SPEED
var speed_hold := 0.0
var distance := 0.0
var score := 0.0
var gold := 0
var banked := 0
var close_calls := 0
var ab_cd: Array[float] = [0.0, 0.0, 0.0]
var ab_active: Array[float] = [0.0, 0.0, 0.0]
var airdash_cd := 0.0
var wall_cd := 0.0
var slam_cd := 0.0
var pw := {"magnet": 0.0, "shield": 0.0, "springs": 0.0, "double": 0.0}
var flow := 0.0
var flow_idle := 0.0
var flow_tier := 0
var wall_active := false
var grapple_active := false
var dashjump_carry := false
var grace := 0.0
var stumble_timer := 0.0
var portal_boost := 0.0
var dead_timer := 0.0
var death_title := ""
var new_best := false
var curve := Vector2(0.0008, -0.0004)
var curve_target := Vector2.ZERO
var curve_timer := 0.0
var beat := 0.0
var coin_streak := 0
var coin_streak_t := 0.0
var last_km := 0
var zone_idx := 0
var zone_from: Dictionary = {}
var zone_cur: Dictionary = {}
var zone_t := 1.0
var shift_amount := 0.0
var start_zone := 0
var char_idx := 1
var zone_start := 0.0
var warp_t := 0.0
var warp_target := -1
var warped := false
var weather: CPUParticles3D
var weather_mat: StandardMaterial3D
var player_light: OmniLight3D
var grind_t := 0.0
var grind_fx_t := 0.0
var on_rail := false
var revive_cost := 150
var revive_bridge_t := 0.0
var veh_hits := 0
var veh_time := 0.0
var veh_granted_zone := -1
var skate_combo := 0
var skate_combo_t := 0.0
var tricking := false
var panel := ""          # menu overlay: "", "garage", "upgrades"
var garage_type := "skate"
var garage_pick := {}
var stage: Node3D
var lobby: Node3D
var splash: Control
var stage_ring: MeshInstance3D
var stage_mats: Array = []
# ---- v9
var style                 # style.gd (STYLE / momentum multiplier)
var events                # events.gd (random events)
var enemies               # enemies.gd
var touch                 # touch.gd (mobile swipe + buttons)
var run_frags := 0
var run_keys := 0
var run_artifacts: Array = []
var run_missions: Array = []
var run_rank := 0
var route := ""           # "high" / "under" while on a branch route
var head_start := 0.0     # metres of HEAD START boost left
var mission_t := 0.0
var enemy_t := 30.0
var is_mobile := false
var perf_t := 0.0
var perf_frames := 0
var perf_level := 0       # auto-performance steps taken (0 = none)


# ============================================================ setup
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	prog = ProgressScript.new()
	prog.load_file()
	char_idx = clampi(prog.char_idx, 1, RigScript.count() - 1)  # 0 (the old fox) is retired
	start_zone = clampi(prog.track, 0, ZONES.size() - 1)
	for t in VehScript.TYPES:
		garage_pick[t] = prog.equipped[t]
	_setup_input()
	_build_env()

	world = WorldScript.new()
	add_child(world)
	fx = FxScript.new()
	add_child(fx)
	player = PlayerScript.new()
	add_child(player)
	player.jumped.connect(_on_jumped)
	player.landed.connect(_on_landed)
	player.slid.connect(func():
		_style_move("slide")
		if player.vehicle == "moto" or player.vehicle == "hover":
			audio.play("grind", 0.55, -3.0)
			audio.play("dash", 0.8, -8.0)
		else:
			audio.play("slide", randf_range(0.95, 1.05), -4.0))
	player.grapple_released.connect(_on_grapple_released)
	player_light = OmniLight3D.new()
	player_light.position = Vector3(0, 2.6, 1.8)
	player_light.light_color = Color(1.0, 0.85, 0.75)
	player_light.omni_range = 9.0
	player_light.light_energy = 0.0
	player.add_child(player_light)

	cam = CamScript.new()
	add_child(cam)
	cam.current = true
	_build_speed_lines()
	_build_weather()

	audio = AudioScript.new()
	add_child(audio)

	hud = HudScript.new()
	add_child(hud)
	hud.setup_abilities(ABILITIES)
	hud.play_pressed.connect(_start_game)
	hud.retry_pressed.connect(_start_game)
	hud.menu_pressed.connect(_enter_menu)
	hud.resume_pressed.connect(func(): _set_paused(false))
	hud.quit_pressed.connect(func(): get_tree().quit())
	hud.track_changed.connect(_select_track)
	hud.revive_pressed.connect(_revive)
	hud.char_changed.connect(_select_char)
	hud.panel_requested.connect(_open_panel)
	hud.garage_tab.connect(_garage_tab)
	hud.garage_item.connect(_garage_item)
	hud.upgrade_buy.connect(_buy_upgrade)
	hud.frag_buy.connect(_buy_frag_upgrade)
	hud.cosmetic_pick.connect(_pick_cosmetic)
	hud.setting_changed.connect(_change_setting)

	style = StyleScript.new()
	events = EventsScript.new()
	events.setup(self)
	enemies = EnemiesScript.new()
	add_child(enemies)
	enemies.setup(self, world)
	enemies.process_mode = Node.PROCESS_MODE_PAUSABLE
	is_mobile = OS.has_feature("mobile") or "--mobile" in OS.get_cmdline_user_args() \
			or bool(ProjectSettings.get_setting("skyline/mobile_build", false))
	if is_mobile and not prog.settings.has("_mobile_init"):
		prog.settings["touch"] = true
		prog.settings["quality"] = "mobile"
		prog.settings["_mobile_init"] = true
	touch = TouchScript.new()
	touch.game = self
	hud.root.add_child(touch)

	for n in [world, fx, player, cam]:
		n.process_mode = Node.PROCESS_MODE_PAUSABLE
	zone_cur = ZONES[0].duplicate()
	_apply_zone(zone_cur)
	_native_display()
	_apply_settings()
	_build_stage()
	lobby = LobbyScript.new()
	add_child(lobby)
	lobby.setup(world.themes)
	_enter_menu()
	_show_splash()


## Fullscreen at the monitor's native resolution; the 3D view renders 1:1
## with the screen's pixels (no upscaling) and the UI scales to fit.
func _native_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = 1.0


## Studio splash: the Chaos Games card fades out over the menu (any key skips).
func _show_splash() -> void:
	var tex = load("res://splash.png")
	if tex == null or DisplayServer.get_name() == "headless":
		return
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.96, 0.96, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_end_splash())
	layer.add_child(bg)
	var img := TextureRect.new()
	img.texture = tex
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.add_child(img)
	splash = bg
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_callback(_end_splash)


func _end_splash() -> void:
	if splash == null:
		return
	var s := splash
	splash = null
	var tw := create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.6)
	tw.tween_callback(s.get_parent().queue_free)


func _build_env() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.12
	sky_mat.sun_angle_max = 30.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.65
	env.glow_strength = 1.0
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.25
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	# depth fog: clear up close, only fades the far distance (hides pop-in)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 0.9
	env.fog_depth_begin = 110.0
	env.fog_depth_end = 245.0
	env.fog_depth_curve = 1.6
	env.fog_aerial_perspective = 0.1
	env.fog_sky_affect = 0.15
	env.ssao_enabled = true
	env.ssao_intensity = 1.0
	env.ssao_radius = 0.8
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	sun.shadow_blur = 1.5
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_color = Color(0.7, 0.6, 1.0)
	fill.light_energy = 0.35
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(fill)

	# Sky Roads: a giant ringed planet in the sky (fixed, like the stars)
	planet = Node3D.new()
	planet.position = Vector3(-230.0, 170.0, -430.0)
	add_child(planet)
	var pmesh := SphereMesh.new()
	pmesh.radius = 55.0
	pmesh.height = 110.0
	var pmi := MeshInstance3D.new()
	pmi.mesh = pmesh
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.85, 0.5, 0.8)
	pm.emission_enabled = true
	pm.emission = Color(0.75, 0.4, 0.8)
	pm.emission_energy_multiplier = 0.12
	pm.disable_fog = true
	pm.rim_enabled = true
	pmi.material_override = pm
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	planet.add_child(pmi)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 72.0
	tm.outer_radius = 100.0
	tm.rings = 64
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.75, 0.85, 1.0, 0.55)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.emission_enabled = true
	rm.emission = Color(0.6, 0.75, 1.0)
	rm.emission_energy_multiplier = 0.4
	rm.disable_fog = true
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rm
	ring.scale = Vector3(1, 0.04, 1)
	ring.rotation = Vector3(0.35, 0, 0.3)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	planet.add_child(ring)
	planet.visible = false

	# star field for the night zones
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := SphereMesh.new()
	sm.radius = 0.9
	sm.height = 1.8
	sm.radial_segments = 6
	sm.rings = 3
	mm.mesh = sm
	mm.instance_count = 700
	for i in mm.instance_count:
		var dir := Vector3(randf_range(-1, 1), randf_range(0.08, 1.0), randf_range(-1, 0.3)).normalized()
		var s := randf_range(0.4, 1.3)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), dir * 420.0))
	var stars := MultiMeshInstance3D.new()
	stars.multimesh = mm
	stars_mat = StandardMaterial3D.new()
	stars_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stars_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stars_mat.disable_fog = true
	stars_mat.albedo_color = Color(1.4, 1.3, 1.6, 0.0)
	stars.material_override = stars_mat
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stars)


## Menu showroom: glossy floor with a neon grid, a podium with a glowing ring,
## a curved wall of LED panels, spotlights and a far city silhouette. Shown
## instead of the live track so nothing in the menu overlaps.
func _build_stage() -> void:
	stage = Node3D.new()
	add_child(stage)
	var mat := func(c: Color, e := 0.0, rough := 0.5, metal := 0.0) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		m.metallic = metal
		if e > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = e
		return m
	var add := func(mesh: Mesh, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = m
		mi.position = pos
		mi.rotation = rot
		stage.add_child(mi)
		return mi
	var cyl := func(r: float, h: float) -> CylinderMesh:
		var c := CylinderMesh.new()
		c.top_radius = r
		c.bottom_radius = r
		c.height = h
		c.radial_segments = 48
		return c
	var bx := func(size: Vector3) -> BoxMesh:
		var b := BoxMesh.new()
		b.size = size
		return b
	add.call(cyl.call(40.0, 0.2), Vector3(0, -0.45, 0), mat.call(Color(0.1, 0.08, 0.16), 0.0, 0.15, 0.3))
	for i in 21:
		var o := -20.0 + i * 2.0
		add.call(bx.call(Vector3(40, 0.01, 0.04)), Vector3(0, -0.34, o), mat.call(Color(0.5, 0.3, 1.0), 0.8))
		add.call(bx.call(Vector3(0.04, 0.01, 40)), Vector3(o, -0.34, 0), mat.call(Color(0.5, 0.3, 1.0), 0.8))
	add.call(cyl.call(2.7, 0.3), Vector3(0, -0.2, 0), mat.call(Color(0.18, 0.16, 0.24), 0.0, 0.3, 0.6))
	add.call(cyl.call(2.45, 0.06), Vector3(0, -0.03, 0), mat.call(Color(0.32, 0.3, 0.42), 0.0, 0.35, 0.3))
	var tm := TorusMesh.new()
	tm.inner_radius = 2.62
	tm.outer_radius = 2.78
	tm.rings = 64
	stage_ring = add.call(tm, Vector3(0, -0.05, 0), mat.call(Color(1.0, 0.35, 0.75), 3.0))
	var tm2 := TorusMesh.new()
	tm2.inner_radius = 2.3
	tm2.outer_radius = 2.36
	tm2.rings = 64
	add.call(tm2, Vector3(0, 0.0, 0), mat.call(Color(0.35, 0.9, 1.0), 2.5))
	# curved LED wall behind the runner (camera looks from ~2.2 rad)
	var back := 2.2 + PI
	for k in 11:
		var a := back + (k - 5) * 0.2
		var p := Vector3(sin(a) * 9.0, 2.6, cos(a) * 9.0)
		var panel: MeshInstance3D = add.call(bx.call(Vector3(1.7, 6.0, 0.3)), p, mat.call(Color(0.12, 0.1, 0.2), 0.0, 0.3, 0.4), Vector3(0, a, 0))
		var c: Color = [Color(1.0, 0.35, 0.75), Color(0.35, 0.9, 1.0), Color(0.6, 0.45, 1.0)][k % 3]
		var m2: StandardMaterial3D = mat.call(c, 1.2)
		stage_mats.append(m2)
		var screen: MeshInstance3D = add.call(bx.call(Vector3(1.45, 4.8, 0.05)), p - Vector3(sin(a), 0, cos(a)) * 0.18, m2, Vector3(0, a, 0))
		screen.set_meta("k", k)
		add.call(bx.call(Vector3(1.75, 0.08, 0.35)), p + Vector3(0, 3.0, 0), mat.call(Color(1, 1, 1), 2.0), Vector3(0, a, 0))
	# far skyline
	for k in 40:
		var a := back + randf_range(-1.6, 1.6)
		var d := randf_range(28.0, 36.0)
		var h := randf_range(6.0, 22.0)
		add.call(bx.call(Vector3(randf_range(3, 6), h, randf_range(3, 6))), Vector3(sin(a) * d, h * 0.5 - 0.4, cos(a) * d), mat.call(Color(0.16, 0.12, 0.26), 0.0), Vector3(0, a, 0))
		for f in int(h / 3.0):
			if randf() < 0.5:
				add.call(bx.call(Vector3(0.5, 0.35, 0.05)), Vector3(sin(a) * (d - 2.6), 1.5 + f * 3.0, cos(a) * (d - 2.6)) + Vector3(cos(a), 0, -sin(a)) * randf_range(-1.5, 1.5), mat.call(Color(1.0, 0.8, 0.5), 2.0), Vector3(0, a, 0))
	# spotlights on the podium
	for k in 3:
		var sl := SpotLight3D.new()
		var a := 2.2 + (k - 1) * 1.1
		sl.position = Vector3(sin(a) * 5.0, 7.0, cos(a) * 5.0)
		stage.add_child(sl)
		sl.look_at(Vector3(0, 0.5, 0))
		sl.spot_angle = 22.0
		sl.spot_range = 14.0
		sl.light_energy = 1.3
		sl.light_color = [Color(1.0, 0.85, 0.95), Color(0.8, 0.9, 1.0), Color(1.0, 0.9, 0.8)][k]
		sl.shadow_enabled = k == 1
	stage.visible = false


func _animate_stage(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in stage_mats.size():
		var m: StandardMaterial3D = stage_mats[i]
		m.emission_energy_multiplier = 0.6 + 0.8 * (0.5 + 0.5 * sin(t * 2.0 + i * 0.7)) + beat * 0.8
	stage_ring.rotation.y += delta * 0.3


func _build_speed_lines() -> void:
	speed_lines = CPUParticles3D.new()
	speed_lines.amount = 110
	speed_lines.lifetime = 0.45
	speed_lines.local_coords = true
	speed_lines.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	speed_lines.emission_ring_axis = Vector3(0, 0, 1)
	speed_lines.emission_ring_radius = 9.0
	speed_lines.emission_ring_inner_radius = 4.0
	speed_lines.emission_ring_height = 1.0
	speed_lines.position = Vector3(0, 0, -28)
	speed_lines.direction = Vector3(0, 0, 1)
	speed_lines.spread = 1.0
	speed_lines.gravity = Vector3.ZERO
	speed_lines.initial_velocity_min = 70.0
	speed_lines.initial_velocity_max = 95.0
	var bm := BoxMesh.new()
	bm.size = Vector3(0.035, 0.035, 4.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.95, 1.0, 0.45)
	bm.material = m
	speed_lines.mesh = bm
	speed_lines.emitting = false
	cam.add_child(speed_lines)


func _build_weather() -> void:
	weather = CPUParticles3D.new()
	weather.local_coords = true
	weather.emitting = false
	weather_mat = StandardMaterial3D.new()
	weather_mat.vertex_color_use_as_albedo = true
	weather_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	weather_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cam.add_child(weather)


func _set_weather(kind: String, wet: bool) -> void:
	env.ssr_enabled = false  # too costly for the rain alley
	weather.emitting = false
	if kind == "none":
		return
	var bm := BoxMesh.new()
	var grad := Gradient.new()
	weather.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	weather.gravity = Vector3.ZERO
	weather.spread = 12.0
	weather_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	match kind:
		"rain":
			bm.size = Vector3(0.025, 0.9, 0.025)
			weather.amount = 160 if is_mobile else 320
			weather.lifetime = 0.55
			weather.position = Vector3(0, 9.0, -9.0)
			weather.emission_box_extents = Vector3(16, 1, 14)
			weather.direction = Vector3(0, -1, 0.25)
			weather.spread = 2.0
			weather.initial_velocity_min = 30.0
			weather.initial_velocity_max = 40.0
			weather_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			grad.set_color(0, Color(0.6, 0.7, 1.0, 0.45))
			grad.set_color(1, Color(0.8, 0.8, 1.0, 0.35))
		"confetti", "petals":
			bm.size = Vector3(0.14, 0.02, 0.1)
			weather.amount = 160
			weather.lifetime = 3.0
			weather.position = Vector3(0, 7.0, -14.0)
			weather.emission_box_extents = Vector3(16, 3, 12)
			weather.direction = Vector3(0.2, -0.4, 1.0)
			weather.initial_velocity_min = 4.0
			weather.initial_velocity_max = 8.0
			weather.gravity = Vector3(0.5, -1.2, 0)
			weather.angular_velocity_min = -200.0
			weather.angular_velocity_max = 200.0
			if kind == "petals":
				grad.set_color(0, Color(1.0, 0.75, 0.85))
				grad.set_color(1, Color(1.0, 0.9, 0.95))
			else:
				grad.set_color(0, Color(1.0, 0.4, 0.5))
				grad.add_point(0.33, Color(0.4, 0.8, 1.0))
				grad.add_point(0.66, Color(1.0, 0.85, 0.3))
				grad.set_color(grad.get_point_count() - 1, Color(0.6, 1.0, 0.6))
		"motes":
			# Sky Roads: slow pastel light motes drifting past
			bm.size = Vector3(0.09, 0.09, 0.09)
			weather.amount = 60 if is_mobile else 110
			weather.lifetime = 4.0
			weather.position = Vector3(0, 3.0, -16.0)
			weather.emission_box_extents = Vector3(18, 6, 14)
			weather.direction = Vector3(0, 0.3, 1.0)
			weather.initial_velocity_min = 2.0
			weather.initial_velocity_max = 5.0
			weather.gravity = Vector3(0, 0.25, 0)
			weather_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			grad.set_color(0, Color(2.0, 1.2, 1.8, 0.0))
			grad.add_point(0.3, Color(1.6, 1.6, 2.2, 0.9))
			grad.set_color(grad.get_point_count() - 1, Color(2.0, 1.9, 1.2, 0.0))
		"sparks":
			bm.size = Vector3(0.07, 0.07, 0.07)
			weather.amount = 90
			weather.lifetime = 3.0
			weather.position = Vector3(0, 1.0, -12.0)
			weather.emission_box_extents = Vector3(14, 3, 12)
			weather.direction = Vector3(0, 1, 0.6)
			weather.initial_velocity_min = 1.0
			weather.initial_velocity_max = 3.0
			weather_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			grad.set_color(0, Color(2.0, 1.4, 0.6, 0.9))
			grad.set_color(1, Color(2.0, 0.8, 1.6, 0.9))
	bm.material = weather_mat
	weather.mesh = bm
	weather.color_initial_ramp = grad
	weather.emitting = true


# ============================================================ input
func _setup_input() -> void:
	var keys := {
		"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_W, KEY_UP, KEY_SPACE], "slide": [KEY_S, KEY_DOWN, KEY_CTRL],
		"ab_dash": [KEY_Q, KEY_SHIFT], "ab_hook": [KEY_E],
		"pause": [KEY_ESCAPE, KEY_P], "confirm": [KEY_ENTER, KEY_SPACE],
		"music": [KEY_M], "fullscreen": [KEY_F11], "controls": [KEY_TAB],
		"revive": [KEY_R], "garage": [KEY_G], "upgrades": [KEY_U],
		"customize": [KEY_C], "records": [KEY_H], "settings": [KEY_O],
	}
	var pads := {
		"left": [JOY_BUTTON_DPAD_LEFT], "right": [JOY_BUTTON_DPAD_RIGHT],
		"jump": [JOY_BUTTON_A], "slide": [JOY_BUTTON_B], "ab_dash": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_Y],
		"ab_hook": [JOY_BUTTON_X, JOY_BUTTON_LEFT_SHOULDER],
		"pause": [JOY_BUTTON_START], "confirm": [JOY_BUTTON_A], "revive": [JOY_BUTTON_Y],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	for action in pads:
		for b in pads[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = b
			InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if splash != null:
		if event.is_pressed():
			_end_splash()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("fullscreen"):
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if event.is_action_pressed("music"):
		audio.toggle_music()
		return

	match state:
		State.MENU:
			if panel != "":
				var closes: bool = event.is_action_pressed("pause") or (InputMap.has_action(panel) and event.is_action_pressed(panel))
				if closes:
					_open_panel("")
				elif panel == "garage" and event.is_action_pressed("left"):
					_garage_tab(VehScript.TYPES[posmod(VehScript.TYPES.find(garage_type) - 1, 3)])
				elif panel == "garage" and event.is_action_pressed("right"):
					_garage_tab(VehScript.TYPES[posmod(VehScript.TYPES.find(garage_type) + 1, 3)])
				return
			if event.is_action_pressed("confirm"):
				_start_game()
			elif event.is_action_pressed("controls"):
				hud.toggle_controls()
			elif event.is_action_pressed("garage"):
				_open_panel("garage")
			elif event.is_action_pressed("upgrades"):
				_open_panel("upgrades")
			elif event.is_action_pressed("customize"):
				_open_panel("customize")
			elif event.is_action_pressed("records"):
				_open_panel("records")
			elif event.is_action_pressed("settings"):
				_open_panel("settings")
			elif event.is_action_pressed("ab_dash"):
				_select_char(-1)
			elif event.is_action_pressed("ab_hook"):
				_select_char(1)
			elif event.is_action_pressed("left"):
				_select_track(-1)
			elif event.is_action_pressed("right"):
				_select_track(1)
		State.PAUSED:
			if event.is_action_pressed("pause"):
				_set_paused(false)
		State.DEAD:
			if dead_timer > 1.2:
				if event.is_action_pressed("revive"):
					_revive()
				elif event.is_action_pressed("confirm"):
					_start_game()
				elif event.is_action_pressed("pause"):
					_enter_menu()
		State.PLAYING:
			if event.is_action_pressed("pause"):
				_set_paused(true)
			elif event.is_action_pressed("left"):
				_on_dir(-1)
			elif event.is_action_pressed("right"):
				_on_dir(1)
			elif event.is_action_pressed("jump"):
				player.sky_ready = ab_cd[SKY] <= 0.0
				player.press_jump()
			elif event.is_action_released("jump"):
				player.release_jump()
			elif event.is_action_pressed("slide"):
				_on_slide()
			elif event.is_action_pressed("ab_dash"):
				_use_dash()
			elif event.is_action_pressed("ab_hook"):
				_use_hook()


func _on_dir(dir: int) -> void:
	if player.is_tricking():
		return
	if player.wall_side != 0:
		if dir == -player.wall_side:
			player.end_wall(false)
			audio.play("click", 0.8, -6.0)
		return
	# swerving into a quarter-pipe from the outer lane: skate trick
	if player.lane == dir and world.qpipe_at(dir) != null and not player.is_grappling():
		_start_trick(dir)
		return
	# pushing into a wall from the outer lane starts a wall run
	if player.lane == dir and _wall_at(dir) and wall_cd <= 0.0 and not player.is_grappling():
		_start_wall(dir)
		return
	player.move(dir)
	audio.play("click", 0.9 if dir < 0 else 1.1, -8.0)


func _on_slide() -> void:
	if player.is_tricking():
		return
	if player.wall_side != 0:
		player.press_slide()
	elif player.is_grappling():
		player.release_grapple(false)
	elif not player.grounded:
		_slam()
	else:
		player.press_slide()


# ============================================================ flow
func _enter_menu() -> void:
	_bank()
	get_tree().paused = false
	Engine.time_scale = 1.0
	state = State.MENU
	panel = ""
	stage.visible = true
	world.visible = false
	world.speed = MENU_SPEED
	world.theme = start_zone
	if events:
		events.reset()
		enemies.clear()
		player.grav_mult = 1.0
		audio.set_rate(1.0)
	world.reset(false)
	player.reset()
	cam.mode = CamScript.Mode.MENU
	audio.set_muffled(false)
	_clear_abilities()
	_snap_zone(start_zone)
	if player.char_idx != char_idx or (char_idx != 0 and player.rig == null):
		player.set_character(char_idx)
	player.set_props(true)
	hud.show_menu(prog.best, prog.wallet)
	hud.set_upgrade_summary(_upgrade_data())
	audio.play_song("menu")
	_show_char()
	_show_track()
	_show_lobby()


func _show_track() -> void:
	var vt: String = VEH_ZONE.get(start_zone, "")
	var hint: String = ("RIDE: " + VehScript.TYPE_NAME[vt]) if vt != "" else ""
	hud.set_track(ZONES[start_zone]["name"], start_zone, ZONES.size(), hint, ThemesScript.ACCENT[start_zone])


func _select_char(dir: int) -> void:
	if state != State.MENU:
		return
	char_idx = 1 + posmod(char_idx - 1 + dir, RigScript.count() - 1)
	var veh: String = player.vehicle
	var var_i: int = player.veh_variant
	player.reset()
	player.set_character(char_idx)
	player.set_props(panel == "")
	if panel == "garage" and veh != "":
		player.set_vehicle(veh, var_i)
	_show_char()
	_show_lobby()
	hud.flash(Color.WHITE, 0.2)
	audio.play("click", 1.2 + dir * 0.1)
	prog.char_idx = char_idx
	prog.save()


## Menu backdrop: each runner's own lobby (court, gym, bedroom, golf, rooftop);
## The garage uses the showroom stage.
func _show_lobby() -> void:
	var has: bool = state == State.MENU and panel != "garage" and lobby.show_for(char_idx)
	if not has:
		lobby.show_for(-1)
	stage.visible = state == State.MENU and not has
	if has:
		_set_weather("none", false)
		env.ssr_enabled = true
		var m: Array = LobbyScript.SKY[char_idx]
		sky_mat.sky_top_color = m[0]
		sky_mat.sky_horizon_color = m[1]
		sky_mat.ground_horizon_color = m[1]
		sun.light_color = m[2]
		sun.light_energy = m[3]
		env.ambient_light_energy = m[4]
	else:
		_snap_zone(start_zone)


func _show_char() -> void:
	var d: Dictionary = RigScript.CHARACTERS[char_idx]
	hud.set_character(d["name"], d["hobby"], char_idx - 1, RigScript.count() - 1)


func _select_track(dir: int) -> void:
	if state != State.MENU:
		return
	start_zone = posmod(start_zone + dir, ZONES.size())
	world.theme = start_zone
	world.reset(false)
	_snap_zone(start_zone)
	_show_track()
	_show_lobby()
	hud.flash(Color.WHITE, 0.3)
	audio.play("click", 1.0 + dir * 0.1)
	prog.track = start_zone
	prog.save()


func _snap_zone(idx: int) -> void:
	zone_idx = idx
	zone_t = 1.0
	zone_cur = ZONES[idx].duplicate()
	_apply_zone(zone_cur)
	_set_weather(ZONES[idx]["fx"], ZONES[idx]["wet"])


func _start_game() -> void:
	_bank()
	get_tree().paused = false
	Engine.time_scale = 1.0
	var from_menu := state == State.MENU
	panel = ""
	hud.show_panel("", {})
	speed = START_SPEED
	speed_target = CRUISE_SPEED
	speed_hold = 0.0
	distance = 0.0
	score = 0.0
	gold = 0
	banked = 0
	close_calls = 0
	grace = 0.0
	stumble_timer = 0.0
	portal_boost = 0.0
	coin_streak = 0
	last_km = 0
	flow = 0.0
	flow_tier = 0
	new_best = false
	revive_cost = 150
	revive_bridge_t = 0.0
	veh_granted_zone = -1
	skate_combo = 0
	tricking = false
	world.speed = speed
	world.difficulty = 0.0
	warp_t = 0.0
	zone_start = 0.0
	world.theme = start_zone
	world.reset(true)
	player.reset()
	_clear_abilities()
	style.reset()
	style.window = prog.frag_value("style_keep")
	events.reset()
	enemies.clear()
	enemy_t = randf_range(25.0, 40.0)
	run_frags = 0
	run_keys = 0
	run_artifacts.clear()
	run_missions.clear()
	run_rank = 0
	route = ""
	mission_t = 0.0
	head_start = prog.frag_value("start_boost")
	prog.start_run()
	player.grav_mult = 1.0
	player.air_control = prog.frag_value("air_control") / 100.0
	_apply_cosmetics()
	audio.set_muffled(false)
	cam.start_play()
	if not from_menu:
		cam.swoop = 0.0
	_snap_zone(start_zone)
	player.set_props(false)
	state = State.PLAYING
	stage.visible = false
	lobby.show_for(-1)
	env.ssr_enabled = false
	world.visible = true
	hud.show_game()
	hud.zone_banner(ZONES[start_zone]["name"], "TRACK  %d" % (start_zone + 1))
	hud.popup("GO!", CYAN, 70)
	audio.play("portal", 1.2, -6.0)
	_update_vehicle_zone(true)
	audio.play_zone(start_zone)
	if head_start > 0.0:
		grace = 3.0
		hud.popup("HEAD START!  %d m" % int(head_start), GOLD, 50)


func _set_paused(on: bool) -> void:
	if on and state == State.PLAYING:
		state = State.PAUSED
		get_tree().paused = true
		hud.show_pause(true)
		audio.play("click")
	elif not on and state == State.PAUSED:
		state = State.PLAYING
		get_tree().paused = false
		hud.show_pause(false)
		audio.play("click")


func _crash(title: String, from_fall := false) -> void:
	state = State.DEAD
	dead_timer = 0.0
	death_title = title
	if player.vehicle != "":
		fx.burst(player.position + Vector3(0, 0.6, 0), Color(1, 0.6, 0.3), 16, 9.0, 0.2, 0.7)
		player.set_vehicle("")
	player.die(from_fall)
	cam.mode = CamScript.Mode.DEAD
	cam.add_trauma(0.9 if not from_fall else 0.4)
	cam.kick(Vector3(0, 0.3, 1.5))
	audio.play("crash")
	audio.set_muffled(true)
	hud.flash(Color(1.0, 0.3, 0.5), 0.55)
	_clear_abilities()
	hud.set_markers([])
	hud.set_prompt("")
	var final := int(score)
	if final > prog.best:
		prog.best = final
		new_best = true
	enemies.clear()
	if events.current != "":
		events.reset()
	player.grav_mult = 1.0
	audio.set_rate(1.0)
	_mission("coins", gold, true)
	_mission("dist", int(distance), true)
	_mission("score", final, true)
	run_rank = prog.add_score(final, int(distance), RigScript.CHARACTERS[char_idx]["name"], ZONES[zone_idx]["name"])
	prog.stat_add("runs")
	prog.stat_add("dist", int(distance))
	_bank()


## Moves this run's coins into the saved wallet.
func _bank() -> void:
	if gold > banked:
		prog.wallet += gold - banked
		banked = gold
	prog.save()


func _show_game_over() -> void:
	hud.show_over({
		"title": death_title, "score": int(score), "distance": int(distance), "gold": gold,
		"close": close_calls, "best": prog.best, "new_best": new_best, "wallet": prog.wallet,
		"revive": prog.wallet >= revive_cost, "revive_cost": revive_cost,
		"rank": run_rank, "style": StyleScript.MULTS[style.best_tier], "frags": run_frags,
		"missions": run_missions.map(func(m): return m["text"]), "artifacts": run_artifacts,
	})


# ============================================================ menu panels (garage / upgrades)
func _open_panel(p: String) -> void:
	if state != State.MENU:
		return
	panel = p
	audio.play("click", 1.1)
	_show_lobby()
	if p == "garage":
		_garage_tab(garage_type)
	elif p == "upgrades":
		player.set_vehicle("")
		player.set_props(true)
		hud.show_panel("upgrades", _upgrade_data())
	elif p == "customize" or p == "records" or p == "settings":
		player.set_vehicle("")
		player.set_props(true)
		var d: Dictionary = _custom_data() if p == "customize" else (_records_data() if p == "records" else _settings_data())
		hud.show_panel(p, d)
	else:
		player.set_vehicle("")
		player.set_props(true)
		hud.show_panel("", {})
		hud.set_wallet(prog.wallet)


func _garage_tab(type: String) -> void:
	garage_type = type
	player.set_props(false)
	player.set_vehicle(type, garage_pick[type])
	hud.show_panel("garage", _garage_data())


func _garage_item(i: int) -> void:
	var t := garage_type
	garage_pick[t] = i
	if prog.is_owned(t, i):
		prog.equip(t, i)
		audio.play("ready", 1.2)
	elif prog.buy_vehicle(t, i):
		audio.play("orb", 1.0)
		hud.flash(GOLD, 0.25)
		hud.popup("UNLOCKED  " + VehScript.variant_name(t, i), GOLD, 40)
	else:
		audio.play("deny")
	player.set_vehicle(t, i)
	hud.show_panel("garage", _garage_data())
	hud.set_wallet(prog.wallet)


func _garage_data() -> Dictionary:
	var items := []
	for i in VehScript.variant_count(garage_type):
		items.append({"name": VehScript.variant_name(garage_type, i), "price": VehScript.price(garage_type, i),
			"owned": prog.is_owned(garage_type, i), "equipped": prog.equipped[garage_type] == i,
			"selected": garage_pick[garage_type] == i, "color": VehScript.swatch(garage_type, i)})
	return {"type": garage_type, "types": VehScript.TYPES, "type_names": VehScript.TYPE_NAME, "zones": VehScript.TYPE_ZONE,
		"items": items, "wallet": prog.wallet}


func _buy_upgrade(id: String) -> void:
	if prog.buy_upgrade(id):
		audio.play("orb", 1.2)
		hud.flash(GOLD, 0.2)
	else:
		audio.play("deny")
	hud.show_panel("upgrades", _upgrade_data())
	hud.set_upgrade_summary(_upgrade_data())
	hud.set_wallet(prog.wallet)


func _upgrade_data() -> Dictionary:
	var rows := []
	for u in ProgressScript.UPGRADES:
		var l: int = prog.level(u["id"])
		rows.append({"id": u["id"], "name": u["name"], "desc": u["desc"], "level": l, "max": ProgressScript.MAX_LEVEL,
			"cost": prog.upgrade_cost(u["id"]), "now": u["vals"][l], "next": u["vals"][mini(l + 1, ProgressScript.MAX_LEVEL)],
			"unit": u["unit"], "color": u["color"]})
	var frows := []
	for u in ProgressScript.FRAG_UPGRADES:
		var l: int = prog.frag_level(u["id"])
		frows.append({"id": u["id"], "name": u["name"], "desc": u["desc"], "level": l, "max": ProgressScript.MAX_LEVEL,
			"cost": prog.frag_cost(u["id"]), "now": u["vals"][l], "next": u["vals"][mini(l + 1, ProgressScript.MAX_LEVEL)],
			"unit": u["unit"], "color": u["color"]})
	return {"rows": rows, "frag_rows": frows, "fragments": prog.fragments, "wallet": prog.wallet}


# ============================================================ main loop
func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	if state == State.PAUSED:
		return

	var ph: float = audio.beat_phase()
	beat = pow(1.0 - fposmod(ph, 1.0), 4.0)
	RenderingServer.global_shader_parameter_set("beat", beat)

	match state:
		State.MENU:
			# every runner shows off on the showroom podium
			player.floor_y = 0.0
			player.tick(delta, 0.0, false)
			fx.tick(delta, 0.0)
			_animate_stage(delta)
		State.PLAYING:
			_play_step(delta)
		State.DEAD:
			dead_timer += delta
			player.tick(delta, 0.0, false)
			fx.tick(delta, 0.0)
			if dead_timer > 1.1 and not hud.is_over_visible():
				_show_game_over()

	_perf_governor(delta)
	_update_curve(delta)
	_update_zone(delta)
	world.update_fx(delta, beat)
	_spin_pickups(delta)
	player.curve = curve
	cam.update_cam(delta, player, _speed_factor(), _extra_fov(), curve, _cam_state())
	_update_visual_fx(delta)


func _play_step(delta: float) -> void:
	_tick_speed(delta)
	_tick_abilities(delta)
	var wmult := _speed_mult()
	var eff := speed * wmult
	var dz := eff * delta
	distance += dz
	score += dz * 0.5 * _score_mult()
	world.speed = speed
	world.difficulty = clampf((speed - START_SPEED) / (MAX_SPEED - START_SPEED), 0.0, 1.0)
	world.scroll(dz)
	fx.tick(delta, dz)
	grace = maxf(0.0, grace - delta)
	stumble_timer = maxf(0.0, stumble_timer - delta)
	portal_boost = maxf(0.0, portal_boost - delta)
	coin_streak_t -= delta
	if coin_streak_t <= 0.0:
		coin_streak = 0
	_tick_flow(delta)
	style.tick(delta)
	events.tick(delta)
	enemies.tick(delta, dz)
	_tick_enemy_spawns(delta)
	if head_start > 0.0:
		head_start -= dz
		grace = maxf(grace, 0.3)
		if head_start <= 0.0:
			hud.popup("GO GO GO!", CYAN, 44)
	mission_t -= delta
	if mission_t <= 0.0:
		mission_t = 0.5
		_mission("coins", gold, true)
		_mission("dist", int(distance), true)
		_mission("score", int(score), true)
	_tick_powers(delta)
	_tick_warp(delta)
	_update_traps(delta, dz / maxf(delta, 0.001))
	revive_bridge_t = maxf(0.0, revive_bridge_t - delta)
	_update_vehicle_zone(false)
	_move_drones(delta)
	_move_buses(delta)
	player.jump_mult = 1.3 if pw["springs"] > 0.0 else 1.0

	# wall run bookkeeping
	if wall_active:
		if player.wall_side == 0:
			wall_active = false
			wall_cd = WALL_CD
			grace = maxf(grace, 0.5)
		elif not _wall_at(player.wall_side, -2.0):
			player.end_wall(false)
		else:
			_add_flow(7.0 * delta)
			score += 40.0 * delta * _score_mult()
			grind_fx_t -= delta
			if grind_fx_t <= 0.0:
				grind_fx_t = 0.07
				fx.burst(Vector3(player.wall_side * 4.9, player.position.y + 0.1, 0.3), Color(0.85, 0.82, 0.9), 2, 3.0, 0.08, 0.3, 4.0)

	if player.is_sliding() and player.vehicle == "moto":
		# knee-down power-slide throws sparks off the bike
		grind_fx_t -= delta
		if grind_fx_t <= 0.0:
			grind_fx_t = 0.05
			fx.burst(player.position + Vector3(player.slide_side * 0.5, 0.1, 0.4), Color(1.0, 0.75, 0.3), 3, 5.0, 0.06, 0.25, 6.0)

	_compute_floor(delta)
	player.tick(delta, eff, true)
	if tricking and not player.is_tricking():
		_trick_landed()
	_update_grind(delta)
	if player.grounded:
		dashjump_carry = false
		skate_combo_t -= delta
		if skate_combo_t <= 0.0:
			skate_combo = 0
	if player.position.y < -4.0:
		_crash("FELL INTO THE GAP", true)
		return
	_check_objects(delta)
	if state != State.PLAYING:
		return
	_update_route()

	var km := int(distance / 1000.0)
	if km > last_km:
		last_km = km
		hud.popup("%d,000 M!" % km, CYAN, 56)
		audio.play("ready", 0.8)

	_update_hud_state()


func _update_hud_state() -> void:
	var grapple_target = _grapple_target()
	var qside := _qpipe_side()
	var any_wall := _wall_at(-1) or _wall_at(1)
	var air: bool = not player.grounded and player.wall_side == 0 and not player.is_grappling()
	var ab := []
	# Q: dash on the ground, air dash in the air
	var dash_cd: float = prog.value("dash")
	if air:
		ab.append({"ready": airdash_cd <= 0.0 and player.air_dash_ready, "cd_ratio": airdash_cd / AIRDASH_CD, "cd_left": airdash_cd,
			"active_ratio": player.air_dash_t / 0.28, "label": "AIR DASH"})
	else:
		ab.append({"ready": ab_cd[DASH] <= 0.0 and player.grounded, "cd_ratio": ab_cd[DASH] / dash_cd, "cd_left": ab_cd[DASH],
			"active_ratio": ab_active[DASH] / prog.frag_value("dash_power"), "label": "DASH"})
	# E: grapple / quarter-pipe / wall run, whatever is in reach
	var hook_label := "GRAPPLE"
	var hook_ready := false
	if player.is_grappling():
		hook_label = "GRAPPLE"
	elif grapple_target != null:
		hook_ready = ab_cd[HOOK] <= 0.0
	elif qside != 0:
		hook_label = "QUARTER PIPE"
		hook_ready = not player.is_tricking()
	elif any_wall:
		hook_label = "WALL RUN"
		hook_ready = wall_cd <= 0.0 and player.wall_side == 0
	ab.append({"ready": hook_ready, "cd_ratio": ab_cd[HOOK] / HOOK_CD, "cd_left": ab_cd[HOOK],
		"active_ratio": 1.0 if (player.is_grappling() or player.wall_side != 0 or player.is_tricking()) else 0.0, "label": hook_label})
	var sky_cd: float = prog.value("sky")
	ab.append({"ready": ab_cd[SKY] <= 0.0, "cd_ratio": ab_cd[SKY] / sky_cd, "cd_left": ab_cd[SKY], "active_ratio": 0.0, "label": "SKY JUMP"})

	var powers := []
	for id in ["magnet", "shield", "springs", "double"]:
		if pw[id] > 0.0:
			powers.append({"id": id, "name": POWER_NAME[id], "t": pw[id], "max": prog.value(id), "color": world.POWER_COL[id]})
	var veh = null
	var vt: String = VEH_ZONE.get(zone_idx, "")
	if player.vehicle != "":
		veh = {"type": player.vehicle, "name": VehScript.TYPE_NAME[player.vehicle] + "  ·  " + VehScript.variant_name(player.vehicle, player.veh_variant),
			"hits": veh_hits, "max": int(prog.value("armor")), "time": veh_time, "time_max": prog.value("ride")}

	var zprog := clampf((distance - zone_start) / ZONE_LEN, 0.0, 1.0)
	hud.update_hud({
		"score": int(score), "dist": int(distance), "mult": _score_mult(), "coins": gold,
		"kmh": int(speed * _speed_mult() * 9.0),
		"speed_ratio": clampf((speed * _speed_mult() - START_SPEED) / (MAX_SPEED - START_SPEED), 0.0, 1.0),
		"flow": flow, "flow_tier": flow_tier, "abilities": ab, "powers": powers, "vehicle": veh,
		"style_mult": style.mult(), "style_prog": style.progress(), "style_chain": style.chain_text(),
		"style_tier": style.tier, "event": (EventsScript.EVENTS[events.current]["name"] if events.current != "" else ""),
		"event_t": events.time_left(), "event_col": (EventsScript.EVENTS[events.current]["col"] if events.current != "" else Color.WHITE),
		"frags": run_frags, "keys": run_keys, "route": route,
		"zone": ZONES[zone_idx]["name"], "next_zone": ZONES[_next_zone()]["name"], "zone_prog": zprog,
		"accent": ThemesScript.ACCENT[zone_idx],
	})

	# world-space markers + context prompts
	var markers := []
	if grapple_target != null and not player.is_grappling():
		var bp: Vector3 = player.bend(grapple_target.position)
		if not cam.is_position_behind(bp):
			markers.append({"pos": cam.unproject_position(bp), "color": GREEN, "text": "E  GRAPPLE", "big": true})
	for h in world.holes:
		if not is_instance_valid(h) or player.vehicle == "hover":
			continue
		var hz: float = h.position.z
		if hz < -8.0 and hz > -75.0:
			var hp: Vector3 = player.bend(Vector3(0, 0.6, hz))
			if not cam.is_position_behind(hp):
				markers.append({"pos": cam.unproject_position(hp), "color": Color(1.0, 0.3, 0.2), "text": "GAP!  JUMP  ·  %d m" % int(-hz), "big": true})
			break
	for obj in world.objects.get_children():
		if obj.get_meta("kind") == "tunnel" and not obj.get_meta("hit") and obj.position.z > -90.0 and obj.position.z < -4.0:
			var tp: Vector3 = player.bend(obj.position + Vector3(0, 1.5, 0))
			if not cam.is_position_behind(tp):
				var tg: int = obj.get_meta("target")
				markers.append({"pos": cam.unproject_position(tp), "color": ThemesScript.ACCENT[tg], "text": "WARP TO  " + ZONES[tg]["name"], "big": true})
	markers.append_array(enemies.markers(cam))
	hud.set_markers(markers)
	var prompt := ""
	if player.wall_side != 0:
		prompt = "SPACE  wall-jump      A / D  drop off"
	elif player.is_grappling():
		prompt = "SPACE  release with boost"
	elif qside != 0 and not player.is_tricking():
		prompt = ("%s  swerve into the QUARTER PIPE   ·   or  E" % ("A" if qside < 0 else "D"))
	elif any_wall and wall_cd <= 0.0:
		prompt = "E  or push into the wall  -  WALL RUN"
	hud.set_prompt(prompt)


func _qpipe_side() -> int:
	if world.qpipe_at(-1) != null:
		return -1
	if world.qpipe_at(1) != null:
		return 1
	return 0


func _compute_floor(delta: float) -> void:
	var f := 0.0
	var px: float = player.position.x
	var py: float = player.position.y
	if player.vehicle != "hover":
		for h in world.holes:
			if not is_instance_valid(h):
				continue
			var near: float = h.position.z
			var far: float = near - float(h.get_meta("len", 8.0))
			if near - 0.25 > 0.0 and far + 0.25 < 0.0:
				f = -1000.0
	if f < -100.0 and revive_bridge_t > 0.0 and py > -0.3:
		f = 0.0
	on_rail = false
	var ramp := false
	for obj in world.objects.get_children():
		var kind: String = obj.get_meta("kind")
		if kind == "ramp":
			# bus ramp: the floor rises along its length
			var rb: AABB = obj.get_meta("box")
			var ro: Vector3 = obj.position
			if absf(px - ro.x) < 1.25 and 0.0 < ro.z + rb.end.z and 0.0 > ro.z + rb.position.z:
				var k := clampf((ro.z + rb.end.z) / rb.size.z, 0.0, 1.0)
				var rh := rb.size.y * k
				if rh >= f:
					f = rh
					ramp = true
			continue
		if not kind in WorldScript.SOLID:
			continue
		var box: AABB = obj.get_meta("box")
		var o: Vector3 = obj.position
		if px > o.x + box.position.x - 0.35 and px < o.x + box.end.x + 0.35 \
				and 0.0 > o.z + box.position.z - 0.35 and 0.0 < o.z + box.end.z + 0.35:
			var top := o.y + box.end.y
			if py >= top - 0.45 and top >= f:
				f = top
				on_rail = kind == "rail"
				ramp = false
	player.floor_y = f
	player.floor_snap = ramp


## Oncoming buses drive at you; one stops if something else is in its way.
func _move_buses(delta: float) -> void:
	var objs: Array = world.objects.get_children()
	for b in objs:
		if b.get_meta("kind") != "bus" or float(b.get_meta("move", 0.0)) <= 0.0 or b.position.z < -140.0:
			continue
		var front: float = b.position.z + (b.get_meta("box") as AABB).end.z
		for o in objs:
			if o != b and absf(o.position.x - b.position.x) < 1.0 and o.position.z > front - 1.0 and o.position.z < front + 8.0 \
					and o.get_meta("kind") in ["car", "speaker", "crate", "bus", "jump", "slide", "pop_wall", "pop_spikes", "drop", "rail"]:
				b.set_meta("move", 0.0)
				break
		b.position.z += float(b.get_meta("move", 0.0)) * delta


func _move_drones(wdelta: float) -> void:
	for obj in world.objects.get_children():
		if obj.get_meta("kind") != "drone" or obj.position.z < -90.0:
			continue
		var t: float = obj.get_meta("t") + wdelta
		obj.set_meta("t", t)
		obj.position.x = float(obj.get_meta("cx", obj.position.x)) + sin(float(obj.get_meta("ph")) + t * 1.7) * float(obj.get_meta("amp", 0.0))


func _check_objects(delta: float) -> void:
	var pbox: AABB = player.get_hitbox()
	var pc: Vector3 = player.position + Vector3(0, 0.9, 0)
	var magnet: bool = pw["magnet"] > 0.0
	for obj in world.objects.get_children():
		if obj.is_queued_for_deletion():
			continue
		var kind: String = obj.get_meta("kind")
		if kind == "coin":
			if magnet and obj.position.z > -28.0 and obj.position.z < 4.0 and absf(obj.position.x - pc.x) < 9.0:
				obj.position = obj.position.move_toward(pc, (40.0 + speed) * delta)
			if obj.position.distance_to(pc) < 1.3:
				_collect_coin(obj)
		elif kind == "power":
			if obj.position.distance_to(pc) < 1.6:
				_gain_power(obj)
		elif kind == "vehicle":
			if obj.position.distance_to(pc) < 1.8:
				_gain_vehicle(obj)
		elif kind == "pickup":
			if magnet and obj.get_meta("ctype") != "artifact" and obj.position.z > -20.0 and obj.position.z < 4.0 and absf(obj.position.x - pc.x) < 7.0:
				obj.position = obj.position.move_toward(pc, (30.0 + speed) * delta)
			if obj.position.distance_to(pc) < 1.5:
				_gain_pickup(obj)
		elif kind == "shortcut":
			if not obj.get_meta("hit") and obj.position.z > -0.5:
				obj.set_meta("hit", true)
				if absf(obj.position.x - player.position.x) < 1.4 and player.position.y < 3.0:
					_shortcut()
		elif kind == "portal":
			if not obj.get_meta("hit") and obj.position.z > 0.0:
				obj.set_meta("hit", true)
				_portal()
		elif kind == "tunnel":
			if not obj.get_meta("hit") and obj.position.z > -0.5:
				obj.set_meta("hit", true)
				if absf(obj.position.x - player.position.x) < 1.4 and player.position.y < 3.0:
					_warp(obj.get_meta("target"))
		elif kind == "kicker":
			if not obj.get_meta("hit") and obj.position.z > -1.2 and absf(obj.position.x - player.position.x) < 1.2 \
					and player.position.y < 0.6:
				obj.set_meta("hit", true)
				_kicker()
		elif kind == "pad":
			if not obj.get_meta("hit") and obj.position.z > -1.0 and absf(obj.position.x - player.position.x) < 1.3 \
					and player.position.y < 0.6:
				obj.set_meta("hit", true)
				_boost_pad()
		elif kind in ["jump", "slide", "car", "speaker", "crate", "drone", "rail", "pop_wall", "pop_spikes", "drop", "bus"]:
			var box: AABB = obj.get_meta("box")
			var wb := AABB(box.position + obj.position, box.size)
			if not obj.get_meta("passed", false) and wb.position.z > 0.6:
				obj.set_meta("passed", true)
				_check_close_call(obj)
			if wb.intersects(pbox):
				var on_top: bool = kind in WorldScript.SOLID and player.position.y >= wb.end.y - 0.45
				if not on_top and kind == "bus" and float(obj.get_meta("move", 0.0)) <= 0.0 \
						and wb.end.z < 1.2 and player.position.y >= wb.end.y - 1.8:
					# a jump that reaches the back of a parked bus climbs onto its roof
					player.mantle(wb.end.y)
					audio.play("land", 1.1, -4.0)
					on_top = true
				if not on_top:
					_on_hit(obj, kind)
					if state != State.PLAYING:
						return


func _collect_coin(obj: Node3D) -> void:
	var v: int = (2 if pw["double"] > 0.0 else 1) * int(obj.get_meta("value", 1)) * events.reward_mult()
	gold += v
	coin_streak += 1
	coin_streak_t = 0.6
	score += 10.0 * _score_mult()
	_add_flow(1.2)
	fx.sparkle(obj.position, GOLD)
	audio.play("coin", 1.0 + minf(coin_streak, 12) * 0.025, -3.0)
	hud.gold_pop()
	obj.queue_free()


func _gain_power(obj: Node3D) -> void:
	var t: String = obj.get_meta("ptype")
	var c: Color = world.POWER_COL[t]
	fx.burst(obj.position, c, 16, 8.0, 0.2, 0.5, 0.0)
	fx.ring(obj.position, c, 3.5, 0.4)
	audio.play("orb")
	obj.queue_free()
	_add_flow(8.0)
	cam.punch_fov(4.0)
	pw[t] = prog.value(t)
	hud.popup("%s  %ds" % [POWER_NAME[t], int(pw[t])], c, 40)
	match t:
		"springs":
			audio.play("djump", 1.3)
			hud.flash(Color(0.4, 1.0, 0.6), 0.2)
		"shield":
			audio.play("shield")
		"magnet":
			audio.play("magnet")
	_update_power_visuals()


func _tick_powers(delta: float) -> void:
	for id in pw:
		if pw[id] > 0.0:
			pw[id] = maxf(0.0, pw[id] - delta)
			if pw[id] == 0.0:
				hud.popup(POWER_NAME[id] + "  OVER", Color(0.8, 0.78, 0.9), 28)
				audio.play("powerdown", 1.0, -6.0)
				_update_power_visuals()


func _update_power_visuals() -> void:
	var list := []
	for id in ["magnet", "springs", "double"]:
		if pw[id] > 0.0:
			list.append(id)
	player.set_cores(list)
	player.set_shield(pw["shield"] > 0.0)


func _check_close_call(obj: Node3D) -> void:
	if player.lane_change_time < 0.5 and player.prev_lane != player.lane \
			and absf(obj.position.x - player.prev_lane * LANE_WIDTH) < 0.3:
		close_calls += 1
		var pts := 50 * _score_mult()
		score += pts
		_add_flow(12.0, "close")
		hud.popup("CLOSE CALL!  +%d" % pts, CYAN, 42)
		audio.play("close")
		cam.punch_fov(5.0)


func _portal() -> void:
	var pts := 250 * _score_mult()
	score += pts
	_add_flow(20.0, "boost")
	portal_boost = 1.6
	cam.punch_fov(14.0)
	cam.kick(Vector3(0, 0, 1.4))
	cam.add_trauma(0.2)
	hud.flash(CYAN, 0.35)
	hud.popup("PORTAL BOOST  +%d" % pts, CYAN, 48)
	audio.play("portal")
	fx.ring(Vector3(0, 2.2, -1.0), CYAN, 7.0, 0.6)


func _boost_pad() -> void:
	portal_boost = 1.2
	_add_flow(10.0, "boost")
	cam.punch_fov(10.0)
	cam.kick(Vector3(0, 0, 1.0))
	audio.play("portal", 1.5, -4.0)
	hud.popup("BOOST!", CYAN, 40)
	fx.burst(player.position, CYAN, 10, 6.0, 0.15, 0.4, 0.0)


func _on_hit(obj: Node3D, kind: String) -> void:
	if grace > 0.0 or player.is_grappling() or player.wall_side != 0 or player.is_tricking():
		return
	var breaking: bool = kind in WorldScript.WEAK and (player.dash_t > 0.0 or player.air_dash_t > 0.0 or player.slamming)
	if breaking:
		world.smash(obj, fx)
		_hitstop(0.05)
		cam.add_trauma(0.3)
		cam.kick(Vector3(0, 0, -0.5))
		audio.play("smash", randf_range(0.9, 1.1))
		_mission("smash", 1)
		var pts := 30 * _score_mult()
		score += pts
		_add_flow(8.0, "smash")
		hud.popup("SMASH!  +%d" % pts, PINK, 40)
		return
	style.broken()
	if pw["shield"] > 0.0:
		world.smash(obj, fx)
		grace = 0.3
		_hitstop(0.05)
		cam.add_trauma(0.4)
		hud.flash(CYAN, 0.25)
		hud.popup("SHIELD!", CYAN, 40)
		audio.play("shield_break")
		return
	if player.vehicle != "":
		world.smash(obj, fx)
		grace = 1.2
		_hitstop(0.08)
		cam.add_trauma(0.5)
		veh_hits -= 1
		if veh_hits <= 0:
			fx.burst(player.position + Vector3(0, 0.6, 0), Color(1, 0.6, 0.3), 18, 9.0, 0.2, 0.7)
			var nm: String = VehScript.TYPE_NAME[player.vehicle]
			player.set_vehicle("")
			hud.flash(Color(1, 0.5, 0.3), 0.35)
			hud.popup(nm + " WRECKED  -  YOU'RE OK!", Color(1, 0.6, 0.35), 40)
		else:
			hud.flash(Color(1, 0.6, 0.3), 0.25)
			hud.popup("ARMOR HIT  ·  %d LEFT" % veh_hits, Color(1, 0.7, 0.4), 38)
		audio.play("shield_break", 0.8)
		return
	var side: bool = absf(player.position.x - obj.position.x) > 0.8 and player.prev_lane != player.lane \
			and player.lane_change_time < 0.6 and player.wall_side == 0
	if side and stumble_timer <= 0.0:
		player.bounce_back()
		stumble_timer = 5.0
		grace = 0.5
		cam.add_trauma(0.45)
		cam.kick_roll(0.2)
		hud.flash(Color(1.0, 0.2, 0.3), 0.25)
		hud.popup("STUMBLE!  THE ENFORCER IS ON YOU", Color(1.0, 0.45, 0.45), 38)
		audio.play("stumble")
		flow *= 0.5
		enemies.stumble()
		return
	# bounce back off the obstacle so the fall never clips into it
	var box: AABB = obj.get_meta("box")
	var front: float = obj.position.z + box.end.z
	if front > -1.6:
		world.scroll(-(front + 1.6))
		fx.tick(0.0, -(front + 1.6))
	_crash("CAUGHT BY THE ENFORCER" if enemies.is_chasing() else "WIPED OUT")


# ============================================================ abilities
func _use_dash() -> void:
	if state != State.PLAYING or player.is_tricking():
		return
	var p: Vector3 = player.position
	if player.grounded and player.wall_side == 0 and not player.is_grappling():
		if ab_cd[DASH] > 0.0 or ab_active[DASH] > 0.0:
			_deny(DASH, "")
			return
		hud.slot_used(DASH)
		var dd: float = prog.frag_value("dash_power")
		ab_active[DASH] = dd
		player.dash_t = dd
		cam.kick(Vector3(0, 0, 1.3))
		cam.punch_fov(12.0)
		cam.add_trauma(0.15)
		fx.ring(p + Vector3(0, 1.0, 0.5), PINK, 3.0, 0.35, 20.0)
		audio.play("dash")
		_add_flow(4.0, "dash")
		return
	# air dash
	if player.wall_side != 0 or player.is_grappling() or not player.air_dash_ready or airdash_cd > 0.0:
		_deny(DASH, "")
		return
	hud.slot_used(DASH)
	var dir := int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left"))
	player.air_dash(dir)
	airdash_cd = AIRDASH_CD
	if dir == 0:
		cam.punch_fov(11.0)
		cam.kick(Vector3(0, 0.15, 1.2))
	else:
		cam.punch_fov(5.0)
		cam.kick(Vector3(dir * 0.7, 0.1, 0.2))
		cam.kick_roll(-dir * 0.4)
	fx.ring(p + Vector3(0, 1.0, 0.0), Color(1, 0.6, 0.9), 2.5, 0.3, 10.0)
	fx.burst(p + Vector3(0, 1.0, 0), PINK, 8, 5.0, 0.12, 0.3, 0.0)
	audio.play("airdash")
	_add_flow(6.0, "airdash")


## E: whatever is in reach - grapple anchor, quarter-pipe, or a wall to run on.
func _use_hook() -> void:
	if state != State.PLAYING or player.is_tricking() or player.is_grappling():
		return
	var target = _grapple_target()
	if target != null:
		if ab_cd[HOOK] > 0.0:
			_deny(HOOK, "")
			return
		hud.slot_used(HOOK)
		player.start_grapple(target)
		target.set_meta("used", true)
		grapple_active = true
		cam.punch_fov(8.0)
		cam.kick(Vector3(0, 0.4, 0.4))
		fx.burst(target.position, GREEN, 12, 6.0, 0.15, 0.4, 0.0)
		audio.play("grapple")
		hud.popup("GRAPPLE!", GREEN, 42)
		_mission("grapple", 1)
		_add_flow(12.0, "grapple")
		return
	var qs := _qpipe_side()
	if qs != 0:
		hud.slot_used(HOOK)
		_start_trick(qs)
		return
	if player.wall_side == 0 and wall_cd <= 0.0:
		var side := 0
		if player.lane != 0 and _wall_at(player.lane):
			side = player.lane
		elif _wall_at(-1):
			side = -1
		elif _wall_at(1):
			side = 1
		if side != 0:
			hud.slot_used(HOOK)
			_start_wall(side)
			return
	_deny(HOOK, "NOTHING TO HOOK  -  LOOK FOR GREEN ANCHORS")


func _start_wall(side: int) -> void:
	player.start_wall(side)
	wall_active = true
	cam.kick(Vector3(-side * 0.6, 0.2, 0))
	cam.punch_fov(6.0)
	audio.play("wall")
	hud.popup("WALL RUN!", Color(0.45, 0.7, 1.0), 42)
	_mission("wall", 1)
	_add_flow(10.0, "wall")


func _start_trick(side: int) -> void:
	player.start_trick(side)
	tricking = true
	grace = maxf(grace, 0.3)
	cam.punch_fov(10.0)
	cam.kick(Vector3(side * 0.5, 0.5, 0.6))
	audio.play("wall", 1.2)
	audio.play("djump", 0.9)
	hud.popup("QUARTER PIPE!", Color(0.4, 0.8, 1.0), 44)
	_add_flow(10.0)


func _trick_landed() -> void:
	tricking = false
	grace = maxf(grace, 0.7)
	# landing shockwave keeps the middle lane clear
	for obj in world.objects.get_children():
		if obj.is_queued_for_deletion():
			continue
		var kind: String = obj.get_meta("kind")
		if kind in ["jump", "slide", "car", "speaker", "crate", "drone", "pop_wall", "pop_spikes", "drop", "bus"] \
				and obj.position.z > -10.0 and obj.position.z < 3.0 and absf(obj.position.x) < 1.6:
			world.smash(obj, fx)
	var pts := (500 if player.boarding else 250) * _score_mult()
	score += pts
	_add_flow(20.0, "qpipe")
	hud.popup(("360 AIR!  +%d" if player.boarding else "WALL FLIP!  +%d") % pts, Color(1, 0.8, 0.3), 48)
	fx.ring(player.position + Vector3(0, 0.2, 0), Color(0.4, 0.8, 1.0), 5.0, 0.4, 0.0, true)
	fx.burst(player.position, Color(1, 0.8, 0.3), 14, 7.0, 0.16, 0.45, 0.0)
	cam.add_trauma(0.3)
	cam.kick(Vector3(0, -0.4, 0))
	audio.play("land", 0.9)


func _slam() -> void:
	if player.grounded or player.wall_side != 0 or player.is_grappling():
		return
	if slam_cd > 0.0:
		player.slam(false)
		return
	player.slam(true)
	slam_cd = SLAM_CD
	audio.play("dash", 0.55)
	cam.punch_fov(-6.0)
	cam.kick(Vector3(0, 0.7, 0))


func _deny(i: int, msg: String) -> void:
	hud.slot_deny(i)
	audio.play("deny")
	if msg != "":
		hud.popup(msg, Color(0.8, 0.75, 0.9), 26)


func _tick_abilities(delta: float) -> void:
	if ab_active[DASH] > 0.0:
		ab_active[DASH] -= delta
		if ab_active[DASH] <= 0.0:
			ab_active[DASH] = 0.0
			grace = maxf(grace, 0.1)
			ab_cd[DASH] = prog.value("dash")
	for i in 3:
		if ab_active[i] > 0.0:
			continue
		if i == HOOK and grapple_active:
			continue
		if ab_cd[i] > 0.0:
			ab_cd[i] = maxf(0.0, ab_cd[i] - delta)
			if ab_cd[i] <= 0.0:
				audio.play("ready", 1.0, -10.0)
	airdash_cd = maxf(0.0, airdash_cd - delta)
	slam_cd = maxf(0.0, slam_cd - delta)
	if not wall_active:
		wall_cd = maxf(0.0, wall_cd - delta)


func _clear_abilities() -> void:
	for i in 3:
		ab_cd[i] = 0.0
		ab_active[i] = 0.0
	airdash_cd = 0.0
	wall_cd = 0.0
	slam_cd = 0.0
	for id in pw:
		pw[id] = 0.0
	wall_active = false
	grapple_active = false
	dashjump_carry = false
	tricking = false
	audio.set_warp(false)
	player.set_phase_visual(false)
	player.set_aura(false)
	_update_power_visuals()


func _wall_at(side: int, margin := -3.0) -> bool:
	for obj in world.objects.get_children():
		if obj.get_meta("kind") != "wall" or int(obj.get_meta("side")) != side:
			continue
		var half: float = obj.get_meta("half")
		if obj.position.z + half > 1.0 and obj.position.z - half < margin:
			return true
	return false


func _grapple_target():
	var best = null
	var best_z := -999.0
	for obj in world.objects.get_children():
		if obj.get_meta("kind") != "anchor" or obj.get_meta("used"):
			continue
		var z: float = obj.position.z
		if z > -prog.frag_value("grapple_range") and z < -3.0 and z > best_z:
			best = obj
			best_z = z
	return best


func _on_grapple_released() -> void:
	grapple_active = false
	grace = maxf(grace, 0.45)
	ab_cd[HOOK] = HOOK_CD
	cam.punch_fov(10.0)
	cam.kick(Vector3(0, -0.4, 0.9))
	fx.ring(player.position + Vector3(0, 1.0, 0), GREEN, 3.0, 0.35)
	audio.play("djump", 1.2)
	_add_flow(8.0, "release")


func _slam_impact() -> void:
	var n := 0
	var p: Vector3 = player.position
	for obj in world.objects.get_children():
		if obj.is_queued_for_deletion():
			continue
		if obj.get_meta("kind") in WorldScript.WEAK and obj.position.z > -10.0 and obj.position.z < 3.0 \
				and absf(obj.position.x - p.x) < 4.0 and absf(obj.position.y - p.y) < 3.0:
			world.smash(obj, fx)
			n += 1
	player.launch(15.0 + mini(n, 3) * 1.5)
	cam.add_trauma(0.75)
	cam.kick(Vector3(0, -1.1, 0))
	cam.punch_fov(12.0)
	_hitstop(0.09)
	fx.ring(p + Vector3(0, 0.2, 0), GOLD, 7.0, 0.5, 0.0, true)
	fx.ring(p + Vector3(0, 0.2, 0), Color.WHITE, 4.0, 0.35, 0.0, true)
	fx.burst(p + Vector3(0, 0.3, 0), GOLD, 16, 9.0, 0.18, 0.5)
	hud.flash(GOLD, 0.3)
	audio.play("shock")
	if n > 0:
		_mission("smash", n)
		var pts := n * 40 * _score_mult()
		score += pts
		_add_flow(10.0 * n, "slam")
		hud.popup("SLAM x%d  +%d" % [n, pts], GOLD, 44)
	else:
		_add_flow(4.0, "slam")


# ============================================================ vehicles
## Vehicles are timed arcade rides: entering a vehicle map gives you your
## garage ride once; it lasts RIDE TIME seconds (upgradable) or until it is
## wrecked. Ride tokens on the track refill it / put you back on.
func _update_vehicle_zone(instant: bool) -> void:
	var want: String = VEH_ZONE.get(zone_idx, "")
	if want == "":
		if player.vehicle != "":
			_dismount("ON FOOT")
		veh_granted_zone = -1
		return
	if player.vehicle != "":
		veh_time -= get_process_delta_time()
		if veh_time <= 0.0:
			_dismount("RIDE OVER  -  grab a ride token!")
		return
	if veh_granted_zone != zone_idx and _can_mount():
		veh_granted_zone = zone_idx
		_mount(want, instant)


func _can_mount() -> bool:
	return not (player.is_grappling() or player.wall_side != 0 or player.is_tricking())


func _mount(type: String, instant := false) -> void:
	var variant: int = prog.equipped[type]
	player.set_vehicle(type, variant)
	veh_hits = int(prog.value("armor"))
	veh_time = prog.value("ride")
	skate_combo = 0
	fx.burst(player.position + Vector3(0, 0.6, 0), ThemesScript.ACCENT[zone_idx], 16, 7.0, 0.16, 0.5, 0.0)
	fx.ring(player.position + Vector3(0, 0.3, 0), ThemesScript.ACCENT[zone_idx], 3.0, 0.4, 0.0, true)
	if not instant:
		cam.punch_fov(8.0)
	audio.play("hover" if type == "hover" else "engine", 1.0, -3.0)
	hud.popup("%s  ·  %s" % [VehScript.TYPE_NAME[type], VehScript.variant_name(type, variant)], ThemesScript.ACCENT[zone_idx], 40)


func _dismount(msg: String) -> void:
	fx.burst(player.position + Vector3(0, 0.6, 0), Color(0.8, 0.9, 1.0), 12, 6.0, 0.15, 0.4, 0.0)
	player.set_vehicle("")
	hud.popup(msg, Color(0.85, 0.85, 1.0), 30)


func _gain_vehicle(obj: Node3D) -> void:
	var t: String = obj.get_meta("vtype")
	obj.queue_free()
	fx.burst(obj.position, ThemesScript.ACCENT[zone_idx], 14, 7.0, 0.16, 0.5, 0.0)
	if player.vehicle == t:
		veh_time = prog.value("ride")
		veh_hits = int(prog.value("armor"))
		audio.play("orb", 1.2)
		hud.popup("RIDE REFILLED  ·  %ds" % int(veh_time), ThemesScript.ACCENT[zone_idx], 36)
	elif _can_mount():
		_mount(t)


## Skateboard tricks on every jump: named trick + combo multiplier.
func _skate_trick() -> void:
	skate_combo += 1
	skate_combo_t = 2.5
	var pts: int = 40 * skate_combo * _score_mult()
	score += pts
	_add_flow(6.0 + skate_combo, "trick")
	audio.play("trick", randf_range(0.95, 1.1), -2.0)
	var txt: String = player.board_trick
	if skate_combo > 1:
		txt += "   x%d COMBO" % skate_combo
	hud.popup("%s  +%d" % [txt, pts], Color(1.0, 0.55, 0.85), 38 + mini(skate_combo, 5) * 2)


# ============================================================ skate park + traps
func _kicker() -> void:
	var big: bool = player.vehicle != ""
	player.launch(23.0 if big else 19.0)
	cam.kick(Vector3(0, 0.6, 0.8))
	cam.punch_fov(10.0)
	audio.play("djump", 0.9)
	var pts := (150 if big else 60) * _score_mult()
	score += pts
	_add_flow(14.0 if big else 8.0, "kicker")
	hud.popup(("KICKFLIP!  +%d" if player.boarding else ("BIG AIR!  +%d" if big else "AIR!  +%d")) % pts, Color(1, 0.8, 0.3), 42)
	fx.burst(player.position, Color(1, 0.8, 0.3), 12, 6.0, 0.15, 0.4, 0.0)


func _update_grind(delta: float) -> void:
	var grinding_now: bool = on_rail and player.grounded
	if grinding_now and not player.grinding and grind_t == 0.0:
		hud.popup("GRIND!" if player.boarding else "RAIL RUN!", CYAN, 40)
		_style_move("grind")
		cam.kick(Vector3(0, -0.2, 0))
	player.grinding = grinding_now and player.boarding
	if not grinding_now:
		grind_t = 0.0
		return
	grind_t += delta
	score += (90.0 if player.boarding else 30.0) * delta * _score_mult()
	_add_flow((12.0 if player.boarding else 5.0) * delta)
	grind_fx_t -= delta
	if grind_fx_t <= 0.0:
		grind_fx_t = 0.05
		fx.burst(player.position + Vector3(0, 0.1, 0.2), Color(1.0, 0.8, 0.3), 3, 6.0, 0.07, 0.25, 12.0)
		if int(grind_t * 20.0) % 6 == 0:
			audio.play("grind", randf_range(0.95, 1.05), -8.0)


func _update_traps(delta: float, world_speed: float) -> void:
	var trigger_z := -maxf(24.0, world_speed * 1.1)
	for obj in world.objects.get_children():
		var kind: String = obj.get_meta("kind")
		if kind != "pop_wall" and kind != "pop_spikes" and kind != "drop":
			continue
		if not obj.get_meta("trig"):
			if obj.position.z > trigger_z:
				obj.set_meta("trig", true)
				audio.play("grapple", 0.55 if kind == "drop" else 0.8, -2.0)
			continue
		if obj.position.y != 0.0:
			var rate := 34.0 if kind == "drop" else 16.0
			obj.position.y = move_toward(obj.position.y, 0.0, rate * delta)
			if obj.position.y == 0.0:
				fx.burst(obj.position + Vector3(0, 0.2, 0), Color(0.9, 0.85, 0.8), 8, 5.0, 0.15, 0.4)
				if obj.position.z > -15.0:
					cam.add_trauma(0.15)


func _revive() -> void:
	if state != State.DEAD or prog.wallet < revive_cost:
		return
	prog.wallet -= revive_cost
	prog.save()
	revive_cost *= 2
	for obj in world.objects.get_children():
		var kind: String = obj.get_meta("kind")
		if kind in ["jump", "slide", "car", "speaker", "crate", "drone", "rail", "pop_wall", "pop_spikes", "drop", "bus"] \
				and obj.position.z > -45.0:
			world.smash(obj, fx)
	Engine.time_scale = 1.0
	player.revive()
	style.reset()
	revive_bridge_t = 2.5
	grace = 2.5
	state = State.PLAYING
	cam.mode = CamScript.Mode.PLAY
	audio.set_muffled(false)
	hud.show_game()
	hud.flash(Color(1, 0.85, 0.4), 0.6)
	hud.popup("REVIVED!", GOLD, 60)
	audio.play("overdrive")


# ============================================================ flow meter
func _add_flow(v: float, kind := "") -> void:
	flow = minf(100.0, flow + v)
	flow_idle = 0.0
	if kind != "":
		_style_move(kind)


## STYLE chain: every move adds style points; variety climbs the multiplier.
func _style_move(kind: String) -> void:
	if state != State.PLAYING:
		return
	var up: int = style.move(kind)
	if up > 0:
		var nm: String = StyleScript.NAMES[up]
		var col: Color = [Color.WHITE, CYAN, Color(0.6, 1.0, 0.5), Color(1.0, 0.55, 0.2), Color(1.0, 0.3, 0.8)][up]
		hud.popup("%s!   STYLE x%d" % [nm, style.mult()], col, 44 + up * 4)
		audio.play("ready", 1.2 + up * 0.1)
		cam.punch_fov(4.0 + up)
		if up >= 3:
			hud.flash(col, 0.2)
		_mission("style", style.mult(), true)


func _tick_flow(delta: float) -> void:
	flow_idle += delta
	if flow_idle > 1.8:
		flow = maxf(0.0, flow - 9.0 * delta)
	var tier := 0
	if flow >= 70.0:
		tier = 2
	elif flow >= 35.0:
		tier = 1
	flow_tier = tier


func _speed_mult() -> float:
	var m := 1.0
	if ab_active[DASH] > 0.0:
		m *= 1.9
	if player.air_dash_t > 0.0 and player.air_dash_dir == 0:
		m *= 1.6
	if dashjump_carry:
		m *= 1.3
	if portal_boost > 0.0:
		m *= 1.25
	if warp_t > 0.0:
		m *= 1.8
	if player.vehicle != "":
		m *= VEH_SPEED[player.vehicle]
	if events:
		m *= events.speed_mult()
	if route == "high":
		m *= 1.2
	elif route == "under":
		m *= 0.88
	if head_start > 0.0:
		m *= 2.2
	return m


func _score_mult() -> int:
	var m: int = (1 + mini(5, int(distance / 600.0))) * (style.mult() if style else 1)
	if pw["double"] > 0.0:
		m *= 2
	if events:
		m *= events.reward_mult()
	return m


func _speed_factor() -> float:
	if state != State.PLAYING:
		return 0.0
	return clampf((speed * _speed_mult() - START_SPEED) / (MAX_SPEED - START_SPEED), 0.0, 1.4)


func _extra_fov() -> float:
	var f := 0.0
	if state == State.PLAYING:
		if ab_active[DASH] > 0.0:
			f += 14.0
		if portal_boost > 0.0:
			f += 6.0
		if warp_t > 0.0:
			f += 22.0 * warp_t
		if player.wall_side != 0:
			f += 7.0
		if player.is_grappling():
			f += 10.0
		if player.is_tricking():
			f += 8.0
		f += flow * 0.06
	return f


func _cam_state() -> Dictionary:
	var gp = null
	if player.is_grappling():
		gp = player.bend(player.anchor.position)
	return {
		"wall": player.wall_side,
		"grapple": gp,
		"slam": player.slamming and player.vy < 0.0,
		"shift": false,
		"phase": false,
		"flow": flow / 100.0,
		"air": not player.grounded,
		"trick": player.trick_side if player.is_tricking() else 0,
		"floor": player.floor_y,
	}


## Impacts used to freeze time for a moment; now they only shake the camera.
func _hitstop(d: float) -> void:
	cam.add_trauma(d * 1.5)


# ============================================================ visuals
func _update_curve(delta: float) -> void:
	curve_timer -= delta
	if curve_timer <= 0.0:
		curve_timer = randf_range(6.0, 11.0)
		curve_target = Vector2(randf_range(-0.0017, 0.0017), randf_range(-0.001, 0.0004))
	curve = curve.lerp(curve_target, 1.0 - exp(-0.35 * delta))
	RenderingServer.global_shader_parameter_set("curve_amount", curve)


func _next_zone() -> int:
	return (zone_idx + 1) % ZONES.size()


var _was_dark := 0.0


func _update_zone(delta: float) -> void:
	if planet:
		planet.visible = zone_idx == 0 and state != State.MENU
	if events and (events.dark > 0.0 or _was_dark > 0.0) and zone_t >= 1.0:
		_apply_zone(zone_cur)
	_was_dark = events.dark if events else 0.0
	if state == State.PLAYING:
		# the world spawns scenery ~215 m ahead, so switch its theme early
		world.theme = _next_zone() if distance + ZONE_LOOKAHEAD >= zone_start + ZONE_LEN else zone_idx
		if distance >= zone_start + ZONE_LEN:
			zone_start += ZONE_LEN
			_begin_zone(_next_zone(), true)
	if zone_t < 1.0:
		zone_t = minf(1.0, zone_t + delta / 3.0)
		var e := zone_t * zone_t * (3.0 - 2.0 * zone_t)
		var to: Dictionary = ZONES[zone_idx]
		for k in to:
			if to[k] is Color:
				zone_cur[k] = (zone_from[k] as Color).lerp(to[k], e)
			elif to[k] is float:
				zone_cur[k] = lerpf(zone_from[k], to[k], e)
		_apply_zone(zone_cur)


func _begin_zone(idx: int, announce: bool) -> void:
	zone_from = zone_cur.duplicate()
	zone_idx = idx
	zone_t = 0.0
	_set_weather(ZONES[idx]["fx"], ZONES[idx]["wet"])
	audio.play_zone(idx)
	if announce:
		var vt: String = VEH_ZONE.get(idx, "")
		hud.zone_banner(ZONES[idx]["name"], ("TRACK  %d" % (idx + 1)) + (("   ·   " + VehScript.TYPE_NAME[vt] + " ZONE") if vt != "" else ""))
		audio.play("portal", 0.7)
		hud.flash(Color.WHITE, 0.25)
		cam.punch_fov(10.0)


func _warp(target: int) -> void:
	warp_t = 1.0
	warp_target = target
	warped = false
	grace = 2.5
	cam.punch_fov(28.0)
	cam.kick(Vector3(0, 0, 2.0))
	cam.add_trauma(0.35)
	audio.play("portal", 0.6)
	audio.play("dash", 0.5)
	_add_flow(25.0, "boost")


func _tick_warp(delta: float) -> void:
	if warp_t <= 0.0:
		return
	warp_t -= delta
	if not warped and warp_t < 0.62:
		warped = true
		hud.flash(Color.WHITE, 1.2)
		world.theme = warp_target
		world.reset(true, 140.0)  # clear run-in after a warp
		if warp_shortcut:
			warp_shortcut = false
			var skip := 400.0
			distance += skip
			score += skip * 0.5 * _score_mult()
			hud.zone_banner("SHORTCUT", "+%d m" % int(skip))
			warp_t = minf(warp_t, 0.6)
			return
		zone_start = distance
		veh_granted_zone = -1
		_snap_zone(warp_target)
		audio.play_zone(warp_target)
		hud.zone_banner(ZONES[warp_target]["name"], "WARPED  ·  TRACK  %d" % (warp_target + 1))
		var pts := 300 * _score_mult()
		score += pts
		hud.popup("WARP!  +%d" % pts, ThemesScript.ACCENT[warp_target], 50)
		cam.punch_fov(-10.0)
		audio.play("portal", 1.3)


func _apply_zone(z: Dictionary) -> void:
	sky_mat.sky_top_color = z["top"]
	sky_mat.sky_horizon_color = z["hor"]
	sky_mat.ground_horizon_color = z["hor"]
	sky_mat.ground_bottom_color = z["ground"]
	env.fog_light_color = z["fog"]
	env.ambient_light_energy = z["amb"]
	sun.light_color = z["sun"]
	sun.light_energy = z["sun_e"]
	stars_mat.albedo_color.a = z["stars"]
	env.glow_intensity = 0.65 + float(z["stars"]) * 0.4 + float(z["plight"]) * 0.25
	if player_light:
		player_light.light_energy = z["plight"]
	# BLACKOUT event: the city goes dark, only warning lights + your torch
	var dk: float = events.dark if events else 0.0
	if dk > 0.0:
		var night := Color(0.01, 0.01, 0.03)
		sky_mat.sky_top_color = (z["top"] as Color).lerp(night, dk)
		sky_mat.sky_horizon_color = (z["hor"] as Color).lerp(Color(0.05, 0.03, 0.1), dk)
		sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
		env.fog_light_color = (z["fog"] as Color).lerp(Color(0.02, 0.02, 0.05), dk)
		env.ambient_light_energy = lerpf(z["amb"], 0.08, dk)
		sun.light_energy = lerpf(z["sun_e"], 0.03, dk)
		stars_mat.albedo_color.a = maxf(z["stars"], dk)
		env.glow_intensity += dk * 0.5
		if player_light:
			player_light.light_energy = maxf(z["plight"], 2.6 * dk)
			player_light.omni_range = lerpf(9.0, 16.0, dk)


func _spin_pickups(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.004
	for obj in world.objects.get_children():
		var kind: String = obj.get_meta("kind")
		if kind == "coin":
			obj.rotate_y(4.0 * delta)
		elif kind == "anchor":
			var in_range: bool = state == State.PLAYING and not obj.get_meta("used") and obj.position.z > -44.0 and obj.position.z < -3.0
			var s := 1.0 + (0.25 + sin(t * 3.0) * 0.15 if in_range else 0.0)
			obj.scale = obj.scale.lerp(Vector3(s, s, s), 0.2)


func _update_visual_fx(delta: float) -> void:
	var sf := _speed_factor()
	var playing := state == State.PLAYING
	var dashing: bool = playing and (ab_active[DASH] > 0.0 or player.air_dash_t > 0.0)
	speed_lines.emitting = playing and (warp_t > 0.0 or sf > 0.3 or dashing or portal_boost > 0.0 or flow > 35.0 or player.is_grappling())
	var ab := 0.0015 + sf * 0.004 + flow * 0.00005
	var blur := 0.0
	if playing:
		if dashing:
			ab += 0.012
			blur += 0.05
		if portal_boost > 0.0:
			blur += 0.035
		if player.is_grappling():
			blur += 0.03
		if warp_t > 0.0:
			blur += 0.12 * warp_t
			ab += 0.02 * warp_t
		blur += maxf(0.0, sf - 0.5) * 0.04
	var shift_t := 0.0
	shift_amount = lerpf(shift_amount, shift_t, 1.0 - exp(-6.0 * delta))
	hud.set_post(ab, shift_amount, blur, Color(0.6, 0.8, 1.0))


# ============================================================ player callbacks
func _on_jumped(kind: String) -> void:
	match kind:
		"double":
			audio.play("djump")
			fx.burst(player.position + Vector3(0, 0.2, 0), CYAN, 8, 5.0, 0.14, 0.35, 0.0)
			cam.kick(Vector3(0, 0.25, 0))
			_add_flow(2.0, "double")
		"sky":
			ab_cd[SKY] = prog.value("sky")
			hud.slot_used(SKY)
			audio.play("djump", 0.7)
			audio.play("portal", 1.6, -8.0)
			fx.ring(player.position + Vector3(0, 0.2, 0), Color(0.45, 0.75, 1.0), 4.0, 0.4, 0.0, true)
			fx.burst(player.position + Vector3(0, 0.2, 0), Color(0.45, 0.75, 1.0), 14, 7.0, 0.16, 0.45, 0.0)
			cam.kick(Vector3(0, 0.5, 0.5))
			cam.punch_fov(10.0)
			hud.popup("SKY JUMP!", Color(0.45, 0.75, 1.0), 40)
			_add_flow(8.0, "sky")
		"dash_jump":
			dashjump_carry = true
			audio.play("djump", 0.8)
			cam.punch_fov(8.0)
			cam.kick(Vector3(0, 0.4, 0.8))
			hud.popup("DASH JUMP!", PINK, 38)
			fx.burst(player.position, PINK, 12, 6.0, 0.15, 0.35, 0.0)
			_add_flow(10.0, "jump")
		"wall_jump":
			audio.play("djump", 1.1)
			cam.kick(Vector3(player.x_vel * 0.03, 0.3, 0))
			cam.kick_roll(0.25 * signf(player.x_vel))
			_add_flow(8.0, "walljump")
		_:
			audio.play("jump", randf_range(0.95, 1.05), -2.0)
			_style_move("jump")
	if player.boarding and kind != "wall_jump":
		_skate_trick()


func _on_landed(impact: float, was_slam: bool) -> void:
	if state != State.PLAYING and state != State.MENU:
		return
	if was_slam and state == State.PLAYING:
		_slam_impact()
		return
	audio.play("land", 1.0, -6.0 + clampf(impact * 0.2, 0.0, 6.0))
	if state == State.PLAYING and not style.chain.is_empty() and impact > 8.0:
		_style_move("land")
	cam.kick(Vector3(0, -clampf(impact * 0.018, 0.05, 0.6), 0))
	if impact > 25.0:
		cam.add_trauma(0.3)
		fx.burst(player.position, PINK, 10, 6.0, 0.16, 0.35, 10.0)
	elif impact > 12.0:
		cam.add_trauma(0.08)


# ============================================================ v9: routes, pickups, enemies, missions
func _update_route() -> void:
	var r := ""
	var py: float = player.position.y
	for obj in world.objects.get_children():
		var k: String = obj.get_meta("kind")
		if k == "platform" and obj.get_meta("route", "") == "high":
			var box: AABB = obj.get_meta("box")
			if absf(player.position.x - obj.position.x) < 1.6 and obj.position.z + box.position.z < 0.0 \
					and obj.position.z + box.end.z > 0.0 and py > 4.0:
				r = "high"
		elif k == "underpass":
			var hl: float = obj.get_meta("half")
			if player.lane == 1 and absf(obj.position.z) < hl and py < 3.0:
				r = "under"
	if r == route:
		return
	if r == "high":
		hud.popup("HIGH ROUTE!   RISKY  ·  x2 COINS  ·  FASTER", GOLD, 42)
		audio.play("portal", 1.3, -4.0)
		_mission("high", 1)
		_style_move("route")
	elif r == "under":
		hud.popup("UNDERPASS  ·  SAFE & STEADY", CYAN, 40)
		audio.play("wall", 0.7, -6.0)
		_mission("under", 1)
	route = r


func _gain_pickup(obj: Node3D) -> void:
	var t: String = obj.get_meta("ctype")
	var c: Color = world.PICKUP_COL[t]
	fx.burst(obj.position, c, 18, 8.0, 0.2, 0.5, 0.0)
	fx.ring(obj.position, c, 3.0, 0.4)
	obj.queue_free()
	match t:
		"energy":
			for i in 3:
				ab_cd[i] = 0.0
			airdash_cd = 0.0
			wall_cd = 0.0
			slam_cd = 0.0
			var es: float = prog.frag_value("energy_boost")
			if es > 0.0:
				pw["shield"] = maxf(pw["shield"], es)
				_update_power_visuals()
			hud.popup("ENERGY!  ABILITIES RECHARGED", c, 38)
			audio.play("orb", 1.4)
			_add_flow(10.0, "boost")
		"fragment":
			run_frags += 1
			prog.fragments += 1
			hud.popup("+1 FRAGMENT", c, 34)
			audio.play("orb", 1.7, -2.0)
			_mission("frag", 1)
		"key":
			run_keys += 1
			hud.popup("KEY!  RUN THROUGH A SHORTCUT GATE", c, 36)
			audio.play("ready", 1.3)
		"artifact":
			var left := ProgressScript.ARTIFACTS.filter(func(a): return not a[0] in prog.artifacts)
			if left.is_empty():
				prog.fragments += 25
				run_frags += 25
				hud.popup("ARTIFACT DUPLICATE  →  +25 FRAGMENTS", c, 36)
			else:
				var a: Array = left[randi() % left.size()]
				prog.artifacts.append(a[0])
				run_artifacts.append(a[1])
				hud.zone_banner(a[1], "ARTIFACT FOUND  ·  %d / %d IN YOUR COLLECTION" % [prog.artifacts.size(), ProgressScript.ARTIFACTS.size()])
				hud.flash(GOLD, 0.4)
			audio.play("overdrive", 1.2)
			prog.save()


var warp_shortcut := false


func _shortcut() -> void:
	if run_keys <= 0:
		hud.popup("SHORTCUT LOCKED  ·  NEEDS A KEY", Color(1.0, 0.8, 0.3), 34)
		audio.play("deny")
		return
	run_keys -= 1
	_mission("shortcut", 1)
	warp_shortcut = true
	_warp(zone_idx)
	hud.popup("SHORTCUT!", GOLD, 56)


## A threat from enemies.gd reached you.
func enemy_hit(title: String) -> void:
	if state != State.PLAYING or grace > 0.0 or player.is_tricking():
		return
	style.broken()
	if pw["shield"] > 0.0:
		grace = 0.6
		cam.add_trauma(0.4)
		hud.flash(CYAN, 0.25)
		hud.popup("SHIELD!", CYAN, 40)
		audio.play("shield_break")
		return
	if player.vehicle != "":
		grace = 1.2
		cam.add_trauma(0.5)
		veh_hits -= 1
		if veh_hits <= 0:
			fx.burst(player.position + Vector3(0, 0.6, 0), Color(1, 0.6, 0.3), 18, 9.0, 0.2, 0.7)
			player.set_vehicle("")
			hud.popup("RIDE WRECKED  -  YOU'RE OK!", Color(1, 0.6, 0.35), 40)
		else:
			hud.popup("ARMOR HIT  ·  %d LEFT" % veh_hits, Color(1, 0.7, 0.4), 38)
		audio.play("shield_break", 0.8)
		return
	_crash(title)


func enemy_dodged(who: String) -> void:
	var pts := 100 * _score_mult()
	score += pts
	hud.popup("DODGED THE %s!  +%d" % [who, pts], Color(1.0, 0.6, 0.4), 36)
	_style_move("dodge")
	_mission("dodge", 1)


func enemy_smashed(pos: Vector3, who: String) -> void:
	fx.burst(pos + Vector3(0, 1, 0), Color(1.0, 0.5, 0.2), 22, 12.0, 0.3, 0.7)
	cam.add_trauma(0.35)
	audio.play("smash", 0.8)
	var pts := 200 * _score_mult()
	score += pts
	hud.popup("%s SMASHED!  +%d" % [who, pts], PINK, 42)
	_style_move("smash")
	_mission("smash", 1)


func rival_knocked(stolen: int) -> void:
	var c := stolen * 2 + 10
	gold += c
	audio.play("smash", 1.2)
	cam.add_trauma(0.25)
	hud.popup("RIVAL DOWN!  +%d COINS" % c, Color(0.75, 0.4, 1.0), 44)
	_style_move("smash")


func titan_escaped() -> void:
	if state != State.PLAYING:
		return
	var pts := 1000 * _score_mult()
	score += pts
	gold += 50
	hud.popup("ESCAPED THE TITAN!  +%d  ·  +50 COINS" % pts, Color(1.0, 0.5, 0.2), 44)
	audio.play("overdrive")
	_mission("boss", 1)


func event_survived(nm: String, _id: String) -> void:
	if state != State.PLAYING:
		return
	var pts := 500 * _score_mult()
	score += pts
	gold += 25
	hud.popup("%s SURVIVED!  +%d  ·  +25 COINS" % [nm, pts], GREEN, 40)
	audio.play("ready", 1.1)
	_mission("event", 1)


## Enemies also turn up outside the random events.
func _tick_enemy_spawns(delta: float) -> void:
	enemy_t -= delta
	if enemy_t > 0.0 or events.current != "" or enemies.any_active() or distance < 250.0:
		return
	enemy_t = randf_range(22.0, 38.0)
	match randi() % 4:
		0:
			enemies.add_rival()
			hud.popup("A RIVAL RUNNER IS STEALING YOUR COINS!  DASH INTO HER", Color(0.75, 0.4, 1.0), 32)
		1:
			enemies.add_blocker()
			hud.popup("BLOCKER AHEAD!", Color(1.0, 0.5, 0.2), 38)
		2:
			enemies.add_bomber()
			enemies.solo_t = 12.0
			hud.popup("BOMBER DRONE!", Color(1.0, 0.3, 0.25), 38)
		3:
			enemies.add_hunter()
			enemies.solo_t = 12.0
			hud.popup("HUNTER DRONE!", Color(1.0, 0.3, 0.25), 38)


func _mission(stat: String, v: int, per_run := false) -> void:
	var done: Array = prog.mission_event(stat, v, per_run)
	for d in done:
		run_missions.append(d)
		var reward := "+%d COINS" % d["coins"]
		if int(d["frags"]) > 0:
			reward += "  ·  +%d FRAGMENTS" % d["frags"]
		hud.popup("MISSION COMPLETE!   " + reward, GREEN, 36)
		hud.popup(String(d["text"]).to_upper(), Color(0.85, 1.0, 0.85), 26)
		audio.play("overdrive", 1.3, -4.0)


# ============================================================ v9: settings, graphics, cosmetics
## Which renderer is running: forward_plus, mobile or gl_compatibility.
func _renderer() -> String:
	if RenderingServer.get_rendering_device() == null:
		return "gl_compatibility"
	var args := OS.get_cmdline_args()
	var i := args.find("--rendering-method")
	if i >= 0 and i + 1 < args.size():
		return args[i + 1]
	var key := "rendering/renderer/rendering_method.mobile" if OS.has_feature("mobile") else "rendering/renderer/rendering_method"
	return str(ProjectSettings.get_setting(key, "forward_plus"))


func _apply_settings() -> void:
	var st: Dictionary = prog.settings
	audio.set_volumes(float(st["music"]), float(st["sfx"]))
	cam.shake_mult = float(st["shake"])
	touch.set_enabled(bool(st["touch"]))
	hud.set_touch_keys(bool(st["touch"]))
	_apply_graphics()


## Ambient occlusion (SSAO) + real-time global illumination (SSIL: screen-space
## indirect light, bounce light from everything on screen). Both render at
## half resolution, and the auto-performance governor switches them off if
## the frame rate drops, so they never cost you smoothness.
func _apply_graphics() -> void:
	var q: String = prog.settings["quality"]
	var forward_plus := _renderer() == "forward_plus"
	var ao: bool = bool(prog.settings["ao"]) and q in ["ultra", "high", "medium"] and forward_plus and perf_level < 2
	var gi: bool = bool(prog.settings["gi"]) and q in ["ultra", "high"] and forward_plus and perf_level < 1 and not is_mobile
	env.ssao_enabled = ao
	env.ssao_radius = 1.1
	env.ssao_intensity = 1.6
	env.ssao_power = 1.5
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.15
	env.ssil_enabled = gi
	env.ssil_radius = 6.0
	env.ssil_intensity = 1.4
	env.ssil_sharpness = 0.98
	env.ssil_normal_rejection = 1.0
	var aoq := RenderingServer.ENV_SSAO_QUALITY_HIGH if q == "ultra" else RenderingServer.ENV_SSAO_QUALITY_MEDIUM
	RenderingServer.environment_set_ssao_quality(aoq, q != "ultra", 0.5, 2, 50.0, 300.0)
	var ilq := RenderingServer.ENV_SSIL_QUALITY_MEDIUM if q == "ultra" else RenderingServer.ENV_SSIL_QUALITY_LOW
	RenderingServer.environment_set_ssil_quality(ilq, true, 0.5, 2, 50.0, 300.0)
	# cheap baked-style contact shading for renderers / presets without SSAO
	RenderingServer.global_shader_parameter_set("fake_ao", 0.0 if ao else 1.0)
	var shadow_d: float = {"ultra": 90.0, "high": 60.0, "medium": 48.0, "low": 34.0, "mobile": 36.0}.get(q, 60.0)
	if perf_level >= 3:
		shadow_d = minf(shadow_d, 34.0)
	sun.directional_shadow_max_distance = shadow_d
	sun.shadow_enabled = q != "low"
	var vp := get_viewport()
	if q == "ultra" and perf_level < 3:
		vp.msaa_3d = Viewport.MSAA_4X
	elif q == "high" and perf_level < 3:
		vp.msaa_3d = Viewport.MSAA_2X
	else:
		vp.msaa_3d = Viewport.MSAA_DISABLED
	if q == "mobile" or q == "low":
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if forward_plus else Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 0.8 if q == "mobile" else 0.85
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 1.0
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	hud.show_fps(bool(prog.settings["fps_counter"]))


## Watches the frame rate while playing: if it stays under 50 fps, AO / GI /
## MSAA are stepped down one at a time so the game keeps running smoothly.
func _perf_governor(delta: float) -> void:
	if not bool(prog.settings["auto_perf"]) or state != State.PLAYING or DisplayServer.get_name() == "headless":
		perf_t = 0.0
		perf_frames = 0
		return
	perf_t += delta
	perf_frames += 1
	if perf_t >= 3.0:
		var fps := perf_frames / perf_t
		perf_t = 0.0
		perf_frames = 0
		if fps < 50.0 and perf_level < 3:
			perf_level += 1
			_apply_graphics()
			print("auto-performance: %.0f fps -> level %d" % [fps, perf_level])


func _apply_cosmetics() -> void:
	var tr: Array = ProgressScript.cosmetic(ProgressScript.TRAILS, prog.trail)
	var au: Array = ProgressScript.cosmetic(ProgressScript.AURAS, prog.aura)
	player.set_cosmetics(tr[3], tr[4], prog.trail == "rainbow", au[0], au[3], au[4])


func _change_setting(key: String, value) -> void:
	if key == "reset_perf":
		perf_level = 0
	else:
		prog.settings[key] = value
	prog.save()
	_apply_settings()
	audio.play("click", 1.1, -4.0)
	if panel == "settings" and not key in ["music", "sfx", "shake"]:
		hud.show_panel("settings", _settings_data())


func _pick_cosmetic(kind: String, id: String) -> void:
	if prog.buy_cosmetic(kind, id):
		audio.play("ready", 1.2)
		_apply_cosmetics()
	else:
		audio.play("deny")
	hud.show_panel("customize", _custom_data())
	hud.set_wallet(prog.wallet)


func _buy_frag_upgrade(id: String) -> void:
	if prog.buy_frag_upgrade(id):
		audio.play("orb", 1.4)
		hud.flash(Color(0.75, 0.35, 1.0), 0.2)
	else:
		audio.play("deny")
	hud.show_panel("upgrades", _upgrade_data())
	hud.set_upgrade_summary(_upgrade_data())


func _custom_data() -> Dictionary:
	var trails := []
	for t in ProgressScript.TRAILS:
		trails.append({"id": t[0], "name": t[1], "price": t[2], "a": t[3], "b": t[4], "owned": t[0] in prog.trails_owned, "on": prog.trail == t[0]})
	var auras := []
	for a in ProgressScript.AURAS:
		auras.append({"id": a[0], "name": a[1], "price": a[2], "a": a[3], "b": a[4], "owned": a[0] in prog.auras_owned, "on": prog.aura == a[0]})
	return {"trails": trails, "auras": auras, "wallet": prog.wallet}


func _records_data() -> Dictionary:
	var ms := []
	for m in prog.missions:
		ms.append(prog.mission_info(m))
	var arts := []
	for a in ProgressScript.ARTIFACTS:
		arts.append({"name": a[1], "color": a[2], "found": a[0] in prog.artifacts})
	return {"scores": prog.scores, "missions": ms, "artifacts": arts, "stats": prog.stats, "wallet": prog.wallet,
		"fragments": prog.fragments}


func _settings_data() -> Dictionary:
	var d: Dictionary = prog.settings.duplicate()
	d["wallet"] = prog.wallet
	d["forward_plus"] = _renderer() == "forward_plus"
	d["perf_level"] = perf_level
	d["mobile"] = is_mobile
	return d


func _tick_speed(delta: float) -> void:
	if speed < speed_target:
		# warm-up is quicker; later steps ease in gently
		var rate := SPEED_GAIN * 1.4 if speed_target <= CRUISE_SPEED else SPEED_EASE
		speed = minf(speed_target, speed + rate * delta)
		return
	speed_hold += delta
	if speed_hold >= SPEED_HOLD and speed_target < MAX_SPEED:
		speed_hold = 0.0
		speed_target = minf(MAX_SPEED, speed_target + SPEED_STEP)
		hud.popup("SPEED UP!", Color(1.0, 0.6, 0.3), 40)
		audio.play("ready", 0.9, -4.0)
		cam.punch_fov(6.0)
