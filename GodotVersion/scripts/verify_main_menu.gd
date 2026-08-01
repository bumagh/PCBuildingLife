extends SceneTree

const SAVE_PATH := "user://verify_main_menu_save.json"
const SETTINGS_PATH := "user://verify_main_menu_settings.cfg"

func _init() -> void:
	_cleanup()
	var fixture := {
		"version": 2,
		"money": 12345,
		"inventory": [{"id": 1, "quantity": 2}, {"id": 2, "quantity": 1}],
		"installed": {"CPU": 1, "MotherBoard": 2, "RAM": 3},
		"powered_on": true,
		"system_booted": true,
		"driver_scan_completed": true,
		"drivers_installed": true,
		"os_restart_required": false,
		"completed_order_ids": ["community_office"],
		"current_order_index": 1,
		"available_order_indices": [1],
	}
	if not _write_save(SAVE_PATH, fixture):
		push_error("Expected temporary main menu save file.")
		quit(1)
		return

	var menu_script := load("res://scripts/main_menu.gd")
	var menu: Control = menu_script.new()
	menu.save_path_override = SAVE_PATH
	root.add_child(menu)
	await process_frame
	await process_frame
	var session := root.get_node("/root/GameSession")

	if menu.continue_button == null or menu.continue_button.disabled:
		push_error("Expected Continue to be enabled when a save exists.")
		quit(1)
		return
	if menu.snapshot_action_button == null or menu.snapshot_action_button.text != "进入当前工作台":
		push_error("Expected a usable save snapshot action.")
		quit(1)
		return
	if menu.snapshot_status_label.text != "存档可用" or menu.snapshot_title_label.text != "继续当前工作台":
		push_error("Expected current save status in the main menu workspace.")
		quit(1)
		return
	if str(menu.snapshot_metric_values.money.text) != "￥12345":
		push_error("Expected saved money in the main menu workspace.")
		quit(1)
		return
	if str(menu.snapshot_metric_values.completed.text) != "1 / 12" or str(menu.snapshot_metric_values.installed.text) != "3 / 9":
		push_error("Expected saved order and installed progress in the main menu workspace.")
		quit(1)
		return
	if str(menu.snapshot_metric_values.system.text) != "驱动已验证" or str(menu.snapshot_metric_values.inventory.text) != "3 件":
		push_error("Expected saved system and inventory state in the main menu workspace.")
		quit(1)
		return
	if not menu.continue_button.has_focus():
		push_error("Expected Continue to receive default keyboard focus.")
		quit(1)
		return
	if menu.settings_panel == null or menu.settings_panel.visible or menu.settings_backdrop.visible:
		push_error("Expected settings panel to start hidden.")
		quit(1)
		return

	menu._on_settings_pressed()
	if not menu.settings_panel.visible or not menu.settings_backdrop.visible:
		push_error("Expected settings panel to open.")
		quit(1)
		return
	menu._on_close_settings_pressed()
	if menu.settings_panel.visible or menu.settings_backdrop.visible:
		push_error("Expected settings panel to close.")
		quit(1)
		return

	menu._on_about_pressed()
	if menu.about_panel == null or not menu.about_panel.visible or not menu.settings_backdrop.visible:
		push_error("Expected production info panel to open.")
		quit(1)
		return
	menu._hide_modals()
	menu._on_quit_pressed()
	if menu.quit_panel == null or not menu.quit_panel.visible or not menu.settings_backdrop.visible:
		push_error("Expected quit confirmation panel to open.")
		quit(1)
		return
	menu._hide_modals()

	session.request_continue()
	if session.consume_launch_mode() != "continue":
		push_error("Expected continue launch mode.")
		quit(1)
		return
	session.request_new_game()
	if session.consume_launch_mode() != "new":
		push_error("Expected new game launch mode.")
		quit(1)
		return

	session.set_fullscreen(true)
	session.set_resolution(2)
	session.set_master_volume(0.35)
	if not session.save_settings(SETTINGS_PATH):
		push_error("Expected settings save to succeed.")
		quit(1)
		return
	session.set_fullscreen(false)
	session.set_resolution(0)
	session.set_master_volume(1.0)
	if not session.load_settings(SETTINGS_PATH):
		push_error("Expected settings load to succeed.")
		quit(1)
		return
	if not session.fullscreen or session.resolution_index != 2 or not is_equal_approx(session.master_volume, 0.35):
		push_error("Expected persisted display and audio settings.")
		quit(1)
		return

	if not _write_save(SAVE_PATH + ".bak", fixture):
		push_error("Expected temporary backup save file.")
		quit(1)
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	menu._refresh_continue_state()
	if menu.continue_button.disabled or menu.continue_button.text != "恢复并继续":
		push_error("Expected backup-only save state to remain recoverable.")
		quit(1)
		return
	menu._on_continue_pressed()
	if not menu.recovery_panel.visible or not menu.recovery_restore_button.visible:
		push_error("Expected backup-only Continue to open the recovery panel.")
		quit(1)
		return
	menu._hide_modals()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + ".bak"))
	menu._refresh_continue_state()
	if not menu.continue_button.disabled:
		push_error("Expected Continue to disable when save is missing.")
		quit(1)
		return
	if menu.snapshot_status_label.text != "新工作台" or menu.snapshot_action_button.text != "创建工作台":
		push_error("Expected a clear new-workshop state when no save exists.")
		quit(1)
		return

	_cleanup()
	print("main_menu=ok")
	print("continue_state=verified")
	print("save_snapshot=verified")
	print("backup_only_recovery=verified")
	print("settings_persistence=verified")
	print("about_and_quit_modals=verified")
	quit(0)

func _cleanup() -> void:
	for path in [SAVE_PATH, SAVE_PATH + ".bak", SETTINGS_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _write_save(path: String, data: Dictionary) -> bool:
	var save := FileAccess.open(path, FileAccess.WRITE)
	if save == null:
		return false
	save.store_string(JSON.stringify(data))
	save.close()
	return true
