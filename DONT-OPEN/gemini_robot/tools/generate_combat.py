import os, math, json
from PIL import Image, ImageDraw
from brawler_renderer import render_brawler_pose, SIZE, FEET

OUT_DIR = "assets/characters/stickman"

def save_combat_clip(name, frames_list, hands_list, fx_frames_list=None, fps=24.0, loop=False):
    num_frames = len(frames_list)
    strip = Image.new('RGBA', (SIZE[0] * num_frames, SIZE[1]), (0, 0, 0, 0))
    for i, f in enumerate(frames_list):
        strip.paste(f, (SIZE[0] * i, 0))
    
    strip_path = os.path.join(OUT_DIR, f"{name}.png")
    json_path = os.path.join(OUT_DIR, f"{name}.json")
    strip.save(strip_path)

    if fx_frames_list:
        fx_strip = Image.new('RGBA', (SIZE[0] * num_frames, SIZE[1]), (0, 0, 0, 0))
        for i, fx in enumerate(fx_frames_list):
            fx_strip.paste(fx, (SIZE[0] * i, 0))
        fx_strip.save(os.path.join(OUT_DIR, f"{name}_fx.png"))

    info = {
        "feet": [FEET[0], FEET[1]],
        "fps": fps,
        "frames": num_frames,
        "hand_front": hands_list,
        "loop": loop,
        "reference_speed": 0.0,
        "size": [SIZE[0], SIZE[1]]
    }
    with open(json_path, 'w') as f:
        json.dump(info, f)
    print(f"Saved {name}: {num_frames} frames, with_fx={fx_frames_list is not None}")


def make_wind_effect(from_pt, to_pt, radius=4.0):
    fx = Image.new('RGBA', SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(fx)
    dx = to_pt[0] - from_pt[0]
    dy = to_pt[1] - from_pt[1]
    dist = math.hypot(dx, dy)
    if dist < 4.0:
        return fx

    steps = max(1, int(dist * 2))
    for s in range(steps + 1):
        t = s / steps
        cx = from_pt[0] + dx * t
        cy = from_pt[1] + dy * t
        # Trail gets thicker and brighter towards the tip
        r = radius * (0.3 + 0.7 * t)
        alpha = int(255 * (0.2 + 0.8 * t))
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, alpha))

    # Speed lines
    norm = (-dy / dist, dx / dist)
    for sign in [-1, 1]:
        sp1 = (from_pt[0] + norm[0] * 7.0 * sign, from_pt[1] + norm[1] * 7.0 * sign)
        sp2 = (to_pt[0] + norm[0] * 7.0 * sign + dx * 0.2, to_pt[1] + norm[1] * 7.0 * sign + dy * 0.2)
        draw.line([sp1, sp2], fill=(255, 255, 255, 220), width=2)
    return fx


