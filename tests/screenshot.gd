extends SceneTree
## Renders the main scene and saves a PNG. Usage (non-headless):
## godot --path . -s res://tests/screenshot.gd -- <level> <out.png> [taps...]
## taps are bottle indices to tap in sequence; the final pour is captured as a
## sequence of frames <out>_0.png, <out>_1.png, ...

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
	if args.size() > 2:
		var t := 0.0
		for n in 6:
			await create_timer(0.17).timeout
			t += 0.17
			root.get_texture().get_image().save_png(args[1].replace(".png", "_%d.png" % n))
	else:
		for f in 20:
			await process_frame
		root.get_texture().get_image().save_png(args[1])
	quit()
