extends Control

## Night Harvest — title screen / main menu.
##
## Everything is drawn on a 1280x720 "stage" that scales to fit the window.
## Background: layered night farm (sky, clouds, mountains, forest, farm hill,
## foreground) made from the game's own sprites, with Ken following the cursor
## and clickable zombies walking in from the forest (title-screen easter egg:
## clear 10 zombies to unlock the Blood Moon title theme).
## Screens: main menu, New Game setup, Load Game, Settings (Audio/Video/Graphics/Controls), Quit.

const GAME_SCENE := "res://Scenes/game.tscn"
const SW := 1280.0
const SH := 720.0
const UI := "res://Assets/UI/MainMenu/"
const PIXEL_FONT := "res://Assets/Fonts/nh_pixel_font.png"
const KEN_SHEET := "res://Assets/Player/character.png"
const ZOMBIE_WALK := "res://Assets/Enemies/zombie/1_Default/Zombie_Default_Walk.png"
const ZOMBIE_DEAD := "res://Assets/Enemies/zombie/1_Default/Zombie_Default_Dead.png"
const TORCH_SHEET := "res://Assets/Items/torch_spritesheet.png"
const TOOLS_SHEET := "res://Assets/Items/tools.png"
const Characters = preload("res://scripts/systems/characters.gd")

const C_TEXT := Color("ECE2C6")
const C_TEXT_SOFT := Color("D8C9AA")
const C_TEXT_DIM := Color("A8916A")
const C_GOLD := Color("F0C266")
const C_GOLD_LIGHT := Color("FFDB80")
const C_PANEL := Color(0.106, 0.075, 0.055, 0.92)
const C_PANEL_HI := Color("3A2814")
const C_ROW := Color("22170F")
const C_BTN_BORDER := Color("6E4F2C")
const C_BORDER := Color("7A5730")
const C_BORDER_DIM := Color("4A3420")
const C_OUTLINE := Color("1E1209")
const C_SHADOW := Color("0A0705")
const C_RED := Color("E0484A")
const C_RED_DARK := Color("7A3A2E")

## Pixel font cell is 9 px tall; sizes are whole multiples so text stays crisp.
const F_SMALL := 18
const F_BIG := 27
const F_TIME := 36
const F_HEAD := 45
const F_TITLE := 90

const KILLS_FOR_BLOOD_MOON := 10


## Plays frames from a sprite sheet on a TextureRect.
class Strip extends TextureRect:
	var frames: Array = []
	var fps: float = 8.0
	var loop: bool = true
	var playing: bool = true
	var _t: float = 0.0
	var _idx: int = -1
	var _atlas := AtlasTexture.new()

	func play(sheet: Texture2D, rects: Array, frame_fps: float, looping: bool = true) -> void:
		_atlas.atlas = sheet
		frames = rects
		fps = frame_fps
		loop = looping
		playing = true
		_t = 0.0
		_idx = -1
		_show(0)
		texture = _atlas

	func _show(i: int) -> void:
		if i == _idx or frames.is_empty():
			return
		_idx = i
		_atlas.region = frames[i]

	func _process(delta: float) -> void:
		if not playing or frames.size() < 2:
			return
		_t += delta * fps
		var n := int(_t)
		if loop:
			n = n % frames.size()
		else:
			n = mini(n, frames.size() - 1)
		_show(n)


var _font: FontFile
var _stage: Control
var _fade: ColorRect
var _time: float = 0.0
var _screen: String = "main"

# Background
var _sky: TextureRect
var _clouds: Array[TextureRect] = []
var _mountains: TextureRect
var _forest: TextureRect
var _glow: TextureRect
var _lamp_glow: TextureRect
var _fog: Array[TextureRect] = []
var _flies: Array[ColorRect] = []
var _stars: Array[ColorRect] = []
var _cloud_x: float = 0.0
var _menu_fx: int = 2

# Ken
var _ken: Strip
var _ken_sheet: Texture2D
var _ken_x: float = 576.0
var _ken_target: float = 576.0
var _ken_anim: String = ""
var _ken_swing_time: float = 0.0
var _mouse_active: bool = false
var _mouse_stage_x: float = 0.0

# Zombies
var _zombies: Array[Dictionary] = []
var _z_walk: Texture2D
var _z_dead: Texture2D

# UI
var _main_ui: Control
var _title_harvest: Array[Label] = []
var _hint: Label
var _hint_box: Panel
var _menu_buttons: Array[Button] = []
var _menu_info: Array[Dictionary] = []
var _focused_menu: int = -1
var _counter: Panel
var _counter_label: Label
var _counter_badge: Panel
var _toast: Panel
var _toast_time: float = 0.0
var _dim: ColorRect
var _load_panel: Panel
var _settings_panel: Panel
var _quit_panel: Panel
var _settings_body: Control
var _settings_tab: String = "audio"
var _tab_buttons: Dictionary = {}
var _selected_slot: int = -1
var _slot_buttons: Array[Button] = []
var _delete_button: Button
var _load_button: Button
var _delete_armed: bool = false
var _clear_button: Button
var _clear_armed: bool = false
var _settings_return: String = "main"

# New Game setup
var _new_panel: Panel
var _new_opts: Control
var _new_farmer: LineEdit
var _new_farm: LineEdit
var _new_seed: LineEdit
var _new_start: Button
var _new_cfg: Dictionary = {}
var _new_slot: int = 0
var _farm_name_touched: bool = false
var _overwrite_armed: bool = false

# Character select
var _char_panel: Panel
var _char_cards: Array[Panel] = []
var _char_previews: Array[Strip] = []
var _char_index: int = 0
var _char_name_touched: bool = false

# Updates
var _update_badge: Button
var _update_progress_label: Label

# Sound
var _sfx_hit: AudioStreamPlayer
var _sfx_groan: AudioStreamPlayer
var _sfx_unlock: AudioStreamPlayer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if has_node("/root/SaveManager"):
		SaveManager.end_session()
	if has_node("/root/Music"):
		get_node("/root/Music").play_title()
	_font = load(PIXEL_FONT)
	var th := Theme.new()
	th.default_font = _font
	th.default_font_size = F_SMALL
	theme = th

	var back := ColorRect.new()
	back.color = Color.BLACK
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	_stage = Control.new()
	_stage.size = Vector2(SW, SH)
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_stage)

	_build_background()
	_build_main_ui()
	_build_load_panel()
	_build_new_panel()
	_build_char_panel()
	_build_settings_panel()
	_build_quit_panel()
	_build_sounds()

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.6)

	if has_node("/root/GameSettings"):
		GameSettings.changed.connect(_on_settings_changed)
	_on_settings_changed()
	_update_counter()

	get_viewport().size_changed.connect(_fit_stage)
	_fit_stage()
	_show_screen("main")
	_connect_updates()


func _fit_stage() -> void:
	var vs := get_viewport_rect().size
	var s := minf(vs.x / SW, vs.y / SH)
	_stage.scale = Vector2(s, s)
	_stage.position = ((vs - Vector2(SW, SH) * s) * 0.5).floor()


# ==========================================================================
# Background
# ==========================================================================

