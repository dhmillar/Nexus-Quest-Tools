# Changelog

## 1.5.210

- Rank Quest compares ready turn-ins using actual hand-in locations on a common yard scale when available. Known NPC endpoints participate in ranking; old objective distance cannot outrank a measured hand-in.

## 1.5.209

- With Focus Close Completed Quests enabled, ready turn-ins beyond 100 yards now compete by distance with unfinished quests instead of being ignored. Turn-ins within 100 yards still have priority.

## 1.5.208

- Rank Quest no longer announces quests that are already ready to turn in on acceptance. Quests completed after acceptance still announce in party chat.

## 1.5.207

- Added clickable portraits and objective lines for identifiable quest NPCs in Rank Quest, including Saving Marshal Ryan. Click to target, mark with a diamond, and ping out of combat without changing Auto Macro.

## 1.5.206

- Paladins can right-click the Smart Buff reminder and pick a named character's blessing directly, without opening Settings. Left-click still casts the suggested buff out of combat.

## 1.5.205 - 2026-11-27

- Rebuilt settings as a larger, MapWise-inspired window with a gold-edged category rail, bigger controls, and separate sections for Smart Buff, Hunter tools, and Pet health.
- Smart Buff reminder now has size, icon-only, preview, and reset controls. It hides when no monitored buff is missing, unless Preview / Move is active.
- Paladin overrides now accept full two-part Forever names, with a separate blessing choice for each character.
- Left-click the reminder to cast the suggested buff outside combat. Paladins can right-click it to open the suggested character's assignment.

## 1.5.204 - 2026-11-27

- Added Classes settings for Hunter Deadzone, Pet Bar, and Smart Buff. Smart Buff offers a movable reminder and an action-bar macro that casts the next recommended learned buff per press outside combat.
- Paladin blessing assignments support class defaults and character-name overrides, including a skip option. Other classes use their own spell rules without per-recipient class settings. Rogues get manual weapon-poison reminders.

## 1.5.203 - 2026-11-27

- Clickable quest items in Rank Quest show the time remaining on cooldown directly on their icons. The countdown clears when the item is ready, and the click behavior is unchanged.

## 1.5.202 - 2026-11-27

- Added **Focus Close Completed Quests** to Rank Quest settings, off by default. When enabled with Auto Focus, the nearest ready turn-in within 100 yards takes priority. Rank Quest shows Completed while focused on a nearby turn-in and returns to In Progress once none remain in range.
- Checks additional client map sources for ready hand-ins, so an eligible quest is not skipped just because its pin is absent from the local map. Manual tracking and the tracking order still take priority.

## 1.5.201 - 2026-11-27

- Auto Focus compares the distance to quest objectives and ready-to-turn-in locations. A closer hand-in can take focus beyond the 100-yard highlight radius. Explicit selections and tracking order still take priority.

## 1.5.200 - 2026-11-27

- Fixes pet name and owner subtitle flicker by suppressing only those text regions. Plater retains control of its frame opacity and visibility.

## 1.5.199 - 2026-11-27

- Hides the duplicate name and owner subtitle drawn by Plater for your active pet while Pet Bar is visible. Other Plater units and settings are unchanged.
- Retries Pet Bar setup after login, reload, and pet changes, including when another addon reapplies the friendly-pet category during startup.

## 1.5.198 - 2026-11-27

- Shows only your active pet’s name above the Pet Bar, replacing the stock owner label. The health display and nameplate settings are unchanged.

## 1.5.197 - 2026-11-27

- Fixes the Pet Bar rendering path when WoW supplies a pet nameplate but the addon fails to draw health. The bar no longer inherits stock nameplate transparency and supports the client’s native health display API when raw health cannot be used. Nameplate settings are unchanged.

## 1.5.196 - 2026-11-27

- Pet Bar requests only the friendly-pet nameplate category outdoors, leaving the friendly-player and NPC settings untouched. Stock graphics are hidden only on confirmed friendly pet nameplates. The game still controls nameplate availability and instance restrictions. The previous pet category setting is restored when NQT no longer needs it.

## 1.5.195 - 2026-11-27

