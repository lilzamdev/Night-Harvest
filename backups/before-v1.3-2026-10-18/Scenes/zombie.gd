extends CharacterBody2D

## Natural Zombie AI for Night Harvest
##
## Features:
## - Strict 4-Direction Cardinal Movement (UP, DOWN, LEFT, RIGHT)
## - Zero diagonal movement
## - Movement direction strictly matches visual sprite facing
## - face_target(target: Node2D) cardinal calculation
## - Zombie faces player BEFORE starting attack animation
## - Directional attack hitbox delivery
## - Full State Machine: IDLE, WANDER, ALERT, CHASE, ATTACK, SEARCH, HURT, DEAD
## - Uses provided sprite sheets: idle, walk, attack, hurt, dead
## - Independent real-time per-zombie health bar
## - 30-hit player survivability balance (damage = 3)
## - Integrates with player attack system (take_damage)
## - Emits EventBus.zombie_killed on death

enum State {
	IDLE,
	WANDER,
	ALERT,
	CHASE,
	ATTACK,
	SEARCH,
	RAID,
	HURT,
	DEAD
}

# --- Stats ---
@export var max_health: int = 100
@export var attack_damage: int = 3
@export var wander_speed: float = 22.0
@export var chase_speed: float = 48.0
@export var detection_range: float = 95.0
@export var lose_range: float = 155.0
@export var attack_range: float = 22.0
@export var attack_cooldown_time: float = 1.2
@export var crop_attack_damage: int = 10

# --- Sunrise Burning ---
@export var burn_damage: int = 5
@export var burn_interval: float = 0.5

var current_health: int = 100
var current_state: State = State.IDLE
var is_dead: bool = false
var facing_direction: Vector2 = Vector2.DOWN

# --- Burning State ---
var is_burning: bool = false
var _burn_timer: float = 0.0
var _burn_effect: CPUParticles2D = null
var _was_damaged_by_player: bool = false

# --- Cardinal Directions (Strict 4-Way Movement) ---
const CARDINAL_DIRECTIONS: Array[Vector2] = [
	Vector2.UP,
	Vector2.DOWN,
	Vector2.LEFT,
	Vector2.RIGHT
]

# --- Timers & Internal State ---
var _state_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _wander_direction: Vector2 = Vector2.DOWN
var _last_known_player_pos: Vector2 = Vector2.ZERO
var _attack_hit_delivered: bool = false
const Pathfinder = preload("res://scripts/zombie_pathfinding.gd")
var _route: Array[Vector2] = []
var _repath_timer: float = 0.0
var _crop_target: Node2D = null
var _attacking_crop := false
var _crop_scan_timer := 0.0

# --- v1.1: variants, slows and defenses ---
## "walker", "runner" or "brute" (set by NightDirector when the zombie spawns).
var variant: String = "walker"
## Damage dealt to barricades / turrets per hit.
var structure_damage: int = 12
var _slow_mult: float = 1.0
var _slow_time: float = 0.0
var _base_chase_speed: float = -1.0
var _groan_t: float = 0.0

# --- Node References ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health_bar: ProgressBar = $HealthBar


func _ready() -> void:
	add_to_group("zombies")
	add_to_group("enemies")
	
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = true
	
	if animated_sprite:
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)
		if not animated_sprite.frame_changed.is_connected(_on_sprite_frame_changed):
			animated_sprite.frame_changed.connect(_on_sprite_frame_changed)
	
	_enter_state(State.IDLE)


