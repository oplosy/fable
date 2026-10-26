class_name Projectile
extends Area2D

@export var lifetime := 2.0

var velocity := Vector2.ZERO
# Carried for the upcoming health/damage milestone.
var damage := 0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(_body: Node2D) -> void:
	queue_free()
