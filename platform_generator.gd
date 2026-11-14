extends Node2D

const CoinPickup = preload("res://coin_pickup.gd")
const COIN_PATH_START_X_FRACTION: float = 0.1
const COIN_PATH_END_X_FRACTION: float = 0.72
const COIN_PATH_CURVE: float = 0.55

@export_category("References")
@export var platform_scene: PackedScene
@export_node_path("Node2D") var player_path: NodePath = ^"../Player"

@export_category("Generation")
@export var random_seed: int = 0
@export_range(0.0, 20000.0, 100.0) var generation_ahead_distance: float = 5000.0
@export_range(1.0, 1000.0, 1.0) var vertical_gap_min: float = 230.0
@export_range(1.0, 1000.0, 1.0) var vertical_gap_max: float = 290.0
@export var horizontal_min: float = -140.0
@export var horizontal_max: float = 140.0
@export_range(0.0, 1000.0, 1.0) var horizontal_step_min: float = 100.0
@export_range(0.0, 1000.0, 1.0) var horizontal_step_max: float = 220.0

@export_category("Jump Judgment")
@export_range(0.1, 3.0, 0.01) var boost_surface_thickness_ratio: float = 1.0

@export_category("Coins")
@export_range(0.0, 1.0, 0.05) var coin_path_chance: float = 0.30
@export_range(35.0, 150.0, 1.0) var coin_spacing: float = 50.0
@export_range(2, 16, 1) var max_coins_per_path: int = 8
@export_range(26.0, 100.0, 1.0) var coin_path_start_clearance: float = 28.0
@export_range(26.0, 100.0, 1.0) var coin_path_end_clearance: float = 72.0

@export_category("Cleanup")
@export_range(0.0, 20000.0, 100.0) var cleanup_distance: float = 5500.0

var player: Node2D
var random_number_generator := RandomNumberGenerator.new()
var coin_random := RandomNumberGenerator.new()
var previous_gap_has_coins: bool = false
var highest_platform_y: float = 0.0
var last_platform_x: float = 0.0
var generated_platform_count: int = 0
var generated_platforms: Array[Node2D] = []

func _ready() -> void:
	player = get_node_or_null(player_path) as Node2D
	if player == null:
		push_error("PlatformGenerator could not find the player at: %s" % player_path)
		set_process(false)
		return

	if platform_scene == null:
		push_error("PlatformGenerator requires a Platform Scene.")
		set_process(false)
		return

	if random_seed == 0:
		random_number_generator.randomize()
	else:
		random_number_generator.seed = random_seed
	coin_random.seed = random_number_generator.seed ^ 0x434F494E

	if not _prepare_existing_platforms():
		push_error("PlatformGenerator requires at least one node in the boost_platform group.")
		set_process(false)
		return

	_generate_platforms_ahead()

func _process(_delta: float) -> void:
	_generate_platforms_ahead()
	_cleanup_old_platforms()

func _prepare_existing_platforms() -> bool:
	var platforms: Array[Node2D] = []
	for platform_node: Node in get_tree().get_nodes_in_group("boost_platform"):
		var platform := platform_node as Node2D
		if platform != null:
			platforms.append(platform)
	if platforms.is_empty():
		return false

	platforms.sort_custom(func(lower: Node2D, higher: Node2D) -> bool:
		return lower.global_position.y > higher.global_position.y
	)
	for index in range(platforms.size()):
		var platform := platforms[index]
		_fit_boost_surface(platform)
		if index > 0:
			_place_coin_path(platforms[index - 1].global_position, platform)
	var highest := platforms.back() as Node2D
	highest_platform_y = highest.global_position.y
	last_platform_x = highest.global_position.x
	return true

func _generate_platforms_ahead() -> void:
	var target_y := player.global_position.y - maxf(generation_ahead_distance, 0.0)
	while highest_platform_y > target_y:
		if not _spawn_platform():
			break

