extends SceneTree

func _init() -> void:
	root.size = Vector2i(1280, 720)
	var game := await _create_game()
	var component_database := root.get_node("/root/ComponentDatabase")

	game.installed["MotherBoard"] = component_database.components_by_id[10021].duplicate(true)
	game._on_slot_pressed("CPU")
	game.open_shop_overlay()
	game.catalog_shop_panel._compatible_toggle.button_pressed = false
	game.catalog_shop_panel._order_toggle.button_pressed = false
	game.catalog_shop_panel._render_items()
	await _settle()

	if not _first_row_has_cards(game.catalog_shop_panel._shop_list, 4):
		_fail("Expected fullscreen shop catalog to show at least four cards in the first row.")
		return
	game.catalog_shop_panel._shop_list.select(0)
	game.catalog_shop_panel._on_item_selected(0)
	if game.catalog_shop_panel._item_preview.texture == null:
		_fail("Expected selected shop catalog item to show a detail preview image.")
		return
	if game.catalog_shop_panel._buy_button.disabled or game.catalog_shop_panel._quick_install_button.disabled:
		_fail("Expected selected shop catalog actions to be enabled.")
		return

	game.inventory.clear()
	var inventory_ids := [10001, 10011, 10021, 10031, 10041, 10051]
	for id in inventory_ids:
		var item: Dictionary = component_database.components_by_id[int(id)].duplicate(true)
		item.quantity = 1
		game.inventory.append(item)
	game.current_filter = ""
	game._refresh_inventory()
	game.open_inventory_overlay()
	await _settle()

	if not _first_row_has_cards(game.catalog_inventory_panel._inventory_list, 4):
		_fail("Expected fullscreen inventory catalog to show at least four cards in the first row.")
		return
	game.catalog_inventory_panel._inventory_list.select(0)
	game.catalog_inventory_panel._on_item_selected(0)
	if game.catalog_inventory_panel._item_preview.texture == null:
		_fail("Expected selected inventory catalog item to show a detail preview image.")
		return
	if game.catalog_inventory_panel._install_button.disabled or game.catalog_inventory_panel._sell_button.disabled:
		_fail("Expected selected inventory catalog actions to be enabled.")
		return

	print("catalog_layout=ok")
	print("shop_cards=%d" % game.catalog_shop_panel._shop_list.item_count)
	print("inventory_cards=%d" % game.catalog_inventory_panel._inventory_list.item_count)
	quit(0)

func _create_game() -> Control:
	var game_scene := load("res://scenes/Game.tscn")
	var game: Control = game_scene.instantiate()
	root.add_child(game)
	await _settle()
	return game

func _settle() -> void:
	for _frame in range(4):
		await process_frame

func _first_row_has_cards(list: ItemList, count: int) -> bool:
	if list == null or list.item_count < count:
		return false
	if list.size.y < 150.0:
		return false
	var first: Rect2 = list.get_item_rect(0, false)
	var target: Rect2 = list.get_item_rect(count - 1, false)
	return target.position.y < first.position.y + maxf(8.0, first.size.y * 0.35)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
