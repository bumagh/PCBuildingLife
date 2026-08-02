extends Control

@export var save_path_override := ""

const BUILDING_PANEL_SCENE := preload("res://scenes/BuildingPanel.tscn")
const INVENTORY_PANEL_SCENE := preload("res://scenes/InventoryPanel.tscn")
const ORDER_PANEL_SCENE := preload("res://scenes/OrderPanel.tscn")
const SHOP_PANEL_SCENE := preload("res://scenes/ShopPanel.tscn")
const UI_ICON_TEXTURES := {
	"workbench": preload("res://assets/ui/icons/workbench.svg"),
	"orders": preload("res://assets/ui/icons/orders.svg"),
	"shop": preload("res://assets/ui/icons/shop.svg"),
	"inventory": preload("res://assets/ui/icons/inventory.svg"),
	"tasks": preload("res://assets/ui/icons/tasks.svg"),
	"power": preload("res://assets/ui/icons/power.svg"),
	"monitor": preload("res://assets/ui/icons/monitor.svg"),
	"check": preload("res://assets/ui/icons/check.svg"),
	"delivery": preload("res://assets/ui/icons/delivery.svg"),
	"save": preload("res://assets/ui/icons/save.svg"),
	"load": preload("res://assets/ui/icons/load.svg"),
	"restart": preload("res://assets/ui/icons/restart.svg"),
	"system": preload("res://assets/ui/icons/system.svg"),
	"close": preload("res://assets/ui/icons/close.svg"),
}
const UI_ART_TEXTURES := {
	"app_cpu": preload("res://assets/ui/art/app_cpu.svg"),
	"app_gpu": preload("res://assets/ui/art/app_gpu.svg"),
	"app_driver": preload("res://assets/ui/art/app_driver.svg"),
	"app_files": preload("res://assets/ui/art/app_files.svg"),
	"app_benchmark": preload("res://assets/ui/art/app_benchmark.svg"),
	"customer_office": preload("res://assets/ui/art/customer_office.svg"),
	"customer_creator": preload("res://assets/ui/art/customer_creator.svg"),
	"customer_gamer": preload("res://assets/ui/art/customer_gamer.svg"),
	"badge_bronze": preload("res://assets/ui/art/badge_bronze.svg"),
	"badge_silver": preload("res://assets/ui/art/badge_silver.svg"),
	"badge_gold": preload("res://assets/ui/art/badge_gold.svg"),
}
const STARTING_MONEY := 20000
const SAVE_PATH := "user://save_game.json"
const ORDERS_PATH := "res://data/orders.json"
const RULES_PATH := "res://data/game_rules.json"
const SAVE_VERSION := 2
const REQUIRED_SLOTS := [
	"Case",
	"Power",
	"MotherBoard",
	"CPU",
	"VideoCard",
	"RAM",
	"SSD",
	"M2",
	"COOLER",
]
const ORDER_DEFS := [
	{
		"name": "入门办公机",
		"customer": "附近工作室",
		"reward": 3500,
		"requirements": {
			"Case": 60,
			"Power": 60,
			"MotherBoard": 60,
			"CPU": 60,
			"RAM": 60,
			"SSD": 55,
		},
	},
	{
		"name": "电竞直播机",
		"customer": "新人主播",
		"reward": 8500,
		"requirements": {
			"CPU": 85,
			"VideoCard": 85,
			"RAM": 85,
			"M2": 80,
			"COOLER": 82,
			"Power": 85,
		},
	},
	{
		"name": "渲染工作站",
		"customer": "小型动画团队",
		"reward": 14000,
		"requirements": {
			"Case": 90,
			"Power": 90,
			"MotherBoard": 90,
			"CPU": 92,
			"VideoCard": 92,
			"RAM": 92,
			"SSD": 88,
			"M2": 90,
			"COOLER": 90,
		},
	},
]

var money: int = STARTING_MONEY
var starting_money: int = STARTING_MONEY
var inventory: Array = []
var installed: Dictionary = {}
var current_filter: String = ""
var powered_on: bool = false
var system_booted: bool = false
var os_app: String = "未开机"
var monitor_app_key: String = "Desktop"
var driver_scan_completed: bool = false
var drivers_installed: bool = false
var gpu_driver_installed: bool = false
var os_restart_required: bool = false
var stability_test_completed: bool = false
var driver_last_report: Array[String] = []
var os_log: Array[String] = []
var current_order_index: int = 0
var available_order_indices: Array[int] = []
var completed_order_ids: Array[String] = []
var order_defs: Array = []
var required_slots: Array[String] = []
var sell_ratio: float = 0.55
var scoring_rules := {
	"performance_weight": 0.4,
	"budget_weight": 0.2,
	"compatibility_weight": 0.15,
	"boot_weight": 0.1,
	"software_weight": 0.15,
}
var last_delivery_score: Dictionary = {}
var tutorial_step: int = 0
var tutorial_order_viewed: bool = false
var tutorial_completed: bool = false
var benchmark_completed: bool = false
var money_label: Label
var order_label: Label
var status_label: Label
var action_feedback_panel: PanelContainer
var action_feedback_title: Label
var action_feedback_detail: Label
var action_feedback_tween: Tween
var money_feedback_tween: Tween
var status_feedback_tween: Tween
var os_feedback_tween: Tween
var last_operation_animation := ""
var operation_animation_count := 0
var tutorial_label: Label
var tutorial_progress_label: Label
var tutorial_action_button: Button
var progression_label: Label
var os_label: Label
var order_state_chip_label: Label
var order_progress_bar: ProgressBar
var os_state_chip_label: Label
var os_progress_bar: ProgressBar
var score_label: Label
var home_system_center_button: Button
var home_system_monitor_button: Button
var delivery_feedback_panel: PanelContainer
var delivery_feedback_title: Label
var delivery_feedback_detail: Label
var delivery_feedback_breakdown: Label
var delivery_feedback_tween: Tween
var feedback_sfx_player: AudioStreamPlayer
var building_panel: BuildingPanel
var workbench_footer: PanelContainer
var workbench_footer_summary_label: Label
var workbench_footer_completion_chip_label: Label
var workbench_footer_missing_chip_label: Label
var workbench_footer_next_chip_label: Label
var inventory_panel: InventoryPanel
var order_panel: Node
var shop_panel: ShopPanel
var last_save_migration_note := ""
var cheat_button: Button
var cheat_panel: PanelContainer
var monitor_overlay: PanelContainer
var monitor_app_title: Label
var monitor_task_board_label: Label
var monitor_content_label: Label
var monitor_status_label: Label
var monitor_action_row: HBoxContainer
var driver_scan_button: Button
var driver_install_button: Button
var driver_restart_button: Button
var gpu_driver_button: Button
var file_order_button: Button
var file_driver_button: Button
var file_benchmark_button: Button
var file_preflight_button: Button
var monitor_app_buttons: Array[Button] = []
var monitor_file_key: String = "order"
var pause_backdrop: ColorRect
var pause_panel: PanelContainer
var pause_status_label: Label
var pause_fullscreen_toggle: CheckButton
var pause_resolution_option: OptionButton
var pause_volume_slider: HSlider
var part_menu: PopupMenu
var _part_menu_slot := ""
var component_database: Node
var main_tabs: TabContainer
var catalog_workspace_panel: PanelContainer
var catalog_workspace_summary_label: Label
var catalog_workspace_slot_chip_label: Label
var catalog_workspace_order_chip_label: Label
var catalog_workspace_inventory_chip_label: Label
var catalog_workspace_state_label: Label
var catalog_workspace_pressure_chip_label: Label
var catalog_workspace_next_action_label: Label
var catalog_workspace_shop_button: Button
var catalog_workspace_inventory_button: Button
var home_bottom_dock: PanelContainer
var home_task_center_button: Button
var home_order_desk_button: Button
var home_deliver_order_button: Button
var home_workbench_tab_button: Button
var order_desk_overlay: ColorRect
var order_desk_list: ItemList
var order_desk_progress_label: Label
var order_desk_title_label: Label
var order_desk_meta_label: Label
var order_desk_customer_label: Label
var order_desk_hardware_ready_label: Label
var order_desk_software_ready_label: Label
var order_desk_delivery_ready_label: Label
var order_desk_requirements_label: Label
var order_desk_software_label: Label
var order_desk_status_label: Label
var order_desk_reward_label: Label
var order_desk_time_label: Label
var order_desk_difficulty_label: Label
var order_desk_scope_label: Label
var order_desk_income_label: Label
var order_desk_risk_label: Label
var order_desk_score_label: Label
var order_desk_unlock_label: Label
var order_desk_action_hint_label: Label
var order_desk_customer_art: TextureRect
var order_desk_grade_art: TextureRect
var order_desk_software_art: TextureRect
var order_desk_accept_button: Button
var order_desk_deliver_button: Button
var order_desk_task_button: Button
var order_desk_market_button: Button
var order_desk_selected_index := -1
var catalog_overlay: ColorRect
var catalog_title_label: Label
var catalog_money_label: Label
var catalog_status_label: Label
var catalog_shop_button: Button
var catalog_inventory_button: Button
var catalog_shop_panel: ShopPanel
var catalog_inventory_panel: InventoryPanel
var catalog_mode := "shop"
var catalog_previous_focus: Control
var task_center_overlay: ColorRect
var task_center_order_label: Label
var task_center_hardware_label: Label
var task_center_software_label: Label
var task_center_next_label: Label
var task_center_delivery_label: Label
var task_center_status_label: Label
var task_center_money_chip_label: Label
var task_center_progress_chip_label: Label
var task_center_queue_chip_label: Label
var task_center_state_chip_label: Label
var task_center_next_button: Button
var task_center_deliver_button: Button
var task_center_check_button: Button
var task_center_monitor_button: Button
var task_center_previous_focus: Control
var system_center_overlay: ColorRect
var system_center_status_label: Label
var system_center_software_label: Label
var system_center_log_label: Label
var system_center_power_button: Button
var system_center_info_button: Button
var system_center_driver_button: Button
var system_center_benchmark_button: Button
var system_center_stability_button: Button
var system_center_files_button: Button
var system_center_monitor_button: Button
var system_center_shutdown_button: Button
var system_center_previous_focus: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	component_database = get_node("/root/ComponentDatabase")
	if component_database.get_all_components().is_empty():
		component_database.load_components()
	_load_game_rules()
	_load_orders()
	if available_order_indices.is_empty():
		available_order_indices = _default_order_indices()
	_build_ui()
	var launch_mode: String = str(get_node("/root/GameSession").consume_launch_mode())
	if launch_mode == "continue":
		if not load_game(_active_save_path()):
			new_game()
			status_label.text = "未找到可读取的存档，已开始新游戏。"
	elif launch_mode == "new":
		new_game()
		save_game(_active_save_path())
	else:
		_refresh_all()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and catalog_overlay != null and catalog_overlay.visible:
		_close_catalog_overlay()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and task_center_overlay != null and task_center_overlay.visible:
		_close_task_center()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and order_desk_overlay != null and order_desk_overlay.visible:
		_close_order_desk()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and system_center_overlay != null and system_center_overlay.visible:
		_close_system_center()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and monitor_overlay != null and monitor_overlay.visible:
		_on_close_monitor_pressed()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.035, 0.13)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_top = 14
	root.offset_right = -16
	root.offset_bottom = -14
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	root.add_child(top_bar)

	var title := Label.new()
	title.text = "装机人生 · 装机工坊"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	top_bar.add_child(title)

	money_label = Label.new()
	money_label.add_theme_font_size_override("font_size", 20)
	money_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	top_bar.add_child(money_label)

	var finish_button := Button.new()
	finish_button.name = "FinishCheckButton"
	finish_button.text = "完成检测"
	_style_top_button(finish_button)
	finish_button.pressed.connect(_on_finish_pressed)
	top_bar.add_child(finish_button)

	var power_button := Button.new()
	power_button.name = "PowerButton"
	power_button.text = "电源按钮"
	_style_top_button(power_button)
	power_button.pressed.connect(_on_power_button_pressed)
	top_bar.add_child(power_button)

	var open_monitor_button := Button.new()
	open_monitor_button.name = "OpenMonitorButton"
	open_monitor_button.text = "Max Monitor"
	_style_top_button(open_monitor_button)
	open_monitor_button.pressed.connect(_on_open_monitor_pressed)
	top_bar.add_child(open_monitor_button)

	var deliver_button := Button.new()
	deliver_button.name = "TopDeliverButton"
	deliver_button.text = "交付订单"
	_style_top_button(deliver_button)
	deliver_button.pressed.connect(_on_deliver_pressed)
	top_bar.add_child(deliver_button)

	var save_button := Button.new()
	save_button.name = "SaveButton"
	save_button.text = "保存"
	save_button.tooltip_text = "保存当前进度"
	save_button.custom_minimum_size = Vector2(42, 38)
	save_button.text = ""
	_style_top_button(save_button)
	save_button.pressed.connect(_on_save_pressed)
	top_bar.add_child(save_button)

	var load_button := Button.new()
	load_button.name = "LoadButton"
	load_button.text = "读取"
	load_button.tooltip_text = "读取最近一次保存"
	load_button.custom_minimum_size = Vector2(42, 38)
	load_button.text = ""
	_style_top_button(load_button)
	load_button.pressed.connect(_on_load_pressed)
	top_bar.add_child(load_button)

	var reset_button := Button.new()
	reset_button.name = "RestartButton"
	reset_button.text = "重开"
	reset_button.tooltip_text = "重置当前装机进度"
	reset_button.custom_minimum_size = Vector2(42, 38)
	reset_button.text = ""
	_style_top_button(reset_button)
	reset_button.pressed.connect(_on_reset_pressed)
	top_bar.add_child(reset_button)

	var menu_button := Button.new()
	menu_button.name = "PauseMenuButton"
	menu_button.text = "☰"
	menu_button.tooltip_text = "暂停菜单"
	menu_button.custom_minimum_size = Vector2(40, 38)
	_style_top_button(menu_button)
	menu_button.pressed.connect(_on_pause_menu_pressed)
	top_bar.add_child(menu_button)

	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 10)
	root.add_child(main)

	var left_column := VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 8)
	main.add_child(left_column)

	var building_scroll := ScrollContainer.new()
	building_scroll.custom_minimum_size = Vector2(540, 0)
	building_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	building_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_column.add_child(building_scroll)

	building_panel = BUILDING_PANEL_SCENE.instantiate()
	building_panel.slot_selected.connect(_on_slot_pressed)
	building_panel.inventory_item_dropped.connect(_on_inventory_item_dropped)
	building_panel.slot_menu_requested.connect(_on_slot_menu_requested)
	building_scroll.add_child(building_panel)

	workbench_footer = PanelContainer.new()
	workbench_footer.name = "WorkbenchFooter"
	workbench_footer.custom_minimum_size = Vector2(0, 68)
	workbench_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workbench_footer.add_theme_stylebox_override("panel", _stylebox(Color(0.010, 0.018, 0.052, 0.94), Color(0.44, 0.34, 1.0, 0.78), 8))
	left_column.add_child(workbench_footer)

	var footer_box := VBoxContainer.new()
	footer_box.add_theme_constant_override("separation", 2)
	workbench_footer.add_child(footer_box)

	var footer_status_row := HBoxContainer.new()
	footer_status_row.add_theme_constant_override("separation", 4)
	footer_box.add_child(footer_status_row)

	workbench_footer_summary_label = Label.new()
	workbench_footer_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workbench_footer_summary_label.max_lines_visible = 1
	workbench_footer_summary_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	workbench_footer_summary_label.clip_text = true
	workbench_footer_summary_label.custom_minimum_size = Vector2(0, 14)
	workbench_footer_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workbench_footer_summary_label.add_theme_font_size_override("font_size", 9)
	workbench_footer_summary_label.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0))
	footer_status_row.add_child(workbench_footer_summary_label)

	workbench_footer_completion_chip_label = _add_compact_footer_chip(footer_status_row, "完成度", Color(1.0, 0.72, 0.28))
	workbench_footer_missing_chip_label = _add_compact_footer_chip(footer_status_row, "缺少", Color(0.24, 0.78, 0.92))
	workbench_footer_next_chip_label = _add_compact_footer_chip(footer_status_row, "下一步", Color(0.36, 1.0, 0.66))

	var footer_actions := HBoxContainer.new()
	footer_actions.add_theme_constant_override("separation", 4)
	footer_box.add_child(footer_actions)

	var footer_order_button := Button.new()
	footer_order_button.name = "FooterOrderButton"
	footer_order_button.text = "订单大厅"
	footer_order_button.custom_minimum_size = Vector2(0, 20)
	footer_order_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_home_dock_button(footer_order_button, Color(0.24, 0.78, 0.92))
	footer_order_button.pressed.connect(open_order_desk)
	footer_actions.add_child(footer_order_button)

	var footer_finish_button := Button.new()
	footer_finish_button.name = "FooterFinishButton"
	footer_finish_button.text = "完成检测"
	footer_finish_button.custom_minimum_size = Vector2(0, 20)
	footer_finish_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_home_dock_button(footer_finish_button, Color(1.0, 0.72, 0.28))
	footer_finish_button.pressed.connect(_on_finish_pressed)
	footer_actions.add_child(footer_finish_button)

	var footer_power_button := Button.new()
	footer_power_button.name = "FooterPowerButton"
	footer_power_button.text = "电源按钮"
	footer_power_button.custom_minimum_size = Vector2(0, 20)
	footer_power_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_home_dock_button(footer_power_button, Color(0.36, 1.0, 0.66))
	footer_power_button.pressed.connect(_on_power_button_pressed)
	footer_actions.add_child(footer_power_button)

	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 6)
	main.add_child(right_column)

	var catalog_actions := HBoxContainer.new()
	catalog_actions.add_theme_constant_override("separation", 8)
	right_column.add_child(catalog_actions)

	var open_task_center := Button.new()
	open_task_center.name = "OpenTaskCenterButton"
	open_task_center.text = "任务中心"
	open_task_center.custom_minimum_size = Vector2(130, 36)
	open_task_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_catalog_entry_button(open_task_center, Color(1.0, 0.72, 0.28))
	open_task_center.pressed.connect(open_task_center_overlay)
	catalog_actions.add_child(open_task_center)

	var open_shop_catalog := Button.new()
	open_shop_catalog.name = "OpenShopCatalogButton"
	open_shop_catalog.text = "配件市场"
	open_shop_catalog.custom_minimum_size = Vector2(130, 36)
	open_shop_catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_catalog_entry_button(open_shop_catalog, Color(0.24, 0.78, 0.92))
	open_shop_catalog.pressed.connect(open_shop_overlay)
	catalog_actions.add_child(open_shop_catalog)

	var open_inventory_catalog := Button.new()
	open_inventory_catalog.name = "OpenInventoryCatalogButton"
	open_inventory_catalog.text = "仓库"
	open_inventory_catalog.custom_minimum_size = Vector2(130, 36)
	open_inventory_catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_catalog_entry_button(open_inventory_catalog, Color(0.36, 1.0, 0.66))
	open_inventory_catalog.pressed.connect(open_inventory_overlay)
	catalog_actions.add_child(open_inventory_catalog)

	main_tabs = TabContainer.new()
	main_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_tabs.tabs_visible = false
	main_tabs.visible = false
	right_column.add_child(main_tabs)

	inventory_panel = INVENTORY_PANEL_SCENE.instantiate()
	inventory_panel.name = "背包"
	inventory_panel.component_database = component_database
	inventory_panel.game = self
	inventory_panel.item_selected.connect(_on_inventory_item_selected)
	inventory_panel.item_sold.connect(_on_inventory_item_sold)
	inventory_panel.filter_cleared.connect(_on_inventory_filter_cleared)
	main_tabs.add_child(inventory_panel)

	shop_panel = SHOP_PANEL_SCENE.instantiate()
	shop_panel.name = "商店"
	shop_panel.component_database = component_database
	shop_panel.game = self
	shop_panel.item_purchased.connect(_on_shop_item_selected)
	shop_panel.item_purchased_and_installed.connect(_on_shop_item_quick_install_selected)
	main_tabs.add_child(shop_panel)

	_build_catalog_workspace_panel(right_column)

	status_label = Label.new()
	status_label.text = "准备开始装机"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.max_lines_visible = 1
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.clip_text = true
	status_label.custom_minimum_size = Vector2(0, 24)
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.94))

	home_bottom_dock = PanelContainer.new()
	home_bottom_dock.name = "HomeBottomDock"
	home_bottom_dock.custom_minimum_size = Vector2(0, 174)
	home_bottom_dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home_bottom_dock.add_theme_stylebox_override("panel", _stylebox(Color(0.010, 0.018, 0.052, 0.96), Color(0.28, 0.58, 1.0, 0.86), 8))

	var dock_shell := VBoxContainer.new()
	dock_shell.add_theme_constant_override("separation", 6)
	home_bottom_dock.add_child(dock_shell)

	var dock_nav := HBoxContainer.new()
	dock_nav.add_theme_constant_override("separation", 6)
	dock_shell.add_child(dock_nav)

	home_workbench_tab_button = Button.new()
	home_workbench_tab_button.name = "HomeWorkbenchTabButton"
	home_workbench_tab_button.text = "装机台"
	home_workbench_tab_button.tooltip_text = "回到当前装机工作台"
	home_workbench_tab_button.custom_minimum_size = Vector2(126, 38)
	_style_home_dock_tab(home_workbench_tab_button, Color(0.32, 0.92, 0.92), true)
	home_workbench_tab_button.pressed.connect(_on_home_workbench_pressed)
	dock_nav.add_child(home_workbench_tab_button)

	home_order_desk_button = Button.new()
	home_order_desk_button.name = "HomeOrderDeskButton"
	home_order_desk_button.text = "订单大厅"
	home_order_desk_button.tooltip_text = "查看客户订单、奖励和交付要求"
	home_order_desk_button.custom_minimum_size = Vector2(126, 38)
	_style_home_dock_tab(home_order_desk_button, Color(1.0, 0.72, 0.28), false)
	home_order_desk_button.pressed.connect(open_order_desk)
	dock_nav.add_child(home_order_desk_button)

	home_system_center_button = Button.new()
	home_system_center_button.name = "HomeSystemCenterButton"
	home_system_center_button.text = "系统中心"
	home_system_center_button.tooltip_text = "打开模拟系统、驱动和跑分工具"
	home_system_center_button.custom_minimum_size = Vector2(126, 38)
	_style_home_dock_tab(home_system_center_button, Color(0.36, 1.0, 0.66), false)
	home_system_center_button.pressed.connect(open_system_center_overlay)
	dock_nav.add_child(home_system_center_button)

	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.custom_minimum_size = Vector2(180, 38)
	dock_nav.add_child(status_label)

	var context_row := HBoxContainer.new()
	context_row.add_theme_constant_override("separation", 8)
	context_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock_shell.add_child(context_row)

	var flow_context := _make_home_context_panel(context_row, "工作流", Color(0.32, 0.92, 0.92), 1.12, "workbench")
	var tutorial_row := HBoxContainer.new()
	tutorial_row.add_theme_constant_override("separation", 8)
	flow_context.add_child(tutorial_row)
	var tutorial_copy := VBoxContainer.new()
	tutorial_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tutorial_copy.add_theme_constant_override("separation", 2)
	tutorial_row.add_child(tutorial_copy)
	tutorial_progress_label = Label.new()
	tutorial_progress_label.add_theme_font_size_override("font_size", 12)
	tutorial_progress_label.add_theme_color_override("font_color", Color(0.32, 0.92, 0.92))
	tutorial_copy.add_child(tutorial_progress_label)
	tutorial_label = Label.new()
	tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_label.max_lines_visible = 1
	tutorial_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tutorial_label.clip_text = true
	tutorial_label.add_theme_font_size_override("font_size", 11)
	tutorial_label.add_theme_color_override("font_color", Color(0.84, 0.90, 0.98))
	tutorial_copy.add_child(tutorial_label)
	progression_label = Label.new()
	progression_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progression_label.max_lines_visible = 1
	progression_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	progression_label.clip_text = true
	progression_label.add_theme_font_size_override("font_size", 10)
	progression_label.add_theme_color_override("font_color", Color(0.68, 0.78, 0.9))
	tutorial_copy.add_child(progression_label)
	tutorial_action_button = Button.new()
	tutorial_action_button.name = "TutorialActionButton"
	tutorial_action_button.custom_minimum_size = Vector2(116, 34)
	_style_home_dock_button(tutorial_action_button, Color(0.32, 0.92, 0.92))
	tutorial_action_button.pressed.connect(_on_tutorial_action_pressed)
	tutorial_row.add_child(tutorial_action_button)

	var order_context := _make_home_context_panel(context_row, "订单状态", Color(1.0, 0.72, 0.28), 1.05, "orders")
	order_label = Label.new()
	order_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	order_label.max_lines_visible = 1
	order_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	order_label.clip_text = true
	order_label.add_theme_font_size_override("font_size", 12)
	order_context.add_child(order_label)
	var order_status_row := HBoxContainer.new()
	order_status_row.add_theme_constant_override("separation", 6)
	order_context.add_child(order_status_row)
	order_state_chip_label = _add_home_dock_chip(order_status_row, "暂无订单", Color(0.24, 0.78, 0.92))
	score_label = Label.new()
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.add_theme_font_size_override("font_size", 11)
	score_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.82))
	order_status_row.add_child(score_label)
	order_progress_bar = _add_home_dock_progress_bar(order_context, Color(1.0, 0.72, 0.28))

	var system_context := _make_home_context_panel(context_row, "系统状态", Color(0.36, 1.0, 0.66), 0.92, "system")
	os_label = Label.new()
	os_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	os_label.max_lines_visible = 1
	os_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	os_label.clip_text = true
	os_label.add_theme_font_size_override("font_size", 12)
	system_context.add_child(os_label)
	var system_status_row := HBoxContainer.new()
	system_status_row.add_theme_constant_override("separation", 6)
	system_context.add_child(system_status_row)
	os_state_chip_label = _add_home_dock_chip(system_status_row, "未开机", Color(0.36, 1.0, 0.66))
	os_progress_bar = _add_home_dock_progress_bar(system_context, Color(0.36, 1.0, 0.66))

	var action_context := _make_home_context_panel(context_row, "快捷操作", Color(0.66, 0.58, 0.94), 0.90, "check")
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 5)
	action_context.add_child(action_row)
	home_task_center_button = Button.new()
	home_task_center_button.name = "HomeTaskCenterButton"
	home_task_center_button.text = "任务"
	home_task_center_button.tooltip_text = "打开任务中心"
	home_task_center_button.custom_minimum_size = Vector2(0, 34)
	home_task_center_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_home_dock_button(home_task_center_button, Color(1.0, 0.72, 0.28))
	home_task_center_button.pressed.connect(open_task_center_overlay)
	action_row.add_child(home_task_center_button)
	home_deliver_order_button = Button.new()
	home_deliver_order_button.name = "HomeDeliverOrderButton"
	home_deliver_order_button.text = "交付"
	home_deliver_order_button.tooltip_text = "检查并交付当前订单"
	home_deliver_order_button.custom_minimum_size = Vector2(0, 34)
	home_deliver_order_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_home_dock_button(home_deliver_order_button, Color(1.0, 0.72, 0.28))
	home_deliver_order_button.pressed.connect(_on_deliver_pressed)
	action_row.add_child(home_deliver_order_button)
	home_system_monitor_button = Button.new()
	home_system_monitor_button.name = "HomeSystemMonitorButton"
	home_system_monitor_button.text = "监视"
	home_system_monitor_button.tooltip_text = "打开 Max Monitor"
	home_system_monitor_button.custom_minimum_size = Vector2(0, 34)
	home_system_monitor_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_home_dock_button(home_system_monitor_button, Color(0.24, 0.78, 0.92))
	home_system_monitor_button.pressed.connect(_on_open_monitor_pressed)
	action_row.add_child(home_system_monitor_button)

	var feedback_row := HBoxContainer.new()
	feedback_row.add_theme_constant_override("separation", 8)
	feedback_row.custom_minimum_size = Vector2(0, 42)
	dock_shell.add_child(feedback_row)
	_build_action_feedback_panel(feedback_row)
	_build_delivery_feedback_panel(feedback_row)

	order_panel = ORDER_PANEL_SCENE.instantiate()
	order_panel.component_database = component_database
	order_panel.order_selected.connect(_on_order_selected)
	order_panel.order_desk_requested.connect(open_order_desk)
	order_panel.visible = false
	order_panel.custom_minimum_size = Vector2.ZERO
	order_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock_shell.add_child(order_panel)

	root.add_child(home_bottom_dock)
	_wire_home_bottom_focus()
	_build_part_menu()
	_build_order_desk_ui()
	_build_task_center_ui()
	_build_system_center_ui()
	_build_catalog_overlay_ui()
	_build_cheat_ui()
	_build_monitor_ui()
	_build_pause_ui()
	_build_feedback_audio()

