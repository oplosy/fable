class_name ThrowableData
extends ItemData

## A counted throwable (grenade, molotov). Holding attack pulls the pin, releasing throws.

## How many a fighter gets when it takes this item.
@export var count := 3
## Seconds from pulling the pin to the blast, in hand or in flight; 0 for no fuse.
@export var fuse_time := 3.0
## Goes off on its first contact with the world or a fighter (molotov).
@export var breaks_on_impact := false
@export var throw_speed := 300.0
## Bounciness off the world, 0..1.
@export var bounce := 0.4
## Spawned where it goes off: an explosion, a fire area.
@export var effect_scene: PackedScene
