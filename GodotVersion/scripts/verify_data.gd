extends SceneTree

func _init() -> void:
	await process_frame
	await process_frame
	var file := FileAccess.open("res://data/core_components.json", FileAccess.READ)
	if file == null:
		push_error("Cannot open core component data.")
		quit(1)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Core component data is not an array.")
		quit(1)
		return

	var counts := {}
	for raw_item in parsed:
		var raw_type := str(raw_item.get("type", ""))
		counts[raw_type] = int(counts.get(raw_type, 0)) + 1

	var component_database := root.get_node("/root/ComponentDatabase")
	if component_database.get_all_components().is_empty():
		component_database.load_components()
	for item in component_database.get_all_components():
		var specs: Dictionary = item.get("specs", {})
		if not specs.has("power_draw"):
			push_error("Component missing power_draw spec: %s" % item.name)
			quit(1)
			return
		match str(item.type_key):
			"CPU", "MotherBoard":
				if str(specs.get("platform", "")) == "":
					push_error("Component missing platform spec: %s" % item.name)
					quit(1)
					return
			"Power":
				if int(specs.get("capacity_w", 0)) <= 0:
					push_error("Power component missing capacity_w spec: %s" % item.name)
					quit(1)
					return

	print("core_components=%d" % parsed.size())
	print("types=%s" % JSON.stringify(counts))
	print("normalized_components=%d" % component_database.get_all_components().size())
	quit(0)
