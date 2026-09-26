extends SceneTree
## Renders the app icon art with the game's own Bottle drawing (non-headless):
##   godot --path . -s res://tools/render_icon.gd -- <out_dir>
## Writes icon_full.png (background + bottles), icon_fg.png (bottles only, transparent)
## and icon_bg.png (background only) at 2048x2048; tools/make_icons.py resizes them.

const SIZE := 2048


class IconArt extends Node2D:
	var with_bg := true
	var with_fg := true

	func _ready() -> void:
		if not with_fg:
			return
		# Three bottles on a shelf: mixed, finished (corked), mixed.
		var specs := [["GHAH", -1], ["GGGG", 0], ["AHGA", 1]]
		for spec in specs:
			var b := Bottle.new()
			b.capacity = 4
			b.scale = Vector2(4.3, 4.3)
			b.position = Vector2(SIZE / 2.0 + spec[1] * 370, SIZE * 0.815)
			b.home_pos = b.position
			add_child(b)
			b.set_layers(spec[0])
			if spec[1] != 0:
				b.scale *= 0.9

	func _draw() -> void:
		if with_bg:
			# Radial slate glow, drawn as a vertex-colored grid.
			var n := 48
			var cell := SIZE / float(n)
			var center := Vector2(SIZE * 0.5, SIZE * 0.4)
			for yi in n:
				for xi in n:
					var pts := PackedVector2Array([
						Vector2(xi, yi) * cell, Vector2(xi + 1, yi) * cell,
						Vector2(xi + 1, yi + 1) * cell, Vector2(xi, yi + 1) * cell])
					var cols := PackedColorArray()
					for p in pts:
						var t := clampf(p.distance_to(center) / (SIZE * 0.78), 0.0, 1.0)
						cols.append(Color("6a8191").lerp(Color("232a30"), t * t * (3 - 2 * t)))
					draw_polygon(pts, cols)
		if with_fg:
			var shelf := StyleBoxFlat.new()
			shelf.bg_color = Color("c98b62")
			shelf.border_width_bottom = 34
			shelf.border_color = Color("9a6446")
			shelf.set_corner_radius_all(40)
			shelf.anti_aliasing = true
			draw_style_box(shelf, Rect2(SIZE * 0.13, SIZE * 0.815 - 8, SIZE * 0.74, 96))


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	for variant in [["full", true, true], ["fg", false, true], ["bg", true, false]]:
		var vp := SubViewport.new()
		vp.size = Vector2i(SIZE, SIZE)
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var art := IconArt.new()
		art.with_bg = variant[1]
		art.with_fg = variant[2]
		vp.add_child(art)
		for f in 4:
			await process_frame
		vp.get_texture().get_image().save_png("%s/icon_%s.png" % [out, variant[0]])
		vp.queue_free()
	quit()
