extends CharacterBody2D

enum State {
	IDLE,
	WALKING,
	ACTING,
	EATING,
	SLEEPING
}

const ItemDataClass = preload("res://scripts/item_data.gd")
const WorldItemClass = preload("res://scripts/world_item.gd")
const WorldItemScene = preload("res://Scenes/world_item.tscn")
const SwooshEffectClass = preload("res://scripts/swoosh_effect.gd")

@export var walk_speed: float = 135.0
@export var sprint_speed: float = 195.0
@export var speed: float = 135.0
@export var pickup_radius: float = 24.0
@export var interaction_distance: float = 32.0

@export_group("Camera Settings")
@export var camera_zoom: Vector2 = Vector2(3.0, 3.0)
@export var camera_smoothing_enabled: bool = true
@export var camera_smoothing_speed: float = 10.0
@export var auto_detect_camera_limits: bool = true
@export var camera_limit_left: int = -1456
@export var camera_limit_top: int = -464
@export var camera_limit_right: int = 880
@export var camera_limit_bottom: int = 576

@export_group("Torch Settings")
@export var placement_distance: float = 24.0
@export var torch_light_scale: float = 2.4 ## Light radius size (higher = larger illuminated circle)
@export var torch_night_energy: float = 1.5 ## Brightness at night
@export var torch_day_energy: float = 1.2 ## Brightness during day / dusk
@export var torch_light_color: Color = Color(1.0, 0.78, 0.48, 1.0) ## Light tint color
@export var torch_flicker_intensity: float = 0.06 ## Flame flicker variation (0.0 = steady light)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var held_item_anchor: Marker2D = $HeldItemAnchor
@onready var held_item_sprite: Sprite2D = $HeldItemAnchor/HeldItemSprite
@onready var held_torch_flame: AnimatedSprite2D = get_node_or_null("HeldItemAnchor/HeldTorchFlame")
@onready var torch_light: PointLight2D = get_node_or_null("HeldItemAnchor/TorchLight")
@onready var tool_hitbox: Area2D = get_node_or_null("ToolHitbox")
@onready var camera: Camera2D = get_node_or_null("Camera2D")
@onready var swoosh_effect: SwooshEffect = get_node_or_null("SwooshEffect")

var _torch_flicker_time: float = 0.0
var _torch_base_energy: float = 1.0
var _game_clock: Node = null
var _is_unhoeing: bool = false

var current_state: State = State.IDLE


var last_direction: Vector2 = Vector2.DOWN
var is_acting: bool = false
var current_held_item: Resource = null
var current_action_type: int = 0
var impact_executed: bool = false
var _current_action_timestamp: int = 0
var _is_eating: bool = false ## True during eating animation
var _eating_item_data: Resource = null ## The food item being consumed
var _is_sleeping: bool = false ## True during sleeping sequence (Phase 7)
var _pre_sleep_rotation: float = 0.0
var _pre_sleep_collision_disabled: bool = false
var _pre_sleep_sprite_offset: Vector2 = Vector2.ZERO

# Camera Middle-Mouse Drag Panning
var is_panning_camera: bool = false
var pan_drag_start_mouse_pos: Vector2 = Vector2.ZERO
var pan_drag_start_camera_offset: Vector2 = Vector2.ZERO

# Cooldown & Continuous Hold Tracking
var _last_action_end_time: int = 0
var _current_item_cooldown: float = 0.2
var _hit_targets_this_swing: Array = []

# --- Health System (Priority 1) ---
var _player_stats: Node = null
var _is_dead: bool = false
var _pending_knockback: Vector2 = Vector2.ZERO

# Natural directional hand offsets (aligned with character spritesheet)
const HELD_OFFSETS := {
	"down": { "pos": Vector2(6, 4), "z": 1, "flip": false, "rot": -20.0 },
	"up": { "pos": Vector2(-5, -2), "z": -1, "flip": false, "rot": -20.0 },
	"left": { "pos": Vector2(-7, 3), "z": 1, "flip": true, "rot": 15.0 },
	"right": { "pos": Vector2(7, 3), "z": 1, "flip": false, "rot": -15.0 }
}


func _ready() -> void:
	add_to_group("player")
	
	if not swoosh_effect:
		swoosh_effect = get_node_or_null("SwooshEffect")
	if not swoosh_effect:
		swoosh_effect = SwooshEffectClass.new()
		add_child(swoosh_effect)
	
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
		animated_sprite.frame_changed.connect(_on_sprite_frame_changed)
		play_idle_animation()
	
	_setup_camera()
	call_deferred("_setup_camera")
	
	if not InputMap.has_action("unhoe_soil"):
		InputMap.add_action("unhoe_soil")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("unhoe_soil", mb)
	
	call_deferred("_connect_hotbar")
	call_deferred("_connect_game_clock")



func _connect_hotbar() -> void:
	var hotbar = get_hotbar()
	if hotbar:
		if not hotbar.slot_selected.is_connected(_on_hotbar_slot_selected):
			hotbar.slot_selected.connect(_on_hotbar_slot_selected)
		var item: Resource = hotbar.call("get_selected_item")
		_on_hotbar_slot_selected(hotbar.selected_slot, item)


func _detect_map_bounds() -> Rect2:
	var root := get_parent()
	if not root:
		return Rect2()
	var tilemap := root.get_node_or_null("TileMap")
	if not tilemap:
		return Rect2()
	
	var min_pos := Vector2(999999, 999999)
	var max_pos := Vector2(-999999, -999999)
	var has_bounds := false
	
	for child in tilemap.get_children():
		if child is TileMapLayer:
			var layer := child as TileMapLayer
			var rect := layer.get_used_rect()
			if rect.has_area() and layer.tile_set:
				var ts := layer.tile_set.tile_size
				var l_min := Vector2(rect.position * ts)
				var l_max := Vector2(rect.end * ts)
				min_pos.x = min(min_pos.x, l_min.x)
				min_pos.y = min(min_pos.y, l_min.y)
				max_pos.x = max(max_pos.x, l_max.x)
				max_pos.y = max(max_pos.y, l_max.y)
				has_bounds = true
	
	if has_bounds:
		return Rect2(min_pos, max_pos - min_pos)
	return Rect2()


func _setup_camera() -> void:
	if not camera:
		camera = get_node_or_null("Camera2D")
	if camera:
		camera.zoom = camera_zoom
		camera.position_smoothing_enabled = camera_smoothing_enabled
		camera.position_smoothing_speed = camera_smoothing_speed
		
		if auto_detect_camera_limits:
			var bounds := _detect_map_bounds()
			if bounds.has_area():
				camera.limit_left = int(bounds.position.x)
				camera.limit_top = int(bounds.position.y)
				camera.limit_right = int(bounds.end.x)
				camera.limit_bottom = int(bounds.end.y)
				return
		
		camera.limit_left = camera_limit_left
		camera.limit_top = camera_limit_top
		camera.limit_right = camera_limit_right
		camera.limit_bottom = camera_limit_bottom


