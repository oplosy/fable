class_name FrameAnimator
extends AnimatedSprite2D

## Plays a character's frame-by-frame animations (one strip and one .json per clip in
## CharacterData.frames_dir, from tools/make_stickman.gd) and picks the clip from the
## fighter's state. Cosmetic only: hits, shapes and timings never read it.

## Below this horizontal speed (world px/s) a crouched fighter counts as still.
const STILL_SPEED := 5.0
## A stun at least this long (s) gets the heavy flinch.
const HEAVY_STUN := 0.4
## Still poses for holding a firearm or throwable, from straight up to straight down.
const AIM_STEPS := 9
## One-shots that finish on their own after the move that started them; any action cuts them.
const SETTLING := ["land", "getup_back", "getup_front"]

var fighter: Fighter
## On the front fist, turned along the forearm, so a held melee item follows the hand.
var hand_anchor := Node2D.new()
## The untinted white wind of attack clips (<clip>_fx), drawn behind the body frame by frame.
var fx := AnimatedSprite2D.new()
var _pixels_per_unit := 3.0
var _feet := Vector2.ZERO
## Clip -> its reference_speed (world px/s at 1x); 0 for clips that do not follow speed.
var _reference_speeds := {}
## Clip -> [[x, y, forearm degrees], ...] of the front hand per frame, in art px.
var _hands := {}
var _last_state := -1
var _was_airborne := false
var _was_diving := false
var _new_hit := false


## Loads every clip in `dir` and starts following `target`. Returns false (and loads
## nothing) when the folder has no clips.
func setup(target: Fighter, dir: String, pixels_per_unit: float) -> bool:
	fighter = target
	_pixels_per_unit = pixels_per_unit
	var library := SpriteFrames.new()
	library.remove_animation(&"default")
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() != "json":
			continue
		var clip := file.get_basename()
		var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(file)))
		var strip := load(dir.path_join(clip + ".png")) as Texture2D
		if not info is Dictionary or strip == null:
			push_error("%s: broken frame clip %s" % [dir, clip])
			continue
		var size := Vector2(info.size[0], info.size[1])
		_feet = Vector2(info.feet[0], info.feet[1])
		library.add_animation(clip)
		library.set_animation_loop(clip, info.loop)
		library.set_animation_speed(clip, info.fps)
		for i in int(info.frames):
			var frame := AtlasTexture.new()
			frame.atlas = strip
			frame.region = Rect2(Vector2(size.x * i, 0), size)
			library.add_frame(clip, frame)
		var wind := dir.path_join(clip + "_fx.png")
		if ResourceLoader.exists(wind):
			var wind_strip := load(wind) as Texture2D
			library.add_animation(clip + "_fx")
			library.set_animation_loop(clip + "_fx", info.loop)
			library.set_animation_speed(clip + "_fx", info.fps)
			for i in int(info.frames):
				var frame := AtlasTexture.new()
				frame.atlas = wind_strip
				frame.region = Rect2(Vector2(size.x * i, 0), size)
				library.add_frame(clip + "_fx", frame)
		_reference_speeds[clip] = float(info.get("reference_speed", 0.0))
		_hands[clip] = info.hand_front
	if library.get_animation_names().is_empty():
		return false
	sprite_frames = library
	centered = false
	offset = -_feet
	scale = Vector2.ONE / pixels_per_unit
	fx.sprite_frames = library
	fx.centered = false
	fx.offset = offset
	fx.show_behind_parent = true
	add_child(fx)
	# The body's frame advances in its own processing, after physics; follow it there.
	frame_changed.connect(_show_wind)
	animation_changed.connect(_show_wind)
	fighter.hit_taken.connect(func() -> void: _new_hit = true)
	return true


func _physics_process(_delta: float) -> void:
	_choose_clip()
	_place_hand()


func _choose_clip() -> void:
	var state := fighter.state()
	# A hit in front throws the body back; a hit from behind throws it on its face.
	var fall := "front" if fighter.hit_from_behind else "back"
	var restart := state != _last_state
	var clip := ""
	var rate := 1.0
	match state:
		Fighter.State.DEAD:
			clip = "death_" + fall
		Fighter.State.DOWN:
			clip = "knockdown_" + fall
			if animation == "lying_" + fall or (animation == clip and not is_playing()):
				clip = "lying_" + fall
		Fighter.State.STUN:
			clip = _flinch()
			restart = restart or _new_hit
		Fighter.State.ATTACK:
			clip = _attack_clip()
		Fighter.State.DIVE:
			clip = "dive"
		Fighter.State.ROLL:
			clip = "roll"
		Fighter.State.CLIMB:
			clip = "climb"
			rate = absf(fighter.controller.aim)
		Fighter.State.AIM, Fighter.State.COOK:
			var step := roundi(remap(fighter.aim_angle, -PI / 2.0, PI / 2.0, 0.0, AIM_STEPS - 1))
			clip = "%s_aim_%d" % ["crouch" if fighter.is_crouching() else "stand", step]
			restart = false
		_:
			restart = false
			clip = _pick()
			# A dive lands into a roll, whether the fighter stops or keeps running.
			if fighter.is_on_floor() and (_was_diving or (animation == &"dive_roll" and is_playing())):
				clip = "dive_roll"
			elif clip == "idle":
				if _last_state == Fighter.State.DOWN:
					clip = "getup_" + fall
				elif _was_airborne and fighter.is_on_floor():
					clip = "land"
				elif animation in SETTLING and is_playing():
					clip = animation
	_new_hit = false
	_last_state = state
	_was_airborne = not fighter.is_on_floor()
	_was_diving = state == Fighter.State.DIVE
	if not sprite_frames.has_animation(clip):
		clip = "idle"
	var reference: float = _reference_speeds.get(clip, 0.0)
	if reference > 0.0 and clip != "climb":
		rate = absf(fighter.velocity.x) / reference
	speed_scale = rate
	# Finished one-shots stay on their last frame.
	if clip != animation or restart:
		play(clip)
		frame = 0


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
	return numbered if sprite_frames.has_animation(numbered) else String(attack.animation)


## The clip for moving about. Crouching also covers cooking while crouched.
func _pick() -> String:
	match fighter.state():
		Fighter.State.WALK:
			return "walk"
		Fighter.State.RUN:
			return "run"
		Fighter.State.AIR:
			return "jump_rise" if fighter.velocity.y < 0.0 else "fall"
	if fighter.is_crouching():
		return "crouch_walk" if absf(fighter.velocity.x) > STILL_SPEED else "crouch_idle"
	return "idle"


## Shows this frame's wind when the clip has any. Self_modulate tints only the body, so
## the wind stays white.
func _show_wind() -> void:
	var wind := String(animation) + "_fx"
	fx.visible = sprite_frames.has_animation(wind)
	if fx.visible:
		fx.animation = wind
		fx.frame = frame


## Puts the hand anchor on this frame's front fist, along the forearm, at world scale.
func _place_hand() -> void:
	var hands: Array = _hands.get(String(animation), [])
	if hands.is_empty():
		return
	var hand: Array = hands[clampi(frame, 0, hands.size() - 1)]
	hand_anchor.position = position + (Vector2(hand[0], hand[1]) - _feet) / _pixels_per_unit
	hand_anchor.rotation = deg_to_rad(hand[2])
