extends Node2D

## LivingWorld (v1.2) — makes the map feel alive.
##
##  * Water ripples and sun glints (shader on the ground tiles).
##  * Wind: tree canopies rustle, tree sprites sway; the WeatherManager sets `wind`.
##  * Critters: butterflies by day, sparrows that peck and fly away when you get
##    close, fireflies at night, fish that jump in the rivers, falling leaves.
##
## Everything is spawned around the camera only, and the amount follows the
## graphics preset (Low = no critters or shaders, Medium = half, High = full).

const WATER_SHADER := preload("res://shaders/water_tiles.gdshader")
const FOLIAGE_SHADER := preload("res://shaders/foliage_tiles.gdshader")
const SWAY_SHADER := preload("res://shaders/sway_sprite.gdshader")
const GEN := "res://Assets/Generated/v12/"

const WATER_SOURCES := ["Water_Tile.png", "Water_Middle.png"]
const TREE_SOURCES := ["Oak_Tree.png"]

var wind: float = 1.0:
	set(v):
		wind = v
		_apply_wind()
var enabled_fx := true

var _game: Node2D
var _terrain: TileMapLayer
var _water_cells: Array[Vector2] = []
var _water_set: Dictionary = {}
var _tree_cells: Array[Vector2] = []
var _materials: Array[ShaderMaterial] = []
var _glow_layer: CanvasLayer
var _critters: Array[Dictionary] = []
var _fireflies: Array[Dictionary] = []
var _spawn_t := 0.0
var _fish_t := 3.0
var _leaf_t := 1.0
var _chirp_t := 6.0
var _tex := {}
var _glow_tex: GradientTexture2D
var _rng := RandomNumberGenerator.new()
var _sway_mat: ShaderMaterial
var _extra_ground: Array = []


func _ready() -> void:
	add_to_group("living_world")
	_game = get_parent() as Node2D
	_rng.randomize()
	y_sort_enabled = true
	for n in ["butterfly_b1", "butterfly_b2", "butterfly_b3", "butterfly_b4", "bird", "fish", "leaf", "splash", "ripple"]:
		_tex[n] = load(GEN + n + ".png")
	_glow_tex = _make_glow()
	_glow_layer = CanvasLayer.new()
	_glow_layer.name = "GlowLayer"
	_glow_layer.layer = 2
	_glow_layer.follow_viewport_enabled = true
	add_child(_glow_layer)
	call_deferred("_setup")


func _setup() -> void:
	_terrain = _game.get_node_or_null("TileMap/TerrainLayer") as TileMapLayer
	if _terrain:
		_scan_cells(_terrain, WATER_SOURCES, _water_cells, true)
	var tall := _game.get_node_or_null("TallThingsLayer") as TileMapLayer
	if tall:
		_scan_cells(tall, TREE_SOURCES, _tree_cells, false)
	_apply_shaders()
	if has_node("/root/GameSettings"):
		get_node("/root/GameSettings").changed.connect(_apply_shaders)


func _scan_cells(layer: TileMapLayer, names: Array, out: Array[Vector2], is_water: bool) -> void:
	var ids := {}
	for i in layer.tile_set.get_source_count():
		var sid := layer.tile_set.get_source_id(i)
		var src := layer.tile_set.get_source(sid)
		if src is TileSetAtlasSource and (src as TileSetAtlasSource).texture:
			var p: String = (src as TileSetAtlasSource).texture.resource_path
			for n in names:
				if p.ends_with(n):
					ids[sid] = true
	for c in layer.get_used_cells():
		if ids.has(layer.get_cell_source_id(c)):
			var wp := layer.to_global(layer.map_to_local(c))
			out.append(wp)
			if is_water:
				_water_set[c] = true


## Is this world position on a river/pond tile?
func is_water(world_pos: Vector2) -> bool:
	if not _terrain:
		return false
	return _water_set.has(_terrain.local_to_map(_terrain.to_local(world_pos)))


func _quality() -> float:
	if has_node("/root/GameSettings"):
		return float(get_node("/root/GameSettings").preset()["particles"])
	return 1.0


