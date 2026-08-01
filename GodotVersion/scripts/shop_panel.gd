class_name ShopPanel
extends PanelContainer

signal item_purchased(item: Dictionary)
signal item_purchased_and_installed(item: Dictionary)

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

var _shop_list: ItemList
var _item_preview: TextureRect
var _details_label: Label
var _buy_button: Button
var _quick_install_button: Button
var _type_filter: OptionButton
var _quality_filter: OptionButton
var _sort_option: OptionButton
var _clear_filter_button: Button
var _compatible_toggle: CheckBox
var _order_toggle: CheckBox
var _count_label: Label
var _slot_status_label: Label
var _money_status_label: Label
var _order_chip_label: Label
var _fit_status_label: Label
var _selected_item: Dictionary = {}
var _all_items: Array = []
var _current_type_filter := ""
var _current_quality_filter := ""
var component_database: Node
var game: Node
var fullscreen_catalog := false

const QUALITY_OPTIONS := ["", "传说", "史诗", "稀有", "精良", "普通"]
const SORT_OPTIONS := ["默认排序", "价格低到高", "价格高到低", "等级高到低", "等级低到高"]

func _ready() -> void:
	custom_minimum_size = Vector2(0, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel_radius := 8 if fullscreen_catalog else 14
	var panel_bg := Color(0.014, 0.022, 0.052, 0.98) if fullscreen_catalog else Color(0.025, 0.035, 0.12, 0.92)
	var panel_border := Color(0.22, 0.78, 0.92, 0.82) if fullscreen_catalog else Color(0.43, 0.23, 0.9, 0.75)
	add_theme_stylebox_override("panel", _panel_style(panel_bg, panel_border, panel_radius))
	_build_ui()
	_render_items()

func update_items(items: Array) -> void:
	_all_items = items.duplicate(true)
	_rebuild_type_filter()
	if _shop_list:
		_render_items()

func set_type_filter(type_key: String) -> void:
	_current_type_filter = type_key
	_select_type_filter(type_key)
	_current_type_filter = type_key
	if _shop_list:
		_render_items()

func clear_filters() -> void:
	_current_type_filter = ""
	_current_quality_filter = ""
	if _compatible_toggle:
		_compatible_toggle.button_pressed = false
	if _order_toggle:
		_order_toggle.button_pressed = false
	_select_type_filter("")
	if _quality_filter:
		_quality_filter.select(0)
	if _sort_option:
		_sort_option.select(0)
	if _shop_list:
		_render_items()

func get_visible_item_count() -> int:
	if _shop_list == null:
		return 0
	return _shop_list.item_count

func get_visible_type_counts() -> Dictionary:
	var counts := {}
	if _shop_list == null:
		return counts
	for i in range(_shop_list.item_count):
		var item: Dictionary = _shop_list.get_item_metadata(i)
		var type_key := str(item.type_key)
		counts[type_key] = int(counts.get(type_key, 0)) + 1
	return counts

func _render_items() -> void:
	if _shop_list == null or _count_label == null:
		return
	_shop_list.clear()
	var visible_count := 0
	for item in _filtered_sorted_items():
		var index := _shop_list.add_item(format_item(item), _item_texture(item))
		_shop_list.set_item_metadata(index, item)
		_shop_list.set_item_custom_fg_color(index, _row_color(item))
		visible_count += 1
	_count_label.text = "显示 %d / %d 件商品" % [visible_count, _all_items.size()]
	_refresh_status_strip(visible_count)
	_clear_selection()

func _filtered_sorted_items() -> Array:
	var items: Array = []
	for item in _all_items:
		if _current_type_filter != "" and item.type_key != _current_type_filter:
			continue
		if _current_quality_filter != "" and item.quality != _current_quality_filter:
			continue
		if _compatible_toggle and _compatible_toggle.button_pressed and game and not game.can_install_component(item).is_empty():
			continue
		if _order_toggle and _order_toggle.button_pressed and game and not game.component_meets_current_order(item):
			continue
		items.append(item)
	_sort_items(items)
	return items

func format_item(item: Dictionary) -> String:
	var status := "%s / %s" % [_install_status_label(item), _order_status_label(item)]
	return "%s  Lv.%d  ￥%d\n%s\n%s" % [
		component_database.display_type(item.type_key),
		int(item.tier),
		int(item.price),
		str(item.name),
		status,
	]

func _build_ui() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10 if fullscreen_catalog else 6)
	add_child(box)

	var label := Label.new()
	label.text = "YellowFish 商店"
	label.add_theme_font_size_override("font_size", 28 if fullscreen_catalog else 24)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	box.add_child(label)

	if fullscreen_catalog:
		var status_strip := HBoxContainer.new()
		status_strip.name = "ShopStatusStrip"
		status_strip.add_theme_constant_override("separation", 8)
		box.add_child(status_strip)

		_slot_status_label = _make_chip("当前槽位 全部")
		status_strip.add_child(_slot_status_label)
		_money_status_label = _make_chip("资金 -")
		status_strip.add_child(_money_status_label)
		_order_chip_label = _make_chip("订单 -")
		status_strip.add_child(_order_chip_label)
		_fit_status_label = _make_chip("兼容 -")
		status_strip.add_child(_fit_status_label)

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	box.add_child(filters)

	_type_filter = OptionButton.new()
	_type_filter.custom_minimum_size = Vector2(190 if fullscreen_catalog else 150, 36 if fullscreen_catalog else 0)
	_type_filter.item_selected.connect(_on_type_filter_selected)
	filters.add_child(_type_filter)

	_quality_filter = OptionButton.new()
	_quality_filter.custom_minimum_size = Vector2(156 if fullscreen_catalog else 0, 36 if fullscreen_catalog else 0)
	for quality in QUALITY_OPTIONS:
		_quality_filter.add_item("全部品质" if quality == "" else quality)
	_quality_filter.item_selected.connect(_on_quality_filter_selected)
	filters.add_child(_quality_filter)

	_sort_option = OptionButton.new()
	_sort_option.custom_minimum_size = Vector2(180 if fullscreen_catalog else 0, 36 if fullscreen_catalog else 0)
	for option in SORT_OPTIONS:
		_sort_option.add_item(option)
	_sort_option.item_selected.connect(_on_sort_selected)
	filters.add_child(_sort_option)

	_clear_filter_button = Button.new()
	_clear_filter_button.text = "清除筛选"
	_clear_filter_button.custom_minimum_size = Vector2(108 if fullscreen_catalog else 0, 36 if fullscreen_catalog else 0)
	_clear_filter_button.pressed.connect(clear_filters)
	filters.add_child(_clear_filter_button)

	var smart_filters := HBoxContainer.new()
	smart_filters.add_theme_constant_override("separation", 8)
	box.add_child(smart_filters)

	_compatible_toggle = CheckBox.new()
	_compatible_toggle.text = "只看兼容"
	_compatible_toggle.toggled.connect(_on_smart_filter_toggled)
	smart_filters.add_child(_compatible_toggle)

	_order_toggle = CheckBox.new()
	_order_toggle.text = "只看满足订单"
	_order_toggle.toggled.connect(_on_smart_filter_toggled)
	smart_filters.add_child(_order_toggle)

	_count_label = Label.new()
	_count_label.text = "显示 0 / 0 件商品"
	_count_label.add_theme_color_override("font_color", Color(0.78, 0.86, 1.0))
	box.add_child(_count_label)

	var content_row := HBoxContainer.new()
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 14 if fullscreen_catalog else 8)
	box.add_child(content_row)

	_shop_list = ItemList.new()
	_shop_list.custom_minimum_size = Vector2(0, 360 if fullscreen_catalog else 158)
	_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_list.max_columns = 7 if fullscreen_catalog else 3
	_shop_list.same_column_width = true
	_shop_list.fixed_column_width = 156 if fullscreen_catalog else 150
	_shop_list.icon_mode = ItemList.ICON_MODE_TOP
	_shop_list.fixed_icon_size = Vector2i(88, 64) if fullscreen_catalog else Vector2i(64, 46)
	_shop_list.auto_height = false
	_shop_list.max_text_lines = 3
	_shop_list.add_theme_font_size_override("font_size", 14 if fullscreen_catalog else 13)
	_shop_list.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	_shop_list.add_theme_color_override("font_selected_color", Color(1.0, 1.0, 1.0))
	_shop_list.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.045, 0.095, 0.95), Color(0.17, 0.22, 0.38, 0.9), 8))
	_shop_list.add_theme_stylebox_override("focus", _panel_style(Color(0, 0, 0, 0), Color(0.83, 0.62, 1.0, 0.9), 8))
	_shop_list.add_theme_stylebox_override("selected", _panel_style(Color(0.23, 0.24, 0.29, 0.92), Color(1.0, 0.77, 0.30, 0.95), 8))
	_shop_list.add_theme_stylebox_override("selected_focus", _panel_style(Color(0.20, 0.18, 0.34, 0.95), Color(0.95, 0.55, 1.0, 0.95), 8))
	_shop_list.item_selected.connect(_on_item_selected)
	_shop_list.item_activated.connect(_on_item_activated)
	content_row.add_child(_shop_list)

	var details_panel := PanelContainer.new()
	details_panel.custom_minimum_size = Vector2(330 if fullscreen_catalog else 216, 0)
	details_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.028, 0.085, 0.96), Color(0.15, 0.56, 0.74, 0.75), 8))
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
	_details_label.text = "选择商品后查看详情"
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

	var action_row := VBoxContainer.new()
	action_row.add_theme_constant_override("separation", 7)
	details_box.add_child(action_row)

	_buy_button = Button.new()
	_buy_button.text = "购买"
	_buy_button.disabled = true
	_buy_button.custom_minimum_size = Vector2(0, 40 if fullscreen_catalog else 0)
	_buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy_button.pressed.connect(_emit_selected_item)
	action_row.add_child(_buy_button)

	_quick_install_button = Button.new()
	_quick_install_button.text = "购买并安装"
	_quick_install_button.disabled = true
	_quick_install_button.custom_minimum_size = Vector2(0, 40 if fullscreen_catalog else 0)
	_quick_install_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quick_install_button.pressed.connect(_emit_selected_item_for_install)
	action_row.add_child(_quick_install_button)

	_wire_focus_chain()

