# Game Design Requirements

Living list of agreed gameplay requirements. Add new items as they are decided; record open questions instead of guessing.

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

Decided, not built yet:
- Fighters walk by default. They run (speed up) either by double-tapping a direction (A A / D D) or while holding Shift.
- A walking jump goes straight up. A running jump is a forward dive, like diving head-first into a pool.
- Pressing down (S) while running rolls forward. S is free while running because the firearm is put away.

## Controls

Player 1: A/D move, W/S aim, K jump, J attack, 1-4 select slot (empty slots cannot be selected). Each local player gets its own `pN_` action set.

- Jump stays on K in every state; W never jumps.
- Open: player 2 key layout on a shared keyboard.

## Character Classes and Melee

- Characters belong to classes that change how they fight; a character's look and its class are separate data.
- Each class has its own melee combo, a fixed chain of attacks. After the last attack of the chain there is a pause before the fighter can attack again, so melee is never unlimited.
- Examples: fast classes chain 4 punches; big classes chain punch, punch, kick.
- Classes also differ in stats: run speed, jump height, health.

Built:
- **Knockdown**: a knocked-down fighter lies on the ground for 1-1.5 s (1.25 s by default, per class), then gets up.
- **Air attacks**: no punching in the air; attack while airborne is the class's jump kick, once per jump (landing restores it). A jump kick that lands knocks the target down. The kick hits forward at foot level and keeps the jump's momentum.
- **Combo finishers**: the last attack of every class combo (Fast's hook, Heavy's kick) knocks the target down. Single punches do not.
- **Disarming**: a single punch never disarms. A knocked-down fighter drops its firearm (full combo or jump kick) into the arena.

Decided, not built yet:
- **Defence**: no blocking; rolling (see Movement).
- **Combo breaker**: while being hit in a combo, pressing attack + jump together breaks free and pushes the attacker back slightly. It then has a long cooldown (around 10 s).

Current melee rules (prototype, easy to change):
- Attack in the melee slot starts the class combo; pressing attack again during an attack queues the next one.
- The pause after a combo scales with how far it got (full combo = full pause), so short chains cannot be spammed.
- Prototype classes: Fast (jab, jab, jab, hook; 0.6 s pause) and Heavy (punch, punch, kick; 0.8 s pause). The player is Fast, the dummy is Heavy.
- Each attack has wind-up, active and recovery time; it hits each target at most once, only during its active time.
- Movement input is ignored on the ground while attacking; the fighter keeps facing the same way.
- Getting hit cancels the current attack and the combo.
- A melee hit stuns long enough for the next attack in the combo to connect.

- **Downed fighters**: cannot be hit while lying down, and are briefly invulnerable while getting up; projectiles pass over them. This is a per-class setting so it can be revisited; allowing hits on the ground would also need a rule against re-knocking-down (endless knockdown loops).

## Damage and Hit Reactions

- Fighters have health (100 by default); weapons define damage and knockback.
- A hit flashes the fighter, pushes it along the hit direction and stuns it briefly (0.25 s): no moving, jumping, aiming or firing.
- At zero health the fighter dies: the body stays on the map lying down, ignores input, and projectiles pass through it.
- A fighter's own projectiles never hit it.

Prototype values (not yet tuned or confirmed): 100 health, pistol 10 damage and 100 px/s knockback, 0.25 s stun.

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

- The pistol is equipped at spawn until weapon pickups exist.
- Melee uses bare hands only; melee weapons, throwables and power-ups are not implemented yet.
- The punch is shown as a placeholder box over the hit area until attack animations exist.
- The main scene spawns an idle target dummy that respawns 1.5 s after dying; it is a testing aid, not a game mode.
- Death and knockdown are placeholders (the rectangle rotates); the real animations come with sprites.
- Dropped firearms cannot be picked up yet; pickups come later.
