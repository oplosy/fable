class_name Fighter
extends CharacterBody2D

## Physics layer bit of hittable fighters; dead or invulnerable fighters leave it.
const FIGHTERS_LAYER := 2
## Every fighter joins this group (cameras, bots and modes find fighters through it).
const GROUP := &"fighters"

## What the fighter is doing, highest priority first in `state()`. Animations pick their
## clip from this alone; stance details (crouching, aim angle, held item, combo index)
## are read from the fighter and its components.
enum State { IDLE, WALK, RUN, CROUCH, AIR, CLIMB, AIM, COOK, ATTACK, STUN, DIVE, ROLL, DOWN, DEAD }

signal state_changed(state: State)
## `killer` is the last fighter that hit it within KILL_CREDIT_TIME (itself for a
## self-kill), or null when nobody did. Game modes score from this.
signal died(killer: Fighter)
## A hit landed (not blocked by invulnerability); animations restart their flinch on it.
signal hit_taken

## Seconds a hit keeps its attacker credited, so a fall soon after a push still counts.
const KILL_CREDIT_TIME := 5.0

@export var character: CharacterData
## Without one the fighter stands idle (e.g. a target dummy).
@export var controller: FighterController

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var facing := 1
## Radians within the half-circle the fighter faces: 0 level, -PI/2 straight up, PI/2 straight down.
## Kept when turning around.
var aim_angle := 0.0
## From the character; a bare default class when there is none.
var fighter_class: FighterClass
## Whether the last hit pushed the fighter forwards (it came from behind). Animations
## pick the flinch, fall and death direction from it.
var hit_from_behind := false
## Stun time of the last hit, so animations can tell light hits from heavy ones.
var last_stun := 0.0

var _hit_stun := 0.0
var _down_time := 0.0
var _getup_invulnerable := 0.0
var _roll_time := 0.0
var _diving := false
## The fighter whose melee hit caused the current stun; the combo breaker pushes it back.
var _stunned_by: Fighter
var _breaker_cooldown := 0.0
var _last_attacker: Fighter
var _credit_left := 0.0
var _crouching := false
var _flash_tween: Tween
var _stand_shape: RectangleShape2D
var _crouch_shape: RectangleShape2D
var _stand_hand_y: float
## Shows the held throwable; hit detection never uses it.
var _throwable_sprite: Sprite2D
var _crosshair := Crosshair.new()
var _state := State.IDLE
## The ladder being climbed, null when not climbing.
var _ladder: Ladder
## The world layers the body collides with; climbing turns them off.
var _world_mask := 0

@onready var _visuals: Node2D = $Visuals
@onready var _placeholder: ColorRect = $Visuals/Placeholder
@onready var _hand: Marker2D = $Visuals/Hand
@onready var _attack_placeholder: ColorRect = $Visuals/AttackPlaceholder
@onready var health: Health = $Health
@onready var melee: Melee = $Melee
@onready var thrower: Thrower = $Thrower
@onready var inventory: Inventory = $Inventory
@onready var _body_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	if character:
		_placeholder.color = character.placeholder_color
		if character.rig_file:
			_show_rig(character)
		elif character.texture:
			_show_art(character)
	fighter_class = character.fighter_class if character and character.fighter_class else FighterClass.new()
	# Health's own _ready already ran with its default, so start it at the class's maximum.
	health.max_health = fighter_class.max_health
	health.current = health.max_health
	melee.fighter = self
	melee.fighter_class = fighter_class
	thrower.fighter = self
	if controller == null:
		controller = FighterController.new()
	if controller.get_parent() == null:
		add_child(controller)
	health.died.connect(_on_died)
	add_to_group(Arena.BOUNDED)
	add_to_group(GROUP)
	_world_mask = collision_mask
	# The scene's shape resource is shared by every fighter, so crouching swaps in its own copy.
	# Each fighter gets its own shapes: the body size comes from the character, and
	# crouching halves the height so level shots from a standing shooter pass over it.
	_stand_shape = RectangleShape2D.new()
	_stand_shape.size = character.body_size if character else CharacterData.DEFAULT_BODY_SIZE
	_crouch_shape = RectangleShape2D.new()
	_crouch_shape.size = Vector2(_stand_shape.size.x, _stand_shape.size.y / 2.0)
	_placeholder.offset_left = -_stand_shape.size.x / 2.0
	_placeholder.offset_right = _stand_shape.size.x / 2.0
	_stand_hand_y = -_stand_shape.size.y / 2.0
	# Starts "crouched" so the call below applies the standing shape, hand and look.
	_crouching = true
	_set_crouching(false)
	inventory.setup(self, _hand)
	var rig := _visuals.get_node_or_null("Rig") as CharacterRig
	if rig and rig.hand_anchor:
		inventory.show_melee_item_on(rig.hand_anchor)
	_throwable_sprite = Sprite2D.new()
	_throwable_sprite.visible = false
	_hand.add_child(_throwable_sprite)
	add_child(_crosshair)


