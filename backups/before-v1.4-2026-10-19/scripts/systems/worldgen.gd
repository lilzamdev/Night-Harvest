extends Node2D

## WorldGen (v1.3) — the endless world around Harvest Village.
##
## The hand-built village map stays at the centre of the world. Everything around
## it is generated from the save's seed, 16x16-tile chunks at a time, as the player
## walks: plains, forests, deserts, snowfields, rocky highlands, lakes and rivers,
## with trees, rocks and ore, berry bushes, mushrooms, cacti, cave entrances into the
## Hollow Mines, abandoned cabins and camps with loot.
##
## Generation is deterministic (seed + tile position), so only what the player
## changes is saved: objects removed, bushes picked, crates looted, bridges built.
## Far-away chunks are unloaded again so the world can be as big as you can walk.

const ForageScript = preload("res://scripts/systems/forage.gd")
const TallGrassScript = preload("res://scripts/systems/tall_grass.gd")
const BlockScript = preload("res://scripts/systems/block.gd")
const MineRockScript = preload("res://scripts/systems/mine_rock.gd")
const WorldItemScene = preload("res://Scenes/world_item.tscn")
const ItemDB = preload("res://scripts/item_database.gd")
const TREE_OAK := preload("res://Scenes/tree.tscn")
const TREE_ROUND := preload("res://Scenes/tree_round.tscn")
const TREE_BUSH := preload("res://Scenes/tree_bush.tscn")
const V13 := "res://Assets/Generated/v13/"

const T := 16
const CHUNK := 16
## Same grid as the village TerrainLayer, so generated tiles line up with it.
const ORIGIN := Vector2(28, 47)
## The hand-built village, in tiles (TerrainLayer coordinates).
const VILLAGE := Rect2i(-106, -44, 178, 95)
const VILLAGE_CENTER := Vector2i(-17, 3)
## World border (tiles from the village). Beyond it is open ocean.
const BORDER := 6000
const LOAD_R := 2
const UNLOAD_R := 3

enum G { GRASS, WATER, SAND, SNOW, ICE, STONE }
enum B { PLAINS, FOREST, DESERT, SNOW, ROCKY, OCEAN }
const BIOME_NAMES := ["PLAINS", "FOREST", "DESERT", "SNOWFIELDS", "HIGHLANDS", "OCEAN"]

var save_key := "worldgen"
var world_seed: int = 1
var spawn_tile := Vector2i(999999, 999999)
var respawn_pos := Vector2.INF
var village_found := false
var ready_world := false

var _game: Node2D
var _ground: TileMapLayer
var _decor: TileMapLayer
var _ts: TileSet
var _src := {}          # name -> source id
var _n_temp := FastNoiseLite.new()
var _n_moist := FastNoiseLite.new()
var _n_elev := FastNoiseLite.new()
var _n_river := FastNoiseLite.new()
var _n_warp := FastNoiseLite.new()
var _n_mount := FastNoiseLite.new()
var _chunks := {}       # Vector2i -> {"node": Node2D, "unloading": bool}
var _queue: Array[Vector2i] = []
var _pending: Array[Vector2i] = []
var _state := {}        # "cx,cy" -> {"r": [], "p": {}, "l": [], "w": []}
var _explored := {}     # "cx,cy" -> true
var _last_center := Vector2i(999999, 999999)
var _map_cache := {}    # Vector2i -> Image (16x16 map pixels)
var _village_img: Image
## Cave mouths you have come across: "cx,cy" -> [x, y] (shown on the map)
var caves := {}
var _living: Node


func _ready() -> void:
	add_to_group("worldgen")
	add_to_group("save_extension")
	y_sort_enabled = true
	_game = get_parent() as Node2D
	global_position = Vector2.ZERO
	_build_tileset()
	_ground = TileMapLayer.new()
	_ground.name = "GenGround"
	_ground.tile_set = _ts
	_ground.z_index = -2
	add_child(_ground)
	_ground.global_position = ORIGIN
	_decor = TileMapLayer.new()
	_decor.name = "GenDecor"
	_decor.tile_set = _ts
	_decor.z_index = -2
	add_child(_decor)
	_decor.global_position = ORIGIN
	_open_village_edges()
	_hook_living.call_deferred()
	if has_node("/root/SaveManager"):
		var sm := get_node("/root/SaveManager")
		var info: Dictionary = sm.active_info
		world_seed = int(info.get("world_seed", 0))
		if world_seed == 0:
			world_seed = int(hash(str(info.get("created_at", 1)) + str(info.get("farm_name", "farm")))) & 0x7FFFFFFF
		sm.session_started.connect(_on_session_started)
	_setup_noise()


func _hook_living() -> void:
	var lw := get_tree().get_first_node_in_group("living_world")
	if lw and lw.has_method("add_ground_layer"):
		lw.add_ground_layer(_ground)


# ==========================================================================
# Tiles
# ==========================================================================

func _atlas(tex_path: String, cols: int, rows: int, water: bool, skip: Array = []) -> int:
	var src := TileSetAtlasSource.new()
	src.texture = load(tex_path)
	src.texture_region_size = Vector2i(T, T)
	var id := _ts.add_source(src)
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			if c in skip:
				continue
			src.create_tile(c)
			if water:
				var td := src.get_tile_data(c, 0)
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
				# Alternative 1: the same tile with no collision (bridged over).
				src.create_alternative_tile(c, 1)
	return id


func _build_tileset() -> void:
	_ts = TileSet.new()
	_ts.tile_size = Vector2i(T, T)
	_ts.add_physics_layer()
	_ts.set_physics_layer_collision_layer(0, 1)
	_ts.set_physics_layer_collision_mask(0, 0)
	var blank := [Vector2i(2, 3), Vector2i(2, 4)]
	_src["grass"] = _atlas("res://Assets/Tiles/Cliff_Tile.png", 3, 6, false, blank)
	_src["water"] = _atlas("res://Assets/Tiles/Water_Tile.png", 3, 6, true, blank)
	_src["sand"] = _atlas("res://Assets/Tiles/Path_Tile.png", 3, 6, false, blank)
	_src["snow"] = _atlas(V13 + "snow_tile.png", 3, 6, false, blank)
	_src["ice"] = _atlas(V13 + "ice_tile.png", 3, 6, false, blank)
	_src["ground"] = _atlas("res://Assets/Pixel Lands Village Demo/ground_demo.png", 12, 3, false)
	_src["decor"] = _atlas("res://Assets/Outdoor decoration/Outdoor_Decor_Free.png", 7, 12, false)


