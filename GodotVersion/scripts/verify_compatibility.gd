extends SceneTree

func _init() -> void:
	var game := await _create_game()
	var component_database := root.get_node("/root/ComponentDatabase")

	game.installed = {
		"CPU": _component_by_id(component_database, 10002),
		"MotherBoard": _component_by_id(component_database, 10021),
	}
	var platform_issues: Array[String] = game.get_compatibility_issues()
	if not _reasons_contain(platform_issues, "CPU 平台 AM5 与主板平台 LGA1700 不兼容"):
		push_error("Expected CPU/mainboard platform incompatibility, got: %s" % JSON.stringify(platform_issues))
		quit(1)
		return

	game.installed = {
		"CPU": _component_by_id(component_database, 10001),
		"MotherBoard": _component_by_id(component_database, 10021),
		"VideoCard": _component_by_id(component_database, 10011),
		"Power": _component_by_id(component_database, 10055),
	}
	var power_issues: Array[String] = game.get_compatibility_issues()
	if not _reasons_contain(power_issues, "电源功率不足"):
		push_error("Expected power shortage, got: %s" % JSON.stringify(power_issues))
		quit(1)
		return

	game.installed = {
		"VideoCard": _component_by_id(component_database, 10011),
		"Case": _component_by_id(component_database, 10085),
	}
	var case_issues: Array[String] = game.get_compatibility_issues()
	if not _reasons_contain(case_issues, "机箱空间不足"):
		push_error("Expected case capacity issue, got: %s" % JSON.stringify(case_issues))
		quit(1)
		return

	game.new_game()
	_buy_and_install_required(game, component_database, true)
	game._on_finish_pressed()
	if not game.powered_on:
		push_error("Expected qualified build to pass compatibility and power-on test: %s" % JSON.stringify(game.get_compatibility_issues()))
		quit(1)
		return

	print("compatibility_smoke=ok")
	print("platform_issue=%s" % platform_issues[0])
	print("power_issue=%s" % power_issues[0])
	print("case_issue=%s" % case_issues[0])
	print("qualified_powered_on=%s" % str(game.powered_on))
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

func _component_by_id(component_database: Node, item_id: int) -> Dictionary:
	return component_database.components_by_id[item_id].duplicate(true)

func _buy_and_install_required(game: Control, component_database: Node, meets_order: bool) -> int:
	var total_cost := 0
	var order: Dictionary = game.get_current_order()
	var requirements: Dictionary = order.requirements
	var install_order: Array[String] = []
	for slot in game.REQUIRED_SLOTS:
		if slot != "Power":
			install_order.append(slot)
	install_order.append("Power")
	for slot in install_order:
		var min_tier := 0
		if meets_order and requirements.has(slot):
			min_tier = int(requirements[slot])
		var item: Dictionary = _cheapest_compatible_for_slot(component_database, game.installed, slot, min_tier)
		game._on_shop_item_selected(item)
		total_cost += int(item.price)
		game._on_inventory_item_selected(_find_inventory_stack(game.inventory, slot))
	return total_cost

func _cheapest_compatible_for_slot(component_database: Node, installed: Dictionary, slot: String, min_tier: int) -> Dictionary:
	var best: Dictionary = {}
	for item in component_database.get_components_by_type(slot):
		if int(item.tier) < min_tier:
			continue
		if slot == "CPU" and installed.has("MotherBoard"):
			if _cpu_platform(item) != _motherboard_platform(installed["MotherBoard"]):
				continue
		if slot == "MotherBoard" and installed.has("CPU"):
			if _motherboard_platform(item) != _cpu_platform(installed["CPU"]):
				continue
		if slot == "VideoCard" and installed.has("Case"):
			if int(item.tier) >= 90 and int(installed["Case"].tier) < 85:
				continue
			if int(item.tier) >= 80 and int(installed["Case"].tier) < 75:
				continue
		if slot == "Case" and installed.has("VideoCard"):
			if int(installed["VideoCard"].tier) >= 90 and int(item.tier) < 85:
				continue
			if int(installed["VideoCard"].tier) >= 80 and int(item.tier) < 75:
				continue
		if slot == "Power":
			var capacity := _power_capacity(item)
			var required_power := _estimated_power_draw(installed)
			if capacity > 0 and required_power > capacity:
				continue
		if best.is_empty() or int(item.price) < int(best.price):
			best = item
	return best

func _find_inventory_stack(inventory: Array, type_key: String) -> Dictionary:
	for stack in inventory:
		if str(stack.type_key) == type_key:
			return stack
	return {}

func _reasons_contain(reasons: Array, needle: String) -> bool:
	for reason in reasons:
		if str(reason).contains(needle):
			return true
	return false

func _cpu_platform(item: Dictionary) -> String:
	var text := "%s %s" % [str(item.name), str(item.model)]
	if text.contains("Threadripper") or text.contains("TR-"):
		return "sTR5"
	if text.contains("7950") or text.contains("7800") or text.contains("7600"):
		return "AM5"
	if text.contains("5600"):
		return "AM4"
	return "LGA1700"

func _motherboard_platform(item: Dictionary) -> String:
	var text := "%s %s" % [str(item.name), str(item.model)]
	if text.contains("X790"):
		return "sTR5"
	if text.contains("X670") or text.contains("B650"):
		return "AM5"
	if text.contains("A520") or text.contains("B550"):
		return "AM4"
	return "LGA1700"

func _power_capacity(item: Dictionary) -> int:
	var text := "%s %s" % [str(item.name), str(item.model)]
	var regex := RegEx.new()
	regex.compile("(\\d{3,4})W")
	var result := regex.search(text)
	if result == null:
		return 0
	return int(result.get_string(1))

func _estimated_power_draw(installed: Dictionary) -> int:
	var total := 150
	if installed.has("CPU"):
		total += 45 + int(installed["CPU"].tier) * 2
	if installed.has("VideoCard"):
		total += 30 + int(installed["VideoCard"].tier) * 4
	if installed.has("RAM"):
		total += 20
	if installed.has("SSD"):
		total += 10
	if installed.has("M2"):
		total += 10
	if installed.has("HDD"):
		total += 10
	if installed.has("COOLER"):
		total += 15
	return total
