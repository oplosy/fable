# Game Design Requirements

Living list of agreed gameplay requirements. Add new items as they are decided; record open questions instead of guessing.

## Vision

- A desktop 2D action game inspired by the original Superfighters Flash game: its simple retro pixel-art look, with more polished combat mechanics and animation.
- The game is meant to be detailed: every interaction (who can hit whom, when a weapon drops, what a kick does to a jumping fighter) is thought through and written down here, not left to chance.

## Visual Direction

- Readable pixel art; side-view camera. Characters do not have to be drawn in strict profile: a 3/4 standing pose is fine (user decision, session 3).
- Stylized characters with clear silhouettes; limited palettes; simple industrial arenas.
- The user's detailed 64x96 character designs (`characters/`, 1 px outline, cel shading, 5 body-part layers) set the character look. No 3D models or photorealistic textures. Animation readability beats visual complexity.
- Characters must stay small relative to the map: maps are large and characters never look huge in them (user requirement, session 3).
- Pixels stay crisp: integer scaling, nearest filtering. Built today: 640x360 internal resolution, 12x28 fighter hitbox, 16 px tiles.
- Open: how the 64x96 art meets the 640x360 world. Proposed: keep world units, render at 1920x1080 with a 3x camera zoom and draw characters at 1/3 scale (86 px art ≈ 29 world px ≈ the hitbox); weapons, items and tiles are then redrawn at the same 3x detail. Undecided: whether the camera may zoom out on large maps (zooming out below 1:1 blurs the detailed art).
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

- With the firearm slot active, attack in the air does nothing: no shot and no jump kick (user decision). The jump kick needs the melee slot.

Ammo (built):
- Every firearm has limited ammo, the starting pistol included (amounts in Content List). Built so far: pistol 12, shotgun 6, SMG 30, sniper rifle 3.
- An empty firearm is dropped automatically (it cannot be picked up) and the fighter falls back to bare hands.
- There are no ammo pickups (user decision); a weapon has only the ammo it came with.

