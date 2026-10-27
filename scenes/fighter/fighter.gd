class_name Fighter
extends CharacterBody2D

const WEAPON_SCENE := preload("res://scenes/weapons/weapon.tscn")
const DROPPED_WEAPON_SCENE := preload("res://scenes/weapons/dropped_weapon.tscn")
## Physics layer bit of hittable fighters; dead or invulnerable fighters leave it.
const FIGHTERS_LAYER := 2
const PICKUPS_LAYER := 8

enum Slot { MELEE, FIREARM, THROWABLE, POWERUP }

@export var character: CharacterData
## Without one the fighter stands idle (e.g. a target dummy).
@export var controller: FighterController
@export var acceleration := 900.0
@export var friction := 1100.0
@export var aim_speed_degrees := 90.0
## Seconds a hit fighter ignores its controller.
@export var hit_stun_time := 0.25
## Spread multiplier while firing crouched.
@export var crouch_spread_scale := 0.4
## Body height while crouched; level shots from a standing shooter pass over it.
@export var crouch_height := 14.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var facing := 1
var active_slot := Slot.MELEE
var firearm: Weapon
## Radians within the half-circle the fighter faces: 0 level, -PI/2 straight up, PI/2 straight down.
## Kept when turning around.
var aim_angle := 0.0
## From the character; a bare default class when there is none.
var fighter_class: FighterClass

var _hit_stun := 0.0
var _down_time := 0.0
var _getup_invulnerable := 0.0
var _roll_time := 0.0
var _diving := false
## The fighter whose melee hit caused the current stun; the combo breaker pushes it back.
var _stunned_by: Fighter
var _breaker_cooldown := 0.0
var _crouching := false
var _flash_tween: Tween
var _stand_shape: RectangleShape2D
var _crouch_shape: RectangleShape2D
var _stand_hand_y: float
## Show the held melee item and throwable; hit detection never uses them.
var _melee_sprite: Sprite2D
var _throwable_sprite: Sprite2D

@onready var _visuals: Node2D = $Visuals
@onready var _placeholder: ColorRect = $Visuals/Placeholder
@onready var _hand: Marker2D = $Visuals/Hand
@onready var _attack_placeholder: ColorRect = $Visuals/AttackPlaceholder
@onready var health: Health = $Health
@onready var melee: Melee = $Melee
@onready var thrower: Thrower = $Thrower
@onready var _body_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	if character:
		_placeholder.color = character.placeholder_color
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
	# The scene's shape resource is shared by every fighter, so crouching swaps in its own copy.
	_stand_shape = _body_shape.shape
	_crouch_shape = _stand_shape.duplicate()
	_crouch_shape.size.y = crouch_height
	_stand_hand_y = _hand.position.y
	_melee_sprite = Sprite2D.new()
	_melee_sprite.visible = false
	_hand.add_child(_melee_sprite)
	melee.item_broke.connect(_show_melee_item)
	_throwable_sprite = Sprite2D.new()
	_throwable_sprite.visible = false
	_hand.add_child(_throwable_sprite)


func equip_firearm(data: WeaponData) -> void:
	if firearm:
		firearm.queue_free()
	firearm = WEAPON_SCENE.instantiate()
	firearm.data = data
	_hand.add_child(firearm)
	active_slot = Slot.FIREARM


func equip_melee_item(data: MeleeItemData) -> void:
	melee.equip(data)
	_show_melee_item()
	active_slot = Slot.MELEE


func _show_melee_item() -> void:
	_melee_sprite.texture = melee.item.texture if melee.item else null
	_melee_sprite.offset = -melee.item.grip if melee.item else Vector2.ZERO


## Fills the throwable slot without selecting it (e.g. the starting grenades).
func equip_throwable(data: ThrowableData, amount: int) -> void:
	thrower.equip(data, amount)


## Empty slots cannot be selected; melee (bare hands) is always available.
func select_slot(slot: Slot) -> bool:
	match slot:
		Slot.MELEE:
			pass
		Slot.FIREARM:
			if firearm == null:
				return false
		Slot.THROWABLE:
			if thrower.is_empty():
				return false
		_:
			# Power-ups do not exist yet, so this slot is always empty.
			return false
	active_slot = slot
	return true


## The firearm is in hand only while standing on the floor; moving puts it away.
func is_firearm_drawn() -> bool:
	return active_slot == Slot.FIREARM and firearm != null and _can_hold_ready()


## Like the firearm, a throwable is aimed and thrown only while standing still.
func is_throwable_drawn() -> bool:
	return active_slot == Slot.THROWABLE and not thrower.is_empty() and _can_hold_ready()


