extends Control
class_name ChestUI

signal opened
signal closed

const ItemDataClass = preload("res://scripts/item_data.gd")
const ItemDatabaseScript = preload("res://scripts/item_database.gd")
const WorldItemScene = preload("res://Scenes/world_item.tscn")

var is_open: bool = false
var current_chest: ChestEntity = null
var current_player: Node2D = null

# Selection tracking for click/drop
var selected_source: String = "" # "player_hotbar", "player_backpack", "chest"
var selected_index: int = -1

# Quantity modal state
var modal_source: String = ""
var modal_index: int = -1
var modal_max_amount: int = 1
var modal_current_amount: int = 1

var _slots_initialized: bool = false
var hotbar_panels: Array[PanelContainer] = []
var backpack_panels: Array[PanelContainer] = []
var chest_panels: Array[PanelContainer] = []

@onready var panel_container: PanelContainer = $CenterContainer/PanelContainer
@onready var player_hotbar_grid: HBoxContainer = $CenterContainer/PanelContainer/MarginContainer/HBoxContainer/PlayerSection/HotbarGrid
@onready var player_backpack_grid: GridContainer = $CenterContainer/PanelContainer/MarginContainer/HBoxContainer/PlayerSection/BackpackGrid
@onready var chest_grid: GridContainer = $CenterContainer/PanelContainer/MarginContainer/HBoxContainer/ChestSection/ChestGrid
@onready var chest_icon_preview: TextureRect = $CenterContainer/PanelContainer/MarginContainer/HBoxContainer/ChestSection/HeaderHBox/ChestIcon
@onready var close_button: Button = $CenterContainer/PanelContainer/MarginContainer/HBoxContainer/ChestSection/HeaderHBox/CloseBtn
@onready var take_all_button: Button = $CenterContainer/PanelContainer/MarginContainer/HBoxContainer/ChestSection/BottomHBox/TakeAllBtn
@onready var store_all_button: Button = $CenterContainer/PanelContainer/MarginContainer/HBoxContainer/PlayerSection/BottomHBox/StoreAllBtn
@onready var drop_button: Button = $CenterContainer/PanelContainer/MarginContainer/HBoxContainer/PlayerSection/BottomHBox/DropBtn
@onready var info_label: Label = $CenterContainer/PanelContainer/MarginContainer/HBoxContainer/ChestSection/InfoLabel

# Quantity Modal Nodes
@onready var quantity_modal: CenterContainer = $QuantityModal
@onready var modal_item_icon: TextureRect = $QuantityModal/ModalPanel/Margin/VBox/ItemRow/ModalItemIcon
@onready var modal_item_label: Label = $QuantityModal/ModalPanel/Margin/VBox/ItemRow/ModalItemLabel
@onready var quantity_slider: HSlider = $QuantityModal/ModalPanel/Margin/VBox/SliderRow/QuantitySlider
@onready var amount_label: Label = $QuantityModal/ModalPanel/Margin/VBox/SliderRow/AmountLabel
@onready var minus_btn: Button = $QuantityModal/ModalPanel/Margin/VBox/SliderRow/MinusBtn
@onready var plus_btn: Button = $QuantityModal/ModalPanel/Margin/VBox/SliderRow/PlusBtn
@onready var quick_1_btn: Button = $QuantityModal/ModalPanel/Margin/VBox/QuickRow/Quick1Btn
@onready var quick_5_btn: Button = $QuantityModal/ModalPanel/Margin/VBox/QuickRow/Quick5Btn
@onready var quick_half_btn: Button = $QuantityModal/ModalPanel/Margin/VBox/QuickRow/QuickHalfBtn
@onready var quick_all_btn: Button = $QuantityModal/ModalPanel/Margin/VBox/QuickRow/QuickAllBtn
@onready var confirm_transfer_btn: Button = $QuantityModal/ModalPanel/Margin/VBox/ActionRow/ConfirmTransferBtn
@onready var cancel_transfer_btn: Button = $QuantityModal/ModalPanel/Margin/VBox/ActionRow/CancelTransferBtn


