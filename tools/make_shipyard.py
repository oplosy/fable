"""Builds the Shipyard map from the user's reference art (art/shipyard/reference.png, 2000x1116).

1. Paints the barrels out of the picture (each filled from the best matching stretch of the
   same rows) and cuts the map's part of it into assets/arenas/shipyard/background.png.
2. Cuts one explosive and one plain barrel out of the picture into assets/props/.
3. Writes scenes/arenas/shipyard.tscn: collision, ladders, barrel props, spawns, items.

The picture is drawn at SCALE world px per art px, the scale at which its barrels are the
game's 12x18 barrels and its doors fit a 28 px fighter; CROP is the 640x360 map's part of
it. Everything below is measured in art px on the reference; edit it here and rerun:

    python tools/make_shipyard.py
"""

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
REFERENCE = ROOT / "art" / "shipyard" / "reference.png"
BACKGROUND = ROOT / "assets" / "arenas" / "shipyard" / "background.png"
PROPS = ROOT / "assets" / "props"
OUT = ROOT / "scenes" / "arenas" / "shipyard.tscn"

SCALE = 0.45
MAP = (640, 360)
# Left and top of the map's part of the picture (art px); it spans MAP / SCALE.
CROP = (305, 180)

# One-way platforms: name, left, right, top.
PLATFORMS = [
	("Warehouse", 0, 1850, 821),
	("QuayWest", 0, 370, 498),
	("QuayEast", 1665, 2000, 498),
	("Deck", 352, 1700, 397),
	("CabinUpper", 675, 1352, 529),
	("CabinLower", 675, 1350, 629),
	("BridgeBalcony", 453, 675, 344),
	("BridgeDeck", 486, 727, 298),
	("BridgeRoof", 605, 738, 248),
]

# Solid blocks: name, left, top, right, bottom.
SOLIDS = [
	("Ground", 0, 957, 2000, 1116),
	("CabinWallWest", 663, 405, 675, 640),
	("CabinWallEast", 1350, 405, 1362, 640),
]

# Ladders: name, x, bottom, top; drawn says whether the art already shows it.
LADDERS = [
	("LadderGroundMid", 960, 957, 821, True),
	("LadderGroundEast", 1250, 957, 821, True),
	("LadderGroundFar", 1521, 957, 821, True),
	("LadderQuayWest", 330, 821, 498, False),
	("LadderSternWest", 362, 498, 397, False),
	("LadderQuayEast", 1712, 821, 498, False),
	("LadderBowEast", 1688, 498, 397, False),
	("LadderKeelWest", 760, 821, 629, False),
	("LadderKeelEast", 1300, 821, 629, False),
	("LadderHatch", 825, 529, 397, True),
	("LadderCabin", 825, 629, 529, True),
	("LadderCabinEast", 1092, 629, 529, True),
	("LadderStairs", 616, 397, 344, True),
	("LadderStairsUpper", 616, 344, 298, True),
	("LadderMast", 700, 298, 248, False),
]

# Barrels painted out of the picture: left, top, right, bottom (bottom on the floor).
PAINTED_BARRELS = [
	(283, 762, 340, 821),  # two gas bottles and an explosive barrel
	(356, 781, 387, 821),
	(710, 781, 741, 821),
	(1010, 782, 1035, 821),
	(1118, 781, 1152, 821),
	(1161, 781, 1187, 821),
	(1406, 781, 1452, 821),
	(878, 928, 922, 956),  # a barrel lying on its side
	(983, 897, 1024, 956),  # a stack of grey drums
	(1028, 918, 1064, 956),
	(1298, 916, 1360, 956),
	(1250, 594, 1278, 628),
]

# Barrel props: kind, x (middle), floor. Neighbours either touch (12 world px apart) or
# leave a fighter's width between them, never a slot a foot could get stuck in.
BARRELS = [
	("explosive", 371, 821),
	("explosive", 725, 821),
	("explosive", 1022, 821),
	("plain", 1135, 821),
	("explosive", 1162, 821),
	("explosive", 1437, 821),
	("plain", 900, 957),
	("plain", 1003, 957),
	("plain", 1030, 957),
	("explosive", 1315, 957),
	("explosive", 1342, 957),
	("plain", 1264, 629),
]

# Barrel art cut from the picture: kind, left, top, right, bottom.
BARREL_ART = [
	("explosive", 711, 782, 740, 822),
	("plain", 1029, 919, 1063, 957),
]

# Spawn points: name, x, feet y.
SPAWNS = [
	("P1", 420, 957),
	("P2", 1640, 957),
	("P3", 1000, 629),
	("P4", 600, 821),
	("P5", 1550, 821),
	("P6", 1200, 397),
]

# Item spawners: name, x, feet y, pool.
ITEMS = [
	("GroundWest", 640, 957, "mixed"),
	("GroundEast", 1420, 957, "mixed"),
	("Warehouse", 1080, 821, "mixed"),
	("CabinUpper", 950, 529, "mixed"),
	("CabinLower", 1180, 629, "mixed"),
	("Deck", 450, 397, "mixed"),
	("BridgeRoof", 650, 248, "sniper"),
]

WALL = 16
PLATFORM_THICKNESS = 6
# Items float this far (world px) over the floor, as in the test arena.
ITEM_LIFT = 8
# Width (art px) of the frame around a painted-out barrel matched against other spots.
RING = 4
# How far (art px) along its rows a painted-out barrel looks for its fill.
SEARCH = 400
# Barrel outlines are darker than this (0-255 sum of RGB / 3); the art around them is cut away.
OUTLINE = 34


