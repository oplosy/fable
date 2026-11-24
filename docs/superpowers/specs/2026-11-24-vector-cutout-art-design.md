# Vector Cutout Art: First Character and Close Camera

Date: 2026-11-24 (session 12). Status: draft for the user's review.

## Intent

The user could not produce pixel art designs, so pixel art is gone (deleted this session). The game takes a stylized 2D vector look like Brawlhalla: bold outlines, flat cel shading, chibi proportions (big head, short readable limbs), animated as a cutout rig, not frame by frame. Claude draws and rigs everything with the tools on the PC (Godot, Blender; the user installs more on request). This first step proves the whole pipeline on one character, so later characters are only new art.

## Goals

- One original character, **Bruno, a street brawler**, drawn as SVG cutout parts and playing in the game with all existing clips.
- The camera moves closer so the character reads at Brawlhalla-like size.
- Adding the next character means a new folder of SVG parts, a `rig.json` and a `CharacterData` resource; no core script changes.

## Non-goals

- Vector weapons, items, props and maps: they stay flat placeholder boxes; each gets its own design later.
- New animations or new moves. Existing clips are only retuned to the new proportions.
- Changing gameplay numbers (hitbox 12x28, speeds, reach, hit windows).
- The second player's character: `dummy.tres` stays a box.

## Anti-goals

- Copying any Brawlhalla (or other game's) character, costume, palette or look. The style is a genre, Bruno is original.
- Hit detection that depends on art (rule stays: shapes and queries only).
- Blurry or jagged art: parts are rasterized at the size they are shown at the closest zoom.
- Visible seams or gaps at joints while limbs rotate.

## Approaches (user picked A)

- **A. SVG parts on the existing rig (picked).** Each body part is an SVG file; Godot imports SVG natively at a chosen scale. `CharacterRig` and `RigAnimator` already build a rig from part images and play angle-based JSON clips. Reuses the system, keeps runtime aiming (head, torso and arms turn toward the cursor), small files. Cost: Claude draws by writing SVG, so the look is refined over a few review rounds.
- B. Blender 2D rig rendered to sprite sheets. Strong animation tools, but the game would play fixed frames: runtime aiming needs every angle drawn, files are large. Rejected.
- C. Godot `Skeleton2D` with deformed `Polygon2D` meshes. Native, but mesh weights are hard to author from code and the existing rig code would be thrown away. Rejected.

## Decided

### Camera (user picked "move the camera closer")

- `FollowCamera.ZOOMS` becomes `[5.0, 2.5, 1.25]` (Claude's pick). At 1920x1080 the views are 384x216, 768x432 and 1536x864 world px; a 28 px fighter is about 140, 70 and 35 screen px tall.
- An arena's `camera_limits` must be one of those three sizes; `CameraShot.zoom` uses those zooms. The Range, the test arena and `tests/bot_course.tscn` are resized to fit; `test_arenas` and `test_camera` follow.
- Textures switch from nearest to linear filtering with mipmaps (project default), since nothing is pixel art any more.

### Bruno (Claude's design, the user asked Claude to decide)

- A stocky street brawler, Fast class (the existing jab, jab, jab, hook and jump kick clips fit him; `fast.tres`).
- Look: big square head about a third of his height, buzz cut, short stubble, heavy brows, a small scar on one eyebrow. White tank top, red cloth hand wraps up the forearms, dark indigo jeans with rolled cuffs, red high-top sneakers. Broad shoulders, thick forearms, slightly bowed legs.
- Palette: skin warm tan; tank off-white; jeans indigo; wraps and sneakers red; one darker cel tone per colour, light from the upper front. Outline dark navy-brown, one constant width on every part (about 3 screen px at zoom 5).
- He is drawn three-quarter facing right, like the old rig; the fighter flips him for left.

### Rig

- Same part names and hierarchy as the old rig, minus the optional coat and scabbard parts (15 parts): `pelvis`, `torso`, `head`, `arm_{front,back}_{upper,lower}`, `hand_{front,back}`, `leg_{front,back}_{upper,lower}`, `foot_{front,back}`. `CharacterRig` already treats coat, scabbard, feet and hands as optional.
- Files: `assets/characters/bruno/<part>.svg` plus `rig.json` (canvas, feet, draw order, hierarchy, pivots, points such as `hand_front`), and `data/characters/bruno.tres` with `rig_file`.
- Every part shares one canvas, like the old rig, so pivots are canvas coordinates. The canvas is sized so the drawn body is about 32 world px tall at 5 canvas units per world px: art is rasterized at the closest zoom's screen size, and mipmaps cover the zoomed-out shots.
- Joints: each limb end is a rounded cap; the child part overlaps the parent's cap, so rotation never opens a gap or shows a cut outline.
- `CharacterRig` loads `<part>.svg` as well as `<part>.png`.
- The back arm and back leg are a shade darker than the front ones so the limbs read apart.

### Animation

- The 28 clips in `assets/animations/` stay; their angles are retuned where the new proportions need it (short limbs, big head), mainly root heights, stride and reach. Strike timing and hit windows do not change.
- Restored tests: rig build, draw order, aim pose and combat sync come back for Bruno (they were deleted with Ronin).

### Review with the user

- Claude renders Bruno with Godot (a small preview scene run with a window, saving a screenshot) in a turnaround: standing, idle, run, jab, aim, and next to the 28 px hitbox. The user approves the look before the clips are retuned, then sees him playing in the game.
- `main.tscn`: player 1 is Bruno, player 2 the `dummy.tres` box, on the Range.

## Left to the builder

- Exact canvas size, pivots and the SVG drawing method (hand-written files or a generator script under `tools/`).
- Godot SVG import settings (scale, mipmaps) that give crisp parts at zoom 5.
- How far each clip needs retuning; keep hit timing tests green.
- No new dependencies without asking the user.
