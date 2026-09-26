# Filler Machine — Water Sort Puzzle (Godot 4.7)

Tap a bottle, then tap another to pour. Only matching colors stack; finish when every
bottle holds a single color (finished bottles get a cork).

## Levels
Infinite, procedurally generated, deterministic per level number
(`scripts/level_generator.gd`). Every level is verified solvable by the DFS solver in
`scripts/water_solver.gd` before it is shown. Difficulty ramps by:

| Levels | Bottle size | Colors | Extra rules |
|-------|-------------|--------|-------------|
| 1–45  | 4 | 3 → 14 (+1 every 4 levels) | from level 6, no equal colors stacked together |
| 46–80 | 4 | 14 | hardest of 8 solvable candidates |
| 81+   | 5 | 10 → 13 | hardest of 6 candidates |

"Hardest" means the level that made the solver search the most.

## Controls
Restart, Undo (Z), +Tube (one extra empty bottle per level), Hint (H; runs the solver
from your current position). In debug builds, N skips a level.

Each level has a stopwatch (starts on your first pour, pauses when the window loses focus)
and a 1–3 star rating: 3 for finishing within the generator's solution length, 2 within
1.5x, 1 otherwise; Hint or +Tube caps it at 2. Best stars and best time are saved per level.

## Tests
```sh
godot --headless --path . -s res://tests/test_levels.gd -- 1 200   # every level solvable
godot --headless --path . -s res://tests/test_scoring.gd           # star rating + time format
godot --headless --path . -s res://tests/test_playthrough.gd       # tap-through + win flow
godot --headless --path . -s res://tests/test_difficulty.gd -- 120 # difficulty ramp + tier rules (~30 s)
godot --path . -s res://tests/screenshot.gd -- 30 shot.png          # render a level
```

## Sound
All sound effects are synthesized by `tools/make_sfx.py` (needs numpy) into `assets/sfx/`,
and played by the `Sfx` autoload (`scripts/sfx.gd`). M or the speaker button mutes (saved).
- **Pour:** a seamless water loop whose pitch rises as the target bottle fills, plus a
  splash when the stream lands and a soft "tock" when the bottle is set back down.
- **Bottles:** mellow tapped-glass tones for pick up / put down, a cork pop + rising chime
  when a bottle is completed, and a falling double knock for invalid moves.
- **Mobile practices:** 48 kHz mono, energy kept above ~300 Hz for phone speakers, short
  UI sounds (80–300 ms), everything pitched in C major pentatonic so overlapping sounds
  stay consonant (bottle taps step down the scale as the bottle fills), each clip loudness-normalized (BS.1770 momentary max, -16 to
  -26 LUFS with gameplay above UI, -1 dBFS peak), random pitch/volume per play against
  repetition fatigue, per-clip voice caps, separate SFX/UI buses and a limiter on Master.

To tweak a sound, edit its function in `tools/make_sfx.py` and rerun it.

## Exporting (mobile / web / desktop)
Presets for Web, Android, iOS, macOS, Windows and Linux are in `export_presets.cfg`.
First install the export templates: Editor → Manage Export Templates → Download.
- **Web:** `godot --headless --export-release "Web" build/web/index.html` (single-threaded, so it runs on any static host)
- **Android:** set the Android SDK + debug keystore in Editor Settings → Export → Android
- **iOS:** needs Xcode and your App Store Team ID in the iOS preset

## Branding
- **Splash:** Godot's boot splash shows `assets/splash.png` (RedCrow Studio). Then
  `scenes/intro.tscn` makes the crow hop and fades into the game (tap to skip).
- **Icons:** drawn with the game's own bottle renderer. To regenerate them all:
  ```sh
  godot --path . -s res://tools/render_icon.gd -- /tmp/icon_src   # 2048px renders
  python3 tools/make_icons.py /tmp/icon_src                         # needs Pillow
  ```
  Output: `assets/icon.png` (project/web/Linux), `icon.icns` (macOS), `icon.ico` (Windows),
  and `assets/icons/` (iOS 1024, Android legacy + adaptive + monochrome, PWA). All of these
  are already wired into `export_presets.cfg`.
