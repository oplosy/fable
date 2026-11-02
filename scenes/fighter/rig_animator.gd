class_name RigAnimator
extends AnimationPlayer

## Plays the shared keyframe clips on a fighter's cutout rig and picks the clip from
## the fighter's state. Cosmetic only: hits, shapes and timings never read it.

const CLIPS_DIR := "res://assets/animations"
## Hip-to-floor length (art px) of the reference rig.
const REFERENCE_LEG_LENGTH := 39.0
## Seconds two clips cross-fade when the clip changes.
const BLEND := 0.1
const SNAP := 0.03
const STILL_SPEED := 5.0
const LANDING_ROLL_STATES: Array[Fighter.State] = [Fighter.State.IDLE, Fighter.State.WALK, Fighter.State.RUN, Fighter.State.CROUCH, Fighter.State.AIM]
## Fall or rise speed (world px/s) of the full stretch.
const FULL_STRETCH_SPEED := 450.0
const MAX_STRETCH := 0.1
const MAX_SQUASH := 0.24
## Below this vertical speed (world px/s) the jump shows its top.
const APEX_SPEED := 130.0
## Limbs a clip may stretch along the bone with a key's "stretch".
const STRETCH_PARTS: Array[String] = ["arm_front_upper", "arm_front_lower", "arm_back_upper", "arm_back_lower", "leg_front_upper", "leg_front_lower"]
## Clips drawn to fit a bare-handed attack's whole length.
const STRIKE_CLIPS: Array[String] = ["jab_1", "jab_2", "jab_3", "hook", "jump_kick"]

var fighter: Fighter
var _rig: CharacterRig
var _leg_scale := 1.0
var _rest_scale := Vector2.ONE
var _trail: StrikeTrail
var _reference_speeds := {}
var _last_state := -1
## Seconds left of the roll a dive lands into.
var _landing_roll := 0.0
var _current_clip := ""
var _last_combo_index := -1
var _last_attack_active := false

func setup(target: Fighter, rig: CharacterRig) -> void:
	fighter = target
	_rig = rig
	_rest_scale = rig.scale
	_leg_scale = rig.leg_length() / REFERENCE_LEG_LENGTH
	root_node = get_path_to(rig)
	_trail = StrikeTrail.new()
	target.add_child(_trail)
	callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library := AnimationLibrary.new()
	if DirAccess.dir_exists_absolute(CLIPS_DIR):
		for file in DirAccess.get_files_at(CLIPS_DIR):
			if file.get_extension() == "json":
				var clip := _load_clip(CLIPS_DIR.path_join(file))
				if clip:
					library.add_animation(file.get_basename(), clip)
	add_animation_library("", library)


func _physics_process(delta: float) -> void:
	_choose_clip()
	advance(delta)
	if not is_instance_valid(fighter):
		return
	_stretch()
	_extend_trail()
	fighter.pose_held_items(_rig, fighter.state() == Fighter.State.AIM)


## Stretches the body with its speed in the air and squashes it into the floor on landing.
func _stretch() -> void:
	var amount := 0.0
	if fighter.state() == Fighter.State.AIR:
		amount = minf(absf(fighter.velocity.y) / FULL_STRETCH_SPEED, 1.0) * MAX_STRETCH
	elif fighter._landing_time > 0.0:
		amount = -MAX_SQUASH * fighter._landing_time / Fighter.LANDING_TIME
	_rig.scale = _rest_scale * Vector2(1.0 - amount, 1.0 + amount)


## Wind follows the striking fist or foot.
func _extend_trail() -> void:
	if not fighter.melee.is_striking():
		return
	var tip: Node2D = _rig.hand_anchor
	if _current_clip == "jump_kick":
		tip = _rig.joints.foot_front
	elif _current_clip == "jab_2":
		tip = _rig.joints.hand_back
	if tip:
		_trail.add(tip.global_position)


## An item is aimed standing still, so the legs under it idle or crouch.
func _state_of_legs(state: Fighter.State) -> Fighter.State:
	if state != Fighter.State.AIM:
		return state
	return Fighter.State.CROUCH if fighter.is_crouching() else Fighter.State.IDLE


