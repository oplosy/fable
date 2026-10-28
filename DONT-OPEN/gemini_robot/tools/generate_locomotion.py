import os, math, json
from PIL import Image
from brawler_renderer import render_brawler_pose, SIZE, FEET

OUT_DIR = "assets/characters/stickman"

def save_clip(name, frames_list, hands_list, fps=24.0, loop=True, ref_speed=0.0):
    num_frames = len(frames_list)
    strip = Image.new('RGBA', (SIZE[0] * num_frames, SIZE[1]), (0, 0, 0, 0))
    for i, f in enumerate(frames_list):
        strip.paste(f, (SIZE[0] * i, 0))
    
    strip_path = os.path.join(OUT_DIR, f"{name}.png")
    json_path = os.path.join(OUT_DIR, f"{name}.json")
    strip.save(strip_path)

    info = {
        "feet": [FEET[0], FEET[1]],
        "fps": fps,
        "frames": num_frames,
        "hand_front": hands_list,
        "loop": loop,
        "reference_speed": ref_speed,
        "size": [SIZE[0], SIZE[1]]
    }
    with open(json_path, 'w') as f:
        json.dump(info, f)
    print(f"Saved {name}: {num_frames} frames, loop={loop}, ref={ref_speed}")


# --- 1. WALK (10 frames loop, ref_speed 88.0) ---
def make_walk():
    frames = []
    hands = []
    N = 10
    for i in range(N):
        t = 2.0 * math.pi * i / N
        stride = math.sin(t)
        lift_near = max(0.0, math.sin(t))
        lift_far = max(0.0, -math.sin(t))
        bounce = abs(math.sin(t * 2))

        # Hips & Chest
        hips = (96.0, 118.0 - 32.0 + bounce * 2.0)
        chest = (hips[0] + 1.0, hips[1] - 14.0)
        head = (chest[0] + 2.0, chest[1] - 18.0)

        # Stride X offsets
        near_x = 96.0 + stride * 12.0
        far_x = 96.0 - stride * 12.0

        near_y = 118.0 - 4.0 - lift_near * 5.0
        far_y = 118.0 - 4.0 - lift_far * 5.0

        near_knee = (near_x - stride * 2.0, (hips[1] + near_y) / 2.0)
        far_knee = (far_x + stride * 2.0, (hips[1] + far_y) / 2.0)

        # Arms pump opposite to legs
        near_arm_swing = -stride * 12.0
        far_arm_swing = stride * 12.0

        near_shoulder = (chest[0] + 6.0, chest[1] - 3.0)
        near_elbow = (near_shoulder[0] + 2.0 + near_arm_swing * 0.4, near_shoulder[1] + 9.0)
        near_fist = (near_elbow[0] + 6.0 + near_arm_swing, near_elbow[1] - 3.0)

        far_shoulder = (chest[0] - 5.0, chest[1] - 5.0)
        far_elbow = (far_shoulder[0] - 6.0 + far_arm_swing * 0.4, far_shoulder[1] + 5.0)
        far_fist = (far_elbow[0] + 5.0 + far_arm_swing, far_elbow[1] - 5.0)

        pose = {
            'hips': hips, 'chest': chest, 'head': head,
            'near_foot': (near_x, near_y), 'near_knee': near_knee,
            'far_foot': (far_x, far_y), 'far_knee': far_knee,
            'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
            'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
            'near_fist_angle': -20.0 + near_arm_swing * 1.5,
            'plume_lag': -stride * 1.5
        }
        frame_img, hand = render_brawler_pose(pose)
        frames.append(frame_img)
        hands.append(hand)

    save_clip("walk", frames, hands, fps=24.0, loop=True, ref_speed=88.0)


