extends SceneTree
## Check visible facial motion on every color, both round and merged.

const Jelly = preload("res://scripts/jelly.gd")
var failures: int = 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)
	else:
		print("PASS: ", label)

func _initialize() -> void:
	call_deferred("run")

func eyes(image: Image, offset: Vector2i) -> Vector3:
	var area: float = 0.0
	var center: Vector2 = Vector2.ZERO
	for y: int in range(25, 85):
		for x: int in range(40, 110):
			var pixel: Color = image.get_pixelv(offset + Vector2i(x, y))
			if maxf(pixel.r, maxf(pixel.g, pixel.b)) < 0.22:
				area += 1.0
				center += Vector2(x, y)
	center /= maxf(area, 1.0)
	return Vector3(center.x, center.y, area)

func sample_faces(viewport: SubViewport, blobs: Array[BlobbleJelly], seconds: float) -> Array[Vector3]:
	for blob: BlobbleJelly in blobs:
		blob.material.set_shader_parameter("clock", seconds)
	await process_frame
	RenderingServer.force_draw()
	var rendered: Image = viewport.get_texture().get_image()
	var faces: Array[Vector3] = []
	for blob: BlobbleJelly in blobs:
		faces.append(eyes(rendered, Vector2i(blob.position)))
	return faces

func catchlights(image: Image, offset: Vector2i) -> Array[Vector3]:
	var split: int = int(eyes(image, offset).x)
	var result: Array[Vector3] = []
	for side: int in 2:
		var bounds: Rect2i = Rect2i()
		for y: int in range(25, 85):
			for x: int in range(40 if side == 0 else split, split if side == 0 else 110):
				var color: Color = image.get_pixelv(offset + Vector2i(x, y))
				if maxf(color.r, maxf(color.g, color.b)) < 0.22:
					var pixel: Rect2i = Rect2i(x, y, 1, 1)
					bounds = pixel if not bounds.has_area() else bounds.merge(pixel)
		var center: Vector2 = Vector2.ZERO
		var count: int = 0
		for y: int in range(bounds.position.y, bounds.end.y):
			for x: int in range(bounds.position.x, bounds.end.x):
				var color: Color = image.get_pixelv(offset + Vector2i(x, y))
				var low: float = minf(color.r, minf(color.g, color.b))
				var high: float = maxf(color.r, maxf(color.g, color.b))
				if low > 0.6 and high - low < 0.15:
					center += Vector2(x, y)
					count += 1
		center /= maxf(float(count), 1.0)
		result.append(Vector3(center.x, center.y, count))
	return result

func check_catchlights(viewport: SubViewport, blobs: Array[BlobbleJelly]) -> void:
	for blob: BlobbleJelly in blobs:
		blob.material.set_shader_parameter("seed", 0.0)
	await sample_faces(viewport, blobs, 0.0)
	var neutral: Image = viewport.get_texture().get_image()
	await sample_faces(viewport, blobs, 8.2)
	var glance: Image = viewport.get_texture().get_image()
	await sample_faces(viewport, blobs, 5.88)
	var blink: Image = viewport.get_texture().get_image()
	for i: int in blobs.size():
		var offset: Vector2i = Vector2i(blobs[i].position)
		var resting: Array[Vector3] = catchlights(neutral, offset)
		var looking: Array[Vector3] = catchlights(glance, offset)
		var closed: Array[Vector3] = catchlights(blink, offset)
		for side: int in 2:
			check(resting[side].z >= 1 and resting[side].z <= 8,
				"Blob %d eye %d has a small white catchlight" % [i, side])
			check(looking[side].z >= 1 and looking[side].z <= 8 and looking[side].x > resting[side].x + 0.4,
				"Blob %d eye %d catchlight follows its glance" % [i, side])
			check(closed[side].z == 0, "Blob %d eye %d hides its catchlight when blinking" % [i, side])

