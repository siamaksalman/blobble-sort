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

## Tests
```sh
godot --headless --path . -s res://tests/test_levels.gd -- 1 200   # every level solvable
godot --headless --path . -s res://tests/test_playthrough.gd       # tap-through + win flow
godot --path . -s res://tests/screenshot.gd -- 30 shot.png          # render a level
```

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
