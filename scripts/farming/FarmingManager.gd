extends Node2D
class_name FarmingManager

## Central Farming Controller for Night Harvest.
## Coordinates hoed soil, watering states, crop instances, and GameClock growth.
## Integrates multi-layer visuals:
## - TerrainLayer: Farmland dirt (FarmLand_Tile.png, Source 9)
## - ThingsLayer: Hoed furrow ridges (tile3.png, Source 4)
## - ThingsOverlayLayer: Planted crop entities and seeds

signal soil_hoed(grid_pos: Vector2i)
signal soil_unhoed(grid_pos: Vector2i)
signal seed_planted(grid_pos: Vector2i, crop_id: String)
signal soil_watered(grid_pos: Vector2i)
signal crop_harvested(grid_pos: Vector2i, crop_id: String, amount: int)
signal farming_xp_gained(amount: int, total_xp: int)


const CropEntityScene = preload("res://Scenes/farming/CropEntity.tscn")
const CropDataClass = preload("res://scripts/farming/CropData.gd")
const SoilStateClass = preload("res://scripts/farming/SoilState.gd")
const ItemDataClass = preload("res://scripts/item_data.gd")
const FARMLAND_TEXTURE_PATH := "res://Assets/Tiles/FarmLand_Tile.png"


const TILE3_TEXTURE_PATH := "res://Assets/Tiles/tile3.png"

@export var tile_size: float = 16.0
@export var default_growth_minutes: float = 30.0
## Character perk: Mira's crops grow faster (1.25 = 25% faster).
var growth_multiplier: float = 1.0


# --- Configurable Farming XP ---
@export var xp_hoe: int = 1
@export var xp_plant: int = 2
@export var xp_water: int = 1
@export var xp_harvest: int = 10

var total_farming_xp: int = 0

## Dictionary mapping Vector2i grid_pos -> Dictionary:
## { "state": SoilState.State, "crop": CropEntity }
var _farm_tiles: Dictionary = {}

# Multi-layer references from game scene
var _terrain_layer: TileMapLayer = null
var _things_layer: TileMapLayer = null
var _overlay_layer: TileMapLayer = null

var _terrain_source_id: int = -1
var _things_source_id: int = -1
var _overlay_source_id: int = -1

# Fallback layer for standalone/headless unit tests if no map exists
var _soil_layer: TileMapLayer = null
var _crops_container: Node2D = null
var _game_clock: Node = null
var _selector_cursor: FarmingCursor = null


func _ready() -> void:
	add_to_group("farming_manager")
	
	_bind_map_layers()
	_setup_crops_container()
	_setup_fallback_soil_layer()
	_setup_selector_cursor()
	call_deferred("_connect_game_clock")


func set_map_layers(terrain: TileMapLayer, things: TileMapLayer = null, overlay: TileMapLayer = null) -> void:
	_terrain_layer = terrain
	_things_layer = things
	_overlay_layer = overlay
	if _soil_layer and is_instance_valid(_soil_layer):
		_soil_layer.queue_free()
		_soil_layer = null
	_detect_source_ids()
	_setup_crops_container()
	_scan_existing_farm_tiles()



func _bind_map_layers() -> void:
	var parent_node := get_parent()
	if parent_node:
		_terrain_layer = parent_node.get_node_or_null("TileMap/TerrainLayer")
		if not _terrain_layer:
			_terrain_layer = parent_node.get_node_or_null("TerrainLayer")
	
	if not _terrain_layer and get_tree():
		var terrain_nodes := get_tree().get_nodes_in_group("terrain_layer")
		if not terrain_nodes.is_empty():
			_terrain_layer = terrain_nodes[0]
	
	if _terrain_layer:
		_things_layer = _terrain_layer.get_node_or_null("ThingsLayer")
		if _things_layer:
			_overlay_layer = _things_layer.get_node_or_null("ThingsOverlayLayer")
	
	_detect_source_ids()
	_scan_existing_farm_tiles()


func _detect_source_ids() -> void:
	if _terrain_layer and _terrain_layer.tile_set:
		_terrain_source_id = _find_source_id_by_texture_name(_terrain_layer.tile_set, "farmland_tile")
		if _terrain_source_id < 0 and _terrain_layer.tile_set.get_source_count() > 9:
			_terrain_source_id = 9
	
	if _things_layer and _things_layer.tile_set:
		_things_source_id = _find_source_id_by_texture_name(_things_layer.tile_set, "tile3")
		if _things_source_id < 0 and _things_layer.tile_set.get_source_count() > 4:
			_things_source_id = 4
	
	if _overlay_layer and _overlay_layer.tile_set:
		_overlay_source_id = _find_source_id_by_texture_name(_overlay_layer.tile_set, "outdoor_decor")
		if _overlay_source_id < 0 and _overlay_layer.tile_set.get_source_count() > 1:
			_overlay_source_id = 1