func _build_catalog_workspace_panel(parent: Container) -> void:
	catalog_workspace_panel = PanelContainer.new()
	catalog_workspace_panel.name = "CatalogWorkspacePanel"
	catalog_workspace_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_workspace_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog_workspace_panel.add_theme_stylebox_override("panel", _stylebox(Color(0.012, 0.022, 0.060, 0.96), Color(0.24, 0.78, 0.92, 0.84), 8))
	parent.add_child(catalog_workspace_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	catalog_workspace_panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	var title := Label.new()
	title.text = "配件工作区"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.80, 0.98, 1.0))
	title_box.add_child(title)

	catalog_workspace_summary_label = Label.new()
	catalog_workspace_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	catalog_workspace_summary_label.max_lines_visible = 2
	catalog_workspace_summary_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	catalog_workspace_summary_label.add_theme_font_size_override("font_size", 13)
	catalog_workspace_summary_label.add_theme_color_override("font_color", Color(0.74, 0.84, 0.96))
	title_box.add_child(catalog_workspace_summary_label)

	var chip_column := VBoxContainer.new()
	chip_column.custom_minimum_size = Vector2(188, 0)
	chip_column.add_theme_constant_override("separation", 6)
	header.add_child(chip_column)

	catalog_workspace_slot_chip_label = _add_home_dock_chip(chip_column, "槽位：全部", Color(0.24, 0.78, 0.92))
	catalog_workspace_order_chip_label = _add_home_dock_chip(chip_column, "订单筛选", Color(1.0, 0.72, 0.28))

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	box.add_child(action_row)

	catalog_workspace_shop_button = Button.new()
	catalog_workspace_shop_button.name = "CatalogWorkspaceShopButton"
	catalog_workspace_shop_button.text = "打开配件市场"
	catalog_workspace_shop_button.custom_minimum_size = Vector2(0, 56)
	catalog_workspace_shop_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_catalog_entry_button(catalog_workspace_shop_button, Color(0.24, 0.78, 0.92))
	catalog_workspace_shop_button.pressed.connect(open_shop_overlay)
	action_row.add_child(catalog_workspace_shop_button)

	catalog_workspace_inventory_button = Button.new()
	catalog_workspace_inventory_button.name = "CatalogWorkspaceInventoryButton"
	catalog_workspace_inventory_button.text = "打开仓库"
	catalog_workspace_inventory_button.custom_minimum_size = Vector2(0, 56)
	catalog_workspace_inventory_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_catalog_entry_button(catalog_workspace_inventory_button, Color(0.36, 1.0, 0.66))
	catalog_workspace_inventory_button.pressed.connect(open_inventory_overlay)
	action_row.add_child(catalog_workspace_inventory_button)

	var info_panel := PanelContainer.new()
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_panel.add_theme_stylebox_override("panel", _catalog_stylebox(Color(0.018, 0.026, 0.070, 0.92), Color(0.34, 0.23, 0.78, 0.78), 8, 10))
	box.add_child(info_panel)

	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 8)
	info_panel.add_child(info_box)

	var flow_title := Label.new()
	flow_title.text = "选件流程"
	flow_title.add_theme_font_size_override("font_size", 18)
	flow_title.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
	info_box.add_child(flow_title)

	var flow_text := Label.new()
	flow_text.text = "1. 在左侧选择槽位\n2. 打开配件市场购买或购买并安装\n3. 打开仓库安装已有配件\n4. 回到工作台完成检测、开机和 OS 配置"
	flow_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flow_text.add_theme_font_size_override("font_size", 15)
	flow_text.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0))
	info_box.add_child(flow_text)

	var decision_row := HBoxContainer.new()
	decision_row.name = "CatalogWorkspaceDecisionRow"
	decision_row.add_theme_constant_override("separation", 8)
	info_box.add_child(decision_row)

	catalog_workspace_state_label = Label.new()
	catalog_workspace_state_label.name = "CatalogWorkspaceStateLabel"
	catalog_workspace_state_label.custom_minimum_size = Vector2(0, 30)
	catalog_workspace_state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_workspace_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	catalog_workspace_state_label.clip_text = true
	catalog_workspace_state_label.max_lines_visible = 1
	catalog_workspace_state_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	catalog_workspace_state_label.add_theme_font_size_override("font_size", 13)
	catalog_workspace_state_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	decision_row.add_child(catalog_workspace_state_label)

	catalog_workspace_pressure_chip_label = _add_home_dock_chip(decision_row, "订单压力：待评估", Color(1.0, 0.72, 0.28))
	catalog_workspace_pressure_chip_label.get_parent().custom_minimum_size = Vector2(180, 30)

	catalog_workspace_next_action_label = Label.new()
	catalog_workspace_next_action_label.name = "CatalogWorkspaceNextActionLabel"
	catalog_workspace_next_action_label.custom_minimum_size = Vector2(0, 22)
	catalog_workspace_next_action_label.clip_text = true
	catalog_workspace_next_action_label.max_lines_visible = 1
	catalog_workspace_next_action_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	catalog_workspace_next_action_label.add_theme_font_size_override("font_size", 13)
	catalog_workspace_next_action_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	info_box.add_child(catalog_workspace_next_action_label)

	catalog_workspace_inventory_chip_label = _add_home_dock_chip(info_box, "仓库 0 件", Color(0.36, 1.0, 0.66))

func _make_home_dock_card(parent: Container, title_text: String, accent: Color, ratio: float, icon_key: String = "") -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "%sCard" % title_text
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	panel.add_theme_stylebox_override("panel", _stylebox(Color(accent.r * 0.055, accent.g * 0.055, accent.b * 0.055, 0.94), Color(accent.r, accent.g, accent.b, 0.78), 8))
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	box.add_child(title_row)
	if icon_key != "":
		title_row.add_child(_make_ui_icon(icon_key, Vector2(22, 22), accent))

	var title := Label.new()
	title.text = title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.max_lines_visible = 1
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 1.0))
	title_row.add_child(title)
	return box

func _make_home_context_panel(parent: Container, title_text: String, accent: Color, ratio: float, icon_key: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "%sContextPanel" % title_text
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	panel.add_theme_stylebox_override("panel", _stylebox(Color(accent.r * 0.055, accent.g * 0.055, accent.b * 0.055, 0.94), Color(accent.r, accent.g, accent.b, 0.78), 7))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 5)
	box.add_child(title_row)
	title_row.add_child(_make_ui_icon(icon_key, Vector2(18, 18), accent))
	var title := Label.new()
	title.text = title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", accent)
	title_row.add_child(title)
	return box

func _make_ui_icon(icon_key: String, size: Vector2, tint: Color = Color.WHITE) -> TextureRect:
	var icon := TextureRect.new()
	var texture = UI_ICON_TEXTURES.get(icon_key, null)
	if texture is Texture2D:
		icon.texture = texture
	icon.custom_minimum_size = size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = tint
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _make_ui_art(art_key: String, size: Vector2) -> TextureRect:
	var art := TextureRect.new()
	var texture = UI_ART_TEXTURES.get(art_key, null)
	if texture is Texture2D:
		art.texture = texture
	art.custom_minimum_size = size
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art

func _add_home_dock_chip(parent: Container, text: String, accent: Color) -> Label:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 30)
	panel.add_theme_stylebox_override("panel", _catalog_stylebox(Color(accent.r * 0.10, accent.g * 0.10, accent.b * 0.10, 0.92), accent, 8, 6))
	parent.add_child(panel)

	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.max_lines_visible = 1
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	panel.add_child(label)
	return label

func _add_compact_footer_chip(parent: Container, text: String, accent: Color) -> Label:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 22)
	panel.add_theme_stylebox_override("panel", _catalog_stylebox(Color(accent.r * 0.10, accent.g * 0.10, accent.b * 0.10, 0.92), accent, 6, 2))
	parent.add_child(panel)

	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.max_lines_visible = 1
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	panel.add_child(label)
	return label

func _add_home_dock_progress_bar(parent: Container, accent: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _catalog_stylebox(Color(0.018, 0.024, 0.050, 0.94), Color(accent.r * 0.58, accent.g * 0.58, accent.b * 0.58, 0.92), 6, 2))
	bar.add_theme_stylebox_override("fill", _catalog_stylebox(Color(accent.r * 0.34, accent.g * 0.34, accent.b * 0.34, 0.96), accent, 6, 2))
	parent.add_child(bar)
	return bar

func _wire_home_bottom_focus() -> void:
	var controls: Array[Button] = [
		home_workbench_tab_button,
		home_task_center_button,
		home_order_desk_button,
		home_deliver_order_button,
		home_system_center_button,
		home_system_monitor_button,
	]
	var valid_controls: Array[Button] = []
	for control in controls:
		if control != null:
			control.focus_mode = Control.FOCUS_ALL
			valid_controls.append(control)
	for index in range(valid_controls.size()):
		var control := valid_controls[index]
		var previous := valid_controls[maxi(0, index - 1)]
		var next := valid_controls[mini(valid_controls.size() - 1, index + 1)]
		control.focus_neighbor_left = previous.get_path()
		control.focus_neighbor_right = next.get_path()

func _set_home_tab(tab_key: String) -> void:
	if home_workbench_tab_button:
		_style_home_dock_tab(home_workbench_tab_button, Color(0.32, 0.92, 0.92), tab_key == "workbench")
	if home_order_desk_button:
		_style_home_dock_tab(home_order_desk_button, Color(1.0, 0.72, 0.28), tab_key == "orders")
	if home_system_center_button:
		_style_home_dock_tab(home_system_center_button, Color(0.36, 1.0, 0.66), tab_key == "system")

func _on_home_workbench_pressed() -> void:
	_close_order_desk()
	_close_task_center()
	_close_system_center()
	_close_catalog_overlay()
	if monitor_overlay:
		monitor_overlay.visible = false
	_set_home_tab("workbench")

func _build_order_desk_ui() -> void:
	order_desk_overlay = ColorRect.new()
	order_desk_overlay.name = "OrderDeskOverlay"
	order_desk_overlay.visible = false
	order_desk_overlay.color = Color(0.012, 0.018, 0.038, 1.0)
	order_desk_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	order_desk_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	order_desk_overlay.z_index = 32
	add_child(order_desk_overlay)

	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 28)
	frame.add_theme_constant_override("margin_top", 20)
	frame.add_theme_constant_override("margin_right", 28)
	frame.add_theme_constant_override("margin_bottom", 20)
	order_desk_overlay.add_child(frame)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 12)
	frame.add_child(shell)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	shell.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	var eyebrow := Label.new()
	eyebrow.text = "WORKSHOP DISPATCH / 桌面工单调度"
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", Color(0.26, 0.95, 0.98))
	title_box.add_child(eyebrow)

	var title := Label.new()
	title.text = "订单大厅"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	title_box.add_child(title)

	order_desk_progress_label = Label.new()
	order_desk_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	order_desk_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	order_desk_progress_label.custom_minimum_size = Vector2(170, 48)
	order_desk_progress_label.add_theme_font_size_override("font_size", 15)
	order_desk_progress_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.96))
	header.add_child(order_desk_progress_label)

	var close_button := Button.new()
	close_button.name = "CloseOrderDeskButton"
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(90, 42)
	_style_order_desk_button(close_button, Color(0.24, 0.78, 0.92), false)
	close_button.pressed.connect(_close_order_desk)
	header.add_child(close_button)

	var rail := ColorRect.new()
	rail.custom_minimum_size = Vector2(0, 3)
	rail.color = Color(0.22, 0.84, 0.92, 0.78)
	shell.add_child(rail)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	shell.add_child(body)

	var queue_panel := PanelContainer.new()
	queue_panel.custom_minimum_size = Vector2(320, 0)
	queue_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	queue_panel.add_theme_stylebox_override("panel", _stylebox(Color(0.024, 0.033, 0.080, 0.98), Color(0.20, 0.80, 0.92), 8))
	body.add_child(queue_panel)

	var queue_box := VBoxContainer.new()
	queue_box.add_theme_constant_override("separation", 10)
	queue_panel.add_child(queue_box)

	var queue_title := Label.new()
	queue_title.text = "工单队列"
	queue_title.add_theme_font_size_override("font_size", 21)
	queue_title.add_theme_color_override("font_color", Color(0.84, 0.96, 1.0))
	queue_box.add_child(queue_title)

	var queue_subtitle := Label.new()
	queue_subtitle.text = "按订单难度、奖励和当前状态选择下一台电脑。"
	queue_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	queue_subtitle.add_theme_font_size_override("font_size", 12)
	queue_subtitle.add_theme_color_override("font_color", Color(0.58, 0.68, 0.78))
	queue_box.add_child(queue_subtitle)

	order_desk_list = ItemList.new()
	order_desk_list.name = "OrderDeskList"
	order_desk_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	order_desk_list.select_mode = ItemList.SELECT_SINGLE
	order_desk_list.fixed_icon_size = Vector2i(38, 38)
	order_desk_list.add_theme_font_size_override("font_size", 15)
	order_desk_list.add_theme_color_override("font_color", Color(0.88, 0.93, 0.98))
	order_desk_list.add_theme_color_override("font_selected_color", Color(0.03, 0.06, 0.08))
	order_desk_list.item_selected.connect(_on_order_desk_item_selected)
	order_desk_list.item_activated.connect(_on_order_desk_item_activated)
	queue_box.add_child(order_desk_list)

	var queue_hint := Label.new()
	queue_hint.text = "双击可接单。绿色为当前工单，琥珀色为高难订单。"
	queue_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	queue_hint.add_theme_font_size_override("font_size", 12)
	queue_hint.add_theme_color_override("font_color", Color(0.58, 0.68, 0.78))
	queue_box.add_child(queue_hint)

	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_stretch_ratio = 1.35
	detail_panel.add_theme_stylebox_override("panel", _stylebox(Color(0.034, 0.038, 0.075, 0.98), Color(0.86, 0.64, 0.22), 8))
	body.add_child(detail_panel)

	var detail_shell := VBoxContainer.new()
	detail_shell.add_theme_constant_override("separation", 12)
	detail_panel.add_child(detail_shell)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_shell.add_child(detail_scroll)

	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 12)
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(detail_box)

	var identity_row := HBoxContainer.new()
	identity_row.add_theme_constant_override("separation", 12)
	detail_box.add_child(identity_row)
	order_desk_customer_art = _make_ui_art("customer_office", Vector2(72, 72))
	identity_row.add_child(order_desk_customer_art)
	var identity_copy := VBoxContainer.new()
	identity_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_copy.add_theme_constant_override("separation", 4)
	identity_row.add_child(identity_copy)
	order_desk_title_label = Label.new()
	order_desk_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	order_desk_title_label.add_theme_font_size_override("font_size", 28)
	order_desk_title_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
	identity_copy.add_child(order_desk_title_label)
	order_desk_meta_label = Label.new()
	order_desk_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	order_desk_meta_label.add_theme_font_size_override("font_size", 14)
	order_desk_meta_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96))
	identity_copy.add_child(order_desk_meta_label)
	order_desk_customer_label = Label.new()
	order_desk_customer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	order_desk_customer_label.add_theme_font_size_override("font_size", 14)
	order_desk_customer_label.add_theme_color_override("font_color", Color(0.66, 0.94, 0.92))
	identity_copy.add_child(order_desk_customer_label)

	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 8)
	detail_box.add_child(chip_row)
	order_desk_status_label = _add_order_desk_chip(chip_row, "状态 -", Color(0.38, 1.0, 0.64))
	order_desk_difficulty_label = _add_order_desk_chip(chip_row, "难度 -", Color(0.24, 0.78, 0.92))
	order_desk_reward_label = _add_order_desk_chip(chip_row, "奖励 -", Color(1.0, 0.72, 0.28))
	order_desk_time_label = _add_order_desk_chip(chip_row, "预计 -", Color(0.66, 0.58, 0.94))

	var readiness_row := HBoxContainer.new()
	readiness_row.name = "OrderDeskReadinessRow"
	readiness_row.add_theme_constant_override("separation", 10)
	detail_box.add_child(readiness_row)
	order_desk_hardware_ready_label = _add_order_desk_readiness_card(readiness_row, "硬件准备", Color(0.24, 0.78, 0.92))
	order_desk_software_ready_label = _add_order_desk_readiness_card(readiness_row, "软件准备", Color(0.36, 1.0, 0.66))
	order_desk_delivery_ready_label = _add_order_desk_readiness_card(readiness_row, "交付状态", Color(1.0, 0.72, 0.28))

	detail_box.add_child(_make_order_desk_section_title("硬件要求", Color(0.95, 0.74, 0.32)))

	order_desk_requirements_label = Label.new()
	order_desk_requirements_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	order_desk_requirements_label.add_theme_font_size_override("font_size", 17)
	order_desk_requirements_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	detail_box.add_child(order_desk_requirements_label)

	detail_box.add_child(_make_order_desk_section_title("软件配置", Color(0.44, 0.96, 0.72)))

	var software_row := HBoxContainer.new()
	software_row.add_theme_constant_override("separation", 8)
	detail_box.add_child(software_row)
	order_desk_software_art = _make_ui_art("app_driver", Vector2(42, 42))
	software_row.add_child(order_desk_software_art)
	order_desk_software_label = Label.new()
	order_desk_software_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	order_desk_software_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	order_desk_software_label.add_theme_font_size_override("font_size", 17)
	order_desk_software_label.add_theme_color_override("font_color", Color(0.9, 0.96, 0.94))
	software_row.add_child(order_desk_software_label)

	order_desk_action_hint_label = Label.new()
	order_desk_action_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	order_desk_action_hint_label.add_theme_font_size_override("font_size", 13)
	order_desk_action_hint_label.add_theme_color_override("font_color", Color(0.65, 0.74, 0.86))
	detail_box.add_child(order_desk_action_hint_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	detail_shell.add_child(actions)

	var secondary_close := Button.new()
	secondary_close.text = "关闭大厅"
	secondary_close.custom_minimum_size = Vector2(132, 42)
	_style_order_desk_button(secondary_close, Color(0.24, 0.78, 0.92), false)
	secondary_close.pressed.connect(_close_order_desk)
	actions.add_child(secondary_close)

	order_desk_accept_button = Button.new()
	order_desk_accept_button.name = "OrderDeskAcceptButton"
	order_desk_accept_button.text = "接取这张订单"
	order_desk_accept_button.custom_minimum_size = Vector2(180, 42)
	order_desk_accept_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_order_desk_button(order_desk_accept_button, Color(1.0, 0.72, 0.28), true)
	order_desk_accept_button.pressed.connect(_on_order_desk_accept_pressed)
	actions.add_child(order_desk_accept_button)

	order_desk_deliver_button = Button.new()
	order_desk_deliver_button.name = "OrderDeskDeliverButton"
	order_desk_deliver_button.text = "交付订单"
	order_desk_deliver_button.custom_minimum_size = Vector2(150, 42)
	order_desk_deliver_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_order_desk_button(order_desk_deliver_button, Color(0.36, 1.0, 0.66), true)
	order_desk_deliver_button.pressed.connect(_on_order_desk_deliver_pressed)
	actions.add_child(order_desk_deliver_button)

	var assessment_panel := PanelContainer.new()
	assessment_panel.name = "OrderDeskAssessmentPanel"
	assessment_panel.custom_minimum_size = Vector2(300, 0)
	assessment_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	assessment_panel.add_theme_stylebox_override("panel", _stylebox(Color(0.026, 0.018, 0.044, 0.98), Color(0.95, 0.56, 1.0), 8))
	body.add_child(assessment_panel)

	var assessment_box := VBoxContainer.new()
	assessment_box.add_theme_constant_override("separation", 7)
	assessment_panel.add_child(assessment_box)

	var assessment_header := HBoxContainer.new()
	assessment_header.add_theme_constant_override("separation", 8)
	assessment_box.add_child(assessment_header)
	var assessment_title := Label.new()
	assessment_title.text = "派工评估"
	assessment_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	assessment_title.add_theme_font_size_override("font_size", 21)
	assessment_title.add_theme_color_override("font_color", Color(1.0, 0.80, 1.0))
	assessment_header.add_child(assessment_title)
	order_desk_grade_art = _make_ui_art("badge_bronze", Vector2(48, 48))
	assessment_header.add_child(order_desk_grade_art)

	var assessment_subtitle := Label.new()
	assessment_subtitle.text = "接单前先看范围、收益、风险和交付影响。"
	assessment_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	assessment_subtitle.add_theme_font_size_override("font_size", 12)
	assessment_subtitle.add_theme_color_override("font_color", Color(0.70, 0.74, 0.86))
	assessment_box.add_child(assessment_subtitle)

	order_desk_scope_label = _add_order_desk_assessment_card(assessment_box, "装机范围", Color(0.24, 0.78, 0.92), 60)
	order_desk_income_label = _add_order_desk_assessment_card(assessment_box, "收益预估", Color(1.0, 0.72, 0.28), 60)
	order_desk_risk_label = _add_order_desk_assessment_card(assessment_box, "风险提示", Color(0.95, 0.56, 1.0), 64)
	order_desk_score_label = _add_order_desk_assessment_card(assessment_box, "交付评分", Color(0.36, 1.0, 0.66), 68)
	order_desk_unlock_label = _add_order_desk_assessment_card(assessment_box, "解锁节奏", Color(0.66, 0.58, 0.94), 56)

	var assessment_spacer := Control.new()
	assessment_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	assessment_box.add_child(assessment_spacer)

	order_desk_task_button = Button.new()
	order_desk_task_button.name = "OrderDeskTaskCenterButton"
	order_desk_task_button.text = "打开任务中心"
	order_desk_task_button.custom_minimum_size = Vector2(0, 34)
	order_desk_task_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_order_desk_button(order_desk_task_button, Color(0.36, 1.0, 0.66), false)
	order_desk_task_button.pressed.connect(_on_order_desk_task_center_pressed)
	assessment_box.add_child(order_desk_task_button)

	order_desk_market_button = Button.new()
	order_desk_market_button.name = "OrderDeskMarketButton"
	order_desk_market_button.text = "打开配件市场"
	order_desk_market_button.custom_minimum_size = Vector2(0, 34)
	order_desk_market_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_order_desk_button(order_desk_market_button, Color(1.0, 0.72, 0.28), true)
	order_desk_market_button.pressed.connect(_on_order_desk_market_pressed)
	assessment_box.add_child(order_desk_market_button)

	_wire_order_desk_focus()

func open_order_desk() -> void:
	if order_desk_overlay == null:
		return
	_close_task_center()
	_close_system_center()
	_close_catalog_overlay()
	order_desk_overlay.visible = true
	order_desk_overlay.move_to_front()
	_set_home_tab("orders")
	_refresh_order_desk()
	var preferred: int = current_order_index if available_order_indices.has(current_order_index) else _first_available_order_index(available_order_indices)
	_select_order_desk_order(preferred)
	order_desk_list.grab_focus()

func _close_order_desk() -> void:
	if order_desk_overlay:
		order_desk_overlay.visible = false
	_set_home_tab("workbench")

func _refresh_order_desk() -> void:
	if order_desk_list == null:
		return
	order_desk_list.clear()
	var completed: int = completed_order_ids.size()
	order_desk_progress_label.text = "已完成 %d / %d\n可接 %d" % [completed, order_defs.size(), available_order_indices.size()]
	for order_index in available_order_indices:
		if order_index < 0 or order_index >= order_defs.size():
			continue
		var order: Dictionary = order_defs[order_index]
		var state: String = "进行中" if order_index == current_order_index else "待接"
		var label: String = "%s  D%d  ￥%d  %s  /  %s" % [
			state,
			int(order.get("difficulty", 1)),
			int(order.get("reward", 0)),
			str(order.get("name", "订单")),
			str(order.get("customer_type", "客户")),
		]
		var order_icon = UI_ART_TEXTURES.get(_order_customer_art_key(order), null)
		var item_index: int = order_desk_list.add_item(label, order_icon if order_icon is Texture2D else null)
		order_desk_list.set_item_metadata(item_index, order_index)
		if order_index == current_order_index:
			order_desk_list.set_item_custom_fg_color(item_index, Color(0.38, 1.0, 0.64))
		elif int(order.get("difficulty", 1)) >= 4:
			order_desk_list.set_item_custom_fg_color(item_index, Color(1.0, 0.78, 0.34))
	if order_desk_selected_index >= 0:
		_select_order_desk_order(order_desk_selected_index)
	else:
		_select_order_desk_order(_first_available_order_index(available_order_indices))

func _on_order_desk_item_selected(list_index: int) -> void:
	_select_order_desk_order(int(order_desk_list.get_item_metadata(list_index)))

func _on_order_desk_item_activated(list_index: int) -> void:
	_select_order_desk_order(int(order_desk_list.get_item_metadata(list_index)))
	_on_order_desk_accept_pressed()

func _select_order_desk_order(order_index: int) -> void:
	order_desk_selected_index = order_index
	if order_desk_list:
		for list_index in range(order_desk_list.get_item_count()):
			if int(order_desk_list.get_item_metadata(list_index)) == order_index:
				order_desk_list.select(list_index)
				break
	var order: Dictionary = get_current_order() if order_index == current_order_index else _order_by_index(order_index)
	if order.is_empty():
		order_desk_title_label.text = "暂无可接订单"
		order_desk_meta_label.text = "首发订单已全部完成。"
		order_desk_customer_label.text = "返回工作台继续优化装机体验。"
		order_desk_customer_art.texture = UI_ART_TEXTURES.get("customer_office", null)
		order_desk_grade_art.texture = UI_ART_TEXTURES.get("badge_bronze", null)
		order_desk_software_art.texture = UI_ART_TEXTURES.get("app_files", null)
		order_desk_hardware_ready_label.text = "没有新的硬件需求"
		order_desk_software_ready_label.text = "没有新的软件任务"
		order_desk_delivery_ready_label.text = "等待下一批客户"
		order_desk_requirements_label.text = "-"
		order_desk_software_label.text = "-"
		order_desk_status_label.text = "状态 -"
		order_desk_difficulty_label.text = "难度 -"
		order_desk_reward_label.text = "奖励 -"
		order_desk_time_label.text = "预计 -"
		order_desk_scope_label.text = "没有新的客户需求"
		order_desk_income_label.text = "等待下一批订单"
		order_desk_risk_label.text = "无风险"
		order_desk_score_label.text = "暂无评分"
		order_desk_unlock_label.text = "首发订单已完成"
		order_desk_action_hint_label.text = "当前没有新的工单。"
		order_desk_accept_button.text = "接取这张订单"
		order_desk_accept_button.disabled = true
		order_desk_deliver_button.disabled = true
		order_desk_market_button.disabled = true
		order_desk_task_button.disabled = false
		return
	order_desk_title_label.text = str(order.get("name", "订单"))
	var is_current_order: bool = order_index == current_order_index
	var is_available: bool = available_order_indices.has(order_index)
	order_desk_status_label.text = "状态 %s" % ("进行中" if is_current_order else ("可接" if is_available else "未解锁"))
	order_desk_difficulty_label.text = "难度 D%d" % int(order.get("difficulty", 1))
	order_desk_reward_label.text = "奖励 ￥%d" % int(order.get("reward", 0))
	order_desk_time_label.text = "预计 %d 分钟" % int(order.get("estimated_minutes", 5))
	order_desk_meta_label.text = "客户类型：%s" % str(order.get("customer_type", "客户"))
	order_desk_customer_label.text = "客户：%s" % str(order.get("customer", "客户"))
	order_desk_customer_art.texture = UI_ART_TEXTURES.get(_order_customer_art_key(order), null)
	order_desk_grade_art.texture = UI_ART_TEXTURES.get(_order_grade_art_key(order), null)
	order_desk_hardware_ready_label.text = _order_desk_hardware_readiness_text(order, is_current_order)
	order_desk_software_ready_label.text = _order_desk_software_readiness_text(order, is_current_order)
	order_desk_delivery_ready_label.text = _order_desk_delivery_readiness_text(order, is_current_order)
	order_desk_requirements_label.text = _format_order_requirements_multiline(order)
	order_desk_software_label.text = _format_software_tasks(order)
	order_desk_software_art.texture = UI_ART_TEXTURES.get(_order_software_art_key(order), null)
	order_desk_scope_label.text = _order_desk_scope_text(order)
	order_desk_income_label.text = _order_desk_income_text(order)
	order_desk_risk_label.text = _order_desk_risk_text(order, is_available)
	order_desk_score_label.text = _order_desk_score_text(order, is_current_order)
	order_desk_unlock_label.text = _order_desk_unlock_text(order, order_index)
	order_desk_market_button.disabled = not is_available
	order_desk_task_button.disabled = false
	order_desk_deliver_button.disabled = not is_current_order
	if is_current_order:
		order_desk_accept_button.text = "返回工作台继续装机"
		order_desk_accept_button.disabled = false
		order_desk_action_hint_label.text = "这张工单正在进行；回到工作台后按硬件要求装配，再进入模拟系统完成软件配置。"
	elif is_available:
		order_desk_accept_button.text = "接取这张订单"
		order_desk_accept_button.disabled = false
		order_desk_action_hint_label.text = "接单会把当前工作台目标切换到这张订单。"
	else:
		order_desk_accept_button.text = "暂未解锁"
		order_desk_accept_button.disabled = true
		order_desk_deliver_button.disabled = true
		order_desk_action_hint_label.text = "继续完成当前工单以解锁这类客户。"

func _order_customer_art_key(order: Dictionary) -> String:
	var customer_type := str(order.get("customer_type", ""))
	if customer_type.contains("创作者") or customer_type.contains("主播"):
		return "customer_creator"
	if customer_type.contains("电竞") or customer_type.contains("玩家"):
		return "customer_gamer"
	return "customer_office"

func _order_grade_art_key(order: Dictionary) -> String:
	var difficulty := int(order.get("difficulty", 1))
	if difficulty >= 5:
		return "badge_gold"
	if difficulty >= 3:
		return "badge_silver"
	return "badge_bronze"

func _order_software_art_key(order: Dictionary) -> String:
	var tasks: Array = order.get("software_tasks", [])
	if tasks.has("benchmark"):
		return "app_benchmark"
	if tasks.has("gpu_driver"):
		return "app_gpu"
	if tasks.has("drivers"):
		return "app_driver"
	return "app_files"

func _on_order_desk_accept_pressed() -> void:
	if order_desk_selected_index < 0:
		return
	if order_desk_selected_index == current_order_index:
		_close_order_desk()
		return
	if _select_order_from_ui(order_desk_selected_index):
		_close_order_desk()
	else:
		_refresh_order_desk()

func _order_by_index(order_index: int) -> Dictionary:
	if order_index < 0 or order_index >= order_defs.size():
		return {}
	return order_defs[order_index]

func _on_order_desk_task_center_pressed() -> void:
	_close_order_desk()
	open_task_center_overlay()

func _on_order_desk_market_pressed() -> void:
	_close_order_desk()
	open_shop_overlay()

func _on_order_desk_deliver_pressed() -> void:
	_on_deliver_pressed()
	if order_desk_overlay != null and order_desk_overlay.visible:
		_refresh_order_desk()

func _order_desk_hardware_readiness_text(order: Dictionary, is_current_order: bool) -> String:
	var requirements: Dictionary = order.get("requirements", {})
	if requirements.is_empty():
		return "硬件需求 0 项\n接单后无需额外硬件"
	var matched := 0
	var blocked: Array[String] = []
	for slot in requirements.keys():
		var slot_key := str(slot)
		var required_tier := int(requirements[slot])
		if installed.has(slot_key) and int(installed[slot_key].tier) >= required_tier:
			matched += 1
		elif is_current_order:
			var label: String = component_database.display_type(slot_key) if component_database else slot_key
			blocked.append(label)
	var percent := int(round(float(matched) / float(requirements.size()) * 100.0))
	if not is_current_order:
		return "需求 %d 项 / 最高 Lv.%d\n接单后按槽位采购" % [
			requirements.size(),
			_order_requirement_max_level(order),
		]
	if blocked.is_empty():
		return "硬件 %d%% / %d/%d 项\n硬件已满足订单" % [percent, matched, requirements.size()]
	return "硬件 %d%% / %d/%d 项\n待补：%s" % [
		percent,
		matched,
		requirements.size(),
		"、".join(blocked.slice(0, 3)),
	]

func _order_desk_software_readiness_text(order: Dictionary, is_current_order: bool) -> String:
	var tasks := _software_tasks(order)
	if tasks.is_empty():
		return "软件任务 0 项\n无需 OS 配置"
	if not is_current_order:
		return "软件任务 %d 项\n%s" % [tasks.size(), _format_software_tasks(order)]
	var complete := 0
	var pending: Array[String] = []
	for task in tasks:
		if _is_software_task_complete(task):
			complete += 1
		else:
			pending.append(_software_task_label(task))
	return "软件 %d/100 / %d/%d 项\n%s" % [
		get_software_configuration_score(),
		complete,
		tasks.size(),
		"全部完成" if pending.is_empty() else "待处理：%s" % "、".join(pending.slice(0, 2)),
	]

func _order_desk_delivery_readiness_text(order: Dictionary, is_current_order: bool) -> String:
	if not is_current_order:
		return "奖励 ￥%d / 预计 %d 分钟\n接单后生成交付检查" % [
			int(order.get("reward", 0)),
			int(order.get("estimated_minutes", 5)),
		]
	var reasons := validate_current_order()
	var score := calculate_delivery_score()
	if reasons.is_empty():
		return "可交付 / 预估 %s / %d分\n软件配置计入评价" % [
			str(score.get("grade", "-")),
			int(score.get("score", 0)),
		]
	return "待处理 %d 项 / 预估 %s / %d分\n%s" % [
		reasons.size(),
		str(score.get("grade", "-")),
		int(score.get("score", 0)),
		_summarize_delivery_reasons(reasons),
	]

func _order_desk_scope_text(order: Dictionary) -> String:
	var requirements: Dictionary = order.get("requirements", {})
	var task_count: int = _software_tasks(order).size()
	return "槽位 %d 项 / 最高 Lv.%d\n软件任务 %d 项" % [
		requirements.size(),
		_order_requirement_max_level(order),
		task_count,
	]

func _order_desk_income_text(order: Dictionary) -> String:
	var minutes: int = max(1, int(order.get("estimated_minutes", 5)))
	var reward: int = int(order.get("reward", 0))
	return "奖励 ￥%d / 预计 %d 分钟\n效率 ￥%d / 分钟" % [
		reward,
		minutes,
		int(round(float(reward) / float(minutes))),
	]

func _order_desk_risk_text(order: Dictionary, is_available: bool) -> String:
	if not is_available:
		return "未解锁\n先完成前置订单"
	var difficulty: int = int(order.get("difficulty", 1))
	var requirements: Dictionary = order.get("requirements", {})
	var software_count: int = _software_tasks(order).size()
	var risk := "低"
	if difficulty >= 4 or software_count >= 3:
		risk = "高"
	elif difficulty >= 2 or requirements.size() >= 8:
		risk = "中"
	return "%s风险 / 难度 D%d\n%s" % [
		risk,
		difficulty,
		"需要完整软硬件闭环" if software_count >= 2 else "基础交付节奏",
	]

func _order_desk_score_text(order: Dictionary, is_current_order: bool) -> String:
	if is_current_order:
		var score := calculate_delivery_score()
		return "当前预估 %d / %s / 软件 %d\n交付会计入订单评价" % [
			int(score.get("score", 0)),
			str(score.get("grade", "-")),
			int(score.get("software", 0)),
		]
	return "接单后按软硬件评分\n任务：%s" % _format_software_tasks(order)

func _order_desk_unlock_text(order: Dictionary, order_index: int) -> String:
	if available_order_indices.has(order_index):
		return "已解锁 / 可立即接单"
	var unlock_after: int = int(order.get("unlock_after", 0))
	var remaining: int = max(0, unlock_after - completed_order_ids.size())
	return "完成 %d 单后解锁\n还差 %d 单" % [unlock_after, remaining]

func _order_requirement_max_level(order: Dictionary) -> int:
	var max_level := 0
	var requirements: Dictionary = order.get("requirements", {})
	for slot in requirements.keys():
		max_level = maxi(max_level, int(requirements[slot]))
	return max_level

func _build_task_center_ui() -> void:
	task_center_overlay = ColorRect.new()
	task_center_overlay.name = "TaskCenterOverlay"
	task_center_overlay.visible = false
	task_center_overlay.color = Color(0.006, 0.010, 0.022, 1.0)
	task_center_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	task_center_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	task_center_overlay.z_index = 33
	add_child(task_center_overlay)

	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 24)
	frame.add_theme_constant_override("margin_top", 20)
	frame.add_theme_constant_override("margin_right", 24)
	frame.add_theme_constant_override("margin_bottom", 20)
	task_center_overlay.add_child(frame)

	var shell_panel := PanelContainer.new()
	shell_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell_panel.add_theme_stylebox_override("panel", _catalog_stylebox(Color(0.014, 0.020, 0.045, 0.98), Color(1.0, 0.72, 0.28), 8, 12))
	frame.add_child(shell_panel)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 10)
	shell_panel.add_child(shell)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	shell.add_child(header)

	var title := Label.new()
	title.text = "任务中心"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
	header.add_child(title)

	task_center_status_label = Label.new()
	task_center_status_label.custom_minimum_size = Vector2(520, 48)
	task_center_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	task_center_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	task_center_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task_center_status_label.max_lines_visible = 2
	task_center_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	task_center_status_label.add_theme_font_size_override("font_size", 13)
	task_center_status_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.96))
	header.add_child(task_center_status_label)

	var close_button := Button.new()
	close_button.name = "TaskCenterCloseButton"
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(88, 40)
	_style_catalog_entry_button(close_button, Color(0.24, 0.78, 0.92))
	close_button.pressed.connect(_close_task_center)
	header.add_child(close_button)

	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 8)
	shell.add_child(summary_row)

	task_center_money_chip_label = _add_home_dock_chip(summary_row, "资金", Color(1.0, 0.72, 0.28))
	task_center_progress_chip_label = _add_home_dock_chip(summary_row, "进度", Color(0.24, 0.78, 0.92))
	task_center_queue_chip_label = _add_home_dock_chip(summary_row, "可接", Color(0.36, 1.0, 0.66))
	task_center_state_chip_label = _add_home_dock_chip(summary_row, "系统", Color(0.95, 0.56, 1.0))

	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	shell.add_child(body)

	var order_box := _make_task_center_section(body, "订单 / 硬件", Color(0.24, 0.78, 0.92), 1.05)
	task_center_order_label = _make_task_center_label(16, Color(0.96, 0.98, 1.0), Vector2(0, 142))
	order_box.add_child(task_center_order_label)
	task_center_hardware_label = _make_task_center_label(14, Color(0.82, 0.90, 1.0), Vector2(0, 300))
	task_center_hardware_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	order_box.add_child(task_center_hardware_label)

	var flow_box := _make_task_center_section(body, "下一步 / 软件", Color(0.36, 1.0, 0.66), 1.0)
	task_center_next_label = _make_task_center_label(17, Color(1.0, 0.96, 0.82), Vector2(0, 128))
	flow_box.add_child(task_center_next_label)
	task_center_next_button = Button.new()
	task_center_next_button.name = "TaskCenterNextButton"
	task_center_next_button.custom_minimum_size = Vector2(0, 44)
	task_center_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_catalog_entry_button(task_center_next_button, Color(1.0, 0.72, 0.28))
	task_center_next_button.pressed.connect(_on_task_center_next_pressed)
	flow_box.add_child(task_center_next_button)
	task_center_software_label = _make_task_center_label(14, Color(0.84, 0.94, 0.90), Vector2(0, 300))
	task_center_software_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	flow_box.add_child(task_center_software_label)

	var delivery_box := _make_task_center_section(body, "交付检查", Color(0.95, 0.56, 1.0), 0.95)
	task_center_delivery_label = _make_task_center_label(15, Color(0.94, 0.90, 1.0), Vector2(0, 260))
	task_center_delivery_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	delivery_box.add_child(task_center_delivery_label)

	var action_grid := GridContainer.new()
	action_grid.columns = 2
	action_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_grid.add_theme_constant_override("h_separation", 8)
	action_grid.add_theme_constant_override("v_separation", 8)
	delivery_box.add_child(action_grid)

	var order_button := _make_task_center_button("订单大厅", Color(0.24, 0.78, 0.92))
	order_button.pressed.connect(_on_task_center_order_pressed)
	action_grid.add_child(order_button)

	var market_button := _make_task_center_button("配件市场", Color(0.24, 0.78, 0.92))
	market_button.pressed.connect(_on_task_center_market_pressed)
	action_grid.add_child(market_button)

	var inventory_button := _make_task_center_button("仓库", Color(0.36, 1.0, 0.66))
	inventory_button.pressed.connect(_on_task_center_inventory_pressed)
	action_grid.add_child(inventory_button)

	task_center_check_button = _make_task_center_button("硬件检查", Color(0.36, 1.0, 0.66))
	task_center_check_button.pressed.connect(_on_task_center_check_pressed)
	action_grid.add_child(task_center_check_button)

	task_center_monitor_button = _make_task_center_button("打开显示器", Color(0.24, 0.78, 0.92))
	task_center_monitor_button.pressed.connect(_on_task_center_monitor_pressed)
	action_grid.add_child(task_center_monitor_button)

	task_center_deliver_button = _make_task_center_button("交付订单", Color(1.0, 0.72, 0.28))
	task_center_deliver_button.pressed.connect(_on_task_center_deliver_pressed)
	action_grid.add_child(task_center_deliver_button)

