extends SceneTree
var failures := 0
func _initialize():
	call_deferred("run")
func check(ok: bool, message: String):
	if ok: print("PASS: ", message)
	else:
		failures += 1
		push_error(message)
func run():
	var game = load("res://Scenes/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await physics_frame
	var clock = get_first_node_in_group("game_clock")
	clock.set_process(false)
	var player = get_first_node_in_group("player")
	player.set_physics_process(false)
	player.global_position = Vector2(-1000, 0)
	var farm = get_first_node_in_group("farming_manager")
	var spot = Vector2(80, -20)
	if farm.can_hoe_tile(spot): farm.hoe_tile(spot)
	var crop = farm.plant_seed(spot, "carrot_seed")
	check(crop != null, "Plant seed in the actual farm")
	if crop == null:
		quit(1)
		return
	check(crop.growth_stage == 0 and crop.health_bar.visible and crop.health_bar.value == 30, "Seed has visible full health bar")
	var zombie = load("res://Scenes/zombie.tscn").instantiate()
	game.add_child(zombie)
	zombie.set_physics_process(false)
	zombie.global_position = game.get_node("SpawnManager").get_zombie_spawn_point().global_position
	await physics_frame
	for marker in game.get_node("SpawnManager").get_zombie_spawn_points():
		zombie.global_position = marker.global_position
		var spawn_route = zombie.Pathfinder.find_raid_path(zombie, crop.global_position)
		check(not spawn_route.is_empty() and spawn_route[-1].distance_to(crop.global_position) <= 16, "Farm reachable from " + marker.name)
	zombie.global_position = game.get_node("SpawnManager").get_zombie_spawn_point().global_position
	zombie._physics_process(0.016)
	check(zombie.current_state == zombie.State.RAID, "Idle zombie seeks crops beyond player detection range")
	var route = zombie.Pathfinder.find_raid_path(zombie, crop.global_position)
	check(not route.is_empty() and route[-1].distance_to(crop.global_position) <= 16, "Quarry route reaches planted farm across map obstacles")
	# Walk the route with real collision sweeps, without a long real-time wait.
	var clear := true
	for point in route:
		var motion: Vector2 = point - zombie.global_position
		if zombie.test_move(zombie.global_transform, motion):
			clear = false
			break
		zombie.global_position = point
	check(clear, "Entire quarry-to-farm route fits zombie collision shape")
	zombie._crop_target = crop
	zombie._enter_state(zombie.State.RAID)
	zombie._process_raid(null, 0.016)
	check(zombie.current_state == zombie.State.ATTACK and zombie._attacking_crop, "Zombie starts crop attack when in reach")
	zombie._deliver_attack_damage()
	check(crop.current_health == 20 and crop.health_bar.value == 20, "Crop attack reduces HP and updates bar")
	crop.set_watered(true)
	crop.advance_game_minute(1000)
	check(crop.mature and crop.current_health == 20 and crop.health_bar.visible, "Growing to maturity preserves damage and health bar")
	zombie._deliver_attack_damage()
	zombie._deliver_attack_damage()
	check(crop.is_dead and not crop.can_harvest(), "Three hits destroy crop without harvest")
	zombie._deliver_attack_damage()
	await process_frame
	check(farm.get_crop_at(spot) == null and farm.can_plant_seed(spot, "carrot_seed"), "Destroyed crop clears its tile for replanting")
	if failures > 0:
		quit(1)
		return
	var next_crop = farm.plant_seed(spot, "carrot_seed")
	zombie._attacking_crop = false
	zombie._enter_state(zombie.State.RAID)
	zombie._process_raid(null, 0.016)
	check(zombie._crop_target == next_crop, "Zombie retargets after previous crop is removed")
	zombie._attacking_crop = false
	zombie._enter_state(zombie.State.RAID)
	player.global_position = zombie.global_position + Vector2(0, 12)
	zombie._process_raid(player, 0.016)
	check(zombie.current_state == zombie.State.CHASE, "Nearby player can draw zombie away to defend crops")
	player.global_position = Vector2(-1000, 0)
	zombie._enter_state(zombie.State.ATTACK)
	# A harvested target must also be safe while an attack is in flight.
	next_crop.set_watered(true)
	next_crop.advance_game_minute(1000)
	var reward = next_crop.harvest()
	check(not reward.is_empty(), "Living mature crop still harvests normally")
	zombie._attacking_crop = true
	zombie._deliver_attack_damage()
	await process_frame
	zombie._on_animation_finished()
	zombie._process_raid(null, 0.016)
	check(zombie.current_state == zombie.State.IDLE, "No crops remaining returns zombie to idle safely")
	var seed_crop = farm.plant_seed(spot, "carrot_seed")
	seed_crop.take_damage(30)
	check(seed_crop.is_dead and seed_crop.growth_stage == 0, "Seeds can be destroyed before sprouting")
	await process_frame
	check(farm.can_plant_seed(spot, "carrot_seed"), "Destroyed seed also leaves soil reusable")
	print("Crop raid regression failures: ", failures)
	quit(1 if failures else 0)
