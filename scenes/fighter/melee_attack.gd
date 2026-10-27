class_name MeleeAttack
extends Resource

## One punch, kick or swing. Timings are in seconds.

@export var display_name := ""
## Clip played for it (docs/CHARACTER_ANIMATION_SPEC.md). The animator first tries
## "<animation>_<place in the combo, from 1>", so repeated attacks can alternate fists.
@export var animation := &""
@export var damage := 5
## Added to the target's velocity; +x points away from the attacker.
@export var knockback := Vector2(40, 0)
## How long the target is stunned; must cover the gap to the next attack of a combo.
@export var stun_time := 0.35
## Knocks the target to the ground instead of stunning it (combo finishers, jump kicks).
@export var knocks_down := false
@export var windup := 0.05
@export var active := 0.08
@export var recovery := 0.12
## Hit area centre relative to the fighter's feet, for a fighter facing right.
@export var hitbox_offset := Vector2(12, -16)
@export var hitbox_size := Vector2(14, 10)


func duration() -> float:
	return windup + active + recovery
