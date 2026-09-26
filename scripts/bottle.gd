class_name Bottle
extends Node2D
## A glass bottle drawn entirely in code. Origin is the bottom-center.

const W := 64.0
const SEG_H := 46.0
const INSET := 5.0
const SHOULDER := 24.0
const NECK_W := 34.0
const NECK_H := 20.0
const LIP_H := 8.0
const BOTTOM_R := 16.0
## Half-height of the ellipses that fake a slightly-from-above 3D view.
const DEPTH := 7.0
const COLUMNS := 16

const PALETTE: Array[Color] = [
	Color("f2c521"), # yellow
	Color("eeeeee"), # white
	Color("a08f82"), # taupe
	Color("5a1a1f"), # dark cherry
	Color("e8833a"), # orange
	Color("9c5a6e"), # mauve
	Color("d7363c"), # red
	Color("3a78d8"), # blue
	Color("3fae55"), # green
	Color("8a4fc9"), # purple
	Color("ff8fc2"), # pink
	Color("3fd0d0"), # cyan
	Color("a6d93a"), # lime
	Color("24305e"), # navy
]

var capacity := 4
var layers := PackedInt32Array()
var home_pos := Vector2.ZERO
var visual_level := 0.0:
	set(v):
		visual_level = v
		queue_redraw()
var hint := false:
	set(v):
		hint = v
		queue_redraw()
var corked := false
var cork_drop := 0.0:
	set(v):
		cork_drop = v
		queue_redraw()

var _outline := PackedVector2Array()


func _ready() -> void:
	set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()


func set_layers(s: String) -> void:
	layers.clear()
	for i in s.length():
		layers.append(s.unicode_at(i) - 65)
	visual_level = layers.size()
	corked = WaterSolver.is_complete(s, capacity)
	queue_redraw()


func liquid_top() -> float:
	return -INSET - DEPTH * 2 - SEG_H * capacity


func body_h() -> float:
	return -liquid_top() + SHOULDER


func total_h() -> float:
	return body_h() + NECK_H + LIP_H


func mouth_local() -> Vector2:
	return Vector2(0, -total_h())


func surface_local() -> Vector2:
	return Vector2(0, -INSET - DEPTH - visual_level * SEG_H)


func hit_rect() -> Rect2:
	return Rect2(-W / 2 - 12, -total_h() - 50, W + 24, total_h() + 70)


func _build_outline() -> void:
	var hw := W / 2
	var ys := liquid_top() - 2
	var yn := -body_h()
	var ym := -total_h()
	var nw := NECK_W / 2
	var right := PackedVector2Array()
	# bottom-right corner
	for k in range(0, 7):
		var a := PI / 2 - PI / 2 * k / 6.0
		right.append(Vector2(hw - BOTTOM_R, -BOTTOM_R) + Vector2(cos(a), sin(a)) * BOTTOM_R)
	# right wall up to the shoulder, then curve into the neck
	for k in range(0, 9):
		var t := k / 8.0
		var p0 := Vector2(hw, ys)
		var p1 := Vector2(hw, yn)
		var p2 := Vector2(nw, yn)
		right.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
	right.append(Vector2(nw, ym + LIP_H))
	right.append(Vector2(nw + 4, ym + LIP_H))
	right.append(Vector2(nw + 4, ym + 2))
	right.append(Vector2(nw + 2, ym))
	_outline = PackedVector2Array()
	for i in range(right.size() - 1, -1, -1):
		_outline.append(Vector2(-right[i].x, right[i].y))
	_outline.append_array(right)
	_outline.reverse()


## Shade of a cylinder surface at u in [-1, 1] (left..right), lit from front-left.
static func _shade(base: Color, u: float) -> Color:
	var nz := sqrt(maxf(0.0, 1.0 - u * u))
	var d := clampf(-0.45 * u + 0.89 * nz, 0.0, 1.0)
	var c := base.darkened(0.45).lerp(base.lightened(0.06), d)
	var spec := exp(-pow((u + 0.48) / 0.13, 2.0)) * 0.38
	return c.lerp(Color.WHITE, spec)


## y of the front (viewer-side) arc of a horizontal ellipse centered at y0.
func _front_y(y0: float, u: float) -> float:
	return y0 + DEPTH * sqrt(maxf(0.0, 1.0 - u * u))


