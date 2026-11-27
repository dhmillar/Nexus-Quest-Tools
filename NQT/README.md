# Nexus Quest Tools 1.5.154
For World of Warcraft: Forever 1.60.1 (interface 16001). Uses the Blizzard quest tracker and a native character-specific action-bar macro. Optional compatibility with Questie.

## Install or update
Install this build as Interface/AddOns/NQT with NQT.toc directly inside it. For upgrades from AutoTrack, follow the repository migration instructions.

## Action bar and keybind
1. Click the teal AT minimap button (or type /at).
2. Choose Place on action bar, then click the empty slot you want to use. Or drag Auto Track from the Character Specific Macros tab in /macro.
3. Press that slot's existing keybind. To change it, use WoW's keybinding settings. Auto Track does not take over a slot or assign a key for you.

To save or replace a mob, select a living hostile NPC out of combat and press the regular action-bar key or left-click the slot. That press keeps the target selected. AT > Save selected mob and /at set also work.

To recall the saved name, press the slot with no target. The regular recall cannot tell which match another group has tagged, so it does not automatically mark or ping ordinary mobs. Use the Smart Target key to check eligibility before acting.


Right-click the macro slot (or use AT > Edit target name) to type a partial name such as Rap. Save partial uses WoW's native partial name search; Save exact matches the full name. Selecting a matching mob won't replace the partial search text. Selecting a different, non-matching mob and pressing the button still learns its full name. Existing saved names stay exact unless changed in the editor. WoW chooses the match, so use a longer piece if several mobs have similar names. Check **Lock saved name** in the target editor, then save. The normal key will not replace a locked name with the selected mob. Uncheck it and save to restore ordinary learning. Typed names can still be changed deliberately.

To learn from a corpse, select a hostile NPC corpse and press the Auto Track slot once to learn it. The macro keeps the corpse selected and never marks or pings it. With readable target data, captures requested in combat are saved when combat ends. Out of combat you can also use AT > Save selected mob. The next recall searches by the same name and drops a corpse if the game returns one; it cannot make the stock search skip directly to another living match.

With enemy nameplates visible, press the normal macro again out of combat while the selected mob has your primary marker or is tagged by another group. When the client exposes enough information, a teal NEXT label briefly highlights a different, visible, living hostile of the same name that the game reports as not tap-denied. If multiple qualify, the label prefers the one nearest the center of your screen, not the physically closest mob. Click its nameplate manually. NEXT is local to your UI: it does not select the mob, send a group ping, remove a real skull, or transfer it automatically after a kill. You can disable it under AT > Highlight next visible untagged mob. If no valid nameplate or tap information is available, use Tab or click a mob yourself. WoW does not offer a tap-aware macro filter.

The standard action-bar macro keeps a selected mob. It learns a different selected hostile on the usual plain press out of combat, or searches the saved name when there is no target. It never pre-clears a living selected target to try another match. The previous Fresh Target option was removed because it prevented that same normal press from learning. WoW chooses search matches; it does not guarantee the closest.

For the group, AT > Place mouseover Ping (/at ping) and Place secondary marker (/at x) create optional native action-bar macros. Put one in an empty slot, hover the intended living enemy or its nameplate, and press the slot key. AT Ping sends the stock Attack ping; AT X places a real red X (or a blue square if X is your primary) if the hovered unit has no existing marker. They never fall back to your current target, pick a unit, or transfer a skull on their own. WoW restrictions, including group permissions, still apply.

Open AT > Primary marker to choose Star, Circle, Diamond, Triangle, Moon, Square, X, or Skull (the default). Choose a different marker than your group members; Auto Track does not reserve a group marker. Your choice is per character, affects Smart Target and the separate primary macro, and is recognized by the NEXT hint. The legacy AT Skull macro name stays on your bar so its slot and keybind do not change.

