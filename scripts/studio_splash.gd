class_name StudioSplash
extends Control
## Opening studio card: the logo pops in, rests, then the card fades away to reveal the game.
## Any tap, click or key skips ahead.

signal finished

const LOGO: Texture2D = preload("res://assets/brand/redcrow_studio.png")
const FADE_IN: float = 0.6
const HOLD: float = 1.3
const FADE_OUT: float = 0.45
const DURATION: float = FADE_IN + HOLD + FADE_OUT

var _logo: TextureRect
var _leaving: bool = false

func _ready() -> void:
	name = "StudioSplash"
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card: ColorRect = ColorRect.new()
	card.color = Color.WHITE # Matches the logo artwork's own background.
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(card)
	_logo = TextureRect.new()
	_logo.name = "Logo"
	_logo.texture = LOGO
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.modulate.a = 0.0
	add_child(_logo)
	resized.connect(_layout)
	_layout()
	var intro: Tween = create_tween().set_parallel()
	_logo.scale = Vector2.ONE * 0.86
	intro.tween_property(_logo, "modulate:a", 1.0, FADE_IN * 0.8)
	intro.tween_property(_logo, "scale", Vector2.ONE, FADE_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.chain().tween_interval(HOLD)
	intro.chain().tween_callback(_leave)

func _layout() -> void:
	var side: float = minf(size.x, size.y) * 0.68
	_logo.size = Vector2(side, side)
	_logo.position = (size - _logo.size) * 0.5
	_logo.pivot_offset = _logo.size * 0.5

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		accept_event()
		_leave()

func _input(event: InputEvent) -> void:
	# Keys never reach the board underneath while the card is up.
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo:
			_leave()

func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	var outro: Tween = create_tween()
	outro.tween_property(self, "modulate:a", 0.0, FADE_OUT).set_ease(Tween.EASE_IN)
	outro.tween_callback(func() -> void:
		finished.emit()
		queue_free())