func _process(delta: float) -> void:
	if is_acting and animated_sprite:
		_sync_held_item_animation_frame(animated_sprite.frame)
	
	# Smoothly return camera offset to center when not actively dragging
	if camera and not is_panning_camera and camera.offset != Vector2.ZERO:
		camera.offset = camera.offset.lerp(Vector2.ZERO, delta * 12.0)
		if camera.offset.length_squared() < 0.1:
			camera.offset = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if _is_dead or _is_sleeping:
		velocity = Vector2.ZERO
		return
	
	# Torch light natural flame flicker
	if torch_light and torch_light.enabled:
		_torch_flicker_time += delta * 7.0
		var flicker := sin(_torch_flicker_time) * torch_flicker_intensity + sin(_torch_flicker_time * 2.3) * (torch_flicker_intensity * 0.65)
		torch_light.energy = _torch_base_energy + flicker
	
	# Failsafe: if held item is null but hotbar has an item, sync it
	if current_held_item == null:
		var hotbar = get_hotbar()
		if hotbar:
			var item = hotbar.call("get_selected_item")
			if item:
				_on_hotbar_slot_selected(hotbar.selected_slot, item)

	if is_ui_blocking():
		velocity = Vector2.ZERO
		if not is_acting:
			play_idle_animation()
		move_and_slide()
		return

	if is_acting:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	var is_running := Input.is_key_pressed(KEY_SHIFT) or (InputMap.has_action("run") and Input.is_action_pressed("run"))
	var active_speed := sprint_speed if is_running else walk_speed
	velocity = direction * active_speed

	if direction != Vector2.ZERO:
		last_direction = get_facing_direction(direction)
		current_state = State.WALKING
		_update_held_item_position()
		_update_tool_hitbox_position()
		play_walk_animation()
	else:
		current_state = State.IDLE
		play_idle_animation()

	check_action_inputs()
	# Apply knockback from damage
	if _pending_knockback != Vector2.ZERO:
		velocity += _pending_knockback
		_pending_knockback = Vector2.ZERO
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if _is_dead or _is_sleeping:
		return
	
	# Middle-mouse camera drag panning (processed unless UI is blocking)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed and not is_ui_blocking():
				is_panning_camera = true
				pan_drag_start_mouse_pos = event.position
				pan_drag_start_camera_offset = camera.offset if camera else Vector2.ZERO
			else:
				is_panning_camera = false
			return
	elif event is InputEventMouseMotion and is_panning_camera:
		if camera and not is_ui_blocking():
			var delta_screen: Vector2 = event.position - pan_drag_start_mouse_pos
			camera.offset = pan_drag_start_camera_offset - (delta_screen / camera.zoom)
			return

	if is_acting or is_ui_blocking():
		return

	if event.is_action_pressed("swing") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE):
		trigger_primary_action()
	elif event.is_action_pressed("watering") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_CTRL or event.keycode == KEY_META)):
		trigger_watering()
	elif event.is_action_pressed("harvest") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		trigger_primary_action()
	elif event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_G or event.keycode == KEY_E)):
		trigger_interact()
	elif event.is_action_pressed("drop_item") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q):
		trigger_drop_item()
	elif event.is_action_pressed("unhoe_soil"):
		trigger_unhoe()
	elif event.is_action_pressed("place_torch") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		var is_holding_hoe: bool = current_held_item != null and (current_held_item.get("action_type") == ItemDataClass.ActionType.TILL or current_held_item.get("item_id") == "hoe")
		if is_holding_hoe:
			trigger_unhoe()
		else:
			trigger_place_held_torch()


func check_action_inputs() -> bool:
	if is_acting or is_ui_blocking():
		return false

	# 1. Direct one-shot inputs
	if Input.is_action_just_pressed("swing") or Input.is_action_just_pressed("harvest"):
		trigger_primary_action()
		return true
	elif Input.is_action_just_pressed("watering"):
		trigger_watering()
		return true
	elif Input.is_action_just_pressed("interact"):
		trigger_interact()
		return true
	elif Input.is_action_just_pressed("drop_item"):
		trigger_drop_item()
		return true
	elif InputMap.has_action("unhoe_soil") and Input.is_action_just_pressed("unhoe_soil"):
		if trigger_unhoe():
			return true

	elif Input.is_action_just_pressed("place_torch") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var is_holding_hoe: bool = current_held_item != null and (current_held_item.get("action_type") == ItemDataClass.ActionType.TILL or current_held_item.get("item_id") == "hoe")
		if is_holding_hoe:
			if trigger_unhoe():
				return true
		else:
			if trigger_place_held_torch():
				return true


	# 2. Continuous Hold-to-Swing check
	if _is_action_key_held() and _is_cooldown_ready():
		trigger_primary_action()
		return true

	return false


func _is_action_key_held() -> bool:
	return (
		Input.is_action_pressed("swing")
		or Input.is_action_pressed("harvest")
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		or Input.is_key_pressed(KEY_SPACE)
	)


func _is_cooldown_ready() -> bool:
	if _last_action_end_time == 0:
		return true
	var elapsed_sec := (Time.get_ticks_msec() - _last_action_end_time) / 1000.0
	return elapsed_sec >= _current_item_cooldown


# ==============================================================================
# ACTION FRAMEWORK & STATE LOCKING
# ==============================================================================

func trigger_primary_action() -> void:
	if is_acting or is_ui_blocking() or _is_sleeping:
		return
	
	# If no item is equipped in active slot, check if player is facing a mature crop to harvest
	if not current_held_item:
		var farm_mgr := _find_farming_manager()
		var farm_reach := global_position + (last_direction * interaction_distance)
		if farm_mgr and (farm_mgr.can_harvest(farm_reach) or farm_mgr.can_harvest(global_position)):
			trigger_harvest()
		return
	
	var action_type: int = ItemDataClass.ActionType.NONE
	if current_held_item.get("action_type") != null:
		action_type = current_held_item.get("action_type")
	
	match action_type:
		ItemDataClass.ActionType.TILL:
			trigger_till()
		ItemDataClass.ActionType.CHOP:
			trigger_chop()
		ItemDataClass.ActionType.ATTACK:
			trigger_attack()
		ItemDataClass.ActionType.MINE:
			trigger_chop()
		ItemDataClass.ActionType.WATER:
			trigger_watering()
		ItemDataClass.ActionType.HARVEST:
			trigger_harvest()
		ItemDataClass.ActionType.PLANT:
			trigger_plant()
		ItemDataClass.ActionType.EAT:
			trigger_eat()
		_:
			if current_held_item and current_held_item.get("item_type") == ItemDataClass.ItemType.SEED:
				trigger_plant()
			elif current_held_item and current_held_item.get("item_id") == "hoe":
				trigger_till()
			elif current_held_item and current_held_item.get("item_id") == "watering_can":
				trigger_watering()
			elif current_held_item and current_held_item.get("edible") == true:
				trigger_eat()
			else:
				trigger_swing()


var _current_farm_target_pos: Vector2 = Vector2.ZERO


## Calculates farming action target: targets mouse cursor if within reach (64px),
## automatically turns Ken to face the cursor, and snaps to grid tile center.
func get_farming_target_pos(max_reach: float = 64.0) -> Vector2:
	var farm_mgr := _find_farming_manager()
	var mouse_pos := get_global_mouse_position()
	var dist := global_position.distance_to(mouse_pos)
	
	if dist <= max_reach:
		var dir := (mouse_pos - global_position).normalized()
		last_direction = get_facing_direction(dir)
		_update_held_item_position()
		_update_tool_hitbox_position()
		play_idle_animation()
		if farm_mgr:
			return farm_mgr.grid_to_world(farm_mgr.world_to_grid(mouse_pos))
		return mouse_pos
	
	# Fallback if mouse is out of reach
	var facing_pos := global_position + (last_direction * interaction_distance)
	if farm_mgr:
		return farm_mgr.grid_to_world(farm_mgr.world_to_grid(facing_pos))
	return facing_pos


