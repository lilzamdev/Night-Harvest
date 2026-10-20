extends SceneTree
var failures := 0
class Target extends CharacterBody2D:
	var _is_dead := false
	var hits := 0
	func take_damage(_amount, _direction, _force):
		hits += 1
func _initialize():
	call_deferred("run")
func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)
func run():
	var zombie = load("res://Scenes/zombie.tscn").instantiate()
	root.add_child(zombie)
	zombie.set_physics_process(false)
	var player = Target.new()
	root.add_child(player)
	player.add_to_group("player")
	player.position = Vector2(96, 0)
	var wall = StaticBody2D.new()
	var collider = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(16, 64)
	collider.shape = shape
	wall.add_child(collider)
	wall.position = Vector2(40, 0)
	root.add_child(wall)
	await physics_frame
	await physics_frame
	zombie.detection_range = 150
	check(not zombie._can_detect_player(player), "Cannot see player through a wall")
	player.position = Vector2(60, 60)
	check(zombie._can_detect_player(player), "Detects player in clear view")
	player.position = Vector2(96, 0)
	var route = zombie.Pathfinder.find_path(zombie, player.position)
	check(not route.is_empty(), "Finds route around blocking wall")
	var detours := false
	for point in route:
		if absf(point.y) >= 48: detours = true
	check(detours, "Route clears wall ends with body-sized clearance")
	for i in range(260):
		zombie._move_toward_position(player.position, 48.0, 1.0 / 60.0)
		if i == 0:
			check(zombie.velocity.x == 0 or zombie.velocity.y == 0, "Cardinal movement")
		zombie.move_and_slide()
		await physics_frame
		if zombie.position.distance_to(player.position) < 18: break
	check(zombie.position.distance_to(player.position) < 18, "Physically walks around wall to target")
	zombie._apply_directional_facing(Vector2.RIGHT)
	zombie._play_anim("walk")
	check(zombie.animated_sprite.flip_h, "Walk artwork faces right while moving right")
	zombie._apply_directional_facing(Vector2.LEFT)
	zombie._play_anim("walk")
	check(not zombie.animated_sprite.flip_h, "Walk artwork faces left while moving left")
	zombie.position = Vector2(24, 0)
	player.position = Vector2(56, 0)
	zombie.facing_direction = Vector2.RIGHT
	zombie._deliver_attack_damage()
	check(player.hits == 0, "Cannot deal melee damage through wall")
	zombie._last_known_player_pos = Vector2(96, 0)
	zombie._enter_state(zombie.State.SEARCH)
	zombie._state_timer = 0
	zombie._process_search(null, 0.016)
	check(zombie.current_state == zombie.State.IDLE, "Search ends even when last seen location is unreachable")
	player._is_dead = true
	zombie._process_chase(player, 0.016)
	check(zombie.current_state == zombie.State.IDLE, "Stops chasing dead player")
	print("Zombie AI regression failures: ", failures)
	quit(1 if failures else 0)
