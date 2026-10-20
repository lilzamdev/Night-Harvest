extends Node2D

const LightLevel = preload("res://scripts/systems/light_level.gd")

## VillageLights (v1.3.1): at dusk the houses of Harvest Village light their windows
## and the street lamps come on; at dawn they go out again.
##
## Nothing is hand-placed: the village map's tiles are scanned once. Window glass is
## found by its colour in the building art and gets a warm overlay plus a small light;
## street lamps and crate lanterns get a lamp light at their head.

const LAMP_REGIONS := {
	# objects_demo.png: street lamp head, lantern on a crate
	"objects_demo.png": [Rect2i(32, 32, 16, 16), Rect2i(48, 32, 16, 16)],
	# v1.4.1: the tall iron lamp posts around the farm
	"Outdoor_Decor_Free.png": [Rect2i(64, 64, 16, 16)],
	# vectoraith buildings: black street lamp head, hanging lanterns
	"vectoraith_tileset_farmingsims_buildings.png": [Rect2i(112, 0, 16, 16), Rect2i(80, 80, 16, 16), Rect2i(112, 80, 16, 16), Rect2i(96, 128, 16, 16)],
}
const BUILDING_SHEETS := ["premade_buildings_demo.png", "vectoraith_tileset_farmingsims_buildings.png", "House_1_Wood_Base_Blue.png"]
const WINDOW_GLOW := Color(1.0, 0.82, 0.46)
const LAMP_COLOR := Color(1.0, 0.74, 0.42)

var save_key := ""   # nothing to save
var _windows: Array[Sprite2D] = []
var _lights: Array[PointLight2D] = []
var _lit := false
var _level := 0.0
var _clock: Node
static var _glow_tex: GradientTexture2D
static var _img_cache := {}
static var _mask_cache := {}


func _ready() -> void:
	add_to_group("village_lights")
	global_position = Vector2.ZERO
	call_deferred("_scan")


func _light_texture() -> GradientTexture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.width = 128
		_glow_tex.height = 128
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(0.5, 0.0)
	return _glow_tex


func _scan() -> void:
	var game := get_parent()
	if game == null:
		return
	for layer in game.find_children("*", "TileMapLayer", true, false):
		var tl := layer as TileMapLayer
		# houses and lamps live on the village's object layers (not the ground)
		if tl.tile_set == null or not (tl.name.contains("Tall") or tl.name == "ThingsLayer"):
			continue
		for cell in tl.get_used_cells():
			var src = tl.tile_set.get_source(tl.get_cell_source_id(cell))
			if not (src is TileSetAtlasSource) or src.texture == null:
				continue
			var sheet: String = src.texture.resource_path.get_file()
			var coords := tl.get_cell_atlas_coords(cell)
			var region: Rect2i = src.get_tile_texture_region(coords)
			var td: TileData = src.get_tile_data(coords, tl.get_cell_alternative_tile(cell))
			var origin := Vector2(td.texture_origin) if td else Vector2.ZERO
			var center := tl.to_global(tl.map_to_local(cell)) - origin
			if LAMP_REGIONS.has(sheet) and region in LAMP_REGIONS[sheet]:
				_add_light(center + Vector2(0, 6 if sheet == "Outdoor_Decor_Free.png" else -2), 0.95, 1.05)
				continue
			if sheet in BUILDING_SHEETS:
				var mask: Dictionary = _window_mask(src.texture, region)
				if mask.is_empty():
					continue
				var spr := Sprite2D.new()
				spr.texture = mask["tex"]
				spr.centered = true
				spr.modulate = Color(1, 1, 1, 0)
				spr.visible = false
				# drawn right over the tile: same parent, sorted a hair in front of it
				var sort_y := float(td.y_sort_origin) if td else 0.0
				spr.position = tl.map_to_local(cell) - origin + Vector2(0, sort_y + 0.25)
				spr.offset = Vector2(0, -(sort_y + 0.25))
				tl.add_child(spr)
				_windows.append(spr)
				_window_spots.append(center + mask["centroid"])
	_add_house_lights()
	_bind_clock()


var _window_spots: Array[Vector2] = []

