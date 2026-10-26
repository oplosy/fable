class_name Projectile
extends Area2D

@export var lifetime := 2.0

var velocity := Vector2.ZERO
var damage := 0
## The fighter that fired it; never hit by its own projectile.
var shooter: Node2D

var _spent := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	# Several bodies can enter in one frame; only the first one counts.
	if _spent or body == shooter:
		return
	_spent = true
	if body.has_method("take_hit"):
		body.take_hit(damage)
	queue_free()
