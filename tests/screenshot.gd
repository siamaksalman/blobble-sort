extends SceneTree
## Renders the main scene and saves a PNG. Usage (non-headless):
## godot --path . -s res://tests/screenshot.gd -- <level> <out.png> [taps...]
## taps are bottle indices to tap in sequence (for testing pours).

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_level(int(args[0]))
	for i in range(2, args.size()):
		for f in 3:
			await process_frame
		while game.busy:
			await process_frame
		game._on_tap(int(args[i]))
		if i % 2 == 1:
			await create_timer(0.3).timeout # mid-pour snapshot on last pair
	for f in (20 if args.size() <= 2 else 1):
		await process_frame
	root.get_texture().get_image().save_png(args[1])
	quit()
