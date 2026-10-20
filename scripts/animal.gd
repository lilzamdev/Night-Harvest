extends CharacterBody2D
class_name Animal

## Relaxed wandering with smooth steering, grazing pauses and local avoidance.
@export var walk_speed: float = 25.0
@export var min_walk_time: float = 2.0
@export var max_walk_time: float = 5.0
@export var min_idle_time: float = 2.0
@export var max_idle_time: float = 5.0
@export var acceleration: float = 45.0
@export var roam_radius: float = 120.0
@export var personal_space: float = 24.0

var direction: Vector2 = Vector2.ZERO
var state: String = "idle"
var timer: float = 0.0
var _pace: float = 1.0
var _home: Vector2
var _home_initialized := false
var _steering_timer := 0.0
var _desired_direction := Vector2.ZERO
var _stuck_elapsed := 0.0
var _stuck_origin := Vector2.ZERO
var _rng := RandomNumberGenerator.new()

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# --- v1.4: hunting, breeding and wild animals --------------------------------
const ItemDB = preload("res://scripts/item_database.gd")
const WorldItemScene = preload("res://Scenes/world_item.tscn")
const V131 := "res://Assets/Generated/v131/"

## hp, drops [[item, min, max]], food that makes it breed, display name
const SPECIES := {
	"chicken": {"hp": 12, "drops": [["raw_chicken", 1, 1], ["feather", 0, 2]], "food": ["wheat_seed", "corn_seed", "tomato_seed"], "name": "CHICKEN"},
	"cow": {"hp": 40, "drops": [["raw_beef", 1, 2], ["leather", 0, 1]], "food": ["wheat"], "name": "COW"},
	"pig": {"hp": 30, "drops": [["raw_pork", 1, 2]], "food": ["carrot", "potato"], "name": "PIG"},
	"sheep": {"hp": 30, "drops": [["raw_mutton", 1, 1], ["wool", 1, 2]], "food": ["wheat"], "name": "SHEEP"},
	"rabbit": {"hp": 8, "drops": [["raw_rabbit", 1, 1]], "food": ["carrot"], "name": "RABBIT", "speed": 34.0, "skittish": true, "r": 5.0},
	"snow_hare": {"hp": 8, "drops": [["raw_rabbit", 1, 1]], "food": ["carrot"], "name": "SNOW HARE", "speed": 34.0, "skittish": true, "r": 5.0},
	"duck": {"hp": 10, "drops": [["raw_chicken", 1, 1], ["feather", 1, 2]], "food": ["wheat_seed", "corn_seed"], "name": "DUCK", "r": 5.0},
	"goat": {"hp": 34, "drops": [["raw_mutton", 1, 2], ["leather", 0, 1]], "food": ["wheat"], "name": "GOAT", "r": 8.0},
	"deer": {"hp": 30, "drops": [["venison", 1, 2], ["leather", 1, 1]], "food": ["berries", "carrot"], "name": "DEER", "speed": 36.0, "skittish": true, "r": 8.0},
}
const NEW_SPECIES := ["rabbit", "snow_hare", "duck", "goat", "deer"]

var species := ""
var hp := 20
var max_hp := 20
var is_dead := false
var is_baby := false
var birth_day := 0
var interact_range := 22.0
var _flee_t := 0.0
var _flee_from := Vector2.ZERO
var _love_t := 0.0
var _breed_cd := 0.0
var _heart_t := 0.0

# --- v1.4.3: idle life (breathing, grazing, pecking, hopping, looking around) ---
var _idle_clock := 0.0
var _breath_phase := 0.0
var _idle_act := ""
var _idle_act_t := 0.0
var _idle_act_len := 0.0
var _idle_act_cd := 0.0
var _look_flipped := false
var _spr_base_pos := Vector2.ZERO


## Builds an animal of any species from code (the original four use their scenes).
static func create(sp: String) -> CharacterBody2D:
	match sp:
		"chicken", "cow", "pig", "sheep":
			var a: CharacterBody2D = (load("res://Scenes/%s.tscn" % sp) as PackedScene).instantiate()
			a.set("species", sp)
			return a
	var body := CharacterBody2D.new()
	body.set_script(load("res://scripts/animal.gd"))
	body.set("species", sp)
	var spr := AnimatedSprite2D.new()
	spr.name = "AnimatedSprite2D"
	var frames := SpriteFrames.new()
	frames.add_animation(sp)
	frames.set_animation_speed(sp, 8.0)
	frames.set_animation_loop(sp, true)
	var sheet: Texture2D = load(V131 + "animal_%s.png" % sp)
	for i in 4:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2((i % 2) * 32, (i / 2) * 32, 32, 32)
		frames.add_frame(sp, at)
	if frames.has_animation("default"):
		frames.remove_animation("default")
	spr.sprite_frames = frames
	spr.animation = sp
	spr.offset = Vector2(0, -8)
	body.add_child(spr)
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = float(SPECIES.get(sp, {}).get("r", 7.0))
	cs.shape = circle
	body.add_child(cs)
	return body


