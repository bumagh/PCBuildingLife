extends Control

const DEFAULT_SAVE_PATH := "user://save_game.json"
const ORDERS_PATH := "res://data/orders.json"
const CORE_SLOT_COUNT := 9
@export var save_path_override := ""

var continue_button: Button
var new_game_button: Button
var settings_button: Button
var about_button: Button
var quit_button: Button
var snapshot_action_button: Button
var snapshot_status_chip: PanelContainer
var snapshot_status_label: Label
var snapshot_title_label: Label
var snapshot_subtitle_label: Label
var snapshot_next_label: Label
var snapshot_metric_values: Dictionary = {}
var settings_backdrop: ColorRect
var settings_panel: PanelContainer
var about_panel: PanelContainer
var quit_panel: PanelContainer
var recovery_panel: PanelContainer
var recovery_message: Label
var recovery_restore_button: Button
var fullscreen_toggle: CheckButton
var resolution_option: OptionButton
var volume_slider: HSlider
var version_label: Label
var order_defs: Array = []

func _ready() -> void:
	order_defs = _load_order_defs()
	_build_ui()
	_refresh_continue_state()
	call_deferred("_focus_default_action")
	_start_release_player_flow_if_requested()
	_start_first_order_audit_if_requested()

func _start_release_player_flow_if_requested() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--pcbl-release-flow"):
		return
	if not OS.has_feature("pcbl_player_flow"):
		return
	var runner_script: Script = load("res://scripts/release_player_flow.gd")
	if runner_script == null or not runner_script.can_instantiate():
		push_error("Release player flow runner missing.")
		get_tree().quit(1)
		return
	var runner: Node = runner_script.new()
	runner.name = "ReleasePlayerFlowRunner"
	add_child(runner)
	runner.start(_release_player_flow_report_path(args))

func _release_player_flow_report_path(args: PackedStringArray) -> String:
	for index in range(args.size() - 1):
		if args[index] == "--pcbl-flow-report":
			return args[index + 1]
	return "user://release-player-flow-report.json"

func _start_first_order_audit_if_requested() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--pcbl-first-order-audit"):
		return
	if not OS.has_feature("pcbl_first_order_audit"):
		return
	var runner_script: Script = load("res://scripts/release_first_order_audit.gd")
	if runner_script == null or not runner_script.can_instantiate():
		push_error("First-order audit runner missing.")
		get_tree().quit(1)
		return
	var runner: Node = runner_script.new()
	runner.name = "FirstOrderAuditRunner"
	add_child(runner)
	runner.start(_first_order_audit_report_path(args))

func _first_order_audit_report_path(args: PackedStringArray) -> String:
	for index in range(args.size() - 1):
		if args[index] == "--pcbl-first-order-report":
			return args[index + 1]
	return "user://first-order-audit-report.json"

func _build_ui() -> void:
	var background := ColorRect.new()
	background.name = "MainMenuBackground"
	background.color = Color("050814")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_build_terminal_grid()

	var menu_band := ColorRect.new()
	menu_band.color = Color(0.008, 0.015, 0.075, 0.9)
	menu_band.anchor_bottom = 1.0
	menu_band.offset_right = 430
	add_child(menu_band)

	var menu := VBoxContainer.new()
	menu.name = "MainMenuActions"
	menu.anchor_top = 0.5
	menu.anchor_bottom = 0.5
	menu.offset_left = 48
	menu.offset_top = -248
	menu.offset_right = 382
	menu.offset_bottom = 248
	menu.add_theme_constant_override("separation", 12)
	add_child(menu)

	var eyebrow := Label.new()
	eyebrow.text = "AKG STUDIO / WORKSHOP SIM"
	eyebrow.add_theme_font_size_override("font_size", 14)
	eyebrow.add_theme_color_override("font_color", Color(0.28, 0.85, 0.95))
	menu.add_child(eyebrow)

	var title := Label.new()
	title.text = "装机人生"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	menu.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "PC BUILDING LIFE"
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.76, 0.9))
	menu.add_child(subtitle)

	var title_spacer := Control.new()
	title_spacer.custom_minimum_size = Vector2(0, 18)
	menu.add_child(title_spacer)

	continue_button = _make_menu_button("继续游戏")
	continue_button.name = "ContinueButton"
	continue_button.pressed.connect(_on_continue_pressed)
	menu.add_child(continue_button)

	new_game_button = _make_menu_button("新游戏")
	new_game_button.name = "NewGameButton"
	new_game_button.pressed.connect(_on_new_game_pressed)
	menu.add_child(new_game_button)

	settings_button = _make_menu_button("设置")
	settings_button.name = "SettingsButton"
	settings_button.pressed.connect(_on_settings_pressed)
	menu.add_child(settings_button)

	about_button = _make_menu_button("制作信息")
	about_button.name = "AboutButton"
	about_button.pressed.connect(_on_about_pressed)
	menu.add_child(about_button)

	quit_button = _make_menu_button("退出游戏")
	quit_button.name = "QuitButton"
	quit_button.pressed.connect(_on_quit_pressed)
	menu.add_child(quit_button)

	var footer_spacer := Control.new()
	footer_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu.add_child(footer_spacer)

	version_label = Label.new()
	version_label.text = "版本 %s / Windows 开发版" % str(ProjectSettings.get_setting("application/config/version", "dev"))
	version_label.add_theme_font_size_override("font_size", 13)
	version_label.add_theme_color_override("font_color", Color(0.48, 0.56, 0.72))
	menu.add_child(version_label)

	_build_save_workspace()
	_build_modal_backdrop()
	_build_settings_panel()
	_build_about_panel()
	_build_quit_panel()
	_build_recovery_panel()
	_wire_main_focus_navigation()

