class_name BlobbleBoard
extends Control

const Jelly = preload("res://scripts/jelly.gd")
const Puzzle = preload("res://scripts/puzzle.gd")
const Layout = preload("res://scripts/board_layout.gd")
const TEXTURE: Texture2D = preload("res://assets/textures/clay_board.png")
const COLUMNS: Array[float] = [158.0, 369.0, 570.0, 782.0]
const BOTTOMS: Array[float] = [478.0, 947.0, 1418.0]
const STEP: float = 89.0
const LIFT_TIME: float = 0.07
const FLIGHT_TIME: float = 0.36
const ARC_HEIGHT: float = 125.0

var pockets: Array = []
var selected: int = -1
var hinted: int = -1
var keyboard_focus: int = -1
var jellies: Array[BlobbleJelly] = []
var pieces: Control
var show_symbols: bool = false
## The group currently in the air during a pour, or null.
var flying: BlobbleJelly
var splash_layer: Control
var _droplets: Array = []  # [position, velocity, color, radius, age, lifetime]
var layout_data: Dictionary = {}
var _backdrop: TextureRect
var _reference_material: ShaderMaterial
var _legacy_material: ShaderMaterial
var _idle_time: float = 0.0

func _ready() -> void:
	# Update contact after each jelly has applied its own animation pose.
	process_priority = 10
	size = Vector2(941, 1672)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop = TextureRect.new()
	_backdrop.texture = TEXTURE
	_backdrop.show_behind_parent = true
	_legacy_material = ShaderMaterial.new()
	_legacy_material.shader = preload("res://shaders/board_edge.gdshader")
	_backdrop.material = _legacy_material
	_backdrop.size = size
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	_reference_material = ShaderMaterial.new()
	_reference_material.shader = preload("res://shaders/reference_board.gdshader")
	pieces = Control.new()
	pieces.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pieces)
	splash_layer = Control.new()
	splash_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash_layer.draw.connect(_draw_droplets)
	add_child(splash_layer)

func center_at(index: int, slot: float) -> Vector2:
	if not layout_data.is_empty():
		return Layout.center_at(layout_data, index, slot)
	return Vector2(COLUMNS[index % 4], BOTTOMS[index / 4] - slot * STEP)

func pocket_rect(index: int) -> Rect2:
	if not layout_data.is_empty():
		return Layout.hit_rect(layout_data, index)
	return Rect2(center_at(index, 3) - Vector2(76, 66), Vector2(152, 402))

func pocket_scale(index: int) -> float:
	return 1.0 if layout_data.is_empty() else float(layout_data["wells"][index]["scale"])

func apply_layout(layout: Dictionary) -> void:
	layout_data = layout.duplicate(true)
	_droplets.clear()
	splash_layer.queue_redraw()
	if layout_data.is_empty():
		_backdrop.texture = TEXTURE
		_backdrop.material = _legacy_material
		return
	_backdrop.texture = TEXTURE
	_backdrop.material = _reference_material
	_reference_material.set_shader_parameter("clay_art", TEXTURE)
	_reference_material.set_shader_parameter("compact_count", layout_data.get("compact_count", 0))
	if layout_data.has("compact_count"):
		var offset: Array = layout_data["offset"]
		_reference_material.set_shader_parameter("compact_offset", Vector2(offset[0], offset[1]))
		_reference_material.set_shader_parameter("reference_layout", false)
		_reference_material.set_shader_parameter("horizontal", PackedInt32Array(layout_data["horizontal"]))
		_reference_material.set_shader_parameter("vertical", PackedInt32Array(layout_data["vertical"]))
		queue_redraw()
		return
	for key: String in ["source_x", "target_x", "source_y", "target_y"]:
		_reference_material.set_shader_parameter(key, PackedFloat32Array(layout_data[key]))
	_reference_material.set_shader_parameter("mirror", layout_data["mirror"])
	_reference_material.set_shader_parameter("reference_layout", layout_data["reference"])
	_reference_material.set_shader_parameter("horizontal", PackedInt32Array(layout_data["horizontal"]))
	_reference_material.set_shader_parameter("vertical", PackedInt32Array(layout_data["vertical"]))
	queue_redraw()

