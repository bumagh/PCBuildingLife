extends SceneTree

func _init() -> void:
	var game := await _create_game()
	var component_database := root.get_node("/root/ComponentDatabase")
	if game.order_defs.size() != 12 or game.available_order_indices != [0, 1, 2]:
		_fail("Expected 12 launch orders with the first three unlocked.")
		return

	var customer_types: Array[String] = []
	var task_types: Array[String] = []
	var estimated_minutes: int = 0
	for order in game.order_defs:
		var customer_type := str(order.get("customer_type", ""))
		if not customer_types.has(customer_type):
			customer_types.append(customer_type)
		for task in order.get("software_tasks", []):
			var task_key := str(task)
			if not task_types.has(task_key):
				task_types.append(task_key)
		estimated_minutes += int(order.get("estimated_minutes", 0))
	if customer_types.size() < 6:
		_fail("Expected at least six customer types, got %d." % customer_types.size())
		return
	for required_task in ["drivers", "gpu_driver", "benchmark", "stability"]:
		if not task_types.has(required_task):
			_fail("Missing software task type: %s." % required_task)
			return
	if estimated_minutes < 60:
		_fail("Expected at least 60 estimated launch minutes, got %d." % estimated_minutes)
		return

	game.new_game()
	var minimum_money: int = int(game.money)
	var total_spent: int = 0
	var total_rewards: int = 0
	for expected_index in range(game.order_defs.size()):
		if game.current_order_index != expected_index:
			_fail("Expected progression order %d, got %d." % [expected_index, game.current_order_index])
			return
		var order: Dictionary = game.get_current_order()
		var build_cost: int = _buy_minimum_build(game, component_database, order)
		if build_cost < 0:
			return
		total_spent += build_cost
		minimum_money = mini(minimum_money, game.money)
		game._on_finish_pressed()
		game._on_power_button_pressed()
		_complete_base_drivers(game)

		var tasks: Array[String] = game._software_tasks(order)
		if tasks.has("gpu_driver"):
			game._on_gpu_driver_install_pressed()
		if tasks.has("benchmark"):
			game._on_os_benchmark_pressed()
		if tasks.has("stability"):
			game._on_os_stability_test_pressed()
		if not game.is_software_configuration_complete():
			_fail("Expected software tasks complete for %s: %s" % [order.name, JSON.stringify(game._incomplete_software_tasks(order))])
			return

		var result: Dictionary = game.deliver_order()
		if not bool(result.get("ok", false)):
			_fail("Expected order %s delivery: %s" % [order.name, JSON.stringify(result)])
			return
		total_rewards += int(result.reward)
		if game.money <= 0:
			_fail("Economy became insolvent after %s." % order.name)
			return

	if game.completed_order_ids.size() != 12 or not game.available_order_indices.is_empty() or game.current_order_index != -1:
		_fail("Expected finite completion state after all 12 orders.")
		return
	if game.money <= game.starting_money:
		_fail("Expected positive career profit, start %d / end %d." % [game.starting_money, game.money])
		return

	print("content_progression=ok")
	print("orders_completed=%d" % game.completed_order_ids.size())
	print("customer_types=%d" % customer_types.size())
	print("software_tasks=%s" % ",".join(task_types))
	print("estimated_minutes=%d" % estimated_minutes)
	print("total_spent=%d" % total_spent)
	print("total_rewards=%d" % total_rewards)
	print("minimum_money=%d" % minimum_money)
	print("final_money=%d" % game.money)
	quit(0)

func _create_game() -> Control:
	var game_script := load("res://scripts/game.gd")
	var game: Control = game_script.new()
	root.add_child(game)
	for _frame in range(4):
		await process_frame
	return game

func _buy_minimum_build(game: Control, component_database: Node, order: Dictionary) -> int:
	var slots: Array[String] = []
	var preferred_order := ["Case", "CPU", "MotherBoard", "VideoCard", "RAM", "SSD", "M2", "COOLER"]
	for slot in preferred_order:
		if game.required_slots.has(slot):
			slots.append(slot)
	for slot in game.required_slots:
		var required_slot := str(slot)
		if required_slot != "Power" and not slots.has(required_slot):
			slots.append(required_slot)
	for slot in order.requirements.keys():
		var slot_key := str(slot)
		if slot_key != "Power" and not slots.has(slot_key):
			slots.append(slot_key)
	slots.append("Power")
	var platform_pair := _cheapest_platform_pair(
		game,
		component_database,
		int(order.requirements.get("CPU", 0)),
		int(order.requirements.get("MotherBoard", 0))
	)
	if platform_pair.is_empty():
		_fail("No compatible CPU/motherboard pair for %s." % order.name)
		return -1

	var total := 0
	for slot in slots:
		var min_tier := int(order.requirements.get(slot, 0))
		var item: Dictionary
		if slot == "CPU":
			item = platform_pair.cpu
		elif slot == "MotherBoard":
			item = platform_pair.board
		else:
			item = _cheapest_compatible(game, component_database.get_components_by_type(slot), min_tier)
		if item.is_empty():
			_fail("No compatible component for %s / %s." % [order.name, slot])
			return -1
		var money_before: int = game.money
		game._on_shop_item_quick_install_selected(item)
		if not game.installed.has(slot) or int(game.installed[slot].id) != int(item.id):
			_fail("Purchase/install failed for %s / %s with money %d." % [order.name, slot, money_before])
			return -1
		total += int(item.price)
	return total

func _cheapest_platform_pair(game: Control, component_database: Node, cpu_tier: int, board_tier: int) -> Dictionary:
	var best: Dictionary = {}
	var best_cost := 2147483647
	for cpu in component_database.get_components_by_type("CPU"):
		if int(cpu.tier) < cpu_tier:
			continue
		game.installed["CPU"] = cpu
		for board in component_database.get_components_by_type("MotherBoard"):
			if int(board.tier) < board_tier or not game.can_install_component(board).is_empty():
				continue
			var pair_cost := int(cpu.price) + int(board.price)
			if pair_cost < best_cost:
				best_cost = pair_cost
				best = {"cpu": cpu, "board": board}
		game.installed.erase("CPU")
	return best

func _cheapest_compatible(game: Control, items: Array, min_tier: int) -> Dictionary:
	var best: Dictionary = {}
	for item in items:
		if int(item.tier) < min_tier or not game.can_install_component(item).is_empty():
			continue
		if best.is_empty() or int(item.price) < int(best.price):
			best = item
	return best

func _complete_base_drivers(game: Control) -> void:
	game._on_monitor_driver_tool_pressed()
	game._on_driver_scan_pressed()
	game._on_driver_install_pressed()
	game._on_driver_restart_pressed()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
