extends Node2D

@export var arena_scene: PackedScene
@export var fighter_scene: PackedScene
@export var character: CharacterData
## Temporary until weapon pickups exist; Superfighters starts fighters unarmed.
@export var starting_weapon: WeaponData
## Temporary target for testing combat; spawned idle at the second spawn point.
@export var dummy_character: CharacterData
@export var dummy_respawn_time := 1.5

var arena: Node2D
var fighter: Fighter
var dummy: Fighter


func _ready() -> void:
	arena = arena_scene.instantiate()
	add_child(arena)

	fighter = _spawn_fighter(character, LocalController.new(), 0)
	if starting_weapon:
		fighter.equip_firearm(starting_weapon)

	if dummy_character:
		_spawn_dummy()


func _spawn_fighter(data: CharacterData, controller: FighterController, spawn_index: int) -> Fighter:
	var spawned: Fighter = fighter_scene.instantiate()
	spawned.character = data
	spawned.controller = controller
	# Spawned into the arena so anything the fighter creates (projectiles) lives with the map.
	arena.add_child(spawned)
	spawned.global_position = arena.get_node("SpawnPoints").get_child(spawn_index).global_position
	return spawned


func _spawn_dummy() -> void:
	# No controller: the fighter stands idle.
	dummy = _spawn_fighter(dummy_character, null, 1)
	dummy.health.died.connect(_on_dummy_died.bind(dummy))


func _on_dummy_died(dead: Fighter) -> void:
	await get_tree().create_timer(dummy_respawn_time).timeout
	dead.queue_free()
	_spawn_dummy()
