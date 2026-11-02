import json
import math
import os
import sys
from PIL import Image

RONIN_DIR = r"assets\characters\ronin"
OUT_DIR = r"assets\animations"
ARTIFACTS_DIR = r"C:\Users\mesut\.gemini\antigravity\brain\d9e27150-5a18-4698-b5ae-bc1bd3ee9606"
RIG_JSON = os.path.join(RONIN_DIR, "rig.json")

os.makedirs(OUT_DIR, exist_ok=True)

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
        
    os.makedirs(ARTIFACTS_DIR, exist_ok=True)
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

    # 2. Head-first dive and tucked forward roll, both within the rig pose
    "dive": {
        "name": "dive",
        "loop": False,
        "length": 0.7,
        "keys": [
            {
                "t": 0.0,
                "root": [0, 10],
                "angles": {
                    "pelvis": 40, "torso": 8, "head": -20,
                    "arm_front_upper": -150, "arm_front_lower": -5, "hand_front": 0,
                    "arm_back_upper": -130, "arm_back_lower": -10, "hand_back": 0,
                    "leg_front_upper": -25, "leg_front_lower": 25, "foot_front": 10,
                    "leg_back_upper": 15, "leg_back_lower": 10, "foot_back": 10,
                    "scabbard": 0, "coat_tail": 5, "coat_back": 5
                }
            },
            {
                "t": 0.25,
                "root": [0, 20],
                "angles": {
                    "pelvis": 72, "torso": 8, "head": -30,
                    "arm_front_upper": -165, "arm_front_lower": -5, "hand_front": 0,
                    "arm_back_upper": -155, "arm_back_lower": -8, "hand_back": 0,
                    "leg_front_upper": -3, "leg_front_lower": 5, "foot_front": 10,
                    "leg_back_upper": 8, "leg_back_lower": 6, "foot_back": 10,
                    "scabbard": 0, "coat_tail": 8, "coat_back": 8
                }
            },
            {
                "t": 0.5,
                "root": [0, 22],
                "angles": {
                    "pelvis": 88, "torso": 6, "head": -32,
                    "arm_front_upper": -168, "arm_front_lower": -4, "hand_front": 0,
                    "arm_back_upper": -158, "arm_back_lower": -6, "hand_back": 0,
                    "leg_front_upper": 0, "leg_front_lower": 4, "foot_front": 10,
                    "leg_back_upper": 10, "leg_back_lower": 8, "foot_back": 10,
                    "scabbard": 0, "coat_tail": 10, "coat_back": 12
                }
            },
            {
                "t": 0.7,
                "root": [0, 22],
                "angles": {
                    "pelvis": 110, "torso": 10, "head": -35,
                    "arm_front_upper": -150, "arm_front_lower": -8, "hand_front": 0,
                    "arm_back_upper": -140, "arm_back_lower": -10, "hand_back": 0,
                    "leg_front_upper": 5, "leg_front_lower": 8, "foot_front": 10,
                    "leg_back_upper": 12, "leg_back_lower": 14, "foot_back": 10,
                    "scabbard": 0, "coat_tail": 12, "coat_back": 14
                }
            }
        ]
    },
    "roll": {
        "name": "roll",
        "loop": False,
        "length": 0.4,
        "keys": [
            {
                "t": 0.0,
                "root": [0, 8],
                "angles": {
                    "pelvis": -340, "torso": 15, "head": 20,
                    "arm_front_upper": -40, "arm_front_lower": -30, "hand_front": 0,
                    "arm_back_upper": -30, "arm_back_lower": -25, "hand_back": 0,
                    "leg_front_upper": -60, "leg_front_lower": 70, "foot_front": 0,
                    "leg_back_upper": -50, "leg_back_lower": 60, "foot_back": 0,
                    "scabbard": 5, "coat_tail": 15, "coat_back": 10
                }
            },
            {
                "t": 0.07,
                "root": [2, 18],
                "angles": {
                    "pelvis": -290, "torso": 35, "head": 30,
                    "arm_front_upper": -70, "arm_front_lower": -50, "hand_front": 0,
                    "arm_back_upper": -55, "arm_back_lower": -45, "hand_back": 0,
                    "leg_front_upper": -115, "leg_front_lower": 125, "foot_front": -10,
                    "leg_back_upper": -100, "leg_back_lower": 115, "foot_back": -10,
                    "scabbard": 10, "coat_tail": 30, "coat_back": 20
                }
            },
            {
                "t": 0.15,
                "root": [2, 14],
                "angles": {
                    "pelvis": -200, "torso": 35, "head": 30,
                    "arm_front_upper": -70, "arm_front_lower": -50, "hand_front": 0,
                    "arm_back_upper": -55, "arm_back_lower": -45, "hand_back": 0,
                    "leg_front_upper": -115, "leg_front_lower": 125, "foot_front": -10,
                    "leg_back_upper": -100, "leg_back_lower": 115, "foot_back": -10,
                    "scabbard": 10, "coat_tail": 30, "coat_back": 20
                }
            },
            {
                "t": 0.23,
                "root": [0, 18],
                "angles": {
                    "pelvis": -110, "torso": 35, "head": 30,
                    "arm_front_upper": -70, "arm_front_lower": -50, "hand_front": 0,
                    "arm_back_upper": -55, "arm_back_lower": -45, "hand_back": 0,
                    "leg_front_upper": -115, "leg_front_lower": 125, "foot_front": -10,
                    "leg_back_upper": -100, "leg_back_lower": 115, "foot_back": -10,
                    "scabbard": 10, "coat_tail": 30, "coat_back": 20
                }
            },
            {
                "t": 0.31,
                "root": [0, 18],
                "angles": {
                    "pelvis": -35, "torso": 20, "head": 18,
                    "arm_front_upper": -40, "arm_front_lower": -30, "hand_front": 0,
                    "arm_back_upper": -30, "arm_back_lower": -30, "hand_back": 0,
                    "leg_front_upper": -70, "leg_front_lower": 90, "foot_front": 0,
                    "leg_back_upper": -60, "leg_back_lower": 80, "foot_back": 0,
                    "scabbard": 5, "coat_tail": 15, "coat_back": 10
                }
            },
            {
                "t": 0.4,
                "root": [0, 4],
                "angles": {
                    "pelvis": 0, "torso": 5, "head": 5,
                    "arm_front_upper": 5, "arm_front_lower": 10, "hand_front": 0,
                    "arm_back_upper": 5, "arm_back_lower": 10, "hand_back": 0,
                    "leg_front_upper": -15, "leg_front_lower": 25, "foot_front": 0,
                    "leg_back_upper": -10, "leg_back_lower": 20, "foot_back": 0,
                    "scabbard": 0, "coat_tail": 2, "coat_back": 2
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

# Legs of a planted pose: the angles that keep a foot flat at its rest place plus
# (dx, dy) art px, with the knee forward, while the body sits at `root`.
def leg(side, root, dx=0.0, dy=0.0):
    upper, lower, foot = f"leg_{side}_upper", f"leg_{side}_lower", f"foot_{side}"
    hip, knee, ankle = pivots[upper], pivots[lower], pivots[foot]
    thigh = (knee[0] - hip[0], knee[1] - hip[1])
    shin = (ankle[0] - knee[0], ankle[1] - knee[1])
    thigh_length, shin_length = math.hypot(*thigh), math.hypot(*shin)
    to_x = ankle[0] + dx - hip[0] - root[0]
    to_y = ankle[1] + dy - hip[1] - root[1]
    distance = min(math.hypot(to_x, to_y), thigh_length + shin_length - 0.01)
    base = math.atan2(to_y, to_x)
    bend = math.acos(max(-1.0, min(1.0, (thigh_length ** 2 + distance ** 2 - shin_length ** 2) / (2 * thigh_length * distance))))
    thigh_angle = base - bend
    knee_x, knee_y = thigh_length * math.cos(thigh_angle), thigh_length * math.sin(thigh_angle)
    foot_x, foot_y = distance * math.cos(base), distance * math.sin(base)
    shin_angle = math.atan2(foot_y - knee_y, foot_x - knee_x)
    upper_turn = thigh_angle - math.atan2(thigh[1], thigh[0])
    lower_turn = shin_angle - math.atan2(shin[1], shin[0]) - upper_turn
    return {
        upper: round(math.degrees(upper_turn), 1),
        lower: round(math.degrees(lower_turn), 1),
        foot: round(-math.degrees(upper_turn + lower_turn), 1),
    }


def key(t, root, front=None, back=None, stretch=None, **angles):
    pose = dict(angles)
    pose.update(front or {})
    pose.update(back or {})
    made = {"t": t, "root": list(root), "angles": pose}
    # A bone's length over its drawn length; strikes reach further than the body could.
    made["stretch"] = stretch or {}
    return made


def clip(name, length, loop, keys, **extra):
    return {"name": name, "loop": loop, "length": length, "keys": keys, **extra}


def crouch_pose(t, root, front_foot, back_foot, sway=0):
    return key(t, root, leg("front", root, *front_foot), leg("back", root, *back_foot),
               pelvis=0, torso=18 + sway, head=-16 - sway,
               arm_front_upper=-32, arm_front_lower=-68, hand_front=0,
               arm_back_upper=-18, arm_back_lower=-74, hand_back=0,
               scabbard=-12, coat_tail=6, coat_back=8)


# A lunge forward, then over the leading shoulder: one leg stays long instead of a tucked
# ball, and the turn happens late and fast. It starts a full turn away so it ends at 0.
def roll_key(t, root, pelvis, torso, head, front_arm, back_arm, front_leg, back_leg, coat):
    return key(t, root, pelvis=pelvis, torso=torso, head=head, hand_front=0, hand_back=0,
               arm_front_upper=front_arm[0], arm_front_lower=front_arm[1],
               arm_back_upper=back_arm[0], arm_back_lower=back_arm[1],
               leg_front_upper=front_leg[0], leg_front_lower=front_leg[1], foot_front=0,
               leg_back_upper=back_leg[0], leg_back_lower=back_leg[1], foot_back=0,
               scabbard=coat / 3, coat_tail=coat, coat_back=coat)


new_and_refined["roll"] = clip("roll", 0.4, False, [
    roll_key(0.0, (0, 8), -352, 12, -6, (-30, -20), (10, -20), (-30, 45), (10, 20), 10),
    roll_key(0.1, (14, 20), -310, 20, -30, (-98, -5), (-84, -10), (-50, 70), (32, 20), 44),
    roll_key(0.18, (12, -6), -210, 50, 20, (-140, -60), (-70, -40), (-30, 40), (-10, 30), 30),
    roll_key(0.27, (6, 16), -100, 30, 20, (-90, -50), (-40, -40), (-85, 100), (-40, 60), 20),
    roll_key(0.34, (2, 18), -30, 28, -10, (-50, -40), (10, -40), (-70, 90), (-35, 70), 10),
    roll_key(0.4, (0, 6), 0, 6, 0, (0, 0), (0, 0), (-15, 25), (-10, 20), 0),
], linear=True)

# Standing still is alive: the chest fills and sinks, weight drifts, hands and coat sway.
def idle_pose(t, breath, drift):
    root = (drift, breath * 2.6)
    return key(t, root, leg("front", root, -1), leg("back", root, 1),
               pelvis=0, torso=2 + breath * 3, head=-1 - breath * 3,
               arm_front_upper=-4 + breath * 7, arm_front_lower=-10 - breath * 8, hand_front=0,
               arm_back_upper=-3 - breath * 6, arm_back_lower=-10 - breath * 8, hand_back=0,
               scabbard=breath * 2, coat_tail=1 + breath * 5, coat_back=1 + breath * 6)


new_and_refined["idle"] = clip("idle", 1.8, True, [
    idle_pose(0.0, 0.0, -0.8),
    idle_pose(0.9, 1.0, 0.8),
    idle_pose(1.8, 0.0, -0.8),
])

# Holding a gun steady breathes far less, so the stretched arms stay on the aim.
new_and_refined["aim_idle"] = clip("aim_idle", 1.8, True, [
    idle_pose(0.0, 0.0, 0.0),
    idle_pose(0.9, 0.2, 0.0),
    idle_pose(1.8, 0.0, 0.0),
])

# 3. Jump in three clear stages and a landing that sinks deep and springs back
SQUAT = (0, 16)
LAND_DEEP = (0, 7)
new_and_refined.update({
    "crouch_idle": clip("crouch_idle", 0.8, True, [
        crouch_pose(0.0, SQUAT, (-7, 0), (9, 0)),
        crouch_pose(0.4, (0, 17), (-7, 0), (9, 0), 2),
        crouch_pose(0.8, SQUAT, (-7, 0), (9, 0)),
    ]),
    "crouch_walk": clip("crouch_walk", 0.6, True, [
        crouch_pose(0.0, SQUAT, (-3, 0), (12, 0)),
        crouch_pose(0.15, (0, 15), (-7, 0), (9, -2), 2),
        crouch_pose(0.3, SQUAT, (-11, 0), (6, 0)),
        crouch_pose(0.45, (0, 15), (-7, -2), (9, 0), 2),
        crouch_pose(0.6, SQUAT, (-3, 0), (12, 0)),
    ], reference_speed=60.0),
    # Rising: the whole body one long line, arms thrown up, toes pointing down.
    "jump_rise": clip("jump_rise", 0.3, False, [
        key(0.0, (0, -3), pelvis=-2, torso=-6, head=-14,
            arm_front_upper=-150, arm_front_lower=-8, hand_front=0,
            arm_back_upper=-125, arm_back_lower=-14, hand_back=0,
            leg_front_upper=-6, leg_front_lower=10, foot_front=34,
            leg_back_upper=14, leg_back_lower=16, foot_back=38,
            scabbard=14, coat_tail=10, coat_back=8),
        key(0.3, (0, -4), pelvis=-1, torso=-4, head=-12,
            arm_front_upper=-138, arm_front_lower=-14, hand_front=0,
            arm_back_upper=-112, arm_back_lower=-20, hand_back=0,
            leg_front_upper=-16, leg_front_lower=24, foot_front=30,
            leg_back_upper=10, leg_back_lower=26, foot_back=34,
            scabbard=10, coat_tail=16, coat_back=14),
    ]),
    # The top of the jump: knees tucked up, arms open, the coat floating out.
    "jump_apex": clip("jump_apex", 0.4, False, [
        key(0.0, (0, -5), pelvis=6, torso=8, head=-8,
            arm_front_upper=-92, arm_front_lower=-34, hand_front=0,
            arm_back_upper=70, arm_back_lower=-30, hand_back=0,
            leg_front_upper=-78, leg_front_lower=92, foot_front=-6,
            leg_back_upper=-42, leg_back_lower=84, foot_back=-8,
            scabbard=-4, coat_tail=34, coat_back=30),
        key(0.4, (0, -5), pelvis=4, torso=6, head=-2,
            arm_front_upper=-104, arm_front_lower=-30, hand_front=0,
            arm_back_upper=84, arm_back_lower=-26, hand_back=0,
            leg_front_upper=-70, leg_front_lower=84, foot_front=-2,
            leg_back_upper=-34, leg_back_lower=76, foot_back=-4,
            scabbard=-8, coat_tail=46, coat_back=42),
    ]),
    # Falling: legs reaching for the floor, arms up and shaking, the coat blown upward.
    "fall": clip("fall", 0.5, True, [
        key(0.0, (0, -2), pelvis=-3, torso=-8, head=14,
            arm_front_upper=-128, arm_front_lower=-24, hand_front=0,
            arm_back_upper=124, arm_back_lower=26, hand_back=0,
            leg_front_upper=-18, leg_front_lower=20, foot_front=-2,
            leg_back_upper=20, leg_back_lower=12, foot_back=-6,
            scabbard=-18, coat_tail=66, coat_back=60),
        key(0.25, (0, -2), pelvis=-3, torso=-7, head=16,
            arm_front_upper=-142, arm_front_lower=-14, hand_front=0,
            arm_back_upper=136, arm_back_lower=18, hand_back=0,
            leg_front_upper=-22, leg_front_lower=26, foot_front=-4,
            leg_back_upper=24, leg_back_lower=16, foot_back=-8,
            scabbard=-22, coat_tail=78, coat_back=72),
        key(0.5, (0, -2), pelvis=-3, torso=-8, head=14,
            arm_front_upper=-128, arm_front_lower=-24, hand_front=0,
            arm_back_upper=124, arm_back_lower=26, hand_back=0,
            leg_front_upper=-18, leg_front_lower=20, foot_front=-2,
            leg_back_upper=20, leg_back_lower=12, foot_back=-6,
            scabbard=-18, coat_tail=66, coat_back=60),
    ]),
    # Hits the floor already sunk in, hangs there a moment, then springs up.
    "land": clip("land", 0.75, False, [
        key(0.0, LAND_DEEP, leg("front", LAND_DEEP, -4), leg("back", LAND_DEEP, 4),
            pelvis=0, torso=12, head=-8,
            arm_front_upper=-22, arm_front_lower=-10, hand_front=0,
            arm_back_upper=20, arm_back_lower=-12, hand_back=0,
            scabbard=-8, coat_tail=18, coat_back=14),
        key(0.28, (0, 5), leg("front", (0, 5), -3), leg("back", (0, 5), 3),
            pelvis=0, torso=9, head=-6,
            arm_front_upper=-16, arm_front_lower=-12, hand_front=0,
            arm_back_upper=14, arm_back_lower=-12, hand_back=0,
            scabbard=-5, coat_tail=10, coat_back=8),
        key(0.58, (0, 2), leg("front", (0, 2), -1), leg("back", (0, 2), 1),
            pelvis=0, torso=3, head=-2,
            arm_front_upper=-5, arm_front_lower=-6, hand_front=0,
            arm_back_upper=4, arm_back_lower=-6, hand_back=0,
            scabbard=2, coat_tail=4, coat_back=3),
        key(0.75, (0, 0), leg("front", (0, 0)), leg("back", (0, 0)),
            pelvis=0, torso=0, head=0,
            arm_front_upper=0, arm_front_lower=0, hand_front=0,
            arm_back_upper=0, arm_back_lower=0, hand_back=0,
            scabbard=0, coat_tail=0, coat_back=0),
    ]),
})

# 4. Strikes you can read: a big wind-up, a limb that keeps moving through the hit window,
# and a slow return. Punches swing up from low behind in a curve on a bent arm and carry on
# past the target; a straight arm shot out and held reads as a stab. Bodies are cartoon, not anatomy.
def rest_pose(t):
    return key(t, (0, 0), leg("front", (0, 0)), leg("back", (0, 0)),
               stretch={"arm_front_upper": 1, "arm_front_lower": 1, "arm_back_upper": 1, "arm_back_lower": 1,
                        "leg_front_upper": 1, "leg_front_lower": 1},
               pelvis=0, torso=0, head=0,
               arm_front_upper=0, arm_front_lower=0, hand_front=0,
               arm_back_upper=0, arm_back_lower=0, hand_back=0,
               scabbard=0, coat_tail=0, coat_back=0)


def cocked(t, punching_front):
    root = (-7, 5)
    strike = dict(arm_front_upper=60, arm_front_lower=-120, arm_back_upper=-34, arm_back_lower=-72)
    if not punching_front:
        strike = dict(arm_front_upper=-34, arm_front_lower=-72, arm_back_upper=60, arm_back_lower=-120)
    return key(t, root, leg("front", root, -8), leg("back", root, 2),
               pelvis=-4, torso=-24, head=12, hand_front=0, hand_back=0,
               scabbard=8, coat_tail=-12, coat_back=-10, **strike)


def swing(t, punching_front, slide, height, bend, reach):
    root = (slide, 4)
    long = {"arm_front_upper": reach, "arm_front_lower": reach} if punching_front else {"arm_back_upper": reach, "arm_back_lower": reach}
    strike = dict(arm_front_upper=height, arm_front_lower=bend, arm_back_upper=58, arm_back_lower=-58)
    if not punching_front:
        strike = dict(arm_front_upper=62, arm_front_lower=-60, arm_back_upper=height, arm_back_lower=bend)
    return key(t, root, leg("front", root, -4), leg("back", root, slide + 6), stretch=long,
               pelvis=8, torso=28, head=-20, hand_front=0, hand_back=0,
               scabbard=-14, coat_tail=34, coat_back=28, **strike)


def punch(name, punching_front, height=-118):
    return clip(name, 0.4, False, [
        rest_pose(0.0),
        cocked(0.06, punching_front),
        swing(0.09, punching_front, 4, -46, -22, 1.15),
        swing(0.12, punching_front, 13, height + 14, -30, 1.25),
        swing(0.2, punching_front, 17, height - 14, -42, 1.15),
        rest_pose(0.4),
    ], linear=True)


HOOK_REACH = (12, 7)
KICK_AIR = (6, -3)
new_and_refined.update({
    "jab_1": punch("jab_1", True),
    "jab_2": punch("jab_2", False),
    "jab_3": punch("jab_3", True, -134),
    # A full turn of the body: the arm comes round from behind and carries on past the target.
    "hook": clip("hook", 0.56, False, [
        rest_pose(0.0),
        key(0.13, (-10, 8), leg("front", (-10, 8), -9), leg("back", (-10, 8), 3),
            pelvis=-8, torso=-34, head=16, hand_front=0, hand_back=0,
            arm_front_upper=92, arm_front_lower=-44, arm_back_upper=-48, arm_back_lower=-60,
            scabbard=14, coat_tail=-26, coat_back=-22),
        key(0.18, HOOK_REACH, leg("front", HOOK_REACH, -4), leg("back", HOOK_REACH, 18),
            stretch={"arm_front_upper": 1.3, "arm_front_lower": 1.3},
            pelvis=10, torso=36, head=-24, hand_front=0, hand_back=0,
            arm_front_upper=-108, arm_front_lower=-32, arm_back_upper=64, arm_back_lower=-50,
            scabbard=-18, coat_tail=46, coat_back=40),
        key(0.26, (16, 4), leg("front", (16, 4), 0), leg("back", (16, 4), 20),
            stretch={"arm_front_upper": 1.15, "arm_front_lower": 1.15},
            pelvis=10, torso=40, head=-26, hand_front=0, hand_back=0,
            arm_front_upper=-165, arm_front_lower=-48, arm_back_upper=70, arm_back_lower=-46,
            scabbard=-20, coat_tail=56, coat_back=50),
        rest_pose(0.56),
    ], linear=True),
    # Knee up first, then one long leg shot out and held, the body thrown back behind it.
    "jump_kick": clip("jump_kick", 0.55, False, [
        rest_pose(0.0),
        key(0.08, (-4, -2), pelvis=-6, torso=14, head=-6, hand_front=0, hand_back=0,
            arm_front_upper=-46, arm_front_lower=-60, arm_back_upper=40, arm_back_lower=-60,
            leg_front_upper=-96, leg_front_lower=104, foot_front=-8,
            leg_back_upper=-30, leg_back_lower=86, foot_back=-6,
            scabbard=-6, coat_tail=20, coat_back=18),
        key(0.1, KICK_AIR, stretch={"leg_front_upper": 1.5, "leg_front_lower": 1.5},
            pelvis=-16, torso=-18, head=16, hand_front=0, hand_back=0,
            arm_front_upper=62, arm_front_lower=-30, arm_back_upper=94, arm_back_lower=-24,
            leg_front_upper=-94, leg_front_lower=2, foot_front=-20,
            leg_back_upper=-22, leg_back_lower=92, foot_back=-8,
            scabbard=18, coat_tail=62, coat_back=56),
        key(0.4, KICK_AIR, stretch={"leg_front_upper": 1.45, "leg_front_lower": 1.45},
            pelvis=-14, torso=-16, head=14, hand_front=0, hand_back=0,
            arm_front_upper=70, arm_front_lower=-24, arm_back_upper=102, arm_back_lower=-20,
            leg_front_upper=-90, leg_front_lower=4, foot_front=-20,
            leg_back_upper=-20, leg_back_lower=88, foot_back=-8,
            scabbard=20, coat_tail=70, coat_back=64),
        key(0.55, (0, 0), pelvis=0, torso=0, head=0, hand_front=0, hand_back=0,
            stretch={"leg_front_upper": 1, "leg_front_lower": 1, "arm_front_upper": 1, "arm_front_lower": 1,
                     "arm_back_upper": 1, "arm_back_lower": 1},
            arm_front_upper=0, arm_front_lower=0, arm_back_upper=0, arm_back_lower=0,
            leg_front_upper=-20, leg_front_lower=30, foot_front=0,
            leg_back_upper=-10, leg_back_lower=30, foot_back=0,
            scabbard=0, coat_tail=0, coat_back=0),
    ], linear=True),
})

# Usage: python tools/build_refined_animations.py [clip ...] [--review]
# Names clips to build (default all). --review also renders contact sheets (slow).
wanted = [arg for arg in sys.argv[1:] if not arg.startswith("--")]
print(f"Building {len(wanted) or len(new_and_refined)} new and refined animation clips...")
for name, data in new_and_refined.items():
    if wanted and name not in wanted:
        continue
    json_path = os.path.join(OUT_DIR, f"{name}.json")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    if "--review" in sys.argv:
        generate_review(name, data, num_frames=8, fps=12)
    print(f"  [+] {name}.json written.")

print("All new and refined animations generated successfully!")
