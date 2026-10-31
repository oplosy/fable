extends Node2D

@export var arena_scene: PackedScene
@export var fighter_scene: PackedScene
## One character per local player; player N uses the pN_ actions and the Nth spawn point.
@export var characters: Array[CharacterData] = []
## Indexes into `characters` played by the computer; the rest read their keys.
@export var bot_players: Array[int] = []
## Every fighter starts the match with this firearm.
@export var starting_weapon: WeaponData
## Every fighter starts the match with this throwable, as many as its `count`.
@export var starting_throwable: ThrowableData
## A dead player comes back at its spawn point after this long.
@export var respawn_time := 1.5
## After the winning kill the arena runs this long, so the last death plays out.
@export var end_settle_time := 0.8
## The result stays up this long before attack starts a rematch, so mashing cannot skip it.
@export var rematch_delay := 1.0

var arena: Node2D
## Index 0 is player 1.
var players: Array[Fighter] = []
var mode: Deathmatch
var hud: Hud
var _rematch_ready := false


func _ready() -> void:
	KeyBindings.load_saved()
	add_child(SettingsMenu.new())
	if OS.is_debug_build():
		var tuning := TuningPanel.new()
		tuning.source = func() -> FighterClass: return players[0].fighter_class if not players.is_empty() and is_instance_valid(players[0]) else null
		add_child(tuning)
	arena = arena_scene.instantiate()
	add_child(arena)
	players.resize(characters.size())
	mode = Deathmatch.new(characters.size())
	mode.match_ended.connect(_on_match_ended)
	hud = Hud.new()
	add_child(hud)
	hud.setup(mode, _player_names())
	for index in characters.size():
		_spawn_player(index)


# The render size is fixed, so the viewport sends no resize signal; check the window instead.
func _process(_delta: float) -> void:
	_fit_window()
	if _rematch_ready and _attack_pressed():
		_rematch_ready = false
		get_tree().reload_current_scene()


## Whole-pixel scaling while the window holds the full 1920x1080 render; a smaller
## window shrinks it smoothly instead (integer scaling never goes below 1x and would crop).
func _fit_window() -> void:
	var window := get_tree().root
	var fits := window.size.x >= window.content_scale_size.x and window.size.y >= window.content_scale_size.y
	window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if fits else Window.CONTENT_SCALE_STRETCH_FRACTIONAL


func _player_names() -> Array[String]:
	var names: Array[String] = []
	for index in characters.size():
		names.append("Bot" if index in bot_players else "Player %d" % (index + 1))
	return names


func _new_controller(index: int) -> FighterController:
	if index in bot_players:
		return BotController.new()
	var local := LocalController.new()
	local.prefix = "p%d_" % (index + 1)
	return local


func _spawn_player(index: int) -> void:
	var spawned := _spawn_fighter(characters[index], _new_controller(index), index)
	if starting_weapon:
		spawned.inventory.equip_firearm(starting_weapon)
	if starting_throwable:
		spawned.inventory.equip_throwable(starting_throwable, starting_throwable.count)
	spawned.health.died.connect(_on_player_died.bind(spawned, index))
	spawned.died.connect(func(killer: Fighter) -> void: mode.record_kill(index, players.find(killer)))
	players[index] = spawned
	hud.follow(index, spawned)


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
	if mode.is_over():
		return
	dead.queue_free()
	_spawn_player(index)


## Fighters stop at once; the arena freezes a moment later and the result waits for a rematch.
func _on_match_ended(_winner: int) -> void:
	for player in players:
		player.controller = FighterController.new()
		player.add_child(player.controller)
	await get_tree().create_timer(end_settle_time, false).timeout
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(rematch_delay, false).timeout
	_rematch_ready = true


func _attack_pressed() -> bool:
	for index in characters.size():
		if Input.is_action_just_pressed("p%d_attack" % (index + 1)):
			return true
	return false