func _setup_species() -> void:
	if species == "" and animated_sprite:
		var an := str(animated_sprite.animation).to_lower()
		for k in SPECIES:
			if an.contains(k):
				species = k
		if species == "":
			var f := get_scene_file_path().get_file().get_basename()
			species = f if SPECIES.has(f) else "chicken"
	var info: Dictionary = SPECIES.get(species, SPECIES["chicken"])
	max_hp = int(info["hp"])
	hp = max_hp
	if info.has("speed"):
		walk_speed = float(info["speed"])
	add_to_group("interactables")
	if is_baby:
		scale = Vector2(0.6, 0.6)


func _ready() -> void:
	add_to_group("animals")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_rng.randomize()
	_setup_species()
	if animated_sprite:
		_spr_base_pos = animated_sprite.position
	_breath_phase = _rng.randf() * TAU
	_idle_act_cd = _rng.randf_range(0.5, 3.0)
	start_idle()

func _physics_process(delta: float) -> void:
	if _v14_tick(delta):
		return
	# SpawnManager assigns position after add_child, so capture home on first tick.
	if not _home_initialized:
		_home = global_position
		_stuck_origin = global_position
		_home_initialized = true
	timer -= delta
	if timer <= 0.0:
		if state == "idle":
			start_walking()
		else:
			start_idle()

	var desired_velocity := Vector2.ZERO
	if state == "walking":
		_steering_timer -= delta
		if _steering_timer <= 0.0:
			_steering_timer = _rng.randf_range(0.15, 0.25)
			var heading := direction
			var home_offset := _home - global_position
			if home_offset.length() > roam_radius:
				heading = heading.lerp(home_offset.normalized(), 0.65).normalized()
			heading = (heading + _separation() * 1.5).normalized()
			_desired_direction = _clear_heading(heading)
		if _desired_direction == Vector2.ZERO:
			start_idle()
		else:
			direction = Vector2.from_angle(lerp_angle(direction.angle(), _desired_direction.angle(), minf(delta * 3.0, 1.0)))
			desired_velocity = direction * walk_speed * _pace

	velocity = velocity.move_toward(desired_velocity, acceleration * delta)
	move_and_slide()
	var actual := get_real_velocity()
	if actual.length() > 2.0:
		_update_facing(actual.normalized())
		_play_anim("walk")
		animated_sprite.speed_scale = clampf(actual.length() / maxf(walk_speed, 1.0), 0.5, 1.3)
	else:
		_play_anim("idle")
	_animate_body(delta, actual.length() > 2.0)
	_stuck_elapsed += delta
	if _stuck_elapsed >= 0.8:
		if state == "walking" and global_position.distance_to(_stuck_origin) < 2.0:
			start_idle()
		_stuck_origin = global_position
		_stuck_elapsed = 0.0

func start_idle() -> void:
	state = "idle"
	timer = _rng.randf_range(min_idle_time, max_idle_time)
	# Physics eases velocity down; the idle pose begins once motion has stopped.
	if velocity.length() < 2.0:
		_play_anim("idle")

func start_walking() -> void:
	state = "walking"
	var angle := _rng.randf_range(-PI, PI)
	if direction != Vector2.ZERO and _rng.randf() < 0.7:
		angle = direction.angle() + _rng.randf_range(-1.0, 1.0)
	direction = Vector2.from_angle(angle)
	_pace = _rng.randf_range(0.75, 1.1)
	timer = _rng.randf_range(min_walk_time, max_walk_time)
	_steering_timer = 0.0
	_stuck_elapsed = 0.0
	_stuck_origin = global_position

