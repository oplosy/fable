# Vector Cutout Art Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bruno, an original street brawler drawn as SVG cutout parts, plays in the game on the existing rig, with the camera moved closer.

**Architecture:** SVG part files are imported by Godot as textures and assembled by the existing `CharacterRig` from a `rig.json`; `RigAnimator` plays the existing angle clips. The camera's zoom steps move from 3/1.5/0.75 to 5/2.5/1.25; world sizes and gameplay numbers do not change.

**Tech Stack:** Godot 4.7 (GDScript, native SVG import), hand-written SVG, JSON clips. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-11-24-vector-cutout-art-design.md`

## Global Constraints

- Godot binary: `C:\Users\mesut\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe` (`<godot>` below). Reimport after adding files: `<godot> --headless --path . --import`. All suites: `tests/run_all.sh` (Git Bash), exit 0 = pass.
- Camera zooms exactly `[5.0, 2.5, 1.25]`; views at 1920x1080: 384x216, 768x432, 1536x864 world px.
- Gameplay numbers stay: hitbox 12x28, speeds, reach, hit windows, `Visuals/Hand` at `Vector2(4, -14)`.
- Bruno: Fast class (`data/classes/fast.tres`); 15 parts: `pelvis`, `torso`, `head`, `arm_front_upper`, `arm_front_lower`, `hand_front`, `arm_back_upper`, `arm_back_lower`, `hand_back`, `leg_front_upper`, `leg_front_lower`, `foot_front`, `leg_back_upper`, `leg_back_lower`, `foot_back`. No coat or scabbard.
- Bruno's look: big square head about a third of his height, buzz cut, short stubble, heavy brows, small scar on one eyebrow; off-white tank top; red cloth hand wraps up the forearms; dark indigo jeans with rolled cuffs; red high-top sneakers; broad shoulders, thick forearms, slightly bowed legs. Skin warm tan. One darker cel tone per colour, light from the upper front. Dark navy-brown outline, one width on every part (about 3 screen px at zoom 5). Back arm and back leg one shade darker. Three-quarter view facing right. Original: nothing copied from Brawlhalla or another game.
- Hit detection never reads art. Fighters never read `Input`.
- Commits: imperative, subject under 72 chars, no AI attribution, the project builds and passes after each commit. Push after committing.

## Review Focus

1. Joint seams: a limb rotated through its full clip range must not open a gap or show a cut outline at the joint. Covered by the user's review of the preview poses (Task 3, Task 5) since no test can judge it.
2. Zoomed-out shots: at zoom 1.25 (35 px fighter) the parts must not shimmer or turn jagged. Pinned by `test_bruno_rig` checking every part texture has mipmaps (Task 3).
3. Old arena sizes: an arena with a 640x360 `camera_limits` must now be rejected. Pinned in `test_arenas` (Task 1).
4. Missing SVG part: a rig whose part file is missing must fail to build with an error, not crash. Pinned in `test_bruno_rig` with a broken rig file (Task 3).
5. Facing left: the flipped rig must keep the gun on the fist and on the aim line. Pinned by `test_aim_pose` aiming both sides (Task 4).

---

### Task 1: Closer camera zooms

**Files:**
- Modify: `scenes/arenas/follow_camera.gd` (`ZOOMS`, `MIN_ZOOM`, comments)
- Modify: `scenes/arenas/arena.gd` (default `camera_limits`, error text, comments)
- Modify: `scenes/arenas/camera_shot.gd` (default `zoom := 5.0`)
- Modify: `scenes/arenas/range.tscn` (two `CameraShot` nodes)
- Modify: `project.godot` (`textures/canvas_textures/default_texture_filter`)
- Test: `tests/test_camera.gd`, `tests/test_arenas.gd`

**Interfaces:**
- Produces: `FollowCamera.ZOOMS == [5.0, 2.5, 1.25]`, `FollowCamera.MIN_ZOOM == 1.25`, `Arena.camera_limits` default `Rect2(-64, -72, 768, 432)`.

- [ ] **Step 1: Update the tests.** In `test_camera.gd` scale every world coordinate and size by 0.6 and map zooms 3→5, 1.5→2.5, 0.75→1.25 (maps 768x432 with LEFT/RIGHT shots at zoom 5, MIDDLE `Vector2(384, 216)`; the one-screen map 384x216 centred `Vector2(192, 108)`; the large map 1536x864). In `test_arenas.gd` add: an arena with `camera_limits = Rect2(0, 0, 640, 360)` → `check(not arena.fits_camera(), "an old 640x360 map is rejected")`, and `check(FollowCamera.ZOOMS == [5.0, 2.5, 1.25], "the camera zooms are 5, 2.5 and 1.25")`.
- [ ] **Step 2: Run** `tests/run_all.sh test_camera test_arenas`. Expected: FAIL.
- [ ] **Step 3: Implement.** `ZOOMS := [5.0, 2.5, 1.25]`, `MIN_ZOOM := 1.25`; arena default `camera_limits := Rect2(-64, -72, 768, 432)` (encloses the existing 640x360 test geometry, so the Range, the test arena and `tests/bot_course.tscn` need no geometry change); error text names 384x216, 768x432, 1536x864; `CameraShot.zoom` default 5.0. Range: add `CameraShot` nodes `ShotLeft` at `(192, 250)` and `ShotRight` at `(448, 250)`, zoom 5. `project.godot`: `default_texture_filter=1` (linear); `Arena._ready` keeps linear with mipmaps. Rewrite comments that mention 3x pixel art.
- [ ] **Step 4: Run** `tests/run_all.sh`. Expected: all suites pass.
- [ ] **Step 5: Commit** `Move the camera zooms closer to 5, 2.5 and 1.25`.

### Task 2: SVG parts in CharacterRig

**Files:**
- Modify: `scenes/fighter/character_rig.gd:62-76` (part loading), doc comments
- Modify: `scenes/fighter/character_data.gd` (comments on `rig_file`, `pixels_per_unit`)
- Create: `tests/fixtures/svg_rig/rig.json` and 11 minimal SVGs (the required parts: pelvis, torso, head, the four arm parts, the four leg parts; each a 4x4 filled rect on a 40x60 canvas), `tests/fixtures/svg_rig/broken.json` (same, plus a pivot for `hand_front` with no file)
- Create: `tests/test_svg_rig.gd`

**Interfaces:**
- Produces: `CharacterRig.build(rig_path, pixels_per_unit)` loads `<part>.svg`, or `<part>.png` when no SVG exists; returns false with `push_error` naming the part when neither exists.

- [ ] **Step 1: Write `test_svg_rig.gd`:** builds `tests/fixtures/svg_rig/rig.json` → `check(built, "a rig of SVG parts builds")`, `check(rig.joints.size() == 11, ...)`, `check(rig.joints.pelvis.get_child(0).texture != null, ...)`. Building `broken.json` → `check(not built, "a missing part file fails the build")`; the build's own error must not fail the suite: add `func expect_error(fragment: String) -> void` to `tests/test_case.gd`, which records the fragment; at the end of `_initialize` each expected fragment removes one collected error containing it, and `check(false, "expected error: " + fragment)` if none matched. Call `expect_error("hand_front.svg")` before building `broken.json`. Also modify: `tests/test_case.gd`.
- [ ] **Step 2: Run** `tests/run_all.sh test_svg_rig`. Expected: FAIL (`.png` not found).
- [ ] **Step 3: Implement** the loading: prefer `ResourceLoader.exists("%s/%s.svg")`, else `.png`; the error names `<part>.svg`.
- [ ] **Step 4: Run** `tests/run_all.sh`. Expected: all pass.
- [ ] **Step 5: Commit** `Let the cutout rig load SVG parts`.

### Task 3: Draw Bruno

**Files:**
- Create: `assets/characters/bruno/<part>.svg` (15 parts), `assets/characters/bruno/rig.json`
- Create: `data/characters/bruno.tres`
- Create: `tools/preview_rig.tscn`, `tools/preview_rig.gd`
- Create: `tests/test_bruno_rig.gd`

**Interfaces:**
- Consumes: Task 2's SVG loading.
- Produces: `res://data/characters/bruno.tres` (`display_name = "Bruno"`, `fighter_class = fast.tres`, `rig_file = "res://assets/characters/bruno/rig.json"`, `pixels_per_unit = 5.0`); `rig.json` with `canvas [200, 240]`, `feet [100, 232]`, `pivots` for the 15 parts, `points.hand_front`, `points.hand_back`, `points.head_top`.