# --- 2. RUN (8 frames loop, ref_speed 123.0) ---
def make_run():
    frames = []
    hands = []
    N = 8
    for i in range(N):
        t = 2.0 * math.pi * i / N
        stride = math.sin(t)
        lift_near = max(0.0, math.sin(t))
        lift_far = max(0.0, -math.sin(t))
        bounce = abs(math.sin(t * 2))

        # Forward lean for sprint
        hips = (98.0, 118.0 - 30.0 + bounce * 3.0)
        chest = (hips[0] + 5.0, hips[1] - 13.0)
        head = (chest[0] + 5.0, chest[1] - 16.0)

        near_x = 96.0 + stride * 20.0
        far_x = 96.0 - stride * 20.0

        near_y = 118.0 - 4.0 - lift_near * 9.0
        far_y = 118.0 - 4.0 - lift_far * 9.0

        near_knee = (near_x - stride * 4.0, (hips[1] + near_y) / 2.0)
        far_knee = (far_x + stride * 4.0, (hips[1] + far_y) / 2.0)

        near_arm_swing = -stride * 22.0
        far_arm_swing = stride * 22.0

        near_shoulder = (chest[0] + 6.0, chest[1] - 3.0)
        near_elbow = (near_shoulder[0] + 3.0 + near_arm_swing * 0.4, near_shoulder[1] + 8.0)
        near_fist = (near_elbow[0] + 7.0 + near_arm_swing, near_elbow[1] - 3.0)

        far_shoulder = (chest[0] - 5.0, chest[1] - 5.0)
        far_elbow = (far_shoulder[0] - 6.0 + far_arm_swing * 0.4, far_shoulder[1] + 5.0)
        far_fist = (far_elbow[0] + 5.0 + far_arm_swing, far_elbow[1] - 5.0)

        pose = {
            'hips': hips, 'chest': chest, 'head': head,
            'near_foot': (near_x, near_y), 'near_knee': near_knee,
            'far_foot': (far_x, far_y), 'far_knee': far_knee,
            'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
            'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
            'near_fist_angle': -15.0 + near_arm_swing * 1.5,
            'plume_lag': -4.0 + near_arm_swing * 0.2
        }
        frame_img, hand = render_brawler_pose(pose)
        frames.append(frame_img)
        hands.append(hand)

    save_clip("run", frames, hands, fps=24.0, loop=True, ref_speed=123.0)


# --- 3. JUMP_RISE (4 frames one-shot) ---
def make_jump_rise():
    frames = []
    hands = []
    N = 4
    for i in range(N):
        prog = i / (N - 1)
        # Tuck up in air
        hips = (96.0, 118.0 - 36.0 - prog * 4.0)
        chest = (hips[0] + 2.0, hips[1] - 14.0)
        head = (chest[0] + 3.0, chest[1] - 18.0)

        near_foot = (96.0 + 8.0, 118.0 - 12.0 - prog * 10.0)
        far_foot = (96.0 - 6.0, 118.0 - 10.0 - prog * 8.0)

        near_knee = (near_foot[0] - 4.0, (hips[1] + near_foot[1]) / 2.0)
        far_knee = (far_foot[0] - 4.0, (hips[1] + far_foot[1]) / 2.0)

        near_shoulder = (chest[0] + 6.0, chest[1] - 3.0)
        near_elbow = (near_shoulder[0] + 5.0, near_shoulder[1] + 6.0)
        near_fist = (near_elbow[0] + 8.0, near_elbow[1] - 10.0 - prog * 4.0)

        far_shoulder = (chest[0] - 5.0, chest[1] - 5.0)
        far_elbow = (far_shoulder[0] - 6.0, far_shoulder[1] + 4.0)
        far_fist = (far_elbow[0] + 5.0, far_elbow[1] - 12.0)

        pose = {
            'hips': hips, 'chest': chest, 'head': head,
            'near_foot': near_foot, 'near_knee': near_knee,
            'far_foot': far_foot, 'far_knee': far_knee,
            'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
            'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
            'near_fist_angle': -40.0,
            'plume_lag': 3.0
        }
        frame_img, hand = render_brawler_pose(pose)
        frames.append(frame_img)
        hands.append(hand)

    save_clip("jump_rise", frames, hands, fps=24.0, loop=False, ref_speed=0.0)


