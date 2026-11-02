import json
import math
import os
from PIL import Image

RONIN_DIR = r"assets\characters\ronin"
OUT_DIR = r"assets\animations"
ARTIFACTS_DIR = r"C:\Users\mesut\.gemini\antigravity\brain\d9e27150-5a18-4698-b5ae-bc1bd3ee9606"
RIG_JSON = os.path.join(RONIN_DIR, "rig.json")

os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(ARTIFACTS_DIR, exist_ok=True)

with open(RIG_JSON, "r", encoding="utf-8") as f:
    rig_data = json.load(f)

pivots = {k: (v[0], v[1]) for k, v in rig_data["pivots"].items()}
hierarchy = rig_data["hierarchy"]
draw_order = rig_data["draw_order"]
canvas_w, canvas_h = rig_data["canvas"]

textures = {}
for part in draw_order:
    png_path = os.path.join(RONIN_DIR, f"{part}.png")
    if os.path.exists(png_path):
        textures[part] = Image.open(png_path).convert("RGBA")

def rotate_point(px, py, angle_rad):
    cos_a = math.cos(angle_rad)
    sin_a = math.sin(angle_rad)
    return px * cos_a - py * sin_a, px * sin_a + py * cos_a

def compute_transforms(angles, root_offset):
    transforms = {}
    def get_joint_tf(part):
        if part in transforms:
            return transforms[part]
        parent = hierarchy.get(part, "")
        local_pivot = pivots[part]
        local_angle = math.radians(angles.get(part, 0.0))
        if parent == "":
            pos_x = local_pivot[0] + root_offset[0]
            pos_y = local_pivot[1] + root_offset[1]
            rot = local_angle
        else:
            parent_x, parent_y, parent_rot = get_joint_tf(parent)
            parent_pivot = pivots[parent]
            rel_x = local_pivot[0] - parent_pivot[0]
            rel_y = local_pivot[1] - parent_pivot[1]
            rx, ry = rotate_point(rel_x, rel_y, parent_rot)
            pos_x = parent_x + rx
            pos_y = parent_y + ry
            rot = parent_rot + local_angle
        transforms[part] = (pos_x, pos_y, rot)
        return transforms[part]

    for part in draw_order:
        get_joint_tf(part)
    return transforms

def render_pose_hires(angles, root_offset, scale=4):
    w = canvas_w * scale
    h = canvas_h * scale
    out_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    transforms = compute_transforms(angles, root_offset)
    
    for part in draw_order:
        if part not in textures:
            continue
        tex = textures[part]
        pos_x, pos_y, rot_rad = transforms[part]
        p_x, p_y = pivots[part]
        
        tex_scaled = tex.resize((canvas_w * scale, canvas_h * scale), Image.NEAREST)
        p_xs = p_x * scale
        p_ys = p_y * scale
        target_xs = pos_x * scale
        target_ys = pos_y * scale
        
        pad = max(w, h)
        padded = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
        padded.paste(tex_scaled, (pad, pad))
        
        pivot_on_padded = (pad + p_xs, pad + p_ys)
        rot_deg = -math.degrees(rot_rad)
        rotated = padded.rotate(rot_deg, resample=Image.BICUBIC, center=pivot_on_padded)
        
        paste_x = int(round(target_xs - pivot_on_padded[0]))
        paste_y = int(round(target_ys - pivot_on_padded[1]))
        
        out_img.alpha_composite(rotated, (paste_x, paste_y))
        
    return out_img

def sample_clip(clip_data, t):
    keys = clip_data["keys"]
    if not keys:
        return {}, (0, 0)
    if len(keys) == 1 or t <= keys[0]["t"]:
        return keys[0].get("angles", {}), keys[0].get("root", [0, 0])
    if t >= keys[-1]["t"]:
        return keys[-1].get("angles", {}), keys[-1].get("root", [0, 0])
        
    k0 = keys[0]
    k1 = keys[-1]
    for i in range(len(keys) - 1):
        if keys[i]["t"] <= t <= keys[i+1]["t"]:
            k0 = keys[i]
            k1 = keys[i+1]
            break
            
    dt = k1["t"] - k0["t"]
    factor = (t - k0["t"]) / dt if dt > 0 else 0.0
    s = factor * factor * (3.0 - 2.0 * factor)
    
    r0 = k0.get("root", [0, 0])
    r1 = k1.get("root", [0, 0])
    interp_root = (r0[0] + (r1[0] - r0[0]) * s, r0[1] + (r1[1] - r0[1]) * s)
    
    a0 = k0.get("angles", {})
    a1 = k1.get("angles", {})
    all_parts = set(a0.keys()).union(set(a1.keys()))
    interp_angles = {}
    for p in all_parts:
        val0 = a0.get(p, 0.0)
        val1 = a1.get(p, 0.0)
        interp_angles[p] = val0 + (val1 - val0) * s
        
    return interp_angles, interp_root

