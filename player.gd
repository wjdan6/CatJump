extends CharacterBody2D

@export var move_speed: float = 240.0
@export var jump_power: float = 1000.0
@export var gravity: float = 1200.0

@export var boost_jump_power: float = 720.0
@export var boost_side_power: float = 220.0

@onready var perfect_jump_area: Area2D = $PerfectJumpArea
@onready var good_jump_area: Area2D = $GoodJumpArea

var used_boost_surfaces: Array[Area2D] = []

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_axis("move_left", "move_right")

	# 좌우 이동
	velocity.x = input_dir * move_speed

	# 중력
	if not is_on_floor():
		velocity.y += gravity * delta

	_clear_exited_boost_surfaces()

	# 점프 입력 처리
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			normal_jump()
		else:
			try_boost_jump(input_dir)

	move_and_slide()

func normal_jump() -> void:
	velocity.y = -jump_power

func try_boost_jump(input_dir: float) -> void:
	var perfect_surface := get_boost_surface(perfect_jump_area)
	if perfect_surface != null:
		boost_jump(perfect_surface, input_dir, "Perfect")
		return

	var good_surface := get_boost_surface(good_jump_area)
	if good_surface != null:
		boost_jump(good_surface, input_dir, "Good")

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

func boost_jump(surface: Area2D, input_dir: float, judgment: String) -> void:
	var target_platform := surface.get_parent() as Node2D
	if target_platform == null:
		return

	used_boost_surfaces.append(surface)

	# 이후 단계에서 Perfect와 Good에 서로 다른 힘을 적용한다.
	velocity.y = -boost_jump_power

	if input_dir != 0.0:
		velocity.x = input_dir * boost_side_power

	print(judgment, " 가속점프 발동! 대상: ", target_platform.name)

func _clear_exited_boost_surfaces() -> void:
	for index: int in range(used_boost_surfaces.size() - 1, -1, -1):
		var surface := used_boost_surfaces[index]
		if not is_instance_valid(surface) or not is_surface_in_jump_areas(surface):
			used_boost_surfaces.remove_at(index)

func is_surface_in_jump_areas(surface: Area2D) -> bool:
	return perfect_jump_area.get_overlapping_areas().has(surface) or good_jump_area.get_overlapping_areas().has(surface)
