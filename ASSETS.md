# Assets

- `shaders/reference_board.gdshader` and `scripts/board_layout.gd`: original code that builds seeded maze graphs and assembles open/closed gate sections sampled from the reference clay artwork. Matching coordinate transforms keep touch targets aligned. No new bitmap art is generated for maze variants.
- `assets/textures/reference_jellies.jpg`: unmodified copy of the user-supplied image. The jelly shader samples sprite regions directly, preserves their photographed colors/eyes, and stretches the body middle for merged groups.
- `assets/textures/clay_board.png`: produced with the built-in image-generation tool, editing the user-supplied `photo_5890847710519169109_w.jpg`. Used by all playable boards, with seeded geometry transformations that preserve the reference design. The original user image is not modified.
- `assets/fonts/Nunito.ttf`: Nunito variable font, downloaded from the Google Fonts repository. SIL Open Font License, included at `assets/fonts/OFL.txt`.
- `assets/audio/*.wav`: eleven original effects synthesized from scratch (bubble chirps, filtered noise, bell partials, a light echo) by `tools/generate_content.py` (needs `numpy`). No samples or third-party audio. All pitched cues are tuned to C major (main notes on the C major pentatonic) so overlapping sounds harmonize; `tests/test_sound_harmony.py` verifies this.
- `assets/icon.svg`, `assets/ui/*.svg`, and the jelly shader: original project code/art.

## Board generation prompt

Tool: built-in `image_gen` (no CLI or API-key fallback).

> Use case: precise-object-edit. Asset type: background board texture for an actual playable Godot puzzle game. Edit this supplied image. Remove EVERY colored jelly character and ALL eyes completely, including the long yellow, purple, green and pink characters and the small characters in horizontal passageways. Reconstruct the empty recessed warm beige floor of the maze underneath them. Preserve EXACTLY the existing outer cream clay board silhouette, dimensions, overhead camera, maze wall shapes, passage openings, position of every wall, lighting, creamy peach background, realistic fine clay texture, ambient occlusion shadows and 3D soft rounded edges. There should be NO colored objects, NO faces, NO text, NO additional holes, NO new walls. All twelve tall vertical capsule wells must be completely empty and visible; maintain the connecting paths between wells as in the reference. Do not crop or reposition anything. Portrait 9:16 full-frame image. This is an edit of the supplied image, preserve geometry as closely as possible.
