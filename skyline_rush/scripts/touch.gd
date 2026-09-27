extends Control
## Mobile controls (auto-on for phones / tablets, or SETTINGS > TOUCH CONTROLS):
##   swipe left / right  - change lane (swipe into a wall to wall-run)
##   swipe up            - jump  (swipe up twice fast = SKY JUMP)
##   swipe down          - slide  (in the air: ground slam)
##   double tap        - HOOK (the E grapple)
##   DASH button         - the Q ability
##   pause button        - top left

const SWIPE := 55.0
const TAP_TIME := 260     # ms a touch may last and still count as a tap
const DOUBLE_TAP := 320   # ms allowed between the two taps of a double tap
const TAP_SLOP := 140.0   # px the second tap may land away from the first

var game
var enabled := false
var starts := {}          # touch index -> [start_pos, time, done]
var buttons: Array = []   # [Rect2 getter node, action]
var btn_dash: Button
var last_tap := -10000       # ms
var last_tap_pos := Vector2.ZERO
var btn_pause: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_dash = _round_button("DASH", Color(1.0, 0.35, 0.75), Vector2(-190, -300))
	btn_pause = _round_button("II", Color(0.7, 0.65, 1.0), Vector2(0, 0), true)
	btn_dash.pressed.connect(func(): game._use_dash())
	btn_pause.pressed.connect(func(): game._set_paused(true))
	set_enabled(false)


func _round_button(text: String, col: Color, off: Vector2, top_left := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	var sz := 150.0 if not top_left else 84.0
	b.custom_minimum_size = Vector2(sz, sz)
	b.size = Vector2(sz, sz)
	b.add_theme_font_size_override("font_size", 30 if not top_left else 26)
	for st in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(col.r * 0.25, col.g * 0.2, col.b * 0.3, 0.55 if st != "pressed" else 0.85)
		s.border_color = col
		s.set_border_width_all(4)
		s.set_corner_radius_all(int(sz * 0.5))
		b.add_theme_stylebox_override(st, s)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if top_left:
		b.position = Vector2(30, 150)
	else:
		b.anchor_left = 1.0
		b.anchor_right = 1.0
		b.anchor_top = 1.0
		b.anchor_bottom = 1.0
		b.offset_left = off.x
		b.offset_top = off.y
		b.offset_right = off.x + sz
		b.offset_bottom = off.y + sz
	add_child(b)
	return b


func set_enabled(on: bool) -> void:
	enabled = on
	visible = on


func _process(_delta: float) -> void:
	if not enabled or game == null:
		return
	var playing: bool = game.state == game.State.PLAYING
	btn_dash.visible = playing
	btn_pause.visible = playing


func _on_button(pos: Vector2) -> bool:
	for b in [btn_dash, btn_pause]:
		if b.visible and b.get_global_rect().grow(12.0).has_point(pos):
			return true
	return false


func _input(event: InputEvent) -> void:
	if not enabled or game == null or game.state != game.State.PLAYING:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _on_button(event.position):
				return
			starts[event.index] = [event.position, Time.get_ticks_msec(), false]
		else:
			var st = starts.get(event.index)
			starts.erase(event.index)
			if st != null and not st[2]:
				var d: Vector2 = event.position - st[0]
				if d.length() >= SWIPE:
					_swipe(d)
				elif Time.get_ticks_msec() - int(st[1]) <= TAP_TIME:
					_tap(event.position)
			game.player.release_jump()
	elif event is InputEventScreenDrag:
		var st = starts.get(event.index)
		if st == null or st[2]:
			return
		var d: Vector2 = event.position - st[0]
		if d.length() >= SWIPE:
			st[2] = true
			_swipe(d)


## Two quick taps = HOOK (grapple).
func _tap(pos: Vector2) -> void:
	var now := Time.get_ticks_msec()
	if now - last_tap <= DOUBLE_TAP and pos.distance_to(last_tap_pos) <= TAP_SLOP:
		last_tap = -10000
		game._use_hook()
		return
	last_tap = now
	last_tap_pos = pos


func _swipe(d: Vector2) -> void:
	if absf(d.x) > absf(d.y):
		game._on_dir(1 if d.x > 0.0 else -1)
	elif d.y < 0.0:
		game.player.sky_ready = game.ab_cd[game.SKY] <= 0.0
		game.player.press_jump()
	else:
		game._on_slide()
