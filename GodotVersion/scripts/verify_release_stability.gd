extends SceneTree

const SAVE_PATH := "user://verify_release_stability.json"
const RELOADS_PER_ORDER := 2
const IDLE_FRAME_COUNT := 480
const HEADLESS_FRAME_BUDGET_MS := 8000

var save_count := 0
var load_count := 0
var minimum_money := 0
var frame_elapsed_ms := 0

func _init() -> void:
	_cleanup()
	var game := await _create_game()
	var component_database := root.get_node("/root/ComponentDatabase")
	var session := root.get_node("GameSession")
	game.save_path_override = SAVE_PATH
	game.new_game()
	minimum_money = int(game.money)

	var frame_start := Time.get_ticks_msec()
	for _frame in range(IDLE_FRAME_COUNT):
		await process_frame
	frame_elapsed_ms = Time.get_ticks_msec() - frame_start
	if frame_elapsed_ms > HEADLESS_FRAME_BUDGET_MS:
		_fail("Headless frame budget exceeded: %dms / %dms." % [frame_elapsed_ms, HEADLESS_FRAME_BUDGET_MS])
		return

	for expected_index in range(game.order_defs.size()):
		if game.current_order_index != expected_index:
			_fail("Expected active order %d, got %d." % [expected_index, game.current_order_index])
			return
		var order: Dictionary = game.get_current_order()
		var build_cost := _buy_minimum_build(game, component_database, order)
		if build_cost < 0:
			return
		minimum_money = mini(minimum_money, int(game.money))
		if not _complete_order_setup(game, order):
			return
		var result: Dictionary = game.deliver_order()
		if not bool(result.get("ok", false)):
			_fail("Expected delivery to pass for %s: %s" % [order.name, JSON.stringify(result)])
			return
		if game.money <= 0:
			_fail("Money dropped below zero after %s." % order.name)
			return
		game = await _save_and_reload_after_order(game, expected_index + 1)
		if game == null:
			return

	if game.completed_order_ids.size() != game.order_defs.size():
		_fail("Expected all orders completed after stability run.")
		return
	if not game.available_order_indices.is_empty() or game.current_order_index != -1:
		_fail("Expected no available orders after full completion.")
		return

	var final_money := int(game.money)
	if not game.save_game(SAVE_PATH):
		_fail("Expected final save to succeed.")
		return
	save_count += 1
	game.money = max(0, final_money - 1)
	if not game.save_game(SAVE_PATH):
		_fail("Expected backup-creating save to succeed.")
		return
	save_count += 1
	var corrupt := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	corrupt.store_string("{abnormal-exit")
	corrupt.close()
	if not session.restore_save_backup(SAVE_PATH):
		_fail("Expected backup restore after corrupt primary.")
		return
	var restored_game := await _create_game()
	if not restored_game.load_game(SAVE_PATH):
		_fail("Expected restored backup save to load.")
		return
	load_count += 1
	if int(restored_game.money) != final_money:
		_fail("Expected restored money %d, got %d." % [final_money, restored_game.money])
		return
	if restored_game.completed_order_ids.size() != restored_game.order_defs.size():
		_fail("Expected restored save to keep all completed orders.")
		return

	_cleanup()
	print("release_stability=ok")
	print("orders_completed=%d" % restored_game.completed_order_ids.size())
	print("save_count=%d" % save_count)
	print("load_count=%d" % load_count)
	print("minimum_money=%d" % minimum_money)
	print("final_money=%d" % final_money)
	print("frame_elapsed_ms=%d" % frame_elapsed_ms)
	quit(0)

func _create_game() -> Control:
	var game_script := load("res://scripts/game.gd")
	var game: Control = game_script.new()
	root.add_child(game)
	for _frame in range(4):
		await process_frame
	return game

func _save_and_reload_after_order(game: Control, completed_count: int) -> Control:
	if not game.save_game(SAVE_PATH):
		_fail("Expected save after order %d to succeed." % completed_count)
		return null
	save_count += 1
	_write_orphan_temp_save()
	game.queue_free()
	await process_frame

	var loaded_game: Control
	for reload_index in range(RELOADS_PER_ORDER):
		loaded_game = await _create_game()
		loaded_game.save_path_override = SAVE_PATH
		if not loaded_game.load_game(SAVE_PATH):
			_fail("Expected reload %d after order %d to succeed." % [reload_index + 1, completed_count])
			return null
		load_count += 1
		if loaded_game.completed_order_ids.size() != completed_count:
			_fail("Expected %d completed orders after reload, got %d." % [completed_count, loaded_game.completed_order_ids.size()])
			return null
		if not FileAccess.file_exists(SAVE_PATH + ".tmp"):
			_fail("Expected orphan temp save to remain available for abnormal-exit coverage.")
			return null
		if reload_index < RELOADS_PER_ORDER - 1:
			loaded_game.queue_free()
			await process_frame
	return loaded_game

func _write_orphan_temp_save() -> void:
	var temp_file := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	temp_file.store_string("{orphan-temp-save")
	temp_file.close()

func _complete_order_setup(game: Control, order: Dictionary) -> bool:
	game._on_finish_pressed()
	if not game.powered_on:
		_fail("Expected build to power on for %s: %s" % [order.name, JSON.stringify(game.get_compatibility_issues())])
		return false
	game._on_power_button_pressed()
	if not game.system_booted:
		_fail("Expected simulated OS to boot for %s." % order.name)
		return false
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
		return false
	return true

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
		game._on_shop_item_quick_install_selected(item)
		if not game.installed.has(slot) or int(game.installed[slot].id) != int(item.id):
			_fail("Purchase/install failed for %s / %s." % [order.name, slot])
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

func _cleanup() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("verify_release_stability.json"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

func _fail(message: String) -> void:
	_cleanup()
	push_error(message)
	quit(1)
