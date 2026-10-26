class_name Health
extends Node

signal damaged(amount: int)
signal died

@export var max_health := 100

var current: int


func _ready() -> void:
	current = max_health


func is_dead() -> bool:
	return current <= 0


func take_damage(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	current = maxi(current - amount, 0)
	damaged.emit(amount)
	if is_dead():
		died.emit()
