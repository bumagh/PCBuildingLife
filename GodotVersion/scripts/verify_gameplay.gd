extends SceneTree

func _init() -> void:
	var game_script := load("res://scripts/game.gd")
	var game: Control = game_script.new()
	root.add_child(game)
	await process_frame
	await process_frame
	await process_frame
	await process_frame

	var component_database := root.get_node("/root/ComponentDatabase")
	var expected_money: int = game.STARTING_MONEY
	var first_cpu: Dictionary = _cheapest(component_database.get_components_by_type("CPU"))
	var first_gpu: Dictionary = _cheapest(component_database.get_components_by_type("VideoCard"))
	game._on_slot_pressed("CPU")

	if game.shop_panel.get_visible_item_count() != 10:
		push_error("Expected CPU slot filter to show 10 shop items, got %d: %s" % [
			game.shop_panel.get_visible_item_count(),
			JSON.stringify(game.shop_panel.get_visible_type_counts()),
		])
		quit(1)
		return

	game._on_shop_item_selected(first_cpu)
	game._on_shop_item_selected(first_cpu)
	expected_money -= int(first_cpu.price) * 2

	if game.inventory.size() != 1 or game.get_inventory_quantity(first_cpu.id) != 2:
		push_error("Expected repeated purchases to stack in inventory.")
		quit(1)
		return

	game._on_inventory_item_selected(game.inventory[0])

	if not game.installed.has("CPU"):
		push_error("Expected CPU slot to be installed.")
		quit(1)
		return

	if game.money != expected_money:
		push_error("Expected money to decrease after repeated CPU purchases.")
		quit(1)
		return

	if game.get_inventory_quantity(first_cpu.id) != 1:
		push_error("Expected CPU stack quantity to decrease after installation.")
		quit(1)
		return

	var replacement_cpu: Dictionary = _cheapest_different(component_database.get_components_by_type("CPU"), first_cpu.id)
	game._on_shop_item_selected(replacement_cpu)
	expected_money -= int(replacement_cpu.price)
	game._on_inventory_item_selected(game.inventory.filter(func(stack): return int(stack.id) == int(replacement_cpu.id))[0])

	if int(game.installed["CPU"].id) != int(replacement_cpu.id):
		push_error("Expected replacement CPU to be installed.")
		quit(1)
		return

	if game.get_inventory_quantity(first_cpu.id) != 2:
		push_error("Expected replaced CPU to return to inventory.")
		quit(1)
		return

	game._on_shop_item_quick_install_selected(first_gpu)
	expected_money -= int(first_gpu.price)

	if not game.installed.has("VideoCard") or int(game.installed["VideoCard"].id) != int(first_gpu.id):
		push_error("Expected quick purchased GPU to be installed.")
		quit(1)
		return

	if game.get_inventory_quantity(first_gpu.id) != 0:
		push_error("Expected quick purchased GPU not to remain in inventory.")
		quit(1)
		return

	var replacement_gpu: Dictionary = _cheapest_different(component_database.get_components_by_type("VideoCard"), first_gpu.id)
	game._on_shop_item_quick_install_selected(replacement_gpu)
	expected_money -= int(replacement_gpu.price)

	if int(game.installed["VideoCard"].id) != int(replacement_gpu.id):
		push_error("Expected quick install to replace installed GPU.")
		quit(1)
		return

	if game.get_inventory_quantity(first_gpu.id) != 1:
		push_error("Expected old GPU to return to inventory after quick install replacement.")
		quit(1)
		return

	if game.get_inventory_quantity(replacement_gpu.id) != 0:
		push_error("Expected replacement GPU not to remain in inventory after quick install.")
		quit(1)
		return

	for slot in game.REQUIRED_SLOTS:
		if slot == "CPU" or slot == "VideoCard":
			continue
		var options: Array = component_database.get_components_by_type(slot)
		if options.is_empty():
			push_error("No component options for required slot: %s" % slot)
			quit(1)
			return
		var first_item: Dictionary = _cheapest(options)
		game._on_shop_item_selected(first_item)
		expected_money -= int(first_item.price)
		if game.inventory.is_empty():
			push_error("Expected purchased item in inventory for slot: %s" % slot)
			quit(1)
			return
		var stack_for_slot := _find_inventory_stack(game.inventory, slot)
		if stack_for_slot.is_empty():
			push_error("Expected purchased stack for slot: %s" % slot)
			quit(1)
			return
		game._on_inventory_item_selected(stack_for_slot)

	game.installed["CPU"] = component_database.components_by_id[10008].duplicate(true)
	game.installed["MotherBoard"] = component_database.components_by_id[10025].duplicate(true)
	game.installed["VideoCard"] = component_database.components_by_id[10019].duplicate(true)
	game.installed["Power"] = component_database.components_by_id[10054].duplicate(true)
	game.installed["Case"] = component_database.components_by_id[10084].duplicate(true)
	game._on_finish_pressed()

	if not game.powered_on:
		push_error("Expected complete build to pass power-on test.")
		quit(1)
		return

	print("gameplay_smoke=ok")
	print("installed_cpu=%s" % game.installed["CPU"].name)
	print("money=%d" % game.money)
	print("powered_on=%s" % str(game.powered_on))
	quit(0)

func _cheapest(items: Array) -> Dictionary:
	var best: Dictionary = items[0]
	for item in items:
		if int(item.price) < int(best.price):
			best = item
	return best

func _most_expensive(items: Array) -> Dictionary:
	var best: Dictionary = items[0]
	for item in items:
		if int(item.price) > int(best.price):
			best = item
	return best

func _cheapest_different(items: Array, excluded_id: int) -> Dictionary:
	var best: Dictionary = {}
	for item in items:
		if int(item.id) == excluded_id:
			continue
		if best.is_empty() or int(item.price) < int(best.price):
			best = item
	return best

func _find_inventory_stack(inventory: Array, type_key: String) -> Dictionary:
	for stack in inventory:
		if str(stack.type_key) == type_key:
			return stack
	return {}