## The firearm is in hand only while standing on the floor; moving puts it away.
func is_firearm_drawn() -> bool:
	return inventory.active_slot == Inventory.Slot.FIREARM and inventory.firearm != null and _can_hold_ready()


## Like the firearm, a throwable is aimed and thrown only while standing still.
func is_throwable_drawn() -> bool:
	return inventory.active_slot == Inventory.Slot.THROWABLE and not thrower.is_empty() and _can_hold_ready()


func _can_hold_ready() -> bool:
	return is_on_floor() and controller.move == 0.0 and can_act() and not is_rolling() and not is_climbing()


func is_stunned() -> bool:
	return _hit_stun > 0.0


func is_dead() -> bool:
	return health.is_dead()


func is_knocked_down() -> bool:
	return _down_time > 0.0


func is_invulnerable() -> bool:
	return (is_knocked_down() and fighter_class.downed_invulnerable) or _getup_invulnerable > 0.0 or is_rolling()


func is_rolling() -> bool:
	return _roll_time > 0.0


func is_diving() -> bool:
	return _diving


func is_climbing() -> bool:
	return _ladder != null


## Only a melee stun can be broken, and only once per cooldown.
func can_break_combo() -> bool:
	return is_stunned() and is_instance_valid(_stunned_by) and _breaker_cooldown <= 0.0 and not is_dead()


func is_breaker_cooling_down() -> bool:
	return _breaker_cooldown > 0.0


func can_act() -> bool:
	return not is_stunned() and not is_dead() and not is_knocked_down()


## Running is moving on the floor with the controller's run intent; crouching overrides it.
func is_running() -> bool:
	return is_on_floor() and controller.run and controller.move != 0.0 and not _crouching


func is_crouching() -> bool:
	return _crouching


## Lowers the body, its hit shape and the hand; standing up restores them.
func _set_crouching(crouching: bool) -> void:
	if crouching == _crouching:
		return
	_crouching = crouching
	var shape := _crouch_shape if crouching else _stand_shape
	_body_shape.shape = shape
	_body_shape.position.y = -shape.size.y / 2.0
	_hand.position.y = _stand_hand_y * shape.size.y / _stand_shape.size.y
	# Placeholder look; the hand is resized above rather than squashing the weapon sprite.
	_placeholder.offset_top = -shape.size.y


## Draws the character's art at 1/pixels_per_unit scale with its feet on the fighter's
## origin, in place of the placeholder box. Hit detection never uses it.
func _show_art(data: CharacterData) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Art"
	sprite.texture = data.texture
	sprite.centered = false
	sprite.offset = -data.feet
	sprite.scale = Vector2.ONE / data.pixels_per_unit
	_visuals.add_child(sprite)
	_visuals.move_child(sprite, 0)
	_placeholder.visible = false


## Builds the character's cutout rig and its animator in place of the placeholder box;
## a broken rig logs an error and leaves the placeholder.
func _show_rig(data: CharacterData) -> void:
	var rig := CharacterRig.new()
	rig.name = "Rig"
	if not rig.build(data.rig_file, data.pixels_per_unit):
		rig.free()
		return
	_visuals.add_child(rig)
	_visuals.move_child(rig, 0)
	_placeholder.visible = false
	var animator := RigAnimator.new()
	animator.name = "Animator"
	add_child(animator)
	animator.setup(self, rig)


