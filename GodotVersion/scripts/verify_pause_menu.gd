extends SceneTree

const SAVE_PATH := "user://verify_pause_menu_save.json"

func _init() -> void:
	_cleanup()
	var game_script := load("res://scripts/game.gd")
	var game: Control = game_script.new()
	game.save_path_override = SAVE_PATH
	root.add_child(game)
	await process_frame
	await process_frame
	await process_frame
	await process_frame

	if game.pause_panel == null or game.pause_panel.visible:
		push_error("Expected pause panel to start hidden.")
		quit(1)
		return

	game._on_pause_menu_pressed()
	if not paused or not game.pause_panel.visible or not game.pause_backdrop.visible:
		push_error("Expected pause menu to pause the tree and show modal UI.")
		quit(1)
		return

	game._on_pause_save_pressed()
	if not FileAccess.file_exists(SAVE_PATH):
		push_error("Expected pause menu save to create a save file.")
		quit(1)
		return
	if not str(game.pause_status_label.text).contains("已保存"):
		push_error("Expected pause menu save confirmation.")
		quit(1)
		return

	game._on_resume_game_pressed()
	if paused or game.pause_panel.visible or game.pause_backdrop.visible:
		push_error("Expected resume to unpause and hide the modal.")
		quit(1)
		return

	_cleanup()
	print("pause_menu=ok")
	print("pause_save=verified")
	quit(0)

func _cleanup() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
