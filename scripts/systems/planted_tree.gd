extends Node2D

## PlantedTree (v1.4): a sapling you planted. It grows on its own:
##   day 0  sapling      (E to dig it up again)
##   day 1  young tree
##   day 2+ a full tree you can chop for wood (and maybe another sapling).
## Saved by the BuildManager.

const TREE_OAK := preload("res://Scenes/tree.tscn")
const TREE_ROUND := preload("res://Scenes/tree_round.tscn")
const ItemDB = preload("res://scripts/item_database.gd")
const WorldItemScene = preload("res://Scenes/world_item.tscn")
const V13 := "res://Assets/Generated/v13/"
const V131 := "res://Assets/Generated/v131/"

## sapling item -> tree kind
const SAPLINGS := {"sapling": "oak", "pine_sapling": "pine"}
const DAYS_YOUNG := 1
const DAYS_GROWN := 2

var kind := "oak"
var planted_day := 1
var anchor := Vector2i.ZERO
var is_dead := false
var interact_range := 20.0
var _stage := -1
var _spr: Sprite2D
var _tree: Node2D


static func item_for(tree_kind: String) -> String:
	return "pine_sapling" if tree_kind in ["pine", "pine_snow"] else "sapling"


func _ready() -> void:
	add_to_group("planted_trees")
	_spr = Sprite2D.new()
	_spr.centered = false
	add_child(_spr)
	var clock := get_tree().get_first_node_in_group("game_clock")
	if clock and clock.has_signal("day_changed"):
		clock.day_changed.connect(func(_d: int) -> void: _update())
	_update()


func age_days() -> int:
	var clock := get_tree().get_first_node_in_group("game_clock")
	return (int(clock.get("current_day")) - planted_day) if clock else 0


func _update() -> void:
	var a := age_days()
	var st := 0 if a < DAYS_YOUNG else (1 if a < DAYS_GROWN else 2)
	if st == _stage:
		return
	_stage = st
	match st:
		0:
			_spr.texture = load(V131 + ("pine_sapling.png" if kind == "pine" else "sapling.png"))
			_spr.scale = Vector2.ONE
			_spr.offset = Vector2(-8, -15)
			add_to_group("interactables")
		1:
			var t: Texture2D = load(V13 + "pine.png") if kind == "pine" else _oak_texture()
			_spr.texture = t
			_spr.scale = Vector2(0.5, 0.5)
			_spr.offset = Vector2(-t.get_width() * 0.5, -t.get_height() + 4.0)
			add_to_group("interactables")
		2:
			_grow_up()


func _oak_texture() -> Texture2D:
	var t: Node = TREE_OAK.instantiate()
	var s := t.get_node_or_null("Sprite2D") as Sprite2D
	var tex: Texture2D = s.texture if s else null
	if s and s.region_enabled:
		var a := AtlasTexture.new()
		a.atlas = s.texture
		a.region = s.region_rect
		tex = a
	t.free()
	return tex


func _grow_up() -> void:
	remove_from_group("interactables")
	_spr.visible = false
	if _tree and is_instance_valid(_tree):
		return
	_tree = (TREE_ROUND if kind == "round" else TREE_OAK).instantiate()
	_tree.set_meta("tree_kind", kind)
	add_child(_tree)
	_tree.position = Vector2(0, -4)
	if kind == "pine":
		var spr := _tree.get_node_or_null("Sprite2D") as Sprite2D
		if spr:
			var tex: Texture2D = load(V13 + "pine.png")
			spr.texture = tex
			spr.region_enabled = false
			spr.position = Vector2(0, -tex.get_height() * 0.5 + 2.0)
			_tree.set("_initial_sprite_pos", spr.position)
	if _tree.has_signal("tree_destroyed"):
		_tree.tree_destroyed.connect(_on_chopped)
	var lw := get_tree().get_first_node_in_group("living_world")
	if lw and lw.has_method("add_tree_sway"):
		lw.add_tree_sway(_tree)


func _on_chopped() -> void:
	is_dead = true
	# the tree plays its fall animation and drops wood; this spot is free again
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())


# --- Dig a sapling back up (E) ------------------------------------------------

func can_interact(_p: Node2D) -> bool:
	return not is_dead and _stage < 2


func get_prompt() -> String:
	return "DIG UP SAPLING" if _stage == 0 else "DIG UP YOUNG TREE"


func interact(_p: Node2D) -> void:
	if is_dead:
		return
	is_dead = true
	var gm := get_tree().get_first_node_in_group("game_mode")
	if not (gm and gm.get("creative") == true):
		var it = ItemDB.get_item(item_for(kind))
		if it:
			var w := WorldItemScene.instantiate()
			get_parent().add_child(w)
			w.global_position = global_position + Vector2(0, -4)
			w.call("set_item", it, 1)
	queue_free()


func get_save_data() -> Dictionary:
	return {"k": kind, "x": anchor.x, "y": anchor.y, "d": planted_day}