func _separation() -> Vector2:
	var force := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("animals"):
		if other == self or not other is Node2D:
			continue
		var away: Vector2 = global_position - other.global_position
		var distance := away.length()
		if distance < 0.01:
			# Coincident spawns choose opposite directions, not the same escape.
			force += Vector2.LEFT if get_instance_id() < other.get_instance_id() else Vector2.RIGHT
		elif distance < personal_space:
			force += away / distance * (1.0 - distance / personal_space)
	return force.limit_length(1.0)

func _clear_heading(heading: Vector2) -> Vector2:
	if heading == Vector2.ZERO:
		return Vector2.ZERO
	var lookahead := maxf(16.0, walk_speed * 0.8)
	# Sweep the actual body so fences, rocks, water and other bodies are avoided.
	for angle in [0.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0, PI * 0.75, -PI * 0.75, PI]:
		var candidate := heading.rotated(angle)
		if not test_move(global_transform, candidate * lookahead):
			return candidate
	return Vector2.ZERO

func _update_facing(dir: Vector2) -> void:
	if not animated_sprite:
		return
	# All four animal sheets face LEFT in their original artwork.
	# A dead zone prevents flip jitter during nearly vertical movement.
	if dir.x < -0.2:
		animated_sprite.flip_h = false
	elif dir.x > 0.2:
		animated_sprite.flip_h = true

func _play_anim(base_name: String) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	var frames := animated_sprite.sprite_frames
	var animation_name := base_name
	if not frames.has_animation(animation_name):
		# These assets have a single species-named locomotion clip.
		animation_name = "default" if frames.has_animation("default") else String(animated_sprite.animation)
		if base_name == "idle":
			animated_sprite.stop()
			animated_sprite.frame = 0
			animated_sprite.speed_scale = 1.0
			return
	if frames.has_animation(animation_name):
		if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
			animated_sprite.play(animation_name)


# ==============================================================================
# v1.4.3 idle animation
# ==============================================================================
# The animal sheets only contain a walk cycle, so standing animals used to freeze
# on frame 0. They now breathe and, every few seconds, do something that suits
# the species. Everything is done on the sprite node, so collisions, baby scale
# and the body position are untouched.

const _FOOT_Y := 9.0  ## sprite pixels from the sprite origin down to the feet


func _idle_actions() -> Array:
	match species:
		"chicken", "duck":
			return ["peck", "peck", "look", "ruffle"]
		"rabbit", "snow_hare":
			return ["hop", "nibble", "look", "look"]
		"deer":
			return ["graze", "look", "look", "twitch"]
		_:
			return ["graze", "graze", "look", "twitch"]


func _start_idle_action() -> void:
	var acts := _idle_actions()
	_idle_act = acts[_rng.randi() % acts.size()]
	_idle_act_t = 0.0
	match _idle_act:
		"peck":
			_idle_act_len = _rng.randf_range(0.7, 1.2)
		"graze":
			_idle_act_len = _rng.randf_range(2.0, 3.5)
		"nibble":
			_idle_act_len = _rng.randf_range(1.0, 1.8)
		"hop":
			_idle_act_len = 0.45
		"look":
			_idle_act_len = _rng.randf_range(0.9, 1.6)
		_:
			_idle_act_len = 0.45
	if _idle_act == "look" and animated_sprite:
		animated_sprite.flip_h = not animated_sprite.flip_h
		_look_flipped = true


func _end_idle_action() -> void:
	if _look_flipped and animated_sprite:
		animated_sprite.flip_h = not animated_sprite.flip_h
	_look_flipped = false
	_idle_act = ""
	_idle_act_cd = _rng.randf_range(1.2, 4.0)