## Middle of the body's hit shape (standing or crouched).
func center() -> Vector2:
	return _body_shape.global_position


## The body's current (standing or crouched) collision shape node.
func body_shape() -> CollisionShape2D:
	return _body_shape


func aim_direction() -> Vector2:
	return Vector2(facing * cos(aim_angle), sin(aim_angle))


## A negative `stun` uses the class's hit_stun_time.
## `knocks_down` puts the fighter on the ground instead of stunning it.
## `attacker` is the fighter credited with the hit (and a kill it leads to).
## `by_melee` lets the combo breaker push the attacker back out of the stun.
func take_hit(damage: int, knockback := Vector2.ZERO, stun := -1.0, knocks_down := false, attacker: Fighter = null, by_melee := false) -> void:
	if is_dead() or is_invulnerable():
		return
	if attacker:
		_last_attacker = attacker
		_credit_left = KILL_CREDIT_TIME
	health.take_damage(damage)
	# Knockback replaces the speed on each axis it pushes along, so repeated hits
	# (e.g. bullets on an airborne fighter, which has no air friction) never stack.
	if knockback.x != 0.0:
		velocity.x = knockback.x
	if knockback.y != 0.0:
		velocity.y = knockback.y
	var new_stun := stun if stun >= 0.0 else fighter_class.hit_stun_time
	if knockback.x != 0.0:
		hit_from_behind = knockback.x * facing > 0.0
	last_stun = new_stun
	hit_taken.emit()
	# Hits that neither stun nor knock down (fire) hurt without interrupting the fighter.
	if knocks_down or new_stun > 0.0:
		melee.cancel()
		_diving = false
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_visuals, "modulate", Color.WHITE, 0.15).from(Color(3, 3, 3))
	if is_dead():
		return
	# Already-downed fighters (only hittable if the class allows it) are never knocked down again.
	if knocks_down and not is_knocked_down():
		# Deferred so the other pellets of the same shotgun blast still land
		# before the downed fighter turns invulnerable.
		_knock_down.call_deferred()
	elif not is_knocked_down() and new_stun >= _hit_stun:
		# A shorter stun never cuts a longer one short, nor takes away its combo breaker.
		_hit_stun = new_stun
		_stunned_by = attacker if by_melee else null


## Ends the stun and pushes the attacker back; its combo is cancelled by the hit.
func _break_combo() -> void:
	_hit_stun = 0.0
	_breaker_cooldown = fighter_class.combo_breaker_cooldown
	_stunned_by.take_hit(0, Vector2(-_stunned_by.facing * fighter_class.combo_breaker_push, 0.0), fighter_class.combo_breaker_stun, false, self)
	_stunned_by = null


func _knock_down() -> void:
	if is_dead() or is_knocked_down():
		return
	_down_time = fighter_class.knockdown_time
	_hit_stun = 0.0
	thrower.drop_live(_hand.global_position)
	inventory.drop_firearm()
	_update_pose()
	_update_hittable()


func _get_up() -> void:
	_down_time = 0.0
	_getup_invulnerable = fighter_class.getup_invulnerability
	_update_pose()
	_update_hittable()


## Out of the fighters layer, projectiles and melee pass over the fighter; it still collides with the world.
func _update_hittable() -> void:
	collision_layer = 0 if is_dead() or is_invulnerable() else FIGHTERS_LAYER


## Placeholder poses where no clip exists yet: lying backwards when down or dead (only
## without a rig, whose animator lays it down), head-first while diving, squashed while rolling.
func _update_pose() -> void:
	var now := state()
	var lying := (now == State.DEAD or now == State.DOWN) and not has_node("Animator")
	_visuals.rotation = -facing * PI / 2.0 if lying else (facing * PI / 2.0 if now == State.DIVE else 0.0)
	_visuals.position.y = -6.0 if lying or now == State.DIVE else 0.0
	_visuals.scale.y = 0.5 if now == State.ROLL else 1.0
	if now != _state:
		_state = now
		state_changed.emit(now)


