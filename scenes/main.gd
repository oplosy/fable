extends Node2D

@export var arena_scene: PackedScene
@export var fighter_scene: PackedScene
## One character per local player; player N uses the pN_ actions and the Nth spawn point.
@export var characters: Array[CharacterData] = []
## Every fighter starts the match with this firearm.
@export var starting_weapon: WeaponData
## Every fighter starts the match with this throwable, as many as its `count`.
@export var starting_throwable: ThrowableData
## Temporary until rounds exist: a dead player comes back at its spawn point.
@export var respawn_time := 1.5

var arena: Node2D
## Index 0 is player 1.
var players: Array[Fighter] = []


func _ready() -> void:
	KeyBindings.load_saved()
	add_child(SettingsMenu.new())
	arena = arena_scene.instantiate()
	add_child(arena)
	players.resize(characters.size())
	for index in characters.size():
		_spawn_player(index)


func _spawn_player(index: int) -> void:
	var controller := LocalController.new()
	controller.prefix = "p%d_" % (index + 1)
	var spawned := _spawn_fighter(characters[index], controller, index)
	if starting_weapon:
		spawned.equip_firearm(starting_weapon)
	if starting_throwable:
		spawned.equip_throwable(starting_throwable, starting_throwable.count)
	spawned.health.died.connect(_on_player_died.bind(spawned, index))
	players[index] = spawned


func _spawn_fighter(data: CharacterData, controller: FighterController, spawn_index: int) -> Fighter:
	var spawned: Fighter = fighter_scene.instantiate()
	spawned.character = data
	spawned.controller = controller
	# Spawned into the arena so anything the fighter creates (projectiles) lives with the map.
	arena.add_child(spawned)
	spawned.global_position = arena.get_node("SpawnPoints").get_child(spawn_index).global_position
	return spawned


func _on_player_died(dead: Fighter, index: int) -> void:
	# process_always = false: the countdown stops while the game is paused.
	await get_tree().create_timer(respawn_time, false).timeout
	dead.queue_free()
	_spawn_player(index)