func _build_terminal_grid() -> void:
	for index in range(10):
		var vertical := ColorRect.new()
		vertical.color = Color(0.12, 0.55, 0.62, 0.075)
		var x_anchor := lerpf(0.375, 0.94, float(index) / 9.0)
		vertical.anchor_left = x_anchor
		vertical.anchor_right = x_anchor
		vertical.anchor_bottom = 1.0
		vertical.offset_right = 1
		vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(vertical)
	for index in range(10):
		var horizontal := ColorRect.new()
		horizontal.color = Color(0.12, 0.55, 0.62, 0.075)
		var y_anchor := float(index) / 9.0
		horizontal.anchor_left = 0.336
		horizontal.anchor_top = y_anchor
		horizontal.anchor_right = 1.0
		horizontal.anchor_bottom = y_anchor
		horizontal.offset_bottom = 1
		horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(horizontal)

	var signal_line := ColorRect.new()
	signal_line.color = Color(0.18, 0.84, 0.88, 0.72)
	signal_line.anchor_left = 1.0
	signal_line.anchor_right = 1.0
	signal_line.anchor_bottom = 1.0
	signal_line.offset_left = -10
	signal_line.offset_right = -6
	signal_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(signal_line)

func _build_save_workspace() -> void:
	var workspace := MarginContainer.new()
	workspace.name = "SaveWorkspace"
	workspace.anchor_left = 0.0
	workspace.anchor_top = 0.08
	workspace.anchor_right = 1.0
	workspace.anchor_bottom = 0.90
	workspace.offset_left = 462
	workspace.offset_right = -64
	workspace.add_theme_constant_override("margin_left", 8)
	workspace.add_theme_constant_override("margin_right", 8)
	workspace.add_theme_constant_override("margin_top", 8)
	workspace.add_theme_constant_override("margin_bottom", 8)
	add_child(workspace)

	var content := VBoxContainer.new()
	content.name = "SaveWorkspaceContent"
	content.add_theme_constant_override("separation", 14)
	workspace.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)

	var eyebrow := Label.new()
	eyebrow.text = "WORKSHOP STATUS / 本地进度"
	eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eyebrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 14)
	eyebrow.add_theme_color_override("font_color", Color(0.28, 0.85, 0.95))
	header.add_child(eyebrow)

	snapshot_status_chip = PanelContainer.new()
	snapshot_status_chip.name = "SaveStatusChip"
	snapshot_status_chip.custom_minimum_size = Vector2(122, 34)
	header.add_child(snapshot_status_chip)

	snapshot_status_label = Label.new()
	snapshot_status_label.name = "SaveStatusLabel"
	snapshot_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	snapshot_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	snapshot_status_label.add_theme_font_size_override("font_size", 14)
	snapshot_status_label.add_theme_color_override("font_color", Color(0.58, 1.0, 0.82))
	snapshot_status_chip.add_child(snapshot_status_label)

	snapshot_title_label = Label.new()
	snapshot_title_label.name = "SaveSnapshotTitle"
	snapshot_title_label.add_theme_font_size_override("font_size", 34)
	snapshot_title_label.add_theme_color_override("font_color", Color.WHITE)
	content.add_child(snapshot_title_label)

	snapshot_subtitle_label = Label.new()
	snapshot_subtitle_label.name = "SaveSnapshotSubtitle"
	snapshot_subtitle_label.custom_minimum_size = Vector2(0, 42)
	snapshot_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	snapshot_subtitle_label.add_theme_font_size_override("font_size", 16)
	snapshot_subtitle_label.add_theme_color_override("font_color", Color(0.68, 0.76, 0.88))
	content.add_child(snapshot_subtitle_label)

	var divider := HSeparator.new()
	divider.add_theme_constant_override("separation", 1)
	content.add_child(divider)

	var metrics := GridContainer.new()
	metrics.name = "SaveSnapshotMetrics"
	metrics.columns = 3
	metrics.size_flags_vertical = Control.SIZE_EXPAND_FILL
	metrics.add_theme_constant_override("h_separation", 10)
	metrics.add_theme_constant_override("v_separation", 10)
	content.add_child(metrics)

	_add_snapshot_metric(metrics, "money", "资金", Color(1.0, 0.72, 0.28))
	_add_snapshot_metric(metrics, "order", "当前订单", Color(0.22, 0.88, 0.94))
	_add_snapshot_metric(metrics, "completed", "订单进度", Color(0.46, 1.0, 0.68))
	_add_snapshot_metric(metrics, "installed", "已安装槽位", Color(0.60, 0.74, 1.0))
	_add_snapshot_metric(metrics, "system", "系统状态", Color(0.78, 0.58, 1.0))
	_add_snapshot_metric(metrics, "inventory", "仓库配件", Color(0.98, 0.62, 0.38))

	var next_panel := PanelContainer.new()
	next_panel.name = "SaveNextActionPanel"
	next_panel.custom_minimum_size = Vector2(0, 92)
	next_panel.add_theme_stylebox_override("panel", _stylebox(Color(0.012, 0.055, 0.085, 0.98), Color(0.18, 0.7, 0.76), 5))
	content.add_child(next_panel)

	var next_row := HBoxContainer.new()
	next_row.add_theme_constant_override("separation", 16)
	next_panel.add_child(next_row)

	var next_copy := VBoxContainer.new()
	next_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_copy.add_theme_constant_override("separation", 5)
	next_row.add_child(next_copy)

	var next_eyebrow := Label.new()
	next_eyebrow.text = "NEXT OPERATION / 下一步"
	next_eyebrow.add_theme_font_size_override("font_size", 13)
	next_eyebrow.add_theme_color_override("font_color", Color(0.28, 0.85, 0.95))
	next_copy.add_child(next_eyebrow)

	snapshot_next_label = Label.new()
	snapshot_next_label.name = "SaveNextActionLabel"
	snapshot_next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	snapshot_next_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	snapshot_next_label.add_theme_font_size_override("font_size", 16)
	snapshot_next_label.add_theme_color_override("font_color", Color(0.86, 0.92, 0.98))
	next_copy.add_child(snapshot_next_label)

	snapshot_action_button = Button.new()
	snapshot_action_button.name = "SaveSnapshotActionButton"
	snapshot_action_button.custom_minimum_size = Vector2(188, 52)
	snapshot_action_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	snapshot_action_button.add_theme_font_size_override("font_size", 16)
	snapshot_action_button.add_theme_stylebox_override("normal", _stylebox(Color(0.04, 0.19, 0.18, 1.0), Color(0.28, 0.9, 0.72), 5))
	snapshot_action_button.add_theme_stylebox_override("hover", _stylebox(Color(0.06, 0.28, 0.24, 1.0), Color(0.54, 1.0, 0.82), 5))
	snapshot_action_button.add_theme_stylebox_override("pressed", _stylebox(Color(0.13, 0.25, 0.2, 1.0), Color(1.0, 0.76, 0.28), 5))
	snapshot_action_button.pressed.connect(_on_snapshot_action_pressed)
	next_row.add_child(snapshot_action_button)