func _physics_process(delta: float) -> void:
	if is_dead or current_state == State.DEAD:
		return
	
	# --- Sunrise burn tick ---
	if is_burning:
		_burn_timer += delta
		if _burn_timer >= burn_interval:
			_burn_timer -= burn_interval
			_apply_burn_damage()
			if is_dead:
				return
	
	# Attack cooldown countdown
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta

	if _slow_time > 0.0:
		_slow_time -= delta
		if _slow_time <= 0.0:
			_slow_mult = 1.0
			if animated_sprite:
				animated_sprite.speed_scale = 1.0
	_groan_t -= delta
	if _groan_t <= 0.0:
		_groan_t = randf_range(6.0, 14.0)
		var pl := _get_player()
		if pl and global_position.distance_to(pl.global_position) < 140.0 and has_node("/root/GameAudio"):
			get_node("/root/GameAudio").play("zombie_groan", -18.0 + randf_range(-3.0, 2.0))
	
	# State timer countdown
	if _state_timer > 0.0:
		_state_timer -= delta
	
	# Handle knockback decay when hurt
	if current_state == State.HURT:
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
		move_and_slide()
		return
	
	var player := _get_player()
	_crop_scan_timer -= delta
	if current_state in [State.IDLE, State.WANDER, State.SEARCH] and not (player and _can_detect_player(player)):
		if _crop_scan_timer <= 0.0:
			_crop_scan_timer = 1.0
			_crop_target = _nearest_crop()
			if is_instance_valid(_crop_target):
				_enter_state(State.RAID)
	
	match current_state:
		State.IDLE:
			_process_idle(player)
		State.WANDER:
			_process_wander(player, delta)
		State.ALERT:
			_process_alert(player)
		State.CHASE:
			_process_chase(player, delta)
		State.ATTACK:
			_process_attack(player)
		State.SEARCH:
			_process_search(player, delta)
		State.RAID:
			_process_raid(player, delta)
	
	move_and_slide()


# ==============================================================================
# STATE HANDLERS
# ==============================================================================

func _enter_state(new_state: State) -> void:
	current_state = new_state
	_route.clear()
	_repath_timer = 0.0
	
	match new_state:
		State.IDLE:
			velocity = Vector2.ZERO
			_state_timer = randf_range(1.5, 3.5)
			_play_anim("idle")
		
		State.WANDER:
			# Pick strictly from 4 cardinal directions (UP, DOWN, LEFT, RIGHT)
			_wander_direction = CARDINAL_DIRECTIONS[randi() % CARDINAL_DIRECTIONS.size()]
			facing_direction = _wander_direction
			_state_timer = randf_range(2.0, 4.0)
			_apply_directional_facing(_wander_direction)
			_play_anim("walk")
		
		State.ALERT:
			velocity = Vector2.ZERO
			_state_timer = 0.35 # Brief reaction pause
			_play_anim("idle")
		
		State.CHASE:
			_play_anim("walk")
		
		State.ATTACK:
			velocity = Vector2.ZERO
			_attack_hit_delivered = false
			var player := _get_player()
			if _attacking_crop and _valid_crop(_crop_target):
				face_target(_crop_target)
			elif player:
				face_target(player)
			_play_anim("attack")
		
		State.SEARCH:
			_state_timer = 6.0
			_play_anim("walk")
		State.RAID:
			_play_anim("walk")
		
		State.HURT:
			_state_timer = 0.25
			_play_anim("hurt")
		
		State.DEAD:
			velocity = Vector2.ZERO
			_play_anim("dead")


func _process_idle(player: CharacterBody2D) -> void:
	velocity = Vector2.ZERO
	# Check if player detected
	if player and _can_detect_player(player):
		_last_known_player_pos = player.global_position
		face_target(player)
		_enter_state(State.ALERT)
		return
	
	# Timer expired -> wander
	if _state_timer <= 0.0:
		_enter_state(State.WANDER)


func _process_wander(player: CharacterBody2D, _delta: float) -> void:
	# Check if player detected
	if player and _can_detect_player(player):
		_last_known_player_pos = player.global_position
		face_target(player)
		_enter_state(State.ALERT)
		return
	
	# Move strictly in current cardinal wander direction
	velocity = _wander_direction * wander_speed
	_apply_directional_facing(_wander_direction)
	
	# Timer expired or hit obstacle -> idle
	if _state_timer <= 0.0 or is_on_wall():
		_enter_state(State.IDLE)


func _process_alert(player: CharacterBody2D) -> void:
	velocity = Vector2.ZERO
	if player:
		face_target(player)
	
	if _state_timer <= 0.0:
		_enter_state(State.CHASE)