def generate_review(clip_name, clip_data, num_frames=8, fps=12):
    length = clip_data.get("length", 1.0)
    loop = clip_data.get("loop", False)
    frames = []
    
    time_step = length / num_frames if loop else (length / (num_frames - 1) if num_frames > 1 else 0.0)
    
    for i in range(num_frames):
        t = min(i * time_step, length)
        angles, root = sample_clip(clip_data, t)
        img = render_pose_hires(angles, root, scale=4)
        frames.append(img)
        
    strip = Image.new("RGBA", (canvas_w * 4 * num_frames, canvas_h * 4), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * canvas_w * 4, 0))
        
    sheet_path = os.path.join(ARTIFACTS_DIR, f"{clip_name}_review_4x.png")
    gif_path = os.path.join(ARTIFACTS_DIR, f"{clip_name}_review_4x.gif")
    
    strip.save(sheet_path)
    
    duration_ms = int(round(1000.0 / fps))
    frames[0].save(
        gif_path,
        save_all=True,
        append_images=frames[1:],
        duration=duration_ms,
        loop=0 if loop else 1,
        transparency=0,
        disposal=2
    )

new_and_refined = {
    # 1. Softened Run Cycle (less exaggerated trailing leg)
    "run": {
        "name": "run",
        "loop": True,
        "length": 0.40,
        "reference_speed": 200.0,
        "events": [{"t": 0.05, "name": "step"}, {"t": 0.25, "name": "step"}],
        "keys": [
            {
                "t": 0.0,
                "root": [0, 0],
                "angles": {
                    "pelvis": 14, "torso": -16, "head": 6,
                    "leg_front_upper": -35, "leg_front_lower": 22, "foot_front": 12,
                    "leg_back_upper": 20, "leg_back_lower": 25, "foot_back": -25,
                    "arm_front_upper": 32, "arm_front_lower": 35, "hand_front": 10,
                    "arm_back_upper": -32, "arm_back_lower": 25, "hand_back": 0,
                    "scabbard": 8, "coat_tail": -22, "coat_back": -16
                }
            },
            {
                "t": 0.05,
                "root": [0, 2],
                "angles": {
                    "pelvis": 12, "torso": -14, "head": 4,
                    "leg_front_upper": -26, "leg_front_lower": 38, "foot_front": 0,
                    "leg_back_upper": 18, "leg_back_lower": 28, "foot_back": -20,
                    "arm_front_upper": 25, "arm_front_lower": 40, "hand_front": 8,
                    "arm_back_upper": -25, "arm_back_lower": 28, "hand_back": 0,
                    "scabbard": 6, "coat_tail": -18, "coat_back": -12
                }
            },
            {
                "t": 0.10,
                "root": [0, -1],
                "angles": {
                    "pelvis": 10, "torso": -12, "head": 2,
                    "leg_front_upper": 8, "leg_front_lower": 45, "foot_front": -12,
                    "leg_back_upper": -8, "leg_back_lower": 22, "foot_back": 8,
                    "arm_front_upper": 8, "arm_front_lower": 35, "hand_front": 5,
                    "arm_back_upper": -10, "arm_back_lower": 25, "hand_back": 0,
                    "scabbard": 4, "coat_tail": -12, "coat_back": -8
                }
            },
            {
                "t": 0.15,
                "root": [0, -2],
                "angles": {
                    "pelvis": 8, "torso": -10, "head": 2,
                    "leg_front_upper": 22, "leg_front_lower": 25, "foot_front": -25,
                    "leg_back_upper": -32, "leg_back_lower": 20, "foot_back": 12,
                    "arm_front_upper": -18, "arm_front_lower": 28, "hand_front": 0,
                    "arm_back_upper": 22, "arm_back_lower": 35, "hand_back": 8,
                    "scabbard": 2, "coat_tail": -6, "coat_back": -4
                }
            },
            {
                "t": 0.20,
                "root": [0, 0],
                "angles": {
                    "pelvis": 14, "torso": -16, "head": 6,
                    "leg_front_upper": 20, "leg_front_lower": 25, "foot_front": -25,
                    "leg_back_upper": -35, "leg_back_lower": 22, "foot_back": 12,
                    "arm_front_upper": -32, "arm_front_lower": 25, "hand_front": 0,
                    "arm_back_upper": 32, "arm_back_lower": 35, "hand_back": 10,
                    "scabbard": 8, "coat_tail": -22, "coat_back": -16
                }
            },
            {
                "t": 0.25,
                "root": [0, 2],
                "angles": {
                    "pelvis": 12, "torso": -14, "head": 4,
                    "leg_front_upper": 18, "leg_front_lower": 28, "foot_front": -20,
                    "leg_back_upper": -26, "leg_back_lower": 38, "foot_back": 0,
                    "arm_front_upper": -25, "arm_front_lower": 28, "hand_front": 0,
                    "arm_back_upper": 25, "arm_back_lower": 40, "hand_back": 8,
                    "scabbard": 6, "coat_tail": -18, "coat_back": -12
                }
            },
            {
                "t": 0.30,
                "root": [0, -1],
                "angles": {
                    "pelvis": 10, "torso": -12, "head": 2,
                    "leg_front_upper": -8, "leg_front_lower": 22, "foot_front": 8,
                    "leg_back_upper": 8, "leg_back_lower": 45, "foot_back": -12,
                    "arm_front_upper": -10, "arm_front_lower": 25, "hand_front": 0,
                    "arm_back_upper": 8, "arm_back_lower": 35, "hand_back": 5,
                    "scabbard": 4, "coat_tail": -12, "coat_back": -8
                }
            },
            {
                "t": 0.35,
                "root": [0, -2],
                "angles": {
                    "pelvis": 8, "torso": -10, "head": 2,
                    "leg_front_upper": -32, "leg_front_lower": 20, "foot_front": 12,
                    "leg_back_upper": 22, "leg_back_lower": 25, "foot_back": -25,
                    "arm_front_upper": 22, "arm_front_lower": 35, "hand_front": 8,
                    "arm_back_upper": -18, "arm_back_lower": 28, "hand_back": 0,
                    "scabbard": 2, "coat_tail": -6, "coat_back": -4
                }
            },
            {
                "t": 0.40,
                "root": [0, 0],
                "angles": {
                    "pelvis": 14, "torso": -16, "head": 6,
                    "leg_front_upper": -35, "leg_front_lower": 22, "foot_front": 12,
                    "leg_back_upper": 20, "leg_back_lower": 25, "foot_back": -25,
                    "arm_front_upper": 32, "arm_front_lower": 35, "hand_front": 10,
                    "arm_back_upper": -32, "arm_back_lower": 25, "hand_back": 0,
                    "scabbard": 8, "coat_tail": -22, "coat_back": -16
                }
            }
        ]
    },

    # 2. Refined Horizontal Dive Plunge (with _visuals.rotation = 0.0)
    "dive": {
        "name": "dive",
        "loop": False,
        "length": 0.40,
        "keys": [
            {
                "t": 0.0,
                "root": [0, 16],
                "angles": {
                    "pelvis": 75, "torso": 12, "head": -25,
                    "arm_front_upper": -25, "arm_front_lower": 10, "hand_front": 0,
                    "arm_back_upper": -75, "arm_back_lower": 10, "hand_back": 0,
                    "leg_front_upper": -65, "leg_front_lower": 10, "foot_front": 10,
                    "leg_back_upper": -75, "leg_back_lower": 15, "foot_back": 10,
                    "scabbard": -70, "coat_tail": -75, "coat_back": -75
                }
            },
            {
                "t": 0.20,
                "root": [0, 18],
                "angles": {
                    "pelvis": 85, "torso": 8, "head": -28,
                    "arm_front_upper": -30, "arm_front_lower": 5, "hand_front": 0,
                    "arm_back_upper": -80, "arm_back_lower": 5, "hand_back": 0,
                    "leg_front_upper": -80, "leg_front_lower": 5, "foot_front": 10,
                    "leg_back_upper": -85, "leg_back_lower": 5, "foot_back": 10,
                    "scabbard": -80, "coat_tail": -85, "coat_back": -85
                }
            },
            {
                "t": 0.40,
                "root": [0, 18],
                "angles": {
                    "pelvis": 85, "torso": 8, "head": -28,
                    "arm_front_upper": -30, "arm_front_lower": 5, "hand_front": 0,
                    "arm_back_upper": -80, "arm_back_lower": 5, "hand_back": 0,
                    "leg_front_upper": -80, "leg_front_lower": 5, "foot_front": 10,
                    "leg_back_upper": -85, "leg_back_lower": 5, "foot_back": 10,
                    "scabbard": -80, "coat_tail": -85, "coat_back": -85
                }
            }
        ]
    },

    # 3. Refined Down (Lying flat on floor with _visuals.rotation = 0.0)
    "down": {
        "name": "down",
        "loop": True,
        "length": 1.0,
        "keys": [
            {
                "t": 0.0,
                "root": [0, 34],
                "angles": {
                    "pelvis": -90, "torso": 0, "head": 5,
                    "arm_front_upper": 12, "arm_front_lower": 6, "hand_front": 0,
                    "arm_back_upper": 6, "arm_back_lower": 8, "hand_back": 0,
                    "leg_front_upper": 4, "leg_front_lower": 6, "foot_front": 10,
                    "leg_back_upper": 9, "leg_back_lower": 8, "foot_back": 10,
                    "scabbard": 2, "coat_tail": 2, "coat_back": 2
                }
            },
            {
                "t": 0.50,
                "root": [0, 33.6],
                "angles": {
                    "pelvis": -90, "torso": -1, "head": 4,
                    "arm_front_upper": 12, "arm_front_lower": 6, "hand_front": 0,
                    "arm_back_upper": 6, "arm_back_lower": 8, "hand_back": 0,
                    "leg_front_upper": 4, "leg_front_lower": 6, "foot_front": 10,
                    "leg_back_upper": 9, "leg_back_lower": 8, "foot_back": 10,
                    "scabbard": 2, "coat_tail": 2, "coat_back": 2
                }
            },
            {
                "t": 1.0,
                "root": [0, 34],
                "angles": {
                    "pelvis": -90, "torso": 0, "head": 5,
                    "arm_front_upper": 12, "arm_front_lower": 6, "hand_front": 0,
                    "arm_back_upper": 6, "arm_back_lower": 8, "hand_back": 0,
                    "leg_front_upper": 4, "leg_front_lower": 6, "foot_front": 10,
                    "leg_back_upper": 9, "leg_back_lower": 8, "foot_back": 10,
                    "scabbard": 2, "coat_tail": 2, "coat_back": 2
                }
            }
        ]
    },

    # 4. Ladder Climb
    "climb": {
        "name": "climb",
        "loop": True,
        "length": 0.60,
        "reference_speed": 75.0,
        "keys": [
            {
                "t": 0.0,
                "root": [0, 0],
                "angles": {
                    "pelvis": 0, "torso": 2, "head": -22,
                    "arm_front_upper": -85, "arm_front_lower": 15, "hand_front": 0,
                    "arm_back_upper": -35, "arm_back_lower": 60, "hand_back": 0,
                    "leg_front_upper": 45, "leg_front_lower": -60, "foot_front": 15,
                    "leg_back_upper": -10, "leg_back_lower": 15, "foot_back": -5,
                    "scabbard": 4, "coat_tail": 6, "coat_back": 6
                }
            },
            {
                "t": 0.15,
                "root": [0, -2],
                "angles": {
                    "pelvis": 2, "torso": 0, "head": -20,
                    "arm_front_upper": -60, "arm_front_lower": 40, "hand_front": 0,
                    "arm_back_upper": -60, "arm_back_lower": 40, "hand_back": 0,
                    "leg_front_upper": 20, "leg_front_lower": -25, "foot_front": 5,
                    "leg_back_upper": 20, "leg_back_lower": -25, "foot_back": 5,
                    "scabbard": 2, "coat_tail": 4, "coat_back": 4
                }
            },
            {
                "t": 0.30,
                "root": [0, 0],
                "angles": {
                    "pelvis": 0, "torso": -2, "head": -22,
                    "arm_front_upper": -35, "arm_front_lower": 60, "hand_front": 0,
                    "arm_back_upper": -85, "arm_back_lower": 15, "hand_back": 0,
                    "leg_front_upper": -10, "leg_front_lower": 15, "foot_front": -5,
                    "leg_back_upper": 45, "leg_back_lower": -60, "foot_back": 15,
                    "scabbard": -4, "coat_tail": 6, "coat_back": 6
                }
            },
            {
                "t": 0.45,
                "root": [0, -2],
                "angles": {
                    "pelvis": -2, "torso": 0, "head": -20,
                    "arm_front_upper": -60, "arm_front_lower": 40, "hand_front": 0,
                    "arm_back_upper": -60, "arm_back_lower": 40, "hand_back": 0,
                    "leg_front_upper": 20, "leg_front_lower": -25, "foot_front": 5,
                    "leg_back_upper": 20, "leg_back_lower": -25, "foot_back": 5,
                    "scabbard": -2, "coat_tail": 4, "coat_back": 4
                }
            },
            {
                "t": 0.60,
                "root": [0, 0],
                "angles": {
                    "pelvis": 0, "torso": 2, "head": -22,
                    "arm_front_upper": -85, "arm_front_lower": 15, "hand_front": 0,
                    "arm_back_upper": -35, "arm_back_lower": 60, "hand_back": 0,
                    "leg_front_upper": 45, "leg_front_lower": -60, "foot_front": 15,
                    "leg_back_upper": -10, "leg_back_lower": 15, "foot_back": -5,
                    "scabbard": 4, "coat_tail": 6, "coat_back": 6
                }
            }
        ]
    },

    # 5. Cook Grenade (Pull pin & ready)
    "cook": {
        "name": "cook",
        "loop": False,
        "length": 0.40,
        "keys": [
            {
                "t": 0.0,
                "root": [0, 0],
                "angles": {
                    "pelvis": 0, "torso": -2, "head": 8,
                    "arm_front_upper": -25, "arm_front_lower": 65, "hand_front": 10,
                    "arm_back_upper": -20, "arm_back_lower": 55, "hand_back": 5,
                    "leg_front_upper": 0, "leg_front_lower": 0, "foot_front": 0,
                    "leg_back_upper": 0, "leg_back_lower": 0, "foot_back": 0,
                    "scabbard": 0, "coat_tail": 0, "coat_back": 0
                }
            },
            {
                "t": 0.15,
                "root": [0, 1],
                "angles": {
                    "pelvis": -2, "torso": 4, "head": 12,
                    "arm_front_upper": -30, "arm_front_lower": 70, "hand_front": 12,
                    "arm_back_upper": -5, "arm_back_lower": 30, "hand_back": 0,
                    "scabbard": -2, "coat_tail": 2, "coat_back": 0
                }
            },
            {
                "t": 0.40,
                "root": [0, 0],
                "angles": {
                    "pelvis": 4, "torso": -8, "head": -4,
                    "arm_front_upper": -55, "arm_front_lower": 50, "hand_front": 5,
                    "arm_back_upper": 20, "arm_back_lower": 25, "hand_back": 0,
                    "scabbard": 2, "coat_tail": -4, "coat_back": -2
                }
            }
        ]
    },

    # 6. Throw Grenade
    "throw": {
        "name": "throw",
        "loop": False,
        "length": 0.25,
        "keys": [
            {
                "t": 0.0,
                "root": [-1, 0],
                "angles": {
                    "pelvis": -6, "torso": -15, "head": 8,
                    "arm_front_upper": -80, "arm_front_lower": 85, "hand_front": 15,
                    "arm_back_upper": 25, "arm_back_lower": 20, "hand_back": 0,
                    "leg_front_upper": -8, "leg_front_lower": 10, "foot_front": 0,
                    "leg_back_upper": 8, "leg_back_lower": -6, "foot_back": 0,
                    "scabbard": -8, "coat_tail": -12, "coat_back": -8
                }
            },
            {
                "t": 0.08,
                "root": [2, 0],
                "angles": {
                    "pelvis": 12, "torso": 20, "head": -8,
                    "arm_front_upper": -45, "arm_front_lower": 10, "hand_front": 0,
                    "arm_back_upper": -30, "arm_back_lower": 35, "hand_back": 0,
                    "leg_front_upper": 12, "leg_front_lower": -12, "foot_front": 0,
                    "leg_back_upper": -12, "leg_back_lower": 8, "foot_back": 0,
                    "scabbard": 12, "coat_tail": 20, "coat_back": 15
                }
            },
            {
                "t": 0.25,
                "root": [0, 0],
                "angles": {
                    "pelvis": 0, "torso": 0, "head": 0,
                    "arm_front_upper": 0, "arm_front_lower": 0, "hand_front": 0,
                    "arm_back_upper": 0, "arm_back_lower": 0, "hand_back": 0,
                    "leg_front_upper": 0, "leg_front_lower": 0, "foot_front": 0,
                    "leg_back_upper": 0, "leg_back_lower": 0, "foot_back": 0,
                    "scabbard": 0, "coat_tail": 0, "coat_back": 0
                }
            }
        ]
    },

    # 7. Hit From Behind (Flinch forward)
    "hit_back": {
        "name": "hit_back",
        "loop": False,
        "length": 0.25,
        "keys": [
            {
                "t": 0.0,
                "root": [2, 1],
                "angles": {
                    "pelvis": 8, "torso": 25, "head": 20,
                    "arm_front_upper": 45, "arm_front_lower": 25, "hand_front": 0,
                    "arm_back_upper": 40, "arm_back_lower": 20, "hand_back": 0,
                    "leg_front_upper": 15, "leg_front_lower": -25, "foot_front": 10,
                    "leg_back_upper": -10, "leg_back_lower": 10, "foot_back": 0,
                    "scabbard": 15, "coat_tail": 25, "coat_back": 20
                }
            },
            {
                "t": 0.10,
                "root": [1, 1],
                "angles": {
                    "pelvis": 4, "torso": 12, "head": 10,
                    "arm_front_upper": 25, "arm_front_lower": 20, "hand_front": 0,
                    "arm_back_upper": 20, "arm_back_lower": 15, "hand_back": 0,
                    "leg_front_upper": 8, "leg_front_lower": -12, "foot_front": 4,
                    "leg_back_upper": -5, "leg_back_lower": 5, "foot_back": 0,
                    "scabbard": 8, "coat_tail": 10, "coat_back": 8
                }
            },
            {
                "t": 0.25,
                "root": [0, 0],
                "angles": {
                    "pelvis": 0, "torso": 0, "head": 0,
                    "arm_front_upper": 0, "arm_front_lower": 0, "hand_front": 0,
                    "arm_back_upper": 0, "arm_back_lower": 0, "hand_back": 0,
                    "leg_front_upper": 0, "leg_front_lower": 0, "foot_front": 0,
                    "leg_back_upper": 0, "leg_back_lower": 0, "foot_back": 0,
                    "scabbard": 0, "coat_tail": 0, "coat_back": 0
                }
            }
        ]
    },

    # 8. Bat Swing (Heavy blunt horizontal club swing)
    "bat_swing": {
        "name": "bat_swing",
        "loop": False,
        "length": 0.42,
        "keys": [
            {
                "t": 0.0,
                "root": [-1, 0],
                "angles": {
                    "pelvis": -12, "torso": -22, "head": 10,
                    "arm_front_upper": 35, "arm_front_lower": 70, "hand_front": 15,
                    "arm_back_upper": 10, "arm_back_lower": 50, "hand_back": 0,
                    "leg_front_upper": -8, "leg_front_lower": 12, "foot_front": 0,
                    "leg_back_upper": 8, "leg_back_lower": -8, "foot_back": 0,
                    "scabbard": -15, "coat_tail": -18, "coat_back": -14
                }
            },
            {
                "t": 0.12,
                "root": [-2, 1],
                "angles": {
                    "pelvis": -20, "torso": -30, "head": 14,
                    "arm_front_upper": 50, "arm_front_lower": 80, "hand_front": 20,
                    "arm_back_upper": 15, "arm_back_lower": 55, "hand_back": 0,
                    "scabbard": -22, "coat_tail": -25, "coat_back": -20
                }
            },
            {
                "t": 0.22,
                "root": [2, 0],
                "angles": {
                    "pelvis": 20, "torso": 35, "head": -14,
                    "arm_front_upper": -75, "arm_front_lower": 20, "hand_front": -10,
                    "arm_back_upper": -50, "arm_back_lower": 20, "hand_back": 0,
                    "leg_front_upper": 14, "leg_front_lower": -16, "foot_front": 2,
                    "leg_back_upper": -16, "leg_back_lower": 14, "foot_back": -2,
                    "scabbard": 22, "coat_tail": 35, "coat_back": 30
                }
            },
            {
                "t": 0.32,
                "root": [1, 0],
                "angles": {
                    "pelvis": 10, "torso": 18, "head": -6,
                    "arm_front_upper": -55, "arm_front_lower": 35, "hand_front": 0,
                    "arm_back_upper": -30, "arm_back_lower": 30, "hand_back": 0,
                    "scabbard": 12, "coat_tail": 15, "coat_back": 12
                }
            },
            {
                "t": 0.42,
                "root": [0, 0],
                "angles": {
                    "pelvis": 0, "torso": 0, "head": 0,
                    "arm_front_upper": 0, "arm_front_lower": 0, "hand_front": 0,
                    "arm_back_upper": 0, "arm_back_lower": 0, "hand_back": 0,
                    "leg_front_upper": 0, "leg_front_lower": 0, "foot_front": 0,
                    "leg_back_upper": 0, "leg_back_lower": 0, "foot_back": 0,
                    "scabbard": 0, "coat_tail": 0, "coat_back": 0
                }
            }
        ]
    },

    # 9. Bat Home Run (Heavy upward crushing smash)
    "bat_homerun": {
        "name": "bat_homerun",
        "loop": False,
        "length": 0.55,
        "keys": [
            {
                "t": 0.0,
                "root": [0, 1],
                "angles": {
                    "pelvis": -10, "torso": -15, "head": 6,
                    "arm_front_upper": 25, "arm_front_lower": 65, "hand_front": 10,
                    "arm_back_upper": 10, "arm_back_lower": 45, "hand_back": 0,
                    "scabbard": -10, "coat_tail": -12, "coat_back": -10
                }
            },
            {
                "t": 0.15,
                "root": [-2, 2],
                "angles": {
                    "pelvis": -24, "torso": -32, "head": 12,
                    "arm_front_upper": 60, "arm_front_lower": 85, "hand_front": 20,
                    "arm_back_upper": 25, "arm_back_lower": 65, "hand_back": 0,
                    "scabbard": -25, "coat_tail": -30, "coat_back": -25
                }
            },
            {
                "t": 0.25,
                "root": [3, -2],
                "angles": {
                    "pelvis": 25, "torso": 40, "head": -18,
                    "arm_front_upper": -85, "arm_front_lower": 45, "hand_front": -15,
                    "arm_back_upper": -60, "arm_back_lower": 35, "hand_back": 0,
                    "leg_front_upper": 18, "leg_front_lower": -20, "foot_front": 2,
                    "leg_back_upper": -20, "leg_back_lower": 16, "foot_back": -2,
                    "scabbard": 28, "coat_tail": 45, "coat_back": 40
                }
            },
            {
                "t": 0.40,
                "root": [1, 0],
                "angles": {
                    "pelvis": 12, "torso": 20, "head": -8,
                    "arm_front_upper": -65, "arm_front_lower": 40, "hand_front": 0,
                    "arm_back_upper": -35, "arm_back_lower": 30, "hand_back": 0,
                    "scabbard": 14, "coat_tail": 20, "coat_back": 15
                }
            },
            {
                "t": 0.55,
                "root": [0, 0],
                "angles": {
                    "pelvis": 0, "torso": 0, "head": 0,
                    "arm_front_upper": 0, "arm_front_lower": 0, "hand_front": 0,
                    "arm_back_upper": 0, "arm_back_lower": 0, "hand_back": 0,
                    "leg_front_upper": 0, "leg_front_lower": 0, "foot_front": 0,
                    "leg_back_upper": 0, "leg_back_lower": 0, "foot_back": 0,
                    "scabbard": 0, "coat_tail": 0, "coat_back": 0
                }
            }
        ]
    }
}

print(f"Building {len(new_and_refined)} new and refined animation clips...")
for name, data in new_and_refined.items():
    json_path = os.path.join(OUT_DIR, f"{name}.json")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    
    char_backup_dir = r"DONT-OPEN\characters\06_Ronin_Street_Samurai\rig_perfect\animations"
    os.makedirs(char_backup_dir, exist_ok=True)
    with open(os.path.join(char_backup_dir, f"{name}.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        
    generate_review(name, data, num_frames=8, fps=12)
    print(f"  [+] {name}.json written and review generated.")

print("All new and refined animations generated successfully!")