func _add_snapshot_metric(parent: GridContainer, key: String, title: String, accent: Color) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 98)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _stylebox(Color(0.012, 0.026, 0.07, 0.98), accent.darkened(0.24), 5))
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", accent)
	box.add_child(title_label)

	var value_label := Label.new()
	value_label.name = "SaveMetric%s" % key.capitalize()
	value_label.text = "-"
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value_label.tooltip_text = "-"
	value_label.add_theme_font_size_override("font_size", 21)
	value_label.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
	box.add_child(value_label)
	snapshot_metric_values[key] = value_label

func _wire_main_focus_navigation() -> void:
	var menu_buttons: Array[Button] = [continue_button, new_game_button, settings_button, about_button, quit_button]
	for index in range(menu_buttons.size()):
		var button := menu_buttons[index]
		button.focus_neighbor_top = menu_buttons[maxi(0, index - 1)].get_path()
		button.focus_neighbor_bottom = menu_buttons[mini(menu_buttons.size() - 1, index + 1)].get_path()
		button.focus_neighbor_right = snapshot_action_button.get_path()
	snapshot_action_button.focus_neighbor_left = continue_button.get_path()
	snapshot_action_button.focus_neighbor_top = snapshot_action_button.get_path()
	snapshot_action_button.focus_neighbor_bottom = snapshot_action_button.get_path()

