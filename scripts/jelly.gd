class_name BlobbleJelly
extends ColorRect

const SHADER: Shader = preload("res://shaders/jelly.gdshader")
const COLORS: Array[Color] = [Color("ff9d58"), Color("43baf1"), Color("ffe44c"), Color("f777b8"), Color("58dfa6"), Color("ae7bf0")]
var pocket_index: int = -1
var start_slot: int = 0
var count: int = 1
var color_index: int = 0
var selected: bool = false
var origin: Vector2
var layout_scale: float = 1.0
## Animated deformation, multiplied with the selection scale each frame.
var squash: Vector2 = Vector2.ONE
var _age: float = 0.0
var _seed: float = 0.0
var _lift: float = 0.0
var _grow: float = 1.0
var _wobble_tween: Tween

func configure(color: int, amount: int, show_symbols: bool = false) -> void:
	color_index = color
	count = amount
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(140, 140 + (count - 1) * 89)
	# Squash from the bottom of the body so jellies stay seated in their pocket.
	pivot_offset = Vector2(size.x * 0.5, (size.y + 101.0 + (count - 1) * 89.0) * 0.5)
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	shader_material.shader = SHADER
	shader_material.set_shader_parameter("jelly_color", COLORS[color])
	shader_material.set_shader_parameter("rect_size", size)
	shader_material.set_shader_parameter("body_height", 101.0 + (count - 1) * 89.0)
	_seed = randf() * 20.0
	shader_material.set_shader_parameter("seed", _seed)
	shader_material.set_shader_parameter("symbols", 1.0 if show_symbols else 0.0)
	shader_material.set_shader_parameter("color_id", float(color))
	shader_material.set_shader_parameter("pinch", 0.0)
	material = shader_material

func _process(delta: float) -> void:
	_age += delta
	material.set_shader_parameter("clock", _age)
	material.set_shader_parameter("selected", 1.0 if selected else 0.0)
	var follow: float = 1.0 - exp(-delta * 14.0)
	_lift = lerpf(_lift, -16.0 + sin(_age * 4.0) * 4.0 if selected else 0.0, follow)
	_grow = lerpf(_grow, 1.025 if selected else 1.0, follow)
	_apply_pose()

func _apply_pose() -> void:
	position = origin + Vector2(0, _lift * layout_scale)
	scale = squash * _grow * layout_scale

func set_selected(value: bool) -> void:
	selected = value

## Springy impact: positive strength flattens, negative stretches upward.
func wobble(strength: float, duration: float = 0.55) -> void:
	if _wobble_tween:
		_wobble_tween.kill()
	squash = Vector2(1.0 + strength, 1.0 - strength)
	_apply_pose()
	_wobble_tween = create_tween()
	_wobble_tween.tween_property(self, "squash", Vector2.ONE, duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## Pinches the body at seam_y (relative to the jelly center), then lets the goo flow together.
func fuse(seam_y: float) -> void:
	material.set_shader_parameter("seam_y", seam_y)
	material.set_shader_parameter("pinch", 1.0)
	create_tween().tween_method(func(value: float) -> void:
		material.set_shader_parameter("pinch", value)
	, 1.0, 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
