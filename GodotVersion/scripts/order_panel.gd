class_name OrderPanel
extends PanelContainer

signal order_selected(order_index: int)
signal order_desk_requested

var _current_label: Label
var _queue_label: Label
var _open_button: Button
var _quick_accept_button: Button
var _selected_order_index := -1
var _order_defs: Array = []
var _available_order_indices: Array[int] = []
var _active_order_index := -1
var component_database: Node

func _ready() -> void:
	custom_minimum_size = Vector2(0, 104)
	_build_ui()
	_render_orders()

func update_orders(order_defs: Array, available_order_indices: Array[int], active_order_index: int) -> void:
	_order_defs = order_defs.duplicate(true)
	_available_order_indices = available_order_indices.duplicate()
	_active_order_index = active_order_index
	if _current_label == null:
		return
	_render_orders()

func _build_ui() -> void:
	add_theme_stylebox_override("panel", _stylebox(Color(0.025, 0.035, 0.11, 0.98), Color(0.20, 0.80, 0.92), 8))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)

	var title := Label.new()
	title.text = "订单调度"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.82, 0.96, 1.0))
	header.add_child(title)

	_open_button = Button.new()
	_open_button.name = "OpenOrderDeskButton"
	_open_button.text = "订单大厅"
	_open_button.custom_minimum_size = Vector2(112, 32)
	_open_button.pressed.connect(func() -> void: order_desk_requested.emit())
	header.add_child(_open_button)

	_current_label = Label.new()
	_current_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_current_label.custom_minimum_size = Vector2(0, 34)
	_current_label.add_theme_font_size_override("font_size", 13)
	box.add_child(_current_label)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	box.add_child(footer)

	_queue_label = Label.new()
	_queue_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_queue_label.add_theme_color_override("font_color", Color(0.66, 0.74, 0.86))
	footer.add_child(_queue_label)

	_quick_accept_button = Button.new()
	_quick_accept_button.name = "QuickAcceptOrderButton"
	_quick_accept_button.text = "接取下一单"
	_quick_accept_button.custom_minimum_size = Vector2(116, 30)
	_quick_accept_button.pressed.connect(_emit_selected_order)
	footer.add_child(_quick_accept_button)

func _render_orders() -> void:
	_selected_order_index = _next_selectable_order()
	var active_order := _order_at(_active_order_index)
	if active_order.is_empty():
		_current_label.text = "首发订单已全部完成。订单大厅可回看职业进度。"
	else:
		_current_label.text = "当前：%s / %s / 难度 %d / 奖励 %d" % [
			str(active_order.get("name", "当前订单")),
			str(active_order.get("customer", "客户")),
			int(active_order.get("difficulty", 1)),
			int(active_order.get("reward", 0)),
		]
	_queue_label.text = "可接订单 %d，已完成 %d / %d" % [
		_available_order_indices.size(),
		maxi(0, _order_defs.size() - _available_order_indices.size()),
		_order_defs.size(),
	]
	_quick_accept_button.disabled = _selected_order_index < 0 or _selected_order_index == _active_order_index

func _next_selectable_order() -> int:
	for order_index in _available_order_indices:
		if order_index != _active_order_index:
			return order_index
	return -1

func _order_at(order_index: int) -> Dictionary:
	if order_index < 0 or order_index >= _order_defs.size():
		return {}
	return _order_defs[order_index]

func _emit_selected_order() -> void:
	if _selected_order_index < 0 or _selected_order_index == _active_order_index:
		order_desk_requested.emit()
		return
	order_selected.emit(_selected_order_index)

func _stylebox(color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border_color
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 10
	box.content_margin_top = 8
	box.content_margin_right = 10
	box.content_margin_bottom = 8
	return box