func _ellipse(center: Vector2, rx: float, ry: float, segments := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in segments:
		var a := TAU * k / segments
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _draw() -> void:
	if _outline.is_empty():
		_build_outline()
	var hw := W / 2

	# Contact shadow, only while resting on the shelf.
	if position.distance_to(home_pos) < 1.0 and absf(rotation) < 0.01:
		draw_colored_polygon(_ellipse(Vector2(3, 2), hw * 1.05, 7), Color(0, 0, 0, 0.22))

	# Glass back: brighter toward the rim edges, like thick curved glass.
	var glass_cols := PackedColorArray()
	for p in _outline:
		var e := absf(p.x) / hw
		glass_cols.append(Color(0.85, 0.95, 1.0, 0.04 + 0.13 * e * e))
	draw_polygon(_outline, glass_cols)
	# Back half of the inner base, seen through the glass.
	var base_y := -INSET - DEPTH
	var r := hw - INSET
	var back := PackedVector2Array()
	for k in 17:
		var u := -1.0 + 2.0 * k / 16.0
		back.append(Vector2(u * r, base_y - DEPTH * sqrt(maxf(0.0, 1.0 - u * u))))
	draw_polyline(back, Color(1, 1, 1, 0.12), 2.0, true)

	# Liquid: a cylinder of stacked layers, each shaded column by column.
	var top_level := minf(visual_level, layers.size())
	for i in layers.size():
		var lo := float(i)
		var hi := minf(float(i + 1), top_level)
		if hi <= lo:
			break
		var base := PALETTE[layers[i] % PALETTE.size()]
		var y_lo := base_y - lo * SEG_H
		var y_hi := base_y - hi * SEG_H
		for k in COLUMNS:
			var u0 := -1.0 + 2.0 * k / COLUMNS
			var u1 := -1.0 + 2.0 * (k + 1) / COLUMNS
			var c0 := _shade(base, u0)
			var c1 := _shade(base, u1)
			draw_polygon(PackedVector2Array([
				Vector2(u0 * r, _front_y(y_hi, u0)), Vector2(u1 * r, _front_y(y_hi, u1)),
				Vector2(u1 * r, _front_y(y_lo, u1)), Vector2(u0 * r, _front_y(y_lo, u0)),
			]), PackedColorArray([c0, c1, c1, c0]))
	if top_level > 0.0:
		var top_col := PALETTE[layers[int(ceilf(top_level)) - 1] % PALETTE.size()]
		var yt := base_y - top_level * SEG_H
		draw_colored_polygon(_ellipse(Vector2(0, yt), r, DEPTH), top_col.lightened(0.18))
		draw_colored_polygon(_ellipse(Vector2(-r * 0.25, yt - DEPTH * 0.15), r * 0.45, DEPTH * 0.45),
			Color(1, 1, 1, 0.18))

	# Glass front: right-edge shade, left highlight streaks, shoulder glint.
	draw_rect(Rect2(hw - 9, liquid_top() + 4, 5, -liquid_top() - 14), Color(0, 0, 0, 0.10))
	var hl := StyleBoxFlat.new()
	hl.bg_color = Color(1, 1, 1, 0.30)
	hl.set_corner_radius_all(4)
	hl.anti_aliasing = true
	draw_style_box(hl, Rect2(-hw + 8, liquid_top() + 10, 7, SEG_H * capacity * 0.7))
	hl.bg_color = Color(1, 1, 1, 0.14)
	draw_style_box(hl, Rect2(-hw + 18, liquid_top() + 14, 3, SEG_H * capacity * 0.45))
	draw_arc(Vector2(0, liquid_top() + 2), hw - 8, PI * 1.15, PI * 1.38, 8, Color(1, 1, 1, 0.3), 3.0, true)

	var closed := _outline.duplicate()
	closed.append(_outline[0])
	if hint:
		draw_polyline(closed, Color(1.0, 0.85, 0.2, 0.9), 9.0, true)
	draw_polyline(closed, Color(0.78, 0.92, 1.0, 0.65), 3.0, true)

	# Open mouth seen from slightly above.
	var mouth := Vector2(0, -total_h())
	draw_colored_polygon(_ellipse(mouth, NECK_W / 2 + 3, 4.5), Color(0.12, 0.14, 0.16, 0.55))
	var rim := _ellipse(mouth, NECK_W / 2 + 3, 4.5)
	rim.append(rim[0])
	draw_polyline(rim, Color(0.85, 0.95, 1.0, 0.75), 2.5, true)

	# Cork on finished bottles, drawn as a short cylinder.
	if corked:
		var cy := -total_h() - 12 - cork_drop
		var cw := NECK_W / 2 + 3
		var cork := Color("c98a4b")
		for k in COLUMNS:
			var u0 := -1.0 + 2.0 * k / COLUMNS
			var u1 := -1.0 + 2.0 * (k + 1) / COLUMNS
			var c0 := _shade(cork, u0)
			var c1 := _shade(cork, u1)
			draw_polygon(PackedVector2Array([
				Vector2(u0 * cw, cy + 4 * sqrt(1 - u0 * u0)), Vector2(u1 * cw, cy + 4 * sqrt(1 - u1 * u1)),
				Vector2(u1 * cw, cy + 22 + 4 * sqrt(1 - u1 * u1)), Vector2(u0 * cw, cy + 22 + 4 * sqrt(1 - u0 * u0)),
			]), PackedColorArray([c0, c1, c1, c0]))
		draw_colored_polygon(_ellipse(Vector2(0, cy), cw, 4), Color("e7ae6a"))