func _find_source_id_by_texture_name(ts: TileSet, name_substr: String) -> int:
	if not ts:
		return -1
	for i in range(ts.get_source_count()):
		var sid := ts.get_source_id(i)
		var src = ts.get_source(sid)
		if src is TileSetAtlasSource and src.texture:
			if name_substr.to_lower() in src.texture.resource_path.to_lower():
				return sid
	return -1


func _scan_existing_farm_tiles() -> void:
	if not _things_layer or _things_source_id < 0:
		return
	
	for cell in _things_layer.get_used_cells():
		var sid := _things_layer.get_cell_source_id(cell)
		if sid == _things_source_id:
			var coords := _things_layer.get_cell_atlas_coords(cell)
			if (coords.x == 10 or coords.x == 11) and (coords.y in [8, 9, 12, 13]):
				var is_watered: bool = (coords.y in [8, 9])
				if not _farm_tiles.has(cell):
					_farm_tiles[cell] = {
						"state": SoilStateClass.State.WATERED if is_watered else SoilStateClass.State.HOED,
						"crop": null
					}
	# v1.3.1: redraw pre-tilled map soil with the direction-free soil tiles
	if _ensure_soil_source() >= 0:
		for cell in _farm_tiles.keys():
			_update_soil_tile_single(cell)


func _setup_crops_container() -> void:
	if _crops_container and is_instance_valid(_crops_container):
		# Re-parent to overlay layer if not already parented there
		if _overlay_layer and is_instance_valid(_overlay_layer) and _crops_container.get_parent() != _overlay_layer:
			_crops_container.get_parent().remove_child(_crops_container)
			_overlay_layer.add_child(_crops_container)
		return
	
	_crops_container = Node2D.new()
	_crops_container.name = "CropsContainer"
	_crops_container.y_sort_enabled = true
	
	if _overlay_layer and is_instance_valid(_overlay_layer):
		_overlay_layer.add_child(_crops_container)
	else:
		add_child(_crops_container)


func _setup_fallback_soil_layer() -> void:
	# Fallback soil layer is STRICTLY for standalone unit tests when no real TerrainLayer exists.
	# If a real terrain layer exists, fallback layer must NEVER exist to prevent duplicate tiles.
	if _terrain_layer != null:
		if _soil_layer and is_instance_valid(_soil_layer):
			_soil_layer.queue_free()
			_soil_layer = null
		return
	
	if _soil_layer:
		return
	
	_soil_layer = get_node_or_null("FarmingSoilLayer")

	if not _soil_layer:
		_soil_layer = TileMapLayer.new()
		_soil_layer.name = "FarmingSoilLayer"
		
		var ts := TileSet.new()
		ts.tile_size = Vector2i(16, 16)
		
		var source := TileSetAtlasSource.new()
		var tex = load(FARMLAND_TEXTURE_PATH)
		if tex:
			source.texture = tex
			source.texture_region_size = Vector2i(16, 16)
			for y in range(3):
				for x in range(3):
					source.create_tile(Vector2i(x, y))
					var alt_id := source.create_alternative_tile(Vector2i(x, y))
					var tile_data := source.get_tile_data(Vector2i(x, y), alt_id)
					if tile_data:
						tile_data.modulate = Color(0.55, 0.48, 0.40, 1.0)
		
		ts.add_source(source, 0)
		_soil_layer.tile_set = ts
		add_child(_soil_layer)


func _connect_game_clock() -> void:
	var clocks := get_tree().get_nodes_in_group("game_clock")
	for c in clocks:
		if is_instance_valid(c):
			_game_clock = c
			break
	
	if _game_clock:
		if not _game_clock.time_updated.is_connected(_on_game_clock_time_updated):
			_game_clock.time_updated.connect(_on_game_clock_time_updated)
		if not _game_clock.day_changed.is_connected(_on_game_clock_day_changed):
			_game_clock.day_changed.connect(_on_game_clock_day_changed)


func _on_game_clock_time_updated(_hour: int, _minute: int) -> void:
	advance_growth_minutes(1.0)


func _on_game_clock_day_changed(_new_day: int) -> void:
	for grid_pos in _farm_tiles.keys():
		var cell: Dictionary = _farm_tiles[grid_pos]
		if cell.get("state") == SoilStateClass.State.WATERED:
			cell["state"] = SoilStateClass.State.HOED
			if cell.get("crop") and is_instance_valid(cell["crop"]):
				cell["crop"].set_watered(false)
			_update_soil_tile_visual(grid_pos)


## Advances growth on all planted crops by specified game minutes
func advance_growth_minutes(amount: float) -> void:
	for grid_pos in _farm_tiles.keys():
		var cell: Dictionary = _farm_tiles[grid_pos]
		var crop: Node2D = cell.get("crop", null)
		if crop and is_instance_valid(crop) and crop.has_method("advance_game_minute"):
			crop.advance_game_minute(amount * growth_multiplier)


# ==============================================================================
# COORDINATE CONVERSIONS
# ==============================================================================

