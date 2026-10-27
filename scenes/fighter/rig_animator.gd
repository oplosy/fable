class_name RigAnimator
extends AnimationPlayer

## Plays the shared keyframe clips (docs/CHARACTER_ANIMATION_SPEC.md, section 3.1) on a
## fighter's cutout rig and picks the clip from the fighter's state. Cosmetic only: hits,
## shapes and timings never read it.

const CLIPS_DIR := "res://assets/animations"
## Hip-to-floor length (art px) of the rig the clips were made on. A rig's body offsets
## and movement speeds scale by its own leg length against it, so feet stay planted on
## short and tall characters alike.
const REFERENCE_LEG_LENGTH := 40.0
## Seconds two clips cross-fade when the clip changes.
const BLEND := 0.1
## Seconds to cross-fade into an attack, a flinch or a fall, short so the hit pose lands on time.
const SNAP := 0.03
## Below this horizontal speed (world px/s) a crouched fighter counts as still.
const STILL_SPEED := 5.0
## A stun at least this long (s) gets the heavy flinch.
const HEAVY_STUN := 0.4
## Coat sway: a spring pulls each coat towards the clip's angle (stiffness 1/s², damping
## 1/s, a little under critical so it swings once), and moving trails it behind the body
## (radians per world px/s, up to COAT_MAX_TRAIL).
const COAT_STIFFNESS := 150.0
const COAT_DAMPING := 16.0
const COAT_TRAIL := 0.0015
const COAT_MAX_TRAIL := 0.35
## Cosmetic one-shots that finish while the fighter stands still; any action cuts them.
const SETTLING := ["land", "getup_back", "getup_front"]

var fighter: Fighter
var _rig: CharacterRig
var _leg_scale := 1.0
## Clip name -> its reference_speed (world px/s); 0 for clips that do not follow speed.
var _reference_speeds := {}
var _was_airborne := false
var _last_state := -1
## Set by the fighter's hit_taken, so a new hit restarts the flinch.
var _new_hit := false
## Coat part -> [angle, angular speed] of its sway, in radians, relative to the hips.
var _sway := {}


## Loads every clip in CLIPS_DIR for this rig. Call once both are in the tree.
func setup(target: Fighter, rig: CharacterRig) -> void:
	fighter = target
	fighter.hit_taken.connect(func() -> void: _new_hit = true)
	_rig = rig
	_leg_scale = rig.leg_length() / REFERENCE_LEG_LENGTH
	root_node = get_path_to(rig)
	# Played by hand in _physics_process, so the coats can be fixed after each step.
	callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library := AnimationLibrary.new()
	for file in DirAccess.get_files_at(CLIPS_DIR):
		if file.get_extension() == "json":
			var clip := _load_clip(CLIPS_DIR.path_join(file))
			if clip:
				library.add_animation(file.get_basename(), clip)
	add_animation_library("", library)


func _physics_process(delta: float) -> void:
	_choose_clip()
	advance(delta)
	_swing_coats(delta)
	for coat in _rig.coats:
		coat.deform()


func _choose_clip() -> void:
	var state := fighter.state()
	# A hit in front throws the body back; a hit from behind throws it on its face.
	var fall := "front" if fighter.hit_from_behind else "back"
	var restart := state != _last_state
	var clip := ""
	var blend := SNAP
	match state:
		Fighter.State.DEAD:
			clip = "death_" + fall
		Fighter.State.DOWN:
			clip = "knockdown_" + fall
			if assigned_animation == "lying_" + fall or (assigned_animation == clip and not is_playing()):
				clip = "lying_" + fall
		Fighter.State.STUN:
			clip = _flinch()
			restart = restart or _new_hit
		Fighter.State.ATTACK:
			clip = _attack_clip()
		_:
			restart = false
			blend = BLEND
			clip = _pick()
			if clip == "idle":
				if _last_state == Fighter.State.DOWN:
					clip = "getup_" + fall
				elif _was_airborne and fighter.is_on_floor():
					clip = "land"
				elif current_animation in SETTLING:
					clip = current_animation
	_new_hit = false
	_last_state = state
	_was_airborne = not fighter.is_on_floor()
	if not has_animation(clip):
		clip = "idle"
		if not has_animation(clip):
			return
	var reference: float = _reference_speeds.get(clip, 0.0)
	speed_scale = absf(fighter.velocity.x) / (reference * _leg_scale) if reference > 0.0 else 1.0
	# Finished one-shot clips stay assigned and hold their last pose.
	if clip != assigned_animation:
		play(clip, blend)
	elif restart:
		play(clip)
		seek(0.0, true)