Turn on Ping when placing marker for an optional Attack ping on the same eligible target with Smart Target, or when you deliberately use the separate primary marker macro. WoW can still deny a marker or a ping.

Check Mute target macro sounds in the AT options to briefly silence the game's target-select and target-clear sounds during a recall without changing your other sound settings. Use Edit target name in the AT minimap options or /at target to type a name or part of a name out of combat. On an action bar that forwards right-clicks to macros, right-clicking the slot also opens the editor. Clear the name by saving a blank value. There is no floating target button. Blizzard action bars can show a portrait for the saved monster after you select it. Until that monster is seen in the current session, the slot uses its normal macro icon. For a regular key without a modifier, choose AT > Place primary macro (or /at skull), then place it in an empty action-bar slot. The minimap AT button opens settings; right-click it to pause or resume, or drag it to reposition.

## Quest focus
Auto Track keeps the current accepted quest until its objectives are complete, or until you leave its range and there is another nearby quest. When one completes, it looks for the next right away and continues scanning as you move. It can remove ready-to-turn-in quests from the tracker; they stay in your quest log. Other manually watched unfinished quests are preserved.

Right-click a quest and toggle its Auto Track exclusion. That choice is saved per character. An excluded quest is left to manual tracking, including after completion, until you re-enable it from its quest menu. If the quest disappears from the tracker, use /at excluded and /at include ID to restore it.

Entry radius is 180 yards and the current focus keeps its lock through 225 yards. Only usable quest-location data can establish range. The addon skips protected updates during combat and catches up afterward.

## Manual quest queue
Ctrl+left-click quests in the Blizzard quest log, on-screen tracker, or compatible Questie tracker to add them to your personal tracking order. In the native floating All Objectives tracker, each queued quest shows a large white number in a cyan-rimmed badge over its existing circle on the left. Normal icons return when you remove quests from the tracking order. The title and objective text are unchanged. The maximized world-map quest log uses the same badge over its quest circles, without adding numbers to the objective text. In the floating tracker, Ctrl+left-click changes the order without opening the map. Ordinary left-click still opens the quest. Ctrl+left-click again to remove a quest; use Add to Tracking Order or Remove from Tracking Order on a quest's right-click menu if needed. Choose Reset Tracking Order to clear all entries, or type /at order to list your saved order. Queued quests take priority over nearby automatic focus, even if no distance is available. Finishing a queued quest advances to the next one.

## Minimap walking GPS
Auto Track draws a thin contour of the actual walkable route to the active quest. It stops drawing inside the objective area and resumes after you move out. It uses the game's task-area flag when available and otherwise uses remaining walking distance: hide at 35 yards, resume beyond 52. The contour updates as you move, follows the route's bends, and is a locally scaled preview rather than the minimap's exact zoom.

When the optional Polestar 0.4.2.2+ (0.4.x) navigation engine is already loaded and has a covered map, Auto Track requests its Balanced road preference, which favors nearby roads over slightly shorter off-road routes. Successful results are labeled ROAD-AWARE WALK. Auto Track does not install, enable, or take over Polestar or its journeys. If an enabled compatible navigation module is already installed and its parent addon is loaded, Auto Track can ask WoW to load that module once out of combat. Shortest Path Forever v1.45.4 (API 2.7+) can supply WALK ROUTE on covered maps, without road preference. Without a real route, a reliable outdoor objective can show a thin glowing amber direction line from the player. It is not a terrain path or road route. Inside caves, dungeon floors, and other ambiguous interior maps, Auto Track does not draw direction. The first eligible quest in your tracking order supplies the GPS destination even when the native watch is full. Without an order, the minimap HUD follows the manually selected Blizzard quest, nearby focus, or a single unambiguous watched quest. The bottom center of the minimap, immediately above the clock when present, shows remaining walking yards that update as you move, or a straight-line yard estimate identified by the amber line and /at gps when the positions are reliable but the route is not available. The lower HUD shows the next bend, quest location, or the reason a route is not available. Arriving hides the route and shows a subtle In objective area status. The route switches at order advance and stays available while recalculating on the same path. Type /at gps to see why a route is not currently shown. Change this under AT > Show minimap walking route.