func _process_chase(player: CharacterBody2D, delta: float) -> void:
	if not player or player.get("_is_dead"):
		velocity = Vector2.ZERO
		_enter_state(State.IDLE)
		return
	
	var diff := player.global_position - global_position
	var dist := diff.length()
	
	# Lost player
	if dist > lose_range or not _has_line_of_sight(player):
		velocity = Vector2.ZERO
		_enter_state(State.SEARCH)
		return
	_last_known_player_pos = player.global_position
	
	# In attack range
	if dist <= attack_range:
		if _attack_cooldown_timer <= 0.0:
			_enter_state(State.ATTACK)
			return
		else:
			# Cooldown waiting: stay in place facing player
			face_target(player)
			velocity = Vector2.ZERO
			_play_anim("idle")
			return
	
	# 4-Direction movement towards player (strictly cardinal, NO diagonals)
	_move_toward_position(player.global_position, chase_speed, delta)


func _process_attack(player: CharacterBody2D) -> void:
	velocity = Vector2.ZERO
	if _attacking_crop:
		if _valid_crop(_crop_target) and not _attack_hit_delivered:
			face_target(_crop_target)
		return
	# Ensure zombie faces player during attack windup before hit is delivered
	if player and not _attack_hit_delivered:
		face_target(player)


func _valid_crop(crop) -> bool:
	return is_instance_valid(crop) and not crop.is_queued_for_deletion() and not crop.is_dead


func _nearest_crop() -> Node2D:
	var nearest: Node2D = null
	var distance := INF
	for crop in get_tree().get_nodes_in_group("crops"):
		if _valid_crop(crop):
			var candidate := global_position.distance_squared_to(crop.global_position)
			if candidate < distance:
				distance = candidate
				nearest = crop
	# Scarecrow turrets draw zombies that come close.
	for t in get_tree().get_nodes_in_group("zombie_targets"):
		if _valid_crop(t):
			var c := global_position.distance_squared_to(t.global_position)
			if c < 90.0 * 90.0 and c < distance:
				distance = c
				nearest = t
	return nearest


func _crop_in_reach() -> bool:
	if not _valid_crop(_crop_target) or global_position.distance_to(_crop_target.global_position) > attack_range:
		return false
	var exclude: Array[RID] = [get_rid()]
	if _crop_target is CollisionObject2D:
		exclude.append((_crop_target as CollisionObject2D).get_rid())
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, 5), _crop_target.global_position, 1, exclude)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _process_raid(player: CharacterBody2D, delta: float) -> void:
	# A nearby defender can draw the zombie away from the crops.
	if player and _can_detect_player(player):
		_attacking_crop = false
		_enter_state(State.CHASE)
		return
	if not _valid_crop(_crop_target):
		_crop_target = _nearest_crop()
		_route.clear()
		_repath_timer = 0.0
	if not _valid_crop(_crop_target):
		_enter_state(State.IDLE)
		return
	if _crop_in_reach():
		velocity = Vector2.ZERO
		face_target(_crop_target)
		if _attack_cooldown_timer <= 0.0:
			_attacking_crop = true
			_enter_state(State.ATTACK)
		else:
			_play_anim("idle")
		return
	_move_toward_position(_crop_target.global_position, chase_speed, delta, true)


func _process_search(player: CharacterBody2D, delta: float) -> void:
	# Check if player re-entered detection range
	if player and _can_detect_player(player):
		_last_known_player_pos = player.global_position
		face_target(player)
		_enter_state(State.CHASE)
		return
	if _state_timer <= 0.0:
		_enter_state(State.IDLE)
		return
	
	var diff_to_search := _last_known_player_pos - global_position
	if diff_to_search.length() > 12.0:
		_move_toward_position(_last_known_player_pos, wander_speed, delta)
	else:
		# Arrived at last known spot, look around
		velocity = Vector2.ZERO
		_play_anim("idle")
		if _state_timer <= 0.0:
			_enter_state(State.IDLE)


# ==============================================================================
# CARDINAL DIRECTION & FACING SYSTEM
# ==============================================================================

## Reusable function to face a target in one of the 4 cardinal directions (UP, DOWN, LEFT, RIGHT).
## Determines whether the target is primarily above, below, left, or right, and updates facing.
func face_target(target: Node2D) -> void:
	if not target or not is_instance_valid(target):
		return
	
	var diff: Vector2 = target.global_position - global_position
	var cardinal := get_cardinal_direction(diff)
	facing_direction = cardinal
	
	if current_state == State.ATTACK:
		_apply_attack_facing_diff(diff)
	else:
		_apply_directional_facing(cardinal)


