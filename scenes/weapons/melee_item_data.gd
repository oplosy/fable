class_name MeleeItemData
extends ItemData

## A hand-held melee item (knife, bat): its combo replaces the punches while held.

## Attacks chained by pressing attack again during the current one.
@export var combo: Array[MeleeAttack] = []
## Pause after the full combo; a combo cut short pauses proportionally less.
@export var combo_cooldown := 0.6
## Hits that land on fighters before the item breaks.
@export var durability := 12
