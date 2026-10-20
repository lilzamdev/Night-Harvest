extends Control
class_name InventoryUI

const ItemDataClass = preload("res://scripts/item_data.gd")

signal opened
signal closed
signal inventory_changed

const INVENTORY_SLOT_COUNT := 24
const HOTBAR_SLOT_COUNT := 4
const TOTAL_SLOTS := 24 # Backward-compatible constant for backpack

@export var is_open: bool = false

# Backpack slots: 24 slots { "item": Resource, "amount": int }
var slots: Array[Dictionary] = []

# Dedicated Hotbar slots: 4 slots { "item": Resource, "amount": int }
var hotbar_slots: Array[Dictionary] = []

# Selected slot tracking for click-to-swap
var selected_slot_type: String = "" # "inventory" or "hotbar"
var selected_slot_index: int = -1

@onready var hotbar_grid: HBoxContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HotbarGrid
@onready var slot_grid: GridContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SlotGrid
@onready var instruction_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/InstructionLabel

var _style_selected: StyleBox = null
var _style_hotbar: StyleBox = null
var _style_backpack: StyleBox = null


func _ready() -> void:
	add_to_group("inventory_ui")
	visible = is_open
	_load_styles()
	_init_slots()
	_bind_slot_inputs()
	_update_slot_visuals()


func _load_styles() -> void:
	if _style_selected == null:
		var s_sel := StyleBoxFlat.new()
		s_sel.bg_color = Color(0.2, 0.16, 0.12, 0.9)
		s_sel.border_width_left = 2
		s_sel.border_width_top = 2
		s_sel.border_width_right = 2
		s_sel.border_width_bottom = 2
		s_sel.border_color = Color(1.0, 0.85, 0.2, 1.0)
		_style_selected = s_sel
	if _style_hotbar == null:
		var s_hot := StyleBoxFlat.new()
		s_hot.bg_color = Color(0.12, 0.09, 0.07, 0.85)
		s_hot.border_width_left = 1
		s_hot.border_width_top = 1
		s_hot.border_width_right = 1
		s_hot.border_width_bottom = 1
		s_hot.border_color = Color(0.6, 0.45, 0.25, 0.8)
		_style_hotbar = s_hot
	if _style_backpack == null:
		var s_bp := StyleBoxFlat.new()
		s_bp.bg_color = Color(0.15, 0.11, 0.08, 0.85)
		s_bp.border_width_left = 1
		s_bp.border_width_top = 1
		s_bp.border_width_right = 1
		s_bp.border_width_bottom = 1
		s_bp.border_color = Color(0.35, 0.25, 0.15, 0.6)
		_style_backpack = s_bp


func _init_slots() -> void:
	if hotbar_slots.size() != HOTBAR_SLOT_COUNT:
		hotbar_slots.clear()
		for i in range(HOTBAR_SLOT_COUNT):
			hotbar_slots.append({ "item": null, "amount": 0 })

	if slots.size() != INVENTORY_SLOT_COUNT:
		slots.clear()
		for i in range(INVENTORY_SLOT_COUNT):
			slots.append({ "item": null, "amount": 0 })


func _bind_slot_inputs() -> void:
	# Bind hotbar slots in inventory menu
	if hotbar_grid:
		var hotbar_nodes := hotbar_grid.get_children()
		for i in range(min(hotbar_nodes.size(), HOTBAR_SLOT_COUNT)):
			var slot_panel := hotbar_nodes[i] as Control
			if slot_panel:
				if not slot_panel.gui_input.is_connected(_on_hotbar_slot_gui_input):
					slot_panel.gui_input.connect(_on_hotbar_slot_gui_input.bind(i))
				slot_panel.set_drag_forwarding(
					Callable(self, "_get_slot_drag_data").bind("hotbar", i),
					Callable(self, "_can_slot_drop_data"),
					Callable(self, "_slot_drop_data").bind("hotbar", i)
				)

	# Bind backpack slots
	if slot_grid:
		var slot_nodes := slot_grid.get_children()
		for i in range(min(slot_nodes.size(), INVENTORY_SLOT_COUNT)):
			var slot_panel := slot_nodes[i] as Control
			if slot_panel:
				if not slot_panel.gui_input.is_connected(_on_backpack_slot_gui_input):
					slot_panel.gui_input.connect(_on_backpack_slot_gui_input.bind(i))
				slot_panel.set_drag_forwarding(
					Callable(self, "_get_slot_drag_data").bind("inventory", i),
					Callable(self, "_can_slot_drop_data"),
					Callable(self, "_slot_drop_data").bind("inventory", i)
				)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F):
		toggle()
		get_viewport().set_input_as_handled()
		return
	
	# If inventory is open, handle quick 1-4 key slot assignment
	if is_open:
		var target_hotbar := -1
		if event.is_action_pressed("hotbar_1") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_1):
			target_hotbar = 0
		elif event.is_action_pressed("hotbar_2") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_2):
			target_hotbar = 1
		elif event.is_action_pressed("hotbar_3") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_3):
			target_hotbar = 2
		elif event.is_action_pressed("hotbar_4") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_4):
			target_hotbar = 3
		
		if target_hotbar >= 0:
			if selected_slot_index >= 0:
				transfer_or_swap(selected_slot_type, selected_slot_index, "hotbar", target_hotbar)
				clear_selection()
			else:
				selected_slot_type = "hotbar"
				selected_slot_index = target_hotbar
			_update_slot_visuals()
			get_viewport().set_input_as_handled()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	clear_selection()
	_bind_slot_inputs()
	_update_slot_visuals()
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	clear_selection()
	closed.emit()


