extends SceneTree

func _init() -> void:
	var game := await _create_game()
	if game.delivery_feedback_panel == null or game.delivery_feedback_title == null:
		push_error("Expected delivery feedback UI to be created.")
		quit(1)
		return
	if game.feedback_sfx_player == null or not (game.feedback_sfx_player.stream is AudioStreamGenerator):
		push_error("Expected generated feedback SFX player.")
		quit(1)
		return

	game._on_deliver_pressed()
	await process_frame
	if not str(game.delivery_feedback_title.text).contains("未通过"):
		push_error("Expected failed delivery to show a pre-delivery check receipt.")
		quit(1)
		return
	if not str(game.delivery_feedback_breakdown.text).contains("待处理"):
		push_error("Expected failed delivery receipt to summarize blockers.")
		quit(1)
		return

	if not game.apply_cheat_complete_driver_flow():
		push_error("Expected cheat driver flow to prepare a deliverable build.")
		quit(1)
		return
	game._on_os_benchmark_pressed()
	game._on_deliver_pressed()
	await process_frame
	var score: Dictionary = game.last_delivery_score
	if score.is_empty() or int(score.get("reward", 0)) <= 0 or str(score.get("order_name", "")).is_empty():
		push_error("Expected delivery score to keep reward and order name.")
		quit(1)
		return
	if not str(game.delivery_feedback_title.text).contains("评分"):
		push_error("Expected successful delivery receipt to show score.")
		quit(1)
		return
	if not str(game.delivery_feedback_detail.text).contains("奖励"):
		push_error("Expected successful delivery receipt to show reward.")
		quit(1)
		return

	print("feedback=ok")
	print("score=%d" % int(score.get("score", 0)))
	print("grade=%s" % str(score.get("grade", "-")))
	print("reward=%d" % int(score.get("reward", 0)))
	quit(0)

func _create_game() -> Control:
	var game_scene := load("res://scenes/Game.tscn")
	var game: Control = game_scene.instantiate()
	root.add_child(game)
	for _frame in range(4):
		await process_frame
	return game