func _build_background() -> void:
	_sky = _tex_rect(_stage, load(UI + "menu_sky.png"), Vector2.ZERO, Vector2(SW, SH))
	for p in [Vector2(212, 92), Vector2(1004, 64), Vector2(1188, 172), Vector2(96, 236)]:
		_stars.append(_color_rect(_stage, Color("E8ECFF"), p, Vector2(4, 4)))
	var cloud_tex: Texture2D = load(UI + "menu_clouds.png")
	for i in 2:
		_clouds.append(_tex_rect(_stage, cloud_tex, Vector2(i * SW, 0), Vector2(SW, 360)))
	_mountains = _tex_rect(_stage, load(UI + "menu_mountains.png"), Vector2(-40, 0), Vector2(1360, SH))
	_fog.append(_soft_rect(_stage, Color(0.59, 0.59, 0.86, 0.14), Vector2(-300, 380), Vector2(1800, 160)))
	_forest = _tex_rect(_stage, load(UI + "menu_forest.png"), Vector2(-40, 0), Vector2(1360, SH))
	_tex_rect(_stage, load(UI + "menu_farm.png"), Vector2.ZERO, Vector2(SW, SH))

	_ken_sheet = load(KEN_SHEET)
	if has_node("/root/SaveManager") and SaveManager.has_any_save():
		var latest_info := SaveManager.get_slot(SaveManager.latest_slot())
		_ken_sheet = load(Characters.get_character(str(latest_info.get("character", "ken")))["sheet"])
	_ken = Strip.new()
	_setup_strip(_ken, Vector2(128, 128))
	_ken.modulate = Color(1.0, 0.9, 0.8)
	_stage.add_child(_ken)
	_set_ken_anim("auto")

	_glow = _soft_rect(_stage, Color(1.0, 0.67, 0.27, 0.24), Vector2(704 - 170, 462 - 170), Vector2(340, 340))
	_lamp_glow = _soft_rect(_stage, Color(1.0, 0.8, 0.43, 0.22), Vector2(880 - 80, 394 - 80), Vector2(160, 160))

	var torch := Strip.new()
	_setup_strip(torch, Vector2(64, 64))
	torch.position = Vector2(684, 444)
	_stage.add_child(torch)
	torch.play(load(TORCH_SHEET), _row_frames(0, 4, 16, 16), 6.6)

	_z_walk = load(ZOMBIE_WALK)
	_z_dead = load(ZOMBIE_DEAD)
	_add_zombie(1360.0, 1160.0, 30.0, 0.4, false, Color(0.45, 0.47, 0.52))
	_add_zombie(1248.0, 1008.0, 26.0, 0.0, false, Color(0.68, 0.7, 0.74))
	_add_zombie(-40.0, 220.0, 28.0, 0.21, true, Color(0.55, 0.57, 0.62))

	_fog.append(_soft_rect(_stage, Color(0.67, 0.75, 0.92, 0.13), Vector2(-200, 500), Vector2(1700, 200)))
	for p in [Vector2(560, 420), Vector2(800, 380), Vector2(420, 470), Vector2(1090, 520), Vector2(260, 430), Vector2(960, 470)]:
		_flies.append(_color_rect(_stage, Color("FFE08A"), p, Vector2(6, 6)))

	_tex_rect(_stage, load(UI + "menu_fg.png"), Vector2.ZERO, Vector2(SW, SH))
	var vig := _gradient_rect(_stage, [0.0, 0.6, 1.0], [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.01, 0.01, 0.04, 0.55)], Vector2.ZERO, Vector2(SW, SH))
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _add_zombie(x0: float, x1: float, period: float, start: float, flip: bool, tint: Color) -> void:
	var root := Control.new()
	root.size = Vector2(256, 256)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(root)
	var spr := Strip.new()
	_setup_strip(spr, Vector2(256, 256))
	spr.flip_h = flip
	spr.modulate = tint
	root.add_child(spr)
	spr.play(_z_walk, _row_frames(0, 6, 64, 64), 5.2)
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.position = Vector2(80, 68)
	hit.size = Vector2(96, 124)
	hit.mouse_default_cursor_shape = Control.CURSOR_CROSS
	hit.tooltip_text = ""
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		hit.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	root.add_child(hit)
	var pop := Label.new()
	_style_label(pop, "+1", F_TIME, C_GOLD_LIGHT)
	pop.add_theme_color_override("font_shadow_color", C_OUTLINE)
	pop.add_theme_constant_override("shadow_offset_y", 3)
	pop.position = Vector2(110, 30)
	pop.visible = false
	root.add_child(pop)
	var z := {"root": root, "spr": spr, "hit": hit, "pop": pop, "x0": x0, "x1": x1,
		"period": period, "prog": start, "state": "walk", "timer": 0.0, "tint": tint}
	_zombies.append(z)
	var idx := _zombies.size() - 1
	hit.pressed.connect(func() -> void: _kill_zombie(idx))
	_place_zombie(z)


func _ground_y(cx: float) -> float:
	var n := cx / 4.0
	return (126.0 + 16.0 * pow((n - 160.0) / 160.0, 2.0)) * 4.0


func _place_zombie(z: Dictionary) -> void:
	var prog: float = z["prog"]
	var cx: float = lerpf(z["x0"], z["x1"], prog)
	var root: Control = z["root"]
	root.position = Vector2(cx - 128.0, _ground_y(cx) - 192.0).round()
	z["cx"] = cx
	if z["state"] == "walk":
		root.modulate.a = clampf(minf(prog / 0.08, (1.0 - prog) / 0.08), 0.0, 1.0)


func _kill_zombie(i: int) -> void:
	var z: Dictionary = _zombies[i]
	if z["state"] != "walk" or _screen != "main":
		return
	z["state"] = "dead"
	z["timer"] = 0.0
	var spr: Strip = z["spr"]
	spr.play(_z_dead, _row_frames(0, 6, 64, 64), 8.5, false)
	var tint: Color = z["tint"]
	spr.modulate = tint.lightened(0.25)
	var hit_b: Button = z["hit"]
	hit_b.visible = false
	var pop: Label = z["pop"]
	pop.visible = true
	pop.position = Vector2(110, 30)
	pop.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(pop, "position:y", -10.0, 0.9)
	tw.parallel().tween_property(pop, "modulate:a", 0.0, 0.9)
	_sfx_hit.play()
	_sfx_groan.play()
	# Ken swings toward the zombie
	var dir := "R" if float(z["cx"]) > _ken_x + 64.0 else "L"
	_set_ken_anim("swing" + dir)
	_ken_swing_time = 0.5
	if has_node("/root/GameSettings"):
		GameSettings.menu_kills += 1
		if GameSettings.menu_kills >= KILLS_FOR_BLOOD_MOON and not GameSettings.blood_moon:
			GameSettings.blood_moon = true
			_show_toast()
			_sfx_unlock.play()
			_apply_blood_moon()
		GameSettings.save_settings()
	_update_counter()


func _update_zombies(delta: float) -> void:
	for z in _zombies:
		var root: Control = z["root"]
		match z["state"]:
			"walk":
				z["prog"] = float(z["prog"]) + delta / float(z["period"])
				if float(z["prog"]) >= 1.0:
					z["prog"] = 0.0
				_place_zombie(z)
			"dead":
				z["timer"] = float(z["timer"]) + delta
				if float(z["timer"]) > 0.8:
					root.modulate.a = clampf(1.0 - (float(z["timer"]) - 0.8) / 0.3, 0.0, 1.0)
				if float(z["timer"]) > 1.1:
					z["state"] = "gone"
					z["timer"] = 0.0
					root.visible = false
			"gone":
				z["timer"] = float(z["timer"]) + delta
				if float(z["timer"]) > 2.5:
					z["state"] = "walk"
					z["prog"] = 0.0
					var spr: Strip = z["spr"]
					spr.modulate = z["tint"]
					spr.play(_z_walk, _row_frames(0, 6, 64, 64), 5.2)
					var hit_b: Button = z["hit"]
					hit_b.visible = true
					root.visible = true
					_place_zombie(z)


# ---- Ken ----

func _set_ken_anim(key: String) -> void:
	if key == _ken_anim:
		return
	_ken_anim = key
	_ken.flip_h = false
	match key:
		"auto":
			var seq: Array = []
			for pair in [[0, 4], [4, 2], [0, 2], [6, 2]]:
				for _r in pair[1]:
					seq.append(Rect2(0, pair[0] * 32, 32, 32))
					seq.append(Rect2(32, pair[0] * 32, 32, 32))
			_ken.play(_ken_sheet, seq, 2.0)
		"idleF":
			_ken.play(_ken_sheet, _row_frames(0, 2, 32, 32), 2.0)
		"idleR":
			_ken.play(_ken_sheet, _row_frames(4, 2, 32, 32), 2.0)
		"idleL":
			_ken.play(_ken_sheet, _row_frames(6, 2, 32, 32), 2.0)
		"walkR":
			_ken.play(_ken_sheet, _row_frames(5, 6, 32, 32), 10.0)
		"walkL":
			_ken.play(_ken_sheet, _row_frames(7, 6, 32, 32), 10.0)
		"swingR":
			_ken.play(_ken_sheet, _row_frames(8, 6, 32, 32), 12.0, false)
		"swingL":
			_ken.play(_ken_sheet, _row_frames(8, 6, 32, 32), 12.0, false)
			_ken.flip_h = true


func _update_ken(delta: float) -> void:
	if _ken_swing_time > 0.0:
		_ken_swing_time -= delta
	else:
		if _mouse_active and _screen == "main":
			_ken_target = clampf(_mouse_stage_x - 64.0, 360.0, 860.0)
		var d := _ken_target - _ken_x
		if absf(d) > 4.0:
			_ken_x += signf(d) * minf(absf(d), 160.0 * delta)
			_set_ken_anim("walkR" if d > 0.0 else "walkL")
		elif not _mouse_active:
			_set_ken_anim("auto")
		else:
			var dx := _mouse_stage_x - (_ken_x + 64.0)
			if absf(dx) < 36.0:
				_set_ken_anim("idleF")
			else:
				_set_ken_anim("idleR" if dx > 0.0 else "idleL")
	_ken.position = Vector2(_ken_x, _ground_y(_ken_x + 64.0) - 120.0).round()


# ---- Ambient animation ----

func _update_ambient(delta: float) -> void:
	var fx := _menu_fx
	if fx >= 1:
		_cloud_x = fmod(_cloud_x - delta * 9.0, SW)
	for i in _clouds.size():
		_clouds[i].position.x = roundf(_cloud_x + i * SW)
	if fx >= 2:
		_mountains.position.x = roundf(-40.0 + 18.0 + 18.0 * sin(_time * TAU / 96.0))
		_forest.position.x = roundf(-40.0 + 18.0 + 18.0 * sin(_time * TAU / 60.0))
	for i in _stars.size():
		var ph := fmod(_time / (2.6 + i * 0.9) + i * 0.37, 1.0)
		_stars[i].modulate.a = 1.0 if (fx >= 1 and ph > 0.75 and ph < 0.85) else 0.3
	var flick := 1.0 - 0.15 * float(int(_time * 3.0) % 2)
	_glow.modulate.a = flick
	_glow.visible = fx >= 1
	_lamp_glow.visible = fx >= 1
	for i in _fog.size():
		_fog[i].visible = fx >= 1
		_fog[i].position.x = (-300.0 + 100.0 * i) + 80.0 * sin(_time * TAU / (52.0 + 16.0 * i))
	for i in _flies.size():
		var f := _flies[i]
		f.visible = fx >= 2
		var ph := _time / (4.2 + i * 0.8) + i
		f.position.y = roundf([420.0, 380.0, 470.0, 520.0, 430.0, 470.0][i] - 12.0 * sin(ph * TAU))
		f.modulate.a = 0.3 + 0.7 * absf(sin(ph * PI))