func _animate_body(delta: float, moving: bool) -> void:
	if not animated_sprite:
		return
	var sx := 1.0
	var sy := 1.0
	var rot := 0.0
	var off := Vector2.ZERO
	# Art faces LEFT; flip_h = facing right. Positive rotation lifts the left side.
	var face := 1.0 if animated_sprite.flip_h else -1.0
	if moving:
		if _idle_act != "":
			_end_idle_action()
		_idle_act_cd = maxf(_idle_act_cd, 0.6)
		# light trot bounce in step with the walk cycle
		_idle_clock += delta
		off.y = -absf(sin(_idle_clock * 10.0)) * 0.8
	else:
		_idle_clock += delta
		var b := sin(_idle_clock * 2.6 + _breath_phase)
		sy = 1.0 + b * 0.03
		sx = 1.0 - b * 0.015
		if _idle_act == "":
			_idle_act_cd -= delta
			if _idle_act_cd <= 0.0:
				_start_idle_action()
		else:
			_idle_act_t += delta
			var p := clampf(_idle_act_t / maxf(_idle_act_len, 0.01), 0.0, 1.0)
			match _idle_act:
				"peck":
					var k := absf(sin(p * PI * 3.0))
					rot = k * 0.25 * face
					off.y += k * 1.5
				"graze", "nibble":
					var dip := sin(p * PI)
					var hold := clampf(dip * 1.6, 0.0, 1.0)
					var chew := sin(_idle_act_t * (11.0 if _idle_act == "nibble" else 7.0)) * 0.03 * hold
					rot = (hold * 0.16 + chew) * face
					off.y += hold * 1.2
				"hop":
					var h := sin(p * PI)
					off.y -= h * 4.0
					sy *= 1.0 + h * 0.08 - (0.12 if p < 0.12 or p > 0.9 else 0.0)
				"look":
					off.y -= sin(p * PI) * 0.6
				"ruffle":
					rot = sin(_idle_act_t * 45.0) * 0.09 * (1.0 - p)
					sx *= 1.0 + sin(p * PI) * 0.1
				"twitch":
					rot = sin(_idle_act_t * 30.0) * 0.05 * (1.0 - p)
			if _idle_act_t >= _idle_act_len:
				_end_idle_action()
	# keep the feet planted while the sprite squashes
	off.y += (1.0 - sy) * _FOOT_Y
	var w := minf(delta * 14.0, 1.0)
	animated_sprite.scale = animated_sprite.scale.lerp(Vector2(sx, sy), w)
	animated_sprite.rotation = lerpf(animated_sprite.rotation, rot, w)
	animated_sprite.position = animated_sprite.position.lerp(_spr_base_pos + off, w)


# ==============================================================================
# v1.4 behaviour
# ==============================================================================

## Returns true when this frame's movement was handled here (dead, fleeing, in love).
func _v14_tick(delta: float) -> bool:
	if is_dead:
		return true
	if _breed_cd > 0.0:
		_breed_cd -= delta
	if is_baby and Engine.get_physics_frames() % 120 == 0:
		var clock := get_tree().get_first_node_in_group("game_clock")
		if clock and int(clock.get("current_day")) > birth_day:
			is_baby = false
			create_tween().tween_property(self, "scale", Vector2.ONE, 1.0)
	var target_v := Vector2.INF
	if _flee_t > 0.0:
		_flee_t -= delta
		var away := (global_position - _flee_from).normalized()
		if away == Vector2.ZERO:
			away = Vector2.RIGHT.rotated(randf() * TAU)
		target_v = _clear_heading(away) * walk_speed * 2.6
	elif _love_t > 0.0:
		_love_t -= delta
		_heart_t -= delta
		if _heart_t <= 0.0:
			_heart_t = 0.7
			var juice := get_tree().get_first_node_in_group("juice")
			if juice:
				juice.popup_text(global_position + Vector2(0, -20), "<3", Color("FF8FB0"))
		var mate := _find_mate()
		if mate:
			var d := mate.global_position - global_position
			if d.length() < 24.0:
				if get_instance_id() < mate.get_instance_id():
					_give_birth(mate)
				target_v = Vector2.ZERO
			else:
				target_v = d.normalized() * walk_speed * 1.2
	if target_v == Vector2.INF:
		return false
	velocity = velocity.move_toward(target_v, acceleration * 3.0 * delta)
	move_and_slide()
	if velocity.length() > 2.0:
		_update_facing(velocity.normalized())
		_play_anim("walk")
		animated_sprite.speed_scale = 1.6 if _flee_t > 0.0 else 1.0
	else:
		_play_anim("idle")
	_animate_body(delta, velocity.length() > 2.0)
	return true


## Hit by the player's tool, weapon or fists.
func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO, knockback: float = 0.0) -> void:
	if is_dead:
		return
	hp -= maxi(1, amount)
	var p := get_tree().get_first_node_in_group("player") as Node2D
	_flee_from = p.global_position if p else global_position - hit_direction * 10.0
	_flee_t = 3.5
	_love_t = 0.0
	if hit_direction != Vector2.ZERO:
		velocity = hit_direction.normalized() * maxf(knockback, 25.0) * 3.0
	if animated_sprite:
		animated_sprite.modulate = Color(1.6, 0.5, 0.5)
		create_tween().tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.damage_number(global_position + Vector2(0, -6), amount)
	# the herd runs too
	for o in get_tree().get_nodes_in_group("animals"):
		if o != self and is_instance_valid(o) and o.get("species") == species and (o as Node2D).global_position.distance_to(global_position) < 90.0:
			o.set("_flee_from", _flee_from)
			o.set("_flee_t", 2.5)
	if hp <= 0:
		_die()


