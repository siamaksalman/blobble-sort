class_name Scoring
## Star rating and time formatting for finished levels.

## Moves at or under the target earn 3 stars, up to 1.5x earns 2, anything else 1.
## Using Hint or +Tube caps the rating at 2. Undo is free: undone moves aren't counted.
static func stars(moves: int, target: int, helpers_used: bool) -> int:
	var s := 1
	if moves <= target:
		s = 3
	elif moves <= target * 1.5:
		s = 2
	if helpers_used:
		s = mini(s, 2)
	return s


static func format_time(seconds: float) -> String:
	var t := int(seconds)
	return "%d:%02d" % [t / 60, t % 60]


## True when this run beats the saved best ({stars, time}) on stars or on time.
static func is_better(stars_now: int, time_now: float, best: Dictionary) -> bool:
	if best.is_empty():
		return true
	return stars_now > int(best.stars) or time_now < float(best.time)