func trigger_till() -> void:
	var farm_mgr := _find_farming_manager()
	_current_farm_target_pos = get_farming_target_pos()
	_is_unhoeing = false
	
	if farm_mgr and not farm_mgr.can_hoe_tile(_current_farm_target_pos):
		# Prevent hoeing invalid terrain, occupied tiles, or already hoed tiles
		return
	
	_start_directional_swing(ItemDataClass.ActionType.TILL)


## Safely undoes hoed soil back to normal ground when holding hoe.
## Cannot unhoe if tile is occupied by a crop.
func trigger_unhoe() -> bool:
	var farm_mgr := _find_farming_manager()
	var target_pos := get_farming_target_pos()
	if not farm_mgr or not farm_mgr.can_unhoe_tile(target_pos):
		return false
	
	_current_farm_target_pos = target_pos
	_is_unhoeing = true
	_start_directional_swing(ItemDataClass.ActionType.TILL)
	return true



func trigger_plant() -> void:
	var hotbar: Control = get_hotbar()
	var inv: Control = get_inventory()
	if not inv or not current_held_item:
		return
	
	var active_slot: int = 0
	if hotbar and hotbar.get("selected_slot") != null:
		active_slot = hotbar.get("selected_slot")
	
	var item_id: String = current_held_item.get("item_id") if current_held_item.get("item_id") != null else ""
	var target_pos := get_farming_target_pos()
	var farm_mgr := _find_farming_manager()
	
	# Validation: tile must be hoed, unoccupied, player has seed.
	# If validation fails: DO NOTHING. Do NOT consume seed!
	if farm_mgr and not farm_mgr.can_plant_seed(target_pos, item_id):
		return
	
	# Remove 1 seed from hotbar
	var removed = null
	if inv.has_method("remove_hotbar_item_at"):
		removed = inv.call("remove_hotbar_item_at", active_slot, 1)
	elif inv.has_method("remove_item_at"):
		removed = inv.call("remove_item_at", active_slot, 1)
	
	if removed:
		if farm_mgr:
			farm_mgr.plant_seed(target_pos, item_id)
		
		var anim_name := "harvest_front"
		if last_direction == Vector2.UP:
			anim_name = "harvest_back"
		elif last_direction == Vector2.LEFT:
			anim_name = "harvest_left"
		elif last_direction == Vector2.RIGHT:
			anim_name = "harvest_right"
		_start_action(ItemDataClass.ActionType.PLANT, anim_name)
		
		if item_id == "carrot_seed":
			_notify_event_bus("carrot_planted")
		_notify_event_bus("crop_planted", [item_id])


func trigger_swing() -> void:
	_start_directional_swing(ItemDataClass.ActionType.NONE)


func trigger_chop() -> void:
	_start_directional_swing(ItemDataClass.ActionType.CHOP)


func trigger_attack() -> void:
	_start_directional_swing(ItemDataClass.ActionType.ATTACK)


func _start_directional_swing(action_type: int) -> void:
	var anim_name := "swing"
	if last_direction == Vector2.UP:
		anim_name = "swing_back"
	
	_start_action(action_type, anim_name)


func trigger_watering() -> void:
	var farm_mgr := _find_farming_manager()
	var target_pos := get_farming_target_pos()
	
	# Validation: cannot water empty untilled soil
	if farm_mgr and not farm_mgr.can_water(target_pos):
		return
	
	if farm_mgr:
		farm_mgr.water_tile(target_pos)
	
	var anim_name := "watering_front"
	if last_direction == Vector2.DOWN:
		anim_name = "watering_front"
	elif last_direction == Vector2.UP:
		anim_name = "watering_back"
	elif last_direction == Vector2.LEFT:
		anim_name = "watering_left"
	elif last_direction == Vector2.RIGHT:
		anim_name = "watering_right"
	_start_action(ItemDataClass.ActionType.WATER, anim_name)


func trigger_harvest() -> bool:
	var farm_mgr := _find_farming_manager()
	var target_pos := get_farming_target_pos()
	if not farm_mgr or not farm_mgr.can_harvest(target_pos):
		var facing_pos := global_position + (last_direction * interaction_distance)
		if farm_mgr and farm_mgr.can_harvest(facing_pos):
			target_pos = facing_pos
		elif farm_mgr and farm_mgr.can_harvest(global_position):
			target_pos = global_position
		else:
			return false
	
	var anim_name := "harvest_front"
	if last_direction == Vector2.DOWN:
		anim_name = "harvest_front"
	elif last_direction == Vector2.UP:
		anim_name = "harvest_back"
	elif last_direction == Vector2.LEFT:
		anim_name = "harvest_left"
	elif last_direction == Vector2.RIGHT:
		anim_name = "harvest_right"
	_start_action(ItemDataClass.ActionType.HARVEST, anim_name)
	
	var inv := get_inventory()
	farm_mgr.harvest_crop(target_pos, inv)
	return true


# ==============================================================================
# EATING SYSTEM (Phase 6)
# ==============================================================================

## Eats the currently selected food item from the hotbar.
## Validates: item exists, is edible, quantity > 0, hunger not full.
## Uses a tween-based "bite" animation that keeps Ken standing.
func trigger_eat() -> void:
	if is_acting or is_ui_blocking():
		return
	
	var hotbar: Control = get_hotbar()
	var inv: Control = get_inventory()
	if not inv or not current_held_item:
		return
	
	# Validate edible
	var is_edible: bool = current_held_item.get("edible") == true
	if not is_edible:
		return
	
	# Validate quantity
	var active_slot: int = 0
	if hotbar and hotbar.get("selected_slot") != null:
		active_slot = hotbar.get("selected_slot")
	
	var slot_data: Dictionary = {}
	if hotbar and hotbar.has_method("get_slot_data"):
		slot_data = hotbar.call("get_slot_data", active_slot)
	elif inv.has_method("get_hotbar_item_at"):
		slot_data = inv.call("get_hotbar_item_at", active_slot)
	
	var amount: int = slot_data.get("amount", 0)
	if amount <= 0:
		return
	
	# Validate hunger needs restoration
	if not _player_stats:
		_player_stats = _find_player_stats()
	if _player_stats and _player_stats.is_full():
		var hud = _find_hud()
		if hud and hud.has_method("show_hud_message"):
			hud.show_hud_message("Already full!", 1.5)
		print("Ken: Already full!")
		return
	
	# Cache the food item data for the animation (consumption happens AFTER anim)
	_eating_item_data = current_held_item
	
	# Lock state — Ken stays standing (idle animation), but actions are blocked
	is_acting = true
	current_state = State.EATING
	_is_eating = true
	velocity = Vector2.ZERO
	
	# Keep the idle animation playing (standing, correct direction)
	play_idle_animation()
	
	# Start the tween-based bite animation
	_start_eating_animation()


