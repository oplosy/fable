import os, math, json
from PIL import Image
from brawler_renderer import render_brawler_pose, SIZE, FEET

OUT_DIR = "assets/characters/stickman"

def save_clip(name, frames_list, hands_list, fps=24.0, loop=False, ref_speed=0.0):
    num_frames = len(frames_list)
    strip = Image.new('RGBA', (SIZE[0] * num_frames, SIZE[1]), (0, 0, 0, 0))
    for i, f in enumerate(frames_list):
        strip.paste(f, (SIZE[0] * i, 0))
    
    strip.save(os.path.join(OUT_DIR, f"{name}.png"))
    info = {
        "feet": [FEET[0], FEET[1]],
        "fps": fps,
        "frames": num_frames,
        "hand_front": hands_list,
        "loop": loop,
        "reference_speed": ref_speed,
        "size": [SIZE[0], SIZE[1]]
    }
    with open(os.path.join(OUT_DIR, f"{name}.json"), 'w') as f:
        json.dump(info, f)
    print(f"Saved {name}: {num_frames} frames, loop={loop}")


# --- 1. REACTION / FLINCH HITS ---
def make_flinches():
    # hit_front_light, hit_back_light (5 frames)
    for side in ["front", "back"]:
        sign = -1.0 if side == "front" else 1.0
        frames = []
        hands = []
        curve = [0.0, 8.0, 12.0, 6.0, 0.0]
        for dist in curve:
            hips = (96.0 + sign * dist * 0.4, 118.0 - 32.0)
            chest = (hips[0] + sign * dist * 0.6, hips[1] - 14.0)
            head = (chest[0] + sign * dist * 0.8, chest[1] - 18.0)

            near_foot = (96.0 + 10.0, 118.0 - 4.0)
            far_foot = (96.0 - 12.0, 118.0 - 4.0)
            near_knee = (near_foot[0], (hips[1] + near_foot[1]) / 2.0)
            far_knee = (far_foot[0], (hips[1] + far_foot[1]) / 2.0)

            near_shoulder = (chest[0] + 6.0, chest[1] - 3.0)
            near_elbow = (near_shoulder[0] + sign * 6.0, near_shoulder[1] + 8.0)
            near_fist = (near_elbow[0] + sign * 8.0, near_elbow[1] - 4.0)

            far_shoulder = (chest[0] - 5.0, chest[1] - 5.0)
            far_elbow = (far_shoulder[0] + sign * 6.0, far_shoulder[1] + 5.0)
            far_fist = (far_elbow[0] + sign * 8.0, far_elbow[1] - 4.0)

            pose = {
                'hips': hips, 'chest': chest, 'head': head,
                'near_foot': near_foot, 'near_knee': near_knee,
                'far_foot': far_foot, 'far_knee': far_knee,
                'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
                'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
                'near_fist_angle': -20.0,
                'plume_lag': sign * dist * 0.3
            }
            frame_img, hand = render_brawler_pose(pose)
            frames.append(frame_img)
            hands.append(hand)

        save_clip(f"hit_{side}_light", frames, hands, fps=24.0, loop=False)

    # hit_front_heavy, hit_back_heavy (9 frames)
    for side in ["front", "back"]:
        sign = -1.0 if side == "front" else 1.0
        frames = []
        hands = []
        curve = [0.0, 10.0, 22.0, 25.0, 20.0, 14.0, 8.0, 3.0, 0.0]
        for dist in curve:
            hips = (96.0 + sign * dist * 0.5, 118.0 - 30.0 + dist * 0.2)
            chest = (hips[0] + sign * dist * 0.8, hips[1] - 14.0)
            head = (chest[0] + sign * dist * 1.0, chest[1] - 18.0)

            near_foot = (96.0 + 10.0, 118.0 - 4.0)
            far_foot = (96.0 - 12.0, 118.0 - 4.0)
            near_knee = (near_foot[0], (hips[1] + near_foot[1]) / 2.0)
            far_knee = (far_foot[0], (hips[1] + far_foot[1]) / 2.0)

            near_shoulder = (chest[0] + 6.0, chest[1] - 3.0)
            near_elbow = (near_shoulder[0] + sign * 8.0, near_shoulder[1] + 8.0)
            near_fist = (near_elbow[0] + sign * 10.0, near_elbow[1] - 4.0)

            far_shoulder = (chest[0] - 5.0, chest[1] - 5.0)
            far_elbow = (far_shoulder[0] + sign * 8.0, far_shoulder[1] + 5.0)
            far_fist = (far_elbow[0] + sign * 10.0, far_elbow[1] - 4.0)

            pose = {
                'hips': hips, 'chest': chest, 'head': head,
                'near_foot': near_foot, 'near_knee': near_knee,
                'far_foot': far_foot, 'far_knee': far_knee,
                'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
                'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
                'near_fist_angle': -20.0,
                'plume_lag': sign * dist * 0.4
            }
            frame_img, hand = render_brawler_pose(pose)
            frames.append(frame_img)
            hands.append(hand)

        save_clip(f"hit_{side}_heavy", frames, hands, fps=24.0, loop=False)

    # hit_air (7 frames)
    frames = []
    hands = []
    for i in range(7):
        flung = math.sin(i / 6.0 * math.pi) * 16.0
        hips = (96.0 - flung, 118.0 - 36.0)
        chest = (hips[0] - 6.0, hips[1] - 12.0)
        head = (chest[0] - 6.0, chest[1] - 16.0)

        near_foot = (hips[0] + 16.0, hips[1] + 8.0)
        far_foot = (hips[0] + 12.0, hips[1] + 14.0)
        near_knee = (hips[0] + 8.0, hips[1] + 4.0)
        far_knee = (hips[0] + 6.0, hips[1] + 6.0)

        near_shoulder = (chest[0] + 6.0, chest[1] - 3.0)
        near_elbow = (near_shoulder[0] - 8.0, near_shoulder[1] + 6.0)
        near_fist = (near_elbow[0] - 10.0, near_elbow[1] - 4.0)

        far_shoulder = (chest[0] - 5.0, chest[1] - 5.0)
        far_elbow = (far_shoulder[0] - 8.0, far_shoulder[1] + 4.0)
        far_fist = (far_elbow[0] - 10.0, far_elbow[1] - 4.0)

        pose = {
            'hips': hips, 'chest': chest, 'head': head,
            'near_foot': near_foot, 'near_knee': near_knee,
            'far_foot': far_foot, 'far_knee': far_knee,
            'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
            'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
            'near_fist_angle': -45.0,
            'plume_lag': -flung * 0.3
        }
        frame_img, hand = render_brawler_pose(pose)
        frames.append(frame_img)
        hands.append(hand)

    save_clip("hit_air", frames, hands, fps=24.0, loop=False)


