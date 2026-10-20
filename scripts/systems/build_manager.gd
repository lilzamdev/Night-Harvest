extends Node2D

## BuildManager (v1.3): place walls, floors, doors, fences, chests, beds and crafting
## stations on the 16 px build grid. Hold the block in your hotbar, aim with the mouse
## (or face a tile) and LEFT CLICK / SPACE; hold the button to build a whole row.
## Wooden floors placed on water make a bridge. Break things with an axe / pickaxe.

const BlockScript = preload("res://scripts/systems/block.gd")
const FurnitureScript = preload("res://scripts/systems/furniture.gd")
const DecorScript = preload("res://scripts/systems/decor.gd")
const PlantScript = preload("res://scripts/systems/planted_tree.gd")
const ItemDB = preload("res://scripts/item_database.gd")
const V13 := "res://Assets/Generated/v13/"
const V12 := "res://Assets/Generated/v12/"
const REACH := 76.0

var save_key := "builds"
var _ghost: Sprite2D
var _player: Node2D
var _solid := {}   # Vector2i -> block / furniture
var _floor := {}   # Vector2i -> floor block
var _flat := {}    # Vector2i -> flowers / rugs (things you can walk over)
var _wall := {}    # Vector2i -> picture / window hung on a wall block
var _ghost_tex := {}
var _last_place_ms := 0
var _last_msg_ms := 0


func _ready() -> void:
	add_to_group("build_manager")
	add_to_group("save_extension")
	y_sort_enabled = true
	global_position = Vector2.ZERO
	_ghost = Sprite2D.new()
	_ghost.centered = false
	_ghost.z_index = 30
	_ghost.visible = false
	add_child(_ghost)
	get_tree().node_added.connect(_on_node_added)


static func handles(id: String) -> bool:
	return BlockScript.KINDS.has(id) or FurnitureScript.KINDS.has(id) or DecorScript.KINDS.has(id) or PlantScript.SAPLINGS.has(id)


# --- Block registry (includes the ruins generated in the wild) ------------

func _on_node_added(n: Node) -> void:
	if n is StaticBody2D and (n.get_script() == BlockScript or n.get_script() == FurnitureScript or n.get_script() == DecorScript):
		_register.call_deferred(n)


func _register(n: Node2D) -> void:
	if not is_instance_valid(n) or not n.is_inside_tree():
		return
	if n.get_script() == BlockScript:
		var c: Vector2i = n.cell()
		if BlockScript.is_floor_kind(str(n.kind)):
			_floor[c] = n
		else:
			_solid[c] = n
		if not n.tree_exiting.is_connected(_unregister):
			n.tree_exiting.connect(_unregister.bind(n))
	else:
		for c in _cells_of(str(n.kind), n.anchor):
			_layer_for(str(n.kind))[c] = n
		if not n.tree_exiting.is_connected(_unregister):
			n.tree_exiting.connect(_unregister.bind(n))


## Which registry a placeable lives in.
func _layer_for(kind: String) -> Dictionary:
	if DecorScript.KINDS.has(kind):
		if DecorScript.is_wall_kind(kind):
			return _wall
		if DecorScript.is_flat_kind(kind):
			return _flat
	return _solid


func _unregister(n: Node) -> void:
	# a picture or window hung on a wall falls off when the wall is broken
	if n.get_script() == BlockScript and n.get("is_dead") == true:
		for c in _solid.keys():
			if _solid[c] == n and _wall.has(c) and is_instance_valid(_wall[c]) and not _wall[c].is_dead \
					and not _wall[c].is_queued_for_deletion():
				_wall[c].call_deferred("pick_up", true)
	for d in [_solid, _floor, _flat, _wall]:
		for c in d.keys():
			if d[c] == n:
				d.erase(c)


