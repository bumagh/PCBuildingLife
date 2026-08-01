extends SceneTree

func _init() -> void:
	root.size = Vector2i(1366, 768)
	var game := await _create_game()
	game.open_order_desk()
	await _settle()

	if game.order_desk_overlay == null or not game.order_desk_overlay.visible:
		_fail("Expected the order desk to open as a full-screen overlay.")
		return
	if game.order_desk_list.get_item_count() != game.available_order_indices.size():
		_fail("Expected order desk list count to match available orders.")
		return

	var overlay_rect: Rect2 = game.order_desk_overlay.get_global_rect()
	if overlay_rect.size.x < 1200.0 or overlay_rect.size.y < 680.0:
		_fail("Expected order desk overlay to use the full viewport.")
		return

	var list_rect: Rect2 = game.order_desk_list.get_global_rect()
	var title_rect: Rect2 = game.order_desk_title_label.get_global_rect()
	if list_rect.size.x < 300.0 or list_rect.size.y < 420.0:
		_fail("Expected order queue to remain wide and tall enough.")
		return
	if title_rect.position.x <= list_rect.end.x:
		_fail("Expected order detail area to sit beside the queue without overlap.")
		return

	var current_name: String = str(game.get_current_order().get("name", ""))
	if not game.order_desk_title_label.text.contains(current_name):
		_fail("Expected order desk to select the current order by default.")
		return
	if game.order_desk_accept_button.disabled or not game.order_desk_accept_button.text.contains("返回工作台"):
		_fail("Expected current order action to return to the workbench.")
		return

	var next_order_index := 1
	var next_order_name: String = str(game.order_defs[next_order_index].get("name", ""))
	game._select_order_desk_order(next_order_index)
	await _settle()
	if not game.order_desk_title_label.text.contains(next_order_name):
		_fail("Expected selecting an order to refresh the detail panel.")
		return
	if game.order_desk_accept_button.disabled:
		_fail("Expected a different available order to be actionable.")
		return

	game._on_order_desk_accept_pressed()
	await _settle()
	if game.current_order_index != next_order_index:
		_fail("Expected accepting from order desk to switch the active order.")
		return
	if game.order_desk_overlay.visible:
		_fail("Expected order desk to close after accepting an order.")
		return

	game.open_order_desk()
	await _settle()
	if game.order_desk_accept_button.disabled or not game.order_desk_accept_button.text.contains("返回工作台"):
		_fail("Expected reopened desk to treat the active order as a return action.")
		return
	if game.order_desk_scope_label.text.is_empty() or game.order_desk_score_label.text.is_empty():
		_fail("Expected order desk assessment cards to be populated.")
		return
	if game.order_desk_hardware_ready_label.text.is_empty() or not game.order_desk_hardware_ready_label.text.contains("硬件"):
		_fail("Expected order desk hardware readiness card to be populated.")
		return
	if game.order_desk_software_ready_label.text.is_empty() or not game.order_desk_software_ready_label.text.contains("软件"):
		_fail("Expected order desk software readiness card to be populated.")
		return
	if game.order_desk_delivery_ready_label.text.is_empty() or not game.order_desk_delivery_ready_label.text.contains("预估"):
		_fail("Expected order desk delivery readiness card to show delivery status.")
		return
	if game.order_desk_deliver_button.disabled:
		_fail("Expected delivery action to be enabled for the active order.")
		return
	if game.order_desk_market_button.disabled or game.order_desk_task_button.disabled:
		_fail("Expected order desk quick route buttons to be enabled.")
		return

	game._on_order_desk_market_pressed()
	await _settle()
	if game.order_desk_overlay.visible or game.catalog_overlay == null or not game.catalog_overlay.visible:
		_fail("Expected order desk market route to open the catalog overlay.")
		return
	game._close_catalog_overlay()
	await _settle()

	game.open_order_desk()
	await _settle()
	game._on_order_desk_task_center_pressed()
	await _settle()
	if game.order_desk_overlay.visible or game.task_center_overlay == null or not game.task_center_overlay.visible:
		_fail("Expected order desk task route to open the task center overlay.")
		return
	game._close_task_center()
	await _settle()

	game.open_order_desk()
	await _settle()

	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	game._unhandled_input(cancel_event)
	await _settle()
	if game.order_desk_overlay.visible:
		_fail("Expected Escape/ui_cancel to close the order desk.")
		return

	print("order_desk=ok")
	print("orders=%d" % game.order_desk_list.get_item_count())
	print("selected=%d" % game.current_order_index)
	quit(0)

func _create_game() -> Control:
	var game_scene := load("res://scenes/Game.tscn")
	var game: Control = game_scene.instantiate()
	root.add_child(game)
	await _settle()
	return game

func _settle() -> void:
	for _frame in range(4):
		await process_frame

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
