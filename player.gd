extends CharacterBody2D

@export var move_speed: float = 240.0
@export var jump_power: float = 1000.0
@export var gravity: float = 1200.0

@export var boost_jump_power: float = 720.0
@export var boost_side_power: float = 220.0

@onready var boost_check_area: Area2D = $BoostCheckArea

var nearby_boost_platforms: Array[Node2D] = []
var used_boost_platforms: Array[Node2D] = []

func _ready() -> void:
	boost_check_area.body_entered.connect(_on_boost_check_area_body_entered)
	boost_check_area.body_exited.connect(_on_boost_check_area_body_exited)

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_axis("move_left", "move_right")

	# 좌우 이동
	velocity.x = input_dir * move_speed

	# 중력
	if not is_on_floor():
		velocity.y += gravity * delta

	# 점프 입력 처리
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			normal_jump()
		elif can_boost_jump():
			boost_jump(input_dir)

	move_and_slide()

func normal_jump() -> void:
	velocity.y = -jump_power

func boost_jump(input_dir: float) -> void:
	var target_platform := get_available_boost_platform()

	if target_platform == null:
		return

	used_boost_platforms.append(target_platform)

	# 위로 강하게 튀기
	velocity.y = -boost_jump_power

	# 방향키를 누르고 있으면 그 방향으로도 가속
	if input_dir != 0:
		velocity.x = input_dir * boost_side_power

	print("가속점프 발동! 대상: ", target_platform.name)

func get_available_boost_platform() -> Node2D:
	for platform in nearby_boost_platforms:
		if not used_boost_platforms.has(platform):
			return platform

	return null

func can_boost_jump() -> bool:
	return get_available_boost_platform() != null

func _on_boost_check_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("boost_platform"):
		if not nearby_boost_platforms.has(body):
			nearby_boost_platforms.append(body)

		print("가속점프 가능: ", body.name)

func _on_boost_check_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("boost_platform"):
		nearby_boost_platforms.erase(body)
		used_boost_platforms.erase(body)

		print("가속점프 범위 벗어남: ", body.name)
