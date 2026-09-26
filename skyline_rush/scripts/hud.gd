extends CanvasLayer
## All UI: in-game HUD, ability slots, power-up timers, vehicle card, main menu,
## garage, upgrade shop, controls, pause, game over, popups and post-fx.
## One visual language: dark glass cards, a thin accent edge, bold type.

signal play_pressed
signal retry_pressed
signal menu_pressed
signal resume_pressed
signal quit_pressed
signal track_changed(dir: int)
signal revive_pressed
signal char_changed(dir: int)
signal panel_requested(panel: String)
signal garage_tab(type: String)
signal garage_item(index: int)
signal upgrade_buy(id: String)

const PINK := Color(1.0, 0.35, 0.75)
const CYAN := Color(0.35, 0.9, 1.0)
const GOLD := Color(1.0, 0.8, 0.25)
const GREEN := Color(0.4, 1.0, 0.6)
const CARD := Color(0.06, 0.045, 0.12, 0.8)
const CARD_HI := Color(0.12, 0.08, 0.22, 0.92)
const TEXT_DIM := Color(0.76, 0.72, 0.9)
const INK := Color(0.05, 0.02, 0.1)
const POSTFX := preload("res://shaders/postfx.gdshader")

var root: Control
var hud: Control
var menu: Control
var menu_col: VBoxContainer
var pause_panel: Control
var over: Control
var post_mat: ShaderMaterial
var font: SystemFont
var font_reg: SystemFont

var score_lbl: Label
var dist_lbl: Label
var mult_lbl: Label
var mult_chip: PanelContainer
var coin_lbl: Label
var speed_lbl: Label
var zone_lbl: Label
var zone_next: Label
var zone_bar: Bar
var flow_bar: Bar
var slots: Array = []
var slot_names: Array = []
var power_box: VBoxContainer
var power_rows := {}
var veh_card: PanelContainer
var veh_name: Label
var veh_pips: Pips
var veh_armor: Pips
var popups: VBoxContainer
var menu_best: Label
var wallet_lbl: Label
var controls_panel: Control
var track_name: Label
var track_num: Label
var track_hint: Label
var track_swatch: ColorRect
var char_name: Label
var char_hobby: Label
var over_title: Label
var over_vals: Dictionary = {}
var over_badge: PanelContainer
var over_revive: Button
var over_bank: Label
var coin_icon: CoinIcon
var markers_layer: MarkerLayer
var prompt_lbl: Label
var zone_box: VBoxContainer
var zone_title: Label
var zone_sub: Label
var side_panel: PanelContainer
var side_body: VBoxContainer
var side_title: Label
var side_wallet: Label
var cur_panel := ""
var upg_card: PanelContainer
var upg_list: VBoxContainer
var nav: HBoxContainer

var _flash := 0.0
var _flash_color := Color.WHITE
var _coin_pop := 0.0
var _t := 0.0
var _last_mult := 1


# ============================================================ custom widgets
class CoinIcon extends Control:
	var pop := 0.0
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 * (1.0 + pop * 0.3)
		draw_circle(c, r, Color(0.85, 0.5, 0.05))
		draw_circle(c, r * 0.82, Color(1.0, 0.8, 0.25))
		draw_arc(c, r * 0.55, 0, TAU, 32, Color(1, 0.95, 0.6), 3.0, true)
		draw_rect(Rect2(c - Vector2(r * 0.12, r * 0.35), Vector2(r * 0.24, r * 0.7)), Color(0.9, 0.55, 0.05))


class MarkerLayer extends Control:
	var markers: Array = []
	var fnt: Font
	var t := 0.0
	func _draw() -> void:
		for m in markers:
			var p: Vector2 = m["pos"]
			var col: Color = m["color"]
			var r := 34.0 if m["big"] else 22.0
			r *= 1.0 + sin(t * 8.0) * 0.08
			for k in 4:
				var a0 := t * 2.0 + k * PI / 2.0
				draw_arc(p, r, a0, a0 + 0.9, 10, col, 4.0 if m["big"] else 3.0, true)
			draw_circle(p, 4.0, col)
			if fnt:
				var fs := 22 if m["big"] else 15
				var tp := p + Vector2(-240, r + fs + 6)
				draw_string_outline(fnt, tp, m["text"], HORIZONTAL_ALIGNMENT_CENTER, 480, fs, 7, Color(0.05, 0.02, 0.1))
				draw_string(fnt, tp, m["text"], HORIZONTAL_ALIGNMENT_CENTER, 480, fs, col)


