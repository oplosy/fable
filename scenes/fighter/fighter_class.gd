class_name FighterClass
extends Resource

## How a class of characters fights. Per-class stats (speed, health) will live here too.

@export var display_name := ""
## Attacks chained by pressing attack again during the current one.
@export var melee_combo: Array[MeleeAttack] = []
## Pause after the full combo before the next attack; a combo cut short pauses proportionally less.
@export var combo_cooldown := 0.6
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
