extends SceneTree

const SIZES := [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1920, 1080),
]

func _init() -> void:
	for size in SIZES:
		if not await _capture_order_desk(size):
			return
	print("order_desk_screenshot=ok")
	quit(0)

func _capture_order_desk(size: Vector2i) -> bool:
	await _prepare_window(size)
	var game_scene := load("res://scenes/Game.tscn")
	var game: Control = game_scene.instantiate()
	root.add_child(game)
	await _settle()

	game.open_order_desk()
	await _settle()

	if not _assert_order_desk_layout(game, size):
		return false

	var image: Image = root.get_texture().get_image()
	if image == null:
		return _fail("Viewport image is not available.")
	var physical_size := Vector2i(image.get_width(), image.get_height())
	var saved_image := image
	if physical_size != size:
		saved_image = image.duplicate()
		saved_image.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var path := "res://../GodotVersion-order-desk-check-%dx%d.png" % [size.x, size.y]
	var err := saved_image.save_png(path)
	if err != OK:
		return _fail("Failed to save order desk screenshot: %s" % error_string(err))
	print("order_desk_path=%s" % ProjectSettings.globalize_path(path))
	print("order_desk_physical_size=%dx%d" % [physical_size.x, physical_size.y])
	print("order_desk_saved_size=%dx%d" % [saved_image.get_width(), saved_image.get_height()])

	game.queue_free()
	await process_frame
	return true

func _assert_order_desk_layout(game: Control, size: Vector2i) -> bool:
	var viewport_size: Vector2 = root.get_visible_rect().size
	var overlay_rect: Rect2 = game.order_desk_overlay.get_global_rect()
	if overlay_rect.position.x > 1.0 or overlay_rect.position.y > 1.0:
		return _fail("Order desk overlay does not start at viewport origin.")
	if overlay_rect.end.x < viewport_size.x - 1.0 or overlay_rect.end.y < viewport_size.y - 1.0:
		return _fail("Order desk overlay does not fill viewport at %dx%d." % [size.x, size.y])
	if game.order_desk_customer_art == null or game.order_desk_customer_art.texture == null:
		return _fail("Order customer illustration is missing at %dx%d." % [size.x, size.y])
	if game.order_desk_grade_art == null or game.order_desk_grade_art.texture == null:
		return _fail("Order grade badge is missing at %dx%d." % [size.x, size.y])
	if game.order_desk_software_art == null or game.order_desk_software_art.texture == null:
		return _fail("Order software illustration is missing at %dx%d." % [size.x, size.y])

	var list_rect: Rect2 = game.order_desk_list.get_global_rect()
	var title_rect: Rect2 = game.order_desk_title_label.get_global_rect()
	var hardware_ready_rect: Rect2 = game.order_desk_hardware_ready_label.get_global_rect()
	var software_ready_rect: Rect2 = game.order_desk_software_ready_label.get_global_rect()
	var delivery_ready_rect: Rect2 = game.order_desk_delivery_ready_label.get_global_rect()
	var scope_rect: Rect2 = game.order_desk_scope_label.get_global_rect()
	var market_rect: Rect2 = game.order_desk_market_button.get_global_rect()
	var deliver_rect: Rect2 = game.order_desk_deliver_button.get_global_rect()
	if list_rect.size.x < 260.0 or list_rect.size.y < 390.0:
		return _fail("Order queue is too cramped at %dx%d." % [size.x, size.y])
	if game.order_desk_list.get_item_count() == 0 or game.order_desk_list.get_item_icon(0) == null:
		return _fail("Order queue items are missing customer illustrations at %dx%d." % [size.x, size.y])
	if title_rect.position.x <= list_rect.end.x:
		return _fail("Order detail overlaps queue at %dx%d." % [size.x, size.y])
	if hardware_ready_rect.position.y <= title_rect.position.y or hardware_ready_rect.size.x < 150.0:
		return _fail("Order hardware readiness card is missing or too narrow at %dx%d." % [size.x, size.y])
	if hardware_ready_rect.size.y < 36.0 or software_ready_rect.size.y < 36.0 or delivery_ready_rect.size.y < 36.0:
		return _fail("Order readiness card text is not visibly tall enough at %dx%d." % [size.x, size.y])
	if software_ready_rect.position.x <= hardware_ready_rect.end.x:
		return _fail("Order software readiness card overlaps hardware readiness at %dx%d." % [size.x, size.y])
	if delivery_ready_rect.position.x <= software_ready_rect.end.x:
		return _fail("Order delivery readiness card overlaps software readiness at %dx%d." % [size.x, size.y])
	if game.order_desk_hardware_ready_label.text.is_empty() or game.order_desk_software_ready_label.text.is_empty() or game.order_desk_delivery_ready_label.text.is_empty():
		return _fail("Order readiness labels did not render at %dx%d." % [size.x, size.y])
	if scope_rect.position.x <= title_rect.end.x:
		return _fail("Order assessment overlaps detail area at %dx%d." % [size.x, size.y])
	if scope_rect.size.x < 250.0:
		return _fail("Order assessment column is too narrow at %dx%d." % [size.x, size.y])
	if market_rect.end.y > viewport_size.y - 8.0:
		return _fail("Order desk action buttons collide with bottom edge at %dx%d: button_y=%.1f viewport_y=%.1f." % [size.x, size.y, market_rect.end.y, viewport_size.y])
	if deliver_rect.end.y > viewport_size.y - 8.0:
		return _fail("Order desk deliver button collides with bottom edge at %dx%d." % [size.x, size.y])
	if game.order_desk_list.focus_neighbor_right.is_empty() or game.order_desk_accept_button.focus_mode == Control.FOCUS_NONE or game.order_desk_deliver_button.focus_mode == Control.FOCUS_NONE:
		return _fail("Order desk focus chain is not wired at %dx%d." % [size.x, size.y])
	if game.order_desk_score_label.text.is_empty() or game.order_desk_risk_label.text.is_empty():
		return _fail("Order assessment labels did not render at %dx%d." % [size.x, size.y])
	return true

func _prepare_window(size: Vector2i) -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(Vector2i(110, 110))
	root.size = size
	await _settle()

func _settle() -> void:
	for _frame in range(4):
		await process_frame

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