func _ready() -> void:
	add_to_group("container_ui")
	visible = false
	if quantity_modal:
		quantity_modal.visible = false
	
	if close_button:
		close_button.pressed.connect(close)
	if take_all_button:
		take_all_button.pressed.connect(_on_take_all_pressed)
	if store_all_button:
		store_all_button.pressed.connect(_on_store_all_pressed)
	if drop_button:
		drop_button.pressed.connect(_on_drop_selected_pressed)
	
	_connect_modal_signals()
	_ensure_slots_built()


func _connect_modal_signals() -> void:
	if quantity_slider:
		quantity_slider.value_changed.connect(_on_slider_value_changed)
	if minus_btn:
		minus_btn.pressed.connect(func(): _set_modal_amount(modal_current_amount - 1))
	if plus_btn:
		plus_btn.pressed.connect(func(): _set_modal_amount(modal_current_amount + 1))
	if quick_1_btn:
		quick_1_btn.pressed.connect(func(): _set_modal_amount(1))
	if quick_5_btn:
		quick_5_btn.pressed.connect(func(): _set_modal_amount(5))
	if quick_half_btn:
		quick_half_btn.pressed.connect(func(): _set_modal_amount(max(1, int(modal_max_amount / 2.0))))
	if quick_all_btn:
		quick_all_btn.pressed.connect(func(): _set_modal_amount(modal_max_amount))
	if confirm_transfer_btn:
		confirm_transfer_btn.pressed.connect(_on_confirm_modal_transfer)
	if cancel_transfer_btn:
		cancel_transfer_btn.pressed.connect(_close_quantity_modal)


func open_with_chest(chest: ChestEntity, player: Node2D) -> void:
	current_chest = chest
	current_player = player
	is_open = true
	visible = true
	selected_source = ""
	selected_index = -1
	_close_quantity_modal()
	
	_ensure_slots_built()
	
	if chest_icon_preview:
		chest_icon_preview.texture = ItemDatabaseScript.get_rpg_chest_texture(7, 3)
	
	if info_label:
		info_label.text = "💡 Drag to move • Right-Click to Split/Choose Amount"
	
	_update_all_visuals()
	
	# Smooth UI pop animation
	if panel_container:
		panel_container.scale = Vector2(0.9, 0.9)
		var tween := create_tween()
		tween.tween_property(panel_container, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	selected_source = ""
	selected_index = -1
	_close_quantity_modal()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	
	if quantity_modal and quantity_modal.visible:
		if event.is_action_pressed("interact") or event.is_action_pressed("toggle_inventory") or event.is_action_pressed("toggle_menu"):
			_close_quantity_modal()
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_close_quantity_modal()
			get_viewport().set_input_as_handled()
			return
	
	if event.is_action_pressed("interact") or event.is_action_pressed("toggle_inventory") or event.is_action_pressed("toggle_menu"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_G or event.keycode == KEY_E or event.keycode == KEY_F:
			close()
			get_viewport().set_input_as_handled()


# ==============================================================================
# ONE-TIME PERSISTENT SLOT PANEL GENERATION
# ==============================================================================

func _ensure_slots_built() -> void:
	if _slots_initialized:
		return
	
	if not player_hotbar_grid or not player_backpack_grid or not chest_grid:
		return
	
	_slots_initialized = true
	hotbar_panels.clear()
	backpack_panels.clear()
	chest_panels.clear()
	
	# 1. Build Player Hotbar 4 slots
	for child in player_hotbar_grid.get_children():
		child.queue_free()
	for i in range(4):
		var slot_panel = _create_slot_panel("player_hotbar", i, str(i + 1))
		player_hotbar_grid.add_child(slot_panel)
		hotbar_panels.append(slot_panel)
	
	# 2. Build Player Backpack 24 slots (6x4)
	for child in player_backpack_grid.get_children():
		child.queue_free()
	for i in range(24):
		var slot_panel = _create_slot_panel("player_backpack", i, "")
		player_backpack_grid.add_child(slot_panel)
		backpack_panels.append(slot_panel)
	
	# 3. Build Chest 24 slots (6x4)
	for child in chest_grid.get_children():
		child.queue_free()
	for i in range(24):
		var slot_panel = _create_slot_panel("chest", i, "")
		chest_grid.add_child(slot_panel)
		chest_panels.append(slot_panel)


func _create_slot_panel(source: String, index: int, slot_num_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(44, 44)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var style := StyleBoxFlat.new()
	if source == "player_hotbar":
		style.bg_color = Color(0.2, 0.15, 0.11, 0.95)
		style.border_color = Color(0.65, 0.5, 0.22, 1)
	elif source == "chest":
		style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
		style.border_color = Color(0.45, 0.45, 0.6, 1.0)
	else:
		style.bg_color = Color(0.16, 0.12, 0.09, 0.95)
		style.border_color = Color(0.38, 0.27, 0.17, 1)
	
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	
	# Centered container for item icon
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(center)
	
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(32, 32)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(icon)
	
	# Text overlay
	var text_layer := Control.new()
	text_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(text_layer)
	
	if slot_num_text != "":
		var num_lbl := Label.new()
		num_lbl.name = "SlotNum"
		num_lbl.text = slot_num_text
		num_lbl.add_theme_font_size_override("font_size", 9)
		num_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 0.95))
		num_lbl.position = Vector2(4, 2)
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_layer.add_child(num_lbl)
	
	var count_lbl := Label.new()
	count_lbl.name = "Count"
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_lbl.add_theme_font_size_override("font_size", 10)
	count_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	count_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	count_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	count_lbl.offset_left = 0
	count_lbl.offset_top = 0
	count_lbl.offset_right = -4
	count_lbl.offset_bottom = -2
	count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_layer.add_child(count_lbl)
	
	# Drag & Drop forwarding
	panel.set_drag_forwarding(
		Callable(self, "_get_slot_drag_data").bind(source, index),
		Callable(self, "_can_slot_drop_data"),
		Callable(self, "_slot_drop_data").bind(source, index)
	)
	
	# Handle Right-Click (Open Amount Modal) or Left Click
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_open_quantity_modal(source, index)
	)
	
	panel.mouse_entered.connect(func():
		_on_slot_hovered(source, index)
	)
	
	return panel