class Bar extends Control:
	var value := 0.0
	var col_a := Color(1.0, 0.35, 0.75)
	var col_b := Color(0.35, 0.9, 1.0)
	var text := ""
	var fnt: Font
	var glow := 0.0
	var ticks: Array = []
	func _draw() -> void:
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.03, 0.02, 0.07, 0.85)
		bg.set_corner_radius_all(int(size.y * 0.5))
		bg.border_color = Color(col_a, 0.35 + glow * 0.6)
		bg.set_border_width_all(2)
		draw_style_box(bg, Rect2(Vector2.ZERO, size))
		var w := (size.x - 6.0) * clampf(value, 0.0, 1.0)
		if w > 3.0:
			var steps := 24
			var h := size.y - 6.0
			for i in steps:
				var x0 := 3.0 + w * i / steps
				var x1 := 3.0 + w * (i + 1) / steps
				draw_rect(Rect2(Vector2(x0, 3.0), Vector2(x1 - x0 + 0.5, h)), col_a.lerp(col_b, float(i) / steps))
			draw_rect(Rect2(Vector2(3.0, 3.0), Vector2(w, h * 0.35)), Color(1, 1, 1, 0.22))
		for tk in ticks:
			var x: float = 3.0 + (size.x - 6.0) * float(tk)
			draw_line(Vector2(x, 2), Vector2(x, size.y - 2), Color(1, 1, 1, 0.5), 2.0)
		if text != "" and fnt:
			var fs := int(size.y * 0.6)
			draw_string_outline(fnt, Vector2(0, size.y * 0.5 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 5, Color(0.05, 0.02, 0.1))
			draw_string(fnt, Vector2(0, size.y * 0.5 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color.WHITE)


class Pips extends Control:
	var count := 3
	var filled := 3
	var col := Color(1.0, 0.6, 0.3)
	var progress := -1.0
	func _draw() -> void:
		if progress >= 0.0:
			var bg := StyleBoxFlat.new()
			bg.bg_color = Color(0.03, 0.02, 0.07, 0.85)
			bg.set_corner_radius_all(6)
			draw_style_box(bg, Rect2(Vector2.ZERO, size))
			draw_rect(Rect2(Vector2(2, 2), Vector2((size.x - 4) * progress, size.y - 4)), col)
			return
		var w := (size.x - (count - 1) * 6.0) / maxf(1.0, count)
		for i in count:
			var r := Rect2(Vector2(i * (w + 6.0), 0), Vector2(w, size.y))
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(5)
			sb.bg_color = col if i < filled else Color(0.15, 0.12, 0.22, 0.9)
			draw_style_box(sb, r)


class Ring extends Control:
	## circular timer for power-ups
	var ratio := 1.0
	var col := Color.WHITE
	var id := ""
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 3.0
		draw_circle(c, r, Color(0.04, 0.02, 0.08, 0.9))
		draw_arc(c, r, -PI / 2, -PI / 2 + TAU * clampf(ratio, 0.0, 1.0), 40, col, 4.0, true)
		var s := r * 0.5
		match id:
			"magnet":
				draw_arc(c + Vector2(0, 0.05 * s), 0.55 * s, 0, PI, 16, col, 4.0, true)
				draw_line(c + Vector2(-0.55 * s, 0), c + Vector2(-0.55 * s, -0.6 * s), col, 4.0)
				draw_line(c + Vector2(0.55 * s, 0), c + Vector2(0.55 * s, -0.6 * s), col, 4.0)
			"shield":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-0.6 * s, -0.6 * s), c + Vector2(0.6 * s, -0.6 * s), c + Vector2(0.5 * s, 0.2 * s), c + Vector2(0, 0.75 * s), c + Vector2(-0.5 * s, 0.2 * s)]), col)
			"springs":
				for k in 3:
					draw_arc(c + Vector2(0, (0.45 - k * 0.3) * s), 0.35 * s, 0, TAU, 14, col, 2.5, true)
				draw_rect(Rect2(c + Vector2(-0.55 * s, -0.75 * s), Vector2(1.1 * s, 0.35 * s)), col)
			"double":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -0.8 * s), c + Vector2(0.6 * s, 0), c + Vector2(0, 0.8 * s), c + Vector2(-0.6 * s, 0)]), col)


class AbilitySlot extends Control:
	var id := ""
	var key := ""
	var col := Color.WHITE
	var cd_ratio := 0.0
	var cd_left := 0.0
	var active_ratio := 0.0
	var is_ready := true
	var bump := 0.0
	var deny := 0.0
	var fnt: Font
	var label := ""

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.42) + Vector2(sin(deny * 40.0) * deny * 8.0, 0)
		var r := minf(size.x, size.y * 0.84) * 0.5 - 6.0
		r *= 1.0 + bump * 0.12
		if is_ready or active_ratio > 0.0:
			draw_circle(c, r + 6.0, Color(col, 0.16 + bump * 0.3))
		draw_circle(c, r, Color(0.05, 0.03, 0.11, 0.94))
		draw_arc(c, r, 0, TAU, 64, Color(col, 0.3 if not is_ready else 0.95), 3.0, true)
		var icol := col if (is_ready or active_ratio > 0.0) else Color(0.5, 0.46, 0.6)
		_icon(c, r * 0.5, icol)
		if active_ratio > 0.0:
			draw_arc(c, r - 1.0, -PI / 2, -PI / 2 + TAU * clampf(active_ratio, 0.0, 1.0), 64, col, 6.0, true)
		if cd_ratio > 0.0:
			var pts := PackedVector2Array([c])
			var seg := 40
			for i in seg + 1:
				var a := -PI / 2 + TAU * cd_ratio * float(i) / seg
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, Color(0.02, 0.0, 0.06, 0.66))
			if fnt:
				var txt := ("%.1f" % cd_left) if cd_left < 1.0 else ("%d" % ceili(cd_left))
				draw_string_outline(fnt, Vector2(c.x - 40, c.y + 11), txt, HORIZONTAL_ALIGNMENT_CENTER, 80, 30, 6, Color(0, 0, 0))
				draw_string(fnt, Vector2(c.x - 40, c.y + 11), txt, HORIZONTAL_ALIGNMENT_CENTER, 80, 30, Color.WHITE)
		if fnt:
			# key badge
			var kw := maxf(34.0, key.length() * 12.0 + 18.0)
			var kr := Rect2(Vector2(c.x - kw * 0.5, c.y + r - 12.0), Vector2(kw, 24))
			var sb := StyleBoxFlat.new()
			sb.bg_color = col if is_ready else Color(0.28, 0.24, 0.38)
			sb.set_corner_radius_all(8)
			draw_style_box(sb, kr)
			draw_string(fnt, Vector2(kr.position.x, kr.position.y + 18), key, HORIZONTAL_ALIGNMENT_CENTER, kw, 16, Color(0.05, 0.02, 0.1))
			draw_string_outline(fnt, Vector2(0, size.y - 4), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, 5, Color(0.03, 0.01, 0.08))
			draw_string(fnt, Vector2(0, size.y - 4), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color.WHITE if is_ready else Color(0.7, 0.66, 0.8))

	func _icon(c: Vector2, s: float, k: Color) -> void:
		var w := 4.0
		match id:
			"dash":
				for o in [-0.45, 0.25]:
					draw_polyline(PackedVector2Array([c + Vector2(o * s - 0.3 * s, -0.6 * s), c + Vector2(o * s + 0.35 * s, 0), c + Vector2(o * s - 0.3 * s, 0.6 * s)]), k, w + 1.0, true)
			"hook":
				draw_arc(c + Vector2(0.1 * s, 0.2 * s), 0.45 * s, 0.2, PI + 0.6, 20, k, w + 1.0, true)
				draw_line(c + Vector2(0.55 * s, 0.25 * s), c + Vector2(0.55 * s, -0.75 * s), k, w + 1.0, true)
				draw_circle(c + Vector2(0.55 * s, -0.8 * s), w * 1.5, k)
				draw_line(c + Vector2(-0.35 * s, 0.3 * s), c + Vector2(-0.55 * s, 0.05 * s), k, w, true)
			"sky":
				for o in [0.3, -0.3]:
					draw_polyline(PackedVector2Array([c + Vector2(-0.55 * s, (o + 0.3) * s), c + Vector2(0, (o - 0.3) * s), c + Vector2(0.55 * s, (o + 0.3) * s)]), k, w + 1.0, true)
				draw_line(c + Vector2(-0.6 * s, 0.85 * s), c + Vector2(0.6 * s, 0.85 * s), Color(k, 0.5), w * 0.8, true)