## One soft light per house (windows within ~40 px are grouped) keeps the light count
## low - the Compatibility renderer only lets 8 lights touch each tile quadrant.
func _add_house_lights() -> void:
	var groups: Array = []   # [sum, count]
	for p in _window_spots:
		var placed := false
		for g in groups:
			if (g[0] / float(g[1])).distance_to(p) < 40.0:
				g[0] += p
				g[1] += 1
				placed = true
				break
		if not placed:
			groups.append([p, 1])
	for g in groups:
		var n: int = g[1]
		_add_light(g[0] / float(n), clampf(0.42 + n * 0.05, 0.42, 0.8), 0.75)
	_window_spots.clear()


func _image_of(tex: Texture2D) -> Image:
	var key := tex.resource_path
	if not _img_cache.has(key):
		var img := tex.get_image()
		if img and img.is_compressed():
			img.decompress()
		_img_cache[key] = img
	return _img_cache[key]


## Window glass inside a tile region -> {tex: warm overlay, centroid: offset from the tile centre}
func _window_mask(tex: Texture2D, region: Rect2i) -> Dictionary:
	var key := "%s|%s" % [tex.resource_path, region]
	if _mask_cache.has(key):
		return _mask_cache[key]
	var img := _image_of(tex)
	var res := {}
	if img:
		var out := Image.create(region.size.x, region.size.y, false, Image.FORMAT_RGBA8)
		var n := 0
		var solid := 0
		var sum := Vector2.ZERO
		var lo := Vector2i(999, 999)
		var hi := Vector2i(-1, -1)
		for y in region.size.y:
			for x in region.size.x:
				var c := img.get_pixel(region.position.x + x, region.position.y + y)
				if c.a < 0.8:
					continue
				solid += 1
				if _is_glass(c):
					n += 1
					sum += Vector2(x, y)
					lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
					hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
					var bright := clampf((c.b - 0.55) * 2.2, 0.0, 1.0)
					out.set_pixel(x, y, WINDOW_GLOW.lerp(Color(1.0, 0.95, 0.75), bright))
		# Real windows are small; a tile that is mostly blue is a roof or water
		var bw := hi.x - lo.x + 1
		var bh := hi.y - lo.y + 1
		# a long flat strip of blue is water in a trough or a pond, not a window
		var strip := bw >= 10 and bw >= bh * 3
		if n >= 3 and n <= maxi(8, solid * 6 / 10) and not strip:
			res = {"tex": ImageTexture.create_from_image(out),
				"centroid": sum / float(n) - Vector2(region.size) * 0.5 + Vector2(0.5, 0.5)}
	_mask_cache[key] = res
	return res


static func _is_glass(c: Color) -> bool:
	# cyan / sky-blue glass, clearly bluer than it is red
	return c.b >= 0.47 and c.b - c.r >= 0.17 and c.g >= c.r and c.b >= c.g - 0.1


func _add_light(pos: Vector2, scale: float, energy: float) -> void:
	var l := PointLight2D.new()
	l.texture = _light_texture()
	l.texture_scale = scale
	l.color = LAMP_COLOR
	l.energy = 0.0
	l.set_meta("full", energy)
	l.enabled = false
	l.shadow_enabled = false
	add_child(l)
	l.global_position = pos
	_lights.append(l)


func _bind_clock() -> void:
	_clock = get_tree().get_first_node_in_group("game_clock")
	_lit = _should_be_lit()
	_level = _want()
	_apply()


func _should_be_lit() -> bool:
	return LightLevel.level(get_tree()) > 0.02


## v1.4.1: how bright to be - follows how dark it really is (dusk, storms, night).
func _want() -> float:
	return LightLevel.level(get_tree())


func _process(delta: float) -> void:
	if _clock == null:
		return
	var want := _want()
	if absf(want - _level) < 0.005:
		return
	_level = move_toward(_level, want, delta * 0.8)
	_apply()


func _apply() -> void:
	for w in _windows:
		if is_instance_valid(w):
			w.visible = _level > 0.01
			w.modulate.a = _level
	for l in _lights:
		if is_instance_valid(l):
			l.enabled = _level > 0.01
			l.energy = float(l.get_meta("full")) * _level * (0.94 + randf() * 0.06)


func lamp_positions() -> Array:
	var out := []
	for l in _lights:
		if float(l.get_meta("full")) > 1.0:
			out.append(l.global_position)
	return out


func light_count() -> int:
	return _lights.size()


func window_count() -> int:
	return _windows.size()