func check_gestures(viewport: SubViewport, blobs: Array[BlobbleJelly]) -> void:
	# Give each color the same timeline to compare the visible gestures.
	for blob: BlobbleJelly in blobs:
		blob.material.set_shader_parameter("seed", 0.0)
	var neutral: Array[Vector3] = await sample_faces(viewport, blobs, 0.0)
	var first_glance: Array[Vector3] = await sample_faces(viewport, blobs, 8.2)
	var next_glance: Array[Vector3] = await sample_faces(viewport, blobs, 44.2)
	var first_blink: Array[Vector3] = await sample_faces(viewport, blobs, 11.56)
	var between_blinks: Array[Vector3] = await sample_faces(viewport, blobs, 11.75)
	var second_blink: Array[Vector3] = await sample_faces(viewport, blobs, 11.9)
	var squint: Array[Vector3] = await sample_faces(viewport, blobs, 18.2)
	viewport.get_texture().get_image().save_png("res://builds/eyes-squint.png")
	var settled: Array[Vector3] = await sample_faces(viewport, blobs, 20.2)
	for i: int in blobs.size():
		check(first_glance[i].x > neutral[i].x + 0.4 and next_glance[i].x < neutral[i].x - 0.4,
			"Blob %d changes its glance direction between gestures" % i)
		check(first_blink[i].z < neutral[i].z * 0.45 and second_blink[i].z < neutral[i].z * 0.45
			and between_blinks[i].z > neutral[i].z * 0.4, "Blob %d occasionally gives a double blink" % i)
		check(squint[i].z > neutral[i].z * 0.2 and squint[i].z < neutral[i].z * 0.5,
			"Blob %d squeezes its eyes into a happy smile" % i)
		check(settled[i].distance_to(neutral[i]) < 1.0, "Blob %d returns to its neutral expression" % i)

func eye_shapes(image: Image, offset: Vector2i, split_at: int = -1) -> Array[Vector3]:
	var split: int = int(eyes(image, offset).x) if split_at < 0 else split_at
	var shapes: Array[Vector3] = []
	for side: int in 2:
		var points: Array[Vector2] = []
		var center: Vector2 = Vector2.ZERO
		var top: int = 85
		var bottom: int = 25
		for y: int in range(25, 85):
			for x: int in range(40 if side == 0 else split, split if side == 0 else 110):
				var color: Color = image.get_pixelv(offset + Vector2i(x, y))
				if maxf(color.r, maxf(color.g, color.b)) < 0.22:
					points.append(Vector2(x, y))
					center += Vector2(x, y)
					top = mini(top, y)
					bottom = maxi(bottom, y)
		center /= maxf(points.size(), 1.0)
		var covariance: float = 0.0
		var variance: float = 0.0
		for point: Vector2 in points:
			var delta: Vector2 = point - center
			covariance += delta.x * delta.y
			variance += delta.x * delta.x
		shapes.append(Vector3(points.size(), bottom - top + 1, covariance / maxf(variance, 1.0)))
	return shapes

func check_moods(viewport: SubViewport, blobs: Array[BlobbleJelly]) -> void:
	for blob: BlobbleJelly in blobs:
		blob.material.set_shader_parameter("seed", 0.0)
	await sample_faces(viewport, blobs, 0.0)
	var neutral: Image = viewport.get_texture().get_image()
	var names: Array[String] = ["sleepy", "curious", "pout"]
	for mood: int in 3:
		await sample_faces(viewport, blobs, 38.2 + mood * 20.0)
		var expression: Image = viewport.get_texture().get_image()
		expression.save_png("res://builds/eyes-%s.png" % names[mood])
		for i: int in blobs.size():
			var offset: Vector2i = Vector2i(blobs[i].position)
			var before: Array[Vector3] = eye_shapes(neutral, offset)
			var after: Array[Vector3] = eye_shapes(expression, offset)
			if mood == 0:
				check(after[0].y < before[0].y * 0.8 and after[1].y < before[1].y * 0.8,
					"Blob %d looks bored with two drooping eyes" % i)
			elif mood == 1:
				check(after[0].x / before[0].x > after[1].x / before[1].x + 0.25,
					"Blob %d looks confused with one eye more open" % i)
			else:
				check(after[0].z > 0.08 and after[1].z < -0.08,
					"Blob %d makes a playful pout with gently slanting eyes" % i)
			check(after[0].x > before[0].x * 0.3 and after[1].x > before[1].x * 0.3,
				"Blob %d keeps its eyes visible during %s" % [i, names[mood]])
		await sample_faces(viewport, blobs, 41.2 + mood * 20.0)
		var settled: Image = viewport.get_texture().get_image()
		for i: int in blobs.size():
			var offset: Vector2i = Vector2i(blobs[i].position)
			check(eyes(settled, offset).distance_to(eyes(neutral, offset)) < 1.0,
				"Blob %d relaxes after looking %s" % [i, names[mood]])

