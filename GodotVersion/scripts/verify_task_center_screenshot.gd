extends SceneTree

const SIZES := [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1920, 1080),
]

func _init() -> void:
	for size in _requested_sizes():
		if not await _capture_task_center(size):
			return
	print("task_center_screenshot=ok")
	quit(0)

func _requested_sizes() -> Array[Vector2i]:
	var sizes: Array[Vector2i] = []
	for raw_arg in OS.get_cmdline_user_args():
		var arg := str(raw_arg)
		if not arg.begins_with("--pcbl-size="):
			continue
		var size := _parse_size(arg.trim_prefix("--pcbl-size="))
		if size == Vector2i.ZERO:
			_fail("Invalid --pcbl-size value: %s" % arg)
			return sizes
		sizes.append(size)
	return sizes if not sizes.is_empty() else SIZES

func _parse_size(value: String) -> Vector2i:
	var parts := value.split("x")
	if parts.size() != 2:
		return Vector2i.ZERO
	if not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i.ZERO
	var width := parts[0].to_int()
	var height := parts[1].to_int()
	if width <= 0 or height <= 0:
		return Vector2i.ZERO
	return Vector2i(width, height)

func _capture_task_center(size: Vector2i) -> bool:
	await _prepare_window(size)
	var game_scene := load("res://scenes/Game.tscn")
	var game: Control = game_scene.instantiate()
	root.add_child(game)
	await _settle()

	if not _prepare_task_center_state(game):
		return false
	game.open_task_center_overlay()
	await _settle()

	if not _assert_task_center_layout(game, size):
		return false

	var image: Image = root.get_texture().get_image()
	if image == null:
		return _fail("Viewport image is not available.")
	var physical_size := Vector2i(image.get_width(), image.get_height())
	var saved_image := image
	if physical_size != size:
		saved_image = image.duplicate()
		saved_image.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var path := "res://../GodotVersion-task-center-check-%dx%d.png" % [size.x, size.y]
	var err := saved_image.save_png(path)
	if err != OK:
		return _fail("Failed to save task center screenshot: %s" % error_string(err))
	print("task_center_path=%s" % ProjectSettings.globalize_path(path))
	print("task_center_physical_size=%dx%d" % [physical_size.x, physical_size.y])
	print("task_center_saved_size=%dx%d" % [saved_image.get_width(), saved_image.get_height()])

	game.queue_free()
	await process_frame
	return true

func _prepare_task_center_state(game: Control) -> bool:
	if not game.apply_cheat_fill_current_order():
		return _fail("Failed to prepare current order for task center screenshot.")
	game._on_finish_pressed()
	game._on_power_button_pressed()
	game._on_driver_scan_pressed()
	game._on_driver_install_pressed()
	game._on_driver_restart_pressed()
	if game._current_order_requires_task("gpu_driver"):
		game._on_gpu_driver_install_pressed()
	if game._current_order_requires_task("benchmark"):
		game._on_os_benchmark_pressed()
	if game._current_order_requires_task("stability"):
		game._on_os_stability_test_pressed()
	return true

func _assert_task_center_layout(game: Control, size: Vector2i) -> bool:
	var viewport_size: Vector2 = root.get_visible_rect().size
	var overlay_rect: Rect2 = game.task_center_overlay.get_global_rect()
	if overlay_rect.position.x > 1.0 or overlay_rect.position.y > 1.0:
		return _fail("Task center overlay does not start at viewport origin.")
	if overlay_rect.end.x < viewport_size.x - 1.0 or overlay_rect.end.y < viewport_size.y - 1.0:
		return _fail("Task center overlay does not fill viewport at %dx%d." % [size.x, size.y])
	var order_rect: Rect2 = game.task_center_order_label.get_global_rect()
	var software_rect: Rect2 = game.task_center_software_label.get_global_rect()
	var delivery_rect: Rect2 = game.task_center_delivery_label.get_global_rect()
	if order_rect.size.x < 270.0 or software_rect.size.x < 270.0 or delivery_rect.size.x < 250.0:
		return _fail("Task center columns are too narrow at %dx%d." % [size.x, size.y])
	if order_rect.end.x >= software_rect.position.x:
		return _fail("Task center order column overlaps software column at %dx%d." % [size.x, size.y])
	if software_rect.end.x >= delivery_rect.position.x:
		return _fail("Task center software column overlaps delivery column at %dx%d." % [size.x, size.y])
	var status_rect: Rect2 = game.task_center_status_label.get_global_rect()
	var status_text := str(game.task_center_status_label.text)
	if status_rect.size.x < 520.0 or status_rect.size.y < 42.0:
		return _fail("Task center status summary is too small at %dx%d." % [size.x, size.y])
	if status_rect.end.x > viewport_size.x - 104.0:
		return _fail("Task center status summary collides with close button area at %dx%d." % [size.x, size.y])
	if not status_text.contains("当前订单") or not status_text.contains("软件") or not status_text.contains("下一步"):
		return _fail("Task center status summary is missing dashboard fields at %dx%d." % [size.x, size.y])
	if game.task_center_deliver_button.get_global_rect().end.y > viewport_size.y - 8.0:
		return _fail("Task center action grid collides with bottom edge at %dx%d." % [size.x, size.y])
	if game.task_center_next_button.text.is_empty() or game.task_center_delivery_label.text.is_empty():
		return _fail("Task center labels did not render at %dx%d." % [size.x, size.y])
	return true

func _prepare_window(size: Vector2i) -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(Vector2i(90, 90))
	root.size = size
	await _settle()

func _settle() -> void:
	for _frame in range(4):
		await process_frame

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
