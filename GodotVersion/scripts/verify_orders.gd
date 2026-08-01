extends SceneTree

func _init() -> void:
	var game := await _create_game()
	var component_database := root.get_node("/root/ComponentDatabase")
	var expected_money: int = game.STARTING_MONEY
	var low_cpu: Dictionary = _cheapest(component_database.get_components_by_type("CPU"))

	if game.order_defs.size() != 12 or game.available_order_indices.size() != 3:
		push_error("Expected 12 orders with 3 available at game start.")
		quit(1)
		return

	if not game.accept_order(1) or game.current_order_index != 1:
		push_error("Expected order 1 to be selectable.")
		quit(1)
		return

	if game.accept_order(99):
		push_error("Expected invalid order index to be rejected.")
		quit(1)
		return

	if game.accept_order(3):
		push_error("Expected order 3 to remain locked before first delivery.")
		quit(1)
		return

	if not game.accept_order(0):
		push_error("Expected order 0 to be selectable again.")
		quit(1)
		return

	_buy_and_install_required(game, component_database, false)
	game.installed["CPU"] = component_database.components_by_id[10010].duplicate(true)
	game.installed["MotherBoard"] = component_database.components_by_id[10025].duplicate(true)
	game._on_finish_pressed()
	game._on_power_button_pressed()

	var low_result: Dictionary = game.deliver_order()
	if bool(low_result.get("ok", false)):
		push_error("Expected low-tier build to fail the active order.")
		quit(1)
		return

	if not _reasons_contain(low_result.get("reasons", []), "CPU 等级不足"):
		push_error("Expected low-tier delivery failure to mention CPU tier.")
		quit(1)
		return

	game.new_game()
	expected_money = game.STARTING_MONEY
	var cost := _buy_and_install_required(game, component_database, true)
	expected_money -= cost
	var qualified_cpu_name := str(game.installed["CPU"].name)
	game._on_finish_pressed()
	game._on_power_button_pressed()

	var software_blocked_result: Dictionary = game.deliver_order()
	if bool(software_blocked_result.get("ok", false)):
		push_error("Expected qualified hardware to remain blocked before software setup.")
		quit(1)
		return
	if not _reasons_contain(software_blocked_result.get("reasons", []), "Software setup incomplete"):
		push_error("Expected delivery failure to mention software setup.")
		quit(1)
		return
	_complete_software_setup(game)

	var success_result: Dictionary = game.deliver_order()
	if not bool(success_result.get("ok", false)):
		push_error("Expected qualified build to complete the active order: %s" % JSON.stringify(success_result))
		quit(1)
		return

	var reward: int = int(success_result.get("reward", 0))
	expected_money += reward
	if game.money != expected_money:
		push_error("Expected money after delivery %d, got %d." % [expected_money, game.money])
		quit(1)
		return

	if not game.installed.is_empty() or game.powered_on:
		push_error("Expected successful delivery to clear installed parts and reset power state.")
		quit(1)
		return

	if game.current_order_index != 1:
		push_error("Expected active order index to advance to 1, got %d." % game.current_order_index)
		quit(1)
		return

	if game.available_order_indices.has(0):
		push_error("Expected completed order 0 to be removed from available orders.")
		quit(1)
		return

	if not game.available_order_indices.has(3):
		push_error("Expected first delivery to unlock order 3.")
		quit(1)
		return

	print("orders_smoke=ok")
	print("failed_order_reason=%s" % low_result.get("reasons", [])[0])
	print("qualified_cpu=%s" % qualified_cpu_name)
	print("delivery_reward=%d" % reward)
	print("money=%d" % game.money)
	print("current_order_index=%d" % game.current_order_index)
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

