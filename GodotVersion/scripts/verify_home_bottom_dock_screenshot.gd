extends SceneTree

const SIZES := [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1920, 1080),
]

func _init() -> void:
	for size in SIZES:
		if not await _capture_home_bottom_dock(size):
			return
	print("home_bottom_dock_screenshot=ok")
	quit(0)

func _capture_home_bottom_dock(size: Vector2i) -> bool:
	await _prepare_window(size)
	var game_scene := load("res://scenes/Game.tscn")
	var game: Control = game_scene.instantiate()
	root.add_child(game)
	await _settle()
	_prepare_dense_home_state(game)
	await _settle()

	if not _assert_home_bottom_dock_layout(game, size):
		return false

	var image: Image = root.get_texture().get_image()
	if image == null:
		return _fail("Viewport image is not available.")
	var physical_size := Vector2i(image.get_width(), image.get_height())
	var saved_image := image
	if physical_size != size:
		saved_image = image.duplicate()
		saved_image.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var path := "res://../GodotVersion-home-bottom-dock-check-%dx%d.png" % [size.x, size.y]
	var err := saved_image.save_png(path)
	if err != OK:
		return _fail("Failed to save home bottom dock screenshot: %s" % error_string(err))
	print("home_bottom_dock_path=%s" % ProjectSettings.globalize_path(path))
	print("home_bottom_dock_physical_size=%dx%d" % [physical_size.x, physical_size.y])
	print("home_bottom_dock_saved_size=%dx%d" % [saved_image.get_width(), saved_image.get_height()])

	game.queue_free()
	await process_frame
	return true

func _prepare_dense_home_state(game: Control) -> void:
	var component_database := root.get_node("/root/ComponentDatabase")
	var installed_ids := {
		"Case": 10081,
		"Power": 10051,
		"MotherBoard": 10021,
		"CPU": 10001,
		"VideoCard": 10018,
		"RAM": 10031,
	}
	for slot in installed_ids.keys():
		game.installed[slot] = component_database.components_by_id[int(installed_ids[slot])].duplicate(true)
	game.money = 4750
	game._on_slot_pressed("CPU")
	game._refresh_all()