func _apply_blood_moon() -> void:
	var on := has_node("/root/GameSettings") and GameSettings.blood_moon
	var tint := Color(1.0, 0.42, 0.4) if on else Color.WHITE
	_sky.modulate = tint
	for c in _clouds:
		c.modulate = tint
	for l in _title_harvest:
		l.add_theme_color_override("font_color", C_RED if on else C_GOLD)


func _on_settings_changed() -> void:
	if has_node("/root/GameSettings"):
		_menu_fx = int(GameSettings.preset()["menu_fx"])
	_apply_blood_moon()
	if _settings_panel and _settings_panel.visible:
		_rebuild_settings_body()


# ==========================================================================
# Main menu UI
# ==========================================================================

func _build_main_ui() -> void:
	_main_ui = Control.new()
	_main_ui.size = Vector2(SW, SH)
	_main_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_main_ui)

	# v1.4.3: game logo badge above the title
	var logo_path := "res://Assets/Generated/v131/game_logo.png"
	if ResourceLoader.exists(logo_path):
		var logo := _tex_rect(_main_ui, load(logo_path), Vector2(roundf((SW - 96.0) * 0.5), 8), Vector2(96, 96))
		logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	# Title with chunky outline
	var title := "NIGHT HARVEST"
	var tx := roundf((SW - _text_w(title, F_TITLE)) * 0.5)
	var ty := 112.0
	var offsets := [Vector2(-5, 0), Vector2(5, 0), Vector2(0, -5), Vector2(0, 5), Vector2(-5, 5), Vector2(5, 5), Vector2(-5, -5), Vector2(5, -5), Vector2(0, 11)]
	for o in offsets:
		_label(_main_ui, title, F_TITLE, C_OUTLINE, Vector2(tx, ty) + o)
	_label(_main_ui, "NIGHT", F_TITLE, Color("F6EBCF"), Vector2(tx, ty))
	_title_harvest.append(_label(_main_ui, "HARVEST", F_TITLE, C_GOLD, Vector2(tx + _text_w("NIGHT ", F_TITLE), ty)))

	var rib_text := "A FARMING SURVIVAL GAME"
	var rw := _text_w(rib_text, F_SMALL) + 36.0
	var rib := _panel(_main_ui, Vector2(roundf((SW - rw) * 0.5), 222), Vector2(rw, 34), _box(Color("6E4424"), C_OUTLINE, 3, false))
	_label(rib, rib_text, F_SMALL, Color("F6EBCF"), Vector2(18, 7))

	# Hint line above the buttons
	_hint_box = _panel(_main_ui, Vector2(0, 548), Vector2(100, 32), _box(Color(0.04, 0.03, 0.02, 0.82), Color(0, 0, 0, 0), 0, false))
	_hint = _label(_hint_box, "", F_SMALL, C_TEXT_SOFT, Vector2(14, 7))

	# Menu buttons
	var has_save := has_node("/root/SaveManager") and SaveManager.has_any_save()
	_menu_info = [
		{"label": "CONTINUE", "icon": 0, "action": "continue", "enabled": has_save,
			"hint": "Return to your latest farm." if has_save else "No saved farm yet. Start a New Game."},
		{"label": "NEW GAME", "icon": 1, "action": "new", "enabled": true, "hint": "Name your farm, pick a difficulty and start fresh."},
		{"label": "LOAD GAME", "icon": 2, "action": "load", "enabled": true, "hint": "Pick up a saved farm, or delete old ones."},
		{"label": "SETTINGS", "icon": 3, "action": "settings", "enabled": true, "hint": "Audio, video, graphics and controls."},
		{"label": "QUIT", "icon": 4, "action": "quit", "enabled": true, "hint": "Put out the torch and leave the farm."},
	]
	var icons: Texture2D = load(UI + "menu_icons.png")
	var x := 112.0
	for i in _menu_info.size():
		var info: Dictionary = _menu_info[i]
		var b := Button.new()
		b.position = Vector2(x, 600)
		b.size = Vector2(200, 64)
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_main_ui.add_child(b)
		var slot := _panel(b, Vector2(8, 10), Vector2(44, 44), _box(Color("120C08"), Color("574029"), 2, false))
		var ic := _tex_rect(slot, _atlas(icons, Rect2(info["icon"] * 16, 0, 16, 16)), Vector2(6, 6), Vector2(32, 32))
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lb := _label(b, info["label"], F_SMALL, C_TEXT, Vector2(62, 23))
		info["button"] = b
		info["slot"] = slot
		info["text"] = lb
		info["base_y"] = 600.0
		_menu_buttons.append(b)
		b.mouse_entered.connect(func() -> void: b.grab_focus())
		b.focus_entered.connect(func() -> void: _on_menu_focus(i))
		b.pressed.connect(func() -> void: _on_menu_pressed(i))
		_style_menu_button(i, false)
		x += 214.0
	for i in _menu_buttons.size():
		var b := _menu_buttons[i]
		b.focus_neighbor_left = b.get_path_to(_menu_buttons[(i - 1 + _menu_buttons.size()) % _menu_buttons.size()])
		b.focus_neighbor_right = b.get_path_to(_menu_buttons[(i + 1) % _menu_buttons.size()])

	# Footer
	_label(_main_ui, "MADE WITH GODOT 4 · LIMBRASONADEV · THORDYYDEV", F_SMALL, Color("B8A884"), Vector2(28, 690))
	var keys := "A/D SELECT · ENTER CONFIRM"
	_label(_main_ui, keys, F_SMALL, Color("B8A884"), Vector2(SW - 28 - _text_w(keys, F_SMALL), 690))

	# Zombie counter (hidden until the first kill)
	_counter = _panel(_main_ui, Vector2(SW - 28 - 268, 28), Vector2(268, 64), _box(C_PANEL, C_BORDER, 3, true))
	var sword := _tex_rect(_counter, _atlas(load(TOOLS_SHEET), Rect2(0, 0, 16, 16)), Vector2(14, 16), Vector2(32, 32))
	sword.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(_counter, "ZOMBIES CLEARED", F_SMALL, Color("C9B794"), Vector2(56, 10))
	_counter_label = _label(_counter, "0", F_BIG, C_GOLD_LIGHT, Vector2(56, 32))
	_counter_badge = _panel(_counter, Vector2(116, 34), Vector2(136, 24), _box(Color("7A1E22"), Color("C0393B"), 2, false))
	_label(_counter_badge, "BLOOD MOON", F_SMALL, Color("FFE1D8"), Vector2(8, 3))
	_counter.visible = false

	# Unlock toast
	_toast = _panel(_main_ui, Vector2(380, 24), Vector2(520, 70), _box(Color(0.16, 0.04, 0.05, 0.95), Color("C0393B"), 3, true))
	_label(_toast, "UNLOCKED · %d ZOMBIES CLEARED" % KILLS_FOR_BLOOD_MOON, F_SMALL, Color("F0A898"), Vector2(20, 10))
	_label(_toast, "BLOOD MOON TITLE THEME", F_BIG, Color("FFE1D8"), Vector2(20, 34))
	_toast.visible = false


func _style_menu_button(i: int, selected: bool) -> void:
	var info: Dictionary = _menu_info[i]
	var b: Button = info["button"]
	var enabled: bool = info["enabled"]
	var normal: StyleBoxFlat
	if selected:
		normal = _box(C_PANEL_HI, C_GOLD, 3, true)
	else:
		normal = _box(C_ROW, C_BTN_BORDER, 3, true)
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, normal)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var slot: Panel = info["slot"]
	slot.add_theme_stylebox_override("panel", _box(Color("120C08"), C_GOLD if selected else Color("574029"), 2, false))
	var lb: Label = info["text"]
	var col := C_GOLD_LIGHT if selected else C_TEXT
	if not enabled:
		col = Color(C_TEXT_DIM, 0.7)
	lb.add_theme_color_override("font_color", col)
	b.modulate.a = 1.0 if enabled else 0.75


func _on_menu_focus(i: int) -> void:
	if _focused_menu != -1 and _focused_menu != i:
		_style_menu_button(_focused_menu, false)
		var prev: Button = _menu_info[_focused_menu]["button"]
		prev.position.y = 600.0
	_focused_menu = i
	_style_menu_button(i, true)
	_set_hint(_menu_info[i]["hint"])


func _set_hint(text: String) -> void:
	_hint.text = text
	var w := _text_w(text, F_SMALL) + 28.0
	_hint_box.size = Vector2(w, 32)
	_hint_box.position.x = roundf((SW - w) * 0.5)


func _on_menu_pressed(i: int) -> void:
	var info: Dictionary = _menu_info[i]
	if not info["enabled"]:
		return
	match info["action"]:
		"continue":
			var latest := SaveManager.latest_slot()
			if latest == -1:
				_refresh_menu_state()
				return
			SaveManager.prepare_load(latest)
			_start_game()
		"new":
			_open_new_game()
		"load":
			_show_screen("load")
		"settings":
			_settings_return = "main"
			_show_screen("settings")
		"quit":
			_show_screen("quit")


## Enables/disables CONTINUE and points its hint at the latest save.
func _refresh_menu_state() -> void:
	var info: Dictionary = _menu_info[0]
	var latest := SaveManager.latest_slot() if has_node("/root/SaveManager") else -1
	info["enabled"] = latest != -1
	if latest != -1:
		var d := SaveManager.get_slot(latest)
		info["hint"] = "Continue %s · Day %d." % [str(d.get("farm_name", "your farm")).to_upper(), int(d.get("day", 1))]
	else:
		info["hint"] = "No saved farm yet. Start a New Game."
	_style_menu_button(0, _focused_menu == 0)
	if _focused_menu == 0:
		_set_hint(info["hint"])


