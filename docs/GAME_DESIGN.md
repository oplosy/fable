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

## Controls

Player 1: A/D move, W/S aim, K jump, J attack. Each local player gets its own `pN_` action set.

- Open: jump is on K because W aims. Should W jump when no firearm is drawn, as in Superfighters?
- Open: player 2 key layout on a shared keyboard.

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
- Only the firearm slot behaves; melee, throwable and power-up slots and slot switching are not implemented yet.
