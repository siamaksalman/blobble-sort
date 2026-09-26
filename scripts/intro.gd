extends Control
## Studio intro. Starts identical to the boot splash, makes the crow hop,
## then fades into the game. Tap to skip.

const SPLASH_SIZE := Vector2(1080, 1920)
## Where the crow sits inside assets/splash.png.
const CROW_RECT := Rect2(333, 669, 428, 362)
const GAME_SCENE := "res://scenes/main.tscn"

var crow: TextureRect
var fade: ColorRect
var leaving := false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.996, 0.996, 0.996)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var base := TextureRect.new()
	base.texture = load("res://assets/intro_base.png")
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(base)

	crow = TextureRect.new()
	crow.texture = load("res://assets/intro_crow.png")
	crow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crow.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(crow)

	fade = ColorRect.new()
	fade.color = Color(0.286, 0.31, 0.329, 0.0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)

	resized.connect(_layout)
	_layout()
	_animate()


func _layout() -> void:
	var k := minf(size.x / SPLASH_SIZE.x, size.y / SPLASH_SIZE.y)
	var offset := (size - SPLASH_SIZE * k) / 2
	crow.size = CROW_RECT.size * k
	crow.position = offset + CROW_RECT.position * k
	crow.pivot_offset = Vector2(crow.size.x / 2, crow.size.y)


func _animate() -> void:
	var home := crow.position
	var hop := crow.size.y * 0.22
	var tw := create_tween()
	tw.tween_interval(0.5)
	for n in 2:
		# crouch, jump, land, settle
		tw.tween_property(crow, "scale", Vector2(1.08, 0.9), 0.1).set_trans(Tween.TRANS_SINE)
		tw.tween_property(crow, "position:y", home.y - hop, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(crow, "scale", Vector2(0.95, 1.07), 0.12)
		tw.tween_property(crow, "position:y", home.y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(crow, "scale", Vector2.ONE, 0.16)
		tw.tween_property(crow, "scale", Vector2(1.1, 0.88), 0.07)
		tw.tween_property(crow, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_callback(_leave)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_leave()


func _leave() -> void:
	if leaving:
		return
	leaving = true
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.35)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(GAME_SCENE))