func world_to_grid(world_pos: Vector2) -> Vector2i:
	if _terrain_layer:
		return _terrain_layer.local_to_map(_terrain_layer.to_local(world_pos))
	elif _things_layer:
		return _things_layer.local_to_map(_things_layer.to_local(world_pos))
	elif _soil_layer:
		return _soil_layer.local_to_map(_soil_layer.to_local(world_pos))
	return Vector2i(int(floor(world_pos.x / tile_size)), int(floor(world_pos.y / tile_size)))


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	if _terrain_layer:
		return _terrain_layer.to_global(_terrain_layer.map_to_local(grid_pos))
	elif _things_layer:
		return _things_layer.to_global(_things_layer.map_to_local(grid_pos))
	elif _soil_layer:
		return _soil_layer.to_global(_soil_layer.map_to_local(grid_pos))
	return Vector2(grid_pos.x * tile_size + (tile_size * 0.5), grid_pos.y * tile_size + (tile_size * 0.5))


## v1.3.1: tilled soil without a furrow direction. A generated 16x2 tile sheet:
## column = which neighbours are tilled too (N=1 E=2 S=4 W=8), row = pattern variant.
const SOIL_SHEET := "res://Assets/Generated/v131/soil.png"
var _soil_src_id: int = -1

func _ensure_soil_source() -> int:
	if _soil_src_id >= 0 or _things_layer == null or _things_layer.tile_set == null:
		return _soil_src_id
	var tex = load(SOIL_SHEET)
	if tex == null:
		return -1
	# The tileset resource is shared between sessions: reuse the soil source if it's already there
	var ts: TileSet = _things_layer.tile_set
	for i in ts.get_source_count():
		var sid := ts.get_source_id(i)
		var existing := ts.get_source(sid) as TileSetAtlasSource
		if existing and existing.texture == tex:
			_soil_src_id = sid
			return sid
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(16, 16)
	for y in 2:
		for x in 16:
			src.create_tile(Vector2i(x, y))
			# flat ground: always sorted behind crops, the player and everything else
			src.get_tile_data(Vector2i(x, y), 0).y_sort_origin = -2000
	_soil_src_id = _things_layer.tile_set.add_source(src)
	return _soil_src_id


func _soil_coords(grid_pos: Vector2i) -> Vector2i:
	var mask := 0
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for i in 4:
		var n: Vector2i = grid_pos + dirs[i]
		if _farm_tiles.has(n) and int(_farm_tiles[n].get("state", 0)) != SoilStateClass.State.UNTILLED:
			mask |= 1 << i
	return Vector2i(mask, (absi(grid_pos.x * 7 + grid_pos.y * 13)) % 2)


func _get_furrow_coords(grid_pos: Vector2i, is_watered: bool) -> Vector2i:
	var col_offset: int = abs(grid_pos.x) % 2
	var row_offset: int = abs(grid_pos.y) % 2
	var base_row: int = 8 if is_watered else 12
	return Vector2i(10 + col_offset, base_row + row_offset)


# ==============================================================================
# HOE / TILLING SYSTEM
# ==============================================================================

## Validates whether the given location can be hoed into plantable farmland
func can_hoe_tile(world_pos: Vector2) -> bool:
	var grid_pos := world_to_grid(world_pos)
	
	# Check if already hoed or watered in tracking dictionary
	if _farm_tiles.has(grid_pos):
		var state: int = _farm_tiles[grid_pos].get("state", SoilStateClass.State.UNTILLED)
		if state == SoilStateClass.State.HOED or state == SoilStateClass.State.WATERED:
			return false
	
	# If ThingsLayer already has a furrow here, it is already hoed
	if _things_layer and _things_source_id >= 0:
		var sid := _things_layer.get_cell_source_id(grid_pos)
		if sid == _things_source_id:
			var coords := _things_layer.get_cell_atlas_coords(grid_pos)
			if (coords.x == 10 or coords.x == 11) and (coords.y in [8, 9, 12, 13]):
				if not _farm_tiles.has(grid_pos):
					var is_watered: bool = (coords.y in [8, 9])
					_farm_tiles[grid_pos] = {
						"state": SoilStateClass.State.WATERED if is_watered else SoilStateClass.State.HOED,
						"crop": null
					}
				return false
	
	# Check physics obstacles (buildings, trees, fences)
	if not _is_tile_passable_and_clear(world_pos):
		return false
	
	# Check invalid terrain (cliffs, water)
	if _terrain_layer:
		var sid := _terrain_layer.get_cell_source_id(grid_pos)
		if sid in [15, 16]: # Water tiles
			return false
		if sid == 13:
			# v1.2: Cliff_Tile.png's plain-grass tiles are the map's ordinary grass,
			# so they can be farmed. Only the real cliff-edge pieces stay blocked.
			var coords := _terrain_layer.get_cell_atlas_coords(grid_pos)
			if not (coords in [Vector2i(1, 1), Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5)]):
				return false
	
	return true


