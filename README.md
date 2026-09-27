# Blobble

A Godot 4 color-sorting puzzle for touchscreens, browsers, and desktop. The cream clay board retains the reference-derived artwork, and the animated characters sample the original photo's jelly colors, highlights, and black eyes. Their movements, squash, and merging remain interactive.

## Play

Open `project.godot` with `/Users/siamak/Downloads/Godot.app`, then press **F6** with the main scene open or **F5** to run the project. From a terminal:

```sh
make run
```

Tap a pocket to select its top group, then tap another pocket. Equal colors stack together, and empty pockets accept any color. A pocket holds four blobs; adjacent equal colors become a single long jelly. Complete ten groups to finish. Dragging between pockets also works.

- **Undo**, **Restart**, and **Hint** are always free.
- Tap the **level badge** to choose an unlocked puzzle.
- Tap **?** for help and the optional color-freckle markings.
- **Arrows + Enter/Space** select pockets; **Z/U** undo, **H** hints, **R** restarts, **M** toggles sound, **Escape** dismisses.
- Progress, undo history, sound settings, and records save automatically.

The reference only defines an appearance, so the rules are an interpretation. The maze connections are decorative: groups transfer between any compatible pockets. Starting arrangements are generated at runtime to guarantee solvability; they do not reproduce every character position in the reference.

## Procedural progression

Every level is generated on demand from the campaign seed and level number. Restarting or reopening a level reproduces the same puzzle. There is no thirty-level ending, and the level picker has pages for unlocked progress.

Layouts preserve the reference's four-column, three-row proportions, broad sculpted channels, and full-size round jellies. The first board retains the original layout. Later levels generate a connected maze on the twelve pockets: a random spanning tree supplies eleven passages, then zero to four extra passages add loops. This changes which walls are open or closed and produces different branches, loops, and dead ends. Horizontal openings also vary between upper, middle, and lower positions.

The renderer assembles open passages and closed walls from sections of the same clay artwork, preserving its grain, rounded edges, and lighting. Small seeded spacing changes and mirroring add variation. Maze passages remain decorative under the existing sorting rules; they do not restrict transfers to compatible pockets.

Geometry uses its own seeded random stream, so maze appearance does not alter puzzle difficulty or solutions. Existing saves retain their color arrangement and undo history; layout version 3 regenerates the maze automatically. Reopening the same level reproduces the same walls and openings.

| Levels | Difficulty | Colors needing sorting | Color boundaries |
| --- | --- | --- | --- |
| 1–8 | Gentle | 2 | 1–4 |
| 9–16 | Easy | 3 | 5–8 |
| 17–24 | Thoughtful | 4 | 9–12 |
| 25–32 | Tricky | 5 | 13–16 |
| 33–38 | Expert | 6 | 17–19 |
| 39 onward | Expert | 6 | 20 |

A boundary is a change of color between adjacent blobs in a pocket. A legal pour removes at most one boundary, so this is a lower bound on the required moves. The target increases every two levels; new active colors enter every eight. Actual boards must meet both requirements. This measures structural complexity, not exact optimal solution length or a promise that every individual puzzle feels harder. Difficulty caps at the twelve-pocket board's expert setting; later levels continue generating new arrangements at that setting.

Generation reverses legal pours from a solved board and retains the inverse moves as a solution certificate. A bounded retry process and tested canonical-seed fallback enforce each target. No network, pre-generated campaign, or expensive solver is required to create a level. The original JSON catalog is retained only to preserve in-progress saves from the previous version; subsequent levels use the generator. Save version 2 records the campaign seed and generator version.

## Builds

| Target | Output | Command |
| --- | --- | --- |
| Browser / mobile browser | `builds/web/index.html` | `make web` |
| Android | `builds/android/Blobble.apk` | `make android` |
| macOS | `builds/desktop/Blobble-macOS.zip` | `make macos` |
| Windows x64 | `builds/desktop/Blobble.exe` | `make windows` |
| Linux x64 | `builds/desktop/Blobble.x86_64` | `make linux` |