# ============================================================ build
func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Montserrat", "Poppins", "Segoe UI", "Arial", "Noto Sans", "DejaVu Sans"])
	font.font_weight = 800
	font_reg = SystemFont.new()
	font_reg.font_names = font.font_names
	font_reg.font_weight = 500

	var post_layer := CanvasLayer.new()
	post_layer.layer = 1
	add_child(post_layer)
	var post := ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = POSTFX
	post.material = post_mat
	post_layer.add_child(post)

	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 24
	root.theme = th
	add_child(root)

	_build_hud()
	_build_menu()
	_build_pause()
	_build_over()


func _style(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 16, shadow := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	s.anti_aliasing = true
	if shadow:
		s.shadow_color = Color(0.02, 0.0, 0.06, 0.45)
		s.shadow_size = 12
		s.shadow_offset = Vector2(0, 5)
	return s


## Glass card with a coloured accent edge on the left.
func _card(accent: Color, bg := CARD) -> PanelContainer:
	var p := PanelContainer.new()
	var s := _style(bg, Color(accent, 0.28), 1, 14)
	s.border_width_left = 5
	s.border_color = Color(accent, 0.9)
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(text: String, size: int, color := Color.WHITE, outline := 0, f: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if f:
		l.add_theme_font_override("font", f)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.01, 0.12))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, col: Color, min_w := 320.0, h := 62.0, fs := 26) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(min_w, h)
	b.add_theme_font_size_override("font_size", fs)
	var n := _style(Color(0.09, 0.05, 0.18, 0.92), Color(col, 0.75), 2, 12, false)
	n.border_width_left = 6
	n.border_color = col
	var hv := _style(Color(col.r * 0.4, col.g * 0.3, col.b * 0.5, 0.96), col.lightened(0.3), 2, 12, false)
	hv.border_width_left = 10
	var pr := _style(col.darkened(0.15), Color.WHITE, 2, 12, false)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("disabled", _style(Color(0.1, 0.08, 0.14, 0.7), Color(0.3, 0.3, 0.35), 2, 12, false))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.48, 0.55))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT if min_w > 200 else HORIZONTAL_ALIGNMENT_CENTER
	b.mouse_entered.connect(func(): b.pivot_offset = b.size * 0.5; create_tween().tween_property(b, "scale", Vector2(1.03, 1.03), 0.08))
	b.mouse_exited.connect(func(): create_tween().tween_property(b, "scale", Vector2.ONE, 0.08))
	return b