func happy_curve(image: Image, offset: Vector2i) -> float:
	var middle: float = eyes(image, offset).x
	var pixels: Array[Vector2] = []
	var center: Vector2 = Vector2.ZERO
	for y: int in range(25, 85):
		for x: int in range(40, int(middle)):
			var color: Color = image.get_pixelv(offset + Vector2i(x, y))
			if maxf(color.r, maxf(color.g, color.b)) < 0.22:
				pixels.append(Vector2(x, y))
				center += Vector2(x, y)
	center /= maxf(pixels.size(), 1.0)
	var inner: Vector2 = Vector2.ZERO
	var outer: Vector2 = Vector2.ZERO
	for point: Vector2 in pixels:
		if absf(point.x - center.x) < 1.5:
			inner += Vector2(point.y, 1)
		elif absf(point.x - center.x) > 3.0:
			outer += Vector2(point.y, 1)
	return outer.x / maxf(outer.y, 1.0) - inner.x / maxf(inner.y, 1.0)

func check_playful_faces(viewport: SubViewport, blobs: Array[BlobbleJelly]) -> void:
	for blob: BlobbleJelly in blobs:
		blob.material.set_shader_parameter("seed", 0.0)
	await sample_faces(viewport, blobs, 0.0)
	var neutral: Image = viewport.get_texture().get_image()
	await sample_faces(viewport, blobs, 18.2)
	var happy: Image = viewport.get_texture().get_image()
	happy.save_png("res://builds/eyes-happy.png")
	await sample_faces(viewport, blobs, 98.2)
	var wink: Image = viewport.get_texture().get_image()
	wink.save_png("res://builds/eyes-wink.png")
	for i: int in blobs.size():
		var offset: Vector2i = Vector2i(blobs[i].position)
		var before: Array[Vector3] = eye_shapes(neutral, offset)
		# A wink shifts the combined dark-pixel centroid toward the open eye;
		# keep the divider between the eyes at its neutral position.
		var after: Array[Vector3] = eye_shapes(wink, offset, int(eyes(neutral, offset).x))
		check(happy_curve(happy, offset) > 0.7, "Blob %d smiles with curved happy eyes" % i)
		check(after[0].x > before[0].x * 0.8 and after[1].x < before[1].x * 0.3,
			"Blob %d gives a cheeky one-eyed wink" % i)