## Optional Smart Target key
In WoW Options > Keybindings > Nexus Quest Tools, bind Smart Target (out of combat). A plain press still learns a different selected mob, even from a hostile corpse. Repeated presses pick a living, eligible match from the current target, mouseover and visible enemy nameplates, using distance or available range checks. If no match is confirmed eligible, it does nothing. The regular action-bar macro can still recall by name, but WoW name recall cannot filter by tap status, so it no longer automatically marks or pings. Boss Target Marking and the manual marker macros are separate.


### Full map route
The large map shows the remaining verified walking path in teal whenever that path is available on the displayed chart. With a known objective but no walking path to draw, the large map shows an amber objective marker and, only on the same outdoor zone map, a thin glowing amber line from the player clearly marked as an estimated direction, not a walking route. Both maps render genuine walking paths in teal, distinct from the labeled amber estimate. The estimate does not imply terrain is walkable. Its small bottom-center readout shows only yards; the large map legend and /at gps identify estimated guidance. On arrival, both overlays stop drawing directions. Neither map input nor quest selection is changed.
### Rank Quest
Turn on **Enable Rank Quest** in the AT minimap settings. Its Current tab shows active quests associated with the zone you are in, including quests that start there or are logged under that zone but send you elsewhere. In Zones, choose All Zones below Current Zone to see each quest once across your whole log, including quests without known zones. In Progress and Completed still apply. All Zones stays selected while traveling; individual zone selections reset to Current when you enter a different zone. An already accepted quest needs a reliable quest-log category, native waypoint/POI, a locally recorded acceptance, or unambiguous starter data from an already-loaded Questie. Ambiguous and unsupported quests are not silently assigned to the current zone.
Drag the header, resize by the bottom-right handle, click the theme name to switch between Map (default, native world-map quest-log artwork) and Minimal (transparent Friz Quadrata), click In Progress or Completed to switch status views, or collapse to the Rank Quest tab. Hover a quest to see its objectives. Click the quest name to open its details on the world map. Click its left circle to make it active for tracking and GPS; click a pinned circle again to resume normal queue/nearby tracking. Ctrl-click adds/removes it from Auto Track's queue. Right-click the quest or its tracking circle for quest actions, including Add/Remove/Reset Tracking Order, Focus/Unfocus, and Abandon Quest. Abandon requires confirmation and is available only for eligible quests in your own log. Enabling Rank Quest hides the Blizzard quest display; disabling it restores Blizzard visibility. Quest watches, the native quest log, and Questie are not changed by this visibility switch.

Open or close the full-height zone drawer with the narrow left handle. Tabs stack vertically; when more zones exist than fit, scroll vertically in the drawer. Quest rows show every native objective (including current kill/collection counts) and, when WoW exposes a special quest item for that quest, show the item icon and its hover tooltip. Click a visible quest-item tile to use that item outside combat. Use the stock item action or your bags during combat; Rank Quest keeps its moving item tiles inactive until combat ends.
Use the top - and + buttons to resize all Rank Quest text without scaling artwork and item icons. Font size persists across reloads. Minimal has no left bar: use its top Zones button instead. Quest titles show WoW's quest level and its player-relative difficulty color in every theme when those data are available.

The quest list, zone drawer, and Minimal zone menu scroll with the mouse wheel without visible scrollbars.

Rank Quest defaults to In Progress. The Completed view shows objective-complete quests still in your quest log for the selected zone, even when Auto Track has removed their watch. It does not list quests you already turned in. The status filter does not change watches or your tracking order. Tracking order numbers appear to the left of quest names.

The Blizzard quest display stays hidden if you collapse the Rank Quest to its tab. Unrelated Blizzard objective modules remain visible. Any native visibility change needed during combat waits until you leave combat.