func clear_selection() -> void:
	selected_slot_type = ""
	selected_slot_index = -1


# ==============================================================================
# ITEM MANAGEMENT & STORAGE
# ==============================================================================

## Adds an item. Prioritizes matching stacks in hotbar, then backpack,
## then first empty hotbar slot, then first empty backpack slot.
func add_item(item_data: Resource, amount: int = 1) -> int:
	if not item_data or amount <= 0:
		return amount
	
	_init_slots()
	
	var remaining := amount
	var max_stack: int = item_data.get("max_stack") if item_data.get("max_stack") != null else 99
	var item_id: String = item_data.get("item_id") if item_data.get("item_id") != null else ""
	
	# 1. Try to stack into existing hotbar slots
	if max_stack > 1:
		for i in range(HOTBAR_SLOT_COUNT):
			var slot := hotbar_slots[i]
			if slot["item"] != null and slot["item"].get("item_id") == item_id:
				var current_amount: int = slot["amount"]
				var space: int = max_stack - current_amount
				if space > 0:
					var to_add: int = min(remaining, space)
					slot["amount"] += to_add
					remaining -= to_add
					if remaining == 0:
						break
	
	# 2. Try to stack into existing backpack slots
	if remaining > 0 and max_stack > 1:
		for i in range(INVENTORY_SLOT_COUNT):
			var slot := slots[i]
			if slot["item"] != null and slot["item"].get("item_id") == item_id:
				var current_amount: int = slot["amount"]
				var space: int = max_stack - current_amount
				if space > 0:
					var to_add: int = min(remaining, space)
					slot["amount"] += to_add
					remaining -= to_add
					if remaining == 0:
						break
	
	# 3. Try to place into empty hotbar slots
	if remaining > 0:
		for i in range(HOTBAR_SLOT_COUNT):
			var slot := hotbar_slots[i]
			if slot["item"] == null:
				var to_add: int = min(remaining, max_stack)
				slot["item"] = item_data
				slot["amount"] = to_add
				remaining -= to_add
				if remaining == 0:
					break
	
	# 4. Try to place into empty backpack slots
	if remaining > 0:
		for i in range(INVENTORY_SLOT_COUNT):
			var slot := slots[i]
			if slot["item"] == null:
				var to_add: int = min(remaining, max_stack)
				slot["item"] = item_data
				slot["amount"] = to_add
				remaining -= to_add
				if remaining == 0:
					break
	
	_update_slot_visuals()
	inventory_changed.emit()
	return remaining


func get_item_at(slot_index: int) -> Dictionary:
	_init_slots()
	if slot_index >= 0 and slot_index < slots.size():
		return slots[slot_index]
	return { "item": null, "amount": 0 }


func get_hotbar_item_at(slot_index: int) -> Dictionary:
	_init_slots()
	if slot_index >= 0 and slot_index < hotbar_slots.size():
		return hotbar_slots[slot_index]
	return { "item": null, "amount": 0 }


func set_item_at(slot_index: int, item_data: Resource, amount: int) -> void:
	_init_slots()
	if slot_index >= 0 and slot_index < slots.size():
		if item_data == null or amount <= 0:
			slots[slot_index] = { "item": null, "amount": 0 }
		else:
			slots[slot_index] = { "item": item_data, "amount": amount }
		_update_slot_visuals()
		inventory_changed.emit()


func set_hotbar_item_at(slot_index: int, item_data: Resource, amount: int) -> void:
	_init_slots()
	if slot_index >= 0 and slot_index < hotbar_slots.size():
		if item_data == null or amount <= 0:
			hotbar_slots[slot_index] = { "item": null, "amount": 0 }
		else:
			hotbar_slots[slot_index] = { "item": item_data, "amount": amount }
		_update_slot_visuals()
		inventory_changed.emit()


