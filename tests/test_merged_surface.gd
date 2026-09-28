extends SceneTree
## Narrow source crops must not turn JPEG detail into long vertical stripes.

const Jelly = preload("res://scripts/jelly.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(840, 1250)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var blobs: Array[BlobbleJelly] = []
	for amount: int in range(2, 5):
		for color: int in 6:
			var blob: BlobbleJelly = Jelly.new()
			blob.configure(color, amount)
			blob.position = Vector2(color * 140, (amount - 2) * 420)
			viewport.add_child(blob)
			blob.set_process(false)
			blob.material.set_shader_parameter("seed", 0.0)
			blobs.append(blob)
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	var rendered: Image = viewport.get_texture().get_image()
	rendered.save_png("res://builds/merged-surfaces.png")
	for blob: BlobbleJelly in blobs:
		var worst_step: float = 0.0
		var roughness: float = 0.0
		var samples: int = 0
		for fraction: float in [0.25, 0.5, 0.75]:
			var y: int = int(blob.position.y + 18.0 + lerpf(80.0, blob.body_height - 64.0, fraction))
			for x: int in range(40, 100):
				var at: int = int(blob.position.x) + x
				# Smooth lighting varies gradually; fine vertical bands alternate sharply.
				var step: float = absf(rendered.get_pixel(at - 1, y).g - 2.0 * rendered.get_pixel(at, y).g + rendered.get_pixel(at + 1, y).g)
				worst_step = maxf(worst_step, step)
				roughness += step
				samples += 1
		var smooth_body: bool = worst_step < 0.02 and roughness / samples < 0.0045
		var label: String = "Color %d, stack %d has no narrow body stripes (peak %.4f, average %.4f)" % [blob.color_index, blob.count, worst_step, roughness / samples]
		if smooth_body:
			print("PASS: ", label)
		else:
			failures += 1
			push_error(label)
	viewport.free()
	print("Merged surface failures: ", failures)
	quit(1 if failures else 0)