func run() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(840, 460)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var blobs: Array[BlobbleJelly] = []
	for row: int in 2:
		for color: int in 6:
			var blob: BlobbleJelly = Jelly.new()
			blob.configure(color, 1 if row == 0 else 3)
			blob.position = Vector2(color * 140, row * 140)
			blob.material.set_shader_parameter("seed", float(row * 6 + color) * 1.7)
			viewport.add_child(blob)
			blob.set_process(false)
			blobs.append(blob)
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	var baseline: Image = viewport.get_texture().get_image()
	baseline.save_png("res://builds/eyes-open.png")
	var reference: Array[Vector3] = []
	var closed_frames: Array[int] = []
	var moved_frames: Array[int] = []
	var minimum_area: Array[float] = []
	var max_motion: Array[float] = []
	for i: int in blobs.size():
		var face: Vector3 = eyes(baseline, Vector2i(blobs[i].position))
		check(face.z > 70.0, "Blob %d starts with two open eyes" % i)
		reference.append(face)
		closed_frames.append(0)
		moved_frames.append(0)
		minimum_area.append(face.z)
		max_motion.append(0.0)
	var most_closed: int = 0
	var body_still: bool = true
	# Sample 16 seconds without waiting for real-time animation.
	for frame: int in range(1, 321):
		for blob: BlobbleJelly in blobs:
			blob.material.set_shader_parameter("clock", frame * 0.05)
		await process_frame
		RenderingServer.force_draw()
		var rendered: Image = viewport.get_texture().get_image()
		if frame == 118 or frame == 168:
			rendered.save_png("res://builds/eyes-%s.png" % ("blink" if frame == 118 else "glance"))
		var simultaneously_closed: int = 0
		for i: int in blobs.size():
			var offset: Vector2i = Vector2i(blobs[i].position)
			var face: Vector3 = eyes(rendered, offset)
			minimum_area[i] = minf(minimum_area[i], face.z)
			# Half-lidded moods are distinct from a closed blink.
			if face.z < reference[i].z * 0.2:
				closed_frames[i] += 1
				simultaneously_closed += 1
			if face.z >= reference[i].z * 0.9:
				var motion: float = Vector2(face.x - reference[i].x, face.y - reference[i].y).length()
				max_motion[i] = maxf(max_motion[i], motion)
				if motion > 0.4:
					moved_frames[i] += 1
			for point: Vector2i in [Vector2i(30, 60), Vector2i(70, int(blobs[i].size.y) - 40), Vector2i(110, 95)]:
				var before: Color = baseline.get_pixelv(offset + point)
				var after: Color = rendered.get_pixelv(offset + point)
				body_still = body_still and Vector3(before.r - after.r, before.g - after.g, before.b - after.b).length() < 0.01
		most_closed = maxi(most_closed, simultaneously_closed)
	for i: int in blobs.size():
		check(minimum_area[i] < reference[i].z * 0.45, "Blob %d visibly closes its eyes" % i)
		check(closed_frames[i] > 0 and closed_frames[i] < 20, "Blob %d blinks only briefly" % i)
		check(max_motion[i] > 0.5 and max_motion[i] < 2.8, "Blob %d makes a tiny glance (%.2f pixels)" % [i, max_motion[i]])
		check(moved_frames[i] > 0 and moved_frames[i] < 100, "Blob %d rests between glances" % i)
	check(most_closed < 5, "Blinks are staggered across the board")
	check(body_still, "Idle facial animation leaves the blob body still")
	await check_gestures(viewport, blobs)
	await check_catchlights(viewport, blobs)
	await check_moods(viewport, blobs)
	await check_playful_faces(viewport, blobs)
	await check_phone_visibility(viewport, blobs)
	viewport.free()
	print("Eye animation failures: ", failures)
	quit(1 if failures else 0)

func check_phone_visibility(viewport: SubViewport, blobs: Array[BlobbleJelly]) -> void:
	# Rasterize at phone scale rather than judging enlarged individual sprites.
	viewport.size = Vector2i(420, 230)
	for i: int in blobs.size():
		blobs[i].position *= 0.5
		blobs[i].scale = Vector2.ONE * 0.5
		blobs[i].pivot_offset = Vector2.ZERO
		blobs[i].material.set_shader_parameter("seed", i * 1.7)
	await sample_faces(viewport, [], 0.0) # Flush the resized render target.
	for blob: BlobbleJelly in blobs:
		blob.material.set_shader_parameter("clock", 0.0)
	await process_frame
	RenderingServer.force_draw()
	var neutral: Image = viewport.get_texture().get_image()
	var visible_frames: Array[int] = []
	visible_frames.resize(blobs.size())
	visible_frames.fill(0)
	for frame: int in range(1, 161):
		for blob: BlobbleJelly in blobs:
			blob.material.set_shader_parameter("clock", frame * 0.25)
		await process_frame
		RenderingServer.force_draw()
		var rendered: Image = viewport.get_texture().get_image()
		if frame == 72:
			rendered.save_png("res://builds/eyes-phone-size.png")
		for i: int in blobs.size():
			var offset: Vector2i = Vector2i(blobs[i].position)
			var changed: int = 0
			for y: int in range(12, 43):
				for x: int in range(20, 55):
					var before: Color = neutral.get_pixelv(offset + Vector2i(x, y))
					var after: Color = rendered.get_pixelv(offset + Vector2i(x, y))
					if maxf(absf(before.r - after.r), maxf(absf(before.g - after.g), absf(before.b - after.b))) > 0.2:
						changed += 1
			if changed >= 10:
				visible_frames[i] += 1
	for i: int in blobs.size():
		check(visible_frames[i] >= 4 and visible_frames[i] <= 56,
			"Blob %d has occasional readable expressions with mostly quiet time over 40 seconds (%d frames)" % [i, visible_frames[i]])
