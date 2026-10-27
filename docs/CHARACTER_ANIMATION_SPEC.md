# Character Rig and Animation Spec

The brief for the artist (human or AI) who prepares the character parts and animations. Read all of it before starting, and again before handing anything over. Gameplay timings quoted here come from the data files named next to them; if a data file and this spec disagree, the data file wins and the disagreement must be reported.

## 0. Ground Rules

- **Do not change any code, scene or data file** (`scenes/`, `data/`, `tests/`, `project.godot`). Only write the files listed in this spec. Claude wires everything into the game.
- Work only inside the character folders: `characters/<NN_Name>/rig/` and `characters/_animations/`.
- Every character uses the same rig and the same animations. Animations are made **once** on the shared rig, never per character.
- Art style stays the user's: 64x96 canvas, 1 px dark outline, cel shading, limited palette, 3/4 view facing right.
- Units: the game world is 1/3 of the art. **1 world pixel = 3 art pixels.** Every art coordinate in this spec is in art pixels on the 64x96 canvas, x to the right, y down.
- Feet origin: art pixel **(32, 93)** is the point between the feet on the floor. Everything is placed relative to it.
- Hit detection never uses the art. Animations must still **look** like they reach the hit areas listed below, at the moment the game hits.

## 1. Facing Left and Right

- Everything is drawn and animated **facing right**.
- Facing left is the whole character **mirrored horizontally** by the game (the rig flips around the feet origin). Do not draw left-facing versions.
- Turning is **instant**: the frame the player presses the other direction, the character is mirrored. There is no turn animation, so that controls stay immediate. (The front arm stays the front arm after mirroring, which is correct for a 3/4 view.)
- Because of mirroring, characters must have **no text, numbers or logos that read wrong when flipped**. Report any asymmetric detail (eye patch, one shoulder pad, scar) so the user can decide whether it may swap sides.

## 2. Phase 1: Cut Every Character Into Rig Parts

All 20 characters in `characters/` (01 to 20). Each already has 5 layers (`01_Back_Arm`, `02_Legs`, `03_Torso`, `04_Head`, `05_Front_Arm`) and a mannequin version. Split them into these parts.

### 2.1 Parts and draw order

Drawn back to front (z 0 is furthest back):

