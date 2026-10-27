# Progress and Handoff

Where development stands and what comes next. Update this at the end of every working session. Gameplay rules live in [GAME_DESIGN.md](GAME_DESIGN.md); this file tracks what is built.

## Status (2026-10-27, session 3)

Branch `main`, pushed to https://github.com/oplosy/fable. Session 3 was a code audit and cleanup: stuns no longer cut each other short, per-weapon hit stun (SMG no longer stunlocks), no hit lands through walls, falling out of the arena kills, `Inventory` split out of `Fighter`, items renamed from "weapon" to "item", one `Fighter.state()` for animations, per-character body size, a seedable match rng, and a 12x faster test runner that fails on script errors. Then a 1920x1080 render with a follow camera for large maps and 1/3-scale character art. Then kill credit for game modes, and the user's 3x item art for the 8 built items. All 20 headless test suites pass. Placeholder art only (colored rectangles); only menu is the Esc controls menu; no maps, bots or networking yet.

## Built So Far

| Area | What works | Main files |
|------|------------|------------|
| Project setup | Godot 4.7.2, 1920x1080 viewport (fullscreen), integer scaling while the window holds it and fractional below (`main.gd`), nearest filter, pixel snap. The Esc menu is laid out for 640x360 and drawn 3x. Physics layers: 1 world, 2 fighters, 3 projectiles, 4 pickups. | `project.godot` |
| Arena | Every arena root is an `Arena` (`scenes/arenas/arena.gd`): `bounds` (leaving them kills fighters and removes items) and the match `rng` and `camera_limits`. Test arena: floor, side walls, `SpawnPoints` (P1, P2), `ItemSpawns` (one spawner with every built firearm and melee item), `FollowCamera`. | `scenes/arenas/test_arena.tscn` |
| Camera | `FollowCamera`: follows the living fighters (group `Fighter.GROUP`) with one zoom: 3 (art pixel = screen pixel) down to the whole map, never below 0.75 (`MIN_ZOOM`); maps are at most 2560x1440 (`MAX_MAP_SIZE`), enforced by `Arena` and `test_arenas`; fast out, calm in with a 10% threshold, log-space easing; clamped to `camera_limits`. Arenas draw with linear filtering and mipmaps. | `scenes/arenas/follow_camera.gd`, `arena.gd` |
| Main scene | Loads the arena, spawns local players from its `characters` list (P1 Fast on `p1_*`, P2 Heavy on `p2_*`), each with the pistol and 3 grenades, and respawns a dead player after 1.5 s. Adds the controls menu. | `scenes/main.gd` |
| Fighter | One shared `CharacterBody2D`: walk, run, jump (K), facing. Its `Inventory` component holds the 4 slots (melee, firearm, throwable, power-up; the first three can hold something), picks spawned items up and drops items. | `scenes/fighter/fighter.gd`, `scenes/fighter/inventory.gd` |
| Controllers | Fighters never read `Input`; a `FighterController` provides intent (move, run, aim, down, jump, attack, slot). `LocalController` reads `p1_*` actions and turns Shift or a double tap into the run intent. The base controller is idle (used in tests). | `scenes/fighter/controllers/` |
| Firearm | Drawn only when standing still on the floor in the firearm slot; A/D holster it. W/S rotate aim within the facing 180°. Attack fires along the aim, deviated within the weapon's spread (plus bloom on held fire, narrower when crouched). Limited ammo; the empty weapon drops itself. Pistol, shotgun (pellets, short range, point-blank knockdown), SMG (automatic, bloom), sniper (piercing). Projectiles are ray-traced each frame (no tunneling). | `scenes/weapons/`, `scenes/projectiles/projectile.gd`, `data/weapons/` |
| Health and hits | `Health` component; `take_hit(damage, knockback, stun, knocks_down, attacker, by_melee)`; hit flash, knockback, stun. Kill credit: `Fighter.died(killer)` names the last attacker within 5 s (falls included), the fighter itself for a self-kill, or null. Dead bodies lie down and leave the fighters layer. | `scenes/components/health.gd` |
| Classes and melee | `FighterClass` resources hold the melee combo (`MeleeAttack` resources), combo cooldown, jump kick and knockdown settings. Fast: jab x3 + hook. Heavy: punch x2 + kick. Hits use a physics shape query, once per target per attack. | `scenes/fighter/melee.gd`, `data/classes/` |
| Melee items | Knife and baseball bat (`MeleeItemData`, sharing `ItemData` with `WeaponData`) fill the melee slot; their combo replaces the class punches. Each landed combo hit wears the item; when worn out it breaks after the current combo. Dead fighters drop it. | `melee.gd`, `fighter.gd`, `data/weapons/knife.tres`, `bat.tres` |
| Knockdown | Combo finishers and the jump kick knock down for 1.25 s. Downed fighters cannot be hit (per-class `downed_invulnerable`), plus 0.4 s invulnerability after getting up. Knockdown drops the firearm into the arena. | `fighter.gd`, `scenes/weapons/item_pickup.gd` |
| Jump kick | No punches in the air; attack while airborne is the class jump kick, once per jump, hitting forward at foot level. | `melee.gd`, `data/classes/*.tres` |
| Combo breaker | While melee-stunned, attack + jump together ends the stun and pushes the attacker back (no damage, 0.3 s stun). 10 s cooldown; settings in `FighterClass`. Melee passes the attacker to `take_hit`. | `fighter.gd`, `local_controller.gd`, `fighter_class.gd` |
| Movement | Walk/run speeds; walking jump straight up, running jump is a forward dive; S while running rolls (invulnerable). Crouch key: slow walk, half-height body. No air steering. Speeds and health come from `FighterClass`; Fast and Heavy differ. | `fighter.gd`, `local_controller.gd` |
| Weapon pickups | `ItemSpawner` points spawn pickable firearms and melee items every 10 s while empty, picked by each item's `spawn_weight`. Empty slot: walk over to take; full slot: S on the item swaps and drops the old one. Fighter-dropped weapons are never pickable and vanish after 5 s. | `scenes/weapons/item_spawner.gd`, `item_pickup.gd`, `fighter.gd` |
| Throwables | Slot 3 holds a counted `ThrowableData` (grenade x3 at start, molotov x2 from spawns). `Thrower` runs pin, fuse and throw; `ThrownItem` flies and goes off by fuse or on impact; `Explosion` and `FireArea` hurt everyone in range, thrower included. | `scenes/fighter/thrower.gd`, `scenes/throwables/`, `data/throwables/` |
| Controls | Default `p1_*` and `p2_*` actions (P2 on arrows, Right Shift, / and .). `KeyBindings` saves per-player rebinds to `user://keybindings.cfg` (swap on conflict); Esc opens `SettingsMenu`, which pauses the game. | `scenes/ui/`, `project.godot` |
| Art pipeline | The user draws the art. Item sprites are the user's 3x "ideal" set from `weapons/` (untracked working folder), copied to `assets/` for the 8 built items; `ItemData.pixels_per_unit` 3 draws them at 1/3 scale, and `ItemData.show_on` sets every item sprite (held, pickup, thrown). Grip and muzzle pixels were read off the art. The user's 64x96 character designs are in `characters/`; `docs/CHARACTER_ANIMATION_SPEC.md` is the brief for cutting them into rig parts and making every animation as keyframe data (the user forwards it to their art AI). `CharacterRig` builds a character from its `rig.json` and part PNGs (joint nodes parented joint to joint, drawn at 1/3 scale); `CharacterData.rig_file` points to it. Character 01 (Trench Coat Agent, `data/characters/trenchcoat_agent.tres`, Fast class) is rigged and is player 1; its parts were copied to `assets/characters/trenchcoat_agent/`. Animations are not wired yet; setting `CharacterData.texture` (plus `feet`) draws a standing frame at 1/3 scale instead of the placeholder box; animations are not wired yet. | `weapons/` → `assets/` |