func _focus_default_action() -> void:
	if continue_button != null and not continue_button.disabled:
		continue_button.grab_focus()
	elif new_game_button != null:
		new_game_button.grab_focus()

func _build_modal_backdrop() -> void:
	settings_backdrop = ColorRect.new()
	settings_backdrop.name = "ModalBackdrop"
	settings_backdrop.color = Color(0.0, 0.0, 0.02, 0.68)
	settings_backdrop.visible = false
	settings_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_backdrop.z_index = 19
	add_child(settings_backdrop)

func _make_menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 48)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", _stylebox(Color(0.025, 0.045, 0.14, 0.96), Color(0.16, 0.5, 0.7), 5))
	button.add_theme_stylebox_override("hover", _stylebox(Color(0.04, 0.13, 0.22, 1.0), Color(0.24, 0.92, 0.94), 5))
	button.add_theme_stylebox_override("pressed", _stylebox(Color(0.12, 0.16, 0.3, 1.0), Color(0.96, 0.78, 0.28), 5))
	button.add_theme_stylebox_override("disabled", _stylebox(Color(0.025, 0.035, 0.075, 0.85), Color(0.14, 0.17, 0.24), 5))
	return button

func _style_dialog_button(button: Button, accent: Color = Color(0.22, 0.72, 0.82)) -> void:
	button.custom_minimum_size.y = 42
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", _stylebox(Color(0.025, 0.045, 0.12, 1.0), accent.darkened(0.28), 4))
	button.add_theme_stylebox_override("hover", _stylebox(Color(0.045, 0.12, 0.18, 1.0), accent, 4))
	button.add_theme_stylebox_override("pressed", _stylebox(Color(0.1, 0.16, 0.22, 1.0), Color(1.0, 0.76, 0.28), 4))

func _build_settings_panel() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.visible = false
	settings_panel.custom_minimum_size = Vector2(430, 360)
	settings_panel.anchor_left = 0.5
	settings_panel.anchor_top = 0.5
	settings_panel.anchor_right = 0.5
	settings_panel.anchor_bottom = 0.5
	settings_panel.offset_left = -215
	settings_panel.offset_top = -180
	settings_panel.offset_right = 215
	settings_panel.offset_bottom = 180
	settings_panel.add_theme_stylebox_override("panel", _stylebox(Color(0.015, 0.025, 0.09, 0.985), Color(0.18, 0.8, 0.86), 7))
	settings_panel.z_index = 20
	add_child(settings_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	settings_panel.add_child(box)

	var title := Label.new()
	title.text = "设置"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	fullscreen_toggle = CheckButton.new()
	fullscreen_toggle.text = "全屏显示"
	fullscreen_toggle.button_pressed = _session().fullscreen
	box.add_child(fullscreen_toggle)

	var resolution_label := Label.new()
	resolution_label.text = "窗口分辨率"
	box.add_child(resolution_label)

	resolution_option = OptionButton.new()
	for resolution in _session().RESOLUTIONS:
		resolution_option.add_item("%d × %d" % [resolution.x, resolution.y])
	resolution_option.selected = _session().resolution_index
	box.add_child(resolution_option)

	var volume_label := Label.new()
	volume_label.text = "主音量"
	box.add_child(volume_label)

	volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.step = 1
	volume_slider.value = _session().master_volume * 100.0
	box.add_child(volume_slider)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)

	var apply_button := Button.new()
	apply_button.text = "应用"
	apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_dialog_button(apply_button, Color(0.28, 0.9, 0.72))
	apply_button.pressed.connect(_on_apply_settings_pressed)
	actions.add_child(apply_button)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_dialog_button(close_button)
	close_button.pressed.connect(_on_close_settings_pressed)
	actions.add_child(close_button)

