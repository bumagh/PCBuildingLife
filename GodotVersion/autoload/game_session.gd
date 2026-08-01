extends Node

const SAVE_PATH := "user://save_game.json"
const SETTINGS_PATH := "user://settings.cfg"
const SAVE_BACKUP_SUFFIX := ".bak"
const CURRENT_SAVE_VERSION := 2
const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1920, 1080),
]

var launch_mode := ""
var fullscreen := false
var resolution_index := 0
var master_volume := 0.8

func _ready() -> void:
	load_settings()
	apply_settings()

func request_continue() -> void:
	launch_mode = "continue"

func request_new_game() -> void:
	launch_mode = "new"

func consume_launch_mode() -> String:
	var mode := launch_mode
	launch_mode = ""
	return mode

func has_save(path: String = SAVE_PATH) -> bool:
	var state := inspect_save(path)
	return bool(state.valid) or bool(state.backup_valid)

func inspect_save(path: String = SAVE_PATH) -> Dictionary:
	var exists := FileAccess.file_exists(path)
	var valid := is_valid_save_file(path) if exists else false
	var backup_path := get_backup_path(path)
	var backup_exists := FileAccess.file_exists(backup_path)
	var backup_valid := is_valid_save_file(backup_path) if backup_exists else false
	return {
		"path": path,
		"exists": exists,
		"valid": valid,
		"corrupt": exists and not valid,
		"backup_path": backup_path,
		"backup_exists": backup_exists,
		"backup_valid": backup_valid,
	}

func is_valid_save_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return false
	return is_valid_save_data(json.data)

func is_valid_save_data(data: Variant) -> bool:
	return is_supported_save_data(data)

func is_supported_save_data(data: Variant, current_version: int = CURRENT_SAVE_VERSION) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var save_data: Dictionary = data
	if save_data.has("version"):
		var version := int(save_data.get("version", 0))
		if version < 1 or version > current_version:
			return false
	elif not _has_legacy_save_shape(save_data):
		return false
	if not save_data.has("money") or typeof(save_data.money) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	if typeof(save_data.get("inventory", null)) != TYPE_ARRAY:
		return false
	if typeof(save_data.get("installed", null)) != TYPE_DICTIONARY:
		return false
	return true

func _has_legacy_save_shape(save_data: Dictionary) -> bool:
	return save_data.has("money") and save_data.has("inventory") and save_data.has("installed")

func get_backup_path(path: String = SAVE_PATH) -> String:
	return path + SAVE_BACKUP_SUFFIX

func create_save_backup(path: String = SAVE_PATH) -> bool:
	if not is_valid_save_file(path):
		return false
	var backup_path := get_backup_path(path)
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_absolute)
	return DirAccess.copy_absolute(ProjectSettings.globalize_path(path), backup_absolute) == OK

func restore_save_backup(path: String = SAVE_PATH) -> bool:
	var backup_path := get_backup_path(path)
	if not is_valid_save_file(backup_path):
		return false
	if FileAccess.file_exists(path):
		archive_corrupt_save(path)
	return DirAccess.copy_absolute(ProjectSettings.globalize_path(backup_path), ProjectSettings.globalize_path(path)) == OK

func archive_corrupt_save(path: String = SAVE_PATH) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-")
	var archive_path := "%s.corrupt-%s" % [path, stamp]
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(archive_path)) != OK:
		return ""
	return archive_path

func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled

func set_resolution(index: int) -> void:
	resolution_index = clampi(index, 0, RESOLUTIONS.size() - 1)

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)

func save_settings(path: String = SETTINGS_PATH) -> bool:
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "resolution_index", resolution_index)
	config.set_value("audio", "master_volume", master_volume)
	return config.save(path) == OK

func load_settings(path: String = SETTINGS_PATH) -> bool:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return false
	fullscreen = bool(config.get_value("display", "fullscreen", false))
	resolution_index = clampi(int(config.get_value("display", "resolution_index", 0)), 0, RESOLUTIONS.size() - 1)
	master_volume = clampf(float(config.get_value("audio", "master_volume", 0.8)), 0.0, 1.0)
	return true

func apply_settings() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(master_volume, 0.0001)))
		AudioServer.set_bus_mute(master_bus, master_volume <= 0.001)
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(RESOLUTIONS[resolution_index])
