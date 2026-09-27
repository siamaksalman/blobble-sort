extends SceneTree
## Sound cues: clean source audio, overlapping playback, and the right cue for each game event.

const SoundBank = preload("res://scripts/sound_bank.gd")
const GAME = preload("res://scripts/game.gd")
const REQUIRED: Array[String] = ["select", "deselect", "pour", "plop", "merge", "complete", "invalid", "undo", "hint", "tap", "win"]
var checks: int = 0
var failures: int = 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	# A script error stops the coroutine; fail instead of hanging.
	create_timer(30.0).timeout.connect(func() -> void:
		push_error("Sound checks timed out")
		quit(1))
	call_deferred("run")

## Reads a 16-bit mono PCM source file as floats in -1..1.
func samples(path: String) -> Dictionary:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var result: Dictionary = {"rate": 0, "data": PackedFloat32Array()}
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return result
	var offset: int = 12
	while offset + 8 <= bytes.size():
		var id: String = bytes.slice(offset, offset + 4).get_string_from_ascii()
		var length: int = bytes.decode_u32(offset + 4)
		if id == "fmt ":
			if bytes.decode_u16(offset + 10) != 1 or bytes.decode_u16(offset + 22) != 16:
				return result
			result.rate = bytes.decode_u32(offset + 12)
		elif id == "data":
			var data: PackedFloat32Array = PackedFloat32Array()
			data.resize(length / 2)
			for i: int in data.size():
				data[i] = bytes.decode_s16(offset + 8 + i * 2) / 32768.0
			result.data = data
		offset += 8 + length + (length % 2)
	return result

func check_asset(cue: String) -> void:
	var sound: Dictionary = samples("res://assets/audio/%s.wav" % cue)
	var data: PackedFloat32Array = sound.data
	check(sound.rate >= 22050 and data.size() > 0, "%s is readable mono 16-bit audio" % cue)
	if data.is_empty():
		return
	var seconds: float = data.size() / float(sound.rate)
	check(seconds >= 0.04 and seconds <= 2.5, "%s has a sensible length (%.2fs)" % [cue, seconds])
	var peak: float = 0.0
	var energy: float = 0.0
	for value: float in data:
		peak = maxf(peak, absf(value))
		energy += value * value
	check(peak >= 0.25 and peak <= 0.95, "%s is audible without clipping (peak %.2f)" % [cue, peak])
	var rms: float = sqrt(energy / data.size())
	check(rms >= 0.02 and rms <= 0.3, "%s sits in a balanced loudness range (rms %.3f)" % [cue, rms])
	check(absf(data[0]) < 0.02 and absf(data[data.size() - 1]) < 0.02, "%s starts and ends without a click" % cue)

func last_cue(game: Control) -> String:
	return game.sounds.history.back() if not game.sounds.history.is_empty() else ""

func latest_pitch(game: Control) -> float:
	return game.sounds.voices[game.sounds.last_voice].pitch_scale

func fill(first: Array, second: Array, third: Array = [], fourth: Array = []) -> Array:
	var state: Array = [first, second, third, fourth]
	for i: int in 8:
		state.append([])
	return state

func stage(game: Control, state: Array) -> void:
	game.puzzle.setup(state)
	game._select(-1)
	game.board.refresh(game.puzzle.pockets)

func run() -> void:
	for cue: String in REQUIRED:
		check(SoundBank.CUES.has(cue), "Sound bank defines the %s cue" % cue)
		check_asset(cue)

	var bank: BlobbleSoundBank = SoundBank.new()
	root.add_child(bank)
	bank.play("plop")
	bank.play("merge")
	check(bank.active_voices() == 2, "Overlapping cues play together instead of cutting each other off")
	var tuned: bool = true
	for voice: AudioStreamPlayer in bank.voices:
		if voice.playing:
			tuned = tuned and voice.pitch_scale == 1.0
	check(tuned, "Cues play exactly in tune, never randomly detuned")
	var steps: Array = [0, 1, 2, 3, 4].map(func(step: int) -> float: return SoundBank.scale_pitch(step))
	var expected: Array = [0, 2, 4, 7, 9].map(func(semitones: int) -> float: return pow(2.0, semitones / 12.0))
	var on_scale: bool = true
	for i: int in steps.size():
		on_scale = on_scale and is_equal_approx(steps[i], expected[i])
	check(on_scale, "Pitch steps follow the C major pentatonic scale")
	check(is_equal_approx(SoundBank.scale_pitch(5), 2.0), "Pitch steps wrap into the next octave")
	bank.enabled = false
	var heard: int = bank.history.size()
	bank.play("tap")
	check(bank.history.size() == heard, "A muted sound bank stays silent")
	bank.queue_free()

	var game: Control = GAME.new()
	game.test_mode = true
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(game)
	await process_frame
	game.save.sound = true

	stage(game, fill([1, 2], [2], [], [3, 3, 3, 3]))
	game._activate_pocket(0)
	check(last_cue(game) == "select", "Picking up a jelly plays the select cue")
	game._activate_pocket(0)
	check(last_cue(game) == "deselect", "Putting a jelly back plays the deselect cue")
	game._activate_pocket(0)
	game._activate_pocket(3)
	check(last_cue(game) == "invalid", "A refused move plays a soft invalid cue")

	stage(game, fill([1, 2], [2], [], [3, 3, 3]))
	game._activate_pocket(0)
	var poured: int = game.sounds.history.size()
	await game._animate_pour(0, 1, 1)
	var pour_cues: Array = game.sounds.history.slice(poured)
	check(pour_cues.size() >= 2 and pour_cues[0] == "pour", "A pour whooshes as the jelly takes off")
	check(last_cue(game) == "merge", "Landing on the same color plays the gooey merge cue")

	stage(game, fill([1], [2], [], [3, 3, 3]))
	await game._animate_pour(0, 2, 1)
	check(last_cue(game) == "plop", "Landing in an empty pocket plops")
	check(is_equal_approx(latest_pitch(game), SoundBank.scale_pitch(0)), "The first jelly in a pocket plops on the root note")
	stage(game, fill([1], [2], [], [3, 3, 3]))
	await game._animate_pour(0, 1, 1)
	check(last_cue(game) == "plop", "Landing on a different color plops without a merge cue")
	stage(game, fill([1, 1], [1], [2]))
	await game._animate_pour(0, 1, 2)
	check(last_cue(game) == "merge" and is_equal_approx(latest_pitch(game), SoundBank.scale_pitch(2)), "Landings climb the scale as a pocket fills")

	stage(game, fill([1], [3], [], [3, 3, 3]))
	await game._animate_pour(1, 3, 1)
	check(last_cue(game) == "complete", "Filling a pocket with one color chimes")

	game._undo()
	check(last_cue(game) == "undo", "Undo plays its own cue")
	stage(game, fill([3], [3, 3, 3]))
	game._hint()
	check(last_cue(game) == "hint", "A hint twinkles")
	game._select(-1)

	game._level_button.pressed.emit()
	check(last_cue(game) == "tap", "Interface buttons tap")
	game._close_modal()

	stage(game, fill([1, 1, 1], [1]))
	await game._animate_pour(1, 0, 1)
	check(last_cue(game) == "win", "Solving the board plays the win jingle")
	game._close_modal()

	game.save.sound = false
	var before_mute: int = game.sounds.history.size()
	game._hint()
	check(game.sounds.history.size() == before_mute, "Muted games stay silent")

	print("Sound checks: %d passed, %d failed" % [checks - failures, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
