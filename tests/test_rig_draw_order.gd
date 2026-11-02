# Run: tests/run_all.sh test_rig_draw_order
extends "res://tests/test_case.gd"

## A rig character draws over the map (z 0), with held items over the body and the
## crosshair and hit sparks over both.

const CROSSHAIR_Z := 20


func run() -> void:
	var fighter: Fighter = preload("res://scenes/fighter/fighter.tscn").instantiate()
	fighter.character = load("res://data/characters/ronin.tres")
	root.add_child(fighter)
	await physics_frames(2)
	fighter.inventory.equip_firearm(load("res://data/weapons/pistol.tres"))
	await physics_frames(2)
	var parts := fighter.get_node("Visuals/Rig").find_children("*", "Sprite2D", true, false)
	var lowest := 1000
	var highest := -1000
	for part: Sprite2D in parts:
		var z := _drawn_z(part)
		lowest = mini(lowest, z)
		highest = maxi(highest, z)
	check(lowest >= 0, "every rig part draws over the map (lowest z %d)" % lowest)
	var gun: Node2D = fighter.inventory.firearm
	check(_drawn_z(gun) > highest, "a held item draws over the body")
	check(CROSSHAIR_Z > _drawn_z(gun), "the crosshair and sparks draw over held items")
	fighter.free()


## The z a node ends up at, adding every relative parent.
func _drawn_z(node: CanvasItem) -> int:
	var z := 0
	var at: Node = node
	while at is CanvasItem:
		z += at.z_index
		at = at.get_parent()
	return z
