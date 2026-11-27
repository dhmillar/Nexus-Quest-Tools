local _, AT = ...
local panel, minimapButton, checks, status, targetStatus, primaryChoice, markerStatus
local deadzonePreviewButton, deadzonePreviewHint
local titleColor = {0.26, 0.88, 0.80}

local function refreshPanel()
    if not panel or not panel:IsShown() then return end
    for key, check in pairs(checks) do
        check:SetChecked(AT.db[key])
        local subDungeon = key == "dungeonMapMinimap" or key == "dungeonPositionAutoOpen" or key == "dungeonPositionShowSelf" or key == "dungeonPositionShowParty"
        check:SetEnabled(key == "enabled" or AT.db.enabled and (not subDungeon or AT.db.dungeonPositionEnabled == true)
            and (key ~= "bossMarkPing" or AT.db.bossAutoMark == true))
    end
    if deadzonePreviewButton then
        local preview = AT.IsHunterDeadzonePreview and AT.IsHunterDeadzonePreview()
        deadzonePreviewButton:SetText(preview and "Done Moving" or "Preview / Move")
        deadzonePreviewHint:SetShown(preview == true)
    end
    local id = AT.GetFocusedQuestID and AT.GetFocusedQuestID()
    local title = id and C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
    if issecretvalue and issecretvalue(title) then title = nil end
    status:SetText(not AT.db.enabled and "Paused" or not AT.db.autoFocus and "Nearby focus is off" or
        (id and ("Focused: " .. (title or ("Quest #" .. id))) or "Scanning for a nearby quest..."))
    local current = AT.GetTargetName and AT.GetTargetName()
    targetStatus:SetText(current and current ~= "" and ("Saved target: " .. current .. (AT.IsPartialTarget and AT.IsPartialTarget() and " (partial)" or "")) or "No target saved")
    if primaryChoice and AT.GetPrimaryMarker and AT.MarkerNames then
        local label = AT.MarkerNames[AT.GetPrimaryMarker()]
        local secondary = AT.GetSecondaryMarker and AT.MarkerNames[AT.GetSecondaryMarker()] or "X"
        local notice = AT.GetMarkerPingNotice and AT.GetMarkerPingNotice()
        primaryChoice:SetText("Primary marker: " .. label)
        markerStatus:SetText(notice or ("Mouseover secondary marker: " .. secondary))
    end
end

local function updateState()
    if AT.RefreshSmartTargetButton then AT.RefreshSmartTargetButton() end
    if AT.RefreshSmartTargetBarKeys then AT.RefreshSmartTargetBarKeys() end
    if AT.RefreshQuests then AT.RefreshQuests() end
    if AT.RefreshTargetMacro then AT.RefreshTargetMacro() end
    if AT.RefreshPortrait then AT.RefreshPortrait() end
    if AT.RefreshQuestRoute then AT.RefreshQuestRoute() end
    if AT.RefreshQuestHUD then AT.RefreshQuestHUD() end
    if AT.RefreshQuestLeftovers then AT.RefreshQuestLeftovers() end
    if AT.RefreshDungeonPosition then AT.RefreshDungeonPosition() end
    if AT.RefreshHunterDeadzone then AT.RefreshHunterDeadzone() end
    if AT.RefreshPetBar then AT.RefreshPetBar() end
    refreshPanel()
    if minimapButton then
        minimapButton.icon:SetDesaturated(not AT.db.enabled)
        minimapButton.icon:SetAlpha(AT.db.enabled and 1 or .76)
    end
end

local function makeText(owner, template, y, value)
    local text = owner:CreateFontString(nil, "OVERLAY", template)
    text:SetPoint("TOPLEFT", 19, y)
    text:SetWidth(315)
    text:SetJustifyH("LEFT")
    text:SetText(value)
    return text
end

local function setupButton(parent, label, w, x, y, action)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(w, 24)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(label)
    button:SetScript("OnClick", action)
    return button
end

local function saveCurrentTarget()
    if not AT.SaveSelectedTarget then return end
    local ok, why = AT.SaveSelectedTarget()
    if not ok and why then AT.Say(why)
    elseif ok then AT.Say("Ready to recall " .. (AT.GetTargetName() or "the saved mob") .. ".") end
end

