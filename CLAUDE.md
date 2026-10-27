# Game Design

Agreed gameplay requirements and open questions live in @docs/GAME_DESIGN.md. Read it before designing a feature and add new requirements there as the user states them.

What is built and what comes next is tracked in @docs/PROGRESS.md. Read it at the start of a session and update it at the end.

# Architecture: Content Extensibility

New maps, character designs and weapons will be added often, so adding content must not require changes to core scripts.

- **Maps**: each arena is a self-contained scene under `scenes/arenas/` that owns its geometry, `SpawnPoints`, `WeaponSpawns` (`WeaponSpawner` nodes) and `Camera2D`. The main scene only loads an arena. Detailed map work is deferred; only the test arena exists for now.
- **Characters**: one shared `Fighter` scene; a character is a `CharacterData` resource under `data/characters/` (its look) that points to a `FighterClass` resource under `data/classes/` (how it fights: melee combo, later class stats).
- **Weapons**: one shared `Weapon` scene; a weapon is a `WeaponData` resource under `data/weapons/` plus its sprite. Weapons are separate sprites attached to the fighter's hand, never baked into character frames.
- Prefer a new resource or scene over a new code branch when adding content.

# Architecture: Code Rules

- Small, focused scenes and scripts. Movement, combat, weapons, health and animation stay separate.
- Damage and hit detection never depend on sprite art (collision shapes and shape queries only).
- Fighters never read `Input`; a controller (local, bot, remote) provides their intent.
- Use signals where they simplify communication; avoid unnecessary abstractions and dependencies. Use Godot's native 2D physics and animation.
- Build one milestone at a time, run the checks after each one, and do not add features that were not requested.

# Art Pipeline

- Sources are `.aseprite` files under `art/`, exported to PNG under `assets/` with the Aseprite CLI (`C:\Program Files\Aseprite\Aseprite.exe -b ... --script file.lua`).
- `images/` holds reference screenshots only; it is excluded from Godot import (`.gdignore`), as is `art/`.

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
