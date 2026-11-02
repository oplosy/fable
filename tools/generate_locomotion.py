import os
import json
import math
import numpy as np
from PIL import Image, ImageDraw

RIG_DIR = r"C:\Users\mesut\Desktop\workspace\A-projects\fable\assets\characters\ronin"
ANIM_DIR = r"C:\Users\mesut\Desktop\workspace\A-projects\fable\assets\animations"
PERFECT_DIR = r"C:\Users\mesut\Desktop\workspace\A-projects\fable\DONT-OPEN\characters\06_Ronin_Street_Samurai\rig_perfect"
os.makedirs(ANIM_DIR, exist_ok=True)

with open(os.path.join(RIG_DIR, "rig.json")) as f:
    rig = json.load(f)

pivots = {k: np.array(v, dtype=float) for k, v in rig["pivots"].items()}
hierarchy = rig["hierarchy"]
draw_order = rig["draw_order"]

def render_pose(angles, root_offset=(0, 0), canvas_size=(64, 96)):
    transforms = {}
    def get_transform(part):
        if part in transforms:
            return transforms[part]
        parent = hierarchy.get(part, "")
        local_pivot = pivots[part]
        local_rot = math.radians(angles.get(part, 0.0))
        
        if parent == "":
            global_pivot = local_pivot + np.array(root_offset, dtype=float)
            global_rot = local_rot
        else:
            p_pivot, p_rot = get_transform(parent)
            parent_local_pivot = pivots[parent]
            offset = local_pivot - parent_local_pivot
            cos_p = math.cos(p_rot)
            sin_p = math.sin(p_rot)
            rot_offset = np.array([
                cos_p * offset[0] - sin_p * offset[1],
                sin_p * offset[0] + cos_p * offset[1]
            ])
            global_pivot = p_pivot + rot_offset
            global_rot = p_rot + local_rot
            
        transforms[part] = (global_pivot, global_rot)
        return transforms[part]

    for part in draw_order:
        get_transform(part)

    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    for part in draw_order:
        img_path = os.path.join(RIG_DIR, f"{part}.png")
        if not os.path.exists(img_path):
            continue
        part_img = Image.open(img_path).convert("RGBA")
        g_pivot, g_rot = transforms[part]
        l_pivot = pivots[part]
        
        if abs(g_rot) < 1e-4 and np.allclose(g_pivot, l_pivot):
            canvas.alpha_composite(part_img)
        else:
            deg = -math.degrees(g_rot)
            rot_img = part_img.rotate(deg, resample=Image.NEAREST, center=(l_pivot[0], l_pivot[1]))
            dx = int(round(g_pivot[0] - l_pivot[0]))
            dy = int(round(g_pivot[1] - l_pivot[1]))
            if dx != 0 or dy != 0:
                translated = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
                translated.paste(rot_img, (dx, dy), rot_img)
                rot_img = translated
            canvas.alpha_composite(rot_img)
            
    return canvas

# =========================================================================
# 1. THE 8-FRAME STREET RONIN WALK CYCLE (0.64s loop, ref_speed=120)
# Classical Mechanics: Contact -> Down (Squash) -> Passing -> Up (Push)
# =========================================================================

