extends Node

const DATA_PATH := "res://data/core_components.json"

var components: Array = []
var components_by_id: Dictionary = {}
var components_by_type: Dictionary = {}

func _ready() -> void:
	load_components()

func load_components() -> void:
	components.clear()
	components_by_id.clear()
	components_by_type.clear()

	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot open component data: %s" % DATA_PATH)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Component data is not a JSON array.")
		return

	for raw_item in parsed:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var item := _normalize_item(raw_item)
		components.append(item)
		components_by_id[item.id] = item
		if not components_by_type.has(item.type_key):
			components_by_type[item.type_key] = []
		components_by_type[item.type_key].append(item)

func get_all_components() -> Array:
	return components

func get_components_by_type(type_key: String) -> Array:
	return components_by_type.get(normalize_type(type_key), [])

func normalize_type(type_name: String) -> String:
	var value := type_name.strip_edges()
	match value:
		"主板":
			return "MotherBoard"
		"电源":
			return "Power"
		"机箱":
			return "Case"
		"散热器":
			return "COOLER"
		"M.2":
			return "M2"
		"GPU":
			return "VideoCard"
		_:
			return value

func display_type(type_key: String) -> String:
	match normalize_type(type_key):
		"MotherBoard":
			return "主板"
		"Power":
			return "电源"
		"Case":
			return "机箱"
		"COOLER":
			return "散热器"
		"M2":
			return "M.2"
		"VideoCard":
			return "GPU"
		_:
			return type_key

func _normalize_item(raw_item: Dictionary) -> Dictionary:
	var raw_type := str(raw_item.get("type", ""))
	var id_value := int(raw_item.get("id", 0))
	var item := {
		"id": id_value,
		"id_text": str(raw_item.get("idText", "")),
		"type": raw_type,
		"type_key": normalize_type(raw_type),
		"name": str(raw_item.get("name", "未命名配件")),
		"describe": str(raw_item.get("describe", "")),
		"model": str(raw_item.get("model", "")),
		"quality": str(raw_item.get("quality", "")),
		"price": int(raw_item.get("price", 0)),
		"tier": int(raw_item.get("tier", 0)),
		"size": str(raw_item.get("size", "")),
	}
	item.specs = _build_specs(item)
	return item

func _build_specs(item: Dictionary) -> Dictionary:
	var type_key := str(item.type_key)
	var tier := int(item.tier)
	var specs := {
		"power_draw": _default_power_draw(type_key, tier),
	}
	match type_key:
		"CPU":
			specs.platform = _cpu_platform(item)
		"MotherBoard":
			specs.platform = _motherboard_platform(item)
		"Power":
			specs.capacity_w = _power_capacity(item)
		"Case":
			specs.max_gpu_tier = _case_max_gpu_tier(tier)
		"VideoCard":
			specs.required_case_tier = _gpu_required_case_tier(tier)
	return specs

func _default_power_draw(type_key: String, tier: int) -> int:
	match type_key:
		"CPU":
			return 45 + tier * 2
		"VideoCard":
			return 30 + tier * 4
		"RAM":
			return 20
		"SSD", "M2", "HDD":
			return 10
		"COOLER":
			return 15
		_:
			return 0

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

func _gpu_required_case_tier(gpu_tier: int) -> int:
	if gpu_tier >= 90:
		return 85
	if gpu_tier >= 80:
		return 75
	return 0

func _case_max_gpu_tier(case_tier: int) -> int:
	if case_tier >= 85:
		return 100
	if case_tier >= 75:
		return 89
	return 79