func remove_item_at(slot_index: int, amount: int = 1) -> Resource:
	_init_slots()
	if slot_index < 0 or slot_index >= slots.size():
		return null
	
	var slot := slots[slot_index]
	if slot["item"] == null or slot["amount"] <= 0:
		return null
	
	var removed_item: Resource = slot["item"]
	slot["amount"] -= amount
	
	if slot["amount"] <= 0:
		slot["item"] = null
		slot["amount"] = 0
	
	_update_slot_visuals()
	inventory_changed.emit()
	return removed_item


func remove_hotbar_item_at(slot_index: int, amount: int = 1) -> Resource:
	_init_slots()
	if slot_index < 0 or slot_index >= hotbar_slots.size():
		return null
	
	var slot := hotbar_slots[slot_index]
	if slot["item"] == null or slot["amount"] <= 0:
		return null
	
	var removed_item: Resource = slot["item"]
	slot["amount"] -= amount
	
	if slot["amount"] <= 0:
		slot["item"] = null
		slot["amount"] = 0
	
	_update_slot_visuals()
	inventory_changed.emit()
	return removed_item


func swap_slots(from_index: int, to_index: int) -> void:
	transfer_or_swap("inventory", from_index, "inventory", to_index)


func swap_hotbar_slots(from_index: int, to_index: int) -> void:
	transfer_or_swap("hotbar", from_index, "hotbar", to_index)


func move_to_hotbar(inv_slot_index: int, hotbar_slot_index: int) -> void:
	transfer_or_swap("inventory", inv_slot_index, "hotbar", hotbar_slot_index)


func move_from_hotbar(hotbar_slot_index: int, inv_slot_index: int) -> void:
	transfer_or_swap("hotbar", hotbar_slot_index, "inventory", inv_slot_index)


func transfer_or_swap(from_type: String, from_index: int, to_type: String, to_index: int) -> void:
	_init_slots()
	
	var from_array: Array[Dictionary] = hotbar_slots if from_type == "hotbar" else slots
	var to_array: Array[Dictionary] = hotbar_slots if to_type == "hotbar" else slots
	
	if from_index < 0 or from_index >= from_array.size():
		return
	if to_index < 0 or to_index >= to_array.size():
		return
	if from_type == to_type and from_index == to_index:
		return
	
	var from_slot := from_array[from_index]
	var to_slot := to_array[to_index]
	
	if from_slot["item"] == null:
		return
	
	# If target has same item, stack together
	if to_slot["item"] != null and to_slot["item"].get("item_id") == from_slot["item"].get("item_id"):
		var max_stack: int = from_slot["item"].get("max_stack") if from_slot["item"].get("max_stack") != null else 99
		if max_stack > 1:
			var space: int = max_stack - to_slot["amount"]
			if space > 0:
				var move_amount: int = min(from_slot["amount"], space)
				to_slot["amount"] += move_amount
				from_slot["amount"] -= move_amount
				if from_slot["amount"] <= 0:
					from_slot["item"] = null
					from_slot["amount"] = 0
				_update_slot_visuals()
				inventory_changed.emit()
				return

	# Otherwise, swap slots completely
	var temp := { "item": from_slot["item"], "amount": from_slot["amount"] }
	from_slot["item"] = to_slot["item"]
	from_slot["amount"] = to_slot["amount"]
	to_slot["item"] = temp["item"]
	to_slot["amount"] = temp["amount"]
	
	_update_slot_visuals()
	inventory_changed.emit()


func has_item(item_id: String, count: int = 1) -> bool:
	var total := 0
	for slot in hotbar_slots:
		if slot["item"] != null and slot["item"].get("item_id") == item_id:
			total += slot["amount"]
	for slot in slots:
		if slot["item"] != null and slot["item"].get("item_id") == item_id:
			total += slot["amount"]
	return total >= count


# ==============================================================================
# GUI INPUT & CLICK HANDLING
# ==============================================================================

func _on_backpack_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	_handle_slot_click("inventory", slot_index)


func _on_hotbar_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	_handle_slot_click("hotbar", slot_index)


func _handle_slot_click(slot_type: String, slot_index: int) -> void:
	if selected_slot_index == -1:
		var array: Array[Dictionary] = hotbar_slots if slot_type == "hotbar" else slots
		if array[slot_index]["item"] != null:
			selected_slot_type = slot_type
			selected_slot_index = slot_index
	elif selected_slot_type == slot_type and selected_slot_index == slot_index:
		clear_selection()
	else:
		transfer_or_swap(selected_slot_type, selected_slot_index, slot_type, slot_index)
		clear_selection()
	
	_update_slot_visuals()


# ==============================================================================
# DRAG & DROP SUPPORT
# ==============================================================================