## Tween-based eating animation: food icon moves toward mouth 3 times (3 bites).
## Ken stays in idle/standing animation throughout.
func _start_eating_animation() -> void:
	if not _eating_item_data:
		_finish_eating()
		return
	
	# Show food icon on held item sprite
	var food_icon: Texture2D = _eating_item_data.get("icon")
	if held_item_sprite and food_icon:
		held_item_sprite.texture = food_icon
		held_item_sprite.visible = true
		held_item_sprite.rotation_degrees = 0.0
		held_item_sprite.flip_h = false
		held_item_sprite.scale = Vector2(1.0, 1.0)
	
	# Get directional positions for hand (start) and mouth (target)
	var dir_key := _get_direction_key()
	var hand_pos := Vector2.ZERO
	var mouth_pos := Vector2.ZERO
	match dir_key:
		"down":
			hand_pos = Vector2(6, 2)
			mouth_pos = Vector2(3, -2)
		"up":
			hand_pos = Vector2(-5, 0)
			mouth_pos = Vector2(-3, -6)
		"left":
			hand_pos = Vector2(-8, 1)
			mouth_pos = Vector2(-5, -3)
		"right":
			hand_pos = Vector2(8, 1)
			mouth_pos = Vector2(5, -3)
	
	if held_item_anchor:
		held_item_anchor.position = hand_pos
		held_item_anchor.z_index = 1
	
	# Create tween: 3 bites (hand → mouth → hand) + final cleanup
	var eat_tween := create_tween()
	eat_tween.set_trans(Tween.TRANS_SINE)
	eat_tween.set_ease(Tween.EASE_IN_OUT)
	
	for i in range(3):
		# Bite: move food toward mouth
		eat_tween.tween_property(held_item_anchor, "position", mouth_pos, 0.12)
		# Small scale pulse on "bite" to simulate crunch
		eat_tween.tween_property(held_item_sprite, "scale", Vector2(0.85, 0.85), 0.04)
		eat_tween.tween_property(held_item_sprite, "scale", Vector2(1.0, 1.0), 0.04)
		# Return food to hand
		eat_tween.tween_property(held_item_anchor, "position", hand_pos, 0.08)
	
	# Brief hold at end then finish
	eat_tween.tween_interval(0.06)
	eat_tween.tween_callback(_finish_eating)
	
	# Play eating sound
	_play_eating_sound()


## Completes the eating action: consumes item, restores hunger, cleans up state.
## Called by the eating tween after the bite animation finishes.
func _finish_eating() -> void:
	if not _is_eating:
		return
	
	var hotbar: Control = get_hotbar()
	var inv: Control = get_inventory()
	var active_slot: int = 0
	if hotbar and hotbar.get("selected_slot") != null:
		active_slot = hotbar.get("selected_slot")
	
	# Read hunger_restore and metadata from cached food data
	var hunger_restore: float = _eating_item_data.get("hunger_restore") if _eating_item_data and _eating_item_data.get("hunger_restore") != null else 0.0
	var item_id: String = _eating_item_data.get("item_id") if _eating_item_data and _eating_item_data.get("item_id") != null else ""
	var food_name: String = _eating_item_data.get("display_name") if _eating_item_data and _eating_item_data.get("display_name") != null else "Food"
	
	# Consume 1 item from hotbar
	var removed = null
	if inv:
		if inv.has_method("remove_hotbar_item_at"):
			removed = inv.call("remove_hotbar_item_at", active_slot, 1)
		elif inv.has_method("remove_item_at"):
			removed = inv.call("remove_item_at", active_slot, 1)
	
	# Restore hunger
	if removed:
		if not _player_stats:
			_player_stats = _find_player_stats()
		if _player_stats:
			_player_stats.restore_hunger(hunger_restore)
		
		# Notify event bus
		_notify_event_bus("food_eaten", [item_id])
		
		print("Ken: Ate %s (+%d hunger)" % [food_name, int(hunger_restore)])
	
	# Clean up eating state
	_is_eating = false
	_eating_item_data = null
	is_acting = false
	current_state = State.IDLE
	
	# Reset held item sprite scale
	if held_item_sprite:
		held_item_sprite.scale = Vector2(1.0, 1.0)
	
	# Restore held item visual (shows equipped tool/item or hides if empty)
	_update_held_item_visuals()
	
	# Return to correct idle animation based on facing direction
	play_idle_animation()


## Plays eating sound effect. Audio assets required:
## - res://Assets/Items/eat_bite.wav (crunch/bite sound)
## - res://Assets/Items/eat_drink.wav (drinking/slurping, future)
func _play_eating_sound() -> void:
	# Hook: load and play eating audio when assets are available
	var eat_sound_path := "res://Assets/Items/eat_bite.wav"
	if ResourceLoader.exists(eat_sound_path):
		var audio_player := AudioStreamPlayer.new()
		audio_player.stream = load(eat_sound_path)
		audio_player.volume_db = -6.0
		add_child(audio_player)
		audio_player.play()
		audio_player.finished.connect(audio_player.queue_free)


## Finds the HUD node for showing messages.
func _find_hud() -> Control:
	if not get_tree():
		return null
	var hud_nodes := get_tree().get_nodes_in_group("hud_ui")
	for node in hud_nodes:
		if is_instance_valid(node):
			return node as Control
	return null




func _start_action(action_type: int, animation_name: String) -> void:
	is_acting = true
	current_state = State.ACTING
	current_action_type = action_type
	impact_executed = false
	velocity = Vector2.ZERO
	_hit_targets_this_swing.clear()
	
	# Fetch item speed scaling and cooldown
	var speed_mult := 1.0
	if current_held_item and current_held_item.get("swing_speed_scale") != null:
		speed_mult = max(0.5, current_held_item.get("swing_speed_scale"))
	
	_current_item_cooldown = 0.2
	if current_held_item and current_held_item.get("swing_cooldown") != null:
		_current_item_cooldown = max(0.05, current_held_item.get("swing_cooldown"))
	
	# Direction-specific sprite orientation
	if animation_name == "swing":
		if last_direction == Vector2.LEFT:
			animated_sprite.flip_h = true
		else:
			animated_sprite.flip_h = false
	elif animation_name == "swing_back":
		animated_sprite.flip_h = false
	elif animation_name.begins_with("watering_") or animation_name.begins_with("harvest_"):
		if held_item_sprite:
			held_item_sprite.visible = false
	
	_update_tool_hitbox_position()
	
	if animated_sprite:
		animated_sprite.speed_scale = speed_mult
		animated_sprite.stop()
		animated_sprite.play(animation_name)
	
	_sync_held_item_animation_frame(0)
	
	# Failsafe action timeout (scaled with speed)
	var action_id := Time.get_ticks_msec()
	_current_action_timestamp = action_id
	var failsafe_duration := 0.55 / speed_mult
	get_tree().create_timer(failsafe_duration).timeout.connect(func():
		if is_acting and _current_action_timestamp == action_id:
			_on_animation_finished()
	)


func _on_sprite_frame_changed() -> void:
	if not animated_sprite:
		return
	
	var frame_idx: int = animated_sprite.frame
	_sync_held_item_animation_frame(frame_idx)
	
	# Impact frame trigger (Frame 3 on swings)
	if is_acting and not impact_executed:
		if (animated_sprite.animation == "swing" or animated_sprite.animation == "swing_back") and frame_idx >= 3:
			impact_executed = true
			_execute_action_impact()


