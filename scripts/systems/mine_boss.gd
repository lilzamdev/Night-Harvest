extends CharacterBody2D

## The Hollow King (v1.2) — boss of mine floor 15.
## Phases:
##   1. Lumbers after you and SLAMS the ground (red warning ring, then a shockwave).
##   2. Under 66% and 33% HP he screams and summons ghouls.
##   3. Under 50% HP he also CHARGES across the cavern.
## Dropping him gives the Hollow Crown (craft the Hollow Blade), a pile of gold and
## makes every future night 25% calmer.

signal defeated

const WorldItemScene = preload("res://Scenes/world_item.tscn")
const ItemDB = preload("res://scripts/item_database.gd")
const CoinScript = preload("res://scripts/systems/coin.gd")
const CaveEnemyScript = preload("res://scripts/systems/cave_enemy.gd")
const Z := "res://Assets/Enemies/zombie/1_Default/Zombie_Default_"

var max_health: int = 2400
var current_health: int = 2400
var is_dead := false
var arena: Rect2

var _sprite: AnimatedSprite2D
var _crown: Sprite2D
var _state := "intro"
var _state_t := 2.0
var _slam_cd := 3.5
var _charge_cd := 6.0
var _charge_dir := Vector2.ZERO
var _summoned := {}
var _ring: Node2D
var _touch_cd := 0.0
var _bar_layer: CanvasLayer
var _bar_fill: ColorRect


func _ready() -> void:
	add_to_group("cave_enemies")
	add_to_group("boss")
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 11.0
	cs.shape = c
	add_child(cs)
	_sprite = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for a in [["idle", "Idle", 6.0, true], ["walk", "Walk", 7.0, true], ["slam", "Attack1", 10.0, false], ["hurt", "Hurt", 12.0, false], ["dead", "Dead", 7.0, false]]:
		sf.add_animation(a[0])
		sf.set_animation_speed(a[0], a[2])
		sf.set_animation_loop(a[0], a[3])
		var tex: Texture2D = load(Z + a[1] + ".png")
		for i in 6:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * 64, 0, 64, 64)
			sf.add_frame(a[0], at)
	_sprite.sprite_frames = sf
	_sprite.scale = Vector2(1.6, 1.6)
	_sprite.offset = Vector2(0, -18)
	_sprite.self_modulate = Color(0.78, 0.62, 1.0)
	add_child(_sprite)
	_sprite.play("idle")
	_crown = Sprite2D.new()
	_crown.texture = load("res://Assets/Generated/v12/boss_crown.png")
	_crown.position = Vector2(0, -50)
	_crown.scale = Vector2(1.4, 1.4)
	add_child(_crown)
	var l := PointLight2D.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	l.texture = gt
	l.texture_scale = 3.0
	l.color = Color(0.7, 0.4, 1.0)
	l.energy = 0.6
	l.position = Vector2(0, -24)
	add_child(l)
	_build_bar()
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("boss_roar", -2.0)
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.shake(4.0, 0.8)


func _build_bar() -> void:
	_bar_layer = CanvasLayer.new()
	_bar_layer.layer = 12
	add_child(_bar_layer)
	var font: Font = load("res://Assets/Fonts/nh_pixel_font.png")
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	root.position = Vector2(-260, 150)
	_bar_layer.add_child(root)
	var name := Label.new()
	name.text = "THE HOLLOW KING"
	name.add_theme_font_override("font", font)
	name.add_theme_font_size_override("font_size", 27)
	name.add_theme_color_override("font_color", Color("E0C8FF"))
	name.add_theme_color_override("font_outline_color", Color("1E1209"))
	name.add_theme_constant_override("outline_size", 8)
	name.position = Vector2(130, -36)
	root.add_child(name)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.04, 0.1, 0.9)
	bg.size = Vector2(520, 16)
	root.add_child(bg)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color("A06CFF")
	_bar_fill.position = Vector2(3, 3)
	_bar_fill.size = Vector2(514, 10)
	root.add_child(_bar_fill)


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	var p := _player()
	if p == null:
		return
	var to_p := p.global_position - global_position
	_state_t -= delta
	_touch_cd -= delta
	_crown.position.y = -50 + sin(Time.get_ticks_msec() * 0.004) * 1.5
	match _state:
		"intro":
			velocity = Vector2.ZERO
			if _state_t <= 0.0:
				_state = "chase"
		"chase":
			_sprite.play("walk")
			var spd := 34.0 if current_health > max_health / 2 else 46.0
			velocity = velocity.lerp(to_p.normalized() * spd, delta * 3.0)
			_sprite.flip_h = to_p.x < 0.0
			_slam_cd -= delta
			_charge_cd -= delta
			if _slam_cd <= 0.0 and to_p.length() < 90.0:
				_begin_slam()
			elif current_health < max_health / 2 and _charge_cd <= 0.0 and to_p.length() > 70.0:
				_state = "windup"
				_state_t = 0.7
				_charge_dir = to_p.normalized()
				_sprite.play("idle")
				_sprite.modulate = Color(1.6, 0.7, 0.7)
		"slam_windup":
			velocity = Vector2.ZERO
			if _state_t <= 0.0:
				_do_slam()
		"slam_recover":
			velocity = Vector2.ZERO
			if _state_t <= 0.0:
				_state = "chase"
		"windup":
			velocity = Vector2.ZERO
			if _state_t <= 0.0:
				_state = "charge"
				_state_t = 0.9
				_sprite.modulate = Color.WHITE
				if has_node("/root/GameAudio"):
					get_node("/root/GameAudio").play("heavy_swing", -4.0)
		"charge":
			_sprite.play("walk")
			velocity = _charge_dir * 230.0
			var juice := get_tree().get_first_node_in_group("juice")
			if juice and randf() < 0.4:
				juice.dust(global_position, 2)
			if _state_t <= 0.0 or get_slide_collision_count() > 0:
				if get_slide_collision_count() > 0 and juice:
					juice.shake(4.0, 0.3)
				_state = "slam_recover"
				_state_t = 1.0
				_charge_cd = randf_range(5.0, 8.0)
	move_and_slide()
	if to_p.length() < 20.0 and _touch_cd <= 0.0 and p.has_method("take_damage"):
		_touch_cd = 0.9
		p.take_damage(16 if _state != "charge" else 30, to_p.normalized(), 160.0)