func _make_task_center_section(parent: Container, title_text: String, accent: Color, ratio: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	panel.add_theme_stylebox_override("panel", _catalog_stylebox(Color(accent.r * 0.035, accent.g * 0.035, accent.b * 0.035, 0.96), accent, 8, 10))
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", accent.lightened(0.24))
	box.add_child(title)
	return box

func _make_task_center_label(font_size: int, color: Color, minimum_size: Vector2) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = minimum_size
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _make_task_center_button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_catalog_entry_button(button, accent)
	return button

func open_task_center_overlay() -> void:
	if task_center_overlay == null:
		return
	_close_order_desk()
	_close_system_center()
	_close_catalog_overlay()
	if not task_center_overlay.visible:
		task_center_previous_focus = get_viewport().gui_get_focus_owner()
	task_center_overlay.visible = true
	task_center_overlay.move_to_front()
	_set_home_tab("workbench")
	_refresh_task_center()
	if task_center_next_button:
		task_center_next_button.grab_focus()

func _close_task_center() -> void:
	if task_center_overlay:
		task_center_overlay.visible = false
	if is_instance_valid(task_center_previous_focus):
		task_center_previous_focus.grab_focus()

func _refresh_task_center() -> void:
	if task_center_overlay == null:
		return
	var order: Dictionary = get_current_order()
	var next_action: Dictionary = _task_center_next_action()
	var reasons: Array[String] = validate_current_order()
	if task_center_status_label:
		task_center_status_label.text = _task_center_status_summary_text(order, next_action, reasons)
	if task_center_money_chip_label:
		task_center_money_chip_label.text = "资金 ￥%d" % money
	if task_center_progress_chip_label:
		task_center_progress_chip_label.text = "进度 %d/%d" % [completed_order_ids.size(), order_defs.size()]
	if task_center_queue_chip_label:
		task_center_queue_chip_label.text = "可接 %d" % available_order_indices.size()
	if task_center_state_chip_label:
		task_center_state_chip_label.text = _task_center_machine_state()
	if task_center_order_label:
		task_center_order_label.text = _task_center_order_text(order)
	if task_center_hardware_label:
		task_center_hardware_label.text = _task_center_hardware_text(order)
	if task_center_next_label:
		task_center_next_label.text = "%s\n%s" % [
			str(next_action.get("title", "下一步")),
			str(next_action.get("detail", "")),
		]
	if task_center_next_button:
		task_center_next_button.text = str(next_action.get("button", "执行下一步"))
		task_center_next_button.disabled = false
	if task_center_software_label:
		task_center_software_label.text = _task_center_software_text(order)
	if task_center_delivery_label:
		task_center_delivery_label.text = _task_center_delivery_text(reasons)
	if task_center_check_button:
		task_center_check_button.disabled = order.is_empty()
	if task_center_monitor_button:
		task_center_monitor_button.disabled = not system_booted
	if task_center_deliver_button:
		task_center_deliver_button.disabled = order.is_empty()

func _task_center_status_summary_text(order: Dictionary, next_action: Dictionary, reasons: Array[String]) -> String:
	var order_name := "暂无订单"
	if not order.is_empty():
		order_name = str(order.get("name", "订单"))
	var delivery_state := "待接单"
	if not order.is_empty():
		delivery_state = "可交付" if reasons.is_empty() else "待处理 %d 项" % reasons.size()
	return "当前订单 %s | 软件 %d/100 | 交付 %s | 下一步 %s" % [
		order_name,
		get_software_configuration_score(),
		delivery_state,
		str(next_action.get("title", "下一步")),
	]

func _task_center_order_text(order: Dictionary) -> String:
	if order.is_empty():
		return "当前没有进行中的订单。\n打开订单大厅接取新的客户需求。"
	return "当前订单：%s\n客户：%s / %s\n难度 D%d   奖励 ￥%d   预计 %d 分钟\n硬件：%s\n软件：%s" % [
		str(order.get("name", "订单")),
		str(order.get("customer", "客户")),
		str(order.get("customer_type", "普通客户")),
		int(order.get("difficulty", 1)),
		int(order.get("reward", 0)),
		int(order.get("estimated_minutes", 5)),
		_format_order_requirements(order),
		_format_software_tasks(order),
	]

func _task_center_hardware_text(order: Dictionary) -> String:
	var lines: Array[String] = []
	var missing := get_missing_required_slots()
	lines.append("核心槽位：%d / %d" % [required_slots.size() - missing.size(), required_slots.size()])
	if missing.is_empty():
		lines.append("核心硬件：已装齐")
	else:
		lines.append("缺少：%s" % "、".join(_slot_labels(missing)))
	var compatibility_issues := get_compatibility_issues()
	if compatibility_issues.is_empty():
		lines.append("兼容性：通过")
	else:
		lines.append("兼容性：%s" % "；".join(compatibility_issues))
	if not order.is_empty():
		lines.append("")
		lines.append("订单硬件检查：")
		var requirements: Dictionary = order.get("requirements", {})
		for slot in requirements.keys():
			var slot_key := str(slot)
			var required_tier := int(requirements[slot])
			if installed.has(slot_key):
				var installed_tier := int(installed[slot_key].tier)
				var state := "通过" if installed_tier >= required_tier else "等级不足"
				lines.append("%s Lv.%d / 需要 Lv.%d  %s" % [
					component_database.display_type(slot_key),
					installed_tier,
					required_tier,
					state,
				])
			else:
				lines.append("%s 未安装 / 需要 Lv.%d" % [component_database.display_type(slot_key), required_tier])
	return "\n".join(lines)

func _task_center_software_text(order: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("模拟系统：%s" % _task_center_machine_state())
	lines.append("软件配置完成度：%d / 100" % get_software_configuration_score())
	if order.is_empty():
		lines.append("接单后会显示软件任务。")
		return "\n".join(lines)
	lines.append("")
	lines.append("订单软件任务：")
	for task in _software_tasks(order):
		var progress := int(round(_software_task_progress(task) * 100.0))
		var state := "完成" if _is_software_task_complete(task) else "未完成"
		lines.append("%s  %s  %d%%" % [_software_task_label(task), state, progress])
	if not os_log.is_empty():
		lines.append("")
		lines.append("最近日志：%s" % str(os_log[os_log.size() - 1]))
	return "\n".join(lines)

func _task_center_delivery_text(reasons: Array[String]) -> String:
	var lines: Array[String] = []
	if not last_delivery_score.is_empty():
		lines.append("最近回执：%s  %d / %s" % [
			str(last_delivery_score.get("order_name", "订单")),
			int(last_delivery_score.get("score", 0)),
			str(last_delivery_score.get("grade", "-")),
		])
		lines.append("性能 %d / 预算 %d / 兼容 %d / 启动 %d / 软件 %d" % [
			int(last_delivery_score.get("performance", 0)),
			int(last_delivery_score.get("budget", 0)),
			int(last_delivery_score.get("compatibility", 0)),
			int(last_delivery_score.get("boot", 0)),
			int(last_delivery_score.get("software", 0)),
		])
		lines.append("")
	if reasons.is_empty():
		var score := calculate_delivery_score()
		lines.append("交付前检查：可交付")
		lines.append("预计评分：%d / %s" % [int(score.get("score", 0)), str(score.get("grade", "-"))])
		lines.append("交付会刷新下一张可接订单。")
	else:
		lines.append("交付前检查：待处理 %d 项" % reasons.size())
		for index in range(mini(4, reasons.size())):
			lines.append("- %s" % str(reasons[index]))
		if reasons.size() > 4:
			lines.append("- 另有 %d 项" % (reasons.size() - 4))
	return "\n".join(lines)

func _task_center_machine_state() -> String:
	if system_booted:
		return "OS 已启动"
	if powered_on:
		return "硬件检查通过，待开机"
	return "未开机"

func _task_center_next_action() -> Dictionary:
	var order := get_current_order()
	if order.is_empty():
		return {"action": "orders", "title": "没有进行中的订单", "detail": "先从订单大厅接取客户需求，再回到工作台装机。", "button": "打开订单大厅"}
	var missing := get_missing_required_slots()
	if not missing.is_empty():
		var first_slot := str(missing[0])
		var label: String = component_database.display_type(first_slot)
		return {"action": "shop", "slot": first_slot, "title": "补齐核心硬件", "detail": "下一件：%s。市场会按该槽位筛选，也可以从仓库安装现有配件。" % label, "button": "打开配件市场"}
	if not powered_on:
		return {"action": "check", "title": "运行硬件检查", "detail": "核心硬件已装齐。先做兼容性和开机前检查。", "button": "执行硬件检查"}
	if not system_booted:
		return {"action": "power", "title": "启动模拟系统", "detail": "硬件检查通过。按下电源后进入模拟 OS。", "button": "按下电源"}
	if not driver_scan_completed:
		return {"action": "driver_scan", "title": "配置基础驱动", "detail": "进入 Driver Tool 扫描设备，开始软件配置闭环。", "button": "扫描设备"}
	if not drivers_installed:
		return {"action": "driver_install", "title": "安装基础驱动", "detail": "设备扫描完成。安装驱动后需要重启验证。", "button": "安装驱动"}
	if os_restart_required:
		return {"action": "driver_restart", "title": "重启验证驱动", "detail": "驱动已安装但未验证。重启 OS 后软件配置才算完成。", "button": "重启验证"}
	if _current_order_requires_task("gpu_driver") and not gpu_driver_installed:
		return {"action": "gpu_driver", "title": "安装显卡驱动", "detail": "这张订单要求 GPU 驱动。基础驱动验证后可安装。", "button": "安装 GPU 驱动"}
	if _current_order_requires_task("benchmark") and not benchmark_completed:
		return {"action": "benchmark", "title": "运行性能跑分", "detail": "订单要求 Benchmark。跑分会影响交付评分。", "button": "运行 Benchmark"}
	if _current_order_requires_task("stability") and not stability_test_completed:
		return {"action": "stability", "title": "运行稳定性测试", "detail": "订单要求 Stability Test。完成后再交付。", "button": "运行稳定性测试"}
	return {"action": "deliver", "title": "准备交付", "detail": "硬件和软件检查已进入可交付状态。", "button": "交付订单"}

func _on_task_center_next_pressed() -> void:
	var action := str(_task_center_next_action().get("action", "orders"))
	match action:
		"orders":
			_close_task_center()
			open_order_desk()
		"shop":
			var next_action := _task_center_next_action()
			var slot := str(next_action.get("slot", ""))
			if slot != "":
				_on_slot_pressed(slot)
			_close_task_center()
			open_shop_overlay()
		"check":
			_on_finish_pressed()
		"power":
			_on_power_button_pressed()
		"driver_scan":
			_on_driver_scan_pressed()
		"driver_install":
			_on_driver_install_pressed()
		"driver_restart":
			_on_driver_restart_pressed()
		"gpu_driver":
			_on_gpu_driver_install_pressed()
		"benchmark":
			_on_os_benchmark_pressed()
		"stability":
			_on_os_stability_test_pressed()
		"deliver":
			_on_deliver_pressed()
	_refresh_task_center()

func _on_task_center_order_pressed() -> void:
	_close_task_center()
	open_order_desk()

func _on_task_center_market_pressed() -> void:
	_close_task_center()
	open_shop_overlay()

func _on_task_center_inventory_pressed() -> void:
	_close_task_center()
	open_inventory_overlay()

func _on_task_center_check_pressed() -> void:
	_on_finish_pressed()
	_refresh_task_center()

func _on_task_center_monitor_pressed() -> void:
	_close_task_center()
	_on_open_monitor_pressed()

func _on_task_center_deliver_pressed() -> void:
	_on_deliver_pressed()
	_refresh_task_center()

func _build_system_center_ui() -> void:
	system_center_overlay = ColorRect.new()
	system_center_overlay.name = "SystemCenterOverlay"
	system_center_overlay.visible = false
	system_center_overlay.color = Color(0.006, 0.010, 0.022, 1.0)
	system_center_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	system_center_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	system_center_overlay.z_index = 31
	add_child(system_center_overlay)

	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 24)
	frame.add_theme_constant_override("margin_top", 20)
	frame.add_theme_constant_override("margin_right", 24)
	frame.add_theme_constant_override("margin_bottom", 20)
	system_center_overlay.add_child(frame)

	var shell_panel := PanelContainer.new()
	shell_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell_panel.add_theme_stylebox_override("panel", _catalog_stylebox(Color(0.014, 0.020, 0.045, 0.98), Color(0.36, 1.0, 0.66), 8, 12))
	frame.add_child(shell_panel)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 10)
	shell_panel.add_child(shell)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	shell.add_child(header)

	var title := Label.new()
	title.text = "系统中心"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 1.0, 0.88))
	header.add_child(title)

	system_center_status_label = Label.new()
	system_center_status_label.custom_minimum_size = Vector2(520, 54)
	system_center_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	system_center_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	system_center_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	system_center_status_label.max_lines_visible = 2
	system_center_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	system_center_status_label.add_theme_font_size_override("font_size", 14)
	system_center_status_label.add_theme_color_override("font_color", Color(0.76, 0.9, 0.86))
	header.add_child(system_center_status_label)

	var close_button := Button.new()
	close_button.name = "SystemCenterCloseButton"
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(88, 40)
	_style_catalog_entry_button(close_button, Color(0.36, 1.0, 0.66))
	close_button.pressed.connect(_close_system_center)
	header.add_child(close_button)

	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	shell.add_child(body)

	var info_box := _make_task_center_section(body, "系统状态", Color(0.36, 1.0, 0.66), 1.05)
	system_center_software_label = _make_task_center_label(14, Color(0.86, 0.94, 0.98), Vector2(0, 160))
	system_center_software_label.size_flags_vertical = Control.SIZE_FILL
	info_box.add_child(system_center_software_label)

	system_center_log_label = _make_task_center_label(13, Color(0.74, 0.9, 0.92), Vector2(0, 140))
	system_center_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_box.add_child(system_center_log_label)

	var action_box := _make_task_center_section(body, "快捷入口", Color(0.24, 0.78, 0.92), 0.95)
	var action_grid := GridContainer.new()
	action_grid.columns = 2
	action_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_grid.add_theme_constant_override("h_separation", 8)
	action_grid.add_theme_constant_override("v_separation", 8)
	action_box.add_child(action_grid)

	system_center_power_button = _make_task_center_button("电源按钮", Color(0.95, 0.56, 1.0))
	system_center_power_button.pressed.connect(_on_system_center_power_pressed)
	action_grid.add_child(system_center_power_button)

	system_center_info_button = _make_task_center_button("系统信息", Color(0.36, 1.0, 0.66))
	system_center_info_button.pressed.connect(_on_system_center_info_pressed)
	action_grid.add_child(system_center_info_button)

	system_center_driver_button = _make_task_center_button("Driver Tool", Color(0.24, 0.78, 0.92))
	system_center_driver_button.pressed.connect(_on_system_center_driver_pressed)
	action_grid.add_child(system_center_driver_button)

	system_center_benchmark_button = _make_task_center_button("跑分", Color(0.24, 0.78, 0.92))
	system_center_benchmark_button.pressed.connect(_on_system_center_benchmark_pressed)
	action_grid.add_child(system_center_benchmark_button)

	system_center_stability_button = _make_task_center_button("稳定性测试", Color(0.36, 1.0, 0.66))
	system_center_stability_button.pressed.connect(_on_system_center_stability_pressed)
	action_grid.add_child(system_center_stability_button)

	system_center_files_button = _make_task_center_button("文件", Color(0.36, 1.0, 0.66))
	system_center_files_button.pressed.connect(_on_system_center_files_pressed)
	action_grid.add_child(system_center_files_button)

	system_center_monitor_button = _make_task_center_button("Max Monitor", Color(1.0, 0.72, 0.28))
	system_center_monitor_button.pressed.connect(_on_system_center_monitor_pressed)
	action_grid.add_child(system_center_monitor_button)

	system_center_shutdown_button = _make_task_center_button("关机", Color(0.95, 0.56, 1.0))
	system_center_shutdown_button.pressed.connect(_on_system_center_shutdown_pressed)
	action_grid.add_child(system_center_shutdown_button)

