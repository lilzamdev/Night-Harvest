extends StaticBody2D

## A placed farm defense (Plants-vs-Zombies style):
##   barricade         solid wall, zombies must chew through it
##   spike_trap        walk-over trap: hurts and slows zombies (no collision)
##   scarecrow_turret  shoots crossbow bolts at the nearest zombie at night
##
## Zombies damage defenses through take_zombie_damage(); the player's own tools
## never hit them (no take_damage method on purpose).

const GEN := "res://Assets/Generated/"
const GEN12 := "res://Assets/Generated/v12/"
const BoltScript = preload("res://scripts/systems/bolt.gd")

const STATS := {
	"barricade": {"hp": 140, "solid": Vector2(16, 10)},
	"spike_trap": {"hp": 40, "solid": Vector2.ZERO},
	"scarecrow_turret": {"hp": 90, "solid": Vector2(10, 6)},
	# v1.2 (crafted)
	"stone_wall": {"hp": 340, "solid": Vector2(16, 10)},
	"iron_spikes": {"hp": 140, "solid": Vector2.ZERO},
	"lantern_post": {"hp": 120, "solid": Vector2(6, 4)},
	"sprinkler": {"hp": 60, "solid": Vector2.ZERO},
}

var kind: String = "barricade"
var interact_range: float = 18.0
var max_hp: int = 100
var hp: int = -1
var is_dead: bool = false

var _sprite: Sprite2D
var _bar: Node2D
var _bar_fill: ColorRect
var _cooldown: float = 0.0
var _spike_area: Area2D
var _spike_tick: Dictionary = {}
var _frame_t: float = 0.0
var _light: PointLight2D
var _tick: float = 0.0


func _ready() -> void:
	add_to_group("defenses")
	add_to_group("interactables")
	collision_mask = 0
	var st: Dictionary = STATS.get(kind, STATS["barricade"])
	max_hp = int(st["hp"])
	if hp <= 0 or hp > max_hp:
		hp = max_hp
	_sprite = Sprite2D.new()
	_sprite.centered = false
	add_child(_sprite)
	var solid: Vector2 = st["solid"]
	if solid != Vector2.ZERO:
		collision_layer = 1
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = solid
		cs.shape = rs
		cs.position = Vector2(0, -solid.y * 0.5)
		add_child(cs)
	else:
		collision_layer = 0
	match kind:
		"barricade":
			_sprite.texture = _frame("barricade.png", 0, 16, 16)
			_sprite.offset = Vector2(-8, -14)
		"spike_trap":
			_sprite.texture = _frame("spikes.png", 0, 16, 16)
			_sprite.offset = Vector2(-8, -11)
			z_index = -1
			_spike_area = Area2D.new()
			_spike_area.collision_layer = 0
			_spike_area.collision_mask = 0xFFFFFFFF
			var acs := CollisionShape2D.new()
			var ars := RectangleShape2D.new()
			ars.size = Vector2(14, 10)
			acs.shape = ars
			acs.position = Vector2(0, -4)
			_spike_area.add_child(acs)
			add_child(_spike_area)
		"scarecrow_turret":
			add_to_group("zombie_targets")
			_sprite.texture = _frame("turret.png", 0, 16, 32)
			_sprite.offset = Vector2(-8, -29)
		"stone_wall":
			_sprite.texture = load(GEN12 + "stone_wall.png")
			_sprite.offset = Vector2(-8, -14)
		"iron_spikes":
			_sprite.texture = load(GEN12 + "iron_spikes.png")
			_sprite.offset = Vector2(-8, -13)
			z_index = -1
			_spike_area = Area2D.new()
			_spike_area.collision_layer = 0
			_spike_area.collision_mask = 0xFFFFFFFF
			var ics := CollisionShape2D.new()
			var irs := RectangleShape2D.new()
			irs.size = Vector2(14, 10)
			ics.shape = irs
			ics.position = Vector2(0, -4)
			_spike_area.add_child(ics)
			add_child(_spike_area)
		"lantern_post":
			_sprite.texture = load(GEN12 + "lantern_post.png")
			_sprite.offset = Vector2(-8, -19)
			_light = PointLight2D.new()
			_light.texture = _glow_texture()
			_light.texture_scale = 2.2
			_light.color = Color(1.0, 0.82, 0.5)
			_light.energy = 1.1
			_light.position = Vector2(0, -14)
			add_child(_light)
		"sprinkler":
			_sprite.texture = _frame12("sprinkler.png", 0, 16, 12)
			_sprite.offset = Vector2(-8, -10)
			z_index = -1
	_build_bar()
	_update_visual()


