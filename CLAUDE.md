# Game Design

Agreed gameplay requirements and open questions live in @docs/GAME_DESIGN.md. Read it before designing a feature and add new requirements there as the user states them.

What is built and what comes next is tracked in @docs/PROGRESS.md. Read it at the start of a session and update it at the end.

# Architecture: Content Extensibility

New maps, character designs and weapons will be added often, so adding content must not require changes to core scripts.

- **Maps**: each arena is a self-contained scene under `scenes/arenas/` that owns its geometry, `SpawnPoints`, `ItemSpawns` (`ItemSpawner` nodes) and `Camera2D`. The main scene only loads an arena. A map's `camera_limits` are exactly 640x360, 1280x720 or 2560x1440 (the view at a camera zoom), and the map maker places `CameraShot` nodes (composed views at zoom 3, 1.5 or 0.75) that the camera cuts between; `test_arenas` checks every arena scene. The game loads the Shipyard (`shipyard.tscn`, the user's reference art as background with collision built by `tools/make_shipyard_arena.py`); the Range (`range.tscn`, a flat floor with measuring lines every 8 px) stays for movement tuning and the test arena for tests. Map props (`Ladder`, barrels) are scenes under `scenes/props/` drawn as flat boxes (`Ladder.placeholder` off where the map art already draws the ladder); one-way platforms are static bodies (or tiles) with one-way collision.
- **Bots**: a map needs no bot setup. `WalkMap` scans each arena's collision and ladders into surfaces and links, and `BotController` plays on it; `Main.bot_players` (in `main.tscn`, player 2 by default) says who is a bot. Empty it for two humans.
- **Characters**: one shared `Fighter` scene; a character is a `CharacterData` resource under `data/characters/` (its placeholder colour, body and optional `rig_file`) that points to a `FighterClass` resource under `data/classes/` (how it fights: melee combo, later class stats). Characters with a `rig_file` build a 2D cutout `CharacterRig` driven by `RigAnimator` keyframe clips under `assets/animations/`. Held items anchor to `CharacterRig.hand_anchor`.
- **Weapons**: one shared `Weapon` scene; a weapon is a `WeaponData` resource under `data/weapons/` pointing to its sprite under `assets/weapons/`.
- Prefer a new resource or scene over a new code branch when adding content.

# Architecture: Code Rules

- Small, focused scenes and scripts. Movement, combat, weapons, health and animation stay separate.
- Damage and hit detection never depend on sprite art (collision shapes and shape queries only).
- Fighters never read `Input`; a controller (local, bot, remote) provides their intent.
- Use signals where they simplify communication; avoid unnecessary abstractions and dependencies. Use Godot's native 2D physics and animation.
- Build one milestone at a time, run the checks after each one, and do not add features that were not requested.
- Production and animation generation scripts live under `tools/`.

# Art

- **DONT-OPEN/** (user, session 5) holds everything set aside: reference art, drawing folders (`DONT-OPEN/characters/`, `DONT-OPEN/weapons/`, git-ignored). Godot ignores it (`.gdignore`). Never open, read, use or change anything in it unless the user asks.
- **Active Art (session 10)**: `assets/characters/ronin/` holds the 17-part cutout rig for Ronin Street Samurai; `assets/animations/` holds JSON keyframe clips; `assets/weapons/` holds pixel art for weapons and throwables. Placeholder characters (`placeholder.tres`, `dummy.tres`) continue to use `ColorRect` boxes and fallback placeholder poses.

# Running Tests

Godot is not on PATH; the binary is `C:\Users\mesut\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`.

- Reimport after adding scripts or assets: `<godot> --headless --path . --import`
- Run every suite (Git Bash): `tests/run_all.sh`; one or more: `tests/run_all.sh test_melee test_pickup`. Exit code 0 = all passed.
- A single suite by hand: `<godot> --headless --fixed-fps 60 --path . -s res://tests/<test_name>.gd`. `--fixed-fps 60` runs physics as fast as possible instead of in real time (about 12x faster).
- Suites extend `tests/test_case.gd`, which fails the suite on any engine or script error, not only on failed checks.

# Commit Conventions

- Split work that would normally fit in a single commit into 4-5 small, logically separate commits.
- Each commit must be atomic: one concern per commit (e.g. scaffolding, core logic, tests, docs, config), and the project should build and pass checks after every commit.
- Follow the global message rules: imperative mood, subject under 72 characters.
