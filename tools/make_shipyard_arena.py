"""Builds scenes/arenas/shipyard.tscn from the Shipyard reference art.

The art (assets/arenas/shipyard/background.png, 2000x1116) is drawn at SCALE world px per
art px, so the map fills a 1280x720 camera area. Every surface, wall and ladder below is
measured in art pixels on that picture; edit them here and rerun:

    python tools/make_shipyard_arena.py
"""

from pathlib import Path

SCALE = 0.64
ART_SIZE = (2000, 1116)
MAP = (1280, 720)
OUT = Path(__file__).resolve().parent.parent / "scenes" / "arenas" / "shipyard.tscn"

# One-way platforms: name, left, right, top (art px).
PLATFORMS = [
	("Warehouse", 0, 1850, 821),
	("QuayWest", 0, 370, 498),
	("QuayEast", 1665, 2000, 498),
	("CatwalkWest", 0, 265, 645),
	("CatwalkEast", 1855, 2000, 647),
	("Deck", 352, 1700, 397),
	("CabinUpper", 675, 1352, 529),
	("CabinLower", 675, 1350, 629),
	("BridgeBalcony", 455, 680, 344),
	("BridgeDeck", 490, 800, 289),
	("BridgeRoof", 548, 818, 237),
]

# Solid blocks: name, left, top, right, bottom (art px).
SOLIDS = [
	("Ground", 0, 957, 2000, 1116),
	("CabinWallWest", 663, 405, 675, 640),
	("CabinWallEast", 1350, 405, 1362, 640),
]

# Ladders: name, x, bottom, top (art px); drawn says whether the art already shows it.
LADDERS = [
	("LadderGroundWest", 123, 957, 821, True),
	("LadderGroundMid", 960, 957, 821, True),
	("LadderGroundEast", 1250, 957, 821, True),
	("LadderGroundFar", 1521, 957, 821, True),
	("LadderCatwalkWest", 235, 821, 645, True),
	("LadderQuayWest", 235, 645, 498, True),
	("LadderSternWest", 362, 498, 397, False),
	("LadderBowEast", 1688, 498, 397, False),
	("LadderCatwalkEast", 1875, 957, 647, False),
	("LadderQuayEast", 1875, 647, 498, False),
	("LadderHatch", 825, 529, 397, True),
	("LadderCabin", 825, 629, 529, True),
	("LadderCabinEast", 1092, 629, 529, True),
	("LadderKeel", 1300, 821, 629, False),
	("LadderStairs", 590, 397, 344, True),
	("LadderStairsUpper", 590, 344, 289, True),
	("LadderMast", 780, 289, 237, False),
]

# Spawn points: name, x, feet y (art px).
SPAWNS = [
	("P1", 300, 957),
	("P2", 1700, 957),
	("P3", 1000, 629),
	("P4", 600, 821),
	("P5", 1850, 498),
	("P6", 1200, 397),
]

# Item spawners: name, x, feet y (art px), pool.
ITEMS = [
	("GroundWest", 640, 957, "mixed"),
	("GroundEast", 1400, 957, "mixed"),
	("Warehouse", 1100, 821, "mixed"),
	("CabinUpper", 950, 529, "mixed"),
	("CabinLower", 760, 629, "mixed"),
	("QuayWest", 100, 498, "mixed"),
	("BridgeRoof", 690, 237, "sniper"),
]

WALL = 16
PLATFORM_THICKNESS = 8
# Items float this far (world px) over the floor, as in the test arena.
ITEM_LIFT = 8


def w(art: float) -> int:
	return round(art * SCALE)


