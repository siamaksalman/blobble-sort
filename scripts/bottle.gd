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


func set_layers(s: String) -> void:
	layers.clear()
	for i in s.length():
		layers.append(s.unicode_at(i) - 65)
	visual_level = layers.size()
	corked = WaterSolver.is_complete(s, capacity)
	queue_redraw()


func liquid_top() -> float:
	return -INSET - SEG_H * capacity


func body_h() -> float:
	return -liquid_top() + SHOULDER


func total_h() -> float:
	return body_h() + NECK_H + LIP_H


func mouth_local() -> Vector2:
	return Vector2(0, -total_h())


func surface_local() -> Vector2:
	return Vector2(0, -INSET - visual_level * SEG_H)


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


func _draw() -> void:
	if _outline.is_empty():
		_build_outline()

	# Glass back.
	draw_colored_polygon(_outline, Color(1, 1, 1, 0.07))

	# Liquid, bottom -> top, clipped at visual_level.
	var inner_w := W - INSET * 2
	var x0 := -W / 2 + INSET
	var y := -INSET
	var top_color := Color.TRANSPARENT
	for i in layers.size():
		var h := clampf(visual_level - i, 0.0, 1.0) * SEG_H
		if h <= 0.0:
			break
		var col := PALETTE[layers[i] % PALETTE.size()]
		var rect := Rect2(x0, y - h, inner_w, h)
		if i == 0:
			var sb := StyleBoxFlat.new()
			sb.bg_color = col
			var r := int(minf(BOTTOM_R - INSET, h))
			sb.corner_radius_bottom_left = r
			sb.corner_radius_bottom_right = r
			sb.anti_aliasing = true
			draw_style_box(sb, rect)
		else:
			draw_rect(rect, col)
		# soft shading for a rounded look
		draw_rect(Rect2(x0 + inner_w * 0.72, y - h, inner_w * 0.28, h), Color(0, 0, 0, 0.13))
		draw_rect(Rect2(x0 + inner_w * 0.1, y - h, inner_w * 0.14, h), Color(1, 1, 1, 0.12))
		y -= h
		top_color = col
	if top_color.a > 0.0:
		draw_rect(Rect2(x0, y, inner_w, 5), top_color.lightened(0.3))

	# Glass highlight + outline.
	var hl := StyleBoxFlat.new()
	hl.bg_color = Color(1, 1, 1, 0.22)
	hl.set_corner_radius_all(4)
	draw_style_box(hl, Rect2(-W / 2 + 9, liquid_top() + 8, 7, SEG_H * capacity * 0.75))
	var closed := _outline.duplicate()
	closed.append(_outline[0])
	if hint:
		draw_polyline(closed, Color(1.0, 0.85, 0.2, 0.9), 9.0, true)
	draw_polyline(closed, Color(0.78, 0.92, 1.0, 0.65), 3.0, true)

	# Cork on finished bottles.
	if corked:
		var cy := -total_h() - 12 - cork_drop
		var cork := StyleBoxFlat.new()
		cork.bg_color = Color("c98a4b")
		cork.set_corner_radius_all(6)
		cork.border_width_top = 5
		cork.border_color = Color("e7ae6a")
		cork.anti_aliasing = true
		draw_style_box(cork, Rect2(-NECK_W / 2 - 3, cy, NECK_W + 6, 24))
