extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var zombie_scene = load("res://Scenes/zombie.tscn")
	var zombie = zombie_scene.instantiate()
	root.add_child(zombie)

	var ken = CharacterBody2D.new()
	root.add_child(ken)

	# Ken is at (150, 100), Zombie is at (100, 100).
	# Ken is to the RIGHT of Zombie.
	zombie.global_position = Vector2(100, 100)
	ken.global_position = Vector2(150, 100)

	print("--- TEST 1: Ken to the RIGHT ---")
	zombie.face_target(ken)
	print("facing_direction: ", zombie.facing_direction)
	print("flip_h: ", zombie.animated_sprite.flip_h)

	# Ken is at (50, 100), Zombie is at (100, 100).
	# Ken is to the LEFT of Zombie.
	ken.global_position = Vector2(50, 100)
	print("--- TEST 2: Ken to the LEFT ---")
	zombie.face_target(ken)
	print("facing_direction: ", zombie.facing_direction)
	print("flip_h: ", zombie.animated_sprite.flip_h)

	# Ken is directly ABOVE Zombie at (100, 50).
	ken.global_position = Vector2(100, 50)
	print("--- TEST 3: Ken directly ABOVE ---")
	zombie.face_target(ken)
	print("facing_direction: ", zombie.facing_direction)
	print("flip_h: ", zombie.animated_sprite.flip_h)

	# Ken is diagonally ABOVE-RIGHT at (130, 50).
	ken.global_position = Vector2(130, 50)
	print("--- TEST 4: Ken diagonally ABOVE-RIGHT ---")
	zombie.face_target(ken)
	print("facing_direction: ", zombie.facing_direction)
	print("flip_h: ", zombie.animated_sprite.flip_h)

	quit(0)