func _begin_slam() -> void:
	_state = "slam_windup"
	_state_t = 0.9
	_sprite.play("slam")
	_ring = Node2D.new()
	_ring.set_script(load("res://scripts/systems/warning_ring.gd"))
	_ring.set("radius", 46.0)
	_ring.set("duration", 0.9)
	get_parent().add_child(_ring)
	_ring.global_position = global_position


func _do_slam() -> void:
	_state = "slam_recover"
	_state_t = 0.8
	_slam_cd = randf_range(3.0, 4.5)
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.shake(5.0, 0.35)
		juice.burst(global_position, Color(0.55, 0.45, 0.6), 20, 120.0)
		juice.dust(global_position, 10)
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("rock_break", -2.0)
	var p := _player()
	if p and p.global_position.distance_to(global_position) < 46.0 and p.has_method("take_damage"):
		p.take_damage(24, (p.global_position - global_position).normalized(), 220.0)


func take_damage(amount: int, direction: Vector2 = Vector2.ZERO, _knockback: float = 0.0) -> void:
	if is_dead or _state == "intro":
		return
	current_health = maxi(0, current_health - amount)
	_bar_fill.size.x = 514.0 * float(current_health) / float(max_health)
	_sprite.modulate = Color(2.0, 1.6, 2.0)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.12)
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.damage_number(global_position + Vector2(0, -20), amount, amount >= 40)
		juice.burst(global_position + Vector2(0, -20), Color(0.6, 0.4, 0.8), 6, 60.0)
		juice.hitstop(0.035)
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("sword_hit", -4.0)
	for threshold in [0.66, 0.33]:
		if float(current_health) / float(max_health) < threshold and not _summoned.has(threshold):
			_summoned[threshold] = true
			_summon()
	if current_health <= 0:
		_die()


func _summon() -> void:
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("boss_roar", -4.0)
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.shake(3.0, 0.5)
		juice.popup_text(global_position + Vector2(0, -60), "RISE, MY CHILDREN!", Color("E0C8FF"), true)
	for i in 3:
		var e: CharacterBody2D = CaveEnemyScript.new()
		e.setup("ghoul" if i < 2 else "skeleton", 15)
		get_parent().add_child(e)
		var pos := global_position + Vector2.from_angle(TAU * float(i) / 3.0) * 40.0
		if arena.has_area():
			pos = pos.clamp(arena.position + Vector2(24, 24), arena.end - Vector2(24, 24))
		e.global_position = pos


func _die() -> void:
	is_dead = true
	collision_layer = 0
	_sprite.play("dead")
	_bar_layer.queue_free()
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("boss_roar", -2.0)
		get_node("/root/GameAudio").play("mission", -4.0)
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.shake(6.0, 1.0)
		juice.burst(global_position + Vector2(0, -20), Color(0.7, 0.5, 1.0), 30, 140.0)
		juice.popup_text(global_position + Vector2(0, -60), "THE HOLLOW KING FALLS!", Color("FFDB80"), true)
	var parent := get_parent()
	for pair in [["hollow_crown", 1], ["gem", 3], ["crystal_shard", 4]]:
		var it = ItemDB.get_item(pair[0])
		if it:
			for i in pair[1]:
				var w := WorldItemScene.instantiate()
				parent.add_child(w)
				w.global_position = global_position
				w.call("set_item", it, 1)
	for i in 8:
		var c: Node2D = CoinScript.new()
		c.value = 50
		parent.add_child(c)
		c.global_position = global_position
		c.launch(Vector2.from_angle(randf() * TAU) * randf_range(30.0, 70.0))
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats:
		stats.add_xp(400)
	for e in get_tree().get_nodes_in_group("cave_enemies"):
		if e != self and is_instance_valid(e) and e.has_method("take_damage") and not e.get("is_dead"):
			e.take_damage(9999, Vector2.ZERO, 0.0)
	defeated.emit()
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(self, "modulate:a", 0.0, 1.0)
	tw.tween_callback(queue_free)