## Autotile layouts: [source, outer 3x3 origin, inner 2x2 origin, centre variants]
func _layout(g: int) -> Array:
	match g:
		G.WATER:
			return [_src["water"], Vector2i(0, 0), Vector2i(0, 3), [Vector2i(1, 1), Vector2i(1, 1), Vector2i(1, 1), Vector2i(1, 1), Vector2i(1, 1), Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5)]]
		G.SAND:
			return [_src["sand"], Vector2i(0, 0), Vector2i(0, 3), [Vector2i(1, 1), Vector2i(1, 1), Vector2i(1, 1), Vector2i(1, 1), Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5)]]
		G.SNOW:
			return [_src["snow"], Vector2i(0, 0), Vector2i(0, 3), [Vector2i(1, 1), Vector2i(1, 1), Vector2i(1, 1), Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5)]]
		G.ICE:
			return [_src["ice"], Vector2i(0, 0), Vector2i(0, 3), [Vector2i(1, 1), Vector2i(1, 1), Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5)]]
		G.STONE:
			return [_src["ground"], Vector2i(7, 0), Vector2i(10, 0), [Vector2i(8, 1)]]
	return []


# ==========================================================================
# Noise & classification (pure functions of seed + tile)
# ==========================================================================

func _setup_noise() -> void:
	for n in [_n_temp, _n_moist, _n_elev, _n_river, _n_warp, _n_mount]:
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_temp.seed = world_seed
	_n_temp.frequency = 0.0013
	_n_temp.fractal_octaves = 2
	_n_moist.seed = world_seed + 101
	_n_moist.frequency = 0.0024
	_n_moist.fractal_octaves = 2
	_n_elev.seed = world_seed + 202
	_n_elev.frequency = 0.011
	_n_elev.fractal_octaves = 3
	_n_river.seed = world_seed + 303
	_n_river.frequency = 0.0042
	_n_river.fractal_octaves = 1
	_n_warp.seed = world_seed + 404
	_n_warp.frequency = 0.02
	_n_warp.fractal_octaves = 1
	_n_mount.seed = world_seed + 505
	_n_mount.frequency = 0.0045
	_n_mount.fractal_octaves = 2


func in_village(c: Vector2i) -> bool:
	return VILLAGE.has_point(c)


## Chebyshev distance (tiles) from the village rectangle; 0 inside it.
func village_dist(c: Vector2i) -> int:
	var dx := maxi(VILLAGE.position.x - c.x, c.x - (VILLAGE.end.x - 1))
	var dy := maxi(VILLAGE.position.y - c.y, c.y - (VILLAGE.end.y - 1))
	return maxi(0, maxi(dx, dy))


func biome_at(c: Vector2i) -> int:
	if absi(c.x) > BORDER or absi(c.y) > BORDER:
		return B.OCEAN
	var dv := village_dist(c)
	var m := _n_moist.get_noise_2d(c.x, c.y)
	if dv < 26:
		return B.FOREST if (dv > 12 and m > 0.22) else B.PLAINS
	var t := _n_temp.get_noise_2d(c.x, c.y)
	# Fade extreme biomes in gently around the village
	var fade := clampf(float(dv - 30) / 110.0, 0.0, 1.0)
	t *= fade
	if t > 0.26 and m < 0.05:
		return B.DESERT
	if t < -0.36:
		return B.SNOW
	var mt := _n_mount.get_noise_2d(c.x, c.y)
	if mt > 0.33 and fade > 0.5:
		return B.ROCKY
	if m > 0.1:
		return B.FOREST
	return B.PLAINS


## Raw ground type (before the thin-edge cleanup). -1 inside the village.
func raw_ground(c: Vector2i, biome: int = -1) -> int:
	if in_village(c):
		return -1
	if biome < 0:
		biome = biome_at(c)
	if biome == B.OCEAN:
		return G.WATER
	var dv := village_dist(c)
	var e := _n_elev.get_noise_2d(c.x, c.y)
	if dv >= 34:
		var lake := -0.42 if biome != B.DESERT else -0.6
		var water := e < lake
		if not water and biome != B.DESERT and biome != B.ROCKY:
			var wx := _n_warp.get_noise_2d(c.x, c.y) * 14.0
			var wy := _n_warp.get_noise_2d(c.y + 777, c.x - 333) * 14.0
			water = absf(_n_river.get_noise_2d(c.x + wx, c.y + wy)) < 0.038
		if water:
			return G.ICE if biome == B.SNOW else G.WATER
	match biome:
		B.DESERT:
			return G.SAND
		B.SNOW:
			return G.SNOW
		B.ROCKY:
			return G.STONE
	if dv >= 34 and e < -0.35:
		return G.SAND  # beach
	return G.GRASS


func _rand(x: int, y: int, salt: int) -> float:
	return float(hash(Vector4i(x, y, salt, world_seed)) & 0xFFFFFF) / 16777216.0


# ==========================================================================
# Chunk generation
# ==========================================================================

func chunk_of(world_pos: Vector2) -> Vector2i:
	var c := tile_of(world_pos)
	return Vector2i(floori(float(c.x) / CHUNK), floori(float(c.y) / CHUNK))


func tile_of(world_pos: Vector2) -> Vector2i:
	var p := (world_pos - ORIGIN) / float(T)
	return Vector2i(floori(p.x), floori(p.y))


func tile_center(c: Vector2i) -> Vector2:
	return ORIGIN + Vector2(c.x * T + T * 0.5, c.y * T + T * 0.5)


func _key(ck: Vector2i) -> String:
	return "%d,%d" % [ck.x, ck.y]


func _st(ck: Vector2i) -> Dictionary:
	var k := _key(ck)
	if not _state.has(k):
		_state[k] = {}
	return _state[k]


