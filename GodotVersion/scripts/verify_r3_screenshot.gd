extends SceneTree

const SIZES := [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1920, 1080),
]

func _init() -> void:
	for size in SIZES:
		if not await _capture_feedback_screen(size):
			return
	print("r3_screenshot=ok")
	quit(0)

func _capture_feedback_screen(size: Vector2i) -> bool:
	await _prepare_window(size)
	var game_scene := load("res://scenes/Game.tscn")
	var game: Control = game_scene.instantiate()
	root.add_child(game)
	for _frame in range(4):
		await process_frame

	if not game.apply_cheat_complete_driver_flow():
		return _fail("Expected R3 screenshot setup to prepare a deliverable build.")
	game._on_os_benchmark_pressed()
	game._on_deliver_pressed()
	if game.monitor_overlay:
		game.monitor_overlay.visible = false
	game.main_tabs.current_tab = 1
	for _frame in range(4):
		await process_frame

	if game.delivery_feedback_panel == null:
		return _fail("Expected delivery feedback panel.")
	if game.home_bottom_dock == null:
		return _fail("Expected home bottom dock.")
	if game.monitor_overlay != null and game.monitor_overlay.visible:
		return _fail("Expected monitor overlay to be closed for R3 feedback screenshot.")
	var viewport_size: Vector2 = root.get_visible_rect().size
	var feedback_rect: Rect2 = game.delivery_feedback_panel.get_global_rect()
	var dock_rect: Rect2 = game.home_bottom_dock.get_global_rect()
	if feedback_rect.size.y < 64.0:
		return _fail("Expected stable feedback panel height, got %.1f." % feedback_rect.size.y)
	if feedback_rect.position.x < -1.0 or feedback_rect.end.x > viewport_size.x + 1.0:
		return _fail("Feedback panel overflows horizontally at %dx%d." % [size.x, size.y])
	if dock_rect.end.y > viewport_size.y + 1.0:
		return _fail("Home bottom dock is clipped at %dx%d: dock_end %.1f, viewport %.1f, main %.1f, dock %.1f, feedback %.1f." % [
			size.x,
			size.y,
			dock_rect.end.y,
			viewport_size.y,
			game.main_tabs.size.y,
			dock_rect.size.y,
			feedback_rect.size.y,
		])
	if feedback_rect.position.y < dock_rect.position.y - 1.0 or feedback_rect.end.y > dock_rect.end.y + 1.0:
		return _fail("Feedback panel is not contained by the home dock at %dx%d." % [size.x, size.y])
	if game.main_tabs.size.y < 190.0:
		return _fail("Expected main tab area to keep usable height at %dx%d." % [size.x, size.y])
	if dock_rect.size.y < 150.0:
		return _fail("Expected home bottom dock to keep usable height at %dx%d." % [size.x, size.y])

	var image: Image = root.get_texture().get_image()
	if image == null:
		return _fail("Viewport image is not available.")
	var physical_size := Vector2i(image.get_width(), image.get_height())
	var saved_image := image
	if physical_size != size:
		saved_image = image.duplicate()
		saved_image.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var path := "res://../GodotVersion-r3-feedback-check-%dx%d.png" % [size.x, size.y]
	var err := saved_image.save_png(path)
	if err != OK:
		return _fail("Failed to save R3 screenshot: %s" % error_string(err))
	print("r3_path=%s" % ProjectSettings.globalize_path(path))
	print("r3_physical_size=%dx%d" % [physical_size.x, physical_size.y])
	print("r3_saved_size=%dx%d" % [saved_image.get_width(), saved_image.get_height()])
	game.queue_free()
	await process_frame
	return true

func _prepare_window(size: Vector2i) -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(Vector2i(130, 130))
	root.size = size
	for _frame in range(4):
		await process_frame

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