# --- FAST JABS (6 frames each: jab_1 near, jab_2 far, jab_3 near upper) ---
def make_fast_jabs():
    for jab_num in [1, 2, 3]:
        frames = []
        fx_frames = []
        hands = []
        is_far_jab = (jab_num == 2)
        is_upper = (jab_num == 3)

        # 6 frames curve: 0 windup, 1 extend, 2-3 strike hold, 4-5 recovery
        reach_curve = [-4.0, 18.0, 28.0, 26.0, 10.0, 0.0]
        y_offset = -6.0 if is_upper else 0.0

        prev_fist = (96.0 + 10.0, 118.0 - 45.0)

        for i, reach in enumerate(reach_curve):
            hips = (96.0 + reach * 0.15, 118.0 - 32.0)
            chest = (hips[0] + 2.0 + reach * 0.2, hips[1] - 14.0)
            head = (chest[0] + 3.0, chest[1] - 18.0)

            near_foot = (96.0 + 10.0, 118.0 - 4.0)
            far_foot = (96.0 - 12.0, 118.0 - 4.0)
            near_knee = (near_foot[0] - 2.0, (hips[1] + near_foot[1]) / 2.0)
            far_knee = (far_foot[0] + 3.0, (hips[1] + far_foot[1]) / 2.0)

            near_shoulder = (chest[0] + 6.0, chest[1] - 3.0)
            far_shoulder = (chest[0] - 5.0, chest[1] - 5.0)

            if not is_far_jab:
                # Near fist punch
                near_fist = (near_shoulder[0] + 12.0 + reach, near_shoulder[1] + 3.0 + y_offset)
                near_elbow = ((near_shoulder[0] + near_fist[0]) / 2.0, near_shoulder[1] + 5.0)
                far_fist = (far_shoulder[0] - 2.0, far_shoulder[1] + 4.0)
                far_elbow = (far_shoulder[0] - 6.0, far_shoulder[1] + 5.0)
                active_fist = near_fist
            else:
                # Far cross punch
                far_fist = (far_shoulder[0] + 14.0 + reach, far_shoulder[1] + 2.0)
                far_elbow = ((far_shoulder[0] + far_fist[0]) / 2.0, far_shoulder[1] + 4.0)
                near_fist = (near_shoulder[0] + 2.0, near_shoulder[1] + 5.0)
                near_elbow = (near_shoulder[0] + 1.0, near_shoulder[1] + 8.0)
                active_fist = far_fist

            pose = {
                'hips': hips, 'chest': chest, 'head': head,
                'near_foot': near_foot, 'near_knee': near_knee,
                'far_foot': far_foot, 'far_knee': far_knee,
                'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
                'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
                'near_fist_angle': -10.0 if not is_upper else -45.0,
                'plume_lag': reach * 0.2
            }
            frame_img, hand = render_brawler_pose(pose)
            frames.append(frame_img)
            hands.append(hand)

            # FX wind during extension
            if i in [1, 2, 3]:
                fx_frames.append(make_wind_effect(prev_fist, active_fist, radius=5.0))
            else:
                fx_frames.append(Image.new('RGBA', SIZE, (0, 0, 0, 0)))
            prev_fist = active_fist

        save_combat_clip(f"fast_jab_{jab_num}", frames, hands, fx_frames_list=fx_frames, fps=24.0, loop=False)


# --- FAST HOOK (9 frames) ---
def make_fast_hook():
    frames = []
    fx_frames = []
    hands = []
    # 9 frames: 0-1 windup back, 2-3 forward swing, 4-5 apex hold, 6-8 recovery
    reach_curve = [-8.0, -12.0, 10.0, 32.0, 35.0, 30.0, 16.0, 6.0, 0.0]
    prev_fist = (96.0 + 10.0, 118.0 - 45.0)

    for i, reach in enumerate(reach_curve):
        hips = (96.0 + reach * 0.2, 118.0 - 32.0)
        chest = (hips[0] + 3.0 + reach * 0.25, hips[1] - 14.0)
        head = (chest[0] + 3.0, chest[1] - 18.0)

        near_foot = (96.0 + 12.0, 118.0 - 4.0)
        far_foot = (96.0 - 12.0, 118.0 - 4.0)
        near_knee = (near_foot[0] - 2.0, (hips[1] + near_foot[1]) / 2.0)
        far_knee = (far_foot[0] + 3.0, (hips[1] + far_foot[1]) / 2.0)

        near_shoulder = (chest[0] + 6.0, chest[1] - 3.0)
        far_shoulder = (chest[0] - 5.0, chest[1] - 5.0)

        # Hook curves in from wide elbow
        near_fist = (near_shoulder[0] + 10.0 + reach, near_shoulder[1] + 4.0)
        near_elbow = (near_shoulder[0] + 6.0 + reach * 0.5, near_shoulder[1] + 12.0)

        far_fist = (far_shoulder[0] - 4.0, far_shoulder[1] + 4.0)
        far_elbow = (far_shoulder[0] - 8.0, far_shoulder[1] + 5.0)

        pose = {
            'hips': hips, 'chest': chest, 'head': head,
            'near_foot': near_foot, 'near_knee': near_knee,
            'far_foot': far_foot, 'far_knee': far_knee,
            'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
            'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
            'near_fist_angle': -30.0,
            'plume_lag': reach * 0.25
        }
        frame_img, hand = render_brawler_pose(pose)
        frames.append(frame_img)
        hands.append(hand)

        if i in [2, 3, 4, 5]:
            fx_frames.append(make_wind_effect(prev_fist, near_fist, radius=7.0))
        else:
            fx_frames.append(Image.new('RGBA', SIZE, (0, 0, 0, 0)))
        prev_fist = near_fist

    save_combat_clip("fast_hook", frames, hands, fx_frames_list=fx_frames, fps=24.0, loop=False)