func _sync_held_item_animation_frame(frame_idx: int) -> void:
	if not held_item_sprite or not held_item_sprite.visible:
		return
	
	var dir_key := _get_direction_key()
	var base_cfg: Dictionary = HELD_OFFSETS[dir_key]
	var base_pos: Vector2 = base_cfg["pos"]
	var base_rot: float = base_cfg["rot"]
	
	if is_acting:
		if animated_sprite.animation == "swing":
			match dir_key:
				"right":
					match frame_idx:
						0:
							held_item_anchor.position = Vector2(-2, -3)
							held_item_sprite.rotation_degrees = -75.0
						1:
							held_item_anchor.position = Vector2(0, -6)
							held_item_sprite.rotation_degrees = -95.0
						2:
							held_item_anchor.position = Vector2(6, -2)
							held_item_sprite.rotation_degrees = -10.0
						3:
							held_item_anchor.position = Vector2(12, 3)
							held_item_sprite.rotation_degrees = 45.0
						4:
							held_item_anchor.position = Vector2(10, 6)
							held_item_sprite.rotation_degrees = 70.0
						_:
							held_item_anchor.position = base_pos
							held_item_sprite.rotation_degrees = base_rot
				"left":
					match frame_idx:
						0:
							held_item_anchor.position = Vector2(2, -3)
							held_item_sprite.rotation_degrees = 75.0
						1:
							held_item_anchor.position = Vector2(0, -6)
							held_item_sprite.rotation_degrees = 95.0
						2:
							held_item_anchor.position = Vector2(-6, -2)
							held_item_sprite.rotation_degrees = 10.0
						3:
							held_item_anchor.position = Vector2(-12, 3)
							held_item_sprite.rotation_degrees = -45.0
						4:
							held_item_anchor.position = Vector2(-10, 6)
							held_item_sprite.rotation_degrees = -70.0
						_:
							held_item_anchor.position = base_pos
							held_item_sprite.rotation_degrees = base_rot
				"down", _:
					match frame_idx:
						0:
							held_item_anchor.position = Vector2(4, -3)
							held_item_sprite.rotation_degrees = -60.0
						1:
							held_item_anchor.position = Vector2(5, -6)
							held_item_sprite.rotation_degrees = -90.0
						2:
							held_item_anchor.position = Vector2(8, -1)
							held_item_sprite.rotation_degrees = -15.0
						3:
							held_item_anchor.position = Vector2(6, 7)
							held_item_sprite.rotation_degrees = 55.0
						4:
							held_item_anchor.position = Vector2(3, 8)
							held_item_sprite.rotation_degrees = 75.0
						_:
							held_item_anchor.position = base_pos
							held_item_sprite.rotation_degrees = base_rot
		elif animated_sprite.animation == "swing_back":
			match frame_idx:
				0:
					held_item_anchor.position = Vector2(6, 3)
					held_item_sprite.rotation_degrees = 20.0
				1:
					held_item_anchor.position = Vector2(6, -2)
					held_item_sprite.rotation_degrees = 50.0
				2:
					held_item_anchor.position = Vector2(3, -7)
					held_item_sprite.rotation_degrees = 15.0
				3:
					held_item_anchor.position = Vector2(-2, -9)
					held_item_sprite.rotation_degrees = -50.0
				4:
					held_item_anchor.position = Vector2(-5, -6)
					held_item_sprite.rotation_degrees = -80.0
				_:
					held_item_anchor.position = base_pos
					held_item_sprite.rotation_degrees = base_rot
	elif current_state == State.WALKING:
		var bob := -1.5 if (frame_idx % 2 == 1) else 0.0
		held_item_anchor.position = base_pos + Vector2(0, bob)
		held_item_sprite.rotation_degrees = base_rot
	else:
		held_item_anchor.position = base_pos
		held_item_sprite.rotation_degrees = base_rot


func _execute_action_impact() -> void:
	if not current_held_item:
		return
	
	var tool_power: int = current_held_item.get("tool_power") if current_held_item.get("tool_power") != null else 1
	var damage: int = current_held_item.get("weapon_damage") if current_held_item.get("weapon_damage") != null else 10
	var is_axe: bool = (current_held_item.get("action_type") == ItemDataClass.ActionType.CHOP or current_held_item.get("item_id") == "wood_axe")
	var knockback: float = current_held_item.get("knockback_force") if current_held_item.get("knockback_force") != null else 40.0
	var s_scale: Vector2 = current_held_item.get("swoosh_scale") if current_held_item.get("swoosh_scale") != null else Vector2.ONE
	var s_color: Color = current_held_item.get("swoosh_color") if current_held_item.get("swoosh_color") != null else Color.WHITE
	var s_duration: float = 0.14
	if current_held_item.get("swing_speed_scale") != null:
		s_duration /= max(0.5, current_held_item.get("swing_speed_scale"))
	
	# 1. Trigger Air-Swoosh Effect
	if swoosh_effect and (animated_sprite.animation == "swing" or animated_sprite.animation == "swing_back"):
		swoosh_effect.play_swoosh(last_direction, s_scale, s_color, s_duration)
	
	# 2. Check for choppable trees in reach
	var hit_tree: TreeEntity = get_target_tree_in_reach()
	if hit_tree and not _hit_targets_this_swing.has(hit_tree):
		_hit_targets_this_swing.append(hit_tree)
		hit_tree.take_hit(tool_power, last_direction, is_axe)
		return
	
	# 3. Check for combat enemies and interactable targets in tool hitbox
	if tool_hitbox:
		var bodies = tool_hitbox.get_overlapping_bodies()
		for body in bodies:
			if body != self and is_instance_valid(body) and not _hit_targets_this_swing.has(body):
				_hit_targets_this_swing.append(body)
				if body.has_method("take_damage"):
					body.take_damage(damage, last_direction, knockback)
					return
				elif body.has_method("take_hit"):
					body.take_hit(tool_power, last_direction)
					return
		
		var areas = tool_hitbox.get_overlapping_areas()
		for area in areas:
			if area != tool_hitbox and is_instance_valid(area) and not _hit_targets_this_swing.has(area):
				_hit_targets_this_swing.append(area)
				if area.has_method("take_damage"):
					area.take_damage(damage, last_direction, knockback)
					return
				elif area.has_method("take_hit"):
					area.take_hit(tool_power, last_direction)
					return
	
	# 4. Check for hoe tilling / unhoeing action
	if current_action_type == ItemDataClass.ActionType.TILL or (current_held_item and current_held_item.get("action_type") == ItemDataClass.ActionType.TILL):
		var farm_mgr := _find_farming_manager()
		if farm_mgr:
			var target_pos: Vector2 = _current_farm_target_pos if _current_farm_target_pos != Vector2.ZERO else (global_position + (last_direction * interaction_distance))
			if _is_unhoeing:
				farm_mgr.unhoe_tile(target_pos)
			else:
				farm_mgr.hoe_tile(target_pos)
			_current_farm_target_pos = Vector2.ZERO
			_is_unhoeing = false
			return




func get_target_tree_in_reach() -> TreeEntity:
	if not get_tree():
		return null
	
	var trees := get_tree().get_nodes_in_group("choppable_trees")
	var reach_point := global_position + (last_direction * 14.0)
	var closest_tree: TreeEntity = null
	var min_dist := 16.0
	
	for tree_node in trees:
		if tree_node is TreeEntity and is_instance_valid(tree_node) and not tree_node.is_dead:
			var tree_pos: Vector2 = tree_node.global_position
			var dist_to_reach := reach_point.distance_to(tree_pos)
			var dist_to_ken := global_position.distance_to(tree_pos)
			var to_tree := (tree_pos - global_position).normalized()
			var is_facing := to_tree.dot(last_direction) > 0.4
			
			if (dist_to_reach <= min_dist or dist_to_ken <= 18.0) and is_facing:
				if dist_to_reach < min_dist:
					min_dist = dist_to_reach
					closest_tree = tree_node
	
	return closest_tree