walk_keys = [
    # Frame 1: Contact 1 (Left heel touches, right toe pushing)
    {
        "t": 0.00,
        "root": [0, 0],
        "angles": {
            "pelvis": 2, "torso": -2, "head": 0,
            "leg_front_upper": -26, "leg_front_lower": 14, "foot_front": 12, # heel strike
            "leg_back_upper": 24, "leg_back_lower": 12, "foot_back": -36, # toe push
            "arm_front_upper": 22, "arm_front_lower": 12, "hand_front": 5,
            "arm_back_upper": -24, "arm_back_lower": 18, "hand_back": 0,
            "scabbard": -4, "coat_tail": -6, "coat_back": -4
        }
    },
    # Frame 2: Down 1 (Squash: weight drops onto front leg, foot completely flat!)
    {
        "t": 0.08,
        "root": [0, 2], # 2 px body squash!
        "angles": {
            "pelvis": 0, "torso": 3, "head": -1,
            "leg_front_upper": -10, "leg_front_lower": 28, "foot_front": -18, # 100% FLAT sole on y=92
            "leg_back_upper": 18, "leg_back_lower": 45, "foot_back": -20, # lifting off
            "arm_front_upper": 12, "arm_front_lower": 8, "hand_front": 0,
            "arm_back_upper": -15, "arm_back_lower": 14, "hand_back": 0,
            "scabbard": 2, "coat_tail": 4, "coat_back": 2
        }
    },
    # Frame 3: Passing 1 (Weight over supporting front leg, back leg swinging through)
    {
        "t": 0.16,
        "root": [0, -1], # body rising
        "angles": {
            "pelvis": -2, "torso": 1, "head": 0,
            "leg_front_upper": 8, "leg_front_lower": 6, "foot_front": -14, # flat supporting
            "leg_back_upper": -16, "leg_back_lower": 65, "foot_back": 10, # knee bent high, clearing floor!
            "arm_front_upper": -8, "arm_front_lower": 10, "hand_front": -5,
            "arm_back_upper": 8, "arm_back_lower": 12, "hand_back": 0,
            "scabbard": 0, "coat_tail": -8, "coat_back": -5
        }
    },
    # Frame 4: Up 1 (Push-off: supporting leg drives upward, body at highest peak)
    {
        "t": 0.24,
        "root": [0, -2], # highest peak!
        "angles": {
            "pelvis": -1, "torso": 0, "head": 0,
            "leg_front_upper": 24, "leg_front_lower": 8, "foot_front": -32, # rolling off ball of foot
            "leg_back_upper": -24, "leg_back_lower": 20, "foot_back": 4, # reaching forward
            "arm_front_upper": -20, "arm_front_lower": 16, "hand_front": -5,
            "arm_back_upper": 20, "arm_back_lower": 14, "hand_back": 0,
            "scabbard": -3, "coat_tail": -10, "coat_back": -8
        }
    },
    # Frame 5: Contact 2 (Mirror: Right heel touches, left toe pushing)
    {
        "t": 0.32,
        "root": [0, 0],
        "angles": {
            "pelvis": -2, "torso": 2, "head": 0,
            "leg_front_upper": 24, "leg_front_lower": 12, "foot_front": -36, # toe push
            "leg_back_upper": -26, "leg_back_lower": 14, "foot_back": 12, # heel strike
            "arm_front_upper": -24, "arm_front_lower": 18, "hand_front": 0,
            "arm_back_upper": 22, "arm_back_lower": 12, "hand_back": 5,
            "scabbard": 4, "coat_tail": 6, "coat_back": 4
        }
    },
    # Frame 6: Down 2 (Squash: weight drops onto back leg, foot flat)
    {
        "t": 0.40,
        "root": [0, 2], # 2 px body squash!
        "angles": {
            "pelvis": 0, "torso": 3, "head": -1,
            "leg_front_upper": 18, "leg_front_lower": 45, "foot_front": -20,
            "leg_back_upper": -10, "leg_back_lower": 28, "foot_back": -18, # 100% FLAT sole
            "arm_front_upper": -15, "arm_front_lower": 14, "hand_front": 0,
            "arm_back_upper": 12, "arm_back_lower": 8, "hand_back": 0,
            "scabbard": -2, "coat_tail": 4, "coat_back": 2
        }
    },
    # Frame 7: Passing 2 (Supporting back leg, front leg swinging through)
    {
        "t": 0.48,
        "root": [0, -1],
        "angles": {
            "pelvis": 2, "torso": 1, "head": 0,
            "leg_front_upper": -16, "leg_front_lower": 65, "foot_front": 10, # knee bent high!
            "leg_back_upper": 8, "leg_back_lower": 6, "foot_back": -14, # flat supporting
            "arm_front_upper": 8, "arm_front_lower": 12, "hand_front": 0,
            "arm_back_upper": -8, "arm_back_lower": 10, "hand_back": -5,
            "scabbard": 0, "coat_tail": -8, "coat_back": -5
        }
    },
    # Frame 8: Up 2 (Push-off on back foot, front leg reaching forward)
    {
        "t": 0.56,
        "root": [0, -2],
        "angles": {
            "pelvis": 1, "torso": 0, "head": 0,
            "leg_front_upper": -24, "leg_front_lower": 20, "foot_front": 4,
            "leg_back_upper": 24, "leg_back_lower": 8, "foot_back": -32, # pushing off toe
            "arm_front_upper": 20, "arm_front_lower": 14, "hand_front": 0,
            "arm_back_upper": -20, "arm_back_lower": 16, "hand_back": -5,
            "scabbard": 3, "coat_tail": -10, "coat_back": -8
        }
    }
]

walk_data = {
    "name": "walk",
    "loop": True,
    "length": 0.64,
    "reference_speed": 120.0,
    "events": [{"t": 0.08, "name": "step"}, {"t": 0.40, "name": "step"}],
    "keys": walk_keys
}

# =========================================================================
# 2. THE 8-FRAME NINJA SPRINT RUN CYCLE (0.40s loop, ref_speed=200)
# Forward Lean (20°), Pumping Arms, Full Flight Phases
# =========================================================================

