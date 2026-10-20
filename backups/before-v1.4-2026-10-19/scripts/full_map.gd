extends Control
class_name FullMapUI

signal map_opened
signal map_closed

## Fallback view, used only if no tile map is found.
@export var map_center: Vector2 = Vector2(80, 0)
@export var map_zoom: float = 0.52
## When on, the map zooms to fit the playable world.
@export var fit_whole_world: bool = true
## When on, the map shows only the area inside the world boundary
## (the same edge the gameplay camera stops at). Off = every tile map layer.
@export var crop_to_boundary: bool = true
## Color drawn over everything outside the boundary.
@export var outside_color: Color = Color(0.06, 0.08, 0.07, 1)
## Empty space kept around the world edges, as a fraction of the map area.
@export_range(0.0, 0.2, 0.01) var fit_margin: float = 0.02

var is_open: bool = false
var target: Node2D = null

@onready var modal_panel: PanelContainer = $CenterContainer/MapWindow
@onready var map_area: Control = $CenterContainer/MapWindow/MarginContainer/VBoxContainer/MapClip/MapArea
@onready var sub_viewport: SubViewport = $CenterContainer/MapWindow/MarginContainer/VBoxContainer/MapClip/MapArea/SubViewportContainer/SubViewport
@onready var map_camera: Camera2D = $CenterContainer/MapWindow/MarginContainer/VBoxContainer/MapClip/MapArea/SubViewportContainer/SubViewport/MapCamera
@onready var player_indicator: Control = $CenterContainer/MapWindow/MarginContainer/VBoxContainer/MapClip/MapArea/PlayerIndicator
@onready var player_arrow: Label = $CenterContainer/MapWindow/MarginContainer/VBoxContainer/MapClip/MapArea/PlayerIndicator/MarkerBox/ArrowLabel
@onready var poi_container: Control = $CenterContainer/MapWindow/MarginContainer/VBoxContainer/MapClip/MapArea/POIContainer
@onready var close_button: Button = $CenterContainer/MapWindow/MarginContainer/VBoxContainer/Header/CloseButton

# Landmark POIs in global world coordinates, in label priority order
# (earlier entries get the best spot when labels would overlap).
const LANDMARKS: Array[Dictionary] = [
	{ "name": "Player Cabin", "icon": "🏠", "pos": Vector2(-4, -150), "color": Color(0.3, 0.7, 1.0) },
	{ "name": "Storage Chest", "icon": "📦", "pos": Vector2(51, -115), "color": Color(1.0, 0.8, 0.2) },
	{ "name": "Farmland", "icon": "🌾", "pos": Vector2(67, 28), "color": Color(0.4, 0.9, 0.3) },
	{ "name": "Pasture / Coop", "icon": "🐔", "pos": Vector2(115, 120), "color": Color(1.0, 0.6, 0.3) },
	{ "name": "Village", "icon": "🏘", "pos": Vector2(-768, 243), "color": Color(0.95, 0.75, 0.55) },
	{ "name": "Old Barn", "icon": "🐄", "pos": Vector2(-398, -167), "color": Color(0.95, 0.45, 0.35) },
	{ "name": "Zombie Quarry", "icon": "⛏", "pos": Vector2(668, -137), "color": Color(0.75, 0.55, 0.95) },
	{ "name": "Deep Forest", "icon": "🌲", "pos": Vector2(450, 100), "color": Color(0.2, 0.8, 0.5) },
]

## Gap between a landmark's dot and its label, in map pixels.
const LABEL_GAP := 5.0

# --- v1.3 endless world: an explored-area map instead of the live view ----
var _wg: Node = null
var _scale := 2.0
var _origin := Vector2i.ZERO     # top-left tile of the map window
var _tex_rect: TextureRect
var _img: Image
var _pending: Array[Vector2i] = []
var _marks: Control
var _built_at := Vector2i(999999, 999999)

var _poi_nodes: Array[Control] = []
var _poi_dots: Array[Control] = []
var _world_rect: Rect2 = Rect2()
var _outside_mask: Control = null


func _ready() -> void:
	add_to_group("full_map_ui")
	add_to_group("map_ui")
	visible = false
	modulate.a = 0.0
	_create_outside_mask()

	if close_button:
		close_button.pressed.connect(close_map)
	
	call_deferred("_setup_world_viewport")
	call_deferred("_spawn_landmarks")
	_locate_player()
	call_deferred("_setup_endless")


