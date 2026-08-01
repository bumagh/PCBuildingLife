extends SceneTree

func _init() -> void:
	var game := await _create_game()
	_verify_task_gate(game, 1, "benchmark", "Benchmark")
	_verify_task_gate(game, 3, "gpu_driver", "显卡驱动")
	_verify_task_gate(game, 5, "stability", "Stability Test")

	_prepare_order(game, 11)
	_complete_base_drivers(game)
	var incomplete: Array[String] = game._incomplete_software_tasks(game.get_current_order())
	for task in ["gpu_driver", "benchmark", "stability"]:
		if not incomplete.has(task):
			_fail("Expected flagship order to require %s." % task)
			return
	game._on_gpu_driver_install_pressed()
	game._on_os_benchmark_pressed()
	game._on_os_stability_test_pressed()
	if not game.is_software_configuration_complete() or game.get_software_configuration_score() != 100:
		_fail("Expected all flagship software tasks to reach 100.")
		return

	print("order_software_tasks=ok")
	print("benchmark_gate=verified")
	print("gpu_driver_gate=verified")
	print("stability_gate=verified")
	print("flagship_software_score=%d" % game.get_software_configuration_score())
	quit(0)

func _verify_task_gate(game: Control, order_index: int, task: String, reason_text: String) -> void:
	_prepare_order(game, order_index)
	_complete_base_drivers(game)
	if game.is_software_configuration_complete():
		_fail("Expected %s to remain incomplete after base drivers." % task)
		return
	var result: Dictionary = game.deliver_order()
	if bool(result.get("ok", false)) or not _reasons_contain(result.get("reasons", []), reason_text):
		_fail("Expected %s delivery gate: %s" % [task, JSON.stringify(result)])
		return
	match task:
		"benchmark":
			game._on_os_benchmark_pressed()
		"gpu_driver":
			game._on_gpu_driver_install_pressed()
		"stability":
			game._on_os_stability_test_pressed()
	if not game.is_software_configuration_complete():
		_fail("Expected %s task completion." % task)

func _prepare_order(game: Control, order_index: int) -> void:
	game.new_game()
	game.current_order_index = order_index
	game.available_order_indices.clear()
	game.available_order_indices.append(order_index)
	game.tutorial_order_viewed = true
	if not game.apply_cheat_fill_current_order():
		_fail("Expected compatible build for order %d." % order_index)
		return
	game._on_finish_pressed()
	game._on_power_button_pressed()

func _complete_base_drivers(game: Control) -> void:
	game._on_monitor_driver_tool_pressed()
	game._on_driver_scan_pressed()
	game._on_driver_install_pressed()
	game._on_driver_restart_pressed()

func _reasons_contain(reasons: Array, needle: String) -> bool:
	for reason in reasons:
		if str(reason).contains(needle):
			return true
	return false

func _create_game() -> Control:
	var game_script := load("res://scripts/game.gd")
	var game: Control = game_script.new()
	root.add_child(game)
	for _frame in range(4):
		await process_frame
	return game

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