func _get_slot_drag_data(_at_position: Vector2, slot_type: String, slot_index: int) -> Variant:
	var slot_data := get_hotbar_item_at(slot_index) if slot_type == "hotbar" else get_item_at(slot_index)
	if slot_data["item"] == null or slot_data["amount"] <= 0:
		return null
	
	var item: Resource = slot_data["item"]
	var amount: int = slot_data["amount"]
	
	var preview_root := Control.new()
	var preview_panel := Panel.new()
	preview_panel.custom_minimum_size = Vector2(40, 40)
	preview_panel.size = Vector2(40, 40)
	preview_panel.position = Vector2(-20, -20)
	
	var icon_rect := TextureRect.new()
	icon_rect.texture = item.get("icon")
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.size = Vector2(32, 32)
	icon_rect.position = Vector2(4, 4)
	preview_panel.add_child(icon_rect)
	
	if amount > 1:
		var count_lbl := Label.new()
		count_lbl.text = str(amount)
		count_lbl.add_theme_font_size_override("font_size", 9)
		count_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
		count_lbl.position = Vector2(22, 24)
		preview_panel.add_child(count_lbl)
	
	preview_root.add_child(preview_panel)
	preview_root.modulate = Color(1.0, 1.0, 1.0, 0.85)
	set_drag_preview(preview_root)
	
	return {
		"slot_type": slot_type,
		"slot_index": slot_index,
		"item": item,
		"amount": amount
	}


func _can_slot_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (typeof(data) == TYPE_DICTIONARY and data.has("slot_type") and data.has("slot_index"))


func _slot_drop_data(_at_position: Vector2, data: Variant, to_slot_type: String, to_slot_index: int) -> void:
	if typeof(data) == TYPE_DICTIONARY and data.has("slot_type") and data.has("slot_index"):
		var from_type: String = data["slot_type"]
		var from_slot: int = data["slot_index"]
		transfer_or_swap(from_type, from_slot, to_slot_type, to_slot_index)
		clear_selection()
		_update_slot_visuals()


# ==============================================================================
# VISUAL RENDERING
# ==============================================================================

func _update_slot_visuals() -> void:
	_init_slots()
	
	if instruction_label:
		if selected_slot_index >= 0:
			var slot_name := "Hotbar [%d]" % (selected_slot_index + 1) if selected_slot_type == "hotbar" else "Slot %d" % (selected_slot_index + 1)
			instruction_label.text = "%s Selected: Click target to move | 1-4: Quick Assign" % slot_name
			instruction_label.modulate = Color(1.0, 0.9, 0.3, 1.0)
		else:
			instruction_label.text = "Drag & Drop to move items | 1-4: Quick Assign | F: Close"
			instruction_label.modulate = Color(0.8, 0.8, 0.8, 1.0)
	
	if not _style_selected:
		_load_styles()
	
	# 1. Update Hotbar row in inventory
	if hotbar_grid:
		var hotbar_nodes := hotbar_grid.get_children()
		for i in range(min(hotbar_nodes.size(), HOTBAR_SLOT_COUNT)):
			var slot_panel := hotbar_nodes[i] as Panel
			var slot_data := get_hotbar_item_at(i)
			
			if selected_slot_type == "hotbar" and selected_slot_index == i:
				slot_panel.add_theme_stylebox_override("panel", _style_selected)
			else:
				slot_panel.add_theme_stylebox_override("panel", _style_hotbar)
			
			_render_slot_contents(slot_panel, slot_data)
	
	# 2. Update Backpack grid in inventory
	if slot_grid:
		var slot_nodes := slot_grid.get_children()
		for i in range(min(slot_nodes.size(), INVENTORY_SLOT_COUNT)):
			var slot_panel := slot_nodes[i] as Panel
			var slot_data := get_item_at(i)
			
			if selected_slot_type == "inventory" and selected_slot_index == i:
				slot_panel.add_theme_stylebox_override("panel", _style_selected)
			else:
				slot_panel.add_theme_stylebox_override("panel", _style_backpack)
			
			_render_slot_contents(slot_panel, slot_data)


func _render_slot_contents(slot_panel: Panel, slot_data: Dictionary) -> void:
	if not slot_panel:
		return
	
	var icon_rect := slot_panel.get_node_or_null("Icon") as TextureRect
	var count_label := slot_panel.get_node_or_null("CountLabel") as Label
	
	if slot_data["item"] != null and slot_data["amount"] > 0:
		var item: Resource = slot_data["item"]
		var amount: int = slot_data["amount"]
		
		if icon_rect:
			icon_rect.texture = item.get("icon")
			icon_rect.visible = true
		if count_label:
			count_label.text = str(amount) if amount > 1 else ""
			count_label.visible = amount > 1
	else:
		if icon_rect:
			icon_rect.texture = null
			icon_rect.visible = false
		if count_label:
			count_label.text = ""
			count_label.visible = false
