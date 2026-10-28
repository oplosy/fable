class_name FighterClass
extends Resource

## How a class of characters moves and fights.

@export var display_name := ""
@export var max_health := 100

@export_group("Movement")
## Speed change per second while starting to move, and while stopping on the floor.
@export var acceleration := 900.0
@export var friction := 1100.0
@export var walk_speed := 120.0
@export var run_speed := 200.0
@export var crouch_speed := 50.0
@export var jump_velocity := -300.0
## Gravity multiplier while rising, and while falling; a heavier fall feels less floaty.
@export var gravity_scale := 1.0
@export var fall_gravity_scale := 1.0
## Releasing jump while still rising multiplies the upward speed by this, so a tap is a
## short hop and a held press a full jump. 1 turns it off.
@export_range(0.0, 1.0) var jump_cut := 1.0
## Seconds after walking off a ledge in which jump still works (coyote time).
@export var coyote_time := 0.0
## Seconds a jump pressed just before landing is remembered and done on landing.
@export var jump_buffer := 0.0
## Speed change per second from A/D in the air, up to walk speed. Jumps keep their
## takeoff speed, so this only bends the arc; dives and jump kicks cannot be steered.
@export var air_acceleration := 500.0
## A running jump is a low, long forward dive.
@export var dive_velocity := Vector2(260.0, -220.0)
@export var roll_speed := 220.0
## Seconds a roll lasts; the fighter cannot be hit while rolling.
@export var roll_time := 0.4
## Speed (px/s) up and down a ladder.
@export var climb_speed := 80.0

@export_group("Aim and Hits")
@export var aim_speed_degrees := 90.0
## Spread multiplier while firing crouched.
@export var crouch_spread_scale := 0.4
## Seconds a hit stuns when the hit does not set its own stun.
@export var hit_stun_time := 0.25

@export_group("Melee")
## Attacks chained by pressing attack again during the current one.
@export var melee_combo: Array[MeleeAttack] = []
## Pause after the full combo before the next attack; a combo cut short pauses proportionally less.
@export var combo_cooldown := 0.6
## Seconds a target stunned by a cut-short combo is guaranteed to be free before the
## attacker's next combo can hit, so single-attack spam cannot stunlock.
@export var combo_escape_time := 0.2
## Jump kick, once per jump. There are no air punches.
@export var air_attack: MeleeAttack

@export_group("Combo Breaker")
## Seconds before a used combo breaker can be used again.
@export var combo_breaker_cooldown := 10.0
## Speed (px/s) the breaker pushes the attacker back with.
@export var combo_breaker_push := 160.0
## Seconds the pushed attacker cannot act.
@export var combo_breaker_stun := 0.3

@export_group("Knockdown")
## Seconds a knocked-down fighter lies on the ground.
@export var knockdown_time := 1.25
## Seconds of invulnerability after getting up.
@export var getup_invulnerability := 0.4
## If false, a downed fighter takes damage but cannot be knocked down again.
@export var downed_invulnerable := true