## Ground types for tiles [x0-1, x0+CHUNK] x [y0-1, y0+CHUNK] after the cleanup that
## removes 1-tile-thin strips (the autotile art needs regions at least 2 wide).
func _ground_grid(x0: int, y0: int, n: int, biomes: Dictionary = {}) -> Dictionary:
	var raw := {}
	for y in range(y0 - 3, y0 + n + 3):
		for x in range(x0 - 3, x0 + n + 3):
			var c0 := Vector2i(x, y)
			var b0 := biome_at(c0)
			biomes[c0] = b0
			raw[c0] = raw_ground(c0, b0)
	# 1. Fill one-tile notches (staircases on diagonal rivers and coasts), so every
	#    shape can be drawn with the 3x3 + inner-corner tiles.
	var filled := {}
	for y in range(y0 - 2, y0 + n + 2):
		for x in range(x0 - 2, x0 + n + 2):
			var c1 := Vector2i(x, y)
			var g1: int = raw[c1]
			if g1 == G.GRASS:
				for pair in [[Vector2i(0, -1), Vector2i(1, 0)], [Vector2i(1, 0), Vector2i(0, 1)], [Vector2i(0, 1), Vector2i(-1, 0)], [Vector2i(-1, 0), Vector2i(0, -1)]]:
					var a1: int = raw[c1 + pair[0]]
					if a1 > G.GRASS and a1 == raw[c1 + pair[1]] and raw[c1 + pair[0] + pair[1]] == a1:
						g1 = a1
						break
			filled[c1] = g1
	# 2. Drop strips that are only one tile thin.
	var out := {}
	for y in range(y0 - 1, y0 + n + 1):
		for x in range(x0 - 1, x0 + n + 1):
			var c := Vector2i(x, y)
			var g: int = filled[c]
			if g > G.GRASS:
				var ok := false
				for o in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
					var a: Vector2i = c + o
					if filled.get(a, -2) == g and filled.get(a + Vector2i(1, 0), -2) == g and filled.get(a + Vector2i(0, 1), -2) == g and filled.get(a + Vector2i(1, 1), -2) == g:
						ok = true
						break
				if not ok:
					g = _fallback(filled, c, g)
			out[c] = g
	return out


func _fallback(raw: Dictionary, c: Vector2i, g: int) -> int:
	var counts := {}
	for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var v: int = raw.get(c + o, G.GRASS)
		if v != g and v >= 0 and v != G.WATER and v != G.ICE:
			counts[v] = int(counts.get(v, 0)) + 1
	var best := G.GRASS
	var bn := 0
	for v in counts:
		if counts[v] > bn:
			bn = counts[v]
			best = v
	return best


func _pick_tile(grid: Dictionary, c: Vector2i, biome: int) -> Array:
	var g: int = grid[c]
	if g == G.GRASS:
		var r := _rand(c.x, c.y, 11)
		if r < 0.035 and biome == B.PLAINS:
			return [_src["ground"], Vector2i(5, 0) if r < 0.025 else Vector2i(6, 0)]
		if r < 0.12:
			return [_src["grass"], Vector2i(int(r * 100.0) % 3, 5)]
		return [_src["grass"], Vector2i(1, 1)]
	var lay := _layout(g)
	var same := func(o: Vector2i) -> bool:
		return grid.get(c + o, g) == g
	var n: bool = same.call(Vector2i(0, -1))
	var s: bool = same.call(Vector2i(0, 1))
	var w: bool = same.call(Vector2i(-1, 0))
	var e: bool = same.call(Vector2i(1, 0))
	var outer: Vector2i = lay[1]
	var inner: Vector2i = lay[2]
	var at := Vector2i(1, 1)
	if not n and not w:
		at = Vector2i(0, 0)
	elif not n and not e:
		at = Vector2i(2, 0)
	elif not s and not w:
		at = Vector2i(0, 2)
	elif not s and not e:
		at = Vector2i(2, 2)
	elif not n:
		at = Vector2i(1, 0)
	elif not s:
		at = Vector2i(1, 2)
	elif not w:
		at = Vector2i(0, 1)
	elif not e:
		at = Vector2i(2, 1)
	else:
		if not same.call(Vector2i(1, 1)):
			return [lay[0], inner + Vector2i(0, 0)]
		if not same.call(Vector2i(-1, 1)):
			return [lay[0], inner + Vector2i(1, 0)]
		if not same.call(Vector2i(1, -1)):
			return [lay[0], inner + Vector2i(0, 1)]
		if not same.call(Vector2i(-1, -1)):
			return [lay[0], inner + Vector2i(1, 1)]
		var vars: Array = lay[3]
		return [lay[0], vars[int(_rand(c.x, c.y, 12) * vars.size()) % vars.size()]]
	return [lay[0], outer + at]


## The ground type of one tile, exactly as it is drawn (used for placement, spawns).
func ground_at(c: Vector2i) -> int:
	if in_village(c):
		return -1
	if raw_ground(c) == G.GRASS and raw_ground(c + Vector2i(1, 0)) == G.GRASS and raw_ground(c + Vector2i(-1, 0)) == G.GRASS \
			and raw_ground(c + Vector2i(0, 1)) == G.GRASS and raw_ground(c + Vector2i(0, -1)) == G.GRASS:
		return G.GRASS
	return _ground_grid(c.x, c.y, 1)[c]


func is_water_tile(c: Vector2i) -> bool:
	if in_village(c):
		return false
	var k := _key(Vector2i(floori(float(c.x) / CHUNK), floori(float(c.y) / CHUNK)))
	if _state.has(k) and (_state[k].get("w", []) as Array).has([c.x, c.y]):
		return false
	return ground_at(c) == G.WATER


## Water under the ground, bridged or not.
func ground_is_water(c: Vector2i) -> bool:
	return not in_village(c) and ground_at(c) == G.WATER


