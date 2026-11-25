"""Draws Bruno, the street brawler, as SVG cutout parts and writes his rig.json.

Run from the project root: python tools/draw_bruno.py
He stands three-quarter view facing right: the near arm and leg (left on screen) are the
rig's "front" limbs and draw over the body, the far ones draw behind it.
Shapes are written in design units on a 420x560 canvas and every SVG is emitted at
SCALE, so the textures and rig.json are in art pixels at 5 art px per world px (the
closest camera zoom shows them 1:1). All parts share the canvas, so pivots are canvas points.

Look (user's reference, session 13): thick dark outline, 2-3 cel tones per colour with the
light from the upper right, a rim highlight on the lit edge, layered costume, big eyes.
Limbs are tapered capsules whose round ends sit on the joints, so a child turning on its
parent's cap never opens a gap.
"""

import json
import math
from pathlib import Path

OUT = Path("assets/characters/bruno")
DESIGN = (420, 560)
SCALE = 0.3
FEET = (212, 546)
OUTLINE = "#1d1a2b"
EDGE = 6.0

SKIN, SKIN_S, SKIN_D, SKIN_H = "#f2bb8e", "#d68a62", "#a9603f", "#ffdcbc"
HAIR_T, HAIR_B, HAIR_S, HAIR_H = "#55406a", "#2a1f36", "#1a1324", "#8a72ad"
TANK, TANK_S = "#f5f2ec", "#cdc5d8"
VEST, VEST_S, VEST_D, VEST_H = "#c8323f", "#8f1f35", "#5c1328", "#f06464"
JEAN, JEAN_S, JEAN_D, JEAN_H = "#3d52a0", "#2b3a7a", "#1d2756", "#6a83d2"
WRAP, WRAP_S, WRAP_H = "#d9343f", "#99202f", "#ff7a7a"
GLOVE, GLOVE_S, GLOVE_H = "#34304a", "#1f1c2e", "#6d6890"
SHOE, SHOE_S, SHOE_H = "#d9343f", "#99202f", "#ff6a6a"
SOLE, SOLE_S = "#f5f2ec", "#bdb3c6"
BELT, BELT_S, GOLD, GOLD_S = "#5b3a2b", "#3b2419", "#f3c64b", "#b9862a"
IRIS, IRIS_S = "#e39a2c", "#8a4a12"
# The far limbs sit in the body's shadow.
FAR_DIM = 0.22

# Joint centres and cap radii (design units).
ARM = {
    "front": {"shoulder": (142, 288, 22), "elbow": (138, 346, 17), "wrist": (143, 390, 15)},
    "back": {"shoulder": (284, 288, 20), "elbow": (290, 346, 16), "wrist": (289, 390, 14)},
}
LEG = {
    "front": {"hip": (188, 418, 26), "knee": (190, 466, 22), "ankle": (190, 500, 19)},
    "back": {"hip": (244, 418, 25), "knee": (246, 464, 21), "ankle": (246, 496, 18)},
}
PIVOTS = {
    "pelvis": (215, 402),
    "torso": (215, 392),
    "head": (210, 250),
    **{f"arm_{s}_upper": ARM[s]["shoulder"][:2] for s in ARM},
    **{f"arm_{s}_lower": ARM[s]["elbow"][:2] for s in ARM},
    **{f"hand_{s}": ARM[s]["wrist"][:2] for s in ARM},
    **{f"leg_{s}_upper": LEG[s]["hip"][:2] for s in LEG},
    **{f"leg_{s}_lower": LEG[s]["knee"][:2] for s in LEG},
    **{f"foot_{s}": LEG[s]["ankle"][:2] for s in LEG},
}
POINTS = {
    "hand_front": (141, 410), "hand_back": (291, 408), "head_top": (205, 12),
    # Where each sneaker's sole meets the floor, for tools/plant_feet.py.
    "heel_front": (152, 546), "toe_front": (252, 544), "heel_back": (222, 540), "toe_back": (306, 538),
}
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


