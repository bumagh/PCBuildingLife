extends Node

const SAVE_PATH := "user://release_player_flow_save.json"
const RELOADS_PER_CHECKPOINT := 1
const IDLE_FRAME_COUNT := 240
const HEADLESS_FRAME_BUDGET_MS := 8000

var report_path: String = "user://release-player-flow-report.json"
var save_count: int = 0
var load_count: int = 0
var minimum_money: int = 0
var frame_elapsed_ms: int = 0
var completed_orders: int = 0
var final_money: int = 0

func start(path: String) -> void:
	report_path = path if path != "" else report_path
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var game: Control = await _create_game()
	var component_database: Node = get_node("/root/ComponentDatabase")
	if game.cheat_button != null:
		_finish(false, "Expected release build to hide cheat tools.")
		return
	game.save_path_override = SAVE_PATH
	game.new_game()
	minimum_money = int(game.money)

	var frame_start: int = Time.get_ticks_msec()
	for _frame in range(IDLE_FRAME_COUNT):
		await get_tree().process_frame
	frame_elapsed_ms = Time.get_ticks_msec() - frame_start
	if frame_elapsed_ms > HEADLESS_FRAME_BUDGET_MS:
		_finish(false, "Frame budget exceeded: %dms / %dms." % [frame_elapsed_ms, HEADLESS_FRAME_BUDGET_MS])
		return

	for expected_index in range(game.order_defs.size()):
		if game.current_order_index != expected_index:
			_finish(false, "Expected active order %d, got %d." % [expected_index, game.current_order_index])
			return
		var order: Dictionary = game.get_current_order()
		var build_cost: int = _buy_minimum_build(game, component_database, order)
		if build_cost < 0:
			return
		minimum_money = mini(minimum_money, int(game.money))
		if not _complete_order_setup(game, order):
			return
		var before_completed: int = game.completed_order_ids.size()
		game._on_deliver_pressed()
		if game.completed_order_ids.size() != before_completed + 1:
			_finish(false, "Expected UI delivery to complete %s." % order.name)
			return
		completed_orders = game.completed_order_ids.size()
		if game.money <= 0:
			_finish(false, "Money dropped below zero after %s." % order.name)
			return
		game = await _save_and_reload_checkpoint(game, completed_orders)
		if game == null:
			return

	final_money = int(game.money)
	if completed_orders != game.order_defs.size():
		_finish(false, "Expected all orders complete, got %d." % completed_orders)
		return
	if not game.available_order_indices.is_empty() or game.current_order_index != -1:
		_finish(false, "Expected no active orders after final delivery.")
		return
	if not game.save_game(SAVE_PATH):
		_finish(false, "Expected final player-flow save to succeed.")
		return
	save_count += 1
	_finish(true, "release_player_flow=ok")

func _create_game() -> Control:
	var game_script := load("res://scripts/game.gd")
	var game: Control = game_script.new()
	game.visible = false
	get_tree().root.add_child(game)
	for _frame in range(4):
		await get_tree().process_frame
	return game

func _save_and_reload_checkpoint(game: Control, expected_completed: int) -> Control:
	if not game.save_game(SAVE_PATH):
		_finish(false, "Expected save after order %d to succeed." % expected_completed)
		return null
	save_count += 1
	game.queue_free()
	await get_tree().process_frame

	var loaded_game: Control
	for reload_index in range(RELOADS_PER_CHECKPOINT):
		loaded_game = await _create_game()
		loaded_game.save_path_override = SAVE_PATH
		if not loaded_game.load_game(SAVE_PATH):
			_finish(false, "Expected reload %d after order %d to succeed." % [reload_index + 1, expected_completed])
			return null
		load_count += 1
		if loaded_game.completed_order_ids.size() != expected_completed:
			_finish(false, "Expected %d completed orders after reload, got %d." % [expected_completed, loaded_game.completed_order_ids.size()])
			return null
		if reload_index < RELOADS_PER_CHECKPOINT - 1:
			loaded_game.queue_free()
			await get_tree().process_frame
	return loaded_game

func _complete_order_setup(game: Control, order: Dictionary) -> bool:
	game._on_finish_pressed()
	if not game.powered_on:
		_finish(false, "Expected build to power on for %s: %s" % [order.name, JSON.stringify(game.get_compatibility_issues())])
		return false
	game._on_power_button_pressed()
	if not game.system_booted:
		_finish(false, "Expected simulated OS to boot for %s." % order.name)
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
		_finish(false, "Expected software tasks complete for %s: %s" % [order.name, JSON.stringify(game._incomplete_software_tasks(order))])
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

	var platform_pair: Dictionary = _cheapest_platform_pair(
		game,
		component_database,
		int(order.requirements.get("CPU", 0)),
		int(order.requirements.get("MotherBoard", 0))
	)
	if platform_pair.is_empty():
		_finish(false, "No compatible CPU/motherboard pair for %s." % order.name)
		return -1

	var total: int = 0
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
			_finish(false, "No compatible component for %s / %s." % [order.name, slot])
			return -1
		game._on_shop_item_quick_install_selected(item)
		if not game.installed.has(slot) or int(game.installed[slot].id) != int(item.id):
			_finish(false, "Purchase/install failed for %s / %s." % [order.name, slot])
			return -1
		total += int(item.price)
	return total

func _cheapest_platform_pair(game: Control, component_database: Node, cpu_tier: int, board_tier: int) -> Dictionary:
	var best: Dictionary = {}
	var best_cost: int = 2147483647
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

func _finish(ok: bool, message: String) -> void:
	var report := {
		"ok": ok,
		"status": "passed" if ok else "failed",
		"message": message,
		"orders_completed": completed_orders,
		"save_count": save_count,
		"load_count": load_count,
		"minimum_money": minimum_money,
		"final_money": final_money,
		"frame_elapsed_ms": frame_elapsed_ms,
	}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print(message)
	if not ok:
		push_error(message)
	_cleanup()
	get_tree().quit(0 if ok else 1)

func _cleanup() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("release_player_flow_save.json"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
