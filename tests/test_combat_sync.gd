# Run: tests/run_all.sh test_combat_sync
extends "res://tests/test_case.gd"

## Attack clips stay in step with the melee logic: damage lands while the strike is at full
## reach, a punch's fist gets to the end of its hit area, and the target reacts right away.
## Reads the Mucho clips (git-ignored): see tools/import_mucho.gd.

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const MALE := preload("res://data/characters/mucho_male1.tres")
const FEMALE := preload("res://data/characters/mucho_female2.tres")
const KNIFE := preload("res://data/weapons/knife.tres")
const BAT := preload("res://data/weapons/bat.tres")
## How late the full reach may show after a hit lands (s): one frame of the game's 24 fps.
const LATE := 1.0 / 24.0
## How far short of its hit area's end a fist may stop (world px).
const FIST_SHORT := 3.0
## A hand this close to its furthest point counts as at full reach (world px).
const REACH_BAND := 2.0


func run() -> void:
	var fast := MALE.fighter_class
	var heavy := FEMALE.fighter_class
	var punches: Array[MeleeAttack] = fast.melee_combo + heavy.melee_combo.slice(0, 2)
	for character: CharacterData in [MALE, FEMALE]:
		for combo: Array in [fast.melee_combo, heavy.melee_combo, KNIFE.combo, BAT.combo, [fast.air_attack], [heavy.air_attack]]:
			for place in combo.size():
				_check_clip(character, combo[place], place, combo[place] in punches)
	await _check_in_play()


## The clip's full reach is on screen when the hit window opens, or a moment later.
func _check_clip(character: CharacterData, attack: MeleeAttack, place: int, is_punch: bool) -> void:
	var clip := _clip_name(character, attack, place)
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(character.frames_dir.path_join(clip + ".json")))
	var reach := _reach_frames(info.hand_front, character.pixels_per_unit)
	var frame_time: float = 1.0 / info.fps
	var first: float = reach[0] * frame_time
	var last: float = (reach[-1] + 1) * frame_time
	check(first <= attack.windup + LATE and last > attack.windup, "%s: %s reaches out at %.3f-%.3f, its hit opens at %.3f" % [character.display_name, clip, first, last, attack.windup])
	if is_punch:
		var fist: float = (_furthest(info.hand_front) - info.feet[0]) / character.pixels_per_unit
		var end := attack.hitbox_offset.x + attack.hitbox_size.x / 2.0
		check(fist >= end - FIST_SHORT, "%s: %s's fist gets to %.1f of %.1f px" % [character.display_name, clip, fist, end])


func _clip_name(character: CharacterData, attack: MeleeAttack, place: int) -> String:
	var numbered := "%s_%d" % [attack.animation, place + 1]
	return numbered if FileAccess.file_exists(character.frames_dir.path_join(numbered + ".json")) else String(attack.animation)


func _furthest(hands: Array) -> float:
	var furthest := -INF
	for hand: Array in hands:
		furthest = maxf(furthest, hand[0])
	return furthest


## The frames of the first run at full reach.
func _reach_frames(hands: Array, pixels_per_unit: float) -> Array[int]:
	var furthest := _furthest(hands)
	var frames: Array[int] = []
	for i in hands.size():
		if hands[i][0] >= furthest - REACH_BAND * pixels_per_unit:
			frames.append(i)
		elif not frames.is_empty():
			break
	return frames


## A full Fast combo in a real fight: every landed hit shows the reach frame and the target's
## reaction starts on the next physics step.
func _check_in_play() -> void:
	var arena: Node2D = load("res://scenes/arenas/test_arena.tscn").instantiate()
	arena.get_node("ItemSpawns/W1").interval = 9999.0
	root.add_child(arena)
	var attacker := _spawn(arena, MALE, Vector2(200, 328))
	var target := _spawn(arena, FEMALE, Vector2(214, 328))
	await physics_frames(10)
	var attacker_frames: FrameAnimator = attacker.get_node("Visuals/Frames")
	var target_frames: FrameAnimator = target.get_node("Visuals/Frames")
	var landed: Array[Dictionary] = []
	attacker.melee.hit_landed.connect(func(_point: Vector2, heavy: bool) -> void:
		landed.append({"clip": attacker_frames.animation, "frame": attacker_frames.frame, "attack": attacker.melee.current_attack(), "place": attacker.melee.combo_index(), "knocks_down": heavy}))
	var seen := 0
	for tick in 120:
		attacker.controller.attack = tick % 6 == 0
		await physics_frames(1)
		if landed.size() > seen:
			var hit: Dictionary = landed[seen]
			seen = landed.size()
			var clip := _clip_name(MALE, hit.attack, hit.place)
			var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MALE.frames_dir.path_join(clip + ".json")))
			var reach := _reach_frames(info.hand_front, MALE.pixels_per_unit)
			check(hit.clip == StringName(clip), "hit %d plays %s (got %s)" % [seen, clip, hit.clip])
			check(hit.frame + 1 >= reach[0] and hit.frame <= reach[-1], "hit %d lands on %s's reach (frame %d, reach %s)" % [seen, clip, hit.frame, reach])
			await physics_frames(2)
			var reaction := "knockdown_" if hit.knocks_down else "hit_"
			check(String(target_frames.animation).begins_with(reaction), "hit %d shows the target's %s clip (got %s)" % [seen, reaction, target_frames.animation])
		if seen == attacker.character.fighter_class.melee_combo.size():
			break
	attacker.controller.attack = false
	check(seen == attacker.character.fighter_class.melee_combo.size(), "the whole combo lands (%d hits)" % seen)


func _spawn(arena: Node2D, character: CharacterData, at: Vector2) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = character
	arena.add_child(fighter)
	fighter.global_position = at
	return fighter