func _can_hold_ready() -> bool:
	return is_on_floor() and controller.move == 0.0 and can_act() and not is_rolling()


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


## Middle of the body's hit shape (standing or crouched).
func center() -> Vector2:
	return _body_shape.global_position


func aim_direction() -> Vector2:
	return Vector2(facing * cos(aim_angle), sin(aim_angle))


## A negative `stun` uses the fighter's default hit_stun_time.
## `knocks_down` puts the fighter on the ground instead of stunning it.
## `attacker` is the fighter behind a melee hit; its stun can be broken with the combo breaker.
func take_hit(damage: int, knockback := Vector2.ZERO, stun := -1.0, knocks_down := false, attacker: Fighter = null) -> void:
	if is_dead() or is_invulnerable():
		return
	health.take_damage(damage)
	# Knockback replaces the speed on each axis it pushes along, so repeated hits
	# (e.g. bullets on an airborne fighter, which has no air friction) never stack.
	if knockback.x != 0.0:
		velocity.x = knockback.x
	if knockback.y != 0.0:
		velocity.y = knockback.y
	var new_stun := stun if stun >= 0.0 else hit_stun_time
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
		_stunned_by = attacker


## Ends the stun and pushes the attacker back; its combo is cancelled by the hit.
func _break_combo() -> void:
	_hit_stun = 0.0
	_breaker_cooldown = fighter_class.combo_breaker_cooldown
	_stunned_by.take_hit(0, Vector2(-_stunned_by.facing * fighter_class.combo_breaker_push, 0.0), fighter_class.combo_breaker_stun)
	_stunned_by = null


func _knock_down() -> void:
	if is_dead() or is_knocked_down():
		return
	_down_time = fighter_class.knockdown_time
	_hit_stun = 0.0
	thrower.drop_live(_hand.global_position)
	_drop_firearm()
	_update_pose()
	_update_hittable()


## The firearm falls into the arena and the fighter is left with bare hands.
func _drop_firearm() -> void:
	if firearm == null:
		return
	_drop_item(firearm.data)
	firearm.queue_free()
	firearm = null
	if active_slot == Slot.FIREARM:
		active_slot = Slot.MELEE


## The melee item falls into the arena and the fighter punches again.
func _drop_melee_item() -> void:
	if melee.item == null:
		return
	_drop_item(melee.item)
	melee.item = null
	_show_melee_item()


## The unused throwables fall into the arena as one item; the slot is left empty.
func _drop_throwables() -> void:
	if thrower.is_empty():
		return
	_drop_item(thrower.item)
	thrower.equip(null, 0)


## Dropped items can never be picked up again and disappear after a while.
func _drop_item(data: ItemData) -> void:
	var dropped: DroppedWeapon = DROPPED_WEAPON_SCENE.instantiate()
	dropped.data = data
	dropped.position = get_parent().to_local(_hand.global_position)
	dropped.linear_velocity = Vector2(-facing * 40.0, -120.0)
	# Hits arrive from physics callbacks, where bodies cannot be added directly.
	get_parent().add_child.call_deferred(dropped)


## Only spawned items can be taken: into an empty slot by walking over one, into a
## full slot by standing on one and pressing down (the old item drops).
func _update_pickup() -> void:
	var item := _pickup_under()
	if item == null:
		return
	var slot_full: bool
	if item.data is WeaponData:
		slot_full = firearm != null
	elif item.data is ThrowableData:
		slot_full = not thrower.is_empty()
	else:
		slot_full = melee.item != null
	var swapping := controller.down and is_on_floor() and not is_running()
	if slot_full and not swapping:
		return
	if item.data is WeaponData:
		_drop_firearm()
		equip_firearm(item.data)
	elif item.data is ThrowableData:
		_drop_throwables()
		equip_throwable(item.data, item.data.count)
		active_slot = Slot.THROWABLE
	else:
		_drop_melee_item()
		equip_melee_item(item.data)
	item.take()


func _pickup_under() -> DroppedWeapon:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _body_shape.shape
	query.transform = _body_shape.global_transform
	query.collision_mask = PICKUPS_LAYER
	for result in get_world_2d().direct_space_state.intersect_shape(query):
		var item := result.collider as DroppedWeapon
		if item and item.pickable and not item.is_queued_for_deletion():
			return item
	return null


func _get_up() -> void:
	_down_time = 0.0
	_getup_invulnerable = fighter_class.getup_invulnerability
	_update_pose()
	_update_hittable()


## Out of the fighters layer, projectiles and melee pass over the fighter; it still collides with the world.
func _update_hittable() -> void:
	collision_layer = 0 if is_dead() or is_invulnerable() else FIGHTERS_LAYER