func _build_about_panel() -> void:
	about_panel = _make_modal_panel("AboutPanel", Vector2(430, 310))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	about_panel.add_child(box)

	var title := Label.new()
	title.text = "制作信息"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	var info := Label.new()
	info.text = "装机人生 / PC Building Life\n\n开发：AKG Studio\n引擎：Godot Engine 4.7\n版本：%s\n\n本项目正在持续完善中。" % str(ProjectSettings.get_setting("application/config/version", "dev"))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_theme_color_override("font_color", Color(0.72, 0.78, 0.9))
	box.add_child(info)

	var close_button := Button.new()
	close_button.text = "关闭"
	_style_dialog_button(close_button)
	close_button.pressed.connect(_hide_modals)
	box.add_child(close_button)

func _build_quit_panel() -> void:
	quit_panel = _make_modal_panel("QuitPanel", Vector2(430, 220))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	quit_panel.add_child(box)

	var title := Label.new()
	title.text = "退出游戏？"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	var message := Label.new()
	message.text = "未保存的进度将会丢失。"
	message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message.add_theme_color_override("font_color", Color(0.78, 0.82, 0.92))
	box.add_child(message)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)

	var cancel_button := Button.new()
	cancel_button.text = "取消"
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_dialog_button(cancel_button)
	cancel_button.pressed.connect(_hide_modals)
	actions.add_child(cancel_button)

	var confirm_button := Button.new()
	confirm_button.text = "退出"
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_dialog_button(confirm_button, Color(1.0, 0.48, 0.36))
	confirm_button.pressed.connect(get_tree().quit)
	actions.add_child(confirm_button)

func _build_recovery_panel() -> void:
	recovery_panel = _make_modal_panel("SaveRecoveryPanel", Vector2(540, 280))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	recovery_panel.add_child(box)

	var title := Label.new()
	title.text = "存档需要处理"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	recovery_message = Label.new()
	recovery_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	recovery_message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	recovery_message.add_theme_color_override("font_color", Color(0.78, 0.82, 0.92))
	box.add_child(recovery_message)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)

	var cancel_button := Button.new()
	cancel_button.text = "取消"
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_dialog_button(cancel_button)
	cancel_button.pressed.connect(_hide_modals)
	actions.add_child(cancel_button)

	recovery_restore_button = Button.new()
	recovery_restore_button.text = "恢复备份"
	recovery_restore_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_dialog_button(recovery_restore_button, Color(0.28, 0.9, 0.72))
	recovery_restore_button.pressed.connect(_on_recovery_restore_pressed)
	actions.add_child(recovery_restore_button)

	var new_game_button := Button.new()
	new_game_button.text = "归档坏档并开始新游戏"
	new_game_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_dialog_button(new_game_button, Color(1.0, 0.68, 0.28))
	new_game_button.pressed.connect(_on_recovery_new_game_pressed)
	actions.add_child(new_game_button)

