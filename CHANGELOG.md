# Changelog

Source previews on the main branch are separate from the tagged GitHub releases that WowUp installs.

## 1.5.95-preview — 2026-11-25

### Added
- **Dungeons** replaces the Dungeon Position tab. With dungeon docking enabled, the normal **M** map shows the live minimap without its menu buttons or zone heading. Supports the stock minimap and SexyMap. Ctrl-left-drag saves a separate dock position.
- **Rank Quest** can show Questie’s known NPC item drop rates as a percentage or range. Unknown rates are omitted; toggle the display in Rank Quest settings.
- **Boss Target Marking** uses the existing player-triggered macro or keybind to acquire and mark detected bosses in order when the client allows it. Optional Attack pings remain available.
- Verified bag-item Ctrl-clicks search Rank Quest. The action-bar macro uses the fire-cat icon rather than a question mark when it has no mob icon.

### Hotfixes
- Fixed normal minimap terrain going black after closing **M** with SexyMap. Clear only the opaque background fill after undocking; retain the border and saved layout. Confirmed working in game.
- Kept the normal minimap in its original position and stopped docked buttons from flashing back on hover.
- Right-click returns to the world view until **M** closes. Reopening uses Dungeon Journal’s own dungeon-view switch rather than stacking a duplicate map.
- Added **Dungeons → Minimap check** and `/nqt minimap` for local renderer diagnostics.
- Removed experimental movement-based dungeon tracking. Map pins are not a promise of live positions when the game does not expose them.

## 1.5.45 — Tagged release
- Fixed keyboard focus remaining in Rank Quest search after clicking outside; search text and results are retained.

See [GitHub releases](https://github.com/dhmillar/Nexus-Quest-Tools/releases) for previous tagged builds.