- Pet Bar now follows the active pet’s visible nameplate instead of floating below screen center. The slim bar shows only the health percentage, bright green at 50% or higher and red below. Enable friendly/minion nameplates if the game is not showing the pet’s plate.

## 1.5.194 - 2026-11-27

- Added Pet Bar under General, off by default. The thin bar shows your active pet’s health from 0% to 100%, green at 50% or more and red below 50%. It does not replace the stock pet frame.

## 1.5.193 - 2026-11-27

- Keeps Rank Quest highlighted when stepping out of a quest area, using a 100-yard buffer from the last confirmed in-area position instead of relying only on the map pin.
- Resolves drop portraits by exact item source when creatures share a name. Crawler Spittle now uses the Riverglades Shore Crawler, not the generic fallback.

## 1.5.192 - 2026-11-27

- Highlights outstanding quest purchases at their verified merchants with a gold box and a bottom-right exclamation mark. The highlight clears on completion, paging, buyback, and close as appropriate. Nothing is purchased automatically.
- Coalesces Rank Quest startup refreshes and lays out the tracker before showing it to reduce reload flicker.

## 1.5.191 - 2026-11-27

- Fixed vendor objective clicks that selected a neutral merchant but skipped the diamond and Assist ping. The same click now requests both for a living, non-hostile target. It still leaves Auto Macro unchanged.

## 1.5.190 - 2026-11-27

- Rank Quest shows a merchant portrait and an (NPC) label for verified buy objectives. Click the portrait or objective line to target, diamond-mark and ping the merchant within client range, out of combat and subject to group permissions. The saved Auto Macro target is unchanged.
- Added verified sources for Flagon of Dwarven Honeymead, Fel Elemental Rod, and the three purchased ingredients in Goes Down Smooth. Crawler Spittle remains a creature drop.

## 1.5.189 - 2026-11-27

- Added nine Riverglades quest pickups and eleven fallback turn-ins, including Eye of Mugg and Tome of Twilight. Corrected five supplied items that were misidentified as quest starters.
- Added two outdoor library book pickups in Eastern Plaguelands and the observed Horde return for The Knight and the Lady.
- Cuergo's Gold identifies the crafted map and the Tanaris pickup and turn-in areas without pretending the chest has only one spawn.

## 1.5.188 - 2026-11-27

- **Scholomance:** Added Eva Sarkhoff’s pickup and return directions for Doctor Theolen Krastinov, Krastinov's Bag of Horrors, and Kirtonos the Herald. Blood of Innocents remains the summon item, not the quest starter. Fallback hand-ins do not replace live game pins.
- **Level Guide:** Added the verified pickups for Vivian Lagrave, Get Me Out of Here!, and Buzzbox 525.

## 1.5.187 - 2026-11-27

- **Riverglades:** Added five pickup locations and seven fallback hand-ins, covering Sergeant Riftan's chain, Drink Up!, Her World, and Frazzlespark's Crate. Drink Up! starts with Innkeeper Zizplink, not the Frothing Mug he gives you.
- **Eastern Plaguelands:** Added Betina Bigglezink as the giver of The Active Agent and as the fallback turn-in for The Flesh Does Not Lie, The Active Agent, and Healthy Dragon Scale. Fallback locations do not replace live game pins.

## 1.5.186 - 2026-11-27

- **Dungeon quest pickups:** Level Guide and Share Verify now identify the vault in the Reliquary of Kings for The Treaty of Understanding, and the underwater Moonshrine Ruins for both Baron Aquanis quest variants. Room directions don't create guessed map pins.
- **Turn-in:** Rank Quest now has an Alliance fallback for King Magni Bronzebeard in Ironforge for The Treaty of Understanding when no live pin is available. The reference doesn't create a GPS route.

## 1.5.185 - 2026-11-27

- **Level Guide:** Added three quest-giver pins for follow-ups in the profession-sign chains: Rotgath Stonebeard in the Great Forge, Jornah in The Barrens, and Karolek in Orgrimmar. The guide keeps the two A Quick Craft quests separate by faction.

## 1.5.184 - 2026-11-27