# --- 4. FALL (4 frames loop) ---
def make_fall():
    frames = []
    hands = []
    N = 4
    for i in range(N):
        t = 2.0 * math.pi * i / N
        flut = math.sin(t) * 1.5

        hips = (96.0, 118.0 - 38.0 + flut)
        chest = (hips[0] + 1.0, hips[1] - 14.0)
        head = (chest[0] + 2.0, chest[1] - 18.0)

        near_foot = (96.0 + 6.0, 118.0 - 14.0 + flut)
        far_foot = (96.0 - 8.0, 118.0 - 12.0 - flut)

        near_knee = (near_foot[0] - 2.0, (hips[1] + near_foot[1]) / 2.0)
        far_knee = (far_foot[0] - 2.0, (hips[1] + far_foot[1]) / 2.0)

        near_shoulder = (chest[0] + 6.0, chest[1] - 3.0)
        near_elbow = (near_shoulder[0] + 6.0, near_shoulder[1] + 5.0)
        near_fist = (near_elbow[0] + 7.0, near_elbow[1] - 5.0)

        far_shoulder = (chest[0] - 5.0, chest[1] - 5.0)
        far_elbow = (far_shoulder[0] - 7.0, far_shoulder[1] + 3.0)
        far_fist = (far_elbow[0] + 4.0, far_elbow[1] - 8.0)

        pose = {
            'hips': hips, 'chest': chest, 'head': head,
            'near_foot': near_foot, 'near_knee': near_knee,
            'far_foot': far_foot, 'far_knee': far_knee,
            'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
            'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
            'near_fist_angle': -25.0,
            'plume_lag': -3.0
        }
        frame_img, hand = render_brawler_pose(pose)
        frames.append(frame_img)
        hands.append(hand)

    save_clip("fall", frames, hands, fps=24.0, loop=True, ref_speed=0.0)


# --- 5. LAND (3 frames one-shot) ---
def make_land():
    frames = []
    hands = []
    squash_levels = [6.0, 2.5, 0.0]
    for s in squash_levels:
        hips = (96.0, 118.0 - 32.0 + s)
        chest = (hips[0] + 1.0, hips[1] - 14.0)
        head = (chest[0] + 2.0, chest[1] - 17.0)

        near_foot = (96.0 + 10.0, 118.0 - 4.0)
        far_foot = (96.0 - 12.0, 118.0 - 4.0)

        near_knee = (near_foot[0] - 2.0, (hips[1] + near_foot[1]) / 2.0 + s * 0.5)
        far_knee = (far_foot[0] + 3.0, (hips[1] + far_foot[1]) / 2.0 + s * 0.5)

        near_shoulder = (chest[0] + 6.0, chest[1] - 3.0)
        near_elbow = (near_shoulder[0] + 3.0, near_shoulder[1] + 9.0)
        near_fist = (near_elbow[0] + 7.0, near_elbow[1] - 4.0 + s * 0.5)

        far_shoulder = (chest[0] - 5.0, chest[1] - 5.0)
        far_elbow = (far_shoulder[0] - 8.0, far_shoulder[1] + 4.0)
        far_fist = (far_elbow[0] + 6.0, far_elbow[1] - 8.0 + s * 0.5)

        pose = {
            'hips': hips, 'chest': chest, 'head': head,
            'near_foot': near_foot, 'near_knee': near_knee,
            'far_foot': far_foot, 'far_knee': far_knee,
            'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
            'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
            'near_fist_angle': -20.0,
            'plume_lag': s * 0.4
        }
        frame_img, hand = render_brawler_pose(pose)
        frames.append(frame_img)
        hands.append(hand)

    save_clip("land", frames, hands, fps=24.0, loop=False, ref_speed=0.0)


