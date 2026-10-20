extends Node2D
class_name SpawnManager

## Dedicated SpawnManager for Night Harvest
##
## Controls where zombies and animals spawn using editor-draggable Marker2D nodes.
##
## Scene Structure:
## SpawnManager (Node2D)
## ├── ZombieSpawnPoint (Marker2D, northwest platform)
## ├── ZombieSpawnPoints (Node2D, three additional platform markers)
## ├── FieldSpawnPoints (Node2D, markers spread across the whole valley)
## ├── AnimalSpawnPoints (Node2D)
## │   ├── SpawnPoint01 (Marker2D)
## │   └── ...
## └── ZombieSpawnTimer (Timer, 60s)
##
## Features:
## - Four editor markers in front of the northeast quarry's stone platforms
## - Markers sit beyond the solid platform edges so zombies can walk out
## - 10 zombies distributed across the markers every 60 seconds
## - Spread spawns: part of each wave rises at the quarry, the rest at the
##   field markers nearest the player that are still off-screen
## - Uses Godot's Timer node for interval tracking
## - Day/Night integration: begins 60s waves at night, stops at day

@export_group("Zombie Spawning")
@export var zombie_scene: PackedScene = preload("res://Scenes/zombie.tscn")
@export var zombies_per_wave: int = 10
@export var spawn_interval: float = 60.0
## When on, waves are split between the quarry and the field markers near
## the player, so there is no safe corner of the map at night.
@export var spread_spawns: bool = true
## How many zombies of each wave still come from the quarry platforms.
@export var quarry_zombies_per_wave: int = 3
## How many of the nearest eligible field markers share the rest of the wave.
@export var field_points_per_wave: int = 3
## Field markers closer than this to the player are skipped (keeps spawns off-screen).
@export var min_spawn_distance: float = 240.0

@export_group("Animal Spawning")
@export var animal_scene: PackedScene = preload("res://Scenes/chicken.tscn")
@export var animal_scenes: Array[PackedScene] = [
	preload("res://Scenes/chicken.tscn"),
	preload("res://Scenes/cow.tscn"),
	preload("res://Scenes/pig.tscn"),
	preload("res://Scenes/sheep.tscn")
]
@export var max_animals: int = 5

# --- Internal State & Node References ---
var _game_clock: Node = null
var _spawned_zombies: Array[Node2D] = []
var _spawned_animals: Array[Node2D] = []

@onready var zombie_spawn_point: Marker2D = get_node_or_null("ZombieSpawnPoint")
@onready var zombie_spawn_timer: Timer = get_node_or_null("ZombieSpawnTimer")


func _ready() -> void:
	add_to_group("spawn_manager")
	
	# Setup ZombieSpawnTimer
	if not zombie_spawn_timer:
		zombie_spawn_timer = Timer.new()
		zombie_spawn_timer.name = "ZombieSpawnTimer"
		add_child(zombie_spawn_timer)
	
	zombie_spawn_timer.wait_time = spawn_interval
	zombie_spawn_timer.autostart = false
	zombie_spawn_timer.stop()
	if not zombie_spawn_timer.timeout.is_connected(_on_zombie_spawn_timer_timeout):
		zombie_spawn_timer.timeout.connect(_on_zombie_spawn_timer_timeout)
	
	call_deferred("_connect_game_clock")


func _connect_game_clock() -> void:
	if is_instance_valid(_game_clock):
		return
	var clock_nodes := get_tree().get_nodes_in_group("game_clock")
	for c in clock_nodes:
		if is_instance_valid(c):
			bind_game_clock(c)
			return
	# Fallback when running standalone scene. Game setup binds its clock later.
	spawn_animals()


## Game setup calls this after creating its deferred GameClock.
func bind_game_clock(clock: Node) -> void:
	if not is_instance_valid(clock) or _game_clock == clock:
		return
	if is_instance_valid(_game_clock):
		_game_clock.night_started.disconnect(_on_night_started)
		_game_clock.night_ended.disconnect(_on_night_ended)
	_game_clock = clock
	_game_clock.night_started.connect(_on_night_started)
	_game_clock.night_ended.connect(_on_night_ended)
	if _game_clock.is_night():
		_start_zombie_spawning()
	else:
		_stop_zombie_spawning()
		spawn_animals()


# ==============================================================================
# SPAWN POINT ACCESSORS
# ==============================================================================

## Returns the primary marker for compatibility with single-marker scenes.
func get_zombie_spawn_point() -> Marker2D:
	if zombie_spawn_point and is_instance_valid(zombie_spawn_point):
		return zombie_spawn_point
	var pt = get_node_or_null("ZombieSpawnPoint")
	if pt and pt is Marker2D:
		return pt
	return null


## Returns the primary marker and any additional platform markers.
func get_zombie_spawn_points() -> Array[Node2D]:
	var points: Array[Node2D] = []
	var pt := get_zombie_spawn_point()
	if pt:
		points.append(pt)
	var container := get_node_or_null("ZombieSpawnPoints")
	if container:
		for child in container.get_children():
			if child is Marker2D:
				points.append(child)
	return points


## Returns the markers spread across the valley (FieldSpawnPoints).
func get_field_spawn_points() -> Array[Node2D]:
	var points: Array[Node2D] = []
	var container := get_node_or_null("FieldSpawnPoints")
	if container:
		for child in container.get_children():
			if child is Marker2D:
				points.append(child)
	return points


## The field markers nearest to player_pos that are at least
## min_spawn_distance away, closest first (at most field_points_per_wave).
func pick_field_spawn_points(player_pos: Vector2) -> Array[Node2D]:
	var eligible: Array[Node2D] = []
	for p in get_field_spawn_points():
		if p.global_position.distance_to(player_pos) >= min_spawn_distance:
			eligible.append(p)
	eligible.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(player_pos) < b.global_position.distance_squared_to(player_pos)
	)
	return eligible.slice(0, maxi(0, field_points_per_wave))