- **Quest turn-ins:** Added six fallback hand-ins across the Alliance and Horde profession-sign chains. Rank Quest can show the correct recipient when the game omits its live pin. Elaine Compton has an area label only because the recorded coordinates disagree; approximate references do not create GPS routes.

## 1.5.183 - 2026-11-27

- **Quest turn-ins:** Completed faction coverage for two A Sealed Crate quests. Alliance characters are directed to Marcy Baker in Redridge Mountains and Horde characters to Dokimi in The Barrens when the game does not return a live hand-in pin.

## 1.5.182 - 2026-11-27

- **Quest turn-ins:** Added four observed hand-in references in Tanaris and Eastern Plaguelands, including the separate Super Egg-O-Matic object quest. Corrected Lost Shipping Crate and A Few Furs for Friz to use Alliance-only Friz Frazzlespark hand-ins in Riverglades. Observed references do not create native GPS routes.

## 1.5.181 - 2026-11-27

- **Level Guide pickups:** Theocritus’ Retrieval now highlights two observed Redridge pickup areas for the Glowing Shadowhide Pendant. It does not show a drop percentage from the small samples. The Horde version of Sign Me Up! now points to the correct Advertising License Application sold by Gishah in The Barrens. Neither reference sets native GPS.

## 1.5.180 - 2026-11-27

- **Level Guide pickup maps:** Added highlighted pickup areas for Sully Balloo’s Letter (Waterlogged Letter, Thandol Span), Attack on Camp Narache (Dirt-stained Map, Brambleblade Ravine), and Sign Me Up! (Alliance vendor Tamelyn Aldridge, Three Corners). Vendor pickups are labeled as purchases, not monster drops. Pickup references do not set native GPS waypoints.

## 1.5.179 - 2026-11-27

- **Drop rates:** 24 quest-item and monster party samples across 16 quests. The percentages show only observed party loot and do not claim solo odds.
- **Quest starts:** Corrected the starting item for Theocritus’ Retrieval, Sully Balloo’s Letter, Attack on Camp Narache, and Sign Me Up! No unverified pickup areas were added.
- **Turn-ins:** Added Betina Bigglezink for Plagued Hatchlings with an observed location and Lorekeeper Lydros in the Athenaeum for Arcane Refreshment. The Athenaeum entry is area-only.

## 1.5.178 - 2026-11-27

- **Rank Quest portraits:** Added 27 verified monster portraits across 18 quests, including Cirrusfly Queen, Roiling Winds, Living Lightning, and all five Hatefury mob entries. The portraits display from quest data without needing to target the mob first.

## 1.5.177 - 2026-11-27

- **Rank Quest portraits:** Added missing display IDs for 1,736 bundled mob records, including Seeking Remnant, Saturated Remnant, and Mana Echo. Kill objectives use exact quest creature IDs when identical names have different portraits, including the Riverglades Redridge Brute.
- Quest icons and hover previews can use the same live portrait as the macro when the matching mob is targeted. This updates only portraits, not the whole quest list. Unknown drop sources still do not get guessed portraits.

## 1.5.176 - 2026-11-27

- **Nearby turn-in tracking:** Uses WoW's same-continent quest distance when a ready quest has no turn-in pin and the map does not show an unfinished objective. Distance-only tracking never supplies guessed GPS coordinates.
- Ready quests can be found under collapsed log headers. The stock tracker is asked to watch the current nearby turn-in when needed to switch; the temporary watch is removed when focus moves on.
- Being inside a broad objective area no longer counts as zero yards when comparing that quest with a nearby turn-in.

## 1.5.175 - 2026-11-27

- **Nearby turn-ins:** A ready quest now joins automatic nearest-quest selection within 100 yards of its verified hand-in location. It can also highlight and sort as nearby in Rank Quest's Completed view.
- Uses the hand-in point for GPS, not the old objective. Manual tracking and the tracking order still take priority. No completed watch is added to the stock tracker by this feature.

## 1.5.174 - 2026-11-27

- **Rank Quest loot data:** Added verified party loot observations for Bloody Bone Necklaces, War on the Woodpaw, and Power Stones. Percentages are labeled as party samples with the number of loot windows. Observations were not pooled across builds or carried over to other quests.