- [ ] **Step 1: Write `test_bruno_rig.gd`** (port of the deleted `test_ronin_rig.gd`, at `git show d5a7b2c:tests/test_ronin_rig.gd`): loads `bruno.tres`; `rig.joints.size() == 15`; has `head`, `torso`, `pelvis`, `hand_front`, `hand_back`, `foot_front`, `foot_back`; no `scabbard`; the same aim up / down / ahead checks with fist distances scaled by 5/3 (16 → 26.7 art px, 17 → 28.3); `reset_pose` zeroes head and torso; every part texture `get_mipmap_count() > 0`; the rig's drawn height from `feet` to `points.head_top` is 150–170 art px (30–34 world px).
- [ ] **Step 2: Run** `tests/run_all.sh test_bruno_rig`. Expected: FAIL (no resource).
- [ ] **Step 3: Draw the parts.** One shared 200x240 canvas, 5 art px per world px, standing pose facing right three-quarter. Each part is a closed shape with the outline drawn as its own stroke (`stroke-linejoin="round"`); every limb end that a child rotates on is a round cap, and the child overlaps the parent's cap so no gap shows. Colours and features from Global Constraints. Write each `.svg.import` with `mipmaps/generate=true` (and `svg/scale=1.0`) after the first import. Write `rig.json` (draw order and hierarchy as `CharacterRig.PARTS` without coat and scabbard) and `bruno.tres`.
- [ ] **Step 4: Preview tool.** `tools/preview_rig.gd` (scene `tools/preview_rig.tscn`, 1920x1080 window, zoom 5): builds a `Fighter` with a character passed by `--character=res://...`, poses it at the given clips and times (`--poses=idle:0,run:0.1,jab_1:0.12,aim:-0.5`), lays them side by side with the 12x28 hitbox outline beside each, saves `--out=<png>` and quits. Run: `<godot> --path . res://tools/preview_rig.tscn -- --character=res://data/characters/bruno.tres --out=<scratchpad>/bruno.png`. Expected: PNG written, no errors.
- [ ] **Step 5: Run** `tests/run_all.sh`. Expected: all pass.
- [ ] **Step 6: User review.** Show the user the preview PNG (standing, idle, run, jab, aim). Iterate the SVGs until they approve the look. Do not start Task 4 before approval.
- [ ] **Step 7: Commit** `Draw Bruno as SVG cutout parts` (parts, rig, data, test, preview tool; split the preview tool into its own commit `Add a rig preview tool` if it is ready first).

