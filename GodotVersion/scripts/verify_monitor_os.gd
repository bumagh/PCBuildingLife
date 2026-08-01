extends SceneTree

func _init() -> void:
	var game := await _create_game()

	if not game.apply_cheat_fill_current_order():
		push_error("Expected test build to be prepared.")
		quit(1)
		return

	if not game.apply_cheat_open_monitor():
		push_error("Expected monitor overlay to open after boot cheat.")
		quit(1)
		return

	if game.monitor_overlay == null or not game.monitor_overlay.visible:
		push_error("Expected monitor overlay to be visible.")
		quit(1)
		return
	if game.monitor_task_board_label == null or not str(game.monitor_task_board_label.text).contains("OS 任务板"):
		push_error("Expected monitor task board.")
		quit(1)
		return
	if not str(game.monitor_task_board_label.text).contains("Driver Tool 扫描设备"):
		push_error("Expected monitor task board to show the next driver scan action.")
		quit(1)
		return
	if game.monitor_content_label == null or not str(game.monitor_content_label.text).contains("Desktop apps"):
		push_error("Expected monitor desktop content.")
		quit(1)
		return

	game._on_os_system_info_pressed()
	if game.monitor_app_key != "System Info":
		push_error("Expected System Info app, got %s." % game.monitor_app_key)
		quit(1)
		return
	if not str(game.monitor_content_label.text).contains("Installed hardware"):
		push_error("Expected installed hardware text in monitor.")
		quit(1)
		return

	game._on_os_benchmark_pressed()
	if game.monitor_app_key != "Benchmark":
		push_error("Expected Benchmark app, got %s." % game.monitor_app_key)
		quit(1)
		return
	if not str(game.monitor_content_label.text).contains("Synthetic score"):
		push_error("Expected benchmark text in monitor.")
		quit(1)
		return

	game._on_monitor_driver_tool_pressed()
	if game.monitor_app_key != "Driver Tool":
		push_error("Expected Driver Tool app, got %s." % game.monitor_app_key)
		quit(1)
		return
	if not str(game.monitor_content_label.text).contains("Not scanned"):
		push_error("Expected Driver Tool to start unscanned.")
		quit(1)
		return
	game._on_driver_scan_pressed()
	if not game.driver_scan_completed:
		push_error("Expected driver scan to complete.")
		quit(1)
		return
	if not str(game.monitor_task_board_label.text).contains("安装基础驱动"):
		push_error("Expected monitor task board to advance to driver installation.")
		quit(1)
		return
	if not str(game.monitor_content_label.text).contains("Ready to install"):
		push_error("Expected Driver Tool to be ready to install.")
		quit(1)
		return
	game._on_driver_install_pressed()
	if not game.drivers_installed or not game.os_restart_required:
		push_error("Expected driver install to require restart.")
		quit(1)
		return
	if not str(game.monitor_content_label.text).contains("Restart required"):
		push_error("Expected restart required content.")
		quit(1)
		return
	game._on_driver_restart_pressed()
	if not game.drivers_installed or game.os_restart_required:
		push_error("Expected driver restart to verify install.")
		quit(1)
		return
	if not str(game.monitor_content_label.text).contains("Verified"):
		push_error("Expected verified driver content.")
		quit(1)
		return

	game._on_monitor_files_pressed()
	if game.monitor_app_key != "Files":
		push_error("Expected Files app, got %s." % game.monitor_app_key)
		quit(1)
		return
	if game.monitor_file_key != "order" or not str(game.monitor_content_label.text).contains("[current_order.txt]"):
		push_error("Expected Files app to open the current order report.")
		quit(1)
		return
	game._on_file_driver_pressed()
	if game.monitor_file_key != "driver" or not str(game.monitor_content_label.text).contains("[device_report.sys]"):
		push_error("Expected Files app to switch to the driver report.")
		quit(1)
		return
	game._on_file_benchmark_pressed()
	if game.monitor_file_key != "benchmark" or not str(game.monitor_content_label.text).contains("[latest_score.log]"):
		push_error("Expected Files app to switch to the benchmark report.")
		quit(1)
		return
	game._on_file_preflight_pressed()
	if game.monitor_file_key != "preflight" or not str(game.monitor_content_label.text).contains("[preflight_report.txt]"):
		push_error("Expected Files app to switch to the preflight report.")
		quit(1)
		return
	if game.file_preflight_button == null or not game.file_preflight_button.visible:
		push_error("Expected Files report buttons to be visible.")
		quit(1)
		return

	game._on_close_monitor_pressed()
	if game.monitor_overlay.visible:
		push_error("Expected monitor overlay to close.")
		quit(1)
		return

	game._on_open_monitor_pressed()
	game._on_os_shutdown_pressed()
	if game.system_booted:
		push_error("Expected shutdown to clear booted state.")
		quit(1)
		return
	if not str(game.monitor_content_label.text).contains("No signal"):
		push_error("Expected no signal monitor content after shutdown.")
		quit(1)
		return

	print("monitor_os=ok")
	print("content_chars=%d" % str(game.monitor_content_label.text).length())
	quit(0)

func _create_game() -> Control:
	var game_script := load("res://scripts/game.gd")
	var game: Control = game_script.new()
	root.add_child(game)
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	return game