Tests (`tests/`): `test_health`, `test_fighter`, `test_combat`, `test_main`, `test_melee`, `test_knockdown`, `test_movement`, `test_combo_breaker`, `test_pickup`, `test_key_bindings`, `test_firearm`, `test_weapons`, `test_melee_items`, `test_throwables`, `test_walls`, `test_bounds`, `test_state`, `test_camera`, `test_kill_credit`, `test_arenas` (every arena scene follows the map rules), all on the `test_case.gd` base (30 s watchdog, fails on any script error). How to run them: see `CLAUDE.md` → Running Tests.

## Next Steps

1. Build the agreed content (GAME_DESIGN.md → Content List); ammo, spread, bloom, crouching, shotgun, SMG, sniper, knife, bat, grenade and molotov are done. Remaining content (revolver, machine gun, bazooka, flamethrower; pipe, machete, sledgehammer; mine, C4) has no agreed order yet.
2. Later (order not agreed yet): game modes (first five agreed in GAME_DESIGN: capture the flag, deathmatch to 20, zone control to 1000, hostage rescue, bomb; kill credit is built, a mode/score layer is next), HUD, sprites and animation states, bots (versus-computer), online play, maps (small/medium/large), user map import (data-only format).

Open questions for the user are listed in `GAME_DESIGN.md` (aim kept on turn, firearm holstered in the air, mode rules).

## Known Bugs

None open. The five bugs found in the session 2 review are fixed and covered by tests: melee trades, single-jab stunlock, firearm kept on death, stacking knockback, respawn during pause.

Risks for later content (from code): wake-up combo loops after knockdown; no spawn protection; keyboard ghosting with two players; no input buffering; S on a spawned weapon swaps even when the player meant to aim down.

## Working Notes

- The user writes in Turkish; code, comments, docs and commits are in English.
- Split each task into 4-5 atomic commits; push to `main` when done.
- Record architectural decisions in the `system-design` MCP, design id `fable` (19 steps so far; the user reviews them there).
- Verify gameplay changes visually: run the game non-headless with a capture script (`SceneTree` script that drives `Input.action_press` and saves `root.get_texture().get_image()`), then crop and zoom the PNG.
- In tests, the fighter reads a press one physics frame later; wait 2 frames before checking. Nodes added in `_initialize` get `_ready` only after the first frame, so read `fighter.controller` after an await.
- `test_case.gd` registers a `Logger`, so any engine or script error fails the suite. Run everything with `tests/run_all.sh` (fixed 60 fps, ~11 s). Tests that load `main.tscn` also get player 2 at the second spawn point, which can absorb bullets.
- Not installed: an Aseprite MCP server (installation was blocked; the user said to skip it). Aseprite is used directly through its CLI.
