extends Resource
class_name CropData

const DECOR_TEXTURE_PATH := "res://Assets/Outdoor decoration/Outdoor_Decor_Free.png"

@export var crop_id: String = "carrot"
@export var crop_name: String = "Carrot"
@export var seed_id: String = "carrot_seed"
@export var harvest_item_id: String = "carrot"

## Duration in GameClock minutes / seconds to reach 100% maturity (30.0 = 30s)
@export var growth_duration_game_minutes: float = 30.0


## If true, crops will only accumulate growth time while soil/crop is watered.
@export var requires_water: bool = true

@export var harvest_yield_min: int = 1
@export var harvest_yield_max: int = 1

## Renewable seed yield on harvest (guarantees farming loop continuity)
@export var seed_yield_min: int = 1
@export var seed_yield_max: int = 1

@export var xp_reward: int = 10

# Textures for stages 0 (Seed), 1 (Sprout), 2 (Growing), 3 (Mature)
@export var stage_textures: Array[Texture2D] = []

static var _decor_sheet: Texture2D = null
static var _registry: Dictionary = {}


static func get_atlas_texture(col: int, row: int, tile_w: int = 16, tile_h: int = 16) -> AtlasTexture:
	if not _decor_sheet:
		_decor_sheet = load(DECOR_TEXTURE_PATH)
	var atlas := AtlasTexture.new()
	atlas.atlas = _decor_sheet
	atlas.region = Rect2(col * tile_w, row * tile_h, tile_w, tile_h)
	return atlas


## Creates default Carrot crop data
static func create_carrot() -> CropData:
	var data = CropData.new()
	data.crop_id = "carrot"
	data.crop_name = "Carrot"
	data.seed_id = "carrot_seed"
	data.harvest_item_id = "carrot"
	data.growth_duration_game_minutes = 30.0
	data.requires_water = true
	data.xp_reward = 10
	data.harvest_yield_min = 1
	data.harvest_yield_max = 1
	data.seed_yield_min = 1
	data.seed_yield_max = 1
	
	data.stage_textures.clear()
	data.stage_textures.append(get_atlas_texture(3, 1)) # Stage 0: Seed
	data.stage_textures.append(get_atlas_texture(4, 1)) # Stage 1: Sprout
	data.stage_textures.append(get_atlas_texture(4, 2)) # Stage 2: Growing
	data.stage_textures.append(get_atlas_texture(4, 3)) # Stage 3: Mature
	return data


## Creates default Wheat crop data
static func create_wheat() -> CropData:
	var data = CropData.new()
	data.crop_id = "wheat"
	data.crop_name = "Wheat"
	data.seed_id = "wheat_seed"
	data.harvest_item_id = "wheat"
	data.growth_duration_game_minutes = 30.0
	data.requires_water = true
	data.xp_reward = 10
	data.harvest_yield_min = 1
	data.harvest_yield_max = 1
	data.seed_yield_min = 1
	data.seed_yield_max = 1
	
	data.stage_textures.clear()
	data.stage_textures.append(get_atlas_texture(3, 1)) # Stage 0: Seed
	data.stage_textures.append(get_atlas_texture(5, 1)) # Stage 1: Sprout
	data.stage_textures.append(get_atlas_texture(5, 2)) # Stage 2: Growing
	data.stage_textures.append(get_atlas_texture(5, 3)) # Stage 3: Mature
	return data


## Creates default Watermelon crop data
static func create_watermelon() -> CropData:
	var data = CropData.new()
	data.crop_id = "watermelon"
	data.crop_name = "Watermelon"
	data.seed_id = "watermelon_seed"
	data.harvest_item_id = "watermelon"
	data.growth_duration_game_minutes = 30.0
	data.requires_water = true
	data.xp_reward = 15
	data.harvest_yield_min = 1
	data.harvest_yield_max = 1
	data.seed_yield_min = 1
	data.seed_yield_max = 1
	
	data.stage_textures.clear()
	data.stage_textures.append(get_atlas_texture(3, 1)) # Stage 0: Seed
	data.stage_textures.append(get_atlas_texture(3, 1)) # Stage 1: Sprout
	data.stage_textures.append(get_atlas_texture(3, 2)) # Stage 2: Growing vine
	data.stage_textures.append(get_atlas_texture(6, 3)) # Stage 3: Mature watermelon
	return data