class Part:
    """One part's SVG body: shapes with clipped shading, outlines and detail lines."""

    def __init__(self, name):
        self.name = name
        self.defs = []
        self.body = []
        self.count = 0

    def shape(self, base, fill, shades=(), lines=(), edge=EDGE):
        """A filled shape, its shades clipped inside it, its outline, then inner lines.
        A shade is (path, colour[, opacity])."""
        self.count += 1
        cid = f"{self.name}_{self.count}"
        self.defs.append(f'<clipPath id="{cid}"><path d="{base}"/></clipPath>')
        self.body.append(f'<path d="{base}" fill="{fill}"/>')
        if shades:
            self.body.append(f'<g clip-path="url(#{cid})">')
            for s in shades:
                opacity = s[2] if len(s) > 2 else 1
                self.body.append(f'<path d="{s[0]}" fill="{s[1]}" opacity="{opacity}"/>')
            self.body.append("</g>")
        if edge:
            self.body.append(f'<path d="{base}" fill="none" stroke="{OUTLINE}" stroke-width="{edge}" stroke-linejoin="round"/>')
        for d in lines:
            self.line(d)

    def line(self, d, width=3.0, colour=OUTLINE):
        self.body.append(f'<path d="{d}" fill="none" stroke="{colour}" stroke-width="{width}" '
                         f'stroke-linecap="round" stroke-linejoin="round"/>')

    def raw(self, text):
        self.body.append(text)

    def svg(self):
        w, h = DESIGN
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w * SCALE:g}" height="{h * SCALE:g}" '
                f'viewBox="0 0 {w} {h}"><defs>{"".join(self.defs)}</defs>{"".join(self.body)}</svg>\n')


def taper(a, ra, b, rb):
    """Closed path around two circles (centre a radius ra, centre b radius rb): a limb
    whose round ends sit on its joints."""
    (ax, ay), (bx, by) = a, b
    d = math.dist(a, b)
    theta = math.atan2(by - ay, bx - ax)
    alpha = math.acos(max(-1.0, min(1.0, (ra - rb) / d)))

    def at(c, r, angle):
        return f"{c[0] + r * math.cos(angle):.2f},{c[1] + r * math.sin(angle):.2f}"

    return (f"M{at(a, ra, theta + alpha)} L{at(b, rb, theta + alpha)} "
            f"A{rb},{rb} 0 0 0 {at(b, rb, theta - alpha)} L{at(a, ra, theta - alpha)} "
            f"A{ra},{ra} 0 1 0 {at(a, ra, theta + alpha)} Z")


def shifted(a, ra, b, rb, dx, dy, grow=0.0):
    return taper((a[0] + dx, a[1] + dy), ra + grow, (b[0] + dx, b[1] + dy), rb + grow)


def limb(part, a, ra, b, rb, base, shade, light, far, lines=()):
    """A tapered limb with shading; `base` fills the lit side over the shade."""
    full = f"M0,0 H{DESIGN[0]} V{DESIGN[1]} H0 Z"
    shades: list = [(full, shade), (shifted(a, ra, b, rb, ra * 0.5, -2), base),
              (shifted(a, ra, b, rb, ra * 1.75, -2), light, 0.75)]
    if far:
        shades.append((full, OUTLINE, FAR_DIM))
    part.shape(taper(a, ra, b, rb), base, shades, lines)


def is_far(side):
    return side == "back"


def arm_upper(side):
    p = Part(f"arm_{side}_upper")
    s, e = ARM[side]["shoulder"], ARM[side]["elbow"]
    lines = [] if is_far(side) else [f"M{e[0] - 8},{e[1] - 22} C{e[0] - 2},{e[1] - 18} {e[0] + 4},{e[1] - 18} {e[0] + 10},{e[1] - 22}"]
    limb(p, s[:2], s[2], e[:2], e[2], SKIN, SKIN_S, SKIN_H, is_far(side), lines)
    # The vest's armhole rim rides on the shoulder.
    x, y = s[0], s[1] - 12
    rim = f"M{x - 20},{y + 2} C{x - 12},{y - 10} {x + 10},{y - 12} {x + 22},{y - 2} C{x + 16},{y + 8} {x - 12},{y + 10} {x - 20},{y + 2} Z"
    shades: list = [(f"M0,{y} H{DESIGN[0]} V{DESIGN[1]} H0 Z", VEST_S)]
    if is_far(side):
        shades.append((f"M0,0 H{DESIGN[0]} V{DESIGN[1]} H0 Z", OUTLINE, FAR_DIM))
    p.shape(rim, VEST, shades, edge=5)
    return p