func _on_item_selected(index: int) -> void:
	_selected_item = _shop_list.get_item_metadata(index)
	_item_preview.texture = _detail_texture(_selected_item)
	_details_label.text = _format_details(_selected_item)
	_refresh_action_buttons()

func _on_item_activated(index: int) -> void:
	_selected_item = _shop_list.get_item_metadata(index)
	_emit_selected_item()

func _emit_selected_item() -> void:
	if _selected_item.is_empty():
		return
	item_purchased.emit(_selected_item)

func _emit_selected_item_for_install() -> void:
	if _selected_item.is_empty():
		return
	item_purchased_and_installed.emit(_selected_item)

func _clear_selection() -> void:
	_selected_item = {}
	if _item_preview:
		_item_preview.texture = null
	if _details_label:
		_details_label.text = "选择商品后查看详情"
	if _buy_button:
		_buy_button.text = "购买"
		_buy_button.disabled = true
	if _quick_install_button:
		_quick_install_button.text = "购买并安装"
		_quick_install_button.disabled = true

func _rebuild_type_filter() -> void:
	if _type_filter == null:
		return
	var previous := _current_type_filter
	_type_filter.clear()
	_type_filter.add_item("全部类型")
	_type_filter.set_item_metadata(0, "")
	var type_keys: Array[String] = []
	for item in _all_items:
		var type_key := str(item.type_key)
		if not type_keys.has(type_key):
			type_keys.append(type_key)
	type_keys.sort()
	for type_key in type_keys:
		var index := _type_filter.item_count
		_type_filter.add_item(component_database.display_type(type_key))
		_type_filter.set_item_metadata(index, type_key)
	_select_type_filter(previous)