func _start_game() -> void:
	set_process_input(false)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.45)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(GAME_SCENE))


func _update_counter() -> void:
	var kills := 0
	var blood := false
	if has_node("/root/GameSettings"):
		kills = GameSettings.menu_kills
		blood = GameSettings.blood_moon
	_counter.visible = kills > 0 and _screen == "main"
	_counter_label.text = str(kills)
	_counter_badge.visible = blood


func _show_toast() -> void:
	_toast.visible = true
	_toast_time = 3.6
	_toast.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.25)


func _show_screen(s: String) -> void:
	_screen = s
	_main_ui.visible = s == "main" or s == "quit"
	_dim.visible = s != "main"
	_load_panel.visible = s == "load"
	_new_panel.visible = s == "new"
	_char_panel.visible = s == "character"
	_settings_panel.visible = s == "settings"
	_quit_panel.visible = s == "quit"
	_update_counter()
	for b in _menu_buttons:
		b.focus_mode = Control.FOCUS_ALL if s == "main" else Control.FOCUS_NONE
	match s:
		"main":
			_refresh_menu_state()
			var first := 0 if _menu_info[0]["enabled"] else 1
			if _focused_menu != -1 and _menu_info[_focused_menu]["enabled"]:
				first = _focused_menu
			_menu_buttons[first].grab_focus()
			_on_menu_focus(first)
		"load":
			_refresh_load_panel()
		"new":
			_overwrite_armed = false
			_set_button_text(_new_start, "START FARM")
			_rebuild_new_opts()
		"character":
			_refresh_char_cards()
		"settings":
			if has_node("/root/GameSettings"):
				GameSettings.refresh_fullscreen_state()
			_select_tab(_settings_tab)
		"quit":
			pass


# ==========================================================================
# Load Game
# ==========================================================================

func _build_load_panel() -> void:
	_dim = _color_rect(_stage, Color(0.02, 0.016, 0.04, 0.45), Vector2.ZERO, Vector2(SW, SH))
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_load_panel = _panel(_stage, Vector2(240, 64), Vector2(800, 560), _box(C_PANEL, C_BORDER, 3, true))
	_load_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_label(_load_panel, "LOAD GAME", F_HEAD, C_TEXT, Vector2(30, 22))
	var slots_txt := "%d SAVE SLOTS" % SaveManager.SLOT_COUNT if has_node("/root/SaveManager") else ""
	_label(_load_panel, slots_txt, F_SMALL, C_TEXT_DIM, Vector2(770 - _text_w(slots_txt, F_SMALL), 46))
	_color_rect(_load_panel, Color("4A3420"), Vector2(30, 82), Vector2(740, 3))
	for i in 3:
		var b := Button.new()
		b.position = Vector2(30, 100 + i * 116)
		b.size = Vector2(740, 104)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_load_panel.add_child(b)
		b.pressed.connect(func() -> void: _on_slot_pressed(i))
		_slot_buttons.append(b)
	var back := _small_button(_load_panel, "‹ BACK  ESC", Vector2(30, 490), false)
	back.pressed.connect(func() -> void: _show_screen("main"))
	_clear_button = _small_button(_load_panel, "CLEAR ALL", Vector2(212, 490), false, true)
	_clear_button.pressed.connect(_on_clear_pressed)
	_delete_button = _small_button(_load_panel, "DELETE", Vector2(470, 490), false, true)
	_delete_button.pressed.connect(_on_delete_pressed)
	_load_button = _small_button(_load_panel, "LOAD FARM", Vector2(610, 490), true)
	_load_button.pressed.connect(_on_load_pressed)


func _refresh_load_panel() -> void:
	_delete_armed = false
	_clear_armed = false
	_set_button_text(_delete_button, "DELETE")
	_set_button_text(_clear_button, "CLEAR ALL")
	_clear_button.visible = has_node("/root/SaveManager") and SaveManager.has_any_save()
	var portraits := {"farm": load(UI + "portrait_farm.png"), "river": load(UI + "portrait_river.png")}
	if _selected_slot == -1 or _slot_info(_selected_slot).is_empty():
		_selected_slot = -1
		for i in 3:
			if not _slot_info(i).is_empty():
				_selected_slot = i
				break
	_delete_button.visible = _selected_slot != -1
	_load_button.visible = _selected_slot != -1
	for i in 3:
		var b := _slot_buttons[i]
		for c in b.get_children():
			c.queue_free()
		var info := _slot_info(i)
		var sel := i == _selected_slot
		var style := _box(Color("2E2014") if sel else C_ROW, C_GOLD if sel else C_BORDER_DIM, 3, true)
		if info.is_empty():
			style = _box(Color(0.07, 0.05, 0.03, 0.6), Color("4A3420"), 2, false)
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, style)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		if info.is_empty():
			var t := "EMPTY SLOT · START A NEW FARM"
			var tw := _text_w(t, F_SMALL) + 44.0
			var ic := _tex_rect(b, _atlas(load(UI + "menu_icons.png"), Rect2(16, 0, 16, 16)), Vector2(roundf((740 - tw) * 0.5), 36), Vector2(32, 32))
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_label(b, t, F_SMALL, C_TEXT_DIM, Vector2(roundf((740 - tw) * 0.5) + 44, 43))
			continue
		var frame := _panel(b, Vector2(14, 13), Vector2(78, 78), _box(C_SHADOW, C_GOLD if sel else C_BORDER_DIM, 3, false))
		var key := str(info.get("portrait", "farm"))
		var pt := _tex_rect(frame, portraits.get(key, portraits["farm"]), Vector2(3, 3), Vector2(72, 72))
		pt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pt.modulate = Color(0.55, 0.55, 0.7)
		var head := _tex_rect(frame, Characters.portrait(str(info.get("character", "ken"))), Vector2(7, 7), Vector2(64, 64))
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label(b, str(info.get("farm_name", "FARM")).to_upper(), F_BIG, C_GOLD_LIGHT if sel else C_TEXT, Vector2(110, 14))
		var diff_key := str(info.get("difficulty", "normal"))
		var diff_label := str(SaveManager.DIFFICULTIES.get(diff_key, SaveManager.DIFFICULTIES["normal"])["label"])
		var mode_tag := ""
		if int(info.get("world_version", 0)) >= 13:
			mode_tag = " · " + ("CREATIVE" if str(info.get("mode", "survival")) == "creative" else "SURVIVAL")
		_label(b, "DAY %d · %d NIGHTS · %s" % [int(info.get("day", 1)), int(info.get("nights_survived", 0)), diff_label], F_SMALL, Color("C9B794"), Vector2(110, 50))
		var crops: Array = info.get("crops", [])
		var line3 := " · ".join(PackedStringArray(crops)).to_upper()
		if crops.is_empty():
			line3 = "FARMER " + str(info.get("farmer_name", "KEN")).to_upper()
		_label(b, (mode_tag.trim_prefix(" · ") + " · " + line3) if mode_tag != "" else line3, F_SMALL, C_TEXT_DIM, Vector2(110, 74))
		var secs := int(info.get("playtime_sec", 0))
		var tstr := "%dH %02dM" % [secs / 3600, (secs / 60) % 60]
		_label(b, tstr, F_TIME, C_TEXT, Vector2(724 - _text_w(tstr, F_TIME), 14))
		var saved := _saved_ago(float(info.get("saved_at", 0)))
		_label(b, saved, F_SMALL, C_TEXT_DIM, Vector2(724 - _text_w(saved, F_SMALL), 62))


func _slot_info(i: int) -> Dictionary:
	if has_node("/root/SaveManager"):
		return SaveManager.get_slot(i)
	return {}


func _saved_ago(t: float) -> String:
	if t <= 0.0:
		return ""
	var mins := int((Time.get_unix_time_from_system() - t) / 60.0)
	if mins < 60:
		return "SAVED %d MIN AGO" % maxi(mins, 1)
	if mins < 60 * 24:
		return "SAVED %d H AGO" % (mins / 60)
	var days := mins / (60 * 24)
	return "SAVED YESTERDAY" if days == 1 else "SAVED %d DAYS AGO" % days


func _on_slot_pressed(i: int) -> void:
	if _slot_info(i).is_empty():
		_open_new_game(i)
		return
	_selected_slot = i
	_refresh_load_panel()


func _on_load_pressed() -> void:
	if _selected_slot == -1:
		return
	SaveManager.prepare_load(_selected_slot)
	_start_game()


func _on_delete_pressed() -> void:
	if _selected_slot == -1:
		return
	if not _delete_armed:
		_delete_armed = true
		_set_button_text(_delete_button, "SURE?")
		return
	SaveManager.delete_slot(_selected_slot)
	_selected_slot = -1
	_refresh_load_panel()


func _on_clear_pressed() -> void:
	if not _clear_armed:
		_clear_armed = true
		_set_button_text(_clear_button, "SURE?")
		return
	SaveManager.delete_all()
	_selected_slot = -1
	_refresh_load_panel()


# ==========================================================================
# New Game setup
# ==========================================================================