def arm_lower(side):
    p = Part(f"arm_{side}_lower")
    e, w = ARM[side]["elbow"], ARM[side]["wrist"]
    limb(p, e[:2], e[2], w[:2], w[2], SKIN, SKIN_S, SKIN_H, is_far(side))
    # Red hand wraps over the lower forearm.
    top = e[1] + 16
    wrap = taper((e[0] + (w[0] - e[0]) * 0.35, top), e[2] + 1, w[:2], w[2] + 1)
    full = f"M0,0 H{DESIGN[0]} V{DESIGN[1]} H0 Z"
    shades: list = [(full, WRAP_S), (shifted((e[0] + (w[0] - e[0]) * 0.35, top), e[2] + 1, w[:2], w[2] + 1, 8, -2), WRAP),
              (shifted((e[0] + (w[0] - e[0]) * 0.35, top), e[2] + 1, w[:2], w[2] + 1, 26, -2), WRAP_H, 0.7)]
    if is_far(side):
        shades.append((full, OUTLINE, FAR_DIM))
    bands = [f"M{w[0] - 17},{top + 10} L{w[0] + 17},{top + 6}", f"M{w[0] - 17},{top + 22} L{w[0] + 17},{top + 18}"]
    p.shape(wrap, WRAP, shades, bands, edge=5)
    return p


def hand(side):
    p = Part(f"hand_{side}")
    x, y = ARM[side]["wrist"][:2]
    # A fingerless glove balled into a fist below the wrist.
    fist = (f"M{x - 18},{y + 2} C{x - 26},{y + 14} {x - 22},{y + 34} {x - 8},{y + 40} "
            f"C{x + 8},{y + 46} {x + 26},{y + 40} {x + 28},{y + 26} C{x + 30},{y + 12} {x + 24},{y + 2} {x + 14},{y - 2} "
            f"C{x + 4},{y - 6} {x - 10},{y - 4} {x - 18},{y + 2} Z")
    full = f"M0,0 H{DESIGN[0]} V{DESIGN[1]} H0 Z"
    shades: list = [(f"M{x - 30},{y + 18} C{x - 20},{y + 38} {x},{y + 46} {x + 20},{y + 46} L{x + 20},{y + 60} L{x - 30},{y + 60} Z", GLOVE_S),
              (f"M{x - 16},{y + 26} C{x - 4},{y + 30} {x + 10},{y + 30} {x + 22},{y + 26} L{x + 22},{y + 34} C{x + 10},{y + 38} {x - 4},{y + 38} {x - 16},{y + 34} Z", GLOVE_S),
              (f"M{x + 10},{y + 2} C{x + 22},{y + 4} {x + 26},{y + 12} {x + 26},{y + 20} C{x + 20},{y + 12} {x + 14},{y + 8} {x + 6},{y + 6} Z", GLOVE_H, 0.9)]
    if is_far(side):
        shades.append((full, OUTLINE, FAR_DIM))
    knuckles = [f"M{x - 4},{y + 6} C{x},{y + 14} {x},{y + 24} {x - 4},{y + 32}",
                f"M{x + 10},{y + 6} C{x + 14},{y + 14} {x + 14},{y + 24} {x + 10},{y + 32}"]
    p.shape(fist, GLOVE, shades, knuckles)
    return p