run_keys = [
    # Frame 1: Contact 1 (Aggressive forward stride, heel touches, body low)
    {
        "t": 0.00,
        "root": [0, 2],
        "angles": {
            "pelvis": 10, "torso": 20, "head": -15, # forward lean!
            "leg_front_upper": -48, "leg_front_lower": 25, "foot_front": 23, # reaching stride
            "leg_back_upper": 35, "leg_back_lower": 20, "foot_back": -55,
            "arm_front_upper": 45, "arm_front_lower": 75, "hand_front": 10, # pumping forward
            "arm_back_upper": -55, "arm_back_lower": 70, "hand_back": -10, # pumping back
            "scabbard": -12, "coat_tail": -18, "coat_back": -15 # trailing in wind
        }
    },
    # Frame 2: Down / Compression 1 (Weight absorbs, knee deep flex, foot flat)
    {
        "t": 0.05,
        "root": [0, 4], # deep compression!
        "angles": {
            "pelvis": 8, "torso": 22, "head": -16,
            "leg_front_upper": -25, "leg_front_lower": 48, "foot_front": -23, # flat foot driving
            "leg_back_upper": 20, "leg_back_lower": 65, "foot_back": -25, # knee tucking
            "arm_front_upper": 25, "arm_front_lower": 80, "hand_front": 5,
            "arm_back_upper": -35, "arm_back_lower": 75, "hand_back": -5,
            "scabbard": -8, "coat_tail": -22, "coat_back": -18
        }
    },
    # Frame 3: Push-off 1 (Explosive drive off front leg)
    {
        "t": 0.10,
        "root": [0, 0],
        "angles": {
            "pelvis": 12, "torso": 19, "head": -14,
            "leg_front_upper": 32, "leg_front_lower": 15, "foot_front": -47, # explosive drive
            "leg_back_upper": -40, "leg_back_lower": 80, "foot_back": 15, # knee driving forward
            "arm_front_upper": -20, "arm_front_lower": 75, "hand_front": 0,
            "arm_back_upper": 25, "arm_back_lower": 75, "hand_back": 0,
            "scabbard": -14, "coat_tail": -25, "coat_back": -20
        }
    },
    # Frame 4: Flight 1 (AIRBORNE! Both feet off the ground, maximum extension)
    {
        "t": 0.15,
        "root": [0, -3], # airborne peak!
        "angles": {
            "pelvis": 14, "torso": 18, "head": -12,
            "leg_front_upper": 45, "leg_front_lower": 10, "foot_front": -20, # trailing leg in air
            "leg_back_upper": -52, "leg_back_lower": 40, "foot_back": 12, # leading leg in air
            "arm_front_upper": -50, "arm_front_lower": 70, "hand_front": -10,
            "arm_back_upper": 45, "arm_back_lower": 75, "hand_back": 10,
            "scabbard": -16, "coat_tail": -30, "coat_back": -25 # maximum flap
        }
    },
    # Frame 5: Contact 2 (Mirror: Opposite heel strikes down, low stance)
    {
        "t": 0.20,
        "root": [0, 2],
        "angles": {
            "pelvis": 10, "torso": 20, "head": -15,
            "leg_front_upper": 35, "leg_front_lower": 20, "foot_front": -55,
            "leg_back_upper": -48, "leg_back_lower": 25, "foot_back": 23,
            "arm_front_upper": -55, "arm_front_lower": 70, "hand_front": -10,
            "arm_back_upper": 45, "arm_back_lower": 75, "hand_back": 10,
            "scabbard": -12, "coat_tail": -18, "coat_back": -15
        }
    },
    # Frame 6: Down / Compression 2
    {
        "t": 0.25,
        "root": [0, 4],
        "angles": {
            "pelvis": 8, "torso": 22, "head": -16,
            "leg_front_upper": 20, "leg_front_lower": 65, "foot_front": -25,
            "leg_back_upper": -25, "leg_back_lower": 48, "foot_back": -23,
            "arm_front_upper": -35, "arm_front_lower": 75, "hand_front": -5,
            "arm_back_upper": 25, "arm_back_lower": 80, "hand_back": 5,
            "scabbard": -8, "coat_tail": -22, "coat_back": -18
        }
    },
    # Frame 7: Push-off 2
    {
        "t": 0.30,
        "root": [0, 0],
        "angles": {
            "pelvis": 12, "torso": 19, "head": -14,
            "leg_front_upper": -40, "leg_front_lower": 80, "foot_front": 15,
            "leg_back_upper": 32, "leg_back_lower": 15, "foot_back": -47,
            "arm_front_upper": 25, "arm_front_lower": 75, "hand_front": 0,
            "arm_back_upper": -20, "arm_back_lower": 75, "hand_back": 0,
            "scabbard": -14, "coat_tail": -25, "coat_back": -20
        }
    },
    # Frame 8: Flight 2 (AIRBORNE! Second flight phase)
    {
        "t": 0.35,
        "root": [0, -3],
        "angles": {
            "pelvis": 14, "torso": 18, "head": -12,
            "leg_front_upper": -52, "leg_front_lower": 40, "foot_front": 12,
            "leg_back_upper": 45, "leg_back_lower": 10, "foot_back": -20,
            "arm_front_upper": 45, "arm_front_lower": 75, "hand_front": 10,
            "arm_back_upper": -50, "arm_back_lower": 70, "hand_back": -10,
            "scabbard": -16, "coat_tail": -30, "coat_back": -25
        }
    }
]

