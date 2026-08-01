class_name InventoryPanel
extends PanelContainer

signal item_selected(item: Dictionary)
signal item_sold(item: Dictionary)
signal filter_cleared()

const DRAGGABLE_ITEM_LIST_SCRIPT := preload("res://scripts/draggable_item_list.gd")
const SORT_OPTIONS := ["默认排序", "类型", "等级高到低", "价格高到低", "数量多到少"]
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

var _inventory_list: ItemList
var _item_preview: TextureRect
var _details_label: Label
var _install_button: Button
var _sell_button: Button
var _clear_filter_button: Button
var _sort_option: OptionButton
var _slot_status_label: Label
var _count_status_label: Label
var _fit_status_label: Label
var _order_status_label: Label
var _selected_item: Dictionary = {}
var _all_items: Array = []
var _current_type_filter := ""
var component_database: Node
var game: Node
var fullscreen_catalog := false

func _ready() -> void:
	custom_minimum_size = Vector2(0, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel_radius := 8 if fullscreen_catalog else 14
	var panel_bg := Color(0.012, 0.026, 0.048, 0.98) if fullscreen_catalog else Color(0.025, 0.035, 0.12, 0.92)
	var panel_border := Color(0.36, 1.0, 0.66, 0.82) if fullscreen_catalog else Color(0.43, 0.23, 0.9, 0.75)
	add_theme_stylebox_override("panel", _panel_style(panel_bg, panel_border, panel_radius))
	_build_ui()
	_render_items()

func update_items(items: Array, type_filter: String = "") -> void:
	_all_items = items.duplicate(true)
	_current_type_filter = type_filter
	if _inventory_list == null:
		return
	_render_items()

func _render_items() -> void:
	_inventory_list.clear()
	var visible_count := 0
	for item in _filtered_sorted_items():
		if _current_type_filter != "" and item.type_key != _current_type_filter:
			continue
		var index := _inventory_list.add_item(format_item(item), _item_texture(item))
		_inventory_list.set_item_metadata(index, item)
		_inventory_list.set_item_custom_fg_color(index, _row_color(item))
		visible_count += 1
	_refresh_status_strip(visible_count)
	_clear_selection()

func _filtered_sorted_items() -> Array:
	var items := _all_items.duplicate(true)
	if _sort_option == null:
		return items
	match _sort_option.selected:
		1:
			items.sort_custom(func(a, b): return str(a.type_key) < str(b.type_key))
		2:
			items.sort_custom(func(a, b): return int(a.tier) > int(b.tier))
		3:
			items.sort_custom(func(a, b): return int(a.price) > int(b.price))
		4:
			items.sort_custom(func(a, b): return int(a.get("quantity", 1)) > int(b.get("quantity", 1)))
	return items

func format_item(item: Dictionary) -> String:
	var quantity := int(item.get("quantity", 1))
	return "%s  Lv.%d  x%d\n%s\n￥%d" % [
		component_database.display_type(item.type_key),
		item.tier,
		quantity,
		item.name,
		item.price,
	]

func _build_ui() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10 if fullscreen_catalog else 6)
	add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)

	var label := Label.new()
	label.text = "背包"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 28 if fullscreen_catalog else 22)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	header.add_child(label)

	_clear_filter_button = Button.new()
	_clear_filter_button.text = "全部"
	_clear_filter_button.custom_minimum_size = Vector2(108 if fullscreen_catalog else 0, 36 if fullscreen_catalog else 0)
	_clear_filter_button.pressed.connect(filter_cleared.emit)
	header.add_child(_clear_filter_button)

	if fullscreen_catalog:
		var status_strip := HBoxContainer.new()
		status_strip.name = "InventoryStatusStrip"
		status_strip.add_theme_constant_override("separation", 8)
		box.add_child(status_strip)

		_slot_status_label = _make_chip("当前槽位 全部")
		status_strip.add_child(_slot_status_label)
		_count_status_label = _make_chip("库存 0")
		status_strip.add_child(_count_status_label)
		_fit_status_label = _make_chip("可安装 -")
		status_strip.add_child(_fit_status_label)
		_order_status_label = _make_chip("订单可用 -")
		status_strip.add_child(_order_status_label)

	_sort_option = OptionButton.new()
	_sort_option.custom_minimum_size = Vector2(220 if fullscreen_catalog else 0, 38 if fullscreen_catalog else 34)
	for option in SORT_OPTIONS:
		_sort_option.add_item(option)
	_sort_option.item_selected.connect(_on_sort_selected)
	box.add_child(_sort_option)

	var content_row := HBoxContainer.new()
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 14 if fullscreen_catalog else 8)
	box.add_child(content_row)

	_inventory_list = ItemList.new()
	_inventory_list.set_script(DRAGGABLE_ITEM_LIST_SCRIPT)
	_inventory_list.custom_minimum_size = Vector2(0, 360 if fullscreen_catalog else 158)
	_inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_list.max_columns = 7 if fullscreen_catalog else 3
	_inventory_list.same_column_width = true
	_inventory_list.fixed_column_width = 156 if fullscreen_catalog else 150
	_inventory_list.icon_mode = ItemList.ICON_MODE_TOP
	_inventory_list.fixed_icon_size = Vector2i(88, 64) if fullscreen_catalog else Vector2i(64, 46)
	_inventory_list.auto_height = false
	_inventory_list.max_text_lines = 3
	_inventory_list.add_theme_font_size_override("font_size", 14 if fullscreen_catalog else 13)
	_inventory_list.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	_inventory_list.add_theme_color_override("font_selected_color", Color(1.0, 1.0, 1.0))
	_inventory_list.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.045, 0.095, 0.95), Color(0.17, 0.22, 0.38, 0.9), 8))
	_inventory_list.add_theme_stylebox_override("focus", _panel_style(Color(0, 0, 0, 0), Color(0.55, 0.95, 1.0, 0.8), 8))
	_inventory_list.add_theme_stylebox_override("selected", _panel_style(Color(0.10, 0.25, 0.28, 0.92), Color(0.32, 1.0, 0.76, 0.95), 8))
	_inventory_list.add_theme_stylebox_override("selected_focus", _panel_style(Color(0.10, 0.20, 0.32, 0.95), Color(0.55, 0.95, 1.0, 0.95), 8))
	_inventory_list.item_selected.connect(_on_item_selected)
	_inventory_list.item_activated.connect(_on_item_activated)
	content_row.add_child(_inventory_list)

	var details_panel := PanelContainer.new()
	details_panel.custom_minimum_size = Vector2(330 if fullscreen_catalog else 216, 0)
	details_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.035, 0.078, 0.96), Color(0.15, 0.68, 0.66, 0.75), 8))
	content_row.add_child(details_panel)

	var details_box := VBoxContainer.new()
	details_box.add_theme_constant_override("separation", 7)
	details_panel.add_child(details_box)

	_item_preview = TextureRect.new()
	_item_preview.custom_minimum_size = Vector2(300, 104) if fullscreen_catalog else Vector2(196, 54)
	_item_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_item_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	details_box.add_child(_item_preview)

	_details_label = Label.new()
	_details_label.text = "选择配件后查看详情"
	_details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not fullscreen_catalog:
		_details_label.max_lines_visible = 4
		_details_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_details_label.clip_text = true
	_details_label.custom_minimum_size = Vector2(0, 116 if fullscreen_catalog else 64)
	_details_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_label.add_theme_font_size_override("font_size", 15 if fullscreen_catalog else 13)
	details_box.add_child(_details_label)

	_install_button = Button.new()
	_install_button.text = "安装选中配件"
	_install_button.disabled = true
	_install_button.custom_minimum_size = Vector2(0, 40 if fullscreen_catalog else 0)
	_install_button.pressed.connect(_emit_selected_item)
	details_box.add_child(_install_button)

	_sell_button = Button.new()
	_sell_button.text = "出售选中配件"
	_sell_button.disabled = true
	_sell_button.custom_minimum_size = Vector2(0, 40 if fullscreen_catalog else 0)
	_sell_button.pressed.connect(_emit_selected_item_for_sale)
	details_box.add_child(_sell_button)

	_wire_focus_chain()