## The single answer to "what is the fighter doing", for animations and debugging.
func state() -> State:
	if is_dead():
		return State.DEAD
	if is_knocked_down():
		return State.DOWN
	if is_rolling():
		return State.ROLL
	if _diving:
		return State.DIVE
	if melee.is_attacking():
		return State.ATTACK
	if is_stunned():
		return State.STUN
	if thrower.is_cooking():
		return State.COOK
	if is_climbing():
		return State.CLIMB
	if not is_on_floor():
		return State.AIR
	if is_firearm_drawn() or is_throwable_drawn():
		return State.AIM
	if _crouching:
		return State.CROUCH
	if controller.move != 0.0 and can_act():
		return State.RUN if is_running() else State.WALK
	return State.IDLE


## Called by the arena once the fighter has left the map: it dies and stops falling.
func fall_out() -> void:
	if not is_dead():
		health.take_damage(health.current)
	velocity = Vector2.ZERO
	visible = false
	set_physics_process(false)


func _on_died() -> void:
	thrower.drop_live(_hand.global_position)
	inventory.drop_all()
	_update_pose()
	_update_hittable()
	melee.cancel()
	var credited := _credit_left > 0.0 and is_instance_valid(_last_attacker)
	died.emit(_last_attacker if credited else null)


func _physics_process(delta: float) -> void:
	controller.poll()
	_hit_stun = maxf(_hit_stun - delta, 0.0)
	_credit_left = maxf(_credit_left - delta, 0.0)
	if is_knocked_down() and not is_dead():
		_down_time -= delta
		if _down_time <= 0.0:
			_get_up()
	elif _getup_invulnerable > 0.0:
		_getup_invulnerable = maxf(_getup_invulnerable - delta, 0.0)
		_update_hittable()
	if is_rolling():
		_roll_time = maxf(_roll_time - delta, 0.0)
		if not is_rolling():
			_update_hittable()
	if _diving and is_on_floor():
		_diving = false
	_breaker_cooldown = maxf(_breaker_cooldown - delta, 0.0)
	# The breaker's attack and jump presses are used up by the break.
	var broke := controller.combo_break and can_break_combo()
	if broke:
		_break_combo()
	# Dives and rolls commit the fighter until they end.
	var acting := can_act() and not is_rolling() and not _diving and not broke
	# A melee attack or a pulled pin commits the fighter: no moving, turning, jumping or
	# slot changes until the attack ends or the item is thrown.
	var unlocked := acting and not melee.is_attacking() and not thrower.is_cooking()

	if is_climbing() and (not unlocked or controller.jump or controller.move != 0.0):
		var jumped := unlocked and controller.jump
		_let_go()
		if jumped:
			velocity.y = fighter_class.jump_velocity
			# The jump is used up; is_on_floor() is stale from before the climb.
			unlocked = false
	elif unlocked and not is_climbing():
		_try_grab()
	if is_climbing():
		_climb(delta)
		return

	if unlocked and controller.select_slot >= 0:
		inventory.select_slot(controller.select_slot)
	if unlocked:
		inventory.update_pickup()

	# Jumping stands the fighter up; so does anything that takes away control.
	_set_crouching(acting and is_on_floor() and controller.crouch and not controller.jump)

	if not is_on_floor():
		velocity.y += gravity * delta

	var direction := controller.move if unlocked else 0.0
	if direction and is_on_floor():
		var speed := fighter_class.walk_speed
		if _crouching:
			speed = fighter_class.crouch_speed
		elif controller.run:
			speed = fighter_class.run_speed
		velocity.x = move_toward(velocity.x, direction * speed, fighter_class.acceleration * delta)
		facing = 1 if direction > 0 else -1
		_visuals.scale.x = facing
	elif direction:
		# Steering in the air bends the jump up to walk speed; it never slows down
		# faster momentum in the held direction (a running takeoff, a knockback).
		if direction * velocity.x < fighter_class.walk_speed:
			velocity.x = move_toward(velocity.x, direction * fighter_class.walk_speed, fighter_class.air_acceleration * delta)
		facing = 1 if direction > 0 else -1
		_visuals.scale.x = facing
	elif is_on_floor() and not is_rolling():
		velocity.x = move_toward(velocity.x, 0.0, fighter_class.friction * delta)

	if unlocked and controller.jump and is_on_floor():
		if is_running():
			_diving = true
			velocity = Vector2(facing * fighter_class.dive_velocity.x, fighter_class.dive_velocity.y)
		else:
			# A jump keeps the speed it was walking with, so it arcs forward.
			velocity.y = fighter_class.jump_velocity
	elif unlocked and controller.down and is_running():
		_roll_time = fighter_class.roll_time
		velocity.x = facing * fighter_class.roll_speed
		_update_hittable()

	_hand.rotation = 0.0
	# A cooking item stays in hand even if a hit knocks the fighter out of the ready stance.
	var throwable_ready := is_throwable_drawn() or thrower.is_cooking()
	if is_firearm_drawn() or throwable_ready:
		aim_angle = clampf(aim_angle + controller.aim * deg_to_rad(fighter_class.aim_speed_degrees) * delta, -PI / 2.0, PI / 2.0)
		# Visuals are mirrored by facing, so the same local angle points into the facing half.
		_hand.rotation = aim_angle
	ItemData.show_on(_throwable_sprite, thrower.item)
	_throwable_sprite.visible = throwable_ready
	thrower.physics_update(delta, is_throwable_drawn(), controller.attack, controller.attack_held, _hand.global_position, aim_direction())
	inventory.physics_update()
	var firearm := inventory.firearm
	if firearm:
		var drawn := is_firearm_drawn()
		firearm.visible = drawn
		var wants_fire := controller.attack_held if firearm.data.automatic else controller.attack
		if drawn and wants_fire:
			# Projectiles belong to the arena, not the fighter, so they outlive it.
			firearm.try_fire(aim_direction(), get_parent(), self, fighter_class.crouch_spread_scale if _crouching else 1.0)
			if firearm.is_empty():
				inventory.drop_firearm()
	_crosshair.point(is_firearm_drawn(), _hand.global_position, aim_direction(), get_rid())

	if acting and inventory.active_slot == Inventory.Slot.MELEE and controller.attack:
		melee.request_attack(not is_on_floor())
	melee.physics_update(delta)
	_update_attack_placeholder()
	_update_pose()

	move_and_slide()


