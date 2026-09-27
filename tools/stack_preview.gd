extends SceneTree
## A short, deterministic close-up using the real board animations.
const Board = preload("res://scripts/board.gd")
var caption: Label

func _initialize() -> void:
	call_deferred("run")

func state(a: Array, b: Array) -> Array:
	var result: Array = [a, b, [], []]
	for i: int in 8:
		result.append([])
	return result

func label_at(text: String, y: float, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = Vector2(20, y)
	label.size = Vector2(500, 110)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", preload("res://assets/fonts/Nunito.ttf"))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("685544"))
	root.add_child(label)
	return label

func run() -> void:
	root.size = Vector2i(540, 960)
	root.content_scale_size = Vector2i(540, 960)
	label_at("Squishy stacks", 42, 34)
	caption = label_at("Blobs share their weight with the stack below.", 790, 23)
	var crop: Control = Control.new()
	crop.position = Vector2(0, 165)
	crop.size = Vector2(540, 580)
	crop.clip_contents = true
	root.add_child(crop)
	var board: BlobbleBoard = Board.new()
	crop.add_child(board)
	board.position = Vector2(-70, -20)
	board.scale = Vector2.ONE * 1.1
	board.apply_layout(preload("res://scripts/board_layout.gd").new().generate(0))
	board.refresh(state([0, 1, 2, 3], [5, 4, 3]))
	await create_timer(0.65).timeout
	caption.text = "Lift a blob: the ones below spring upward."
	board.set_selection(0)
	await create_timer(0.85).timeout
	caption.text = "Put it down: the stack gently compresses."
	board.set_selection(-1)
	await create_timer(1.0).timeout
	caption.text = "Landing sends a soft wobble down the stack."
	board.set_selection(0)
	await create_timer(0.35).timeout
	board.set_selection(-1)
	await board.play_pour(0, 1, 1, state([0, 1, 2], [5, 4, 3, 3]))
	await create_timer(1.25).timeout
	caption.text = "The blobs settle together, keeping their original shape."
	await create_timer(1.0).timeout
	crop.free()
	quit()
