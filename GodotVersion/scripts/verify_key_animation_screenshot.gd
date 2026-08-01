extends SceneTree

const SIZES := [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1920, 1080),
]

func _init() -> void:
	for size in _requested_sizes():
		if not await _capture_key_animation(size):
			return
	print("key_animation_screenshot=ok")
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

func _capture_key_animation(size: Vector2i) -> bool:
	root.size = size
	var game_scene := load("res://scenes/Game.tscn")
	var game: Control = game_scene.instantiate()
	root.add_child(game)
	await _settle()

	game.main_tabs.current_tab = 1
	var component_database := root.get_node("/root/ComponentDatabase")
	var cpu: Dictionary = component_database.get_components_by_type("CPU")[0]
	game._on_shop_item_quick_install_selected(cpu)
	await process_frame

	if game.last_operation_animation != "install":
		return _fail("Expected install animation to be the latest animation at %dx%d." % [size.x, size.y])
	if int(game.operation_animation_count) < 2:
		return _fail("Expected purchase and install animations at %dx%d." % [size.x, size.y])
	if game.building_panel._visual_cards["CPU"].modulate == Color.WHITE:
		return _fail("Expected CPU visual card to be animated at %dx%d." % [size.x, size.y])

	var action_rect: Rect2 = game.action_feedback_panel.get_global_rect()
	var dock_rect: Rect2 = game.home_bottom_dock.get_global_rect()
	var tabs_rect: Rect2 = game.main_tabs.get_global_rect()
	if action_rect.end.x > float(size.x) + 1.0 or action_rect.end.y > float(size.y) + 1.0:
		return _fail("Action animation feedback overflows at %dx%d." % [size.x, size.y])
	if dock_rect.position.y < tabs_rect.end.y - 1.0:
		return _fail("Home bottom dock overlaps catalog tabs at %dx%d." % [size.x, size.y])
	if dock_rect.end.y > float(size.y) + 1.0:
		return _fail("Home bottom dock is clipped at %dx%d." % [size.x, size.y])
	if action_rect.position.y < dock_rect.position.y - 1.0 or action_rect.end.y > dock_rect.end.y + 1.0:
		return _fail("Action animation feedback is not contained by the home dock at %dx%d." % [size.x, size.y])
	if game.main_tabs.size.y < 190.0:
		return _fail("Main tab area became too small during animation at %dx%d." % [size.x, size.y])

	var image: Image = root.get_texture().get_image()
	if image == null:
		return _fail("Viewport image is not available.")
	var path := "res://../GodotVersion-r3-key-animation-check-%dx%d.png" % [size.x, size.y]
	var err := image.save_png(path)
	if err != OK:
		return _fail("Failed to save key animation screenshot: %s" % error_string(err))
	print("key_animation_path=%s" % ProjectSettings.globalize_path(path))
	game.queue_free()
	await process_frame
	return true

func _settle() -> void:
	for _frame in range(4):
		await process_frame

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