def leg_upper(side):
    p = Part(f"leg_{side}_upper")
    h, k = LEG[side]["hip"], LEG[side]["knee"]
    limb(p, h[:2], h[2], k[:2], k[2], JEAN, JEAN_D, JEAN_H, is_far(side))
    return p


def leg_lower(side):
    p = Part(f"leg_{side}_lower")
    k, a = LEG[side]["knee"], LEG[side]["ankle"]
    lines = []
    shades_extra = []
    if not is_far(side):
        # A torn knee with skin showing.
        x, y = k[:2]
        rip = f"M{x - 14},{y - 2} L{x - 6},{y - 8} L{x},{y} L{x + 8},{y - 6} L{x + 14},{y + 2} L{x + 10},{y + 12} L{x + 2},{y + 8} L{x - 4},{y + 16} L{x - 12},{y + 10} Z"
        shades_extra.append((rip, SKIN_S))
        lines = [f"M{x - 14},{y - 2} L{x - 6},{y - 8} L{x},{y} L{x + 8},{y - 6} L{x + 14},{y + 2}",
                 f"M{x - 12},{y + 10} L{x - 4},{y + 16} L{x + 2},{y + 8} L{x + 10},{y + 12}"]
    full = f"M0,0 H{DESIGN[0]} V{DESIGN[1]} H0 Z"
    shades: list = [(full, JEAN_D), (shifted(k, k[2], a, a[2], k[2] * 0.5, -2), JEAN),
              (shifted(k, k[2], a, a[2], k[2] * 1.75, -2), JEAN_H, 0.75)] + shades_extra
    if is_far(side):
        shades.append((full, OUTLINE, FAR_DIM))
    p.shape(taper(k[:2], k[2], a[:2], a[2]), JEAN, shades, lines)
    # Rolled cuff above the shoe.
    x, y, r = a
    cuff = f"M{x - r - 3},{y - 14} L{x + r + 3},{y - 14} L{x + r + 3},{y + 2} L{x - r - 3},{y + 2} Z"
    cuff_shades: list = [(f"M0,{y - 4} H{DESIGN[0]} V{DESIGN[1]} H0 Z", JEAN_S)]
    if is_far(side):
        cuff_shades.append((full, OUTLINE, FAR_DIM))
    p.shape(cuff, JEAN_H, cuff_shades, edge=5)
    return p


def foot(side):
    p = Part(f"foot_{side}")
    x, y, _ = LEG[side]["ankle"]
    heel, toe = POINTS[f"heel_{side}"], POINTS[f"toe_{side}"]
    floor = heel[1]
    # A chunky red high-top: collar round the ankle, toe forward to the right.
    shoe = (f"M{x - 26},{y - 6} L{x + 22},{y - 6} C{x + 30},{y + 6} {x + 42},{y + 12} {toe[0] - 8},{floor - 30} "
            f"C{toe[0] + 2},{floor - 26} {toe[0] + 4},{floor - 14} {toe[0] - 2},{floor - 8} L{heel[0] + 2},{floor - 8} "
            f"C{heel[0] - 2},{floor - 24} {x - 32},{y + 4} {x - 26},{y - 6} Z")
    full = f"M0,0 H{DESIGN[0]} V{DESIGN[1]} H0 Z"
    shades: list = [(f"M0,{floor - 22} H{DESIGN[0]} V{DESIGN[1]} H0 Z", SHOE_S),
              (f"M{x - 16},{y} C{x + 4},{y + 6} {x + 24},{y + 12} {x + 42},{y + 18} C{x + 24},{y + 8} {x + 6},{y + 2} {x - 8},{y - 2} Z", SHOE_H, 0.8)]
    if is_far(side):
        shades.append((full, OUTLINE, FAR_DIM))
    laces = [f"M{x - 10},{y + 2} L{x + 6},{y + 16}", f"M{x + 4},{y + 2} L{x - 10},{y + 16}",
             f"M{x + 14},{y + 8} L{x + 26},{y + 20}", f"M{x + 24},{y + 8} L{x + 14},{y + 20}"]
    p.shape(shoe, SHOE, shades)
    for d in laces:
        p.line(d, 3.0, SOLE)
    sole = (f"M{heel[0] - 2},{floor - 16} L{toe[0] - 2},{floor - 16} C{toe[0] + 4},{floor - 10} {toe[0] + 2},{floor - 2} {toe[0] - 6},{floor} "
            f"L{heel[0] + 4},{floor} C{heel[0] - 4},{floor - 2} {heel[0] - 5},{floor - 10} {heel[0] - 2},{floor - 16} Z")
    sole_shades: list = [(f"M0,{floor - 6} H{DESIGN[0]} V{DESIGN[1]} H0 Z", SOLE_S)]
    if is_far(side):
        sole_shades.append((full, OUTLINE, FAR_DIM))
    p.shape(sole, SOLE, sole_shades)
    cap = f"M{toe[0] - 26},{floor - 30} C{toe[0] - 14},{floor - 28} {toe[0] - 4},{floor - 24} {toe[0]},{floor - 18} C{toe[0] - 8},{floor - 12} {toe[0] - 20},{floor - 12} {toe[0] - 28},{floor - 16} Z"
    p.shape(cap, SOLE, sole_shades[1:], edge=4)
    return p


