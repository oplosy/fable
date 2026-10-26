extends Node2D

@export var arena_scene: PackedScene
@export var player_scene: PackedScene

var arena: Node2D
var player: CharacterBody2D


func _ready() -> void:
	arena = arena_scene.instantiate()
	add_child(arena)

	player = player_scene.instantiate()
	# Spawned into the arena so anything the player creates (projectiles) lives with the map.
	arena.add_child(player)
	player.global_position = arena.get_node("SpawnPoints").get_child(0).global_position