func _gen_chunk(ck: Vector2i) -> void:
	var x0 := ck.x * CHUNK
	var y0 := ck.y * CHUNK
	var node := Node2D.new()
	node.name = "Chunk_%d_%d" % [ck.x, ck.y]
	node.y_sort_enabled = true
	add_child(node)
	var entry := {"node": node, "unloading": false}
	_chunks[ck] = entry
	_explored[_key(ck)] = true
	var st := _st(ck)
	var removed: Array = st.get("r", [])
	var bridges: Array = st.get("w", [])
	var biomes := {}
	var grid := _ground_grid(x0, y0, CHUNK, biomes)
	var reserved := {}
	var idx := 0
	# Chunk structures first (they reserve their footprint)
	var structs := _plan_structures(ck, grid)
	for s in structs:
		for y in range(s["rect"].position.y, s["rect"].end.y):
			for x in range(s["rect"].position.x, s["rect"].end.x):
				reserved[Vector2i(x, y)] = true
	for y in range(y0, y0 + CHUNK):
		for x in range(x0, x0 + CHUNK):
			var c := Vector2i(x, y)
			if in_village(c):
				continue
			var t := _pick_tile(grid, c, biomes[c])
			var alt := 0
			if grid[c] == G.WATER and bridges.has([x, y]):
				alt = 1
			_ground.set_cell(c, t[0], t[1], alt)
	for s in structs:
		idx = _build_structure(node, ck, s, idx, removed)
	var sign_c := spawn_tile + Vector2i(2, -1)
	if Rect2i(x0, y0, CHUNK, CHUNK).has_point(sign_c):
		var sign: Node2D = ForageScript.new()
		sign.kind = "sign"
		sign.sign_text = _sign_text()
		node.add_child(sign)
		sign.global_position = tile_center(sign_c) + Vector2(0, 6)
	# Objects are instanced over the next frames (see _process) to keep walking smooth.
	var jobs: Array = []
	for y in range(y0, y0 + CHUNK):
		for x in range(x0, x0 + CHUNK):
			var c := Vector2i(x, y)
			if in_village(c) or reserved.has(c):
				continue
			var g: int = grid[c]
			if g == G.WATER or g == G.ICE:
				continue
			var kind := object_kind(c, g, biomes[c])
			if kind == "" or kind == "decor":
				_maybe_decor(c, g, biomes[c])
				continue
			if not removed.has(idx):
				jobs.append([c, kind, idx])
			idx += 1
	entry["jobs"] = jobs
	_pending.append(ck)
	if not _map_cache.has(ck):
		_map_cache[ck] = _image_from_grid(ck, grid, biomes)


## Instances queued objects, nearest chunks first, within a small time budget.
func _run_jobs(budget_usec: int) -> void:
	var t0 := Time.get_ticks_usec()
	while not _pending.is_empty():
		var ck: Vector2i = _pending[0]
		var entry: Dictionary = _chunks.get(ck, {})
		if entry.is_empty():
			_pending.pop_front()
			continue
		var jobs: Array = entry.get("jobs", [])
		var st := _st(ck)
		while not jobs.is_empty():
			var j: Array = jobs.pop_front()
			_instance_object(entry["node"], ck, j[0], j[1], j[2], st)
			if budget_usec > 0 and Time.get_ticks_usec() - t0 > budget_usec:
				return
		_pending.pop_front()


func _unload_chunk(ck: Vector2i) -> void:
	var entry: Dictionary = _chunks.get(ck, {})
	if entry.is_empty():
		return
	entry["unloading"] = true
	var node: Node2D = entry["node"]
	if is_instance_valid(node):
		node.queue_free()
	var x0 := ck.x * CHUNK
	var y0 := ck.y * CHUNK
	for y in range(y0, y0 + CHUNK):
		for x in range(x0, x0 + CHUNK):
			_ground.erase_cell(Vector2i(x, y))
			_decor.erase_cell(Vector2i(x, y))
	_chunks.erase(ck)


func _track(obj: Node, ck: Vector2i, idx: int) -> void:
	obj.set_meta("wg_chunk", ck)
	obj.set_meta("wg_idx", idx)
	obj.tree_exiting.connect(_on_obj_exit.bind(obj, ck, idx))


func _on_obj_exit(obj: Node, ck: Vector2i, idx: int) -> void:
	var entry: Dictionary = _chunks.get(ck, {})
	var unloading: bool = entry.is_empty() or bool(entry.get("unloading", false))
	var broken := false
	if is_instance_valid(obj):
		if obj.get("is_dead") == true:
			broken = true
		elif obj.get("hp") != null and int(obj.get("hp")) <= 0:
			broken = true
		elif obj.has_meta("picked_up"):
			broken = true
	if unloading and not broken:
		return
	var st := _st(ck)
	var r: Array = st.get("r", [])
	if not r.has(idx):
		r.append(idx)
	st["r"] = r


# ==========================================================================
# Objects
# ==========================================================================

func _instance_object(parent: Node2D, ck: Vector2i, c: Vector2i, kind: String, idx: int, st: Dictionary) -> bool:
	if not is_instance_valid(parent):
		return false
	var pos := tile_center(c) + Vector2((_rand(c.x, c.y, 21) - 0.5) * 6.0, (_rand(c.x, c.y, 22) - 0.5) * 4.0 + 4.0)
	var obj: Node2D = null
	match kind:
		"oak":
			obj = TREE_OAK.instantiate()
		"round":
			obj = TREE_ROUND.instantiate()
		"bush_tree":
			obj = TREE_BUSH.instantiate()
		"pine", "pine_snow":
			obj = TREE_OAK.instantiate()
			obj.set_meta("sprite_swap", V13 + kind + ".png")
		"cactus":
			obj = TREE_OAK.instantiate()
			obj.set_meta("sprite_swap", V13 + "cactus.png")
			obj.set("wood_item_id", "cactus_fruit")
			obj.set("wood_drop_count", 1)
			obj.set("max_health", 2)
		"dead_bush":
			obj = TREE_OAK.instantiate()
			obj.set_meta("sprite_swap", V13 + "dead_bush.png")
			obj.set("wood_drop_count", 1)
			obj.set("max_health", 1)
		"rock_stone", "rock_copper", "rock_iron", "rock_gold":
			obj = MineRockScript.new()
			obj.rock_type = kind.substr(5)
			obj.variant = int(_rand(c.x, c.y, 23) * 3.0)
			obj.set_meta("surface", true)
		"berry_bush":
			obj = ForageScript.new()
			obj.kind = "berry_bush"
			var picked: Dictionary = st.get("p", {})
			obj.picked_day = int(picked.get(str(idx), -100))
			obj.on_picked = _on_bush_picked.bind(ck, idx)
		"tall_grass":
			var tg: Area2D = TallGrassScript.new()
			tg.variant = int(_rand(c.x, c.y, 9) * 3.0)
			tg.seed_roll = _rand(c.x, c.y, 8)
			parent.add_child(tg)
			tg.global_position = pos
			_track(tg, ck, idx)
			return true
		"mushroom":
			var w := WorldItemScene.instantiate()
			parent.add_child(w)
			w.global_position = pos
			w.call("set_item", ItemDB.get_item("wild_mushroom"), 1)
			w.set_meta("world_forage", true)
			_track(w, ck, idx)
			return true
	if obj == null:
		return false
	parent.add_child(obj)
	obj.global_position = pos
	if obj.has_meta("sprite_swap"):
		_swap_tree_sprite(obj, str(obj.get_meta("sprite_swap")), kind)
	_track(obj, ck, idx)
	if obj is TreeEntity:
		_sway(obj)
	return true