func _choose_clip() -> void:
	if not is_instance_valid(fighter) or _rig == null:
		return
	var state := _state_of_legs(fighter.state())
	var clip := ""
	var blend := BLEND
	var speed := 1.0
	var is_attack := state == Fighter.State.ATTACK
	# A dive lands into a forward roll; only the picture rolls, the fighter is free to act.
	_landing_roll = maxf(_landing_roll - get_physics_process_delta_time(), 0.0)
	if _last_state == Fighter.State.DIVE and state in LANDING_ROLL_STATES:
		_landing_roll = get_animation("roll").length
	_last_state = state

	# 1. High priority states: Down / Dead / Stun / Invulnerable Getup
	if state == Fighter.State.DEAD or state == Fighter.State.DOWN:
		clip = "down"
		blend = BLEND
	elif fighter.is_on_floor() and fighter._getup_invulnerable > 0.0:
		clip = "getup"
		blend = SNAP
	elif state == Fighter.State.STUN:
		clip = "hit_back" if fighter.hit_from_behind else "hit_front"
		blend = SNAP
	elif state == Fighter.State.ROLL:
		clip = "roll"
		# The turn ends at 0 for the next clip, so it starts a full turn away: never blended.
		blend = 0.0
	elif _landing_roll > 0.0 and state in LANDING_ROLL_STATES:
		clip = "roll"
		blend = 0.0
	elif state == Fighter.State.DIVE:
		clip = "dive"
		blend = SNAP
	elif is_attack:
		blend = SNAP
		if fighter.melee.is_air_attacking():
			clip = "jump_kick"
		elif fighter.melee.item != null:
			var idx := fighter.melee.combo_index()
			var item_name: String = fighter.melee.item.display_name.to_lower()
			if "bat" in item_name or "sopa" in item_name:
				clip = "bat_homerun" if idx == 2 else "bat_swing"
			else:
				clip = "knife_slash" if idx == 2 else "knife_stab"
		else:
			var idx := fighter.melee.combo_index()
			match idx:
				0: clip = "jab_1"
				1: clip = "jab_2"
				2: clip = "jab_3"
				3: clip = "hook"
				_: clip = "jab_1"
	elif fighter._throw_time > 0.0:
		clip = "throw"
		blend = SNAP
	elif state == Fighter.State.COOK:
		clip = "cook"
		blend = SNAP
	elif state == Fighter.State.CLIMB:
		clip = "climb"
		blend = BLEND
		var ref_speed: float = _reference_speeds.get("climb", 75.0)
		speed = absf(fighter.controller.aim) * (fighter.fighter_class.climb_speed / ref_speed) if ref_speed > 0.0 else 1.0
	elif state == Fighter.State.AIR:
		if fighter.melee.is_air_attacking():
			clip = "jump_kick"
			blend = SNAP
		elif fighter.velocity.y < -APEX_SPEED:
			clip = "jump_rise"
			blend = SNAP
		elif fighter.velocity.y > APEX_SPEED:
			clip = "fall"
			blend = BLEND
		else:
			clip = "jump_apex"
			blend = BLEND
	elif fighter._landing_time > 0.0 and fighter.is_on_floor() and fighter.controller.move == 0.0:
		clip = "land"
		blend = SNAP
	elif state == Fighter.State.CROUCH:
		blend = BLEND
		if fighter.controller.move != 0.0:
			clip = "crouch_walk"
			var ref_speed: float = _reference_speeds.get("crouch_walk", 60.0)
			speed = absf(fighter.velocity.x) / (ref_speed * _leg_scale) if ref_speed > 0.0 else 1.0
		else:
			clip = "crouch_idle"
	elif state == Fighter.State.WALK:
		clip = "walk"
		blend = BLEND
		var ref_speed: float = _reference_speeds.get("walk", 120.0)
		speed = absf(fighter.velocity.x) / (ref_speed * _leg_scale) if ref_speed > 0.0 else 1.0
	elif state == Fighter.State.RUN:
		clip = "run"
		blend = BLEND
		var ref_speed: float = _reference_speeds.get("run", 200.0)
		speed = absf(fighter.velocity.x) / (ref_speed * _leg_scale) if ref_speed > 0.0 else 1.0
	elif state == Fighter.State.IDLE:
		clip = "aim_idle" if fighter.state() == Fighter.State.AIM else "idle"
		blend = BLEND

	if clip in STRIKE_CLIPS and has_animation(clip):
		speed = get_animation(clip).length / fighter.melee.current_attack().duration()
	if clip == "dive":
		speed = get_animation(clip).length / fighter.fighter_class.air_time(fighter.fighter_class.dive_velocity.y)

	if clip != "":
		if has_animation(clip):
			speed_scale = speed
			var combo_idx := fighter.melee.combo_index() if is_attack else -1
			var action_changed := clip != _current_clip or (is_attack and (combo_idx != _last_combo_index or not _last_attack_active))
			
			if action_changed:
				play(clip, blend)
				_current_clip = clip
				_last_combo_index = combo_idx
			elif not is_playing():
				var anim := get_animation(clip)
				if anim and anim.loop_mode != Animation.LOOP_NONE:
					play(clip, blend)
			_last_attack_active = is_attack
		return

	_last_attack_active = false
	_last_combo_index = -1
	_current_clip = ""
	if is_playing():
		stop()
		_rig.reset_pose()


func _load_clip(path: String) -> Animation:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path).trim_prefix(char(0xFEFF)))
	if not data is Dictionary or not data.get("keys") is Array or data.keys.is_empty():
		return null
	var clip := Animation.new()
	clip.length = data.get("length", 0.0)
	clip.loop_mode = Animation.LOOP_LINEAR if data.get("loop", false) else Animation.LOOP_NONE
	_reference_speeds[path.get_file().get_basename()] = float(data.get("reference_speed", 0.0))
	
	var root_track := _add_track(clip, "pelvis", "position")
	var angle_tracks := {}
	for part: String in _rig.joints:
		angle_tracks[part] = _add_track(clip, part, "rotation")
	var stretch_tracks := {}
	for part in STRETCH_PARTS:
		stretch_tracks[part] = _add_track(clip, part, "scale")
	var stretches := {}
		
	# Strikes snap between far-apart keys, where a cubic curve would overshoot wildly.
	if data.get("linear", false):
		for track in clip.get_track_count():
			clip.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)

	var rest_root: Vector2 = _rig.joints.pelvis.position
	var root := Vector2.ZERO
	var angles := {}
	
	for key: Dictionary in data.keys:
		var t := float(key.get("t", 0.0))
		if key.has("root"):
			root = CharacterRig._vec(key.root)
		clip.track_insert_key(root_track, t, rest_root + root * _leg_scale)
		for part: String in angle_tracks:
			angles[part] = float(key.get("angles", {}).get(part, angles.get(part, 0.0)))
			clip.track_insert_key(angle_tracks[part], t, deg_to_rad(angles[part]))
		for part: String in stretch_tracks:
			stretches[part] = float(key.get("stretch", {}).get(part, stretches.get(part, 1.0)))
			clip.track_insert_key(stretch_tracks[part], t, Vector2(1.0, stretches[part]))
	return clip


func _add_track(clip: Animation, part: String, property: String) -> int:
	var track := clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(track, "%s:%s" % [_rig.get_path_to(_rig.joints[part]), property])
	clip.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	return track