func _cells_of(kind: String, anchor: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if DecorScript.KINDS.has(kind):
		var dsz := DecorScript.size_of(kind)
		for dy in dsz.y:
			for dx in dsz.x:
				out.append(anchor + Vector2i(dx, -dy))
		return out
	if not FurnitureScript.KINDS.has(kind):
		out.append(anchor)
		return out
	var sz: Vector2i = FurnitureScript.KINDS[kind]["size"]
	for dy in sz.y:
		for dx in sz.x:
			out.append(anchor + Vector2i(dx, -dy))
	return out


func block_at(c: Vector2i) -> Node:
	var n = _solid.get(c)
	return n if is_instance_valid(n) else null


func floor_at(c: Vector2i) -> Node:
	var n = _floor.get(c)
	return n if is_instance_valid(n) else null


# --- Ghost preview --------------------------------------------------------

func _process(_delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if not _player:
			return
	var item: Resource = _player.get("current_held_item")
	var id := str(item.get("item_id")) if item else ""
	if item == null or not handles(id) or _player.is_ui_blocking():
		_ghost.visible = false
		return
	var c := target_cell(_player)
	var why := can_place(id, c)
	_ghost.texture = _ghost_texture(id)
	if DecorScript.KINDS.has(id):
		var dt: Texture2D = _ghost.texture
		var base_d := DecorScript.base_for(id, c)
		if DecorScript.is_wall_kind(id):
			_ghost.offset = Vector2(-dt.get_width() * 0.5, -21.0 - dt.get_height() * 0.5)
		else:
			_ghost.offset = Vector2(-dt.get_width() * 0.5, -dt.get_height() + 1.0)
		_ghost.global_position = base_d
	elif FurnitureScript.KINDS.has(id):
		var center := FurnitureScript.center_for(id, c)
		var t: Texture2D = _ghost.texture
		_ghost.offset = Vector2(-t.get_width() * 0.5, -t.get_height() * (0.5 if id in ["bed", "chest"] else 1.0))
		_ghost.global_position = center
	else:
		var base := BlockScript.cell_base(c)
		_ghost.offset = Vector2(-8, -float(_ghost.texture.get_height()))
		_ghost.global_position = base
	_ghost.modulate = Color(0.6, 1.0, 0.6, 0.6) if why == "" else Color(1.0, 0.4, 0.4, 0.55)
	_ghost.visible = true


func _ghost_texture(id: String) -> Texture2D:
	if _ghost_tex.has(id):
		return _ghost_tex[id]
	var t: Texture2D
	if DecorScript.KINDS.has(id):
		t = DecorScript.texture_of(id)
		_ghost_tex[id] = t
		return t
	if PlantScript.SAPLINGS.has(id):
		t = load("res://Assets/Generated/v131/%s.png" % id)
		_ghost_tex[id] = t
		return t
	match id:
		"door_wood":
			t = load(V13 + "door_wood.png")
		"chest":
			t = ItemDB.get_rpg_chest_texture(7, 0)
		"bed":
			t = load("res://Assets/Generated/v131/bed_1x2.png")
		"workbench":
			t = load(V12 + "workbench.png")
		"anvil":
			t = load("res://Assets/Generated/v131/anvil_1x1.png")
		"furnace":
			var a := AtlasTexture.new()
			a.atlas = load("res://Assets/Generated/v131/furnace_1x1.png")
			a.region = Rect2(0, 0, 16, 16)
			t = a
		_:
			t = load(BlockScript.tex_path(id))
	_ghost_tex[id] = t
	return t


func target_cell(player: Node2D) -> Vector2i:
	var m := player.get_global_mouse_position()
	var p: Vector2
	if m.distance_to(player.global_position) <= REACH:
		p = m
	else:
		var dir: Vector2 = player.get("last_direction")
		p = player.global_position + dir * 20.0 + Vector2(0, 2)
	return BlockScript.cell_of(p)


# --- Placement ------------------------------------------------------------

## "" when the spot is fine, otherwise the reason it isn't.
func can_place(id: String, c: Vector2i) -> String:
	var world := get_tree().get_first_node_in_group("nh_world")
	if world and world.is_player_indoors():
		return "You can't build inside village houses."
	var mines := get_tree().get_first_node_in_group("mines")
	if mines and mines.get("active"):
		return "The mines are too unstable to build in."
	var wg := get_tree().get_first_node_in_group("worldgen")
	if BlockScript.is_floor_kind(id):
		if floor_at(c):
			return "There is already a floor there."
		if _village_water(c):
			return "Can't build on that water."
		var on_water: bool = wg != null and wg.ground_is_water(c)
		if on_water and not id in ["floor_wood", "bridge_wood"]:
			return "Only wooden floors and bridges float."
		if id == "bridge_wood" and not on_water:
			return "Bridges go over water."
		var fm := get_tree().get_first_node_in_group("farming_manager")
		if fm and fm.has_method("get_crop_at") and fm.get_crop_at(BlockScript.cell_base(c) + Vector2(0, -8)) != null:
			return "Don't build on your crops."
		if not on_water and _blocked_by_world(c, true):
			return "That spot is blocked."
		return ""
	if DecorScript.KINDS.has(id):
		return _can_place_decor(id, c)
	if PlantScript.SAPLINGS.has(id):
		if block_at(c) or floor_at(c):
			return "Something is already there."
		if _village_water(c) or (wg and wg.ground_is_water(c)):
			return "Saplings don't grow in water."
		if wg and wg.has_method("ground_name_at") and wg.ground_name_at(c) in ["sand", "ice"]:
			return "Plant it on grass, dirt or snow."
		var fm2 := get_tree().get_first_node_in_group("farming_manager")
		if fm2 and fm2.has_method("get_soil_state") and int(fm2.get_soil_state(BlockScript.cell_base(c) + Vector2(0, -8))) != 0:
			return "Not on your farm soil."
		if _blocked_by_world(c, false):
			return "Too close to something else."
		return ""
	var cells := _cells_of(id, c)
	for cc in cells:
		if block_at(cc):
			return "Something is already built there."
		if _village_water(cc) or (wg and wg.ground_is_water(cc) and not floor_at(cc)):
			return "Can't build on water."
		if _blocked_by_world(cc, false):
			return "That spot is blocked."
	if _player:
		for cc in cells:
			var r := Rect2(BlockScript.cell_base(cc) + Vector2(-8, -16), Vector2(16, 16))
			if r.grow(-1).has_point(_player.global_position + Vector2(0, 4)):
				return "Step aside first."
	return ""


func _can_place_decor(id: String, c: Vector2i) -> String:
	var wg := get_tree().get_first_node_in_group("worldgen")
	var cells := _cells_of(id, c)
	if DecorScript.is_wall_kind(id):
		var b := block_at(c)
		if b == null or b.get_script() != BlockScript or bool(BlockScript.KINDS.get(str(b.kind), {}).get("fence", false)) \
				or bool(BlockScript.KINDS.get(str(b.kind), {}).get("door", false)):
			return "Hang it on a wall you built."
		if _wall.has(c) and is_instance_valid(_wall[c]):
			return "Something already hangs there."
		return ""
	var flat := DecorScript.is_flat_kind(id)
	for cc in cells:
		if flat:
			if _flat.has(cc) and is_instance_valid(_flat[cc]):
				return "Something is already there."
			if block_at(cc) and not DecorScript.info(id).get("flat", false):
				return "Something is already built there."
		elif block_at(cc):
			return "Something is already built there."
		if _village_water(cc) or (wg and wg.ground_is_water(cc) and not floor_at(cc)):
			return "Can't put that on water."
		if not flat and _blocked_by_world(cc, false):
			return "That spot is blocked."
	if not flat and _player:
		for cc in cells:
			var r := Rect2(BlockScript.cell_base(cc) + Vector2(-8, -16), Vector2(16, 16))
			if r.grow(-1).has_point(_player.global_position + Vector2(0, 4)):
				return "Step aside first."
	return ""


func _village_water(c: Vector2i) -> bool:
	var terrain := get_tree().current_scene.get_node_or_null("TileMap/TerrainLayer") as TileMapLayer
	if terrain == null:
		return false
	return terrain.get_cell_source_id(c) in [15, 16]


## Trees, rocks, buildings, other players' things... anything solid on layer 1.
func _blocked_by_world(c: Vector2i, floor_check: bool) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(12, 12) if not floor_check else Vector2(8, 8)
	q.shape = rs
	q.transform = Transform2D(0.0, BlockScript.cell_base(c) + Vector2(0, -8))
	q.collision_mask = 1
	q.collide_with_areas = false
	var ex: Array[RID] = []
	if _player:
		ex.append((_player as CollisionObject2D).get_rid())
	q.exclude = ex
	for hit in get_world_2d().direct_space_state.intersect_shape(q, 8):
		var col = hit.get("collider")
		if col is TileMapLayer:
			# Generated water is handled separately (bridges); floors may cover it.
			if floor_check:
				continue
			return true
		if floor_check and (col is CharacterBody2D):
			continue
		if floor_check and col.get_script() == BlockScript:
			continue
		return true
	return false


func try_place_from_player(player: Node2D, item: Resource) -> bool:
	_player = player
	# Holding the button builds a row; don't stack attempts every frame.
	var now := Time.get_ticks_msec()
	if now - _last_place_ms < 110:
		return false
	_last_place_ms = now
	var id := str(item.get("item_id"))
	var c := target_cell(player)
	var why := can_place(id, c)
	if why != "":
		_msg(why)
		return false
	var hotbar := get_tree().get_first_node_in_group("hotbar_ui")
	var inv := get_tree().get_first_node_in_group("inventory_ui")
	if not hotbar or not inv:
		return false
	var slot: int = hotbar.get("selected_slot")
	if not _creative():
		var removed = inv.remove_hotbar_item_at(slot, 1)
		if removed == null:
			return false
	var node := spawn(id, c)
	if player.has_method("_on_hotbar_slot_selected"):
		player._on_hotbar_slot_selected(slot, hotbar.get_selected_item())
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("build", -6.0)
	if node:
		var tw := node.create_tween()
		node.scale = Vector2(0.7, 0.7)
		tw.tween_property(node, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.emit("block_placed", {"kind": id})
			break
	return true


func spawn(id: String, c: Vector2i, extra: Dictionary = {}) -> Node2D:
	if BlockScript.KINDS.has(id):
		var b: StaticBody2D = BlockScript.new()
		b.kind = id
		b.name = "B_%s_%d_%d" % [id, c.x, c.y]
		if extra.has("hp"):
			b.hp = int(extra["hp"])
		b.is_open = bool(extra.get("open", false))
		add_child(b)
		b.global_position = BlockScript.cell_base(c)
		if BlockScript.is_floor_kind(id):
			_floor[c] = b
			var wg := get_tree().get_first_node_in_group("worldgen")
			if id in ["floor_wood", "bridge_wood"] and wg and wg.ground_is_water(c):
				wg.set_bridge(c, true)
		else:
			_solid[c] = b
		b.tree_exiting.connect(_unregister.bind(b))
		return b
	if PlantScript.SAPLINGS.has(id):
		var pt: Node2D = PlantScript.new()
		pt.kind = str(extra.get("k", PlantScript.SAPLINGS[id]))
		var clock := get_tree().get_first_node_in_group("game_clock")
		pt.planted_day = int(extra.get("d", clock.get("current_day") if clock else 1))
		pt.anchor = c
		pt.name = "P_%s_%d_%d" % [pt.kind, c.x, c.y]
		add_child(pt)
		pt.global_position = BlockScript.cell_base(c)
		_solid[c] = pt
		pt.tree_exiting.connect(_unregister.bind(pt))
		return pt
	if DecorScript.KINDS.has(id):
		var d: StaticBody2D = DecorScript.new()
		d.kind = id
		d.anchor = c
		d.name = "D_%s_%d_%d" % [id, c.x, c.y]
		add_child(d)
		d.global_position = DecorScript.base_for(id, c)
		var layer := _layer_for(id)
		for cc in _cells_of(id, c):
			layer[cc] = d
		d.tree_exiting.connect(_unregister.bind(d))
		return d
	if FurnitureScript.KINDS.has(id):
		var f: StaticBody2D = FurnitureScript.new()
		f.kind = id
		f.anchor = c
		f.name = "F_%s_%d_%d" % [id, c.x, c.y]
		add_child(f)
		f.global_position = FurnitureScript.center_for(id, c)
		for cc in _cells_of(id, c):
			_solid[cc] = f
		f.tree_exiting.connect(_unregister.bind(f))
		if id == "chest" and extra.has("slots") and has_node("/root/SaveManager") and f.inner:
			get_node("/root/SaveManager")._deser_into(f.inner.storage_slots, extra["slots"])
		if id == "bed":
			var wg2 := get_tree().get_first_node_in_group("worldgen")
			var bed: Node = f.inner
			if wg2 and bed and bed.has_method("get_wake_position") and not extra.get("loading", false):
				wg2.respawn_pos = bed.get_wake_position()
				_msg("Bed placed. You will wake up here if you fall.")
		return f
	return null


## Breaking floors: they are flat, so the tool swing looks at the aimed tile.
func hit_floor(player: Node2D, tool_power: int) -> bool:
	var c := target_cell(player)
	var f := floor_at(c)
	if f == null and block_at(c) == null:
		# Also try the tile under / in front of the player
		c = BlockScript.cell_of(player.global_position + (player.get("last_direction") as Vector2) * 14.0)
		f = floor_at(c)
	if f and f.has_method("take_hit"):
		return f.take_hit(tool_power, player.get("last_direction"))
	return false


func _msg(t: String) -> void:
	if Time.get_ticks_msec() - _last_msg_ms < 700:
		return
	_last_msg_ms = Time.get_ticks_msec()
	var hud := get_tree().get_first_node_in_group("hud_ui")
	if hud:
		hud.show_hud_message(t, 1.8)


func _creative() -> bool:
	var gm := get_tree().get_first_node_in_group("game_mode")
	return gm != null and gm.get("creative") == true


func count_blocks() -> int:
	var n := 0
	for c in get_children():
		if c.get_script() == BlockScript or c.get_script() == FurnitureScript or c.get_script() == DecorScript:
			n += 1
	return n


func get_save_data() -> Dictionary:
	var blocks: Array = []
	var furn: Array = []
	var decor: Array = []
	var plants: Array = []
	for c in get_children():
		if c.get("is_dead") == true:
			continue
		if c.get_script() == BlockScript:
			blocks.append(c.get_save_data())
		elif c.get_script() == FurnitureScript:
			furn.append(c.get_save_data())
		elif c.get_script() == DecorScript:
			decor.append(c.get_save_data())
		elif c.get_script() == PlantScript:
			plants.append(c.get_save_data())
	var animals: Array = []
	for a in get_tree().get_nodes_in_group("saved_animals"):
		if is_instance_valid(a) and not a.get("is_dead") and a.has_method("get_save_data"):
			animals.append(a.get_save_data())
	var boats: Array = []
	for b in get_tree().get_nodes_in_group("boats"):
		if is_instance_valid(b) and not b.get("is_dead"):
			boats.append(b.get_save_data())
	return {"blocks": blocks, "furn": furn, "decor": decor, "plants": plants, "animals": animals, "boats": boats}


func load_save_data(d: Dictionary) -> void:
	for c in get_children():
		if c.get_script() == BlockScript or c.get_script() == FurnitureScript or c.get_script() == DecorScript or c.get_script() == PlantScript:
			c.queue_free()
	_solid.clear()
	_floor.clear()
	_flat.clear()
	_wall.clear()
	for e in d.get("blocks", []):
		spawn(str(e.get("k", "wall_wood")), Vector2i(int(e.get("x", 0)), int(e.get("y", 0))), e)
	for e in d.get("furn", []):
		var ex: Dictionary = e.duplicate()
		ex["loading"] = true
		spawn(str(e.get("k", "chest")), Vector2i(int(e.get("x", 0)), int(e.get("y", 0))), ex)
	for e in d.get("decor", []):
		spawn(str(e.get("k", "stool")), Vector2i(int(e.get("x", 0)), int(e.get("y", 0))), e)
	for e in d.get("plants", []):
		spawn(PlantScript.item_for(str(e.get("k", "oak"))), Vector2i(int(e.get("x", 0)), int(e.get("y", 0))), e)
	for a in get_tree().get_nodes_in_group("saved_animals"):
		if is_instance_valid(a):
			a.queue_free()
	# v1.4 boats (get back in if you saved while rowing)
	for b in get_tree().get_nodes_in_group("boats"):
		if is_instance_valid(b):
			if b.get("rider"):
				b.leave(false)
			b.queue_free()
	var BoatScript = load("res://scripts/systems/boat.gd")
	for e in d.get("boats", []):
		var bt: StaticBody2D = BoatScript.create()
		add_child(bt)
		bt.global_position = Vector2(float(e.get("x", 0)), float(e.get("y", 0)))
		bt.load_data(e)
		if bool(e.get("ride", false)):
			bt.pending_ride = true
			var pl := get_tree().get_first_node_in_group("player")
			if pl:
				(func() -> void:
					if is_instance_valid(bt) and is_instance_valid(pl):
						pl.global_position = bt.global_position
						bt.board(pl)).call_deferred()
	var AnimalScript = load("res://scripts/animal.gd")
	for e in d.get("animals", []):
		var an: CharacterBody2D = AnimalScript.create(str(e.get("s", "chicken")))
		an.set("is_baby", bool(e.get("b", false)))
		an.set("birth_day", int(e.get("d", 0)))
		an.set_meta("bred", true)
		an.add_to_group("saved_animals")
		add_child(an)
		an.global_position = Vector2(float(e.get("x", 0)), float(e.get("y", 0)))