## Returns all Marker2D / Node2D spawn points under AnimalSpawnPoints
func get_animal_spawn_points() -> Array[Node2D]:
	var points: Array[Node2D] = []
	var container := get_node_or_null("AnimalSpawnPoints")
	if container:
		for child in container.get_children():
			if child is Node2D:
				points.append(child)
	return points


# ==============================================================================
# CONTROLLED ZOMBIE SPAWNING (10 Zombies every 60s across the platforms)
# ==============================================================================

## Distributes exactly zombies_per_wave zombies across the editor markers.
func spawn_zombies() -> Array[Node2D]:
	if not zombie_scene:
		return []
	
	var points := get_zombie_spawn_points()
	var field: Array[Node2D] = []
	if spread_spawns:
		var player := _get_player()
		if player:
			field = pick_field_spawn_points(player.global_position)

	if points.is_empty() and field.is_empty():
		push_warning("SpawnManager: No ZombieSpawnPoint found!")
		return []

	# Work out where each zombie of the wave appears.
	var positions: Array[Vector2] = []
	if field.is_empty():
		for i in range(zombies_per_wave):
			positions.append(points[i % points.size()].global_position)
	else:
		var quarry_count := 0
		if not points.is_empty():
			quarry_count = clampi(quarry_zombies_per_wave, 0, zombies_per_wave)
		for i in range(quarry_count):
			positions.append(points[i % points.size()].global_position)
		for i in range(zombies_per_wave - quarry_count):
			positions.append(field[i % field.size()].global_position)

	var target_parent := _get_entity_parent()
	var newly_spawned: Array[Node2D] = []

	for pos in positions:
		var zombie = zombie_scene.instantiate()
		target_parent.add_child(zombie)
		zombie.global_position = pos
		_spawned_zombies.append(zombie)
		newly_spawned.append(zombie)

	print("[SpawnManager] Wave spawned: %d zombies (%d field markers in use)" % [newly_spawned.size(), field.size()])
	return newly_spawned


func _on_zombie_spawn_timer_timeout() -> void:
	if not is_instance_valid(_game_clock) or not _game_clock.is_night():
		_stop_zombie_spawning()
		return
	spawn_zombies()


func _start_zombie_spawning() -> void:
	if zombie_spawn_timer:
		zombie_spawn_timer.wait_time = spawn_interval
		zombie_spawn_timer.start()
	# Spawn initial wave of 10 zombies upon night arrival
	spawn_zombies()


func _stop_zombie_spawning() -> void:
	if zombie_spawn_timer:
		zombie_spawn_timer.stop()


## Cleans up active spawned zombies
func clear_zombies() -> void:
	_clean_tracked_zombies()
	for z in _spawned_zombies:
		if is_instance_valid(z):
			z.queue_free()
	_spawned_zombies.clear()


# ==============================================================================
# ANIMAL SPAWNING
# ==============================================================================

## Spawns animals at available AnimalSpawnPoints up to max_animals.
func spawn_animals() -> Array[Node2D]:
	_clean_tracked_animals()
	var available_points := get_animal_spawn_points()
	if available_points.is_empty():
		return []
	
	var slots_available := maxi(0, max_animals - _spawned_animals.size())
	var spawn_count := mini(slots_available, available_points.size())
	
	var newly_spawned: Array[Node2D] = []
	var target_parent := _get_entity_parent()
	
	for i in range(spawn_count):
		var spawn_pt: Node2D = available_points[i]
		var chosen_scene: PackedScene = animal_scene
		if not animal_scenes.is_empty():
			chosen_scene = animal_scenes[i % animal_scenes.size()]
		
		if not chosen_scene:
			continue
		
		var animal = chosen_scene.instantiate()
		target_parent.add_child(animal)
		animal.global_position = spawn_pt.global_position
		_spawned_animals.append(animal)
		newly_spawned.append(animal)
	
	return newly_spawned


## Clears active spawned animals
func clear_animals() -> void:
	_clean_tracked_animals()
	for a in _spawned_animals:
		if is_instance_valid(a):
			a.queue_free()
	_spawned_animals.clear()


# ==============================================================================
# DAY / NIGHT SIGNALS
# ==============================================================================

func _on_night_started() -> void:
	_start_zombie_spawning()


func _on_night_ended() -> void:
	_stop_zombie_spawning()
	_ignite_all_zombies()
	spawn_animals()


## Ignites all living tracked zombies so they burn to death at sunrise.
## Does NOT instantly free them — they die naturally from burn damage.
func _ignite_all_zombies() -> void:
	_clean_tracked_zombies()
	for z in _spawned_zombies:
		if is_instance_valid(z) and not z.get("is_dead"):
			if z.has_method("start_burning"):
				z.start_burning()


# ==============================================================================
# HELPERS
# ==============================================================================

func _clean_tracked_zombies() -> void:
	var valid: Array[Node2D] = []
	for z in _spawned_zombies:
		if is_instance_valid(z) and not z.get("is_dead"):
			valid.append(z)
	_spawned_zombies = valid


func _clean_tracked_animals() -> void:
	var valid: Array[Node2D] = []
	for a in _spawned_animals:
		if is_instance_valid(a):
			valid.append(a)
	_spawned_animals = valid


func _get_entity_parent() -> Node:
	var parent := get_parent()
	if parent:
		return parent
	return get_tree().current_scene if get_tree() else self


func _get_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p is CharacterBody2D:
			return p
	return null