# --- JUMP KICKS (fast_jump_kick 9 frames, heavy_jump_kick 11 frames) ---
def make_jump_kicks(name="fast_jump_kick", num_frames=9):
    frames = []
    fx_frames = []
    hands = []
    prev_foot = (96.0 + 10.0, 118.0 - 20.0)

    for i in range(num_frames):
        prog = i / (num_frames - 1)
        # Dropkick extension
        kick_ext = math.sin(prog * math.pi) * 32.0

        hips = (96.0, 118.0 - 36.0)
        chest = (hips[0] - 4.0, hips[1] - 12.0)
        head = (chest[0] - 2.0, chest[1] - 16.0)

        # Front foot kicks straight forward-down
        near_foot = (hips[0] + 16.0 + kick_ext, hips[1] + 14.0)
        near_knee = (hips[0] + 8.0 + kick_ext * 0.5, hips[1] + 6.0)

        far_foot = (hips[0] - 8.0, hips[1] + 10.0)
        far_knee = (hips[0] - 4.0, hips[1] + 5.0)

        near_shoulder = (chest[0] + 6.0, chest[1] - 3.0)
        near_elbow = (near_shoulder[0] - 4.0, near_shoulder[1] + 6.0)
        near_fist = (near_elbow[0] - 6.0, near_elbow[1] - 2.0)

        far_shoulder = (chest[0] - 5.0, chest[1] - 5.0)
        far_elbow = (far_shoulder[0] - 6.0, far_shoulder[1] + 4.0)
        far_fist = (far_elbow[0] - 8.0, far_elbow[1] - 2.0)

        pose = {
            'hips': hips, 'chest': chest, 'head': head,
            'near_foot': near_foot, 'near_knee': near_knee,
            'far_foot': far_foot, 'far_knee': far_knee,
            'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
            'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
            'near_fist_angle': -60.0,
            'plume_lag': -kick_ext * 0.2
        }
        frame_img, hand = render_brawler_pose(pose)
        frames.append(frame_img)
        hands.append(hand)

        if prog > 0.2 and prog < 0.7:
            fx_frames.append(make_wind_effect(prev_foot, near_foot, radius=7.0))
        else:
            fx_frames.append(Image.new('RGBA', SIZE, (0, 0, 0, 0)))
        prev_foot = near_foot

    save_combat_clip(name, frames, hands, fx_frames_list=fx_frames, fps=24.0, loop=False)