## 1.5.173 - 2026-11-27

- **Rank Quest party chat:** Announces all quest completions with your Primary raid marker, including delivery, exploration, escort, and quests without objective counters.
- Announces a newly ready quest once. If it was turned in before the quest log showed it as ready, the turn-in event supplies the confirmation. Kill and collection milestones are still shown on unfinished quests.

## 1.5.172 - 2026-11-27

- **Rank Quest:** Announces newly completed kill or collection objectives in party chat with your chosen raid marker. On by default; switch it off in Rank Quest settings. It does not replay already-completed objectives.
- **Smart Target:** Checks the client's current soft target and tracks visible nameplate tokens from game events, so more eligible mobs can be targeted, marked and pinged on the first press. If the mob is only revealed by native name search, marking and pinging still require a second press so tapped mobs are not tagged.

## 1.5.171 - 2026-11-27

- **Smart Target:** Skip mobs tagged by another group and select a readable, eligible match on the same out-of-combat keypress. A tagged selection no longer overwrites the saved name.
- Smart Target now looks at pet and party targets in addition to visible enemy nameplates, focus and mouseover. It no longer falls back to an unfiltered name search after choosing an eligible unit.
- The raw mouse-click macro and in-combat fallback still use WoW’s native name recall, which has no tap filter. The dungeon boss macro is unchanged.

## 1.5.170 - 2026-11-27

- **Questie independence:** Removed all live Questie and QuestieDB calls and load declarations, including spawn scans, tracker hooks, map-pin suppression, menu actions, and database lookups.
- **Rank Quest and Level Guide:** Use Blizzard's quest APIs and NQT's bundled Forever records. Known drop rates, quest origins, turn-ins, bag links and world-map pins remain available without Questie. Unsupported data remains unknown.
- **Tests:** Verified the standalone paths offline, including a simulated loaded Questie. This release does not claim to resolve the reported in-game stutter.

## 1.5.169 - 2026-11-27

- Rank Quest no longer rebuilds the full list on unchanged party snapshots. Background checks are spread across ticks, and party events still refresh live progress.
- The walking route updates less often and does no periodic work when turned off.
- Optional stutter diagnostics: run `/nqt perf start`, reproduce the hitch, then run `/nqt perf stop`. Results print locally in chat.
- Offline regression tests passed. In-game verification of the reported stutter is pending.

## 1.5.168 - 2026-11-27

- **Performance:** Removed idle bag scans from the quest-starting item popup, stopped rebuilding the full drop-name index during quest updates, and batched routine quest and map refreshes. Offline regressions passed; in-game stutter on affected setups is not yet confirmed resolved.
- **World map:** Clicking a quest is a manual focus change. A selected completed quest stays tracked for turn-in after the map closes.
- **Rank Quest drop rates:** Resolves known item IDs even when the English item cache is empty. Added Riverglades loot observations with solo/party and small-sample labels, and separate Wowhead-reported references for Farmers’ Mementos and Damaged Locket.
- **Quest data:** Refined Damp Note and Excavation Tools pickup areas, added room hints for both Crest of Lordaeron starters, and corrected several turn-in references.

## 1.5.163 - 2026-11-27

- **Rank Quest:** Automatically follows the closest unfinished quest with a known distance, even outside the highlight range. A manual pick stays active until its objectives are complete; explicit tracking order still takes priority over distance.
- **Quest-starting item popup:** A newly acquired quest starter can appear above your character. Click the item to open WoW’s quest offer. Accepting the quest clears the icon immediately. On by default in Rank Quest settings; right-click to dismiss.
- **Share Verify:** Shows the quest level and available starter details, such as giver, coordinates, or item pickup area. Offers stay visible as pending until WoW confirms acceptance or ineligibility, or the offer times out.
- **Minimap:** Removed the separate quest panel under the minimap. The route line and yard count are unchanged.

## 1.5.158 - 2026-11-26
- Rank Quest: bulk sharing verifies party quest ownership. Added Share Verify, per-quest and inline party Share buttons, pending offer deduplication, acceptance refresh, and handling for explicit WoW completion and eligibility replies.