func _on_slot_hovered(source: String, index: int) -> void:
	if not info_label:
		return
	
	var slot_data: Dictionary = _get_slot_data(source, index)
	if slot_data.get("item") != null:
		var item: Resource = slot_data["item"]
		var item_name: String = item.get("display_name") if item.get("display_name") != null else "Item"
		info_label.text = "%s (x%d) — Right-Click to Split/Choose Amount" % [item_name, slot_data["amount"]]
	else:
		info_label.text = "💡 Drag to move • Right-Click to Split/Choose Amount"


# ==============================================================================
# QUANTITY TRANSFER MODAL (HOW MANY ITEMS TO TRANSFER)
# ==============================================================================

func _open_quantity_modal(source: String, index: int) -> void:
	var slot_data := _get_slot_data(source, index)
	if slot_data.get("item") == null or slot_data.get("amount", 0) <= 0:
		return
	
	modal_source = source
	modal_index = index
	modal_max_amount = slot_data["amount"]
	modal_current_amount = modal_max_amount
	
	var item: Resource = slot_data["item"]
	var item_name: String = item.get("display_name") if item.get("display_name") != null else "Item"
	var tex: Texture2D = item.get("icon") if item.get("icon") != null else item.get("world_texture")
	
	if modal_item_icon:
		modal_item_icon.texture = tex
	if modal_item_label:
		modal_item_label.text = "%s (Total: %d)" % [item_name, modal_max_amount]
	
	if quantity_slider:
		quantity_slider.min_value = 1
		quantity_slider.max_value = modal_max_amount
		quantity_slider.value = modal_current_amount
	
	if confirm_transfer_btn:
		if source == "chest":
			confirm_transfer_btn.text = "⬅ Take to Backpack"
		else:
			confirm_transfer_btn.text = "Store to Chest ➡"
	
	_set_modal_amount(modal_current_amount)
	
	if quantity_modal:
		quantity_modal.visible = true