func take_hit(tool_power: int = 1, hit_dir: Vector2 = Vector2.ZERO) -> bool:
	take_damage(4 + tool_power * 2, hit_dir, 25.0)
	return true


func _die() -> void:
	is_dead = true
	remove_from_group("interactables")
	collision_layer = 0
	var info: Dictionary = SPECIES.get(species, {})
	var parent := get_parent()
	for d in info.get("drops", []):
		var n: int = _rng.randi_range(int(d[1]), int(d[2]))
		if is_baby:
			n = mini(n, 1)
		var it = ItemDB.get_item(str(d[0]))
		if it and n > 0:
			var w := WorldItemScene.instantiate()
			parent.add_child(w)
			w.global_position = global_position + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-2, 6))
			w.call("set_item", it, n)
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats and stats.has_method("add_xp"):
		stats.add_xp(4)
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.emit("animal_killed", {"species": species})
			break
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


# --- Feeding and breeding -----------------------------------------------------

func _held_food(p: Node2D) -> String:
	var item: Resource = p.get("current_held_item") if p else null
	if item == null:
		return ""
	var id := str(item.get("item_id"))
	return id if id in SPECIES.get(species, {}).get("food", []) else ""


func can_interact(p: Node2D) -> bool:
	return not is_dead and not is_baby and _love_t <= 0.0 and _breed_cd <= 0.0 and _held_food(p) != ""


func get_prompt() -> String:
	return "FEED " + str(SPECIES.get(species, {}).get("name", "ANIMAL"))


func interact(p: Node2D) -> void:
	var food := _held_food(p)
	if food == "":
		return
	var hotbar := get_tree().get_first_node_in_group("hotbar_ui")
	var inv := get_tree().get_first_node_in_group("inventory_ui")
	var gm := get_tree().get_first_node_in_group("game_mode")
	if hotbar and inv and not (gm and gm.get("creative") == true):
		inv.remove_hotbar_item_at(int(hotbar.get("selected_slot")), 1)
		if p.has_method("_on_hotbar_slot_selected"):
			p._on_hotbar_slot_selected(hotbar.selected_slot, hotbar.get_selected_item())
	_love_t = 14.0
	_heart_t = 0.0
	start_idle()
	var hud := get_tree().get_first_node_in_group("hud_ui")
	if hud and _find_mate() == null:
		hud.show_hud_message("Feed another %s nearby so they can have a baby." % str(SPECIES[species]["name"]).to_lower(), 3.0)


func _find_mate() -> Node2D:
	var best: Node2D = null
	var bd := 140.0
	for o in get_tree().get_nodes_in_group("animals"):
		if o == self or not is_instance_valid(o) or o.get("species") != species or o.get("is_baby") or o.get("is_dead"):
			continue
		if float(o.get("_love_t")) <= 0.0:
			continue
		var d := (o as Node2D).global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = o
	return best


func _give_birth(mate: Node2D) -> void:
	_love_t = 0.0
	mate.set("_love_t", 0.0)
	_breed_cd = 240.0
	mate.set("_breed_cd", 240.0)
	var baby: CharacterBody2D = create(species)
	baby.set("is_baby", true)
	var clock := get_tree().get_first_node_in_group("game_clock")
	baby.set("birth_day", int(clock.get("current_day")) if clock else 0)
	baby.set_meta("bred", true)
	baby.add_to_group("saved_animals")
	var home: Node = get_tree().get_first_node_in_group("build_manager")
	(home if home else get_parent()).add_child(baby)
	baby.global_position = (global_position + mate.global_position) * 0.5 + Vector2(0, 6)
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.popup_text(baby.global_position + Vector2(0, -18), "A BABY " + str(SPECIES[species]["name"]) + "!", Color("FFDB80"))
	# the parents now belong to your farm too
	for a in [self, mate]:
		a.set_meta("bred", true)
		a.add_to_group("saved_animals")
		# wild animals move to your farm for good (they are saved from now on)
		if home and a.get_parent() != home:
			a.call_deferred("reparent", home)


func get_save_data() -> Dictionary:
	return {"s": species, "x": global_position.x, "y": global_position.y, "b": is_baby, "d": birth_day}