func _apply_shaders() -> void:
	enabled_fx = _quality() > 0.0
	_materials.clear()
	var water_layers := ["TileMap/TerrainLayer"]
	for path in water_layers:
		var l := _game.get_node_or_null(path) as CanvasItem
		if l:
			l.material = _mat(WATER_SHADER) if enabled_fx else null
	for path in ["TallThingsLayer"]:
		var l := _game.get_node_or_null(path) as CanvasItem
		if l:
			l.material = _mat(FOLIAGE_SHADER) if enabled_fx else null
	_sway_mat = _mat(SWAY_SHADER) if enabled_fx else null
	for t in get_tree().get_nodes_in_group("choppable_trees"):
		var spr := t.get_node_or_null("Sprite2D") as Sprite2D
		if spr:
			spr.material = _sway_mat
	for l in _extra_ground:
		if is_instance_valid(l):
			(l as CanvasItem).material = _mat(WATER_SHADER) if enabled_fx else null
	_apply_wind()


## v1.3: trees spawned by the world generator sway like the hand-placed ones.
func add_tree_sway(tree: Node) -> void:
	if not enabled_fx:
		return
	var spr := tree.get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return
	if _sway_mat == null:
		_sway_mat = _mat(SWAY_SHADER)
		_apply_wind()
	spr.material = _sway_mat


## v1.3: generated ground (water ripples on the generated lakes and rivers).
func add_ground_layer(layer: CanvasItem) -> void:
	_extra_ground.append(layer)
	layer.material = _mat(WATER_SHADER) if enabled_fx else null
	_apply_wind()