const NEW_DIFFICULTY_DESC := {
	"easy": "FEWER, WEAKER ZOMBIES. SLOW HUNGER.",
	"normal": "THE NIGHT AS IT WAS MEANT TO BE.",
	"hard": "BIGGER WAVES. ZOMBIES HIT HARDER.",
}
const NEW_DAY_DESC := {
	"short": "12 REAL MINUTES PER DAY.",
	"normal": "24 REAL MINUTES PER DAY.",
	"long": "48 REAL MINUTES PER DAY.",
}
const NEW_KIT_DESC := {
	"full": "HOE, WATERING CAN, SEEDS AND BREAD.",
	"basic": "A FEW CARROT SEEDS. NOTHING ELSE.",
}
const NEW_MODE_DESC := {
	"survival": "GATHER, CRAFT, BUILD AND SURVIVE THE NIGHTS.",
	"creative": "EVERY ITEM, NO DAMAGE. BUILD FREELY.",
}


func _build_new_panel() -> void:
	_new_panel = _panel(_stage, Vector2(210, 40), Vector2(860, 640), _box(C_PANEL, C_BORDER, 3, true))
	_new_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_label(_new_panel, "NEW GAME", F_HEAD, C_TEXT, Vector2(30, 22))
	var sub := "STEP 2 OF 2"
	_label(_new_panel, sub, F_SMALL, C_TEXT_DIM, Vector2(830 - _text_w(sub, F_SMALL), 46))
	_color_rect(_new_panel, Color("4A3420"), Vector2(30, 82), Vector2(800, 3))

	var r1 := _row_in(_new_panel, Vector2(30, 94), 800.0, "FARMER NAME", "WHO IS WORKING THE LAND?")
	_new_farmer = _line_edit(r1, Vector2(420, 11), 364.0, 16)
	_new_farmer.text_changed.connect(_on_farmer_changed)
	var r2 := _row_in(_new_panel, Vector2(30, 160), 800.0, "FARM NAME · SEED", "SEED: EMPTY = RANDOM.")
	_new_farm = _line_edit(r2, Vector2(300, 11), 300.0, 20)
	_new_farm.text_changed.connect(func(_t: String) -> void: _farm_name_touched = true)
	_new_seed = _line_edit(r2, Vector2(610, 11), 174.0, 10)
	_new_seed.placeholder_text = "RANDOM"

	_new_opts = Control.new()
	_new_opts.position = Vector2(30, 226)
	_new_opts.size = Vector2(800, 340)
	_new_opts.mouse_filter = Control.MOUSE_FILTER_PASS
	_new_panel.add_child(_new_opts)

	var back := _small_button(_new_panel, "‹ BACK  ESC", Vector2(30, 568), false)
	back.pressed.connect(func() -> void: _show_screen("character"))
	var gs := _small_button(_new_panel, "GAME SETTINGS", Vector2(212, 568), false)
	gs.pressed.connect(_open_settings_from_new)
	_new_start = _small_button(_new_panel, "START FARM", Vector2(830 - (_text_w("START FARM", F_SMALL) + 36.0), 568), true)
	_new_start.pressed.connect(_on_start_new)


func _open_settings_from_new() -> void:
	_settings_return = "new"
	_show_screen("settings")


## Opens the New Game screen with fresh defaults. slot = -1 picks one automatically.
func _open_new_game(slot: int = -1) -> void:
	_new_cfg = {"difficulty": "normal", "day_length": "normal", "starter_kit": "full", "mode": "survival"}
	if _new_seed:
		_new_seed.text = ""
	_farm_name_touched = false
	_char_name_touched = false
	_char_index = 0
	_new_farmer.text = "KEN"
	_new_farm.text = _default_farm_name("KEN")
	_new_slot = slot if slot >= 0 else SaveManager.suggest_new_slot()
	_show_screen("character")


## Step 2 of New Game: names, difficulty and slot.
func _open_new_setup() -> void:
	var c: Dictionary = Characters.PLAYABLE[_char_index]
	if not _char_name_touched:
		_new_farmer.text = str(c["name"])
		if not _farm_name_touched:
			_new_farm.text = _default_farm_name(_new_farmer.text)
	_show_screen("new")
	_new_farmer.grab_focus()
	_new_farmer.caret_column = _new_farmer.text.length()


func _default_farm_name(farmer: String) -> String:
	var n := farmer.strip_edges().to_upper()
	if n.is_empty():
		n = "KEN"
	return (n + "'S FARM").left(20)


func _on_farmer_changed(t: String) -> void:
	if _new_farmer.has_focus():
		_char_name_touched = true
	if not _farm_name_touched:
		_new_farm.text = _default_farm_name(t)


func _rebuild_new_opts() -> void:
	for c in _new_opts.get_children():
		c.queue_free()
	var y := 0.0
	var mode: String = _new_cfg.get("mode", "survival")
	y = _seg_row(_new_opts, y, "GAME MODE", NEW_MODE_DESC[mode],
		[["survival", "SURVIVAL", C_RED_DARK], ["creative", "CREATIVE", Color("3E7A3A")]], mode,
		func(id: Variant) -> void: _set_new_cfg("mode", id))
	var diff: String = _new_cfg["difficulty"]
	y = _seg_row(_new_opts, y, "DIFFICULTY", NEW_DIFFICULTY_DESC[diff],
		[["easy", "EASY", Color("3E7A3A")], ["normal", "NORMAL", C_PANEL_HI], ["hard", "HARD", C_RED_DARK]], diff,
		func(id: Variant) -> void: _set_new_cfg("difficulty", id))
	var day: String = _new_cfg["day_length"]
	y = _seg_row(_new_opts, y, "DAY LENGTH", NEW_DAY_DESC[day],
		[["short", "SHORT", C_PANEL_HI], ["normal", "NORMAL", C_PANEL_HI], ["long", "LONG", C_PANEL_HI]], day,
		func(id: Variant) -> void: _set_new_cfg("day_length", id))
	var kit: String = _new_cfg["starter_kit"]
	y = _seg_row(_new_opts, y, "STARTER KIT", NEW_KIT_DESC[kit],
		[["full", "FULL", C_PANEL_HI], ["basic", "BASIC", C_PANEL_HI]], kit,
		func(id: Variant) -> void: _set_new_cfg("starter_kit", id))
	var info := SaveManager.get_slot(_new_slot)
	var slot_desc := "EMPTY · YOUR FARM SAVES HERE."
	var slot_col := C_TEXT_DIM
	if not info.is_empty():
		slot_desc = "OVERWRITES " + str(info.get("farm_name", "FARM")).to_upper()
		slot_col = Color("E8A898")
	var slot_opts: Array = []
	for i in SaveManager.SLOT_COUNT:
		slot_opts.append([i, "SLOT %d" % (i + 1), C_PANEL_HI])
	_seg_row(_new_opts, y, "SAVE SLOT", slot_desc, slot_opts, _new_slot, _pick_new_slot, slot_col)


func _pick_new_slot(id: Variant) -> void:
	_new_slot = int(id)
	_overwrite_armed = false
	_set_button_text(_new_start, "START FARM")
	_rebuild_new_opts()


func _set_new_cfg(key: String, value: Variant) -> void:
	_new_cfg[key] = value
	_rebuild_new_opts()


## Row with segmented buttons on the right. options: [[id, label, on_color], ...]
func _seg_row(parent: Control, y: float, title: String, desc: String, options: Array, current: Variant, on_pick: Callable, desc_col: Color = C_TEXT_DIM) -> float:
	var row := _row_in(parent, Vector2(0, y), 800.0, title, desc, desc_col)
	var widths: Array = []
	var total := 0.0
	for o in options:
		var w := _text_w(str(o[1]), F_SMALL) + 28.0
		widths.append(w)
		total += w + 4.0
	var x := 784.0 - total + 4.0
	for i in options.size():
		var o: Array = options[i]
		var id: Variant = o[0]
		var b := _seg_button(row, str(o[1]), Vector2(x, 15), id == current, o[2], widths[i])
		b.pressed.connect(func() -> void: on_pick.call(id))
		x += float(widths[i]) + 4.0
	return y + 66.0


func _on_start_new() -> void:
	var existing := SaveManager.get_slot(_new_slot)
	if not existing.is_empty() and not _overwrite_armed:
		_overwrite_armed = true
		_set_button_text(_new_start, "OVERWRITE?")
		return
	var farmer := _new_farmer.text.strip_edges().to_upper()
	if farmer.is_empty():
		farmer = "KEN"
	var farm := _new_farm.text.strip_edges().to_upper()
	if farm.is_empty():
		farm = _default_farm_name(farmer)
	SaveManager.create_new_game(_new_slot, {
		"farmer_name": farmer,
		"farm_name": farm,
		"difficulty": _new_cfg["difficulty"],
		"day_length": _new_cfg["day_length"],
		"starter_kit": _new_cfg["starter_kit"],
		"character": str(Characters.PLAYABLE[_char_index]["id"]),
		"mode": str(_new_cfg.get("mode", "survival")),
		"world_seed": _seed_from_text(_new_seed.text if _new_seed else ""),
	})
	_start_game()


## Numbers are used as they are; words are turned into a number, so "HARVEST" is
## always the same world. Empty = a random world.
func _seed_from_text(t: String) -> int:
	t = t.strip_edges()
	if t.is_empty():
		return 0
	if t.is_valid_int():
		return maxi(1, absi(int(t)) & 0x7FFFFFFF)
	return maxi(1, absi(hash(t.to_upper())) & 0x7FFFFFFF)


