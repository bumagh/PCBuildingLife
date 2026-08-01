extends SceneTree

const OUTPUT_DIR := "res://tmp/ui-checks/main-menu"

func _init() -> void:
	var target_size := _requested_size()
	root.size = target_size
	var save_path := "user://main_menu_screenshot_%dx%d.json" % [target_size.x, target_size.y]
	_cleanup_save(save_path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var scene := load("res://scenes/MainMenu.tscn")
	var menu: Control = scene.instantiate()
	menu.save_path_override = save_path
	root.add_child(menu)
	await _settle_frames(4)

	if not _verify_layout(menu, target_size, "new"):
		return
	var new_path := "%s/main-menu-new-%dx%d.png" % [OUTPUT_DIR, target_size.x, target_size.y]
	if not _capture(new_path, target_size):
		return

	var fixture := {
		"version": 2,
		"money": 4750,
		"inventory": [{"id": 1, "quantity": 4}],
		"installed": {"CPU": 1, "MotherBoard": 2, "RAM": 3, "SSD": 4, "Power": 5},
		"powered_on": true,
		"system_booted": true,
		"driver_scan_completed": true,
		"drivers_installed": true,
		"os_restart_required": false,
		"completed_order_ids": ["community_office"],
		"current_order_index": 1,
		"available_order_indices": [1],
	}
	if not _write_save(save_path, fixture):
		_fail("Failed to write main menu screenshot fixture.")
		return
	menu._refresh_continue_state()
	await _settle_frames(2)
	if not _verify_layout(menu, target_size, "continue"):
		return
	var continue_path := "%s/main-menu-continue-%dx%d.png" % [OUTPUT_DIR, target_size.x, target_size.y]
	if not _capture(continue_path, target_size):
		return

	if target_size == Vector2i(1280, 720):
		if not await _capture_modals(menu, target_size):
			return

	_cleanup_save(save_path)
	print("main_menu_screenshot=ok")
	print("new_path=%s" % ProjectSettings.globalize_path(new_path))
	print("continue_path=%s" % ProjectSettings.globalize_path(continue_path))
	print("size=%dx%d" % [target_size.x, target_size.y])
	quit(0)

func _verify_layout(menu: Control, target_size: Vector2i, expected_state: String) -> bool:
	var workspace := menu.get_node_or_null("SaveWorkspace") as Control
	if workspace == null:
		return _fail("Expected save workspace at %dx%d." % [target_size.x, target_size.y])
	if menu.continue_button == null or menu.continue_button.size.x < 300.0:
		return _fail("Expected stable main menu button width at %dx%d." % [target_size.x, target_size.y])
	if menu.snapshot_action_button == null or menu.snapshot_action_button.size.x < 180.0:
		return _fail("Expected stable save action width at %dx%d." % [target_size.x, target_size.y])
	var workspace_rect := workspace.get_global_rect()
	var action_rect: Rect2 = menu.snapshot_action_button.get_global_rect()
	var continue_rect: Rect2 = menu.continue_button.get_global_rect()
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(target_size))
	if not viewport_rect.encloses(workspace_rect) or not viewport_rect.encloses(action_rect):
		return _fail("Main menu workspace exceeds viewport at %dx%d." % [target_size.x, target_size.y])
	if continue_rect.end.x >= workspace_rect.position.x:
		return _fail("Main menu actions overlap save workspace at %dx%d." % [target_size.x, target_size.y])
	if workspace_rect.size.x < 700.0 or workspace_rect.size.y < 540.0:
		return _fail("Main menu save workspace is too small at %dx%d." % [target_size.x, target_size.y])
	for key in ["money", "order", "completed", "installed", "system", "inventory"]:
		var label: Label = menu.snapshot_metric_values.get(key)
		if label == null or label.text.is_empty() or not viewport_rect.encloses(label.get_global_rect()):
			return _fail("Main menu metric %s is missing or clipped at %dx%d." % [key, target_size.x, target_size.y])
	if expected_state == "new":
		if menu.snapshot_status_label.text != "新工作台" or menu.snapshot_action_button.text != "创建工作台":
			return _fail("Expected new-workshop state at %dx%d." % [target_size.x, target_size.y])
	else:
		if menu.snapshot_status_label.text != "存档可用" or menu.snapshot_action_button.text != "进入当前工作台":
			return _fail("Expected continue-workshop state at %dx%d." % [target_size.x, target_size.y])
	return true

func _capture_modals(menu: Control, target_size: Vector2i) -> bool:
	menu._on_settings_pressed()
	await _settle_frames(2)
	if not menu.settings_panel.visible:
		return _fail("Expected settings modal for screenshot.")
	if not _capture("%s/main-menu-settings-%dx%d.png" % [OUTPUT_DIR, target_size.x, target_size.y], target_size):
		return false

	menu._hide_modals()
	menu._on_about_pressed()
	await _settle_frames(1)
	if not _capture("%s/main-menu-about-%dx%d.png" % [OUTPUT_DIR, target_size.x, target_size.y], target_size):
		return false

	menu._hide_modals()
	menu._on_quit_pressed()
	await _settle_frames(1)
	if not _capture("%s/main-menu-quit-%dx%d.png" % [OUTPUT_DIR, target_size.x, target_size.y], target_size):
		return false
	menu._hide_modals()
	return true

func _capture(path: String, target_size: Vector2i) -> bool:
	var image := root.get_texture().get_image()
	if image == null:
		return _fail("Main menu viewport image is not available.")
	if image.get_size() != target_size:
		image = image.duplicate()
		image.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	var err := image.save_png(path)
	if err != OK:
		return _fail("Failed to save main menu screenshot: %s" % error_string(err))
	return true

func _requested_size() -> Vector2i:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--pcbl-size="):
			continue
		var parts := arg.trim_prefix("--pcbl-size=").split("x")
		if parts.size() == 2:
			return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i(1280, 720)

func _write_save(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true

func _cleanup_save(path: String) -> void:
	for candidate in [path, path + ".bak"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))

func _settle_frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