func _spawn_platform() -> bool:
	var platform := platform_scene.instantiate() as Node2D
	if platform == null:
		push_error("Platform Scene root must inherit Node2D.")
		set_process(false)
		return false

	var previous_position := Vector2(last_platform_x, highest_platform_y)
	var minimum_gap := maxf(minf(vertical_gap_min, vertical_gap_max), 1.0)
	var maximum_gap := maxf(vertical_gap_min, vertical_gap_max)
	highest_platform_y -= random_number_generator.randf_range(minimum_gap, maximum_gap)
	last_platform_x = _get_next_platform_x()

	generated_platform_count += 1
	platform.name = "GeneratedPlatform%d" % generated_platform_count
	platform.add_to_group("generated_platform")
	_fit_boost_surface(platform)
	add_child(platform)
	platform.global_position = Vector2(last_platform_x, highest_platform_y)
	_place_coin_path(previous_position, platform)
	generated_platforms.append(platform)
	return true

func _place_coin_path(lower_position: Vector2, upper_platform: Node2D) -> void:
	if previous_gap_has_coins:
		previous_gap_has_coins = false
		return
	if coin_random.randf() >= coin_path_chance:
		return

	var upper_position := upper_platform.global_position
	var start_y := lower_position.y - coin_path_start_clearance
	var end_y := upper_position.y + coin_path_end_clearance
	if start_y <= end_y:
		return

	var start := Vector2(lerpf(lower_position.x, upper_position.x, COIN_PATH_START_X_FRACTION), start_y)
	var end := Vector2(lerpf(lower_position.x, upper_position.x, COIN_PATH_END_X_FRACTION), end_y)
	# A steeper start follows the cat's faster initial rise after a boost.
	var control := start.lerp(end, 0.5)
	control.x = lerpf(start.x, end.x, (1.0 - COIN_PATH_CURVE) * 0.5)
	var path := Curve2D.new()
	path.add_point(start, Vector2.ZERO, (control - start) * (2.0 / 3.0))
	path.add_point(end, (control - end) * (2.0 / 3.0))
	var length := path.get_baked_length()
	var count := mini(max_coins_per_path, floori(length / coin_spacing) + 1)
	if count < 2:
		return

	previous_gap_has_coins = true
	for index in range(count):
		var distance := length * float(index) / (count - 1)
		var coin := CoinPickup.new()
		coin.name = "CoinPickup%d" % (index + 1)
		coin.position = upper_platform.to_local(path.sample_baked(distance))
		upper_platform.add_child(coin)

func _fit_boost_surface(platform: Node2D) -> void:
	var collision := platform.get_node_or_null("BoostSurface/CollisionShape2D") as CollisionShape2D
	if collision == null or not collision.shape is RectangleShape2D:
		return

	# The current platform scenes use a single polygon for the visible platform body.
	for child in platform.get_children():
		var body := child as Polygon2D
		if body == null or body.polygon.is_empty():
			continue

		var top := INF
		var bottom := -INF
		for point: Vector2 in body.polygon:
			var point_y := (body.transform * (point + body.offset)).y
			top = minf(top, point_y)
			bottom = maxf(bottom, point_y)

		var original := collision.shape as RectangleShape2D
		var thickness := (bottom - top) * boost_surface_thickness_ratio
		if thickness > 0.0 and not is_equal_approx(original.size.y, thickness):
			var adjusted := original.duplicate() as RectangleShape2D
			adjusted.size = Vector2(original.size.x, thickness)
			collision.shape = adjusted
		return

func _get_next_platform_x() -> float:
	var left_limit := minf(horizontal_min, horizontal_max)
	var right_limit := maxf(horizontal_min, horizontal_max)
	var minimum_step := maxf(minf(horizontal_step_min, horizontal_step_max), 0.0)
	var maximum_step := maxf(horizontal_step_min, horizontal_step_max)
	var step := random_number_generator.randf_range(minimum_step, maximum_step)
	var direction := -1.0 if random_number_generator.randi_range(0, 1) == 0 else 1.0
	var next_x := last_platform_x + step * direction

	if next_x < left_limit or next_x > right_limit:
		next_x = last_platform_x - step * direction

	return clampf(next_x, left_limit, right_limit)

func _cleanup_old_platforms() -> void:
	var cleanup_y := player.global_position.y + maxf(cleanup_distance, 0.0)

	for index: int in range(generated_platforms.size() - 1, -1, -1):
		var platform := generated_platforms[index]
		if not is_instance_valid(platform):
			generated_platforms.remove_at(index)
			continue

		if platform.global_position.y > cleanup_y:
			platform.queue_free()
			generated_platforms.remove_at(index)