func open_system_center_overlay() -> void:
	if system_center_overlay == null:
		return
	if not system_center_overlay.visible:
		system_center_previous_focus = get_viewport().gui_get_focus_owner()
	_close_order_desk()
	_close_task_center()
	_close_catalog_overlay()
	if monitor_overlay != null:
		monitor_overlay.visible = false
	system_center_overlay.visible = true
	system_center_overlay.move_to_front()
	_set_home_tab("system")
	_refresh_system_center()
	if system_booted and system_center_info_button:
		system_center_info_button.grab_focus()
	elif system_center_power_button:
		system_center_power_button.grab_focus()

func _close_system_center() -> void:
	if system_center_overlay:
		system_center_overlay.visible = false
	if is_instance_valid(system_center_previous_focus):
		system_center_previous_focus.grab_focus()

func _refresh_system_center() -> void:
	if system_center_overlay == null:
		return
	var order: Dictionary = get_current_order()
	var reasons: Array[String] = validate_current_order()
	if system_center_status_label:
		var state := "未开机"
		if powered_on:
			state = "待按电源"
		if system_booted:
			state = "已启动"
		var delivery_state := "无订单"
		if not order.is_empty():
			delivery_state = "可交付" if reasons.is_empty() else "待完成 %d 项" % reasons.size()
		system_center_status_label.text = "状态：%s | 当前：%s\n软件 %d/100 | 交付：%s" % [
			state,
			os_app,
			get_software_configuration_score(),
			delivery_state,
		]
	if system_center_power_button:
		system_center_power_button.text = "电源按钮" if not system_booted else "重进系统"
	if system_center_software_label:
		if not powered_on:
			system_center_software_label.text = "系统尚未通电。\n先完成装机检查，再按电源按钮进入模拟系统。"
		elif not system_booted:
			system_center_software_label.text = "硬件检测已完成，等待按电源进入模拟系统。\n进入后可执行系统信息、驱动、跑分和稳定性测试。"
		else:
			system_center_software_label.text = _system_center_software_text(order)
	if system_center_log_label:
		var log_lines: Array[String] = []
		if os_log.is_empty():
			log_lines.append("暂无系统日志。")
		else:
			var start_index := maxi(0, os_log.size() - 3)
			for index in range(start_index, os_log.size()):
				log_lines.append(os_log[index])
		log_lines.append("软件配置会计入订单评分。")
		if not order.is_empty():
			log_lines.append("交付前检查：%s" % ("全部通过" if reasons.is_empty() else "、".join(reasons)))
		system_center_log_label.text = "最近日志：\n%s" % "\n".join(log_lines)
	if system_center_info_button:
		system_center_info_button.disabled = not system_booted
	if system_center_driver_button:
		system_center_driver_button.disabled = not system_booted
	if system_center_benchmark_button:
		system_center_benchmark_button.disabled = not system_booted
	if system_center_stability_button:
		system_center_stability_button.disabled = not system_booted
	if system_center_files_button:
		system_center_files_button.disabled = not system_booted
	if system_center_monitor_button:
		system_center_monitor_button.disabled = not system_booted
	if system_center_shutdown_button:
		system_center_shutdown_button.disabled = not system_booted

func _system_center_software_text(order: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("模拟系统：OS 已启动")
	lines.append("软件配置完成度：%d / 100" % get_software_configuration_score())
	lines.append("")
	if order.is_empty():
		lines.append("当前没有进行中的订单。")
		lines.append("可先从订单大厅接单，再回到系统中心处理软件配置。")
		return "\n".join(lines)
	lines.append("订单软件任务：")
	if not driver_scan_completed:
		lines.append("基础驱动  待扫描")
	elif not drivers_installed:
		lines.append("基础驱动  待安装")
	elif os_restart_required:
		lines.append("基础驱动  待重启验证")
	else:
		lines.append("基础驱动  已验证")
	if _current_order_requires_task("gpu_driver"):
		lines.append("显卡驱动  %s" % ("已完成" if gpu_driver_installed else "待安装"))
	if _current_order_requires_task("benchmark"):
		lines.append("Benchmark  %s" % ("已完成 %d 分" % _benchmark_score() if benchmark_completed else "待运行"))
	if _current_order_requires_task("stability"):
		lines.append("稳定性测试  %s" % ("已通过" if stability_test_completed else "待运行"))
	lines.append("")
	lines.append("当前应用：%s" % os_app)
	return "\n".join(lines)

func _open_system_center_monitor_action(action: String) -> void:
	if not _require_booted_system():
		_refresh_system_center()
		return
	_close_system_center()
	match action:
		"system_info":
			_on_os_system_info_pressed()
		"driver":
			_on_monitor_driver_tool_pressed()
		"benchmark":
			_on_os_benchmark_pressed()
		"stability":
			_on_os_stability_test_pressed()
		"files":
			_on_monitor_files_pressed()
		"desktop":
			_on_monitor_desktop_pressed()
		"monitor":
			pass
	_on_open_monitor_pressed()

func _on_system_center_power_pressed() -> void:
	_on_power_button_pressed()
	_refresh_system_center()

func _on_system_center_info_pressed() -> void:
	_open_system_center_monitor_action("system_info")

func _on_system_center_driver_pressed() -> void:
	_open_system_center_monitor_action("driver")

func _on_system_center_benchmark_pressed() -> void:
	_open_system_center_monitor_action("benchmark")

func _on_system_center_stability_pressed() -> void:
	_open_system_center_monitor_action("stability")

func _on_system_center_files_pressed() -> void:
	_open_system_center_monitor_action("files")

func _on_system_center_monitor_pressed() -> void:
	_open_system_center_monitor_action("monitor")

func _on_system_center_shutdown_pressed() -> void:
	_on_os_shutdown_pressed()
	_refresh_system_center()

func _build_catalog_overlay_ui() -> void:
	catalog_overlay = ColorRect.new()
	catalog_overlay.name = "CatalogOverlay"
	catalog_overlay.visible = false
	catalog_overlay.color = Color(0.006, 0.010, 0.022, 1.0)
	catalog_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	catalog_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catalog_overlay.z_index = 34
	add_child(catalog_overlay)

	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 24)
	frame.add_theme_constant_override("margin_top", 20)
	frame.add_theme_constant_override("margin_right", 24)
	frame.add_theme_constant_override("margin_bottom", 20)
	catalog_overlay.add_child(frame)

	var shell_panel := PanelContainer.new()
	shell_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell_panel.add_theme_stylebox_override("panel", _catalog_stylebox(Color(0.014, 0.020, 0.045, 0.98), Color(0.22, 0.78, 0.92), 8, 12))
	frame.add_child(shell_panel)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 10)
	shell_panel.add_child(shell)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	shell.add_child(header)

	catalog_title_label = Label.new()
	catalog_title_label.text = "配件市场"
	catalog_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	catalog_title_label.add_theme_font_size_override("font_size", 30)
	catalog_title_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
	header.add_child(catalog_title_label)

	catalog_money_label = Label.new()
	catalog_money_label.custom_minimum_size = Vector2(170, 42)
	catalog_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	catalog_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	catalog_money_label.add_theme_font_size_override("font_size", 18)
	catalog_money_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.34))
	header.add_child(catalog_money_label)

	catalog_shop_button = Button.new()
	catalog_shop_button.name = "CatalogShopModeButton"
	catalog_shop_button.text = "市场"
	catalog_shop_button.custom_minimum_size = Vector2(92, 40)
	catalog_shop_button.pressed.connect(open_shop_overlay)
	header.add_child(catalog_shop_button)

	catalog_inventory_button = Button.new()
	catalog_inventory_button.name = "CatalogInventoryModeButton"
	catalog_inventory_button.text = "仓库"
	catalog_inventory_button.custom_minimum_size = Vector2(92, 40)
	catalog_inventory_button.pressed.connect(open_inventory_overlay)
	header.add_child(catalog_inventory_button)

	var close_button := Button.new()
	close_button.name = "CatalogCloseButton"
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(88, 40)
	_style_catalog_entry_button(close_button, Color(0.24, 0.78, 0.92))
	close_button.pressed.connect(_close_catalog_overlay)
	header.add_child(close_button)

	catalog_status_label = Label.new()
	catalog_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	catalog_status_label.custom_minimum_size = Vector2(0, 24)
	catalog_status_label.add_theme_font_size_override("font_size", 14)
	catalog_status_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.94))
	shell.add_child(catalog_status_label)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(body)

	catalog_shop_panel = SHOP_PANEL_SCENE.instantiate()
	catalog_shop_panel.name = "CatalogShopPanel"
	catalog_shop_panel.fullscreen_catalog = true
	catalog_shop_panel.component_database = component_database
	catalog_shop_panel.game = self
	catalog_shop_panel.item_purchased.connect(_on_shop_item_selected)
	catalog_shop_panel.item_purchased_and_installed.connect(_on_shop_item_quick_install_selected)
	body.add_child(catalog_shop_panel)

	catalog_inventory_panel = INVENTORY_PANEL_SCENE.instantiate()
	catalog_inventory_panel.name = "CatalogInventoryPanel"
	catalog_inventory_panel.fullscreen_catalog = true
	catalog_inventory_panel.component_database = component_database
	catalog_inventory_panel.game = self
	catalog_inventory_panel.item_selected.connect(_on_inventory_item_selected)
	catalog_inventory_panel.item_sold.connect(_on_inventory_item_sold)
	catalog_inventory_panel.filter_cleared.connect(_on_inventory_filter_cleared)
	body.add_child(catalog_inventory_panel)

	_refresh_catalog_mode_buttons()

func open_shop_overlay() -> void:
	_open_catalog_overlay("shop")

func open_inventory_overlay() -> void:
	_open_catalog_overlay("inventory")

func _open_catalog_overlay(mode: String) -> void:
	if catalog_overlay == null:
		return
	if not catalog_overlay.visible:
		catalog_previous_focus = get_viewport().gui_get_focus_owner()
	catalog_overlay.visible = true
	catalog_overlay.move_to_front()
	_refresh_catalog_overlay()
	_show_catalog_mode(mode)

func _close_catalog_overlay() -> void:
	if catalog_overlay:
		catalog_overlay.visible = false
	if is_instance_valid(catalog_previous_focus):
		catalog_previous_focus.grab_focus()

func _refresh_catalog_overlay() -> void:
	if catalog_money_label:
		catalog_money_label.text = "资金  %d" % money
	if catalog_shop_panel:
		catalog_shop_panel.update_items(component_database.get_all_components())
		catalog_shop_panel.set_type_filter(current_filter)
	if catalog_inventory_panel:
		catalog_inventory_panel.update_items(inventory, current_filter)

func _show_catalog_mode(mode: String) -> void:
	catalog_mode = mode
	var shop_mode: bool = mode == "shop"
	if catalog_title_label:
		catalog_title_label.text = "配件市场" if shop_mode else "仓库"
	if catalog_status_label:
		if shop_mode:
			var filter_text: String = "全部类型" if current_filter == "" else component_database.display_type(current_filter)
			catalog_status_label.text = "按当前槽位筛选：%s。购买后可继续留在目录里选择、安装或切到仓库。" % filter_text
		else:
			catalog_status_label.text = "库存会跟随当前槽位筛选；可直接安装、出售，或切回市场继续采购。"
	if catalog_shop_panel:
		catalog_shop_panel.visible = shop_mode
	if catalog_inventory_panel:
		catalog_inventory_panel.visible = not shop_mode
	_refresh_catalog_mode_buttons()
	_focus_catalog_panel(shop_mode)

func _focus_catalog_panel(shop_mode: bool) -> void:
	if shop_mode and catalog_shop_panel and catalog_shop_panel._shop_list:
		catalog_shop_panel._shop_list.grab_focus()
	elif not shop_mode and catalog_inventory_panel and catalog_inventory_panel._inventory_list:
		catalog_inventory_panel._inventory_list.grab_focus()
	elif catalog_shop_button:
		catalog_shop_button.grab_focus()

func _refresh_catalog_mode_buttons() -> void:
	if catalog_shop_button:
		_style_catalog_mode_button(catalog_shop_button, Color(0.24, 0.78, 0.92), catalog_mode == "shop")
	if catalog_inventory_button:
		_style_catalog_mode_button(catalog_inventory_button, Color(0.36, 1.0, 0.66), catalog_mode == "inventory")

func _style_catalog_entry_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", _catalog_stylebox(Color(0.024, 0.034, 0.078, 0.94), accent, 8, 8))
	button.add_theme_stylebox_override("hover", _catalog_stylebox(Color(0.04, 0.08, 0.11, 0.96), accent.lightened(0.14), 8, 8))
	button.add_theme_stylebox_override("pressed", _catalog_stylebox(Color(0.08, 0.10, 0.07, 0.98), Color(1.0, 0.72, 0.28), 8, 8))
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_apply_button_icon(button, _button_icon_key(button), 18)

func _style_home_dock_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", _catalog_stylebox(Color(0.024, 0.034, 0.078, 0.94), accent, 6, 3))
	button.add_theme_stylebox_override("hover", _catalog_stylebox(Color(0.04, 0.08, 0.11, 0.96), accent.lightened(0.14), 6, 3))
	button.add_theme_stylebox_override("pressed", _catalog_stylebox(Color(0.08, 0.10, 0.07, 0.98), Color(1.0, 0.72, 0.28), 6, 3))
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_apply_button_icon(button, _button_icon_key(button), 16)

func _style_home_dock_tab(button: Button, accent: Color, active: bool) -> void:
	var base := Color(accent.r * 0.20, accent.g * 0.20, accent.b * 0.20, 0.98) if active else Color(0.024, 0.034, 0.078, 0.94)
	var border := accent if active else Color(accent.r * 0.62, accent.g * 0.62, accent.b * 0.62, 0.84)
	button.add_theme_stylebox_override("normal", _catalog_stylebox(base, border, 7, 6))
	button.add_theme_stylebox_override("hover", _catalog_stylebox(base.lightened(0.10), accent.lightened(0.12), 7, 6))
	button.add_theme_stylebox_override("pressed", _catalog_stylebox(Color(0.12, 0.16, 0.12, 0.98), Color(1.0, 0.72, 0.28), 7, 6))
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0) if active else Color(0.78, 0.86, 0.94))
	_apply_button_icon(button, _button_icon_key(button), 18)

func _style_catalog_mode_button(button: Button, accent: Color, active: bool) -> void:
	var bg := Color(accent.r * 0.16, accent.g * 0.16, accent.b * 0.16, 0.98) if active else Color(0.020, 0.028, 0.062, 0.96)
	var border := accent if active else Color(accent.r * 0.55, accent.g * 0.55, accent.b * 0.55, 0.75)
	button.add_theme_stylebox_override("normal", _catalog_stylebox(bg, border, 8, 8))
	button.add_theme_stylebox_override("hover", _catalog_stylebox(bg.lightened(0.08), accent.lightened(0.12), 8, 8))
	button.add_theme_stylebox_override("pressed", _catalog_stylebox(Color(0.08, 0.10, 0.07, 0.98), Color(1.0, 0.72, 0.28), 8, 8))
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0) if active else Color(0.78, 0.86, 0.94))
	_apply_button_icon(button, _button_icon_key(button), 18)

func _button_icon_key(button: Button) -> String:
	match button.name:
		"FinishCheckButton":
			return "check"
		"PowerButton":
			return "power"
		"TopDeliverButton":
			return "delivery"
		"SaveButton":
			return "save"
		"LoadButton":
			return "load"
		"RestartButton":
			return "restart"
		"OpenTaskCenterButton", "HomeTaskCenterButton", "OrderDeskTaskCenterButton", "TaskCenterNextButton", "TutorialActionButton":
			return "tasks"
		"OpenShopCatalogButton", "CatalogWorkspaceShopButton", "CatalogShopModeButton":
			return "shop"
		"OpenInventoryCatalogButton", "CatalogWorkspaceInventoryButton", "CatalogInventoryModeButton":
			return "inventory"
		"FooterOrderButton", "HomeOrderDeskButton":
			return "orders"
		"FooterFinishButton":
			return "check"
		"FooterPowerButton":
			return "power"
		"HomeWorkbenchTabButton":
			return "workbench"
		"HomeDeliverOrderButton":
			return "delivery"
		"HomeSystemCenterButton":
			return "system"
		"HomeSystemMonitorButton", "OpenMonitorButton":
			return "monitor"
		"TaskCenterCloseButton", "SystemCenterCloseButton", "CatalogCloseButton", "MonitorCloseButton", "OrderDeskCloseButton":
			return "close"
	return ""

func _apply_button_icon(button: Button, icon_key: String, max_width: int) -> void:
	if icon_key == "":
		return
	var texture = UI_ICON_TEXTURES.get(icon_key, null)
	if texture is Texture2D:
		button.icon = texture
		button.expand_icon = true
		button.add_theme_constant_override("h_separation", 5)

func _catalog_stylebox(color: Color, border_color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var box := _stylebox(color, border_color, radius)
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin
	box.content_margin_bottom = margin
	return box

func _format_order_requirements_multiline(order: Dictionary) -> String:
	var parts: Array[String] = []
	var requirements: Dictionary = order.get("requirements", {})
	for slot in requirements.keys():
		var slot_key := str(slot)
		var label: String = component_database.display_type(slot_key) if component_database else slot_key
		parts.append("%s Lv.%d" % [label, int(requirements[slot])])
	return "\n".join(parts)

func _add_order_desk_assessment_card(parent: Container, title: String, accent: Color, min_height: int) -> Label:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, min_height)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _stylebox(Color(accent.r * 0.08, accent.g * 0.08, accent.b * 0.08, 0.88), Color(accent.r, accent.g, accent.b, 0.82), 8))
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 11)
	title_label.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 1.0))
	box.add_child(title_label)

	var value_label := Label.new()
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	box.add_child(value_label)
	return value_label

func _add_order_desk_readiness_card(parent: Container, title: String, accent: Color) -> Label:
	var panel := PanelContainer.new()
	panel.name = "OrderDesk%sReadinessCard" % title
	panel.custom_minimum_size = Vector2(0, 86)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _stylebox(Color(accent.r * 0.08, accent.g * 0.08, accent.b * 0.08, 0.90), Color(accent.r, accent.g, accent.b, 0.82), 8))
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 1.0))
	box.add_child(title_label)

	var value_label := Label.new()
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.clip_text = true
	value_label.custom_minimum_size = Vector2(160, 48)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	value_label.max_lines_visible = 3
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value_label.add_theme_font_size_override("font_size", 13)
	value_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	box.add_child(value_label)
	return value_label

func _add_order_desk_chip(parent: Container, text: String, accent: Color) -> Label:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 34)
	panel.add_theme_stylebox_override("panel", _stylebox(Color(accent.r * 0.10, accent.g * 0.10, accent.b * 0.10, 0.92), accent, 8))
	parent.add_child(panel)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0))
	panel.add_child(label)
	return label

func _make_order_desk_section_title(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", color)
	return label

func _style_order_desk_button(button: Button, accent: Color, strong: bool) -> void:
	var base := Color(accent.r * 0.10, accent.g * 0.10, accent.b * 0.10, 0.96)
	var hover := Color(accent.r * 0.18, accent.g * 0.18, accent.b * 0.18, 0.96)
	var pressed := Color(accent.r * 0.26, accent.g * 0.26, accent.b * 0.26, 0.96)
	if strong:
		base = Color(accent.r * 0.34, accent.g * 0.24, accent.b * 0.10, 0.98)
		hover = Color(accent.r * 0.44, accent.g * 0.30, accent.b * 0.12, 0.98)
		pressed = Color(accent.r * 0.52, accent.g * 0.36, accent.b * 0.14, 0.98)
	button.add_theme_stylebox_override("normal", _stylebox(base, accent, 8))
	button.add_theme_stylebox_override("hover", _stylebox(hover, accent.lightened(0.12), 8))
	button.add_theme_stylebox_override("pressed", _stylebox(pressed, accent.lightened(0.18), 8))
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))

func _wire_order_desk_focus() -> void:
	var controls: Array[Control] = [
		order_desk_list,
		order_desk_accept_button,
		order_desk_deliver_button,
		order_desk_task_button,
		order_desk_market_button,
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

func _build_part_menu() -> void:
	part_menu = PopupMenu.new()
	part_menu.add_item("Details", 0)
	part_menu.add_item("Uninstall", 1)
	part_menu.add_item("Replace", 2)
	part_menu.id_pressed.connect(_on_part_menu_id_pressed)
	add_child(part_menu)

func _build_cheat_ui() -> void:
	if not OS.is_debug_build():
		return
	cheat_button = Button.new()
	cheat_button.name = "CheatButton"
	cheat_button.text = "金手指"
	cheat_button.tooltip_text = "打开测试金手指"
	_style_top_button(cheat_button)
	cheat_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	cheat_button.offset_left = 24
	cheat_button.offset_top = -162
	cheat_button.offset_right = 120
	cheat_button.offset_bottom = -120
	cheat_button.pressed.connect(_on_cheat_toggle_pressed)
	add_child(cheat_button)

	cheat_panel = PanelContainer.new()
	cheat_panel.name = "CheatPanel"
	cheat_panel.visible = false
	cheat_panel.custom_minimum_size = Vector2(240, 0)
	cheat_panel.add_theme_stylebox_override("panel", _stylebox(Color(0.025, 0.035, 0.12, 0.96), Color(1.0, 0.68, 0.22), 10))
	cheat_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	cheat_panel.offset_left = 24
	cheat_panel.offset_top = -374
	cheat_panel.offset_right = 280
	cheat_panel.offset_bottom = -172
	add_child(cheat_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	cheat_panel.add_child(box)

	var title := Label.new()
	title.text = "测试金手指"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	box.add_child(title)

	var add_money := Button.new()
	add_money.text = "+100000 资金"
	add_money.tooltip_text = "测试用：立即增加资金"
	add_money.pressed.connect(_on_cheat_add_money_pressed)
	box.add_child(add_money)

	var fill_order := Button.new()
	fill_order.text = "补齐当前订单"
	fill_order.tooltip_text = "测试用：自动安装一套满足当前订单的兼容配件"
	fill_order.pressed.connect(_on_cheat_fill_order_pressed)
	box.add_child(fill_order)

	var pass_boot := Button.new()
	pass_boot.text = "开机通过"
	pass_boot.tooltip_text = "测试用：直接标记硬件检测和模拟系统启动通过"
	pass_boot.pressed.connect(_on_cheat_boot_pressed)
	box.add_child(pass_boot)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.pressed.connect(_on_cheat_toggle_pressed)
	box.add_child(close_button)

func _build_monitor_ui() -> void:
	monitor_overlay = PanelContainer.new()
	monitor_overlay.name = "MonitorOverlay"
	monitor_overlay.visible = false
	monitor_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	monitor_overlay.z_index = 30
	monitor_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	monitor_overlay.offset_left = 8
	monitor_overlay.offset_top = 8
	monitor_overlay.offset_right = -8
	monitor_overlay.offset_bottom = -8
	monitor_overlay.add_theme_stylebox_override("panel", _stylebox(Color(0.006, 0.009, 0.018, 1.0), Color(0.06, 0.78, 0.9), 8))
	add_child(monitor_overlay)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	monitor_overlay.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	outer.add_child(header)

	var title := Label.new()
	title.text = "Workbench Monitor"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.82, 0.97, 1.0))
	header.add_child(title)

	monitor_status_label = Label.new()
	monitor_status_label.text = "No signal"
	monitor_status_label.add_theme_color_override("font_color", Color(0.55, 0.92, 0.86))
	header.add_child(monitor_status_label)

	var close_monitor_button := Button.new()
	close_monitor_button.name = "MonitorCloseButton"
	close_monitor_button.text = "Close"
	close_monitor_button.pressed.connect(_on_close_monitor_pressed)
	header.add_child(close_monitor_button)

	var screen := PanelContainer.new()
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.add_theme_stylebox_override("panel", _stylebox(Color(0.018, 0.03, 0.045, 1.0), Color(0.09, 0.43, 0.48), 6))
	outer.add_child(screen)

	var screen_box := HBoxContainer.new()
	screen_box.add_theme_constant_override("separation", 12)
	screen.add_child(screen_box)

	var dock := VBoxContainer.new()
	dock.custom_minimum_size = Vector2(150, 0)
	dock.add_theme_constant_override("separation", 8)
	screen_box.add_child(dock)

	dock.add_child(_make_monitor_app_button("Desktop", _on_monitor_desktop_pressed))
	dock.add_child(_make_monitor_app_button("System Info", _on_os_system_info_pressed))
	dock.add_child(_make_monitor_app_button("Benchmark", _on_os_benchmark_pressed))
	dock.add_child(_make_monitor_app_button("Stability Test", _on_os_stability_test_pressed))
	dock.add_child(_make_monitor_app_button("Driver Tool", _on_monitor_driver_tool_pressed))
	dock.add_child(_make_monitor_app_button("Files", _on_monitor_files_pressed))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock.add_child(spacer)
	dock.add_child(_make_monitor_app_button("Shutdown", _on_os_shutdown_pressed))

	var app_panel := PanelContainer.new()
	app_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	app_panel.add_theme_stylebox_override("panel", _stylebox(Color(0.01, 0.07, 0.09, 1.0), Color(0.08, 0.68, 0.72), 4))
	screen_box.add_child(app_panel)

	var app_box := VBoxContainer.new()
	app_box.add_theme_constant_override("separation", 8)
	app_panel.add_child(app_box)

	monitor_app_title = Label.new()
	monitor_app_title.name = "MonitorAppTitle"
	monitor_app_title.text = "Desktop"
	monitor_app_title.add_theme_font_size_override("font_size", 30)
	monitor_app_title.add_theme_color_override("font_color", Color(0.94, 1.0, 0.82))
	app_box.add_child(monitor_app_title)

	var task_board_panel := PanelContainer.new()
	task_board_panel.name = "MonitorTaskBoard"
	task_board_panel.custom_minimum_size = Vector2(0, 82)
	task_board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_board_panel.add_theme_stylebox_override("panel", _stylebox(Color(0.018, 0.09, 0.08, 0.96), Color(0.20, 0.88, 0.76), 6))
	app_box.add_child(task_board_panel)

	monitor_task_board_label = Label.new()
	monitor_task_board_label.name = "MonitorTaskBoardLabel"
	monitor_task_board_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	monitor_task_board_label.clip_text = true
	monitor_task_board_label.custom_minimum_size = Vector2(0, 52)
	monitor_task_board_label.max_lines_visible = 3
	monitor_task_board_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	monitor_task_board_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	monitor_task_board_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	monitor_task_board_label.add_theme_font_size_override("font_size", 14)
	monitor_task_board_label.add_theme_color_override("font_color", Color(0.88, 1.0, 0.94))
	task_board_panel.add_child(monitor_task_board_label)

	monitor_action_row = HBoxContainer.new()
	monitor_action_row.name = "MonitorActionRow"
	monitor_action_row.visible = false
	monitor_action_row.add_theme_constant_override("separation", 8)
	app_box.add_child(monitor_action_row)

	driver_scan_button = _make_monitor_action_button("Scan devices", _on_driver_scan_pressed)
	monitor_action_row.add_child(driver_scan_button)
	driver_install_button = _make_monitor_action_button("Install drivers", _on_driver_install_pressed)
	monitor_action_row.add_child(driver_install_button)
	driver_restart_button = _make_monitor_action_button("Restart OS", _on_driver_restart_pressed)
	monitor_action_row.add_child(driver_restart_button)
	gpu_driver_button = _make_monitor_action_button("Install GPU driver", _on_gpu_driver_install_pressed)
	monitor_action_row.add_child(gpu_driver_button)
	file_order_button = _make_monitor_action_button("current_order.txt", _on_file_order_pressed)
	monitor_action_row.add_child(file_order_button)
	file_driver_button = _make_monitor_action_button("device_report.sys", _on_file_driver_pressed)
	monitor_action_row.add_child(file_driver_button)
	file_benchmark_button = _make_monitor_action_button("latest_score.log", _on_file_benchmark_pressed)
	monitor_action_row.add_child(file_benchmark_button)
	file_preflight_button = _make_monitor_action_button("preflight_report.txt", _on_file_preflight_pressed)
	monitor_action_row.add_child(file_preflight_button)

	var content_scroll := ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	app_box.add_child(content_scroll)

	monitor_content_label = Label.new()
	monitor_content_label.name = "MonitorContentLabel"
	monitor_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	monitor_content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	monitor_content_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	monitor_content_label.add_theme_font_size_override("font_size", 18)
	monitor_content_label.add_theme_color_override("font_color", Color(0.9, 0.98, 0.95))
	content_scroll.add_child(monitor_content_label)

