import json
import math
import os
import numpy as np
from PIL import Image

RONIN_DIR = r"assets\characters\ronin"
RIG_JSON = os.path.join(RONIN_DIR, "rig.json")

with open(RIG_JSON, "r", encoding="utf-8") as f:
    rig_data = json.load(f)

pivots = {k: (v[0], v[1]) for k, v in rig_data["pivots"].items()}
hierarchy = rig_data["hierarchy"]
draw_order = rig_data["draw_order"]
canvas_w, canvas_h = rig_data["canvas"]
feet_x, feet_y = rig_data["feet"]

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
    # Render at 4x for crystal clear pixel evaluation
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
        
        # In texture space, (p_x, p_y) rotates around itself.
        # We can upscale tex first with Nearest, or rotate around center:
        # A clean way in PIL:
        # 1. Scale tex by `scale` using NEAREST (preserves authentic pixel art)
        tex_scaled = tex.resize((canvas_w * scale, canvas_h * scale), Image.NEAREST)
        
        # 2. Pivot in scaled space:
        p_xs = p_x * scale
        p_ys = p_y * scale
        target_xs = pos_x * scale
        target_ys = pos_y * scale
        
        # Rotate image around pivot:
        # In PIL, rotate around center by default, or rotate around translate
        # We can create a larger canvas to avoid clipping during rotation
        pad = max(w, h)
        padded = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
        padded.paste(tex_scaled, (pad, pad))
        
        pivot_on_padded = (pad + p_xs, pad + p_ys)
        # PIL rotate angle is counter-clockwise in degrees
        rot_deg = -math.degrees(rot_rad)
        rotated = padded.rotate(rot_deg, resample=Image.BICUBIC, center=pivot_on_padded)
        
        # Paste onto out_img at offset:
        # The pivot in `rotated` is at `pivot_on_padded`.
        # We want `pivot_on_padded` to land at `(target_xs, target_ys)` in out_img:
        paste_x = int(round(target_xs - pivot_on_padded[0]))
        paste_y = int(round(target_ys - pivot_on_padded[1]))
        
        out_img.alpha_composite(rotated, (paste_x, paste_y))
        
    return out_img

# Test with rest pose
test_img = render_pose_hires({}, (0, 0), scale=4)
test_img.save(r"scratch\test_rest_render.png")
print("Saved scratch\\test_rest_render.png successfully.")