func _make_modal_panel(panel_name: String, panel_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.visible = false
	panel.custom_minimum_size = panel_size
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_size.x / 2.0
	panel.offset_top = -panel_size.y / 2.0
	panel.offset_right = panel_size.x / 2.0
	panel.offset_bottom = panel_size.y / 2.0
	panel.add_theme_stylebox_override("panel", _stylebox(Color(0.015, 0.025, 0.09, 0.985), Color(0.18, 0.8, 0.86), 7))
	panel.z_index = 20
	add_child(panel)
	return panel

func _refresh_continue_state() -> void:
	if continue_button == null:
		return
	var state: Dictionary = _session().inspect_save(_save_path())
	continue_button.disabled = not bool(state.valid) and not bool(state.backup_valid)
	continue_button.text = "恢复并继续" if not bool(state.valid) and bool(state.backup_valid) else "继续游戏"
	if bool(state.valid):
		continue_button.tooltip_text = "读取上次保存的装机进度"
	elif bool(state.backup_valid):
		continue_button.tooltip_text = "主存档不可用，可以恢复上一份有效备份"
	elif bool(state.corrupt):
		continue_button.tooltip_text = "当前存档损坏且没有有效备份"
	else:
		continue_button.tooltip_text = "暂无可继续的存档"
	_refresh_save_snapshot(state)
	if is_inside_tree():
		call_deferred("_focus_default_action")

func _refresh_save_snapshot(state: Dictionary) -> void:
	if snapshot_status_label == null:
		return
	var save_data := _read_snapshot_save_data(state)
	var has_valid_save := bool(state.get("valid", false))
	var has_backup := bool(state.get("backup_valid", false))
	var is_corrupt := bool(state.get("corrupt", false))
	var total_orders := maxi(1, order_defs.size())
	var money := 20000
	var completed_count := 0
	var current_order_index := 0
	var installed_count := 0
	var inventory_count := 0
	var system_state := "未开机"

	if not save_data.is_empty():
		money = int(save_data.get("money", money))
		completed_count = _string_array_size(save_data.get("completed_order_ids", []))
		current_order_index = int(save_data.get("current_order_index", 0))
		var installed_value: Variant = save_data.get("installed", {})
		if typeof(installed_value) == TYPE_DICTIONARY:
			installed_count = (installed_value as Dictionary).size()
		inventory_count = _saved_inventory_quantity(save_data.get("inventory", []))
		system_state = _saved_system_state(save_data)

	var order_name := _saved_order_name(current_order_index, completed_count, total_orders)
	_set_snapshot_metric("money", "￥%d" % money)
	_set_snapshot_metric("order", order_name)
	_set_snapshot_metric("completed", "%d / %d" % [completed_count, total_orders])
	_set_snapshot_metric("installed", "%d / %d" % [installed_count, CORE_SLOT_COUNT])
	_set_snapshot_metric("system", system_state)
	_set_snapshot_metric("inventory", "%d 件" % inventory_count)

	if has_valid_save:
		_set_snapshot_status("存档可用", Color(0.28, 0.9, 0.72), Color(0.02, 0.13, 0.16, 0.96))
		snapshot_title_label.text = "继续当前工作台"
		snapshot_subtitle_label.text = "订单、资金、仓库和模拟系统进度已就绪。"
		snapshot_next_label.text = "返回“%s”，从当前装机或系统配置状态继续。" % order_name
		snapshot_action_button.text = "进入当前工作台"
	elif has_backup:
		_set_snapshot_status("备份可恢复", Color(1.0, 0.72, 0.28), Color(0.16, 0.09, 0.02, 0.96))
		snapshot_title_label.text = "发现可恢复进度"
		snapshot_subtitle_label.text = "主存档不可用，但上一份有效备份仍然保留。"
		snapshot_next_label.text = "先打开存档处理面板，确认恢复备份后继续。"
		snapshot_action_button.text = "处理存档"
	elif is_corrupt:
		_set_snapshot_status("存档需处理", Color(1.0, 0.46, 0.38), Color(0.18, 0.045, 0.055, 0.96))
		snapshot_title_label.text = "当前存档不可读取"
		snapshot_subtitle_label.text = "损坏文件不会被直接覆盖，可以先归档再开始新游戏。"
		snapshot_next_label.text = "打开存档处理面板，保留坏档后创建新的工作台。"
		snapshot_action_button.text = "处理存档"
	else:
		_set_snapshot_status("新工作台", Color(0.28, 0.9, 0.86), Color(0.02, 0.13, 0.16, 0.96))
		snapshot_title_label.text = "从第一份订单开始"
		snapshot_subtitle_label.text = "本地还没有装机进度，首单将从“%s”开始。" % order_name
		snapshot_next_label.text = "创建工作台，接取首单并开始采购配件。"
		snapshot_action_button.text = "创建工作台"

func _read_snapshot_save_data(state: Dictionary) -> Dictionary:
	var path := ""
	if bool(state.get("valid", false)):
		path = str(state.get("path", ""))
	elif bool(state.get("backup_valid", false)):
		path = str(state.get("backup_path", ""))
	if path.is_empty():
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary

func _load_order_defs() -> Array:
	var file := FileAccess.open(ORDERS_PATH, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Array if typeof(parsed) == TYPE_ARRAY else []

func _saved_order_name(order_index: int, completed_count: int, total_orders: int) -> String:
	if completed_count >= total_orders or order_index < 0:
		return "全部订单完成"
	if order_index >= 0 and order_index < order_defs.size():
		return str((order_defs[order_index] as Dictionary).get("name", "当前订单"))
	return "社区办公机"

func _saved_inventory_quantity(value: Variant) -> int:
	if typeof(value) != TYPE_ARRAY:
		return 0
	var quantity := 0
	for raw_stack in value as Array:
		if typeof(raw_stack) == TYPE_DICTIONARY:
			quantity += maxi(1, int((raw_stack as Dictionary).get("quantity", 1)))
	return quantity

func _string_array_size(value: Variant) -> int:
	return (value as Array).size() if typeof(value) == TYPE_ARRAY else 0

func _saved_system_state(save_data: Dictionary) -> String:
	if not bool(save_data.get("powered_on", false)):
		return "未开机"
	if not bool(save_data.get("system_booted", false)):
		return "等待进入 OS"
	if bool(save_data.get("os_restart_required", false)):
		return "等待系统重启"
	if bool(save_data.get("drivers_installed", false)):
		return "驱动已验证"
	if bool(save_data.get("driver_scan_completed", false)):
		return "设备已扫描"
	return "OS 已启动"

func _set_snapshot_metric(key: String, value: String) -> void:
	var label: Label = snapshot_metric_values.get(key)
	if label == null:
		return
	label.text = value
	label.tooltip_text = value

func _set_snapshot_status(text: String, accent: Color, background: Color) -> void:
	snapshot_status_label.text = text
	snapshot_status_label.add_theme_color_override("font_color", accent.lightened(0.18))
	snapshot_status_chip.add_theme_stylebox_override("panel", _stylebox(background, accent, 4))

func _save_path() -> String:
	return save_path_override if save_path_override != "" else DEFAULT_SAVE_PATH

func _session() -> Node:
	return get_node("/root/GameSession")

func _on_continue_pressed() -> void:
	var state: Dictionary = _session().inspect_save(_save_path())
	if bool(state.corrupt) or (not bool(state.valid) and bool(state.backup_valid)):
		_show_recovery_modal(state)
		return
	if not bool(state.valid):
		_refresh_continue_state()
		return
	_session().request_continue()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_snapshot_action_pressed() -> void:
	var state: Dictionary = _session().inspect_save(_save_path())
	if bool(state.get("valid", false)):
		_on_continue_pressed()
	elif bool(state.get("corrupt", false)) or bool(state.get("backup_valid", false)):
		_show_recovery_modal(state)
	else:
		_on_new_game_pressed()

func _on_new_game_pressed() -> void:
	_session().request_new_game()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_settings_pressed() -> void:
	_show_modal(settings_panel)

func _on_close_settings_pressed() -> void:
	_hide_modals()

func _on_about_pressed() -> void:
	_show_modal(about_panel)

func _on_quit_pressed() -> void:
	_show_modal(quit_panel)

func _show_modal(panel: PanelContainer) -> void:
	_hide_modals()
	settings_backdrop.visible = true
	panel.visible = true

func _hide_modals() -> void:
	settings_backdrop.visible = false
	for panel in [settings_panel, about_panel, quit_panel, recovery_panel]:
		if panel != null:
			panel.visible = false

func _show_recovery_modal(state: Dictionary) -> void:
	var has_backup := bool(state.get("backup_valid", false))
	recovery_restore_button.visible = has_backup
	if has_backup:
		recovery_message.text = "当前存档无法读取，但检测到上一份有效备份。恢复前会先归档损坏文件，原文件不会被直接覆盖。"
	else:
		recovery_message.text = "当前存档无法读取，也没有可用备份。可以归档损坏文件并开始新游戏，稍后仍可人工检查归档文件。"
	_show_modal(recovery_panel)

func _on_recovery_restore_pressed() -> void:
	if not _session().restore_save_backup(_save_path()):
		recovery_message.text = "备份恢复失败，请检查存档目录权限。"
		return
	_hide_modals()
	_refresh_continue_state()
	continue_button.text = "继续游戏"

func _on_recovery_new_game_pressed() -> void:
	_session().archive_corrupt_save(_save_path())
	_session().request_new_game()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_apply_settings_pressed() -> void:
	_session().set_fullscreen(fullscreen_toggle.button_pressed)
	_session().set_resolution(resolution_option.selected)
	_session().set_master_volume(float(volume_slider.value) / 100.0)
	_session().apply_settings()
	_session().save_settings()
	_hide_modals()

func _stylebox(color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border_color
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box