The stock quest tracker stays visually hidden during native layout refreshes such as Ctrl-click tracking-order changes. The original Blizzard frame opacity is restored when Auto Track no longer replaces it.

Rank Quest highlights recently updated objectives in amber until completion or confirmed departure, and uses teal for verified quest areas or proximity to known objective locations. Quest grouping, focus, and the tracking order are not changed. If WoW briefly withholds location data, existing highlights are retained in the same zone. Highlights do not require a walking-path provider.

A skull marks a group quest when WoW identifies it as a group quest or recommends more than one player. The quest tooltip shows the recommended group size when it is available.

Use **Dungeons** next to **Zones** to filter Rank Quest to a dungeon for which you hold quests. The list uses recognizable dungeon locations and quest data, and does not treat all group quests as dungeon quests. In Progress and Completed still apply. Choose **All zones** to clear the dungeon filter.

Zones includes held quests from collapsed Blizzard categories, without changing their visible collapsed state. The list refreshes when quest data becomes available. A held quest with no verifiable zone appears under **Other quests** rather than being assigned a guessed zone.

**Quest Party Progress** is on by default. Click the person icon just left of In Progress / Completed to toggle inline remaining counts for other party members. Inline starts off and does not affect hover or quest retention. The inline view puts your objectives first, followed by a separate Party objectives section grouped by player. Only reported unfinished objectives are listed, and older counts are marked last reported. Hover a Rank Quest entry to see the counts WoW reports for your party, without sending addon messages. A quest can stay in In Progress while a party member still needs objectives, even after you complete it. After your turn-in it is a display-only entry, with no tracking or map actions. If WoW stops reporting a member, the tooltip marks last-reported counts as unavailable for up to 45 seconds. Leaving the party, disconnects, or reported completion clear pending entries as applicable.

In Rank Quest, click a ready quest's left tracking circle in Completed to pin its verified turn-in location. Click again to resume regular tracking. Pinning can't show a destination where the game and the optional Questie data don't identify a finisher. The pin ends when you turn in or remove the quest.

### 1.5.23
- Added All Zones to the Map and Minimal Zones panels.
- Focused ready-to-turn-in quests use exact native or Questie finisher locations. Guidance stays visible closer to the NPC, and the full map can show estimated direction between zones on a shared continent map. Lines remain hidden if there is no reliable destination or map position.

### 1.5.24
- Added the Rank Quest right-click menu in both themes. Questie map icon, objective, and TomTom actions appear when Questie supplies them; the main quest actions do not require Questie.
- Abandon Quest names the quest and requires confirmation, checks eligibility and verifies the exact staged quest ID again before acting. Party-only quests and blocked in-combat actions cannot be abandoned from Rank Quest.

### 1.5.25
- Confirmed abandoned quests disappear from Rank Quest, even if the WoW quest log briefly shows stale data or a party member still has the quest. A confirmed turn-in can still show party progress. Reaccepting a quest restores its entry.

- Current Zone uses the current dungeon when inside a party instance, including named floors. All Zones and explicit filters remain available, and In Progress/Completed still apply.

### 1.5.26
- Rank Quest shows Ready to turn in instead of your completed objective checklist. When a verified destination is available it shows the map name and coordinates, plus the finisher name when Questie identifies that point. The existing party-progress controls still show unfinished party objectives. Looking up a destination does not change watches or GPS focus.

### 1.5.27
- Turn-in rows put area and coordinates above the finisher name.
- Click a verified NPC name out of combat to ask WoW to target that exact name and apply a diamond. Uses a native secure button on a real click, with no automatic targeting or interaction. Targeting and marking still depend on the client, nearby NPC availability, and marker permissions.