# --- 6. CROUCH_IDLE & CROUCH_WALK ---
def make_crouch(is_walk=False):
    frames = []
    hands = []
    N = 8 if is_walk else 8
    for i in range(N):
        t = 2.0 * math.pi * i / N
        stride = math.sin(t) if is_walk else 0.0
        bounce = math.sin(t * 2) if is_walk else math.sin(t) * 0.8

        hips = (96.0 + stride * 4.0, 118.0 - 18.0 + bounce * 1.5)
        chest = (hips[0] + 6.0, hips[1] - 10.0)
        head = (chest[0] + 6.0, chest[1] - 12.0)

        near_x = 96.0 + 12.0 + stride * 8.0
        far_x = 96.0 - 10.0 - stride * 8.0
        near_foot = (near_x, 118.0 - 4.0)
        far_foot = (far_x, 118.0 - 4.0)

        near_knee = (near_foot[0] - 6.0, hips[1] + 2.0)
        far_knee = (far_foot[0] - 4.0, hips[1] + 2.0)

        near_shoulder = (chest[0] + 5.0, chest[1] - 2.0)
        near_elbow = (near_shoulder[0] + 4.0, near_shoulder[1] + 6.0)
        near_fist = (near_elbow[0] + 7.0 - stride * 6.0, near_elbow[1] - 2.0)

        far_shoulder = (chest[0] - 4.0, chest[1] - 3.0)
        far_elbow = (far_shoulder[0] - 5.0, far_shoulder[1] + 4.0)
        far_fist = (far_elbow[0] + 4.0 + stride * 6.0, far_elbow[1] - 4.0)

        pose = {
            'hips': hips, 'chest': chest, 'head': head,
            'near_foot': near_foot, 'near_knee': near_knee,
            'far_foot': far_foot, 'far_knee': far_knee,
            'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
            'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
            'near_fist_angle': -10.0,
            'plume_lag': -1.0
        }
        frame_img, hand = render_brawler_pose(pose)
        frames.append(frame_img)
        hands.append(hand)

    clip_name = "crouch_walk" if is_walk else "crouch_idle"
    save_clip(clip_name, frames, hands, fps=24.0, loop=True, ref_speed=50.0 if is_walk else 0.0)


# --- 7. DIVE (Head-first forward leap) ---
def make_dive():
    frames = []
    hands = []
    N = 6
    for i in range(N):
        prog = i / (N - 1)
        # Horizontal dive pose
        hips = (96.0 + prog * 10.0, 118.0 - 24.0)
        chest = (hips[0] + 16.0, hips[1] - 4.0)
        head = (chest[0] + 16.0, chest[1] - 2.0)

        near_foot = (hips[0] - 22.0, hips[1] + 2.0)
        far_foot = (hips[0] - 26.0, hips[1] - 2.0)

        near_knee = (hips[0] - 11.0, hips[1] + 1.0)
        far_knee = (hips[0] - 13.0, hips[1] - 1.0)

        near_shoulder = (chest[0] + 4.0, chest[1] - 1.0)
        near_elbow = (near_shoulder[0] + 8.0, near_shoulder[1] + 1.0)
        near_fist = (near_elbow[0] + 10.0, near_elbow[1])

        far_shoulder = (chest[0] - 2.0, chest[1] - 3.0)
        far_elbow = (far_shoulder[0] + 8.0, far_shoulder[1] - 2.0)
        far_fist = (far_elbow[0] + 10.0, far_elbow[1] - 1.0)

        pose = {
            'hips': hips, 'chest': chest, 'head': head,
            'near_foot': near_foot, 'near_knee': near_knee,
            'far_foot': far_foot, 'far_knee': far_knee,
            'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
            'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
            'near_fist_angle': 0.0,
            'plume_lag': -5.0
        }
        frame_img, hand = render_brawler_pose(pose)
        frames.append(frame_img)
        hands.append(hand)

    save_clip("dive", frames, hands, fps=24.0, loop=False, ref_speed=0.0)


