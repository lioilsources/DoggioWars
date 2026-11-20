# Changelog

The version you have installed is shown in chat when you join a game, and
any time with `/version`. Older releases: https://github.com/lioilsources/DoggioWars/releases

## v2.5.1

- Fixed a crash on Android right after spawning
  (`Invalid vector coordinate y (value is nil)` in `hud_add`).
- The game shows its version and what's new when you join; `/version`.

## v2.5.0

- Music: every island biome has its own theme that crossfades in as you
  approach; creatures carry their own looped sounds.
- Shot sound, and impacts that sound different by material (stone, sand,
  dirt, wood, leaves, ice, crystal, magma, metal), plus a crash explosion.
- Shots bore tunnels through islands; a headlight lights the way (`/headlight`).
- Creatures are twice as big, more of them live on each island, and they no
  longer fly through the terrain.
- R1/L1 (Xbox RB/LB, mouse wheel) switch between fighter and submarine.
- `/music on|off`; music and creature volume in Settings.
