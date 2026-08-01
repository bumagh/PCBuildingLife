extends SceneTree

const SCREENSHOT_PATH := "res://../GodotVersion-pause-menu-check-1280x720.png"

func _init() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/Game.tscn")
	var game: Control = scene.instantiate()
	game.save_path_override = "user://pause_menu_screenshot_save.json"
	root.add_child(game)
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	game._on_pause_menu_pressed()
	await process_frame
	await process_frame

	if not game.pause_panel.visible or game.pause_panel.size.x < 480.0:
		push_error("Expected visible stable pause modal for screenshot.")
		paused = false
		quit(1)
		return

	var image := root.get_texture().get_image()
	if image == null:
		push_error("Pause menu viewport image is not available.")
		paused = false
		quit(1)
		return
	var err := image.save_png(SCREENSHOT_PATH)
	paused = false
	if err != OK:
		push_error("Failed to save pause menu screenshot: %s" % error_string(err))
		quit(1)
		return

	print("pause_menu_screenshot=ok")
	print("path=%s" % ProjectSettings.globalize_path(SCREENSHOT_PATH))
	print("size=%dx%d" % [image.get_width(), image.get_height()])
	quit(0)
