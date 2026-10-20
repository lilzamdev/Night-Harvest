@tool
extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	print("--- Running Zombie Attack Facing & Movement Test ---")
	var zombie_scene = load("res://Scenes/zombie.tscn")
	var zombie = zombie_scene.instantiate()
	root.add_child(zombie)
	zombie.set_physics_process(false)
	
	var dummy = Node2D.new()
	root.add_child(dummy)
	
	# 1. Test IDLE/WALK facing (Walk animation natively faces LEFT)
	# Target to the right -> flip_h == true
	dummy.global_position = zombie.global_position + Vector2(30, 0)
	zombie.face_target(dummy)
	assert(zombie.facing_direction == Vector2.RIGHT, "IDLE: facing RIGHT")
	assert(zombie.animated_sprite.flip_h == true, "IDLE: flip_h true when facing right")
	print("PASS: Idle facing RIGHT")
	
	# Target to the left -> flip_h == false
	dummy.global_position = zombie.global_position + Vector2(-30, 0)
	zombie.face_target(dummy)
	assert(zombie.facing_direction == Vector2.LEFT, "IDLE: facing LEFT")
	assert(zombie.animated_sprite.flip_h == false, "IDLE: flip_h false when facing left")
	print("PASS: Idle facing LEFT")
	
	# 2. Test ATTACK facing (Attack animation natively faces LEFT)
	# In ATTACK state, target to the right MUST flip_h == true to hit RIGHT!
	zombie._enter_state(zombie.State.ATTACK)
	dummy.global_position = zombie.global_position + Vector2(20, 0)
	zombie.face_target(dummy)
	assert(zombie.facing_direction == Vector2.RIGHT, "ATTACK: facing RIGHT")
	assert(zombie.animated_sprite.flip_h == true, "ATTACK: flip_h is TRUE when target is to the RIGHT (hits toward player)")
	print("PASS: Attack facing RIGHT flips sprite so slam faces toward player")
	
	# In ATTACK state, target to the left MUST flip_h == false to hit LEFT!
	dummy.global_position = zombie.global_position + Vector2(-20, 0)
	zombie.face_target(dummy)
	assert(zombie.facing_direction == Vector2.LEFT, "ATTACK: facing LEFT")
	assert(zombie.animated_sprite.flip_h == false, "ATTACK: flip_h is FALSE when target is to the LEFT (hits toward player)")
	print("PASS: Attack facing LEFT keeps sprite unflipped so slam faces toward player")
	
	# 3. Test ATTACK facing when target is diagonal/vertical
	# Target mostly UP, slightly RIGHT
	dummy.global_position = zombie.global_position + Vector2(5, -20)
	zombie.face_target(dummy)
	assert(zombie.facing_direction == Vector2.UP, "ATTACK: facing UP")
	assert(zombie.animated_sprite.flip_h == true, "ATTACK: flip_h is TRUE when target is UP-RIGHT")
	print("PASS: Attack facing UP-RIGHT")
	
	# Target mostly UP, slightly LEFT
	dummy.global_position = zombie.global_position + Vector2(-5, -20)
	zombie.face_target(dummy)
	assert(zombie.facing_direction == Vector2.UP, "ATTACK: facing UP")
	assert(zombie.animated_sprite.flip_h == false, "ATTACK: flip_h is FALSE when target is UP-LEFT")
	print("PASS: Attack facing UP-LEFT")
	
	# 4. Test target in front logic
	# Facing RIGHT: diff = (10, 0) is in front, (-10, 0) is behind
	zombie.facing_direction = Vector2.RIGHT
	assert(zombie._is_target_in_front(Vector2(10, 0), 10.0) == true, "Target on right is in front of right-facing zombie")
	assert(zombie._is_target_in_front(Vector2(-20, 0), 20.0) == false, "Target on left is behind right-facing zombie")
	print("PASS: In front check for RIGHT")
	
	# Facing LEFT: diff = (-10, 0) is in front, (10, 0) is behind
	zombie.facing_direction = Vector2.LEFT
	assert(zombie._is_target_in_front(Vector2(-10, 0), 10.0) == true, "Target on left is in front of left-facing zombie")
	assert(zombie._is_target_in_front(Vector2(20, 0), 20.0) == false, "Target on right is behind left-facing zombie")
	print("PASS: In front check for LEFT")
	
	# 5. Test exit from ATTACK restores WALK facing
	zombie._enter_state(zombie.State.CHASE)
	dummy.global_position = zombie.global_position + Vector2(30, 0)
	zombie.face_target(dummy)
	assert(zombie.animated_sprite.flip_h == true, "CHASE: flip_h restores to true for moving right")
	print("PASS: Chase restoration")
	
	dummy.queue_free()
	zombie.queue_free()
	print("--- ALL ZOMBIE ATTACK FACING TESTS PASSED! ---")
	quit()
