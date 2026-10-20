extends StaticBody2D

## Furniture you craft and place yourself (v1.3): storage chests, beds and the
## workbench / furnace / anvil crafting stations. Take one back with an axe
## (wooden things) or a pickaxe (furnace, anvil). A chest drops what is inside.

const ItemDB = preload("res://scripts/item_database.gd")
const ItemDataClass = preload("res://scripts/item_data.gd")
const WorldItemScene = preload("res://Scenes/world_item.tscn")
const CraftingScript = preload("res://scripts/systems/crafting.gd")
const ChestScene = preload("res://Scenes/Objects/chest.tscn")
const BedScene = preload("res://Scenes/Objects/Bed.tscn")

## footprint in cells (w, h), measured up from the anchor cell
const KINDS := {
	"chest": {"size": Vector2i(1, 1), "work": 3, "tool": "axe", "name": "CHEST"},
	"bed": {"size": Vector2i(1, 2), "work": 3, "tool": "axe", "name": "BED"},   # v1.4.2: 1 x 2, head up
	"workbench": {"size": Vector2i(2, 1), "work": 3, "tool": "axe", "name": "WORKBENCH"},
	"furnace": {"size": Vector2i(1, 1), "work": 4, "tool": "pick", "name": "FURNACE"},   # v1.4.2: one block
	"anvil": {"size": Vector2i(1, 1), "work": 4, "tool": "pick", "name": "ANVIL"},
	"watch_tower": {"size": Vector2i(2, 2), "work": 6, "tool": "axe", "name": "WATCH TOWER"},
}
const TOWER_HP := 420

var kind := "chest"
var anchor := Vector2i.ZERO
var is_dead := false
var inner: Node2D
var _work := 0.0
## Watch tower
var hp := TOWER_HP
var max_hp := TOWER_HP
var interact_range := 30.0
var _climber: Node2D
var _mark_t := 0.0
var _cam_zoom := Vector2.ZERO
var _spr: Sprite2D


static func center_for(k: String, c: Vector2i) -> Vector2:
	var sz: Vector2i = KINDS[k]["size"]
	var o := Vector2(28, 47)
	match k:
		"bed":
			return o + Vector2(c.x * 16 + 8, c.y * 16)   # centre of the 1 x 2 bed
		"chest":
			return o + Vector2(c.x * 16 + 8, c.y * 16 + 8)
	return o + Vector2(c.x * 16 + sz.x * 8, c.y * 16 + 16)


func _ready() -> void:
	add_to_group("furniture")
	collision_layer = 1
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	match kind:
		"chest":
			inner = ChestScene.instantiate()
			inner.name = "Chest"
			add_child(inner)
			rs.size = Vector2(14, 10)
			cs.position = Vector2(0, 2)
		"bed":
			inner = BedScene.instantiate()
			inner.name = "Bed"
			add_child(inner)
			_fit_bed(inner)
			rs.size = Vector2(14, 26)
			cs.position = Vector2(0, 1)
		"watch_tower":
			add_to_group("interactables")
			add_to_group("defenses")
			_spr = Sprite2D.new()
			_spr.texture = load("res://Assets/Generated/v13/watch_tower.png")
			_spr.centered = false
			_spr.offset = Vector2(-16, -64)
			add_child(_spr)
			rs.size = Vector2(28, 8)
			cs.position = Vector2(0, -4)
		_:
			inner = CraftingScript.make_station(self, kind, global_position, kind in ["anvil", "furnace"])
			inner.position = Vector2.ZERO
			rs.size = Vector2(28 if kind == "workbench" else 22, 6)
			cs.position = Vector2(0, -3)
	cs.shape = rs
	add_child(cs)