Spread, bullet speed and crouching (built):
- Bullets do not all fly in a perfect line. Each weapon has a spread angle (each shot deviates randomly within it) and its own bullet speed.
- The sniper rifle fires dead straight with the fastest bullets; the SMG has the slowest bullets and the widest spread; the machine gun sits between them. Other weapons follow the same idea (the shotgun's pellets spread by design).
- Holding the trigger on automatic weapons widens the spread shot by shot; it narrows again when firing stops.
- Crouching narrows the spread (like crouching in Counter-Strike). Crouch has its own key (not S, which keeps aiming down): the fighter can walk slowly while crouched, and the body gets lower so level shots from a standing shooter pass over it. Walking while crouched still puts the firearm away, so crouched firing means crouching still.
- Prototype values: pistol 2° spread, 600 px/s bullets, no bloom. Crouching multiplies the spread by 0.4, lowers the body from 28 to 14 px (the hand moves down with it) and walks at 50 px/s. Each weapon sets `spread_degrees`, `spread_per_shot`, `max_bloom_degrees`, `bloom_recovery` and `projectile_speed` in its `WeaponData`.

Built firearm values (prototype, easy to change):

| Weapon | Ammo | Damage | Fire interval | Bullet speed | Spread | Other |
|---|---|---|---|---|---|---|
| Pistol | 12 | 10 | 0.3 s | 600 px/s | 2° | |
| Shotgun | 6 | 8 per pellet | 0.8 s | 700 px/s | 12° | 5 pellets, 180 px range, knocks down within 40 px of the muzzle |
| SMG | 30 | 5 | 0.08 s, automatic | 450 px/s | 4° + 1° per shot, up to +6° | |
| Sniper rifle | 3 | 80 | 1.2 s | 1500 px/s | 0° | Passes through 2 fighters and stops in the third |

- Bullets trace a ray along their path every frame, so even the sniper bullet never skips through a fighter or a thin wall.
- A point-blank shotgun blast lands every pellet before the knockdown makes the target invulnerable.

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

Player 1 (defaults): A/D move, Left Shift run, C crouch, W/S aim (S rolls while running), K jump, J attack (J + K together breaks a combo), 1-4 select slot (empty slots cannot be selected). Each local player gets its own `pN_` action set.

Player 2 (defaults): Left/Right arrows move, Right Shift run, Right Ctrl crouch, Up/Down arrows aim, / jump, . (Period) attack, 7-0 select slot.

- Jump always uses the jump key, in every state; aim up never jumps.
- Built: Esc opens a Controls menu (the game pauses) where every player rebinds their own keys: click a binding, press the new key (Esc cancels). Taking a key that another action uses swaps the two, so no action is left unbound. Bindings are saved to `user://keybindings.cfg`; "Reset to defaults" restores the list above. Escape cannot be bound.

## Weapon Pickups

Built:
- Only weapons spawned by the game can be picked up. Weapons dropped by fighters (disarmed or swapped out) can never be picked up; they disappear after a few seconds (5 s).
- Each arena defines fixed weapon spawn points. An empty spawn point spawns a weapon at an interval (about 10 s).
- With an empty firearm slot, walking over a spawned firearm picks it up automatically.
- With a full firearm slot, the fighter stands on the weapon and presses S once to swap: the new weapon is equipped and the old one drops (and cannot be picked up).
- Melee items work the same way with the melee slot (bare hands count as empty). Picking up an item selects its slot.
- Fighters start the match with a pistol (user decision) and 3 grenades (both built).
- Spawn points pick weighted at random by each weapon's `spawn_weight` (built): pistol, SMG and knife 3; shotgun, baseball bat, grenade and molotov 2; sniper rifle 1.
- Melee items and throwables come only from spawn points and the starting loadout (built). Throwables follow the same pickup rules with the throwable slot (empty = none left); a swap gives the full count of the new type and drops the old ones.
- A fighter that dies drops its firearm and its melee item. Like every fighter-dropped weapon, they cannot be picked up.

Current pickup rules (prototype, easy to change):
- Spawn points are `ItemSpawner` nodes under the arena's `ItemSpawns`; each lists the weapons it can spawn (one picked at random) and its interval. The test arena has one pistol spawn point near the left wall.
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
- No stunlock: after a combo cut short, the pause is long enough that the target is free for at least 0.2 s (per-class `combo_escape_time`) before the next combo can hit it.
- Trades: when two fighters' attacks connect on the same frame, both hits land.
- Prototype classes: Fast (jab, jab, jab, hook; 0.6 s pause) and Heavy (punch, punch, kick; 0.8 s pause). Player 1 is Fast, player 2 is Heavy.
- Each attack has wind-up, active and recovery time; it hits each target at most once, only during its active time.
- Movement input is ignored on the ground while attacking; the fighter keeps facing the same way.
- Getting hit cancels the current attack and the combo.
- A melee hit stuns long enough for the next attack in the combo to connect.

- **Downed fighters**: cannot be hit while lying down, and are briefly invulnerable while getting up; projectiles pass over them. This is a per-class setting so it can be revisited; allowing hits on the ground would also need a rule against re-knocking-down (endless knockdown loops).

## Damage and Hit Reactions

- Fighters have health (per class: Fast 90, Heavy 130); weapons define damage and knockback.
- A hit flashes the fighter, pushes it along the hit direction and stuns it briefly (0.25 s): no moving, jumping, aiming or firing.
- Stuns never shorten each other: a new hit only replaces the stun if it is at least as long, and a shorter bullet stun keeps a melee stun's combo breaker. Hits that neither stun nor knock down (fire) hurt and flash without interrupting the fighter's attack or dive.
- Each firearm sets its own stun per hit (`WeaponData.hit_stun`, default 0.25 s). Automatic weapons keep it below their fire interval so the target can still act under fire (SMG 0.03 s at 0.08 s per shot).
- Walls and floors block every hit: melee, blasts and fire only reach fighters with a clear line from the hit's origin to the body centre (`HitQuery`), and a shot whose muzzle pokes past a thin wall stops at that wall.
- Knockback sets the fighter's speed along the push instead of adding to it, so repeated hits never stack into huge speeds (there is no air friction).
- At zero health the fighter dies: the body stays on the map lying down, ignores input, and projectiles pass through it.
- A fighter's own projectiles never hit it.
- Fighters pass through each other; they do not block or push one another (user decision).

Prototype values (not yet tuned or confirmed): pistol 10 damage and 100 px/s knockback, 0.25 s stun.

## Players and Modes

- Multiplayer is a core requirement.
- A versus-computer mode (bots) is also required.
- Multiplayer is both local (several players on one machine) and online.
- Implication: fighters must not read `Input` directly; a controller (local player, bot, remote player) drives each fighter, and local players need separate key bindings.

Game modes (decided, not built yet):
- Several modes, for example capture the flag and a straight versus fight (deathmatch).
- Modes end in different ways: some by score, some by time, some by lives.
- Lives mode: every player has 3 lives. Each death costs one life and the player respawns until no lives are left; a player out of lives is out of the match.
- Open: the full mode list, each mode's rules (team or free-for-all, score limits, time limits), and whether a HUD shows health, lives, score and time.

## Maps

- Maps are classified as small, medium or large. Example designs will be discussed later.
- Maps are large: bigger than one screen, so the camera follows the fighters. Even small maps are not tiny rooms.
- Every arena's root is an `Arena` with a `bounds` rectangle. A fighter that leaves it (falls into a pit) dies; items and thrown objects that leave it are removed, so a lost spawned item frees its spawn point.
- Players will be able to import their own maps from outside the game. Format and tooling to be discussed later.
- Implication: imported maps must not run arbitrary code; a data-only map format (no scripts) is required for user content.

## Content List

Agreed with the user (session 2). Numbers are starting values to tune in play.

Firearms (slot 2):

| Weapon | Ammo | Fire | Role |
|--------|------|------|------|
| Pistol | 12 | Semi-auto | Starting weapon; weak but reliable. |
| Revolver | 6 | Semi-auto, slow | High damage and knockback. |
| Shotgun | 6 | 5 pellets in a cone | Deadly up close, weak far away; knocks down at point blank. |
| SMG | 30 | Automatic | Fast fire, low damage per bullet, slow bullets, widest spread. |
| Machine gun | 40 | Automatic | Medium damage, long range; spread and bullet speed between SMG and sniper. |
| Sniper rifle | 3 | Semi-auto, very slow | Nearly one-shot kill; fastest bullet, no spread; pierces through several fighters. |
| Bazooka | 2 | Rocket | Explosion hurts and knocks down everyone in range. |
| Flamethrower | 50 (fuel) | Hold | Short range; sets the target on fire (burn damage over time). |

Melee items (slot 1, replace the punch; each has its own combo and breaks after 10-15 hits). Knife and baseball bat are built:

- Durability counts hits that land on fighters; the jump kick is a kick and does not wear the item. An item that runs out finishes its current combo, then breaks and vanishes (nothing drops) and the fighter punches again.
- Built values (prototype): knife = stab, stab, slash (5/5/8 damage, very fast, reach about 22 px), 0.5 s combo pause, 15 hits. Bat = swing, swing, home run (8/8/14, the home run knocks down, reach about 29 px), 0.8 s combo pause, 10 hits.
- A knockdown drops the firearm but keeps the melee item (user decision); death drops both.


| Item | Speed | Reach | Role |
|------|-------|-------|------|
| Knife | Very fast | Short | Fast, low-damage combo. |
| Baseball bat | Medium | Medium | Strong knockback; the combo finisher knocks down. |
| Pipe / crowbar | Slow | Medium | Heavy hit; stuns in one blow. |
| Machete | Medium | Long | High damage. |
| Sledgehammer | Very slow | Long | Knocks down in one hit; a miss leaves a big opening. |

Bombs and throwables (slot 3, counted):

| Type | Count | Behaviour |
|------|-------|-----------|
| Grenade | 3 | Thrown, bounces, explodes 3 s after the pin is pulled; area damage and knockdown. Every fighter starts with 3. |
| Molotov | 2 | Breaks on impact and leaves a burning area for a few seconds. |
| Mine | 2 | Placed on the ground; explodes when someone steps on it. |
| Remote explosive (C4) | 1 | Stuck to a surface; detonated with the attack key. |

Rules for throwables and explosions:
- Throwing aims like a firearm (the facing half-circle, W/S), with a fixed throw strength.
- Explosions and fire hurt the thrower too; position and timing matter. A molotov thrown at your own feet burns you. A grenade's fuse starts when the pin is pulled, so holding it too long makes it explode in your hand.
- Grenade controls: holding the attack key pulls the pin and starts the fuse; releasing it throws. Held past the fuse time, it explodes in the hand.

Grenade and molotov (built; prototype values, easy to change):
- Like the firearm, the throwable is in hand and aimed (W/S) only while standing still on the floor in slot 3. Pressing attack pulls the pin; the fighter then cannot move, jump or change slots until it throws. Releasing attack throws along the aim lifted 30° upwards at 300 px/s, so a level aim still lobs.
- Grenade: 3 s fuse counted from the pin, bounces off the world (passes through fighters). The blast hits every hittable fighter within 40 px once: 35 damage, pushed away and knocked down.
- Molotov: no fuse; it breaks on its first contact with the world or a fighter and leaves a 48 px fire on the floor below for 4 s. Fire burns 4 damage every 0.5 s to everyone standing in it, without stunning.
- The thrower is never hit by its own throw in flight, but the blast and fire hurt it like anyone else.
- Current defaults (not yet confirmed by the user): a stunned fighter keeps holding a live grenade and throws when the stun ends; a knockdown or death drops a live item at the fighter's feet. A dead fighter's unused throwables drop as one item that cannot be picked up.

Build order is open; shotgun, SMG, sniper rifle, knife, baseball bat, grenade and molotov are built.

## Current Prototype Deviations

- Only the knife and baseball bat exist as melee items, and only the grenade and molotov as throwables; power-ups are not implemented yet. Blasts and fire are placeholder shapes. Melee items are held level in the hand like a firearm until swing animations exist.
- The punch is shown as a placeholder box over the hit area until attack animations exist.
- The main scene spawns two local players (P1 Fast, P2 Heavy, both with a pistol and 3 grenades) and respawns a dead player after 1.5 s of unpaused time; this is a testing aid until rounds and a match flow exist.
- Death and knockdown are placeholders (the rectangle rotates); the real animations come with sprites.