## 1.5.157 - 2026-11-26
- Rank Quest: added the green Share Quests menu for the full log, the current zone or dungeon, and all dungeon quests. Uses native shareability checks, paced offers, and a Stop Sharing action.

## 1.5.156 - 2026-11-26
- Nearby auto-focus and Rank Quest highlights share a 100-yard objective check; current focus holds through 125 yards. Auto-focus recognizes confirmed quest areas and parent-zone waypoints when native distance is missing. Manual focus and tracking order still take priority.

## 1.5.155 - 2026-11-26
- Removed the floating Smart Target bar. Existing action-bar macro placement and keybinds are unchanged.

## 1.5.154 - 2026-11-26
- Rank Quest reconciles confirmed native party completion with stale shared progress and refreshes retained quest rows without a hover. Completion events also trigger party sync after the log confirms readiness.

## 1.5.153 - 2026-11-26

- Level Guide: map pickup areas for 31 additional item-start quests since 1.5.149, including Field Marshal's Log, Furlbrow's Deed and The Admiral's Orders. Separate patrol areas stay separate; approximate circles do not become exact GPS points.
- Corrected starter items that were confused with objectives. The Admiral's Orders starts from the Aged Envelope in Benedict's Chest, not the orders you deliver.
- Added 219 numbered conversation and game-object objectives across 102 quests. In-game progress still takes precedence.
- Rank Quest: added 50 turn-in references, including Krom'rosh for Farholde Scouting Report. Native waypoints remain authoritative.
- Updated quest facts, item associations and measured drop rates without mixing solo loot windows, group loot windows and individual kills. Unknown locations and rates are not guessed.


## 1.5.149 - 2026-11-26

### Level Guide
- New layout: full-height Location list on the left, a larger center map, and Quests and Quest Details stacked on the right. Scroll each list directly.
- Matched Maximize and Close controls, same-size Scale and Solo controls, and adaptive text fit. The Scale slider stays fixed while you adjust it.
- Selecting a quest pulses its normal-sized start icon inside a gold ring. Recorded quest starters and coordinates appear in the list and details, including dungeon quests started outside the instance. Recorded item-start quests can highlight a pickup area instead.
- NPC Icons now shows available counts for the displayed map and draws the markers above the terrain. Missing location data is not guessed.

## 1.5.144 - 2026-11-26

### Level Guide and Rank Quest
- Open NQT Level Guide from the map-book button in Rank Quest. Browse zones and dungeons, compare solo and party recommendations, filter by quest type, and open individual objectives.
- See eligible quest-start pins and optional service markers on the guide map. Track routes to a known quest start or highlights a recorded item-drop area. Markers appear only where the guide has a location.
- Rank Quest has a unified Zones menu with quest counts, more readable objective tooltips, and clickable monster portraits or objective text that can set the Auto Track macro.

### Fixes and data
- Improved standalone quest data for item use, drop rates, dungeon classification and turn-ins. Missing or uncertain facts are not presented as confirmed.
- Refined party objective counts and completion, targeting, and tooltip behavior. No save migration or folder rename is needed from an existing NQT installation.

## 1.5.143-preview - 2026-11-26

- The Level Guide map now adds the native terrain details normally hidden until exploration, using bundled Forever map references without requiring OpenMap. No game textures are redistributed.

## 1.5.142-preview - 2026-11-26

- Selecting a Level Guide quest opens its objectives below the map. Held quests use the game's exact text and live progress; unaccepted quests use recorded objectives and required counts where known.
- Replaced observed level ranges with the bundled OpenMap zone level ranges. Maps without a published range no longer show a guessed band. Removed the two unnecessary recommendation/location messages.

## 1.5.141-preview - 2026-11-26

- Expanded the Level Guide’s map to the right half of the window. Kill, Collect, Mixed and Other are compact click-to-filter buttons. Click the selected type again to clear it.
- Removed D markers from dungeon rows. Dungeon quests use the same quest-giver routing and can display verified outdoor or in-dungeon starter locations; a compatible installed quest database can supply missing, unambiguous NPC positions.

## 1.5.140-preview - 2026-11-26

