extends SceneTree

## Run with --headless --path . --script res://scripts/tests/spawn_manager_regression.gd.
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("SPAWN REGRESSION: " + message)

func run() -> void:
	var game = load("res://Scenes/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	var clock = get_first_node_in_group("game_clock")
	clock.set_process(false)
	var managers := get_nodes_in_group("spawn_manager")
	check(not managers.is_empty(), "Game contains spawn managers")
	for manager in managers:
		check(manager._game_clock == clock, "%s connects to the deferred game clock" % manager.name)
		check(manager.zombie_spawn_timer.is_stopped(), "No automatic waves during daytime")
	if failures > 0:
		quit(1)
		return

	clock.advance_to_time(18, 59)
	for manager in managers:
		check(manager._spawned_zombies.is_empty(), "No zombies before nightfall")
	clock.advance_to_time(19, 0)
	for manager in managers:
		# The graveyard (v1.1) also raises a few zombies through the same manager; count the wave only.
		var wave: Array = manager._spawned_zombies.filter(func(z): return not z.has_meta("graveyard"))
		check(wave.size() == manager.zombies_per_wave, "Nightfall immediately spawns one full wave")
		check(not manager.zombie_spawn_timer.is_stopped(), "Nightfall starts the repeating timer")
		check(is_equal_approx(manager.zombie_spawn_timer.wait_time, 60.0), "Normal wave interval remains 60 seconds")
		var points = manager.get_zombie_spawn_points()
		check(points.size() == 4, "All four quarry platforms are spawn points")
		var expected = [Vector2(620, -169), Vector2(704, -169), Vector2(620, -105), Vector2(716, -105)]
		for i in range(points.size()):
			check(points[i].global_position == expected[i], "Marker is in front of the screenshot platform")
		var field_positions := []
		for marker in manager.get_field_spawn_points():
			field_positions.append(marker.global_position)
		var wave_z: Array = manager._spawned_zombies.filter(func(z): return not z.has_meta("graveyard"))
		for i in range(wave_z.size()):
			var zombie = wave_z[i]
			if i < manager.quarry_zombies_per_wave:
				check(zombie.global_position == points[i % points.size()].global_position, "Quarry share of the wave uses the platform markers")
			else:
				check(field_positions.has(zombie.global_position), "Rest of the wave uses field markers near the player")
			var collider = zombie.get_node("CollisionShape2D")
			var query = PhysicsShapeQueryParameters2D.new()
			query.shape = collider.shape
			query.transform = collider.global_transform
			query.collision_mask = 1
			query.exclude = [zombie.get_rid()]
			check(zombie.get_world_2d().direct_space_state.intersect_shape(query).is_empty(), "Zombie emerges clear of map collision")
		# Every field marker must be a clear spot for a zombie body.
		var probe = manager._spawned_zombies[0]
		var probe_shape = probe.get_node("CollisionShape2D")
		for marker in manager.get_field_spawn_points():
			var q = PhysicsShapeQueryParameters2D.new()
			q.shape = probe_shape.shape
			q.transform = Transform2D(0, marker.global_position + probe_shape.position)
			q.collision_mask = 1
			q.exclude = [probe.get_rid()]
			check(probe.get_world_2d().direct_space_state.intersect_shape(q).is_empty(), "Field marker %s is clear of map collision" % marker.name)
		manager.bind_game_clock(clock)
		check(manager._spawned_zombies.filter(func(z): return not z.has_meta("graveyard")).size() == manager.zombies_per_wave, "Repeated clock binding does not duplicate waves")
		# Exercise real timer callbacks without waiting a minute.
		manager.zombie_spawn_timer.start(0.1)
	await create_timer(0.25).timeout
	for manager in managers:
		check(manager._spawned_zombies.size() >= manager.zombies_per_wave * 2, "Timer produces subsequent nighttime waves")

	# A manager loaded during an existing night must also spawn immediately.
	var late_manager = load("res://Scenes/SpawnManager.tscn").instantiate()
	game.add_child(late_manager)
	await process_frame
	await process_frame
	check(late_manager._spawned_zombies.size() == late_manager.zombies_per_wave, "Loading during night spawns the first wave")
	managers.append(late_manager)
	clock.advance_to_time(6, 0)
	for manager in managers:
		check(manager.zombie_spawn_timer.is_stopped(), "Sunrise stops the wave timer")
		for zombie in manager._spawned_zombies:
			check(zombie.is_burning, "Living zombies burn at sunrise")
		var count: int = manager._spawned_zombies.size()
		manager._on_zombie_spawn_timer_timeout()
		check(manager._spawned_zombies.size() == count, "A late timeout cannot spawn a daytime wave")
		manager.clear_zombies()
	clock.advance_to_time(19, 0)
	for manager in managers:
		check(manager._spawned_zombies.filter(func(z): return not z.has_meta("graveyard")).size() == manager.zombies_per_wave, "Following night starts a fresh wave")
	print("Spawn manager regression failures: ", failures)
	quit(1 if failures > 0 else 0)
