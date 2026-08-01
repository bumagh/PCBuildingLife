extends SceneTree

func _init() -> void:
	var game := await _create_game()
	game.new_game()
	if not _assert_step(game, 0, "查看订单"):
		return

	game._on_tutorial_action_pressed()
	if not game.tutorial_order_viewed or game.order_desk_overlay == null or not game.order_desk_overlay.visible:
		_fail("Expected guide to open and acknowledge the full-screen order desk.")
		return
	game._close_order_desk()
	if not _assert_step(game, 1, "选择下一个空槽"):
		return

	game._on_tutorial_action_pressed()
	if game.current_filter == "" or game.main_tabs.current_tab != 1:
		_fail("Expected guide to select a missing slot and open the shop.")
		return
	if not _assert_step(game, 2, "继续选件"):
		return

	if not game.apply_cheat_fill_current_order():
		_fail("Expected test helper to fill the onboarding build.")
		return
	if not _assert_step(game, 3, "完成检查"):
		return

	game._on_tutorial_action_pressed()
	if not game.powered_on:
		_fail("Expected guide to run the hardware check.")
		return
	if not _assert_step(game, 4, "按电源"):
		return

	game._on_tutorial_action_pressed()
	if not game.system_booted:
		_fail("Expected guide to boot the simulated OS.")
		return
	if not _assert_step(game, 5, "打开 Driver Tool"):
		return

	game._on_tutorial_action_pressed()
	if not game.monitor_overlay.visible or game.monitor_app_key != "Driver Tool":
		_fail("Expected guide to open the maximized Driver Tool.")
		return
	if not _assert_step(game, 6, "扫描设备"):
		return

	game._on_tutorial_action_pressed()
	if not _assert_step(game, 6, "安装驱动"):
		return
	game._on_tutorial_action_pressed()
	if not _assert_step(game, 6, "重启验证"):
		return
	game._on_tutorial_action_pressed()
	if not _assert_step(game, 7, "跑分"):
		return

	game._on_tutorial_action_pressed()
	if not game.benchmark_completed:
		_fail("Expected guide to complete the benchmark.")
		return
	if not _assert_step(game, 8, "交付订单"):
		return
	var benchmark_was_completed: bool = game.benchmark_completed

	game._on_tutorial_action_pressed()
	if not game.tutorial_completed or game.tutorial_step != 9:
		_fail("Expected guide to complete after first delivery.")
		return
	if not game.tutorial_action_button.disabled:
		_fail("Expected completed guide action to be disabled.")
		return

	print("guided_onboarding=ok")
	print("final_step=%d" % game.tutorial_step)
	print("benchmark_completed=%s" % str(benchmark_was_completed))
	quit(0)

func _create_game() -> Control:
	var game_script := load("res://scripts/game.gd")
	var game: Control = game_script.new()
	root.add_child(game)
	for _frame in range(4):
		await process_frame
	return game

func _assert_step(game: Control, expected: int, action_text: String) -> bool:
	game._refresh_tutorial_status()
	if game.tutorial_step != expected or game.tutorial_action_button.text != action_text:
		_fail("Expected guide step %d / %s, got %d / %s." % [expected, action_text, game.tutorial_step, game.tutorial_action_button.text])
		return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
