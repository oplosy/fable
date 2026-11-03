"""Builds the Shipyard map, a dry dock at night after the user's reference picture
(art/shipyard/reference.png, used only for layout and colour).

1. Writes the layout below to art/shipyard/layout.json.
2. Runs tools/draw_shipyard.lua in Aseprite, which draws the map pixel by pixel from that
   layout: art/shipyard/shipyard.aseprite, assets/arenas/shipyard/background.png and the
   barrel sprites in assets/props/.
3. Writes scenes/arenas/shipyard.tscn: collision, ladders, barrel props, spawns, items.

Everything is in world px, and the art is 1 px per world px (640x360), shown unfiltered at
zoom 3 so every art pixel is a sharp 3x3 block. Edit the layout here and rerun:

    python tools/make_shipyard.py
"""

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASEPRITE = Path("C:/Program Files/Aseprite/Aseprite.exe")
LAYOUT = ROOT / "art" / "shipyard" / "layout.json"
OUT = ROOT / "scenes" / "arenas" / "shipyard.tscn"

MAP = (640, 360)

# Heights of the floors and the ship's outline, shared with the drawing.
GROUND = 350
WAREHOUSE = 288
QUAY = 143
DECK = 98
KEEL = 212
CABIN_WEST, CABIN_EAST = 166, 470
CABIN_UPPER, CABIN_LOWER = 157, 202
BALCONY, BRIDGE_DECK, ROOF = 74, 53, 31

# One-way platforms: name, left, right, top.
PLATFORMS = [
	("Warehouse", 0, MAP[0], WAREHOUSE),
	("QuayWest", 0, 29, QUAY),
	("QuayEast", 612, MAP[0], QUAY),
	("Deck", 21, 628, DECK),
	("CabinUpper", CABIN_WEST, CABIN_EAST, CABIN_UPPER),
	("CabinLower", CABIN_WEST, CABIN_EAST, CABIN_LOWER),
	("BridgeBalcony", 67, 166, BALCONY),
	("BridgeDeck", 81, 190, BRIDGE_DECK),
	("BridgeRoof", 135, 195, ROOF),
]

# Solid blocks: name, left, top, right, bottom. The cabin walls are the hull's cut edges.
SOLIDS = [
	("Ground", 0, GROUND, MAP[0], MAP[1] + 60),
	("CabinWallWest", CABIN_WEST - 5, DECK + 3, CABIN_WEST, KEEL - 5),
	("CabinWallEast", CABIN_EAST, DECK + 3, CABIN_EAST + 6, KEEL - 5),
]

# Ladders: name, x (middle), bottom, top. All are drawn in the art.
LADDERS = [
	("LadderGroundMid", 295, GROUND, WAREHOUSE),
	("LadderGroundEast", 425, GROUND, WAREHOUSE),
	("LadderGroundFar", 547, GROUND, WAREHOUSE),
	("LadderQuayWest", 11, WAREHOUSE, QUAY),
	("LadderSternWest", 26, QUAY, DECK),
	("LadderQuayEast", 633, WAREHOUSE, QUAY),
	("LadderBowEast", 622, QUAY, DECK),
	("LadderKeelWest", 205, WAREHOUSE, CABIN_LOWER),
	("LadderKeelEast", 448, WAREHOUSE, CABIN_LOWER),
	("LadderHatch", 234, CABIN_UPPER, DECK),
	("LadderCabin", 234, CABIN_LOWER, CABIN_UPPER),
	("LadderCabinEast", 354, CABIN_LOWER, CABIN_UPPER),
	("LadderStairs", 140, DECK, BALCONY),
	("LadderStairsUpper", 140, BALCONY, BRIDGE_DECK),
	("LadderMast", 178, BRIDGE_DECK, ROOF),
]

# Barrel props: kind, x (middle), floor. Neighbours either touch (12 px apart) or leave
# a fighter's width between them, never a slot a foot could get stuck in.
BARRELS = [
	("explosive", 30, WAREHOUSE),
	("explosive", 189, WAREHOUSE),
	("explosive", 323, WAREHOUSE),
	("plain", 374, WAREHOUSE),
	("explosive", 386, WAREHOUSE),
	("explosive", 509, WAREHOUSE),
	("plain", 268, GROUND),
	("plain", 314, GROUND),
	("plain", 326, GROUND),
	("explosive", 454, GROUND),
	("explosive", 466, GROUND),
	("plain", 432, CABIN_LOWER),
]

# Spawn points: name, x, feet y.
SPAWNS = [
	("P1", 52, GROUND),
	("P2", 601, GROUND),
	("P3", 313, CABIN_LOWER),
	("P4", 133, WAREHOUSE),
	("P5", 560, WAREHOUSE),
	("P6", 403, DECK),
]

# Item spawners: name, x, feet y, pool.
ITEMS = [
	("GroundWest", 120, GROUND, "mixed"),
	("GroundEast", 520, GROUND, "mixed"),
	("Warehouse", 349, WAREHOUSE, "mixed"),
	("CabinUpper", 290, CABIN_UPPER, "mixed"),
	("CabinLower", 394, CABIN_LOWER, "mixed"),
	("Deck", 65, DECK, "mixed"),
	("BridgeRoof", 155, ROOF, "sniper"),
]

WALL = 16
PLATFORM_THICKNESS = 6
# Items float this far over the floor, as in the test arena.
ITEM_LIFT = 8


