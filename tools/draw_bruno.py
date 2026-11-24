"""Draws Bruno, the street brawler, as SVG cutout parts and writes his rig.json.

Run from the project root: python tools/draw_bruno.py
Every part shares one 200x240 canvas (5 art px per world px, so 1 art px is 1 screen px
at camera zoom 5). He stands three-quarter facing right with his feet pixel at (100, 232).
Each part is a silhouette with a 3 px outline, a flat base colour, one cel shade from the
upper front light, and detail lines. Limbs are capsules whose round ends sit on the joints,
so a child rotating on its parent's cap never opens a gap.
"""

import json
import math
from pathlib import Path

OUT = Path("assets/characters/bruno")
CANVAS = (200, 240)
FEET = (100, 232)
OUTLINE = "#2a1f2b"
LINE = 3.0

# Front colours, then the back limbs one shade darker.
SKIN, SKIN_SHADE = "#e3a97a", "#b97b54"
SKIN_BACK, SKIN_BACK_SHADE = "#c48f66", "#9c6745"
TANK, TANK_SHADE = "#f2ede4", "#cfc5b5"
JEANS, JEANS_SHADE, CUFF = "#33407a", "#232d5a", "#4f62a3"
JEANS_BACK, JEANS_BACK_SHADE, CUFF_BACK = "#283265", "#1b2348", "#3f5089"
RED, RED_SHADE = "#cc3138", "#8e1e28"
RED_BACK, RED_BACK_SHADE = "#a9272f", "#741822"
SOLE, SOLE_BACK = "#f2ede4", "#cfc5b5"
HAIR, HAIR_SHADE = "#3a3035", "#251e22"
BELT = "#4a3328"
STUBBLE = "#6e5040"
SCAR = "#f3cfae"

PIVOTS = {
    "pelvis": (100, 178),
    "torso": (100, 174),
    "head": (102, 130),
    "arm_front_upper": (118, 136),
    "arm_front_lower": (122, 157),
    "hand_front": (124, 175),
    "arm_back_upper": (82, 136),
    "arm_back_lower": (80, 157),
    "hand_back": (80, 175),
    "leg_front_upper": (108, 184),
    "leg_front_lower": (110, 205),
    "foot_front": (110, 222),
    "leg_back_upper": (92, 184),
    "leg_back_lower": (90, 205),
    "foot_back": (90, 222),
}
POINTS = {"hand_front": (125, 183), "hand_back": (81, 183), "head_top": (103, 70)}
DRAW_ORDER = [
    "arm_back_upper", "arm_back_lower", "hand_back",
    "leg_back_upper", "leg_back_lower", "foot_back",
    "pelvis",
    "leg_front_upper", "leg_front_lower", "foot_front",
    "torso", "head",
    "arm_front_upper", "arm_front_lower", "hand_front",
]
HIERARCHY = {
    "pelvis": "", "torso": "pelvis", "head": "torso",
    "arm_front_upper": "torso", "arm_front_lower": "arm_front_upper", "hand_front": "arm_front_lower",
    "arm_back_upper": "torso", "arm_back_lower": "arm_back_upper", "hand_back": "arm_back_lower",
    "leg_front_upper": "pelvis", "leg_front_lower": "leg_front_upper", "foot_front": "leg_front_lower",
    "leg_back_upper": "pelvis", "leg_back_lower": "leg_back_upper", "foot_back": "leg_back_lower",
}


def capsule(a, b, width):
    """Closed path of a bone from a to b, `width` thick, with round ends on both joints."""
    (ax, ay), (bx, by) = a, b
    angle = math.atan2(by - ay, bx - ax)
    r = width / 2.0
    nx, ny = -math.sin(angle) * r, math.cos(angle) * r
    return (f"M{ax + nx:.2f},{ay + ny:.2f} L{bx + nx:.2f},{by + ny:.2f} "
            f"A{r},{r} 0 0 0 {bx - nx:.2f},{by - ny:.2f} L{ax - nx:.2f},{ay - ny:.2f} "
            f"A{r},{r} 0 0 0 {ax + nx:.2f},{ay + ny:.2f} Z")


