extends Node2D

@export var arena_scene: PackedScene
@export var fighter_scene: PackedScene
@export var character: CharacterData
## Temporary until weapon pickups exist; Superfighters starts fighters unarmed.
@export var starting_weapon: WeaponData

var arena: Node2D
var fighter: Fighter


func _ready() -> void:
	arena = arena_scene.instantiate()
	add_child(arena)

	fighter = fighter_scene.instantiate()
	fighter.character = character
	# Spawned into the arena so anything the fighter creates (projectiles) lives with the map.
	arena.add_child(fighter)
	fighter.global_position = arena.get_node("SpawnPoints").get_child(0).global_position
	if starting_weapon:
		fighter.equip(starting_weapon)
