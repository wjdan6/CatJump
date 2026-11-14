extends ColorRect

signal retry_requested

const RunProgress = preload("res://run_progress.gd")

@export_category("Scoring")
@export_range(1, 1000, 1) var height_per_point: int = 10
@export_range(1, 20000, 1) var height_per_bonus_coin: int = 4000
@export_range(1, 100, 1) var combo_per_bonus_coin: int = 5

@export_category("Shop")
@export_range(1, 1000, 1) var stamina_price: int = 4
@export_range(0, 100, 1) var stamina_bonus: int = 20
@export_range(1, 1000, 1) var air_acceleration_price: int = 7
@export_range(0, 100, 1) var air_acceleration_bonus_percent: int = 15

@onready var content: VBoxContainer = $CenterContainer/GameOverContent
@onready var title: Label = $CenterContainer/GameOverContent/TitleLabel
@onready var retry_button: Button = $CenterContainer/GameOverContent/RetryButton

var progress := RunProgress.new()
var result_label: Label
var balance_label: Label
var status_label: Label
var shop_button: Button
var stamina_button: Button
var air_acceleration_button: Button
var back_button: Button
var save_retry_button: Button
var score: int = 0
var reward: int = 0
var result_recorded: bool = false

func _ready() -> void:
	result_label = _add_label()
	balance_label = _add_label()
	status_label = _add_label()
	shop_button = _add_button("SHOP", _show_shop)
	stamina_button = _add_button("", _buy_upgrade.bind(RunProgress.STAMINA_UPGRADE, stamina_price))
	air_acceleration_button = _add_button("", _buy_upgrade.bind(RunProgress.AIR_ACCELERATION_UPGRADE, air_acceleration_price))
	back_button = _add_button("BACK TO RESULTS", _show_results)
	save_retry_button = _add_button("RETRY SAVE", _record_result)
	content.move_child(retry_button, -1)
	retry_button.pressed.connect(retry_requested.emit)
	hide()

func get_stamina_bonus() -> float:
	return float(stamina_bonus) if progress.owns(RunProgress.STAMINA_UPGRADE) else 0.0

func get_air_acceleration_multiplier() -> float:
	return 1.0 + air_acceleration_bonus_percent / 100.0 if progress.owns(RunProgress.AIR_ACCELERATION_UPGRADE) else 1.0

func show_result(height: float, peak_combo: int, collected_coins: int) -> void:
	if visible:
		return

	score = floori(height / height_per_point)
	var bonus_coins := 0
	if collected_coins > 0:
		bonus_coins = floori(height / height_per_bonus_coin) + floori(float(peak_combo) / combo_per_bonus_coin)
	reward = collected_coins + bonus_coins
	result_label.text = "HEIGHT  %d\nSCORE  %d\nBEST COMBO  %d\nCOLLECTED  %d\nHEIGHT & COMBO BONUS  +%d\nCOINS EARNED  %d" % [
		floori(height), score, peak_combo, collected_coins, bonus_coins, reward,
	]
	show()
	_show_results()
	_record_result()

func _record_result() -> void:
	if result_recorded:
		return

	var error := progress.record_result(score, reward)
	result_recorded = error == OK
	status_label.text = "" if result_recorded else "Could not save this run."
	status_label.visible = not result_recorded
	save_retry_button.visible = not result_recorded
	shop_button.disabled = not result_recorded
	_update_balance()
	if result_recorded:
		retry_button.grab_focus()

func _show_results() -> void:
	title.text = "GAME OVER"
	result_label.show()
	shop_button.show()
	stamina_button.hide()
	air_acceleration_button.hide()
	back_button.hide()
	status_label.hide()
	_update_balance()
	retry_button.grab_focus()

func _show_shop() -> void:
	title.text = "SHOP"
	result_label.hide()
	shop_button.hide()
	stamina_button.show()
	air_acceleration_button.show()
	back_button.show()
	status_label.hide()
	_refresh_shop()
	back_button.grab_focus()

func _buy_upgrade(item: StringName, price: int) -> void:
	var error := progress.purchase(item, price)
	status_label.text = "Purchased. Active next run." if error == OK else "Could not complete the purchase."
	status_label.show()
	_refresh_shop()
	if error == OK:
		back_button.grab_focus()

func _refresh_shop() -> void:
	_update_balance()
	_update_upgrade(stamina_button, "MAX STAMINA +%d" % stamina_bonus, RunProgress.STAMINA_UPGRADE, stamina_price)
	_update_upgrade(air_acceleration_button, "AIR ACCELERATION +%d%%" % air_acceleration_bonus_percent, RunProgress.AIR_ACCELERATION_UPGRADE, air_acceleration_price)

func _update_upgrade(button: Button, item_name: String, item: StringName, price: int) -> void:
	var owned := progress.owns(item)
	button.text = "%s  /  %s" % [item_name, "OWNED" if owned else "%d COINS" % price]
	button.disabled = owned or progress.get_currency() < price

func _update_balance() -> void:
	balance_label.text = "BEST SCORE  %d    |    COINS  %d" % [progress.get_best_score(), progress.get_currency()]

func _add_label() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(label)
	return label

func _add_button(label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = retry_button.custom_minimum_size.y
	button.pressed.connect(action)
	content.add_child(button)
	return button