## Up takes hold of a ladder anywhere below its top; down only from its top.
func _try_grab() -> void:
	if controller.aim == 0.0 or is_running():
		return
	for ladder: Ladder in get_tree().get_nodes_in_group(Ladder.GROUP):
		if not ladder.reaches(global_position):
			continue
		var up := controller.aim < 0.0 and global_position.y > ladder.top() + 1.0
		var down := controller.aim > 0.0 and is_on_floor() and global_position.y < ladder.bottom() - 1.0
		if up or down:
			_grab(ladder)
			return


func _grab(ladder: Ladder) -> void:
	_ladder = ladder
	# Off the world layers, the body passes the platforms the ladder goes through.
	collision_mask = 0
	velocity = Vector2.ZERO
	_set_crouching(false)
	if inventory.firearm:
		inventory.firearm.visible = false
	_throwable_sprite.visible = false
	_crosshair.point(false, Vector2.ZERO, Vector2.RIGHT, get_rid())
	_update_pose()


## Moves along the ladder with the up/down intent; either end steps off onto what is there.
func _climb(delta: float) -> void:
	global_position.x = _ladder.global_position.x
	global_position.y = clampf(global_position.y + controller.aim * fighter_class.climb_speed * delta, _ladder.top(), _ladder.bottom())
	if (controller.aim < 0.0 and global_position.y <= _ladder.top()) or (controller.aim > 0.0 and global_position.y >= _ladder.bottom()):
		_let_go()
	_update_pose()


func _let_go() -> void:
	_ladder = null
	collision_mask = _world_mask
	_update_pose()


## Shows the hit area while an attack can land. Replaced by attack animations later.
func _update_attack_placeholder() -> void:
	_attack_placeholder.visible = melee.is_hitting()
	var attack := melee.current_attack()
	if attack:
		# Visuals are mirrored by facing, so the facing-right offset is used as is.
		_attack_placeholder.position = attack.hitbox_offset - attack.hitbox_size / 2.0
		_attack_placeholder.size = attack.hitbox_size