## v1.4.2: built beds are one block wide and two long, the pillow at the top.
func _fit_bed(bed: Node) -> void:
	var spr := bed.get_node_or_null("Sprite2D") as Sprite2D
	if spr:
		spr.texture = load("res://Assets/Generated/v131/bed_1x2.png")
		spr.position = Vector2.ZERO
	var solid := bed.get_node_or_null("StaticBody2D/CollisionShape2D") as CollisionShape2D
	if solid:
		var r := RectangleShape2D.new()
		r.size = Vector2(14, 26)
		solid.shape = r
		solid.position = Vector2(0, 1)
	var area := bed.get_node_or_null("InteractionArea/CollisionShape2D") as CollisionShape2D
	if area:
		var r2 := RectangleShape2D.new()
		r2.size = Vector2(36, 44)
		area.shape = r2
		area.position = Vector2(0, 2)
	var sp := bed.get_node_or_null("SleepPosition") as Node2D
	if sp:
		sp.position = Vector2(0, -2)
	var wp := bed.get_node_or_null("WakePosition") as Node2D
	if wp:
		wp.position = Vector2(16, 6)
	var lb := bed.get_node_or_null("InteractionLabel") as Control
	if lb:
		lb.position = Vector2(10, -24)


func take_hit(tool_power: int = 1, _hit_dir: Vector2 = Vector2.ZERO) -> bool:
	if is_dead or _climber != null:
		return false
	var p := get_tree().get_first_node_in_group("player")
	var item: Resource = p.get("current_held_item") if p else null
	var act: int = int(item.get("action_type")) if item else -1
	var is_axe := act == ItemDataClass.ActionType.CHOP
	var is_pick := act == ItemDataClass.ActionType.MINE or (item != null and str(item.get("item_id")) == "war_hammer")
	var creative := _creative()
	if not creative and not is_axe and not is_pick:
		return false
	var info: Dictionary = KINDS[kind]
	var right: bool = (info["tool"] == "axe" and is_axe) or (info["tool"] == "pick" and is_pick)
	_work += float(maxi(1, tool_power)) if right else 0.5
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("tree_chop" if info["tool"] == "axe" else "rock_hit", -8.0)
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.burst(global_position + Vector2(0, -8), Color(0.63, 0.44, 0.24) if info["tool"] == "axe" else Color(0.6, 0.6, 0.65), 4, 45.0)
	if creative or _work >= float(info["work"]):
		pick_up()
	return true


func pick_up() -> void:
	if is_dead:
		return
	if _climber:
		climb_down()
	is_dead = true
	var parent := get_parent()
	if kind == "chest" and inner and "storage_slots" in inner:
		if inner.get("is_open") and inner.has_method("close_chest"):
			inner.close_chest()
		for s in inner.storage_slots:
			if s.get("item") != null and int(s.get("amount", 0)) > 0:
				_drop(parent, s["item"], int(s["amount"]))
	if not _creative():
		_drop(parent, ItemDB.get_item(kind), 1)
	if kind == "bed":
		var wg := get_tree().get_first_node_in_group("worldgen")
		if wg and wg.get("respawn_pos") != Vector2.INF and (wg.respawn_pos as Vector2).distance_to(global_position) < 40.0:
			wg.respawn_pos = Vector2.INF
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.emit("block_removed", {"kind": kind, "by_player": true})
			break
	queue_free()


# --- Watch tower: climb up to see the whole field at night ---------------

func can_interact(_p: Node2D) -> bool:
	return kind == "watch_tower" and not is_dead


func get_prompt() -> String:
	return "CLIMB DOWN" if _climber else "CLIMB WATCH TOWER"


func interact(p: Node2D) -> void:
	if kind != "watch_tower":
		return
	if _climber:
		climb_down()
	else:
		_climb_up(p)


func _climb_up(p: Node2D) -> void:
	_climber = p
	p.set_meta("on_tower", self)
	p.set("input_locked", true)
	p.set("velocity", Vector2.ZERO)
	var col := p.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col:
		col.set_deferred("disabled", true)
	p.global_position = global_position + Vector2(0, -34)
	p.z_index = 2
	var cam := p.get_node_or_null("Camera2D") as Camera2D
	if cam:
		# v1.3.1: always zoom relative to the player's normal zoom, never to the zoom of
		# a half-finished tween (pressing E quickly kept widening the view).
		var base = p.get("camera_zoom")
		_cam_zoom = base if base is Vector2 and base != Vector2.ZERO else Vector2(3, 3)
		_zoom_to(cam, _cam_zoom * 0.62, 0.5)
	_mark_t = 0.0
	var hud := get_tree().get_first_node_in_group("hud_ui")
	if hud:
		hud.show_hud_message("From up here you can see zombies coming. E to climb down.", 3.0)
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("ladder", -6.0)


