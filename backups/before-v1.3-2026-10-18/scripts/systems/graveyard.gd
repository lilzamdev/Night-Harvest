extends Node2D

## Old Hollow Cemetery — a haunted graveyard in the north-west field.
## At night the dead claw their way out of its open graves and head for your farm,
## so the threat now comes from two sides (the quarry in the north-east and here).

const GEN := "res://Assets/Generated/"
## Fenced area (global coordinates).
const AREA := Rect2(-1060, -322, 208, 112)
const GATE_W := 32.0

var _graves: Array[Vector2] = []
var _timer: Timer
var _clock: Node
var _spawner: Node
var _crypt_light: PointLight2D
var _fog: CPUParticles2D


func _ready() -> void:
	y_sort_enabled = true
	_build_ground()
	_build_fence()
	_build_props()
	_timer = Timer.new()
	_timer.wait_time = 70.0
	_timer.timeout.connect(_rise_wave)
	add_child(_timer)
	call_deferred("_bind")


func _bind() -> void:
	_clock = get_tree().get_first_node_in_group("game_clock")
	_spawner = get_tree().get_first_node_in_group("spawn_manager")
	if _clock:
		_clock.night_started.connect(_on_night)
		_clock.night_ended.connect(_on_day)
		if _clock.is_night():
			_on_night()
		else:
			_on_day()


func _tex(name: String) -> Texture2D:
	return load(GEN + name + ".png")


func _sprite(tex: Texture2D, pos: Vector2, solid: Vector2 = Vector2.ZERO) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
	add_child(s)
	s.global_position = pos
	if solid != Vector2.ZERO:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = solid
		cs.shape = rs
		cs.position = Vector2(0, -solid.y * 0.5)
		body.add_child(cs)
		s.add_child(body)
	return s


func _build_ground() -> void:
	# Patchy dead earth, drawn just above the tile map (origin far up so y-sort keeps it behind everything).
	var w := int(AREA.size.x) + 24
	var h := int(AREA.size.y) + 24
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1031
	var cols := [Color("3d4a2e"), Color("44502f"), Color("4b4a32"), Color("39402c"), Color("524a34")]
	for y in h:
		for x in w:
			var edge := minf(minf(x, w - 1 - x), minf(y, h - 1 - y))
			var keep := edge > 6.0 or rng.randf() < edge / 6.0 * 0.85
			if keep:
				var c: Color = cols[rng.randi() % cols.size()]
				img.set_pixel(x, y, Color(c, 0.92))
	for i in 90:
		var px := rng.randi_range(4, w - 5)
		var py := rng.randi_range(4, h - 5)
		img.set_pixel(px, py, Color("5f6b45"))
		img.set_pixel(px + 1, py, Color("6f7b50"))
	var holder := Node2D.new()
	add_child(holder)
	holder.global_position = Vector2(AREA.position.x - 12, -20000)
	var spr := Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(img)
	spr.centered = false
	holder.add_child(spr)
	spr.global_position = AREA.position - Vector2(12, 12)


func _build_fence() -> void:
	var fence := _tex("iron_fence")
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var x := AREA.position.x
	var gate_l := AREA.get_center().x - GATE_W * 0.5
	var gate_r := AREA.get_center().x + GATE_W * 0.5
	while x < AREA.end.x:
		_sprite(fence, Vector2(x + 8, AREA.position.y + 4))
		if x + 16 <= gate_l or x >= gate_r:
			_sprite(fence, Vector2(x + 8, AREA.end.y + 4))
		x += 16.0
	_add_rect(body, Rect2(AREA.position.x, AREA.position.y - 6, AREA.size.x, 8))
	_add_rect(body, Rect2(AREA.position.x, AREA.end.y - 6, gate_l - AREA.position.x, 8))
	_add_rect(body, Rect2(gate_r, AREA.end.y - 6, AREA.end.x - gate_r, 8))
	# Side posts
	var post := AtlasTexture.new()
	post.atlas = fence
	post.region = Rect2(0, 0, 3, 16)
	var y := AREA.position.y + 8
	while y < AREA.end.y:
		_sprite(post, Vector2(AREA.position.x + 1, y + 4))
		_sprite(post, Vector2(AREA.end.x - 1, y + 4))
		y += 10.0
	_add_rect(body, Rect2(AREA.position.x - 2, AREA.position.y, 5, AREA.size.y))
	_add_rect(body, Rect2(AREA.end.x - 3, AREA.position.y, 5, AREA.size.y))