## Converts normal ground into Hoed plantable soil with farmland dirt and furrows
func hoe_tile(world_pos: Vector2) -> bool:
	if not can_hoe_tile(world_pos):
		return false
	
	var grid_pos := world_to_grid(world_pos)
	var prev_sid := -1
	var prev_coords := Vector2i.ZERO
	var prev_alt := 0
	if _terrain_layer:
		prev_sid = _terrain_layer.get_cell_source_id(grid_pos)
		prev_coords = _terrain_layer.get_cell_atlas_coords(grid_pos)
		prev_alt = _terrain_layer.get_cell_alternative_tile(grid_pos)
	
	_farm_tiles[grid_pos] = {
		"state": SoilStateClass.State.HOED,
		"crop": null,
		"prev_terrain": {
			"sid": prev_sid,
			"coords": prev_coords,
			"alt": prev_alt
		}
	}
	
	_update_soil_tile_visual(grid_pos)
	_award_xp(xp_hoe)
	soil_hoed.emit(grid_pos)
	return true


## Validates whether target tile can be safely unhoed (reverted to normal ground).
## Strict rule: CANNOT UNHOE if any crop exists (seed, sprout, growing, or mature).
func can_unhoe_tile(world_pos: Vector2) -> bool:
	var grid_pos := world_to_grid(world_pos)
	if not _farm_tiles.has(grid_pos):
		return false
	
	var cell: Dictionary = _farm_tiles[grid_pos]
	
	# Crop protection: cannot unhoe if occupied by a crop at any stage
	var crop: Node2D = cell.get("crop", null)
	if crop != null and is_instance_valid(crop):
		return false
	
	var state: int = cell.get("state", SoilStateClass.State.UNTILLED)
	return (state == SoilStateClass.State.HOED or state == SoilStateClass.State.WATERED)


## Unhoes empty hoed soil and reverts terrain to normal ground
func unhoe_tile(world_pos: Vector2) -> bool:
	if not can_unhoe_tile(world_pos):
		return false
	
	var grid_pos := world_to_grid(world_pos)
	var cell: Dictionary = _farm_tiles[grid_pos]
	var prev: Dictionary = cell.get("prev_terrain", {})
	
	# 1. Clear furrow on ThingsLayer
	if _things_layer and (_things_source_id >= 0 or _soil_src_id >= 0):
		_things_layer.set_cell(grid_pos, -1)
	
	# 2. Revert TerrainLayer to previous or clear
	if _terrain_layer:
		if prev.has("sid") and prev["sid"] != -1 and prev["sid"] != _terrain_source_id:
			_terrain_layer.set_cell(grid_pos, prev["sid"], prev.get("coords", Vector2i.ZERO), prev.get("alt", 0))
		else:
			_terrain_layer.set_cell(grid_pos, -1)
	
	# 3. Clear fallback layer if active
	if _soil_layer:
		_soil_layer.set_cell(grid_pos, -1)
	
	_farm_tiles.erase(grid_pos)
	_update_soil_tile_visual(grid_pos)   # v1.3.1: re-join the neighbouring soil edges
	soil_unhoed.emit(grid_pos)
	return true


# ==============================================================================
# SEED / PLANTING SYSTEM
# ==============================================================================

## Validates if seed can be planted on target tile
func can_plant_seed(world_pos: Vector2, seed_id: String) -> bool:
	var grid_pos := world_to_grid(world_pos)
	if not _farm_tiles.has(grid_pos):
		# Also check if ThingsLayer has furrow
		if _things_layer and _things_source_id >= 0:
			var sid := _things_layer.get_cell_source_id(grid_pos)
			if sid == _things_source_id:
				var coords := _things_layer.get_cell_atlas_coords(grid_pos)
				if (coords.x == 10 or coords.x == 11) and (coords.y in [8, 9, 12, 13]):
					_farm_tiles[grid_pos] = {
						"state": SoilStateClass.State.HOED,
						"crop": null
					}
		if not _farm_tiles.has(grid_pos):
			return false
	
	var cell: Dictionary = _farm_tiles[grid_pos]
	var state: int = cell.get("state", SoilStateClass.State.UNTILLED)
	
	# Must be hoed or watered soil
	if state != SoilStateClass.State.HOED and state != SoilStateClass.State.WATERED:
		return false
	
	# Must not already be occupied by a crop
	if cell.get("crop") != null and is_instance_valid(cell.get("crop")):
		return false
	
	if seed_id.is_empty():
		return false
	
	return true


