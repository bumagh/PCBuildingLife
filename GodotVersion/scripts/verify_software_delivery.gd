extends SceneTree

func _init() -> void:
	var game := await _create_game()
	if not game.apply_cheat_fill_current_order():
		push_error("Expected compatible order build for software delivery test.")
		quit(1)
		return
	game.apply_cheat_boot_pass()

	_assert_software_state(game, 40, false, "scan devices")
	game._on_monitor_driver_tool_pressed()
	game._on_driver_scan_pressed()
	_assert_software_state(game, 65, false, "install drivers")
	game._on_driver_install_pressed()
	_assert_software_state(game, 80, false, "restart OS")
	game._on_driver_restart_pressed()
	_assert_software_state(game, 100, true, "")

	var result: Dictionary = game.deliver_order()
	if not bool(result.get("ok", false)):
		push_error("Expected verified software setup to allow delivery: %s" % JSON.stringify(result))
		quit(1)
		return
	if int(result.get("score", {}).get("software", 0)) != 100:
		push_error("Expected delivery result to include software score 100.")
		quit(1)
		return

	print("software_delivery=ok")
	print("software_score=%d" % int(result.score.software))
	print("delivery_score=%d" % int(result.score.score))
	quit(0)

func _assert_software_state(game: Control, expected_score: int, complete: bool, reason_text: String) -> void:
	var score: int = int(game.get_software_configuration_score())
	if score != expected_score:
		push_error("Expected software score %d, got %d." % [expected_score, score])
		quit(1)
		return
	if game.is_software_configuration_complete() != complete:
		push_error("Unexpected software completion state for score %d." % expected_score)
		quit(1)
		return
	if complete:
		return
	var result: Dictionary = game.deliver_order()
	if bool(result.get("ok", false)):
		push_error("Expected delivery block at software score %d." % expected_score)
		quit(1)
		return
	if not _reasons_contain(result.get("reasons", []), reason_text):
		push_error("Expected delivery reason containing '%s': %s" % [reason_text, JSON.stringify(result)])
		quit(1)

func _reasons_contain(reasons: Array, needle: String) -> bool:
	for reason in reasons:
		if str(reason).contains(needle):
			return true
	return false

func _create_game() -> Control:
	var game_script := load("res://scripts/game.gd")
	var game: Control = game_script.new()
	root.add_child(game)
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	return game