func _add_rect(body: StaticBody2D, r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	cs.shape = rs
	cs.global_position = r.get_center()
	body.add_child(cs)
	cs.global_position = r.get_center()


func _build_props() -> void:
	var c := AREA.get_center()
	_sprite(_tex("crypt"), Vector2(c.x, AREA.position.y + 34), Vector2(22, 12))
	_crypt_light = PointLight2D.new()
	_crypt_light.texture = _glow_tex()
	_crypt_light.color = Color(0.5, 0.75, 1.0)
	_crypt_light.energy = 0.0
	_crypt_light.texture_scale = 1.4
	add_child(_crypt_light)
	_crypt_light.global_position = Vector2(c.x, AREA.position.y + 26)
	_sprite(_tex("dead_tree"), Vector2(AREA.position.x + 18, AREA.position.y + 30), Vector2(6, 4))
	_sprite(_tex("dead_tree"), Vector2(AREA.end.x - 22, AREA.position.y + 36), Vector2(6, 4)).flip_h = true
	var kinds := ["tomb_round", "tomb_cross", "tomb_slab", "tomb_round", "tomb_cross"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var i := 0
	for row in 3:
		for col in 6:
			var px := AREA.position.x + 22 + col * 33
			var py := AREA.position.y + 52 + row * 22
			if absf(px - c.x) < 22 and row == 0:
				continue
			if absf(px - c.x) < 14:
				continue  # keep the central path clear
			var pos := Vector2(px + rng.randi_range(-3, 3), py + rng.randi_range(-2, 2))
			if (row * 6 + col) % 5 == 2:
				_sprite(_tex("grave_dirt"), pos + Vector2(0, 4))
				_graves.append(pos)
			else:
				_sprite(_tex(kinds[i % kinds.size()]), pos, Vector2(10, 4))
				i += 1
	for k in 6:
		var sk := _sprite(_tex("skull"), Vector2(rng.randf_range(AREA.position.x + 10, AREA.end.x - 10), rng.randf_range(AREA.position.y + 46, AREA.end.y - 10)))
		sk.flip_h = rng.randf() < 0.5
	if _graves.is_empty():
		_graves.append(c)
	_fog = CPUParticles2D.new()
	_fog.amount = 10
	_fog.lifetime = 9.0
	_fog.preprocess = 9.0
	_fog.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_fog.emission_rect_extents = AREA.size * 0.5
	_fog.direction = Vector2(1, 0)
	_fog.spread = 15.0
	_fog.gravity = Vector2.ZERO
	_fog.initial_velocity_min = 3.0
	_fog.initial_velocity_max = 7.0
	_fog.scale_amount_min = 2.5
	_fog.scale_amount_max = 4.5
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.75, 0.8, 0.95, 0.0), Color(0.75, 0.8, 0.95, 0.09), Color(0.75, 0.8, 0.95, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	_fog.color_ramp = g
	_fog.texture = _glow_tex()
	_fog.z_index = 6
	add_child(_fog)
	_fog.global_position = c


func _glow_tex() -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 32
	t.height = 32
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


func _on_night() -> void:
	_crypt_light.energy = 1.1
	_fog.amount = 22
	_timer.start()
	_rise_wave()


func _on_day() -> void:
	_crypt_light.energy = 0.0
	_timer.stop()


func _night_number() -> int:
	var d := get_tree().get_first_node_in_group("night_director")
	if d:
		return int(d.tonight) if int(d.tonight) > 0 else d.night_number()
	return 1


func _rise_wave() -> void:
	if not _spawner or not _spawner.has_method("spawn_zombie_at"):
		return
	var n := _night_number()
	var count := clampi(1 + n / 2, 1, 6)
	for k in count:
		var pos: Vector2 = _graves[k % _graves.size()] + Vector2(randf_range(-4, 4), 6)
		var z: Node2D = _spawner.spawn_zombie_at(pos)
		if z:
			_rise_fx(z)


func _rise_fx(z: Node2D) -> void:
	var spr: Node2D = z.get_node_or_null("AnimatedSprite2D")
	if spr:
		var base_y := spr.position.y
		spr.position.y = base_y + 10.0
		var tw := z.create_tween()
		tw.tween_property(spr, "position:y", base_y, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 12
	p.lifetime = 0.7
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 60.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 45.0
	p.gravity = Vector2(0, 120)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 2.5
	p.color = Color("5a3a2a")
	add_child(p)
	p.global_position = z.global_position
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)
