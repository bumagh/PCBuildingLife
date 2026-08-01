extends SceneTree

const SIZES := [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1920, 1080),
]

func _init() -> void:
	for size in SIZES:
		if not await _capture_catalog_overlay(size, true):
			return
		if not await _capture_catalog_overlay(size, false):
			return
	print("catalog_overlay_screenshot=ok")
	quit(0)

func _capture_catalog_overlay(size: Vector2i, shop_mode: bool) -> bool:
	await _prepare_window(size)
	var game_scene := load("res://scenes/Game.tscn")
	var game: Control = game_scene.instantiate()
	root.add_child(game)
	await _settle()

	var component_database := root.get_node("/root/ComponentDatabase")
	if shop_mode:
		_prepare_shop(game, component_database)
		game.open_shop_overlay()
	else:
		_prepare_inventory(game, component_database)
		game.open_inventory_overlay()
	await _settle()

	if not _assert_overlay_layout(game, size, shop_mode):
		return false
	await _settle()

	var image: Image = root.get_texture().get_image()
	if image == null:
		return _fail("Viewport image is not available.")
	var physical_size := Vector2i(image.get_width(), image.get_height())
	var saved_image := image
	if physical_size != size:
		saved_image = image.duplicate()
		saved_image.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var mode := "shop" if shop_mode else "inventory"
	var path := "res://../GodotVersion-catalog-%s-overlay-check-%dx%d.png" % [mode, size.x, size.y]
	var err := saved_image.save_png(path)
	if err != OK:
		return _fail("Failed to save catalog overlay screenshot: %s" % error_string(err))
	print("catalog_overlay_path=%s" % ProjectSettings.globalize_path(path))
	print("catalog_overlay_physical_size=%dx%d" % [physical_size.x, physical_size.y])
	print("catalog_overlay_saved_size=%dx%d" % [saved_image.get_width(), saved_image.get_height()])

	game.queue_free()
	await process_frame
	return true

func _prepare_shop(game: Control, component_database: Node) -> void:
	game.installed["MotherBoard"] = component_database.components_by_id[10021].duplicate(true)
	game._on_slot_pressed("CPU")
	game.catalog_shop_panel._compatible_toggle.button_pressed = false
	game.catalog_shop_panel._order_toggle.button_pressed = false
	game.catalog_shop_panel._render_items()

func _prepare_inventory(game: Control, component_database: Node) -> void:
	game.inventory.clear()
	var inventory_ids := [10001, 10011, 10021, 10031, 10041, 10051]
	for id in inventory_ids:
		var item: Dictionary = component_database.components_by_id[int(id)].duplicate(true)
		item.quantity = 1
		game.inventory.append(item)
	game.current_filter = ""
	game._refresh_inventory()

func _assert_overlay_layout(game: Control, size: Vector2i, shop_mode: bool) -> bool:
	var viewport_size: Vector2 = root.get_visible_rect().size
	var overlay_rect: Rect2 = game.catalog_overlay.get_global_rect()
	if overlay_rect.position.x > 1.0 or overlay_rect.position.y > 1.0:
		return _fail("Catalog overlay does not start at viewport origin.")
	if overlay_rect.end.x < viewport_size.x - 1.0 or overlay_rect.end.y < viewport_size.y - 1.0:
		return _fail("Catalog overlay does not fill viewport at %dx%d." % [size.x, size.y])

	var list: ItemList = game.catalog_shop_panel._shop_list if shop_mode else game.catalog_inventory_panel._inventory_list
	var preview: TextureRect = game.catalog_shop_panel._item_preview if shop_mode else game.catalog_inventory_panel._item_preview
	list.select(0)
	if shop_mode:
		game.catalog_shop_panel._on_item_selected(0)
	else:
		game.catalog_inventory_panel._on_item_selected(0)

	var list_rect: Rect2 = list.get_global_rect()
	var preview_rect: Rect2 = preview.get_global_rect()
	if list_rect.size.x < 650.0 or list_rect.size.y < 360.0:
		return _fail("Catalog grid is too cramped at %dx%d." % [size.x, size.y])
	if preview_rect.position.x <= list_rect.end.x:
		return _fail("Catalog detail overlaps the grid at %dx%d." % [size.x, size.y])
	if not _first_row_has_cards(list, 4):
		return _fail("Catalog first row has fewer than four cards at %dx%d." % [size.x, size.y])
	if preview.texture == null:
		return _fail("Catalog preview texture is missing at %dx%d." % [size.x, size.y])
	if shop_mode:
		if not _assert_shop_panel(game.catalog_shop_panel, size):
			return false
	else:
		if not _assert_inventory_panel(game.catalog_inventory_panel, size):
			return false
	return true