func _on_item_selected(index: int) -> void:
	_selected_item = _inventory_list.get_item_metadata(index)
	_item_preview.texture = _detail_texture(_selected_item)
	_details_label.text = _format_details(_selected_item)
	_refresh_action_buttons()
	_sell_button.disabled = false

func _on_item_activated(index: int) -> void:
	_selected_item = _inventory_list.get_item_metadata(index)
	_emit_selected_item()

func _emit_selected_item() -> void:
	if _selected_item.is_empty():
		return
	item_selected.emit(_selected_item)

func _emit_selected_item_for_sale() -> void:
	if _selected_item.is_empty():
		return
	item_sold.emit(_selected_item)

func _on_sort_selected(_index: int) -> void:
	_render_items()

func _clear_selection() -> void:
	_selected_item = {}
	if _item_preview:
		_item_preview.texture = null
	if _details_label:
		_details_label.text = "选择配件后查看详情"
	if _install_button:
		_install_button.text = "安装选中配件"
		_install_button.disabled = true
	if _sell_button:
		_sell_button.text = "出售选中配件"
		_sell_button.disabled = true

func _format_details(item: Dictionary) -> String:
	var hints: Array[String] = []
	if game:
		var install_issues: Array[String] = game.can_install_component(item)
		hints.append("可安装" if install_issues.is_empty() else "不兼容：%s" % "；".join(install_issues))
		hints.append("满足订单" if game.component_meets_current_order(item) else "未满足当前订单")
	return "%s\n%s\n型号：%s  品质：%s  尺寸：%s  数量：x%d\n%s" % [
		item.name,
		item.describe,
		item.model,
		item.quality,
		item.size,
		int(item.get("quantity", 1)),
		" / ".join(hints),
	]