func _update_tool_hitbox_position() -> void:
	if not tool_hitbox:
		return
	
	var reach_dist := 10.0
	if current_held_item and current_held_item.get("swing_range") != null:
		reach_dist = current_held_item.get("swing_range") * 0.5
	
	tool_hitbox.position = last_direction * reach_dist


# ==============================================================================
# WORLD ITEM & CHEST INTERACTION
# ==============================================================================

func trigger_interact() -> void:
	if is_ui_blocking() or _is_sleeping:
		return
	
	# 0. Check for nearby mature crop to harvest
	var farm_mgr := _find_farming_manager()
	var farm_reach := global_position + (last_direction * interaction_distance)
	if farm_mgr and (farm_mgr.can_harvest(farm_reach) or farm_mgr.can_harvest(global_position)):
		trigger_harvest()
		return
	
	# 1. Check for nearby Bed (Phase 7)
	var bed := _get_closest_bed()
	if bed and is_instance_valid(bed):
		bed.interact(self)
		return
	
	# 2. Check for nearby Chest
	var chest: ChestEntity = get_closest_chest()
	if chest and is_instance_valid(chest):
		chest.interact(self)
		return
	
	# 2. Check for ground world item
	var closest_item: Area2D = get_closest_world_item()
	if closest_item and is_instance_valid(closest_item):
		var inv: Control = get_inventory()
		if inv and inv.has_method("add_item"):
			var item_data: Resource = closest_item.get("item_data")
			var amount: int = closest_item.get("amount") if closest_item.get("amount") != null else 1
			var leftover: int = inv.add_item(item_data, amount)
			if leftover == 0:
				var picked_id: String = item_data.get("item_id") if item_data and item_data.get("item_id") != null else ""
				_notify_event_bus("item_collected", [picked_id])
				closest_item.queue_free()
			else:
				closest_item.set("amount", leftover)
			var item_name: String = item_data.get("display_name") if item_data and item_data.get("display_name") != null else "Item"
			print("Ken: Picked up ", item_name)
	else:
		print("Ken: No chest or item nearby")


func get_closest_chest() -> ChestEntity:
	if not get_tree():
		return null
	var chests := get_tree().get_nodes_in_group("chests")
	var closest: ChestEntity = null
	var min_dist := interaction_distance
	for node in chests:
		if node is ChestEntity and is_instance_valid(node):
			var dist := global_position.distance_to(node.global_position)
			if dist <= min_dist:
				min_dist = dist
				closest = node
	return closest


func _get_closest_bed() -> Node2D:
	if not get_tree():
		return null
	var beds := get_tree().get_nodes_in_group("beds")
	var closest: Node2D = null
	var min_dist := interaction_distance + 16.0
	for node in beds:
		if is_instance_valid(node) and node.has_method("can_interact"):
			if node.can_interact(self):
				var dist := global_position.distance_to(node.global_position)
				if dist <= min_dist:
					min_dist = dist
					closest = node
	return closest


## Called by Bed.gd when Ken goes to sleep
func enter_sleep_state() -> void:
	if _is_sleeping:
		return
	_pre_sleep_rotation = rotation
	_pre_sleep_sprite_offset = animated_sprite.offset
	_is_sleeping = true
	current_state = State.SLEEPING
	velocity = Vector2.ZERO
	is_acting = false
	# This top-down bed is vertical; keep the centered Ken visual upright.
	rotation = 0.0
	var col := get_node_or_null("CollisionShape2D")
	if col:
		_pre_sleep_collision_disabled = col.disabled
		col.disabled = true
	_update_held_item_visuals()
	# Display the face without changing last_direction (restored idle uses it).
	animated_sprite.flip_h = false
	animated_sprite.flip_v = false
	animated_sprite.animation = &"idle_front"
	animated_sprite.stop()
	animated_sprite.frame = 0
	# Front frame's opaque bounds are Rect2(8, 2, 16, 30) in a 32x32 cell.
	# Its visible center is one pixel below the origin; align it to SleepPosition.
	animated_sprite.offset = Vector2(0, -1)


## Called by Bed.gd when Ken wakes up
func exit_sleep_state() -> void:
	if not _is_sleeping:
		return
	_is_sleeping = false
	current_state = State.IDLE
	rotation = _pre_sleep_rotation
	animated_sprite.offset = _pre_sleep_sprite_offset
	velocity = Vector2.ZERO
	var col := get_node_or_null("CollisionShape2D")
	if col:
		col.disabled = _pre_sleep_collision_disabled
	_update_held_item_visuals()
	play_idle_animation()


func trigger_drop_item() -> void:
	var hotbar: Control = get_hotbar()
	var inv: Control = get_inventory()
	if not hotbar or not inv:
		return
	
	var active_slot: int = hotbar.get("selected_slot") if hotbar.get("selected_slot") != null else 0
	var slot_data: Dictionary = hotbar.call("get_slot_data", active_slot) if hotbar.has_method("get_slot_data") else (inv.call("get_hotbar_item_at", active_slot) if inv.has_method("get_hotbar_item_at") else inv.call("get_item_at", active_slot))
	var item_to_drop: Resource = slot_data.get("item", null)
	
	if item_to_drop:
		var removed_item: Resource = null
		if inv.has_method("remove_hotbar_item_at"):
			removed_item = inv.call("remove_hotbar_item_at", active_slot, 1)
		else:
			removed_item = inv.call("remove_item_at", active_slot, 1)
		if removed_item:
			var item_id: String = removed_item.get("item_id") if removed_item.get("item_id") != null else ""
			var target_pos := global_position + (last_direction * 22.0)
			
			# Validate placement against solid walls/obstacles
			var space_state := get_world_2d().direct_space_state
			var query := PhysicsPointQueryParameters2D.new()
			query.position = target_pos
			query.collision_mask = 1 # Solid world obstacles
			var hits := space_state.intersect_point(query)
			if not hits.is_empty():
				target_pos = global_position + (last_direction * 10.0)
			
			var spawn_parent: Node = get_parent() if get_parent() else self
			if item_id == "torch":
				var torch_scene = load("res://Scenes/Torch.tscn")
				var torch_node: Area2D = torch_scene.instantiate()
				spawn_parent.add_child(torch_node)
				torch_node.global_position = target_pos
			else:
				var world_item: Area2D = WorldItemScene.instantiate()
				spawn_parent.add_child(world_item)
				world_item.global_position = target_pos
				world_item.call("set_item", removed_item, 1)
			
			var item_name: String = removed_item.get("display_name") if removed_item.get("display_name") != null else "Item"
			print("Ken: Dropped 1 ", item_name)
	else:
		print("Ken: Selected hotbar slot is empty, nothing to drop")


