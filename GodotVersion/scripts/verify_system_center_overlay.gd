extends SceneTree

func _init() -> void:
	root.size = Vector2i(1280, 720)
	var game := await _create_game()

	if not game.apply_cheat_fill_current_order():
		_fail("Failed to prepare the current order for system center.")
		return

	game.open_system_center_overlay()
	await _settle()
	if not _assert_system_center_visible(game):
		return
	if root.gui_get_focus_owner() != game.system_center_power_button:
		_fail("Expected system center to focus the power button before boot.")
		return
	if not game.system_center_info_button.disabled:
		_fail("Expected OS app buttons to be disabled before boot.")
		return

	game._on_system_center_power_pressed()
	await _settle()
	if not game.system_booted:
		_fail("Expected system center power button to boot the simulated OS.")
		return
	if game.system_center_info_button.disabled or game.system_center_monitor_button.disabled:
		_fail("Expected OS app buttons to unlock after boot.")
		return

	game._on_system_center_monitor_pressed()
	await _settle()
	if game.system_center_overlay.visible:
		_fail("Expected system center to close when Max Monitor opens.")
		return
	if game.monitor_overlay == null or not game.monitor_overlay.visible:
		_fail("Expected Max Monitor to open from system center.")
		return

	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	game._unhandled_input(cancel_event)
	await _settle()
	if game.monitor_overlay.visible:
		_fail("Expected ui_cancel to close Max Monitor.")
		return

	game.open_system_center_overlay()
	await _settle()
	game._unhandled_input(cancel_event)
	await _settle()
	if game.system_center_overlay.visible:
		_fail("Expected ui_cancel to close system center.")
		return

	print("system_center_overlay=ok")
	print("software_score=%d" % game.get_software_configuration_score())
	quit(0)

func _create_game() -> Control:
	var game_script := load("res://scripts/game.gd")
	var game: Control = game_script.new()
	root.add_child(game)
	await _settle()
	return game

func _assert_system_center_visible(game: Control) -> bool:
	if game.system_center_overlay == null or not game.system_center_overlay.visible:
		return _fail("Expected system center overlay to be visible.")
	var overlay_rect: Rect2 = game.system_center_overlay.get_global_rect()
	if overlay_rect.position.x > 1.0 or overlay_rect.position.y > 1.0:
		return _fail("System center overlay does not start at viewport origin.")
	if overlay_rect.end.x < 1279.0 or overlay_rect.end.y < 719.0:
		return _fail("System center overlay does not fill the viewport.")
	if game.system_center_status_label.text.is_empty() or game.system_center_software_label.text.is_empty():
		return _fail("Expected system center labels to render.")
	return true

func _settle() -> void:
	for _frame in range(4):
		await process_frame

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