### Task 4: Bruno in the game

**Files:**
- Modify: `scenes/main.tscn` (player 1 = `bruno.tres`, player 2 = `dummy.tres`)
- Modify: `data/characters/bruno.tres` (`aim_shoulder`, `aim_shoulder_crouched`, `aim_reach`)
- Create (ports from `git show d5a7b2c:tests/<name>.gd`, `ronin.tres` → `bruno.tres`, 18 joints → 15): `tests/test_rig_draw_order.gd`, `tests/test_aim_pose.gd`, `tests/test_combat_sync.gd`, `tests/test_bruno_gameplay.gd` (from `test_ronin_gameplay.gd`), `tests/test_bruno_actions.gd` and `tests/test_bruno_locomotion.gd` (from the Ronin versions)

**Interfaces:**
- Consumes: `bruno.tres` from Task 3.

- [ ] **Step 1: Port the tests.** Keep every check; change only the character path, joint count and art-px distances (×5/3). `test_aim_pose` aims at the same points with the fighter facing left as well as right and checks the gun stays on the fist (< 1 px) and on the line (< 2°).
- [ ] **Step 2: Run** the ported suites. Expected: aim checks FAIL until the aim values are set.
- [ ] **Step 3: Set** `aim_shoulder` (feet origin, world px, the front shoulder pivot), `aim_shoulder_crouched` and `aim_reach` (shoulder to fist with the arm straight) from Bruno's `rig.json` pivots divided by 5; point `main.tscn` at Bruno.
- [ ] **Step 4: Run** `tests/run_all.sh`. Expected: all pass.
- [ ] **Step 5: Commit** `Play Bruno in the main scene` and `Restore rig tests for Bruno` as two commits (tests first only if they pass with the aim values; otherwise data then tests).

### Task 5: Retune clips and document

**Files:**
- Modify: `assets/animations/*.json` (only what the new proportions need)
- Modify: `docs/PROGRESS.md`, `docs/GAME_DESIGN.md` (Visual Direction: Bruno, zooms), `CLAUDE.md` (Characters, Maps camera sizes, Active Art)

- [ ] **Step 1: Review every clip** with the preview tool at its key times (contact, apex, full reach). Fix feet sliding through or floating above the floor (root heights), limbs crossing the head, fists short of full reach in strikes. Keep each clip's `length`, key times and hit timing.
- [ ] **Step 2: Run** `tests/run_all.sh`. Expected: all pass (`test_combat_sync` guards hit timing).
- [ ] **Step 3: User review in the game.** Run the game window (`<godot> --path .`), capture Bruno walking, running, jabbing, kicking, aiming and rolling; show the user. Iterate until approved.
- [ ] **Step 4: Docs.** Record Bruno, the zooms and the SVG pipeline in `GAME_DESIGN.md` → Visual Direction, a session 12 status in `PROGRESS.md`, and update `CLAUDE.md` (map camera sizes 384x216, 768x432, 1536x864; shot zooms 5, 2.5, 1.25; Active Art).
- [ ] **Step 5: Commit** `Retune clips to Bruno's proportions` and `Document Bruno and the closer camera`; push.