### 1.5.28
- Selecting a zone or dungeon with quests ready to turn in but none in progress automatically opens Completed. The manual status toggle still works, and the temporary fallback does not replace the player's status preference.
- The Dungeons picker has All Dungeons. It combines and deduplicates dungeon quests without including outdoor quests; the Zones picker still has All Zones.
- Rank Quest always uses the compact layout. Font size is still adjustable; the old Compact/Roomy setting is gone.
- Minimal is the default theme for new settings. Existing Map and Minimal selections are preserved.

### 1.5.29
- Quest titles and turn-in NPC names have separate mouse hitboxes. A title opens the quest; a verified NPC name uses the higher-layer secure click to target and mark, and never opens the map if the action is unavailable.
- The same hardware click also sends a native Assist ping for the targeted NPC, subject to range and ping permissions.

### 1.5.30
- The NPC click no longer requires the turn-in target to be assistable. The native diamond and Assist ping are attempted on a living exact-name target, including neutral quest NPCs. A failed lookup still cannot mark or ping the previous target.

### 1.5.31
- Corrects dungeon grouping for The Drowned City and other Forever launch dungeons when the game provides no usable dungeon map or quest category. Uses verified quest and instance IDs as well as the existing native lookup, without guesswork from a generic dungeon tag.
- Adds live search over the entire held quest log, including active and completed quests. Match partial titles, IDs, zone and dungeon names, or objective keywords; Escape clears the query.
- Moves the font-size and dungeon/zone controls immediately below the top status/theme row.

### 1.5.32
- Search Results, All Zones, and All Dungeons show named, collapsible branches with quest counts. Each quest appears once, under its best known area or dungeon. Search favors areas that match the query. Clicking a branch toggles its rows without changing tracking, and Rank Quest remembers each view’s collapsed branches.

### 1.5.33
- Settings now have General, Auto Macro, Rank Quest, and Dungeon Position tabs. Dungeon Position controls the map view, automatic opening, and player/party icons.
- Opening the world map inside an instance opens Dungeon Position first when enabled. World Map switches back for that opening. An already-visible Dungeon Journal map takes precedence; otherwise AutoTrack can render floor textures directly from an installed Journal or use the client’s own matching floor art.
- No third-party art is bundled. If neither the client nor the installed Journal exposes floor art, the panel explains that there is no map available.
- Position icons only use the supported C_Map API and a matching native floor. Unavailable, restricted, or wrong-floor coordinates are not shown. Custom Journal artwork has no reliable coordinate alignment; AutoTrack never projects dots onto it from a different map.

### 1.5.34
- Rank Quest search uses the same font size as its section heading, follows the font-size controls, and has a taller field.

### 1.5.35
- Rank Quest search starts tucked behind the magnifying glass at the far right. Click it to start typing. Search stays visible while working; click X or delete the query to close it.
- Dungeon Position can draw on Dungeon Journal's live map view when the selected dungeon and visible floor match verified native tiles. It only shows locations the game makes available; opening the map from Dungeon Position settings reports when live positions are unavailable.

### 1.5.36
- Auto Track was renamed to Rankor Tools. Keep the AutoTrack folder in place so existing settings, slash commands, action-bar macros, and keybinds continue working.

### 1.5.37-preview
- Local only. Tries native WoW pins on matching verified art where permitted; the Open Dungeon Map button can report a game-provided area label when the coordinates are unavailable.

### 1.5.39-preview
- The addon now displays as Nexus Quest Tools. Install folder, saved settings, and keybinds are unchanged.

