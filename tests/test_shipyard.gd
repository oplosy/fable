# Run: tests/run_all.sh test_shipyard
extends "res://tests/test_case.gd"

## The Shipyard's collision fits its art: every ladder stands on a floor and leads to
## one, every spawn point and item spawner is over a floor, and both classes get from
## the quay to every floor and back.

const FAST := preload("res://data/characters/placeholder.tres")
const HEAVY := preload("res://data/characters/dummy.tres")


func run() -> void:
	var arena: Arena = load("res://scenes/arenas/shipyard.tscn").instantiate()
	root.add_child(arena)
	await physics_frames(5)
	var map := WalkMap.of(arena)
	check(map.surfaces.size() >= 11, "the scan finds the map's floors (%d surfaces)" % map.surfaces.size())
	for ladder: Ladder in arena.find_children("*", "Node2D", true, false).filter(func(n: Node) -> bool: return n is Ladder):
		var x := ladder.global_position.x
		check(_floor_at(map, x, ladder.bottom()), "%s stands on a floor" % ladder.name)
		check(_floor_at(map, x, ladder.top()), "%s leads to a floor" % ladder.name)
	for marker: Marker2D in arena.get_node("SpawnPoints").get_children():
		check(_floor_at(map, marker.global_position.x, marker.global_position.y), "spawn %s is on a floor" % marker.name)
	for spawner: Marker2D in arena.get_node("ItemSpawns").get_children():
		var below := map.surface_under(spawner.global_position)
		check(below >= 0 and map.surfaces[below].y - spawner.global_position.y <= 12.0, "item spawner %s is just over a floor" % spawner.name)
	var ground := map.surface_under(Vector2(200, 600))
	check(ground >= 0, "the quay is a floor")
	for character: CharacterData in [FAST, HEAVY]:
		for i in map.surfaces.size():
			if i == ground:
				continue
			var at := "surface %d (x %d-%d, y %d)" % [i, map.surfaces[i].left, map.surfaces[i].right, map.surfaces[i].y]
			check(map.next_link(ground, i, 200.0, character.fighter_class) != null, "%s gets from the quay to %s" % [character.resource_path.get_file(), at])
			check(map.next_link(i, ground, map.surfaces[i].left, character.fighter_class) != null, "%s gets from %s to the quay" % [character.resource_path.get_file(), at])
	arena.free()


func _floor_at(map: WalkMap, x: float, y: float) -> bool:
	var found := map.surface_under(Vector2(x, y))
	return found >= 0 and absf(map.surfaces[found].y - y) <= WalkMap.FEET_SLACK
