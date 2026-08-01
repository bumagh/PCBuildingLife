class_name BuildingPanel
extends PanelContainer

signal slot_selected(slot: String)
signal inventory_item_dropped(slot: String, item: Dictionary)
signal slot_menu_requested(slot: String, position: Vector2)

const PC_SHAPE := preload("res://assets/original/workbench/pc_preview.png")
const INSTALL_SLOT_BUTTON_SCRIPT := preload("res://scripts/install_slot_button.gd")
const INSTALL_SLOT_DROP_PANEL_SCRIPT := preload("res://scripts/install_slot_drop_panel.gd")
const ITEM_IMAGES := {
	"CPU": preload("res://assets/original/item_icons/cpu_icon.png"),
	"VideoCard": preload("res://assets/original/item_icons/videocard_icon.png"),
	"MotherBoard": preload("res://assets/original/item_icons/motherboard_icon.png"),
	"Power": preload("res://assets/original/item_icons/power_icon.png"),
	"RAM": preload("res://assets/original/item_icons/ram_icon.png"),
	"Case": preload("res://assets/original/item_icons/case_icon.png"),
	"HDD": preload("res://assets/original/item_icons/hdd_icon.png"),
	"COOLER": preload("res://assets/original/item_icons/cooler_icon.png"),
	"SSD": preload("res://assets/original/item_icons/ssd_icon.png"),
	"M2": preload("res://assets/original/item_icons/m2_icon.png"),
}
const ITEM_DETAIL_IMAGES := {
	"CPU": preload("res://assets/original/item_details/cpu_detail.png"),
	"VideoCard": preload("res://assets/original/item_details/videocard_detail.png"),
	"MotherBoard": preload("res://assets/original/item_details/motherboard_detail.png"),
	"Power": preload("res://assets/original/item_details/power_detail.png"),
	"RAM": preload("res://assets/original/item_details/ram_detail.png"),
	"Case": preload("res://assets/original/item_details/case_detail.png"),
	"HDD": preload("res://assets/original/item_details/hdd_detail.png"),
	"COOLER": preload("res://assets/original/item_details/cooler_detail.png"),
	"SSD": preload("res://assets/original/item_details/ssd_detail.png"),
	"M2": preload("res://assets/original/item_details/m2_detail.png"),
}
const SLOT_DEFS := [
	{"slot": "Case", "label": "机箱"},
	{"slot": "Power", "label": "电源"},
	{"slot": "MotherBoard", "label": "主板"},
	{"slot": "CPU", "label": "CPU"},
	{"slot": "VideoCard", "label": "GPU"},
	{"slot": "RAM", "label": "内存"},
	{"slot": "SSD", "label": "SSD"},
	{"slot": "HDD", "label": "HDD"},
	{"slot": "M2", "label": "M.2"},
	{"slot": "COOLER", "label": "散热器"},
]

const OVERLAY_POSITIONS := {
	"Case": Vector2(0.14, 0.72),
	"Power": Vector2(0.76, 0.75),
	"MotherBoard": Vector2(0.42, 0.46),
	"CPU": Vector2(0.43, 0.34),
	"VideoCard": Vector2(0.52, 0.60),
	"RAM": Vector2(0.62, 0.38),
	"SSD": Vector2(0.28, 0.70),
	"HDD": Vector2(0.22, 0.56),
	"M2": Vector2(0.54, 0.48),
	"COOLER": Vector2(0.36, 0.30),
}
const OVERLAY_LAYOUTS := {
	"Case": {"pos": Vector2(0.08, 0.62), "size": Vector2(34, 34)},
	"Power": {"pos": Vector2(0.68, 0.70), "size": Vector2(42, 32)},
	"MotherBoard": {"pos": Vector2(0.28, 0.32), "size": Vector2(58, 48)},
	"CPU": {"pos": Vector2(0.40, 0.31), "size": Vector2(28, 28)},
	"VideoCard": {"pos": Vector2(0.38, 0.58), "size": Vector2(64, 26)},
	"RAM": {"pos": Vector2(0.58, 0.36), "size": Vector2(42, 18)},
	"SSD": {"pos": Vector2(0.22, 0.70), "size": Vector2(38, 24)},
	"HDD": {"pos": Vector2(0.18, 0.52), "size": Vector2(34, 30)},
	"M2": {"pos": Vector2(0.52, 0.49), "size": Vector2(42, 16)},
	"COOLER": {"pos": Vector2(0.32, 0.22), "size": Vector2(38, 38)},
}