# --- HEAVY PUNCHES & KICK (heavy_punch_1, 2, heavy_kick) ---
def make_heavy_combo():
    # heavy_punch_1 & 2 (9 frames)
    for p_num in [1, 2]:
        frames = []
        fx_frames = []
        hands = []
        is_far = (p_num == 2)
        reach_curve = [-10.0, -14.0, 12.0, 34.0, 38.0, 32.0, 16.0, 6.0, 0.0]
        prev_fist = (96.0 + 10.0, 118.0 - 45.0)

        for i, reach in enumerate(reach_curve):
            hips = (96.0 + reach * 0.2, 118.0 - 32.0)
            chest = (hips[0] + 4.0 + reach * 0.25, hips[1] - 14.0)
            head = (chest[0] + 4.0, chest[1] - 18.0)

            near_foot = (96.0 + 14.0, 118.0 - 4.0)
            far_foot = (96.0 - 14.0, 118.0 - 4.0)
            near_knee = (near_foot[0] - 2.0, (hips[1] + near_foot[1]) / 2.0)
            far_knee = (far_foot[0] + 3.0, (hips[1] + far_foot[1]) / 2.0)

            near_shoulder = (chest[0] + 6.0, chest[1] - 3.0)
            far_shoulder = (chest[0] - 5.0, chest[1] - 5.0)

            if not is_far:
                near_fist = (near_shoulder[0] + 14.0 + reach, near_shoulder[1] + 3.0)
                near_elbow = ((near_shoulder[0] + near_fist[0]) / 2.0, near_shoulder[1] + 6.0)
                far_fist = (far_shoulder[0] - 4.0, far_shoulder[1] + 4.0)
                far_elbow = (far_shoulder[0] - 8.0, far_shoulder[1] + 5.0)
                active_fist = near_fist
            else:
                far_fist = (far_shoulder[0] + 16.0 + reach, far_shoulder[1] + 3.0)
                far_elbow = ((far_shoulder[0] + far_fist[0]) / 2.0, far_shoulder[1] + 5.0)
                near_fist = (near_shoulder[0] + 2.0, near_shoulder[1] + 5.0)
                near_elbow = (near_shoulder[0] + 1.0, near_shoulder[1] + 8.0)
                active_fist = far_fist

            pose = {
                'hips': hips, 'chest': chest, 'head': head,
                'near_foot': near_foot, 'near_knee': near_knee,
                'far_foot': far_foot, 'far_knee': far_knee,
                'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
                'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
                'near_fist_angle': -15.0,
                'plume_lag': reach * 0.25
            }
            frame_img, hand = render_brawler_pose(pose)
            frames.append(frame_img)
            hands.append(hand)

            if i in [2, 3, 4, 5]:
                fx_frames.append(make_wind_effect(prev_fist, active_fist, radius=7.0))
            else:
                fx_frames.append(Image.new('RGBA', SIZE, (0, 0, 0, 0)))
            prev_fist = active_fist

        save_combat_clip(f"heavy_punch_{p_num}", frames, hands, fx_frames_list=fx_frames, fps=24.0, loop=False)

    # heavy_kick (14 frames)
    frames = []
    fx_frames = []
    hands = []
    prev_foot = (96.0 - 12.0, 118.0 - 4.0)
    for i in range(14):
        prog = i / 13.0
        kick_ext = math.sin(prog * math.pi) * 36.0

        hips = (96.0, 118.0 - 32.0)
        chest = (hips[0] - 6.0, hips[1] - 14.0)
        head = (chest[0] - 4.0, chest[1] - 18.0)

        far_foot = (96.0 + 8.0, 118.0 - 4.0)
        far_knee = (far_foot[0], (hips[1] + far_foot[1]) / 2.0)

        near_foot = (hips[0] + 14.0 + kick_ext, hips[1] + 4.0 - kick_ext * 0.3)
        near_knee = (hips[0] + 8.0 + kick_ext * 0.5, hips[1] + 2.0)

        near_shoulder = (chest[0] + 6.0, chest[1] - 3.0)
        near_elbow = (near_shoulder[0] - 4.0, near_shoulder[1] + 6.0)
        near_fist = (near_elbow[0] - 6.0, near_elbow[1] - 2.0)

        far_shoulder = (chest[0] - 5.0, chest[1] - 5.0)
        far_elbow = (far_shoulder[0] - 6.0, far_shoulder[1] + 4.0)
        far_fist = (far_elbow[0] - 8.0, far_elbow[1] - 2.0)

        pose = {
            'hips': hips, 'chest': chest, 'head': head,
            'near_foot': near_foot, 'near_knee': near_knee,
            'far_foot': far_foot, 'far_knee': far_knee,
            'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
            'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
            'near_fist_angle': -40.0,
            'plume_lag': -kick_ext * 0.2
        }
        frame_img, hand = render_brawler_pose(pose)
        frames.append(frame_img)
        hands.append(hand)

        if prog > 0.2 and prog < 0.7:
            fx_frames.append(make_wind_effect(prev_foot, near_foot, radius=8.0))
        else:
            fx_frames.append(Image.new('RGBA', SIZE, (0, 0, 0, 0)))
        prev_foot = near_foot

    save_combat_clip("heavy_kick", frames, hands, fx_frames_list=fx_frames, fps=24.0, loop=False)