def pelvis():
    p = Part("pelvis")
    hips = "M158,396 L272,396 C278,416 278,432 274,446 L162,446 C157,430 155,414 158,396 Z"
    p.shape(hips, JEAN, [("M150,396 L180,396 C176,416 176,432 180,450 L150,450 Z", JEAN_D),
                         ("M150,430 L280,430 L280,450 L150,450 Z", JEAN_S, 0.6)],
            ["M216,404 L216,440"])
    return p


def torso():
    p = Part("torso")
    # Neck under the head.
    p.shape("M188,226 L188,266 L234,266 L232,228 Z", SKIN, [("M180,226 L240,226 L240,252 C222,258 200,254 180,246 Z", SKIN_S)])
    # Tank top.
    p.shape("M178,256 L264,256 C270,300 268,350 264,396 L176,396 C173,346 173,300 178,256 Z", TANK,
            [("M176,256 L200,256 C194,300 194,350 198,396 L176,396 Z", TANK_S),
             ("M196,322 C212,334 236,334 254,322 L254,332 C236,344 212,344 196,332 Z", TANK_S, 0.8),
             ("M240,270 C252,280 258,296 258,312 C252,298 246,284 236,276 Z", "#ffffff", 0.9)])
    p.shape("M190,256 C200,282 232,284 246,256 Z", SKIN, [("M190,256 L246,256 L246,266 C228,270 206,270 190,264 Z", SKIN_S)], edge=4)
    # Open leather vest.
    p.shape("M138,272 C148,258 170,253 190,255 C186,292 190,332 198,396 L160,396 C151,372 145,345 141,318 C137,300 135,285 138,272 Z", VEST,
            [("M134,250 L162,250 C156,300 160,350 168,400 L134,400 Z", VEST_S),
             ("M134,380 L200,380 L200,400 L134,400 Z", VEST_D, 0.7),
             ("M176,262 C182,300 184,340 190,380 L184,380 C178,340 174,300 170,264 Z", VEST_H, 0.7)],
            ["M176,300 L188,302", "M180,330 L192,332"])
    p.shape("M250,255 C268,255 284,261 291,276 C297,300 293,330 285,350 C281,370 274,384 268,396 L256,396 C262,350 262,300 250,255 Z", VEST,
            [("M250,255 L262,255 C268,300 268,350 262,396 L250,396 Z", VEST_S),
             ("M274,270 C284,282 288,300 286,320 C282,302 278,286 270,276 Z", VEST_H, 0.8)])
    # Popped collar.
    p.shape("M166,262 C162,240 176,230 196,236 L202,258 C190,256 176,258 166,262 Z", VEST, [("M160,248 L204,248 L204,262 L160,262 Z", VEST_D)])
    p.shape("M236,258 L244,236 C258,232 270,242 268,264 C258,258 246,256 236,258 Z", VEST, [("M232,252 L272,252 L272,266 L232,266 Z", VEST_D)])
    # Belt with a gold buckle.
    p.shape("M157,384 L273,384 L272,402 L159,402 Z", BELT, [("M155,396 L276,396 L276,404 L155,404 Z", BELT_S)], ["M168,390 L172,390"])
    p.shape("M210,382 L236,382 L236,404 L210,404 Z", GOLD,
            [("M226,382 L238,382 L238,406 L226,406 Z", GOLD_S), ("M212,384 L218,384 L214,392 Z", "#fff3c0")], edge=4)
    p.shape("M216,388 L230,388 L230,398 L216,398 Z", BELT, edge=3)
    return p


