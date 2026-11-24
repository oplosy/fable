"""Keeps a rig's sneakers (and, in a roll, its whole body) out of the floor in the shared clips.

The clips were keyed for a rig with small feet; a long shoe turned by the same angle
pushes its toe or heel through the floor. For every key of a grounded clip this turns each
foot that goes below the floor to the nearest angle that keeps its sole on or above it,
and lifts the hips only when no foot angle is enough. Feet above the floor are left alone,
so steps and flight phases keep their lift. In a roll the hips are lifted until no
point of the body (head corners, fists, soles) is below the floor.

Run: python tools/plant_feet.py [assets/characters/bruno/rig.json] [--check]
--check prints what would change and writes nothing.
"""

import json
import math
import sys
from pathlib import Path

CLIPS_DIR = Path("assets/animations")
# Clips whose feet stand on the floor; airborne, lying and rolling clips are left alone.
GROUNDED = [
    "idle", "aim_idle", "walk", "run", "crouch_idle", "crouch_walk", "land",
    "jab_1", "jab_2", "jab_3", "hook", "knife_stab", "knife_slash", "bat_swing",
    "bat_homerun", "cook", "throw", "hit_front", "hit_back", "getup",
]
# Clips that tumble along the floor: only the hips move, lifted over the lowest body point.
TUMBLING = ["roll"]
# Same as CharacterRig.PARTS: part and parent.
HIERARCHY = {
    "pelvis": "", "torso": "pelvis", "head": "torso",
    "leg_front_upper": "pelvis", "leg_front_lower": "leg_front_upper", "foot_front": "leg_front_lower",
    "leg_back_upper": "pelvis", "leg_back_lower": "leg_back_upper", "foot_back": "leg_back_lower",
    "arm_front_upper": "torso", "arm_front_lower": "arm_front_upper", "hand_front": "arm_front_lower",
    "arm_back_upper": "torso", "arm_back_lower": "arm_back_upper", "hand_back": "arm_back_lower",
}
# Body points (rig.json points or canvas corners of the head) a roll keeps above the floor.
HEAD_CORNERS = "head_corners"
BODY_POINTS = {
    "head": [HEAD_CORNERS], "hand_front": ["hand_front"], "hand_back": ["hand_back"],
    "foot_front": ["heel_front", "toe_front"], "foot_back": ["heel_back", "toe_back"],
}
FOOT_CHAIN = {
    side: ["pelvis", f"leg_{side}_upper", f"leg_{side}_lower", f"foot_{side}"] for side in ("front", "back")
}
# Same as RigAnimator.REFERENCE_LEG_LENGTH.
REFERENCE_LEG_LENGTH = 39.0
# Art px a sole may dip below the floor: the outline already reaches past it.
TOLERANCE = 1.0
# Rounding slack, so a second run changes nothing.
SLACK = 0.05
# How far (degrees) a foot may turn from its keyed angle.
MAX_TURN = 70


def mat(position, angle_deg, stretch=1.0):
    """A node's 2D transform (Godot order: scale, rotate, translate) as a 2x3 tuple."""
    c, s = math.cos(math.radians(angle_deg)), math.sin(math.radians(angle_deg))
    return (c, -s * stretch, position[0], s, c * stretch, position[1])


def mul(a, b):
    return (a[0] * b[0] + a[1] * b[3], a[0] * b[1] + a[1] * b[4], a[0] * b[2] + a[1] * b[5] + a[2],
            a[3] * b[0] + a[4] * b[3], a[3] * b[1] + a[4] * b[4], a[3] * b[2] + a[4] * b[5] + a[5])


def apply(m, p):
    return (m[0] * p[0] + m[1] * p[1] + m[2], m[3] * p[0] + m[4] * p[1] + m[5])


