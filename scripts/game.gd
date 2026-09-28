extends Control
## Responsive, mouse/touch/keyboard front end for the independent puzzle model.

const Puzzle = preload("res://scripts/puzzle.gd")
const Board = preload("res://scripts/board.gd")
const Jelly = preload("res://scripts/jelly.gd")
const Solver = preload("res://scripts/hint_solver.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const Generator = preload("res://scripts/level_generator.gd")
const Layout = preload("res://scripts/board_layout.gd")
const FONT: Font = preload("res://assets/fonts/interface.tres")
const INK: Color = Color("665343")
const MUTED: Color = Color("947b63")
const SoundBank = preload("res://scripts/sound_bank.gd")
const Splash = preload("res://scripts/studio_splash.gd")

var puzzle: BlobblePuzzle = Puzzle.new()
var solver: BlobbleHintSolver = Solver.new()
var save: BlobbleSaveStore = SaveStore.new()
var generator: RefCounted = Generator.new()
var current_level: Dictionary = {}
var board: BlobbleBoard
var _header: Control
var _footer: Control
var _level_button: Button
var _moves_label: Label
var _progress_label: Label
var _message: Label
var _undo_button: Button
var _sound_button: Button
var _modal: Control
var _modal_panel: Panel
var sounds: BlobbleSoundBank
var _selected: int = -1
var _busy: bool = false
var _press_pocket: int = -1
var _press_position: Vector2
var _keyboard_pocket: int = 0
var _toast_id: int = 0
var _confetti: Array = []
var _confetti_time: float = 0.0
var test_mode: bool = false
var _confetti_layer: Node2D
var _difficulty_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not test_mode:
		save.read_save()
	sounds = SoundBank.new()
	add_child(sounds)
	_create_interface()
	_confetti_layer = Node2D.new()
	_confetti_layer.z_index = 100
	_confetti_layer.draw.connect(func() -> void:
		for piece: Array in _confetti:
			_confetti_layer.draw_circle(piece[0], piece[3], piece[2]))
	add_child(_confetti_layer)
	resized.connect(_layout)
	_layout()
	_load_level(save.level, true)
	if not test_mode:
		add_child(Splash.new())
	if OS.get_cmdline_user_args().has("--show-help"):
		_show_help()

func _create_interface() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color("f6e9d8")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	board = Board.new()
	add_child(board)
	_header = Control.new()
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_header)
	var title: Label = _label("blobble", 65, INK, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_font_override("font", preload("res://assets/fonts/title.tres"))
	title.position = Vector2(150, 6)
	title.size = Vector2(460, 88)
	_header.add_child(title)
	var tagline: Label = _label("a little pocket of calm", 21, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	tagline.position = Vector2(160, 87)
	tagline.size = Vector2(440, 34)
	_header.add_child(tagline)
	_sound_button = _button("", Vector2(22, 32), Vector2(66, 66), _toggle_sound, true)
	_sound_button.icon = preload("res://assets/ui/sound.svg")
	_sound_button.tooltip_text = "Toggle sound"
	_header.add_child(_sound_button)
	var help: Button = _button("?", Vector2(674, 32), Vector2(66, 66), _show_help, true)
	help.tooltip_text = "How to play and settings"
	_header.add_child(help)
	_level_button = _button("LEVEL 01  ···", Vector2(26, 137), Vector2(195, 48), _show_levels, true)
	_level_button.add_theme_font_size_override("font_size", 20)
	_header.add_child(_level_button)
	_progress_label = _label("2 / 10 together", 21, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_progress_label.position = Vector2(237, 141)
	_progress_label.size = Vector2(285, 42)
	_header.add_child(_progress_label)
	_moves_label = _label("0 moves", 23, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	_moves_label.position = Vector2(530, 140)
	_moves_label.size = Vector2(198, 42)
	_header.add_child(_moves_label)
	_footer = Control.new()
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_footer)
	_message = _label("Tap a top jelly, then any pocket with space", 23, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_message.size = Vector2(760, 40)
	_footer.add_child(_message)
	_undo_button = _button("Undo", Vector2(60, 57), Vector2(197, 70), _undo)
	_undo_button.icon = preload("res://assets/ui/undo.svg")
	_footer.add_child(_undo_button)
	var restart: Button = _button("Restart", Vector2(281, 57), Vector2(197, 70), _confirm_restart)
	restart.icon = preload("res://assets/ui/restart.svg")
	_footer.add_child(restart)
	var hint: Button = _button("Hint", Vector2(502, 57), Vector2(197, 70), _hint)
	hint.icon = preload("res://assets/ui/hint.svg")
	_style_button(hint, Color("9ba785"), Color("fff9ed"))
	_footer.add_child(hint)
	_difficulty_label = _label("GENTLE · NO TIMER. NO RUSH.", 16, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_difficulty_label.position = Vector2(0, 151)
	_difficulty_label.size = Vector2(760, 30)
	_footer.add_child(_difficulty_label)

func _layout() -> void:
	if board == null:
		return
	var viewport: Vector2 = size
	var safe_top: float = 0.0
	var safe_bottom: float = 0.0
	if OS.get_name() in ["Android", "iOS"]:
		var safe_area: Rect2i = DisplayServer.get_display_safe_area()
		var physical_height: float = float(DisplayServer.window_get_size().y)
		if physical_height > 0 and safe_area.size.y > 0:
			safe_top = safe_area.position.y / physical_height * viewport.y
			safe_bottom = maxf(0, physical_height - safe_area.end.y) / physical_height * viewport.y
	var ui_scale: float = minf((viewport.x - 32.0) / 760.0, 1.12)
	var usable_height: float = viewport.y - safe_top - safe_bottom - 390.0 * ui_scale
	var board_scale: float = minf((viewport.x - 24.0) / 941.0, usable_height / 1672.0)
	board.scale = Vector2.ONE * board_scale
	board.position = Vector2((viewport.x - 941.0 * board_scale) * 0.5, safe_top + 194.0 * ui_scale)
	_header.scale = Vector2.ONE * ui_scale
	_header.position = Vector2((viewport.x - 760.0 * ui_scale) * 0.5, safe_top)
	_footer.scale = Vector2.ONE * ui_scale
	_footer.position = Vector2((viewport.x - 760.0 * ui_scale) * 0.5, viewport.y - safe_bottom - 196.0 * ui_scale)
	if is_instance_valid(_modal):
		_modal.size = viewport
		_modal_panel.scale = Vector2.ONE * ui_scale
		_modal_panel.position = (viewport - _modal_panel.size * ui_scale) * 0.5

func _load_level(index: int, restore: bool = false) -> void:
	_close_modal()
	index = maxi(0, index)
	if index != save.level:
		save.legacy_level = false
	save.level = index
	if save.legacy_level:
		var legacy: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels.json"))
		current_level = legacy[index].duplicate(true)
		current_level["difficulty"] = {"name": "Classic", "colors": 6}
		current_level["layout"] = Layout.new().generate(index, save.campaign_seed)
	else:
		current_level = generator.generate(index, save.campaign_seed)
	puzzle.setup(current_level["pockets"])
	solver.known.clear()
	solver.register_level(current_level["pockets"], current_level["solution"])
	if restore and not save.saved_board.is_empty():
		puzzle.pockets = save.saved_board.duplicate(true)
		puzzle.moves = save.saved_moves
		puzzle.history = save.saved_history.duplicate(true)
	_selected = -1
	_keyboard_pocket = 0
	board.selected = -1
	board.keyboard_focus = -1
	save.board_layout = current_level.get("layout", {}).duplicate(true)
	board.apply_layout(save.board_layout)
	board.show_symbols = save.symbols
	board.refresh(puzzle.pockets, true)
	_busy = false
	_update_status()
	_persist()
	if Puzzle.solved(puzzle.pockets):
		_win()

func _update_status() -> void:
	_level_button.text = "LEVEL %02d  ···" % (save.level + 1)
	_moves_label.text = "%d %s" % [puzzle.moves, "move" if puzzle.moves == 1 else "moves"]
	_progress_label.text = "%d / %d together" % [puzzle.completed_count(), _group_count()]
	_difficulty_label.text = "%s · NO TIMER. NO RUSH." % str(current_level["difficulty"]["name"]).to_upper()
	_undo_button.disabled = puzzle.history.is_empty()
	_sound_button.icon = preload("res://assets/ui/sound.svg") if save.sound else preload("res://assets/ui/muted.svg")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(_modal):
				_close_modal()
			else:
				_deselect()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(_modal) or _busy:
			return
		match event.keycode:
			KEY_Z, KEY_U: _undo()
			KEY_H: _hint()
			KEY_R: _confirm_restart()
			KEY_M: _toggle_sound()
			KEY_LEFT: _keyboard_pocket = board.directional_neighbor(_keyboard_pocket, Vector2.LEFT)
			KEY_RIGHT: _keyboard_pocket = board.directional_neighbor(_keyboard_pocket, Vector2.RIGHT)
			KEY_UP: _keyboard_pocket = board.directional_neighbor(_keyboard_pocket, Vector2.UP)
			KEY_DOWN: _keyboard_pocket = board.directional_neighbor(_keyboard_pocket, Vector2.DOWN)
			KEY_ENTER, KEY_SPACE: _activate_pocket(_keyboard_pocket)
		board.keyboard_focus = _keyboard_pocket
		board.queue_redraw()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _busy or is_instance_valid(_modal):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pocket = board.hit_test(event.position)
			_press_position = event.position
			board.poke_at(event.position)
		else:
			var target: int = board.hit_test(event.position)
			if _press_pocket >= 0 and target >= 0:
				if target != _press_pocket and _press_position.distance_to(event.position) > 12:
					_select(_press_pocket)
					_activate_pocket(target)
				else:
					_activate_pocket(target)
			elif target < 0:
				_deselect()
			_press_pocket = -1

func _select(index: int, quiet: bool = false) -> void:
	_selected = index
	board.set_selection(index)
	if index >= 0 and not quiet:
		_play("select")

func _deselect() -> void:
	if _selected >= 0:
		_select(-1)
		_play("deselect")

func _activate_pocket(index: int) -> void:
	if _busy:
		return
	if _selected < 0:
		if not puzzle.pockets[index].is_empty():
			_select(index)
		return
	if _selected == index:
		_deselect()
		return
	var amount: int = Puzzle.transfer_size(puzzle.pockets, _selected, index)
	if amount > 0:
		_animate_pour(_selected, index, amount)
	else:
		_play("invalid")
		_toast("Choose a pocket with space")
		if not puzzle.pockets[index].is_empty():
			_select(index, true)

func _animate_pour(source: int, target: int, amount: int) -> void:
	_busy = true
	var old_complete: int = puzzle.completed_count()
	var merging: bool = not puzzle.pockets[target].is_empty() and puzzle.pockets[source].back() == puzzle.pockets[target].back()
	_select(-1)
	puzzle.pour(source, target)
	_play("pour")
	await board.play_pour(source, target, amount, puzzle.pockets)
	if Puzzle.solved(puzzle.pockets):
		pass  # _win plays the jingle.
	elif puzzle.completed_count() > old_complete:
		_play("complete")
	else:
		# Landings climb the pentatonic scale as a pocket fills up.
		_play("merge" if merging else "plop", SoundBank.scale_pitch(puzzle.pockets[target].size() - 1))
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(18)
	_busy = false
	_update_status()
	_persist()
	if Puzzle.solved(puzzle.pockets):
		_win()
	elif puzzle.completed_count() > old_complete:
		_toast("Better together. One happy jelly!")

func _undo() -> void:
	if _busy or not puzzle.undo():
		return
	_close_modal()
	_select(-1)
	board.refresh(puzzle.pockets)
	_play("undo")
	_update_status()
	_persist()
	_toast("A little step back. Take your time.")

func _confirm_restart() -> void:
	if _busy:
		return
	if puzzle.moves == 0:
		_toast("A fresh little puzzle, ready when you are")
		return
	_dialog("A fresh start?", "Give these little jellies another chance.\nYour other levels and records are safe.", 390)
	_modal_panel.add_child(_button("Keep playing", Vector2(45, 275), Vector2(220, 70), _close_modal))
	_modal_panel.add_child(_button("Start again", Vector2(285, 275), Vector2(230, 70), func() -> void: _load_level(save.level)))

func _hint() -> void:
	if _busy:
		return
	var hint: Vector2i = solver.get_hint(puzzle.pockets)
	if hint.x < 0:
		_toast("Try Undo to open up a little more room")
		return
	_selected = hint.x
	board.set_selection(hint.x, hint.y)
	_play("hint")
	_toast("This jelly would love the highlighted pocket")

func _toggle_sound() -> void:
	save.sound = not save.sound
	_update_status()
	_play("tap")
	_persist()

func _show_help() -> void:
	if _busy:
		return
	_dialog("Hello, little jellies.", "A soft sorting puzzle, at your own pace.", 680)
	var instructions: Label = _label("1   Tap the top jelly in any pocket.\n\n2   Tap any pocket with space, whatever its\n      color. You can drag, too.\n\n3   Bring four of a color together. They merge\n      into one happy jelly. Sort them all to finish.", 23, INK)
	instructions.position = Vector2(44, 167)
	instructions.size = Vector2(480, 272)
	_modal_panel.add_child(instructions)
	var symbols_button: Button = _button("Color freckles: " + ("ON" if save.symbols else "OFF"), Vector2(45, 460), Vector2(470, 62), func() -> void:
		save.symbols = not save.symbols
		board.show_symbols = save.symbols
		board.refresh(puzzle.pockets)
		_persist()
		_show_help())
	_modal_panel.add_child(symbols_button)
	var shortcuts: Label = _label("KEYBOARD   Arrows + Enter · Z undo · H hint · M sound", 15, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	shortcuts.position = Vector2(25, 538)
	shortcuts.size = Vector2(510, 33)
	_modal_panel.add_child(shortcuts)
	_modal_panel.add_child(_button("Let's get cozy", Vector2(145, 588), Vector2(270, 65), _close_modal))

func _show_levels(page: int = -1) -> void:
	if _busy:
		return
	if page < 0:
		page = save.level / 30
	page = clampi(page, 0, (save.unlocked - 1) / 30)
	_dialog("Little moments", "A new puzzle at every step.\nGentle beginnings, deeper tangles.", 870)
	for slot: int in 30:
		var index: int = page * 30 + slot
		var text: String = "%02d" % (index + 1)
		if save.best.has(str(index)):
			text += "  *"
		var button: Button = _button(text, Vector2(42 + (slot % 5) * 98, 188 + (slot / 5) * 81), Vector2(84, 66), _load_level.bind(index))
		button.add_theme_font_size_override("font_size", 19 if index >= 99 else 24)
		button.disabled = index >= save.unlocked
		if index == save.level:
			_style_button(button, Color("a2ad8d"), Color("fff8eb"))
		_modal_panel.add_child(button)
	var previous: Button = _button("Previous", Vector2(44, 690), Vector2(160, 60), _show_levels.bind(page - 1))
	previous.disabled = page == 0
	_modal_panel.add_child(previous)
	var next_page: Button = _button("Next", Vector2(356, 690), Vector2(160, 60), _show_levels.bind(page + 1))
	next_page.disabled = (page + 1) * 30 >= save.unlocked
	_modal_panel.add_child(next_page)
	var page_label: Label = _label(str(page + 1), 23, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	page_label.position = Vector2(208, 690)
	page_label.size = Vector2(144, 60)
	_modal_panel.add_child(page_label)
	_modal_panel.add_child(_button("Back to my jellies", Vector2(120, 775), Vector2(320, 62), _close_modal))

func _win() -> void:
	save.unlocked = maxi(save.unlocked, save.level + 2)
	var key: String = str(save.level)
	if not save.best.has(key) or int(save.best[key]) > puzzle.moves:
		save.best[key] = puzzle.moves
	_persist()
	_play("win")
	_start_confetti()
	_dialog("All together now.", "Every little jelly has found its people.\nLovely work.", 510)
	var score: Label = _label("%d gentle moves" % puzzle.moves, 35, INK, HORIZONTAL_ALIGNMENT_CENTER)
	score.position = Vector2(40, 218)
	score.size = Vector2(480, 65)
	_modal_panel.add_child(score)
	var next: Button = _button("Next little puzzle", Vector2(70, 325), Vector2(420, 77), _load_level.bind(save.level + 1))
	_style_button(next, Color("9ba785"), Color("fff9ed"))
	_modal_panel.add_child(next)
	_modal_panel.add_child(_button("Enjoy the moment", Vector2(135, 420), Vector2(290, 55), _close_modal, true))

func _dialog(title: String, subtitle: String, height: float) -> void:
	_close_modal()
	_modal = Control.new()
	_modal.size = size
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.31, 0.24, 0.17, 0.25)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	_modal_panel = Panel.new()
	_modal_panel.size = Vector2(560, height)
	var style: StyleBoxFlat = _rounded(Color("fff6e8"), 35)
	style.shadow_color = Color(0.35, 0.25, 0.14, 0.15)
	style.shadow_size = 30
	style.shadow_offset = Vector2(0, 12)
	_modal_panel.add_theme_stylebox_override("panel", style)
	_modal.add_child(_modal_panel)
	var heading: Label = _label(title, 39, INK, HORIZONTAL_ALIGNMENT_CENTER)
	heading.position = Vector2(25, 35)
	heading.size = Vector2(510, 65)
	_modal_panel.add_child(heading)
	var sub: Label = _label(subtitle, 22, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	sub.position = Vector2(25, 106)
	sub.size = Vector2(510, 67)
	_modal_panel.add_child(sub)
	_layout()

func _close_modal() -> void:
	if is_instance_valid(_modal):
		remove_child(_modal)
		_modal.queue_free()
	_modal = null

func _label(text: String, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, at: Vector2, dimensions: Vector2, action: Callable, flat: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_constant_override("h_separation", 12)
	button.add_theme_constant_override("icon_max_width", 30)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	_style_button(button, Color(1.0, 0.975, 0.928, 0.5) if flat else Color("fff7e9"), INK, flat)
	button.pressed.connect(_play.bind("tap"))
	button.pressed.connect(action)
	return button

func _style_button(button: Button, background: Color, foreground: Color, flat: bool = false) -> void:
	var normal: StyleBoxFlat = _rounded(background, 23)
	if not flat:
		normal.shadow_color = Color(0.48, 0.35, 0.2, 0.11)
		normal.shadow_size = 5
		normal.shadow_offset = Vector2(0, 4)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", _rounded(background.lightened(0.1), 23))
	button.add_theme_stylebox_override("pressed", _rounded(background.darkened(0.045), 23))
	button.add_theme_stylebox_override("disabled", _rounded(Color(0.96, 0.92, 0.85, 0.4), 23))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, foreground)
	button.add_theme_color_override("font_disabled_color", Color("c7b6a0"))

func _rounded(color: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	return style

func _toast(text: String) -> void:
	_toast_id += 1
	var id: int = _toast_id
	_message.text = text
	await get_tree().create_timer(3.4).timeout
	if id == _toast_id:
		_message.text = "Tap a top jelly, then any pocket with space"

## Color groups on this board: every four blobs of a color make one finished jelly.
func _group_count() -> int:
	var blobs: int = 0
	for pocket: Array in puzzle.pockets:
		blobs += pocket.size()
	return blobs / Puzzle.CAPACITY

func _play(sound: String, pitch: float = 1.0) -> void:
	if save.sound:
		sounds.play(sound, pitch)

func _persist() -> void:
	if not test_mode:
		save.write_save(puzzle)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not puzzle.pockets.is_empty():
			_persist()

func _start_confetti() -> void:
	_confetti_time = 0.0
	_confetti.clear()
	for i: int in 70:
		_confetti.append([Vector2(randf_range(0, size.x), randf_range(-500, -20)), Vector2(randf_range(-35, 35), randf_range(110, 220)), Jelly.COLORS[i % 6], randf_range(4, 9)])

func _process(delta: float) -> void:
	if _confetti.is_empty():
		return
	_confetti_time += delta
	for piece: Array in _confetti:
		piece[0] += piece[1] * delta
	if _confetti_time > 9:
		_confetti.clear()
	_confetti_layer.queue_redraw()
