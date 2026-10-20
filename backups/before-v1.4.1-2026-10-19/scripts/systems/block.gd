extends StaticBody2D

## A building block (v1.3): walls, floors, doors and fences you place yourself.
## The same blocks make up the abandoned cabins found out in the wild.
##
## Zombies chew through solid blocks (take_zombie_damage, same as defenses).
## You take a block back with an axe (wood) or a pickaxe (stone, brick); the
## right tool is quickest. Floors placed on water become a bridge.

const ItemDB = preload("res://scripts/item_database.gd")
const ItemDataClass = preload("res://scripts/item_data.gd")
const WorldItemScene = preload("res://Scenes/world_item.tscn")
const V13 := "res://Assets/Generated/v13/"
## The build grid matches the village TerrainLayer grid.
const ORIGIN := Vector2(28, 47)
const T := 16

## hp: what zombies must chew through · work: hits (x tool power) for you to take it
const KINDS := {
	"wall_wood": {"hp": 140, "work": 4, "tool": "axe", "name": "WOODEN WALL"},
	"wall_stone": {"hp": 320, "work": 6, "tool": "pick", "name": "STONE WALL"},
	"wall_brick": {"hp": 480, "work": 7, "tool": "pick", "name": "BRICK WALL"},
	"door_wood": {"hp": 160, "work": 4, "tool": "axe", "name": "WOODEN DOOR", "door": true},
	"fence_wood": {"hp": 90, "work": 3, "tool": "axe", "name": "WOODEN FENCE", "fence": true},
	"floor_wood": {"hp": 1, "work": 2, "tool": "axe", "name": "WOODEN FLOOR", "floor": true},
	"floor_stone": {"hp": 1, "work": 3, "tool": "pick", "name": "STONE FLOOR", "floor": true},
	"floor_brick": {"hp": 1, "work": 3, "tool": "pick", "name": "BRICK FLOOR", "floor": true},
	# v1.4 biome blocks - materials you find in one kind of land
	"wall_sandstone": {"hp": 280, "work": 5, "tool": "pick", "name": "SANDSTONE WALL"},
	"wall_ice": {"hp": 240, "work": 5, "tool": "pick", "name": "ICE WALL"},
	"wall_mossy": {"hp": 360, "work": 6, "tool": "pick", "name": "MOSSY STONE WALL"},
	"wall_driftwood": {"hp": 150, "work": 4, "tool": "axe", "name": "DRIFTWOOD WALL"},
	"wall_pine": {"hp": 180, "work": 4, "tool": "axe", "name": "PINE WALL"},
	"floor_sandstone": {"hp": 1, "work": 3, "tool": "pick", "name": "SANDSTONE FLOOR", "floor": true},
	"floor_ice": {"hp": 1, "work": 3, "tool": "pick", "name": "ICE FLOOR", "floor": true},
	"floor_mossy": {"hp": 1, "work": 3, "tool": "pick", "name": "MOSSY STONE FLOOR", "floor": true},
	"floor_driftwood": {"hp": 1, "work": 2, "tool": "axe", "name": "DRIFTWOOD FLOOR", "floor": true},
	"floor_pine": {"hp": 1, "work": 2, "tool": "axe", "name": "PINE FLOOR", "floor": true},
}
const V131 := "res://Assets/Generated/v131/"

## Where a block's picture lives (the v1.4 biome blocks are in v131).
static func tex_path(k: String) -> String:
	var p := V13 + k + ".png"
	return p if ResourceLoader.exists(p) else V131 + k + ".png"


static func is_wood_kind(k: String) -> bool:
	return k.ends_with("wood") or k.ends_with("pine")

var kind := "wall_wood"
## Part of a generated ruin (saved by WorldGen, not by the build system).
var natural := false
var hp := -1
var max_hp := 100
var is_dead := false
var is_open := false
var interact_range := 22.0

var _sprite: Sprite2D
var _shape: CollisionShape2D
var _bar: Node2D
var _bar_fill: ColorRect
var _work := 0.0


static func cell_of(pos: Vector2) -> Vector2i:
	var p := (pos - ORIGIN) / float(T)
	return Vector2i(floori(p.x), floori(p.y))