## Placeholder poses until animations exist: lying backwards when down or dead,
## head-first while diving, squashed while rolling.
func _update_pose() -> void:
	var lying := is_dead() or is_knocked_down()
	_visuals.rotation = -facing * PI / 2.0 if lying else (facing * PI / 2.0 if _diving else 0.0)
	_visuals.position.y = -6.0 if lying or _diving else 0.0
	_visuals.scale.y = 0.5 if is_rolling() else 1.0


## Called by the arena once the fighter has left the map: it dies and stops falling.
func fall_out() -> void:
	if not is_dead():
		health.take_damage(health.current)
	velocity = Vector2.ZERO
	visible = false
	set_physics_process(false)


func _on_died() -> void:
	thrower.drop_live(_hand.global_position)
	_drop_firearm()
	_drop_melee_item()
	_drop_throwables()
	_update_pose()
	_update_hittable()
	melee.cancel()


func _physics_process(delta: float) -> void:
	controller.poll()
	_hit_stun = maxf(_hit_stun - delta, 0.0)
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

	if unlocked and controller.select_slot >= 0:
		select_slot(controller.select_slot)
	if unlocked:
		_update_pickup()

	# Jumping stands the fighter up; so does anything that takes away control.
	_set_crouching(acting and is_on_floor() and controller.crouch and not controller.jump)

	if not is_on_floor():
		velocity.y += gravity * delta

	# No steering in the air: jumps, dives and jump kicks keep their takeoff momentum.
	var direction := controller.move if unlocked and is_on_floor() else 0.0
	if direction:
		var speed := fighter_class.walk_speed
		if _crouching:
			speed = fighter_class.crouch_speed
		elif controller.run:
			speed = fighter_class.run_speed
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
		facing = 1 if direction > 0 else -1
		_visuals.scale.x = facing
	elif is_on_floor() and not is_rolling():
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if unlocked and controller.jump and is_on_floor():
		if is_running():
			_diving = true
			velocity = Vector2(facing * fighter_class.dive_velocity.x, fighter_class.dive_velocity.y)
		else:
			# A walking jump goes straight up.
			velocity = Vector2(0.0, fighter_class.jump_velocity)
	elif unlocked and controller.down and is_running():
		_roll_time = fighter_class.roll_time
		velocity.x = facing * fighter_class.roll_speed
		_update_hittable()

	_melee_sprite.visible = active_slot == Slot.MELEE and melee.item != null
	_hand.rotation = 0.0
	# A cooking item stays in hand even if a hit knocks the fighter out of the ready stance.
	var throwable_ready := is_throwable_drawn() or thrower.is_cooking()
	if is_firearm_drawn() or throwable_ready:
		aim_angle = clampf(aim_angle + controller.aim * deg_to_rad(aim_speed_degrees) * delta, -PI / 2.0, PI / 2.0)
		# Visuals are mirrored by facing, so the same local angle points into the facing half.
		_hand.rotation = aim_angle
	_throwable_sprite.texture = thrower.item.texture if thrower.item else null
	_throwable_sprite.offset = -thrower.item.grip if thrower.item else Vector2.ZERO
	_throwable_sprite.visible = throwable_ready
	thrower.physics_update(delta, is_throwable_drawn(), controller.attack, controller.attack_held, _hand.global_position, aim_direction())
	if active_slot == Slot.THROWABLE and thrower.is_empty():
		active_slot = Slot.MELEE
	if firearm:
		var drawn := is_firearm_drawn()
		firearm.visible = drawn
		var wants_fire := controller.attack_held if firearm.data.automatic else controller.attack
		if drawn and wants_fire:
			# Projectiles belong to the arena, not the fighter, so they outlive it.
			firearm.try_fire(aim_direction(), get_parent(), self, crouch_spread_scale if _crouching else 1.0)
			if firearm.is_empty():
				_drop_firearm()

	if acting and active_slot == Slot.MELEE and controller.attack:
		melee.request_attack(not is_on_floor())
	melee.physics_update(delta)
	_update_attack_placeholder()
	_update_pose()

	move_and_slide()


## Shows the hit area while an attack can land. Replaced by attack animations later.
func _update_attack_placeholder() -> void:
	_attack_placeholder.visible = melee.is_hitting()
	var attack := melee.current_attack()
	if attack:
		# Visuals are mirrored by facing, so the facing-right offset is used as is.
		_attack_placeholder.position = attack.hitbox_offset - attack.hitbox_size / 2.0
		_attack_placeholder.size = attack.hitbox_size