func _close_quantity_modal() -> void:
	if quantity_modal:
		quantity_modal.visible = false
	modal_source = ""
	modal_index = -1


func _on_slider_value_changed(val: float) -> void:
	modal_current_amount = int(val)
	if amount_label:
		amount_label.text = str(modal_current_amount)


func _set_modal_amount(amt: int) -> void:
	modal_current_amount = clamp(amt, 1, modal_max_amount)
	if quantity_slider:
		quantity_slider.value = modal_current_amount
	if amount_label:
		amount_label.text = str(modal_current_amount)


func _on_confirm_modal_transfer() -> void:
	if modal_source == "" or modal_index < 0:
		_close_quantity_modal()
		return
	
	var transfer_qty := modal_current_amount
	var slot_data := _get_slot_data(modal_source, modal_index)
	if slot_data.get("item") == null or slot_data.get("amount", 0) <= 0:
		_close_quantity_modal()
		return
	
	var item: Resource = slot_data["item"]
	var total_avail: int = slot_data["amount"]
	var count_to_move: int = min(transfer_qty, total_avail)
	
	var inv := _get_player_inventory()
	if modal_source == "chest" and inv:
		var leftover: int = inv.add_item(item, count_to_move)
		var actual_moved: int = count_to_move - leftover
		if actual_moved > 0:
			var remaining: int = total_avail - actual_moved
			if remaining <= 0:
				_set_slot_data(modal_source, modal_index, null, 0)
			else:
				_set_slot_data(modal_source, modal_index, item, remaining)
	elif (modal_source == "player_hotbar" or modal_source == "player_backpack") and current_chest:
		var leftover: int = current_chest.add_item(item, count_to_move)
		var actual_moved: int = count_to_move - leftover
		if actual_moved > 0:
			var remaining: int = total_avail - actual_moved
			if remaining <= 0:
				_set_slot_data(modal_source, modal_index, null, 0)
			else:
				_set_slot_data(modal_source, modal_index, item, remaining)
	
	_close_quantity_modal()
	_update_all_visuals()


# ==============================================================================
# DRAG & DROP IMPLEMENTATION
# ==============================================================================

func _get_slot_drag_data(_at_position: Vector2, source: String, index: int) -> Variant:
	var slot_data := _get_slot_data(source, index)
	if slot_data.get("item") == null or slot_data.get("amount", 0) <= 0:
		return null
	
	var item: Resource = slot_data["item"]
	var amount: int = slot_data["amount"]
	
	# Create drag preview
	var preview_root := Control.new()
	var preview_panel := Panel.new()
	preview_panel.custom_minimum_size = Vector2(44, 44)
	preview_panel.size = Vector2(44, 44)
	preview_panel.position = Vector2(-22, -22)
	
	var icon_rect := TextureRect.new()
	var tex: Texture2D = item.get("icon") if item.get("icon") != null else item.get("world_texture")
	icon_rect.texture = tex
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.size = Vector2(32, 32)
	icon_rect.position = Vector2(6, 6)
	preview_panel.add_child(icon_rect)
	
	if amount > 1:
		var count_lbl := Label.new()
		count_lbl.text = str(amount)
		count_lbl.add_theme_font_size_override("font_size", 10)
		count_lbl.position = Vector2(20, 24)
		preview_panel.add_child(count_lbl)
	
	preview_root.add_child(preview_panel)
	preview_root.modulate = Color(1.0, 1.0, 1.0, 0.85)
	set_drag_preview(preview_root)
	
	return {
		"source": source,
		"index": index,
		"item": item,
		"amount": amount
	}


func _can_slot_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (typeof(data) == TYPE_DICTIONARY and data.has("source") and data.has("index"))


