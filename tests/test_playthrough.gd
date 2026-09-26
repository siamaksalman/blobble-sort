extends SceneTree
## Plays a level's generated solution through the real game via taps and checks the win flow.
## Run: godot --headless --path . -s res://tests/test_playthrough.gd

func _init() -> void:
	await process_frame # let autoloads (Sfx) register before game.gd compiles
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
	# Playing the generated solution exactly hits the target: 3 stars, timer ran and stopped.
	var best: Dictionary = game._load_best(3)
	var t_won: float = game.elapsed
	await create_timer(0.3).timeout
	print("stars: %d, time: %.2f, best: %s" % [game.earned_stars, t_won, best])
	ok = ok and game.earned_stars == 3 and t_won > 0 and game.elapsed == t_won
	ok = ok and best.stars == 3 and best.time <= t_won
	# Replay resets the board and timer and shows the saved best.
	game.restart_level()
	print("after replay: win %s, elapsed %.2f, best shown %s" % [
		game.win_layer.visible, game.elapsed, game.best_box.visible])
	ok = ok and not game.win_layer.visible and game.elapsed == 0.0 and game.best_box.visible
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