- Select a Level Guide quest to preview its known quest start on the guide's own fully revealed terrain map without changing active tracking. Use the map's zoom buttons or mouse wheel and drag to pan.
- The default-checked In Quest Log filter hides held quests and removes them from displayed counts. Uncheck it to show held quests again.

## 1.5.139-preview - 2026-11-26

- Fixed the Level Guide Maximize/Restore control receiving clicks under the draggable title bar. The control now matches the gold-framed red Close button and uses separate maximize and restore icons.

## 1.5.138-preview - 2026-11-26

- Leveling suggestions filter out faction-ineligible, gray and low-reward quests.
- Quest rows show verified quest-giver locations and can set an active waypoint. Alternate-level copies are collapsed when their objective identities match.
- The Level Guide scales the entire interface when resized. Use the square next to Close to maximize it to the game screen; click again to restore the previous size and position.

- Applied Forever hotfix corrections: Agamaggan's Blood is an outdoor quest, the shared quest drops for Coyote Huntin' and A Heart of Crystal no longer get a personal-loot penalty, and the repeatable Water Pouch Bounty contributes zero quest XP. Unending Torment uses the Horde minimum level of 15.

## 1.5.137-preview - 2026-11-26

- Level Guide uses eligible quests across the full quest catalog in its scores and totals, not just quests in the log. It separates offers shown by the game from quests that fit the character's level and known unlocks.
- Objective types prefer live quest objectives, recognize collection and kill tasks separately, and retain the quest type when its objectives are finished. Turned-in quests leave the list and totals; ready turn-ins remain.
- Restyled the guide with a large route recommendation, native artwork, objective badges and progress bars. Drag the bottom-right grip to resize and save the window size.
- Dungeon quest lists show unfinished quests assigned to that particular dungeon and currently within reach, not unrelated quests from the surrounding zone or pickup location.

## 1.5.136-preview - 2026-11-26

- Rank Quest settings include an illustrated Level Guide. Use For You for character-specific questing recommendations, Browse Zones to filter by name and level range, and Dungeons for five-player ranges and quest plans.
- Recommendations consider level, confirmed offers, active and completed quests, likely XP, objective mix and known solo drop rates. Solo, 2 players and 3 players estimate different questing pace from shared kills and personal collection effort. Catalog leads are shown separately from confirmed quests.

## 1.5.135-preview - 2026-11-26

- The Rank Quest Zones menu expands to fit its entries, up to the bottom of the quest log. Scroll only when the list is taller than the available space.
- The Zones menu shows your in-progress and ready-to-turn-in quest counts at the right of each zone, dungeon, and top-level filter.

## 1.5.134-preview - 2026-11-26

- Clicking a verified mob-kill or monster-drop objective in Rank Quest now sets Auto Macro without changing text colors. Hovering the text shows the same portrait and click hint as its mob icon. Text on items with several sources uses the first displayed mob; individual portraits still select their own mobs.

## 1.5.133-preview - 2026-11-26

- Increased inline Rank Quest mob portraits from 13 to 18 pixels, with matching hitboxes. The larger hover portrait is unchanged.

## 1.5.132-preview - 2026-11-26

- Hovering a clickable quest mob shows a larger portrait before its name and Auto Macro hint, without enlarging the inline icon.

## 1.5.131-preview - 2026-11-26

- Rank Quest gives objective portraits more breathing room. Verified kill objectives set Auto Macro through the mob portrait, not the objective text.

## 1.5.130-preview - 2026-11-26

- Rank Quest replaces drop-source lines with compact 13-pixel clickable mob portraits beside each item objective. Hover shows the mob name; an overflow menu lists additional sources. Removed leading dashes from objective text in both themes.

## 1.5.129-preview - 2026-11-26

- Auto Macro shows known mob portraits directly from Rank Quest selections, without selecting a live target. Live portraits take precedence.

## 1.5.128-preview - 2026-11-26