func _chip(text: String, col := Color(0.95, 0.9, 1.0), fs := 18) -> PanelContainer:
	var p := PanelContainer.new()
	var s := _style(col, Color(0, 0, 0, 0), 0, 8, false)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", s)
	var l := _label(text, fs, INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.custom_minimum_size = Vector2(50, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# ------------------------------------------------------------ in-game HUD
func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)

	markers_layer = MarkerLayer.new()
	markers_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	markers_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	markers_layer.fnt = font
	hud.add_child(markers_layer)

	# score (top-left)
	var sp := _card(PINK)
	sp.position = Vector2(32, 28)
	hud.add_child(sp)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", -6)
	sp.add_child(sv)
	sv.add_child(_label("SCORE", 16, TEXT_DIM))
	score_lbl = _label("0", 56, Color.WHITE, 8)
	score_lbl.custom_minimum_size = Vector2(300, 0)
	sv.add_child(score_lbl)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	sv.add_child(row)
	dist_lbl = _label("0 m", 22, CYAN)
	row.add_child(dist_lbl)
	mult_chip = _chip("x1", GOLD)
	mult_lbl = mult_chip.get_child(0)
	row.add_child(mult_chip)

	# coins + power-ups (top-right)
	var right := VBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -32
	right.offset_right = -32
	right.offset_top = 28
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.add_theme_constant_override("separation", 10)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(right)
	var gp := _card(GOLD)
	right.add_child(gp)
	var gh := HBoxContainer.new()
	gh.add_theme_constant_override("separation", 12)
	gp.add_child(gh)
	coin_icon = CoinIcon.new()
	coin_icon.custom_minimum_size = Vector2(46, 46)
	gh.add_child(coin_icon)
	coin_lbl = _label("0", 46, GOLD, 8)
	coin_lbl.custom_minimum_size = Vector2(130, 0)
	coin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gh.add_child(coin_lbl)
	power_box = VBoxContainer.new()
	power_box.add_theme_constant_override("separation", 8)
	power_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(power_box)
	for id in ["magnet", "shield", "springs", "double"]:
		var pc := _card(Color.WHITE, Color(0.06, 0.045, 0.12, 0.7))
		pc.custom_minimum_size = Vector2(250, 0)
		var ph := HBoxContainer.new()
		ph.add_theme_constant_override("separation", 12)
		pc.add_child(ph)
		var ring := Ring.new()
		ring.id = id
		ring.custom_minimum_size = Vector2(44, 44)
		ph.add_child(ring)
		var pv := VBoxContainer.new()
		pv.add_theme_constant_override("separation", -4)
		ph.add_child(pv)
		var nm := _label("", 18, Color.WHITE)
		pv.add_child(nm)
		var tl := _label("", 16, TEXT_DIM)
		pv.add_child(tl)
		pc.visible = false
		power_box.add_child(pc)
		power_rows[id] = [pc, ring, nm, tl]

	# zone progress + speed (top-center)
	var top := VBoxContainer.new()
	top.anchor_left = 0.5
	top.anchor_right = 0.5
	top.offset_top = 28
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(top)
	var zr := HBoxContainer.new()
	zr.alignment = BoxContainer.ALIGNMENT_CENTER
	zr.add_theme_constant_override("separation", 14)
	top.add_child(zr)
	zone_lbl = _label("SKY ROADS", 24, Color.WHITE, 7)
	zr.add_child(zone_lbl)
	zone_next = _label("NEXT  ·  LANTERN FESTIVAL", 16, TEXT_DIM, 5)
	zr.add_child(zone_next)
	zone_bar = Bar.new()
	zone_bar.custom_minimum_size = Vector2(440, 12)
	top.add_child(zone_bar)
	speed_lbl = _label("0 KM/H", 20, Color(0.9, 0.9, 1.0), 6)
	speed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(speed_lbl)

	# vehicle card (bottom-left)
	veh_card = _card(Color(1.0, 0.6, 0.3))
	veh_card.anchor_top = 1.0
	veh_card.anchor_bottom = 1.0
	veh_card.offset_left = 32
	veh_card.offset_top = -40
	veh_card.offset_bottom = -40
	veh_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.add_child(veh_card)
	var vv := VBoxContainer.new()
	vv.add_theme_constant_override("separation", 6)
	veh_card.add_child(vv)
	vv.add_child(_label("RIDING", 14, TEXT_DIM))
	veh_name = _label("SKATEBOARD", 22, Color.WHITE)
	vv.add_child(veh_name)
	veh_pips = Pips.new()
	veh_pips.custom_minimum_size = Vector2(260, 12)
	vv.add_child(veh_pips)
	var ar := HBoxContainer.new()
	ar.add_theme_constant_override("separation", 10)
	vv.add_child(ar)
	ar.add_child(_label("ARMOR", 13, TEXT_DIM))
	veh_armor = Pips.new()
	veh_armor.custom_minimum_size = Vector2(120, 10)
	veh_armor.col = Color(0.4, 0.9, 1.0)
	veh_armor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ar.add_child(veh_armor)
	veh_card.visible = false

	popups = VBoxContainer.new()
	popups.anchor_left = 0.5
	popups.anchor_right = 0.5
	popups.offset_top = 170
	popups.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popups.alignment = BoxContainer.ALIGNMENT_BEGIN
	popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(popups)

	# abilities (bottom-center): flow meter + Q / E / SPACE x2
	var bottom := VBoxContainer.new()
	bottom.anchor_left = 0.5
	bottom.anchor_right = 0.5
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_bottom = -22
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.add_theme_constant_override("separation", 8)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bottom)
	flow_bar = Bar.new()
	flow_bar.custom_minimum_size = Vector2(430, 22)
	flow_bar.col_a = Color(0.6, 0.45, 1.0)
	flow_bar.col_b = PINK
	flow_bar.fnt = font
	flow_bar.ticks = [0.35, 0.7]
	bottom.add_child(flow_bar)
	var bar_panel := PanelContainer.new()
	var bs := _style(Color(0.05, 0.03, 0.1, 0.62), Color(0.6, 0.5, 1.0, 0.25), 1, 18)
	bar_panel.add_theme_stylebox_override("panel", bs)
	bar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(bar_panel)
	var hb := HBoxContainer.new()
	hb.name = "Slots"
	hb.add_theme_constant_override("separation", 22)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_panel.add_child(hb)

	prompt_lbl = _label("", 24, Color.WHITE, 8)
	prompt_lbl.anchor_left = 0.5
	prompt_lbl.anchor_right = 0.5
	prompt_lbl.anchor_top = 1.0
	prompt_lbl.anchor_bottom = 1.0
	prompt_lbl.offset_top = -250
	prompt_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(prompt_lbl)

	zone_box = VBoxContainer.new()
	zone_box.anchor_left = 0.5
	zone_box.anchor_right = 0.5
	zone_box.anchor_top = 0.3
	zone_box.anchor_bottom = 0.3
	zone_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	zone_box.add_theme_constant_override("separation", -10)
	zone_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(zone_box)
	zone_sub = _label("TRACK 2", 26, CYAN, 6)
	zone_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_box.add_child(zone_sub)
	zone_title = _label("SKY ROADS", 92, Color.WHITE, 18)
	zone_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_title.add_theme_color_override("font_shadow_color", Color(0.9, 0.2, 0.7, 0.8))
	zone_title.add_theme_constant_override("shadow_offset_x", 6)
	zone_title.add_theme_constant_override("shadow_offset_y", 8)
	zone_box.add_child(zone_title)
	zone_box.modulate.a = 0.0


func setup_abilities(abilities: Array) -> void:
	var hb: HBoxContainer = hud.find_child("Slots", true, false)
	for a in abilities:
		var s := AbilitySlot.new()
		s.id = a["id"]
		s.key = a["key"]
		s.col = a["color"]
		s.label = a["name"]
		s.fnt = font
		s.custom_minimum_size = Vector2(118, 118)
		hb.add_child(s)
		slots.append(s)