## Bottom-centre of a cell: blocks stand on it so they Y-sort with the player.
static func cell_base(c: Vector2i) -> Vector2:
	return ORIGIN + Vector2(c.x * T + T * 0.5, c.y * T + T)


static func is_floor_kind(k: String) -> bool:
	return KINDS.has(k) and KINDS[k].get("floor", false)


func cell() -> Vector2i:
	return cell_of(global_position + Vector2(0, -8))


func _ready() -> void:
	add_to_group("blocks")
	var info: Dictionary = KINDS.get(kind, KINDS["wall_wood"])
	max_hp = int(info["hp"])
	if hp <= 0 or hp > max_hp:
		hp = max_hp
	collision_mask = 0
	_sprite = Sprite2D.new()
	_sprite.centered = false
	add_child(_sprite)
	if info.get("floor", false):
		add_to_group("floors")
		collision_layer = 0
		z_index = -1
		_sprite.texture = load(tex_path(kind))
		_sprite.offset = Vector2(-8, -16)
	else:
		add_to_group("defenses")
		collision_layer = 1
		_shape = CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		if info.get("fence", false):
			rs.size = Vector2(16, 8)
			_shape.position = Vector2(0, -5)
			_sprite.texture = load(V13 + "fence_wood.png")
			_sprite.offset = Vector2(-8, -16)
		else:
			rs.size = Vector2(16, 14)
			_shape.position = Vector2(0, -7)
			_sprite.texture = load(V13 + "door_wood.png") if info.get("door", false) else load(tex_path(kind))
			_sprite.offset = Vector2(-8, -24)
		_shape.shape = rs
		add_child(_shape)
		if info.get("door", false):
			add_to_group("interactables")
			add_to_group("doors_built")
			_set_open(is_open, false)
		_build_bar()


func _build_bar() -> void:
	_bar = Node2D.new()
	_bar.position = Vector2(-8, -28)
	_bar.z_index = 10
	add_child(_bar)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.02, 0.85)
	bg.size = Vector2(16, 3)
	_bar.add_child(bg)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color("8FD14F")
	_bar_fill.position = Vector2(1, 1)
	_bar_fill.size = Vector2(14, 1)
	_bar.add_child(_bar_fill)
	_bar.visible = false


func _update_bar() -> void:
	if _bar == null:
		return
	var r := float(hp) / float(max_hp)
	_bar.visible = r < 0.999
	_bar_fill.size.x = 14.0 * r
	_bar_fill.color = Color("8FD14F") if r > 0.5 else (Color("F0C266") if r > 0.25 else Color("E0484A"))


# --- Doors ----------------------------------------------------------------

func can_interact(_p: Node2D) -> bool:
	return not is_dead and KINDS.get(kind, {}).get("door", false)


func get_prompt() -> String:
	return "CLOSE DOOR" if is_open else "OPEN DOOR"


func interact(p: Node2D) -> void:
	if is_open:
		# Don't shut the door on someone standing in the doorway.
		var q := PhysicsShapeQueryParameters2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(14, 12)
		q.shape = rs
		q.transform = Transform2D(0.0, global_position + Vector2(0, -7))
		q.collision_mask = 0xFFFFFFFF
		q.exclude = [get_rid()]
		for hit in get_world_2d().direct_space_state.intersect_shape(q, 8):
			var col = hit.get("collider")
			if col is CharacterBody2D:
				_toast("SOMETHING IS IN THE WAY")
				return
	_set_open(not is_open, true)


func _set_open(open: bool, sound: bool) -> void:
	is_open = open
	if _sprite:
		_sprite.texture = load(V13 + ("door_wood_open.png" if open else "door_wood.png"))
	collision_layer = 0 if open else 1
	if sound and has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("door", -8.0)


# --- Damage ---------------------------------------------------------------

## Zombies chewing on a wall or a closed door.
func take_zombie_damage(amount: int) -> void:
	if is_dead or is_floor_kind(kind):
		return
	hp = maxi(0, hp - amount)
	_update_bar()
	_flash(Color(1.6, 0.6, 0.5))
	if hp <= 0:
		_break(false)


