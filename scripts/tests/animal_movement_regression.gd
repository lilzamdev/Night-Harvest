extends SceneTree

var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)
func run() -> void:
	var animals: Array[Node2D] = []
	for species in ["chicken", "cow", "pig", "sheep"]:
		var animal = load("res://Scenes/" + species + ".tscn").instantiate()
		root.add_child(animal)
		animal.set_physics_process(false)
		animal.position = Vector2(0, animals.size() * 200)
		animal._rng.seed = 23 + animals.size()
		animals.append(animal)
		check(not animal.animated_sprite.is_playing(), species + " rests without walking in place")
		animal._physics_process(1.0 / 60.0)
		check(animal._home == animal.global_position, species + " home uses position assigned after spawning")
		animal.start_walking()
		animal.timer = 30.0
		check(animal.direction.is_normalized(), species + " uses free-direction normalized heading")
		animal._physics_process(1.0 / 60.0)
		check(animal.velocity.length() <= animal.acceleration / 60.0 + 0.01, species + " accelerates gradually")
		for i in range(30):
			animal._physics_process(1.0 / 60.0)
			await physics_frame
		check(animal.walk_speed == 25.0, species + " retains configured base speed")
		check(animal.animated_sprite.is_playing(), species + " plays its walking clip while moving")
		animal.start_idle()
		animal.timer = 30
		for i in range(45):
			animal._physics_process(1.0 / 60.0)
			await physics_frame
		check(animal.velocity == Vector2.ZERO and not animal.animated_sprite.is_playing(), species + " slows to a still resting pose")
		animal._update_facing(Vector2(-1, 0.5).normalized())
		check(not animal.animated_sprite.flip_h, species + " uses native left-facing artwork for diagonal left travel")
		animal._update_facing(Vector2(1, 0.5).normalized())
		check(animal.animated_sprite.flip_h, species + " mirrors left-facing artwork for diagonal right travel")
		animal._update_facing(Vector2.UP)
		check(animal.animated_sprite.flip_h, species + " retains facing during vertical travel")
		animal.start_idle()
		check(animal.animated_sprite.flip_h, species + " retains facing when resting")
	var animal = animals[0]
	animal.position = Vector2.ZERO
	animal._home = Vector2.ZERO
	var neighbor = animals[1]
	neighbor.position = Vector2(12, 0)
	check(animal._separation().x < 0, "Steers away from a nearby animal")
	neighbor.position = Vector2.ZERO
	check(animal._separation().dot(neighbor._separation()) < 0, "Coincident animals choose opposite escape headings")
	neighbor.position = Vector2(0, 200)
	var wall := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 60)
	collider.shape = shape
	wall.add_child(collider)
	wall.position = Vector2(24, 0)
	root.add_child(wall)
	await physics_frame
	await physics_frame
	var heading: Vector2 = animal._clear_heading(Vector2.RIGHT)
	check(heading != Vector2.RIGHT and heading != Vector2.ZERO, "Finds a clear turn before reaching wall")
	check(not animal.test_move(animal.global_transform, heading * 20), "Avoidance heading fits actual collision body")
	animal.start_walking()
	animal.direction = Vector2.RIGHT
	animal.timer = 30
	for i in range(100):
		animal._physics_process(1.0 / 60.0)
		await physics_frame
	check(animal.position.distance_to(Vector2.ZERO) > 15, "Animal makes progress around obstacle")
	wall.queue_free()
	await physics_frame
	animal.position = Vector2(150, -200)
	animal._home = Vector2(0, -200)
	animal.start_walking()
	animal.direction = Vector2.RIGHT
	animal._physics_process(1.0 / 60.0)
	check(animal._desired_direction.x < 0, "Gently turns back toward roaming area")
	for i in range(90):
		animal._physics_process(1.0 / 60.0)
		await physics_frame
	check(animal.velocity.x < 0, "Completes a smooth turn even from the opposite heading")
	print("Animal movement regression failures: ", failures)
	quit(1 if failures else 0)