func _setup_endless() -> void:
	_wg = get_tree().get_first_node_in_group("worldgen")
	if _wg == null or not map_area:
		return
	_tex_rect = TextureRect.new()
	_tex_rect.name = "WorldTexture"
	_tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	map_area.add_child(_tex_rect)
	var svc := map_area.get_node_or_null("SubViewportContainer")
	if svc:
		map_area.move_child(_tex_rect, svc.get_index() + 1)
	_marks = Control.new()
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_area.add_child(_marks)
	map_area.move_child(_marks, _tex_rect.get_index() + 1)
	_marks.draw.connect(_draw_marks)
	var sub := find_child("SubtitleLabel", true, false) as Label
	if sub:
		sub.text = "Explored world · mouse wheel to zoom"


func _endless() -> bool:
	return _wg != null and is_instance_valid(_wg) and _tex_rect != null


## Tiles shown across the map window at the current zoom.
func _view_tiles() -> Vector2i:
	var a := map_area.size if map_area.size.x > 10.0 else Vector2(716, 380)
	return Vector2i(ceili(a.x / _scale), ceili(a.y / _scale))


func _rebuild_endless() -> void:
	if not is_instance_valid(target):
		return
	var center: Vector2i = _wg.tile_of(target.global_position)
	if absf(target.global_position.x) > 150000.0 or absf(target.global_position.y) > 150000.0:
		center = _wg.tile_of(_wg.spawn_world_pos())
	var vt := _view_tiles()
	_origin = center - vt / 2
	_built_at = center
	_img = Image.create(vt.x, vt.y, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0.07, 0.08, 0.08))
	_pending.clear()
	var c0 := Vector2i(floori(float(_origin.x) / 16.0), floori(float(_origin.y) / 16.0))
	var c1 := Vector2i(floori(float(_origin.x + vt.x) / 16.0), floori(float(_origin.y + vt.y) / 16.0))
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var ck := Vector2i(cx, cy)
			if not _wg.is_explored(ck):
				continue
			if _wg.has_map_image(ck):
				_blit_chunk(ck)
			else:
				_pending.append(ck)
	if _wg.village_found:
		var vimg: Image = _wg.village_map_image()
		var vr: Rect2i = _wg.VILLAGE
		_img.blend_rect(vimg, Rect2i(Vector2i.ZERO, vimg.get_size()), vr.position - _origin)
	_tex_rect.texture = ImageTexture.create_from_image(_img)
	_marks.queue_redraw()


func _blit_chunk(ck: Vector2i) -> void:
	var cimg: Image = _wg.chunk_map_image(ck)
	_img.blend_rect(cimg, Rect2i(0, 0, 16, 16), ck * 16 - _origin)


func _endless_world_to_map(world_pos: Vector2) -> Vector2:
	var p: Vector2 = (world_pos - _wg.ORIGIN) / 16.0
	return (p - Vector2(_origin)) * _scale


