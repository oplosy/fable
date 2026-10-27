class_name ExplosiveBarrel
extends StaticBody2D

## A solid barrel on the world and fighters layers: bullets, melee, blasts and fire hit it,
## and once `health` runs out it blows up (setting off barrels next to it), crediting
## whoever hit it last.

const EXPLOSION := preload("res://scenes/throwables/explosion.tscn")

@export var health := 20
@export var radius := 56.0
@export var damage := 45
## Where the blast starts, from the barrel's origin (its bottom middle).
@export var blast_offset := Vector2(0, -9)


## Same arguments as Fighter.take_hit, so every hit source can hit a barrel.
func take_hit(amount: int, _knockback := Vector2.ZERO, _stun := -1.0, _knocks_down := false, attacker: Fighter = null, _by_melee := false) -> void:
	if health <= 0:
		return
	health -= amount
	if health > 0:
		return
	var blast: Explosion = EXPLOSION.instantiate()
	blast.radius = radius
	blast.damage = damage
	blast.attacker = attacker
	blast.position = position + blast_offset
	# Deferred: hits arrive mid physics query, when the tree must not change.
	get_parent().add_child.call_deferred(blast)
	queue_free()


## Blasts aim at a target's middle.
func center() -> Vector2:
	return global_position + blast_offset