## Determines the single closest cardinal direction (UP, DOWN, LEFT, RIGHT) from a vector.
## Never returns a diagonal vector.
func get_cardinal_direction(vec: Vector2) -> Vector2:
	if abs(vec.x) >= abs(vec.y):
		return Vector2.RIGHT if vec.x > 0 else Vector2.LEFT
	else:
		return Vector2.DOWN if vec.y > 0 else Vector2.UP


## Applies visual sprite facing specifically for attack animation.
## In Zombie_Default_Attack1.png, the sprite natively faces and slams to the LEFT.
## Therefore:
## - When target is to the right (diff.x > 0.5), flip_h must be true to slam RIGHT toward target.
## - When target is to the left (diff.x < -0.5), flip_h must be false to slam LEFT toward target.
## - When vertically aligned (|diff.x| <= 0.5):
##   Follow cardinal intent or current flip so attack faces toward target side.
func _apply_attack_facing_diff(diff: Vector2) -> void:
	if not animated_sprite:
		return
	
	if diff.x > 0.5:
		animated_sprite.flip_h = true
	elif diff.x < -0.5:
		animated_sprite.flip_h = false
	else:
		if facing_direction == Vector2.RIGHT:
			animated_sprite.flip_h = true
		elif facing_direction == Vector2.LEFT:
			animated_sprite.flip_h = false
		elif diff.x >= 0.0:
			animated_sprite.flip_h = true
		else:
			animated_sprite.flip_h = false


## Determines cardinal chase direction with wall obstacle fallback.
## Strictly returns UP, DOWN, LEFT, or RIGHT.
func _get_chase_cardinal_direction(diff: Vector2) -> Vector2:
	var primary: Vector2 = Vector2.ZERO
	var secondary: Vector2 = Vector2.ZERO
	
	if abs(diff.x) >= abs(diff.y):
		primary = Vector2.RIGHT if diff.x > 0 else Vector2.LEFT
		secondary = Vector2.DOWN if diff.y > 0 else Vector2.UP
	else:
		primary = Vector2.DOWN if diff.y > 0 else Vector2.UP
		secondary = Vector2.RIGHT if diff.x > 0 else Vector2.LEFT
	
	# If bumping against wall along primary axis, try secondary cardinal axis
	if is_on_wall() and abs(diff.y if primary.x != 0 else diff.x) > 6.0:
		return secondary
	
	return primary


## Applies visual sprite facing for a given cardinal direction.
## Handles horizontal flipping (flip_h) and directional animation variants if present.
func _apply_directional_facing(dir: Vector2) -> void:
	if not animated_sprite:
		return
	
	# The supplied zombie sheets face LEFT in their unflipped artwork.
	if dir == Vector2.LEFT or dir.x < -0.1:
		animated_sprite.flip_h = false
	elif dir == Vector2.RIGHT or dir.x > 0.1:
		animated_sprite.flip_h = true
	
	# Check for directional animations if scene supports them (e.g. attack_up, walk_down, idle_left)
	var dir_suffix := ""
	if dir == Vector2.UP:
		dir_suffix = "_up"
	elif dir == Vector2.DOWN:
		dir_suffix = "_down"
	elif dir == Vector2.LEFT:
		dir_suffix = "_left"
	elif dir == Vector2.RIGHT:
		dir_suffix = "_right"
	
	if dir_suffix != "" and animated_sprite.sprite_frames:
		var current_base := _get_current_base_anim()
		if animated_sprite.sprite_frames.has_animation(current_base + dir_suffix):
			animated_sprite.play(current_base + dir_suffix)


func _get_current_base_anim() -> String:
	match current_state:
		State.IDLE, State.ALERT:
			return "idle"
		State.WANDER, State.CHASE, State.SEARCH, State.RAID:
			return "walk"
		State.ATTACK:
			return "attack"
		State.HURT:
			return "hurt"
		State.DEAD:
			return "dead"
	return "idle"


# ==============================================================================
# ANIMATION & COMBAT EVENTS
# ==============================================================================