func _buy_and_install_required(game: Control, component_database: Node, meets_order: bool) -> int:
	var total_cost := 0
	var order: Dictionary = game.get_current_order()
	var requirements: Dictionary = order.requirements
	var install_order: Array[String] = []
	for slot in game.REQUIRED_SLOTS:
		if slot != "Power":
			install_order.append(slot)
	install_order.append("Power")
	for slot in install_order:
		var min_tier := 0
		if meets_order and requirements.has(slot):
			min_tier = int(requirements[slot])
		var item: Dictionary = _cheapest_compatible_for_slot(component_database, game.installed, slot, min_tier)
		game._on_shop_item_selected(item)
		total_cost += int(item.price)
		game._on_inventory_item_selected(_find_inventory_stack(game.inventory, slot))
	return total_cost

func _cheapest(items: Array) -> Dictionary:
	var best: Dictionary = items[0]
	for item in items:
		if int(item.price) < int(best.price):
			best = item
	return best

func _cheapest_compatible_for_slot(component_database: Node, installed: Dictionary, slot: String, min_tier: int) -> Dictionary:
	var best: Dictionary = {}
	for item in component_database.get_components_by_type(slot):
		if int(item.tier) < min_tier:
			continue
		if slot == "CPU" and installed.has("MotherBoard"):
			if _cpu_platform(item) != _motherboard_platform(installed["MotherBoard"]):
				continue
		if slot == "MotherBoard" and installed.has("CPU"):
			if _motherboard_platform(item) != _cpu_platform(installed["CPU"]):
				continue
		if slot == "VideoCard" and installed.has("Case"):
			if int(item.tier) >= 90 and int(installed["Case"].tier) < 85:
				continue
			if int(item.tier) >= 80 and int(installed["Case"].tier) < 75:
				continue
		if slot == "Case" and installed.has("VideoCard"):
			if int(installed["VideoCard"].tier) >= 90 and int(item.tier) < 85:
				continue
			if int(installed["VideoCard"].tier) >= 80 and int(item.tier) < 75:
				continue
		if slot == "Power":
			var capacity := _power_capacity(item)
			var required_power := _estimated_power_draw(installed)
			if capacity > 0 and required_power > capacity:
				continue
		if best.is_empty() or int(item.price) < int(best.price):
			best = item
	return best

func _find_inventory_stack(inventory: Array, type_key: String) -> Dictionary:
	for stack in inventory:
		if str(stack.type_key) == type_key:
			return stack
	return {}

func _complete_software_setup(game: Control) -> void:
	game._on_monitor_driver_tool_pressed()
	game._on_driver_scan_pressed()
	game._on_driver_install_pressed()
	game._on_driver_restart_pressed()

func _reasons_contain(reasons: Array, needle: String) -> bool:
	for reason in reasons:
		if str(reason).contains(needle):
			return true
	return false

func _cpu_platform(item: Dictionary) -> String:
	var text := "%s %s" % [str(item.name), str(item.model)]
	if text.contains("Threadripper") or text.contains("TR-"):
		return "sTR5"
	if text.contains("7950") or text.contains("7800") or text.contains("7600"):
		return "AM5"
	if text.contains("5600"):
		return "AM4"
	return "LGA1700"

func _motherboard_platform(item: Dictionary) -> String:
	var text := "%s %s" % [str(item.name), str(item.model)]
	if text.contains("X790"):
		return "sTR5"
	if text.contains("X670") or text.contains("B650"):
		return "AM5"
	if text.contains("A520") or text.contains("B550"):
		return "AM4"
	return "LGA1700"

func _power_capacity(item: Dictionary) -> int:
	var text := "%s %s" % [str(item.name), str(item.model)]
	var regex := RegEx.new()
	regex.compile("(\\d{3,4})W")
	var result := regex.search(text)
	if result == null:
		return 0
	return int(result.get_string(1))

func _estimated_power_draw(installed: Dictionary) -> int:
	var total := 150
	if installed.has("CPU"):
		total += 45 + int(installed["CPU"].tier) * 2
	if installed.has("VideoCard"):
		total += 30 + int(installed["VideoCard"].tier) * 4
	if installed.has("RAM"):
		total += 20
	if installed.has("SSD"):
		total += 10
	if installed.has("M2"):
		total += 10
	if installed.has("HDD"):
		total += 10
	if installed.has("COOLER"):
		total += 15
	return total
