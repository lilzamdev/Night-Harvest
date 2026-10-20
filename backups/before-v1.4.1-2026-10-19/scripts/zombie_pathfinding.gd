extends RefCounted

## Bounded local A*: cardinal steps checked with the zombie's actual collider.
## Routes are cached by the caller, rather than rebuilt every physics frame.
const STEP := 16.0
const MAX_VISITS := 256

## Use a finer grid only when narrow map passages defeat the cheaper search.
static func find_raid_path(body: CharacterBody2D, target: Vector2) -> Array[Vector2]:
	var path := find_path(body, target, 8192, 8.0)
	if path.is_empty() or path[-1].distance_to(target) > 8.0:
		path = find_path(body, target, 20000, 4.0)
	return path

static func find_path(body: CharacterBody2D, target: Vector2, max_visits: int = MAX_VISITS, step: float = STEP) -> Array[Vector2]:
	var origin := body.global_position
	var frontier: Array[Vector2i] = [Vector2i.ZERO]
	var cost := {Vector2i.ZERO: 0.0}
	var previous := {}
	var closed := {}
	var end := Vector2i.ZERO
	var best_distance := origin.distance_to(target)
	for visit in range(max_visits):
		if frontier.is_empty():
			break
		var best_index := 0
		var best_score := INF
		for i in range(frontier.size()):
			var cell := frontier[i]
			var delta := (target - origin) / step - Vector2(cell)
			var score: float = cost[cell] + absf(delta.x) + absf(delta.y)
			if score < best_score:
				best_score = score
				best_index = i
		var current: Vector2i = frontier.pop_at(best_index)
		closed[current] = true
		var point := origin + Vector2(current) * step
		var distance := point.distance_to(target)
		if distance < best_distance:
			best_distance = distance
			end = current
		if distance <= step:
			break
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + direction
			if closed.has(next):
				continue
			var transform := body.global_transform
			transform.origin = point
			if body.test_move(transform, Vector2(direction) * step):
				continue
			var new_cost: float = cost[current] + 1.0
			if not cost.has(next) or new_cost < cost[next]:
				cost[next] = new_cost
				previous[next] = current
				if not frontier.has(next):
					frontier.append(next)
	var path: Array[Vector2] = []
	while end != Vector2i.ZERO:
		path.push_front(origin + Vector2(end) * step)
		end = previous[end]
	return path
