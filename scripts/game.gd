extends Node2D
## Main game controller: board layout, input, pour animation, UI and saving.

const SAVE_PATH := "user://save.cfg"
const TOP_UI := 170.0
const BOTTOM_UI := 170.0
const LIFT := 34.0

var level := 1
var capacity := 4
var initial_state: Array = []
var state: Array = []
var history: Array = []
var bottles: Array[Bottle] = []
var selected := -1
var busy := false
var extra_used := false
var moves_made := 0
var target_moves := 0
var hint_used := false
var elapsed := 0.0
var timer_running := false
var window_focused := true
var shelves: Array[Rect2] = []

var stream: Line2D
var splash: CPUParticles2D
var confetti: CPUParticles2D
var level_label: Label
var sub_label: Label
var toast: Label
var undo_btn: Button
var add_btn: Button
var hint_btn: Button
var sound_btn: Button
var win_layer: Control
var win_title: Label
var win_stars: Control
var win_stats: Label
var win_best: Label
var best_box: Control
var best_time_label: Label
var best_stars := 0
var earned_stars := 0
var star_pop: Array[float] = [0.0, 0.0, 0.0]


func _ready() -> void:
	_load()
	stream = Line2D.new()
	stream.z_index = 9
	stream.begin_cap_mode = Line2D.LINE_CAP_ROUND
	stream.end_cap_mode = Line2D.LINE_CAP_ROUND
	stream.visible = false
	stream.antialiased = true
	var taper := Curve.new()
	taper.add_point(Vector2(0, 1.0))
	taper.add_point(Vector2(1, 0.65))
	stream.width_curve = taper
	add_child(stream)
	splash = CPUParticles2D.new()
	splash.z_index = 9
	splash.emitting = false
	splash.amount = 28
	splash.lifetime = 0.35
	splash.direction = Vector2(0, -1)
	splash.spread = 55
	splash.gravity = Vector2(0, 1400)
	splash.initial_velocity_min = 140
	splash.initial_velocity_max = 260
	var drop := GradientTexture2D.new()
	drop.width = 16
	drop.height = 16
	drop.fill = GradientTexture2D.FILL_RADIAL
	drop.fill_from = Vector2(0.5, 0.5)
	drop.fill_to = Vector2(1.0, 0.5)
	drop.gradient = Gradient.new()
	drop.gradient.set_color(0, Color.WHITE)
	drop.gradient.set_color(1, Color(1, 1, 1, 0))
	drop.gradient.set_offset(0, 0.55)
	splash.texture = drop
	add_child(splash)
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	start_level(level)


# ---------------------------------------------------------------- levels

func start_level(n: int) -> void:
	level = maxi(n, 1)
	var data := LevelGenerator.generate(level)
	capacity = data.capacity
	initial_state = data.state.duplicate()
	target_moves = data.solution.size()
	_reset_board()


func restart_level() -> void:
	if busy:
		return
	_reset_board()


func _reset_board() -> void:
	var best := _load_best(level)
	best_box.visible = not best.is_empty()
	if best_box.visible:
		best_stars = best.stars
		best_time_label.text = "Best " + Scoring.format_time(best.time)
		best_box.queue_redraw()
	state = initial_state.duplicate()
	history.clear()
	extra_used = false
	selected = -1
	moves_made = 0
	hint_used = false
	elapsed = 0.0
	timer_running = false
	busy = false
	win_layer.hide()
	_rebuild_bottles()
	_update_ui()


func _rebuild_bottles() -> void:
	for b in bottles:
		b.queue_free()
	bottles.clear()
	for i in state.size():
		var b := Bottle.new()
		b.capacity = capacity
		b.set_layers(state[i])
		add_child(b)
		bottles.append(b)
	_layout()


func _refresh_bottles() -> void:
	for i in bottles.size():
		bottles[i].set_layers(state[i])
		bottles[i].hint = false


# ---------------------------------------------------------------- layout

