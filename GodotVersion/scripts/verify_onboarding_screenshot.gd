extends SceneTree

const SCREENSHOT_PATH := "res://../GodotVersion-onboarding-check-1280x720.png"

func _init() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/Game.tscn")
	var game: Control = scene.instantiate()
	root.add_child(game)
	for _frame in range(4):
		await process_frame
	game.new_game()
	game._on_tutorial_action_pressed()
	game._on_tutorial_action_pressed()
	await process_frame
	await process_frame
	if game.tutorial_step != 2 or game.main_tabs.current_tab != 1:
		push_error("Expected guided shop state for screenshot.")
		quit(1)
		return
	var image := root.get_texture().get_image()
	if image.save_png(SCREENSHOT_PATH) != OK:
		push_error("Failed to save onboarding screenshot.")
		quit(1)
		return
	print("onboarding_screenshot=ok")
	print("path=%s" % ProjectSettings.globalize_path(SCREENSHOT_PATH))
	print("size=%dx%d" % [image.get_width(), image.get_height()])
	quit(0)
