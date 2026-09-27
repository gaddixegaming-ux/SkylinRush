extends RefCounted
## Random events: every minute or so something unusual happens for a while.
##   BUS RUSH      - waves of oncoming buses, always one lane free
##   DRONE HUNT    - bomber + hunter drones go after you
##   OVERDRIVE     - everything speeds up, score and coins x2
##   GRAVITY SHIFT - low gravity: floaty, huge jumps
## Surviving an event pays a bonus and counts towards missions.

const EVENTS := {
	"bus_rush": {"name": "BUS RUSH", "sub": "ONE LANE STAYS FREE  ·  FIND IT", "dur": 14.0, "col": Color(1.0, 0.75, 0.2)},
	"drone_hunt": {"name": "DRONE HUNT", "sub": "BOMBERS + HUNTERS INCOMING", "dur": 18.0, "col": Color(1.0, 0.3, 0.25)},
	"overdrive": {"name": "OVERDRIVE", "sub": "SPEED UP  ·  SCORE + COINS x2", "dur": 20.0, "col": Color(1.0, 0.4, 0.9)},
	"gravity": {"name": "GRAVITY SHIFT", "sub": "LOW GRAVITY  ·  FLY HIGH", "dur": 15.0, "col": Color(0.45, 1.0, 0.8)},
}

var g
var current := ""
var t := 0.0
var next_in := 45.0
var wave_t := 0.0
var dark := 0.0        # blackout amount 0..1 (smoothed)
var last := ""


func setup(game) -> void:
	g = game


func reset() -> void:
	if current != "":
		_end(false)
	current = ""
	t = 0.0
	next_in = randf_range(38.0, 50.0)
	dark = 0.0


func active(id: String) -> bool:
	return current == id


func time_left() -> float:
	return t if current != "" else 0.0


func start(id: String) -> void:
	if current != "":
		_end(false)
	current = id
	last = id
	var e: Dictionary = EVENTS[id]
	t = e["dur"]
	wave_t = 1.0
	g.hud.zone_banner(e["name"], e["sub"])
	g.hud.flash(e["col"], 0.35)
	g.audio.play("overdrive" if id == "overdrive" else "portal", 0.8, -2.0)
	g.cam.punch_fov(8.0)
	match id:
		"drone_hunt":
			g.enemies.add_bomber()
			g.enemies.add_hunter()
		"gravity":
			g.player.grav_mult = 0.45
		"overdrive":
			g.audio.set_rate(1.06)


func tick(delta: float) -> void:
	var want_dark := 1.0 if current == "blackout" else 0.0
	dark = move_toward(dark, want_dark, delta / 1.5)
	if current == "":
		# no events on a vehicle map's first seconds or during a warp
		next_in -= delta
		if next_in <= 0.0 and g.warp_t <= 0.0:
			var pool := EVENTS.keys().filter(func(k): return k != last)
			start(pool[randi() % pool.size()])
		return
	t -= delta
	match current:
		"bus_rush":
			wave_t -= delta
			if wave_t <= 0.0:
				wave_t = randf_range(1.4, 1.9)
				var free: int = randi() % 3 - 1
				for lane in [-1, 0, 1]:
					if lane != free and randf() < 0.8:
						g.world.spawn_oncoming_bus(lane, -200.0 - randf_range(0.0, 20.0))
		"drone_hunt":
			pass
	if t <= 0.0:
		_end(true)


func _end(survived: bool) -> void:
	var id := current
	current = ""
	next_in = randf_range(45.0, 70.0)
	match id:
		"drone_hunt":
			g.enemies.clear()
		"gravity":
			g.player.grav_mult = 1.0
		"overdrive":
			g.audio.set_rate(1.0)
	if survived:
		g.event_survived(EVENTS[id]["name"], id)


## Speed and reward multipliers the director applies while an event runs.
func speed_mult() -> float:
	return 1.35 if current == "overdrive" else 1.0


func reward_mult() -> int:
	return 2 if current == "overdrive" else 1
