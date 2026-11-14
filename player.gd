extends CharacterBody2D

const RunResults = preload("res://run_results.gd")

enum JumpJudgment {
	PERFECT,
	GOOD,
}

@export var move_speed: float = 480.0
@export var jump_power: float = 1000.0
@export var rise_gravity: float = 1300.0
@export var fall_gravity: float = 1500.0
@export var max_fall_speed: float = 1500.0

@export_category("Acceleration Jump")
@export var perfect_jump_power: float = 1250.0
@export var good_jump_power: float = 1050.0
@export var perfect_side_impulse: float = 240.0
@export var good_side_impulse: float = 145.0
@export var max_air_speed: float = 3000.0
@export var air_acceleration: float = 4200.0
@export var air_deceleration: float = 500.0

@export_category("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_regen_per_second: float = 5.0
@export var boost_stamina_cost: float = 10.0
@export var fall_speed_stamina_cost: float = 0.01
@export var perfect_stamina_recovery: float = 15.0

@export_category("Judgment Feedback")
@export var judgment_feedback_duration: float = 0.45
@export var judgment_feedback_scale: float = 1.25

@export_category("Animation")
@export var apex_velocity_threshold: float = 80.0
@export var jump_prepare_animation_duration: float = 0.08
@export var boost_animation_duration: float = 0.18
@export var miss_animation_duration: float = 0.2
@export var landing_animation_duration: float = 0.12

@export_category("Combo")
@export var max_combo_count: int = 10
@export var max_combo_acceleration: float = 10.0
@export var perfect_combo_acceleration_gain: float = 1.0
@export var good_combo_acceleration_gain: float = 0.5
@export var jump_power_per_combo_acceleration: float = 50.0
@export var side_impulse_per_combo_acceleration: float = 16.0
@export var move_speed_per_combo_acceleration: float = 32.0

@export_category("Camera")
@export_range(0.0, 0.95, 0.05) var camera_fall_follow_ratio: float = 0.70

@onready var perfect_jump_area: Area2D = $PerfectJumpArea
@onready var good_jump_area: Area2D = $GoodJumpArea
@onready var miss_jump_area: Area2D = $MissJumpArea
@onready var stamina_bar: ProgressBar = $"../StaminaUI/StaminaBar"
@onready var stamina_value_label: Label = $"../StaminaUI/StaminaValueLabel"
@onready var combo_label: Label = $"../StaminaUI/ComboLabel"
@onready var velocity_label: Label = $"../StaminaUI/VelocityLabel"
@onready var coin_label: Label = $"../StaminaUI/CoinLabel"
@onready var judgment_label: Label = $"../StaminaUI/JudgmentLabel"
@onready var player_sprite: AnimatedSprite2D = $Sprite2D
@onready var run_results: RunResults = $"../StaminaUI/GameOverOverlay"
@onready var camera: Camera2D = $Camera2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var body_shape: CapsuleShape2D = body_collision.shape as CapsuleShape2D

var used_boost_surfaces: Array[Area2D] = []
var current_stamina: float = 0.0
var combo_count: int = 0
var combo_acceleration: float = 0.0
var judgment_feedback_tween: Tween
var animation_lock_remaining: float = 0.0
var run_started: bool = false
var is_game_over: bool = false
var start_height_y: float = 0.0
var highest_reached_y: float = 0.0
var peak_combo_count: int = 0
var collected_coins: int = 0
var camera_vertical_offset: float = 0.0

func _ready() -> void:
	max_stamina += run_results.get_stamina_bonus()
	air_acceleration *= run_results.get_air_acceleration_multiplier()
	current_stamina = max_stamina
	_update_stamina_ui()
	_update_combo_ui()
	_update_velocity_ui()
	_play_player_animation(&"idle")
	run_results.retry_requested.connect(restart_game)
	camera_vertical_offset = camera.position.y
	var initial_camera_position := camera.global_position
	camera.top_level = true
	camera.global_position = initial_camera_position
	_update_camera(global_position.y)

func _physics_process(delta: float) -> void:
	if is_game_over:
		return

	var was_on_floor_before_move := is_on_floor()
	var input_dir := Input.get_axis("move_left", "move_right")

	_update_horizontal_movement(input_dir, delta)  #수평이동업데이트

	# 중력 처리 (상승,하강 분리)
	if not is_on_floor():
		var current_gravity := fall_gravity if velocity.y >= 0.0 else rise_gravity
		velocity.y = minf(velocity.y + current_gravity * delta, max_fall_speed)

	_update_stamina(delta)
	_clear_exited_boost_surfaces()

	# 점프 입력 처리
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			normal_jump()
		else:
			try_boost_jump(input_dir)

	var previous_y := global_position.y
	move_and_slide()
	_keep_player_in_view_horizontally()
	_update_game_over_state(global_position.y - previous_y)
	_update_player_animation(delta, was_on_floor_before_move)
	_update_velocity_ui()

func normal_jump() -> void:
	if not run_started:
		run_started = true
		start_height_y = global_position.y
		highest_reached_y = global_position.y

	reset_combo()
	velocity.y = -jump_power
	_play_locked_animation(&"jump_prepare", jump_prepare_animation_duration)

func _update_horizontal_movement(input_dir: float, delta: float) -> void:
	if not run_started:
		velocity.x = 0.0
		return

	var combo_move_speed := get_combo_move_speed()
	if is_on_floor():  #바닥
		velocity.x = input_dir * combo_move_speed
		return
	#공중
	var target_speed := input_dir * combo_move_speed
	var acceleration := air_acceleration if input_dir != 0.0 else air_deceleration
	velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
	velocity.x = clampf(velocity.x, -max_air_speed, max_air_speed)

func get_combo_move_speed() -> float:
	return move_speed + combo_acceleration * move_speed_per_combo_acceleration

func collect_coin() -> bool:
	if not run_started or is_game_over:
		return false

	collected_coins += 1
	coin_label.text = "COINS %d" % collected_coins
	return true

func _update_stamina(delta: float) -> void:
	current_stamina = clampf(current_stamina, 0.0, max_stamina)
	current_stamina = minf(current_stamina + stamina_regen_per_second * delta, max_stamina)
	_update_stamina_ui()

func _update_stamina_ui() -> void:
	stamina_bar.max_value = max_stamina
	stamina_bar.value = current_stamina
	stamina_value_label.text = "%d / %d" % [roundi(current_stamina), roundi(max_stamina)]

func try_boost_jump(input_dir: float) -> void:
	var perfect_surface := get_boost_surface(perfect_jump_area)
	if perfect_surface != null:
		attempt_boost_jump(perfect_surface, input_dir, JumpJudgment.PERFECT)
		return

	var good_surface := get_boost_surface(good_jump_area)
	if good_surface != null:
		attempt_boost_jump(good_surface, input_dir, JumpJudgment.GOOD)
		return

	var miss_surface := get_boost_surface(miss_jump_area)
	if miss_surface != null:
		miss_boost_jump(miss_surface)

func get_boost_surface(check_area: Area2D) -> Area2D:
	for overlapping_area: Area2D in check_area.get_overlapping_areas():
		if overlapping_area.name != "BoostSurface":
			continue

		if not overlapping_area.get_parent().is_in_group("boost_platform"):
			continue

		if used_boost_surfaces.has(overlapping_area):
			continue

		return overlapping_area

	return null

func attempt_boost_jump(surface: Area2D, input_dir: float, judgment: int) -> void:
	var stamina_cost := get_boost_stamina_cost()
	if current_stamina < stamina_cost:
		miss_boost_jump(surface, "스태미너 부족")
		return

	var consumed_stamina := consume_stamina(stamina_cost)
	var recovered_stamina := 0.0
	if judgment == JumpJudgment.PERFECT:
		recovered_stamina = recover_stamina(perfect_stamina_recovery)
	increase_combo(judgment)
	show_judgment_feedback(judgment)
	boost_jump(surface, input_dir, judgment)
	print("스태미너 소모: ", snappedf(consumed_stamina, 0.1), " | 회복: ", snappedf(recovered_stamina, 0.1), " | 남음: ", snappedf(current_stamina, 0.1))

func get_boost_stamina_cost() -> float:
	var fall_speed := maxf(velocity.y, 0.0)
	return boost_stamina_cost + fall_speed * fall_speed_stamina_cost

func consume_stamina(stamina_cost: float) -> float:
	var consumed_stamina := minf(current_stamina, maxf(stamina_cost, 0.0))
	current_stamina -= consumed_stamina
	_update_stamina_ui()
	return consumed_stamina

func recover_stamina(stamina_recovery: float) -> float:
	var previous_stamina := current_stamina
	current_stamina = minf(current_stamina + maxf(stamina_recovery, 0.0), max_stamina)
	_update_stamina_ui()
	return current_stamina - previous_stamina

func increase_combo(judgment: int) -> void:
	combo_count = min(combo_count + 1, max_combo_count)
	peak_combo_count = maxi(peak_combo_count, combo_count)
	var acceleration_gain := perfect_combo_acceleration_gain if judgment == JumpJudgment.PERFECT else good_combo_acceleration_gain
	combo_acceleration = minf(combo_acceleration + acceleration_gain, max_combo_acceleration)
	_update_combo_ui()

func reset_combo() -> void:
	combo_count = 0
	combo_acceleration = 0.0
	_update_combo_ui()

func _update_combo_ui() -> void:
	combo_label.text = "COMBO %d" % combo_count

func _update_velocity_ui() -> void:
	velocity_label.text = "X: %d | Y: %d" % [roundi(velocity.x), roundi(velocity.y)]

func _update_player_animation(delta: float, was_on_floor_before_move: bool) -> void:
	if is_on_floor() and not was_on_floor_before_move:
		_play_locked_animation(&"land", landing_animation_duration)
		return

	if animation_lock_remaining > 0.0:
		animation_lock_remaining = maxf(animation_lock_remaining - delta, 0.0)
		return

	if is_on_floor():
		_play_player_animation(&"idle")
	elif absf(velocity.y) <= apex_velocity_threshold:
		_play_player_animation(&"apex")
	elif velocity.y < 0.0:
		_play_player_animation(&"rise")
	else:
		_play_player_animation(&"fall")

func _play_locked_animation(animation_name: StringName, duration: float) -> void:
	animation_lock_remaining = maxf(duration, 0.0)
	_play_player_animation(animation_name)

func _play_player_animation(animation_name: StringName) -> void:
	if player_sprite.animation != animation_name or not player_sprite.is_playing():
		player_sprite.play(animation_name)

func show_judgment_feedback(judgment: int) -> void:
	if judgment == JumpJudgment.PERFECT:
		_show_judgment_feedback("PERFECT", Color(1.0, 0.84, 0.2, 1.0))
	else:
		_show_judgment_feedback("GOOD", Color(0.25, 0.85, 1.0, 1.0))

func show_miss_feedback(reason: String) -> void:
	var feedback_text := "MISS" if reason.is_empty() else "MISS - NO STAMINA"
	_show_judgment_feedback(feedback_text, Color(1.0, 0.35, 0.35, 1.0))

func _show_judgment_feedback(feedback_text: String, feedback_color: Color) -> void:
	if judgment_feedback_tween != null and judgment_feedback_tween.is_valid():
		judgment_feedback_tween.kill()

	judgment_label.text = feedback_text
	judgment_label.modulate = feedback_color
	judgment_label.scale = Vector2.ONE * judgment_feedback_scale
	judgment_label.pivot_offset = judgment_label.size * 0.5
	judgment_label.show()

	judgment_feedback_tween = create_tween()
	judgment_feedback_tween.tween_property(judgment_label, "scale", Vector2.ONE, judgment_feedback_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	judgment_feedback_tween.parallel().tween_property(judgment_label, "modulate:a", 0.0, judgment_feedback_duration * 0.7).set_delay(judgment_feedback_duration * 0.3)

func boost_jump(surface: Area2D, input_dir: float, judgment: int) -> void:
	var target_platform := surface.get_parent() as Node2D
	if target_platform == null:
		return

	used_boost_surfaces.append(surface)

	velocity.y = -get_jump_power(judgment)
	if input_dir != 0.0:
		velocity.x += input_dir * get_side_impulse(judgment)
		velocity.x = clampf(velocity.x, -max_air_speed, max_air_speed)
	_play_locked_animation(&"boost", boost_animation_duration)

	print(
		get_judgment_name(judgment),
		" 가속점프 발동! 대상: ", target_platform.name,
		" | 콤보: ", combo_count,
		" | 가속: ", snappedf(combo_acceleration, 0.1),
		" | 속도: (", snappedf(velocity.x, 0.1), ", ", snappedf(velocity.y, 0.1), ")"
	)

func get_jump_power(judgment: int) -> float:
	var base_jump_power := perfect_jump_power if judgment == JumpJudgment.PERFECT else good_jump_power
	return base_jump_power + combo_acceleration * jump_power_per_combo_acceleration

func get_side_impulse(judgment: int) -> float:
	var base_side_impulse := perfect_side_impulse if judgment == JumpJudgment.PERFECT else good_side_impulse
	return base_side_impulse + combo_acceleration * side_impulse_per_combo_acceleration

func get_judgment_name(judgment: int) -> String:
	return "Perfect" if judgment == JumpJudgment.PERFECT else "Good"

func miss_boost_jump(surface: Area2D, reason: String = "") -> void:
	var target_platform := surface.get_parent() as Node2D
	if target_platform == null:
		return

	used_boost_surfaces.append(surface)
	reset_combo()
	var consumed_stamina := consume_stamina(get_boost_stamina_cost())
	show_miss_feedback(reason)
	_play_locked_animation(&"miss", miss_animation_duration)
	if reason.is_empty():
		print("Miss 판정! 대상: ", target_platform.name, " | 스태미너 소모: ", snappedf(consumed_stamina, 0.1))
	else:
		print("Miss 판정! 대상: ", target_platform.name, " | ", reason, " | 스태미너 소모: ", snappedf(consumed_stamina, 0.1))

func _clear_exited_boost_surfaces() -> void:
	for index: int in range(used_boost_surfaces.size() - 1, -1, -1):
		var surface := used_boost_surfaces[index]
		if not is_instance_valid(surface) or not is_surface_in_jump_areas(surface):
			used_boost_surfaces.remove_at(index)

func is_surface_in_jump_areas(surface: Area2D) -> bool:
	return perfect_jump_area.get_overlapping_areas().has(surface) or good_jump_area.get_overlapping_areas().has(surface) or miss_jump_area.get_overlapping_areas().has(surface)

func _update_game_over_state(vertical_travel: float) -> void:
	if not run_started:
		_update_camera(global_position.y)
		return

	highest_reached_y = minf(highest_reached_y, global_position.y)
	var follow_y := camera.global_position.y - camera_vertical_offset
	# Let the cat regain the camera's height before scrolling upward again.
	follow_y += maxf(vertical_travel, 0.0) * camera_fall_follow_ratio
	_update_camera(minf(follow_y, global_position.y))

	if is_on_floor() or (velocity.y > 0.0 and _is_below_viewport()):
		trigger_game_over()

func _update_camera(follow_y: float) -> void:
	camera.global_position.y = follow_y + camera_vertical_offset
	camera.force_update_scroll()

func _keep_player_in_view_horizontally() -> void:
	var view_half_width := get_viewport_rect().size.x / (2.0 * camera.zoom.x)
	var travel_limit := maxf(view_half_width - body_shape.radius, 0.0)
	var camera_x := camera.get_screen_center_position().x
	var bounded_x := clampf(global_position.x, camera_x - travel_limit, camera_x + travel_limit)
	if bounded_x != global_position.x:
		global_position.x = bounded_x
		velocity.x = 0.0

func _is_below_viewport() -> bool:
	var body_top := body_collision.get_global_transform_with_canvas() * Vector2(0.0, -body_shape.height * 0.5)
	return body_top.y >= get_viewport_rect().end.y

func trigger_game_over() -> void:
	if is_game_over:
		return

	is_game_over = true
	velocity = Vector2.ZERO
	reset_combo()
	run_results.show_result(start_height_y - highest_reached_y, peak_combo_count, collected_coins)

func restart_game() -> void:
	get_tree().reload_current_scene()
