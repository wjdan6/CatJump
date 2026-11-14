extends RefCounted

const SAVE_PATH := "user://cat_jump_progress.cfg"
const SECTION := "progress"
const STAMINA_UPGRADE := &"stamina_upgrade"
const AIR_ACCELERATION_UPGRADE := &"air_acceleration_upgrade"

var data := ConfigFile.new()
var load_error: Error = OK
var save_path: String

func _init(path: String = SAVE_PATH) -> void:
	save_path = path
	load_error = data.load(save_path)
	if load_error == ERR_FILE_NOT_FOUND:
		load_error = OK
	elif load_error != OK:
		data.clear()

func get_currency() -> int:
	var value: Variant = data.get_value(SECTION, "currency", 0)
	return maxi(value, 0) if value is int else 0

func get_best_score() -> int:
	var value: Variant = data.get_value(SECTION, "best_score", 0)
	return maxi(value, 0) if value is int else 0

func owns(item: StringName) -> bool:
	var value: Variant = data.get_value(SECTION, item, false)
	return value is bool and value

func record_result(score: int, reward: int) -> Error:
	var best_score := maxi(get_best_score(), score)
	if reward == 0 and best_score == get_best_score():
		return load_error

	var updated := _copy_data()
	updated.set_value(SECTION, "currency", get_currency() + reward)
	updated.set_value(SECTION, "best_score", best_score)
	return _save(updated)

func purchase(item: StringName, price: int) -> Error:
	if owns(item) or get_currency() < price:
		return ERR_UNAVAILABLE

	var updated := _copy_data()
	updated.set_value(SECTION, "currency", get_currency() - price)
	updated.set_value(SECTION, item, true)
	return _save(updated)

func _copy_data() -> ConfigFile:
	var updated := ConfigFile.new()
	updated.parse(data.encode_to_text())
	return updated

func _save(updated: ConfigFile) -> Error:
	if load_error != OK:
		return load_error

	var temporary_path := save_path + ".tmp"
	var error := updated.save(temporary_path)
	if error != OK:
		return error

	error = DirAccess.rename_absolute(temporary_path, save_path)
	if error != OK:
		return error

	data = updated
	return OK