var _slot_buttons: Dictionary = {}
var _slot_labels: Dictionary = {}
var _visual_cards: Dictionary = {}
var _visual_icons: Dictionary = {}
var _visual_labels: Dictionary = {}
var _overlay_cards: Dictionary = {}
var _overlay_icons: Dictionary = {}
var _overlay_labels: Dictionary = {}
var _last_installed: Dictionary = {}
var _animation_tweens: Array[Tween] = []
var _summary_label: Label
var _selected_slot_label: Label
var _checklist_label: Label
var _progress_bar: ProgressBar
var _power_state_label: Label
var _active_slot := ""

func _ready() -> void:
	custom_minimum_size = Vector2(520, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.055, 0.16, 0.88), Color(0.34, 0.23, 0.78, 0.7), 12))
	_build_ui()

func update_slots(installed: Dictionary) -> void:
	_last_installed = installed
	for slot_def in SLOT_DEFS:
		var slot := str(slot_def.slot)
		var button: Button = _slot_buttons[slot]
		var label: Label = _slot_labels[slot]
		if installed.has(slot):
			button.text = "%s  已安装" % slot_def.label
			label.text = installed[slot].name
		else:
			button.text = "%s  空槽" % slot_def.label
			label.text = "未安装"
		_apply_slot_style(slot)
		_apply_visual_slot(slot, installed)
	_update_selected_slot_detail()

func set_active_slot(slot: String) -> void:
	_active_slot = slot
	for key in _slot_buttons.keys():
		_apply_slot_style(str(key))
	for key in _overlay_cards.keys():
		_apply_overlay_slot(str(key), _last_installed)
	_update_selected_slot_detail()

func update_build_status(installed_count: int, required_count: int, missing_labels: Array[String], powered_on: bool, system_booted: bool = false) -> void:
	var percent := 0
	if required_count > 0:
		percent = int(round(float(installed_count) / float(required_count) * 100.0))
	_progress_bar.value = percent
	if missing_labels.is_empty():
		_summary_label.text = "核心配件已齐，可以进行开机测试。"
		_checklist_label.text = "装机检查：槽位齐全\n下一步：完成检测 -> 电源按钮"
	else:
		_summary_label.text = "完成度 %d%%，缺少：%s" % [percent, " / ".join(missing_labels)]
		_checklist_label.text = "装机检查：还缺 %d 项\n下一步：选槽 -> 拖拽或购买并安装" % missing_labels.size()
	if system_booted:
		_power_state_label.text = "模拟系统：已启动"
		_power_state_label.add_theme_color_override("font_color", Color(0.36, 1.0, 0.62))
	elif powered_on:
		_power_state_label.text = "开机测试：通过，待按电源"
		_power_state_label.add_theme_color_override("font_color", Color(0.36, 1.0, 0.62))
	elif missing_labels.is_empty():
		_power_state_label.text = "开机测试：待检测"
		_power_state_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36))
	else:
		_power_state_label.text = "开机测试：缺件"
		_power_state_label.add_theme_color_override("font_color", Color(1.0, 0.43, 0.36))

func pulse_slot(slot: String, success: bool = true) -> void:
	var tint := Color(0.55, 1.18, 0.84, 1.0) if success else Color(1.18, 0.55, 0.50, 1.0)
	_pulse_canvas_item(_slot_buttons.get(slot), tint, 0.32)
	_pulse_canvas_item(_visual_cards.get(slot), tint, 0.32)
	_pulse_canvas_item(_overlay_cards.get(slot), tint, 0.32)
	_pulse_canvas_item(_overlay_icons.get(slot), Color(1.28, 1.28, 1.10, 1.0) if success else tint, 0.32)

