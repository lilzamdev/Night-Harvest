extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var zombie_scene = load("res://Scenes/zombie.tscn")
	var zombie = zombie_scene.instantiate()
	root.add_child(zombie)

	var dummy = CharacterBody2D.new()
	root.add_child(dummy)

	zombie.global_position = Vector2(100, 100)

	# Case 1: Player is to the RIGHT
	dummy.global_position = Vector2(115, 100) # dist 15 <= attack_range (22)
	zombie._process_chase(dummy, 0.016)
	print("Player to the RIGHT:")
	print("  State: ", zombie.current_state, " (ATTACK=4)")
	print("  facing_direction: ", zombie.facing_direction)
	print("  flip_h: ", zombie.animated_sprite.flip_h)

	# Case 2: Player is to the LEFT
	zombie.current_state = zombie.State.CHASE
	zombie._attack_cooldown_timer = 0.0
	dummy.global_position = Vector2(85, 100)
	zombie._process_chase(dummy, 0.016)
	print("Player to the LEFT:")
	print("  State: ", zombie.current_state)
	print("  facing_direction: ", zombie.facing_direction)
	print("  flip_h: ", zombie.animated_sprite.flip_h)

	# Case 3: Player is ABOVE
	zombie.current_state = zombie.State.CHASE
	zombie._attack_cooldown_timer = 0.0
	dummy.global_position = Vector2(100, 85)
	zombie._process_chase(dummy, 0.016)
	print("Player ABOVE:")
	print("  State: ", zombie.current_state)
	print("  facing_direction: ", zombie.facing_direction)
	print("  flip_h: ", zombie.animated_sprite.flip_h)

	# Case 4: Player is BELOW
	zombie.current_state = zombie.State.CHASE
	zombie._attack_cooldown_timer = 0.0
	dummy.global_position = Vector2(100, 115)
	zombie._process_chase(dummy, 0.016)
	print("Player BELOW:")
	print("  State: ", zombie.current_state)
	print("  facing_direction: ", zombie.facing_direction)
	print("  flip_h: ", zombie.animated_sprite.flip_h)

	quit(0)