def head():
    p = Part("head")
    face = ("M200,62 C245,60 282,86 286,130 C289,165 283,195 268,218 C257,233 246,241 232,243 "
            "C210,245 175,239 155,223 C132,206 118,179 118,148 C118,100 150,64 200,62 Z")
    p.shape(face, SKIN,
            [("M110,90 C150,110 168,150 170,190 C172,215 190,236 214,248 L110,248 Z", SKIN_S),
             ("M150,108 C190,118 240,118 290,104 L290,130 C240,132 190,132 150,124 Z", SKIN_S, 0.8),
             ("M160,212 C190,232 230,236 268,212 L268,252 L160,252 Z", "#7a6a8a", 0.28),
             ("M262,176 C272,180 276,192 272,204 C268,196 264,186 258,180 Z", SKIN_H, 0.9),
             ("M232,136 C244,134 258,136 268,142 C258,140 244,140 234,142 Z", SKIN_H, 0.7),
             ("M282,112 C294,150 290,192 272,224 L264,222 C280,190 284,150 276,114 Z", SKIN_H, 0.9)],
            edge=7)
    p.shape("M120,152 C108,150 104,166 110,178 C114,188 124,190 130,184 Z", SKIN,
            [("M114,160 C112,170 116,180 124,182 L120,190 L104,190 L104,150 Z", SKIN_S)],
            ["M118,162 C114,168 116,176 122,178"], edge=5)
    hair = ("M118,178 C110,150 102,115 116,88 C126,62 148,40 178,32 L170,14 C196,16 214,20 228,28 L238,8 "
            "C262,20 280,38 290,60 L310,58 C302,78 292,92 282,102 C264,94 242,94 224,102 C206,110 190,114 174,112 "
            "C162,120 154,132 150,150 C148,162 142,172 134,178 Z")
    p.defs.append(f'<linearGradient id="hair_gradient" x1="0" y1="0" x2="0.3" y2="1">'
                  f'<stop offset="0" stop-color="{HAIR_T}"/><stop offset="1" stop-color="{HAIR_B}"/></linearGradient>')
    p.shape(hair, "url(#hair_gradient)",
            [("M100,120 C130,110 150,130 160,160 C150,170 140,180 130,186 L96,186 Z", HAIR_S, 0.8),
             ("M170,100 C200,104 240,90 290,96 L290,110 L170,120 Z", HAIR_S, 0.7),
             ("M150,52 C180,36 220,34 252,44 C222,44 186,50 160,64 Z", HAIR_H, 0.9),
             ("M232,58 C254,62 274,72 286,84 C270,78 252,72 236,68 Z", HAIR_H, 0.8),
             ("M126,90 C134,74 146,62 160,56 C150,68 140,80 134,96 Z", HAIR_H, 0.6)],
            ["M180,40 C200,60 214,76 222,96", "M236,30 C250,50 262,66 270,92", "M150,70 C160,88 166,100 168,110"],
            edge=7)
    # Brows.
    p.shape("M184,146 L234,150 L232,140 C216,134 198,132 188,136 Z", HAIR_B, edge=4)
    p.shape("M248,149 L278,145 L276,137 C266,136 256,138 250,141 Z", HAIR_B, edge=4)
    # Near eye.
    p.shape("M190,156 L232,160 C230,174 220,182 209,181 C198,180 191,170 190,156 Z", "#ffffff",
            [("M188,154 L234,154 L234,166 C220,164 204,164 188,166 Z", "#d9d4e6")], edge=4)
    p.shape("M206,158 C214,156 222,158 224,166 C225,174 220,180 214,180 C207,180 204,172 206,158 Z", IRIS,
            [("M200,154 L228,154 L228,166 L200,166 Z", IRIS_S, 0.8)], edge=2)
    p.raw(f'<ellipse cx="215" cy="169" rx="4.5" ry="6" fill="{OUTLINE}"/>')
    p.raw('<circle cx="211" cy="163" r="3" fill="#ffffff"/><circle cx="219" cy="174" r="1.5" fill="#ffffff"/>')
    p.line("M186,155 L234,160", 6)
    # Far eye.
    p.shape("M248,159 L274,157 C274,170 268,178 261,178 C254,178 249,170 248,159 Z", "#ffffff",
            [("M246,156 L276,156 L276,166 L246,166 Z", "#d9d4e6")], edge=4)
    p.shape("M258,159 C264,158 270,160 270,167 C270,174 266,178 262,178 C257,178 256,170 258,159 Z", IRIS,
            [("M254,156 L274,156 L274,166 L254,166 Z", IRIS_S, 0.8)], edge=2)
    p.raw(f'<ellipse cx="264" cy="169" rx="3.5" ry="5.5" fill="{OUTLINE}"/>')
    p.raw('<circle cx="261" cy="164" r="2.2" fill="#ffffff"/>')
    p.line("M246,159 L276,156", 6)
    # Nose, smirk.
    p.shape("M256,170 C262,180 266,188 262,194 C258,196 252,196 248,192 Z", SKIN_S, edge=0)
    p.line("M258,172 C264,182 266,190 260,194 C256,195 252,194 250,192")
    p.line("M226,214 C238,216 250,214 262,206", 4)
    p.line("M262,206 L266,202")
    p.line("M236,222 C242,224 248,223 252,221", 2, SKIN_D)
    # Band-aid on the near cheek.
    p.raw('<g transform="rotate(-25 186 196)">')
    p.shape("M170,190 L202,190 C206,190 206,202 202,202 L170,202 C166,202 166,190 170,190 Z", "#f2d3a8",
            [("M166,197 L206,197 L206,204 L166,204 Z", "#d9b282")], edge=3)
    p.shape("M181,190 L191,190 L191,202 L181,202 Z", "#e8c08e", edge=0)
    p.raw("</g>")
    return p