def svg(body):
    w, h = CANVAS
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">\n'
            f"{body}</svg>\n")


def figure(name, silhouette, base, shade=None, details=""):
    """A part: outline under the silhouette, base fill, the shade clipped to it, details."""
    shade_layer = ""
    if shade:
        shade_layer = (f'<clipPath id="{name}_clip"><path d="{silhouette}"/></clipPath>\n'
                       f'<g clip-path="url(#{name}_clip)">{shade}</g>\n')
    return (f'<path d="{silhouette}" fill="{OUTLINE}" stroke="{OUTLINE}" stroke-width="{LINE * 2}" stroke-linejoin="round"/>\n'
            f'<path d="{silhouette}" fill="{base}"/>\n'
            f"{shade_layer}{details}")


def line(d, colour=OUTLINE, width=2.0):
    return f'<path d="{d}" fill="none" stroke="{colour}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>\n'


def offset_shade(silhouette, colour, dx, dy):
    """The silhouette shifted away from the light: what is left uncovered reads as shade."""
    return f'<path d="{silhouette}" fill="{colour}" transform="translate({dx},{dy})"/>\n'


def limb(name, a, b, width, base, shade):
    sil = capsule(a, b, width)
    # Light from the upper front (right): the back (left) edge falls in shade.
    shade_layer = f'<rect x="0" y="0" width="200" height="240" fill="{shade}"/>' + \
        f'<path d="{capsule((a[0] + 4, a[1]), (b[0] + 4, b[1]), width)}" fill="{base}"/>'
    return figure(name, sil, base, shade_layer)


def arm_upper(side):
    front = side == "front"
    a, b = PIVOTS[f"arm_{side}_upper"], PIVOTS[f"arm_{side}_lower"]
    return limb(f"arm_{side}_upper", a, b, 19, SKIN if front else SKIN_BACK, SKIN_SHADE if front else SKIN_BACK_SHADE)


def arm_lower(side):
    front = side == "front"
    a, b = PIVOTS[f"arm_{side}_lower"], PIVOTS[f"hand_{side}"]
    skin, skin_shade = (SKIN, SKIN_SHADE) if front else (SKIN_BACK, SKIN_BACK_SHADE)
    red, red_shade = (RED, RED_SHADE) if front else (RED_BACK, RED_BACK_SHADE)
    sil = capsule(a, b, 18)
    # Hand wraps cover the forearm from a little below the elbow.
    wrap_top = a[1] + 7
    shade = (f'<rect x="0" y="0" width="200" height="240" fill="{skin_shade}"/>'
             f'<path d="{capsule((a[0] + 4, a[1]), (b[0] + 4, b[1]), 18)}" fill="{skin}"/>'
             f'<rect x="0" y="{wrap_top}" width="200" height="60" fill="{red_shade}"/>'
             f'<path d="{capsule((a[0] + 4, wrap_top + 8), (b[0] + 4, b[1]), 18)}" fill="{red}"/>')
    details = line(f"M{a[0] - 9},{wrap_top} L{a[0] + 11},{wrap_top + 2}")
    for y in (wrap_top + 6, wrap_top + 12):
        details += line(f"M{a[0] - 7},{y} L{a[0] + 11},{y + 3}", red_shade, 1.5)
    return figure(f"arm_{side}_lower", sil, skin, shade, details)


def hand(side):
    front = side == "front"
    x, y = POINTS[f"hand_{side}"]
    red, red_shade = (RED, RED_SHADE) if front else (RED_BACK, RED_BACK_SHADE)
    sil = f"M{x - 10},{y - 7} Q{x - 10},{y - 10} {x - 6},{y - 10} L{x + 6},{y - 10} Q{x + 11},{y - 10} {x + 11},{y - 5} " \
          f"L{x + 11},{y + 5} Q{x + 11},{y + 9} {x + 6},{y + 9} L{x - 5},{y + 9} Q{x - 10},{y + 9} {x - 10},{y + 5} Z"
    shade = f'<rect x="{x - 12}" y="{y + 4}" width="26" height="8" fill="{red_shade}"/>'
    # Knuckle creases on the front of the fist.
    details = "".join(line(f"M{x + k},{y - 9} L{x + k},{y - 3}", red_shade, 1.5) for k in (0, 4, 8))
    return figure(f"hand_{side}", sil, red, shade, details)


