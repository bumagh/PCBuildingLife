extends SceneTree

func _init() -> void:
	var game := await _create_game()
	var component_database := root.get_node("/root/ComponentDatabase")

	if game.order_defs.size() != 12:
		push_error("Expected 12 data-driven launch orders to load.")
		quit(1)
		return

	if game.required_slots.size() != game.REQUIRED_SLOTS.size():
		push_error("Expected required slots to load from rules.")
		quit(1)
		return

	var cpu: Dictionary = _cheapest(component_database.get_components_by_type("CPU"))
	game._on_shop_item_selected(cpu)
	if game.get_inventory_quantity(int(cpu.id)) != 1:
		push_error("Expected purchased CPU in inventory.")
		quit(1)
		return

	var money_after_buy: int = game.money
	var expected_refund := int(round(float(cpu.price) * game.sell_ratio))
	game._on_inventory_item_sold(game.inventory[0])
	if game.money != money_after_buy + expected_refund:
		push_error("Expected inventory sale refund.")
		quit(1)
		return

	game.new_game()
	game._on_shop_item_selected(cpu)
	game._on_inventory_item_dropped("CPU", game.inventory[0])
	if not game.installed.has("CPU"):
		push_error("Expected drag-drop install to place CPU.")
		quit(1)
		return

	game.new_game()
	_buy_and_install_required(game, component_database)
	game._on_finish_pressed()
	if not game.powered_on:
		push_error("Expected completed build to pass detection: %s" % JSON.stringify(game.get_compatibility_issues()))
		quit(1)
		return

	game._on_power_button_pressed()
	if not game.system_booted or game.os_app != "桌面":
		push_error("Expected power button to boot simulated OS.")
		quit(1)
		return

	game._on_os_system_info_pressed()
	if game.os_app != "系统信息":
		push_error("Expected system info app to open.")
		quit(1)
		return

	game._on_os_benchmark_pressed()
	if game.os_app != "跑分工具" or game.os_log.is_empty():
		push_error("Expected benchmark operation to log a result.")
		quit(1)
		return
	game._on_monitor_driver_tool_pressed()
	game._on_driver_scan_pressed()
	game._on_driver_install_pressed()
	game._on_driver_restart_pressed()

	var score: Dictionary = game.calculate_delivery_score()
	if int(score.get("score", 0)) <= 0 or str(score.get("grade", "")) == "":
		push_error("Expected delivery score to be calculated.")
		quit(1)
		return
	if int(score.get("software", 0)) != 100:
		push_error("Expected verified software setup to score 100.")
		quit(1)
		return

	var result: Dictionary = game.deliver_order()
	if not bool(result.get("ok", false)):
		push_error("Expected extended delivery to pass: %s" % JSON.stringify(result))
		quit(1)
		return

	if not result.has("score") or int(result.score.get("score", 0)) <= 0:
		push_error("Expected delivery result to include score.")
		quit(1)
		return

	print("extended_flow=ok")
	print("loaded_orders=%d" % game.order_defs.size())
	print("sell_refund=%d" % expected_refund)
	print("score=%d" % int(result.score.score))
	print("grade=%s" % str(result.score.grade))
	print("os_log=%s" % game.os_log[game.os_log.size() - 1])
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

func _buy_and_install_required(game: Control, component_database: Node) -> void:
	var order: Dictionary = game.get_current_order()
	var requirements: Dictionary = order.requirements
	var install_order := _build_install_order(game.required_slots)
	for slot in install_order:
		var min_tier := 0
		if requirements.has(slot):
			min_tier = int(requirements[slot])
		var item: Dictionary = _cheapest_compatible_for_slot(game, component_database, slot, min_tier)
		if item.is_empty():
			push_error("No compatible item for slot: %s" % slot)
			quit(1)
			return
		game._on_shop_item_quick_install_selected(item)

func _build_install_order(required_slots: Array) -> Array[String]:
	var install_order: Array[String] = []
	for slot in required_slots:
		if slot != "Power":
			install_order.append(str(slot))
	install_order.append("Power")
	return install_order

func _cheapest(items: Array) -> Dictionary:
	var best: Dictionary = items[0]
	for item in items:
		if int(item.price) < int(best.price):
			best = item
	return best

func _cheapest_compatible_for_slot(game: Control, component_database: Node, slot: String, min_tier: int) -> Dictionary:
	var best: Dictionary = {}
	for item in component_database.get_components_by_type(slot):
		if int(item.tier) < min_tier:
			continue
		if not game.can_install_component(item).is_empty():
			continue
		if best.is_empty() or int(item.price) < int(best.price):
			best = item
	return best
