extends SceneTree

const SIZES := [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1920, 1080),
]

func _init() -> void:
	for size in SIZES:
		if not await _capture_catalog(size, true):
			return
		if not await _capture_catalog(size, false):
			return
	print("catalog_screenshot=ok")
	quit(0)

func _capture_catalog(size: Vector2i, shop_mode: bool) -> bool:
	root.size = size
	var game_scene := load("res://scenes/Game.tscn")
	var game: Control = game_scene.instantiate()
	root.add_child(game)
	await _settle()

	if shop_mode:
		_prepare_shop(game)
	else:
		_prepare_inventory(game)
	await _settle()

	var list: ItemList = game.shop_panel._shop_list if shop_mode else game.inventory_panel._inventory_list
	if not _first_row_has_cards(list, 2):
		return _fail("Expected compact %s tab to show at least two cards at %dx%d." % ["shop" if shop_mode else "inventory", size.x, size.y])
	var preview: TextureRect = game.shop_panel._item_preview if shop_mode else game.inventory_panel._item_preview
	if preview.texture == null:
		return _fail("Expected %s detail preview at %dx%d." % ["shop" if shop_mode else "inventory", size.x, size.y])
	var rect: Rect2 = list.get_global_rect()
	var viewport_size: Vector2 = root.get_visible_rect().size
	if rect.end.x > viewport_size.x + 1.0 or rect.end.y > viewport_size.y + 1.0:
		return _fail("Catalog list overflows at %dx%d." % [size.x, size.y])

	var image: Image = root.get_texture().get_image()
	if image == null:
		return _fail("Viewport image is not available.")
	var saved_image := image
	if image.get_size() != size:
		saved_image = image.duplicate()
		saved_image.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var mode := "shop" if shop_mode else "inventory"
	var path := "res://../GodotVersion-r3-%s-cards-check-%dx%d.png" % [mode, size.x, size.y]
	var err := saved_image.save_png(path)
	if err != OK:
		return _fail("Failed to save catalog screenshot: %s" % error_string(err))
	print("catalog_path=%s" % ProjectSettings.globalize_path(path))
	game.queue_free()
	await process_frame
	return true

func _prepare_shop(game: Control) -> void:
	var component_database := root.get_node("/root/ComponentDatabase")
	game.installed["MotherBoard"] = component_database.components_by_id[10021].duplicate(true)
	game._on_slot_pressed("CPU")
	game.main_tabs.current_tab = 1
	game.shop_panel._compatible_toggle.button_pressed = false
	game.shop_panel._order_toggle.button_pressed = false
	game.shop_panel._render_items()
	game.shop_panel._shop_list.select(0)
	game.shop_panel._on_item_selected(0)

func _prepare_inventory(game: Control) -> void:
	var component_database := root.get_node("/root/ComponentDatabase")
	game.inventory.clear()
	var inventory_ids := [10001, 10011, 10021, 10031, 10041, 10051]
	for id in inventory_ids:
		var item: Dictionary = component_database.components_by_id[int(id)].duplicate(true)
		item.quantity = 1
		game.inventory.append(item)
	game.current_filter = ""
	game.main_tabs.current_tab = 0
	game._refresh_inventory()
	game.inventory_panel._inventory_list.select(0)
	game.inventory_panel._on_item_selected(0)

func _settle() -> void:
	for _frame in range(4):
		await process_frame

func _first_row_has_cards(list: ItemList, count: int) -> bool:
	if list == null or list.item_count < count or list.size.y < 150.0:
		return false
	var first: Rect2 = list.get_item_rect(0, false)
	var target: Rect2 = list.get_item_rect(count - 1, false)
	return target.position.y < first.position.y + maxf(8.0, first.size.y * 0.35)

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