def leg_upper(side):
    front = side == "front"
    a, b = PIVOTS[f"leg_{side}_upper"], PIVOTS[f"leg_{side}_lower"]
    return limb(f"leg_{side}_upper", a, b, 21, JEANS if front else JEANS_BACK, JEANS_SHADE if front else JEANS_BACK_SHADE)


def leg_lower(side):
    front = side == "front"
    a, b = PIVOTS[f"leg_{side}_lower"], PIVOTS[f"foot_{side}"]
    jeans, shade_c, cuff = (JEANS, JEANS_SHADE, CUFF) if front else (JEANS_BACK, JEANS_BACK_SHADE, CUFF_BACK)
    sil = capsule(a, (b[0], b[1] + 2), 19)
    shade = (f'<rect x="0" y="0" width="200" height="240" fill="{shade_c}"/>'
             f'<path d="{capsule((a[0] + 4, a[1]), (b[0] + 4, b[1] + 2), 19)}" fill="{jeans}"/>'
             f'<rect x="0" y="{b[1] - 6}" width="200" height="20" fill="{cuff}"/>')
    details = line(f"M{b[0] - 9},{b[1] - 6} L{b[0] + 9},{b[1] - 6}")
    return figure(f"leg_{side}_lower", sil, jeans, shade, details)


def foot(side):
    front = side == "front"
    x, y = PIVOTS[f"foot_{side}"]
    red, red_shade, sole = (RED, RED_SHADE, SOLE) if front else (RED_BACK, RED_BACK_SHADE, SOLE_BACK)
    ground = FEET[1]
    # High-top: the collar wraps the ankle, the shoe runs forward to a rounded toe.
    sil = (f"M{x - 10},{y - 7} L{x + 8},{y - 7} L{x + 10},{y + 1} Q{x + 21},{y + 1} {x + 24},{ground - 5} "
           f"Q{x + 25},{ground} {x + 19},{ground} L{x - 10},{ground} Q{x - 12},{ground} {x - 12},{ground - 3} Z")
    shade = f'<rect x="{x - 12}" y="{y - 8}" width="7" height="20" fill="{red_shade}"/>'
    details = (f'<path d="M{x - 12},{ground - 4} L{x + 25},{ground - 4} L{x + 25},{ground} L{x - 12},{ground} Z" fill="{sole}"/>\n'
               + line(f"M{x - 12},{ground - 4} L{x + 24},{ground - 4}")
               + line(f"M{x - 2},{y - 3} L{x + 4},{y + 5}", red_shade, 1.5)
               + line(f"M{x + 4},{y - 3} L{x - 1},{y + 5}", red_shade, 1.5))
    return figure(f"foot_{side}", sil, red, shade, details)


def pelvis():
    sil = "M82,170 Q82,166 86,166 L116,166 Q120,166 120,170 L121,190 Q121,194 117,194 L85,194 Q81,194 81,190 Z"
    shade = f'<rect x="78" y="164" width="14" height="34" fill="{JEANS_SHADE}"/>'
    details = (f'<rect x="82" y="167" width="38" height="5" fill="{BELT}"/>\n'
               + line("M82,172 L120,172", OUTLINE, 1.5)
               + f'<rect x="108" y="166" width="7" height="7" rx="1" fill="#c9a24a" stroke="{OUTLINE}" stroke-width="1.5"/>\n')
    return figure("pelvis", sil, JEANS, shade, details)


def torso():
    # Broad shoulders tapering to the waist; the tank's scoop shows the neck and chest.
    sil = ("M84,180 L78,152 Q70,136 82,129 Q92,125 100,126 Q112,125 122,128 Q134,134 128,152 "
           "L120,180 Q100,184 84,180 Z")
    shade = f'<path d="M70,120 L94,124 Q88,150 92,186 L70,186 Z" fill="{TANK_SHADE}"/>'
    details = (f'<path d="M93,128 Q102,144 113,129 Q104,131 93,128 Z" fill="{SKIN}" stroke="{OUTLINE}" stroke-width="2" stroke-linejoin="round"/>\n'
               + line("M106,154 Q112,158 118,155", TANK_SHADE, 2)
               + line("M88,176 Q100,179 116,176", TANK_SHADE, 2))
    return figure("torso", sil, TANK, shade, details)


