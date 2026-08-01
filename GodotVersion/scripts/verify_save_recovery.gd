extends SceneTree

const SAVE_PATH := "user://verify_save_recovery.json"

func _init() -> void:
	_cleanup()
	var game := await _create_game()
	var session := root.get_node("GameSession")
	game.save_path_override = SAVE_PATH
	game.new_game()
	game.money = 12345
	if not game.save_game(SAVE_PATH):
		_fail("Expected first recovery save to succeed.")
		return
	game.money = 11111
	if not game.save_game(SAVE_PATH):
		_fail("Expected second recovery save to create a backup.")
		return
	if not session.is_valid_save_file(session.get_backup_path(SAVE_PATH)):
		_fail("Expected previous valid save backup.")
		return

	var corrupt := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	corrupt.store_string("{broken-json")
	corrupt.close()
	var state: Dictionary = session.inspect_save(SAVE_PATH)
	if not state.corrupt or not state.backup_valid:
		_fail("Expected corrupt primary save with valid backup.")
		return

	var menu_script := load("res://scripts/main_menu.gd")
	var menu: Control = menu_script.new()
	menu.save_path_override = SAVE_PATH
	root.add_child(menu)
	await process_frame
	if menu.continue_button.text != "恢复并继续" or menu.continue_button.disabled:
		_fail("Expected recovery continue state in main menu.")
		return
	menu._on_continue_pressed()
	if not menu.recovery_panel.visible or not menu.recovery_restore_button.visible:
		_fail("Expected recovery prompt with backup action.")
		return
	menu._on_recovery_restore_pressed()
	if not session.is_valid_save_file(SAVE_PATH):
		_fail("Expected valid primary save after backup restore.")
		return

	var loaded_game := await _create_game()
	if not loaded_game.load_game(SAVE_PATH) or loaded_game.money != 12345:
		_fail("Expected restored backup data, got money %d." % loaded_game.money)
		return

	DirAccess.remove_absolute(ProjectSettings.globalize_path(session.get_backup_path(SAVE_PATH)))
	var corrupt_again := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	corrupt_again.store_string("not-json")
	corrupt_again.close()
	state = session.inspect_save(SAVE_PATH)
	menu._show_recovery_modal(state)
	if menu.recovery_restore_button.visible:
		_fail("Expected no restore action without a valid backup.")
		return
	var archive_path: String = session.archive_corrupt_save(SAVE_PATH)
	if archive_path == "" or not FileAccess.file_exists(archive_path):
		_fail("Expected corrupt save to be archived.")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(archive_path))

	_cleanup()
	print("save_recovery=ok")
	print("restored_money=12345")
	print("corrupt_archive=verified")
	quit(0)

func _create_game() -> Control:
	var game_script := load("res://scripts/game.gd")
	var game: Control = game_script.new()
	root.add_child(game)
	for _frame in range(4):
		await process_frame
	return game

func _cleanup() -> void:
	for path in [SAVE_PATH, SAVE_PATH + ".bak", SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _fail(message: String) -> void:
	_cleanup()
	push_error(message)
	quit(1)