func _assert_shop_panel(panel: ShopPanel, size: Vector2i) -> bool:
	var strip := panel.find_child("ShopStatusStrip", true, false)
	if strip == null or not strip.visible:
		return _fail("Shop status strip is missing at %dx%d." % [size.x, size.y])
	if strip.get_global_rect().size.y < 30.0:
		return _fail("Shop status strip is too short at %dx%d." % [size.x, size.y])
	if panel._slot_status_label == null or not panel._slot_status_label.text.contains("当前槽位"):
		return _fail("Shop slot status is missing.")
	if panel._money_status_label == null or not panel._money_status_label.text.contains("资金"):
		return _fail("Shop money status is missing.")
	if panel._order_chip_label == null or not panel._order_chip_label.text.contains("订单"):
		return _fail("Shop order status is missing.")
	if panel._fit_status_label == null or not panel._fit_status_label.text.contains("兼容"):
		return _fail("Shop compatibility status is missing.")
	if panel._buy_button.get_global_rect().size.y < 38.0 or panel._quick_install_button.get_global_rect().size.y < 38.0:
		return _fail("Shop action buttons are too small at %dx%d." % [size.x, size.y])
	if panel._quick_install_button.get_global_rect().end.y > root.get_visible_rect().size.y - 12.0:
		return _fail("Shop action buttons are clipped at %dx%d." % [size.x, size.y])
	if panel._shop_list.focus_neighbor_bottom.is_empty() or panel._buy_button.focus_mode == Control.FOCUS_NONE:
		return _fail("Shop focus chain is not wired.")
	if not panel._buy_button.text.contains("￥") and not panel._buy_button.text.contains("资金不足"):
		return _fail("Shop buy button does not explain the action cost/state.")
	return true

func _assert_inventory_panel(panel: InventoryPanel, size: Vector2i) -> bool:
	var strip := panel.find_child("InventoryStatusStrip", true, false)
	if strip == null or not strip.visible:
		return _fail("Inventory status strip is missing at %dx%d." % [size.x, size.y])
	if strip.get_global_rect().size.y < 30.0:
		return _fail("Inventory status strip is too short at %dx%d." % [size.x, size.y])
	if panel._slot_status_label == null or not panel._slot_status_label.text.contains("当前槽位"):
		return _fail("Inventory slot status is missing.")
	if panel._count_status_label == null or not panel._count_status_label.text.contains("库存"):
		return _fail("Inventory count status is missing.")
	if panel._fit_status_label == null or not panel._fit_status_label.text.contains("可安装"):
		return _fail("Inventory installable status is missing.")
	if panel._order_status_label == null or not panel._order_status_label.text.contains("订单可用"):
		return _fail("Inventory order status is missing.")
	if panel._install_button.get_global_rect().size.y < 38.0 or panel._sell_button.get_global_rect().size.y < 38.0:
		return _fail("Inventory action buttons are too small at %dx%d." % [size.x, size.y])
	if panel._sell_button.get_global_rect().end.y > root.get_visible_rect().size.y - 12.0:
		return _fail("Inventory action buttons are clipped at %dx%d." % [size.x, size.y])
	if panel._inventory_list.focus_neighbor_bottom.is_empty() or panel._install_button.focus_mode == Control.FOCUS_NONE:
		return _fail("Inventory focus chain is not wired.")
	if not panel._install_button.text.contains("安装") and not panel._install_button.text.contains("不兼容"):
		return _fail("Inventory install button does not explain its state.")
	return true

func _prepare_window(size: Vector2i) -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(Vector2i(80, 80))
	root.size = size
	await _settle()

func _settle() -> void:
	for _frame in range(4):
		await process_frame

func _first_row_has_cards(list: ItemList, count: int) -> bool:
	if list == null or list.item_count < count:
		return false
	var first: Rect2 = list.get_item_rect(0, false)
	var target: Rect2 = list.get_item_rect(count - 1, false)
	return target.position.y < first.position.y + maxf(8.0, first.size.y * 0.35)

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