func _slot_drop_data(_at_position: Vector2, data: Variant, to_source: String, to_index: int) -> void:
	if not (typeof(data) == TYPE_DICTIONARY and data.has("source") and data.has("index")):
		return
	
	var from_source: String = data["source"]
	var from_index: int = data["index"]
	
	# If dropping on the exact same slot, do nothing
	if from_source == to_source and from_index == to_index:
		return
	
	_transfer_or_swap_slots(from_source, from_index, to_source, to_index)
	_update_all_visuals()


func _transfer_or_swap_slots(from_source: String, from_index: int, to_source: String, to_index: int) -> void:
	var from_data := _get_slot_data(from_source, from_index)
	var to_data := _get_slot_data(to_source, to_index)
	
	if from_data.get("item") == null:
		return
	
	var from_item: Resource = from_data["item"]
	var from_amount: int = from_data["amount"]
	var to_item: Resource = to_data.get("item", null)
	var to_amount: int = to_data.get("amount", 0)
	
	# Same item stack combining
	if to_item != null and to_item.get("item_id") == from_item.get("item_id"):
		var max_stk: int = to_item.get("max_stack") if to_item.get("max_stack") != null else 99
		var space: int = max_stk - to_amount
		if space > 0:
			var to_add: int = min(from_amount, space)
			_set_slot_data(to_source, to_index, to_item, to_amount + to_add)
			var rem: int = from_amount - to_add
			if rem > 0:
				_set_slot_data(from_source, from_index, from_item, rem)
			else:
				_set_slot_data(from_source, from_index, null, 0)
			return
	
	# Direct swap
	_set_slot_data(from_source, from_index, to_item, to_amount)
	_set_slot_data(to_source, to_index, from_item, from_amount)


# ==============================================================================
# DROP / REMOVE ITEMS TO WORLD
# ==============================================================================

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (typeof(data) == TYPE_DICTIONARY and data.has("source") and data.has("index"))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if typeof(data) == TYPE_DICTIONARY and data.has("source") and data.has("index"):
		var from_source: String = data["source"]
		var from_index: int = data["index"]
		_drop_item_to_world(from_source, from_index)
		_update_all_visuals()


func _on_drop_selected_pressed() -> void:
	if selected_source != "" and selected_index >= 0:
		_drop_item_to_world(selected_source, selected_index)
		selected_source = ""
		selected_index = -1
		_update_all_visuals()


func _drop_item_to_world(source: String, index: int) -> void:
	var slot_data := _get_slot_data(source, index)
	if slot_data.get("item") == null or slot_data.get("amount", 0) <= 0:
		return
	
	var item: Resource = slot_data["item"]
	var amount: int = slot_data["amount"]
	_set_slot_data(source, index, null, 0)
	
	var target_parent: Node = current_player.get_parent() if (current_player and current_player.get_parent()) else (get_tree().root if get_tree() else null)
	if target_parent:
		var w_item = WorldItemScene.instantiate()
		target_parent.add_child(w_item)
		var spawn_pos := current_player.global_position + Vector2(0, 16) if current_player else Vector2.ZERO
		w_item.global_position = spawn_pos
		w_item.call("set_item", item, amount)
		var item_name: String = item.get("display_name") if item.get("display_name") != null else "Item"
		if info_label:
			info_label.text = "Dropped %s (x%d) on ground" % [item_name, amount]


# ==============================================================================
# HELPER DATA GETTERS / SETTERS & VISUAL RENDERING
# ==============================================================================

func _get_slot_data(source: String, index: int) -> Dictionary:
	var inv := _get_player_inventory()
	if source == "player_hotbar" and inv:
		return inv.get_hotbar_item_at(index)
	elif source == "player_backpack" and inv:
		return inv.get_item_at(index)
	elif source == "chest" and current_chest:
		return current_chest.get_item_at(index)
	return { "item": null, "amount": 0 }


func _set_slot_data(source: String, index: int, item: Resource, amount: int) -> void:
	var inv := _get_player_inventory()
	if source == "player_hotbar" and inv:
		inv.set_hotbar_item_at(index, item, amount)
		inv.inventory_changed.emit()
		_sync_hud_hotbar()
	elif source == "player_backpack" and inv:
		inv.set_item_at(index, item, amount)
		inv.inventory_changed.emit()
	elif source == "chest" and current_chest:
		current_chest.set_item_at(index, item, amount)


