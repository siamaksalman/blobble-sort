extends SceneTree
## The studio splash opens the game, guards the board while visible, and gets out of the way.

const Splash = preload("res://scripts/studio_splash.gd")
const GAME = preload("res://scripts/game.gd")
const SAVE_PATH: String = "res://tests/.tmp/splash_save.json"
var checks: int = 0
var failures: int = 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		push_error("Splash checks timed out")
		quit(1))
	call_deferred("run")

func tap(target: Control) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = target.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func run() -> void:
	root.size = Vector2i(540, 960)
	# Left alone, the splash shows the studio logo, then leaves by itself.
	var splash: Control = Splash.new()
	var done: Array[bool] = [false]
	splash.finished.connect(func() -> void: done[0] = true)
	root.add_child(splash)
	await process_frame
	check(splash.get_global_rect().has_point(Vector2(5, 5)) and splash.get_global_rect().has_point(Vector2(535, 955)), "Splash covers the whole screen")
	check(splash.mouse_filter == Control.MOUSE_FILTER_STOP, "Splash blocks touches from reaching the board")
	var logo: TextureRect = splash.find_child("Logo", true, false)
	check(logo != null and logo.texture != null and logo.texture.resource_path.ends_with("redcrow_studio.png"), "Splash shows the Redcrow Studio logo")
	await create_timer(Splash.DURATION + 0.4).timeout
	check(done[0], "Splash finishes on its own")
	check(not is_instance_valid(splash), "Finished splash removes itself")
	# A tap skips straight to the game.
	splash = Splash.new()
	done[0] = false
	splash.finished.connect(func() -> void: done[0] = true)
	root.add_child(splash)
	await create_timer(0.3).timeout
	await tap(splash)
	await create_timer(Splash.FADE_OUT + 0.2).timeout
	check(done[0] and not is_instance_valid(splash), "Tapping skips the splash")
	# The game opens with the splash, except in test mode.
	DirAccess.make_dir_recursive_absolute("res://tests/.tmp")
	DirAccess.remove_absolute(SAVE_PATH)
	var game: Control = GAME.new()
	game.save.path = SAVE_PATH
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(game)
	await process_frame
	check(game.find_child("StudioSplash", true, false) != null, "Launching the game shows the studio splash")
	game.queue_free()
	var quiet: Control = GAME.new()
	quiet.test_mode = true
	quiet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(quiet)
	await process_frame
	check(quiet.find_child("StudioSplash", true, false) == null, "Test mode skips the splash")
	quiet.queue_free()
	await process_frame
	DirAccess.remove_absolute(SAVE_PATH)
	print("Splash checks: ", checks, ", failures: ", failures)
	quit(1 if failures else 0)
