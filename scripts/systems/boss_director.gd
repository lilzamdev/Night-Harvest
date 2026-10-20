extends Node2D

## BossDirector (v1.3): surface bosses and zombie drops.
##  * Use a Rotten Totem / Plague Idol at night to call a boss to you.
##  * Every Blood Moon from night 7 on, the Rotting Giant comes for your farm.
##  * Zombies you kill can drop Rotten Flesh and Bones (boss idols are made of them).

const SurfaceBoss = preload("res://scripts/systems/surface_boss.gd")
const ItemDB = preload("res://scripts/item_database.gd")
const WorldItemScene = preload("res://Scenes/world_item.tscn")

var save_key := "bosses"
var kills := {"giant": 0, "plague": 0}
var _boss: Node2D
var _blood_timer := -1.0
var _game: Node2D


func _ready() -> void:
	add_to_group("boss_director")
	add_to_group("save_extension")
	y_sort_enabled = true
	global_position = Vector2.ZERO
	_game = get_parent() as Node2D
	call_deferred("_bind")


func _bind() -> void:
	var bus := get_tree().get_first_node_in_group("event_bus")
	if bus and bus.has_signal("gameplay_event"):
		bus.gameplay_event.connect(_on_event)
	var clock := get_tree().get_first_node_in_group("game_clock")
	if clock:
		clock.night_started.connect(_on_night_started)


func boss_alive() -> bool:
	return is_instance_valid(_boss) and not _boss.get("is_dead")


func _in_overworld(p: Node2D) -> bool:
	var mines := get_tree().get_first_node_in_group("mines")
	if mines and mines.get("active"):
		return false
	var world := get_tree().get_first_node_in_group("nh_world")
	if world and world.has_method("is_player_indoors") and world.is_player_indoors():
		return false
	return absf(p.global_position.x) < 150000.0 and absf(p.global_position.y) < 150000.0


func _is_night() -> bool:
	var clock := get_tree().get_first_node_in_group("game_clock")
	return clock != null and clock.is_night()


## Called by the player when using a boss idol. Returns true when the item was handled.
func use_item(p: Node2D, item: Resource) -> bool:
	var id := str(item.get("item_id"))
	var kind := ""
	match id:
		"rotten_totem":
			kind = "giant"
		"plague_idol":
			kind = "plague"
		_:
			return false
	if not _in_overworld(p):
		_msg("Use it outside, under the open sky.")
		return true
	if not _is_night():
		_msg("The idol stays silent. Use it at night.")
		return true
	if boss_alive():
		_msg("A boss is already hunting you!")
		return true
	var hotbar := get_tree().get_first_node_in_group("hotbar_ui")
	var inv := get_tree().get_first_node_in_group("inventory_ui")
	if hotbar and inv:
		inv.remove_hotbar_item_at(int(hotbar.get("selected_slot")), 1)
		if p.has_method("_on_hotbar_slot_selected"):
			p._on_hotbar_slot_selected(hotbar.selected_slot, hotbar.get_selected_item())
	spawn_boss(kind, p.global_position)
	return true


func spawn_boss(kind: String, near: Vector2) -> Node2D:
	var b: CharacterBody2D = SurfaceBoss.new()
	b.kind = kind
	b.first_kill = int(kills.get(kind, 0)) == 0
	b.name = "Boss_" + kind
	add_child(b)
	b.global_position = _spot_near(near)
	b.defeated.connect(_on_boss_defeated)
	_boss = b
	if has_node("/root/Music"):
		var m := get_node("/root/Music")
		if m.has_method("set_night"):
			m.set_night(true, true)
	_event("boss_spawned", {"kind": kind})
	return b


func _spot_near(center: Vector2) -> Vector2:
	var space := get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.collision_mask = 1
	for i in 24:
		var ang := randf() * TAU
		var pos := center + Vector2(cos(ang), sin(ang) * 0.7) * randf_range(110.0, 150.0)
		q.position = pos
		if space.intersect_point(q, 1).is_empty():
			return pos
	return center + Vector2(0, -120)


func _on_boss_defeated(kind: String) -> void:
	kills[kind] = int(kills.get(kind, 0)) + 1
	_event("surface_boss_defeated", {"kind": kind})
	var hud := get_tree().get_first_node_in_group("hud_ui")
	if hud:
		hud.show_hud_message("Boss defeated! Collect your reward.", 3.0)


func _on_night_started() -> void:
	var nd := get_tree().get_first_node_in_group("night_director")
	if nd == null:
		return
	var n: int = nd.night_number()
	if n >= 7 and nd.is_blood_moon_night(n):
		_blood_timer = 40.0


func _process(delta: float) -> void:
	if _blood_timer < 0.0:
		return
	_blood_timer -= delta
	if _blood_timer > 0.0:
		return
	_blood_timer = -1.0
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p and _is_night() and _in_overworld(p) and not boss_alive():
		var gm := get_tree().get_first_node_in_group("game_mode")
		if gm and gm.get("creative") == true:
			return
		_msg("The ground shakes... THE ROTTING GIANT comes for your farm!")
		spawn_boss("giant", p.global_position)


# --- Zombie drops -----------------------------------------------------------

func _on_event(type: String, data: Dictionary) -> void:
	if type != "zombie_died" or not data.get("by_player", false):
		return
	var pos: Vector2 = data.get("pos", Vector2.ZERO)
	if randf() < 0.55:
		_drop(pos, "rotten_flesh", 1)
	if randf() < 0.14:
		_drop(pos, "bone", 1)
	if str(data.get("variant", "")) == "brute" and randf() < 0.5:
		_drop(pos, "iron_ore", randi_range(1, 2))


func _drop(pos: Vector2, id: String, n: int) -> void:
	var it = ItemDB.get_item(id)
	if it == null:
		return
	var w := WorldItemScene.instantiate()
	_game.add_child(w)
	w.global_position = pos + Vector2(randf_range(-6, 6), randf_range(-2, 6))
	w.call("set_item", it, n)


func _msg(t: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud_ui")
	if hud:
		hud.show_hud_message(t, 3.0)


func _event(t: String, data: Dictionary) -> void:
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.emit(t, data)
			break


func get_save_data() -> Dictionary:
	return {"kills": kills}


func load_save_data(d: Dictionary) -> void:
	var k: Dictionary = d.get("kills", {})
	kills = {"giant": int(k.get("giant", 0)), "plague": int(k.get("plague", 0))}
