extends SceneTree

const SIZES := [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1920, 1080),
]

func _init() -> void:
	var sizes := _requested_sizes()
	for index in range(sizes.size()):
		if not await _capture_monitor(sizes[index], index < sizes.size() - 1):
			return
	print("monitor_screenshot=ok")
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

func _capture_monitor(size: Vector2i, cleanup_after_capture: bool) -> bool:
	await _prepare_window(size)
	var game_scene := load("res://scenes/Game.tscn")
	var game: Control = game_scene.instantiate()
	root.add_child(game)
	await _settle()

	if not game.apply_cheat_fill_current_order():
		return _fail("Expected monitor screenshot setup to prepare an order build.")
	if not game.apply_cheat_open_monitor():
		return _fail("Expected monitor screenshot setup to open monitor.")
	game._on_monitor_driver_tool_pressed()
	game._on_driver_scan_pressed()
	game._on_driver_install_pressed()
	game._on_driver_restart_pressed()
	game._on_os_benchmark_pressed()
	game._on_monitor_files_pressed()
	game._on_file_preflight_pressed()
	await _settle()

	if not _assert_monitor_layout(game, size):
		return false

	var image := root.get_texture().get_image()
	if image == null:
		return _fail("Viewport image is not available.")

	var saved_image := image
	if image.get_size() != size:
		saved_image = image.duplicate()
		saved_image.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var path := "res://../GodotVersion-monitor-check-%dx%d.png" % [size.x, size.y]
	var err := saved_image.save_png(path)
	if err != OK:
		return _fail("Failed to save monitor screenshot: %s" % error_string(err))

	print("monitor_path=%s" % ProjectSettings.globalize_path(path))
	print("monitor_physical_size=%dx%d" % [image.get_width(), image.get_height()])
	print("monitor_saved_size=%dx%d" % [saved_image.get_width(), saved_image.get_height()])

	# A single-size process exits immediately after the success marker. Avoiding
	# post-capture teardown also sidesteps an NVIDIA/OpenGL driver crash without
	# relaxing any screenshot or layout assertion.
	if cleanup_after_capture:
		game.queue_free()
		await process_frame
	return true

func _assert_monitor_layout(game: Control, size: Vector2i) -> bool:
	if game.monitor_overlay == null or not game.monitor_overlay.visible:
		return _fail("Expected monitor overlay for screenshot.")
	var viewport_size: Vector2 = root.get_visible_rect().size
	if game.monitor_overlay.size.x < viewport_size.x - 80.0 or game.monitor_overlay.size.y < viewport_size.y - 80.0:
		return _fail("Expected monitor overlay to fill most of the viewport at %dx%d." % [size.x, size.y])
	if game.monitor_task_board_label == null or not str(game.monitor_task_board_label.text).contains("OS 任务板"):
		return _fail("Expected monitor task board to render.")
	var task_rect: Rect2 = game.monitor_task_board_label.get_global_rect()
	var content_rect: Rect2 = game.monitor_content_label.get_global_rect()
	if task_rect.size.y < 42.0:
		return _fail("Expected monitor task board text to be visibly tall at %dx%d." % [size.x, size.y])
	if content_rect.position.y <= task_rect.end.y:
		return _fail("Expected monitor content to sit below the task board without overlap at %dx%d." % [size.x, size.y])
	if game.file_preflight_button == null or not game.file_preflight_button.visible:
		return _fail("Expected Files report buttons to be visible at %dx%d." % [size.x, size.y])
	if game.monitor_content_label.text.is_empty() or not str(game.monitor_content_label.text).contains("[preflight_report.txt]"):
		return _fail("Expected preflight report content to remain visible at %dx%d." % [size.x, size.y])
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