## Places the currently equipped Torch into the world via Right-Click or place_torch action.
func trigger_place_held_torch() -> bool:
	if is_acting or is_ui_blocking():
		return false
	
	if not current_held_item or current_held_item.get("item_id") != "torch":
		return false
	
	var hotbar: Control = get_hotbar()
	var inv: Control = get_inventory()
	if not inv and not hotbar:
		return false
	
	var active_slot: int = 0
	if hotbar and hotbar.get("selected_slot") != null:
		active_slot = hotbar.get("selected_slot")
	var target_pos := global_position + (last_direction * placement_distance)
	
	# Validate placement against solid walls / obstacles
	var space_state := get_world_2d().direct_space_state
	
	# Exclude player's own physics body & child areas from blocking placement
	var exclude_rids: Array[RID] = [get_rid()]
	if tool_hitbox:
		exclude_rids.append(tool_hitbox.get_rid())
	
	# 1. Point check at target location
	var point_query := PhysicsPointQueryParameters2D.new()
	point_query.position = target_pos
	point_query.collision_mask = 1 # Solid world obstacles / walls
	point_query.exclude = exclude_rids
	point_query.collide_with_areas = false
	point_query.collide_with_bodies = true
	var point_hits := space_state.intersect_point(point_query)
	if not point_hits.is_empty():
		print("Ken: Cannot place torch here (location blocked).")
		return false
	
	# 2. Raycast check from player to target location to prevent placing through walls
	var ray_start := global_position + (last_direction * 8.0)
	var ray_query := PhysicsRayQueryParameters2D.create(ray_start, target_pos)
	ray_query.collision_mask = 1
	ray_query.exclude = exclude_rids
	ray_query.collide_with_areas = false
	ray_query.collide_with_bodies = true
	var ray_hits := space_state.intersect_ray(ray_query)
	if not ray_hits.is_empty():
		print("Ken: Cannot place torch through an obstacle.")
		return false
	
	# Remove 1 torch from hotbar / inventory
	var removed_item: Resource = null
	if inv and inv.has_method("remove_hotbar_item_at"):
		removed_item = inv.call("remove_hotbar_item_at", active_slot, 1)
	elif inv and inv.has_method("remove_item_at"):
		removed_item = inv.call("remove_item_at", active_slot, 1)
	
	if not removed_item:
		return false
	
	# Instantiate placed torch in world
	var torch_scene = load("res://Scenes/Torch.tscn")
	var torch_node: Area2D = torch_scene.instantiate()
	var spawn_parent: Node = get_parent() if get_parent() else self
	spawn_parent.add_child(torch_node)
	torch_node.global_position = target_pos
	
	print("Ken: Placed torch at ", target_pos)
	
	# Re-sync hotbar slot to check if torches remain
	var slot_data: Dictionary = {}
	if inv and inv.has_method("get_hotbar_item_at"):
		slot_data = inv.call("get_hotbar_item_at", active_slot)
	elif inv and inv.has_method("get_item_at"):
		slot_data = inv.call("get_item_at", active_slot)
	elif hotbar and hotbar.has_method("get_slot_data"):
		slot_data = hotbar.call("get_slot_data", active_slot)
	
	var remaining_item: Resource = slot_data.get("item", null) if slot_data != null else null
	var remaining_amount: int = slot_data.get("amount", 0) if slot_data != null else 0
	
	if remaining_amount <= 0 or remaining_item == null:
		current_held_item = null
	else:
		current_held_item = remaining_item
	
	_update_held_item_visuals()
	return true


# ==============================================================================
# HELD ITEM RENDERING & DIRECTIONAL ORIENTATION
# ==============================================================================

func _on_hotbar_slot_selected(_slot_index: int, item_data: Resource) -> void:
	current_held_item = item_data
	_update_held_item_visuals()


func _update_held_item_visuals() -> void:
	if not held_item_anchor:
		return
	if _is_sleeping:
		if held_item_sprite:
			held_item_sprite.visible = false
		if held_torch_flame:
			held_torch_flame.visible = false
		_update_torch_light_state()
		return
	
	var is_torch: bool = (current_held_item != null and current_held_item.get("item_id") == "torch")
	
	if is_torch:
		if held_item_sprite:
			held_item_sprite.visible = false
		if held_torch_flame:
			held_torch_flame.visible = true
			if not held_torch_flame.is_playing():
				held_torch_flame.play("flicker")
	elif current_held_item:
		if held_torch_flame:
			held_torch_flame.visible = false
		if held_item_sprite:
			var tex: Texture2D = current_held_item.get("held_texture")
			if not tex:
				tex = current_held_item.get("icon")
			held_item_sprite.texture = tex
			held_item_sprite.visible = (tex != null)
	else:
		if held_torch_flame:
			held_torch_flame.visible = false
		if held_item_sprite:
			held_item_sprite.texture = null
			held_item_sprite.visible = false
	
	_update_held_item_position()
	_update_torch_light_state()


func _update_held_item_position() -> void:
	if not held_item_anchor:
		return
	
	var dir_key := _get_direction_key()
	var cfg: Dictionary = HELD_OFFSETS[dir_key]
	
	held_item_anchor.position = cfg["pos"]
	held_item_anchor.z_index = cfg["z"]
	
	if held_item_sprite:
		held_item_sprite.flip_h = cfg["flip"]
		held_item_sprite.rotation_degrees = cfg["rot"]
	
	if held_torch_flame:
		held_torch_flame.flip_h = cfg["flip"]
		held_torch_flame.rotation_degrees = cfg["rot"]


func _update_torch_light_state() -> void:
	if not torch_light:
		return
	var is_torch: bool = (current_held_item != null and current_held_item.get("item_id") == "torch")
	if not is_torch or _is_sleeping:
		torch_light.enabled = false
		return
	
	# Always illuminate while holding a torch!
	torch_light.enabled = true
	torch_light.texture_scale = torch_light_scale
	torch_light.color = torch_light_color
	
	var is_night_time := true
	if not _game_clock:
		_game_clock = _find_game_clock()
	if _game_clock and _game_clock.has_method("is_night"):
		is_night_time = _game_clock.is_night()
	
	# Rich, warm source of light
	if is_night_time:
		_torch_base_energy = torch_night_energy
	else:
		_torch_base_energy = torch_day_energy


func _connect_game_clock() -> void:
	_game_clock = _find_game_clock()
	if _game_clock and _game_clock.has_signal("time_updated"):
		if not _game_clock.time_updated.is_connected(_on_clock_time_updated):
			_game_clock.time_updated.connect(_on_clock_time_updated)
	_update_torch_light_state()


func _find_game_clock() -> Node:
	var clocks := get_tree().get_nodes_in_group("game_clock")
	for c in clocks:
		if is_instance_valid(c):
			return c
	return null


func _on_clock_time_updated(_hour: int, _minute: int) -> void:
	_update_torch_light_state()


func _get_direction_key() -> String:
	if last_direction == Vector2.UP:
		return "up"
	elif last_direction == Vector2.LEFT:
		return "left"
	elif last_direction == Vector2.RIGHT:
		return "right"
	return "down"


func get_facing_direction(direction: Vector2) -> Vector2:
	if abs(direction.x) > abs(direction.y):
		return Vector2.RIGHT if direction.x > 0 else Vector2.LEFT
	else:
		return Vector2.DOWN if direction.y > 0 else Vector2.UP


# ==============================================================================
# ANIMATION CONTROLLER & UI BLOCKING
# ==============================================================================