# ------------------------------------------------------------ main menu
func _build_menu() -> void:
	menu = Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(menu)

	var grad := Gradient.new()
	grad.set_color(0, Color(0.06, 0.02, 0.14, 0.9))
	grad.set_color(1, Color(0.06, 0.02, 0.14, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.anchor_bottom = 1.0
	tr.anchor_right = 0.6
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(tr)

	# top bar: wallet + best
	var topbar := HBoxContainer.new()
	topbar.anchor_left = 1.0
	topbar.anchor_right = 1.0
	topbar.offset_left = -40
	topbar.offset_right = -40
	topbar.offset_top = 32
	topbar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	topbar.add_theme_constant_override("separation", 14)
	menu.add_child(topbar)
	var bc := _card(PINK)
	topbar.add_child(bc)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", -4)
	bc.add_child(bv)
	bv.add_child(_label("BEST SCORE", 14, TEXT_DIM))
	menu_best = _label("0", 30, Color.WHITE)
	bv.add_child(menu_best)
	var wc := _card(GOLD)
	topbar.add_child(wc)
	var wh := HBoxContainer.new()
	wh.add_theme_constant_override("separation", 10)
	wc.add_child(wh)
	var ci := CoinIcon.new()
	ci.custom_minimum_size = Vector2(40, 40)
	wh.add_child(ci)
	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", -4)
	wh.add_child(wv)
	wv.add_child(_label("COINS", 14, TEXT_DIM))
	wallet_lbl = _label("0", 30, GOLD)
	wv.add_child(wallet_lbl)

	# left column: logo, buttons, track + runner pickers
	menu_col = VBoxContainer.new()
	menu_col.anchor_top = 0.5
	menu_col.anchor_bottom = 0.5
	menu_col.offset_left = 96
	menu_col.grow_vertical = Control.GROW_DIRECTION_BOTH
	menu_col.add_theme_constant_override("separation", 10)
	menu.add_child(menu_col)
	menu_col.add_child(_label("ENDLESS  SKY  RUNNER", 22, CYAN, 5))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -40)
	menu_col.add_child(tv)
	var t1 := _label("SKYLINE", 132, PINK, 20)
	t1.add_theme_color_override("font_shadow_color", Color(0.35, 0.1, 0.6, 0.9))
	t1.add_theme_constant_override("shadow_offset_x", 7)
	t1.add_theme_constant_override("shadow_offset_y", 9)
	tv.add_child(t1)
	var t2 := _label("RUSH", 132, CYAN, 20)
	t2.add_theme_color_override("font_shadow_color", Color(0.1, 0.25, 0.6, 0.9))
	t2.add_theme_constant_override("shadow_offset_x", 7)
	t2.add_theme_constant_override("shadow_offset_y", 9)
	tv.add_child(t2)
	menu_col.add_child(_gap(8))
	var play := _button("▶   PLAY                       SPACE", PINK, 470, 76, 32)
	play.pressed.connect(func(): play_pressed.emit())
	menu_col.add_child(play)
	# top navigation bar
	nav = HBoxContainer.new()
	nav.offset_left = 96
	nav.offset_top = 30
	nav.add_theme_constant_override("separation", 8)
	menu.add_child(nav)
	for it in [["GARAGE", "G", Color(1.0, 0.6, 0.3), "garage"], ["UPGRADES", "U", GOLD, "upgrades"], ["CONTROLS", "TAB", CYAN, "controls"], ["QUIT", "", Color(0.6, 0.5, 0.9), "quit"]]:
		var nb := _button(it[0] + (("   " + it[1]) if it[1] != "" else ""), it[2], 150, 46, 18)
		nb.alignment = HORIZONTAL_ALIGNMENT_CENTER
		var id: String = it[3]
		nb.pressed.connect(func():
			if id == "controls":
				toggle_controls()
			elif id == "quit":
				quit_pressed.emit()
			else:
				panel_requested.emit(id))
		nav.add_child(nb)
	menu_col.add_child(_gap(8))
	# track picker
	var tp := _card(CYAN)
	menu_col.add_child(tp)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 12)
	tp.add_child(th)
	var prev := _button("<", CYAN, 54, 54, 26)
	prev.pressed.connect(func(): track_changed.emit(-1))
	th.add_child(prev)
	var tsv := VBoxContainer.new()
	tsv.custom_minimum_size = Vector2(300, 0)
	tsv.add_theme_constant_override("separation", -4)
	th.add_child(tsv)
	track_num = _label("TRACK 1 / 9  ·  A / D", 14, TEXT_DIM)
	tsv.add_child(track_num)
	var tn := HBoxContainer.new()
	tn.add_theme_constant_override("separation", 10)
	tsv.add_child(tn)
	track_swatch = ColorRect.new()
	track_swatch.custom_minimum_size = Vector2(10, 30)
	track_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tn.add_child(track_swatch)
	track_name = _label("SKY ROADS", 30, Color.WHITE)
	tn.add_child(track_name)
	track_hint = _label("", 14, Color(1.0, 0.7, 0.4))
	tsv.add_child(track_hint)
	var nxt := _button(">", CYAN, 54, 54, 26)
	nxt.pressed.connect(func(): track_changed.emit(1))
	th.add_child(nxt)
	# runner picker
	var cp := _card(PINK)
	menu_col.add_child(cp)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 12)
	cp.add_child(ch)
	var cprev := _button("<", PINK, 54, 54, 26)
	cprev.pressed.connect(func(): char_changed.emit(-1))
	ch.add_child(cprev)
	var cv := VBoxContainer.new()
	cv.custom_minimum_size = Vector2(300, 0)
	cv.add_theme_constant_override("separation", -4)
	ch.add_child(cv)
	char_hobby = _label("RUNNER 1 / 6  ·  Q / E", 14, TEXT_DIM)
	cv.add_child(char_hobby)
	char_name = _label("HOOPS", 30, Color.WHITE)
	cv.add_child(char_name)
	var cnext := _button(">", PINK, 54, 54, 26)
	cnext.pressed.connect(func(): char_changed.emit(1))
	ch.add_child(cnext)

	# upgrade summary card (bottom right): every upgradable part at a glance
	upg_card = _card(GOLD, Color(0.05, 0.035, 0.11, 0.88))
	upg_card.anchor_left = 1.0
	upg_card.anchor_right = 1.0
	upg_card.anchor_top = 1.0
	upg_card.anchor_bottom = 1.0
	upg_card.offset_right = -40
	upg_card.offset_left = -40
	upg_card.offset_bottom = -36
	upg_card.offset_top = -36
	upg_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	upg_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	upg_card.custom_minimum_size = Vector2(380, 0)
	menu.add_child(upg_card)
	var uv := VBoxContainer.new()
	uv.add_theme_constant_override("separation", 6)
	upg_card.add_child(uv)
	var uh := HBoxContainer.new()
	uv.add_child(uh)
	var ut := _label("YOUR UPGRADES", 20, GOLD)
	ut.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uh.add_child(ut)
	var ub := _button("SHOP   U", GOLD, 110, 36, 15)
	ub.alignment = HORIZONTAL_ALIGNMENT_CENTER
	ub.pressed.connect(func(): panel_requested.emit("upgrades"))
	uh.add_child(ub)
	upg_list = VBoxContainer.new()
	upg_list.add_theme_constant_override("separation", 4)
	uv.add_child(upg_list)

	_build_side_panel()
	_build_controls()