# --- 2. KNOCKDOWNS, LYING, GETUP, DEATH ---
def make_knockdowns_lying():
    for side in ["back", "front"]:
        sign = -1.0 if side == "back" else 1.0

        # knockdown_back, knockdown_front (9 frames)
        frames = []
        hands = []
        for i in range(9):
            prog = i / 8.0
            # From airborne hit to floor slam
            hips_y = 118.0 - 32.0 + prog * 24.0
            hips_x = 96.0 + sign * prog * 24.0
            hips = (hips_x, hips_y)

            chest = (hips_x + sign * 14.0 * (1.0 - prog), hips_y - 8.0 * (1.0 - prog))
            head = (chest[0] + sign * 14.0 * (1.0 - prog), chest[1] - 6.0 * (1.0 - prog))

            near_foot = (hips_x - sign * 20.0 * prog, 118.0 - 4.0)
            far_foot = (hips_x - sign * 24.0 * prog, 118.0 - 4.0)
            near_knee = ((hips[0] + near_foot[0]) / 2.0, hips[1])
            far_knee = ((hips[0] + far_foot[0]) / 2.0, hips[1])

            near_shoulder = chest
            near_elbow = (chest[0] + 4.0, chest[1] + 4.0)
            near_fist = (chest[0] + 10.0, chest[1] + 6.0)

            far_shoulder = chest
            far_elbow = (chest[0] - 4.0, chest[1] + 4.0)
            far_fist = (chest[0] - 10.0, chest[1] + 6.0)

            pose = {
                'hips': hips, 'chest': chest, 'head': head,
                'near_foot': near_foot, 'near_knee': near_knee,
                'far_foot': far_foot, 'far_knee': far_knee,
                'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
                'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
                'near_fist_angle': 0.0,
                'plume_lag': -sign * 4.0
            }
            frame_img, hand = render_brawler_pose(pose)
            frames.append(frame_img)
            hands.append(hand)

        save_clip(f"knockdown_{side}", frames, hands, fps=24.0, loop=False)

        # lying_back, lying_front (12 frames loop)
        frames = []
        hands = []
        for i in range(12):
            t = 2.0 * math.pi * i / 12.0
            b = math.sin(t) * 1.0

            hips = (96.0, 118.0 - 8.0)
            chest = (96.0 + sign * 14.0, 118.0 - 8.0 - b)
            head = (96.0 + sign * 28.0, 118.0 - 8.0 - b)

            near_foot = (96.0 - sign * 20.0, 118.0 - 4.0)
            far_foot = (96.0 - sign * 24.0, 118.0 - 4.0)
            near_knee = (96.0 - sign * 10.0, 118.0 - 6.0)
            far_knee = (96.0 - sign * 12.0, 118.0 - 6.0)

            near_shoulder = chest
            near_elbow = (chest[0] - sign * 4.0, 118.0 - 6.0)
            near_fist = (chest[0] - sign * 10.0, 118.0 - 6.0)

            far_shoulder = chest
            far_elbow = (chest[0] + sign * 4.0, 118.0 - 6.0)
            far_fist = (chest[0] + sign * 10.0, 118.0 - 6.0)

            pose = {
                'hips': hips, 'chest': chest, 'head': head,
                'near_foot': near_foot, 'near_knee': near_knee,
                'far_foot': far_foot, 'far_knee': far_knee,
                'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
                'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
                'near_fist_angle': 0.0,
                'plume_lag': 0.0
            }
            frame_img, hand = render_brawler_pose(pose)
            frames.append(frame_img)
            hands.append(hand)

        save_clip(f"lying_{side}", frames, hands, fps=24.0, loop=True)

        # getup_back, getup_front (10 frames)
        frames = []
        hands = []
        for i in range(10):
            prog = i / 9.0
            # Spring up from ground to standing
            hips_y = 118.0 - 8.0 - prog * 24.0
            hips = (96.0, hips_y)
            chest = (96.0 + 1.0, hips_y - 14.0 * prog)
            head = (chest[0] + 2.0, chest[1] - 18.0 * prog)

            near_foot = (96.0 + 10.0, 118.0 - 4.0)
            far_foot = (96.0 - 12.0, 118.0 - 4.0)
            near_knee = (near_foot[0] - 2.0, (hips[1] + near_foot[1]) / 2.0)
            far_knee = (far_foot[0] + 3.0, (hips[1] + far_foot[1]) / 2.0)

            near_shoulder = (chest[0] + 6.0, chest[1] - 3.0)
            near_elbow = (near_shoulder[0] + 3.0, near_shoulder[1] + 9.0)
            near_fist = (near_elbow[0] + 7.0, near_elbow[1] - 4.0)

            far_shoulder = (chest[0] - 5.0, chest[1] - 5.0)
            far_elbow = (far_shoulder[0] - 8.0, far_shoulder[1] + 4.0)
            far_fist = (far_elbow[0] + 6.0, far_elbow[1] - 8.0)

            pose = {
                'hips': hips, 'chest': chest, 'head': head,
                'near_foot': near_foot, 'near_knee': near_knee,
                'far_foot': far_foot, 'far_knee': far_knee,
                'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
                'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
                'near_fist_angle': -20.0,
                'plume_lag': (1.0 - prog) * 2.0
            }
            frame_img, hand = render_brawler_pose(pose)
            frames.append(frame_img)
            hands.append(hand)

        save_clip(f"getup_{side}", frames, hands, fps=24.0, loop=False)

        # death_back, death_front (13 frames)
        frames = []
        hands = []
        for i in range(13):
            prog = min(1.0, i / 10.0)
            hips = (96.0 + sign * prog * 16.0, 118.0 - 32.0 + prog * 24.0)
            chest = (hips[0] + sign * 14.0 * (1.0 - prog), hips[1] - 8.0 * (1.0 - prog))
            head = (chest[0] + sign * 14.0 * (1.0 - prog), chest[1] - 6.0 * (1.0 - prog))

            near_foot = (hips[0] - sign * 20.0 * prog, 118.0 - 4.0)
            far_foot = (hips[0] - sign * 24.0 * prog, 118.0 - 4.0)
            near_knee = ((hips[0] + near_foot[0]) / 2.0, hips[1])
            far_knee = ((hips[0] + far_foot[0]) / 2.0, hips[1])

            near_shoulder = chest
            near_elbow = (chest[0] + 4.0, chest[1] + 4.0)
            near_fist = (chest[0] + 10.0, chest[1] + 6.0)

            far_shoulder = chest
            far_elbow = (chest[0] - 4.0, chest[1] + 4.0)
            far_fist = (chest[0] - 10.0, chest[1] + 6.0)

            pose = {
                'hips': hips, 'chest': chest, 'head': head,
                'near_foot': near_foot, 'near_knee': near_knee,
                'far_foot': far_foot, 'far_knee': far_knee,
                'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
                'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
                'near_fist_angle': 0.0,
                'plume_lag': 0.0
            }
            frame_img, hand = render_brawler_pose(pose)
            frames.append(frame_img)
            hands.append(hand)

        save_clip(f"death_{side}", frames, hands, fps=24.0, loop=False)


