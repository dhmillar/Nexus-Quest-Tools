# Nexus Quest Tools for WoW Forever

<img src="https://raw.githubusercontent.com/dhmillar/Nexus-Quest-Tools/main/assets/nexus-fire-cat.png" alt="Nexus Quest Tools fire-cat icon" width="112">

Nexus Quest Tools is a World of Warcraft: Forever addon that organizes your quest log, tracks what you’re working on, and helps you get to the next objective. It also adds a reusable action-bar macro for named targets and an optional dungeon map view. Formerly Rankor Tools and Auto Track.

[Read the Nexus Quest Tools Field Manual](https://nighteternal.net/NQT) for installation, screenshots, and feature walkthroughs.

## What it does

### Quest tracking and navigation

- **Nearby quest focus.** Automatically watches eligible nearby quests. It sticks with the current quest while you’re in range, looks for the next one after completion or when you move on, and can unwatch finished objectives without removing the quest from your log. Right-click a quest to exclude it from automatic tracking.
- **Your order comes first.** Ctrl-click to build a numbered queue of up to 10 quests. The queue takes priority over nearby tracking and advances as quests are completed. You can also pin one quest directly or reset the queue from the quest menu.
- **Navigation on both maps.** Follow the focused quest or a pinned turn-in on the minimap and world map. Covered areas can use a walking route from a compatible navigation addon; road-aware routing requires a provider that supports it. Otherwise, when reliable positions are available, the addon can show an estimated direction. Directions hide when you reach the objective area.

### Rank Quest

- **A customizable floating quest log.** Filter by current zone, any zone, current dungeon, or all dungeons. Search the entire held quest log by quest title, area, dungeon, or objective. Collapse groups to keep the log tidy. Choose the compact Minimal or Map theme, adjust font size with − and +, and move, resize, or collapse the panel.
- **Quest details at a glance.** See difficulty, kill and collection counts, group-quest skulls, and usable quest items when WoW supplies them. Use the left circle to focus a quest and the title to open it on the map. The Completed view shows quests still awaiting turn-in, including area, coordinates, and NPC when known.
- **Drop rates.** Rank Quest optionally shows whole percentages for known item drops. Questie is optional; bundled observed Forever rates cover NPCs and objects. Unknown rates stay blank.
- **Party objectives.** Hover for available party progress or use the person button for named counts under your own objectives. A quest can stay on the list while a party member still needs it. Counts depend on what WoW reports.
- **Bag cleanup hints.** Optional badges explain why a verified leftover quest item is no longer needed by your current log. Items with uncertain data are left alone. The addon never destroys items.

### Auto Macro

- Place the **Auto Track** macro on an action bar and use that slot’s normal keybind. Save a selected mob or type an exact or partial name, then reuse it without editing the macro each time. Lock a manually entered name if you don’t want other selections to replace it.
- Choose a raid marker and optionally request an Attack ping when using the macro. These are player-triggered actions subject to WoW’s targeting, combat, range, and group permissions. The game chooses the match; the addon does not guarantee the nearest target.

### Dungeons

- Open the current dungeon map first when you open the world map inside a supported instance. Use in-client floor art or supported maps from a separately installed Forever Dungeon Journal. No third-party map art is bundled.
- **Live minimap dock.** Show the real minimap in the dungeon view opened with M. Ctrl-left-drag to move it without changing its normal layout. Supports stock and SexyMap.
- **Boss Target Marking.** Use the existing macro or Smart Target key to mark detected bosses, with optional pings. Player and party positions depend on game-provided data; no movement-based position estimate is used.

## Standalone quest data

Rank Quest uses built-in game APIs first, including active quest-item links and exact native turn-in map pins. A small set of handwritten factual item relationships includes Goretusk Liver → Goretusk Liver Pie and Murloc Eye → Westfall Stew. These were cross-checked on the individual [Goretusk Liver Pie](https://www.wowhead.com/forever/quest=22/goretusk-liver-pie) and [Westfall Stew](https://www.wowhead.com/forever/quest=38/westfall-stew) Wowhead Forever pages. No database, quest text, maps, or drop tables from Wowhead are bundled. Missing data stays unknown. Questie still optionally supplies extra locations and drop rates.

## Install and update

- **WowUp:** Select **WoW Forever**. If Nexus Quest Tools is not yet visible in Get Addons, choose **Install from URL** and paste `https://github.com/dhmillar/Nexus-Quest-Tools`. Use the repository URL, not the ZIP URL, to stay on the release update channel.
- **Manual:** Download the attached Forever ZIP from [Releases](https://github.com/dhmillar/Nexus-Quest-Tools/releases/latest), not GitHub’s autogenerated source ZIP. Extract the folder supplied by the release into the Forever Interface/AddOns directory. Version 1.5.45 used the AutoTrack folder; version 1.5.95 uses NQT. Keep just one installed copy.
- **Start here:** Type `/nqt` to open settings. `/at` and `/autotrack` still work. The four settings tabs are **General**, **Auto Macro**, **Rank Quest**, and **Dungeons**. Use `/reload` for updates to existing addon files; reopen WoW for a fresh install if it doesn’t appear on the addon list.

See the [changelog and hotfixes](CHANGELOG.md), [detailed controls](NQT/README.md), or [public release notes](https://github.com/dhmillar/Nexus-Quest-Tools/releases).


### Migrating to NQT

Fully exit WoW before switching folder names. Back up the old AutoTrack add-on and settings. For an NQT build, copy AutoTrack.lua to NQT.lua in each same SavedVariables directory, at the account and character levels. Keep the originals. If NQT.lua already exists, do not overwrite it. Move the old AutoTrack addon folder out of Interface/AddOns so both copies cannot load together. Existing macro and keybind names do not change. Launch WoW and make sure Nexus Quest Tools is enabled.
## Release packaging

Set the version in `NQT/NQT.toc`, run `tools/New-Release.ps1`, and attach the resulting `-forever.zip` to a tagged GitHub release. The archive must contain `NQT/NQT.toc` at the root addon folder and target Forever interface 16001.

### Optional drop-rate observations
Data from Everloot (https://everloot.app), CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/).
EverlootDrops.lua is the separately licensed adapted data. It holds only NPC/object IDs, item IDs, and observed counts; no game-file layer or install pseudonyms. Snapshots: https://everloot.app/database/download (November 14, 2026) and https://everloot.app/docs/api/rollups-drops (data as of November 26, 2026). Keep the credit and share this adapted data on the same license. Filters: public observations from at least three installs for NPC and object sources. For each item and source type, smaller samples fill gaps only when no source has at least 20 eligible windows. Newer observations replace older ones for the same source unless the older sample is the only one with at least 20 windows. Rates are rounded up for display; a range indicates that different sources have different rates. Counts were not pooled. An absent rate is unknown, not zero. Observed rates per eligible loot window are estimates, not game constants. Hover a quest to see the counts and snapshot dates.

## Standalone map pins versus Questie Forever defaults

In Rank Quest settings, Show standalone map pins is on by default and hides the NQT layer when Questie is loaded. Where Forever reports them, NQT shows available starts, active quest/waypoint pins, ready turn-ins, flight masters, and service POIs. It avoids drawing over detected stock quest pins. Outdoor minimap placement uses the client's position and view radius and does not draw when those values or rotation are unavailable. The world map shows cursor coordinates while supported.

Additional observed service pins: 12 innkeeper, 39 flight-master and 51 mailbox records. Coordinates are approximate interaction points, not exact spawns. Known factions are filtered; a mailbox or inn with unknown affiliation does not imply access. Observed quest givers is a separate off-by-default option, with 61 recorded locations. These are prior observations, not proof the quest is offered to your character.

Data from Efficient Games (https://efficient.games), licensed under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/). The separate ForeverTownPins.lua data is adapted from https://github.com/JIVESCORP/eg-link-output-wowf/tree/main/data/wowf (Forever builds 1.60.1.70959, 1.60.1.71037, 1.60.1.71091). Numeric positions and service interactions only; no names or quest prose. Filtered to supported categories and coherent coordinates; observed giver inclusion requires the location across two snapshots.

Audit: Questie Forever 12.15.0 defaults enable quest/available starter-item/object/monster/event/turn-in pins, party objectives, NPC patrol paths, map and minimap icons, world-map coordinates, map controls and next-chain/NPC quest tooltips. It also enables innkeepers, flight masters, mailboxes, meeting stones; most other services are off by default. Fresh Questie allows repeatable, event, dungeon, raid and PvP quests where eligible, not AQ/SoD extras. This preview does not claim full parity: broad remote availability and prerequisite/phase logic, starter-item source pins, complete per-mob/object spawns, party-only map points, patrol paths and full service/meeting-stone coverage still need verified data. You can keep Questie for those and use Rank Quest normally.
