GODOT ?= /Users/siamak/Downloads/Godot.app/Contents/MacOS/Godot

.PHONY: run import test playtest web android macos windows linux serve
run:
	"$(GODOT)" --path .
import:
	"$(GODOT)" --headless --path . --editor --quit
test:
	"$(GODOT)" --headless --path . --script tests/test_puzzle.gd
	"$(GODOT)" --headless --path . --script tests/test_save_store.gd
	"$(GODOT)" --headless --path . --script tests/test_animation.gd
	"$(GODOT)" --headless --path . --script tests/test_level_generator.gd
	"$(GODOT)" --headless --path . --script tests/test_progression.gd
playtest:
	"$(GODOT)" --path . --rendering-method gl_compatibility --script tests/playtest.gd
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