func _refresh_status_strip(visible_count: int = -1) -> void:
	if not fullscreen_catalog:
		return
	var shown := visible_count if visible_count >= 0 else _inventory_list.item_count
	if _slot_status_label:
		var slot_text: String = "全部" if _current_type_filter == "" or component_database == null else component_database.display_type(_current_type_filter)
		_slot_status_label.text = "当前槽位 %s" % slot_text
	if _count_status_label:
		_count_status_label.text = "库存 %d / 当前显示 %d" % [_all_items.size(), shown]
	var installable_count := 0
	var order_count := 0
	for item in _all_items:
		if _current_type_filter != "" and str(item.type_key) != _current_type_filter:
			continue
		if game == null or game.can_install_component(item).is_empty():
			installable_count += 1
		if game and game.component_meets_current_order(item):
			order_count += 1
	if _fit_status_label:
		_fit_status_label.text = "可安装 %d" % installable_count
	if _order_status_label:
		_order_status_label.text = _catalog_order_summary(order_count)

func _catalog_order_summary(order_count: int) -> String:
	if game == null:
		return "订单可用 %d" % order_count
	var order: Dictionary = game.get_current_order()
	if order.is_empty():
		return "订单可用 %d" % order_count
	var requirements: Dictionary = order.get("requirements", {})
	var target: String = "全部槽位"
	if _current_type_filter != "":
		target = component_database.display_type(_current_type_filter)
		if requirements.has(_current_type_filter):
			target = "%s Lv.%d+" % [target, int(requirements[_current_type_filter])]
	return "订单可用 %d / %s" % [order_count, target]

func _refresh_action_buttons() -> void:
	if _install_button == null:
		return
	if _selected_item.is_empty():
		_install_button.text = "安装选中配件"
		_install_button.disabled = true
		return
	var issues: Array[String] = []
	if game:
		issues = game.can_install_component(_selected_item)
	_install_button.disabled = not issues.is_empty()
	_install_button.text = "安装选中配件" if issues.is_empty() else "不兼容，无法安装"

func _row_color(item: Dictionary) -> Color:
	if game and not game.can_install_component(item).is_empty():
		return Color(1.0, 0.43, 0.36)
	if game and game.component_meets_current_order(item):
		return Color(0.36, 1.0, 0.62)
	return _quality_color(str(item.quality))

func _quality_color(quality: String) -> Color:
	match quality:
		"传说":
			return Color(1.0, 0.72, 0.18)
		"史诗":
			return Color(0.74, 0.48, 1.0)
		"稀有":
			return Color(0.30, 0.63, 1.0)
		"精良":
			return Color(0.35, 0.92, 0.58)
		_:
			return Color(0.88, 0.88, 0.88)

func _item_texture(item: Dictionary) -> Texture2D:
	return ITEM_IMAGES.get(str(item.type_key), ITEM_IMAGES["CPU"])

func _detail_texture(item: Dictionary) -> Texture2D:
	return ITEM_DETAIL_IMAGES.get(str(item.type_key), _item_texture(item))

func _panel_style(color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border_color
	box.set_border_width_all(1)
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

func _wire_focus_chain() -> void:
	if not fullscreen_catalog:
		return
	var controls: Array[Control] = [
		_clear_filter_button,
		_sort_option,
		_inventory_list,
		_install_button,
		_sell_button,
	]
	var previous: Control = null
	for control in controls:
		if control == null:
			continue
		control.focus_mode = Control.FOCUS_ALL
		if previous:
			previous.focus_neighbor_right = control.get_path()
			previous.focus_neighbor_bottom = control.get_path()
			control.focus_neighbor_left = previous.get_path()
			control.focus_neighbor_top = previous.get_path()
		previous = control

func _make_chip(text: String) -> Label:
	var chip := Label.new()
	chip.text = text
	chip.clip_text = true
	chip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	chip.custom_minimum_size = Vector2(0, 34)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_theme_font_size_override("font_size", 14)
	chip.add_theme_color_override("font_color", Color(0.90, 0.98, 0.94))
	chip.add_theme_stylebox_override("normal", _panel_style(Color(0.035, 0.075, 0.095, 0.92), Color(0.18, 0.52, 0.45, 0.75), 8))
	return chip