func _pocket_count() -> int:
	return 12 if layout_data.is_empty() else layout_data["wells"].size()

func directional_neighbor(index: int, direction: Vector2) -> int:
	var origin: Vector2 = center_at(index, 1.5)
	var result: int = index
	var best: float = INF
	for candidate: int in _pocket_count():
		var offset: Vector2 = center_at(candidate, 1.5) - origin
		if offset.dot(direction) <= 20:
			continue
		var score: float = offset.length() + absf(offset.cross(direction)) * 2.0
		if score < best:
			best = score
			result = candidate
	return result

func hit_test(global_point: Vector2) -> int:
	var local: Vector2 = get_global_transform().affine_inverse() * global_point
	for i: int in _pocket_count():
		if pocket_rect(i).has_point(local):
			return i
	return -1

## A press squishes the contacted body and passes a softer pulse to its neighbors.
func poke_at(global_point: Vector2) -> void:
	var pocket: int = hit_test(global_point)
	if pocket < 0:
		return
	# Test the visible capsule, including its current lift and deformation.
	for index: int in range(jellies.size() - 1, -1, -1):
		var touched: BlobbleJelly = jellies[index]
		if touched.pocket_index != pocket:
			continue
		var point: Vector2 = touched.get_global_transform().affine_inverse() * global_point - touched.size * 0.5
		var half_line: float = maxf(0.0, touched.body_height * 0.5 - 52.0)
		point.y -= clampf(point.y, -half_line, half_line)
		if point.length_squared() > 52.0 * 52.0:
			continue
		for neighbor: int in jellies.size():
			var jelly: BlobbleJelly = jellies[neighbor]
			if jelly.pocket_index != pocket:
				continue
			var distance: int = absi(neighbor - index)
			jelly.wobble(0.14 * pow(0.62, distance) / sqrt(float(jelly.count)), 0.55, distance * 0.045)
		return

func refresh(state: Array, animate: bool = false) -> void:
	pockets = state.duplicate(true)
	for jelly: BlobbleJelly in jellies:
		pieces.remove_child(jelly)
		jelly.queue_free()
	jellies.clear()
	for index: int in pockets.size():
		var pocket: Array = pockets[index]
		var slot: int = 0
		while slot < pocket.size():
			var amount: int = 1
			while slot + amount < pocket.size() and int(pocket[slot + amount]) == int(pocket[slot]):
				amount += 1
			var jelly: BlobbleJelly = Jelly.new()
			jelly.configure(int(pocket[slot]), amount, show_symbols)
			_continue_idle(jelly, index, slot)
			jelly.pocket_index = index
			jelly.start_slot = slot
			jelly.layout_scale = pocket_scale(index)
			jelly.scale = Vector2.ONE * jelly.layout_scale
			jelly.position = jelly.origin_for_center(center_at(index, slot + (amount - 1) * 0.5))
			jelly.origin = jelly.position
			pieces.add_child(jelly)
			jellies.append(jelly)
			if animate:
				jelly.modulate.a = 0
				var tween: Tween = create_tween()
				tween.tween_property(jelly, "modulate:a", 1.0, 0.3).set_delay(index * 0.018)
			slot += amount
	set_selection(selected)

func jelly_at(pocket: int, slot: int) -> BlobbleJelly:
	for jelly: BlobbleJelly in jellies:
		if jelly.pocket_index == pocket and slot >= jelly.start_slot and slot < jelly.start_slot + jelly.count:
			return jelly
	return null