| z | Part file | What it contains | Parent | Pivot (joint it rotates around) |
|---|---|---|---|---|
| 0 | `arm_back_upper.png` | back upper arm, shoulder to elbow | torso | back shoulder |
| 1 | `arm_back_lower.png` | back forearm and hand | arm_back_upper | back elbow |
| 2 | `coat_back.png` | **optional**: the inside and back of a long coat, skirt or cape, seen between and behind the legs (for example a coat's dark lining between the thighs) | pelvis | waist |
| 3 | `leg_back_upper.png` | back thigh, hip to knee | pelvis | back hip |
| 4 | `leg_back_lower.png` | back shin and foot | leg_back_upper | back knee |
| 5 | `pelvis.png` | hips and belt area | root | centre of the hips |
| 6 | `leg_front_upper.png` | front thigh | pelvis | front hip |
| 7 | `leg_front_lower.png` | front shin and foot | leg_front_upper | front knee |
| 8 | `torso.png` | chest and belly, shoulders included | pelvis | waist (where torso meets pelvis) |
| 9 | `coat_tail.png` | **optional**: the outside front of a long coat, skirt or apron that hangs over the thighs | pelvis | waist |
| 10 | `head.png` | head, hair, hat, mask | torso | neck |
| 11 | `arm_front_upper.png` | front upper arm | torso | front shoulder |
| 12 | `arm_front_lower.png` | front forearm and hand | arm_front_upper | front elbow |

Rules for the parts:

1. Every part file is the **full 64x96 canvas**, with the part drawn **exactly where it is in the current standing pose** (like the existing layers). Do not move or re-centre it.
2. **Joints overlap.** Each part extends 2-3 art px past its joint as a rounded cap that is hidden under the neighbouring part in the standing pose. Then rotations of up to ±100° (shoulders and hips: any angle) never open a gap or show a hard cut.
3. Parts hidden behind other parts in the standing pose must still be drawn complete underneath (for example the top of the back thigh behind the pelvis, the shoulder under the head's chin), because animations will reveal them.
4. Hands are part of the forearm. The front hand is drawn **closed in a grip** (it holds every weapon). The back hand is drawn as a loose fist.
5. Feet are part of the shin. Shoes stay flat on the floor in the standing pose: the sole's lowest pixel row is y = 92, whose bottom edge is the floor line y = 93 (the feet origin). This is how all 20 characters are already drawn; keep it.
6. Keep the outline: every part has its own complete 1 px outline where it is visible on its own.
7. Long hair, scarves, belts and coat tails that would look stiff when the body bends go into `coat_tail.png` if they hang from the waist, or stay on `head.png` / `torso.png` otherwise. Anything of a coat or skirt that is seen between or behind the legs (its lining, its back hem) goes into `coat_back.png`, so the legs walk in front of it while `coat_tail.png` covers them from the front. Do not add more parts than the table.
8. Use the character's own colours; never change the design. The user approves the designs, not the rig.

### 2.2 Joint file

One `rig.json` per character in `characters/<NN_Name>/rig/`:

```json
{
  "character": "01_TrenchCoat_Agent",
  "canvas": [64, 96],
  "feet": [32, 93],
  "pivots": {
    "pelvis": [32, 52],
    "torso": [32, 50],
    "head": [33, 24],
    "arm_back_upper": [41, 28],
    "arm_back_lower": [43, 41],
    "arm_front_upper": [22, 28],
    "arm_front_lower": [20, 41],
    "leg_back_upper": [37, 54],
    "leg_back_lower": [38, 73],
    "leg_front_upper": [27, 54],
    "leg_front_lower": [26, 73],
    "coat_tail": [32, 50],
    "coat_back": [32, 50]
  },
  "points": {
    "hand_front": [18, 56],
    "hand_back": [44, 56],
    "head_top": [33, 7]
  },
  "asymmetric_details": ["none"]
}
```

The numbers above only show the format; measure the real ones on each character.

- `pivots`: the art pixel each part rotates around (its joint centre), in the standing pose.
- `points.hand_front`: the pixel inside the closed front fist where a weapon's grip pixel goes. `hand_back`: the same for the back fist (it steadies two-handed weapons).
- `points.head_top`: the highest pixel of the head or hat (for the health bar and name).
- Leave `coat_tail` and `coat_back` out of `pivots` when the character has no such part.
- `asymmetric_details`: see section 1.

### 2.3 Phase 1 check before handing over (go through twice)

For every character:
- [ ] All 11 files exist, plus `coat_tail.png` and `coat_back.png` when the character has them,, each exactly 64x96, transparent background.
- [ ] Stacking all parts in the z order gives back the original standing character pixel for pixel (no missing or doubled pixels).
- [ ] Each part, rotated ±60° around its pivot (shoulders and hips: also 180°), shows no gap and no hard cut at the joint.
- [ ] `rig.json` is valid JSON, every pivot lies inside its part, the feet origin is (32, 93), the lowest shoe pixel row is y = 92.
- [ ] Nothing in the design changed.
- [ ] A preview sheet `rig_preview.png` (4x scale) shows the parts pulled apart (exploded view) with the pivots marked.

## 3. Phase 2: Animations

Make every animation **once**, on character 01 (TrenchCoat Agent) and its mannequin, as keyframe data for the shared rig. The game plays the same data on every character, so the timings and poses must not depend on 01's look.

### 3.1 Keyframe format

One file per animation in `characters/_animations/<name>.json`:

```json
{
  "name": "walk",
  "loop": true,
  "length": 0.32,
  "reference_speed": 120,
  "events": [{"t": 0.0, "name": "step"}, {"t": 0.16, "name": "step"}],
  "keys": [
    {
      "t": 0.0,
      "root": [0, 0],
      "angles": {
        "pelvis": 0, "torso": 4, "head": -2,
        "arm_back_upper": -25, "arm_back_lower": 15,
        "arm_front_upper": 25, "arm_front_lower": 10,
        "leg_back_upper": 20, "leg_back_lower": 5,
        "leg_front_upper": -25, "leg_front_lower": 30,
        "coat_tail": -5
      }
    }
  ]
}
```

- `length`: seconds. `loop`: whether it repeats.
- `keys[].t`: seconds from the start; the first key is at 0, the last before `length`. The game blends smoothly between keys.
- `angles`: degrees, **relative to the standing pose**, around each part's pivot. Positive = clockwise on screen (Godot convention: y points down). A part missing from a key keeps the previous key's angle.
- `root`: art pixel offset of the whole body from the feet origin (for crouching down, jumping up in a pose, leaning, lying).
- `events`: named moments the game reacts to (footstep sound, hit frame, throw release). Names are listed per animation below.
- `reference_speed`: for movement loops, the speed (world px/s) the leg cycle matches. The game speeds the playback up or down to the real speed.
- Also deliver a `<name>_preview.png` for every animation: the key poses of character 01 side by side at 4x, with the key times written under them, so the user can review without running the game.

### 3.2 Movement speed and foot sliding

Feet must not slide. The planted foot moves backwards at exactly the running speed. In art pixels: speed x 3. A walk at 120 world px/s moves the floor under the foot 360 art px per second. With a step of S art px, one full cycle (two steps) lasts 2S / (speed x 3) seconds. Example: steps of 48 art px at 120 world px/s give a 0.27 s walk cycle. The game is fast and arcade-like, so legs move quickly. That is intended.

Reference speeds (`data/classes/*.tres`, `scenes/fighter/fighter_class.gd`): walk 120 (Fast class 130, Heavy 100), run 200 (Fast 215, Heavy 170), crouch walk 50, roll 220 (Fast 235, Heavy 190), dive forward 260 and up 220 (Heavy 220/190), jump up 300 (Heavy 260). Gravity is the project default (980).

### 3.3 Hit areas the poses must reach

Hit areas are given per attack as `hitbox_offset` and `hitbox_size` in world px, relative to the feet, facing right (`data/classes/fast.tres`, `heavy.tres`, `data/weapons/knife.tres`, `bat.tres`). Multiply by 3 for art px. At the **first frame of the active window** (after `windup`), the fist, foot or weapon tip must be inside that area and stay there for the whole `active` time. Then it returns during `recovery`.

| Attack | windup / active / recovery (s) | Fist, foot or tip at (art px from feet) |
|---|---|---|
| Fast jab (x3) | 0.05 / 0.07 / 0.10 | fist at (+36, -54), area 42x24 |
| Fast hook (combo finisher, knocks down) | 0.08 / 0.08 / 0.20 | fist at (+36, -54), area 42x30, swinging in from the side |
| Fast jump kick | 0.05 / 0.20 / 0.10 | foot at (+36, 0), area 48x48 (forward, at the fighter's own feet height while in the air) |
| Heavy punch (x2) | 0.10 / 0.08 / 0.18 | fist at (+36, -54), area 48x30 |
| Heavy kick (finisher, knocks down) | 0.15 / 0.10 / 0.30 | foot at (+42, -24), area 54x30 |
| Heavy jump kick | 0.08 / 0.20 / 0.15 | foot at (+36, 0), area 54x48 |
| Knife stab (x2) | 0.03 / 0.06 / 0.08 | blade tip at (+42, -54), area 48x24 |
| Knife slash (finisher) | 0.05 / 0.08 / 0.15 | blade sweeps through (+42, -54), area 48x36 |
| Bat swing (x2) | 0.12 / 0.10 / 0.20 | bat head through (+54, -54), area 66x42 |
| Bat home run (finisher, knocks down) | 0.15 / 0.10 / 0.30 | bat head through (+54, -54), area 66x42, bigger wind-up |

For weapon attacks, the weapon is a separate sprite held at `hand_front` (its grip pixel on the hand). Animate the arms so the weapon reaches the area. The weapon sprites and their grip pixels are in `assets/` and `data/weapons/*.tres`.

Every attack animation has an event `"hit"` at `t = windup` and its `length = windup + active + recovery` exactly.

### 3.4 The complete animation list

Each entry: file name, loop or not, length, and what it must show. "Hold" means the last key stays until the game changes the animation. The game state each one belongs to is `Fighter.State` in `scenes/fighter/fighter.gd`.

**Standing and moving** (states IDLE, WALK, RUN, CROUCH)
1. `idle`: loop, 1.2-1.6 s. Relaxed fighting stance, breathing (torso and head bob 1 art px), arms ready. Bare-handed.
2. `idle_melee_item`: loop, same timing as `idle`. Holding a one-handed melee item (knife) low and ready in the front hand.
3. `idle_melee_two_hand`: loop. Holding a long melee item (bat, pipe, sledgehammer) with both hands, resting on the shoulder.
4. `walk`: loop, reference speed 120. Arms swing opposite the legs. Events `step` at each foot plant.
5. `run`: loop, reference speed 200. Leaning forward, longer stride with a moment where both feet are off the floor, arms pumping. Events `step`.
6. `crouch_enter`: 0.08 s, from standing down to the crouch. The crouched body is half height: the top of the head at about 45 art px above the feet (`root` y about +40, knees bent).
7. `crouch_idle`: loop, 1.2 s, crouched and still, slight breathing.
8. `crouch_walk`: loop, reference speed 50, crouched, short steps. Events `step`.
9. `crouch_exit`: 0.08 s, back up to standing.

**Jumping, falling and landing** (state AIR)
10. `jump_rise`: hold. Pushes off, then tucks the legs slightly while going up. A jump is instant on the button press (no wind-up on the ground, the controls must stay immediate), so the first key already shows the take-off.
11. `jump_apex`: 0.15 s, the turn at the top of the jump, body loosening.
12. `fall`: loop, 0.4 s. Falling, arms out for balance, legs reaching down.
13. `fall_long`: loop, 0.5 s. Falling a long way (off the map or from very high): flailing arms and legs. The game switches to it once the fall speed is high.
14. `land`: 0.12 s, cosmetic. Knees absorb the landing, then back to stance. The game may cut it at any frame when the player acts.
15. `land_hard`: 0.2 s, after a long fall: a deeper crouch on landing. Cosmetic, cuttable.

**Dive and roll** (states DIVE, ROLL)
16. `dive`: hold. A running jump is a long, low **head-first dive**: body almost horizontal, arms stretched forward. Lasts until landing.
17. `dive_land`: 0.15 s. Catches the landing on the hands and springs back to the feet (cosmetic, cuttable).
18. `roll`: **exactly 0.4 s**, not looping. Down while running: a forward somersault on the floor, tucked into a ball, one full turn (the root moves down so the ball stays on the floor). The fighter cannot be hit during it, so it must read clearly as a dodge.

**Firearms** (state AIM). A firearm is only out while standing still on the floor; moving puts it away (the weapon sprite is hidden, there is no holster on the body). Aim goes from straight up (-90°) to straight down (+90°) in the facing half, turning at 90° per second.
19. `aim_one_hand_up`, `aim_one_hand_level`, `aim_one_hand_down`: hold poses at -90°, 0° and +90° for one-handed guns (pistol, revolver, SMG). The front arm stretches towards the aim, the back hand supports the grip or rests. The game blends between the three by the aim angle, so the three must blend cleanly (same arm order, no flips).
20. `aim_two_hand_up`, `aim_two_hand_level`, `aim_two_hand_down`: the same for long guns held with both hands (shotgun, machine gun, sniper, flamethrower). Stock at the shoulder, back hand on the barrel. Use `hand_back` for the back hand.
21. `aim_shoulder_up`, `aim_shoulder_level`, `aim_shoulder_down`: the same for the bazooka, resting on the front shoulder.
22. `aim_crouch_one_hand_*`, `aim_crouch_two_hand_*`, `aim_crouch_shoulder_*` (up, level and down for each): the same nine poses while crouched. Crouching makes shots more accurate, so this is a common pose.
23. `draw`: 0.1 s, the moment the fighter stops and brings the gun up (cosmetic, cuttable). One-handed, two-handed and shoulder variants: `draw_one_hand`, `draw_two_hand`, `draw_shoulder`.
24. `recoil_one_hand`, `recoil_two_hand`, `recoil_shoulder`: 0.08 s each. A short kick back of the arms and shoulders, played additively on top of the aim pose at every shot (the SMG and machine gun fire every 0.1 s or faster, so it must look right when restarted every frame or two).
25. `weapon_empty_toss`: 0.15 s. The empty gun is thrown aside (the game drops it). Event `release`.

**Melee attacks** (state ATTACK). Exact timings and reach in section 3.3. Each is one attack of a combo; pressing attack again during it chains the next.
26. `fast_jab_1`, `fast_jab_2`, `fast_jab_3`: alternating fists (front, back, front) so a three-jab chain looks like a flurry.
27. `fast_hook`: wide hook with the front fist, body turning into it. Knocks down.
28. `heavy_punch_1`, `heavy_punch_2`: slow, heavy straight punches (front, then back fist).
29. `heavy_kick`: front kick or side kick. Knocks down.
30. `fast_jump_kick` and `heavy_jump_kick`: in the air, one leg stretched forward for the whole active window, the other tucked. Hold the active pose; it ends on landing or after recovery.
31. `knife_stab_1`, `knife_stab_2`, `knife_slash`: quick stabs forward, then a horizontal slash.
32. `bat_swing_1`, `bat_swing_2`, `bat_home_run`: two-handed horizontal swings; the home run has a big wind-up and a full follow-through.
33. Future melee items, same structure (three attacks each, timings will follow their data files; make them now with the bat's timing as a placeholder): `machete_*` (like knife but wider slashes), `pipe_*` (one-handed blunt swings), `sledgehammer_*` (slow two-handed overhead smashes).
34. `combo_breaker`: 0.2 s. While being comboed, the fighter bursts free with a two-handed shove (attack and jump together). Event `hit` at 0.05 s. The attacker is pushed back 160 px/s and stunned 0.3 s.

**Throwables** (state COOK, and AIM while holding one)
35. `throwable_hold_up`, `throwable_hold_level`, `throwable_hold_down`: standing still with a grenade or molotov ready in the front hand, arm cocked back, aiming from -90° to +90° like the guns (blended by angle).
36. `pull_pin`: 0.15 s. The back hand pulls the pin or lights the molotov's rag, then holds. Event `armed`.
37. `cook`: loop, 0.5 s. Holding the live item ready to throw (attack held). The fighter cannot move.
38. `throw`: 0.25 s. Overhand throw along the aim (the item leaves 30° above the aim line). Event `release` at the moment the arm is forward.
39. `place_low`: 0.4 s, for future mines and C4: kneel and set the item on the floor. Event `release`.

**Getting hit** (state STUN). Stun times vary from 0.03 s (SMG bullets) to 0.7 s (heavy kick); the game plays these at their natural length and cuts or holds them.
40. `hit_front_light`: 0.2 s. A flinch from a hit in front: head snaps back, torso leans back.
41. `hit_back_light`: 0.2 s. A flinch from a hit from behind: lurch forward.
42. `hit_front_heavy` and `hit_back_heavy`: 0.35 s. Bigger stagger for strong hits (stun 0.4 s or more), one step back or forward.
43. `hit_air`: 0.25 s. Hit while in the air: body jerks, limbs flung.
44. `hit_crouch`: 0.2 s. Flinch while crouched.
45. `burning`: loop, 0.4 s, upper body only (played additively): patting at flames, flinching. Fire does not stun, the fighter keeps running, so it must layer over walk and run.

**Knockdown and getting up** (state DOWN). A knockdown lasts **1.25 s** from the hit (`knockdown_time`), then the fighter gets up and is invulnerable for **0.4 s** (`getup_invulnerability`).
46. `knockdown_back`: 0.35 s. Hit from the front: launched backwards (knockback pushes up and back), falling onto the back. Ends lying face up, head away from the attacker. Root moves down to the floor (lying height about 12-15 art px).
47. `knockdown_front`: 0.35 s. Hit from behind: thrown forward onto the face. Ends lying face down.
48. `knockdown_air`: hold. Knocked down while in the air or by an explosion: tumbling in the air (spinning), until landing.
49. `lying_back` and `lying_front`: loop, 0.8 s. Lying on the floor, small breathing or groggy movement. Total time on the floor with the fall: 1.25 s.
50. `getup_back` and `getup_front`: **exactly 0.4 s**. From lying face up / face down back to the fighting stance. The fighter is invulnerable during it, so it should look like a quick kip-up or push-up, not slow. The fighter may already act during these 0.4 s, so the game cuts it the moment the player moves or attacks; the stance must be readable from about 0.2 s on.
51. `explosion_launch`: hold. Blown away by a blast: spread-eagle, spinning, then `knockdown_air` rules apply.

**Death** (state DEAD). The body stays on the map, lying down.
52. `death_back` and `death_front`: 0.5 s. Collapsing backwards or forwards (same logic as the knockdowns), heavier and limp. Ends lying, not breathing.
53. `death_air`: hold. Killed in the air: limp falling body, then `death_land` 0.2 s on hitting the floor.
54. `death_explosion`: hold. Killed by a blast: thrown and spinning, limp.
55. `dead_back` and `dead_front`: hold, a single still pose lying dead.
56. `fall_out`: the fighter fell off the map. Use `fall_long` until it leaves the screen (the game removes it there).

**Items and inventory**
57. `pickup_swap`: 0.2 s. Down on a spawned item while the slot is full: quick crouch and grab from the floor, then stand. Event `grab`. (Walking over an item for an empty slot has no animation.)
58. `slot_switch`: 0.1 s, upper body only. Changing the held item with keys 1-4.
59. `drop`: 0.15 s, upper body only. Letting go of an item (it falls from the hand).

**Match and modes** (needed later; deliver after everything above is approved)
60. `spawn`: 0.3 s. Appearing at the start of a match or on respawn: landing into the stance.
61. `victory`: loop, 1.5 s. Winning pose.
62. `defeat`: hold. Slumped.
63. `taunt`: 1.0 s. Mocking gesture, cosmetic.
64. `carry_idle`, `carry_walk`, `carry_run`: carrying the objective (capture the flag) under the back arm, front arm free for melee. Reference speeds as walk and run.
65. `plant_loop` and `defuse_loop`: loop, 0.6 s. Kneeling and working on a bomb (C4) with both hands.
66. `hostage_idle`, `hostage_walk`: for hostage characters: hands tied, hunched; they walk while led.
67. `interact`: 0.3 s. Pressing a button or freeing a hostage.

### 3.5 Phase 2 check before handing over (go through twice)

For every animation:
- [ ] The file name is exactly as listed, the JSON is valid, and every part name matches the rig.
- [ ] `length` is the exact time given (attacks: windup + active + recovery; roll and getup 0.4 s).
- [ ] Attacks have a `hit` event at `t = windup`, and the fist, foot or tip is inside the listed area through the whole active window.
- [ ] Movement loops have `reference_speed` and `step` events, and the planted foot does not slide at that speed.
- [ ] Looping animations join their last key to their first without a jump.
- [ ] Blended sets (aim up, level and down; throwable hold) use matching limb arrangements, so blending never flips a limb through the body.
- [ ] Nothing pokes through the floor (no pixel row of feet or lying bodies goes below y = 92), except the roll's tuck, which stays on the floor too.
- [ ] Played on characters 01 (tall), 08 (wide sumo) and 10 (short dwarf) using their own `rig.json`, the poses still read correctly. Report anything that breaks for one body type.
- [ ] A preview PNG exists for every animation.
- [ ] Nothing in `scenes/`, `data/`, `tests/` or `project.godot` was changed.

### 3.6 Clips already made by Claude

While the art AI was out of quota, Claude generated these clips into `assets/animations/` with `tools/make_animations.gd` (leg poses solved from foot targets): `idle`, `walk`, `run`, `jump_rise`, `fall`, `land`, `crouch_idle`, `crouch_walk`; the melee attacks `fast_jab_1..3`, `fast_hook`, `fast_jump_kick`, `heavy_punch_1..2`, `heavy_kick`, `heavy_jump_kick`, `knife_stab_1..2`, `knife_slash`, `bat_swing_1..2`, `bat_home_run` (timed from the data files, the hit pose reaching the hit area); `hit_front_light`, `hit_front_heavy`, `hit_back_light`, `hit_back_heavy`, `hit_air`; `knockdown_back/front`, `lying_back/front`, `getup_back/front`, `death_back/front`. A delivered clip of the same name replaces the generated one. Rules learned while making them:
- The rig has no ankle, so a foot turns with its shin. A deep crouch therefore stands on the balls of the feet (a real squat), not flat-footed with upright shins; walking feet roll heel to toe with the shin.
- `walk`, `crouch_idle` and `crouch_walk` are copied from motion capture (CMU, `art/mocap/`), so their body height, lean and foot paths are a real person's.
- Held items lie along the forearm, grip in the fist, so an attack aims the item by turning the forearm.
- Lying face up, the near arm and leg sit lower than the body line in the 3/4 view; keep them across the body so they stay above the floor.
- The game bends `coat_tail` and `coat_back` as cloth over the thighs and keeps them off the floor, so clips only turn coats to hang straight down; they need no coat poses.

### 3.7 Designing a character that animates easily

The clips are made on the Street Brawler's rig (`assets/characters/street_brawler/`). A new character animates cleanly when it follows the same rules:

- Strict side view, facing right; front and back limbs at the same x.
- Reuse the Street Brawler's pivots and `feet`, so the shared clips fit without changes.
- Draw each limb as a capsule whose round ends sit on its joints, so turning a part never opens a gap.
- Separate `foot_front` / `foot_back` parts (children of the lower legs), pivot on the ankle, flat sole on row 92.
- No long stiff clothes below the waist; a coat needs the cloth mesh (`coat_back` / `coat_tail`).

## 4. Order of Work and Hand-over

1. Phase 1 for **character 01 only**. Stop and hand over for review (Claude builds the rig in the game with it).
2. After approval: Phase 1 for characters 02 to 20.
3. Phase 2 in this order, stopping after each group for review: (a) `idle`, `walk`, `run`, `jump_rise`, `fall`, `land`; (b) everything else in sections "Standing and moving" to "Throwables"; (c) getting hit, knockdown and death; (d) items; (e) match and modes.
4. With each hand-over, write `characters/_animations/HANDOVER.md`: what was delivered, anything that disagreed with the data files, and any open question. Never guess silently.