run_data = {
    "name": "run",
    "loop": True,
    "length": 0.40,
    "reference_speed": 200.0,
    "events": [{"t": 0.05, "name": "step"}, {"t": 0.25, "name": "step"}],
    "keys": run_keys
}

# Save JSONs
for folder in [ANIM_DIR, PERFECT_DIR]:
    with open(os.path.join(folder, "walk.json"), "w") as f:
        json.dump(walk_data, f, indent=2)
    with open(os.path.join(folder, "run.json"), "w") as f:
        json.dump(run_data, f, indent=2)

print("Saved walk.json and run.json")

# =========================================================================
# Render Visual 4x Review Strips and Animated GIFs
# =========================================================================

def render_anim_sheet(title, keys, duration, out_path, is_run=False):
    num_frames = len(keys)
    w_scale = 4
    cell_w = 64 * w_scale
    cell_h = 96 * w_scale
    padding = 10
    total_w = num_frames * cell_w + (num_frames + 1) * padding
    total_h = cell_h + 80
    
    sheet = Image.new("RGBA", (total_w, total_h), (20, 22, 30, 255))
    draw = ImageDraw.Draw(sheet)
    
    frames_list = []
    
    for i, k in enumerate(keys):
        root = k.get("root", [0, 0])
        frame = render_pose(k["angles"], root_offset=root)
        frame_4x = frame.resize((cell_w, cell_h), Image.NEAREST)
        frames_list.append(frame_4x)
        
        x_cell = padding + i * (cell_w + padding)
        y_cell = 50
        
        # Draw ground line (y = 93 on 64x96)
        floor_y = y_cell + 93 * w_scale
        draw.line([(x_cell - 2, floor_y), (x_cell + cell_w + 2, floor_y)], fill=(70, 80, 100, 255), width=2)
        
        # Paste frame
        sheet.paste(frame_4x, (x_cell, y_cell), frame_4x)
        
        # Label frame
        step_phase = ""
        if not is_run:
            phases = ["1. Contact", "2. Down (Squash)", "3. Passing", "4. Up (Push)",
                      "5. Contact", "6. Down (Squash)", "7. Passing", "8. Up (Push)"]
            step_phase = phases[i]
        else:
            phases = ["1. Strike", "2. Down (Squash)", "3. Drive", "4. FLIGHT (Air!)",
                      "5. Strike", "6. Down (Squash)", "7. Drive", "8. FLIGHT (Air!)"]
            step_phase = phases[i]
            
        draw.text((x_cell + 5, 10), f"Frame {i+1} ({k['t']:.2f}s)", fill=(240, 240, 250, 255))
        color_tag = (100, 255, 160, 255) if "FLIGHT" in step_phase else ((255, 200, 80, 255) if "Down" in step_phase else (180, 190, 210, 255))
        draw.text((x_cell + 5, 26), step_phase, fill=color_tag)

    sheet.save(out_path)
    print(f"Saved review sheet to {out_path}")
    
    # Also save as animated GIF
    gif_path = out_path.replace(".png", ".gif")
    frame_ms = int((duration / num_frames) * 1000)
    frames_list[0].save(gif_path, save_all=True, append_images=frames_list[1:], duration=frame_ms, loop=0)
    print(f"Saved animated GIF to {gif_path}")

render_anim_sheet("Ronin Walk Cycle (0.64s)", walk_keys, 0.64, os.path.join(PERFECT_DIR, "walk_review_4x.png"), is_run=False)
render_anim_sheet("Ronin Ninja Run Cycle (0.40s)", run_keys, 0.40, os.path.join(PERFECT_DIR, "run_review_4x.png"), is_run=True)
print("Locomotion generation complete!")
