import math
from PIL import Image, ImageDraw

SIZE = (192, 128)
FEET = (96.0, 118.0)

# Master Palette
OUTLINE = (18, 16, 26, 255)

# Primary armor / body (white/silver base for team color modulation)
HI = (255, 255, 255, 255)
MID = (220, 226, 236, 255)
SHD = (160, 170, 188, 255)
DARK = (110, 120, 138, 255)

# Far shaded limbs (depth cue)
FAR_HI = (170, 178, 196, 255)
FAR_MID = (130, 138, 156, 255)
FAR_SHD = (85, 92, 110, 255)

# Glowing visor
VISOR = (60, 230, 255, 255)
VISOR_CORE = (210, 250, 255, 255)

# Gold / Bronze accent
GOLD_HI = (255, 225, 110, 255)
GOLD_MID = (215, 165, 45, 255)
GOLD_SHD = (140, 95, 25, 255)

def draw_circle(draw, cx, cy, r, fill):
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)

def draw_capsule(draw, p1, p2, r, fill):
    dx = p2[0] - p1[0]
    dy = p2[1] - p1[1]
    dist = math.hypot(dx, dy)
    steps = max(1, int(dist * 2))
    for s in range(steps + 1):
        t = s / steps
        cx = p1[0] + dx * t
        cy = p1[1] + dy * t
        draw_circle(draw, cx, cy, r, fill)

def draw_shaded_capsule(draw, p1, p2, r, fill_shd, fill_mid, fill_hi=None):
    draw_capsule(draw, p1, p2, r, fill_shd)
    if fill_mid:
        draw_capsule(draw, (p1[0] + 0.8, p1[1] - 0.8), (p2[0] + 0.8, p2[1] - 0.8), max(1.0, r - 1.2), fill_mid)
    if fill_hi and r >= 3.5:
        draw_capsule(draw, (p1[0] + 1.5, p1[1] - 1.5), (p2[0] + 1.5, p2[1] - 1.5), max(1.0, r - 2.5), fill_hi)

def draw_boot(draw, pos, is_far=False, toe_dir=1.0):
    # pos: ankle center
    x, y = pos
    shd = FAR_SHD if is_far else SHD
    mid = FAR_MID if is_far else MID
    hi = FAR_HI if is_far else HI

    x0 = x - 6 * toe_dir
    x1 = x + 8 * toe_dir
    y0 = y - 4
    y1 = y + 4
    left, right = min(x0, x1), max(x0, x1)

    draw.rounded_rectangle([left, y0, right, y1], radius=3, fill=shd)
    draw.rounded_rectangle([left + 1, y0 + 1, right - 1, y1 - 1], radius=2, fill=mid)
    if not is_far:
        toe_left = right - 5 if toe_dir > 0 else left
        toe_right = right if toe_dir > 0 else left + 5
        draw.rectangle([toe_left, y0 + 1, toe_right, y1 - 1], fill=GOLD_MID)

def draw_gauntlet(draw, pos, angle_deg=-20.0, is_far=False, scale=1.0):
    x, y = pos
    shd = FAR_SHD if is_far else SHD
    mid = FAR_MID if is_far else MID
    hi = FAR_HI if is_far else HI

    rad = 5.5 * scale
    draw.rounded_rectangle([x - rad, y - rad, x + rad + 1, y + rad + 1], radius=3, fill=shd)
    draw.rounded_rectangle([x - rad + 1.5, y - rad + 1.5, x + rad - 0.5, y + rad - 0.5], radius=2, fill=mid)
    if not is_far:
        draw.rounded_rectangle([x - rad + 3, y - rad + 2.5, x + rad - 2, y + rad - 2.5], radius=2, fill=hi)
        # Knuckle steel plate
        rad_r = math.radians(angle_deg)
        along = (math.cos(rad_r), math.sin(rad_r))
        ortho = (-along[1], along[0])
        p1 = (x + along[0] * 4 + ortho[0] * 3, y + along[1] * 4 + ortho[1] * 3)
        p2 = (x + along[0] * 4 - ortho[0] * 3, y + along[1] * 4 - ortho[1] * 3)
        draw.line([p1, p2], fill=GOLD_MID, width=2)

def draw_head_and_helmet(draw, pos, facing_angle=0.0, plume_lag=0.0):
    x, y = pos
    head_r = 11.5

    # Helmet ball
    draw_circle(draw, x, y, head_r, SHD)
    draw_circle(draw, x + 1, y - 1, head_r - 1.5, MID)
    draw_circle(draw, x + 2, y - 2, head_r - 3.5, HI)

    # Horns / Crest
    crest_pts = [
        (x - 6, y - 8),
        (x - 14 + plume_lag * 2, y - 18 + plume_lag),
        (x - 4, y - 12),
        (x + 4, y - 12),
        (x + 8, y - 8)
    ]
    draw.polygon(crest_pts, fill=GOLD_SHD)
    draw.line([(x - 13 + plume_lag * 2, y - 17 + plume_lag), (x - 4, y - 11)], fill=GOLD_HI, width=2)

    # Glowing Visor
    vx = x + 3
    vy = y
    draw.rectangle([vx - 1, vy - 2, vx + 6, vy + 2], fill=OUTLINE)
    draw.line([(vx, vy), (vx + 5, vy)], fill=VISOR, width=2)
    draw.point((int(vx + 3), int(vy)), fill=VISOR_CORE)

