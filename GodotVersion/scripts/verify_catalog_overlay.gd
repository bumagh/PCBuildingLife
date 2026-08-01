extends SceneTree

func _init() -> void:
	root.size = Vector2i(1280, 720)
	var game := await _create_game()
	var component_database := root.get_node("/root/ComponentDatabase")

	_prepare_shop(game, component_database)
	game.open_shop_overlay()
	await _settle()
	if not _assert_overlay(game, Vector2i(1280, 720), "shop"):
		return
	if not _assert_shop(game):
		return
	_send_cancel(game)
	await _settle()
	if game.catalog_overlay.visible:
		_fail("Expected ui_cancel to close the shop catalog overlay.")
		return

	_prepare_inventory(game, component_database)
	game.open_inventory_overlay()
	await _settle()
	if not _assert_overlay(game, Vector2i(1280, 720), "inventory"):
		return
	if not _assert_inventory(game):
		return
	_send_cancel(game)
	await _settle()
	if game.catalog_overlay.visible:
		_fail("Expected ui_cancel to close the inventory catalog overlay.")
		return

	print("catalog_overlay=ok")
	print("shop_cards=%d" % game.catalog_shop_panel._shop_list.item_count)
	print("inventory_cards=%d" % game.catalog_inventory_panel._inventory_list.item_count)
	quit(0)

func _create_game() -> Control:
	var game_script := load("res://scripts/game.gd")
	var game: Control = game_script.new()
	root.add_child(game)
	await _settle()
	return game

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

func _assert_overlay(game: Control, size: Vector2i, expected_mode: String) -> bool:
	if game.catalog_overlay == null or not game.catalog_overlay.visible:
		return _fail("Expected catalog overlay to be visible.")
	if game.catalog_mode != expected_mode:
		return _fail("Expected catalog mode %s, got %s." % [expected_mode, game.catalog_mode])
	var overlay_rect: Rect2 = game.catalog_overlay.get_global_rect()
	if overlay_rect.position.x > 1.0 or overlay_rect.position.y > 1.0:
		return _fail("Catalog overlay does not start at the viewport origin.")
	if overlay_rect.end.x < float(size.x) - 1.0 or overlay_rect.end.y < float(size.y) - 1.0:
		return _fail("Catalog overlay does not fill %dx%d." % [size.x, size.y])
	return true

func _assert_shop(game: Control) -> bool:
	if not game.catalog_shop_panel.visible or game.catalog_inventory_panel.visible:
		return _fail("Expected shop panel to be the only visible catalog panel.")
	var list: ItemList = game.catalog_shop_panel._shop_list
	if list.get_global_rect().size.x < 650.0 or list.get_global_rect().size.y < 360.0:
		return _fail("Shop catalog grid is too cramped.")
	if not _first_row_has_cards(list, 4):
		return _fail("Expected shop catalog to show at least four cards on the first row.")
	list.select(0)
	game.catalog_shop_panel._on_item_selected(0)
	if game.catalog_shop_panel._item_preview.texture == null:
		return _fail("Expected shop catalog detail preview.")
	if game.catalog_shop_panel._buy_button.disabled or game.catalog_shop_panel._quick_install_button.disabled:
		return _fail("Expected shop catalog actions to be enabled.")
	return _assert_detail_beside_list(list, game.catalog_shop_panel._item_preview, "shop")

func _assert_inventory(game: Control) -> bool:
	if not game.catalog_inventory_panel.visible or game.catalog_shop_panel.visible:
		return _fail("Expected inventory panel to be the only visible catalog panel.")
	var list: ItemList = game.catalog_inventory_panel._inventory_list
	if list.get_global_rect().size.x < 650.0 or list.get_global_rect().size.y < 360.0:
		return _fail("Inventory catalog grid is too cramped.")
	if not _first_row_has_cards(list, 4):
		return _fail("Expected inventory catalog to show at least four cards on the first row.")
	list.select(0)
	game.catalog_inventory_panel._on_item_selected(0)
	if game.catalog_inventory_panel._item_preview.texture == null:
		return _fail("Expected inventory catalog detail preview.")
	if game.catalog_inventory_panel._install_button.disabled or game.catalog_inventory_panel._sell_button.disabled:
		return _fail("Expected inventory catalog actions to be enabled.")
	return _assert_detail_beside_list(list, game.catalog_inventory_panel._item_preview, "inventory")

func _assert_detail_beside_list(list: ItemList, preview: TextureRect, mode: String) -> bool:
	var list_rect: Rect2 = list.get_global_rect()
	var preview_rect: Rect2 = preview.get_global_rect()
	if preview_rect.position.x <= list_rect.end.x:
		return _fail("Expected %s detail preview to sit beside the grid." % mode)
	return true

func _first_row_has_cards(list: ItemList, count: int) -> bool:
	if list == null or list.item_count < count:
		return false
	var first: Rect2 = list.get_item_rect(0, false)
	var target: Rect2 = list.get_item_rect(count - 1, false)
	return target.position.y < first.position.y + maxf(8.0, first.size.y * 0.35)

func _send_cancel(game: Control) -> void:
	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	game._unhandled_input(cancel_event)

func _settle() -> void:
	for _frame in range(4):
		await process_frame

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
