extends Node

const SAVE_PATH := "user://first_order_audit_save.json"
const IDLE_FRAME_COUNT := 120
const HEADLESS_FRAME_BUDGET_MS := 8000

var report_path: String = "user://first-order-audit-report.json"
var save_count: int = 0
var load_count: int = 0
var order_name: String = ""
var reward: int = 0
var score: int = 0
var grade: String = ""
var final_money: int = 0
var frame_elapsed_ms: int = 0

func start(path: String) -> void:
	report_path = path if path != "" else report_path
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var game: Control = await _create_game()
	var component_database: Node = get_node("/root/ComponentDatabase")
	if game.cheat_button != null:
		_finish(false, "Expected release-like audit build to hide cheat tools.")
		return
	game.save_path_override = SAVE_PATH
	game.new_game()

	var frame_start: int = Time.get_ticks_msec()
	for _frame in range(IDLE_FRAME_COUNT):
		await get_tree().process_frame
	frame_elapsed_ms = Time.get_ticks_msec() - frame_start
	if frame_elapsed_ms > HEADLESS_FRAME_BUDGET_MS:
		_finish(false, "Frame budget exceeded: %dms / %dms." % [frame_elapsed_ms, HEADLESS_FRAME_BUDGET_MS])
		return

	var order: Dictionary = game.get_current_order()
	order_name = str(order.get("name", ""))
	if order_name == "":
		_finish(false, "Expected first order to be available.")
		return
	if _buy_minimum_build(game, component_database, order) < 0:
		return
	if not _complete_order_setup(game, order):
		return
	var before_money: int = int(game.money)
	game._on_deliver_pressed()
	if game.completed_order_ids.size() != 1:
		_finish(false, "Expected first order to be delivered.")
		return
	if game.last_delivery_score.is_empty():
		_finish(false, "Expected first order to produce a delivery score.")
		return
	score = int(game.last_delivery_score.get("score", 0))
	if score <= 0:
		_finish(false, "Expected first order delivery score to be positive.")
		return
	reward = int(game.money) - before_money
	grade = str(game.last_delivery_score.get("grade", ""))
	final_money = int(game.money)
	if not game.save_game(SAVE_PATH):
		_finish(false, "Expected first-order save to succeed.")
		return
	save_count += 1

	game.queue_free()
	await get_tree().process_frame
	var loaded_game: Control = await _create_game()
	loaded_game.save_path_override = SAVE_PATH
	if not loaded_game.load_game(SAVE_PATH):
		_finish(false, "Expected first-order save to load.")
		return
	load_count += 1
	if loaded_game.completed_order_ids.size() != 1:
		_finish(false, "Expected one completed order after loading first-order save.")
		return
	if int(loaded_game.money) != final_money:
		_finish(false, "Expected loaded money %d, got %d." % [final_money, int(loaded_game.money)])
		return
	_finish(true, "first_order_audit=ok")

func _create_game() -> Control:
	var game_script := load("res://scripts/game.gd")
	var game: Control = game_script.new()
	game.visible = false
	get_tree().root.add_child(game)
	for _frame in range(4):
		await get_tree().process_frame
	return game

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
		"orders_completed": 1 if ok else 0,
		"order_name": order_name,
		"save_count": save_count,
		"load_count": load_count,
		"reward": reward,
		"score": score,
		"grade": grade,
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
		if file_name.begins_with("first_order_audit_save.json"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