def main() -> None:
	ext = [
		("Script", "res://scenes/arenas/arena.gd", "arena"),
		("Script", "res://scenes/arenas/follow_camera.gd", "camera"),
		("Script", "res://scenes/arenas/camera_shot.gd", "shot"),
		("Texture2D", "res://assets/arenas/shipyard/background.png", "art"),
		("PackedScene", "res://scenes/props/ladder.tscn", "ladder"),
		("Script", "res://scenes/items/item_spawner.gd", "spawner"),
		("Script", "res://scenes/items/item_data.gd", "item_data"),
		("Resource", "res://data/weapons/pistol.tres", "pistol"),
		("Resource", "res://data/weapons/shotgun.tres", "shotgun"),
		("Resource", "res://data/weapons/smg.tres", "smg"),
		("Resource", "res://data/weapons/sniper.tres", "sniper"),
		("Resource", "res://data/weapons/knife.tres", "knife"),
		("Resource", "res://data/weapons/bat.tres", "bat"),
		("Resource", "res://data/throwables/grenade.tres", "grenade"),
		("Resource", "res://data/throwables/molotov.tres", "molotov"),
	]
	pools = {
		"mixed": ["pistol", "shotgun", "smg", "knife", "bat", "grenade", "molotov"],
		"sniper": ["sniper"],
	}
	subs: list[str] = []
	nodes: list[str] = []

	def shape(sid: str, width: int, height: int) -> str:
		subs.append(f'[sub_resource type="RectangleShape2D" id="{sid}"]\nsize = Vector2({width}, {height})\n')
		return sid

	def body(name: str, parent: str, left: int, top: int, right: int, bottom: int, one_way: bool) -> None:
		sid = shape(f"shape_{name}", right - left, bottom - top)
		nodes.append(f'[node name="{name}" type="StaticBody2D" parent="{parent}"]\nposition = Vector2({(left + right) / 2}, {(top + bottom) / 2})\n')
		props = f'shape = SubResource("{sid}")\n'
		if one_way:
			props += "one_way_collision = true\n"
		nodes.append(f'[node name="CollisionShape2D" type="CollisionShape2D" parent="{parent}/{name}"]\n{props}')

	nodes.append(
		'[node name="Shipyard" type="Node2D"]\n'
		'script = ExtResource("arena")\n'
		f"bounds = Rect2(-64, -360, {MAP[0] + 128}, {MAP[1] + 424})\n"
		f"camera_limits = Rect2(0, 0, {MAP[0]}, {MAP[1]})\n"
	)
	nodes.append(
		'[node name="Backdrop" type="ColorRect" parent="."]\n'
		f"offset_right = {MAP[0]}.0\noffset_bottom = {MAP[1]}.0\nmouse_filter = 2\n"
		"color = Color(0.05, 0.06, 0.08, 1)\n"
	)
	nodes.append(
		'[node name="Background" type="Sprite2D" parent="."]\n'
		f'texture = ExtResource("art")\ncentered = false\nscale = Vector2({SCALE}, {SCALE})\n'
	)

	nodes.append('[node name="Collision" type="Node2D" parent="."]\n')
	for name, left, top, right, bottom in SOLIDS:
		body(name, "Collision", w(left), w(top), w(right), w(bottom), False)
	for name, left, right, top in PLATFORMS:
		body(name, "Collision", w(left), w(top), w(right), w(top) + PLATFORM_THICKNESS, True)
	ground = w(957)
	body("WallWest", "Collision", -WALL, -360, 0, ground, False)
	body("WallEast", "Collision", MAP[0], -360, MAP[0] + WALL, ground, False)

	nodes.append('[node name="Props" type="Node2D" parent="."]\n')
	for name, x, bottom, top, drawn in LADDERS:
		props = f"position = Vector2({w(x)}, {w(bottom)})\nheight = {float(w(bottom) - w(top))}\n"
		if drawn:
			props += "placeholder = false\n"
		nodes.append(f'[node name="{name}" parent="Props" instance=ExtResource("ladder")]\n{props}')

	nodes.append('[node name="SpawnPoints" type="Node2D" parent="."]\n')
	for name, x, y in SPAWNS:
		nodes.append(f'[node name="{name}" type="Marker2D" parent="SpawnPoints"]\nposition = Vector2({w(x)}, {w(y)})\n')

	nodes.append('[node name="ItemSpawns" type="Node2D" parent="."]\n')
	for name, x, y, pool in ITEMS:
		items = ", ".join(f'ExtResource("{i}")' for i in pools[pool])
		nodes.append(
			f'[node name="{name}" type="Marker2D" parent="ItemSpawns"]\n'
			f"position = Vector2({w(x)}, {w(y) - ITEM_LIFT})\n"
			'script = ExtResource("spawner")\n'
			f'items = Array[ExtResource("item_data")]([{items}])\n'
		)

	nodes.append(
		'[node name="Camera2D" type="Camera2D" parent="."]\n'
		f"position = Vector2({MAP[0] / 2}, {MAP[1] / 2})\n"
		'script = ExtResource("camera")\n'
	)
	# Zoom-3 shots (640x360): the quay and warehouse below, the ship and quays above.
	nodes.append('[node name="CameraShots" type="Node2D" parent="."]\n')
	for row, y in (("Low", 540), ("High", 250)):
		for col, x in (("West", 320), ("Mid", 640), ("East", 960)):
			nodes.append(
				f'[node name="{row}{col}" type="Marker2D" parent="CameraShots"]\n'
				f"position = Vector2({x}, {y})\n"
				'script = ExtResource("shot")\n'
			)

	header = f"[gd_scene load_steps={len(ext) + len(subs) + 1} format=3]\n"
	ext_lines = "".join(f'[ext_resource type="{t}" path="{p}" id="{i}"]\n' for t, p, i in ext)
	OUT.write_text(header + "\n" + ext_lines + "\n" + "\n".join(subs) + "\n" + "\n".join(nodes), encoding="utf-8", newline="\n")
	print(f"wrote {OUT}")


if __name__ == "__main__":
	main()