## Creates default Corn crop data
static func create_corn() -> CropData:
	var data = CropData.new()
	data.crop_id = "corn"
	data.crop_name = "Corn"
	data.seed_id = "corn_seed"
	data.harvest_item_id = "corn"
	data.growth_duration_game_minutes = 30.0
	data.requires_water = true
	data.xp_reward = 12
	data.harvest_yield_min = 1
	data.harvest_yield_max = 1
	data.seed_yield_min = 1
	data.seed_yield_max = 1
	
	data.stage_textures.clear()
	data.stage_textures.append(get_atlas_texture(3, 1)) # Stage 0: Seed
	data.stage_textures.append(get_atlas_texture(6, 1)) # Stage 1: Sprout
	data.stage_textures.append(get_atlas_texture(6, 2)) # Stage 2: Growing stalk
	data.stage_textures.append(get_atlas_texture(6, 2)) # Stage 3: Mature corn
	return data


## Creates default Potato crop data
static func create_potato() -> CropData:
	var data = CropData.new()
	data.crop_id = "potato"
	data.crop_name = "Potato"
	data.seed_id = "potato_seed"
	data.harvest_item_id = "potato"
	data.growth_duration_game_minutes = 30.0
	data.requires_water = true
	data.xp_reward = 10
	data.harvest_yield_min = 1
	data.harvest_yield_max = 1
	data.seed_yield_min = 1
	data.seed_yield_max = 1
	
	data.stage_textures.clear()
	data.stage_textures.append(get_atlas_texture(3, 1)) # Stage 0: Seed
	data.stage_textures.append(get_atlas_texture(4, 1)) # Stage 1: Sprout
	data.stage_textures.append(get_atlas_texture(4, 2)) # Stage 2: Growing leaves
	data.stage_textures.append(get_atlas_texture(2, 2)) # Stage 3: Mature potato mound
	return data


## Creates default Tomato crop data
static func create_tomato() -> CropData:
	var data = CropData.new()
	data.crop_id = "tomato"
	data.crop_name = "Tomato"
	data.seed_id = "tomato_seed"
	data.harvest_item_id = "tomato"
	data.growth_duration_game_minutes = 30.0
	data.requires_water = true
	data.xp_reward = 10
	data.harvest_yield_min = 1
	data.harvest_yield_max = 1
	data.seed_yield_min = 1
	data.seed_yield_max = 1
	
	data.stage_textures.clear()
	data.stage_textures.append(get_atlas_texture(3, 1)) # Stage 0: Seed
	data.stage_textures.append(get_atlas_texture(3, 1)) # Stage 1: Sprout
	data.stage_textures.append(get_atlas_texture(3, 2)) # Stage 2: Growing plant
	data.stage_textures.append(get_atlas_texture(3, 3)) # Stage 3: Mature red tomato
	return data



## Lookup crop data by crop_id or seed_id
static func get_crop_data(identifier: String) -> CropData:
	_init_registry_if_needed()
	var key := identifier.to_lower()
	if _registry.has(key):
		return _registry[key]
	return null


static func get_crop_data_by_seed(seed_item_id: String) -> CropData:
	return get_crop_data(seed_item_id)


static func _init_registry_if_needed() -> void:
	if not _registry.is_empty():
		return
	
	var carrot = create_carrot()
	_registry["carrot"] = carrot
	_registry["carrot_seed"] = carrot
	
	var wheat = create_wheat()
	_registry["wheat"] = wheat
	_registry["wheat_seed"] = wheat
	
	var watermelon = create_watermelon()
	_registry["watermelon"] = watermelon
	_registry["watermelon_seed"] = watermelon
	
	var corn = create_corn()
	_registry["corn"] = corn
	_registry["corn_seed"] = corn
	
	var potato = create_potato()
	_registry["potato"] = potato
	_registry["potato_seed"] = potato
	
	var tomato = create_tomato()
	_registry["tomato"] = tomato
	_registry["tomato_seed"] = tomato


func get_stage_texture(stage: int) -> Texture2D:
	if stage >= 0 and stage < stage_textures.size():
		return stage_textures[stage]
	if not stage_textures.is_empty():
		return stage_textures[clampi(stage, 0, stage_textures.size() - 1)]
	return null
