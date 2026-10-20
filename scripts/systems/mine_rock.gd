extends StaticBody2D

## A breakable rock or ore vein in The Hollow Mines (v1.2).
## Only pickaxes can break rocks, and harder veins need a better pickaxe (v1.3):
##   stone: wooden · copper: stone · iron: copper · gold: iron · crystal/gem: golden

const ItemDataClass = preload("res://scripts/item_data.gd")
const WorldItemScene = preload("res://Scenes/world_item.tscn")
const ItemDB = preload("res://scripts/item_database.gd")
const V12 := "res://Assets/Generated/v12/"

## type -> hp, power needed, drops [[item, min, max, chance]], xp, hit sound, chip colour
const TYPES := {
	"stone": {"hp": 3, "power": 1, "drops": [["stone_rock", 1, 2, 1.0]], "xp": 1, "sfx": "rock_hit", "chip": Color(0.62, 0.6, 0.66)},
	"copper": {"hp": 5, "power": 2, "drops": [["copper_ore", 1, 3, 1.0], ["stone_rock", 0, 1, 0.5]], "xp": 3, "sfx": "ore_hit", "chip": Color(0.88, 0.5, 0.25)},
	"iron": {"hp": 8, "power": 3, "drops": [["iron_ore", 1, 3, 1.0], ["stone_rock", 0, 1, 0.5]], "xp": 5, "sfx": "ore_hit", "chip": Color(0.82, 0.6, 0.55)},
	"gold": {"hp": 10, "power": 4, "drops": [["gold_ore", 1, 2, 1.0]], "xp": 8, "sfx": "ore_hit", "chip": Color(0.98, 0.78, 0.25)},
	"crystal": {"hp": 12, "power": 5, "drops": [["crystal_shard", 1, 2, 1.0]], "xp": 12, "sfx": "ore_hit", "chip": Color(0.5, 0.9, 0.9)},
	"gem": {"hp": 10, "power": 5, "drops": [["gem", 1, 1, 1.0]], "xp": 15, "sfx": "gem", "chip": Color(0.95, 0.45, 0.7)},
}
## Pickaxe needed for each power level (shown when a rock is too hard).
const PICK_NAMES := {2: "STONE", 3: "COPPER", 4: "IRON", 5: "GOLDEN"}

var rock_type: String = "stone"
var variant: int = 0
var hp: int = 3
var _sprite: Sprite2D
var _shake_tw: Tween
var _warned_t := 0


func _ready() -> void:
	add_to_group("mine_rocks")
	collision_layer = 1
	collision_mask = 0
	var t: Dictionary = TYPES.get(rock_type, TYPES["stone"])
	hp = int(t["hp"])
	_sprite = Sprite2D.new()
	var name := "rock_%s_%s" % [rock_type, "abc"[variant % 3]]
	if rock_type in ["crystal", "gem"]:
		name = "rock_" + rock_type
	_sprite.texture = load(V12 + name + ".png")
	_sprite.offset = Vector2(0, -7)
	add_child(_sprite)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(12, 8)
	cs.shape = rs
	cs.position = Vector2(0, -3)
	add_child(cs)
	if rock_type in ["crystal", "gem"]:
		var l := PointLight2D.new()
		l.texture = _glow()
		l.texture_scale = 0.5
		l.energy = 0.7
		l.color = Color(0.5, 0.95, 1.0) if rock_type == "crystal" else Color(1.0, 0.5, 0.8)
		l.position = Vector2(0, -6)
		add_child(l)


func _glow() -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tx := GradientTexture2D.new()
	tx.gradient = g
	tx.width = 64
	tx.height = 64
	tx.fill = GradientTexture2D.FILL_RADIAL
	tx.fill_from = Vector2(0.5, 0.5)
	tx.fill_to = Vector2(1.0, 0.5)
	return tx


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


