extends SceneTree

func _init() -> void:
	var game := await _create_game()
	var component_database := root.get_node("/root/ComponentDatabase")

	game.installed["MotherBoard"] = component_database.components_by_id[10021].duplicate(true)
	game._on_slot_pressed("CPU")
	var all_cpu_count: int = game.shop_panel.get_visible_item_count()
	var first_row_text: String = game.shop_panel._shop_list.get_item_text(0)
	if not first_row_text.contains("兼容") or not first_row_text.contains("满足订单"):
		push_error("Expected first row labels to show compatible and order state: %s" % first_row_text)
		quit(1)
		return

	if not _visible_rows_contain(game.shop_panel._shop_list, "不兼容"):
		push_error("Expected visible rows to include an incompatible label.")
		quit(1)
		return

	game.shop_panel._sort_option.select(1)
	game.shop_panel._on_sort_selected(1)
	var cheapest_cpu: Dictionary = game.shop_panel._shop_list.get_item_metadata(0)
	if int(cheapest_cpu.price) != 499:
		push_error("Expected price ascending sort to put cheapest CPU first.")
		quit(1)
		return

	game.shop_panel._sort_option.select(3)
	game.shop_panel._on_sort_selected(3)
	var highest_tier_cpu: Dictionary = game.shop_panel._shop_list.get_item_metadata(0)
	if int(highest_tier_cpu.tier) != 100:
		push_error("Expected tier descending sort to put top CPU first.")
		quit(1)
		return

	game.shop_panel._sort_option.select(0)
	game.shop_panel._on_sort_selected(0)
	game.shop_panel._compatible_toggle.button_pressed = true
	var compatible_cpu_count: int = game.shop_panel.get_visible_item_count()
	if all_cpu_count != 10 or compatible_cpu_count >= all_cpu_count:
		push_error("Expected compatible CPU filter to reduce CPU list, got %d/%d." % [compatible_cpu_count, all_cpu_count])
		quit(1)
		return

	game.shop_panel._compatible_toggle.button_pressed = false
	game.shop_panel._order_toggle.button_pressed = true
	var order_cpu_count: int = game.shop_panel.get_visible_item_count()
	if order_cpu_count <= 0 or order_cpu_count >= all_cpu_count:
		push_error("Expected order CPU filter to reduce CPU list, got %d/%d." % [order_cpu_count, all_cpu_count])
		quit(1)
		return

	var incompatible_cpu: Dictionary = component_database.components_by_id[10002]
	var money_before: int = game.money
	game._on_shop_item_quick_install_selected(incompatible_cpu)
	if game.money != money_before:
		push_error("Expected blocked quick install not to spend money.")
		quit(1)
		return
	if game.installed.has("CPU"):
		push_error("Expected blocked quick install not to install incompatible CPU.")
		quit(1)
		return
	if not game.status_label.text.contains("购买并安装已阻止"):
		push_error("Expected blocked quick install warning in status label.")
		quit(1)
		return

	print("shop_filters=ok")
	print("all_cpu_count=%d" % all_cpu_count)
	print("compatible_cpu_count=%d" % compatible_cpu_count)
	print("order_cpu_count=%d" % order_cpu_count)
	print("blocked_status=%s" % game.status_label.text)
	quit(0)

func _create_game() -> Control:
	var game_script := load("res://scripts/game.gd")
	var game: Control = game_script.new()
	root.add_child(game)
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	return game

func _visible_rows_contain(list: ItemList, text: String) -> bool:
	for index in range(list.item_count):
		if list.get_item_text(index).contains(text):
			return true
	return false