## The player's axe / pickaxe.
func take_hit(tool_power: int = 1, hit_dir: Vector2 = Vector2.ZERO) -> bool:
	if is_dead:
		return false
	var p := get_tree().get_first_node_in_group("player")
	var item: Resource = p.get("current_held_item") if p else null
	var creative := _creative()
	var act: int = int(item.get("action_type")) if item else -1
	var id: String = str(item.get("item_id")) if item else ""
	var is_axe := act == ItemDataClass.ActionType.CHOP
	var is_pick := act == ItemDataClass.ActionType.MINE or id == "war_hammer"
	if not creative and not is_axe and not is_pick:
		_bump(hit_dir)
		_popup("USE AN AXE OR PICKAXE")
		return false
	var info: Dictionary = KINDS.get(kind, KINDS["wall_wood"])
	var right: bool = (info["tool"] == "axe" and is_axe) or (info["tool"] == "pick" and is_pick)
	var power := float(maxi(1, tool_power)) if right else 0.5
	_work += power
	_bump(hit_dir)
	_sfx("tree_chop" if info["tool"] == "axe" else "rock_hit", -8.0)
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.burst(global_position + Vector2(0, -10), _chip_color(), 4, 45.0)
	if creative or _work >= float(info["work"]):
		_break(true)
	return true


func _chip_color() -> Color:
	match kind.get_slice("_", 1):
		"sandstone": return Color(0.85, 0.68, 0.42)
		"ice": return Color(0.75, 0.9, 1.0)
		"mossy": return Color(0.45, 0.55, 0.38)
		"driftwood": return Color(0.75, 0.72, 0.65)
		"pine": return Color(0.5, 0.28, 0.18)
	if kind.ends_with("stone"):
		return Color(0.62, 0.6, 0.66)
	if kind.ends_with("brick"):
		return Color(0.77, 0.38, 0.25)
	return Color(0.63, 0.44, 0.24)


func _break(drop: bool) -> void:
	if is_dead:
		return
	is_dead = true
	hp = 0
	remove_from_group("defenses")
	remove_from_group("interactables")
	remove_from_group("blocks")
	collision_layer = 0
	if is_floor_kind(kind):
		var wg := get_tree().get_first_node_in_group("worldgen")
		if wg and wg.has_method("set_bridge"):
			var c := cell()
			if wg.ground_is_water(c):
				wg.set_bridge(c, false)
	if drop:
		var it = ItemDB.get_item(kind)
		if it and not _creative():
			var w := WorldItemScene.instantiate()
			get_parent().add_child(w)
			w.global_position = global_position + Vector2(0, -6)
			w.call("set_item", it, 1)
	_sfx("rock_break" if not is_wood_kind(kind) else "tree_chop", -8.0)
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.burst(global_position + Vector2(0, -10), _chip_color(), 10, 70.0)
		juice.dust(global_position, 4)
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.emit("block_removed", {"kind": kind, "by_player": drop})
			break
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)


func repair_full() -> void:
	hp = max_hp
	_update_bar()


func _flash(c: Color) -> void:
	if _sprite == null:
		return
	_sprite.modulate = c
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.15)


func _bump(dir: Vector2) -> void:
	if _sprite == null:
		return
	var o := dir.normalized() * 1.0 if dir != Vector2.ZERO else Vector2(1, 0)
	var tw := create_tween()
	_sprite.position = o
	tw.tween_property(_sprite, "position", Vector2.ZERO, 0.08)


var _popup_t := 0


func _popup(text: String) -> void:
	if Time.get_ticks_msec() - _popup_t < 1000:
		return
	_popup_t = Time.get_ticks_msec()
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.popup_text(global_position + Vector2(0, -26), text, Color("E8A898"))


func _toast(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud_ui")
	if hud and hud.has_method("show_hud_message"):
		hud.show_hud_message(text, 1.5)


func _creative() -> bool:
	var gm := get_tree().get_first_node_in_group("game_mode")
	return gm != null and gm.get("creative") == true


func _sfx(n: String, db: float) -> void:
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play(n, db)


func get_save_data() -> Dictionary:
	var c := cell()
	var d := {"k": kind, "x": c.x, "y": c.y}
	if hp < max_hp:
		d["hp"] = hp
	if is_open:
		d["open"] = true
	return d
