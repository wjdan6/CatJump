extends Area2D

const Player = preload("res://player.gd")
const RADIUS: float = 15.0

var collected: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	var collider := CollisionShape2D.new()
	collider.shape = circle
	add_child(collider)
	body_entered.connect(_on_body_entered)

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(0.26, 0.14, 0.04), true, -1.0, true)
	draw_circle(Vector2.ZERO, RADIUS - 2.5, Color(1.0, 0.75, 0.14), true, -1.0, true)
	draw_line(Vector2(0.0, -6.0), Vector2(0.0, 6.0), Color(0.62, 0.33, 0.07), 3.0, true)

func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if collected or player == null or not player.collect_coin():
		return

	collected = true
	hide()
	queue_free()