## Called by the player's tool swing.
func take_hit(tool_power: int = 1, hit_dir: Vector2 = Vector2.ZERO) -> bool:
	if hp <= 0:
		return false
	var p := _player()
	var item: Resource = p.get("current_held_item") if p else null
	var is_pick: bool = item != null and item.get("action_type") == ItemDataClass.ActionType.MINE
	var t: Dictionary = TYPES.get(rock_type, TYPES["stone"])
	var juice := get_tree().get_first_node_in_group("juice")
	_bump(hit_dir)
	var gm := get_tree().get_first_node_in_group("game_mode")
	if gm and gm.get("creative") == true:
		hp = 0
		_break(t)
		return true
	if not is_pick:
		_sfx("rock_hit", -14.0)
		_warn("USE A PICKAXE")
		return false
	if tool_power < int(t["power"]):
		_sfx("rock_hit", -8.0)
		_warn("TOO HARD! NEED A %s PICKAXE" % str(PICK_NAMES.get(int(t["power"]), "BETTER")))
		if juice:
			juice.burst(global_position + Vector2(0, -6), Color(1, 1, 0.8), 3, 40.0)
		return false
	hp -= maxi(1, tool_power)
	_sfx(str(t["sfx"]), -8.0)
	if juice:
		juice.burst(global_position + Vector2(0, -6), t["chip"], 5, 55.0)
		juice.shake(0.8, 0.08)
	if hp <= 0:
		_break(t)
	return true


func _bump(dir: Vector2) -> void:
	if _shake_tw and _shake_tw.is_valid():
		_shake_tw.kill()
	var o := dir.normalized() * 1.5 if dir != Vector2.ZERO else Vector2(1, 0)
	_shake_tw = create_tween()
	_sprite.position = o
	_shake_tw.tween_property(_sprite, "position", -o * 0.5, 0.04)
	_shake_tw.tween_property(_sprite, "position", Vector2.ZERO, 0.05)
	_sprite.modulate = Color(1.5, 1.5, 1.5)
	_shake_tw.parallel().tween_property(_sprite, "modulate", Color.WHITE, 0.1)


func _warn(text: String) -> void:
	if Time.get_ticks_msec() - _warned_t < 900:
		return
	_warned_t = Time.get_ticks_msec()
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.popup_text(global_position + Vector2(0, -20), text, Color("E8A898"))


func _break(t: Dictionary) -> void:
	collision_layer = 0
	_sfx("rock_break", -6.0)
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.burst(global_position + Vector2(0, -6), t["chip"], 12, 80.0)
		juice.dust(global_position, 6)
		juice.shake(1.6, 0.14)
	var parent := get_parent()
	for d in t["drops"]:
		if randf() > float(d[3]):
			continue
		var n := randi_range(int(d[1]), int(d[2]))
		var item = ItemDB.get_item(str(d[0]))
		if item == null:
			continue
		for i in n:
			var w := WorldItemScene.instantiate()
			parent.add_child(w)
			w.global_position = global_position + Vector2(0, -2)
			w.call("set_item", item, 1)
	# v1.4: rocks out in the desert / snowfields / highlands also give that land's stone
	if has_meta("bonus_drop"):
		var bd: Array = get_meta("bonus_drop")
		var bitem = ItemDB.get_item(str(bd[0]))
		if bitem:
			for i in randi_range(int(bd[1]), int(bd[2])):
				var wb := WorldItemScene.instantiate()
				parent.add_child(wb)
				wb.global_position = global_position + Vector2(randf_range(-6, 6), 2)
				wb.call("set_item", bitem, 1)
	# Rare surprise gem in any rock
	if rock_type in ["stone", "copper", "iron"] and randf() < 0.03:
		var g = ItemDB.get_item("gem")
		if g:
			var w2 := WorldItemScene.instantiate()
			parent.add_child(w2)
			w2.global_position = global_position
			w2.call("set_item", g, 1)
			if juice:
				juice.popup_text(global_position + Vector2(0, -22), "A GEM!", Color("FFB0D8"), true)
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats:
		stats.add_xp(int(t["xp"]))
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.emit("rock_mined", {"type": rock_type})
			break
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2(1.3, 0.4), 0.08)
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.08)
	tw.tween_callback(queue_free)


func _sfx(n: String, db: float) -> void:
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play(n, db)