func _mat(sh: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	_materials.append(m)
	return m


func _apply_wind() -> void:
	for m in _materials:
		m.set_shader_parameter("wind", wind)


func _make_glow() -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 32
	t.height = 32
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


# ==========================================================================
# Critters
# ==========================================================================

func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _outdoors() -> bool:
	var w := get_tree().get_first_node_in_group("nh_world")
	if w and w.has_method("is_player_indoors") and w.is_player_indoors():
		return false
	var mines := get_tree().get_first_node_in_group("mines")
	if mines and mines.get("active"):
		return false
	return true


func _clock() -> Node:
	return get_tree().get_first_node_in_group("game_clock")


func _is_night() -> bool:
	var c := _clock()
	return c != null and c.is_night()


func _raining() -> bool:
	var w := get_tree().get_first_node_in_group("weather")
	return w != null and w.has_method("is_raining") and w.is_raining()


func _process(delta: float) -> void:
	var p := _player()
	if p == null:
		return
	var q := _quality()
	var outdoors := _outdoors()
	_update_critters(delta, p)
	_update_fireflies(delta, p)
	if q <= 0.0 or not outdoors:
		return
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = 0.6
		_spawn_ambient(p, q)
	_fish_t -= delta
	if _fish_t <= 0.0:
		_fish_t = _rng.randf_range(3.5, 8.0) / q
		_fish_jump(p)
	_leaf_t -= delta
	if _leaf_t <= 0.0:
		_leaf_t = _rng.randf_range(0.35, 0.9) / (q * maxf(0.5, wind))
		_drop_leaf(p)
	_chirp_t -= delta
	if _chirp_t <= 0.0:
		_chirp_t = _rng.randf_range(6.0, 14.0)
		if not _is_night() and not _raining() and _count("bird") > 0:
			_sfx("bird_chirp", -16.0)


func _count(kind: String) -> int:
	var n := 0
	for c in _critters:
		if c["kind"] == kind:
			n += 1
	return n


func _spawn_ambient(p: Node2D, q: float) -> void:
	var night := _is_night()
	var rain := _raining()
	if not night and not rain:
		if _count("butterfly") < int(6 * q):
			_spawn_butterfly(p.global_position + _ring(90, 200))
		if _count("bird") < int(4 * q):
			var pos := p.global_position + _ring(110, 220)
			if not is_water(pos):
				_spawn_bird(pos)
	if night and _fireflies.size() < int(16 * q) and not rain:
		_spawn_firefly(p.global_position + _ring(40, 220))


func _ring(rmin: float, rmax: float) -> Vector2:
	return Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(rmin, rmax)


func _strip_frame(tex: Texture2D, idx: int, w: int, h: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(idx * w, 0, w, h)
	return a


func _spawn_butterfly(pos: Vector2) -> void:
	var s := Sprite2D.new()
	var tex: Texture2D = _tex["butterfly_b%d" % _rng.randi_range(1, 4)]
	s.texture = _strip_frame(tex, 0, 7, 6)
	s.z_index = 5
	s.global_position = pos
	s.modulate.a = 0.0
	add_child(s)
	_critters.append({"kind": "butterfly", "node": s, "tex": tex, "t": _rng.randf() * 10.0,
		"home": pos, "vel": Vector2.ZERO, "life": _rng.randf_range(18.0, 40.0)})


func _spawn_bird(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = _strip_frame(_tex["bird"], 0, 10, 8)
	s.offset = Vector2(0, -4)
	s.global_position = pos
	s.flip_h = _rng.randf() < 0.5
	s.modulate.a = 0.0
	add_child(s)
	_critters.append({"kind": "bird", "node": s, "t": _rng.randf() * 3.0, "state": "sit",
		"vel": Vector2.ZERO, "life": _rng.randf_range(25.0, 60.0)})


func _spawn_firefly(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = _glow_tex
	s.scale = Vector2(0.28, 0.28)
	s.modulate = Color(0.9, 1.0, 0.45, 0.0)
	_glow_layer.add_child(s)
	s.global_position = pos
	_fireflies.append({"node": s, "t": _rng.randf() * 10.0, "home": pos, "life": _rng.randf_range(12.0, 30.0)})


func _update_critters(delta: float, p: Node2D) -> void:
	var keep: Array[Dictionary] = []
	var outdoors := _outdoors()
	for c in _critters:
		var s: Sprite2D = c["node"]
		if not is_instance_valid(s):
			continue
		c["t"] = float(c["t"]) + delta
		c["life"] = float(c["life"]) - delta
		var far := s.global_position.distance_to(p.global_position) > 380.0
		var dying: bool = c["life"] <= 0.0 or far or not outdoors
		match c["kind"]:
			"butterfly":
				var t: float = c["t"]
				var home: Vector2 = c["home"]
				var target := home + Vector2(sin(t * 0.7) * 30.0, cos(t * 0.53) * 18.0)
				var v: Vector2 = c["vel"]
				v = v.lerp((target - s.global_position) * 0.9 + Vector2(wind * 6.0, sin(t * 6.0) * 10.0), delta * 2.0)
				c["vel"] = v
				s.global_position += v * delta
				s.texture = _strip_frame(c["tex"], int(t * 8.0) % 2, 7, 6)
				s.flip_h = v.x < 0.0
			"bird":
				var t: float = c["t"]
				if c["state"] == "sit":
					var frame := 1 if fmod(t, 2.3) < 0.25 else 0
					s.texture = _strip_frame(_tex["bird"], frame, 10, 8)
					if fmod(t, 4.0) < delta:
						s.flip_h = _rng.randf() < 0.5
					if s.global_position.distance_to(p.global_position) < 44.0 or (_is_night() and _rng.randf() < 0.01):
						c["state"] = "fly"
						var away := (s.global_position - p.global_position).normalized()
						c["vel"] = (away + Vector2(0, -0.9)).normalized() * 120.0
						s.flip_h = away.x < 0.0
						_sfx("bird_flap", -12.0)
				else:
					var v: Vector2 = c["vel"]
					v.y -= 30.0 * delta
					c["vel"] = v
					s.global_position += v * delta
					s.z_index = 20
					s.texture = _strip_frame(_tex["bird"], 2 + int(t * 12.0) % 2, 10, 8)
					if c["t"] > 0.0 and s.global_position.distance_to(p.global_position) > 260.0:
						dying = true
			"leaf":
				var v: Vector2 = c["vel"]
				var t: float = c["t"]
				s.global_position += Vector2(v.x + sin(t * 3.0) * 12.0 + wind * 8.0, v.y) * delta
				s.rotation = sin(t * 4.0) * 0.6
				if t > float(c["fall"]):
					s.modulate.a = maxf(0.0, s.modulate.a - delta * 1.5)
					if s.modulate.a <= 0.0:
						dying = true
						s.modulate.a = 0.0
			"fx":
				var t: float = c["t"]
				var frames: int = c["frames"]
				var idx := int(t * float(c["fps"]))
				if idx >= frames:
					dying = true
					s.modulate.a = 0.0
				else:
					s.texture = _strip_frame(c["tex"], idx, c["w"], c["h"])
			"fish":
				var t: float = c["t"]
				var dur: float = c["dur"]
				var k := t / dur
				var a: Vector2 = c["from"]
				var b: Vector2 = c["to"]
				s.global_position = a.lerp(b, k) + Vector2(0, -sin(k * PI) * 14.0)
				s.texture = _strip_frame(_tex["fish"], 0 if k < 0.5 else 1, 8, 5)
				s.rotation = lerpf(-0.8, 0.8, k) * (1.0 if b.x > a.x else -1.0)
				if k >= 1.0:
					_fx(b, "splash", 6, 5, 3, 12.0)
					_fx(b, "ripple", 8, 6, 2, 4.0)
					dying = true
					s.modulate.a = 0.0
		# fade in / out
		if dying:
			s.modulate.a = maxf(0.0, s.modulate.a - delta * 2.5)
			if s.modulate.a <= 0.0:
				s.queue_free()
				continue
		elif s.modulate.a < 1.0:
			s.modulate.a = minf(1.0, s.modulate.a + delta * 2.0)
		keep.append(c)
	_critters = keep


func _update_fireflies(delta: float, p: Node2D) -> void:
	var keep: Array[Dictionary] = []
	var night := _is_night() and _outdoors()
	for f in _fireflies:
		var s: Sprite2D = f["node"]
		if not is_instance_valid(s):
			continue
		f["t"] = float(f["t"]) + delta
		f["life"] = float(f["life"]) - delta
		var t: float = f["t"]
		var home: Vector2 = f["home"]
		s.global_position = home + Vector2(sin(t * 0.6) * 24.0 + cos(t * 1.7) * 6.0, cos(t * 0.45) * 16.0 + sin(t * 2.3) * 4.0)
		var pulse := 0.35 + 0.65 * maxf(0.0, sin(t * 2.2 + float(f["home"].x)))
		var fading: bool = f["life"] <= 0.0 or not night or s.global_position.distance_to(p.global_position) > 360.0
		var a := s.modulate.a
		a = maxf(0.0, a - delta) if fading else minf(pulse, a + delta)
		s.modulate.a = a
		if fading and a <= 0.0:
			s.queue_free()
			continue
		keep.append(f)
	_fireflies = keep


func _fish_jump(p: Node2D) -> void:
	if _water_cells.is_empty() or _is_night():
		return
	var near: Array[Vector2] = []
	for c in _water_cells:
		var d := c.distance_to(p.global_position)
		if d > 40.0 and d < 230.0:
			near.append(c)
	if near.is_empty():
		return
	var a: Vector2 = near[_rng.randi() % near.size()] + Vector2(_rng.randf_range(-5, 5), _rng.randf_range(-4, 4))
	var b := a + Vector2(_rng.randf_range(10, 18) * (1.0 if _rng.randf() < 0.5 else -1.0), 0)
	if not is_water(b):
		b = a + Vector2(2, 0)
	var s := Sprite2D.new()
	s.texture = _strip_frame(_tex["fish"], 0, 8, 5)
	s.z_index = 3
	s.global_position = a
	add_child(s)
	_critters.append({"kind": "fish", "node": s, "t": 0.0, "dur": 0.55, "from": a, "to": b, "life": 5.0})
	_fx(a, "ripple", 8, 6, 2, 4.0)
	if a.distance_to(p.global_position) < 150.0:
		_sfx("splash", -14.0)


func _drop_leaf(p: Node2D) -> void:
	if _tree_cells.is_empty():
		return
	var vp := get_viewport_rect().size
	var cam := get_viewport().get_camera_2d()
	var half := vp / (cam.zoom if cam else Vector2.ONE) * 0.5
	var center := cam.get_screen_center_position() if cam else p.global_position
	for _i in 6:
		var c: Vector2 = _tree_cells[_rng.randi() % _tree_cells.size()]
		if absf(c.x - center.x) < half.x + 16.0 and absf(c.y - center.y) < half.y + 16.0:
			var s := Sprite2D.new()
			s.texture = _strip_frame(_tex["leaf"], _rng.randi() % 3, 4, 4)
			s.z_index = 20
			s.global_position = c + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-12, 0))
			add_child(s)
			_critters.append({"kind": "leaf", "node": s, "t": 0.0, "vel": Vector2(_rng.randf_range(-4, 4), _rng.randf_range(10, 18)),
				"fall": _rng.randf_range(1.6, 2.8), "life": 6.0})
			return


## One-shot sprite-strip effect (splash, ripple, dust...). Public: other systems use it.
func _fx(pos: Vector2, tex_name: String, w: int, h: int, frames: int, fps: float) -> void:
	if not _tex.has(tex_name):
		_tex[tex_name] = load(GEN + tex_name + ".png")
	var s := Sprite2D.new()
	s.texture = _strip_frame(_tex[tex_name], 0, w, h)
	s.z_index = 2
	s.global_position = pos
	add_child(s)
	_critters.append({"kind": "fx", "node": s, "t": 0.0, "tex": _tex[tex_name], "w": w, "h": h, "frames": frames, "fps": fps, "life": 3.0})


func play_fx(pos: Vector2, tex_name: String, w: int, h: int, frames: int, fps: float) -> void:
	if _quality() <= 0.0:
		return
	_fx(pos, tex_name, w, h, frames, fps)


func _sfx(n: String, db: float) -> void:
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play(n, db)
