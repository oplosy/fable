# Game Design Requirements

Living list of agreed gameplay requirements. Add new items as they are decided; record open questions instead of guessing.

## Vision

- A desktop 2D action game inspired by the original Superfighters Flash game: its simple retro pixel-art look, with more polished combat mechanics and animation.
- The game is meant to be detailed: every interaction (who can hit whom, when a weapon drops, what a kick does to a jumping fighter) is thought through and written down here, not left to chance.

## Visual Direction

- Simple, chunky, readable pixel art like the original Superfighters; strict side-view camera.
- Small, stylized characters with clear silhouettes; limited palettes; simple industrial arenas.
- No 3D models, photorealistic textures, heavy shading or high-detail character art. Animation readability beats visual complexity.
- Pixels stay crisp: 640x360 internal resolution, integer scaling, nearest filtering. Characters are about 32 px tall, tiles are 16 px.
- `images/` holds Superfighters screenshots (`main-image.png` shows nearly everything) as a reference for look and feel only. All characters, animations and art are drawn from scratch in Aseprite.
- AI-generated art, if any, must match the style and be reviewed by the user before it goes in.

## Inventory Slots

Every fighter has four slots:

| # | Slot | Contents |
|---|------|----------|
| 1 | Melee | Bare hands (punch) by default; picked-up melee weapons such as knives and swords replace the punch. |
| 2 | Firearm | All firearm types. |
| 3 | Throwable | Grenades, molotovs and other throwables. |
| 4 | Power-up | Pickups found on the map: slow motion, speed boost, health regeneration, etc. |

## Firearm Handling and Aiming

- No mouse aiming and no separate aim mode or aim key.
- With the firearm slot active and the fighter standing still, the firearm is drawn in hand; pressing attack fires it.
- Left/right (A/D) always move the fighter. While moving, the firearm is put away and the run/walk animation plays; when the fighter stops, the firearm is drawn again because the firearm slot is still active. No firing while moving.
- A faces the fighter left, D faces it right.
- A vertical line through the fighter splits the space into a left and a right half-circle (180° each). The fighter aims within the half on the side it faces, from straight down to straight up.
- Up (W) rotates the aim upward gradually, down (S) rotates it downward gradually.

Example: the fighter walks, stops, the firearm appears in hand and attack fires it. Pressing A or D again puts the firearm away and the fighter runs; on stopping, the firearm is drawn again.

Current defaults (not yet confirmed by the user, easy to change):
- The aim angle is kept when turning around (mirrored into the new facing half).
- The firearm is also put away while airborne.

## Movement: Walk, Run, Jump, Dive, Roll

Built:
- Fighters walk by default. They run (speed up) either by double-tapping a direction (A A / D D) or while holding Shift.
- A walking jump goes straight up. A running jump is a forward dive, like diving head-first into a pool.
- Pressing down (S) while running rolls forward. S is free while running because the firearm is put away.

Current movement rules (prototype, easy to change):
- Speeds are per class (see Character Classes). A double tap counts when the second press comes within 0.25 s of the first; the run lasts while that direction is held.
- No steering or turning in the air: every jump, dive and jump kick keeps its takeoff momentum.
- The dive launches forward (Fast 260, Heavy 220 px/s), lower than a normal jump. No attacking during a dive; it ends on landing and the fighter slides to a stop. A hit cancels the dive.
- The roll lasts 0.4 s in the facing direction (Fast 235, Heavy 190 px/s). The fighter cannot be hit, act or draw the firearm while rolling.
- Dive and roll poses are placeholders (head-first rectangle, squashed rectangle) until animations exist.

## Controls

Player 1 (defaults): A/D move, Left Shift run, W/S aim (S rolls while running), K jump, J attack (J + K together breaks a combo), 1-4 select slot (empty slots cannot be selected). Each local player gets its own `pN_` action set.

Player 2 (defaults): Left/Right arrows move, Right Shift run, Up/Down arrows aim, / jump, . (Period) attack, 7-0 select slot.

- Jump always uses the jump key, in every state; aim up never jumps.
- Built: Esc opens a Controls menu (the game pauses) where every player rebinds their own keys: click a binding, press the new key (Esc cancels). Taking a key that another action uses swaps the two, so no action is left unbound. Bindings are saved to `user://keybindings.cfg`; "Reset to defaults" restores the list above. Escape cannot be bound.

## Weapon Pickups

Built:
- Only weapons spawned by the game can be picked up. Weapons dropped by fighters (disarmed or swapped out) can never be picked up; they disappear after a few seconds (5 s).
- Each arena defines fixed weapon spawn points. An empty spawn point spawns a weapon at an interval (about 10 s).
- With an empty firearm slot, walking over a spawned firearm picks it up automatically.
- With a full firearm slot, the fighter stands on the weapon and presses S once to swap: the new weapon is equipped and the old one drops (and cannot be picked up).
- Fighters start the match with a pistol (user decision).

