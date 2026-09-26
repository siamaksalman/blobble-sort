extends SceneTree
## Plays a level's generated solution through the real game via taps and checks the win flow.
## Run: godot --headless --path . -s res://tests/test_playthrough.gd

func _init() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_level(3)
	for m: Array in LevelGenerator.generate(3).solution:
		while game.busy:
			await process_frame
		game._on_tap(m[0])
		game._on_tap(m[1])
	await create_timer(2.0).timeout
	var ok: bool = game.win_layer.visible and WaterSolver.is_solved(game.state, game.capacity)
	var cfg := ConfigFile.new()
	cfg.load("user://save.cfg")
	var saved := int(cfg.get_value("progress", "level", 0))
	print("win shown: %s, saved level: %d" % [game.win_layer.visible, saved])
	# Undo + hint smoke test on a fresh level
	game.start_level(10)
	game.show_hint()
	var hinted := 0
	for b in game.bottles:
		hinted += int(b.hint)
	print("hinted bottles: %d" % hinted)
	ok = ok and saved == 4 and hinted == 2
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