def head():
    # Neck, then a big square head with a heavy jaw, facing right.
    neck = f'<path d="M94,122 L110,122 L110,136 L94,136 Z" fill="{SKIN_SHADE}" stroke="{OUTLINE}" stroke-width="{LINE * 2}" stroke-linejoin="round"/>\n' \
           f'<path d="M94,122 L110,122 L110,136 L94,136 Z" fill="{SKIN_SHADE}"/>\n'
    sil = ("M78,84 Q78,70 94,70 L120,70 Q134,70 134,86 L134,100 L139,106 L135,110 L134,118 "
           "Q134,130 122,131 L92,131 Q78,131 77,118 Z")
    shade = (f'<path d="M70,60 L92,60 Q86,96 92,140 L70,140 Z" fill="{SKIN_SHADE}"/>'
             f'<path d="M96,112 Q112,118 134,110 L140,140 L90,140 Z" fill="{STUBBLE}" fill-opacity="0.45"/>')
    hair = (f'<path d="M78,90 Q77,70 94,69 L121,69 Q135,70 134,84 Q124,78 114,80 Q100,77 92,84 Q86,88 84,96 Z" '
            f'fill="{HAIR}" stroke="{OUTLINE}" stroke-width="2" stroke-linejoin="round"/>\n'
            f'<path d="M80,88 Q80,74 92,72 Q86,80 86,92 Z" fill="{HAIR_SHADE}"/>\n')
    ear = (f'<path d="M84,96 Q76,96 77,106 Q78,114 86,113 Z" fill="{SKIN}" stroke="{OUTLINE}" stroke-width="2" stroke-linejoin="round"/>\n'
           + line("M82,101 Q80,106 83,109", SKIN_SHADE, 1.5))
    face = (f'<path d="M112,91 L131,93 L130,98 L113,96 Z" fill="{HAIR}" stroke="{OUTLINE}" stroke-width="1.5" stroke-linejoin="round"/>\n'
            f'<ellipse cx="123" cy="103" rx="3" ry="4" fill="{OUTLINE}"/>\n'
            f'<circle cx="124" cy="101.5" r="1.2" fill="#ffffff"/>\n'
            + line("M127,88 L130,99", SCAR, 2)
            + line("M120,121 L131,120", OUTLINE, 2)
            + line("M134,100 L139,106 L135,110", OUTLINE, 2))
    return neck + figure("head", sil, SKIN, shade, hair + ear + face)


PARTS = {
    "pelvis": pelvis, "torso": torso, "head": head,
    "arm_front_upper": lambda: arm_upper("front"), "arm_front_lower": lambda: arm_lower("front"), "hand_front": lambda: hand("front"),
    "arm_back_upper": lambda: arm_upper("back"), "arm_back_lower": lambda: arm_lower("back"), "hand_back": lambda: hand("back"),
    "leg_front_upper": lambda: leg_upper("front"), "leg_front_lower": lambda: leg_lower("front"), "foot_front": lambda: foot("front"),
    "leg_back_upper": lambda: leg_upper("back"), "leg_back_lower": lambda: leg_lower("back"), "foot_back": lambda: foot("back"),
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, draw in PARTS.items():
        (OUT / f"{name}.svg").write_text(svg(draw()), encoding="utf-8")
    rig = {
        "character": "bruno",
        "canvas": list(CANVAS),
        "feet": list(FEET),
        "draw_order": DRAW_ORDER,
        "hierarchy": HIERARCHY,
        "pivots": {k: list(v) for k, v in PIVOTS.items()},
        "points": {k: list(v) for k, v in POINTS.items()},
    }
    (OUT / "rig.json").write_text(json.dumps(rig, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {len(PARTS)} parts to {OUT}")


if __name__ == "__main__":
    main()