func climb_down() -> void:
	var p := _climber
	_climber = null
	if p == null or not is_instance_valid(p):
		return
	p.remove_meta("on_tower")
	p.set("input_locked", false)
	var col := p.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col:
		col.set_deferred("disabled", false)
	p.global_position = global_position + Vector2(0, 14)
	p.z_index = 0
	var cam := p.get_node_or_null("Camera2D") as Camera2D
	if cam and _cam_zoom != Vector2.ZERO:
		_zoom_to(cam, _cam_zoom, 0.4)
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("ladder", -6.0)


var _zoom_tw: Tween

func _zoom_to(cam: Camera2D, z: Vector2, t: float) -> void:
	if _zoom_tw and _zoom_tw.is_valid():
		_zoom_tw.kill()
	_zoom_tw = cam.create_tween()
	_zoom_tw.tween_property(cam, "zoom", z, t).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	if _climber == null:
		return
	if not is_instance_valid(_climber):
		_climber = null
		return
	_climber.global_position = global_position + Vector2(0, -34)
	_mark_t -= delta
	if _mark_t > 0.0:
		return
	_mark_t = 0.9
	var juice := get_tree().get_first_node_in_group("juice")
	if juice == null:
		return
	var biting := 0
	for z in get_tree().get_nodes_in_group("zombies"):
		if z.get("is_dead"):
			continue
		var d := (z as Node2D).global_position.distance_to(global_position)
		if d < 520.0:
			juice.popup_text((z as Node2D).global_position + Vector2(0, -34), "!", Color("FF5A4E"))
		if d < 40.0:
			biting += 1
	if biting > 0:
		take_zombie_damage(8 * biting)


func _unhandled_input(event: InputEvent) -> void:
	if _climber == null:
		return
	var leave: bool = event.is_action_pressed("interact") or event.is_action_pressed("move_up") or event.is_action_pressed("move_down") \
		or event.is_action_pressed("move_left") or event.is_action_pressed("move_right")
	if leave:
		climb_down()
		get_viewport().set_input_as_handled()


## Zombies batter the tower; if it falls, so do you.
func take_zombie_damage(amount: int) -> void:
	if is_dead or kind != "watch_tower":
		return
	hp = maxi(0, hp - amount)
	if _spr:
		_spr.modulate = Color(1.6, 0.6, 0.5)
		create_tween().tween_property(_spr, "modulate", Color.WHITE, 0.15)
	if hp <= 0:
		var p := _climber
		if p:
			climb_down()
			if p.has_method("take_damage"):
				p.take_damage(10)
		is_dead = true
		remove_from_group("defenses")
		remove_from_group("interactables")
		collision_layer = 0
		_drop(get_parent(), ItemDB.get_item("wood_log"), 4)
		var juice := get_tree().get_first_node_in_group("juice")
		if juice:
			juice.burst(global_position + Vector2(0, -30), Color(0.63, 0.44, 0.24), 18, 90.0)
			juice.shake(3.0, 0.3)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
		tw.tween_callback(queue_free)


func repair_full() -> void:
	hp = max_hp


func _drop(parent: Node, it: Resource, n: int) -> void:
	if it == null:
		return
	var w := WorldItemScene.instantiate()
	parent.add_child(w)
	w.global_position = global_position + Vector2(randf_range(-6, 6), randf_range(2, 8))
	w.call("set_item", it, n)


func _creative() -> bool:
	var gm := get_tree().get_first_node_in_group("game_mode")
	return gm != null and gm.get("creative") == true


func get_save_data() -> Dictionary:
	var d := {"k": kind, "x": anchor.x, "y": anchor.y}
	if kind == "chest" and inner and has_node("/root/SaveManager"):
		d["slots"] = get_node("/root/SaveManager")._ser_slots(inner.storage_slots)
	return d