- Rank Quest: one Zones dropdown with Current Zone, All Zones and All Dungeons pinned above separate Zones and Dungeons sections.
- All Zones groups all logged quests, including dungeon branches. All Dungeons groups only dungeon quests.
- The minimize button is always visible. Hover the compact Rank Quest title for Click to show Settings.
- Known drop mobs and kill objectives can set Auto Macro. Hover the macro for its saved target and known mob information.
- Shady Saltseers groups under The Drowned City. Removed source references from in-game tooltips; credits remain in documentation.

## 1.5.127-preview - 2026-11-26

- Added eight measured drop-source rows from Everloot and refreshed 27 with larger samples.

## 1.5.126-preview - 2026-11-26

- Added five ready-quest area/recipient labels for Alcaz Prison and Gnomeregan.

## 1.5.125-preview - 2026-11-26

- Show verified dungeon area and recipient without Questie when no precise pin exists, across 19 quests. Only NPC names attach the existing targeting action; GPS never uses an area-only reference.

## 1.5.124-preview - 2026-11-26

- Added another 38 corroborated Forever turn-in map references.

## 1.5.123-preview - 2026-11-26

- Added 62 corroborated Forever turn-in references and candidate map lookups for native GPS.

## 1.5.122-preview - 2026-11-26

- Added 11 more usable quest-item links from exact game quest instructions matched to unique quest-class items and live-confirmed On Use spells. Includes Book of Aquor and the Extra-Dimensional Ghost Revealer; no item fires without a click.

## 1.5.121-preview - 2026-11-26

- Refreshed Everloot quest objective drop coverage from a consistent ten-page Forever snapshot. Added 53 source/item pairs including 10 items with no prior Everloot measurement, and replaced 42 strictly smaller samples. No pooling, Classic substitution, or inferred zeros.

## 1.5.120-preview - 2026-11-26

- Added 78 more clickable turn-in references by matching exact NPC and quest IDs in the Forever edition of AllTheThings to the recipient named in the Forever server objective. Existing native pins and stronger observations still win.

## 1.5.119-preview - 2026-11-26

- Added 29 opened-loot-window samples for grouped quest objectives across 20 quests. Rank Quest uses the group sample only when grouped, distinguishes it from solo per-kill estimates, and names the source and sample size in the tooltip.

## 1.5.118-preview - 2026-11-26

- Added 246 quest-supplied item/On Use links. Rank Quest shows a clickable button when a still-active unfinished quest provided the item, it is in the bags, and the live client confirms the expected use spell. The native quest button and observed-use pack retain priority.

## 1.5.117-preview - 2026-11-26

- Added 221 quest-specific NPC turn-in references from named Forever delivery objectives joined to separately observed NPC locations, plus three cross-checked Westfall references. These are used only for completed quest display and do not drive GPS without a matching native pin.

## 1.5.116-preview - 2026-11-26

- Added quest-specific Forever drop estimates for 16 quest/item pairs from 19 qualified Efficient Games creature samples. Counts, client build, and source are shown in the tooltip. Samples are not combined across builds or applied across quests.
- Added independently corroborated turn-in references for A Lesson to Learn and A Dark Threat Looms. These show coordinates and clickable NPC names without routing to a non-native reference.

## 1.5.115-preview - 2026-11-26

- Rank Quest All Zones places dungeon quests in their dungeon branches instead of their pickup zones. Dungeon quests stay in their collapsible branches even when focused or highlighted.

## 1.5.114 (local preview) - 2026-11-26

### Standalone quest coverage
- Removed the tilde before turn-in coordinates. Drop percentages remain whole numbers without a tilde.
- Audited 5,635 catalog IDs. Older recorded Forever offers and turn-ins fill gaps without replacing three newer snapshots. Added 933 recorded starters and 867 usable unambiguous turn-in locations within the audited catalog.
- Rank Quest now displays multiple verified usable quest items on a row. Native quest-use actions remain first; standalone observations cover 99 quest-item pairs for 93 quests, requiring live bag possession and the matching use spell. Uses still require a player click and Blizzard's restrictions apply.

## 1.5.113 (local preview) - 2026-11-26

### Hotfixes
- Added an approximate turn-in location and clickable NPC for Akiris by the Bundle, part 2, when the native map has no turn-in data.
- Bag tooltips now identify verified quest rewards and provided items, including Translated Letter from The Embalmer (reward from Translation to Ello).
- Retains exact abandoned quest-item evidence across reloads. Amber review no longer requires unrelated quest metadata or a repeatability response for the recorded removal. Trash badges still require stronger completion evidence.