func pulse_power_status(success: bool = true) -> void:
	var tint := Color(0.55, 1.18, 0.84, 1.0) if success else Color(1.18, 0.62, 0.52, 1.0)
	_pulse_canvas_item(_power_state_label, tint, 0.36)

func pulse_progress(success: bool = true) -> void:
	var tint := Color(0.60, 1.15, 0.90, 1.0) if success else Color(1.16, 0.72, 0.46, 1.0)
	_pulse_canvas_item(_progress_bar, tint, 0.30)

func _build_ui() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	box.add_child(header_row)

	var header := Label.new()
	header.text = "装机工作台"
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
	header_row.add_child(header)

	var hint := Label.new()
	hint.text = "拖拽配件到机箱插槽"
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0))
	header_row.add_child(hint)

	var pc_row := HBoxContainer.new()
	pc_row.add_theme_constant_override("separation", 12)
	pc_row.custom_minimum_size = Vector2(0, 176)
	box.add_child(pc_row)

	var pc_frame := PanelContainer.new()
	pc_frame.custom_minimum_size = Vector2(292, 170)
	pc_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pc_frame.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.04, 0.12, 0.6), Color(0.61, 0.36, 1.0, 0.85), 14))
	pc_row.add_child(pc_frame)

	var pc_icon := TextureRect.new()
	pc_icon.texture = PC_SHAPE
	pc_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pc_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pc_frame.add_child(pc_icon)

	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pc_frame.add_child(overlay)

	for slot_def in SLOT_DEFS:
		var slot_key := str(slot_def.slot)
		var layout: Dictionary = OVERLAY_LAYOUTS.get(slot_key, {"pos": OVERLAY_POSITIONS.get(slot_key, Vector2(0.5, 0.5)), "size": Vector2(26, 26)})
		var pos: Vector2 = layout.get("pos", Vector2(0.5, 0.5))
		var marker_size: Vector2 = layout.get("size", Vector2(26, 26))
		var marker = INSTALL_SLOT_DROP_PANEL_SCRIPT.new()
		marker.slot_key = slot_key
		marker.custom_minimum_size = marker_size
		marker.mouse_filter = Control.MOUSE_FILTER_STOP
		marker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		marker.tooltip_text = str(slot_def.label)
		marker.set_anchors_preset(Control.PRESET_TOP_LEFT)
		marker.anchor_left = pos.x
		marker.anchor_top = pos.y
		marker.anchor_right = pos.x
		marker.anchor_bottom = pos.y
		marker.offset_left = -marker_size.x * 0.5
		marker.offset_top = -marker_size.y * 0.5
		marker.offset_right = marker_size.x * 0.5
		marker.offset_bottom = marker_size.y * 0.5
		marker.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.025, 0.06, 0.28), Color(0.38, 0.46, 0.64, 0.36), 13))
		marker.gui_input.connect(_on_overlay_marker_gui_input.bind(slot_key))
		marker.item_dropped.connect(_on_item_dropped)
		overlay.add_child(marker)

		var marker_icon := TextureRect.new()
		marker_icon.texture = ITEM_DETAIL_IMAGES.get(slot_key, ITEM_IMAGES.get(slot_key, ITEM_IMAGES["CPU"]))
		marker_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		marker_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		marker_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker_icon.modulate = Color(1, 1, 1, 0.10)
		marker.add_child(marker_icon)

		var marker_label := Label.new()
		marker_label.text = str(slot_def.label)
		marker_label.visible = false
		overlay.add_child(marker_label)

		_overlay_cards[slot_key] = marker
		_overlay_icons[slot_key] = marker_icon
		_overlay_labels[slot_key] = marker_label

	var visual_grid := GridContainer.new()
	visual_grid.columns = 5
	visual_grid.add_theme_constant_override("h_separation", 4)
	visual_grid.add_theme_constant_override("v_separation", 2)
	box.add_child(visual_grid)

	for slot_def in SLOT_DEFS:
		var slot_key := str(slot_def.slot)
		var visual_card = INSTALL_SLOT_DROP_PANEL_SCRIPT.new()
		visual_card.slot_key = slot_key
		visual_card.custom_minimum_size = Vector2(62, 34)
		visual_card.tooltip_text = "%s：可拖拽安装" % str(slot_def.label)
		visual_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		visual_card.item_dropped.connect(_on_item_dropped)
		visual_card.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.03, 0.08, 0.72), Color(0.25, 0.32, 0.48, 0.85), 8))
		visual_grid.add_child(visual_card)

		var visual_box := VBoxContainer.new()
		visual_box.alignment = BoxContainer.ALIGNMENT_CENTER
		visual_card.add_child(visual_box)

		var icon := TextureRect.new()
		icon.texture = ITEM_IMAGES.get(slot_key, ITEM_IMAGES["CPU"])
		icon.custom_minimum_size = Vector2(40, 18)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.modulate = Color(1, 1, 1, 0.32)
		visual_box.add_child(icon)

		var visual_label := Label.new()
		visual_label.text = str(slot_def.label)
		visual_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		visual_label.clip_text = true
		visual_label.add_theme_font_size_override("font_size", 7)
		visual_box.add_child(visual_label)

		_visual_cards[slot_key] = visual_card
		_visual_icons[slot_key] = icon
		_visual_labels[slot_key] = visual_label

	var status_box := VBoxContainer.new()
	status_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_box.add_theme_constant_override("separation", 8)
	pc_row.add_child(status_box)

	_summary_label = Label.new()
	_summary_label.text = "点击槽位筛选背包，安装后会在这里点亮配置。"
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_box.add_child(_summary_label)

	_selected_slot_label = Label.new()
	_selected_slot_label.text = "当前槽位：未选择"
	_selected_slot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selected_slot_label.add_theme_font_size_override("font_size", 13)
	_selected_slot_label.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0))
	status_box.add_child(_selected_slot_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0
	_progress_bar.max_value = 100
	_progress_bar.value = 0
	_progress_bar.show_percentage = true
	status_box.add_child(_progress_bar)

	_power_state_label = Label.new()
	_power_state_label.text = "开机测试：未检测"
	_power_state_label.add_theme_font_size_override("font_size", 16)
	status_box.add_child(_power_state_label)

	_checklist_label = Label.new()
	_checklist_label.text = "装机检查：等待选择订单"
	_checklist_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_checklist_label.add_theme_font_size_override("font_size", 13)
	_checklist_label.add_theme_color_override("font_color", Color(0.68, 0.78, 0.92))
	status_box.add_child(_checklist_label)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)

	for slot_def in SLOT_DEFS:
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(0, 28)
		grid.add_child(card)

		var button := Button.new()
		button.set_script(INSTALL_SLOT_BUTTON_SCRIPT)
		button.slot_key = str(slot_def.slot)
		button.text = "%s  空槽" % slot_def.label
		button.custom_minimum_size = Vector2(0, 20)
		button.pressed.connect(_select_slot.bind(str(slot_def.slot)))
		button.item_dropped.connect(_on_item_dropped)
		card.add_child(button)

		var state_label := Label.new()
		state_label.text = "未安装"
		state_label.clip_text = true
		state_label.add_theme_font_size_override("font_size", 8)
		card.add_child(state_label)

		_slot_buttons[slot_def.slot] = button
		_slot_labels[slot_def.slot] = state_label

