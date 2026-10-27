# Progress and Handoff

Where development stands and what comes next. Update this at the end of every working session. Gameplay rules live in [GAME_DESIGN.md](GAME_DESIGN.md); this file tracks what is built.

## Status (2026-10-27, session 2)

Branch `main` (last feature commit `717a940`, movement package), pushed to https://github.com/oplosy/fable. All 7 headless test suites pass. Placeholder art only (colored rectangles); no menus, maps, bots or networking yet.

## Built So Far

| Area | What works | Main files |
|------|------------|------------|
| Project setup | Godot 4.7.2, 640x360 viewport scaled x2 to 1280x720, integer scaling, nearest filter, pixel snap. Physics layers: 1 world, 2 fighters, 3 projectiles, 4 pickups. | `project.godot` |
| Arena | Test arena: floor, side walls, `SpawnPoints` (P1, P2), fixed `Camera2D`. | `scenes/arenas/test_arena.tscn` |
| Main scene | Loads the arena, spawns the player (Fast class, pistol equipped) and an idle target dummy (Heavy class) that respawns 1.5 s after dying. | `scenes/main.gd` |
| Fighter | One shared `CharacterBody2D`: walk, run, jump (K), facing, 4 slots (melee, firearm, throwable, power-up; only the first two can hold anything). | `scenes/fighter/fighter.gd` |
| Controllers | Fighters never read `Input`; a `FighterController` provides intent (move, run, aim, down, jump, attack, slot). `LocalController` reads `p1_*` actions and turns Shift or a double tap into the run intent. The base controller is idle (dummy). | `scenes/fighter/controllers/` |
| Firearm | Drawn only when standing still on the floor in the firearm slot; A/D holster it. W/S rotate aim within the facing 180°. Attack fires projectiles along the aim. | `scenes/weapons/`, `data/weapons/pistol.tres` |
| Health and hits | `Health` component; `take_hit(damage, knockback, stun, knocks_down)`; hit flash, knockback, stun. Dead bodies lie down and leave the fighters layer. | `scenes/components/health.gd` |
| Classes and melee | `FighterClass` resources hold the melee combo (`MeleeAttack` resources), combo cooldown, jump kick and knockdown settings. Fast: jab x3 + hook. Heavy: punch x2 + kick. Hits use a physics shape query, once per target per attack. | `scenes/fighter/melee.gd`, `data/classes/` |
| Knockdown | Combo finishers and the jump kick knock down for 1.25 s. Downed fighters cannot be hit (per-class `downed_invulnerable`), plus 0.4 s invulnerability after getting up. Knockdown drops the firearm into the arena. | `fighter.gd`, `scenes/weapons/dropped_weapon.gd` |
| Jump kick | No punches in the air; attack while airborne is the class jump kick, once per jump, hitting forward at foot level. | `melee.gd`, `data/classes/*.tres` |
| Movement | Walk/run speeds; walking jump straight up, running jump is a forward dive; S while running rolls (invulnerable). No air steering. Speeds are `Fighter` exports until per-class stats. | `fighter.gd`, `local_controller.gd` |
| Art pipeline | Aseprite CLI with Lua scripts; first sprite: pistol (9x5). | `art/weapons/pistol.aseprite` → `assets/weapons/pistol.png` |

Tests (`tests/`): `test_health`, `test_fighter`, `test_combat`, `test_main`, `test_melee`, `test_knockdown`, `test_movement`, all on the `test_case.gd` base (30 s watchdog). How to run them: see `CLAUDE.md` → Running Tests.

## Next Steps (in agreed order)

1. **Combo breaker**: attack + jump together while being comboed breaks free and pushes the attacker back slightly; about 10 s cooldown.
2. **Per-class stats**: walk/run speed, dive and roll, jump height and health move into `FighterClass`.
3. **Weapon pickups**: pick up dropped/spawned firearms (dropped weapons already exist in the arena but cannot be picked up).
4. Then: sprites and animation states, player 2 key layout, bots (versus-computer), online play, maps (small/medium/large), user map import (data-only format).

Open questions for the user are listed in `GAME_DESIGN.md` (player 2 keys, aim kept on turn, firearm holstered in the air).

## Working Notes

- The user writes in Turkish; code, comments, docs and commits are in English.
- Split each task into 4-5 atomic commits; push to `main` when done.
- Record architectural decisions in the `system-design` MCP, design id `fable` (6 steps so far; the user reviews them there).
- Verify gameplay changes visually: run the game non-headless with a capture script (`SceneTree` script that drives `Input.action_press` and saves `root.get_texture().get_image()`), then crop and zoom the PNG.
- In tests, the fighter reads a press one physics frame later; wait 2 frames before checking. Nodes added in `_initialize` get `_ready` only after the first frame, so read `fighter.controller` after an await.
- `test_case.gd` does not catch script errors: a crashing test can still print ALL PASSED. Grep the output for `SCRIPT ERROR`. Tests that load `main.tscn` also get the dummy at P2, which can absorb bullets.
- Not installed: an Aseprite MCP server (installation was blocked; the user said to skip it). Aseprite is used directly through its CLI.
