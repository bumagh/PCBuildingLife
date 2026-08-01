extends SceneTree

const SIZES := [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1920, 1080),
]

func _init() -> void:
	for size in SIZES:
		if not await _capture_workbench(size):
			return
	print("workbench_screenshot=ok")
	quit(0)

func _capture_workbench(size: Vector2i) -> bool:
	await _prepare_window(size)
	var game_scene := load("res://scenes/Game.tscn")
	var game: Control = game_scene.instantiate()
	root.add_child(game)
	await _settle()
	_prepare_workbench_state(game)
	await _settle()

	var image: Image = root.get_texture().get_image()
	if image == null:
		return _fail("Viewport image is not available.")
	var physical_size := Vector2i(image.get_width(), image.get_height())
	var saved_image := image
	if physical_size != size:
		saved_image = image.duplicate()
		saved_image.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var path := "res://../GodotVersion-workbench-check-%dx%d.png" % [size.x, size.y]
	var err := saved_image.save_png(path)
	if err != OK:
		return _fail("Failed to save workbench screenshot: %s" % error_string(err))
	print("workbench_path=%s" % ProjectSettings.globalize_path(path))
	print("workbench_physical_size=%dx%d" % [physical_size.x, physical_size.y])
	print("workbench_saved_size=%dx%d" % [saved_image.get_width(), saved_image.get_height()])

	if not _assert_workbench_layout(game, size):
		return false

	game.queue_free()
	await process_frame
	return true

func _prepare_workbench_state(game: Control) -> void:
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
	game._on_slot_pressed("CPU")
	game._refresh_all()

func _assert_workbench_layout(game: Control, size: Vector2i) -> bool:
	var viewport_size: Vector2 = root.get_visible_rect().size
	var panel_rect: Rect2 = game.building_panel.get_global_rect()
	if panel_rect.size.x < 500.0:
		return _fail("Workbench panel is too narrow at %dx%d." % [size.x, size.y])
	var visible_rect: Rect2 = (game.building_panel.get_parent() as Control).get_global_rect()
	if visible_rect.size.y < 350.0:
		var footer_height := 0.0
		if game.workbench_footer != null:
			footer_height = game.workbench_footer.get_global_rect().size.y
		print("workbench_visible=%.1f footer=%.1f" % [visible_rect.size.y, footer_height])
		return _fail("Workbench visible area is too short at %dx%d: visible=%.1f footer=%.1f." % [
			size.x,
			size.y,
			visible_rect.size.y,
			footer_height,
		])

	var cpu_marker: Control = game.building_panel._overlay_cards.get("CPU")
	var ram_card: Control = game.building_panel._visual_cards.get("RAM")
	var cooler_label: Control = game.building_panel._slot_labels.get("COOLER")
	if cpu_marker == null or ram_card == null:
		return _fail("Workbench slot drop targets are missing.")
	if not cpu_marker.has_method("_drop_data") or not ram_card.has_method("_drop_data"):
		return _fail("Workbench visual slots are not drag-drop targets.")

	var cpu_rect: Rect2 = cpu_marker.get_global_rect()
	var ram_rect: Rect2 = ram_card.get_global_rect()
	if cpu_rect.size.x < 20.0 or cpu_rect.size.y < 20.0:
		return _fail("CPU machine slot is too small at %dx%d." % [size.x, size.y])
	if ram_rect.size.x < 40.0 or ram_rect.size.y < 28.0:
		return _fail("RAM visual card is too small at %dx%d." % [size.x, size.y])
	if cooler_label == null:
		return _fail("Workbench bottom slot labels are missing at %dx%d." % [size.x, size.y])
	var cooler_rect: Rect2 = cooler_label.get_global_rect()
	if cooler_rect.end.y > visible_rect.end.y + 18.0:
		return _fail("Workbench bottom slot labels are not visible at %dx%d: bottom=%.1f visible=%.1f." % [
			size.x,
			size.y,
			cooler_rect.end.y,
			visible_rect.end.y,
		])

	var selected_text := String(game.building_panel._selected_slot_label.text)
	var checklist_text := String(game.building_panel._checklist_label.text)
	if not selected_text.contains("CPU") or checklist_text.is_empty():
		return _fail("Workbench selected slot or checklist text did not render.")
	if game.workbench_footer_summary_label == null or game.workbench_footer_completion_chip_label == null or game.workbench_footer_missing_chip_label == null or game.workbench_footer_next_chip_label == null:
		return _fail("Workbench footer status chips are missing.")
	var footer_text := str(game.workbench_footer_summary_label.text)
	if not footer_text.contains("当前订单"):
		return _fail("Workbench footer summary did not render current order.")
	if not str(game.workbench_footer_completion_chip_label.text).contains("完成度"):
		return _fail("Workbench footer completion chip did not render.")
	if not str(game.workbench_footer_missing_chip_label.text).contains("缺少"):
		return _fail("Workbench footer missing chip did not render.")
	if not str(game.workbench_footer_next_chip_label.text).contains("下一步"):
		return _fail("Workbench footer next-step chip did not render.")
	return true

func _prepare_window(size: Vector2i) -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(Vector2i(130, 130))
	root.size = size
	await _settle()

func _settle() -> void:
	for _frame in range(4):
		await process_frame

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