func _select_type_filter(type_key: String) -> void:
	if _type_filter == null:
		return
	for i in range(_type_filter.item_count):
		if str(_type_filter.get_item_metadata(i)) == type_key:
			_type_filter.select(i)
			return
	_type_filter.select(0)

func _on_type_filter_selected(index: int) -> void:
	_current_type_filter = str(_type_filter.get_item_metadata(index))
	_render_items()

func _on_quality_filter_selected(index: int) -> void:
	_current_quality_filter = QUALITY_OPTIONS[index]
	_render_items()

func _on_sort_selected(_index: int) -> void:
	_render_items()

func _on_smart_filter_toggled(_pressed: bool) -> void:
	_render_items()

func _format_details(item: Dictionary) -> String:
	var hints: Array[String] = []
	if game:
		var install_issues: Array[String] = game.can_install_component(item)
		if install_issues.is_empty():
			hints.append("兼容")
		else:
			hints.append("预警：%s" % "；".join(install_issues))
		hints.append("满足订单" if game.component_meets_current_order(item) else "未满足当前订单")
	var spec_text := _format_specs(item)
	return "%s\n%s\n型号：%s  品质：%s  价格：￥%d%s\n%s" % [
		item.name,
		item.describe,
		item.model,
		item.quality,
		item.price,
		"" if spec_text == "" else "  %s" % spec_text,
		" / ".join(hints),
	]

func _refresh_status_strip(visible_count: int = -1) -> void:
	if not fullscreen_catalog:
		return
	var shown := visible_count if visible_count >= 0 else get_visible_item_count()
	if _slot_status_label:
		var slot_text: String = "全部" if _current_type_filter == "" or component_database == null else component_database.display_type(_current_type_filter)
		_slot_status_label.text = "当前槽位 %s" % slot_text
	if _money_status_label:
		var money_text: String = "-" if game == null else "￥%d" % int(game.money)
		_money_status_label.text = "资金 %s" % money_text
	if _order_chip_label:
		_order_chip_label.text = _catalog_order_summary()
	if _fit_status_label:
		var compatible_count := 0
		var order_count := 0
		for item in _all_items:
			if _current_type_filter != "" and str(item.type_key) != _current_type_filter:
				continue
			if game == null or game.can_install_component(item).is_empty():
				compatible_count += 1
			if game and game.component_meets_current_order(item):
				order_count += 1
		_fit_status_label.text = "兼容 %d / 订单可用 %d / 当前显示 %d" % [compatible_count, order_count, shown]