func _line_edit(parent: Control, pos: Vector2, w: float, max_len: int) -> LineEdit:
	var le := LineEdit.new()
	le.position = pos
	le.size = Vector2(w, 40)
	le.max_length = max_len
	le.context_menu_enabled = false
	le.caret_blink = true
	le.mouse_default_cursor_shape = Control.CURSOR_IBEAM
	le.add_theme_font_override("font", _font)
	le.add_theme_font_size_override("font_size", F_SMALL)
	le.add_theme_color_override("font_color", Color("F6EBCF"))
	le.add_theme_color_override("font_placeholder_color", C_TEXT_DIM)
	le.add_theme_color_override("caret_color", C_GOLD_LIGHT)
	le.add_theme_color_override("selection_color", Color(C_GOLD, 0.35))
	var st := _box(Color("0E0A08"), C_BORDER, 2, false)
	st.content_margin_left = 12
	st.content_margin_right = 12
	var fo := _box(Color(0, 0, 0, 0), C_GOLD, 2, false)
	fo.draw_center = false
	le.add_theme_stylebox_override("normal", st)
	le.add_theme_stylebox_override("read_only", st)
	le.add_theme_stylebox_override("focus", fo)
	# The title font is drawn in capitals, so names are kept upper-case.
	le.text_changed.connect(func(t: String) -> void:
		var up := t.to_upper()
		if up != t:
			var c := le.caret_column
			le.text = up
			le.caret_column = c)
	parent.add_child(le)
	return le


# ==========================================================================
# Character select (New Game step 1)
# ==========================================================================

func _build_char_panel() -> void:
	_char_panel = _panel(_stage, Vector2(130, 40), Vector2(1020, 640), _box(C_PANEL, C_BORDER, 3, true))
	_char_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_label(_char_panel, "CHOOSE YOUR FARMER", F_HEAD, C_TEXT, Vector2(30, 22))
	var sub := "STEP 1 OF 2"
	_label(_char_panel, sub, F_SMALL, C_TEXT_DIM, Vector2(990 - _text_w(sub, F_SMALL), 46))
	_color_rect(_char_panel, Color("4A3420"), Vector2(30, 82), Vector2(960, 3))
	var n := Characters.PLAYABLE.size()
	var cw := 304.0
	var gap := (960.0 - cw * n) / maxf(1.0, n - 1)
	for i in n:
		var c: Dictionary = Characters.PLAYABLE[i]
		var card := _panel(_char_panel, Vector2(30 + i * (cw + gap), 100), Vector2(cw, 448), _box(C_ROW, C_BORDER_DIM, 3, true))
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var idx := i
		card.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				if _char_index == idx and ev.double_click:
					_open_new_setup()
				else:
					_pick_char(idx))
		var stage_bg := _gradient_rect(card, [0.0, 1.0], [Color(1.0, 0.8, 0.45, 0.22), Color(1.0, 0.8, 0.45, 0.0)], Vector2(32, 24), Vector2(240, 240))
		stage_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_color_rect(card, Color(0, 0, 0, 0.35), Vector2(102, 222), Vector2(100, 10))
		var spr := Strip.new()
		_setup_strip(spr, Vector2(192, 192))
		spr.position = Vector2(56, 40)
		card.add_child(spr)
		spr.play(load(c["sheet"]), _row_frames(0, 2, 32, 32), 2.0)
		_char_previews.append(spr)
		var name_txt: String = c["name"]
		_label(card, name_txt, F_TIME, C_TEXT, Vector2(roundf((cw - _text_w(name_txt, F_TIME)) * 0.5), 248))
		var t: String = c["title"]
		_label(card, t, F_SMALL, C_GOLD, Vector2(roundf((cw - _text_w(t, F_SMALL)) * 0.5), 296))
		var perk := Label.new()
		_style_label(perk, c["perk"], F_SMALL, Color("BFE3A0"))
		perk.autowrap_mode = TextServer.AUTOWRAP_WORD
		perk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		perk.position = Vector2(18, 330)
		perk.size = Vector2(cw - 36, 50)
		card.add_child(perk)
		var bio := Label.new()
		_style_label(bio, c["bio"], F_SMALL, C_TEXT_DIM)
		bio.autowrap_mode = TextServer.AUTOWRAP_WORD
		bio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bio.position = Vector2(18, 386)
		bio.size = Vector2(cw - 36, 50)
		card.add_child(bio)
		_char_cards.append(card)
	var back := _small_button(_char_panel, "‹ BACK  ESC", Vector2(30, 568), false)
	back.pressed.connect(func() -> void: _show_screen("main"))
	var hint := "A/D OR CLICK TO CHOOSE"
	_label(_char_panel, hint, F_SMALL, C_TEXT_DIM, Vector2(roundf((1020 - _text_w(hint, F_SMALL)) * 0.5), 583))
	var nxt := _small_button(_char_panel, "NEXT ›", Vector2(990 - (_text_w("NEXT ›", F_SMALL) + 36.0), 568), true)
	nxt.pressed.connect(_open_new_setup)


func _pick_char(i: int) -> void:
	if i == _char_index:
		return
	_char_index = i
	_refresh_char_cards()
	if _sfx_hit:
		_sfx_hit.pitch_scale = 1.6
		_sfx_hit.volume_db = -14.0
		_sfx_hit.play()
		get_tree().create_timer(0.2).timeout.connect(func() -> void:
			_sfx_hit.pitch_scale = 1.0
			_sfx_hit.volume_db = -2.0)


func _refresh_char_cards() -> void:
	for i in _char_cards.size():
		var sel := i == _char_index
		_char_cards[i].add_theme_stylebox_override("panel", _box(Color("2E2014") if sel else C_ROW, C_GOLD if sel else C_BORDER_DIM, 3, true))
		_char_cards[i].modulate = Color.WHITE if sel else Color(0.72, 0.72, 0.78)
		var sheet: Texture2D = load(Characters.PLAYABLE[i]["sheet"])
		if sel:
			_char_previews[i].play(sheet, _row_frames(1, 6, 32, 32), 9.0)
		else:
			_char_previews[i].play(sheet, _row_frames(0, 2, 32, 32), 2.0)


# ==========================================================================
# Settings
# ==========================================================================

func _build_settings_panel() -> void:
	_settings_panel = _panel(_stage, Vector2(170, 36), Vector2(940, 648), _box(C_PANEL, C_BORDER, 3, true))
	_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_label(_settings_panel, "SETTINGS", F_HEAD, C_TEXT, Vector2(30, 22))
	var x := 30.0
	for t in [["audio", "AUDIO"], ["video", "VIDEO"], ["graphics", "GRAPHICS"], ["controls", "CONTROLS"], ["updates", "UPDATES"]]:
		var w := _text_w(t[1], F_SMALL) + 40.0
		var b := Button.new()
		b.position = Vector2(x, 82)
		b.size = Vector2(w, 42)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_settings_panel.add_child(b)
		_label(b, t[1], F_SMALL, C_TEXT_DIM, Vector2(20, 12))
		var tab_id: String = t[0]
		b.pressed.connect(func() -> void: _select_tab(tab_id))
		_tab_buttons[tab_id] = b
		x += w + 8.0
	_color_rect(_settings_panel, Color("4A3420"), Vector2(30, 124), Vector2(880, 3))
	_settings_body = Control.new()
	_settings_body.position = Vector2(30, 142)
	_settings_body.size = Vector2(880, 420)
	_settings_body.mouse_filter = Control.MOUSE_FILTER_PASS
	_settings_panel.add_child(_settings_body)
	var back := _small_button(_settings_panel, "‹ BACK  ESC", Vector2(30, 580), false)
	back.pressed.connect(func() -> void: _show_screen(_settings_return))
	var reset := _small_button(_settings_panel, "RESET TO DEFAULTS", Vector2(610, 580), false)
	reset.pressed.connect(func() -> void: GameSettings.reset_to_defaults())


func _select_tab(id: String) -> void:
	_settings_tab = id
	for k in _tab_buttons:
		var b: Button = _tab_buttons[k]
		var on: bool = k == id
		var st := _box(Color("2E2014") if on else Color(0, 0, 0, 0), C_BORDER if on else Color(0, 0, 0, 0), 3, false)
		for s in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(s, st)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		(b.get_child(0) as Label).add_theme_color_override("font_color", C_GOLD_LIGHT if on else C_TEXT_DIM)
	_rebuild_settings_body()


func _rebuild_settings_body() -> void:
	for c in _settings_body.get_children():
		c.queue_free()
	if not has_node("/root/GameSettings"):
		return
	var gs := GameSettings
	var y := 0.0
	match _settings_tab:
		"audio":
			y = _slider_row(y, "MASTER VOLUME", "EVERYTHING AT ONCE.", "master_volume", gs.master_volume)
			y = _slider_row(y, "MUSIC", "BACKGROUND MUSIC.", "music_volume", gs.music_volume)
			y = _slider_row(y, "SOUND EFFECTS", "TOOLS, CROPS, ZOMBIES, MENUS.", "sfx_volume", gs.sfx_volume)
		"video":
			y = _choice_row(y, "DISPLAY MODE", "ALSO TOGGLED IN GAME WITH F11.", ["WINDOWED", "FULLSCREEN"], 1 if gs.fullscreen else 0,
				func(idx: int) -> void: gs.set_value("fullscreen", idx == 1))
			y = _toggle_row(y, "V-SYNC", "PREVENTS SCREEN TEARING.", gs.vsync, func(v: bool) -> void: gs.set_value("vsync", v))
			y = _toggle_row(y, "PIXEL-PERFECT SCALING", "KEEPS THE PIXEL ART CRISP. MAY ADD BLACK BORDERS.", gs.pixel_perfect,
				func(v: bool) -> void: gs.set_value("pixel_perfect", v))
		"graphics":
			y = _preset_row(y, gs.quality)
			var p: Dictionary = gs.preset()
			var fps := int(p["max_fps"])
			y = _info_row(y, "FRAME RATE LIMIT", "LOWER USES LESS BATTERY AND POWER.", "UNLIMITED" if fps == 0 else "%d FPS" % fps)
			y = _info_row(y, "LIGHTING", "TORCH AND LAMP SHADOWS AT NIGHT.", "FULL" if p["shadows"] else "SIMPLE")
			var parts := float(p["particles"])
			y = _info_row(y, "PARTICLES", "FOG, DUST AND OTHER EFFECTS.", "FULL" if parts >= 1.0 else ("REDUCED" if parts > 0.0 else "OFF"))
			y = _info_row(y, "MENU ANIMATION", "CLOUDS, PARALLAX AND FIREFLIES ON THIS SCREEN.", ["STILL", "REDUCED", "FULL"][int(p["menu_fx"])])
		"controls":
			_build_controls()
		"updates":
			_build_updates_tab()