func _frame(file: String, idx: int, w: int, h: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = load(GEN + file)
	a.region = Rect2(idx * w, 0, w, h)
	return a


func _frame12(file: String, idx: int, w: int, h: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = load(GEN12 + file)
	a.region = Rect2(idx * w, 0, w, h)
	return a


func _glow_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 128
	t.height = 128
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


func _build_bar() -> void:
	_bar = Node2D.new()
	_bar.position = Vector2(-8, -36 if kind in ["scarecrow_turret", "lantern_post"] else -20)
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


func _update_visual() -> void:
	var r := float(hp) / float(max_hp)
	_bar.visible = r < 0.999
	_bar_fill.size.x = 14.0 * r
	_bar_fill.color = Color("8FD14F") if r > 0.5 else (Color("F0C266") if r > 0.25 else Color("E0484A"))
	if kind == "barricade":
		var idx := 0 if r > 0.6 else (1 if r > 0.25 else 2)
		_sprite.texture = _frame("barricade.png", idx, 16, 16)


## Called by zombies (and spike wear).
func take_zombie_damage(amount: int) -> void:
	if is_dead:
		return
	hp = maxi(0, hp - amount)
	_update_visual()
	var tw := create_tween()
	_sprite.modulate = Color(1.6, 0.6, 0.5)
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.15)
	var shake := create_tween()
	shake.tween_property(_sprite, "position:x", 1.0, 0.04)
	shake.tween_property(_sprite, "position:x", -1.0, 0.04)
	shake.tween_property(_sprite, "position:x", 0.0, 0.04)
	if hp <= 0:
		_break()


func repair_full() -> void:
	hp = max_hp
	_update_visual()


func _break() -> void:
	is_dead = true
	remove_from_group("defenses")
	remove_from_group("zombie_targets")
	collision_layer = 0
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.emit("defense_destroyed", {"kind": kind, "pos": global_position})
			break
	var p := CPUParticles2D.new()
	p.amount = 14
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.6
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 60.0
	p.gravity = Vector2(0, 160)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 2.5
	p.color = Color("9BABB2") if kind in ["spike_trap", "iron_spikes", "stone_wall"] else Color("A0703E")
	p.position = Vector2(0, -8)
	get_parent().add_child(p)
	p.global_position = global_position + Vector2(0, -8)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	match kind:
		"spike_trap", "iron_spikes":
			_process_spikes(delta)
		"scarecrow_turret":
			_process_turret(delta)
		"lantern_post":
			_process_lantern(delta)
		"sprinkler":
			_process_sprinkler(delta)


## Lantern posts light the farm at night and make zombies in their glow sluggish.
func _process_lantern(delta: float) -> void:
	if _light:
		_light.energy = 1.05 + sin(Time.get_ticks_msec() * 0.006) * 0.06
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	for z in get_tree().get_nodes_in_group("zombies"):
		if not z.get("is_dead") and global_position.distance_to(z.global_position) < 52.0 and z.has_method("apply_slow"):
			z.apply_slow(0.7, 0.7)


## Sprinklers water every thirsty crop in the 3x3 tiles around them.
func _process_sprinkler(delta: float) -> void:
	if _frame_t > 0.0:
		_frame_t -= delta
		_sprite.texture = _frame12("sprinkler.png", int(_frame_t * 8.0) % 2, 16, 12)
		if _frame_t <= 0.0:
			_sprite.texture = _frame12("sprinkler.png", 0, 16, 12)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 3.0
	var fm := get_tree().get_first_node_in_group("farming_manager")
	if fm == null:
		return
	var n := 0
	for dx in [-16, 0, 16]:
		for dy in [-16, 0, 16]:
			var pos: Vector2 = global_position + Vector2(dx, dy - 6)
			if fm.can_water(pos):
				var crop: Node2D = fm.get_crop_at(pos)
				if crop and crop.has_method("set_watered"):
					crop.set_watered(true)
					n += 1
	if n > 0:
		_frame_t = 1.2
		var lw := get_tree().get_first_node_in_group("living_world")
		if lw:
			for i in 3:
				lw.play_fx(global_position + Vector2(randf_range(-14, 14), randf_range(-16, 6)), "splash", 6, 5, 3, 10.0)
		if has_node("/root/GameAudio"):
			var p := get_tree().get_first_node_in_group("player") as Node2D
			if p and p.global_position.distance_to(global_position) < 140.0:
				get_node("/root/GameAudio").play("sprinkler", -14.0)


func _process_spikes(delta: float) -> void:
	var any := false
	for b in _spike_area.get_overlapping_bodies():
		if not b.is_in_group("zombies") or b.get("is_dead"):
			continue
		any = true
		var id := b.get_instance_id()
		var t: float = _spike_tick.get(id, 0.0) - delta
		if t <= 0.0:
			t = 0.8
			b.take_damage(22 if kind == "iron_spikes" else 12, Vector2.ZERO, 0.0)
			if b.has_method("apply_slow"):
				b.apply_slow(0.35 if kind == "iron_spikes" else 0.45, 1.2)
			take_zombie_damage(1)
		_spike_tick[id] = t
	_frame_t -= delta
	if kind == "iron_spikes":
		return
	if any and _frame_t <= 0.0:
		_frame_t = 0.3
		_sprite.texture = _frame("spikes.png", 1, 16, 16)
	elif not any and _frame_t <= 0.0:
		_sprite.texture = _frame("spikes.png", 0, 16, 16)


func _process_turret(delta: float) -> void:
	_cooldown -= delta
	if _frame_t > 0.0:
		_frame_t -= delta
		if _frame_t <= 0.0:
			_sprite.texture = _frame("turret.png", 0, 16, 32)
	if _cooldown > 0.0:
		return
	var best: Node2D = null
	var best_d := 120.0
	for z in get_tree().get_nodes_in_group("zombies"):
		if z.get("is_dead"):
			continue
		var d := global_position.distance_to(z.global_position)
		if d < best_d:
			best_d = d
			best = z
	if not best:
		_cooldown = 0.3
		return
	_cooldown = 1.15
	_sprite.texture = _frame("turret.png", 1, 16, 32)
	_frame_t = 0.18
	_sprite.flip_h = best.global_position.x < global_position.x
	var bolt: Node2D = BoltScript.new()
	bolt.target = best
	bolt.damage = 16
	get_parent().add_child(bolt)
	bolt.global_position = global_position + Vector2(0, -18)
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("bow_shot", -10.0)


# --- Picking a defense back up (E) ---

const NAMES := {"barricade": "BARRICADE", "spike_trap": "SPIKE TRAP", "scarecrow_turret": "SCARECROW",
	"stone_wall": "STONE WALL", "iron_spikes": "IRON SPIKES", "lantern_post": "LANTERN", "sprinkler": "SPRINKLER"}


func can_interact(_player: Node2D) -> bool:
	return not is_dead


func get_prompt() -> String:
	var tag := "" if hp >= max_hp else " (%d%%)" % int(100.0 * hp / max_hp)
	return "PICK UP " + str(NAMES.get(kind, "DEFENSE")) + tag


func interact(_player: Node2D) -> void:
	if is_dead:
		return
	var inv := get_tree().get_first_node_in_group("inventory_ui")
	var hud := get_tree().get_first_node_in_group("hud_ui")
	# Badly damaged defenses only give back some wood.
	if hp < max_hp / 2:
		var wood = load("res://scripts/item_database.gd").get_item("wood_log")
		if inv and wood:
			inv.add_item(wood, 2)
		if hud:
			hud.show_hud_message("Too damaged to reuse. Salvaged 2 wood.", 2.0)
	else:
		var item = load("res://scripts/item_database.gd").get_item(kind)
		if inv and item and inv.add_item(item, 1) > 0:
			if hud:
				hud.show_hud_message("Your bag is full.", 1.5)
			return
	is_dead = true
	remove_from_group("defenses")
	remove_from_group("zombie_targets")
	remove_from_group("interactables")
	queue_free()


func get_save_data() -> Dictionary:
	return {"kind": kind, "x": global_position.x, "y": global_position.y, "hp": hp}