class Rig:
    def __init__(self, path):
        data = json.loads(Path(path).read_text(encoding="utf-8-sig"))
        self.pivots = {k: tuple(v) for k, v in data["pivots"].items()}
        self.points = {k: tuple(v) for k, v in data["points"].items()}
        self.feet = tuple(data["feet"])
        self.leg_scale = (self.feet[1] - self.pivots["leg_front_upper"][1]) / REFERENCE_LEG_LENGTH
        # The head's box: from its top point down to its pivot (the jaw), as wide as tall.
        top, pivot = self.points["head_top"], self.pivots["head"]
        half = (pivot[1] - top[1]) / 2
        self.head_corners = [(top[0] - half, top[1]), (top[0] + half, top[1]),
                             (top[0] - half, pivot[1]), (top[0] + half, pivot[1])]

    def rest(self, part):
        parent = HIERARCHY[part]
        origin = self.feet if parent == "" else self.pivots[parent]
        return (self.pivots[part][0] - origin[0], self.pivots[part][1] - origin[1])

    def depth(self, part, names, root, angles, stretch):
        """How far (art px) the lowest of a part's points is below the floor."""
        chain = []
        at = part
        while at != "":
            chain.insert(0, at)
            at = HIERARCHY[at]
        m = (1, 0, 0, 0, 1, 0)
        for joint in chain:
            position = self.rest(joint)
            if joint == "pelvis":
                position = (position[0] + root[0] * self.leg_scale, position[1] + root[1] * self.leg_scale)
            m = mul(m, mat(position, angles.get(joint, 0.0), stretch.get(joint, 1.0)))
        pivot = self.pivots[part]
        lowest = -1e9
        for name in names:
            for point in (self.head_corners if name == HEAD_CORNERS else [self.points[name]]):
                lowest = max(lowest, apply(m, (point[0] - pivot[0], point[1] - pivot[1]))[1])
        return lowest

    def sole_depth(self, side, root, angles, stretch):
        """How far (art px) the lowest sole point of one foot is below the floor."""
        return self.depth(f"foot_{side}", [f"heel_{side}", f"toe_{side}"], root, angles, stretch)

    def body_depth(self, root, angles, stretch):
        """How far (art px) the lowest body point is below the floor."""
        return max(self.depth(part, names, root, angles, stretch) for part, names in BODY_POINTS.items())


def plant(rig, clip):
    """Fixes a clip's keys in place; returns a line per change."""
    changes = []
    angles, stretch, root = {}, {}, [0.0, 0.0]
    for key in clip["keys"]:
        angles.update(key.get("angles", {}))
        stretch.update(key.get("stretch", {}))
        if "root" in key:
            root = list(key["root"])
        best = {}
        for side in ("front", "back"):
            part = f"foot_{side}"
            keyed = float(angles.get(part, 0.0))
            if rig.sole_depth(side, root, angles, stretch) <= TOLERANCE + SLACK:
                continue
            tries = sorted((d * 0.5 for d in range(-2 * MAX_TURN, 2 * MAX_TURN + 1)), key=abs)
            fits = [keyed + d for d in tries
                    if rig.sole_depth(side, root, {**angles, part: keyed + d}, stretch) <= TOLERANCE]
            if fits:
                best[part] = fits[0]
            else:
                least = min(tries, key=lambda d: rig.sole_depth(side, root, {**angles, part: keyed + d}, stretch))
                best[part] = keyed + least
        lift = max([0.0] + [rig.sole_depth(side, root, {**angles, **best}, stretch) - TOLERANCE
                            for side in ("front", "back")])
        for part, angle in best.items():
            changes.append(f"t {key['t']}: {part} {angles.get(part, 0)} -> {angle:g}")
            angles[part] = angle
            key.setdefault("angles", {})[part] = round(angle, 1)
        if lift > SLACK:
            root = [root[0], math.floor((root[1] - lift / rig.leg_scale) * 100) / 100]
            key["root"] = root
            changes.append(f"t {key['t']}: hips up {lift:.1f} art px")
    return changes


def lift_over_floor(rig, clip):
    """Lifts a tumbling clip's hips so no body point is below the floor; returns a line per change."""
    changes = []
    angles, stretch, root = {}, {}, [0.0, 0.0]
    for key in clip["keys"]:
        angles.update(key.get("angles", {}))
        stretch.update(key.get("stretch", {}))
        if "root" in key:
            root = list(key["root"])
        lift = rig.body_depth(root, angles, stretch) - TOLERANCE
        if lift > SLACK:
            root = [root[0], math.floor((root[1] - lift / rig.leg_scale) * 100) / 100]
            key["root"] = root
            changes.append(f"t {key['t']}: hips up {lift:.1f} art px")
    return changes


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    check = "--check" in sys.argv
    rig = Rig(args[0] if args else "assets/characters/bruno/rig.json")
    for name in GROUNDED + TUMBLING:
        path = CLIPS_DIR / f"{name}.json"
        clip = json.loads(path.read_text(encoding="utf-8-sig"))
        changes = plant(rig, clip) if name in GROUNDED else lift_over_floor(rig, clip)
        for line in changes:
            print(f"{name}: {line}")
        if changes and not check:
            path.write_text(json.dumps(clip, indent=2) + "\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