# --- WEAPONS: KNIFE & BAT ---
def make_knife_bat():
    # knife_stab_1, 2 (5 frames)
    for k_num in [1, 2]:
        frames = []
        fx_frames = []
        hands = []
        curve = [-4.0, 16.0, 26.0, 14.0, 0.0]
        prev_fist = (96.0 + 10.0, 118.0 - 45.0)
        for i, reach in enumerate(curve):
            hips = (96.0 + reach * 0.15, 118.0 - 32.0)
            chest = (hips[0] + 2.0 + reach * 0.2, hips[1] - 14.0)
            head = (chest[0] + 2.0, chest[1] - 18.0)

            near_foot = (96.0 + 10.0, 118.0 - 4.0)
            far_foot = (96.0 - 12.0, 118.0 - 4.0)
            near_knee = (near_foot[0] - 2.0, (hips[1] + near_foot[1]) / 2.0)
            far_knee = (far_foot[0] + 3.0, (hips[1] + far_foot[1]) / 2.0)

            near_shoulder = (chest[0] + 6.0, chest[1] - 3.0)
            near_fist = (near_shoulder[0] + 14.0 + reach, near_shoulder[1] + 4.0)
            near_elbow = ((near_shoulder[0] + near_fist[0]) / 2.0, near_shoulder[1] + 5.0)

            far_shoulder = (chest[0] - 5.0, chest[1] - 5.0)
            far_fist = (far_shoulder[0] - 2.0, far_shoulder[1] + 4.0)
            far_elbow = (far_shoulder[0] - 6.0, far_shoulder[1] + 5.0)

            pose = {
                'hips': hips, 'chest': chest, 'head': head,
                'near_foot': near_foot, 'near_knee': near_knee,
                'far_foot': far_foot, 'far_knee': far_knee,
                'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
                'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
                'near_fist_angle': 0.0,
                'plume_lag': reach * 0.1
            }
            frame_img, hand = render_brawler_pose(pose)
            frames.append(frame_img)
            hands.append(hand)

            if i in [1, 2, 3]:
                fx_frames.append(make_wind_effect(prev_fist, near_fist, radius=4.5))
            else:
                fx_frames.append(Image.new('RGBA', SIZE, (0, 0, 0, 0)))
            prev_fist = near_fist

        save_combat_clip(f"knife_stab_{k_num}", frames, hands, fx_frames_list=fx_frames, fps=24.0, loop=False)

    # knife_slash (7 frames)
    frames = []
    fx_frames = []
    hands = []
    slash_curve = [-8.0, 10.0, 28.0, 32.0, 24.0, 10.0, 0.0]
    prev_fist = (96.0 + 10.0, 118.0 - 45.0)
    for i, reach in enumerate(slash_curve):
        hips = (96.0 + reach * 0.2, 118.0 - 32.0)
        chest = (hips[0] + 3.0, hips[1] - 14.0)
        head = (chest[0] + 3.0, chest[1] - 18.0)

        near_foot = (96.0 + 10.0, 118.0 - 4.0)
        far_foot = (96.0 - 12.0, 118.0 - 4.0)
        near_knee = (near_foot[0] - 2.0, (hips[1] + near_foot[1]) / 2.0)
        far_knee = (far_foot[0] + 3.0, (hips[1] + far_foot[1]) / 2.0)

        near_shoulder = (chest[0] + 6.0, chest[1] - 3.0)
        near_fist = (near_shoulder[0] + 12.0 + reach, near_shoulder[1] + 2.0)
        near_elbow = ((near_shoulder[0] + near_fist[0]) / 2.0, near_shoulder[1] + 8.0)

        far_shoulder = (chest[0] - 5.0, chest[1] - 5.0)
        far_fist = (far_shoulder[0] - 2.0, far_shoulder[1] + 4.0)
        far_elbow = (far_shoulder[0] - 6.0, far_shoulder[1] + 5.0)

        pose = {
            'hips': hips, 'chest': chest, 'head': head,
            'near_foot': near_foot, 'near_knee': near_knee,
            'far_foot': far_foot, 'far_knee': far_knee,
            'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
            'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
            'near_fist_angle': -25.0,
            'plume_lag': reach * 0.2
        }
        frame_img, hand = render_brawler_pose(pose)
        frames.append(frame_img)
        hands.append(hand)

        if i in [1, 2, 3, 4]:
            fx_frames.append(make_wind_effect(prev_fist, near_fist, radius=6.5))
        else:
            fx_frames.append(Image.new('RGBA', SIZE, (0, 0, 0, 0)))
        prev_fist = near_fist

    save_combat_clip("knife_slash", frames, hands, fx_frames_list=fx_frames, fps=24.0, loop=False)

    # bat_swing_1, 2 (11 frames) & bat_home_run (14 frames)
    for b_name, b_frames in [("bat_swing_1", 11), ("bat_swing_2", 11), ("bat_home_run", 14)]:
        frames = []
        fx_frames = []
        hands = []
        prev_fist = (96.0 + 10.0, 118.0 - 45.0)
        for i in range(b_frames):
            prog = i / (b_frames - 1)
            # Big windup then powerful forward sweep
            if prog < 0.3:
                reach = -12.0 * (prog / 0.3)
            elif prog < 0.6:
                reach = -12.0 + 48.0 * ((prog - 0.3) / 0.3)
            else:
                reach = 36.0 - 36.0 * ((prog - 0.6) / 0.4)

            hips = (96.0 + reach * 0.2, 118.0 - 32.0)
            chest = (hips[0] + 3.0 + reach * 0.2, hips[1] - 14.0)
            head = (chest[0] + 3.0, chest[1] - 18.0)

            near_foot = (96.0 + 12.0, 118.0 - 4.0)
            far_foot = (96.0 - 12.0, 118.0 - 4.0)
            near_knee = (near_foot[0] - 2.0, (hips[1] + near_foot[1]) / 2.0)
            far_knee = (far_foot[0] + 3.0, (hips[1] + far_foot[1]) / 2.0)

            near_shoulder = (chest[0] + 6.0, chest[1] - 3.0)
            near_fist = (near_shoulder[0] + 12.0 + reach, near_shoulder[1] + 4.0)
            near_elbow = ((near_shoulder[0] + near_fist[0]) / 2.0, near_shoulder[1] + 8.0)

            far_shoulder = (chest[0] - 5.0, chest[1] - 5.0)
            far_fist = (near_fist[0] - 4.0, near_fist[1] + 2.0)
            far_elbow = ((far_shoulder[0] + far_fist[0]) / 2.0, far_shoulder[1] + 6.0)

            pose = {
                'hips': hips, 'chest': chest, 'head': head,
                'near_foot': near_foot, 'near_knee': near_knee,
                'far_foot': far_foot, 'far_knee': far_knee,
                'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
                'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
                'near_fist_angle': -30.0,
                'plume_lag': reach * 0.25
            }
            frame_img, hand = render_brawler_pose(pose)
            frames.append(frame_img)
            hands.append(hand)

            if prog > 0.3 and prog < 0.7:
                fx_frames.append(make_wind_effect(prev_fist, near_fist, radius=9.0))
            else:
                fx_frames.append(Image.new('RGBA', SIZE, (0, 0, 0, 0)))
            prev_fist = near_fist

        save_combat_clip(b_name, frames, hands, fx_frames_list=fx_frames, fps=24.0, loop=False)


if __name__ == '__main__':
    print("Generating Combat Suite...")
    make_fast_jabs()
    make_fast_hook()
    make_jump_kicks("fast_jump_kick", 9)
    make_heavy_combo()
    make_jump_kicks("heavy_jump_kick", 11)
    make_knife_bat()
    print("All Combat Clips Generated Successfully!")