func _row_box(y: float, title: String, desc: String) -> Panel:
	return _row_in(_settings_body, Vector2(0, y), 880.0, title, desc)


func _row_in(parent: Control, pos: Vector2, w: float, title: String, desc: String, desc_col: Color = C_TEXT_DIM) -> Panel:
	var row := _panel(parent, pos, Vector2(w, 62), _box(C_ROW, Color("3A2818"), 2, false))
	_label(row, title, F_SMALL, C_TEXT, Vector2(16, 9))
	_label(row, desc, F_SMALL, desc_col, Vector2(16, 34))
	return row


func _slider_row(y: float, title: String, desc: String, key: String, value: float) -> float:
	var row := _row_box(y, title, desc)
	var s := HSlider.new()
	s.position = Vector2(520, 19)
	s.size = Vector2(260, 24)
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.focus_mode = Control.FOCUS_NONE
	var track := _box(Color("0E0A08"), Color("574029"), 2, false)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	s.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = C_GOLD
	fill.content_margin_top = 8
	fill.content_margin_bottom = 8
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var grab := _solid_texture(Vector2i(10, 22), C_GOLD_LIGHT)
	s.add_theme_icon_override("grabber", grab)
	s.add_theme_icon_override("grabber_highlight", grab)
	row.add_child(s)
	var val := _label(row, str(int(round(value * 100))), F_BIG, Color("F6EBCF"), Vector2(800, 17))
	var on_change := func(v: float) -> void:
		val.text = str(int(round(v * 100)))
		GameSettings.set(key, v)
		GameSettings.apply_audio()
	s.value_changed.connect(on_change)
	s.drag_ended.connect(func(_changed: bool) -> void: GameSettings.save_settings())
	return y + 72.0


func _choice_row(y: float, title: String, desc: String, options: Array, current: int, on_pick: Callable) -> float:
	var row := _row_box(y, title, desc)
	var left := _arrow_button(row, "◀", Vector2(560, 15))
	var val_text: String = options[current]
	var cw := 220.0
	_label(row, val_text, F_SMALL, Color("F6EBCF"), Vector2(600 + roundf((cw - _text_w(val_text, F_SMALL)) * 0.5), 22))
	var right := _arrow_button(row, "▶", Vector2(830, 15))
	left.pressed.connect(func() -> void: on_pick.call((current - 1 + options.size()) % options.size()))
	right.pressed.connect(func() -> void: on_pick.call((current + 1) % options.size()))
	return y + 72.0


func _toggle_row(y: float, title: String, desc: String, value: bool, on_set: Callable) -> float:
	var row := _row_box(y, title, desc)
	var on_b := _seg_button(row, "ON", Vector2(744, 15), value, Color("3E7A3A"))
	var off_b := _seg_button(row, "OFF", Vector2(800, 15), not value, C_RED_DARK)
	on_b.pressed.connect(func() -> void: on_set.call(true))
	off_b.pressed.connect(func() -> void: on_set.call(false))
	return y + 72.0


func _preset_row(y: float, current: String) -> float:
	var row := _panel(_settings_body, Vector2(0, y), Vector2(880, 72), _box(Color("2A1C10"), C_BORDER, 2, false))
	_label(row, "GRAPHICS PRESET", F_SMALL, C_GOLD_LIGHT, Vector2(16, 12))
	var notes := {"low": "BEST FOR OLDER PHONES AND LOW-END LAPTOPS.", "medium": "BALANCED LOOK AND SPEED FOR MOST DEVICES.", "high": "FULL EFFECTS. FOR GAMING PCS AND NEWER DEVICES."}
	_label(row, notes[current], F_SMALL, Color("C9B794"), Vector2(16, 40))
	var x := 616.0
	for p in [["low", "LOW"], ["medium", "MEDIUM"], ["high", "HIGH"]]:
		var w := _text_w(p[1], F_SMALL) + 28.0
		var b := _seg_button(row, p[1], Vector2(x, 18), p[0] == current, C_PANEL_HI, w)
		var id: String = p[0]
		b.pressed.connect(func() -> void: GameSettings.set_value("quality", id))
		x += w + 4.0
	return y + 82.0


func _info_row(y: float, title: String, desc: String, value: String) -> float:
	var row := _row_box(y, title, desc)
	_label(row, value, F_SMALL, Color("F6EBCF"), Vector2(864 - _text_w(value, F_SMALL), 22))
	return y + 72.0


## v1.3.1: the keys can be changed here (same list as the in-game Settings).
func _build_controls() -> void:
	var sp: Control = load("res://scripts/systems/settings_panel.gd").new()
	sp.set("controls_only", true)
	sp.size = _settings_body.size
	_settings_body.add_child(sp)


## Key names for actions, e.g. ["move_up", ...] -> "W A S D".
## first_only: use only the first event of each action and join with spaces.
func _keys_for(actions: Array, first_only: int = -1) -> String:
	var parts: PackedStringArray = []
	for a in actions:
		if not InputMap.has_action(a):
			continue
		var evs := InputMap.action_get_events(a)
		var names: PackedStringArray = []
		for ev in evs:
			names.append(_event_name(ev))
		if names.is_empty():
			continue
		if first_only == 0 or actions.size() > 1:
			parts.append(names[0])
		else:
			parts.append(" / ".join(names))
	return " ".join(parts) if not parts.is_empty() else "-"


func _event_name(ev: InputEvent) -> String:
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "LEFT CLICK"
			MOUSE_BUTTON_RIGHT:
				return "RIGHT CLICK"
			MOUSE_BUTTON_MIDDLE:
				return "MIDDLE MOUSE"
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code := k.keycode if k.keycode != KEY_NONE else k.physical_keycode
		return OS.get_keycode_string(code).to_upper()
	return ev.as_text().to_upper()


# ==========================================================================
# Updates
# ==========================================================================

func _connect_updates() -> void:
	if not has_node("/root/UpdateManager"):
		return
	var um := get_node("/root/UpdateManager")
	_update_badge = Button.new()
	_update_badge.position = Vector2(28, 28)
	_update_badge.size = Vector2(300, 64)
	_update_badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var st := _box(Color(0.12, 0.18, 0.08, 0.95), Color("8FD14F"), 3, true)
	for s in ["normal", "hover", "pressed"]:
		_update_badge.add_theme_stylebox_override(s, st)
	_update_badge.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_label(_update_badge, "UPDATE AVAILABLE", F_SMALL, Color("BFE3A0"), Vector2(16, 10))
	_label(_update_badge, "OPEN SETTINGS › UPDATES", F_SMALL, Color("F6EBCF"), Vector2(16, 34))
	_update_badge.pressed.connect(func() -> void:
		_settings_return = "main"
		_settings_tab = "updates"
		_show_screen("settings"))
	_update_badge.visible = false
	_main_ui.add_child(_update_badge)
	um.check_finished.connect(func(result: String, _info: Dictionary) -> void:
		_update_badge.visible = result == "update"
		if _settings_panel.visible and _settings_tab == "updates":
			_rebuild_settings_body())
	um.download_progress.connect(func(ratio: float, done: int, total: int) -> void:
		if _update_progress_label and is_instance_valid(_update_progress_label):
			if total > 0:
				_update_progress_label.text = "%d%%  ·  %.1f / %.1f MB" % [int(ratio * 100.0), done / 1048576.0, total / 1048576.0]
			else:
				_update_progress_label.text = "%.1f MB" % (done / 1048576.0))
	um.download_finished.connect(func(_ok: bool, _msg: String) -> void:
		if _settings_panel.visible and _settings_tab == "updates":
			_rebuild_settings_body())
	um.check_started.connect(func() -> void:
		if _settings_panel.visible and _settings_tab == "updates":
			_rebuild_settings_body())
	um.mark_boot_ok()
	_update_badge.visible = um.state == "available"


