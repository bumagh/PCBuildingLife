extends SceneTree

func _init() -> void:
	var game := await _create_game()
	var component_database := root.get_node("/root/ComponentDatabase")
	var cpu: Dictionary = component_database.get_components_by_type("CPU")[0]

	var initial_count: int = int(game.operation_animation_count)
	game._on_shop_item_selected(cpu)
	if game.last_operation_animation != "purchase" or int(game.operation_animation_count) <= initial_count:
		_fail("Expected purchase animation to run.")
		return
	if game.money_label.modulate == Color.WHITE:
		_fail("Expected money label to pulse on purchase.")
		return

	var after_purchase_count: int = int(game.operation_animation_count)
	if not game._install_from_inventory(cpu):
		_fail("Expected CPU to install from inventory.")
		return
	if game.last_operation_animation != "install" or int(game.operation_animation_count) <= after_purchase_count:
		_fail("Expected install animation to run.")
		return
	if game.building_panel._visual_cards["CPU"].modulate == Color.WHITE:
		_fail("Expected installed CPU visual card to pulse.")
		return

	if not game.apply_cheat_fill_current_order():
		_fail("Expected cheat fill to prepare the build.")
		return
	game._on_finish_pressed()
	if game.last_operation_animation != "power":
		_fail("Expected power-check animation.")
		return
	if game.building_panel._power_state_label.modulate == Color.WHITE:
		_fail("Expected power state label to pulse.")
		return

	game._on_power_button_pressed()
	game._on_open_monitor_pressed()
	game._on_monitor_driver_tool_pressed()
	game._on_driver_scan_pressed()
	game._on_driver_install_pressed()
	game._on_driver_restart_pressed()
	if game.last_operation_animation != "software":
		_fail("Expected driver software animation.")
		return
	if game.os_label.modulate == Color.WHITE:
		_fail("Expected OS label to pulse for software work.")
		return

	game._on_os_benchmark_pressed()
	if game.last_operation_animation != "benchmark":
		_fail("Expected benchmark animation.")
		return

	game._on_deliver_pressed()
	if game.last_operation_animation != "delivery":
		_fail("Expected delivery animation.")
		return
	if game.money_label.modulate == Color.WHITE:
		_fail("Expected money label to pulse on delivery reward.")
		return

	print("key_animations=ok")
	print("animation_count=%d" % int(game.operation_animation_count))
	print("last_animation=%s" % str(game.last_operation_animation))
	quit(0)

func _create_game() -> Control:
	var game_scene := load("res://scenes/Game.tscn")
	var game: Control = game_scene.instantiate()
	root.add_child(game)
	for _frame in range(4):
		await process_frame
	return game

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