func _assert_home_bottom_dock_layout(game: Control, size: Vector2i) -> bool:
	var viewport_size: Vector2 = root.get_visible_rect().size
	if game.main_tabs == null:
		return _fail("Main tabs are missing at %dx%d." % [size.x, size.y])
	if game.main_tabs.tabs_visible:
		return _fail("Main shop/inventory TabContainer labels should be hidden at %dx%d." % [size.x, size.y])
	if game.main_tabs.visible:
		return _fail("Main shop/inventory TabContainer content should be hidden at %dx%d." % [size.x, size.y])
	if game.catalog_workspace_panel == null or not game.catalog_workspace_panel.visible:
		return _fail("Catalog workspace panel is missing at %dx%d." % [size.x, size.y])
	if game.home_bottom_dock == null:
		return _fail("HomeBottomDock is missing at %dx%d." % [size.x, size.y])
	if game.home_workbench_tab_button == null or game.home_workbench_tab_button.icon == null:
		return _fail("Workbench mode tab is missing its illustrated icon at %dx%d." % [size.x, size.y])

	var dock_rect: Rect2 = game.home_bottom_dock.get_global_rect()
	var tabs_rect: Rect2 = game.main_tabs.get_global_rect()
	if dock_rect.position.y < tabs_rect.end.y - 1.0:
		return _fail("HomeBottomDock overlaps the shop/inventory panel at %dx%d." % [size.x, size.y])
	if dock_rect.end.y > viewport_size.y + 1.0:
		return _fail("HomeBottomDock is clipped at %dx%d: bottom=%.1f viewport=%.1f." % [size.x, size.y, dock_rect.end.y, viewport_size.y])
	if dock_rect.size.x < viewport_size.x - 48.0:
		return _fail("HomeBottomDock is too narrow at %dx%d: %.1f." % [size.x, size.y, dock_rect.size.x])
	if dock_rect.size.y < 168.0:
		return _fail("HomeBottomDock is too short at %dx%d: %.1f." % [size.x, size.y, dock_rect.size.y])
	var workspace_rect: Rect2 = game.catalog_workspace_panel.get_global_rect()
	if workspace_rect.end.y > dock_rect.position.y - 1.0:
		return _fail("Catalog workspace collides with HomeBottomDock at %dx%d." % [size.x, size.y])
	if workspace_rect.size.y < 260.0:
		return _fail("Catalog workspace is too short at %dx%d: %.1f." % [size.x, size.y, workspace_rect.size.y])
	if game.catalog_workspace_shop_button == null or game.catalog_workspace_inventory_button == null:
		return _fail("Catalog workspace buttons are missing at %dx%d." % [size.x, size.y])
	if game.catalog_workspace_state_label == null or not str(game.catalog_workspace_state_label.text).contains("当前状态"):
		return _fail("Catalog workspace does not expose current state at %dx%d." % [size.x, size.y])
	if game.catalog_workspace_pressure_chip_label == null or not str(game.catalog_workspace_pressure_chip_label.text).contains("订单压力"):
		return _fail("Catalog workspace does not expose order pressure at %dx%d." % [size.x, size.y])
	if game.catalog_workspace_next_action_label == null or not str(game.catalog_workspace_next_action_label.text).contains("推荐操作"):
		return _fail("Catalog workspace does not expose recommended action at %dx%d." % [size.x, size.y])
	for workspace_button in [game.catalog_workspace_shop_button, game.catalog_workspace_inventory_button]:
		var workspace_button_rect: Rect2 = workspace_button.get_global_rect()
		if not workspace_rect.encloses(workspace_button_rect):
			return _fail("%s is outside CatalogWorkspacePanel at %dx%d." % [str(workspace_button.name), size.x, size.y])
		if workspace_button_rect.size.y < 44.0:
			return _fail("%s is too short at %dx%d." % [str(workspace_button.name), size.x, size.y])
		if workspace_button.focus_mode != Control.FOCUS_ALL:
			return _fail("%s is not keyboard/gamepad focusable at %dx%d." % [str(workspace_button.name), size.x, size.y])

	var buttons: Array[Button] = [
		game.home_task_center_button,
		game.home_order_desk_button,
		game.home_deliver_order_button,
		game.home_system_center_button,
		game.home_system_monitor_button,
	]
	var names := [
		"HomeTaskCenterButton",
		"HomeOrderDeskButton",
		"HomeDeliverOrderButton",
		"HomeSystemCenterButton",
		"HomeSystemMonitorButton",
	]
	for index in range(buttons.size()):
		var button := buttons[index]
		if button == null:
			return _fail("Bottom dock button is missing: %s." % names[index])
		if str(button.name) != names[index]:
			return _fail("Bottom dock button has wrong name: expected %s got %s." % [names[index], str(button.name)])
		var rect := button.get_global_rect()
		if not dock_rect.encloses(rect):
			return _fail("%s is outside HomeBottomDock at %dx%d." % [names[index], size.x, size.y])
		if rect.size.x < 72.0 or rect.size.y < 22.0:
			return _fail("%s is too small at %dx%d: %.1fx%.1f." % [names[index], size.x, size.y, rect.size.x, rect.size.y])
		if button.focus_mode != Control.FOCUS_ALL:
			return _fail("%s is not keyboard/gamepad focusable." % names[index])

	for index in range(1, buttons.size()):
		if buttons[index - 1].focus_neighbor_right != buttons[index].get_path():
			return _fail("Bottom dock focus-right chain is broken before %s." % names[index])
		if buttons[index].focus_neighbor_left != buttons[index - 1].get_path():
			return _fail("Bottom dock focus-left chain is broken at %s." % names[index])

	if not str(game.status_label.text).contains("当前步骤"):
		return _fail("Workflow card does not expose current step text.")
	if not str(game.order_label.text).contains("当前订单"):
		return _fail("Order card does not expose current order text.")
	if not str(game.os_label.text).contains("模拟系统"):
		return _fail("System card does not expose OS state text.")
	if not str(game.order_state_chip_label.text).is_empty() and str(game.order_state_chip_label.text).length() > 10:
		return _fail("Order state chip text is too long: %s." % str(game.order_state_chip_label.text))
	return true

func _prepare_window(size: Vector2i) -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(Vector2i(120, 120))
	root.size = size
	await _settle()

func _settle() -> void:
	for _frame in range(4):
		await process_frame

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