PARTS = {
    "pelvis": pelvis, "torso": torso, "head": head,
    **{f"arm_{s}_upper": (lambda s=s: arm_upper(s)) for s in ARM},
    **{f"arm_{s}_lower": (lambda s=s: arm_lower(s)) for s in ARM},
    **{f"hand_{s}": (lambda s=s: hand(s)) for s in ARM},
    **{f"leg_{s}_upper": (lambda s=s: leg_upper(s)) for s in LEG},
    **{f"leg_{s}_lower": (lambda s=s: leg_lower(s)) for s in LEG},
    **{f"foot_{s}": (lambda s=s: foot(s)) for s in LEG},
}


def art(point):
    """A design-unit point in art pixels."""
    return [round(point[0] * SCALE, 2), round(point[1] * SCALE, 2)]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, draw in PARTS.items():
        (OUT / f"{name}.svg").write_text(draw().svg(), encoding="utf-8")
    rig = {
        "character": "bruno",
        "canvas": art(DESIGN),
        "feet": art(FEET),
        "draw_order": DRAW_ORDER,
        "hierarchy": HIERARCHY,
        "pivots": {k: art(v) for k, v in PIVOTS.items()},
        "points": {k: art(v) for k, v in POINTS.items()},
    }
    (OUT / "rig.json").write_text(json.dumps(rig, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {len(PARTS)} parts to {OUT}")


if __name__ == "__main__":
    main()