func _draw_marks() -> void:
	if not _endless():
		return
	var font := ThemeDB.fallback_font
	var marks: Array = []
	marks.append([_wg.spawn_world_pos(), "START", Color("8FD14F")])
	if _wg.respawn_pos != Vector2.INF:
		marks.append([_wg.respawn_pos, "BED", Color("8fd3ff")])
	for k in _wg.caves:
		var c: Array = _wg.caves[k]
		marks.append([_wg.tile_center(Vector2i(c[0], c[1])), "CAVE", Color("c9b8ff")])
	if _wg.village_found:
		marks.append([_wg.tile_center(_wg.VILLAGE_CENTER), "HARVEST VILLAGE", Color("F0C266")])
	for m in marks:
		var pt := _endless_world_to_map(m[0])
		if pt.x < -4 or pt.y < -4 or pt.x > _marks.size.x + 4 or pt.y > _marks.size.y + 4:
			continue
		_marks.draw_circle(pt, 3.5, Color(0.05, 0.04, 0.03))
		_marks.draw_circle(pt, 2.5, m[2])
		_marks.draw_string(font, pt + Vector2(6, 4), str(m[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, m[2])


func _setup_world_viewport() -> void:
	if not sub_viewport:
		return
	
	var parent_viewport := get_viewport()
	if parent_viewport and parent_viewport.find_world_2d():
		sub_viewport.world_2d = parent_viewport.find_world_2d()
	
	if fit_whole_world:
		_world_rect = Rect2()
		if crop_to_boundary:
			_world_rect = _compute_boundary_rect()
		if _world_rect.size.x <= 0.0 or _world_rect.size.y <= 0.0:
			_world_rect = _compute_world_rect()
	_fit_camera()


## The playable boundary, taken from the player's camera limits
## (those limits sit exactly on the grass-edge tiles around the valley).
func _compute_boundary_rect() -> Rect2:
	_locate_player()
	if not is_instance_valid(target):
		return Rect2()
	var cam: Camera2D = target.get("camera") as Camera2D
	if cam == null:
		cam = target.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return Rect2()
	var left := float(cam.limit_left)
	var top := float(cam.limit_top)
	var right := float(cam.limit_right)
	var bottom := float(cam.limit_bottom)
	# Unset limits default to +/-10,000,000; ignore those.
	if absf(left) >= 1000000.0 or absf(right) >= 1000000.0 or absf(top) >= 1000000.0 or absf(bottom) >= 1000000.0:
		return Rect2()
	if right <= left or bottom <= top:
		return Rect2()
	return Rect2(left, top, right - left, bottom - top)


## Paints over the map area outside the boundary so only the valley shows.
func _create_outside_mask() -> void:
	if not map_area:
		return
	_outside_mask = Control.new()
	_outside_mask.name = "OutsideMask"
	_outside_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outside_mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_area.add_child(_outside_mask)
	# Sit right above the world view, below the POIs and player marker.
	var svc := map_area.get_node_or_null("SubViewportContainer")
	if svc:
		map_area.move_child(_outside_mask, svc.get_index() + 1)
	_outside_mask.draw.connect(_draw_outside_mask)


func _draw_outside_mask() -> void:
	if not crop_to_boundary or not _outside_mask:
		return
	if _world_rect.size.x <= 0.0 or _world_rect.size.y <= 0.0:
		return
	var full := Rect2(Vector2.ZERO, _outside_mask.size)
	var a := world_to_map_position(_world_rect.position)
	var b := world_to_map_position(_world_rect.end)
	var inner := Rect2(a, b - a).intersection(full)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		_outside_mask.draw_rect(full, outside_color)
		return
	# Top, bottom, left, right strips around the boundary.
	_outside_mask.draw_rect(Rect2(0, 0, full.size.x, inner.position.y), outside_color)
	_outside_mask.draw_rect(Rect2(0, inner.end.y, full.size.x, full.size.y - inner.end.y), outside_color)
	_outside_mask.draw_rect(Rect2(0, inner.position.y, inner.position.x, inner.size.y), outside_color)
	_outside_mask.draw_rect(Rect2(inner.end.x, inner.position.y, full.size.x - inner.end.x, inner.size.y), outside_color)


## Bounding box (world coordinates) of every tile map in the game scene.
func _compute_world_rect() -> Rect2:
	var root := get_tree().current_scene
	if root == null:
		return Rect2()
	var result := Rect2()
	var has_any := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is TileMapLayer or n is TileMap):
			continue
		if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
			continue
		var layer = n  # TileMapLayer or legacy TileMap (same methods)
		var used: Rect2i = layer.get_used_rect()
		var ts: TileSet = layer.tile_set
		if used.size == Vector2i.ZERO or ts == null:
			continue
		var half: Vector2 = Vector2(ts.tile_size) * 0.5
		var a: Vector2 = layer.to_global(layer.map_to_local(used.position) - half)
		var b: Vector2 = layer.to_global(layer.map_to_local(used.end - Vector2i.ONE) + half)
		var r := Rect2(a, Vector2.ZERO).expand(b)
		result = r if not has_any else result.merge(r)
		has_any = true
	return result if has_any else Rect2()


## Centers the map camera and picks a zoom so the whole world fits the map area.
func _fit_camera() -> void:
	if not map_camera:
		return
	if not fit_whole_world or _world_rect.size.x <= 0.0 or _world_rect.size.y <= 0.0 or not map_area:
		map_camera.global_position = map_center
		map_camera.zoom = Vector2(map_zoom, map_zoom)
		return
	var area := map_area.size
	area.x = maxf(area.x, map_area.custom_minimum_size.x)
	area.y = maxf(area.y, map_area.custom_minimum_size.y)
	var usable := area * (1.0 - fit_margin * 2.0)
	var z := minf(usable.x / _world_rect.size.x, usable.y / _world_rect.size.y)
	map_camera.global_position = _world_rect.get_center()
	map_camera.zoom = Vector2(z, z)


func _locate_player() -> void:
	if not target:
		var ken := get_tree().get_first_node_in_group("player")
		if ken and ken is Node2D:
			target = ken
		else:
			var root_node := get_tree().current_scene
			if root_node:
				var candidate := root_node.find_child("CharacterBody2D3", true, false)
				if candidate and candidate is Node2D:
					target = candidate


func _sync_endless() -> void:
	var svc := map_area.get_node_or_null("SubViewportContainer") as Control
	if svc:
		svc.visible = false
	if _outside_mask:
		_outside_mask.visible = false
	for n in _poi_nodes + _poi_dots:
		if is_instance_valid(n):
			n.visible = false
	# Fill in chunks explored in earlier sessions a few at a time
	var t0 := Time.get_ticks_msec()
	var changed := false
	while not _pending.is_empty() and Time.get_ticks_msec() - t0 < 6:
		_blit_chunk(_pending.pop_front())
		changed = true
	if changed:
		(_tex_rect.texture as ImageTexture).update(_img)
	if is_instance_valid(target):
		var tc: Vector2i = _wg.tile_of(target.global_position)
		var vt := _view_tiles()
		if absi(tc.x - _built_at.x) > vt.x / 4 or absi(tc.y - _built_at.y) > vt.y / 4:
			_rebuild_endless()
		if player_indicator:
			player_indicator.position = _endless_world_to_map(target.global_position)
			var facing_dir: Vector2 = target.get("last_direction") if target.get("last_direction") != null else Vector2.DOWN
			if player_arrow:
				player_arrow.text = "▲" if facing_dir == Vector2.UP else ("►" if facing_dir == Vector2.RIGHT else ("◄" if facing_dir == Vector2.LEFT else "▼"))


func _gui_input(event: InputEvent) -> void:
	if not is_open or not _endless():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scale = minf(_scale * 2.0, 8.0)
			_rebuild_endless()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scale = maxf(_scale * 0.5, 0.5)
			_rebuild_endless()
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and _endless() and event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_scale = minf(_scale * 2.0, 8.0) if event.button_index == MOUSE_BUTTON_WHEEL_UP else maxf(_scale * 0.5, 0.5)
		_rebuild_endless()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("open_map"):
		toggle_map()
		get_viewport().set_input_as_handled()
	elif is_open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_menu")):
		close_map()
		get_viewport().set_input_as_handled()


func toggle_map() -> void:
	if is_open:
		close_map()
	else:
		open_map()


func open_map() -> void:
	if is_open:
		return
	
	_locate_player()
	_setup_world_viewport()
	if _tex_rect == null:
		_setup_endless()
	if _endless():
		_rebuild_endless()
	
	is_open = true
	visible = true
	
	# Smooth fade-in
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if modal_panel:
		modal_panel.scale = Vector2(0.96, 0.96)
		tween.tween_property(modal_panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	_sync_elements()
	map_opened.emit()


func close_map() -> void:
	if not is_open:
		return
	
	is_open = false
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if modal_panel:
		tween.tween_property(modal_panel, "scale", Vector2(0.96, 0.96), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.chain().tween_callback(func():
		visible = false
		map_closed.emit()
	)


func _process(_delta: float) -> void:
	if not is_open:
		return
	
	if not is_instance_valid(target):
		_locate_player()
		return
	
	_sync_elements()


func _sync_elements() -> void:
	if not map_area or not map_camera:
		return
	if _endless():
		_sync_endless()
		return
	_fit_camera()  # keeps the fit right if the window is resized
	if _outside_mask:
		_outside_mask.queue_redraw()

	# Update player indicator position & facing direction
	if player_indicator and is_instance_valid(target):
		var screen_pos := world_to_map_position(target.global_position)
		player_indicator.position = screen_pos
		
		var facing_dir: Vector2 = target.get("last_direction") if target.get("last_direction") != null else Vector2.DOWN
		if player_arrow:
			if facing_dir == Vector2.UP:
				player_arrow.text = "▲"
			elif facing_dir == Vector2.RIGHT:
				player_arrow.text = "►"
			elif facing_dir == Vector2.LEFT:
				player_arrow.text = "◄"
			else:
				player_arrow.text = "▼"
	
	_layout_landmarks()


## Puts a dot on each landmark and places its label next to it,
## trying above / below / right / left so no two labels overlap.
func _layout_landmarks() -> void:
	var bounds := Rect2(Vector2.ZERO, map_area.size)
	var placed: Array[Rect2] = []
	for i in range(LANDMARKS.size()):
		if i >= _poi_nodes.size() or not is_instance_valid(_poi_nodes[i]):
			continue
		var point := world_to_map_position(LANDMARKS[i].pos)
		if i < _poi_dots.size() and is_instance_valid(_poi_dots[i]):
			_poi_dots[i].position = point - _poi_dots[i].size * 0.5

		var panel := _poi_nodes[i]
		var s := panel.get_combined_minimum_size()
		panel.size = s
		var candidates: Array[Vector2] = [
			Vector2(-s.x * 0.5, -s.y - LABEL_GAP),               # above
			Vector2(-s.x * 0.5, LABEL_GAP),                      # below
			Vector2(LABEL_GAP + 2.0, -s.y * 0.5),                # right
			Vector2(-s.x - LABEL_GAP - 2.0, -s.y * 0.5),         # left
			Vector2(-s.x * 0.5, -s.y * 2.0 - LABEL_GAP - 2.0),   # two rows up
			Vector2(-s.x * 0.5, s.y + LABEL_GAP + 2.0),          # two rows down
			Vector2(LABEL_GAP + 2.0, -s.y * 1.5 - 2.0),          # up-right
			Vector2(LABEL_GAP + 2.0, s.y * 0.5 + 2.0),           # down-right
		]
		var chosen := Rect2()
		var found := false
		for off in candidates:
			var r := Rect2(point + off, s)
			if not bounds.encloses(r):
				continue
			var clash := false
			for other in placed:
				if r.grow(2.0).intersects(other):
					clash = true
					break
			if not clash:
				chosen = r
				found = true
				break
		if not found:
			# Everything is taken: fall back to above, kept inside the map.
			var r := Rect2(point + candidates[0], s)
			r.position = r.position.clamp(Vector2.ZERO, (bounds.size - s).max(Vector2.ZERO))
			chosen = r
		panel.position = chosen.position
		placed.append(chosen)


func world_to_map_position(world_pos: Vector2) -> Vector2:
	if not map_area or not map_camera:
		return Vector2.ZERO
	
	var cam_pos: Vector2 = map_camera.global_position
	var cam_zoom: Vector2 = map_camera.zoom
	var half_size: Vector2 = map_area.size * 0.5
	var offset: Vector2 = (world_pos - cam_pos) * cam_zoom
	return half_size + offset


func _spawn_landmarks() -> void:
	if not poi_container:
		return
	
	for child in poi_container.get_children():
		child.queue_free()
	_poi_nodes.clear()
	_poi_dots.clear()

	for poi in LANDMARKS:
		# Small dot marking the exact spot; the label sits beside it.
		var dot := Panel.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.size = Vector2(6, 6)
		var dot_style := StyleBoxFlat.new()
		dot_style.bg_color = poi.color
		dot_style.set_corner_radius_all(3)
		dot_style.set_border_width_all(1)
		dot_style.border_color = Color(0.05, 0.04, 0.03, 0.9)
		dot.add_theme_stylebox_override("panel", dot_style)
		poi_container.add_child(dot)
		_poi_dots.append(dot)

		var poi_panel := PanelContainer.new()
		poi_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.08, 0.06, 0.9)
		style.set_border_width_all(1)
		style.border_color = poi.color
		style.set_corner_radius_all(4)
		style.content_margin_left = 4
		style.content_margin_right = 4
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		poi_panel.add_theme_stylebox_override("panel", style)
		
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 3)
		
		var icon_lbl := Label.new()
		icon_lbl.text = poi.icon
		icon_lbl.add_theme_font_size_override("font_size", 10)
		hbox.add_child(icon_lbl)
		
		var name_lbl := Label.new()
		name_lbl.text = poi.name
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color", poi.color)
		hbox.add_child(name_lbl)
		
		poi_panel.add_child(hbox)
		poi_container.add_child(poi_panel)
		_poi_nodes.append(poi_panel)