func _layout() -> void:
	var vs := get_viewport_rect().size
	var n := bottles.size()
	if n == 0:
		return
	var avail := Vector2(vs.x - 32, vs.y - TOP_UI - BOTTOM_UI)
	var proto := bottles[0]
	var cell := Vector2(Bottle.W + 28, proto.total_h() + 78)
	var best_s := 0.0
	var rows := 1
	for r in range(1, n + 1):
		var per := ceili(n / float(r))
		var s := minf(avail.x / (per * cell.x), avail.y / (r * cell.y))
		if s > best_s:
			best_s = s
			rows = r
	var s := minf(best_s, 1.5)
	var grid_h := rows * cell.y * s
	var y0 := TOP_UI + (avail.y - grid_h) / 2
	shelves.clear()
	var idx := 0
	var base := n / rows
	var extra := n % rows
	for r in rows:
		var count := base + (1 if r < extra else 0)
		var row_w := count * cell.x * s
		var x0 := (vs.x - row_w) / 2 + cell.x * s / 2
		var yb := y0 + (r + 1) * cell.y * s - 26 * s
		for c in count:
			var b := bottles[idx]
			b.scale = Vector2(s, s)
			b.home_pos = Vector2(x0 + c * cell.x * s, yb)
			b.position = b.home_pos - Vector2(0, LIFT * s if idx == selected else 0.0)
			b.rotation = 0
			idx += 1
		shelves.append(Rect2((vs.x - row_w) / 2 - 6 * s, yb - 2 * s, row_w + 12 * s, 20 * s))
	queue_redraw()


func _draw() -> void:
	for r in shelves:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("c98b62")
		sb.border_width_bottom = int(maxf(4, r.size.y * 0.35))
		sb.border_color = Color("9a6446")
		sb.set_corner_radius_all(int(r.size.y * 0.35))
		sb.shadow_color = Color(0, 0, 0, 0.25)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 4)
		draw_style_box(sb, r)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if busy or win_layer.visible:
			return
		_on_tap(_bottle_at(get_global_mouse_position()))
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Z, KEY_BACKSPACE:
				undo()
			KEY_R:
				restart_level()
			KEY_H:
				show_hint()
			KEY_M:
				_toggle_sound()
			KEY_N:
				if OS.is_debug_build():
					start_level(level + 1)


func _bottle_at(p: Vector2) -> int:
	for i in bottles.size():
		if bottles[i].hit_rect().has_point(bottles[i].to_local(p)):
			return i
	return -1


func _on_tap(idx: int) -> void:
	if idx == -1:
		_select(-1)
		return
	if selected == -1:
		if state[idx].is_empty() or WaterSolver.is_complete(state[idx], capacity):
			_shake(idx)
			return
		_select(idx)
	elif selected == idx:
		Sfx.play("deselect", Sfx.bottle_pitch(String(state[idx]).length(), capacity, 1))
		_select(-1)
	else:
		var amt := WaterSolver.pour_amount(state, selected, idx, capacity)
		if amt > 0:
			_pour(selected, idx, amt)
		elif not state[idx].is_empty() and not WaterSolver.is_complete(state[idx], capacity):
			_select(idx)
		else:
			_shake(idx)
			_select(-1)