## Animates `amount` blobs from source to target; `after` is the state once they land.
func play_pour(source: int, target: int, amount: int, after: Array) -> void:
	var color: int = int(after[target].back())
	var below: int = after[target].size() - amount
	var in_flight: Array = after.duplicate(true)
	for i: int in amount:
		in_flight[target].pop_back()
	refresh(in_flight)
	_pulse_supports(source, after[source].size(), -0.075)
	flying = Jelly.new()
	flying.configure(color, amount, show_symbols)
	_continue_idle(flying, source, after[source].size())
	flying.z_index = 1
	pieces.add_child(flying)
	var start: Vector2 = center_at(source, after[source].size() + (amount - 1) * 0.5)
	var end: Vector2 = center_at(target, below + (amount - 1) * 0.5)
	flying.layout_scale = pocket_scale(source)
	flying.origin = flying.origin_for_center(start)
	flying.position = flying.origin
	flying.scale = Vector2.ONE * flying.layout_scale
	var lean: float = signf(end.x - start.x) if not is_equal_approx(end.x, start.x) else 0.0
	var tween: Tween = flying.create_tween()
	# Crouch, then spring out of the pocket and stretch along the arc.
	tween.tween_property(flying, "squash", Vector2(1.13, 0.87), LIFT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(t: float) -> void:
		flying.layout_scale = lerpf(pocket_scale(source), pocket_scale(target), t)
		flying.origin = flying.origin_for_center(start.lerp(end, t) + Vector2(0, -sin(t * PI) * ARC_HEIGHT))
		var stretch: float = sin(t * PI) * 0.6 + pow(t, 4.0) * 0.5
		flying.squash = Vector2(1.13, 0.87).lerp(Vector2.ONE, minf(t * 5.0, 1.0)) + Vector2(-0.1, 0.16) * stretch
		flying.rotation = sin(t * TAU) * 0.09 * lean
	, 0.0, 1.0, FLIGHT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	flying.queue_free()
	flying = null
	refresh(after)
	var landed: BlobbleJelly = jelly_at(target, after[target].size() - 1)
	var merged: bool = landed.start_slot < below
	_pulse_supports(target, landed.start_slot, minf(0.16, 0.095 * sqrt(float(amount))))
	var impact: Vector2 = center_at(target, below - 0.5)
	if merged:
		var middle: float = landed.start_slot + (landed.count - 1) * 0.5
		landed.fuse(-(below - 0.5 - middle) * STEP)
		splash(impact, Jelly.COLORS[color], 9)
	else:
		splash(impact + Vector2(0, 40), Color(0.36, 0.23, 0.12, 0.35), 5)
	if Puzzle.is_complete(after[target]):
		landed.wobble(0.2, 0.75)
		splash(center_at(target, 1.5), Jelly.COLORS[color], 16, 1.6)
	else:
		landed.wobble(0.15 if merged else 0.11)

func splash(at: Vector2, color: Color, amount: int, power: float = 1.0) -> void:
	for i: int in amount:
		# Fling from the body's sides so droplets are visible against the jelly.
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var angle: float = -PI * 0.5 + side * randf_range(0.35, 1.2)
		var velocity: Vector2 = Vector2.from_angle(angle) * randf_range(160.0, 340.0) * power
		_droplets.append([at + Vector2(side * randf_range(44, 54), randf_range(-10, 10)), velocity, color, randf_range(5.0, 10.0), 0.0, randf_range(0.35, 0.6)])
	splash_layer.queue_redraw()

func splash_count() -> int:
	return _droplets.size()

func _process(delta: float) -> void:
	_idle_time += delta
	_update_supports()
	if _droplets.is_empty():
		return
	for droplet: Array in _droplets:
		droplet[1].y += 900.0 * delta
		droplet[0] += droplet[1] * delta
		droplet[4] += delta
	_droplets = _droplets.filter(func(droplet: Array) -> bool: return droplet[4] < droplet[5])
	splash_layer.queue_redraw()

func _continue_idle(jelly: BlobbleJelly, pocket: int, slot: int) -> void:
	var personality: float = fposmod(float(pocket * 17 + slot * 7 + jelly.color_index * 13) * 1.618, 20.0)
	jelly.set_idle_phase(_idle_time, personality)

func _draw_droplets() -> void:
	for droplet: Array in _droplets:
		var life: float = 1.0 - droplet[4] / droplet[5]
		var tint: Color = droplet[2]
		tint.a *= life
		splash_layer.draw_circle(droplet[0], droplet[3] * (0.4 + 0.6 * life), tint)
		splash_layer.draw_circle(droplet[0] + Vector2(-0.3, -0.3) * droplet[3], droplet[3] * 0.3 * life, Color(1, 1, 1, 0.5 * life))

## A soft reaction travels downward; each supporting body receives less force.
func _pulse_supports(pocket: int, below_slot: int, strength: float) -> void:
	var depth: int = 0
	for i: int in range(jellies.size() - 1, -1, -1):
		var jelly: BlobbleJelly = jellies[i]
		if jelly.pocket_index != pocket or jelly.start_slot >= below_slot:
			continue
		jelly.wobble(strength * pow(0.62, depth) / sqrt(float(jelly.count)), 0.52, depth * 0.045)
		depth += 1

func _update_supports() -> void:
	var pocket: int = -1
	var displacement: float = 0.0
	# Refresh creates the bodies bottom-up, including merged groups.
	for jelly: BlobbleJelly in jellies:
		if jelly.pocket_index != pocket:
			pocket = jelly.pocket_index
			displacement = 0.0
		jelly.support_offset = displacement
		jelly._apply_pose()
		displacement = jelly.top_displacement()

func set_selection(index: int, destination: int = -1) -> void:
	if index != selected:
		for jelly: BlobbleJelly in jellies:
			if jelly.pocket_index == selected and jelly.selected:
				_pulse_supports(selected, jelly.start_slot, 0.04)
		if index >= 0 and index < pockets.size() and not pockets[index].is_empty():
			var top: BlobbleJelly = jelly_at(index, pockets[index].size() - 1)
			if top:
				_pulse_supports(index, top.start_slot, -0.055)
	selected = index
	hinted = destination
	for jelly: BlobbleJelly in jellies:
		jelly.set_selected(jelly.pocket_index == index and jelly.start_slot + jelly.count == pockets[index].size())
	queue_redraw()

func _draw() -> void:
	if pockets.is_empty():
		return
	for i: int in _pocket_count():
		var rect: Rect2 = pocket_rect(i).grow(-5) if layout_data.is_empty() else Layout.well_rect(layout_data, i).grow(3)
		var color: Color = Color.TRANSPARENT
		if i == selected:
			color = Color("b39061")
		elif i == hinted:
			color = Color("6ba88d")
		elif selected >= 0 and Puzzle.transfer_size(pockets, selected, i) > 0:
			color = Color(0.53, 0.65, 0.49, 0.48)
		elif i == keyboard_focus:
			color = Color(0.55, 0.41, 0.29, 0.45)
		if color.a > 0:
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.bg_color = Color.TRANSPARENT
			style.border_color = color
			style.set_border_width_all(3)
			style.set_corner_radius_all(70)
			draw_style_box(style, rect)

	if hinted >= 0 and selected >= 0:
		var from: Vector2 = center_at(selected, pockets[selected].size() - 1) + Vector2(0, -68) * pocket_scale(selected)
		var to: Vector2 = center_at(hinted, pockets[hinted].size()) + Vector2(0, -57) * pocket_scale(hinted)
		var direction: Vector2 = (to - from).normalized()
		draw_dashed_line(from, to, Color(0.41, 0.55, 0.39, 0.7), 4.0, 12.0, true)
		draw_line(to, to - direction.rotated(0.55) * 21, Color("698c64"), 4, true)
		draw_line(to, to - direction.rotated(-0.55) * 21, Color("698c64"), 4, true)