local function placeSkullMacro()
    if not AT.PickupSkullMacro then return end
    local ok, why = AT.PickupSkullMacro()
    if ok then
        if panel then panel:Hide() end
        AT.Say("Click an empty action-bar slot for AT Skull. It applies your chosen primary marker if WoW allows it.")
    elseif why then
        AT.Say(why)
    end
end

local function placeMouseoverMacro(fn, label)
    if not fn then return end
    local ok, why = fn()
    if not ok then if why then AT.Say(why) end; return end
    if panel then panel:Hide() end
    AT.Say("Place " .. label .. " on an empty slot. Hover an enemy, then use that slot's key.")
end

local function choosePrimary(self)
    if not (AT.SetPrimaryMarker and AT.GetPrimaryMarker and AT.MarkerNames) then return end
    local function selectMarker(id)
        local ok, why = AT.SetPrimaryMarker(id)
        if not ok and why then AT.Say(why) end
        refreshPanel()
    end
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:CreateTitle("Primary raid marker")
            for i, label in ipairs(AT.MarkerNames) do
                local id = i
                root:CreateButton(label, function() selectMarker(id) end)
            end
        end)
    else
        selectMarker(AT.GetPrimaryMarker() % #AT.MarkerNames + 1)
    end
end

local function buildPanel()
    panel = CreateFrame("Frame", "AutoTrackOptionsFrame", UIParent, "BackdropTemplate")
    panel:SetSize(404, 426)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8", edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 14, insets = {left=4, right=4, top=4, bottom=4},
    })
    panel:SetBackdropColor(0.027, 0.048, 0.059, 0.985)
    panel:SetBackdropBorderColor(0.28, 0.67, 0.65, 1)
    panel:Hide()
    local moving = false
    local function stopMoving()
        if not moving then return end
        panel:StopMovingOrSizing()
        panel:SetUserPlaced(false)
        moving = false
    end
    panel:SetScript("OnShow", function()
        panel:ClearAllPoints()
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        refreshPanel()
    end)
    panel:HookScript("OnHide", stopMoving)
    local titleDrag = CreateFrame("Frame", nil, panel)
    titleDrag:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -8)
    titleDrag:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -38, -8)
    titleDrag:SetHeight(52)
    titleDrag:EnableMouse(true)
    titleDrag:RegisterForDrag("LeftButton")
    titleDrag:SetScript("OnDragStart", function()
        if not moving then
            moving = true
            panel:StartMoving()
        end
    end)
    titleDrag:SetScript("OnDragStop", stopMoving)
    table.insert(UISpecialFrames, panel:GetName())
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    local heading = makeText(panel, "GameFontNormalLarge", -17, "Nexus Quest Tools")
    heading:SetTextColor(unpack(titleColor))
    local desc = makeText(panel, "GameFontHighlightSmall", -44, "QUEST FOCUS  /  NAMED TARGET")
    desc:SetTextColor(0.70, 0.79, 0.82)
    checks = {}
    local names = {"General", "Auto Macro", "Rank Quest", "Dungeons"}
    local widths = {76, 91, 91, 108}
    local pages, tabs = {}, {}
    local function showPage(which)
        for i, page in ipairs(pages) do
            page:SetShown(i == which)
            if i == which then tabs[i]:LockHighlight() else tabs[i]:UnlockHighlight() end
        end
        refreshPanel()
    end
    local x = 14
    for i, name in ipairs(names) do
        local index = i
        local page = CreateFrame("Frame", nil, panel)
        page:SetPoint("TOPLEFT", 0, -103)
        page:SetPoint("BOTTOMRIGHT", 0, 0)
        pages[i] = page
        tabs[i] = setupButton(panel, name, widths[i], x, -66, function() showPage(index) end)
        x = x + widths[i] + 4
    end
    local general, macro, rank, dungeon = unpack(pages)
    local function option(page, key, label, y, hint)
        local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 14, y)
        check:SetSize(26, 26)
        local text = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", check, "RIGHT", 2, 0)
        text:SetText(label)
        check:SetScript("OnClick", function(self)
            if (key == "showQuestMapPins" or key == "showObservedQuestGivers") and AT.RefreshQuestMapPins then AT.RefreshQuestMapPins() end
            if key == "pingWithMarker" and AT.SetMarkerPing then
                local ok, why = AT.SetMarkerPing(self:GetChecked() and true or false)
                if not ok and why then AT.Say(why) end
                refreshPanel()
                return
            end
            AT.db[key] = self:GetChecked() and true or false
            if (key == "rankQuestPartyAnnouncements" or key == "enabled") and AT.RefreshRankQuestAnnouncements then AT.RefreshRankQuestAnnouncements() end
            if (key == "questStartItemAlert" or key == "enabled") and AT.RefreshQuestStartItemAlert then AT.RefreshQuestStartItemAlert() end
            updateState()
        end)
        if hint then
            check:HookScript("OnEnter", function(self)
                if not GameTooltip then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(label)
                GameTooltip:AddLine(hint, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            check:HookScript("OnLeave", function(self)
                if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
            end)
        end
        checks[key] = check
    end
    option(general, "enabled", "Enable Nexus Quest Tools", -2)
    option(general, "autoFocus", "Automatically focus the closest quest", -30)
    option(general, "hideCompleted", "Untrack ready-to-turn-in quests", -58)
    option(general, "showQuestRoute", "Show minimap walking route", -86)
    option(general, "hunterDeadzone", "Hunter Deadzone", -114,
        "Shows a crossed-out bow when your current enemy is in melee range during Hunter combat and Auto Shot is not in range.")
    deadzonePreviewButton = setupButton(general, "Preview / Move", 128, 232, -115, function()
        if AT.SetHunterDeadzonePreview and AT.IsHunterDeadzonePreview then
            AT.SetHunterDeadzonePreview(not AT.IsHunterDeadzonePreview())
            refreshPanel()
        end
    end)
    deadzonePreviewHint = makeText(general, "GameFontDisableSmall", -151, "Drag the bow to move it, then click Done Moving.")
    deadzonePreviewHint:Hide()
    general:HookScript("OnHide", function()
        if AT.SetHunterDeadzonePreview then AT.SetHunterDeadzonePreview(false) end
    end)
    option(general, "petBarEnabled", "Pet Bar", -174,
        "Shows only your active pet’s overhead health where supported. Uses the pet category without changing friendly player or NPC settings. Bright green at 50% and above, red below 50%.")
    status = makeText(general, "GameFontHighlightSmall", -209, "")
    status:SetTextColor(0.43, 0.88, 0.81)

    option(macro, "quietTarget", "Mute target macro sounds", -2)
    option(macro, "pressSkull", "Raid marker on Smart Target press", -30, "Your existing stock action-bar shortcut automatically runs Smart Target out of combat. You can also bind Smart Target directly.")
    option(macro, "nextMobHint", "Highlight next visible untagged mob", -58)
    option(macro, "pingWithMarker", "Ping when placing marker", -86)
    primaryChoice = setupButton(macro, "Primary marker: Skull", 300, 18, -118, choosePrimary)
    markerStatus = makeText(macro, "GameFontHighlightSmall", -149, "")
    targetStatus = makeText(macro, "GameFontHighlightSmall", -172, "")

    option(rank, "questHUDEnabled", "Enable Rank Quest", -2, "Show the movable, zone-organized Rank Quest panel and hide the stock quest display.")
    option(rank, "questPartyProgress", "Quest Party Progress", -30, "Show the party progress Blizzard reports on hover, and keep shared quests visible while a party member still needs objectives.")
    option(rank, "questLeftoverMarks", "Mark leftover quest items in bags", -58, "Shows a trash badge for verified leftovers and an amber badge for items from a quest you dropped. Keep amber items if you plan to retry the quest. Never deletes anything.")
    option(rank, "rankQuestDropRates", "Show item drop rates", -86, "Show estimated percentages next to item objectives. Unknown rates are hidden.")
    option(rank, "showQuestMapPins", "Show standalone map pins", -114, "Adds quest and service pins to the world map. NQT adds no minimap pins. Recorded starts can still have prerequisites.")
    option(rank, "showObservedQuestGivers", "Show observed quest giver locations", -142, "Show known giver locations, even when the associated quest is not currently available.")
    option(rank, "questStartItemAlert", "Quest-starting item popup", -170, "Shows the icon for a newly acquired quest-starting item above your character. Click to open the quest offer, or right-click to dismiss.")
    option(rank, "rankQuestPartyAnnouncements", "Announce quest completion in party chat", -198,
        "Announces any completed quest to your party, with your Primary marker in front. Also shows kill and collection milestones on unfinished quests. On by default.")
    makeText(rank, "GameFontHighlightSmall", -234, "Right-click a quest to exclude it from automatic tracking.")
    makeText(rank, "GameFontDisableSmall", -256, "Ctrl-click quest titles to number them. /at order lists them.")

    option(dungeon, "dungeonPositionEnabled", "Enable dungeon maps", -2)
    option(dungeon, "dungeonPositionAutoOpen", "Open automatically in a dungeon", -30)
    option(dungeon, "dungeonPositionShowSelf", "Show my position", -58)
    option(dungeon, "dungeonPositionShowParty", "Show party positions", -86, "Only shows positions that the game makes available.")
    option(dungeon, "dungeonMapMinimap", "Show minimap on dungeon map", -114,
        "When you open the dungeon map with your normal map key, dock the real minimap. Ctrl-drag it to save a different spot. Closing the map restores your regular minimap.")
    setupButton(dungeon, "Open Dungeon Map", 166, 18, -151, function()
        if AT.OpenDungeonPositionMap then AT.OpenDungeonPositionMap() end
    end)
    local function showMinimapCheck()
        AT.Say(AT.CheckDungeonMinimapRender and AT.CheckDungeonMinimapRender() or "Dungeon minimap check is not loaded.")
    end
    setupButton(dungeon, "Minimap check", 140, 196, -151, showMinimapCheck)
    option(dungeon, "bossAutoMark", "Boss Target Marking", -190,
        "Inside an instance, your Auto Track action-bar macro or Smart Target key selects and marks a detected boss out of combat. Uses all eight marks in order, starting with Skull and X; does not replace the saved mob.")
    option(dungeon, "bossMarkPing", "Also ping the boss", -218,
        "Include an Attack ping on the same macro press when the client allows it.")
    makeText(dungeon, "GameFontHighlightSmall", -249, "Uses your existing macro. Enemy nameplates help.")
    setupButton(macro, "Place recall macro", 151, 18, -192, function()
        if InCombatLockdown() then AT.Say("Leave combat before setting up the target macro."); return end
        if AT.PickupTargetMacro then
            local ok, why = AT.PickupTargetMacro()
            if ok then
                panel:Hide()
                AT.Say("Click an empty action-bar slot. For regular mob markers and pings, use that slot keybind or bind Smart Target directly.")
            elseif why then AT.Say(why) end
        end
        refreshPanel()
    end)
    setupButton(macro, "Place primary macro", 139, 177, -192, placeSkullMacro)
    setupButton(macro, "Place mouseover Ping", 151, 18, -224, function() placeMouseoverMacro(AT.PickupPingMacro,"AT Ping") end)
    setupButton(macro, "Place secondary marker", 139, 177, -224, function() placeMouseoverMacro(AT.PickupCrossMacro,"AT X (secondary marker)") end)
    showPage(1)
end

local function updateMinimap()
    local angle = math.rad(AT.db.minimapAngle % 360)
    local radius = Minimap:GetWidth() / 2 + 4
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle)*radius, math.sin(angle)*radius)
end

