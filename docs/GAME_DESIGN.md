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

## Firearm Aiming

- No mouse aiming.
- While aiming a firearm the fighter cannot move; the movement keys aim the weapon instead.
- Up (W) rotates the aim upward gradually, down (S) rotates it downward gradually.
- Open: does aiming start whenever the firearm slot is active, or only while an aim key is held (as in Superfighters)? What do left/right do while aiming (turn around)?

## Players and Modes

- Multiplayer is a core requirement.
- A versus-computer mode (bots) is also required.
- Implication: fighters must not read `Input` directly; a controller (local player, bot, remote player) drives each fighter.
- Open: local multiplayer on one machine, online, or both?

## Maps

- Maps are classified as small, medium or large. Example designs will be discussed later.
- Players will be able to import their own maps from outside the game. Format and tooling to be discussed later.
- Implication: imported maps must not run arbitrary code; a data-only map format (no scripts) is required for user content.

## Current Prototype Deviations

- The pistol currently fires horizontally while moving and is equipped at spawn; both change once slots and aiming are implemented.