func _sync_hud_hotbar() -> void:
	if not get_tree():
		return
	var hotbars := get_tree().get_nodes_in_group("hotbar_ui")
	for hb in hotbars:
		if is_instance_valid(hb) and hb.has_method("_update_slot_visuals"):
			hb.call("_update_slot_visuals")


func _update_all_visuals() -> void:
	var inv := _get_player_inventory()
	
	# Update Player Hotbar
	if inv:
		for i in range(min(hotbar_panels.size(), inv.hotbar_slots.size())):
			var panel: PanelContainer = hotbar_panels[i]
			var slot_data: Dictionary = inv.get_hotbar_item_at(i)
			_apply_slot_visual(panel, slot_data)
	
	# Update Player Backpack
	if inv:
		for i in range(min(backpack_panels.size(), inv.slots.size())):
			var panel: PanelContainer = backpack_panels[i]
			var slot_data: Dictionary = inv.get_item_at(i)
			_apply_slot_visual(panel, slot_data)
	
	# Update Chest Grid
	if current_chest:
		for i in range(min(chest_panels.size(), current_chest.storage_slots.size())):
			var panel: PanelContainer = chest_panels[i]
			var slot_data: Dictionary = current_chest.get_item_at(i)
			_apply_slot_visual(panel, slot_data)


func _apply_slot_visual(panel: PanelContainer, slot_data: Dictionary) -> void:
	if not panel or not is_instance_valid(panel):
		return
	
	var icon: TextureRect = panel.find_child("Icon", true, false)
	var count_lbl: Label = panel.find_child("Count", true, false)
	
	if slot_data.get("item") != null and slot_data.get("amount", 0) > 0:
		var item: Resource = slot_data["item"]
		var tex: Texture2D = item.get("icon")
		if not tex:
			tex = item.get("world_texture")
		if not tex:
			tex = item.get("held_texture")
		
		if icon:
			icon.texture = tex
			icon.visible = (tex != null)
		
		if count_lbl:
			if slot_data["amount"] > 1:
				count_lbl.text = str(slot_data["amount"])
				count_lbl.visible = true
			else:
				count_lbl.text = ""
				count_lbl.visible = false
	else:
		if icon:
			icon.texture = null
			icon.visible = false
		if count_lbl:
			count_lbl.text = ""
			count_lbl.visible = false


func _on_take_all_pressed() -> void:
	var inv := _get_player_inventory()
	if not current_chest or not inv:
		return
	
	for i in range(current_chest.storage_slots.size()):
		var slot: Dictionary = current_chest.get_item_at(i)
		if slot.get("item") != null and slot.get("amount", 0) > 0:
			var leftover: int = inv.add_item(slot["item"], slot["amount"])
			if leftover == 0:
				current_chest.set_item_at(i, null, 0)
			else:
				current_chest.set_item_at(i, slot["item"], leftover)
	
	inv.inventory_changed.emit()
	_sync_hud_hotbar()
	_update_all_visuals()


func _on_store_all_pressed() -> void:
	var inv := _get_player_inventory()
	if not current_chest or not inv:
		return
	
	# Store from backpack
	for i in range(inv.slots.size()):
		var slot: Dictionary = inv.get_item_at(i)
		if slot.get("item") != null and slot.get("amount", 0) > 0:
			var leftover: int = current_chest.add_item(slot["item"], slot["amount"])
			if leftover == 0:
				inv.set_item_at(i, null, 0)
			else:
				inv.set_item_at(i, slot["item"], leftover)
	
	inv.inventory_changed.emit()
	_sync_hud_hotbar()
	_update_all_visuals()


func _get_player_inventory() -> InventoryUI:
	if not get_tree():
		return null
	var nodes := get_tree().get_nodes_in_group("inventory_ui")
	for node in nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			return node as InventoryUI
	return null