def wx(art: float) -> int:
	return round((art - CROP[0]) * SCALE)


def wy(art: float) -> int:
	return round((art - CROP[1]) * SCALE)


def paint_out(picture: np.ndarray) -> np.ndarray:
	"""Fills every PAINTED_BARRELS box with the stretch of the same rows whose frame matches best."""
	out = picture.copy()
	blocked = np.zeros(picture.shape[:2], bool)
	for left, top, right, bottom in PAINTED_BARRELS:
		blocked[top - RING:bottom, left - RING:right + RING] = True
	for left, top, right, bottom in PAINTED_BARRELS:
		frame = np.zeros(picture.shape[:2], bool)
		frame[top - RING:bottom, left - RING:right + RING] = True
		frame[top:bottom, left:right] = False
		ys, xs = np.nonzero(frame)
		target = picture[ys, xs].astype(float)
		best, best_dx = None, 0
		for dx in range(-SEARCH, SEARCH + 1):
			l, r = left + dx - RING, right + dx + RING
			if abs(dx) < right - left + RING or l < 0 or r > picture.shape[1]:
				continue
			if blocked[top - RING:bottom, l:r].any():
				continue
			cost = ((picture[ys, xs + dx].astype(float) - target) ** 2).sum()
			if best is None or cost < best:
				best, best_dx = cost, dx
		out[top:bottom, left:right] = picture[top:bottom, left + best_dx:right + best_dx]
	return out


def cut_barrel(picture: np.ndarray, left: int, top: int, right: int, bottom: int) -> Image.Image:
	"""The barrel inside its outline on each row, with the art around it see-through."""
	part = picture[top:bottom, left:right]
	dark = part.mean(axis=2) < OUTLINE
	alpha = np.zeros(dark.shape, np.uint8)
	for row in range(dark.shape[0]):
		cols = np.nonzero(dark[row])[0]
		if cols.size:
			alpha[row, cols[0]:cols[-1] + 1] = 255
	return Image.fromarray(np.dstack([part, alpha]), "RGBA")


def build_art() -> dict[str, tuple[int, int]]:
	picture = np.array(Image.open(REFERENCE).convert("RGB"))
	painted = paint_out(picture)
	size = (round(MAP[0] / SCALE), round(MAP[1] / SCALE))
	crop = painted[CROP[1]:CROP[1] + size[1], CROP[0]:CROP[0] + size[0]]
	BACKGROUND.parent.mkdir(parents=True, exist_ok=True)
	Image.fromarray(crop).save(BACKGROUND)
	PROPS.mkdir(parents=True, exist_ok=True)
	sizes = {}
	for kind, left, top, right, bottom in BARREL_ART:
		cut_barrel(picture, left, top, right, bottom).save(PROPS / f"{kind}_barrel.png")
		sizes[kind] = (right - left, bottom - top)
	return sizes


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
		left, right = max(left, -WALL), min(right, MAP[0] + WALL)
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
	nodes.append(
		'[node name="Background" type="Sprite2D" parent="."]\n'
		f'texture = ExtResource("art")\ncentered = false\nscale = Vector2({SCALE}, {SCALE})\n'
	)

	nodes.append('[node name="Collision" type="Node2D" parent="."]\n')
	for name, left, top, right, bottom in SOLIDS:
		body(name, wx(left), wy(top), wx(right), wy(bottom), False)
	for name, left, right, top in PLATFORMS:
		body(name, wx(left), wy(top), wx(right), wy(top) + PLATFORM_THICKNESS, True)
	ground = wy(957)
	body("WallWest", -WALL, -360, 0, ground, False)
	body("WallEast", MAP[0], -360, MAP[0] + WALL, ground, False)

	nodes.append('[node name="Props" type="Node2D" parent="."]\n')
	for name, x, bottom, top, drawn in LADDERS:
		props = f"position = Vector2({wx(x)}, {wy(bottom)})\nheight = {float(wy(bottom) - wy(top))}\n"
		if drawn:
			props += "placeholder = false\n"
		nodes.append(f'[node name="{name}" parent="Props" instance=ExtResource("ladder")]\n{props}')
	for i, (kind, x, floor) in enumerate(BARRELS):
		nodes.append(f'[node name="Barrel{i + 1}" parent="Props" instance=ExtResource("{kind}")]\nposition = Vector2({wx(x)}, {wy(floor)})\n')

	nodes.append('[node name="SpawnPoints" type="Node2D" parent="."]\n')
	for name, x, y in SPAWNS:
		nodes.append(f'[node name="{name}" type="Marker2D" parent="SpawnPoints"]\nposition = Vector2({wx(x)}, {wy(y)})\n')

	nodes.append('[node name="ItemSpawns" type="Node2D" parent="."]\n')
	for name, x, y, pool in ITEMS:
		items = ", ".join(f'ExtResource("{i}")' for i in pools[pool])
		nodes.append(
			f'[node name="{name}" type="Marker2D" parent="ItemSpawns"]\n'
			f"position = Vector2({wx(x)}, {wy(y) - ITEM_LIFT})\n"
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
	sizes = build_art()
	build_scene()
	for kind, (width, height) in sizes.items():
		print(f"{kind} barrel art {width}x{height} -> {width * SCALE:.1f}x{height * SCALE:.1f} world px")
	print(f"wrote {BACKGROUND}, {PROPS} and {OUT}")


if __name__ == "__main__":
	main()
