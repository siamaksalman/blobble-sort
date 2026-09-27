GODOT ?= /Users/siamak/Downloads/Godot.app/Contents/MacOS/Godot

.PHONY: run import test playtest web android macos windows linux serve test-art
run:
	"$(GODOT)" --path .
import:
	"$(GODOT)" --headless --path . --editor --quit
test:
	"$(GODOT)" --headless --path . --script tests/test_puzzle.gd
	"$(GODOT)" --headless --path . --script tests/test_save_store.gd
	"$(GODOT)" --headless --path . --script tests/test_animation.gd
	"$(GODOT)" --headless --path . --script tests/test_sound.gd
	python3 tests/test_sound_harmony.py
	"$(GODOT)" --headless --path . --script tests/test_level_generator.gd
	"$(GODOT)" --headless --path . --script tests/test_board_layout.gd
	"$(GODOT)" --headless --path . --script tests/test_progression.gd
playtest:
	"$(GODOT)" --path . --rendering-method gl_compatibility --script tests/playtest.gd
test-art:
	"$(GODOT)" --path . --rendering-method gl_compatibility --script tests/test_reference_render.gd
	"$(GODOT)" --path . --rendering-method gl_compatibility --script tests/test_maze_art.gd
web:
	mkdir -p builds/web
	"$(GODOT)" --headless --path . --export-release Web
android:
	mkdir -p builds/android
	"$(GODOT)" --headless --path . --export-debug Android
macos:
	mkdir -p builds/desktop
	"$(GODOT)" --headless --path . --export-release macOS
windows:
	mkdir -p builds/desktop
	"$(GODOT)" --headless --path . --export-release Windows
linux:
	mkdir -p builds/desktop
	"$(GODOT)" --headless --path . --export-release Linux
serve:
	python3 -m http.server 8060 --directory builds/web