## 1.5.112 (local preview) - 2026-11-26

### Hotfixes
- Turn-in NPC names now come from explicitly localized records or the live client, not mixed-language observations. Fixed Bloom of the Heavens to show Thundris Windweaver in English. If the right locale name is unknown, show the location without offering a broken target action.

## 1.5.111 (local preview) - 2026-11-26

### Hotfixes
- Quest Cleaner uses verified standalone objective links and live completion status for bag trash badges without Questie. Protects current, future known, starter, reward, repeatable, and uncertain uses. Amber means a previously held but uncompleted quest item needs review, not that it is safe to discard.
- Ctrl-click opens all verified matches still in the player's quest log; ambiguous name-only matches are not guessed. Related quests that are not held remain in the bag tooltip.

## 1.5.110 (local preview) - 2026-11-26

### Standalone quest data
- NQT quest-start exclamation marks are on the world map only. NQT no longer adds any point-of-interest pins to the minimap.
- Added numeric Forever quest facts for 5,619 quests, including 3,369 quests with item objectives. Ctrl-click can resolve known held quest items without Questie, including under collapsed headers. Known numeric quest levels back up the live log. Observed starter pins respect known minimum levels. Drop rates still require actual observed loot data; unknown rates remain blank.

## 1.5.109 (local preview) - 2026-11-26

### Hotfixes
- NQT's minimap pins now show quest-start exclamation marks only. Native starts are preferred; known NPC and object offers supplement them even with Questie off. Recorded offers do not guarantee eligibility.
- Ready-to-turn-in quests can use recorded NPC and object turn-ins without Questie. Use the native pin coordinates when presented; only attach a clickable NPC when the finisher is unambiguous. Data from Efficient Games, CC BY 4.0.

## 1.5.108 (local preview) - 2026-11-26

### Changes
- The Rank Quest party button now shows or hides compact name-and-count lines only. Hover details and retention until the party finishes are unchanged.
- Removed the redundant Edit target name and Save selected mob buttons from Auto Macro settings. Existing target controls still work.

## 1.5.107 (local preview) - 2026-11-26

### Hotfixes
- Rank Quest sends updated objective counts to the current party when WoW confirms pickups or other objective changes. Updated clients display those counts instead of stale tooltip numbers.

## 1.5.106 (local preview) - 2026-11-26

### Hotfixes
- Rank Quest shares confirmed completion, removal, and reacceptance with current party members running the updated addon. Completed members no longer keep a row open because of old progress. Native party progress remains the fallback for members without the update.

## 1.5.105 - 2026-11-26

### Hotfixes
- Smart Target no longer lets a mob with unknown distance make it ignore measured distances for other mobs with the saved name. It can use exposed same-map positions and, if already loaded, LibRangeCheck for additional range information. When the client only provides range bands, the nearest choice is approximate.
- Tap checks, marking, pinging, mute settings, and dungeon boss targeting are unchanged.


## 1.5.104 - 2026-11-26

### Changes
- Rank Quest keeps your tracked quest first, promotes nearby objectives as you move, and sorts each group from lowest to highest quest level.
- Drop rates display as whole percentages, rounded up. The standalone Forever database now has observed rates for 1,150 item IDs across 1,932 NPC/item and object/item pairs. Unknown rates stay blank. Optional QuestieDB data can identify items even with the Questie tracker disabled.
- Added standalone world map and outdoor minimap pins for supported quests and services. Historical quest-giver sightings are optional and do not indicate quest availability.
- The existing stock Auto Track hotkey automatically runs Smart Target out of combat. It can search for the saved mob without a selected target. If the game will not expose tap status before selection, the first press recalls the mob and the next can mark or ping it after checking.

### Hotfixes
- Restored Mute macro sounds on the regular Smart Target hotkey.
- Removed redundant area labels from Rank Quest. Nearby highlights and progress text remain.
- Dungeon boss targeting, mark rotation, and ping logic are unchanged.

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
