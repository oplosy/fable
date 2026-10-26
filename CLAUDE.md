# Game Design

Agreed gameplay requirements and open questions live in @docs/GAME_DESIGN.md. Read it before designing a feature and add new requirements there as the user states them.

# Architecture: Content Extensibility

New maps, character designs and weapons will be added often, so adding content must not require changes to core scripts.

- **Maps**: each arena is a self-contained scene under `scenes/arenas/` that owns its geometry, `SpawnPoints` and `Camera2D`. The main scene only loads an arena. Detailed map work is deferred; only the test arena exists for now.
- **Characters**: one shared `Fighter` scene; a character is a `CharacterData` resource under `data/characters/` (its look) that points to a `FighterClass` resource under `data/classes/` (how it fights: melee combo, later class stats).
- **Weapons**: one shared `Weapon` scene; a weapon is a `WeaponData` resource under `data/weapons/` plus its sprite. Weapons are separate sprites attached to the fighter's hand, never baked into character frames.
- Prefer a new resource or scene over a new code branch when adding content.

# Running Tests

Godot is not on PATH; the binary is `C:\Users\mesut\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`.

- Reimport after adding scripts or assets: `<godot> --headless --path . --import`
- Run each suite: `<godot> --headless --path . -s res://tests/<test_name>.gd` (exit code 0 = pass). Suites extend `tests/test_case.gd`.

# Commit Conventions

- Split work that would normally fit in a single commit into 4-5 small, logically separate commits.
- Each commit must be atomic: one concern per commit (e.g. scaffolding, core logic, tests, docs, config), and the project should build and pass checks after every commit.
- Follow the global message rules: imperative mood, subject under 72 characters.