func _on_sprite_frame_changed() -> void:
	if is_dead:
		return
	
	# Attack impact at frame 3 (halfway through attack animation)
	if current_state == State.ATTACK and not _attack_hit_delivered:
		if animated_sprite and animated_sprite.frame >= 3:
			_attack_hit_delivered = true
			_deliver_attack_damage()


func _deliver_attack_damage() -> void:
	if _attacking_crop:
		if _crop_in_reach():
			if _crop_target.has_method("take_zombie_damage"):
				_crop_target.take_zombie_damage(structure_damage)
			else:
				_crop_target.take_damage(crop_attack_damage)
		return
	var player := _get_player()
	if not player or not is_instance_valid(player) or player.get("_is_dead") or not _has_line_of_sight(player):
		return
	
	var diff := player.global_position - global_position
	var dist := diff.length()
	
	# Check distance reach
	if dist <= attack_range + 10.0:
		if _is_target_in_front(diff, dist):
			if player.has_method("take_damage"):
				var push_dir := diff.normalized() if diff != Vector2.ZERO else facing_direction
				player.take_damage(attack_damage, push_dir, 35.0)


func _is_target_in_front(diff: Vector2, dist: float) -> bool:
	if dist <= 16.0:
		return true
	match facing_direction:
		Vector2.RIGHT:
			return diff.x > 0.0
		Vector2.LEFT:
			return diff.x < 0.0
		Vector2.DOWN:
			return diff.y > 0.0
		Vector2.UP:
			return diff.y < 0.0
	return false


func _on_animation_finished() -> void:
	if is_dead:
		return
	
	match current_state:
		State.ATTACK:
			_attack_cooldown_timer = attack_cooldown_time
			if _attacking_crop:
				_attacking_crop = false
				_enter_state(State.RAID)
				return
			var player := _get_player()
			if player and _can_detect_player(player):
				_enter_state(State.CHASE)
				face_target(player)
			else:
				_enter_state(State.IDLE)
		
		State.HURT:
			_attacking_crop = false
			var player := _get_player()
			if player:
				_enter_state(State.CHASE)
				face_target(player)
			else:
				_enter_state(State.IDLE)


## Called by player attack system (see ken_idle_front.gd: _execute_action_impact).
var _last_hit_dir := Vector2.ZERO