func _make_monitor_app_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(130, 38)
	button.pressed.connect(callback)
	button.add_theme_stylebox_override("normal", _stylebox(Color(0.02, 0.08, 0.095, 1.0), Color(0.08, 0.38, 0.42), 6))
	button.add_theme_stylebox_override("hover", _stylebox(Color(0.04, 0.16, 0.18, 1.0), Color(0.12, 0.86, 0.84), 6))
	button.add_theme_stylebox_override("pressed", _stylebox(Color(0.06, 0.23, 0.22, 1.0), Color(0.94, 0.82, 0.32), 6))
	button.add_theme_color_override("font_color", Color(0.93, 1.0, 0.98))
	monitor_app_buttons.append(button)
	return button

func _make_monitor_action_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 36)
	button.pressed.connect(callback)
	button.add_theme_stylebox_override("normal", _stylebox(Color(0.055, 0.075, 0.09, 1.0), Color(0.14, 0.46, 0.48), 5))
	button.add_theme_stylebox_override("hover", _stylebox(Color(0.08, 0.16, 0.16, 1.0), Color(0.16, 0.94, 0.82), 5))
	button.add_theme_stylebox_override("pressed", _stylebox(Color(0.16, 0.21, 0.12, 1.0), Color(0.96, 0.82, 0.32), 5))
	button.add_theme_color_override("font_color", Color(0.93, 1.0, 0.96))
	return button

func _style_monitor_file_button(button: Button, active: bool) -> void:
	if button == null:
		return
	var accent := Color(0.36, 1.0, 0.66) if active else Color(0.14, 0.46, 0.48)
	var base := Color(0.035, 0.12, 0.10, 1.0) if active else Color(0.055, 0.075, 0.09, 1.0)
	button.add_theme_stylebox_override("normal", _stylebox(base, accent, 5))
	button.add_theme_stylebox_override("hover", _stylebox(Color(0.08, 0.16, 0.16, 1.0), Color(0.16, 0.94, 0.82), 5))
	button.add_theme_stylebox_override("pressed", _stylebox(Color(0.16, 0.21, 0.12, 1.0), Color(0.96, 0.82, 0.32), 5))
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0) if active else Color(0.88, 0.96, 0.94))