## The flinch for the last hit: in the air, or light or heavy from in front or behind.
func _flinch() -> String:
	if not fighter.is_on_floor():
		return "hit_air"
	var weight := "heavy" if fighter.last_stun >= HEAVY_STUN else "light"
	return "hit_%s_%s" % ["back" if fighter.hit_from_behind else "front", weight]


## The running attack's clip: "<animation>_<place in the combo>" when there is one (three
## jabs alternate fists), else "<animation>".
func _attack_clip() -> String:
	var attack := fighter.melee.current_attack()
	if attack == null or attack.animation == &"":
		return "idle"
	var numbered := "%s_%d" % [attack.animation, fighter.melee.combo_index() + 1]
	return numbered if has_animation(numbered) else String(attack.animation)


## The clip sets where each coat hangs; the coat follows it on a spring, lagging behind
## the body as it moves, so it swings instead of snapping with the legs.
func _swing_coats(delta: float) -> void:
	var trail := clampf(fighter.velocity.x * fighter.facing * COAT_TRAIL, -COAT_MAX_TRAIL, COAT_MAX_TRAIL)
	for coat in _rig.coats:
		var joint: Node2D = coat.get_parent()
		var part := String(joint.name)
		var sway: Array = _sway.get(part, [joint.rotation, 0.0])
		sway[1] += (COAT_STIFFNESS * (joint.rotation + trail - sway[0]) - COAT_DAMPING * sway[1]) * delta
		sway[0] += sway[1] * delta
		_sway[part] = sway
		joint.rotation = sway[0]


## The clip for what the fighter is doing. States without their own clips yet show idle.
func _pick() -> String:
	match fighter.state():
		Fighter.State.WALK:
			return "walk"
		Fighter.State.RUN:
			return "run"
		Fighter.State.AIR:
			return "jump_rise" if fighter.velocity.y < 0.0 else "fall"
	# Crouching also covers aiming and cooking while crouched.
	if fighter.is_crouching():
		return "crouch_walk" if absf(fighter.velocity.x) > STILL_SPEED else "crouch_idle"
	return "idle"


func _load_clip(path: String) -> Animation:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path).trim_prefix(char(0xFEFF)))
	if not data is Dictionary or not data.get("keys") is Array or data.keys.is_empty():
		push_error("%s: not a valid animation file" % path)
		return null
	var clip := Animation.new()
	clip.length = data.get("length", 0.0)
	clip.loop_mode = Animation.LOOP_LINEAR if data.get("loop", false) else Animation.LOOP_NONE
	_reference_speeds[path.get_file().get_basename()] = float(data.get("reference_speed", 0.0))
	# Every part gets a track, so a clip resets what the previous clip turned.
	var root_track := _add_track(clip, "pelvis", "position")
	var angle_tracks := {}
	for part: String in _rig.joints:
		angle_tracks[part] = _add_track(clip, part, "rotation")
	var rest_root: Vector2 = _rig.joints.pelvis.position
	var root := Vector2.ZERO
	var angles := {}
	for key: Dictionary in data.keys:
		var t := float(key.get("t", 0.0))
		if key.has("root"):
			root = CharacterRig._vec(key.root)
		clip.track_insert_key(root_track, t, rest_root + root * _leg_scale)
		for part: String in angle_tracks:
			# A part missing from a key keeps the previous key's angle.
			angles[part] = float(key.get("angles", {}).get(part, angles.get(part, 0.0)))
			clip.track_insert_key(angle_tracks[part], t, deg_to_rad(angles[part]))
	return clip


func _add_track(clip: Animation, part: String, property: String) -> int:
	var track := clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(track, "%s:%s" % [_rig.get_path_to(_rig.joints[part]), property])
	clip.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	return track
