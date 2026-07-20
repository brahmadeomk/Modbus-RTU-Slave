# Rivals-Style Fast-Paced Shooter (Roblox)

A complete team-deathmatch arena shooter for Roblox Studio, inspired by
Rivals: low time-to-kill hitscan guns, heal-on-kill, double jump, dash,
jump pads, and a symmetric arena that is generated at runtime — it works
in any place, including an empty baseplate.

## Install — option A: one paste (fastest)

1. Open your place in Roblox Studio.
2. Enable the command bar: **View → Command Bar**.
3. Open [`StudioInstaller.lua`](StudioInstaller.lua), copy the **entire**
   file, paste it into the command bar, and press Enter.
4. Press **Play** to test solo, or **Test → Clients and Servers** with
   2+ players to try actual PvP.

Re-running the installer is safe; it replaces the previous install.

## Install — option B: Rojo sync (for iterating on the code)

1. Install [Rojo](https://rojo.space) and its Studio plugin.
2. From this `roblox/` folder run `rojo serve`.
3. In Studio, connect the Rojo plugin.

## Controls

| Input | Action |
| --- | --- |
| Left mouse | Fire (hold for full-auto on the AK-77) |
| R | Reload |
| Space (in air) | Double jump |
| Q | Dash (2s cooldown) |
| 1 / 2 / 3 | Switch weapon (AK-77 / Riot Shotgun / DMR-9) |

## Game rules

- Everyone spawns unarmed in a **lobby** deck outside the arena; a
  15-second countdown runs between matches.
- On match start, players are teleported onto their team's arena pads,
  armed, and given 3 seconds of spawn protection. Mid-match respawns and
  late joiners drop straight back into the arena.
- Two auto-balanced teams (Red vs Blue). First team to **40 kills**, or
  the higher score when the **5 minute** match timer runs out — then
  everyone returns to the lobby and the next countdown starts.
- Kills heal you **+35 HP** (Rivals-style reward for aggression).
- Green pads launch you into the air; the center platform is high ground.

## Architecture

```
src/
  shared/   WeaponConfig (balance table), Remotes (RemoteEvent access)
  server/   MapBuilder (arena + lobby), PlayerSetup (movement stats),
            Loadout (weapon hand-out), CombatServer (server-authoritative
            hit validation), GameManager (teams, scores, killfeed,
            lobby/match state machine)
  client/   WeaponClient (aim lock, crosshair, firing, tracers),
            MovementClient (double jump, dash), HUD (health, ammo,
            scoreboard, killfeed, round banner)
```

Combat is server-authoritative: the client only *requests* a shot; the
server enforces fire rate, ammo, reload state, muzzle position, and team
before dealing damage, so exploiters can't send "I hit them for 999".

Tweak weapon feel in `src/shared/WeaponConfig.luau`, then re-run
`python3 build_installer.py` to regenerate `StudioInstaller.lua`.
