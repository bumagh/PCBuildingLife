class_name InstallSlotButton
extends Button

signal item_dropped(slot: String, item: Dictionary)

var slot_key := ""

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if str(data.get("source", "")) != "inventory":
		return false
	var item: Variant = data.get("item", {})
	return typeof(item) == TYPE_DICTIONARY

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	item_dropped.emit(slot_key, data.item)