### 1.5.48-preview
- Ctrl-left-click a recognized quest item in the default bags to open its quest details without changing tracked quests. Items with more than one matching active quest are left alone.
- Dungeon Position can show an approximate room on verified native artwork for the Mast Room and Ironclad Cove in Deadmines. This is not a step-by-step location. If Dungeon Journal has another floor open, choose the corresponding Journal floor or use Game floor map.
- Selected room geometry and native tile IDs adapted from [Forever Dungeon Routes](https://github.com/Checkov23/ForeverDungeonRoutes), copyright (c) 2026 Checkov23, [MIT license](https://github.com/Checkov23/ForeverDungeonRoutes/blob/main/LICENSE). Dungeon map art is read from the client, not included.

### 1.5.49-preview
- Dungeon Position now also recognizes Dungeon Journal's standalone window. It still requires matching artwork and either an exact client position or a verified room anchor, and does not show a marker over unrelated dungeon art.
- /nqtdungeon reports which map window is open and the public area labels, so an unavailable position can be distinguished from a missing calibration.
- Ctrl-left-click now opens the native quest details without opening the map. Exact item associations and leftover badges work with stock bags and EnhanceQoL Bags. /nqtbag reports whether the badge setting is enabled, active-quest coverage is verified, and how many badges are visible.

### 1.5.50-preview
- Dungeon Position > Boss Target Marking lets the existing Smart Target key use Skull, then X, on living detected bosses in dungeons or raids where you have marking permission. It uses exact distance if the client reports it for all candidates, then available range checks, then a stable detected unit; it cannot scan undisclosed bosses. Enemy nameplates expand the visible candidates; target and mouseover also work.
- The optional Attack ping uses the same press. The stored mob and the standard character macro are unchanged. Boss marking is opt-in, only on genuine out-of-combat Smart Target presses, and is never attempted automatically or by reading game memory.

### 1.5.51-preview
- Boss Target Marking uses the original Auto Track action-bar macro as well as the Smart Target key. It now selects the boss by exact name before applying the marker and optional ping. The Stockade boss creature IDs are built in so they work even without Journal. Enemy nameplates or a manually selected boss are still required when the game does not expose a boss unit.

### 1.5.52-preview
- Recognizes visible dungeon bosses by verified NPC ID or exact known name even when a nameplate's identity is partly restricted. Stockade can also search known boss names on the existing press, starting with Targorr the Dread and Hamhock, then advancing after a miss. The default macro remains unchanged outside supported instances.
- An unreadable mark state no longer prevents target selection. The macro will skip changing raid icons when it cannot verify which icons are free.

### 1.5.53-preview
- Ctrl-left-click a bag item tied to one verified active quest to search for that exact quest in the Rank Quest floating log. A collapsed panel opens without capturing the keyboard, opening the stock quest window, or changing quest tracking.
- Boss marking reserves existing Skull/X assignments even when the first boss moves off-screen, and uses the selected boss explicitly for Attack pings. Built-in roster: 292 boss records across 35 dungeon/wing lists, checked against DungeonJournal 2.1.5, plus client boss units and the installed Journal's additional data when available.
- Nexus shows its own verified quest link and character status in the bag tooltip. Teronis' Journal (item 5505) links to Raene's Cleansing (quest 1023). This is not a deletion recommendation.

### 1.5.54-preview
- Boss Target Marking now uses all eight raid icons: Skull, X, Square, Moon, Triangle, Diamond, Circle, Star. It skips occupied icons, stops assigning icons when all eight are in use, and can free an icon when its boss is confirmed dead.

### 1.5.55-preview
- Boss icon priority: Skull, X, Triangle, Square, Diamond, Star, Moon, Circle. Recheck from Skull on every press and reuse a confirmed deceased owner's icon.
- An unreadable copy of a known or reserved owner no longer prevents marking the next boss. If a different unit's marker cannot be checked, leave marks untouched rather than risk overwriting. /nqtboss reports the prepared mark or why it is unavailable.

### 1.5.56-preview
- A confirmed mark removed from the boss you currently target now frees its old icon. The next press can apply the highest free icon to that boss again. Off-screen or unreadable state still does not clear a reservation.

### 1.5.57-preview
- Refresh the action-bar macro on WoW's actual marker-change event. A previously confirmed mark no longer has an extra half-second lock after being cleared on the selected boss; a positive read on a nameplate is valid confirmation too. Unknown or conflicting reads will not release another boss's mark.

### 1.5.58-preview
- Reconcile manual marker removals on visible bosses even when no boss is selected, using the same observable unit identity and marker-change event. If a selected boss's first mark was never confirmed, retry its own reserved icon instead of getting stuck. The macro no longer issues its extra dead-target clear command. /nqtboss also reports available verification for the last attempt.

### 1.5.59-preview
- Prevent the boss action-bar macro from rewriting itself during its active press, including if WoW reports a raid-icon change mid-macro. Removed the optional last-target restore line; a missed exact target no longer tries to restore a different target.

### 1.5.60-preview
- Do not reserve a second icon when the game reports a different existing mark on the acquired boss. Do not create untrackable anonymous reservations.
- Retry release/recovery follows raid icon priority, not Lua table iteration order. /nqtboss distinguishes a press with no marker command from a mark attempt and shows a recent game error if available. Targeting and pings remain unchanged.

### 1.5.61-preview
- Keep uncertain marks on their original owners. A missing icon read does not let Skull move to another living boss.
- Carry the exact native search name into the result when WoW hides the name and GUID from Lua. This keeps repeated presses advancing Skull, X, Triangle without changing the targeting or ping commands.

### 1.5.62-preview
- Smart Target keybind can try multiple unmarked boss names on one hardware press when the client hides its nearby units. Keep pressing to mark one additional boss per press in the usual icon order. The 255-byte macro limit can still require another press for later names. The regular action-bar macro retains its verified behavior.
- Stockade: try the official player-point API on the verified single floor even when the client doesn't report the current map ID, without overriding explicit icon rules. When no live position is available, Dungeon Journal can show a short-lived, clearly labeled last-known landmark for portal entry and uniquely mapped boss pulls. Reloads and roaming Targorr are not position signals.

### 1.5.63-preview
- On the Smart Target binding, try the full Stockade roster using the native secure macrotext action rather than the stored macro's shorter 255-byte format. If no unmarked boss responds, reacquire and ping the last reachable boss without moving its marker.
- The action-bar macro stays at 255 bytes and still probes one new hidden name per press, but now re-finds the last successful boss after a miss whenever the fallback fits.

### 1.5.64-preview
- Match Stockade floor 225 using the verified legacy game tiles or Dungeon Journal's matching map copy, even when Forever returns no map-art metadata. Render the live player point only if WoW provides one. The diagnostic now separates raw coordinate availability from artwork matching. Boss logic unchanged.

### 1.5.65-preview
- Use the fire-cat artwork when the owned Auto Track action-bar macro would show WoW's question mark. Leave a linked mob portrait or manually chosen icon alone.

## Standalone quest reference coverage
Built-in game APIs handle the normal quest log. The optional Questie integration fills extra data when available. The small handwritten bag lookup includes Goretusk Liver for Goretusk Liver Pie and Murloc Eye for Westfall Stew, individually checked against:
- https://www.wowhead.com/forever/quest=22/goretusk-liver-pie
- https://www.wowhead.com/forever/quest=38/westfall-stew

These lookups cannot cause an item to be marked safe to discard. No Wowhead database or drop-rate table is bundled.
### Optional drop-rate observations
Data from Everloot (https://everloot.app), CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/).
EverlootDrops.lua is the separately licensed adapted data. It holds only NPC/object IDs, item IDs, and observed counts; no game-file layer or install pseudonyms. Snapshots: https://everloot.app/database/download (November 14, 2026) and https://everloot.app/docs/api/rollups-drops (data as of November 26, 2026). Keep the credit and share this adapted data on the same license. Filters: public observations from at least three installs for NPC and object sources. For each item and source type, smaller samples fill gaps only when no source has at least 20 eligible windows. Newer observations replace older ones for the same source unless the older sample is the only one with at least 20 windows. Rates are rounded up for display; a range indicates that different sources have different rates. Counts were not pooled. An absent rate is unknown, not zero. Observed rates per eligible loot window are estimates, not game constants.

## Standalone map pins versus Questie Forever defaults

In Rank Quest settings, Show standalone map pins is on by default and hides the NQT layer when Questie is loaded. Where Forever reports them, NQT shows available starts, active quest/waypoint pins, ready turn-ins, flight masters, and service POIs. It avoids drawing over detected stock quest pins. Outdoor minimap placement uses the client's position and view radius and does not draw when those values or rotation are unavailable. The world map shows cursor coordinates while supported.

Additional observed service pins: 12 innkeeper, 39 flight-master and 51 mailbox records. Coordinates are approximate interaction points, not exact spawns. Known factions are filtered; a mailbox or inn with unknown affiliation does not imply access. Observed quest givers is a separate off-by-default option, with 61 recorded locations. These are prior observations, not proof the quest is offered to your character.

Data from Efficient Games (https://efficient.games), licensed under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/). The separate ForeverTownPins.lua data is adapted from https://github.com/JIVESCORP/eg-link-output-wowf/tree/main/data/wowf (Forever builds 1.60.1.70959, 1.60.1.71037, 1.60.1.71091). Numeric positions and service interactions only; no names or quest prose. Filtered to supported categories and coherent coordinates; observed giver inclusion requires the location across two snapshots.

Audit: Questie Forever 12.15.0 defaults enable quest/available starter-item/object/monster/event/turn-in pins, party objectives, NPC patrol paths, map and minimap icons, world-map coordinates, map controls and next-chain/NPC quest tooltips. It also enables innkeepers, flight masters, mailboxes, meeting stones; most other services are off by default. Fresh Questie allows repeatable, event, dungeon, raid and PvP quests where eligible, not AQ/SoD extras. This preview does not claim full parity: broad remote availability and prerequisite/phase logic, starter-item source pins, complete per-mob/object spawns, party-only map points, patrol paths and full service/meeting-stone coverage still need verified data. You can keep Questie for those and use Rank Quest normally.


### Additional quest turn-in reference coordinates

Selected turn-in references adapt coordinates from [AllTheThings WoW Addon](https://github.com/ATTWoWAddon/AllTheThings), Forever source snapshot 0b14eb6ccb55d16c48531bed794735bf97100441, verified against the exact Forever quest and entity records. These references are not native GPS pins.

```
MIT License

Copyright (c) 2026 AllTheThings WoW Addon

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### Supplemental quest endpoint pack
ForeverVerifiedEndpoints.lua is adapted under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) from [wow-completionist-data](https://github.com/danielalanbates/wow-completionist-data/tree/64feae0e472c5b615e72e682ce470df03d485056) by Daniel Bates and contributors and [Warcraft Wiki](https://warcraft.wiki.gg) contributors. The Lua file records applicable Wiki revision IDs; view them via https://warcraft.wiki.gg/index.php?oldid= plus the revision number. Numeric locations use corroborated [Efficient Games](https://efficient.games) Forever observations (CC BY 4.0) where available. NQT selected, cross-checked and normalized this subset; it contains no third-party quest text. Coordinates are fallback references; NQT uses the client to verify navigation pins for these entries.

### Quest mob names and drops

Rank Quest shows known corpse-drop mobs under the item. Click a listed mob or a verified kill objective to set the exact saved Auto Macro name; this doesn't target, mark, or ping the mob. The saved-name lock and combat restrictions still apply. Hover the owned action-bar macro to see its saved name and any available mob details. The bundled English creature names, observed classifications and levels, and named quest corpse-drop links in `QuestMobData.lua` were adapted from [Efficient Games' live Forever data](https://github.com/JIVESCORP/eg-link-output-wowf/tree/1339ce5600bbc2b12e8f1081e584f548f62fa57f/data/wowf) under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Drop-source names are observations, not an exhaustive list.
