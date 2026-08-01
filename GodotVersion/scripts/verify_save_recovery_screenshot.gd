extends SceneTree

const SAVE_PATH := "user://verify_recovery_screenshot.json"
const SCREENSHOT_PATH := "res://../GodotVersion-save-recovery-check-1280x720.png"

func _init() -> void:
	root.size = Vector2i(1280, 720)
	_cleanup()
	var valid_data := {"version": 1, "money": 18000, "inventory": [], "installed": {}}
	var backup := FileAccess.open(SAVE_PATH + ".bak", FileAccess.WRITE)
	backup.store_string(JSON.stringify(valid_data))
	backup.close()
	var corrupt := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	corrupt.store_string("{damaged")
	corrupt.close()

	var scene := load("res://scenes/MainMenu.tscn")
	var menu: Control = scene.instantiate()
	menu.save_path_override = SAVE_PATH
	root.add_child(menu)
	for _frame in range(4):
		await process_frame
	menu._on_continue_pressed()
	await process_frame
	if not menu.recovery_panel.visible or not menu.recovery_restore_button.visible:
		push_error("Expected visible save recovery modal for screenshot.")
		_cleanup()
		quit(1)
		return
	var image := root.get_texture().get_image()
	if image.save_png(SCREENSHOT_PATH) != OK:
		push_error("Failed to save recovery screenshot.")
		_cleanup()
		quit(1)
		return
	_cleanup()
	print("save_recovery_screenshot=ok")
	print("path=%s" % ProjectSettings.globalize_path(SCREENSHOT_PATH))
	print("size=%dx%d" % [image.get_width(), image.get_height()])
	quit(0)

func _cleanup() -> void:
	for path in [SAVE_PATH, SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
