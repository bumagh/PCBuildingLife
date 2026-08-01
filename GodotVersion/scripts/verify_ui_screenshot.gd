extends SceneTree

const SCREENSHOT_PATH := "res://../GodotVersion-ui-check-1280x720.png"
const TARGET_SIZE := Vector2i(1280, 720)

func _init() -> void:
	root.size = TARGET_SIZE

	var game_scene := load("res://scenes/Game.tscn")
	var game: Control = game_scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	_prepare_dense_ui_state(game)
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	var viewport_size: Vector2 = root.get_visible_rect().size
	if game.home_bottom_dock == null:
		push_error("Expected HomeBottomDock to replace the old lower tab area.")
		quit(1)
		return
	var dock_rect: Rect2 = game.home_bottom_dock.get_global_rect()
	var tabs_rect: Rect2 = game.main_tabs.get_global_rect()
	if dock_rect.position.y < tabs_rect.end.y - 1.0:
		push_error("HomeBottomDock overlaps the shop/inventory area.")
		quit(1)
		return
	if dock_rect.end.y > viewport_size.y + 1.0:
		push_error("HomeBottomDock is clipped in %dx%d: end_y %.1f." % [int(viewport_size.x), int(viewport_size.y), dock_rect.end.y])
		quit(1)
		return
	if dock_rect.size.y < 150.0:
		push_error("HomeBottomDock is too short: %.1f." % dock_rect.size.y)
		quit(1)
		return
	if dock_rect.size.x < viewport_size.x - 48.0:
		push_error("HomeBottomDock is too narrow: %.1f." % dock_rect.size.x)
		quit(1)
		return
	for text in ["工作流", "订单", "系统"]:
		if not _has_visible_label_text(game.home_bottom_dock, text):
			push_error("Expected bottom dock text: %s." % text)
			quit(1)
			return
	if game.status_label == null or not str(game.status_label.text).contains("当前步骤"):
		push_error("Expected the workflow card to expose the current step.")
		quit(1)
		return
	if game.tutorial_progress_label == null or not str(game.tutorial_progress_label.text).contains("新手引导"):
		push_error("Expected the workflow card to expose tutorial progress.")
		quit(1)
		return
	if game.tutorial_label == null or str(game.tutorial_label.text).is_empty():
		push_error("Expected the workflow card to show step detail text.")
		quit(1)
		return
	if game.tutorial_action_button == null or str(game.tutorial_action_button.text).is_empty():
		push_error("Expected the workflow card to show the primary action button.")
		quit(1)
		return
	if game.progression_label == null or not str(game.progression_label.text).contains("阻塞"):
		push_error("Expected the workflow card to show a blocker reason.")
		quit(1)
		return
	if game.order_label == null or not str(game.order_label.text).contains("当前订单"):
		push_error("Expected the order card to show a current-order summary.")
		quit(1)
		return
	if str(game.order_label.text).contains("\n"):
		push_error("Expected the order card to stay single-line.")
		quit(1)
		return
	if game.score_label == null or not str(game.score_label.text).contains("交付评分"):
		push_error("Expected the order card to show a delivery-score summary.")
		quit(1)
		return
	if game.os_label == null or not str(game.os_label.text).contains("模拟系统"):
		push_error("Expected the system card to show a system summary.")
		quit(1)
		return
	if str(game.os_label.text).contains("\n"):
		push_error("Expected the system card to stay single-line.")
		quit(1)
		return
	if _has_visible_extra_tab_container(game, game.main_tabs):
		push_error("Expected the old lower TabContainer to be removed.")
		quit(1)
		return
	if game.main_tabs.visible:
		push_error("Expected the legacy shop/inventory TabContainer content to be hidden from the home screen.")
		quit(1)
		return
	if game.catalog_workspace_panel == null or not game.catalog_workspace_panel.visible:
		push_error("Expected the right-side catalog workspace entry panel.")
		quit(1)
		return
	if game.catalog_workspace_panel.get_global_rect().size.y < 260.0:
		push_error("CatalogWorkspacePanel is too short.")
		quit(1)
		return
	if game.catalog_workspace_shop_button == null or game.catalog_workspace_inventory_button == null:
		push_error("Expected catalog workspace market and inventory buttons.")
		quit(1)
		return
	if not str(game.catalog_workspace_summary_label.text).contains("全屏目录"):
		push_error("Expected catalog workspace to explain the full-screen catalog flow.")
		quit(1)
		return
	if game.catalog_workspace_state_label == null or not str(game.catalog_workspace_state_label.text).contains("当前状态"):
		push_error("Expected catalog workspace to show the current slot/order state.")
		quit(1)
		return
	if game.catalog_workspace_pressure_chip_label == null or not str(game.catalog_workspace_pressure_chip_label.text).contains("订单压力"):
		push_error("Expected catalog workspace to show order pressure.")
		quit(1)
		return
	if game.catalog_workspace_next_action_label == null or not str(game.catalog_workspace_next_action_label.text).contains("推荐操作"):
		push_error("Expected catalog workspace to show a recommended action.")
		quit(1)
		return
	if game.workbench_footer == null or game.workbench_footer_summary_label == null:
		push_error("Expected the left workbench footer quick bar.")
		quit(1)
		return
	var footer_rect: Rect2 = game.workbench_footer.get_global_rect()
	if footer_rect.end.y > viewport_size.y + 1.0:
		push_error("WorkbenchFooter is clipped in %dx%d: end_y %.1f." % [int(viewport_size.x), int(viewport_size.y), footer_rect.end.y])
		quit(1)
		return
	if not str(game.workbench_footer_summary_label.text).contains("下一步"):
		push_error("Expected WorkbenchFooter to show the next-step hint.")
		quit(1)
		return
	if game.order_state_chip_label == null or game.order_progress_bar == null:
		push_error("Expected order status chip and progress bar.")
		quit(1)
		return
	if game.os_state_chip_label == null or game.os_progress_bar == null:
		push_error("Expected system status chip and progress bar.")
		quit(1)
		return
	if game.home_system_center_button == null or game.home_system_monitor_button == null:
		push_error("Expected the compact home system buttons.")
		quit(1)
		return
	if str(game.home_system_center_button.name) != "HomeSystemCenterButton" or str(game.home_system_monitor_button.name) != "HomeSystemMonitorButton":
		push_error("Expected the home system card to expose the compact system buttons.")
		quit(1)
		return
	var system_center_button_width: float = game.home_system_center_button.get_global_rect().size.x
	var system_monitor_button_width: float = game.home_system_monitor_button.get_global_rect().size.x
	if system_center_button_width < 72.0 or system_monitor_button_width < 72.0:
		push_error("Expected the home system buttons to stay wide enough, got %.1f and %.1f." % [system_center_button_width, system_monitor_button_width])
		quit(1)
		return
	var order_chip_text := str(game.order_state_chip_label.text)
	if order_chip_text.contains("评分") or order_chip_text.contains("完成"):
		push_error("Expected order status chip to stay short.")
		quit(1)
		return
	if order_chip_text.length() > 10:
		push_error("Expected order status chip to fit in the home dock.")
		quit(1)
		return
	if not str(game.os_state_chip_label.text).contains("未开机"):
		push_error("Expected system status chip to surface boot state.")
		quit(1)
		return
	if game.order_progress_bar.get_global_rect().size.y < 10.0 or game.os_progress_bar.get_global_rect().size.y < 10.0:
		push_error("Expected visible progress bars in the home dock.")
		quit(1)
		return
	if game.cheat_button != null and game.cheat_button.visible and game.cheat_button.get_global_rect().intersects(footer_rect):
		push_error("Cheat button overlaps the WorkbenchFooter.")
		quit(1)
		return
	var image := root.get_texture().get_image()
	if image == null:
		push_error("Viewport image is not available.")
		quit(1)
		return

	var saved_image := image
	if image.get_size() != TARGET_SIZE:
		saved_image = image.duplicate()
		saved_image.resize(TARGET_SIZE.x, TARGET_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var err := saved_image.save_png(SCREENSHOT_PATH)
	if err != OK:
		push_error("Failed to save UI screenshot: %s" % error_string(err))
		quit(1)
		return

	print("ui_screenshot=ok")
	print("path=%s" % ProjectSettings.globalize_path(SCREENSHOT_PATH))
	print("size=%dx%d" % [image.get_width(), image.get_height()])
	print("saved_size=%dx%d" % [saved_image.get_width(), saved_image.get_height()])
	quit(0)

func _prepare_dense_ui_state(game: Control) -> void:
	var component_database := root.get_node("/root/ComponentDatabase")
	var installed_ids := {
		"Case": 10081,
		"Power": 10051,
		"MotherBoard": 10021,
		"CPU": 10001,
		"VideoCard": 10018,
	}
	for slot in installed_ids.keys():
		game.installed[slot] = component_database.components_by_id[int(installed_ids[slot])].duplicate(true)
	game.money = 4405
	game._on_slot_pressed("CPU")
	var tab_container := _find_first_tab_container(game)
	if tab_container:
		tab_container.current_tab = 1
	game._refresh_all()
	game.shop_panel._compatible_toggle.button_pressed = true
	game.shop_panel._order_toggle.button_pressed = true
	await _select_first_shop_item(game)

func _select_first_shop_item(game: Control) -> void:
	await process_frame
	var list := _find_first_item_list(game.shop_panel)
	if list and list.item_count > 0:
		list.select(0)
		game.shop_panel._on_item_selected(0)

func _find_first_item_list(node: Node) -> ItemList:
	if node is ItemList:
		return node
	for child in node.get_children():
		var found := _find_first_item_list(child)
		if found:
			return found
	return null

func _find_first_tab_container(node: Node) -> TabContainer:
	if node is TabContainer:
		return node
	for child in node.get_children():
		var found := _find_first_tab_container(child)
		if found:
			return found
	return null

func _has_visible_label_text(node: Node, text: String) -> bool:
	if node is Label and node.visible and str(node.text).contains(text):
		return true
	for child in node.get_children():
		if _has_visible_label_text(child, text):
			return true
	return false

func _has_visible_extra_tab_container(node: Node, allowed: TabContainer) -> bool:
	if node is TabContainer and node != allowed and node.visible:
		return true
	for child in node.get_children():
		if _has_visible_extra_tab_container(child, allowed):
			return true
	return false