func _catalog_order_summary() -> String:
	if game == null:
		return "订单 -"
	var order: Dictionary = game.get_current_order()
	if order.is_empty():
		return "订单 无"
	var requirements: Dictionary = order.get("requirements", {})
	var target: String = "全部槽位"
	if _current_type_filter != "":
		target = component_database.display_type(_current_type_filter)
		if requirements.has(_current_type_filter):
			target = "%s Lv.%d+" % [target, int(requirements[_current_type_filter])]
	return "订单 %s / %s" % [str(order.get("name", "未命名")), target]

func _refresh_action_buttons() -> void:
	if _buy_button == null or _quick_install_button == null:
		return
	if _selected_item.is_empty():
		_buy_button.text = "购买"
		_buy_button.disabled = true
		_quick_install_button.text = "购买并安装"
		_quick_install_button.disabled = true
		return
	var price := int(_selected_item.get("price", 0))
	var has_money := game == null or int(game.money) >= price
	_buy_button.disabled = not has_money
	_buy_button.text = "购买 ￥%d" % price if has_money else "资金不足 ￥%d" % price
	var issues: Array[String] = []
	if game:
		issues = game.can_install_component(_selected_item)
	_quick_install_button.disabled = not has_money or not issues.is_empty()
	if not has_money:
		_quick_install_button.text = "资金不足，无法安装"
	elif not issues.is_empty():
		_quick_install_button.text = "不兼容，无法安装"
	else:
		_quick_install_button.text = "购买并安装"

func _format_specs(item: Dictionary) -> String:
	var specs: Dictionary = item.get("specs", {})
	var parts: Array[String] = []
	if specs.has("platform"):
		parts.append("平台：%s" % specs.platform)
	if int(specs.get("power_draw", 0)) > 0:
		parts.append("功耗：%dW" % int(specs.power_draw))
	if int(specs.get("capacity_w", 0)) > 0:
		parts.append("额定：%dW" % int(specs.capacity_w))
	if int(specs.get("required_case_tier", 0)) > 0:
		parts.append("机箱需求：Lv.%d" % int(specs.required_case_tier))
	if int(specs.get("max_gpu_tier", 0)) > 0:
		parts.append("显卡上限：Lv.%d" % int(specs.max_gpu_tier))
	return "  ".join(parts)

func _sort_items(items: Array) -> void:
	if _sort_option == null:
		return
	match _sort_option.selected:
		1:
			items.sort_custom(func(a, b): return int(a.price) < int(b.price))
		2:
			items.sort_custom(func(a, b): return int(a.price) > int(b.price))
		3:
			items.sort_custom(func(a, b): return int(a.tier) > int(b.tier))
		4:
			items.sort_custom(func(a, b): return int(a.tier) < int(b.tier))

func _wire_focus_chain() -> void:
	if not fullscreen_catalog:
		return
	var controls: Array[Control] = [
		_type_filter,
		_quality_filter,
		_sort_option,
		_clear_filter_button,
		_compatible_toggle,
		_order_toggle,
		_shop_list,
		_buy_button,
		_quick_install_button,
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

func _install_status_label(item: Dictionary) -> String:
	if game == null:
		return "待检测"
	var issues: Array[String] = game.can_install_component(item)
	return "兼容" if issues.is_empty() else "不兼容"

func _order_status_label(item: Dictionary) -> String:
	if game == null:
		return "无订单"
	if game.component_meets_current_order(item):
		return "满足订单"
	var order: Dictionary = game.get_current_order()
	var requirements: Dictionary = order.get("requirements", {})
	var slot := str(item.type_key)
	if requirements.has(slot):
		return "等级不足"
	return "非订单项"

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

func _make_chip(text: String) -> Label:
	var chip := Label.new()
	chip.text = text
	chip.clip_text = true
	chip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	chip.custom_minimum_size = Vector2(0, 34)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_theme_font_size_override("font_size", 14)
	chip.add_theme_color_override("font_color", Color(0.90, 0.96, 1.0))
	chip.add_theme_stylebox_override("normal", _panel_style(Color(0.045, 0.065, 0.12, 0.92), Color(0.18, 0.38, 0.58, 0.75), 8))
	return chip
