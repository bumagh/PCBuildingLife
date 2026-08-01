extends SceneTree

func _init() -> void:
	var game := await _create_game()
	var component_database := root.get_node("/root/ComponentDatabase")
	var expected_money: int = game.STARTING_MONEY
	var order: Dictionary = game.get_current_order()
	var requirements: Dictionary = order.requirements
	var install_order := _build_install_order(game.REQUIRED_SLOTS)

	game.new_game()
	if game.shop_panel.get_visible_item_count() != 100:
		push_error("Expected full shop to show 100 items at onboarding start.")
		quit(1)
		return

	game.shop_panel._compatible_toggle.button_pressed = true
	game.shop_panel._order_toggle.button_pressed = true

	for slot in install_order:
		game._on_slot_pressed(slot)
		var min_tier := 0
		if requirements.has(slot):
			min_tier = int(requirements[slot])
		var item: Dictionary = _cheapest_compatible_for_slot(game, component_database, slot, min_tier)
		if item.is_empty():
			push_error("No compatible onboarding item for slot: %s" % slot)
			quit(1)
			return
		game._on_shop_item_quick_install_selected(item)
		expected_money -= int(item.price)
		if not game.installed.has(slot) or int(game.installed[slot].id) != int(item.id):
			push_error("Expected quick install for slot: %s" % slot)
			quit(1)
			return
		if game.get_inventory_quantity(item.id) != 0:
			push_error("Expected quick installed item to skip inventory: %s" % item.name)
			quit(1)
			return

	game._on_finish_pressed()
	if not game.powered_on:
		push_error("Expected onboarding build to power on: %s" % JSON.stringify(game.get_compatibility_issues()))
		quit(1)
		return
	game._on_power_button_pressed()
	if not game.system_booted:
		push_error("Expected onboarding build to boot simulated OS.")
		quit(1)
		return
	game._on_monitor_driver_tool_pressed()
	game._on_driver_scan_pressed()
	game._on_driver_install_pressed()
	game._on_driver_restart_pressed()

	var result: Dictionary = game.deliver_order()
	if not bool(result.get("ok", false)):
		push_error("Expected onboarding order delivery to pass: %s" % JSON.stringify(result))
		quit(1)
		return

	expected_money += int(result.reward)
	if game.money != expected_money:
		push_error("Expected onboarding money %d, got %d." % [expected_money, game.money])
		quit(1)
		return

	print("onboarding_flow=ok")
	print("completed_order=%s" % order.name)
	print("reward=%d" % int(result.reward))
	print("money=%d" % game.money)
	print("next_order_index=%d" % game.current_order_index)
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

func _build_install_order(required_slots: Array) -> Array[String]:
	var order: Array[String] = []
	for slot in required_slots:
		if slot != "Power":
			order.append(slot)
	order.append("Power")
	return order

func _cheapest_compatible_for_slot(game: Control, component_database: Node, slot: String, min_tier: int) -> Dictionary:
	var best: Dictionary = {}
	for item in component_database.get_components_by_type(slot):
		if int(item.tier) < min_tier:
			continue
		if not game.component_meets_current_order(item) and game.get_current_order().requirements.has(slot):
			continue
		if not game.can_install_component(item).is_empty():
			continue
		if best.is_empty() or int(item.price) < int(best.price):
			best = item
	return best