## Plants seed at target tile, creates CropEntity in ThingsOverlayLayer, and tracks growth
func plant_seed(world_pos: Vector2, seed_id: String) -> Node2D:
	if not can_plant_seed(world_pos, seed_id):
		return null
	
	var grid_pos := world_to_grid(world_pos)
	var cell: Dictionary = _farm_tiles[grid_pos]
	
	var crop_data: Resource = CropDataClass.get_crop_data_by_seed(seed_id)
	if not crop_data:
		crop_data = CropDataClass.create_carrot()
	
	var crop_node: Node2D = CropEntityScene.instantiate()
	if not _crops_container or not is_instance_valid(_crops_container):
		_setup_crops_container()
	_crops_container.add_child(crop_node)
	
	var tile_center := grid_to_world(grid_pos)
	crop_node.global_position = tile_center
	
	var current_time := {
		"day": _game_clock.current_day if _game_clock else 1,
		"hour": _game_clock.current_hour if _game_clock else 6,
		"minute": _game_clock.current_minute if _game_clock else 0
	}
	
	crop_node.setup(crop_data, grid_pos, false, current_time)
	cell["crop"] = crop_node
	
	crop_node.tree_exiting.connect(func():
		if _farm_tiles.has(grid_pos) and _farm_tiles[grid_pos].get("crop") == crop_node:
			_farm_tiles[grid_pos]["crop"] = null
	)
	
	_award_xp(xp_plant)
	if seed_id == "carrot_seed":
		_notify_event_bus("carrot_planted")
	_notify_event_bus("crop_planted", [seed_id])
	seed_planted.emit(grid_pos, crop_data.crop_id)
	
	return crop_node


# ==============================================================================
# WATERING SYSTEM
# ==============================================================================

## Validates if target tile can be watered.
## Phase 1.5 Rule: Empty hoed soil CANNOT be watered.
## Watering only applies if there is a living, non-mature crop that requires water.
func can_water(world_pos: Vector2) -> bool:
	var grid_pos := world_to_grid(world_pos)
	if not _farm_tiles.has(grid_pos):
		return false
	
	var cell: Dictionary = _farm_tiles[grid_pos]
	var crop: Node2D = cell.get("crop", null)
	if not crop or not is_instance_valid(crop):
		# No crop on soil -> cannot water empty hoed soil!
		return false
	
	if crop.has_method("can_be_watered"):
		return crop.can_be_watered()
	return not crop.get("watered") and not crop.get("mature")


## Waters the planted crop.
## Phase 1.5 Rule: Ground tile is NOT changed; soil remains clean HOED soil.
## Watering strictly affects the crop's internal state and triggers splash feedback.
func water_tile(world_pos: Vector2) -> bool:
	if not can_water(world_pos):
		return false
	
	var grid_pos := world_to_grid(world_pos)
	var cell: Dictionary = _farm_tiles[grid_pos]
	var crop: Node2D = cell.get("crop", null)
	
	if crop and is_instance_valid(crop) and crop.has_method("set_watered"):
		crop.set_watered(true)
	
	# Ground tile is NOT replaced or altered; soil remains HOED.
	_spawn_water_splash(grid_to_world(grid_pos))
	_award_xp(xp_water)
	_notify_event_bus("crop_watered")
	soil_watered.emit(grid_pos)
	
	return true


## Rain (v1.2): waters every planted crop that still needs water. No XP, no splash.
func water_all_from_rain() -> int:
	var n := 0
	for gp in _farm_tiles:
		var crop: Node2D = _farm_tiles[gp].get("crop", null)
		if crop and is_instance_valid(crop) and crop.has_method("set_watered"):
			var needs: bool = crop.can_be_watered() if crop.has_method("can_be_watered") else (not crop.get("watered") and not crop.get("mature"))
			if needs:
				crop.set_watered(true)
				soil_watered.emit(gp)
				n += 1
	return n


# ==============================================================================
# HARVESTING SYSTEM
# ==============================================================================

## Validates if target tile has a mature crop ready for harvest
func can_harvest(world_pos: Vector2) -> bool:
	var grid_pos := world_to_grid(world_pos)
	if not _farm_tiles.has(grid_pos):
		return false
	
	var crop: Node2D = _farm_tiles[grid_pos].get("crop", null)
	if crop and is_instance_valid(crop):
		if crop.has_method("can_harvest"):
			return crop.can_harvest()
		elif crop.has_method("is_mature"):
			return crop.is_mature()
	return false


## Harvests the mature crop, awards crop yield AND renewable replacement seeds to player inventory
func harvest_crop(world_pos: Vector2, target_inventory: Object = null) -> Dictionary:
	if not can_harvest(world_pos):
		return {}
	
	var grid_pos := world_to_grid(world_pos)
	var crop: Node2D = _farm_tiles[grid_pos].get("crop", null)
	if not crop or not is_instance_valid(crop):
		return {}
	
	var result: Dictionary = crop.harvest()
	var item_id: String = result.get("item_id", "carrot")
	var amount: int = result.get("amount", 1)
	var seed_id: String = result.get("seed_id", "carrot_seed")
	var seed_amount: int = result.get("seed_amount", 1)
	var xp_amt: int = result.get("xp", xp_harvest)
	
	if not target_inventory:
		target_inventory = _find_inventory()
	
	if target_inventory and target_inventory.has_method("add_item"):
		var db = load("res://scripts/item_database.gd")
		var crop_resource = db.get_item(item_id)
		if crop_resource:
			target_inventory.call("add_item", crop_resource, amount)
		var seed_resource = db.get_item(seed_id)
		if seed_resource:
			target_inventory.call("add_item", seed_resource, seed_amount)
	
	# Soil remains hoed for replanting
	if _farm_tiles.has(grid_pos):
		_farm_tiles[grid_pos]["crop"] = null
		_farm_tiles[grid_pos]["state"] = SoilStateClass.State.HOED
	
	_award_xp(xp_amt)
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		var wp := grid_to_world(grid_pos)
		juice.burst(wp, Color(0.45, 0.75, 0.3), 7, 55.0)
		var db2 = load("res://scripts/item_database.gd")
		var res = db2.get_item(item_id)
		var nm: String = str(res.display_name).to_upper() if res else item_id.to_upper()
		juice.popup_text(wp + Vector2(0, -14), "+%d %s" % [amount, nm], Color("C8F0A0"))
	_notify_event_bus("crop_harvested", [item_id])
	crop_harvested.emit(grid_pos, item_id, amount)
	
	return result



