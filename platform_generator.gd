extends Node2D

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

@export_category("Cleanup")
@export_range(0.0, 20000.0, 100.0) var cleanup_distance: float = 5500.0

var player: Node2D
var random_number_generator := RandomNumberGenerator.new()
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

	if not _find_highest_existing_platform():
		push_error("PlatformGenerator requires at least one node in the boost_platform group.")
		set_process(false)
		return

	_generate_platforms_ahead()

func _process(_delta: float) -> void:
	_generate_platforms_ahead()
	_cleanup_old_platforms()

func _find_highest_existing_platform() -> bool:
	var found_platform := false
	var highest_y := INF

	for platform_node: Node in get_tree().get_nodes_in_group("boost_platform"):
		var platform := platform_node as Node2D
		if platform == null or platform.global_position.y >= highest_y:
			continue

		highest_y = platform.global_position.y
		highest_platform_y = platform.global_position.y
		last_platform_x = platform.global_position.x
		found_platform = true

	return found_platform

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

	var minimum_gap := maxf(minf(vertical_gap_min, vertical_gap_max), 1.0)
	var maximum_gap := maxf(vertical_gap_min, vertical_gap_max)
	highest_platform_y -= random_number_generator.randf_range(minimum_gap, maximum_gap)
	last_platform_x = _get_next_platform_x()

	generated_platform_count += 1
	platform.name = "GeneratedPlatform%d" % generated_platform_count
	platform.add_to_group("generated_platform")
	add_child(platform)
	platform.global_position = Vector2(last_platform_x, highest_platform_y)
	generated_platforms.append(platform)
	return true

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
