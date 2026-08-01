extends SceneTree

const SAVE_PATH := "user://verify_save_migration.json"

func _init() -> void:
	_cleanup()
	var game := await _create_game()
	var session := root.get_node("GameSession")

	var legacy_save := {
		"money": 32100,
		"inventory": [10001, {"id": 10001, "quantity": 2}],
		"installed": {"CPU": {"id": 10001}},
		"powered_on": true,
		"current_order_index": 1,
		"completed_order_ids": ["community_office"],
	}
	_write_save(legacy_save)
	if not session.is_valid_save_file(SAVE_PATH):
		_fail("Expected unversioned legacy save to be recognized as loadable.")
		return
	if not game.load_game(SAVE_PATH):
		_fail("Expected unversioned legacy save to load.")
		return
	if game.money != 32100:
		_fail("Expected legacy money to load, got %d." % game.money)
		return
	if game.get_inventory_quantity(10001) != 3:
		_fail("Expected legacy inventory stacks to normalize and merge.")
		return
	if not game.installed.has("CPU") or int(game.installed["CPU"].id) != 10001:
		_fail("Expected legacy installed CPU dictionary to migrate.")
		return
	if game.system_booted or game.drivers_installed or game.benchmark_completed:
		_fail("Expected missing software fields to default to incomplete.")
		return
	if not game.available_order_indices.has(1) or game.current_order_index != 1:
		_fail("Expected legacy order availability to derive from completed orders.")
		return
	if not game.last_save_migration_note.contains("legacy_unversioned"):
		_fail("Expected migration note for unversioned legacy save.")
		return

	var v1_save := {
		"version": 1,
		"money": 22222,
		"inventory": [{"id": 10008, "quantity": 1}],
		"installed": {"CPU": 10008},
		"powered_on": false,
		"current_order_index": 3,
		"completed_order_ids": ["community_office"],
	}
	_write_save(v1_save)
	if not game.load_game(SAVE_PATH):
		_fail("Expected v1 save to load.")
		return
	if game.money != 22222 or game.current_order_index != 3:
		_fail("Expected v1 fields and derived current order to load.")
		return
	if not game.available_order_indices.has(3):
		_fail("Expected v1 missing available_order_indices to derive unlocks.")
		return
	if not game.last_save_migration_note.contains("v1_to_v2"):
		_fail("Expected migration note for v1 save.")
		return

	var previous_money: int = game.money
	var previous_order_index: int = game.current_order_index
	var future_save := {
		"version": 999,
		"money": 99999,
		"inventory": [],
		"installed": {},
	}
	_write_save(future_save)
	if session.is_valid_save_file(SAVE_PATH):
		_fail("Expected future save version to be rejected by session validation.")
		return
	if game.load_game(SAVE_PATH, false):
		_fail("Expected future save version to fail loading.")
		return
	if game.money != previous_money or game.current_order_index != previous_order_index:
		_fail("Expected failed future load to preserve existing game state.")
		return
	if not game.last_save_migration_note.contains("unsupported_future_version"):
		_fail("Expected unsupported future version migration note.")
		return

	_write_save(v1_save)
	if not game.load_game(SAVE_PATH):
		_fail("Expected v1 save to reload before upgrade save.")
		return
	if not game.save_game(SAVE_PATH):
		_fail("Expected migrated save to write current format.")
		return
	var upgraded := _read_save()
	if int(upgraded.get("version", 0)) != game.SAVE_VERSION:
		_fail("Expected migrated save to write version %d." % game.SAVE_VERSION)
		return
	if typeof(upgraded.get("available_order_indices", null)) != TYPE_ARRAY:
		_fail("Expected upgraded save to include available_order_indices.")
		return

	_cleanup()
	print("save_migration=ok")
	print("legacy_note=verified")
	print("future_version=rejected")
	quit(0)

func _create_game() -> Control:
	var game_script := load("res://scripts/game.gd")
	var game: Control = game_script.new()
	root.add_child(game)
	for _frame in range(4):
		await process_frame
	return game

func _write_save(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func _read_save() -> Dictionary:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func _cleanup() -> void:
	for path in [SAVE_PATH, SAVE_PATH + ".bak", SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _fail(message: String) -> void:
	_cleanup()
	push_error(message)
	quit(1)
