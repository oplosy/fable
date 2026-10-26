# Run: godot --headless --path . -s res://tests/test_health.gd
extends "res://tests/test_case.gd"


func run() -> void:
	var health := Health.new()
	health.max_health = 30
	root.add_child(health)
	await process_frame

	var damage_events: Array[int] = []
	var deaths := [0]
	health.damaged.connect(func(amount: int) -> void: damage_events.append(amount))
	health.died.connect(func() -> void: deaths[0] += 1)

	check(health.current == 30, "starts at max health")
	health.take_damage(10)
	check(health.current == 20 and damage_events == [10], "damage lowers health and emits damaged")
	health.take_damage(0)
	health.take_damage(-5)
	check(health.current == 20 and damage_events.size() == 1, "zero or negative damage is ignored")
	health.take_damage(50)
	check(health.current == 0 and health.is_dead(), "health clamps at zero")
	check(deaths[0] == 1, "died emits once")
	health.take_damage(10)
	check(deaths[0] == 1 and damage_events.size() == 2, "dead health ignores further damage")
