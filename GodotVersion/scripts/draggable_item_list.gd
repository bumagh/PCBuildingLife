class_name DraggableItemList
extends ItemList

func _get_drag_data(at_position: Vector2) -> Variant:
	var index := get_item_at_position(at_position, true)
	if index < 0:
		var selected := get_selected_items()
		if selected.is_empty():
			return null
		index = int(selected[0])
	var item: Dictionary = get_item_metadata(index)
	if item.is_empty():
		return null

	var preview := Label.new()
	preview.text = "%s Lv.%d" % [str(item.name), int(item.tier)]
	preview.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	set_drag_preview(preview)
	return {
		"source": "inventory",
		"item": item,
	}
