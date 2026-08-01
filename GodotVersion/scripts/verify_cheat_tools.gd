extends SceneTree

func _init() -> void:
	var game := await _create_game()
	var initial_money := int(game.money)

	game.apply_cheat_money(100000)
	if int(game.money) != initial_money + 100000:
		push_error("Expected cheat money to increase funds.")
		quit(1)
		return

	game.money = 0
	if not game.apply_cheat_fill_current_order():
		push_error("Expected cheat fill order to install compatible parts.")
		quit(1)
		return
	if int(game.money) != 0:
		push_error("Expected cheat fill order to preserve current money.")
		quit(1)
		return
	if not game.get_missing_required_slots().is_empty():
		push_error("Expected cheat fill order to satisfy required slots.")
		quit(1)
		return
	if not game.get_compatibility_issues().is_empty():
		push_error("Expected cheat fill order to be compatible: %s" % JSON.stringify(game.get_compatibility_issues()))
		quit(1)
		return

	game.apply_cheat_boot_pass()
	if not game.powered_on or not game.system_booted:
		push_error("Expected cheat boot pass to power and boot the system.")
		quit(1)
		return
	game._on_monitor_driver_tool_pressed()
	game._on_driver_scan_pressed()
	game._on_driver_install_pressed()
	game._on_driver_restart_pressed()

	var result: Dictionary = game.deliver_order()
	if not bool(result.get("ok", false)):
		push_error("Expected cheated build to deliver current order: %s" % JSON.stringify(result))
		quit(1)
		return

	print("cheat_tools=ok")
	print("reward=%d" % int(result.get("reward", 0)))
	print("next_order_index=%d" % int(result.get("order_index", -1)))
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
