extends SceneTree

func _init() -> void:
	root.size = Vector2i(1280, 720)
	var game := await _create_game()

	game.open_task_center_overlay()
	await _settle()
	if not _assert_task_center_visible(game):
		return
	if root.gui_get_focus_owner() != game.task_center_next_button:
		_fail("Expected task center to focus the next-action button.")
		return
	if game.task_center_order_label.text.is_empty() or game.task_center_hardware_label.text.is_empty():
		_fail("Expected task center to render order and hardware summaries.")
		return

	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	game._unhandled_input(cancel_event)
	await _settle()
	if game.task_center_overlay.visible:
		_fail("Expected ui_cancel to close the task center.")
		return

	game.open_task_center_overlay()
	await _settle()
	game._on_task_center_next_pressed()
	await _settle()
	if game.task_center_overlay.visible or game.catalog_overlay == null or not game.catalog_overlay.visible:
		_fail("Expected task center next action to open the filtered shop while closing task center.")
		return
	game._close_catalog_overlay()

	if not game.apply_cheat_fill_current_order():
		_fail("Expected cheat helper to prepare the current order.")
		return
	game.open_task_center_overlay()
	await _settle()
	if not _assert_task_center_visible(game):
		return

	for _attempt in range(10):
		var action := str(game._task_center_next_action().get("action", ""))
		if action == "deliver":
			break
		game._on_task_center_next_pressed()
		await _settle()

	if str(game._task_center_next_action().get("action", "")) != "deliver":
		_fail("Expected task center flow to reach delivery action.")
		return
	var completed_before: int = game.completed_order_ids.size()
	game._on_task_center_next_pressed()
	await _settle()
	if game.completed_order_ids.size() <= completed_before:
		_fail("Expected task center delivery action to complete an order.")
		return
	if not game.task_center_overlay.visible:
		_fail("Expected task center to stay open after delivery and show the next state.")
		return
	if game.task_center_delivery_label.text.is_empty():
		_fail("Expected task center delivery label to remain populated.")
		return

	print("task_center_overlay=ok")
	print("completed_orders=%d" % game.completed_order_ids.size())
	print("next_action=%s" % str(game._task_center_next_action().get("action", "")))
	quit(0)

func _create_game() -> Control:
	var game_script := load("res://scripts/game.gd")
	var game: Control = game_script.new()
	root.add_child(game)
	await _settle()
	return game

func _assert_task_center_visible(game: Control) -> bool:
	if game.task_center_overlay == null or not game.task_center_overlay.visible:
		return _fail("Expected task center overlay to be visible.")
	var overlay_rect: Rect2 = game.task_center_overlay.get_global_rect()
	if overlay_rect.position.x > 1.0 or overlay_rect.position.y > 1.0:
		return _fail("Task center overlay does not start at viewport origin.")
	if overlay_rect.end.x < 1279.0 or overlay_rect.end.y < 719.0:
		return _fail("Task center overlay does not fill the viewport.")
	var order_rect: Rect2 = game.task_center_order_label.get_global_rect()
	var software_rect: Rect2 = game.task_center_software_label.get_global_rect()
	var delivery_rect: Rect2 = game.task_center_delivery_label.get_global_rect()
	if order_rect.end.x >= software_rect.position.x:
		return _fail("Task center order column overlaps software column.")
	if software_rect.end.x >= delivery_rect.position.x:
		return _fail("Task center software column overlaps delivery column.")
	return true

func _settle() -> void:
	for _frame in range(4):
		await process_frame

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