func _swap_tree_sprite(obj: Node2D, path: String, kind: String) -> void:
	var spr := obj.get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return
	var tex: Texture2D = load(path)
	spr.texture = tex
	spr.region_enabled = false
	spr.position = Vector2(0, -tex.get_height() * 0.5 + 2.0)
	obj.set("_initial_sprite_pos", spr.position)
	if kind == "dead_bush":
		var cs := obj.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if cs:
			cs.disabled = true


func _sway(obj: Node2D) -> void:
	if _living == null:
		_living = get_tree().get_first_node_in_group("living_world")
	if _living and _living.has_method("add_tree_sway"):
		_living.add_tree_sway(obj)


## What grows on this tile ("" = nothing). Pure function of seed + tile.
func object_kind(c: Vector2i, g: int = -99, biome: int = -1) -> String:
	if g == -99:
		g = ground_at(c)
	if g < 0 or g == G.WATER or g == G.ICE:
		return ""
	var dv := village_dist(c)
	if dv < 3:
		return ""
	if absi(c.x - spawn_tile.x) <= 2 and absi(c.y - spawn_tile.y) <= 2:
		return ""
	if biome < 0:
		biome = biome_at(c)
	var near := 0.5 if dv < 10 else 1.0
	var r := _rand(c.x, c.y, 1)
	var even := (c.x & 1) == 0 and (c.y & 1) == 0
	match biome:
		B.FOREST:
			if even and r < 0.42 * near:
				var k := _rand(c.x, c.y, 2)
				return "oak" if k < 0.42 else ("pine" if k < 0.72 else ("round" if k < 0.9 else "bush_tree"))
			if r > 0.993:
				return "berry_bush"
			if r > 0.985:
				return "mushroom"
			if r > 0.982:
				return "rock_stone"
		B.PLAINS:
			if even and r < 0.075 * near:
				var k2 := _rand(c.x, c.y, 2)
				return "oak" if k2 < 0.55 else ("round" if k2 < 0.8 else "bush_tree")
			if r > 0.995:
				return "berry_bush"
			if r > 0.991:
				return _rock(c, biome)
			if r > 0.9895:
				return "mushroom"
		B.SNOW:
			if even and r < 0.24:
				return "pine_snow"
			if r > 0.992:
				return _rock(c, biome)
		B.DESERT:
			if (c.x & 1) == 0 and (c.y & 1) == 1 and r < 0.05:
				return "cactus"
			if r > 0.99:
				return "dead_bush"
			if r > 0.982:
				return _rock(c, biome)
		B.ROCKY:
			if r > 0.95:
				return _rock(c, biome)
			if even and r < 0.03:
				return "pine"
	if (biome == B.PLAINS or biome == B.FOREST) and g == G.GRASS and _rand(c.x, c.y, 7) < (0.06 if biome == B.PLAINS else 0.045):
		return "tall_grass"
	return "decor"


func _rock(c: Vector2i, biome: int) -> String:
	var k := _rand(c.x, c.y, 3)
	var far := clampf(float(village_dist(c)) / 900.0, 0.0, 1.0)
	match biome:
		B.ROCKY:
			if k < 0.03 + 0.04 * far:
				return "rock_gold"
			if k < 0.15 + 0.06 * far:
				return "rock_iron"
			if k < 0.38:
				return "rock_copper"
		B.DESERT:
			if k < 0.04:
				return "rock_gold"
			if k < 0.28:
				return "rock_copper"
		B.SNOW:
			if k < 0.22:
				return "rock_iron"
		_:
			if k < 0.12:
				return "rock_copper"
	return "rock_stone"


func _maybe_decor(c: Vector2i, g: int, biome: int) -> void:
	if g != G.GRASS:
		return
	var r := _rand(c.x, c.y, 5)
	var p := 0.12 if biome == B.PLAINS else (0.08 if biome == B.FOREST else 0.0)
	if r >= p:
		return
	var k := _rand(c.x, c.y, 6)
	var at: Vector2i
	if biome == B.FOREST:
		at = Vector2i(int(k * 3.0), 0) if k < 0.6 else Vector2i(int(k * 10.0) % 3, 1)
	else:
		if k < 0.25:
			at = Vector2i(int(k * 7.0) % 3, 0)
		elif k < 0.7:
			at = Vector2i(int(k * 9.0) % 3, 1)
		else:
			at = Vector2i(int(k * 11.0) % 2, 8 + int(k * 17.0) % 4)
	_decor.set_cell(c, _src["decor"], at)


func _on_bush_picked(day: int, ck: Vector2i, idx: int) -> void:
	var st := _st(ck)
	var p: Dictionary = st.get("p", {})
	p[str(idx)] = day
	st["p"] = p


# ==========================================================================
# Structures: cave entrances, abandoned cabins, camps
# ==========================================================================

func _plan_structures(ck: Vector2i, grid: Dictionary) -> Array:
	var out: Array = []
	var cx := ck.x * CHUNK + 8
	var cy := ck.y * CHUNK + 8
	var center := Vector2i(cx, cy)
	var dv := village_dist(center)
	if dv < 40 or absi(cx) > BORDER - 20 or absi(cy) > BORDER - 20:
		return out
	if Rect2i(ck.x * CHUNK - 3, ck.y * CHUNK - 3, CHUNK + 6, CHUNK + 6).has_point(spawn_tile):
		return out
	var biome := biome_at(center)
	var r := _rand(ck.x, ck.y, 901)
	var cave_p := 0.32 if biome == B.ROCKY else 0.025
	if r < cave_p:
		var rect := Rect2i(cx - 1, cy - 1, 3, 3)
		if _area_dry(grid, rect, true):
			out.append({"type": "cave", "rect": rect})
			return out
	var r2 := _rand(ck.x, ck.y, 902)
	if biome != B.ROCKY and r2 < 0.035:
		var rect2 := Rect2i(ck.x * CHUNK + 4, ck.y * CHUNK + 4, 8, 7)
		if _area_dry(grid, rect2, false):
			out.append({"type": "cabin", "rect": rect2})
			return out
	if r2 > 0.975:
		var rect3 := Rect2i(cx - 2, cy - 2, 4, 4)
		if _area_dry(grid, rect3, false):
			out.append({"type": "camp", "rect": rect3})
	return out