func take_damage(amount: int, direction: Vector2 = Vector2.ZERO, knockback: float = 0.0) -> void:
	if is_dead or current_state == State.DEAD:
		return
	
	# Track that the player contributed damage (for kill-credit / EXP)
	_was_damaged_by_player = true
	
	current_health = maxi(0, current_health - amount)
	
	# Update individual health bar immediately
	if health_bar:
		health_bar.value = current_health
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("sword_hit", -6.0)

	# Visual hit reaction (red flash) — use white target if not burning, warm tint if burning
	if animated_sprite:
		var tween := create_tween()
		animated_sprite.modulate = Color(1.8, 0.3, 0.3, 1.0)
		var restore_color := Color(1.5, 0.7, 0.3, 1.0) if is_burning else Color.WHITE
		tween.tween_property(animated_sprite, "modulate", restore_color, 0.15)
	
	# Apply knockback
	if direction != Vector2.ZERO:
		_last_hit_dir = direction.normalized()
	if direction != Vector2.ZERO and knockback > 0.0:
		velocity = direction.normalized() * knockback
	# v1.2 game feel: numbers, goo, a tiny freeze frame on player hits
	var juice := get_tree().get_first_node_in_group("juice") if is_inside_tree() else null
	if juice:
		juice.damage_number(global_position, amount, amount >= 30)
		juice.burst(global_position + Vector2(0, -12), Color(0.42, 0.62, 0.3), 5, 55.0)
		if knockback > 0.0:
			juice.hitstop(0.03 if current_health > 0 else 0.06)
			juice.shake(1.2 if current_health > 0 else 2.2, 0.12)
	
	# Check for death
	if current_health <= 0:
		_die()
		return
	
	# If zombie was wandering or idling, immediately alert/aggro on player
	var player := _get_player()
	if player:
		_last_known_player_pos = player.global_position
		face_target(player)
	
	_enter_state(State.HURT)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	
	# Stop burning and clean up fire effect
	is_burning = false
	_burn_timer = 0.0
	if _burn_effect and is_instance_valid(_burn_effect):
		_burn_effect.emitting = false
		_burn_effect.queue_free()
		_burn_effect = null
	
	_enter_state(State.DEAD)
	# v1.2: the body is flung back a little and splatters
	if is_inside_tree():
		var fling := create_tween()
		fling.tween_property(self, "global_position", global_position + _last_hit_dir * 16.0, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		var juice := get_tree().get_first_node_in_group("juice")
		if juice:
			juice.burst(global_position + Vector2(0, -10), Color(0.38, 0.55, 0.26), 14, 85.0)
			juice.dust(global_position, 6)
	
	# Hide health bar
	if health_bar:
		health_bar.visible = false
	
	# Disable physics collision so player and other entities walk through corpse
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	if is_inside_tree():
		for bus in get_tree().get_nodes_in_group("event_bus"):
			if is_instance_valid(bus) and bus.has_signal("gameplay_event"):
				bus.gameplay_event.emit("zombie_died", {"pos": global_position, "variant": variant, "by_player": _was_damaged_by_player})
				break
		if has_node("/root/GameAudio"):
			get_node("/root/GameAudio").play("zombie_death", -10.0)

	# Notify QuestManager / EventBus — only if the player contributed damage.
	# Pure sunlight deaths do NOT award kill credit / quest progress.
	if _was_damaged_by_player and is_inside_tree():
		var tree := get_tree()
		if tree:
			var bus_nodes := tree.get_nodes_in_group("event_bus")
			for bus in bus_nodes:
				if is_instance_valid(bus) and bus.has_signal("zombie_killed"):
					bus.zombie_killed.emit()
					break
	
	# Play dead animation, then fade out and free
	if animated_sprite:
		_play_anim("dead")
		animated_sprite.modulate = Color.WHITE  # Reset tint for death anim
		var tween := create_tween()
		tween.tween_interval(0.8) # Let dead animation display
		tween.tween_property(animated_sprite, "modulate:a", 0.0, 0.4)
		tween.tween_callback(queue_free)
	else:
		queue_free()


# ==============================================================================
# HELPERS
# ==============================================================================

func _can_detect_player(player: CharacterBody2D) -> bool:
	if not player or not is_instance_valid(player):
		return false
	if player.get("_is_dead"):
		return false
	return global_position.distance_to(player.global_position) <= detection_range and _has_line_of_sight(player)


func _has_line_of_sight(player: CharacterBody2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0, 5), player.global_position + Vector2(0, 5), 1,
		[get_rid(), player.get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _move_toward_position(target: Vector2, speed: float, delta: float, persistent_route: bool = false) -> void:
	_repath_timer -= delta
	if _repath_timer <= 0.0 and (not persistent_route or _route.is_empty()):
		_route = Pathfinder.find_raid_path(self, target) if persistent_route else Pathfinder.find_path(self, target)
		_repath_timer = 0.8 + float(get_instance_id() % 5) * 0.05
	while not _route.is_empty() and global_position.distance_to(_route[0]) < 1.0:
		_route.pop_front()
	var waypoint := target if _route.is_empty() else _route[0]
	var diff := waypoint - global_position
	var direction := get_cardinal_direction(diff)
	var remaining := absf(diff.x) if direction.x != 0.0 else absf(diff.y)
	var step := minf(speed * delta, remaining)
	if step < 0.01 or test_move(global_transform, direction * step):
		if persistent_route:
			_route.clear()
		var blocker := _defense_in_way(direction)
		if blocker and current_state != State.RAID or (blocker and _crop_target != blocker):
			_crop_target = blocker
			_enter_state(State.RAID)
			return
		velocity = Vector2.ZERO
		_play_anim("idle")
		return
	facing_direction = direction
	velocity = direction * (step / maxf(delta, 0.001)) * _slow_mult
	_apply_directional_facing(direction)
	_play_anim("walk")


## A barricade or turret right in front of the zombie (it will chew through it).
func _defense_in_way(direction: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := 26.0
	for d in get_tree().get_nodes_in_group("defenses"):
		if d.get("is_dead") or d.get("collision_layer") == 0:
			continue
		var diff: Vector2 = (d as Node2D).global_position - global_position
		var dist := diff.length()
		if dist < best_d and (dist < 12.0 or diff.normalized().dot(direction) > 0.3):
			best_d = dist
			best = d
	return best


## Spike traps slow zombies down for a moment.
func apply_slow(mult: float, duration: float) -> void:
	_slow_mult = minf(_slow_mult, mult)
	_slow_time = maxf(_slow_time, duration)
	if animated_sprite:
		animated_sprite.speed_scale = maxf(0.4, mult)


func _play_anim(anim_name: String) -> void:
	if not animated_sprite:
		return
	
	# Try directional variant first if available
	var dir_suffix := ""
	if facing_direction == Vector2.UP:
		dir_suffix = "_up"
	elif facing_direction == Vector2.DOWN:
		dir_suffix = "_down"
	elif facing_direction == Vector2.LEFT:
		dir_suffix = "_left"
	elif facing_direction == Vector2.RIGHT:
		dir_suffix = "_right"
	
	if dir_suffix != "" and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name + dir_suffix):
		if animated_sprite.animation != (anim_name + dir_suffix) or not animated_sprite.is_playing():
			animated_sprite.play(anim_name + dir_suffix)
			return
	
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name or not animated_sprite.is_playing():
			animated_sprite.play(anim_name)


func _get_player() -> CharacterBody2D:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if not tree:
		return null
	var players := tree.get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p is CharacterBody2D:
			return p
	return null


# ==============================================================================
# SUNRISE BURNING SYSTEM
# ==============================================================================

## Called by SpawnManager when morning begins.
## Ignites this zombie — it will take periodic burn damage until death.
## Safe to call multiple times; duplicate calls are ignored.
func start_burning() -> void:
	if is_burning or is_dead:
		return
	
	is_burning = true
	_burn_timer = 0.0
	
	# Apply warm orange tint to sprite
	if animated_sprite:
		animated_sprite.modulate = Color(1.5, 0.7, 0.3, 1.0)
	
	# Create procedural fire particles
	_burn_effect = _create_burn_effect()
	add_child(_burn_effect)
	print("[Zombie] Started burning at sunrise")


## Applies burn damage directly — bypasses take_damage() to avoid
## setting _was_damaged_by_player (sunlight kills ≠ player kills).
func _apply_burn_damage() -> void:
	if is_dead:
		return
	
	current_health = maxi(0, current_health - burn_damage)
	
	# Update health bar
	if health_bar:
		health_bar.value = current_health
	
	# Brief orange flash on each burn tick
	if animated_sprite and not is_dead:
		var tween := create_tween()
		animated_sprite.modulate = Color(2.0, 0.9, 0.2, 1.0)
		tween.tween_property(animated_sprite, "modulate", Color(1.5, 0.7, 0.3, 1.0), 0.2)
	
	if current_health <= 0:
		_die()


## Creates a procedural CPUParticles2D fire effect — pixel-art friendly,
## no external textures required.
func _create_burn_effect() -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = "BurnFireEffect"
	particles.position = Vector2(0, -5)  # Near zombie center
	particles.emitting = true
	particles.amount = 12
	particles.lifetime = 0.5
	particles.one_shot = false
	particles.explosiveness = 0.1
	particles.randomness = 0.3
	
	# Direction & spread
	particles.direction = Vector2(0, -1)
	particles.spread = 30.0
	
	# Speed
	particles.initial_velocity_min = 15.0
	particles.initial_velocity_max = 25.0
	
	# Gravity — slight upward drift for fire feel
	particles.gravity = Vector2(0, -10)
	
	# Scale — small pixel-art particles
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0
	
	# Emission shape — small sphere around zombie body
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 5.0
	
	# Color gradient: yellow → orange → dark red → transparent
	var gradient := Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(1.0, 0.95, 0.1, 1.0))   # Bright yellow
	gradient.add_point(0.3, Color(1.0, 0.5, 0.0, 0.9))   # Orange
	gradient.add_point(0.7, Color(0.8, 0.15, 0.0, 0.6))   # Dark red
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, Color(0.3, 0.3, 0.3, 0.0))     # Transparent smoke
	particles.color_ramp = gradient
	
	return particles