func get_crop_at(world_pos: Vector2) -> Node2D:
	var grid_pos := world_to_grid(world_pos)
	if _farm_tiles.has(grid_pos):
		var crop = _farm_tiles[grid_pos].get("crop", null)
		if crop and is_instance_valid(crop):
			return crop as Node2D
	return null


func get_soil_state(world_pos: Vector2) -> int:
	var grid_pos := world_to_grid(world_pos)
	if _farm_tiles.has(grid_pos):
		return _farm_tiles[grid_pos].get("state", SoilStateClass.State.UNTILLED)
	return SoilStateClass.State.UNTILLED


# ==============================================================================
# MULTI-LAYER SOIL VISUALIZATION
# ==============================================================================

func _update_soil_tile_visual(grid_pos: Vector2i) -> void:
	_update_soil_tile_single(grid_pos)
	if _soil_src_id >= 0:
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			if _farm_tiles.has(grid_pos + d):
				_update_soil_tile_single(grid_pos + d)


func _update_soil_tile_single(grid_pos: Vector2i) -> void:
	if not _farm_tiles.has(grid_pos):
		if _things_layer and _things_source_id >= 0:
			_things_layer.set_cell(grid_pos, -1)
		elif _soil_layer:
			_soil_layer.set_cell(grid_pos, -1)
		return
	
	var state: int = _farm_tiles[grid_pos].get("state", SoilStateClass.State.UNTILLED)
	
	match state:
		SoilStateClass.State.HOED:
			# 1. Base dirt on TerrainLayer (FarmLand_Tile.png, Source 9, coords (1, 1), alt 0)
			if _terrain_layer and _terrain_source_id >= 0:
				var cur_sid := _terrain_layer.get_cell_source_id(grid_pos)
				if cur_sid != _terrain_source_id:
					_terrain_layer.set_cell(grid_pos, _terrain_source_id, Vector2i(1, 1), 0)
			
			# 2. Hoed furrow on ThingsLayer (tile3.png, Source 4, dry rows 12-13)
			if _things_layer and _ensure_soil_source() >= 0:
				_things_layer.set_cell(grid_pos, _soil_src_id, _soil_coords(grid_pos), 0)
			elif _things_layer and _things_source_id >= 0:
				var coords := _get_furrow_coords(grid_pos, false)
				_things_layer.set_cell(grid_pos, _things_source_id, coords, 0)
			elif _soil_layer:
				_soil_layer.set_cell(grid_pos, 0, Vector2i(1, 1), 0)
				
		SoilStateClass.State.WATERED:
			# 1. Base dirt on TerrainLayer
			if _terrain_layer and _terrain_source_id >= 0:
				var cur_sid := _terrain_layer.get_cell_source_id(grid_pos)
				if cur_sid != _terrain_source_id:
					_terrain_layer.set_cell(grid_pos, _terrain_source_id, Vector2i(1, 1), 0)
			
			# 2. Moist furrow on ThingsLayer (tile3.png, Source 4, moist rows 8-9)
			if _things_layer and _ensure_soil_source() >= 0:
				_things_layer.set_cell(grid_pos, _soil_src_id, _soil_coords(grid_pos), 0)
			elif _things_layer and _things_source_id >= 0:
				var coords := _get_furrow_coords(grid_pos, true)
				_things_layer.set_cell(grid_pos, _things_source_id, coords, 0)
			elif _soil_layer:
				_soil_layer.set_cell(grid_pos, 0, Vector2i(1, 1), 1)
				
		SoilStateClass.State.UNTILLED, _:
			if _things_layer and (_things_source_id >= 0 or _soil_src_id >= 0):
				_things_layer.set_cell(grid_pos, -1)
			elif _soil_layer:
				_soil_layer.set_cell(grid_pos, -1)


# ==============================================================================
# HELPERS & REWARDS
# ==============================================================================

func _award_xp(amount: int) -> void:
	total_farming_xp += amount
	farming_xp_gained.emit(amount, total_farming_xp)
	
	var stats_nodes := get_tree().get_nodes_in_group("player_stats")
	for s in stats_nodes:
		if is_instance_valid(s) and s.has_method("add_xp"):
			s.add_xp(amount)
			break


