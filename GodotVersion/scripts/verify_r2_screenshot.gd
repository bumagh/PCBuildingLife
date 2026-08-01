extends SceneTree

const ORDER_SCREENSHOT_PATH := "res://../GodotVersion-r2-order-desk-check-1280x720.png"
const STABILITY_SCREENSHOT_PATH := "res://../GodotVersion-r2-stability-check-1280x720.png"

func _init() -> void:
	await _prepare_window(Vector2i(1280, 720))
	var scene := load("res://scenes/Game.tscn")
	var game: Control = scene.instantiate()
	root.add_child(game)
	await _settle()

	game.completed_order_ids.clear()
	for index in range(11):
		game.completed_order_ids.append(str(game.order_defs[index].id))
	game.available_order_indices.clear()
	game.available_order_indices.append(11)
	game.current_order_index = 11
	game._refresh_all()
	game.open_order_desk()
	game._select_order_desk_order(11)
	await _settle()
	var order_image := root.get_texture().get_image()
	var saved_order_image: Image = _image_for_target_size(order_image, Vector2i(1280, 720))
	if saved_order_image.save_png(ORDER_SCREENSHOT_PATH) != OK:
		push_error("Failed to save R2 order screenshot.")
		quit(1)
		return

	if not game.apply_cheat_fill_current_order():
		push_error("Expected flagship build for R2 screenshot.")
		quit(1)
		return
	game.apply_cheat_boot_pass()
	game._on_monitor_driver_tool_pressed()
	game._on_driver_scan_pressed()
	game._on_driver_install_pressed()
	game._on_driver_restart_pressed()
	game._on_gpu_driver_install_pressed()
	game._on_os_stability_test_pressed()
	game._on_open_monitor_pressed()
	await _settle()
	var stability_image := root.get_texture().get_image()
	var saved_stability_image: Image = _image_for_target_size(stability_image, Vector2i(1280, 720))
	if saved_stability_image.save_png(STABILITY_SCREENSHOT_PATH) != OK:
		push_error("Failed to save R2 stability screenshot.")
		quit(1)
		return

	print("r2_screenshot=ok")
	print("orders_path=%s" % ProjectSettings.globalize_path(ORDER_SCREENSHOT_PATH))
	print("stability_path=%s" % ProjectSettings.globalize_path(STABILITY_SCREENSHOT_PATH))
	print("physical_size=%dx%d" % [order_image.get_width(), order_image.get_height()])
	print("saved_size=%dx%d" % [saved_order_image.get_width(), saved_order_image.get_height()])
	quit(0)

func _image_for_target_size(image: Image, size: Vector2i) -> Image:
	if image.get_width() == size.x and image.get_height() == size.y:
		return image
	var resized: Image = image.duplicate()
	resized.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	return resized

func _prepare_window(size: Vector2i) -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(Vector2i(60, 60))
	root.size = size
	await _settle()

func _settle() -> void:
	for _frame in range(4):
		await process_frame
