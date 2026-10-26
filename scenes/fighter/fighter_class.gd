class_name FighterClass
extends Resource

## How a class of characters fights. Per-class stats (speed, health) will live here too.

@export var display_name := ""
## Attacks chained by pressing attack again during the current one.
@export var melee_combo: Array[MeleeAttack] = []
## Pause after the full combo before the next attack; a combo cut short pauses proportionally less.
@export var combo_cooldown := 0.6
