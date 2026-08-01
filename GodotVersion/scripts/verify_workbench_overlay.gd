extends SceneTree

func _init() -> void:
	var game := await _create_game()
	var cpu_marker: Control = game.building_panel._overlay_cards.get("CPU")
	if cpu_marker == null:
		push_error("Expected CPU overlay marker to exist.")
		quit(1)
		return

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	cpu_marker.gui_input.emit(click)
	await process_frame
	await process_frame

	if game.current_filter != "CPU":
		push_error("Expected overlay click to select CPU filter, got: %s" % game.current_filter)
		quit(1)
		return

	var counts: Dictionary = game.shop_panel.get_visible_type_counts()
	if counts.size() != 1 or int(counts.get("CPU", 0)) <= 0:
		push_error("Expected shop to filter to CPU after overlay click: %s" % JSON.stringify(counts))
		quit(1)
		return

	if game.building_panel._active_slot != "CPU":
		push_error("Expected building panel active slot to be CPU.")
		quit(1)
		return

	var component_database := root.get_node("/root/ComponentDatabase")
	var cpu: Dictionary = component_database.get_components_by_type("CPU")[0]
	game.installed["CPU"] = cpu.duplicate(true)
	game._refresh_all()
	cpu_marker.gui_input.emit(click)
	await process_frame
	await process_frame

	if not game.part_menu.visible:
		push_error("Expected installed overlay click to open part menu.")
		quit(1)
		return

	game.part_menu.id_pressed.emit(0)
	await process_frame
	if not String(game.status_label.text).contains("Part:"):
		push_error("Expected details menu action to update status.")
		quit(1)
		return

	var previous_quantity: int = game.get_inventory_quantity(int(cpu.id))
	game.part_menu.id_pressed.emit(1)
	await process_frame
	await process_frame
	if game.installed.has("CPU"):
		push_error("Expected uninstall menu action to remove installed CPU.")
		quit(1)
		return
	if game.get_inventory_quantity(int(cpu.id)) != previous_quantity + 1:
		push_error("Expected uninstall menu action to return CPU to inventory.")
		quit(1)
		return
	if game.current_filter != "CPU":
		push_error("Expected uninstall to keep CPU replacement filter.")
		quit(1)
		return

	game.part_menu.hide()
	var drag_quantity_before: int = game.get_inventory_quantity(int(cpu.id))
	cpu_marker._drop_data(Vector2.ZERO, {"source": "inventory", "item": cpu})
	await process_frame
	await process_frame
	if not game.installed.has("CPU") or int(game.installed["CPU"].id) != int(cpu.id):
		push_error("Expected dropping CPU on visual motherboard slot to install it.")
		quit(1)
		return
	if game.get_inventory_quantity(int(cpu.id)) != drag_quantity_before - 1:
		push_error("Expected visual slot drop to consume one CPU from inventory.")
		quit(1)
		return

	game._add_to_inventory(cpu)
	var power_marker: Control = game.building_panel._overlay_cards.get("Power")
	power_marker._drop_data(Vector2.ZERO, {"source": "inventory", "item": cpu})
	await process_frame
	await process_frame
	if not String(game.status_label.text).contains("拖拽目标不匹配"):
		push_error("Expected dropping a CPU on the Power slot to report a mismatch.")
		quit(1)
		return

	var ram: Dictionary = component_database.get_components_by_type("RAM")[0]
	game._add_to_inventory(ram)
	var ram_card: Control = game.building_panel._visual_cards.get("RAM")
	ram_card._drop_data(Vector2.ZERO, {"source": "inventory", "item": ram})
	await process_frame
	await process_frame
	if not game.installed.has("RAM") or int(game.installed["RAM"].id) != int(ram.id):
		push_error("Expected dropping RAM on the visual summary card to install it.")
		quit(1)
		return

	print("workbench_overlay=ok")
	print("cpu_count=%d" % int(counts.get("CPU", 0)))
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
