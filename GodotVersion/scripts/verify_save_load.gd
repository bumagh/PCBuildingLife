extends SceneTree

const SAVE_PATH := "user://verify_save_load.json"

func _init() -> void:
	var game := await _create_game()
	var component_database := root.get_node("/root/ComponentDatabase")
	var expected_money: int = game.STARTING_MONEY
	var first_cpu: Dictionary = _cheapest(component_database.get_components_by_type("CPU"))

	game._on_shop_item_selected(first_cpu)
	game._on_shop_item_selected(first_cpu)
	expected_money -= int(first_cpu.price) * 2
	game._on_inventory_item_selected(_find_inventory_stack(game.inventory, "CPU"))

	for slot in game.REQUIRED_SLOTS:
		if slot == "CPU":
			continue
		var item: Dictionary = _cheapest(component_database.get_components_by_type(slot))
		game._on_shop_item_selected(item)
		expected_money -= int(item.price)
		game._on_inventory_item_selected(_find_inventory_stack(game.inventory, slot))

	game.installed["CPU"] = component_database.components_by_id[10008].duplicate(true)
	game.installed["MotherBoard"] = component_database.components_by_id[10025].duplicate(true)
	game.installed["VideoCard"] = component_database.components_by_id[10019].duplicate(true)
	game.installed["Power"] = component_database.components_by_id[10054].duplicate(true)
	game.installed["Case"] = component_database.components_by_id[10084].duplicate(true)
	var installed_cpu_id: int = int(game.installed["CPU"].id)
	game._on_finish_pressed()
	if not game.powered_on:
		push_error("Expected completed build to power on before saving.")
		quit(1)
		return

	game.current_order_index = 1
	var saved_order_indices: Array[int] = [1, 2]
	game.available_order_indices = saved_order_indices
	var saved_cpu_quantity: int = game.get_inventory_quantity(first_cpu.id)
	if not game.save_game(SAVE_PATH):
		push_error("Expected save_game to succeed.")
		quit(1)
		return

	game.queue_free()
	await process_frame

	var loaded_game := await _create_game()
	if not loaded_game.load_game(SAVE_PATH):
		push_error("Expected load_game to succeed.")
		quit(1)
		return

	if loaded_game.money != expected_money:
		push_error("Expected loaded money %d, got %d." % [expected_money, loaded_game.money])
		quit(1)
		return

	if loaded_game.get_inventory_quantity(first_cpu.id) != 1:
		push_error("Expected one remaining CPU stack after load.")
		quit(1)
		return

	if not loaded_game.installed.has("CPU") or int(loaded_game.installed["CPU"].id) != installed_cpu_id:
		push_error("Expected installed CPU to be restored.")
		quit(1)
		return

	if loaded_game.installed.size() != loaded_game.REQUIRED_SLOTS.size():
		push_error("Expected all required installed slots to be restored.")
		quit(1)
		return

	if not loaded_game.powered_on:
		push_error("Expected powered_on to be restored.")
		quit(1)
		return

	if loaded_game.current_order_index != 1:
		push_error("Expected current_order_index to be restored.")
		quit(1)
		return

	if loaded_game.available_order_indices != saved_order_indices:
		push_error("Expected available_order_indices to be restored.")
		quit(1)
		return

	var loaded_powered_on: bool = loaded_game.powered_on
	loaded_game.new_game()
	if loaded_game.money != loaded_game.STARTING_MONEY or not loaded_game.inventory.is_empty() or not loaded_game.installed.is_empty() or loaded_game.powered_on:
		push_error("Expected new_game to reset money, inventory, installed slots, and power state.")
		quit(1)
		return

	print("save_load_smoke=ok")
	print("saved_money=%d" % expected_money)
	print("saved_inventory_cpu=%d" % saved_cpu_quantity)
	print("loaded_powered_on=%s" % str(loaded_powered_on))
	print("reset_powered_on=%s" % str(loaded_game.powered_on))
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

func _cheapest(items: Array) -> Dictionary:
	var best: Dictionary = items[0]
	for item in items:
		if int(item.price) < int(best.price):
			best = item
	return best

func _find_inventory_stack(inventory: Array, type_key: String) -> Dictionary:
	for stack in inventory:
		if str(stack.type_key) == type_key:
			return stack
	return {}
