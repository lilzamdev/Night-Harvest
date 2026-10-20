extends Node2D
class_name CropEntity

## Visual and logical instance of a planted crop in the game world.
## Supports multi-stage growth, stage-reset watering, and renewable seed yield.

signal stage_changed(new_stage: int)
signal crop_matured()
signal crop_harvested(crop_id: String)
signal crop_destroyed()

@export var crop_data: Resource
@export var max_health: int = 30
var current_health: int = 30
var is_dead: bool = false
var health_bar: ProgressBar

var crop_id: String = ""
var growth_stage: int = 0
var max_growth_stage: int = 3
var growth_progress_minutes: float = 0.0
var watered: bool = false
var mature: bool = false
var grid_pos: Vector2i = Vector2i.ZERO
var planted_day: int = 1
var planted_hour: int = 6
var planted_minute: int = 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var mature_indicator: Sprite2D = get_node_or_null("MatureIndicator")

var _bob_time: float = 0.0


func _ready() -> void:
	add_to_group("crops")
	current_health = max_health
	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.position = Vector2(-7, -13)
	health_bar.size = Vector2(14, 3)
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar.z_index = 5
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.12, 0.08, 0.06, 0.9)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.3, 0.85, 0.25)
	health_bar.add_theme_stylebox_override("background", background)
	health_bar.add_theme_stylebox_override("fill", fill)
	health_bar.max_value = max_health
	health_bar.value = current_health
	add_child(health_bar)
	if not sprite:
		sprite = get_node_or_null("Sprite2D")
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	
	if crop_data and not crop_data.stage_textures.is_empty():
		max_growth_stage = crop_data.stage_textures.size() - 1
	
	_update_visuals()


func _process(delta: float) -> void:
	if mature and sprite:
		# Gentle floating bounce when crop is mature and ready for harvest
		_bob_time += delta * 4.0
		sprite.position.y = sin(_bob_time) * 1.2
	elif sprite and sprite.position.y != 0.0:
		sprite.position.y = 0.0


func setup(p_data: Resource, p_grid_pos: Vector2i, p_watered: bool = false, current_time: Dictionary = {}) -> void:
	crop_data = p_data
	crop_id = p_data.crop_id
	grid_pos = p_grid_pos
	watered = p_watered
	growth_stage = 0
	growth_progress_minutes = 0.0
	mature = false
	
	if crop_data and not crop_data.stage_textures.is_empty():
		max_growth_stage = crop_data.stage_textures.size() - 1
	else:
		max_growth_stage = 3
	
	planted_day = current_time.get("day", 1)
	planted_hour = current_time.get("hour", 6)
	planted_minute = current_time.get("minute", 0)
	
	_update_visuals()


## Advances growth by game time minutes. Called by FarmingManager on GameClock ticks.
## Crops grow after being watered once, reaching maturity over 30 seconds.
func advance_game_minute(amount: float = 1.0) -> void:
	if is_dead or mature:
		return
	
	# Crops strictly require water for growth progress if requires_water is true
	if crop_data and crop_data.requires_water and not watered:
		return
	
	growth_progress_minutes += amount
	
	var duration: float = crop_data.growth_duration_game_minutes if crop_data else 30.0
	var stages_total: int = max(1, max_growth_stage)
	var time_per_stage: float = duration / float(stages_total)
	
	# Determine target stage based on accumulated watered growth minutes
	var calculated_stage: int = clampi(int(growth_progress_minutes / time_per_stage), 0, max_growth_stage)
	
	if calculated_stage > growth_stage:
		growth_stage = calculated_stage
		_update_visuals()
		stage_changed.emit(growth_stage)
		
		if growth_stage >= max_growth_stage:
			mature = true
			crop_matured.emit()



## Checks if the crop can be watered
func can_be_watered() -> bool:
	if is_dead or mature:
		return false
	if not (crop_data and crop_data.requires_water):
		return false
	return not watered


func set_watered(p_watered: bool) -> void:
	watered = p_watered
	_update_visuals()


func _update_visuals() -> void:
	if not sprite:
		return
	
	if crop_data:
		var tex = crop_data.get_stage_texture(growth_stage)
		if tex:
			sprite.texture = tex
	
	# Visual feedback:
	# Mature: gentle golden highlight
	# Watered: moist glistening light blue tint
	# Dry: standard white
	if mature:
		sprite.modulate = Color(1.08, 1.08, 0.95, 1.0)
	elif watered:
		sprite.modulate = Color(0.85, 0.95, 1.15, 1.0)
	else:
		sprite.modulate = Color.WHITE


func can_harvest() -> bool:
	return not is_dead and not is_queued_for_deletion() and (mature or growth_stage >= max_growth_stage)


## Destruction awards no harvest items or XP. FarmingManager's tree_exiting
## connection clears the tile's crop reference, preserving the tilled soil.
func take_damage(amount: int) -> void:
	if is_dead or is_queued_for_deletion() or amount <= 0:
		return
	current_health = maxi(0, current_health - amount)
	if health_bar:
		health_bar.value = current_health
	if current_health == 0:
		is_dead = true
		remove_from_group("crops")
		crop_destroyed.emit()
		for bus in get_tree().get_nodes_in_group("event_bus"):
			if bus.has_signal("gameplay_event"):
				bus.gameplay_event.emit("crop_destroyed", {"pos": global_position})
				break
		queue_free()


func is_mature() -> bool:
	return can_harvest()


## Harvests the mature crop. Returns crop yield + renewable seeds.
func harvest() -> Dictionary:
	if not can_harvest():
		return {}
	
	var harvest_item: String = crop_data.harvest_item_id if crop_data else "carrot"
	var yield_amt: int = randi_range(crop_data.harvest_yield_min, crop_data.harvest_yield_max) if crop_data else 1
	var seed_item: String = crop_data.seed_id if crop_data else "carrot_seed"
	var seed_yield_amt: int = randi_range(crop_data.seed_yield_min, crop_data.seed_yield_max) if crop_data else 1
	var xp_reward: int = crop_data.xp_reward if crop_data else 10
	
	crop_harvested.emit(harvest_item)
	queue_free()
	
	return {
		"item_id": harvest_item,
		"amount": yield_amt,
		"seed_id": seed_item,
		"seed_amount": seed_yield_amt,
		"xp": xp_reward
	}


## Serializable representation for future save/load integration
func get_save_data() -> Dictionary:
	return {
		"crop_id": crop_id,
		"current_health": current_health,
		"grid_x": grid_pos.x,
		"grid_y": grid_pos.y,
		"world_x": global_position.x,
		"world_y": global_position.y,
		"growth_stage": growth_stage,
		"growth_progress_minutes": growth_progress_minutes,
		"watered": watered,
		"mature": mature,
		"planted_day": planted_day,
		"planted_hour": planted_hour,
		"planted_minute": planted_minute
	}