func _select(idx: int) -> void:
	if selected != -1 and selected != idx:
		var old := bottles[selected]
		create_tween().tween_property(old, "position", old.home_pos, 0.12)
	selected = idx
	if idx != -1:
		Sfx.play("select", _bottle_pitch(idx))
		var b := bottles[idx]
		create_tween().tween_property(b, "position", b.home_pos - Vector2(0, LIFT * b.scale.y), 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _bottle_pitch(idx: int) -> float:
	return Sfx.bottle_pitch(String(state[idx]).length(), capacity)


func _shake(idx: int) -> void:
	Sfx.play("invalid")
	var b := bottles[idx]
	var p := b.position
	var tw := create_tween()
	for dx in [8.0, -8.0, 5.0, -5.0, 0.0]:
		tw.tween_property(b, "position", p + Vector2(dx * b.scale.x, 0), 0.04)


# ---------------------------------------------------------------- pouring

func _pour(i: int, j: int, amt: int) -> void:
	busy = true
	_clear_hint()
	history.append(state.duplicate())
	var src := bottles[i]
	var dst := bottles[j]
	var src_str: String = state[i]
	var color := Bottle.PALETTE[(src_str.unicode_at(src_str.length() - 1) - 65) % Bottle.PALETTE.size()]
	var src_len := src_str.length()
	state = WaterSolver.apply_move(state, i, j, amt)
	var dst_len: int = String(state[j]).length()
	selected = -1
	moves_made += 1
	timer_running = true
	_update_ui()

	dst.set_layers(state[j])
	dst.corked = false
	dst.visual_level = dst_len - amt

	var s := src.scale.x
	var dir := 1.0 if dst.home_pos.x >= src.home_pos.x else -1.0
	# Fuller bottles start pouring at a shallower angle and tip further as they empty.
	var a_start := dir * _tilt_for(src_len, src.capacity)
	var a_end := dir * _tilt_for(src_len - amt, src.capacity)
	var mouth_target := dst.home_pos + dst.mouth_local() * dst.scale.x + Vector2(-dir * 4 * s, -24 * s)
	var mouth_off := src.mouth_local() * s
	var start_pos := src.position
	var start_rot := src.rotation
	var pour_pos := mouth_target - mouth_off.rotated(a_start)
	var apex := (start_pos + pour_pos) * 0.5 + Vector2(0, -70 * s)
	var pour_time := 0.3 + 0.12 * amt
	src.z_index = 10
	stream.default_color = color
	stream.width = 10 * s
	splash.color = color
	splash.scale_amount_min = 0.35 * s
	splash.scale_amount_max = 0.7 * s

	var tw := create_tween()
	# 1. Swing over on an arc while tilting to the starting angle.
	tw.tween_method(func(t: float) -> void:
		var e := ease(t, -1.8)
		src.position = _bezier(start_pos, apex, pour_pos, e)
		src.rotation = lerpf(start_rot, a_start, e), 0.0, 1.0, 0.34)
	# 2. Pour: keep the mouth pinned above the target while tipping further.
	tw.tween_method(func(t: float) -> void:
		var ang := lerpf(a_start, a_end, ease(t, -1.4))
		src.rotation = ang
		src.position = mouth_target - mouth_off.rotated(ang)
		src.visual_level = src_len - amt * clampf(t / 0.88, 0.0, 1.0)
		dst.visual_level = dst_len - amt + amt * clampf((t - 0.12) / 0.88, 0.0, 1.0)
		Sfx.set_pour_fill(dst.visual_level / capacity)
		_update_stream(src, dst, t, dir), 0.0, 1.0, pour_time)
	# Sounds follow the stream: it starts, lands on the liquid, then breaks off.
	tw.parallel().tween_callback(func() -> void: Sfx.start_pour(dst.visual_level / capacity))
	tw.parallel().tween_callback(func() -> void:
		Sfx.play("splash", lerpf(0.9, 1.3, float(dst_len - amt) / capacity))).set_delay(pour_time * 0.12)
	tw.parallel().tween_callback(Sfx.stop_pour.bind(pour_time * 0.14)).set_delay(pour_time * 0.86)
	tw.tween_callback(func() -> void:
		stream.visible = false
		splash.emitting = false
		src.set_layers(state[i])
		_bump(dst))
	# 3. Swing back home and settle with a little overshoot.
	var end_pos := mouth_target - mouth_off.rotated(a_end)
	var back_apex := (end_pos + src.home_pos) * 0.5 + Vector2(0, -50 * s)
	tw.tween_method(func(t: float) -> void:
		src.position = _bezier(end_pos, back_apex, src.home_pos, ease(t, -1.8)), 0.0, 1.0, 0.32)
	tw.parallel().tween_property(src, "rotation", 0.0, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		src.z_index = 0
		src.position = src.home_pos
		Sfx.play("place", _bottle_pitch(i))
		busy = false
		_after_pour(j))


func _tilt_for(level_units: float, cap: int) -> float:
	return deg_to_rad(lerpf(86.0, 52.0, level_units / float(cap)))


static func _bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


## Stream grows from the mouth to the target surface, wobbles, then breaks off.
func _update_stream(src: Bottle, dst: Bottle, t: float, dir: float) -> void:
	var head := clampf(t / 0.14, 0.0, 1.0)
	var tail := clampf((t - 0.86) / 0.14, 0.0, 1.0)
	var p0 := src.to_global(src.mouth_local())
	var p2 := dst.to_global(dst.surface_local())
	var p1 := Vector2(p0.x + dir * 10 * src.scale.x, lerpf(p0.y, p2.y, 0.25))
	var pts := PackedVector2Array()
	var now := Time.get_ticks_msec() / 1000.0
	for k in 13:
		var f := lerpf(tail, head, k / 12.0)
		var p := _bezier(p0, p1, p2, f)
		p.x += sin(now * 28.0 + f * 9.0) * 1.6 * src.scale.x * f
		pts.append(p)
	stream.points = pts
	stream.visible = head > tail
	splash.position = p2
	splash.emitting = head >= 1.0 and tail <= 0.0


func _bump(b: Bottle) -> void:
	var tw := create_tween()
	tw.tween_property(b, "position", b.home_pos + Vector2(0, 4 * b.scale.y), 0.07)
	tw.tween_property(b, "position", b.home_pos, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _after_pour(j: int) -> void:
	var dst := bottles[j]
	dst.set_layers(state[j])
	if dst.corked:
		Sfx.play("cork")
		dst.cork_drop = 60.0
		create_tween().tween_property(dst, "cork_drop", 0.0, 0.35) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if WaterSolver.is_solved(state, capacity):
		_win()


func _process(delta: float) -> void:
	if not timer_running or not window_focused:
		return
	var shown := int(elapsed)
	elapsed += delta
	if int(elapsed) != shown:
		_update_ui()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		window_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		window_focused = true


# ---------------------------------------------------------------- actions

func undo() -> void:
	if busy or history.is_empty() or win_layer.visible:
		return
	state = history.pop_back()
	moves_made = maxi(moves_made - 1, 0)
	_select(-1)
	_refresh_bottles()
	_update_ui()


func add_tube() -> void:
	if busy or extra_used or win_layer.visible:
		return
	extra_used = true
	state.append("")
	for h: Array in history:
		h.append("")
	selected = -1
	_rebuild_bottles()
	_update_ui()


func show_hint() -> void:
	if busy or win_layer.visible:
		return
	_clear_hint()
	var res := WaterSolver.solve(state, capacity, 30000)
	if not res.solved or res.moves.is_empty():
		_toast("Stuck! Try Undo or +Tube")
		Sfx.play("invalid")
		return
	var m: Array = res.moves[0]
	_select(-1)
	Sfx.play("hint")
	hint_used = true
	bottles[m[0]].hint = true
	bottles[m[1]].hint = true


func _clear_hint() -> void:
	for b in bottles:
		b.hint = false


func _win() -> void:
	timer_running = false
	_save(level + 1)
	earned_stars = Scoring.stars(moves_made, target_moves, extra_used or hint_used)
	var best := _load_best(level)
	var new_best := not best.is_empty() and Scoring.is_better(earned_stars, elapsed, best)
	_save_best(level, earned_stars, elapsed, best)
	win_title.text = "Level %d Complete!" % level
	win_stats.text = "Moves %d / %d    Time %s" % [moves_made, target_moves, Scoring.format_time(elapsed)]
	win_best.visible = new_best
	star_pop.fill(0.0)
	win_stars.queue_redraw()
	confetti.position = Vector2(get_viewport_rect().size.x / 2, get_viewport_rect().size.y * 0.45)
	confetti.restart()
	confetti.emitting = true
	Sfx.play("win")
	await get_tree().create_timer(0.6).timeout
	win_layer.modulate.a = 0
	win_layer.show()
	create_tween().tween_property(win_layer, "modulate:a", 1.0, 0.25)
	for k in earned_stars:
		await get_tree().create_timer(0.22).timeout
		if not win_layer.visible:
			return
		Sfx.play("place", Sfx.note([0, 4, 7, 12][mini(k, 3)])) # C E G arpeggio
		create_tween().tween_method(_set_star_pop.bind(k), 0.0, 1.0, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_star_pop(v: float, k: int) -> void:
	star_pop[k] = v
	win_stars.queue_redraw()


# ---------------------------------------------------------------- save

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		level = int(cfg.get_value("progress", "level", 1))


func _save(next_level: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("progress", "level", next_level)
	cfg.save(SAVE_PATH)


## Best result for a level as {stars, time}, or {} if it was never finished.
func _load_best(n: int) -> Dictionary:
	var cfg := ConfigFile.new()
	var section := "level_%d" % n
	if cfg.load(SAVE_PATH) != OK or not cfg.has_section(section):
		return {}
	return {stars = int(cfg.get_value(section, "stars", 0)), time = float(cfg.get_value(section, "time", 0.0))}


## Best stars and best time are kept independently.
func _save_best(n: int, stars: int, time: float, prev: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var section := "level_%d" % n
	cfg.set_value(section, "stars", maxi(stars, int(prev.get("stars", 0))))
	cfg.set_value(section, "time", minf(time, float(prev.get("time", INF))))
	cfg.save(SAVE_PATH)


# ---------------------------------------------------------------- UI

func _update_ui() -> void:
	level_label.text = "LEVEL %d" % level
	sub_label.text = "%s  ·  %s" % [LevelGenerator.difficulty_name(level), Scoring.format_time(elapsed)]
	undo_btn.disabled = history.is_empty()
	add_btn.disabled = extra_used


func _toast(msg: String) -> void:
	toast.text = msg
	toast.modulate.a = 1
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(toast, "modulate:a", 0.0, 0.4)


func _make_button(text: String, color: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(140, 88)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 30)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		if st == "hover":
			sb.bg_color = color.lightened(0.12)
		elif st == "pressed":
			sb.bg_color = color.darkened(0.15)
		elif st == "disabled":
			sb.bg_color = color.darkened(0.45)
		sb.set_corner_radius_all(22)
		sb.border_width_bottom = 6
		sb.border_color = color.darkened(0.35)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
	b.pressed.connect(func() -> void: Sfx.play("tap"))
	b.pressed.connect(cb)
	return b


func _toggle_sound() -> void:
	Sfx.toggle_mute()
	Sfx.play("tap")
	sound_btn.queue_redraw()


func _draw_sound_icon() -> void:
	var c := sound_btn.size / 2 + Vector2(-8, 0)
	var col := Color(1, 1, 1, 0.9 if not Sfx.muted else 0.45)
	var body := PackedVector2Array([
		c + Vector2(-20, -9), c + Vector2(-10, -9), c + Vector2(4, -22),
		c + Vector2(4, 22), c + Vector2(-10, 9), c + Vector2(-20, 9),
	])
	sound_btn.draw_colored_polygon(body, col)
	if Sfx.muted:
		sound_btn.draw_line(c + Vector2(13, -10), c + Vector2(31, 10), col, 5, true)
		sound_btn.draw_line(c + Vector2(13, 10), c + Vector2(31, -10), col, 5, true)
	else:
		sound_btn.draw_arc(c + Vector2(4, 0), 12, -0.9, 0.9, 12, col, 4.5, true)
		sound_btn.draw_arc(c + Vector2(4, 0), 23, -0.85, 0.85, 16, col, 4.5, true)


## Five-pointed star drawn as a polygon so it needs no font glyphs.
func _draw_star(ci: CanvasItem, c: Vector2, r: float, filled: bool) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2 + k * PI / 5
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	if filled:
		ci.draw_colored_polygon(pts, Color("ffd65a"))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color("ffd65a") if filled else Color(1, 1, 1, 0.3), maxf(r / 10, 2), true)


func _draw_best_stars() -> void:
	for k in 3:
		_draw_star(best_box, Vector2(22 + k * 40, 22), 17, k < best_stars)


func _draw_win_stars() -> void:
	var mid := win_stars.size / 2
	for k in 3:
		var c := mid + Vector2((k - 1) * 110, 0 if k == 1 else 14)
		var r := 46.0 if k == 1 else 38.0
		_draw_star(win_stars, c, r, false)
		if star_pop[k] > 0:
			_draw_star(win_stars, c, r * star_pop[k], true)


func _outlined_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("outline_size", maxi(size / 6, 4))
	return l


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# Header
	var header := VBoxContainer.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_top = 40
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header)
	level_label = _outlined_label(58, Color.WHITE)
	header.add_child(level_label)
	sub_label = _outlined_label(28, Color(0.72, 0.8, 0.84))
	header.add_child(sub_label)

	# Sound toggle, top-right. The speaker icon is drawn so it needs no font glyphs.
	sound_btn = Button.new()
	sound_btn.flat = true
	sound_btn.focus_mode = Control.FOCUS_NONE
	sound_btn.custom_minimum_size = Vector2(88, 88)
	sound_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sound_btn.offset_left = -112
	sound_btn.offset_right = -24
	sound_btn.offset_top = 36
	sound_btn.offset_bottom = 124
	sound_btn.draw.connect(_draw_sound_icon)
	sound_btn.pressed.connect(_toggle_sound)
	root.add_child(sound_btn)

	# Best result for this level, top-left.
	best_box = Control.new()
	best_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	best_box.offset_left = 28
	best_box.offset_top = 44
	best_box.custom_minimum_size = Vector2(124, 88)
	best_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	best_box.draw.connect(_draw_best_stars)
	best_box.hide()
	root.add_child(best_box)
	best_time_label = _outlined_label(24, Color(0.72, 0.8, 0.84))
	best_time_label.position = Vector2(0, 46)
	best_time_label.custom_minimum_size = Vector2(124, 0)
	best_box.add_child(best_time_label)

	toast = _outlined_label(30, Color(1, 0.9, 0.5))
	toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast.offset_top = 150
	toast.modulate.a = 0
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast)

	# Bottom toolbar
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -140
	bar.offset_bottom = -40
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 16)
	root.add_child(bar)
	bar.add_child(_make_button("Restart", Color("5b6b78"), restart_level))
	undo_btn = _make_button("Undo", Color("3a86c8"), undo)
	bar.add_child(undo_btn)
	add_btn = _make_button("+Tube", Color("3fa55c"), add_tube)
	bar.add_child(add_btn)
	hint_btn = _make_button("Hint", Color("e0a526"), show_hint)
	bar.add_child(hint_btn)

	# Confetti
	confetti = CPUParticles2D.new()
	confetti.emitting = false
	confetti.one_shot = true
	confetti.amount = 160
	confetti.lifetime = 2.2
	confetti.explosiveness = 0.95
	confetti.direction = Vector2(0, -1)
	confetti.spread = 70
	confetti.gravity = Vector2(0, 1100)
	confetti.initial_velocity_min = 700
	confetti.initial_velocity_max = 1300
	confetti.angular_velocity_min = -400
	confetti.angular_velocity_max = 400
	confetti.scale_amount_min = 10
	confetti.scale_amount_max = 18
	confetti.color = Color(1, 0.4, 0.4)
	confetti.hue_variation_min = -1
	confetti.hue_variation_max = 1
	confetti.z_index = 50
	add_child(confetti)

	# Win overlay
	win_layer = ColorRect.new()
	(win_layer as ColorRect).color = Color(0, 0, 0, 0.55)
	win_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_layer.hide()
	root.add_child(win_layer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_layer.add_child(center)
	var panel := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color("39424a")
	psb.set_corner_radius_all(32)
	psb.border_width_bottom = 8
	psb.border_color = Color("252b30")
	psb.set_content_margin_all(40)
	panel.add_theme_stylebox_override("panel", psb)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 30)
	panel.add_child(vb)
	win_title = _outlined_label(46, Color("ffd65a"))
	vb.add_child(win_title)
	win_stars = Control.new()
	win_stars.custom_minimum_size = Vector2(360, 110)
	win_stars.draw.connect(_draw_win_stars)
	vb.add_child(win_stars)
	win_stats = _outlined_label(30, Color.WHITE)
	vb.add_child(win_stats)
	win_best = _outlined_label(30, Color("7fe08f"))
	win_best.text = "New best!"
	vb.add_child(win_best)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 20)
	vb.add_child(btns)
	var replay_btn := _make_button("Replay", Color("5b6b78"), restart_level)
	replay_btn.custom_minimum_size = Vector2(220, 100)
	replay_btn.add_theme_font_size_override("font_size", 38)
	btns.add_child(replay_btn)
	var next_btn := _make_button("Next Level", Color("3fa55c"), func() -> void: start_level(level + 1))
	next_btn.custom_minimum_size = Vector2(300, 100)
	next_btn.add_theme_font_size_override("font_size", 38)
	btns.add_child(next_btn)