# --- 8. ROLL & DIVE_ROLL (Tucked rotation ball) ---
def make_rolls(name="roll"):
    frames = []
    hands = []
    N = 8
    for i in range(N):
        ang = 2.0 * math.pi * i / N
        cos_a = math.cos(ang)
        sin_a = math.sin(ang)

        cx, cy = 96.0, 118.0 - 18.0
        # Rotate tuck ball around center
        hips = (cx - sin_a * 8.0, cy + cos_a * 8.0)
        chest = (cx + sin_a * 8.0, cy - cos_a * 8.0)
        head = (cx + sin_a * 16.0, cy - cos_a * 16.0)

        near_foot = (cx - cos_a * 12.0, cy - sin_a * 12.0)
        far_foot = (cx - cos_a * 14.0, cy - sin_a * 14.0)

        near_knee = ((hips[0] + near_foot[0]) / 2.0, (hips[1] + near_foot[1]) / 2.0)
        far_knee = ((hips[0] + far_foot[0]) / 2.0, (hips[1] + far_foot[1]) / 2.0)

        near_shoulder = chest
        near_elbow = (cx + cos_a * 8.0, cy + sin_a * 8.0)
        near_fist = (cx + cos_a * 14.0, cy + sin_a * 14.0)

        far_shoulder = chest
        far_elbow = (cx - cos_a * 6.0, cy - sin_a * 6.0)
        far_fist = (cx - cos_a * 12.0, cy - sin_a * 12.0)

        pose = {
            'hips': hips, 'chest': chest, 'head': head,
            'near_foot': near_foot, 'near_knee': near_knee,
            'far_foot': far_foot, 'far_knee': far_knee,
            'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
            'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
            'near_fist_angle': math.degrees(ang),
            'plume_lag': -2.0
        }
        frame_img, hand = render_brawler_pose(pose)
        frames.append(frame_img)
        hands.append(hand)

    save_clip(name, frames, hands, fps=24.0, loop=False, ref_speed=0.0)


# --- 9. CLIMB (Back view ladder cycle) ---
def make_climb():
    frames = []
    hands = []
    N = 8
    for i in range(N):
        t = 2.0 * math.pi * i / N
        stride = math.sin(t)

        hips = (96.0, 118.0 - 32.0)
        chest = (hips[0], hips[1] - 14.0)
        head = (chest[0], chest[1] - 18.0)

        near_foot = (96.0 + 8.0, 118.0 - 4.0 - max(0.0, stride) * 12.0)
        far_foot = (96.0 - 8.0, 118.0 - 4.0 - max(0.0, -stride) * 12.0)

        near_knee = (near_foot[0], (hips[1] + near_foot[1]) / 2.0)
        far_knee = (far_foot[0], (hips[1] + far_foot[1]) / 2.0)

        near_shoulder = (chest[0] + 5.0, chest[1] - 2.0)
        near_elbow = (near_shoulder[0] + 4.0, near_shoulder[1] - 6.0)
        near_fist = (near_elbow[0], near_elbow[1] - 8.0 - max(0.0, -stride) * 12.0)

        far_shoulder = (chest[0] - 5.0, chest[1] - 2.0)
        far_elbow = (far_shoulder[0] - 4.0, far_shoulder[1] - 6.0)
        far_fist = (far_elbow[0], far_elbow[1] - 8.0 - max(0.0, stride) * 12.0)

        pose = {
            'hips': hips, 'chest': chest, 'head': head,
            'near_foot': near_foot, 'near_knee': near_knee,
            'far_foot': far_foot, 'far_knee': far_knee,
            'near_shoulder': near_shoulder, 'near_elbow': near_elbow, 'near_fist': near_fist,
            'far_shoulder': far_shoulder, 'far_elbow': far_elbow, 'far_fist': far_fist,
            'near_fist_angle': -90.0,
            'plume_lag': 0.0
        }
        frame_img, hand = render_brawler_pose(pose)
        frames.append(frame_img)
        hands.append(hand)

    save_clip("climb", frames, hands, fps=24.0, loop=True, ref_speed=0.0)


if __name__ == '__main__':
    print("Generating Locomotion Suite...")
    make_walk()
    make_run()
    make_jump_rise()
    make_fall()
    make_land()
    make_crouch(is_walk=False)
    make_crouch(is_walk=True)
    make_dive()
    make_rolls("roll")
    make_rolls("dive_roll")
    make_climb()
    print("All Locomotion Clips Generated Successfully!")