func _area_dry(grid: Dictionary, rect: Rect2i, allow_stone: bool) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var g: int = grid.get(Vector2i(x, y), G.WATER)
			if g == G.WATER or g == G.ICE or g < 0:
				return false
			if g == G.STONE and not allow_stone:
				return false
	return true


func _build_structure(parent: Node2D, ck: Vector2i, s: Dictionary, idx: int, removed: Array) -> int:
	var rect: Rect2i = s["rect"]
	var looted: Array = _st(ck).get("l", [])
	match s["type"]:
		"cave":
			var c := Vector2i(rect.position.x + 1, rect.position.y + 2)
			var cave: Node2D = ForageScript.new()
			cave.kind = "cave"
			parent.add_child(cave)
			cave.global_position = tile_center(c) + Vector2(0, 6)
			caves[_key(ck)] = [c.x, c.y]
			return idx + 1
		"cabin":
			var biome := biome_at(rect.get_center())
			var mat := "wood"
			if biome == B.SNOW or _rand(ck.x, ck.y, 903) < 0.3:
				mat = "stone"
			elif _rand(ck.x, ck.y, 904) < 0.12:
				mat = "brick"
			var door_x := rect.position.x + 2 + int(_rand(ck.x, ck.y, 905) * 4.0)
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					var edge := x == rect.position.x or x == rect.end.x - 1 or y == rect.position.y or y == rect.end.y - 1
					var c2 := Vector2i(x, y)
					if not edge:
						if _rand(x, y, 906) < 0.8 and not removed.has(idx):
							_block(parent, ck, idx, "floor_" + mat, c2)
						idx += 1
						continue
					if y == rect.end.y - 1 and x == door_x:
						idx += 1
						continue
					# Ruins: some wall pieces have crumbled away
					if _rand(x, y, 907) < 0.18:
						idx += 1
						continue
					if not removed.has(idx):
						_block(parent, ck, idx, "wall_" + mat, c2)
					idx += 1
			var crate_c := Vector2i(rect.position.x + 1 + int(_rand(ck.x, ck.y, 908) * 5.0), rect.position.y + 1)
			_crate(parent, ck, idx, crate_c, looted)
			return idx + 1
		"camp":
			var center := rect.get_center()
			_crate(parent, ck, idx, center, looted)
			idx += 1
			for o in [Vector2i(-2, -1), Vector2i(1, 1)]:
				if not removed.has(idx):
					var log: Node2D = TREE_OAK.instantiate()
					parent.add_child(log)
					log.global_position = tile_center(center + o) + Vector2(0, 4)
					log.set("wood_drop_count", 2)
					log.set("max_health", 1)
					_swap_tree_sprite(log, V13 + "dead_bush.png", "dead_bush")
					_track(log, ck, idx)
				idx += 1
			return idx
	return idx


func _block(parent: Node2D, ck: Vector2i, idx: int, kind: String, c: Vector2i) -> void:
	var b: StaticBody2D = BlockScript.new()
	b.kind = kind
	b.natural = true
	parent.add_child(b)
	b.global_position = BlockScript.cell_base(c)
	_track(b, ck, idx)


func _crate(parent: Node2D, ck: Vector2i, idx: int, c: Vector2i, looted: Array) -> void:
	var crate: Node2D = ForageScript.new()
	crate.kind = "crate"
	crate.looted = looted.has(idx)
	crate.loot_tier = clampi(village_dist(c) / 350, 0, 2)
	crate.loot_seed = hash(Vector3i(c.x, c.y, world_seed))
	crate.on_looted = _on_crate_looted.bind(ck, idx)
	parent.add_child(crate)
	crate.global_position = tile_center(c) + Vector2(0, 4)


func _on_crate_looted(ck: Vector2i, idx: int) -> void:
	var st := _st(ck)
	var l: Array = st.get("l", [])
	if not l.has(idx):
		l.append(idx)
	st["l"] = l


# ==========================================================================
# Bridges (wooden floors over water)
# ==========================================================================

func set_bridge(c: Vector2i, on: bool) -> void:
	var ck := Vector2i(floori(float(c.x) / CHUNK), floori(float(c.y) / CHUNK))
	var st := _st(ck)
	var w: Array = st.get("w", [])
	var key := [c.x, c.y]
	if on and not w.has(key):
		w.append(key)
	elif not on:
		w.erase(key)
	st["w"] = w
	if _ground.get_cell_source_id(c) == _src["water"]:
		_ground.set_cell(c, _src["water"], _ground.get_cell_atlas_coords(c), 1 if on else 0)


# ==========================================================================
# Streaming
# ==========================================================================

func _process(_delta: float) -> void:
	if not ready_world:
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return
	var pos := p.global_position
	if absf(pos.x) > 150000.0 or absf(pos.y) > 150000.0:
		return  # inside a house or the mines
	var center := chunk_of(pos)
	if center != _last_center:
		_last_center = center
		_refresh_around(center)
	if not village_found and village_dist(tile_of(pos)) < 6:
		village_found = true
		_event("village_found", {})
		var hud := get_tree().get_first_node_in_group("hud_ui")
		if hud and hud.has_method("show_hud_message"):
			hud.show_hud_message("You found HARVEST VILLAGE!", 4.0)
	if not _queue.is_empty():
		var ck: Vector2i = _queue.pop_front()
		if not _chunks.has(ck) and _cheb(ck, _last_center) <= LOAD_R:
			_gen_chunk(ck)
	_run_jobs(3500)


func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _refresh_around(center: Vector2i) -> void:
	for ck in _chunks.keys():
		if _cheb(ck, center) > UNLOAD_R:
			_unload_chunk(ck)
	var want: Array[Vector2i] = []
	for dy in range(-LOAD_R, LOAD_R + 1):
		for dx in range(-LOAD_R, LOAD_R + 1):
			var ck := center + Vector2i(dx, dy)
			if not _chunks.has(ck) and not _queue.has(ck):
				want.append(ck)
	want.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _cheb(a, center) < _cheb(b, center))
	for ck in want:
		_queue.append(ck)


