# Progress and Handoff

Where development stands and what comes next. Update this at the end of every working session. Gameplay rules live in [GAME_DESIGN.md](GAME_DESIGN.md); this file tracks what is built.

## Status (2026-10-27, session 2)

Branch `main` (movement package, combo breaker, per-class stats, weapon pickups, key rebinding, review fixes, ammo, spread, crouching, shotgun, SMG, sniper, knife, bat, grenade and molotov done this session), pushed to https://github.com/oplosy/fable. All 14 headless test suites pass. Placeholder art only (colored rectangles); only menu is the Esc controls menu; no maps, bots or networking yet.

## Built So Far

| Area | What works | Main files |
|------|------------|------------|
| Project setup | Godot 4.7.2, 640x360 viewport scaled x2 to 1280x720, integer scaling, nearest filter, pixel snap. Physics layers: 1 world, 2 fighters, 3 projectiles, 4 pickups. | `project.godot` |
| Arena | Test arena: floor, side walls, `SpawnPoints` (P1, P2), `ItemSpawns` (one spawner with every built firearm and melee item), fixed `Camera2D`. | `scenes/arenas/test_arena.tscn` |
| Main scene | Loads the arena, spawns local players from its `characters` list (P1 Fast on `p1_*`, P2 Heavy on `p2_*`), each with the pistol, and respawns a dead player after 1.5 s. Adds the controls menu. | `scenes/main.gd` |
| Fighter | One shared `CharacterBody2D`: walk, run, jump (K), facing, 4 slots (melee, firearm, throwable, power-up; the first three can hold something). | `scenes/fighter/fighter.gd` |
| Controllers | Fighters never read `Input`; a `FighterController` provides intent (move, run, aim, down, jump, attack, slot). `LocalController` reads `p1_*` actions and turns Shift or a double tap into the run intent. The base controller is idle (used in tests). | `scenes/fighter/controllers/` |
| Firearm | Drawn only when standing still on the floor in the firearm slot; A/D holster it. W/S rotate aim within the facing 180°. Attack fires along the aim, deviated within the weapon's spread (plus bloom on held fire, narrower when crouched). Limited ammo; the empty weapon drops itself. Pistol, shotgun (pellets, short range, point-blank knockdown), SMG (automatic, bloom), sniper (piercing). Projectiles are ray-traced each frame (no tunneling). | `scenes/weapons/`, `scenes/projectiles/projectile.gd`, `data/weapons/` |
| Health and hits | `Health` component; `take_hit(damage, knockback, stun, knocks_down)`; hit flash, knockback, stun. Dead bodies lie down and leave the fighters layer. | `scenes/components/health.gd` |
| Classes and melee | `FighterClass` resources hold the melee combo (`MeleeAttack` resources), combo cooldown, jump kick and knockdown settings. Fast: jab x3 + hook. Heavy: punch x2 + kick. Hits use a physics shape query, once per target per attack. | `scenes/fighter/melee.gd`, `data/classes/` |
| Melee items | Knife and baseball bat (`MeleeItemData`, sharing `ItemData` with `WeaponData`) fill the melee slot; their combo replaces the class punches. Each landed combo hit wears the item; when worn out it breaks after the current combo. Dead fighters drop it. | `melee.gd`, `fighter.gd`, `data/weapons/knife.tres`, `bat.tres` |
| Knockdown | Combo finishers and the jump kick knock down for 1.25 s. Downed fighters cannot be hit (per-class `downed_invulnerable`), plus 0.4 s invulnerability after getting up. Knockdown drops the firearm into the arena. | `fighter.gd`, `scenes/weapons/item_pickup.gd` |
| Jump kick | No punches in the air; attack while airborne is the class jump kick, once per jump, hitting forward at foot level. | `melee.gd`, `data/classes/*.tres` |
| Combo breaker | While melee-stunned, attack + jump together ends the stun and pushes the attacker back (no damage, 0.3 s stun). 10 s cooldown; settings in `FighterClass`. Melee passes the attacker to `take_hit`. | `fighter.gd`, `local_controller.gd`, `fighter_class.gd` |
| Movement | Walk/run speeds; walking jump straight up, running jump is a forward dive; S while running rolls (invulnerable). Crouch key: slow walk, half-height body. No air steering. Speeds and health come from `FighterClass`; Fast and Heavy differ. | `fighter.gd`, `local_controller.gd` |
| Weapon pickups | `ItemSpawner` points spawn pickable firearms and melee items every 10 s while empty, picked by each item's `spawn_weight`. Empty slot: walk over to take; full slot: S on the item swaps and drops the old one. Fighter-dropped weapons are never pickable and vanish after 5 s. | `scenes/weapons/item_spawner.gd`, `item_pickup.gd`, `fighter.gd` |
| Throwables | Slot 3 holds a counted `ThrowableData` (grenade x3 at start, molotov x2 from spawns). `Thrower` runs pin, fuse and throw; `ThrownItem` flies and goes off by fuse or on impact; `Explosion` and `FireArea` hurt everyone in range, thrower included. | `scenes/fighter/thrower.gd`, `scenes/throwables/`, `data/throwables/` |
| Controls | Default `p1_*` and `p2_*` actions (P2 on arrows, Right Shift, / and .). `KeyBindings` saves per-player rebinds to `user://keybindings.cfg` (swap on conflict); Esc opens `SettingsMenu`, which pauses the game. | `scenes/ui/`, `project.godot` |
| Art pipeline | Aseprite CLI with Lua scripts; first sprite: pistol (9x5). | `art/weapons/pistol.aseprite` → `assets/weapons/pistol.png` |