func _is_tile_passable_and_clear(world_pos: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	if not space:
		return true
	
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collision_mask = 1 # Solid world obstacles / trees / chests / walls
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var hits := space.intersect_point(query)
	return hits.is_empty()


func _find_inventory() -> Control:
	var nodes := get_tree().get_nodes_in_group("inventory_ui")
	for n in nodes:
		if is_instance_valid(n):
			return n as Control
	return null


func _notify_event_bus(signal_name: String, args: Array = []) -> void:
	var bus_nodes := get_tree().get_nodes_in_group("event_bus")
	for bus in bus_nodes:
		if is_instance_valid(bus) and bus.has_signal(signal_name):
			match args.size():
				0: bus.emit_signal(signal_name)
				1: bus.emit_signal(signal_name, args[0])
				2: bus.emit_signal(signal_name, args[0], args[1])
			break


## Save/Load Serialization support for Phase 1
func get_save_data() -> Dictionary:
	var crops_data: Array = []
	var tiles_data: Array = []
	
	for grid_pos in _farm_tiles.keys():
		var cell: Dictionary = _farm_tiles[grid_pos]
		tiles_data.append({
			"x": grid_pos.x,
			"y": grid_pos.y,
			"state": cell.get("state", 0)
		})
		var crop: Node2D = cell.get("crop", null)
		if crop and is_instance_valid(crop) and crop.has_method("get_save_data"):
			crops_data.append(crop.get_save_data())
	
	return {
		"total_farming_xp": total_farming_xp,
		"farm_tiles": tiles_data,
		"crops": crops_data
	}


## Restores tilled soil and crops from get_save_data() output (used by SaveManager).
func load_save_data(data: Dictionary) -> void:
	total_farming_xp = int(data.get("total_farming_xp", total_farming_xp))

	# Remove crops that exist right now (fresh scene)
	for gp in _farm_tiles.keys():
		var old_crop = _farm_tiles[gp].get("crop", null)
		if old_crop and is_instance_valid(old_crop):
			old_crop.queue_free()
		_farm_tiles[gp]["crop"] = null

	var saved := {}
	for t in data.get("farm_tiles", []):
		saved[Vector2i(int(t.get("x", 0)), int(t.get("y", 0)))] = int(t.get("state", SoilStateClass.State.HOED))

	# Tiles tilled on the map but un-hoed by the player in the save
	for gp in _farm_tiles.keys():
		if not saved.has(gp):
			_farm_tiles.erase(gp)
			_update_soil_tile_visual(gp)

	for gp in saved:
		if _farm_tiles.has(gp):
			_farm_tiles[gp]["state"] = saved[gp]
		else:
			var prev := {}
			if _terrain_layer:
				prev = {
					"sid": _terrain_layer.get_cell_source_id(gp),
					"coords": _terrain_layer.get_cell_atlas_coords(gp),
					"alt": _terrain_layer.get_cell_alternative_tile(gp)
				}
			_farm_tiles[gp] = {"state": saved[gp], "crop": null, "prev_terrain": prev}
		_update_soil_tile_visual(gp)

	for cd in data.get("crops", []):
		var gp := Vector2i(int(cd.get("grid_x", 0)), int(cd.get("grid_y", 0)))
		if not _farm_tiles.has(gp):
			continue
		var crop_data: Resource = CropDataClass.get_crop_data(str(cd.get("crop_id", "")))
		if not crop_data:
			continue
		if not _crops_container or not is_instance_valid(_crops_container):
			_setup_crops_container()
		var crop_node: Node2D = CropEntityScene.instantiate()
		_crops_container.add_child(crop_node)
		crop_node.global_position = grid_to_world(gp)
		crop_node.setup(crop_data, gp, bool(cd.get("watered", false)), {
			"day": int(cd.get("planted_day", 1)),
			"hour": int(cd.get("planted_hour", 6)),
			"minute": int(cd.get("planted_minute", 0))
		})
		crop_node.growth_stage = clampi(int(cd.get("growth_stage", 0)), 0, crop_node.max_growth_stage)
		crop_node.growth_progress_minutes = float(cd.get("growth_progress_minutes", 0.0))
		crop_node.mature = bool(cd.get("mature", false))
		crop_node.current_health = int(cd.get("current_health", crop_node.max_health))
		if crop_node.health_bar:
			crop_node.health_bar.value = crop_node.current_health
		crop_node._update_visuals()
		_farm_tiles[gp]["crop"] = crop_node
		var cell_pos := gp
		crop_node.tree_exiting.connect(func():
			if _farm_tiles.has(cell_pos) and _farm_tiles[cell_pos].get("crop") == crop_node:
				_farm_tiles[cell_pos]["crop"] = null
		)


func _spawn_water_splash(pos: Vector2) -> void:
	if not is_inside_tree():
		return
	var splash := CPUParticles2D.new()
	splash.emitting = true
	splash.one_shot = true
	splash.explosiveness = 0.95
	splash.amount = 12
	splash.lifetime = 0.4
	splash.direction = Vector2(0, -1)
	splash.spread = 60.0
	splash.gravity = Vector2(0, 98.0)
	splash.initial_velocity_min = 25.0
	splash.initial_velocity_max = 50.0
	splash.scale_amount_min = 1.5
	splash.scale_amount_max = 3.0
	splash.color = Color(0.25, 0.65, 1.0, 0.9)
	splash.global_position = pos
	splash.z_index = 40
	add_child(splash)
	get_tree().create_timer(0.5).timeout.connect(splash.queue_free)


func _setup_selector_cursor() -> void:
	if _selector_cursor and is_instance_valid(_selector_cursor):
		return
	_selector_cursor = FarmingCursor.new()
	_selector_cursor.name = "FarmingCursor"
	_selector_cursor.z_index = 60
	add_child(_selector_cursor)


var _growth_time_accumulator: float = 0.0


func _process(delta: float) -> void:
	_update_selector_cursor()
	if _game_clock == null:
		_growth_time_accumulator += delta
		while _growth_time_accumulator >= 1.0:
			_growth_time_accumulator -= 1.0
			advance_growth_minutes(1.0)



func _update_selector_cursor() -> void:
	if not _selector_cursor or not is_instance_valid(_selector_cursor):
		return
	
	var player = _get_player()
	if not player:
		if _selector_cursor.is_active:
			_selector_cursor.is_active = false
			_selector_cursor.queue_redraw()
		return
	
	var held = player.get("current_held_item")
	var is_farming_tool := false
	var tool_type: int = -1
	var item_id: String = ""
	
	if held:
		var id_val = held.get("item_id")
		item_id = str(id_val) if id_val != null else ""
		var action_val = held.get("action_type")
		var action_type: int = int(action_val) if action_val != null else -1
		var type_val = held.get("item_type")
		var item_type: int = int(type_val) if type_val != null else -1
		
		if action_type == ItemDataClass.ActionType.TILL or item_id == "hoe":
			is_farming_tool = true
			tool_type = ItemDataClass.ActionType.TILL
		elif action_type == ItemDataClass.ActionType.WATER or item_id == "watering_can":
			is_farming_tool = true
			tool_type = ItemDataClass.ActionType.WATER
		elif item_type == ItemDataClass.ItemType.SEED or action_type == ItemDataClass.ActionType.PLANT:
			is_farming_tool = true
			tool_type = ItemDataClass.ActionType.PLANT

	
	if not is_farming_tool:
		if _selector_cursor.is_active:
			_selector_cursor.is_active = false
			_selector_cursor.queue_redraw()
		return
	
	var mpos := get_global_mouse_position()
	var gpos := world_to_grid(mpos)
	var snap_pos := grid_to_world(gpos)
	
	_selector_cursor.global_position = snap_pos
	_selector_cursor.is_active = true
	_selector_cursor.in_reach = player.global_position.distance_to(snap_pos) <= 64.0
	
	match tool_type:
		ItemDataClass.ActionType.TILL:
			var can_hoe = can_hoe_tile(snap_pos)
			var can_unhoe = can_unhoe_tile(snap_pos)
			_selector_cursor.is_valid = can_hoe or can_unhoe
			_selector_cursor.is_unhoe_mode = can_unhoe
		ItemDataClass.ActionType.WATER:
			_selector_cursor.is_valid = can_water(snap_pos)
			_selector_cursor.is_unhoe_mode = false
		ItemDataClass.ActionType.PLANT:
			_selector_cursor.is_valid = can_plant_seed(snap_pos, item_id)
			_selector_cursor.is_unhoe_mode = false
		_:
			_selector_cursor.is_valid = false
			_selector_cursor.is_unhoe_mode = false
			
	_selector_cursor.queue_redraw()


func _get_player() -> Node2D:
	if get_tree():
		var ken_nodes = get_tree().get_nodes_in_group("player")
		if not ken_nodes.is_empty() and is_instance_valid(ken_nodes[0]):
			return ken_nodes[0] as Node2D
		var root = get_tree().current_scene
		if root and is_instance_valid(root):
			var ken = root.find_child("*ken*", true, false)
			if ken is Node2D:
				return ken
	return null


class FarmingCursor extends Node2D:
	var is_active: bool = false
	var in_reach: bool = false
	var is_valid: bool = false
	var is_unhoe_mode: bool = false
	
	func _draw() -> void:
		if not is_active:
			return
		var col: Color
		if not in_reach:
			col = Color(1.0, 0.25, 0.25, 0.55) # Out of reach
		elif is_valid:
			if is_unhoe_mode:
				col = Color(0.2, 0.85, 1.0, 0.85) # Cyan when hovering empty soil to unhoe
			else:
				col = Color(0.2, 1.0, 0.4, 0.8) # Green when hovering untilled soil to till
		else:
			col = Color(1.0, 0.75, 0.2, 0.65) # Amber/yellow when invalid or protected crop
		
		# Draw clean 16x16 border box centered on tile
		draw_rect(Rect2(-8, -8, 16, 16), col, false, 1.5)
		# Draw subtle semi-transparent fill
		draw_rect(Rect2(-7, -7, 14, 14), Color(col.r, col.g, col.b, 0.12), true)
