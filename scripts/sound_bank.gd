class_name BlobbleSoundBank
extends Node
## A small pool of voices so overlapping cues ring out instead of cutting each other off.

const VOICES: int = 8
const CUES: Dictionary = {
	"select": preload("res://assets/audio/select.wav"),
	"deselect": preload("res://assets/audio/deselect.wav"),
	"pour": preload("res://assets/audio/pour.wav"),
	"plop": preload("res://assets/audio/plop.wav"),
	"merge": preload("res://assets/audio/merge.wav"),
	"complete": preload("res://assets/audio/complete.wav"),
	"invalid": preload("res://assets/audio/invalid.wav"),
	"undo": preload("res://assets/audio/undo.wav"),
	"hint": preload("res://assets/audio/hint.wav"),
	"tap": preload("res://assets/audio/tap.wav"),
	"win": preload("res://assets/audio/win.wav")}
## Mix level per cue in dB, so frequent small sounds stay behind rewarding ones.
const LEVELS: Dictionary = {"tap": -6.0, "pour": -4.0, "deselect": -3.0, "invalid": -2.0}
## Every cue is tuned to C major; transposing by these semitones keeps overlaps consonant.
const PENTATONIC: Array[int] = [0, 2, 4, 7, 9]

var enabled: bool = true
## Every cue played, newest last; lets tests and tools observe audio without hearing it.
var history: Array[String] = []
var voices: Array[AudioStreamPlayer] = []
## Index of the voice used by the most recent cue.
var last_voice: int = 0

func _ready() -> void:
	for i: int in VOICES:
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)

## Pitch ratio for a step up the C major pentatonic (0 = as recorded, 5 = an octave up).
static func scale_pitch(step: int) -> float:
	var octave: int = floori(step / float(PENTATONIC.size()))
	return pow(2.0, (octave * 12 + PENTATONIC[posmod(step, PENTATONIC.size())]) / 12.0)

## `pitch` should come from scale_pitch so the cue stays in key.
func play(cue: String, pitch: float = 1.0) -> void:
	if not enabled or not CUES.has(cue):
		return
	history.append(cue)
	last_voice = _free_voice()
	var voice: AudioStreamPlayer = voices[last_voice]
	voice.stream = CUES[cue]
	voice.pitch_scale = pitch
	voice.volume_db = LEVELS.get(cue, 0.0)
	voice.play()

func active_voices() -> int:
	return voices.filter(func(voice: AudioStreamPlayer) -> bool: return voice.playing).size()

func _free_voice() -> int:
	for i: int in voices.size():
		if not voices[i].playing:
			return i
	# All busy: steal voices round-robin.
	return (last_voice + 1) % voices.size()