func _build_side_panel() -> void:
	side_panel = PanelContainer.new()
	side_panel.add_theme_stylebox_override("panel", _style(Color(0.05, 0.03, 0.11, 0.93), Color(1, 1, 1, 0.12), 1, 20))
	side_panel.anchor_top = 0.5
	side_panel.anchor_bottom = 0.5
	side_panel.offset_left = 70
	side_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	side_panel.custom_minimum_size = Vector2(800, 0)
	side_panel.visible = false
	menu.add_child(side_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	side_panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	side_title = _label("GARAGE", 44, Color.WHITE, 6)
	side_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(side_title)
	side_wallet = _label("0", 28, GOLD)
	head.add_child(side_wallet)
	var back := _button("BACK   ESC", Color(0.6, 0.5, 0.9), 150, 48, 18)
	back.pressed.connect(func(): panel_requested.emit(""))
	head.add_child(back)
	side_body = VBoxContainer.new()
	side_body.add_theme_constant_override("separation", 10)
	v.add_child(side_body)


func _build_controls() -> void:
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", _style(Color(0.05, 0.03, 0.11, 0.93), Color(0.4, 0.9, 1.0, 0.35), 1, 20))
	controls_panel = cp
	cp.visible = false
	cp.anchor_left = 1.0
	cp.anchor_right = 1.0
	cp.anchor_top = 0.5
	cp.anchor_bottom = 0.5
	cp.offset_right = -60
	cp.offset_left = -60
	cp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	cp.grow_vertical = Control.GROW_DIRECTION_BOTH
	menu.add_child(cp)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	cp.add_child(cv)
	cv.add_child(_label("CONTROLS", 30, CYAN))
	var rows := [
		["A / D", "Switch lane", Color(0.92, 0.88, 1.0)],
		["W / SPACE", "Jump  -  press again in the air: double jump", Color(0.92, 0.88, 1.0)],
		["S", "Slide   ·   in the air: GROUND SLAM", Color(0.92, 0.88, 1.0)],
		["Q", "DASH  -  burst forward, smash crates  (air: AIR DASH)", PINK],
		["E", "HOOK  -  grapple anchors, quarter-pipes, wall runs", GREEN],
		["SPACE x2", "SKY JUMP  -  double-tap fast to launch up high", Color(0.45, 0.75, 1.0)],
		["SKATE PARK", "swerve into a quarter-pipe  -  360 air!", Color(0.3, 0.7, 1.0)],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	cv.add_child(grid)
	for r in rows:
		grid.add_child(_chip(r[0], r[2]))
		grid.add_child(_label(r[1], 19, Color.WHITE, 0, font_reg))
	cv.add_child(_gap(4))
	cv.add_child(_label("POWER-UPS ON THE TRACK", 20, GOLD))
	var pg := GridContainer.new()
	pg.columns = 2
	pg.add_theme_constant_override("h_separation", 16)
	pg.add_theme_constant_override("v_separation", 6)
	cv.add_child(pg)
	for r in [["MAGNET", "pulls coins to you", Color(1.0, 0.4, 0.45)], ["SHIELD", "smash through anything", CYAN],
			["SPRINGS", "super-high jumps", Color(0.4, 1.0, 0.55)], ["2X", "double score + coins", GOLD]]:
		pg.add_child(_chip(r[0], r[2]))
		pg.add_child(_label(r[1], 18, Color.WHITE, 0, font_reg))
	cv.add_child(_gap(4))
	cv.add_child(_label("Your garage ride is handed to you when you enter its map, for RIDE TIME seconds (ride tokens refill it):\nskateboard - SKATE PARK  ·  hover - HOVER HARBOR  ·  moto - TURBO HIGHWAY\nESC pause  ·  M music  ·  F11 fullscreen  ·  gamepad supported", 16, TEXT_DIM, 0, font_reg))


func _center_panel(border: Color) -> VBoxContainer:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.01, 0.1, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(dim)
	var p := PanelContainer.new()
	var st := _style(Color(0.06, 0.035, 0.13, 0.95), Color(border, 0.5), 2, 22)
	st.border_width_top = 6
	st.border_color = border
	st.content_margin_left = 40
	st.content_margin_right = 40
	st.content_margin_top = 26
	st.content_margin_bottom = 26
	p.add_theme_stylebox_override("panel", st)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(640, 0)
	holder.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	holder.set_meta("panel", p)
	root.add_child(holder)
	v.set_meta("holder", holder)
	return v


func _build_pause() -> void:
	var v := _center_panel(CYAN)
	pause_panel = v.get_meta("holder")
	var t := _label("PAUSED", 68, CYAN, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b1 := _button("RESUME            ESC", CYAN, 440)
	b1.pressed.connect(func(): resume_pressed.emit())
	v.add_child(b1)
	var b2 := _button("RESTART", PINK, 440)
	b2.pressed.connect(func(): retry_pressed.emit())
	v.add_child(b2)
	var b3 := _button("MAIN MENU", Color(0.6, 0.5, 0.9), 440)
	b3.pressed.connect(func(): menu_pressed.emit())
	v.add_child(b3)
	for b in [b1, b2, b3]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _build_over() -> void:
	var v := _center_panel(PINK)
	over = v.get_meta("holder")
	over_title = _label("WIPED OUT", 70, PINK, 12)
	over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(over_title)
	over_badge = _chip("NEW BEST!", GOLD, 22)
	over_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(over_badge)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 90)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(grid)
	for k in ["SCORE", "DISTANCE", "COINS", "CLOSE CALLS", "BEST"]:
		grid.add_child(_label(k, 24, TEXT_DIM))
		var val := _label("0", 28, Color.WHITE)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(val)
		over_vals[k] = val
	over_vals["SCORE"].add_theme_color_override("font_color", PINK)
	over_vals["COINS"].add_theme_color_override("font_color", GOLD)
	over_bank = _label("", 20, GOLD)
	over_bank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(over_bank)
	over_revive = _button("REVIVE   R", GOLD, 560)
	over_revive.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	over_revive.pressed.connect(func(): revive_pressed.emit())
	v.add_child(over_revive)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(hb)
	var b1 := _button("RUN AGAIN   SPACE", PINK, 320)
	b1.pressed.connect(func(): retry_pressed.emit())
	hb.add_child(b1)
	var b2 := _button("MENU   ESC", Color(0.6, 0.5, 0.9), 220)
	b2.pressed.connect(func(): menu_pressed.emit())
	hb.add_child(b2)


# ============================================================ screens
func show_menu(best: int, wallet: int) -> void:
	menu.visible = true
	hud.visible = false
	pause_panel.visible = false
	over.visible = false
	menu_best.text = _fmt(best)
	set_wallet(wallet)
	show_panel("", {})
	menu.modulate.a = 0.0
	create_tween().tween_property(menu, "modulate:a", 1.0, 0.5)


func set_upgrade_summary(d: Dictionary) -> void:
	for c in upg_list.get_children():
		c.queue_free()
	for r in d["rows"]:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		upg_list.add_child(hb)
		var nm := _label(String(r["name"]).split("  ")[0], 14, Color.WHITE, 0, font_reg)
		nm.custom_minimum_size = Vector2(150, 0)
		hb.add_child(nm)
		var pp := Pips.new()
		pp.count = r["max"]
		pp.filled = r["level"]
		pp.col = r["color"]
		pp.custom_minimum_size = Vector2(130, 9)
		pp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(pp)
		var val := _label("%s%s" % [_num(r["now"]), r["unit"]], 14, TEXT_DIM, 0, font_reg)
		hb.add_child(val)


func set_wallet(n: int) -> void:
	wallet_lbl.text = _fmt(n)
	side_wallet.text = "●  " + _fmt(n)


func toggle_controls() -> void:
	controls_panel.visible = not controls_panel.visible
	upg_card.visible = not controls_panel.visible and cur_panel == ""


## Garage / upgrades overlay on the left (the lobby character stays visible).
func show_panel(p: String, data: Dictionary) -> void:
	cur_panel = p
	side_panel.visible = p != ""
	menu_col.visible = p == ""
	nav.visible = p == ""
	upg_card.visible = p == ""
	if p != "":
		controls_panel.visible = false
	for c in side_body.get_children():
		c.queue_free()
	if data.has("wallet"):
		set_wallet(data["wallet"])
	match p:
		"garage":
			_fill_garage(data)
		"upgrades":
			_fill_upgrades(data)


func _fill_garage(d: Dictionary) -> void:
	side_title.text = "GARAGE"
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	side_body.add_child(tabs)
	for t in d["types"]:
		var on: bool = t == d["type"]
		var b := _button(d["type_names"][t], Color(1.0, 0.6, 0.3) if on else Color(0.5, 0.45, 0.7), 240, 50, 18)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		if on:
			b.add_theme_stylebox_override("normal", _style(Color(1.0, 0.6, 0.3), Color.WHITE, 2, 12, false))
			b.add_theme_color_override("font_color", INK)
		b.pressed.connect(func(): garage_tab.emit(t))
		tabs.add_child(b)
	side_body.add_child(_label("Your ride in  %s   ·   A / D switch type   ·   click to buy / equip" % d["zones"][d["type"]], 16, TEXT_DIM, 0, font_reg))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	side_body.add_child(grid)
	var items: Array = d["items"]
	for i in items.size():
		var it: Dictionary = items[i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(375, 62)
		var col: Color = it["color"]
		var bgc := Color(0.1, 0.06, 0.18, 0.95)
		var st := _style(bgc, Color(col, 0.5), 2, 12, false)
		st.border_width_left = 14
		st.border_color = col
		if it["selected"]:
			st.border_color = col
			st.bg_color = Color(col.r * 0.3, col.g * 0.3, col.b * 0.35, 0.95)
			st.border_width_top = 2
			st.border_width_right = 2
			st.border_width_bottom = 2
		var hv := st.duplicate()
		hv.bg_color = Color(col.r * 0.35, col.g * 0.3, col.b * 0.45, 0.98)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", hv)
		b.add_theme_stylebox_override("pressed", hv)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var hb := HBoxContainer.new()
		hb.set_anchors_preset(Control.PRESET_FULL_RECT)
		hb.offset_left = 26
		hb.offset_right = -14
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hb)
		var nm := _label(it["name"], 22, Color.WHITE)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(nm)
		var status: Control
		if it["equipped"]:
			status = _chip("EQUIPPED", GREEN, 15)
		elif it["owned"]:
			status = _chip("OWNED", Color(0.8, 0.78, 0.95), 15)
		else:
			status = _chip("●  " + _fmt(it["price"]), GOLD if d["wallet"] >= it["price"] else Color(0.55, 0.5, 0.55), 15)
		status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(status)
		b.pressed.connect(func(): garage_item.emit(i))
		grid.add_child(b)


func _fill_upgrades(d: Dictionary) -> void:
	side_title.text = "UPGRADES"
	side_body.add_child(_label("Spend the coins you collect on longer power-ups, faster abilities and tougher rides.", 16, TEXT_DIM, 0, font_reg))
	for r in d["rows"]:
		var card := _card(r["color"], Color(0.09, 0.06, 0.17, 0.95))
		side_body.add_child(card)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 16)
		card.add_child(hb)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(v)
		v.add_child(_label(r["name"], 22, Color.WHITE))
		var nowt := "%s%s" % [_num(r["now"]), r["unit"]]
		var nxtt := ("   →   %s%s" % [_num(r["next"]), r["unit"]]) if r["level"] < r["max"] else "   ·   MAX"
		v.add_child(_label(r["desc"] + "   ·   " + nowt + nxtt, 15, TEXT_DIM, 0, font_reg))
		var pips := Pips.new()
		pips.count = r["max"]
		pips.filled = r["level"]
		pips.col = r["color"]
		pips.custom_minimum_size = Vector2(220, 10)
		v.add_child(pips)
		var cost: int = r["cost"]
		var b := _button("MAX" if cost < 0 else ("●  " + _fmt(cost)), GOLD, 150, 52, 20)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.disabled = cost < 0 or d["wallet"] < cost
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var id: String = r["id"]
		b.pressed.connect(func(): upgrade_buy.emit(id))
		hb.add_child(b)


func _num(v) -> String:
	var f := float(v)
	return ("%d" % int(f)) if is_equal_approx(f, roundf(f)) else ("%.1f" % f)


func set_character(name: String, hobby: String, idx: int, total: int) -> void:
	char_name.text = name
	char_hobby.text = "RUNNER %d / %d  ·  %s  ·  Q / E" % [idx + 1, total, hobby.to_upper()]
	_pop(char_name)


func set_track(name: String, idx: int, total: int, hint := "", accent := CYAN) -> void:
	track_name.text = name
	track_num.text = "TRACK %d / %d  ·  A / D" % [idx + 1, total]
	track_hint.text = hint
	track_hint.visible = hint != ""
	track_swatch.color = accent
	_pop(track_name)


func _pop(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(1.15, 1.15)
	c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


func show_game() -> void:
	menu.visible = false
	over.visible = false
	pause_panel.visible = false
	hud.visible = true
	hud.modulate.a = 0.0
	create_tween().tween_property(hud, "modulate:a", 1.0, 0.4)
	for c in popups.get_children():
		c.queue_free()
	_last_mult = 1


func show_pause(on: bool) -> void:
	pause_panel.visible = on


func show_over(d: Dictionary) -> void:
	over.visible = true
	over_title.text = d["title"]
	over_vals["SCORE"].text = _fmt(d["score"])
	over_vals["DISTANCE"].text = "%s m" % _fmt(d["distance"])
	over_vals["COINS"].text = "+%s" % _fmt(d["gold"])
	over_vals["CLOSE CALLS"].text = "%d" % d["close"]
	over_vals["BEST"].text = _fmt(d["best"])
	over_bank.text = "COINS BANKED  ·  WALLET  %s" % _fmt(d.get("wallet", 0))
	over_badge.visible = d["new_best"]
	over_revive.visible = d.get("revive", false)
	over_revive.text = "REVIVE   R      ·      ● %s" % _fmt(d.get("revive_cost", 100))
	var p: Control = over.get_meta("panel")
	p.pivot_offset = p.size * 0.5
	p.scale = Vector2(0.85, 0.85)
	over.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(over, "modulate:a", 1.0, 0.3)
	tw.tween_property(p, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_over_visible() -> bool:
	return over.visible


# ============================================================ runtime updates
func update_hud(d: Dictionary) -> void:
	score_lbl.text = _fmt(d["score"])
	dist_lbl.text = "%s m" % _fmt(d["dist"])
	var mult: int = d["mult"]
	mult_lbl.text = "x%d" % mult
	if mult != _last_mult:
		_last_mult = mult
		mult_chip.pivot_offset = mult_chip.size * 0.5
		mult_chip.scale = Vector2(1.5, 1.5)
		create_tween().tween_property(mult_chip, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	coin_lbl.text = _fmt(d["coins"])
	speed_lbl.text = "%d KM/H" % d["kmh"]
	zone_lbl.text = d["zone"]
	zone_lbl.add_theme_color_override("font_color", d["accent"])
	zone_next.text = "NEXT  ·  " + d["next_zone"]
	zone_bar.value = d["zone_prog"]
	zone_bar.col_a = d["accent"]
	zone_bar.col_b = Color.WHITE
	zone_bar.queue_redraw()
	var flow: float = d["flow"]
	var tier: int = d["flow_tier"]
	flow_bar.value = flow / 100.0
	flow_bar.text = "FLOW  %d%%%s" % [int(flow), ("   ·   SCORE  +%d" % tier) if tier > 0 else ""]
	flow_bar.glow = (0.5 + 0.5 * sin(_t * 8.0)) if tier >= 2 else 0.0
	flow_bar.queue_redraw()
	var ab: Array = d["abilities"]
	for i in slots.size():
		var s: AbilitySlot = slots[i]
		var a: Dictionary = ab[i]
		if a["ready"] and not s.is_ready:
			s.bump = 1.0
		s.is_ready = a["ready"]
		s.cd_ratio = a["cd_ratio"]
		s.cd_left = a["cd_left"]
		s.active_ratio = a["active_ratio"]
		s.label = a["label"]
		s.queue_redraw()
	var active := {}
	for p in d["powers"]:
		active[p["id"]] = p
	for id in power_rows:
		var row: Array = power_rows[id]
		var on := active.has(id)
		row[0].visible = on
		if on:
			var p: Dictionary = active[id]
			var ring: Ring = row[1]
			ring.ratio = p["t"] / maxf(p["max"], 0.01)
			ring.col = p["color"]
			ring.queue_redraw()
			row[2].text = p["name"]
			row[3].text = "%.1f s" % p["t"]
			var sb: StyleBoxFlat = row[0].get_theme_stylebox("panel")
			sb.border_color = p["color"]
	var veh = d["vehicle"]
	veh_card.visible = veh != null
	if veh != null:
		veh_name.text = "%s     %ds" % [veh["name"], ceili(veh["time"])]
		veh_pips.progress = clampf(veh["time"] / maxf(veh["time_max"], 1.0), 0.0, 1.0)
		veh_pips.col = Color(1.0, 0.3, 0.3) if veh["time"] < 5.0 else Color(1.0, 0.6, 0.3)
		veh_pips.queue_redraw()
		veh_armor.count = maxi(1, veh["max"])
		veh_armor.filled = veh["hits"]
		veh_armor.queue_redraw()


func slot_used(i: int) -> void:
	if i < slots.size():
		slots[i].bump = 1.0


func slot_deny(i: int) -> void:
	if i < slots.size():
		slots[i].deny = 0.35


func gold_pop() -> void:
	_coin_pop = 1.0


func popup(text: String, color: Color, size := 44) -> void:
	var l := _label(text, size, color, 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popups.add_child(l)
	if popups.get_child_count() > 4:
		popups.get_child(0).queue_free()
	l.pivot_offset = Vector2(350, size * 0.6)
	l.custom_minimum_size = Vector2(700, 0)
	l.scale = Vector2(1.5, 1.5)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


func flash(color: Color, amount: float) -> void:
	_flash_color = color
	_flash = maxf(_flash, amount)


func set_post(aberration: float, tint_amount: float, blur := 0.0, tint := Color(0.6, 0.8, 1.0)) -> void:
	post_mat.set_shader_parameter("aberration", aberration)
	post_mat.set_shader_parameter("tint_amount", tint_amount)
	post_mat.set_shader_parameter("radial_blur", blur)
	post_mat.set_shader_parameter("tint", tint)


func set_markers(list: Array) -> void:
	markers_layer.markers = list
	markers_layer.queue_redraw()


func set_prompt(text: String) -> void:
	if prompt_lbl.text != text:
		prompt_lbl.text = text
		prompt_lbl.modulate.a = 0.0
		if text != "":
			prompt_lbl.create_tween().tween_property(prompt_lbl, "modulate:a", 1.0, 0.2)


func zone_banner(title: String, sub: String) -> void:
	zone_title.text = title
	zone_sub.text = sub
	zone_box.pivot_offset = Vector2(zone_box.size.x * 0.5, 60)
	zone_box.scale = Vector2(1.4, 1.4)
	zone_box.modulate.a = 0.0
	var tw := zone_box.create_tween()
	tw.set_parallel(true)
	tw.tween_property(zone_box, "modulate:a", 1.0, 0.35)
	tw.tween_property(zone_box, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.8)
	tw.chain().tween_property(zone_box, "modulate:a", 0.0, 0.6)


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 2.5)
	post_mat.set_shader_parameter("flash", _flash)
	post_mat.set_shader_parameter("flash_color", _flash_color)
	_coin_pop = maxf(0.0, _coin_pop - delta * 6.0)
	if markers_layer and not markers_layer.markers.is_empty():
		markers_layer.t = _t
		markers_layer.queue_redraw()
	if coin_icon:
		coin_icon.pop = _coin_pop
		coin_icon.queue_redraw()
	for s in slots:
		if s.bump > 0.0 or s.deny > 0.0:
			s.bump = maxf(0.0, s.bump - delta * 3.0)
			s.deny = maxf(0.0, s.deny - delta)
			s.queue_redraw()


func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out