func _select_slot(slot: String) -> void:
	set_active_slot(slot)
	slot_selected.emit(slot)

func _on_overlay_marker_gui_input(event: InputEvent, slot: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_slot(slot)
		if _last_installed.has(slot):
			slot_menu_requested.emit(slot, get_global_mouse_position())

func _on_item_dropped(slot: String, item: Dictionary) -> void:
	inventory_item_dropped.emit(slot, item)

func _update_selected_slot_detail() -> void:
	if _selected_slot_label == null:
		return
	if _active_slot == "":
		_selected_slot_label.text = "当前槽位：未选择\n点击机箱插槽，或从订单/任务中心跳转。"
		return
	var display_name := _slot_display_name(_active_slot)
	if _last_installed.has(_active_slot):
		var item: Dictionary = _last_installed[_active_slot]
		_selected_slot_label.text = "当前槽位：%s\n已安装：%s  Lv.%d" % [
			display_name,
			str(item.get("name", "配件")),
			int(item.get("tier", 0)),
		]
	else:
		_selected_slot_label.text = "当前槽位：%s\n可将背包中的 %s 拖到机箱插槽。" % [display_name, display_name]

func _slot_display_name(slot: String) -> String:
	for slot_def in SLOT_DEFS:
		if str(slot_def.slot) == slot:
			return str(slot_def.label)
	return slot

func _apply_slot_style(slot: String) -> void:
	if not _slot_buttons.has(slot):
		return
	var button: Button = _slot_buttons[slot]
	var base_color := Color(0.16, 0.18, 0.20)
	var hover_color := Color(0.22, 0.25, 0.28)
	var pressed_color := Color(0.10, 0.38, 0.52)
	var font_color := Color(0.92, 0.94, 0.96)
	if slot == _active_slot:
		base_color = Color(0.05, 0.36, 0.54)
		hover_color = Color(0.07, 0.42, 0.62)
		font_color = Color(1.0, 1.0, 1.0)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_stylebox_override("normal", _stylebox(base_color))
	button.add_theme_stylebox_override("hover", _stylebox(hover_color))
	button.add_theme_stylebox_override("pressed", _stylebox(pressed_color))

func _apply_visual_slot(slot: String, installed: Dictionary) -> void:
	if not _visual_cards.has(slot):
		return
	var card: PanelContainer = _visual_cards[slot]
	var icon: TextureRect = _visual_icons[slot]
	var label: Label = _visual_labels[slot]
	var installed_part := installed.has(slot)
	if installed_part:
		icon.modulate = Color(1, 1, 1, 1)
		label.text = str(installed[slot].name)
		label.add_theme_color_override("font_color", Color(0.78, 1.0, 0.86))
		card.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.13, 0.14, 0.86), Color(0.28, 0.95, 0.68, 0.95), 8))
	else:
		icon.modulate = Color(1, 1, 1, 0.28)
		label.add_theme_color_override("font_color", Color(0.64, 0.70, 0.82))
		card.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.03, 0.08, 0.72), Color(0.25, 0.32, 0.48, 0.85), 8))
	_apply_overlay_slot(slot, installed)