# --- 3. AIM POSES (stand_aim_0..8 & crouch_aim_0..8) ---
def make_aim_poses():
    for mode in ["stand", "crouch"]:
        is_crouch = (mode == "crouch")
        for step in range(9):
            # angle from -90 deg (straight UP) to +90 deg (straight DOWN)
            angle_deg = -90.0 + step * (180.0 / 8.0)
            angle_rad = math.radians(angle_deg)
            along = (math.cos(angle_rad), math.sin(angle_rad))

            hips = (96.0, 118.0 - (18.0 if is_crouch else 32.0))
            chest = (hips[0] + (6.0 if is_crouch else 1.0), hips[1] - (10.0 if is_crouch else 14.0))
            head = (chest[0] + (6.0 if is_crouch else 2.0), chest[1] - (12.0 if is_crouch else 18.0))

            near_foot = (96.0 + 10.0, 118.0 - 4.0)
            far_foot = (96.0 - 12.0, 118.0 - 4.0)
            near_knee = (near_foot[0] - 2.0, (hips[1] + near_foot[1]) / 2.0)
            far_knee = (far_foot[0] + 3.0, (hips[1] + far_foot[1]) / 2.0)

            near_shoulder = (chest[0] + 6.0, chest[1] - 3.0)
            far_shoulder = (chest[0] - 5.0, chest[1] - 5.0)

            # Arm extends along aim direction
            reach = 14.0
            near_fist = (near_shoulder[0] + along[0] * reach, near_shoulder[1] + along[1] * reach)
            near_elbow = (near_shoulder[0] + along[0] * reach * 0.5, near_shoulder[1] + along[1] * reach * 0.5 + 4.0)

            far_fist = (near_fist[0] - 3.0, near_fist[1] + 1.0)
            far_elbow = (far_shoulder[0] + along[0] * reach * 0.4, far_shoulder[1] + along[1] * reach * 0.4 + 4.0)

            pose = {
                'hips': hips, 'chest': chest, 'head': head,
                'near_foot': near_foot, 'near_knee': near_knee,
                'far_foot': far_foot, 'far_knee': far_knee,
                'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
                'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
                'near_fist_angle': angle_deg,
                'plume_lag': 0.0
            }
            frame_img, hand = render_brawler_pose(pose)
            save_clip(f"{mode}_aim_{step}", [frame_img], [hand], fps=24.0, loop=True)


if __name__ == '__main__':
    print("Generating Reaction & Aim Suite...")
    make_flinches()
    make_knockdowns_lying()
    make_aim_poses()
    print("All Reaction & Aim Clips Generated Successfully!")