def render_brawler_pose(pose):
    """
    pose: dict containing coordinates of joints:
      hips: (x, y)
      chest: (x, y)
      head: (x, y)
      far_foot: (x, y)
      far_knee: (x, y)
      near_foot: (x, y)
      near_knee: (x, y)
      far_shoulder: (x, y)
      far_elbow: (x, y)
      far_fist: (x, y)
      near_shoulder: (x, y)
      near_elbow: (x, y)
      near_fist: (x, y)
      near_fist_angle: float (degrees)
      plume_lag: float
    """
    img = Image.new('RGBA', SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    hips = pose['hips']
    chest = pose['chest']
    head = pose['head']

    # 1. FAR LEG
    far_knee = pose['far_knee']
    far_foot = pose['far_foot']
    draw_shaded_capsule(draw, (hips[0] - 4, hips[1]), far_knee, 4.5, FAR_SHD, FAR_MID)
    draw_shaded_capsule(draw, far_knee, far_foot, 4.5, FAR_SHD, FAR_MID)
    draw_boot(draw, far_foot, is_far=True)

    # 2. FAR ARM
    far_shoulder = pose['far_shoulder']
    far_elbow = pose['far_elbow']
    far_fist = pose['far_fist']
    draw_shaded_capsule(draw, far_shoulder, far_elbow, 3.5, FAR_SHD, FAR_MID)
    draw_shaded_capsule(draw, far_elbow, far_fist, 3.5, FAR_SHD, FAR_MID)
    draw_gauntlet(draw, far_fist, is_far=True, scale=0.9)

    # 3. TORSO & BELT
    draw.rounded_rectangle([hips[0] - 7, hips[1] - 4, hips[0] + 8, hips[1] + 4], radius=3, fill=SHD)
    draw.rectangle([hips[0] - 7, hips[1] - 2, hips[0] + 8, hips[1] + 2], fill=DARK)
    draw.rectangle([hips[0] - 2, hips[1] - 3, hips[0] + 3, hips[1] + 3], fill=GOLD_MID)
    draw.point((int(hips[0]), int(hips[1] - 1)), fill=GOLD_HI)

    # Chestplate
    draw_shaded_capsule(draw, (hips[0], hips[1] - 2), chest, 7.5, SHD, MID, HI)

    # 4. NEAR LEG
    near_knee = pose['near_knee']
    near_foot = pose['near_foot']
    draw_shaded_capsule(draw, (hips[0] + 3, hips[1]), near_knee, 5.0, SHD, MID)
    draw_shaded_capsule(draw, near_knee, near_foot, 5.0, SHD, MID)
    draw_boot(draw, near_foot, is_far=False)

    # 5. HEAD & HELMET
    draw_head_and_helmet(draw, head, plume_lag=pose.get('plume_lag', 0.0))

    # 6. NEAR SHOULDER PAULDRON
    near_shoulder = pose['near_shoulder']
    draw_circle(draw, near_shoulder[0], near_shoulder[1], 6.5, SHD)
    draw_circle(draw, near_shoulder[0] + 1, near_shoulder[1] - 1, 5.0, MID)
    draw_circle(draw, near_shoulder[0] + 2, near_shoulder[1] - 2, 3.5, HI)
    draw.rectangle([near_shoulder[0] - 2, near_shoulder[1] - 1, near_shoulder[0] + 4, near_shoulder[1] + 1], fill=GOLD_MID)

    # 7. NEAR ARM & GAUNTLET
    near_elbow = pose['near_elbow']
    near_fist = pose['near_fist']
    near_fist_angle = pose.get('near_fist_angle', -20.0)
    draw_shaded_capsule(draw, near_shoulder, near_elbow, 4.0, SHD, MID)
    draw_shaded_capsule(draw, near_elbow, near_fist, 4.0, SHD, MID)
    draw_gauntlet(draw, near_fist, angle_deg=near_fist_angle, is_far=False, scale=1.0)

    # 8. OUTLINE PASS
    alpha = img.split()[-1]
    outline_img = Image.new('RGBA', SIZE, (0, 0, 0, 0))
    out_draw = ImageDraw.Draw(outline_img)
    w, h = SIZE
    alpha_data = alpha.load()
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            if alpha_data[x, y] > 30:
                if alpha_data[x-1, y] <= 30 or alpha_data[x+1, y] <= 30 or alpha_data[x, y-1] <= 30 or alpha_data[x, y+1] <= 30:
                    out_draw.point((x, y), fill=OUTLINE)

    final = Image.alpha_composite(img, outline_img)
    return final, [round(near_fist[0], 1), round(near_fist[1], 1), round(near_fist_angle, 1)]
