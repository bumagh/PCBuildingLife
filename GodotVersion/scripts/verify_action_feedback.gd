extends SceneTree

func _init() -> void:
	var game := await _create_game()
	if game.action_feedback_panel == null or game.action_feedback_title == null or game.action_feedback_detail == null:
		push_error("Expected global action feedback UI to be created.")
		quit(1)
		return
	if not str(game.action_feedback_title.text).contains("准备"):
		push_error("Expected initial action feedback to be idle.")
		quit(1)
		return

	var component_database := root.get_node("/root/ComponentDatabase")
	var cpu: Dictionary = component_database.get_components_by_type("CPU")[0]

	game.money = 0
	game._on_shop_item_selected(cpu)
	await process_frame
	if not _feedback_contains(game, "购买失败", "当前资金"):
		push_error("Expected purchase failure feedback with funds reason.")
		quit(1)
		return

	game.money = game.starting_money
	game._on_shop_item_selected(cpu)
	await process_frame
	if not _feedback_contains(game, "已购买配件", "加入背包"):
		push_error("Expected purchase success feedback.")
		quit(1)
		return

	game.money = 999999
	var board: Dictionary = component_database.get_components_by_type("MotherBoard")[0]
	game.installed["MotherBoard"] = board.duplicate(true)
	var blocked_cpu := _first_blocked_cpu(game, component_database)
	if blocked_cpu.is_empty():
		push_error("Expected at least one CPU to be blocked by the selected motherboard.")
		quit(1)
		return
	game._on_shop_item_quick_install_selected(blocked_cpu)
	await process_frame
	if not _feedback_contains(game, "兼容性阻止安装", "不兼容"):
		push_error("Expected compatibility blocker feedback.")
		quit(1)
		return

	if not game.apply_cheat_complete_driver_flow():
		push_error("Expected cheat driver flow to complete.")
		quit(1)
		return
	await process_frame
	if not _feedback_contains(game, "驱动验证完成", "软件配置完成度"):
		push_error("Expected software configuration feedback after driver restart.")
		quit(1)
		return

	game._on_os_benchmark_pressed()
	game._on_deliver_pressed()
	await process_frame
	if not _feedback_contains(game, "订单交付成功", "奖励"):
		push_error("Expected delivery reward feedback.")
		quit(1)
		return

	print("action_feedback=ok")
	print("title=%s" % str(game.action_feedback_title.text))
	print("detail=%s" % str(game.action_feedback_detail.text))
	quit(0)

func _create_game() -> Control:
	var game_scene := load("res://scenes/Game.tscn")
	var game: Control = game_scene.instantiate()
	root.add_child(game)
	for _frame in range(4):
		await process_frame
	return game

func _feedback_contains(game: Control, title_text: String, detail_text: String) -> bool:
	return str(game.action_feedback_title.text).contains(title_text) and str(game.action_feedback_detail.text).contains(detail_text)

func _first_blocked_cpu(game: Control, component_database: Node) -> Dictionary:
	for candidate in component_database.get_components_by_type("CPU"):
		var issues: Array[String] = game.can_install_component(candidate)
		if not issues.is_empty():
			var item: Dictionary = candidate
			return item
	return {}
