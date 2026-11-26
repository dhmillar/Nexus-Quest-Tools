# Changelog

WowUp installs the Forever ZIP attached to tagged GitHub releases.

## 1.5.103 - 2026-11-26

### Changes
- Rank Quest displays observed drop rates with Questie disabled. Includes 1,177 NPC/item pairs across 626 item IDs; unknown rates remain hidden. Hover the quest for sample sizes and dates. Data from Everloot (https://everloot.app), CC BY-SA 4.0.
- Party rows show teammates' names and combined progress. Remaining objectives expand once yours are done.
- Rank Quest finds more quest-item links from game data and rechecks verified turn-in pins after you leave a map.
- Added General > Hunter Deadzone, a crossed-out bow cue with a draggable preview. Settings can be dragged and reopen centered.
- Smart Target skips mobs tagged by another group. Ordinary action-bar recall no longer marks or pings unverified mobs. Boss mode is unchanged.

### Hotfixes
- Extended quest-item details now stay within the native bag tooltip's dark backdrop.

## 1.5.102 - 2026-11-25

### Changes
- Rank Quest shows how many of your quests are displayed out of the total in your quest log (for example, `4/20 Quests`). Search, filters, and collapsed groups change the number shown. Party-only quests do not count toward your personal totals.

### Hotfixes
- Clicking Rank Quest toolbar controls keeps the toolbar open. Clicking outside Rank Quest still collapses it.
- Boss Target Marking no longer keeps a dead boss selected, marks it, or pings it. Smart Target continues looking for a living boss on the same press.

## 1.5.99 — 2026-11-25

### Changes
- Rank Quest starts with a larger title and hidden toolbar. Click the title bar to show the controls; click outside the log to tuck them away.
- Longer area names use the width up to the search icon. Opening search puts the input on its own row.

### Hotfixes
- Clicking away from an empty search restores the magnifying glass. Typed queries and results stay in place.
- Dungeon minimap docking accepts the default Blizzard minimap anchor without SexyMap and restores its normal position and controls on close. The stock minimap can also dock on the dungeon panel when overview artwork is unavailable.

Both UI regression suites passed. The stock minimap change still needs confirmation in the game client.

## 1.5.95 — 2026-11-25

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