Current pickup rules (prototype, easy to change):
- Spawn points are `WeaponSpawner` nodes under the arena's `WeaponSpawns`; each lists the weapons it can spawn (one picked at random) and its interval. The test arena has one pistol spawn point near the left wall.
- The interval starts counting once the point is empty, so the first weapon appears 10 s into the match.
- Pickup and swap need a fighter that can act (not stunned, downed, attacking, rolling or diving); the swap also needs the floor and not running (S while running rolls). Pickup range is the fighter's body overlapping the weapon.

## Character Classes and Melee

- Characters belong to classes that change how they fight; a character's look and its class are separate data.
- Each class has its own melee combo, a fixed chain of attacks. After the last attack of the chain there is a pause before the fighter can attack again, so melee is never unlimited.
- Examples: fast classes chain 4 punches; big classes chain punch, punch, kick.
- Classes also differ in stats: walk and run speed, jump height, dive and roll, health (built; all in `FighterClass`).
  Prototype values (not yet tuned): Fast 90 health, walk 130, run 215 px/s, normal jump; Heavy 130 health, walk 100, run 170 px/s, lower jump and shorter dive and roll.

Built:
- **Knockdown**: a knocked-down fighter lies on the ground for 1-1.5 s (1.25 s by default, per class), then gets up.
- **Air attacks**: no punching in the air; attack while airborne is the class's jump kick, once per jump (landing restores it). A jump kick that lands knocks the target down. The kick hits forward at foot level and keeps the jump's momentum.
- **Combo finishers**: the last attack of every class combo (Fast's hook, Heavy's kick) knocks the target down. Single punches do not.
- **Disarming**: a single punch never disarms. A knocked-down fighter drops its firearm (full combo or jump kick) into the arena.
- **Defence**: no blocking; rolling (see Movement) is the only defence.
- **Combo breaker**: while being hit in a combo, pressing attack + jump together breaks free and pushes the attacker back slightly. It then has a long cooldown (around 10 s).

Current combo breaker rules (prototype, easy to change):
- It works only while stunned by a melee hit; bullet stuns and knockdowns (combo finishers, jump kicks) cannot be broken.
- "Together" means one key goes down while the other is held, in either order. The press is used up: the fighter neither jumps nor attacks on that frame.
- The attacker takes no damage: its combo is cancelled, it is pushed back at 160 px/s (about 12 px) and stunned for 0.3 s.
- Cooldown 10 s, push and stun are per-class settings in `FighterClass`.

Current melee rules (prototype, easy to change):
- Attack in the melee slot starts the class combo; pressing attack again during an attack queues the next one.
- The pause after a combo scales with how far it got (full combo = full pause), so short chains cannot be spammed.
- Prototype classes: Fast (jab, jab, jab, hook; 0.6 s pause) and Heavy (punch, punch, kick; 0.8 s pause). Player 1 is Fast, player 2 is Heavy.
- Each attack has wind-up, active and recovery time; it hits each target at most once, only during its active time.
- Movement input is ignored on the ground while attacking; the fighter keeps facing the same way.
- Getting hit cancels the current attack and the combo.
- A melee hit stuns long enough for the next attack in the combo to connect.

- **Downed fighters**: cannot be hit while lying down, and are briefly invulnerable while getting up; projectiles pass over them. This is a per-class setting so it can be revisited; allowing hits on the ground would also need a rule against re-knocking-down (endless knockdown loops).

## Damage and Hit Reactions

- Fighters have health (per class: Fast 90, Heavy 130); weapons define damage and knockback.
- A hit flashes the fighter, pushes it along the hit direction and stuns it briefly (0.25 s): no moving, jumping, aiming or firing.
- At zero health the fighter dies: the body stays on the map lying down, ignores input, and projectiles pass through it.
- A fighter's own projectiles never hit it.

Prototype values (not yet tuned or confirmed): pistol 10 damage and 100 px/s knockback, 0.25 s stun.

## Players and Modes

- Multiplayer is a core requirement.
- A versus-computer mode (bots) is also required.
- Multiplayer is both local (several players on one machine) and online.
- Implication: fighters must not read `Input` directly; a controller (local player, bot, remote player) drives each fighter, and local players need separate key bindings.

## Maps

- Maps are classified as small, medium or large. Example designs will be discussed later.
- Players will be able to import their own maps from outside the game. Format and tooling to be discussed later.
- Implication: imported maps must not run arbitrary code; a data-only map format (no scripts) is required for user content.

## Current Prototype Deviations

- Melee uses bare hands only; melee weapons, throwables and power-ups are not implemented yet.
- The punch is shown as a placeholder box over the hit area until attack animations exist.
- The main scene spawns two local players (P1 Fast, P2 Heavy, both with a pistol) and respawns a dead player after 1.5 s; this is a testing aid until rounds and a match flow exist.
- Death and knockdown are placeholders (the rectangle rotates); the real animations come with sprites.