function AT.InitOptions()
    buildPanel()
    minimapButton = CreateFrame("Button", "AutoTrackMinimapButton", Minimap, "BackdropTemplate")
    minimapButton:SetSize(31, 31)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    minimapButton:SetBackdrop({bgFile="Interface/Buttons/WHITE8X8", edgeFile="Interface/Tooltips/UI-Tooltip-Border", edgeSize=10})
    minimapButton:SetBackdropColor(0.02, 0.10, 0.12, 0.98)
    minimapButton:SetBackdropBorderColor(0.34, 0.63, 0.60, 1)
    minimapButton:SetHighlightTexture("Interface/Minimap/UI-Minimap-ZoomButton-Highlight")
    -- Leatrix copies named textures when converting non-LibDBIcon buttons.
    -- FontString text is not copied by the minimap proxy.
    local icon = minimapButton:CreateTexture("AutoTrackMinimapButtonIcon", "OVERLAY", nil, 4)
    icon:SetSize(26, 26)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface/AddOns/NQT/MinimapAT.tga")
    minimapButton.icon = icon
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")
    minimapButton:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local scale = Minimap:GetEffectiveScale()
            local x, y = GetCursorPosition()
            local mx, my = Minimap:GetCenter()
            if mx and my then
                AT.db.minimapAngle = math.deg(math.atan2(y/scale-my, x/scale-mx)) % 360
                updateMinimap()
            end
        end)
    end)
    minimapButton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    minimapButton:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            AT.db.enabled = not AT.db.enabled
            updateState()
        elseif panel:IsShown() then panel:Hide() else panel:Show() end
    end)
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Nexus Quest Tools")
        GameTooltip:AddLine("Left-click: Options", 0.9, 0.95, 1)
        GameTooltip:AddLine("Right-click: Enable / pause", 0.9, 0.95, 1)
        GameTooltip:AddLine("Drag: Move around minimap", 0.9, 0.95, 1)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    updateMinimap()
    updateState()
    SLASH_AUTOTRACK1 = "/autotrack"
    SLASH_AUTOTRACK2 = "/at"
    SlashCmdList.AUTOTRACK = function(arg)
        local command, rest = (arg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
        if command == "target" then
            if AT.OpenTargetEditor then AT.OpenTargetEditor() end
        elseif command == "ping" then
            placeMouseoverMacro(AT.PickupPingMacro,"AT Ping")
        elseif command == "x" then
            placeMouseoverMacro(AT.PickupCrossMacro,"AT X (secondary marker)")
        elseif command == "skull" then
            placeSkullMacro()
        elseif command == "set" then
            saveCurrentTarget()
        elseif command == "include" then
            local id = tonumber(rest)
            if id and AT.IsQuestExcluded and AT.IsQuestExcluded(id) and AT.SetQuestExcluded then
                AT.SetQuestExcluded(id, false)
                AT.Say("Automatic tracking re-enabled for quest #" .. id .. ".")
            else
                AT.Say("Use /at excluded to find the ID, then /at include ID.")
            end
        elseif command == "gps" then
            if AT.RefreshQuestRoute then AT.RefreshQuestRoute() end
            local status,quest,details
            if AT.GetQuestRouteStatus then status,quest,details=AT.GetQuestRouteStatus() end
            local messages={
                provider_missing="No compatible walking-route provider is loaded for this map.",
                objective_missing="No usable objective coordinates on this walking map.",
                interior="Route hidden in an interior or uncertain floor.",
                position="Waiting for a reliable player position.",
                arrival="Route hidden inside the objective area.",
                disabled="Walking GPS is disabled.",
                no_quest="No active quest to route.",
                planning="Waiting for the walking route.",
                replan="Recalculating after leaving the route.",
                routed="Walking route ready.",
                road="Road-aware walking route ready.",
            }
            AT.Say("GPS" .. (quest and (" quest #" .. quest) or "") .. ": " ..
                (messages[status] or ("No walking route available" .. (status and (" (" .. status .. ").") or "."))))
            if details then AT.Say(details) end
        elseif command == "order" then
            local order = AT.char.trackingOrder or {}
            if #order == 0 then AT.Say("Tracking order is empty."); return end
            for position = 1, math.min(#order, 10) do
                local id = order[position]
                if type(id) == "number" then
                    local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
                    if issecretvalue and issecretvalue(title) then title = nil end
                    AT.Say(position .. ". " .. (type(title) == "string" and title or ("Quest #" .. id)))
                end
            end
        elseif command == "excluded" then
            local ids = {}
            for id, excluded in pairs(AT.char.excludedQuests or {}) do
                if type(id) == "number" and excluded then ids[#ids + 1] = id end
            end
            table.sort(ids)
            if #ids == 0 then AT.Say("No quests are excluded."); return end
            AT.Say("Excluded quests. Use /at include ID to re-enable one.")
            for _, id in ipairs(ids) do
                local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
                if issecretvalue and issecretvalue(title) then title = nil end
                AT.Say("#" .. id .. (type(title) == "string" and ("  " .. title) or ""))
            end
        elseif panel:IsShown() then panel:Hide() else panel:Show() end
    end
    SLASH_NEXUSQUESTTOOLSETTINGS1 = "/nqt"
    SlashCmdList.NEXUSQUESTTOOLSETTINGS = function(arg)
        local command,rest=(arg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
        if command=="perf" and AT.PerfCommand then AT.PerfCommand(rest);return end
        if type(arg)=="string" and arg:match("^%s*minimap%s*$") then
            AT.Say(AT.CheckDungeonMinimapRender and AT.CheckDungeonMinimapRender() or "Dungeon minimap check is not loaded.")
            return
        end
        if not panel:IsShown() then panel:Show() end
    end
    AT.RefreshOptions = refreshPanel
    C_Timer.NewTicker(1.5, refreshPanel)
end