To play the web build locally, run `make serve` and visit **http://localhost:8060**. The web files must be served over HTTP, rather than opened as `file://`. The exported folder can be served by any static web host. HTTPS enables installable PWA/offline behavior. No server or external API is needed during gameplay.

Web uses the Compatibility renderer and single-thread export. See the [Godot web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).

The Android APK is debug-signed for testing. Store distribution needs your release keystore. macOS uses ad-hoc signing; public distribution needs your Developer ID and notarization. An iOS export preset is included; native iOS packaging requires the matching iOS template, Xcode, and your Apple signing team. The web build can be used on iPhone and iPad without a native package.

The downloaded web/desktop templates are in the ignored `.export-templates/` directory. Android uses the local Godot installation's template. On a different machine, install matching export templates and update/clear the custom template paths in `export_presets.cfg`. Override `GODOT` when needed, for example `make run GODOT=godot`.

## Verification

```sh
make import
make test       # Rules, solvability/difficulty, layout geometry, saves/migration, pour/merge animation, sound cues
make playtest   # Real input, animation, hints, win/unlock, portrait/landscape captures
make test-art   # Reference fidelity plus rendered open/closed maze gates
```

`tests/web_playtest.cjs` runs a Chromium mobile/desktop test using Playwright. It checks WebGL startup, real touch input on two different layouts, persisted game data and geometry in IndexedDB, reload, level completion, and resizing. Set `PLAYWRIGHT_MODULE` and `CHROMIUM_PATH` if using an existing installation. Run `make serve` first.

Development follows the red → green → refactor cycle in [AGENTS.md](AGENTS.md). New behavior and bug fixes start with a failing test. The save regression suite uses a disposable file under `tests/.tmp/`; it never modifies player progress. Tests added to the original implementation were retrospective; subsequent fixes follow TDD.

Windows/Linux packages are cross-exported; running them requires their respective OS. Android APK signing is verified during export; no Android device was connected for native device testing.

## Implementation

- `scripts/puzzle.gd`: independent rules, move validation, history, win detection.
- `scripts/level_generator.gd`: deterministic runtime generation, certified solutions, and measured difficulty tiers.
- `scripts/board_layout.gd`: seeded connected maze graphs, opening variants, and reference-preserving pocket geometry.
- `shaders/reference_board.gdshader`: assembles original clay sections into each maze and transforms the matching touch coordinates.
- `shaders/jelly.gdshader`: samples the original jelly artwork, stretches body middles, and animates merge seams.
- `scripts/hint_solver.gd`: generated solution paths plus a bounded search for deviations. If no solution is found within the search budget, suggests undoing a move.
- `scripts/board.gd`, `scripts/jelly.gd`, `shaders/`: board layout and animated pieces.
- `scripts/game.gd`: responsive interface, input, transitions, level selection.
- `scripts/sound_bank.gd`: pooled playback of the eleven sound cues with gentle pitch variation.
- `scripts/save_store.gd`: validated versioned saves with atomic replacement.
- `tools/generate_content.py`: regenerates original synthesized sound effects. The legacy level data is kept immutable for save compatibility.

No plug-ins, paid SDKs, analytics, ads, or runtime network calls. See [ASSETS.md](ASSETS.md) for font licensing and artwork provenance. `builds/reference-design.png` is a rendered art fixture arranged similarly to the photo; the playable campaign retains its generated puzzles. The game is not a pixel-for-pixel reproduction of every character position in the photograph.

Open `builds/maze-variants.html` for a side-by-side comparison with a show/hide-jellies toggle. `builds/maze-empty-02.png` through `maze-empty-05.png` show four maze structures without pieces. Matching `maze-art-*.png` images use one shared puzzle arrangement to compare the artwork.