def write_layout() -> None:
	LAYOUT.parent.mkdir(parents=True, exist_ok=True)
	LAYOUT.write_text(json.dumps({
		"ground_y": GROUND, "warehouse_y": WAREHOUSE, "quay_y": QUAY, "deck_y": DECK, "keel_y": KEEL,
		"cabin_west": CABIN_WEST, "cabin_east": CABIN_EAST, "cabin_upper_y": CABIN_UPPER, "cabin_lower_y": CABIN_LOWER,
		"balcony_y": BALCONY, "bridge_deck_y": BRIDGE_DECK, "roof_y": ROOF,
		"ladders": [{"x": x, "bottom": bottom, "top": top} for _, x, bottom, top in LADDERS],
	}, indent=1), encoding="utf-8")


def draw() -> None:
	result = subprocess.run(
		[str(ASEPRITE), "-b", "--script-param", f"root={ROOT.as_posix()}", "--script", str(ROOT / "tools" / "draw_shipyard.lua")],
		capture_output=True, text=True,
	)
	# Aseprite's own extensions may complain in batch mode; only the script's result counts.
	if "drew the Shipyard" not in result.stdout:
		raise SystemExit(f"Aseprite failed:\n{result.stdout}\n{result.stderr}")


def build_scene() -> None:
	ext = [
		("Script", "res://scenes/arenas/arena.gd", "arena"),
		("Script", "res://scenes/arenas/follow_camera.gd", "camera"),
		("Texture2D", "res://assets/arenas/shipyard/background.png", "art"),
		("PackedScene", "res://scenes/props/ladder.tscn", "ladder"),
		("PackedScene", "res://scenes/props/explosive_drum.tscn", "explosive"),
		("PackedScene", "res://scenes/props/oil_drum.tscn", "plain"),
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

	def body(name: str, left: int, top: int, right: int, bottom: int, one_way: bool) -> None:
		sid = f"shape_{name}"
		subs.append(f'[sub_resource type="RectangleShape2D" id="{sid}"]\nsize = Vector2({right - left}, {bottom - top})\n')
		nodes.append(f'[node name="{name}" type="StaticBody2D" parent="Collision"]\nposition = Vector2({(left + right) / 2}, {(top + bottom) / 2})\n')
		props = f'shape = SubResource("{sid}")\n'
		if one_way:
			props += "one_way_collision = true\n"
		nodes.append(f'[node name="CollisionShape2D" type="CollisionShape2D" parent="Collision/{name}"]\n{props}')

	nodes.append(
		'[node name="Shipyard" type="Node2D"]\n'
		'script = ExtResource("arena")\n'
		f"bounds = Rect2(-64, -360, {MAP[0] + 128}, {MAP[1] + 424})\n"
		f"camera_limits = Rect2(0, 0, {MAP[0]}, {MAP[1]})\n"
	)
	# Pixel art: drawn unfiltered, so each art pixel stays a sharp block at zoom 3.
	nodes.append(
		'[node name="Background" type="Sprite2D" parent="."]\n'
		'texture_filter = 1\ntexture = ExtResource("art")\ncentered = false\n'
	)

	nodes.append('[node name="Collision" type="Node2D" parent="."]\n')
	for name, left, top, right, bottom in SOLIDS:
		body(name, left, top, right, bottom, False)
	for name, left, right, top in PLATFORMS:
		body(name, left, top, right, top + PLATFORM_THICKNESS, True)
	body("WallWest", -WALL, -360, 0, GROUND, False)
	body("WallEast", MAP[0], -360, MAP[0] + WALL, GROUND, False)

	nodes.append('[node name="Props" type="Node2D" parent="."]\n')
	for name, x, bottom, top in LADDERS:
		nodes.append(
			f'[node name="{name}" parent="Props" instance=ExtResource("ladder")]\n'
			f"position = Vector2({x}, {bottom})\nheight = {float(bottom - top)}\nplaceholder = false\n"
		)
	for i, (kind, x, floor) in enumerate(BARRELS):
		nodes.append(f'[node name="Barrel{i + 1}" parent="Props" instance=ExtResource("{kind}")]\nposition = Vector2({x}, {floor})\n')

	nodes.append('[node name="SpawnPoints" type="Node2D" parent="."]\n')
	for name, x, y in SPAWNS:
		nodes.append(f'[node name="{name}" type="Marker2D" parent="SpawnPoints"]\nposition = Vector2({x}, {y})\n')

	nodes.append('[node name="ItemSpawns" type="Node2D" parent="."]\n')
	for name, x, y, pool in ITEMS:
		items = ", ".join(f'ExtResource("{i}")' for i in pools[pool])
		nodes.append(
			f'[node name="{name}" type="Marker2D" parent="ItemSpawns"]\n'
			f"position = Vector2({x}, {y - ITEM_LIFT})\n"
			'script = ExtResource("spawner")\n'
			f'items = Array[ExtResource("item_data")]([{items}])\n'
		)

	# The whole map is one zoom-3 view, so the camera needs no other shots.
	nodes.append(
		'[node name="Camera2D" type="Camera2D" parent="."]\n'
		f"position = Vector2({MAP[0] / 2}, {MAP[1] / 2})\n"
		'script = ExtResource("camera")\n'
	)

	header = f"[gd_scene load_steps={len(ext) + len(subs) + 1} format=3]\n"
	ext_lines = "".join(f'[ext_resource type="{t}" path="{p}" id="{i}"]\n' for t, p, i in ext)
	OUT.write_text(header + "\n" + ext_lines + "\n" + "\n".join(subs) + "\n" + "\n".join(nodes), encoding="utf-8", newline="\n")


def main() -> None:
	write_layout()
	draw()
	build_scene()
	print(f"drew the art and wrote {OUT}")


if __name__ == "__main__":
	main()