func _apply_overlay_slot(slot: String, installed: Dictionary) -> void:
	if not _overlay_cards.has(slot):
		return
	var card: PanelContainer = _overlay_cards[slot]
	var icon: TextureRect = _overlay_icons[slot]
	if installed.has(slot):
		icon.modulate = Color(1, 1, 1, 1)
		card.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.08, 0.08, 0.46), Color(0.32, 1.0, 0.74, 0.82), 8))
	elif slot == _active_slot:
		icon.modulate = Color(1, 1, 1, 0.34)
		card.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.14, 0.28, 0.46), Color(1.0, 0.76, 0.32, 0.88), 8))
	else:
		icon.modulate = Color(1, 1, 1, 0.06)
		card.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.025, 0.06, 0.12), Color(0.38, 0.46, 0.64, 0.22), 8))

func _pulse_canvas_item(item: Variant, tint: Color, duration: float) -> void:
	if not (item is CanvasItem):
		return
	var canvas_item := item as CanvasItem
	var tween := create_tween()
	_animation_tweens.append(tween)
	var original := canvas_item.modulate
	canvas_item.modulate = tint
	tween.tween_property(canvas_item, "modulate", original, duration)
	tween.finished.connect(func() -> void:
		_animation_tweens.erase(tween)
	)

func _stylebox(color: Color) -> StyleBoxFlat:
	return _panel_style(color, Color(0.34, 0.42, 0.48), 8)

func _panel_style(color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border_color
	box.set_border_width_all(1)
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 8
	box.content_margin_right = 8
	return box