## Generates every chunk around pos right away (new game / respawn / teleport).
func load_around_now(pos: Vector2) -> void:
	var center := chunk_of(pos)
	_last_center = center
	for ck in _chunks.keys():
		if _cheb(ck, center) > UNLOAD_R:
			_unload_chunk(ck)
	for dy in range(-LOAD_R, LOAD_R + 1):
		for dx in range(-LOAD_R, LOAD_R + 1):
			var ck := center + Vector2i(dx, dy)
			if not _chunks.has(ck):
				_gen_chunk(ck)
	_queue.clear()
	_run_jobs(0)


# ==========================================================================
# Village edges
# ==========================================================================

## The old map had invisible walls on its outer edges and the camera stopped there.
## A ring of cliff-edge tiles also marked that edge; it becomes plain grass.
const OLD_EDGE := Rect2i(-91, -29, 148, 65)


func _open_village_edges() -> void:
	var terrain := _game.get_node_or_null("TileMap/TerrainLayer") as TileMapLayer
	if terrain:
		var grass_ok := [Vector2i(1, 1), Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5)]
		for y in range(OLD_EDGE.position.y, OLD_EDGE.end.y):
			for x in range(OLD_EDGE.position.x, OLD_EDGE.end.x):
				if x != OLD_EDGE.position.x and x != OLD_EDGE.end.x - 1 and y != OLD_EDGE.position.y and y != OLD_EDGE.end.y - 1:
					continue
				var c := Vector2i(x, y)
				if terrain.get_cell_source_id(c) == 13 and not terrain.get_cell_atlas_coords(c) in grass_ok:
					terrain.set_cell(c, 13, Vector2i(1, 1))
	var col := _game.get_node_or_null("TileMap/MapCollisions")
	if col:
		for n in ["Solid000", "Solid1019", "Solid1020", "Solid1021"]:
			var cs := col.get_node_or_null(n) as CollisionShape2D
			if cs:
				cs.disabled = true


func open_camera(p: Node2D) -> void:
	var cam: Camera2D = p.get_node_or_null("Camera2D")
	if cam:
		cam.limit_left = -10000000
		cam.limit_top = -10000000
		cam.limit_right = 10000000
		cam.limit_bottom = 10000000


# ==========================================================================
# Spawn & helpers for other systems
# ==========================================================================

func find_spawn() -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	for i in 600:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(130.0, 220.0)
		var c := VILLAGE_CENTER + Vector2i(roundi(cos(ang) * dist * 1.4), roundi(sin(ang) * dist))
		var dv := village_dist(c)
		if dv < 55 or dv > 140:
			continue
		var b := biome_at(c)
		if b != B.PLAINS and b != B.FOREST:
			continue
		var ok := true
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				if ground_at(c + Vector2i(dx, dy)) != G.GRASS:
					ok = false
					break
			if not ok:
				break
		if ok:
			return c
	return Vector2i(VILLAGE.end.x + 40, VILLAGE_CENTER.y)


## Text on the signpost next to where you start: which way the village is.
func _sign_text() -> String:
	var d := Vector2(VILLAGE_CENTER - spawn_tile)
	var ang := rad_to_deg(d.angle())
	var dirs := ["EAST", "SOUTH-EAST", "SOUTH", "SOUTH-WEST", "WEST", "NORTH-WEST", "NORTH", "NORTH-EAST"]
	var i := int(round(fposmod(ang, 360.0) / 45.0)) % 8
	return "HARVEST VILLAGE  ->  %s, about %d steps.\nThe shop, the smith and the quest board are there. Build your farm here first, before night falls!" % [dirs[i], int(d.length() / 10.0) * 10]


func spawn_world_pos() -> Vector2:
	return tile_center(spawn_tile) + Vector2(0, 4)


## Where the player comes back after dying: their bed if they placed one, else spawn.
func respawn_world_pos() -> Vector2:
	if respawn_pos != Vector2.INF:
		return respawn_pos
	return spawn_world_pos()


func player_in_wilds() -> bool:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return false
	if absf(p.global_position.x) > 150000.0 or absf(p.global_position.y) > 150000.0:
		return false
	return village_dist(tile_of(p.global_position)) > 8


func biome_name_at(world_pos: Vector2) -> String:
	var c := tile_of(world_pos)
	if in_village(c) or village_dist(c) < 6:
		return "HARVEST VILLAGE"
	return BIOME_NAMES[biome_at(c)]