func _on_animation_finished() -> void:
	# Eating uses its own tween-based cleanup (_finish_eating), skip here
	if _is_eating:
		return
	if is_acting:
		var completed_action := current_action_type
		is_acting = false
		_is_unhoeing = false
		current_state = State.IDLE
		impact_executed = false

		animated_sprite.flip_h = false
		animated_sprite.speed_scale = 1.0
		_last_action_end_time = Time.get_ticks_msec()
		
		if completed_action == ItemDataClass.ActionType.WATER:
			_notify_event_bus("crop_watered")
		
		# Clean up eating state (Phase 6)
		if completed_action == ItemDataClass.ActionType.EAT:
			_is_eating = false
			_eating_item_data = null
		
		# Restore held item visual in case it was hidden
		_update_held_item_visuals()
		
		if is_ui_blocking():
			play_idle_animation()
			return

		# Continuous hold-to-swing evaluation after cooldown
		if _is_action_key_held() and current_held_item != null:
			get_tree().create_timer(_current_item_cooldown).timeout.connect(func():
				if not is_acting and _is_action_key_held() and not is_ui_blocking():
					trigger_primary_action()
			)
			return

		var direction := Input.get_vector(
			"move_left",
			"move_right",
			"move_up",
			"move_down"
		)
		if direction != Vector2.ZERO:
			last_direction = get_facing_direction(direction)
			current_state = State.WALKING
			play_walk_animation()
		else:
			play_idle_animation()
		
		_update_held_item_position()


func play_walk_animation() -> void:
	animated_sprite.flip_h = false
	var animation_name := ""
	if last_direction == Vector2.DOWN:
		animation_name = "walk_front"
	elif last_direction == Vector2.UP:
		animation_name = "walk_back"
	elif last_direction == Vector2.LEFT:
		animation_name = "walk_left"
	elif last_direction == Vector2.RIGHT:
		animation_name = "walk_right"

	if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)


func play_idle_animation() -> void:
	animated_sprite.flip_h = false
	var animation_name := ""
	if last_direction == Vector2.DOWN:
		animation_name = "idle_front"
	elif last_direction == Vector2.UP:
		animation_name = "idle_back"
	elif last_direction == Vector2.LEFT:
		animation_name = "idle_left"
	elif last_direction == Vector2.RIGHT:
		animation_name = "idle_right"

	if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)


func get_inventory() -> Control:
	if not get_tree():
		return null
	var parent := get_parent()
	if parent:
		var inv = parent.find_child("Inventory", true, false)
		if inv and is_instance_valid(inv) and not inv.is_queued_for_deletion():
			return inv as Control
	
	if get_tree().root:
		var inv = get_tree().root.find_child("Inventory", true, false)
		if inv and is_instance_valid(inv) and not inv.is_queued_for_deletion():
			return inv as Control
	
	var nodes := get_tree().get_nodes_in_group("inventory_ui")
	for i in range(nodes.size() - 1, -1, -1):
		var node = nodes[i]
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			return node as Control
	return null


func get_hotbar() -> Control:
	if not get_tree():
		return null
	var parent := get_parent()
	if parent:
		var hb = parent.find_child("Hotbar", true, false)
		if hb and is_instance_valid(hb) and not hb.is_queued_for_deletion():
			return hb as Control
	
	if get_tree().root:
		var hb = get_tree().root.find_child("Hotbar", true, false)
		if hb and is_instance_valid(hb) and not hb.is_queued_for_deletion():
			return hb as Control
	
	var nodes := get_tree().get_nodes_in_group("hotbar_ui")
	for i in range(nodes.size() - 1, -1, -1):
		var node = nodes[i]
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			return node as Control
	return null


func _find_farming_manager() -> Node:
	if not get_tree():
		return null
	var parent := get_parent()
	if parent:
		var m = parent.find_child("FarmingManager", true, false)
		if m and is_instance_valid(m) and not m.is_queued_for_deletion():
			return m
	var mgrs := get_tree().get_nodes_in_group("farming_manager")
	for i in range(mgrs.size() - 1, -1, -1):
		var m = mgrs[i]
		if is_instance_valid(m) and not m.is_queued_for_deletion():
			return m
	return null


func get_closest_world_item() -> Area2D:
	if not get_tree():
		return null
	
	var items := get_tree().get_nodes_in_group("world_items")
	var closest: Area2D = null
	var min_dist := pickup_radius
	
	for item in items:
		if item is Area2D and is_instance_valid(item) and not item.is_queued_for_deletion():
			var dist := global_position.distance_to(item.global_position)
			if dist <= min_dist:
				min_dist = dist
				closest = item
	
	return closest


func is_ui_blocking() -> bool:
	if not get_tree():
		return false
	var inv_nodes := get_tree().get_nodes_in_group("inventory_ui")
	for inv in inv_nodes:
		if is_instance_valid(inv) and inv.get("is_open"):
			return true
	
	var menu_nodes := get_tree().get_nodes_in_group("menu_ui")
	for menu in menu_nodes:
		if is_instance_valid(menu) and menu.get("is_open"):
			return true
	
	var container_nodes := get_tree().get_nodes_in_group("container_ui")
	for container in container_nodes:
		if is_instance_valid(container) and container.get("is_open"):
			return true
	
	var map_nodes := get_tree().get_nodes_in_group("map_ui")
	for m in map_nodes:
		if is_instance_valid(m) and m.get("is_open"):
			return true
	
	var sleep_nodes := get_tree().get_nodes_in_group("sleep_ui")
	for s in sleep_nodes:
		if is_instance_valid(s) and s.get("is_open"):
			return true
	
	return false


# ==============================================================================
# HEALTH SYSTEM (Priority 1)
# ==============================================================================

func _find_player_stats() -> Node:
	var stats_nodes := get_tree().get_nodes_in_group("player_stats")
	for node in stats_nodes:
		if is_instance_valid(node):
			return node
	return null


## Called by zombies/enemies to damage the player.
## Signature: (amount, hit_direction, knockback) to match existing combat conventions.
func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO, knockback: float = 0.0) -> void:
	if _is_dead:
		return
	if not _player_stats:
		_player_stats = _find_player_stats()
	if not _player_stats:
		return
	
	var actual_damage: int = _player_stats.take_damage(amount)
	if actual_damage <= 0:
		return
	
	# Hit flash (red tint → restore)
	_play_hit_flash()
	
	# Knockback (applied next physics frame)
	if hit_direction != Vector2.ZERO and knockback > 0.0:
		_pending_knockback = hit_direction.normalized() * knockback
	
	# Check for death
	if _player_stats.is_dead:
		_on_player_died()


func _play_hit_flash() -> void:
	if not animated_sprite:
		return
	var tween := create_tween()
	animated_sprite.modulate = Color(1.5, 0.3, 0.3, 1.0)
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)


func _on_player_died() -> void:
	_is_dead = true
	is_acting = false
	velocity = Vector2.ZERO
	if animated_sprite:
		animated_sprite.modulate = Color(0.5, 0.3, 0.3, 1.0)
		animated_sprite.stop()


func _notify_event_bus(signal_name: String, args: Array = []) -> void:
	var bus_nodes := get_tree().get_nodes_in_group("event_bus")
	for bus in bus_nodes:
		if is_instance_valid(bus) and bus.has_signal(signal_name):
			match args.size():
				0:
					bus.emit_signal(signal_name)
				1:
					bus.emit_signal(signal_name, args[0])
				2:
					bus.emit_signal(signal_name, args[0], args[1])
			break