Tests (`tests/`): `test_health`, `test_fighter`, `test_combat`, `test_main`, `test_melee`, `test_knockdown`, `test_movement`, `test_combo_breaker`, `test_pickup`, `test_key_bindings`, `test_firearm`, `test_weapons`, `test_melee_items`, `test_throwables`, all on the `test_case.gd` base (30 s watchdog). How to run them: see `CLAUDE.md` → Running Tests.

## Next Steps

1. Build the agreed content (GAME_DESIGN.md → Content List); ammo, spread, bloom, crouching, shotgun, SMG, sniper, knife, bat, grenade and molotov are done. Remaining content (revolver, machine gun, bazooka, flamethrower; pipe, machete, sledgehammer; mine, C4) has no agreed order yet.
2. Later (order not agreed yet): game modes (capture the flag, deathmatch; score, time or 3-life endings), HUD, sprites and animation states, bots (versus-computer), online play, maps (small/medium/large), user map import (data-only format).

Open questions for the user are listed in `GAME_DESIGN.md` (aim kept on turn, firearm holstered in the air, mode rules).

## Known Bugs

None open. The five bugs found in the session 2 review are fixed and covered by tests: melee trades, single-jab stunlock, firearm kept on death, stacking knockback, respawn during pause.

Risks for later content (from code): wake-up combo loops after knockdown; no spawn protection; keyboard ghosting with two players; no input buffering; S on a spawned weapon swaps even when the player meant to aim down.

## Working Notes

- The user writes in Turkish; code, comments, docs and commits are in English.
- Split each task into 4-5 atomic commits; push to `main` when done.
- Record architectural decisions in the `system-design` MCP, design id `fable` (12 steps so far; the user reviews them there).
- Verify gameplay changes visually: run the game non-headless with a capture script (`SceneTree` script that drives `Input.action_press` and saves `root.get_texture().get_image()`), then crop and zoom the PNG.
- In tests, the fighter reads a press one physics frame later; wait 2 frames before checking. Nodes added in `_initialize` get `_ready` only after the first frame, so read `fighter.controller` after an await.
- `test_case.gd` registers a `Logger`, so any engine or script error fails the suite. Run everything with `tests/run_all.sh` (fixed 60 fps, ~11 s). Tests that load `main.tscn` also get player 2 at the second spawn point, which can absorb bullets.
- Not installed: an Aseprite MCP server (installation was blocked; the user said to skip it). Aseprite is used directly through its CLI.