func _build_pause_ui() -> void:
	pause_backdrop = ColorRect.new()
	pause_backdrop.name = "PauseBackdrop"
	pause_backdrop.color = Color(0.0, 0.0, 0.02, 0.72)
	pause_backdrop.visible = false
	pause_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_backdrop.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause_backdrop.z_index = 40
	add_child(pause_backdrop)

	pause_panel = PanelContainer.new()
	pause_panel.name = "PausePanel"
	pause_panel.visible = false
	pause_panel.anchor_left = 0.5
	pause_panel.anchor_top = 0.5
	pause_panel.anchor_right = 0.5
	pause_panel.anchor_bottom = 0.5
	pause_panel.offset_left = -260
	pause_panel.offset_top = -250
	pause_panel.offset_right = 260
	pause_panel.offset_bottom = 250
	pause_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause_panel.z_index = 41
	pause_panel.add_theme_stylebox_override("panel", _stylebox(Color(0.012, 0.02, 0.08, 0.99), Color(0.18, 0.8, 0.86), 7))
	add_child(pause_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	pause_panel.add_child(box)

	var title := Label.new()
	title.text = "暂停菜单"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	pause_status_label = Label.new()
	pause_status_label.text = "当前进度尚未保存"
	pause_status_label.add_theme_color_override("font_color", Color(0.48, 0.86, 0.9))
	box.add_child(pause_status_label)

	var resume_button := Button.new()
	resume_button.text = "继续游戏"
	resume_button.pressed.connect(_on_resume_game_pressed)
	box.add_child(resume_button)

	var save_button := Button.new()
	save_button.text = "保存游戏"
	save_button.pressed.connect(_on_pause_save_pressed)
	box.add_child(save_button)

	var divider := HSeparator.new()
	box.add_child(divider)

	pause_fullscreen_toggle = CheckButton.new()
	pause_fullscreen_toggle.text = "全屏显示"
	box.add_child(pause_fullscreen_toggle)

	var resolution_label := Label.new()
	resolution_label.text = "窗口分辨率"
	box.add_child(resolution_label)

	pause_resolution_option = OptionButton.new()
	for resolution in get_node("/root/GameSession").RESOLUTIONS:
		pause_resolution_option.add_item("%d × %d" % [resolution.x, resolution.y])
	box.add_child(pause_resolution_option)

	var volume_label := Label.new()
	volume_label.text = "主音量"
	box.add_child(volume_label)

	pause_volume_slider = HSlider.new()
	pause_volume_slider.min_value = 0
	pause_volume_slider.max_value = 100
	pause_volume_slider.step = 1
	box.add_child(pause_volume_slider)

	var apply_settings_button := Button.new()
	apply_settings_button.text = "应用设置"
	apply_settings_button.pressed.connect(_on_pause_apply_settings_pressed)
	box.add_child(apply_settings_button)

	var main_menu_button := Button.new()
	main_menu_button.text = "保存并返回主菜单"
	main_menu_button.pressed.connect(_on_save_and_main_menu_pressed)
	box.add_child(main_menu_button)

func _build_action_feedback_panel(parent: Container) -> void:
	action_feedback_panel = PanelContainer.new()
	action_feedback_panel.name = "ActionFeedbackPanel"
	action_feedback_panel.custom_minimum_size = Vector2(0, 40)
	action_feedback_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_feedback_panel.size_flags_stretch_ratio = 1.0
	action_feedback_panel.add_theme_stylebox_override("panel", _action_feedback_style("idle"))
	parent.add_child(action_feedback_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	action_feedback_panel.add_child(box)

	action_feedback_title = Label.new()
	action_feedback_title.name = "ActionFeedbackTitle"
	action_feedback_title.text = "操作提示：准备开始"
	action_feedback_title.clip_text = true
	action_feedback_title.max_lines_visible = 1
	action_feedback_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	action_feedback_title.add_theme_font_size_override("font_size", 12)
	action_feedback_title.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	box.add_child(action_feedback_title)

	action_feedback_detail = Label.new()
	action_feedback_detail.name = "ActionFeedbackDetail"
	action_feedback_detail.text = "当前订单待处理。"
	action_feedback_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_feedback_detail.clip_text = true
	action_feedback_detail.max_lines_visible = 1
	action_feedback_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	action_feedback_detail.add_theme_font_size_override("font_size", 10)
	action_feedback_detail.add_theme_color_override("font_color", Color(0.68, 0.78, 0.92))
	box.add_child(action_feedback_detail)

func _build_delivery_feedback_panel(parent: Container) -> void:
	delivery_feedback_panel = PanelContainer.new()
	delivery_feedback_panel.name = "DeliveryFeedbackPanel"
	delivery_feedback_panel.custom_minimum_size = Vector2(0, 40)
	delivery_feedback_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delivery_feedback_panel.size_flags_stretch_ratio = 1.0
	delivery_feedback_panel.add_theme_stylebox_override("panel", _delivery_feedback_style("idle"))
	parent.add_child(delivery_feedback_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	delivery_feedback_panel.add_child(box)

	delivery_feedback_title = Label.new()
	delivery_feedback_title.clip_text = true
	delivery_feedback_title.max_lines_visible = 1
	delivery_feedback_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	delivery_feedback_title.add_theme_font_size_override("font_size", 13)
	delivery_feedback_title.add_theme_color_override("font_color", Color(0.88, 0.93, 1.0))
	box.add_child(delivery_feedback_title)

	delivery_feedback_detail = Label.new()
	delivery_feedback_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	delivery_feedback_detail.clip_text = true
	delivery_feedback_detail.max_lines_visible = 1
	delivery_feedback_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	delivery_feedback_detail.add_theme_font_size_override("font_size", 11)
	delivery_feedback_detail.add_theme_color_override("font_color", Color(0.72, 0.82, 0.93))
	box.add_child(delivery_feedback_detail)

	delivery_feedback_breakdown = Label.new()
	delivery_feedback_breakdown.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	delivery_feedback_breakdown.clip_text = true
	delivery_feedback_breakdown.max_lines_visible = 1
	delivery_feedback_breakdown.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	delivery_feedback_breakdown.add_theme_font_size_override("font_size", 10)
	delivery_feedback_breakdown.add_theme_color_override("font_color", Color(0.56, 0.92, 0.88))
	box.add_child(delivery_feedback_breakdown)
	_set_delivery_feedback_idle()

func _build_feedback_audio() -> void:
	feedback_sfx_player = AudioStreamPlayer.new()
	feedback_sfx_player.name = "FeedbackSfxPlayer"
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 44100.0
	stream.buffer_length = 0.2
	feedback_sfx_player.stream = stream
	feedback_sfx_player.volume_db = -12.0
	add_child(feedback_sfx_player)

func _refresh_all() -> void:
	_refresh_money()
	_refresh_slots()
	_refresh_build_status()
	_refresh_order_status()
	_refresh_progression_status()
	_refresh_tutorial_status()
	_refresh_os_status()
	_refresh_monitor_ui()
	_refresh_score_status()
	_refresh_order_panel()
	_refresh_inventory()
	_refresh_shop()
	_refresh_catalog_workspace()
	_refresh_task_center()
	_refresh_workbench_footer()

func _refresh_money() -> void:
	money_label.text = "资金  %d" % money

	if catalog_money_label:
		catalog_money_label.text = "资金  %d" % money
	_refresh_catalog_workspace()

func _refresh_slots() -> void:
	building_panel.update_slots(installed)

func _refresh_build_status() -> void:
	var missing := get_missing_required_slots()
	building_panel.update_build_status(required_slots.size() - missing.size(), required_slots.size(), _slot_labels(missing), powered_on, system_booted)

func _refresh_order_status() -> void:
	if order_label == null:
		return
	var order := get_current_order()
	_refresh_home_order_summary(order)
	return
	if order.is_empty():
		order_label.text = "当前没有可接订单，首发订单已全部完成。"
		if order_state_chip_label:
			order_state_chip_label.text = "暂无订单"
		if order_progress_bar:
			order_progress_bar.value = 0
		_refresh_workbench_footer()
		return
	order_label.text = "当前订单：%s / %s / D%d / 奖励 %d / 客户：%s\n硬件：%s | 软件：%s" % [
		order.name,
		str(order.get("customer_type", "客户")),
		int(order.get("difficulty", 1)),
		int(order.reward),
		str(order.get("customer", "客户")),
		_format_order_requirements(order),
		_format_software_tasks(order),
	]
	if order_state_chip_label:
		order_state_chip_label.text = _home_order_state_text(order)
	if order_progress_bar:
		order_progress_bar.value = _home_order_completion_percent()
	_refresh_workbench_footer()

func _refresh_progression_status() -> void:
	if progression_label == null:
		return
	var total := order_defs.size()
	var completed := completed_order_ids.size()
	var next_unlock := _next_unlock_requirement()
	if completed >= total:
		progression_label.text = "职业进度：%d / %d，首发订单全部完成。" % [completed, total]
	elif next_unlock <= completed:
		progression_label.text = "职业进度：%d / %d，可接订单 %d。" % [completed, total, available_order_indices.size()]
	else:
		progression_label.text = "职业进度：%d / %d，可接订单 %d；再完成 %d 单解锁新客户。" % [completed, total, available_order_indices.size(), next_unlock - completed]
	_refresh_workbench_footer()

func _refresh_order_panel() -> void:
	if order_panel == null:
		return
	order_panel.update_orders(order_defs, available_order_indices, current_order_index)
	if order_desk_overlay != null and order_desk_overlay.visible:
		_refresh_order_desk()

func _refresh_inventory() -> void:
	inventory_panel.update_items(inventory, current_filter)

	if catalog_inventory_panel:
		catalog_inventory_panel.update_items(inventory, current_filter)

func _refresh_shop() -> void:
	shop_panel.update_items(component_database.get_all_components())

	if catalog_shop_panel:
		catalog_shop_panel.update_items(component_database.get_all_components())
		catalog_shop_panel.set_type_filter(current_filter)
	_refresh_catalog_workspace()

func _refresh_catalog_workspace() -> void:
	if catalog_workspace_panel == null:
		return
	var slot_text := "全部类型"
	if current_filter != "":
		slot_text = component_database.display_type(current_filter)
	var order := get_current_order()
	var order_name := "暂无订单"
	if not order.is_empty():
		order_name = str(order.get("name", "当前订单"))
	var matching_inventory := 0
	for item in inventory:
		if current_filter == "" or str(item.get("type_key", "")) == current_filter:
			matching_inventory += 1
	var missing := get_missing_required_slots()
	var next_action := _task_center_next_action()
	var next_title := str(next_action.get("title", "查看订单"))
	var next_detail := str(next_action.get("detail", "先查看当前订单需求。"))
	var pressure_text := "订单压力：低"
	var pressure_color := Color(0.36, 1.0, 0.66)
	if order.is_empty():
		pressure_text = "订单压力：无订单"
		pressure_color = Color(0.52, 0.66, 0.82)
	elif not missing.is_empty():
		pressure_text = "订单压力：缺 %d 个硬件槽" % missing.size()
		pressure_color = Color(1.0, 0.72, 0.28)
	else:
		var reasons := validate_current_order()
		if not reasons.is_empty():
			pressure_text = "订单压力：待处理 %d 项" % reasons.size()
			pressure_color = Color(1.0, 0.72, 0.28)
		else:
			pressure_text = "订单压力：可交付"
			pressure_color = Color(0.36, 1.0, 0.66)
	if catalog_workspace_summary_label:
		catalog_workspace_summary_label.text = "当前按 %s 选件。订单、库存和推荐动作已同步，市场与仓库在全屏目录中操作。" % slot_text
	if catalog_workspace_slot_chip_label:
		catalog_workspace_slot_chip_label.text = "槽位 %s" % slot_text
	if catalog_workspace_order_chip_label:
		catalog_workspace_order_chip_label.text = "订单 %s" % order_name
	if catalog_workspace_inventory_chip_label:
		catalog_workspace_inventory_chip_label.text = "仓库匹配 %d 件 / 总计 %d 件" % [matching_inventory, inventory.size()]
	if catalog_workspace_state_label:
		var state_text := "当前状态：%s" % ("未接订单" if order.is_empty() else ("缺少 %s" % "、".join(_slot_labels(missing)) if not missing.is_empty() else _home_order_state_text(order)))
		catalog_workspace_state_label.text = state_text
	if catalog_workspace_pressure_chip_label:
		catalog_workspace_pressure_chip_label.text = pressure_text
		var pressure_panel := catalog_workspace_pressure_chip_label.get_parent()
		if pressure_panel is PanelContainer:
			pressure_panel.add_theme_stylebox_override("panel", _catalog_stylebox(Color(pressure_color.r * 0.10, pressure_color.g * 0.10, pressure_color.b * 0.10, 0.92), pressure_color, 8, 6))
	if catalog_workspace_next_action_label:
		catalog_workspace_next_action_label.text = "推荐操作：%s | %s" % [next_title, next_detail]
		catalog_workspace_next_action_label.tooltip_text = next_detail
	if catalog_workspace_shop_button:
		catalog_workspace_shop_button.text = "打开配件市场"
		catalog_workspace_shop_button.tooltip_text = "按当前槽位筛选购买配件"
	if catalog_workspace_inventory_button:
		catalog_workspace_inventory_button.text = "打开仓库"
		catalog_workspace_inventory_button.tooltip_text = "安装或出售已有配件"

func _tutorial_steps() -> Array[Dictionary]:
	return [
		{"title": "查看订单", "detail": "先查看当前订单的客户、奖励和配件等级要求。", "action": "查看订单"},
		{"title": "筛选空槽", "detail": "选中左侧空槽，商店会自动筛选对应类型的配件。", "action": "选择下一个空槽"},
		{"title": "继续选件", "detail": "购买并安装全部核心配件；也可以从背包拖到槽位。", "action": "继续选件"},
		{"title": "完成装机", "detail": "核心配件齐全后，运行兼容性与开机检查。", "action": "完成检查"},
		{"title": "启动电脑", "detail": "检查通过后，按下电源按钮进入模拟系统。", "action": "按电源"},
		{"title": "打开系统", "detail": "放大显示器，再进入 Driver Tool 使用 OS 层。", "action": "打开 Driver Tool"},
		{"title": "安装驱动", "detail": "依次扫描设备、安装驱动，并重启验证。", "action": _tutorial_driver_action_text()},
		{"title": "跑分验证", "detail": "运行一次 Benchmark，记录交付前性能结果。", "action": "跑分"},
		{"title": "交付订单", "detail": "完成所有检查后交付订单并查看最终评分。", "action": "交付订单"},
		{"title": "首单完成", "detail": "首单已完成，可以继续接更高难度订单。", "action": "继续接单"},
	]

func _tutorial_step_data(step_index: int) -> Dictionary:
	var steps := _tutorial_steps()
	if steps.is_empty():
		return {}
	return steps[clampi(step_index, 0, steps.size() - 1)]

func _workflow_blocker_text(step_index: int) -> String:
	if tutorial_completed:
		return "阻塞：无，首单已完成"
	if step_index == 0:
		return "阻塞：先查看订单需求"
	if step_index <= 2:
		var missing := get_missing_required_slots()
		if not missing.is_empty():
			return "阻塞：缺少 %s" % " / ".join(_slot_labels(missing))
	if not powered_on:
		return "阻塞：先通过开机检查"
	if not system_booted:
		return "阻塞：先按电源进入模拟系统"
	if not driver_scan_completed:
		return "阻塞：先打开 Driver Tool 扫描设备"
	if not drivers_installed or os_restart_required:
		return "阻塞：驱动尚未完成验证"
	if not benchmark_completed:
		return "阻塞：先跑分验证"
	var reasons := validate_current_order()
	if not reasons.is_empty():
		return "阻塞：%s" % reasons[0]
	return "阻塞：无，当前订单可交付"

func _refresh_tutorial_status() -> void:
	if tutorial_label == null or tutorial_progress_label == null or tutorial_action_button == null:
		return
	_sync_tutorial_step()
	_refresh_tutorial_status_v2()
	return
	var steps := [
		{"text": "先查看当前订单的客户、奖励和配件等级要求。", "action": "查看订单"},
		{"text": "选择左侧空槽，商店会自动筛选对应类型的配件。", "action": "选择下一个空槽"},
		{"text": "购买并安装全部核心配件；也可以从背包拖到槽位。", "action": "继续选件"},
		{"text": "核心配件齐全后，运行兼容性与开机检测。", "action": "完成检测"},
		{"text": "检测通过，按下电源按钮进入模拟操作系统。", "action": "启动电脑"},
		{"text": "打开最大化显示器，并进入 Driver Tool。", "action": "打开 Driver Tool"},
		{"text": "依次扫描设备、安装驱动并重启验证。", "action": _tutorial_driver_action_text()},
		{"text": "运行一次 Benchmark，记录交付前性能结果。", "action": "运行跑分"},
		{"text": "全部检查完成，交付订单并查看最终评分。", "action": "交付订单"},
		{"text": "首单已完成。可以继续接取更高难度订单。", "action": "引导完成"},
	]
	var index := clampi(tutorial_step, 0, steps.size() - 1)
	tutorial_progress_label.text = "新手引导  %d / 9" % mini(index + 1, 9) if index < 9 else "新手引导  已完成"
	tutorial_label.text = str(steps[index].text)
	tutorial_action_button.text = str(steps[index].action)
	tutorial_action_button.disabled = index >= 9
	if task_center_overlay != null and task_center_overlay.visible:
		_refresh_task_center()
	_refresh_workbench_footer()

func _refresh_tutorial_status_v2() -> void:
	var steps := _tutorial_steps()
	if steps.is_empty():
		return
	var index := clampi(tutorial_step, 0, steps.size() - 1)
	var step: Dictionary = steps[index]
	var step_title := str(step.get("title", ""))
	var step_detail := str(step.get("detail", ""))
	var step_action := str(step.get("action", ""))
	tutorial_progress_label.text = "新手引导  %d / 9" % mini(index + 1, 9) if index < 9 else "新手引导  已完成"
	tutorial_label.text = step_detail
	tutorial_action_button.text = step_action
	tutorial_action_button.disabled = index >= 9
	status_label.text = "当前步骤：%s" % step_title
	if progression_label:
		progression_label.text = _workflow_blocker_text(index)
	if task_center_overlay != null and task_center_overlay.visible:
		_refresh_task_center()
	_refresh_home_workbench_footer()

func _refresh_home_workbench_footer() -> void:
	if workbench_footer_summary_label == null:
		return
	var order := get_current_order()
	var order_text := "暂无"
	if not order.is_empty():
		order_text = str(order.get("name", "未命名"))
	var missing := get_missing_required_slots()
	var completion := 0
	if required_slots.size() > 0:
		completion = int(round(float(required_slots.size() - missing.size()) / float(required_slots.size()) * 100.0))
	workbench_footer_summary_label.text = "当前订单：%s | 下一步：%s" % [
		order_text,
		_workbench_next_step_hint(),
	]
	if workbench_footer_completion_chip_label:
		workbench_footer_completion_chip_label.text = "完成度 %d%%" % completion
	if workbench_footer_missing_chip_label:
		workbench_footer_missing_chip_label.text = "缺少 %s" % ("0 项" if missing.is_empty() else "%d 项" % missing.size())
	if workbench_footer_next_chip_label:
		workbench_footer_next_chip_label.text = "下一步 %s" % _workbench_next_step_hint()

func _refresh_home_order_summary(order: Dictionary) -> void:
	if order_label == null:
		return
	if order.is_empty():
		order_label.text = "当前订单：暂无"
		if order_state_chip_label:
			order_state_chip_label.text = "暂无订单"
		if order_progress_bar:
			order_progress_bar.value = 0
		if score_label:
			score_label.text = "交付评分：暂无"
		_refresh_home_workbench_footer()
		return
	order_label.text = "当前订单：%s · D%d · ￥%d" % [
		str(order.get("name", "订单")),
		int(order.get("difficulty", 1)),
		int(order.get("reward", 0)),
	]
	if order_state_chip_label:
		order_state_chip_label.text = _home_order_state_text(order)
	if order_progress_bar:
		order_progress_bar.value = _home_order_completion_percent()
	if score_label:
		var score := calculate_delivery_score()
		score_label.text = "评分 %d/%s" % [int(score.get("score", 0)), str(score.get("grade", "-"))]
	_refresh_home_workbench_footer()

func _refresh_home_system_summary() -> void:
	if os_label == null:
		return
	var state := "已开机" if system_booted else ("待按电源" if powered_on else "未开机")
	os_label.text = "模拟系统：%s" % state
	if os_state_chip_label:
		os_state_chip_label.text = _home_system_state_text()
	if os_progress_bar:
		os_progress_bar.value = get_software_configuration_score()
	_refresh_home_workbench_footer()

func _home_order_completion_percent() -> int:
	if required_slots.is_empty():
		return 0
	var missing := get_missing_required_slots()
	return clampi(int(round(float(required_slots.size() - missing.size()) / float(required_slots.size()) * 100.0)), 0, 100)

func _home_order_state_text(order: Dictionary) -> String:
	if order.is_empty():
		return "暂无订单"
	var reasons := validate_current_order()
	if reasons.is_empty():
		return "可交付"
	if not powered_on:
		return "待检测"
	if not system_booted:
		return "待开机"
	if not driver_scan_completed:
		return "配驱动"
	if not drivers_installed or os_restart_required:
		return "验驱动"
	if _current_order_requires_task("gpu_driver") and not gpu_driver_installed:
		return "GPU 驱动"
	if _current_order_requires_task("benchmark") and not benchmark_completed:
		return "跑分"
	if _current_order_requires_task("stability") and not stability_test_completed:
		return "稳定"
	var score := calculate_delivery_score()
	return "评分 %d/%s" % [
		int(score.get("score", 0)),
		str(score.get("grade", "-")),
	]

func _home_system_state_text() -> String:
	var software_score := get_software_configuration_score()
	if not powered_on:
		return "未开机"
	if not system_booted:
		return "待按电源 · 软件 %d/100" % software_score
	return "已启动 · 软件 %d/100" % software_score

func _sync_tutorial_step() -> void:
	if tutorial_completed:
		tutorial_step = 9
	elif not tutorial_order_viewed:
		tutorial_step = 0
	elif not get_missing_required_slots().is_empty():
		tutorial_step = 1 if current_filter == "" else 2
	elif not powered_on:
		tutorial_step = 3
	elif not system_booted:
		tutorial_step = 4
	elif monitor_app_key != "Driver Tool" and not driver_scan_completed:
		tutorial_step = 5
	elif not driver_scan_completed or not drivers_installed or os_restart_required:
		tutorial_step = 6
	elif not benchmark_completed:
		tutorial_step = 7
	else:
		tutorial_step = 8

func _tutorial_driver_action_text() -> String:
	if not driver_scan_completed:
		return "扫描设备"
	if not drivers_installed:
		return "安装驱动"
	if os_restart_required:
		return "重启验证"
	return "驱动已验证"

func _on_tutorial_action_pressed() -> void:
	_sync_tutorial_step()
	match tutorial_step:
		0:
			tutorial_order_viewed = true
			open_order_desk()
			status_label.text = "已打开订单页，请确认当前订单要求。"
		1, 2:
			var missing := get_missing_required_slots()
			if not missing.is_empty():
				_on_slot_pressed(missing[0])
				main_tabs.current_tab = 1
				open_shop_overlay()
		3:
			_on_finish_pressed()
		4:
			_on_power_button_pressed()
		5:
			_on_open_monitor_pressed()
			_on_monitor_driver_tool_pressed()
		6:
			if not driver_scan_completed:
				_on_driver_scan_pressed()
			elif not drivers_installed:
				_on_driver_install_pressed()
			elif os_restart_required:
				_on_driver_restart_pressed()
		7:
			_on_os_benchmark_pressed()
		8:
			_on_deliver_pressed()
	_refresh_tutorial_status()

func _refresh_os_status() -> void:
	if os_label == null:
		return
	_refresh_home_system_summary()
	return
	var latest := "暂无系统日志"
	if not os_log.is_empty():
		latest = os_log[os_log.size() - 1]
	var state := "已启动" if system_booted else ("检测通过，待按电源" if powered_on else "未启动")
	os_label.text = "模拟系统：%s / 当前：%s\n%s" % [state, os_app, latest]
	if os_state_chip_label:
		os_state_chip_label.text = _home_system_state_text()
	if os_progress_bar:
		os_progress_bar.value = get_software_configuration_score()

	if task_center_overlay != null and task_center_overlay.visible:
		_refresh_task_center()
	_refresh_workbench_footer()

func _refresh_workbench_footer() -> void:
	if workbench_footer_summary_label == null:
		return
	_refresh_home_workbench_footer()
	return
	var order := get_current_order()
	var order_text := "当前订单：暂无"
	if not order.is_empty():
		order_text = "当前订单：%s / 奖励 %d / 软件 %s" % [
			str(order.get("name", "未命名")),
			int(order.get("reward", 0)),
			_format_software_tasks(order),
		]
	var missing := get_missing_required_slots()
	var completion := 0
	if required_slots.size() > 0:
		completion = int(round(float(required_slots.size() - missing.size()) / float(required_slots.size()) * 100.0))
	var missing_text := "核心配件齐全" if missing.is_empty() else "缺少：%s" % " / ".join(missing)
	workbench_footer_summary_label.text = "%s | 完成度 %d%% | %s | 下一步：%s" % [
		order_text,
		completion,
		missing_text,
		_workbench_next_step_hint(),
	]

func _workbench_next_step_hint() -> String:
	if not tutorial_order_viewed:
		return "先看订单"
	if not get_missing_required_slots().is_empty():
		return "选槽安装"
	if not powered_on:
		return "完成检测"
	if not system_booted:
		return "按电源按钮"
	if not driver_scan_completed:
		return "打开 Driver Tool"
	if not drivers_installed or os_restart_required:
		return "完成驱动流程"
	if not benchmark_completed:
		return "运行跑分"
	return "交付订单"

func _refresh_monitor_ui() -> void:
	if monitor_overlay == null or monitor_app_title == null or monitor_content_label == null:
		return
	for button in monitor_app_buttons:
		button.disabled = not system_booted and button.text != "Shutdown"
	var latest := "No OS log yet."
	if not os_log.is_empty():
		latest = os_log[os_log.size() - 1]
	var state := "Booted" if system_booted else ("Ready for power" if powered_on else "No signal")
	if monitor_status_label:
		monitor_status_label.text = "%s | %s" % [state, latest]
	if not system_booted:
		if monitor_action_row:
			monitor_action_row.visible = false
		if monitor_task_board_label:
			monitor_task_board_label.text = "OS 任务板\n等待开机信号。完成硬件检查并按电源后可进入软件配置。"
		monitor_app_title.text = "No signal"
		monitor_content_label.text = "No signal\n\nThe monitor is enlarged and waiting for a booted PC.\n\n1. Finish hardware check.\n2. Press Power.\n3. Open Max Monitor again to use the OS layer."
		return
	monitor_app_title.text = monitor_app_key
	if monitor_task_board_label:
		monitor_task_board_label.text = _monitor_task_board_text()
	_refresh_monitor_action_row()
	monitor_content_label.text = _monitor_content_for_app(monitor_app_key)

func _refresh_monitor_action_row() -> void:
	if monitor_action_row == null:
		return
	var in_driver_tool := monitor_app_key == "Driver Tool"
	var in_files := monitor_app_key == "Files"
	monitor_action_row.visible = in_driver_tool or in_files
	var driver_buttons: Array[Button] = [driver_scan_button, driver_install_button, driver_restart_button, gpu_driver_button]
	for button in driver_buttons:
		if button:
			button.visible = in_driver_tool
	var file_buttons: Array[Button] = [file_order_button, file_driver_button, file_benchmark_button, file_preflight_button]
	for button in file_buttons:
		if button:
			button.visible = in_files
	if in_files:
		_style_monitor_file_button(file_order_button, monitor_file_key == "order")
		_style_monitor_file_button(file_driver_button, monitor_file_key == "driver")
		_style_monitor_file_button(file_benchmark_button, monitor_file_key == "benchmark")
		_style_monitor_file_button(file_preflight_button, monitor_file_key == "preflight")
	if not in_driver_tool:
		return
	var has_blockers := _driver_has_blockers()
	if driver_scan_button:
		driver_scan_button.disabled = not system_booted
	if driver_install_button:
		driver_install_button.disabled = not system_booted or not driver_scan_completed or has_blockers or drivers_installed
	if driver_restart_button:
		driver_restart_button.disabled = not system_booted or not os_restart_required
	if gpu_driver_button:
		gpu_driver_button.visible = _current_order_requires_task("gpu_driver")
		gpu_driver_button.disabled = not system_booted or not drivers_installed or os_restart_required or gpu_driver_installed or not installed.has("VideoCard")

func _monitor_content_for_app(app_name: String) -> String:
	match app_name:
		"System Info", "绯荤粺淇℃伅":
			return _monitor_system_info_text()
		"Benchmark", "璺戝垎宸ュ叿":
			return _monitor_benchmark_text()
		"Stability Test":
			return _monitor_stability_text()
		"Driver Tool":
			return _monitor_driver_text()
		"Files":
			return _monitor_files_text()
		"Desktop", "妗岄潰":
			return _monitor_desktop_text()
		_:
			return _monitor_desktop_text()

func _monitor_desktop_text() -> String:
	return "Desktop apps\n\nSystem Info: inspect installed parts.\nBenchmark: run a quick score.\nStability Test: verify sustained operation.\nDriver Tool: check devices and install required drivers.\nFiles: browse order, benchmark, driver, and delivery reports.\n\n%s" % _monitor_next_os_action_text()

func _monitor_task_board_text() -> String:
	var order := get_current_order()
	var tasks := _software_tasks(order)
	var task_parts: Array[String] = []
	for task in tasks:
		var progress := int(round(_software_task_progress(task) * 100.0))
		var state := "完成" if _is_software_task_complete(task) else "待办"
		task_parts.append("%s %s %d%%" % [_software_task_label(task), state, progress])
	if task_parts.is_empty():
		task_parts.append("无软件任务")
	return "OS 任务板 | %s | 软件 %d/100\n下一步：%s\n%s" % [
		str(order.get("name", "无订单")),
		get_software_configuration_score(),
		_monitor_next_os_action_text(),
		" / ".join(task_parts),
	]

func _monitor_next_os_action_text() -> String:
	if not system_booted:
		return "先按电源进入模拟系统"
	if not driver_scan_completed:
		return "Driver Tool 扫描设备"
	if _driver_has_blockers():
		return "修复硬件阻塞后重新扫描"
	if not drivers_installed:
		return "安装基础驱动"
	if os_restart_required:
		return "重启 OS 验证驱动"
	if _current_order_requires_task("gpu_driver") and not gpu_driver_installed:
		return "安装 GPU 驱动"
	if _current_order_requires_task("benchmark") and not benchmark_completed:
		return "运行 Benchmark"
	if _current_order_requires_task("stability") and not stability_test_completed:
		return "运行 Stability Test"
	return "软件配置完成，可回到任务中心交付"

func _monitor_system_info_text() -> String:
	var lines: Array[String] = ["Installed hardware"]
	if installed.is_empty():
		lines.append("- No installed parts.")
	for slot in required_slots:
		if installed.has(slot):
			var item: Dictionary = installed[slot]
			lines.append("- %s: %s / Lv.%d / $%d" % [
				component_database.display_type(slot),
				str(item.get("name", "")),
				int(item.get("tier", 0)),
				int(item.get("price", 0)),
			])
		else:
			lines.append("- %s: missing" % component_database.display_type(slot))
	lines.append("")
	lines.append("Power draw estimate: %dW" % _estimated_power_draw())
	return "\n".join(lines)

func _monitor_benchmark_text() -> String:
	var score := _benchmark_score()
	var delivery := calculate_delivery_score()
	var software := int(delivery.get("software", 0))
	var software_note := "Software configuration verified. Delivery gate passed." if software == 100 else "Complete Driver Tool scan, install, and restart verification to reach 100 software setup."
	return "Benchmark complete\n\nSynthetic score: %d\nDelivery grade preview: %s (%d)\nPerformance: %d\nCompatibility: %d\nBoot: %d\nSoftware setup: %d\n\n%s" % [
		score,
		str(delivery.get("grade", "-")),
		int(delivery.get("score", 0)),
		int(delivery.get("performance", 0)),
		int(delivery.get("compatibility", 0)),
		int(delivery.get("boot", 0)),
		software,
		software_note,
	]

func _monitor_stability_text() -> String:
	if not stability_test_completed:
		return "Stability Test\n\nNo completed test for this build.\n\nRun Stability Test from the dock after drivers are verified."
	return "Stability Test passed\n\nCPU load: stable\nGPU load: stable\nMemory check: passed\nThermal simulation: within limit\n\nThe stability requirement is ready for delivery."

func _monitor_driver_text() -> String:
	var lines: Array[String] = ["Driver Tool"]
	lines.append("Status: %s" % _driver_status_text())
	lines.append("Detected slots: %d/%d" % [installed.size(), required_slots.size()])
	lines.append("")
	if not driver_scan_completed:
		lines.append("Run Scan devices to build a device report.")
	elif not driver_last_report.is_empty():
		lines.append_array(driver_last_report)
	if driver_scan_completed and not _driver_has_blockers():
		if drivers_installed and os_restart_required:
			lines.append("")
			lines.append("Drivers are staged. Restart OS to verify the installation.")
		elif drivers_installed:
			lines.append("")
			lines.append("Driver state: Verified.")
		else:
			lines.append("")
			lines.append("No blockers found. Install drivers to complete the software setup.")
	if _current_order_requires_task("gpu_driver"):
		lines.append("")
		lines.append("GPU driver: installed." if gpu_driver_installed else "GPU driver: required by this order.")
	lines.append("")
	lines.append("DLC hook: driver packages, corrupted installs, BIOS updates, and repair jobs can live here.")
	return "\n".join(lines)

func _driver_status_text() -> String:
	if not driver_scan_completed:
		return "Not scanned"
	if _driver_has_blockers():
		return "Hardware blockers found"
	if os_restart_required:
		return "Restart required"
	if drivers_installed:
		return "Verified"
	return "Ready to install"

func _driver_has_blockers() -> bool:
	return not get_missing_required_slots().is_empty() or not get_compatibility_issues().is_empty()

func _build_driver_report() -> Array[String]:
	var lines: Array[String] = []
	var missing := get_missing_required_slots()
	var issues := get_compatibility_issues()
	if missing.is_empty() and issues.is_empty():
		lines.append("- All core devices are detected.")
		lines.append("- Compatibility check: clear.")
		lines.append("- Driver package: YellowFish Universal Pack ready.")
	else:
		if not missing.is_empty():
			lines.append("- Missing devices: %s" % ", ".join(_slot_labels(missing)))
		for issue in issues:
			lines.append("- Compatibility issue: %s" % issue)
	return lines

func _monitor_files_text() -> String:
	match monitor_file_key:
		"driver":
			return _monitor_driver_report_file_text()
		"benchmark":
			return _monitor_benchmark_report_file_text()
		"preflight":
			return _monitor_preflight_report_file_text()
		_:
			return _monitor_order_report_file_text()

func _monitor_file_header(file_name: String) -> Array[String]:
	return [
		"C:/Workbench",
		"- /orders/current_order.txt",
		"- /benchmarks/latest_score.log",
		"- /drivers/device_report.sys",
		"- /delivery/preflight_report.txt",
		"",
		"Selected: %s" % file_name,
		"Software setup: %d/100" % get_software_configuration_score(),
		"",
	]

func _monitor_order_report_file_text() -> String:
	var order := get_current_order()
	var lines := _monitor_file_header("current_order.txt")
	lines.append("[current_order.txt]")
	lines.append("Order: %s" % str(order.get("name", "None")))
	lines.append("Customer: %s / %s" % [str(order.get("customer", "客户")), str(order.get("customer_type", "客户"))])
	lines.append("Reward: $%d / Estimated: %d min" % [int(order.get("reward", 0)), int(order.get("estimated_minutes", 0))])
	lines.append("Requirements: %s" % _format_order_requirements(order))
	lines.append("Software tasks: %s" % _format_software_tasks(order))
	lines.append("Funds: $%d" % money)
	lines.append("Installed slots: %d/%d" % [installed.size(), required_slots.size()])
	return "\n".join(lines)

func _monitor_driver_report_file_text() -> String:
	var lines := _monitor_file_header("device_report.sys")
	lines.append("[device_report.sys]")
	lines.append("Driver status: %s" % _driver_status_text())
	lines.append("Detected slots: %d/%d" % [installed.size(), required_slots.size()])
	if driver_scan_completed and not driver_last_report.is_empty():
		lines.append_array(driver_last_report)
	else:
		lines.append("- No scan report. Open Driver Tool and scan devices.")
	if _current_order_requires_task("gpu_driver"):
		lines.append("GPU driver: %s" % ("installed" if gpu_driver_installed else "required"))
	return "\n".join(lines)

func _monitor_benchmark_report_file_text() -> String:
	var lines := _monitor_file_header("latest_score.log")
	lines.append("[latest_score.log]")
	lines.append("Benchmark: %s" % ("completed %d" % _benchmark_score() if benchmark_completed else "not run"))
	lines.append("Stability: %s" % ("passed" if stability_test_completed else "not run"))
	var score := calculate_delivery_score()
	lines.append("Delivery preview: %s / %d" % [str(score.get("grade", "-")), int(score.get("score", 0))])
	lines.append("Performance: %d / Compatibility: %d / Boot: %d / Software: %d" % [
		int(score.get("performance", 0)),
		int(score.get("compatibility", 0)),
		int(score.get("boot", 0)),
		int(score.get("software", 0)),
	])
	return "\n".join(lines)

func _monitor_preflight_report_file_text() -> String:
	var lines := _monitor_file_header("preflight_report.txt")
	lines.append("[preflight_report.txt]")
	var reasons := validate_current_order()
	lines.append("Delivery: %s" % ("ready" if reasons.is_empty() else "blocked"))
	if reasons.is_empty():
		var score := calculate_delivery_score()
		lines.append("Preview: %s / %d" % [str(score.get("grade", "-")), int(score.get("score", 0))])
		lines.append("No blockers found. This order can be delivered.")
	else:
		lines.append("Blockers: %s" % _summarize_delivery_reasons(reasons))
		for reason in reasons.slice(0, 6):
			lines.append("- %s" % str(reason))
	return "\n".join(lines)

func _show_action_feedback(kind: String, title: String, detail: String, animate: bool = true) -> void:
	if action_feedback_panel == null:
		return
	action_feedback_panel.add_theme_stylebox_override("panel", _action_feedback_style(kind))
	action_feedback_title.text = title
	action_feedback_detail.text = detail
	if animate:
		_pulse_action_feedback()

func _pulse_action_feedback() -> void:
	if action_feedback_panel == null:
		return
	if action_feedback_tween:
		action_feedback_tween.kill()
	action_feedback_panel.modulate = Color(1.14, 1.14, 1.05, 1.0)
	action_feedback_tween = create_tween()
	action_feedback_tween.tween_property(action_feedback_panel, "modulate", Color.WHITE, 0.22)

func _action_feedback_style(kind: String) -> StyleBoxFlat:
	var bg := Color(0.018, 0.030, 0.092, 0.94)
	var border := Color(0.22, 0.44, 0.78, 0.90)
	match kind:
		"success":
			bg = Color(0.018, 0.085, 0.070, 0.95)
			border = Color(0.22, 0.95, 0.72, 0.95)
		"error":
			bg = Color(0.115, 0.035, 0.060, 0.96)
			border = Color(1.00, 0.36, 0.42, 0.95)
		"warning":
			bg = Color(0.105, 0.072, 0.028, 0.96)
			border = Color(1.00, 0.72, 0.24, 0.95)
		"reward":
			bg = Color(0.090, 0.070, 0.018, 0.96)
			border = Color(1.00, 0.82, 0.30, 0.95)
		"software":
			bg = Color(0.012, 0.075, 0.092, 0.96)
			border = Color(0.28, 0.92, 1.00, 0.95)
		"action":
			bg = Color(0.040, 0.038, 0.120, 0.96)
			border = Color(0.62, 0.48, 1.00, 0.95)
	var box := _stylebox(bg, border, 6)
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box

func _play_operation_animation(kind: String, slot: String = "") -> void:
	last_operation_animation = kind
	operation_animation_count += 1
	match kind:
		"purchase":
			_pulse_money_label(Color(0.75, 0.95, 1.22, 1.0))
		"install":
			if building_panel:
				building_panel.pulse_slot(slot, true)
				building_panel.pulse_progress(true)
			_pulse_status_label(Color(0.68, 1.18, 0.86, 1.0))
		"blocked":
			if building_panel and slot != "":
				building_panel.pulse_slot(slot, false)
			_pulse_status_label(Color(1.18, 0.62, 0.52, 1.0))
		"power":
			if building_panel:
				building_panel.pulse_power_status(true)
			_pulse_status_label(Color(0.70, 1.16, 0.92, 1.0))
		"software":
			_pulse_os_label(Color(0.62, 1.12, 1.18, 1.0))
		"benchmark":
			_pulse_os_label(Color(0.90, 1.18, 0.62, 1.0))
		"delivery":
			_pulse_money_label(Color(1.22, 1.02, 0.50, 1.0))
			_pulse_status_label(Color(1.16, 1.00, 0.62, 1.0))
		"reward":
			_pulse_money_label(Color(1.18, 1.06, 0.56, 1.0))
			_pulse_status_label(Color(1.08, 1.00, 0.68, 1.0))
		"error":
			_pulse_status_label(Color(1.18, 0.56, 0.54, 1.0))

func _pulse_money_label(tint: Color) -> void:
	if money_label == null:
		return
	if money_feedback_tween:
		money_feedback_tween.kill()
	money_label.modulate = tint
	money_feedback_tween = create_tween()
	money_feedback_tween.tween_property(money_label, "modulate", Color.WHITE, 0.28)

func _pulse_status_label(tint: Color) -> void:
	if status_label == null:
		return
	if status_feedback_tween:
		status_feedback_tween.kill()
	status_label.modulate = tint
	status_feedback_tween = create_tween()
	status_feedback_tween.tween_property(status_label, "modulate", Color.WHITE, 0.28)

func _pulse_os_label(tint: Color) -> void:
	if os_label == null:
		return
	if os_feedback_tween:
		os_feedback_tween.kill()
	os_label.modulate = tint
	os_feedback_tween = create_tween()
	os_feedback_tween.tween_property(os_label, "modulate", Color.WHITE, 0.34)
	if monitor_content_label:
		monitor_content_label.modulate = tint
		os_feedback_tween.parallel().tween_property(monitor_content_label, "modulate", Color.WHITE, 0.34)

func _set_delivery_feedback_idle() -> void:
	if delivery_feedback_panel == null:
		return
	delivery_feedback_panel.add_theme_stylebox_override("panel", _delivery_feedback_style("idle"))
	delivery_feedback_title.text = "订单回执：待交付"
	delivery_feedback_detail.text = "当前装机尚未形成客户评分。"
	delivery_feedback_breakdown.text = "性能 -- / 预算 -- / 兼容 -- / 启动 -- / 软件 --"

func _show_delivery_feedback(success: bool, score: Dictionary = {}, reasons: Array = [], animate: bool = true) -> void:
	if delivery_feedback_panel == null:
		return
	if success:
		var grade := str(score.get("grade", "-"))
		var order_name := str(score.get("order_name", "当前订单"))
		delivery_feedback_panel.add_theme_stylebox_override("panel", _delivery_feedback_style("success"))
		delivery_feedback_title.text = "订单回执：%s  评分 %d / %s" % [
			order_name,
			int(score.get("score", 0)),
			grade,
		]
		delivery_feedback_detail.text = "奖励 +%d；软件配置 %d；跑分 %d。" % [
			int(score.get("reward", 0)),
			int(score.get("software", 0)),
			int(score.get("benchmark", 0)),
		]
		delivery_feedback_breakdown.text = "性能 %d / 预算 %d / 兼容 %d / 启动 %d / 软件 %d" % [
			int(score.get("performance", 0)),
			int(score.get("budget", 0)),
			int(score.get("compatibility", 0)),
			int(score.get("boot", 0)),
			int(score.get("software", 0)),
		]
	else:
		delivery_feedback_panel.add_theme_stylebox_override("panel", _delivery_feedback_style("error"))
		delivery_feedback_title.text = "订单回执：未通过交付前检查"
		delivery_feedback_detail.text = _summarize_delivery_reasons(reasons)
		delivery_feedback_breakdown.text = "待处理 %d 项；修复后重新交付。" % reasons.size()
	if animate:
		_pulse_delivery_feedback()

func _summarize_delivery_reasons(reasons: Array) -> String:
	if reasons.is_empty():
		return "没有可交付的当前订单。"
	var clipped: Array[String] = []
	for index in range(mini(2, reasons.size())):
		clipped.append(str(reasons[index]))
	var summary := "；".join(clipped)
	if reasons.size() > clipped.size():
		summary += "；另有 %d 项" % (reasons.size() - clipped.size())
	return summary

func _pulse_delivery_feedback() -> void:
	if delivery_feedback_panel == null:
		return
	if delivery_feedback_tween:
		delivery_feedback_tween.kill()
	delivery_feedback_panel.modulate = Color(1.18, 1.18, 1.08, 1.0)
	delivery_feedback_tween = create_tween()
	delivery_feedback_tween.tween_property(delivery_feedback_panel, "modulate", Color.WHITE, 0.24)

func _delivery_feedback_style(state: String) -> StyleBoxFlat:
	match state:
		"success":
			return _stylebox(Color(0.02, 0.09, 0.10, 0.94), Color(0.20, 0.95, 0.72), 6)
		"error":
			return _stylebox(Color(0.12, 0.035, 0.075, 0.95), Color(1.0, 0.38, 0.42), 6)
		_:
			return _stylebox(Color(0.025, 0.04, 0.12, 0.92), Color(0.22, 0.43, 0.78), 6)

func _play_feedback_sound(kind: String) -> void:
	if feedback_sfx_player == null or DisplayServer.get_name() == "headless":
		return
	feedback_sfx_player.stop()
	feedback_sfx_player.play()
	var playback := feedback_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var tones: Array = []
	match kind:
		"success":
			tones = [[560.0, 0.045], [820.0, 0.085]]
		"error":
			tones = [[260.0, 0.075], [180.0, 0.11]]
		"action":
			tones = [[420.0, 0.055]]
		"power":
			tones = [[180.0, 0.06], [420.0, 0.09]]
		_:
			tones = [[520.0, 0.05]]
	var mix_rate := 44100.0
	for tone in tones:
		var frequency := float(tone[0])
		var frames := int(mix_rate * float(tone[1]))
		for frame in range(frames):
			var t := float(frame) / mix_rate
			var envelope := 1.0 - (float(frame) / float(maxi(frames, 1)))
			var sample := sin(TAU * frequency * t) * 0.18 * envelope
			playback.push_frame(Vector2(sample, sample))

func _refresh_score_status() -> void:
	if score_label == null:
		return
	if last_delivery_score.is_empty():
		var order := get_current_order()
		if order.is_empty():
			score_label.text = "交付评分：暂无"
		else:
			score_label.text = "交付评分：待生成"
		_set_delivery_feedback_idle()
		return
	score_label.text = "交付评分 %d/%s" % [
		int(last_delivery_score.get("score", 0)),
		str(last_delivery_score.get("grade", "-")),
	]
	_show_delivery_feedback(true, last_delivery_score, [], false)

func _on_slot_pressed(slot: String) -> void:
	current_filter = slot
	building_panel.set_active_slot(slot)
	shop_panel.set_type_filter(slot)
	if catalog_shop_panel:
		catalog_shop_panel.set_type_filter(slot)
	if catalog_inventory_panel:
		catalog_inventory_panel.update_items(inventory, current_filter)
	_refresh_inventory()
	status_label.text = "已筛选 %s：可从商店购买，或从背包安装。" % component_database.display_type(slot)
	_show_action_feedback("action", "已选择槽位", "当前筛选：%s。商店和背包已同步到该类型。" % component_database.display_type(slot))
	_refresh_tutorial_status()

func _on_shop_item_selected(item: Dictionary) -> void:
	if money < item.price:
		status_label.text = "资金不足，无法购买：%s" % item.name
		_show_action_feedback("error", "购买失败", "需要 ￥%d，当前资金 ￥%d。" % [int(item.price), money])
		_play_operation_animation("error")
		_play_feedback_sound("error")
		return
	money -= item.price
	_add_to_inventory(item)
	_update_tutorial_step(1)
	status_label.text = "已购买：%s" % item.name
	_show_action_feedback("action", "已购买配件", "%s 已加入背包；资金 -￥%d，剩余 ￥%d。" % [str(item.name), int(item.price), money])
	_play_feedback_sound("action")
	_refresh_money()
	_refresh_inventory()
	_refresh_tutorial_status()
	_play_operation_animation("purchase")

func _on_shop_item_quick_install_selected(item: Dictionary) -> void:
	if money < item.price:
		status_label.text = "资金不足，无法购买并安装：%s" % item.name
		_show_action_feedback("error", "购买并安装失败", "需要 ￥%d，当前资金 ￥%d。" % [int(item.price), money])
		_play_operation_animation("error")
		_play_feedback_sound("error")
		return
	var install_issues := can_install_component(item)
	if not install_issues.is_empty():
		status_label.text = "购买并安装已阻止：%s" % "；".join(install_issues)
		_show_action_feedback("warning", "兼容性阻止安装", "；".join(install_issues))
		_play_operation_animation("blocked", str(item.type_key))
		_play_feedback_sound("error")
		return
	money -= item.price
	_install_component(item)
	_update_tutorial_step(2)
	status_label.text = "已购买并安装：%s -> %s" % [
		component_database.display_type(str(item.type_key)),
		item.name,
	]
	_show_action_feedback("success", "购买并安装完成", "%s 已装入 %s；资金 -￥%d，剩余 ￥%d。" % [
		str(item.name),
		component_database.display_type(str(item.type_key)),
		int(item.price),
		money,
	])
	_play_feedback_sound("success")
	_refresh_money()
	_refresh_slots()
	_refresh_build_status()
	_refresh_inventory()
	_refresh_shop()
	_refresh_tutorial_status()
	_refresh_os_status()
	_play_operation_animation("purchase")
	_play_operation_animation("install", str(item.type_key))

func _on_inventory_item_selected(item: Dictionary) -> void:
	_install_from_inventory(item)

func _on_inventory_item_dropped(slot: String, item: Dictionary) -> void:
	if str(item.get("type_key", "")) != slot:
		status_label.text = "拖拽目标不匹配：%s 不能装到 %s" % [
			component_database.display_type(str(item.get("type_key", ""))),
			component_database.display_type(slot),
		]
		_show_action_feedback("error", "拖动安装失败", "%s 不能安装到 %s 槽位。" % [
			component_database.display_type(str(item.get("type_key", ""))),
			component_database.display_type(slot),
		])
		_play_operation_animation("blocked", slot)
		_play_feedback_sound("error")
		return
	_install_from_inventory(item)

func _on_inventory_item_sold(item: Dictionary) -> void:
	if _sell_inventory_item(item):
		_refresh_money()
		_refresh_inventory()
		_refresh_tutorial_status()

func _on_inventory_filter_cleared() -> void:
	current_filter = ""
	building_panel.set_active_slot("")
	shop_panel.clear_filters()
	if catalog_shop_panel:
		catalog_shop_panel.clear_filters()
	if catalog_inventory_panel:
		catalog_inventory_panel.update_items(inventory, current_filter)
	_refresh_inventory()
	status_label.text = "显示全部背包配件"
	_show_action_feedback("action", "背包筛选已清除", "当前显示全部背包配件。")

func _on_slot_menu_requested(slot: String, position: Vector2) -> void:
	if not installed.has(slot):
		return
	_part_menu_slot = slot
	_on_slot_pressed(slot)
	if part_menu:
		part_menu.position = Vector2i(int(position.x), int(position.y))
		part_menu.popup()

func _on_part_menu_id_pressed(id: int) -> void:
	match id:
		0:
			_show_installed_part_details(_part_menu_slot)
		1:
			_uninstall_part(_part_menu_slot)
		2:
			_prepare_part_replacement(_part_menu_slot)

func _show_installed_part_details(slot: String) -> void:
	if not installed.has(slot):
		return
	var item: Dictionary = installed[slot]
	status_label.text = "Part: %s / %s / Lv.%d / $%d" % [
		component_database.display_type(slot),
		str(item.name),
		int(item.tier),
		int(item.price),
	]
	_show_action_feedback("action", "已查看已安装配件", "%s / Lv.%d / ￥%d。" % [
		str(item.name),
		int(item.tier),
		int(item.price),
	])

func _uninstall_part(slot: String) -> bool:
	if not installed.has(slot):
		return false
	var item: Dictionary = installed[slot]
	_add_to_inventory(item)
	installed.erase(slot)
	current_filter = slot
	powered_on = false
	system_booted = false
	os_app = "OFF"
	_reset_driver_state()
	last_delivery_score.clear()
	building_panel.set_active_slot(slot)
	shop_panel.set_type_filter(slot)
	status_label.text = "Uninstalled: %s." % str(item.name)
	_show_action_feedback("warning", "已拆下配件", "%s 已放回背包；相关开机和软件验证需要重做。" % str(item.name))
	_refresh_slots()
	_refresh_build_status()
	_refresh_inventory()
	_refresh_shop()
	_refresh_tutorial_status()
	_refresh_os_status()
	_refresh_score_status()
	return true

func _prepare_part_replacement(slot: String) -> void:
	_on_slot_pressed(slot)
	status_label.text = "Replace: choose another %s in shop or inventory." % component_database.display_type(slot)
	_show_action_feedback("action", "准备更换配件", "请选择新的 %s，安装后会重新检测兼容性。" % component_database.display_type(slot))

func _on_cheat_toggle_pressed() -> void:
	if cheat_panel == null:
		return
	cheat_panel.visible = not cheat_panel.visible

func _on_cheat_add_money_pressed() -> void:
	apply_cheat_money(100000)

func _on_cheat_fill_order_pressed() -> void:
	if apply_cheat_fill_current_order():
		if cheat_panel:
			cheat_panel.visible = false

func _on_cheat_boot_pressed() -> void:
	apply_cheat_boot_pass()
	if cheat_panel:
		cheat_panel.visible = false

func apply_cheat_money(amount: int = 100000) -> int:
	money += amount
	status_label.text = "Cheat: money +%d." % amount
	_refresh_money()
	_refresh_shop()
	return money

func apply_cheat_fill_current_order() -> bool:
	var order := get_current_order()
	if order.is_empty():
		status_label.text = "Cheat: no active order."
		return false
	var previous_money := money
	tutorial_order_viewed = true
	money = max(money, 999999)
	inventory.clear()
	installed.clear()
	current_filter = ""
	powered_on = false
	system_booted = false
	os_app = "OFF"
	_reset_driver_state()
	last_delivery_score.clear()
	if building_panel:
		building_panel.set_active_slot("")

	var failed_slot := _cheat_install_required_parts(order)
	money = previous_money
	if failed_slot != "":
		status_label.text = "Cheat: no compatible part for %s." % component_database.display_type(failed_slot)
		_refresh_all()
		return false

	_update_tutorial_step(2)
	status_label.text = "Cheat: current order build is ready."
	_refresh_all()
	return true

func apply_cheat_boot_pass() -> void:
	powered_on = true
	system_booted = true
	os_app = "Desktop"
	monitor_app_key = "Desktop"
	_append_os_log("Cheat: boot check passed and OS entered.")
	_update_tutorial_step(4)
	status_label.text = "Cheat: boot check passed."
	_refresh_build_status()
	_refresh_tutorial_status()
	_refresh_os_status()
	_refresh_monitor_ui()

func apply_cheat_open_monitor() -> bool:
	apply_cheat_boot_pass()
	_on_open_monitor_pressed()
	return monitor_overlay != null and monitor_overlay.visible

func apply_cheat_complete_driver_flow() -> bool:
	if not apply_cheat_fill_current_order():
		return false
	if not apply_cheat_open_monitor():
		return false
	_on_monitor_driver_tool_pressed()
	_on_driver_scan_pressed()
	if _driver_has_blockers():
		return false
	_on_driver_install_pressed()
	_on_driver_restart_pressed()
	return drivers_installed and not os_restart_required

func _on_finish_pressed() -> void:
	var missing := get_missing_required_slots()
	var compatibility_issues := get_compatibility_issues()
	if missing.is_empty() and compatibility_issues.is_empty():
		powered_on = true
		_update_tutorial_step(3)
		status_label.text = "开机测试通过：电脑可以正常工作。"
		_show_action_feedback("success", "开机检测通过", "核心配件完整，兼容性检查通过，可以按电源进入模拟系统。")
		_play_feedback_sound("success")
	else:
		powered_on = false
		system_booted = false
		os_app = "未开机"
		var reasons: Array[String] = []
		if not missing.is_empty():
			reasons.append("缺少零件：%s" % "、".join(_slot_labels(missing)))
		reasons.append_array(compatibility_issues)
		status_label.text = "开机失败，%s" % "；".join(reasons)
		_show_action_feedback("error", "开机检测失败", "；".join(reasons))
		_play_feedback_sound("error")
	_refresh_build_status()
	_refresh_tutorial_status()
	_refresh_os_status()
	_play_operation_animation("power" if powered_on else "error")

func _on_deliver_pressed() -> void:
	var result := deliver_order()
	if bool(result.get("ok", false)):
		var score: Dictionary = result.get("score", {})
		status_label.text = "订单交付成功：获得 %d，评分 %d（%s），下一单已刷新。" % [
			int(result.get("reward", 0)),
			int(score.get("score", 0)),
			str(score.get("grade", "-")),
		]
		_show_action_feedback("reward", "订单交付成功", "奖励 +￥%d；评分 %d / %s；软件配置 %d。" % [
			int(result.get("reward", 0)),
			int(score.get("score", 0)),
			str(score.get("grade", "-")),
			int(score.get("software", 0)),
		])
		_show_delivery_feedback(true, score, [], true)
		_play_operation_animation("delivery")
		_play_feedback_sound("success")
	else:
		var reasons: Array = result.get("reasons", [])
		status_label.text = "订单未完成：%s" % "、".join(reasons)
		_show_action_feedback("error", "交付前检查未通过", _summarize_delivery_reasons(reasons))
		_show_delivery_feedback(false, {}, reasons, true)
		_play_operation_animation("error")
		_play_feedback_sound("error")
	_refresh_tutorial_status()
	if bool(result.get("ok", false)):
		_refresh_score_status()

func _select_order_from_ui(order_index: int) -> bool:
	if accept_order(order_index):
		status_label.text = "已接单：%s" % get_current_order().name
		_show_action_feedback("action", "已接单", "%s；先按订单等级购买核心配件。" % str(get_current_order().name))
		return true
	status_label.text = "该订单暂不可接"
	_show_action_feedback("error", "接单失败", "该订单还未解锁或当前不可接。")
	return false

func _on_order_selected(order_index: int) -> void:
	_select_order_from_ui(order_index)
	return
	if accept_order(order_index):
		status_label.text = "已接单：%s" % get_current_order().name
		_show_action_feedback("action", "已接单", "%s；先按订单等级购买核心配件。" % str(get_current_order().name))
	else:
		status_label.text = "该订单暂不可接"
		_show_action_feedback("error", "接单失败", "该订单还未解锁或当前不可接。")

func _on_save_pressed() -> void:
	if save_game(_active_save_path()):
		status_label.text = "进度已保存"
		_show_action_feedback("success", "进度已保存", "当前资金、背包、已安装配件和软件状态已写入存档。")
	else:
		status_label.text = "保存失败"
		_show_action_feedback("error", "保存失败", "存档写入失败，请检查路径或权限。")

func _on_load_pressed() -> void:
	if load_game(_active_save_path()):
		status_label.text = "进度已读取"
		_show_action_feedback("success", "进度已读取", "已恢复资金、背包、装机和订单进度。")
	else:
		status_label.text = "没有可读取的进度"
		_show_action_feedback("warning", "读取失败", "没有找到可读取的进度。")

func _on_reset_pressed() -> void:
	new_game()
	status_label.text = "已开始新装机"
	_show_action_feedback("warning", "已开始新装机", "当前局面已重置为初始资金和第一批订单。")

func _on_pause_menu_pressed() -> void:
	if pause_panel == null:
		return
	_sync_pause_settings()
	pause_status_label.text = "可保存当前装机进度"
	pause_backdrop.visible = true
	pause_panel.visible = true
	get_tree().paused = true

func _on_resume_game_pressed() -> void:
	get_tree().paused = false
	pause_backdrop.visible = false
	pause_panel.visible = false

func _on_pause_save_pressed() -> void:
	if save_game(_active_save_path()):
		pause_status_label.text = "进度已保存"
	else:
		pause_status_label.text = "保存失败，请检查存储权限"

func _on_pause_apply_settings_pressed() -> void:
	var session := get_node("/root/GameSession")
	session.set_fullscreen(pause_fullscreen_toggle.button_pressed)
	session.set_resolution(pause_resolution_option.selected)
	session.set_master_volume(float(pause_volume_slider.value) / 100.0)
	session.apply_settings()
	if session.save_settings():
		pause_status_label.text = "设置已应用并保存"
	else:
		pause_status_label.text = "设置已应用，但保存失败"

func _on_save_and_main_menu_pressed() -> void:
	if not save_game(_active_save_path()):
		pause_status_label.text = "保存失败，未返回主菜单"
		return
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _sync_pause_settings() -> void:
	var session := get_node("/root/GameSession")
	pause_fullscreen_toggle.button_pressed = bool(session.fullscreen)
	pause_resolution_option.selected = int(session.resolution_index)
	pause_volume_slider.value = float(session.master_volume) * 100.0

func _active_save_path() -> String:
	return save_path_override if save_path_override != "" else SAVE_PATH

func _on_power_button_pressed() -> void:
	if not powered_on:
		_on_finish_pressed()
	if powered_on:
		system_booted = true
		os_app = "桌面"
		_append_os_log("系统启动完成，进入桌面。")
		_update_tutorial_step(4)
		status_label.text = "已按下电源按钮：系统启动完成。"
		_show_action_feedback("success", "模拟系统已启动", "Max Monitor 可以放大操作；下一步完成 Driver Tool 和 Benchmark。")
		_play_feedback_sound("power")
	_refresh_build_status()
	_refresh_tutorial_status()
	_refresh_os_status()
	_refresh_monitor_ui()
	if system_booted:
		_play_operation_animation("power")

func _on_open_monitor_pressed() -> void:
	if not _require_booted_system():
		return
	if not ["System Info", "Benchmark", "Stability Test", "Driver Tool", "Files"].has(monitor_app_key):
		monitor_app_key = "Desktop"
	monitor_overlay.visible = true
	_refresh_monitor_ui()
	status_label.text = "Monitor enlarged."
	_show_action_feedback("action", "显示器已放大", "当前应用：%s。" % monitor_app_key)

func _on_close_monitor_pressed() -> void:
	if monitor_overlay:
		monitor_overlay.visible = false
	status_label.text = "Monitor closed."
	_show_action_feedback("action", "显示器已收起", "回到装机工作台。")

func _on_monitor_desktop_pressed() -> void:
	if not _require_booted_system():
		return
	os_app = "Desktop"
	monitor_app_key = "Desktop"
	_append_os_log("Desktop opened.")
	_refresh_os_status()
	_refresh_monitor_ui()
	status_label.text = "已打开模拟系统桌面。"
	_show_action_feedback("software", "桌面已打开", "可从左侧 Dock 进入系统信息、跑分、驱动和文件。")
	_play_operation_animation("software")

func _on_monitor_driver_tool_pressed() -> void:
	if not _require_booted_system():
		return
	os_app = "Driver Tool"
	monitor_app_key = "Driver Tool"
	_append_os_log("Driver Tool opened.")
	_refresh_os_status()
	_refresh_monitor_ui()
	_refresh_tutorial_status()
	status_label.text = "已打开 Driver Tool。"
	_show_action_feedback("software", "Driver Tool 已打开", "扫描设备、安装驱动并重启后，软件配置分数才会计入交付。")
	_play_operation_animation("software")

func _on_driver_scan_pressed() -> void:
	if not _require_booted_system():
		return
	monitor_app_key = "Driver Tool"
	os_app = "Driver Tool"
	driver_scan_completed = true
	driver_last_report = _build_driver_report()
	if _driver_has_blockers():
		drivers_installed = false
		os_restart_required = false
		_append_os_log("Driver scan found hardware blockers.")
		status_label.text = "Driver scan found blockers."
		_show_action_feedback("error", "驱动扫描发现阻塞", "请先修复硬件缺件或兼容性问题，再重新扫描。")
		_play_operation_animation("error")
		_play_feedback_sound("error")
	else:
		_append_os_log("Driver scan complete: devices ready.")
		status_label.text = "Driver scan complete."
		_show_action_feedback("software", "驱动扫描完成", "设备报告正常，可以安装基础驱动。")
		_play_operation_animation("software")
		_play_feedback_sound("action")
	_refresh_os_status()
	_refresh_monitor_ui()
	_refresh_tutorial_status()

func _on_driver_install_pressed() -> void:
	if not _require_booted_system():
		return
	monitor_app_key = "Driver Tool"
	os_app = "Driver Tool"
	if not driver_scan_completed:
		status_label.text = "Scan devices before installing drivers."
		_show_action_feedback("error", "驱动安装失败", "请先在 Driver Tool 扫描设备。")
		_play_operation_animation("error")
		_play_feedback_sound("error")
		return
	if _driver_has_blockers():
		driver_last_report = _build_driver_report()
		status_label.text = "Driver install blocked by hardware issues."
		_show_action_feedback("error", "驱动安装被阻止", "硬件问题未修复，无法进入软件配置完成状态。")
		_play_operation_animation("error")
		_play_feedback_sound("error")
		_refresh_monitor_ui()
		return
	drivers_installed = true
	os_restart_required = true
	_append_os_log("Drivers installed. Restart required.")
	status_label.text = "Drivers installed. Restart OS."
	_show_action_feedback("software", "基础驱动已安装", "需要重启 OS 验证后，软件配置才算完成。")
	_play_operation_animation("software")
	_play_feedback_sound("action")
	_refresh_os_status()
	_refresh_monitor_ui()
	_refresh_tutorial_status()

func _on_driver_restart_pressed() -> void:
	if not _require_booted_system():
		return
	monitor_app_key = "Driver Tool"
	os_app = "Driver Tool"
	if not os_restart_required:
		status_label.text = "No OS restart required."
		_show_action_feedback("warning", "无需重启", "当前没有待验证的驱动安装。")
		_play_operation_animation("error")
		_play_feedback_sound("error")
		return
	os_restart_required = false
	drivers_installed = true
	_append_os_log("OS restarted. Drivers verified.")
	status_label.text = "OS restarted. Drivers verified."
	_show_action_feedback("software", "驱动验证完成", "基础驱动已通过重启验证；软件配置完成度 %d / 100。" % int(calculate_delivery_score().get("software", 0)))
	_play_operation_animation("software")
	_play_feedback_sound("success")
	_refresh_build_status()
	_refresh_os_status()
	_refresh_monitor_ui()
	_refresh_tutorial_status()

func _on_gpu_driver_install_pressed() -> void:
	if not _require_booted_system():
		return
	monitor_app_key = "Driver Tool"
	os_app = "Driver Tool"
	if not installed.has("VideoCard"):
		status_label.text = "No GPU detected for driver installation."
		_show_action_feedback("error", "显卡驱动失败", "没有检测到 GPU，无法安装显卡驱动。")
		_play_operation_animation("error")
		_play_feedback_sound("error")
		return
	if not drivers_installed or os_restart_required:
		status_label.text = "Verify base drivers before installing the GPU driver."
		_show_action_feedback("warning", "显卡驱动未就绪", "请先完成基础驱动安装和重启验证。")
		_play_operation_animation("error")
		_play_feedback_sound("error")
		return
	gpu_driver_installed = true
	_append_os_log("GPU driver installed and device acceleration enabled.")
	status_label.text = "GPU driver installed."
	_show_action_feedback("software", "显卡驱动已安装", "GPU 加速已启用；软件配置完成度 %d / 100。" % int(calculate_delivery_score().get("software", 0)))
	_play_operation_animation("software")
	_play_feedback_sound("success")
	_refresh_os_status()
	_refresh_monitor_ui()

func _on_monitor_files_pressed() -> void:
	if not _require_booted_system():
		return
	os_app = "Files"
	monitor_app_key = "Files"
	monitor_file_key = "order"
	_append_os_log("File browser opened.")
	_refresh_os_status()
	_refresh_monitor_ui()
	status_label.text = "已打开模拟文件管理器。"
	_show_action_feedback("software", "文件管理器已打开", "可查看订单、跑分和驱动报告记录。")
	_play_operation_animation("software")

func _on_file_order_pressed() -> void:
	_select_monitor_file("order")

func _on_file_driver_pressed() -> void:
	_select_monitor_file("driver")

func _on_file_benchmark_pressed() -> void:
	_select_monitor_file("benchmark")

func _on_file_preflight_pressed() -> void:
	_select_monitor_file("preflight")

func _select_monitor_file(file_key: String) -> void:
	if not _require_booted_system():
		return
	monitor_file_key = file_key
	monitor_app_key = "Files"
	os_app = "Files"
	_append_os_log("Opened report file: %s." % file_key)
	_refresh_os_status()
	_refresh_monitor_ui()

func _on_os_system_info_pressed() -> void:
	if not _require_booted_system():
		return
	monitor_app_key = "System Info"
	os_app = "系统信息"
	_append_os_log("已打开系统信息，显示 CPU/GPU/内存配置。")
	_refresh_os_status()
	_refresh_monitor_ui()
	status_label.text = "已打开系统信息。"
	_show_action_feedback("software", "系统信息已打开", "当前已安装 %d / %d 个核心槽位。" % [installed.size(), required_slots.size()])
	_play_operation_animation("software")

func _on_os_benchmark_pressed() -> void:
	if not _require_booted_system():
		return
	benchmark_completed = true
	monitor_app_key = "Benchmark"
	os_app = "跑分工具"
	_append_os_log("跑分完成：%d 分。" % _benchmark_score())
	status_label.text = "Benchmark 完成：%d 分。" % _benchmark_score()
	_show_action_feedback("success", "Benchmark 完成", "跑分 %d；交付评分会使用这次结果。" % _benchmark_score())
	_play_operation_animation("benchmark")
	_play_feedback_sound("success")
	_refresh_os_status()
	_refresh_monitor_ui()
	_refresh_tutorial_status()

func _on_os_stability_test_pressed() -> void:
	if not _require_booted_system():
		return
	if not drivers_installed or os_restart_required:
		status_label.text = "请先在 Driver Tool 完成基础驱动验证。"
		_show_action_feedback("warning", "稳定性测试未就绪", "请先完成基础驱动安装和重启验证。")
		_play_operation_animation("error")
		_play_feedback_sound("error")
		return
	stability_test_completed = true
	monitor_app_key = "Stability Test"
	os_app = "稳定性测试"
	_append_os_log("稳定性测试通过：处理器、显卡、内存和温度均正常。")
	status_label.text = "稳定性测试通过。"
	_show_action_feedback("success", "稳定性测试通过", "CPU、GPU、内存和温度均通过测试。")
	_play_operation_animation("software")
	_play_feedback_sound("success")
	_refresh_os_status()
	_refresh_monitor_ui()

func _on_os_shutdown_pressed() -> void:
	if not system_booted:
		status_label.text = "系统尚未启动。"
		_show_action_feedback("warning", "关机无效", "模拟系统尚未启动。")
		return
	system_booted = false
	os_app = "已关机"
	_append_os_log("系统已关机，硬件检测状态保留。")
	status_label.text = "已从模拟系统关机。"
	_show_action_feedback("action", "模拟系统已关机", "硬件开机检测保留，软件操作需重新进入系统。")
	_refresh_build_status()
	_refresh_os_status()
	_refresh_monitor_ui()

func save_game(path: String = SAVE_PATH) -> bool:
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot open temporary save file for write: %s" % temp_path)
		return false
	file.store_string(JSON.stringify(_build_save_data(), "\t"))
	file.close()
	var session := get_node("/root/GameSession")
	if not session.is_valid_save_file(temp_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		push_error("New save data failed validation: %s" % path)
		return false
	if FileAccess.file_exists(path):
		if session.is_valid_save_file(path):
			if not session.create_save_backup(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
				push_error("Cannot create save backup: %s" % path)
				return false
		else:
			session.archive_corrupt_save(path)
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_path)
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), absolute_path) != OK:
		push_error("Cannot replace save file: %s" % path)
		return false
	return true

func load_game(path: String = SAVE_PATH, report_errors: bool = true) -> bool:
	last_save_migration_note = ""
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		if report_errors:
			push_error("Cannot open save file for read: %s" % path)
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		if report_errors:
			push_error("Save file contains invalid JSON: %s" % path)
		return false
	var parsed: Variant = json.data
	var migrated := _migrate_save_data(parsed)
	if migrated.is_empty() or not get_node("/root/GameSession").is_valid_save_data(migrated):
		if report_errors:
			push_error("Save file failed validation: %s" % path)
		return false
	_apply_save_data(migrated)
	_refresh_all()
	return true

func new_game() -> void:
	money = starting_money
	inventory.clear()
	installed.clear()
	current_filter = ""
	powered_on = false
	system_booted = false
	os_app = "未开机"
	os_log.clear()
	_reset_driver_state()
	last_delivery_score.clear()
	tutorial_step = 0
	tutorial_order_viewed = false
	tutorial_completed = false
	benchmark_completed = false
	completed_order_ids.clear()
	current_order_index = 0
	available_order_indices = _default_order_indices()
	if building_panel:
		building_panel.set_active_slot("")
	if shop_panel:
		shop_panel.clear_filters()
	if catalog_shop_panel:
		catalog_shop_panel.clear_filters()
	_refresh_all()

func accept_order(order_index: int) -> bool:
	if not available_order_indices.has(order_index):
		return false
	if order_index < 0 or order_index >= order_defs.size():
		return false
	current_order_index = order_index
	tutorial_order_viewed = true
	_update_tutorial_step(1)
	_refresh_order_status()
	_refresh_order_panel()
	_refresh_tutorial_status()
	return true

func deliver_order() -> Dictionary:
	var reasons := validate_current_order()
	if not reasons.is_empty():
		return {
			"ok": false,
			"reasons": reasons,
			"reward": 0,
			"order_index": current_order_index,
	}

	var order := get_current_order()
	var reward := int(order.reward)
	last_delivery_score = calculate_delivery_score()
	last_delivery_score.reward = reward
	last_delivery_score.order_name = str(order.get("name", "当前订单"))
	last_delivery_score.customer = str(order.get("customer", "客户"))
	tutorial_completed = true
	var completed_id := str(order.get("id", "order_%d" % current_order_index))
	if not completed_order_ids.has(completed_id):
		completed_order_ids.append(completed_id)
	money += reward
	installed.clear()
	current_filter = ""
	powered_on = false
	system_booted = false
	os_app = "已交付"
	_reset_driver_state()
	available_order_indices.erase(current_order_index)
	var unlocked_orders := _unlock_eligible_orders()
	current_order_index = _next_available_order_index()
	if building_panel:
		building_panel.set_active_slot("")
	if shop_panel:
		shop_panel.clear_filters()
	if catalog_shop_panel:
		catalog_shop_panel.clear_filters()
	_refresh_all()
	return {
		"ok": true,
		"reasons": [],
		"reward": reward,
		"score": last_delivery_score,
		"order_index": current_order_index,
		"unlocked_orders": unlocked_orders,
	}

func calculate_delivery_score() -> Dictionary:
	var performance := _performance_score()
	var budget := _budget_score()
	var compatibility := 100 if get_compatibility_issues().is_empty() else 0
	var boot := 100 if powered_on else 0
	var software := get_software_configuration_score()
	var total := int(round(
		float(performance) * float(scoring_rules.get("performance_weight", 0.4)) +
		float(budget) * float(scoring_rules.get("budget_weight", 0.2)) +
		float(compatibility) * float(scoring_rules.get("compatibility_weight", 0.15)) +
		float(boot) * float(scoring_rules.get("boot_weight", 0.1)) +
		float(software) * float(scoring_rules.get("software_weight", 0.15))
	))
	total = clampi(total, 0, 100)
	return {
		"score": total,
		"grade": _score_grade(total),
		"performance": performance,
		"budget": budget,
		"compatibility": compatibility,
		"boot": boot,
		"software": software,
		"benchmark": _benchmark_score(),
	}

func is_software_configuration_complete() -> bool:
	if not system_booted:
		return false
	return _incomplete_software_tasks(get_current_order()).is_empty()

func get_software_configuration_score() -> int:
	if not powered_on:
		return 0
	if not system_booted:
		return 25
	var order := get_current_order()
	var tasks := _software_tasks(order)
	if tasks.is_empty():
		return 100
	var progress := 0.0
	for task in tasks:
		progress += _software_task_progress(task)
	return clampi(40 + int(round(60.0 * progress / float(tasks.size()))), 40, 100)

func validate_current_order() -> Array[String]:
	var reasons: Array[String] = []
	if not available_order_indices.has(current_order_index):
		reasons.append("没有进行中的订单")
		return reasons
	if not powered_on:
		reasons.append("需要先通过开机检测")
	if powered_on and not system_booted:
		reasons.append("需要按下电源按钮并进入模拟系统")
	if system_booted:
		for task in _incomplete_software_tasks(get_current_order()):
			reasons.append(_software_task_failure_reason(task))

	var missing := get_missing_required_slots()
	if not missing.is_empty():
		reasons.append("缺少核心零件：%s" % "、".join(_slot_labels(missing)))

	var compatibility_issues := get_compatibility_issues()
	reasons.append_array(compatibility_issues)

	var order := get_current_order()
	var requirements: Dictionary = order.requirements
	for slot in requirements.keys():
		var slot_key := str(slot)
		if not installed.has(slot_key):
			reasons.append("缺少订单零件：%s" % component_database.display_type(slot_key))
			continue
		var installed_tier := int(installed[slot_key].tier)
		var required_tier := int(requirements[slot])
		if installed_tier < required_tier:
			reasons.append("%s 等级不足：%d/%d" % [
				component_database.display_type(slot_key),
				installed_tier,
				required_tier,
			])
	return reasons

func get_compatibility_issues() -> Array[String]:
	var issues: Array[String] = []
	if installed.has("CPU") and installed.has("MotherBoard"):
		var cpu_platform := _spec_string(installed["CPU"], "platform")
		var board_platform := _spec_string(installed["MotherBoard"], "platform")
		if cpu_platform != "" and board_platform != "" and cpu_platform != board_platform:
			issues.append("CPU 平台 %s 与主板平台 %s 不兼容" % [cpu_platform, board_platform])

	if installed.has("Power"):
		var capacity := _spec_int(installed["Power"], "capacity_w")
		var required_power := _estimated_power_draw()
		if capacity > 0 and required_power > capacity:
			issues.append("电源功率不足：需要 %dW / 当前 %dW" % [required_power, capacity])

	if installed.has("Case") and installed.has("VideoCard"):
		var gpu_tier := int(installed["VideoCard"].tier)
		var required_case_tier := _spec_int(installed["VideoCard"], "required_case_tier")
		var max_gpu_tier := _spec_int(installed["Case"], "max_gpu_tier")
		if required_case_tier > 0 and int(installed["Case"].tier) < required_case_tier:
			issues.append("机箱空间不足：显卡需要 Lv.%d 以上机箱" % required_case_tier)
		elif max_gpu_tier > 0 and gpu_tier > max_gpu_tier:
			issues.append("机箱空间不足：当前机箱最高支持 Lv.%d 显卡" % max_gpu_tier)
	return issues

func can_install_component(item: Dictionary) -> Array[String]:
	var slot := str(item.type_key)
	var previous: Dictionary = {}
	var had_previous := installed.has(slot)
	if had_previous:
		previous = installed[slot]
	installed[slot] = item
	var issues := get_compatibility_issues()
	if had_previous:
		installed[slot] = previous
	else:
		installed.erase(slot)
	return issues

func component_meets_current_order(item: Dictionary) -> bool:
	var order := get_current_order()
	if order.is_empty():
		return false
	var requirements: Dictionary = order.requirements
	var slot := str(item.type_key)
	if not requirements.has(slot):
		return false
	return int(item.tier) >= int(requirements[slot])

func get_current_order() -> Dictionary:
	if order_defs.is_empty() or current_order_index < 0 or current_order_index >= order_defs.size():
		return {}
	return order_defs[current_order_index]

func get_total_installed_cost() -> int:
	var total := 0
	for item in installed.values():
		total += int(item.price)
	return total

func _build_save_data() -> Dictionary:
	var inventory_stacks: Array = []
	for stack in inventory:
		inventory_stacks.append({
			"id": int(stack.id),
			"quantity": int(stack.get("quantity", 1)),
		})

	var installed_slots := {}
	for slot in installed.keys():
		installed_slots[str(slot)] = int(installed[slot].id)

	return {
		"version": SAVE_VERSION,
		"money": money,
		"inventory": inventory_stacks,
		"installed": installed_slots,
		"powered_on": powered_on,
		"system_booted": system_booted,
		"os_app": os_app,
		"monitor_app_key": monitor_app_key,
		"driver_scan_completed": driver_scan_completed,
		"drivers_installed": drivers_installed,
		"gpu_driver_installed": gpu_driver_installed,
		"os_restart_required": os_restart_required,
		"stability_test_completed": stability_test_completed,
		"driver_last_report": driver_last_report,
		"os_log": os_log,
		"last_delivery_score": last_delivery_score,
		"tutorial_step": tutorial_step,
		"tutorial_order_viewed": tutorial_order_viewed,
		"tutorial_completed": tutorial_completed,
		"benchmark_completed": benchmark_completed,
		"completed_order_ids": completed_order_ids,
		"current_order_index": current_order_index,
		"available_order_indices": available_order_indices,
	}

func _migrate_save_data(raw_data: Variant) -> Dictionary:
	if typeof(raw_data) != TYPE_DICTIONARY:
		last_save_migration_note = "invalid:not_dictionary"
		return {}
	var save_data: Dictionary = raw_data.duplicate(true)
	var version := _save_data_version(save_data)
	if version > SAVE_VERSION:
		last_save_migration_note = "unsupported_future_version:%d" % version
		return {}
	if version < 0:
		last_save_migration_note = "invalid:bad_version"
		return {}
	if not _has_minimum_save_fields(save_data):
		last_save_migration_note = "invalid:missing_required_fields"
		return {}

	var migration_steps: Array[String] = []
	if version == 0:
		migration_steps.append("legacy_unversioned")
	elif version < SAVE_VERSION:
		migration_steps.append("v%d_to_v%d" % [version, SAVE_VERSION])

	save_data.version = SAVE_VERSION
	save_data.inventory = _normalize_inventory_save_stacks(save_data.get("inventory", []))
	save_data.installed = _normalize_installed_save_slots(save_data.get("installed", {}))
	save_data.powered_on = bool(save_data.get("powered_on", false))
	save_data.system_booted = bool(save_data.get("system_booted", false))
	save_data.monitor_app_key = str(save_data.get("monitor_app_key", "Desktop"))
	save_data.os_app = str(save_data.get("os_app", "桌面" if bool(save_data.system_booted) else "未开机"))
	save_data.driver_scan_completed = bool(save_data.get("driver_scan_completed", false))
	save_data.drivers_installed = bool(save_data.get("drivers_installed", false))
	save_data.gpu_driver_installed = bool(save_data.get("gpu_driver_installed", false))
	save_data.os_restart_required = bool(save_data.get("os_restart_required", false))
	save_data.stability_test_completed = bool(save_data.get("stability_test_completed", false))
	save_data.benchmark_completed = bool(save_data.get("benchmark_completed", false))
	save_data.driver_last_report = _parse_string_array(save_data.get("driver_last_report", []))
	save_data.os_log = _parse_string_array(save_data.get("os_log", []))
	if typeof(save_data.get("last_delivery_score", {})) != TYPE_DICTIONARY:
		save_data.last_delivery_score = {}
	save_data.tutorial_step = int(save_data.get("tutorial_step", 0))
	save_data.tutorial_order_viewed = bool(save_data.get("tutorial_order_viewed", int(save_data.tutorial_step) > 0))
	save_data.tutorial_completed = bool(save_data.get("tutorial_completed", false))
	save_data.completed_order_ids = _parse_string_array(save_data.get("completed_order_ids", []))
	if save_data.has("available_order_indices"):
		save_data.available_order_indices = _parse_order_indices(save_data.get("available_order_indices", []))
	else:
		save_data.available_order_indices = _derive_available_order_indices(save_data.completed_order_ids)
		if not migration_steps.has("derived_orders"):
			migration_steps.append("derived_orders")
	save_data.current_order_index = int(save_data.get("current_order_index", 0))
	if not save_data.available_order_indices.has(int(save_data.current_order_index)):
		save_data.current_order_index = _first_available_order_index(save_data.available_order_indices)
		if not migration_steps.has("normalized_current_order"):
			migration_steps.append("normalized_current_order")
	last_save_migration_note = ",".join(migration_steps)
	return save_data

func _save_data_version(save_data: Dictionary) -> int:
	if not save_data.has("version"):
		return 0
	var raw_version: Variant = save_data.get("version", 0)
	if typeof(raw_version) not in [TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
		return -1
	var version := int(raw_version)
	return version if version >= 1 else -1

func _has_minimum_save_fields(save_data: Dictionary) -> bool:
	if not save_data.has("money") or typeof(save_data.money) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	if typeof(save_data.get("inventory", null)) != TYPE_ARRAY:
		return false
	if typeof(save_data.get("installed", null)) != TYPE_DICTIONARY:
		return false
	return true

func _normalize_inventory_save_stacks(raw_inventory: Variant) -> Array:
	var stacks: Array = []
	if typeof(raw_inventory) != TYPE_ARRAY:
		return stacks
	for raw_stack in raw_inventory:
		var item_id := 0
		var quantity := 1
		if typeof(raw_stack) == TYPE_DICTIONARY:
			item_id = int(raw_stack.get("id", 0))
			quantity = max(1, int(raw_stack.get("quantity", 1)))
		else:
			item_id = int(raw_stack)
		if item_id <= 0:
			continue
		var merged := false
		for stack in stacks:
			if int(stack.id) == item_id:
				stack.quantity = int(stack.quantity) + quantity
				merged = true
				break
		if not merged:
			stacks.append({"id": item_id, "quantity": quantity})
	return stacks

func _normalize_installed_save_slots(raw_installed: Variant) -> Dictionary:
	var installed_slots := {}
	if typeof(raw_installed) != TYPE_DICTIONARY:
		return installed_slots
	for raw_slot in raw_installed.keys():
		var slot := str(raw_slot)
		if slot == "":
			continue
		var raw_item: Variant = raw_installed[raw_slot]
		var item_id := int(raw_item.get("id", 0)) if typeof(raw_item) == TYPE_DICTIONARY else int(raw_item)
		if item_id > 0:
			installed_slots[slot] = item_id
	return installed_slots

func _apply_save_data(save_data: Dictionary) -> void:
	money = int(save_data.get("money", STARTING_MONEY))
	inventory = []
	for raw_stack in save_data.get("inventory", []):
		if typeof(raw_stack) != TYPE_DICTIONARY:
			continue
		var item := _component_by_id(int(raw_stack.get("id", 0)))
		if item.is_empty():
			continue
		var stack := item.duplicate(true)
		stack.quantity = max(1, int(raw_stack.get("quantity", 1)))
		inventory.append(stack)

	installed.clear()
	var raw_installed: Variant = save_data.get("installed", {})
	if typeof(raw_installed) == TYPE_DICTIONARY:
		for slot in raw_installed.keys():
			var item := _component_by_id(int(raw_installed[slot]))
			if not item.is_empty():
				installed[str(slot)] = item.duplicate(true)

	current_filter = ""
	powered_on = bool(save_data.get("powered_on", false))
	system_booted = bool(save_data.get("system_booted", false))
	os_app = str(save_data.get("os_app", "桌面" if system_booted else "未开机"))
	monitor_app_key = str(save_data.get("monitor_app_key", "Desktop"))
	driver_scan_completed = bool(save_data.get("driver_scan_completed", false))
	drivers_installed = bool(save_data.get("drivers_installed", false))
	gpu_driver_installed = bool(save_data.get("gpu_driver_installed", false))
	os_restart_required = bool(save_data.get("os_restart_required", false))
	stability_test_completed = bool(save_data.get("stability_test_completed", false))
	driver_last_report = _parse_string_array(save_data.get("driver_last_report", []))
	os_log = _parse_string_array(save_data.get("os_log", []))
	last_delivery_score = save_data.get("last_delivery_score", {})
	tutorial_step = int(save_data.get("tutorial_step", 0))
	tutorial_order_viewed = bool(save_data.get("tutorial_order_viewed", tutorial_step > 0))
	tutorial_completed = bool(save_data.get("tutorial_completed", false))
	benchmark_completed = bool(save_data.get("benchmark_completed", false))
	completed_order_ids = _parse_string_array(save_data.get("completed_order_ids", []))
	current_order_index = int(save_data.get("current_order_index", 0))
	if save_data.has("available_order_indices"):
		available_order_indices = _parse_order_indices(save_data.get("available_order_indices", []))
	else:
		available_order_indices = _default_order_indices()
		_unlock_eligible_orders()
	if not available_order_indices.has(current_order_index):
		current_order_index = _next_available_order_index()
	if building_panel:
		building_panel.set_active_slot("")
	if shop_panel:
		shop_panel.clear_filters()
	if catalog_shop_panel:
		catalog_shop_panel.clear_filters()

func get_missing_required_slots() -> Array[String]:
	var missing: Array[String] = []
	for slot in required_slots:
		if not installed.has(slot):
			missing.append(slot)
	return missing

func _slot_labels(slots: Array[String]) -> Array[String]:
	var labels: Array[String] = []
	for slot in slots:
		labels.append(component_database.display_type(slot))
	return labels

func _format_order_requirements(order: Dictionary) -> String:
	var parts: Array[String] = []
	var requirements: Dictionary = order.requirements
	for slot in requirements.keys():
		parts.append("%s Lv.%d" % [
			component_database.display_type(str(slot)),
			int(requirements[slot]),
		])
	return "、".join(parts)

func _software_tasks(order: Dictionary) -> Array[String]:
	var tasks := _parse_string_array(order.get("software_tasks", ["drivers"]))
	if tasks.is_empty():
		tasks.append("drivers")
	return tasks

func _format_software_tasks(order: Dictionary) -> String:
	var labels: Array[String] = []
	for task in _software_tasks(order):
		labels.append(_software_task_label(task))
	return "、".join(labels)

func _software_task_label(task: String) -> String:
	match task:
		"drivers":
			return "基础驱动"
		"gpu_driver":
			return "显卡驱动"
		"benchmark":
			return "性能跑分"
		"stability":
			return "稳定性测试"
	return task

func _current_order_requires_task(task: String) -> bool:
	return _software_tasks(get_current_order()).has(task)

func _is_software_task_complete(task: String) -> bool:
	match task:
		"drivers":
			return driver_scan_completed and drivers_installed and not os_restart_required and not _driver_has_blockers()
		"gpu_driver":
			return gpu_driver_installed
		"benchmark":
			return benchmark_completed
		"stability":
			return stability_test_completed
	return false

func _software_task_progress(task: String) -> float:
	if task != "drivers":
		return 1.0 if _is_software_task_complete(task) else 0.0
	if _is_software_task_complete("drivers"):
		return 1.0
	if drivers_installed and os_restart_required:
		return 2.0 / 3.0
	if driver_scan_completed and not _driver_has_blockers():
		return 5.0 / 12.0
	return 0.0

func _incomplete_software_tasks(order: Dictionary) -> Array[String]:
	var incomplete: Array[String] = []
	for task in _software_tasks(order):
		if not _is_software_task_complete(task):
			incomplete.append(task)
	return incomplete

func _software_task_failure_reason(task: String) -> String:
	match task:
		"drivers":
			if not driver_scan_completed:
				return "Software setup incomplete: scan devices in Driver Tool."
			if _driver_has_blockers():
				return "Software setup blocked: resolve hardware issues and scan again."
			if not drivers_installed:
				return "Software setup incomplete: install drivers in Driver Tool."
			if os_restart_required:
				return "Software setup incomplete: restart OS to verify drivers."
		"gpu_driver":
			return "软件任务未完成：需要在 Driver Tool 安装显卡驱动。"
		"benchmark":
			return "软件任务未完成：需要运行 Benchmark 性能跑分。"
		"stability":
			return "软件任务未完成：需要运行 Stability Test 稳定性测试。"
	return "软件任务未完成：%s。" % _software_task_label(task)

func _load_game_rules() -> void:
	required_slots = _parse_required_slots(REQUIRED_SLOTS)
	starting_money = STARTING_MONEY
	var parsed: Variant = _load_json_file(RULES_PATH)
	if typeof(parsed) != TYPE_DICTIONARY:
		money = starting_money
		return
	starting_money = int(parsed.get("starting_money", STARTING_MONEY))
	required_slots = _parse_required_slots(parsed.get("required_slots", REQUIRED_SLOTS))
	if required_slots.is_empty():
		required_slots = _parse_required_slots(REQUIRED_SLOTS)
	sell_ratio = float(parsed.get("sell_ratio", sell_ratio))
	if typeof(parsed.get("scoring", {})) == TYPE_DICTIONARY:
		var raw_scoring: Dictionary = parsed.scoring
		for key in raw_scoring.keys():
			scoring_rules[str(key)] = float(raw_scoring[key])
	money = starting_money

func _load_orders() -> void:
	order_defs = ORDER_DEFS.duplicate(true)
	var parsed: Variant = _load_json_file(ORDERS_PATH)
	if typeof(parsed) != TYPE_ARRAY:
		return
	var loaded_orders: Array = []
	for raw_order in parsed:
		if typeof(raw_order) != TYPE_DICTIONARY:
			continue
		var order := {
			"id": str(raw_order.get("id", "order_%d" % loaded_orders.size())),
			"name": str(raw_order.get("name", "未命名订单")),
			"customer": str(raw_order.get("customer", "客户")),
			"customer_type": str(raw_order.get("customer_type", "普通客户")),
			"reward": int(raw_order.get("reward", 0)),
			"difficulty": int(raw_order.get("difficulty", 1)),
			"estimated_minutes": max(1, int(raw_order.get("estimated_minutes", 5))),
			"unlock_after": max(0, int(raw_order.get("unlock_after", 0))),
			"software_tasks": _parse_string_array(raw_order.get("software_tasks", ["drivers"])),
			"requirements": {},
		}
		var raw_requirements: Variant = raw_order.get("requirements", {})
		if typeof(raw_requirements) == TYPE_DICTIONARY:
			for slot in raw_requirements.keys():
				order.requirements[str(slot)] = int(raw_requirements[slot])
		loaded_orders.append(order)
	if not loaded_orders.is_empty():
		order_defs = loaded_orders

func _load_json_file(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())

func _parse_required_slots(raw_value: Variant) -> Array[String]:
	var slots: Array[String] = []
	if typeof(raw_value) != TYPE_ARRAY:
		return slots
	for raw_slot in raw_value:
		var slot := str(raw_slot)
		if slot != "" and not slots.has(slot):
			slots.append(slot)
	return slots

func _reset_driver_state() -> void:
	driver_scan_completed = false
	drivers_installed = false
	gpu_driver_installed = false
	os_restart_required = false
	driver_last_report.clear()
	benchmark_completed = false
	stability_test_completed = false

func _parse_string_array(raw_value: Variant) -> Array[String]:
	var strings: Array[String] = []
	if typeof(raw_value) != TYPE_ARRAY:
		return strings
	for raw_text in raw_value:
		strings.append(str(raw_text))
	return strings

func _add_to_inventory(item: Dictionary) -> void:
	var item_id := int(item.id)
	for stack in inventory:
		if int(stack.id) == item_id:
			stack.quantity = int(stack.get("quantity", 1)) + 1
			return
	var new_stack := item.duplicate(true)
	new_stack.quantity = 1
	inventory.append(new_stack)

func _remove_one_from_inventory(item: Dictionary) -> void:
	var item_id := int(item.id)
	for stack in inventory:
		if int(stack.id) != item_id:
			continue
		var quantity := int(stack.get("quantity", 1)) - 1
		if quantity <= 0:
			inventory.erase(stack)
		else:
			stack.quantity = quantity
		return

func _install_component(item: Dictionary) -> void:
	var slot := str(item.type_key)
	if installed.has(slot):
		_add_to_inventory(installed[slot])
	installed[slot] = item.duplicate(true)
	current_filter = ""
	powered_on = false
	system_booted = false
	os_app = "未开机"
	_reset_driver_state()
	building_panel.set_active_slot("")

func _cheat_install_required_parts(order: Dictionary) -> String:
	var requirements: Dictionary = order.get("requirements", {})
	var install_order := _cheat_install_order(requirements)
	for slot in install_order:
		var min_tier := 0
		if requirements.has(slot):
			min_tier = int(requirements[slot])
		var item := _cheat_best_component_for_slot(slot, min_tier)
		if item.is_empty():
			return slot
		_install_component(item)
	return ""

func _cheat_install_order(order_requirements: Dictionary = {}) -> Array[String]:
	var install_order: Array[String] = []
	for slot in required_slots:
		var slot_key := str(slot)
		if slot_key != "Power":
			install_order.append(slot_key)
	for slot in order_requirements.keys():
		var slot_key := str(slot)
		if slot_key != "Power" and not install_order.has(slot_key):
			install_order.append(slot_key)
	install_order.append("Power")
	return install_order

func _cheat_best_component_for_slot(slot: String, min_tier: int) -> Dictionary:
	var best: Dictionary = {}
	for item in component_database.get_components_by_type(slot):
		if int(item.tier) < min_tier:
			continue
		if not can_install_component(item).is_empty():
			continue
		if best.is_empty() or int(item.tier) > int(best.tier):
			best = item
	return best

func _install_from_inventory(item: Dictionary) -> bool:
	if get_inventory_quantity(int(item.id)) <= 0:
		status_label.text = "背包中没有该配件：%s" % item.name
		_show_action_feedback("error", "安装失败", "背包中没有该配件：%s。" % str(item.name))
		_play_operation_animation("error")
		_play_feedback_sound("error")
		return false
	var install_issues := can_install_component(item)
	if not install_issues.is_empty():
		status_label.text = "安装已阻止：%s" % "；".join(install_issues)
		_show_action_feedback("warning", "兼容性阻止安装", "；".join(install_issues))
		_play_operation_animation("blocked", str(item.type_key))
		_play_feedback_sound("error")
		return false
	_install_component(item)
	_remove_one_from_inventory(item)
	_update_tutorial_step(2)
	status_label.text = "已安装：%s -> %s" % [component_database.display_type(str(item.type_key)), item.name]
	_show_action_feedback("success", "安装完成", "%s 已装入 %s；开机和软件验证已重置。" % [
		str(item.name),
		component_database.display_type(str(item.type_key)),
	])
	_play_feedback_sound("success")
	_refresh_slots()
	_refresh_build_status()
	_refresh_inventory()
	_refresh_shop()
	_refresh_tutorial_status()
	_refresh_os_status()
	_play_operation_animation("install", str(item.type_key))
	return true

func _sell_inventory_item(item: Dictionary) -> bool:
	if get_inventory_quantity(int(item.id)) <= 0:
		status_label.text = "背包中没有可出售的配件。"
		_show_action_feedback("error", "出售失败", "背包中没有可出售的配件。")
		_play_operation_animation("error")
		_play_feedback_sound("error")
		return false
	var refund := int(round(float(item.price) * sell_ratio))
	_remove_one_from_inventory(item)
	money += refund
	status_label.text = "已出售：%s，回收 %d。" % [item.name, refund]
	_show_action_feedback("reward", "出售完成", "%s 已出售；回收 ￥%d，当前资金 ￥%d。" % [str(item.name), refund, money])
	_play_operation_animation("reward")
	_play_feedback_sound("action")
	return true

func _performance_score() -> int:
	var order := get_current_order()
	var requirements: Dictionary = order.get("requirements", {})
	if requirements.is_empty():
		return 100
	var total_ratio := 0.0
	var counted := 0
	for slot in requirements.keys():
		var slot_key := str(slot)
		if not installed.has(slot_key):
			continue
		var required_tier: int = max(1, int(requirements[slot]))
		var installed_tier := int(installed[slot_key].tier)
		total_ratio += min(1.25, float(installed_tier) / float(required_tier))
		counted += 1
	if counted == 0:
		return 0
	return clampi(int(round(total_ratio / float(counted) * 90.0)), 0, 100)

func _budget_score() -> int:
	var order := get_current_order()
	var reward: int = max(1, int(order.get("reward", 1)))
	var cost := get_total_installed_cost()
	var target_cost := float(reward) * 2.2
	if cost <= 0:
		return 0
	if float(cost) <= target_cost:
		return 100
	var over_ratio := (float(cost) - target_cost) / target_cost
	return clampi(100 - int(round(over_ratio * 120.0)), 25, 100)

func _score_grade(score: int) -> String:
	if score >= 95:
		return "S"
	if score >= 85:
		return "A"
	if score >= 75:
		return "B"
	if score >= 60:
		return "C"
	return "D"

func _benchmark_score() -> int:
	var total := 0
	for item in installed.values():
		total += int(item.tier) * 120
	return total

func _require_booted_system() -> bool:
	if system_booted:
		return true
	status_label.text = "需要先点击电源按钮启动模拟系统。"
	_show_action_feedback("warning", "模拟系统未启动", "先完成开机检测，再点击电源按钮进入系统。")
	_play_operation_animation("error")
	return false

func _append_os_log(text: String) -> void:
	os_log.append(text)
	while os_log.size() > 5:
		os_log.pop_front()

func _update_tutorial_step(target_step: int) -> void:
	if target_step > tutorial_step:
		tutorial_step = target_step

func get_inventory_quantity(item_id: int) -> int:
	for stack in inventory:
		if int(stack.id) == item_id:
			return int(stack.get("quantity", 1))
	return 0

func _component_by_id(item_id: int) -> Dictionary:
	if component_database == null:
		return {}
	return component_database.components_by_id.get(item_id, {})

func _estimated_power_draw() -> int:
	var total := 150
	for item in installed.values():
		total += _spec_int(item, "power_draw")
	return total

func _spec_string(item: Dictionary, key: String) -> String:
	var specs: Dictionary = item.get("specs", {})
	return str(specs.get(key, ""))

func _spec_int(item: Dictionary, key: String) -> int:
	var specs: Dictionary = item.get("specs", {})
	return int(specs.get(key, 0))

func _default_order_indices() -> Array[int]:
	var indices: Array[int] = []
	for index in range(order_defs.size()):
		var order: Dictionary = order_defs[index]
		if int(order.get("unlock_after", 0)) <= 0 and not completed_order_ids.has(str(order.get("id", "order_%d" % index))):
			indices.append(index)
	return indices

func _unlock_eligible_orders() -> Array[String]:
	var unlocked: Array[String] = []
	for index in range(order_defs.size()):
		var order: Dictionary = order_defs[index]
		var order_id := str(order.get("id", "order_%d" % index))
		if completed_order_ids.has(order_id) or available_order_indices.has(index):
			continue
		if int(order.get("unlock_after", 0)) <= completed_order_ids.size():
			available_order_indices.append(index)
			unlocked.append(str(order.get("name", order_id)))
	available_order_indices.sort()
	return unlocked

func _derive_available_order_indices(completed_ids: Array[String]) -> Array[int]:
	var indices: Array[int] = []
	for index in range(order_defs.size()):
		var order: Dictionary = order_defs[index]
		var order_id := str(order.get("id", "order_%d" % index))
		if completed_ids.has(order_id):
			continue
		if int(order.get("unlock_after", 0)) <= completed_ids.size() and not indices.has(index):
			indices.append(index)
	indices.sort()
	return indices

func _next_unlock_requirement() -> int:
	var requirement := order_defs.size()
	for index in range(order_defs.size()):
		var order: Dictionary = order_defs[index]
		var order_id := str(order.get("id", "order_%d" % index))
		if completed_order_ids.has(order_id) or available_order_indices.has(index):
			continue
		requirement = mini(requirement, int(order.get("unlock_after", order_defs.size())))
	return requirement

func _parse_order_indices(raw_value: Variant) -> Array[int]:
	var indices: Array[int] = []
	if typeof(raw_value) != TYPE_ARRAY:
		return indices
	for raw_index in raw_value:
		var index := int(raw_index)
		if index >= 0 and index < order_defs.size() and not indices.has(index):
			indices.append(index)
	return indices

func _next_available_order_index() -> int:
	return available_order_indices[0] if not available_order_indices.is_empty() else -1

func _first_available_order_index(indices: Array[int]) -> int:
	return indices[0] if not indices.is_empty() else -1

func _style_top_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _stylebox(Color(0.04, 0.055, 0.16, 0.95), Color(0.34, 0.23, 0.78), 12))
	button.add_theme_stylebox_override("hover", _stylebox(Color(0.12, 0.08, 0.32, 0.95), Color(0.78, 0.36, 1.0), 12))
	button.add_theme_stylebox_override("pressed", _stylebox(Color(0.20, 0.08, 0.42, 0.95), Color(1.0, 0.68, 0.22), 12))
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_apply_button_icon(button, _button_icon_key(button), 18)

func _stylebox(color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
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