func _build_updates_tab() -> void:
	_update_progress_label = null
	if not has_node("/root/UpdateManager"):
		_info_row(0.0, "UPDATES", "NOT AVAILABLE IN THIS BUILD.", "-")
		return
	var um := get_node("/root/UpdateManager")
	var y := 0.0
	y = _info_row(y, "GAME VERSION", "YOUR SAVES AND SETTINGS ARE KEPT WHEN YOU UPDATE.", "V" + str(um.current_version))
	var row := _row_box(y, "STATUS", str(um.status_text))
	match str(um.state):
		"checking":
			_label(row, "PLEASE WAIT...", F_SMALL, C_TEXT_SOFT, Vector2(864 - _text_w("PLEASE WAIT...", F_SMALL), 22))
		"available":
			var b := _small_button(row, "DOWNLOAD & INSTALL", Vector2(864 - (_text_w("DOWNLOAD & INSTALL", F_SMALL) + 36.0), 7), true)
			b.size.y = 48
			b.pressed.connect(func() -> void:
				um.download_update()
				_rebuild_settings_body())
		"downloading":
			_update_progress_label = _label(row, "0%", F_SMALL, C_GOLD_LIGHT, Vector2(620, 22))
		"ready":
			var b := _small_button(row, "RESTART NOW", Vector2(864 - (_text_w("RESTART NOW", F_SMALL) + 36.0), 7), true)
			b.pressed.connect(func() -> void: um.restart_game())
		_:
			var b := _small_button(row, "CHECK NOW", Vector2(864 - (_text_w("CHECK NOW", F_SMALL) + 36.0), 7), true)
			b.pressed.connect(func() -> void: um.check_for_updates())
	y += 72.0
	var notes: Array = um.latest_info.get("notes", []) if um.state in ["available", "downloading", "ready"] else um.installed_notes()
	if not notes.is_empty():
		var box := _panel(_settings_body, Vector2(0, y), Vector2(880, 124), _box(Color("1A120B"), Color("3A2818"), 2, false))
		_label(box, "WHAT'S NEW", F_SMALL, C_GOLD, Vector2(16, 10))
		for i in mini(notes.size(), 4):
			_label(box, "· " + str(notes[i]).to_upper().left(70), F_SMALL, C_TEXT_SOFT, Vector2(16, 36 + i * 21))
		y += 134.0
	y = _toggle_row(y, "CHECK AUTOMATICALLY", "LOOK FOR UPDATES EACH TIME THE GAME STARTS.", bool(um.auto_check),
		func(v: bool) -> void:
			um.set_auto_check(v)
			_rebuild_settings_body())
	if um.has_installed_update():
		var r2 := _row_box(y, "INSTALLED UPDATE", "SOMETHING WRONG AFTER AN UPDATE? GO BACK TO V%s." % um.BASE_VERSION)
		var rb := _small_button(r2, "REMOVE", Vector2(864 - (_text_w("REMOVE", F_SMALL) + 36.0), 7), false, true)
		rb.pressed.connect(func() -> void:
			um.remove_installed_update()
			_rebuild_settings_body())


# ==========================================================================
# Quit
# ==========================================================================

func _build_quit_panel() -> void:
	_quit_panel = _panel(_stage, Vector2(400, 190), Vector2(480, 320), _box(C_PANEL, C_BORDER, 3, true))
	_quit_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ic := _tex_rect(_quit_panel, _atlas(load(UI + "menu_icons.png"), Rect2(64, 0, 16, 16)), Vector2(208, 24), Vector2(64, 64))
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := "LEAVE THE FARM?"
	_label(_quit_panel, t, F_TIME, C_TEXT, Vector2(roundf((480 - _text_w(t, F_TIME)) * 0.5), 104))
	var body := Label.new()
	_style_label(body, "ANYTHING SINCE YOUR LAST SAVE WILL BE LOST. THE ZOMBIES WILL STILL BE HERE TOMORROW NIGHT.", F_SMALL, C_TEXT_SOFT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.position = Vector2(30, 160)
	body.size = Vector2(420, 60)
	_quit_panel.add_child(body)
	var stay := _small_button(_quit_panel, "STAY", Vector2(110, 244), true)
	stay.pressed.connect(func() -> void: _show_screen("main"))
	var leave := _small_button(_quit_panel, "QUIT GAME", Vector2(232, 244), false, true)
	leave.pressed.connect(func() -> void: get_tree().quit())


# ==========================================================================
# Sound
# ==========================================================================

func _build_sounds() -> void:
	_sfx_hit = _player(UI + "sfx_hit.wav", -2.0)
	_sfx_groan = _player(UI + "sfx_groan.wav", -4.0)
	_sfx_unlock = _player(UI + "sfx_unlock.wav", -6.0)


func _player(path: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	add_child(p)
	return p


# ==========================================================================
# Loop & input
# ==========================================================================

func _process(delta: float) -> void:
	_time += delta
	_update_ambient(delta)
	_update_zombies(delta)
	_update_ken(delta)
	if _screen == "main" and _focused_menu != -1:
		var b: Button = _menu_info[_focused_menu]["button"]
		b.position.y = 600.0 - 4.0 - (3.0 if fmod(_time, 1.6) < 0.8 else 0.0)
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time < 0.4:
			_toast.modulate.a = maxf(_toast_time / 0.4, 0.0)
		if _toast_time <= 0.0:
			_toast.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_active = true
		_mouse_stage_x = _stage.get_local_mouse_position().x


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_menu"):
		match _screen:
			"main":
				_show_screen("quit")
			"settings":
				_show_screen(_settings_return)
			"new":
				_show_screen("character")
			_:
				_show_screen("main")
		get_viewport().set_input_as_handled()
		return
	if _screen == "character":
		if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
			_pick_char((_char_index - 1 + Characters.PLAYABLE.size()) % Characters.PLAYABLE.size())
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
			_pick_char((_char_index + 1) % Characters.PLAYABLE.size())
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_accept"):
			_open_new_setup()
			get_viewport().set_input_as_handled()
		return
	if _screen != "main" or _menu_buttons.is_empty():
		return
	var step := 0
	if event.is_action_pressed("move_left"):
		step = -1
	elif event.is_action_pressed("move_right"):
		step = 1
	if step != 0:
		var cur := maxi(_focused_menu, 0)
		_menu_buttons[(cur + step + _menu_buttons.size()) % _menu_buttons.size()].grab_focus()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_active = false


# ==========================================================================
# Small builders
# ==========================================================================

func _text_w(text: String, font_size: int) -> float:
	return float(text.length()) * 6.0 * float(font_size) / 9.0


func _style_label(l: Label, text: String, font_size: int, color: Color) -> void:
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _label(parent: Control, text: String, font_size: int, color: Color, pos: Vector2) -> Label:
	var l := Label.new()
	_style_label(l, text, font_size, color)
	l.position = pos
	parent.add_child(l)
	return l


func _box(bg: Color, border: Color, bw: int, shadow: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.anti_aliasing = false
	if shadow:
		s.shadow_color = Color(C_SHADOW, 0.9)
		s.shadow_size = 1
		s.shadow_offset = Vector2(0, 5)
	return s


func _panel(parent: Control, pos: Vector2, sz: Vector2, style: StyleBox) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = sz
	p.add_theme_stylebox_override("panel", style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func _small_button(parent: Control, text: String, pos: Vector2, primary: bool, danger: bool = false) -> Button:
	var b := Button.new()
	b.position = pos
	var w := _text_w(text, F_SMALL) + 36.0
	b.size = Vector2(w, 48)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var border := C_GOLD if primary else (C_RED_DARK if danger else C_BTN_BORDER)
	var normal := _box(C_PANEL_HI if primary else C_ROW, border, 3, true)
	var hover := _box(C_PANEL_HI, C_GOLD_LIGHT if primary else C_GOLD, 3, true)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(b)
	var col := C_GOLD_LIGHT if primary else (Color("E8A898") if danger else C_TEXT)
	_label(b, text, F_SMALL, col, Vector2(18, 15))
	return b


func _set_button_text(b: Button, text: String) -> void:
	for c in b.get_children():
		if c is Label:
			(c as Label).text = text


func _arrow_button(parent: Control, text: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = Vector2(36, 32)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var st := _box(Color("120C08"), C_BORDER, 2, false)
	var hv := _box(C_PANEL_HI, C_GOLD, 2, false)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(b)
	_label(b, text, F_SMALL, C_GOLD, Vector2(12, 7))
	return b


func _seg_button(parent: Control, text: String, pos: Vector2, on: bool, on_color: Color, w: float = 52.0) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = Vector2(w, 32)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var st := _box(on_color if on else Color("0E0A08"), Color("574029"), 2, false)
	var hv := _box(on_color if on else C_PANEL_HI, C_GOLD, 2, false)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(b)
	_label(b, text, F_SMALL, Color("F6EBCF") if on else Color("6E5A40"), Vector2(roundf((w - _text_w(text, F_SMALL)) * 0.5), 7))
	return b


func _tex_rect(parent: Control, tex: Texture2D, pos: Vector2, sz: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = pos
	r.size = sz
	parent.add_child(r)
	return r


func _setup_strip(s: Strip, sz: Vector2) -> void:
	s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s.stretch_mode = TextureRect.STRETCH_SCALE
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.size = sz


func _color_rect(parent: Control, c: Color, pos: Vector2, sz: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.position = pos
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## Soft radial blob (glows, fog banks).
func _soft_rect(parent: Control, c: Color, pos: Vector2, sz: Vector2) -> TextureRect:
	var r := _gradient_rect(parent, [0.0, 1.0], [c, Color(c, 0.0)], pos, sz)
	return r


func _gradient_rect(parent: Control, offsets: Array, colors: Array, pos: Vector2, sz: Vector2) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	var r := _tex_rect(parent, t, pos, sz)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return r


func _atlas(tex: Texture2D, region: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = region
	return a


func _row_frames(row: int, count: int, w: int, h: int) -> Array:
	var out: Array = []
	for i in count:
		out.append(Rect2(i * w, row * h, w, h))
	return out


func _solid_texture(sz: Vector2i, c: Color) -> ImageTexture:
	var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)