## Open ground positions on a ring around `center` (night zombie spawns).
func zombie_spawn_positions(center: Vector2, n: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var space := get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.collision_mask = 1
	for i in n * 6:
		if out.size() >= n:
			break
		var ang := randf() * TAU
		var r := randf_range(250.0, 380.0)
		var pos := center + Vector2(cos(ang) * r * 1.3, sin(ang) * r * 0.85)
		var c := tile_of(pos)
		if not in_village(c) and ground_at(c) == G.WATER:
			continue
		q.position = pos
		if not space.intersect_point(q, 1).is_empty():
			continue
		out.append(pos)
	return out


## A 16x16 image of one chunk for the world map (1 pixel per tile).
func chunk_map_image(ck: Vector2i) -> Image:
	if _map_cache.has(ck):
		return _map_cache[ck]
	var biomes := {}
	var grid := _ground_grid(ck.x * CHUNK, ck.y * CHUNK, CHUNK, biomes)
	var img := _image_from_grid(ck, grid, biomes)
	_map_cache[ck] = img
	return img


func has_map_image(ck: Vector2i) -> bool:
	return _map_cache.has(ck)


func _image_from_grid(ck: Vector2i, grid: Dictionary, biomes: Dictionary) -> Image:
	var img := Image.create(CHUNK, CHUNK, false, Image.FORMAT_RGBA8)
	var x0 := ck.x * CHUNK
	var y0 := ck.y * CHUNK
	for y in CHUNK:
		for x in CHUNK:
			var c := Vector2i(x0 + x, y0 + y)
			if in_village(c):
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			img.set_pixel(x, y, _map_color(c, grid[c], biomes[c]))
	return img


func _map_color(c: Vector2i, g: int, b: int) -> Color:
	var col: Color
	match g:
		G.WATER:
			col = Color("2f6fb8") if b != B.OCEAN else Color("1f4f8f")
		G.ICE:
			col = Color("a9d8ef")
		G.SAND:
			col = Color("d9b07a")
		G.SNOW:
			col = Color("e8eef6")
		G.STONE:
			col = Color("8a8794")
		_:
			col = Color("4f9a4a") if b == B.PLAINS else Color("3d7f3e")
	var k := object_kind(c, g, b)
	if k in ["oak", "round", "pine", "bush_tree"]:
		col = col.darkened(0.32)
	elif k == "pine_snow":
		col = Color("4c7d5e")
	elif k.begins_with("rock"):
		col = Color("6e6a74")
	elif k == "cactus":
		col = Color("5a9a3a")
	return col


## The hand-built village drawn in map colours (from its tile layers).
func village_map_image() -> Image:
	if _village_img:
		return _village_img
	var img := Image.create(VILLAGE.size.x, VILLAGE.size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color("4f9a4a"))
	var terrain := _game.get_node_or_null("TileMap/TerrainLayer") as TileMapLayer
	var tall := _game.get_node_or_null("TallThingsLayer") as TileMapLayer
	if terrain:
		for c in terrain.get_used_cells():
			if not VILLAGE.has_point(c):
				continue
			var sid := terrain.get_cell_source_id(c)
			var at := terrain.get_cell_atlas_coords(c)
			var col := Color("4f9a4a")
			match sid:
				15, 16:
					col = Color("2f6fb8") if at == Vector2i(1, 1) or sid == 15 else Color("3f7fc0")
				14, 8:
					col = Color("d9b07a")
				9:
					col = Color("8a5a3d")
				20:
					col = Color("9a6a40") if at.x <= 4 else (Color("4f9a4a") if at.x <= 6 else Color("8a8794"))
				5, 0:
					col = Color("a0703e")
				13:
					col = Color("4f9a4a") if at in [Vector2i(1, 1), Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5)] else Color("3e7a3a")
			img.set_pixelv(c - VILLAGE.position, col)
	if tall:
		for c in tall.get_used_cells():
			if not VILLAGE.has_point(c):
				continue
			var sid2 := tall.get_cell_source_id(c)
			var col2 := Color("6e3a2a") if sid2 in [7, 9] else (Color("7a5232") if sid2 == 0 else Color("2f5f30"))
			img.set_pixelv(c - VILLAGE.position, col2)
	_village_img = img
	return img


func is_explored(ck: Vector2i) -> bool:
	return _explored.has(_key(ck))


func explored_keys() -> Array:
	return _explored.keys()


func _event(t: String, data: Dictionary) -> void:
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.emit(t, data)
			break


# ==========================================================================
# Session / save
# ==========================================================================

func _on_session_started(root: Node, is_new: bool) -> void:
	if root != _game:
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if spawn_tile.x == 999999:
		spawn_tile = find_spawn()
	if p:
		open_camera(p)
		var sm := get_node_or_null("/root/SaveManager")
		var respawn: bool = sm != null and sm.has_meta("respawn_pending")
		if sm:
			sm.remove_meta("respawn_pending")
		if (is_new and _starts_in_wilds()) or (respawn and _starts_in_wilds()):
			p.global_position = spawn_world_pos() if is_new else respawn_world_pos()
			var cam: Camera2D = p.get_node_or_null("Camera2D")
			if cam:
				cam.reset_smoothing()
		var pos := p.global_position
		if absf(pos.x) < 150000.0 and absf(pos.y) < 150000.0:
			load_around_now(pos)
	ready_world = true


## New farms start out in the wilds. (Old saves keep their place in the village.)
func _starts_in_wilds() -> bool:
	if has_node("/root/SaveManager"):
		return int(get_node("/root/SaveManager").active_info.get("world_version", 0)) >= 13
	return false


func get_save_data() -> Dictionary:
	# Drop empty chunk states to keep saves small
	var st := {}
	for k in _state:
		var d: Dictionary = _state[k]
		var keep := {}
		for f in ["r", "l", "w"]:
			if not (d.get(f, []) as Array).is_empty():
				keep[f] = d[f]
		if not (d.get("p", {}) as Dictionary).is_empty():
			keep["p"] = d["p"]
		if not keep.is_empty():
			st[k] = keep
	var rp: Array = [] if respawn_pos == Vector2.INF else [respawn_pos.x, respawn_pos.y]
	return {"seed": world_seed, "spawn": [spawn_tile.x, spawn_tile.y], "state": st,
		"explored": _explored.keys(), "village_found": village_found, "respawn": rp, "caves": caves}


func load_save_data(d: Dictionary) -> void:
	if d.has("seed") and int(d["seed"]) != 0 and int(d["seed"]) != world_seed:
		world_seed = int(d["seed"])
		_setup_noise()
	var sp: Array = d.get("spawn", [])
	if sp.size() == 2:
		spawn_tile = Vector2i(int(sp[0]), int(sp[1]))
	_state = {}
	var st: Dictionary = d.get("state", {})
	for k in st:
		var e: Dictionary = st[k]
		var fixed := {}
		for f in ["r", "l"]:
			var arr: Array = []
			for v in e.get(f, []):
				arr.append(int(v))
			if not arr.is_empty():
				fixed[f] = arr
		var w: Array = []
		for v in e.get("w", []):
			if v is Array and v.size() == 2:
				w.append([int(v[0]), int(v[1])])
		if not w.is_empty():
			fixed["w"] = w
		if e.has("p"):
			var pd := {}
			for pk in e["p"]:
				pd[str(pk)] = int(e["p"][pk])
			fixed["p"] = pd
		_state[str(k)] = fixed
	_explored = {}
	for k in d.get("explored", []):
		_explored[str(k)] = true
	village_found = bool(d.get("village_found", false))
	caves = {}
	var cv: Dictionary = d.get("caves", {})
	for k in cv:
		if cv[k] is Array and (cv[k] as Array).size() == 2:
			caves[str(k)] = [int(cv[k][0]), int(cv[k][1])]
	var rp: Array = d.get("respawn", [])
	respawn_pos = Vector2(float(rp[0]), float(rp[1])) if rp.size() == 2 else Vector2.INF
	# Chunks that were generated before the save was applied must be rebuilt.
	for ck in _chunks.keys():
		_unload_chunk(ck)
