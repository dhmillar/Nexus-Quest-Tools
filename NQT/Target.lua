local _, AT = ...
local marker, previousMarker, oldMarker, v1Marker = "#AT4", "#AT3:t", "# AT2:target", "# AutoTrack:owned:v1"
local icon = 134400
local macroNames = { "Auto Track", "Auto Track AT" }
local setupLine = "/atmob [btn:2]e;c"
local captureCondition = "[harm,nodead,nocombat,nomod]"
local recallStop = "/stopmacro [btn:2]" .. captureCondition
local recallPrefix, partialPrefix = "/targetexact ", "/target "
local cleanupLine = "/cleartarget [dead]"
local quietLine = "/atmob q"
local tapLine = "/atmob m"
local markerNames = {"Star","Circle","Diamond","Triangle","Moon","Square","X","Skull"}
AT.MarkerNames = markerNames

function AT.GetPrimaryMarker()
    local id = AT.char and AT.char.primaryMarker
    if type(id) ~= "number" or id < 1 or id > 8 or id % 1 ~= 0 then return 8 end
    return id
end

function AT.GetSecondaryMarker()
    return AT.GetPrimaryMarker() == 7 and 6 or 7
end

local function markLine(condition)
    return "/tm [" .. condition .. "] !" .. AT.GetPrimaryMarker()
end

local function pingLine(condition)
    return "/ping [@target," .. condition .. "] Attack"
end

local maxNameLength = 255 - #table.concat({marker, setupLine, recallStop, recallPrefix, cleanupLine}, "\n")

local function say(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff38ddd1Nexus Quest Tools:|r " .. message) end
end

local function private(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function ownedBody(body)
    return not private(body) and type(body) == "string"
        and (body:sub(1,#marker+1) == marker .. "\n" or body:sub(1,#previousMarker+1) == previousMarker .. "\n"
            or body:sub(1,#oldMarker+1) == oldMarker .. "\n"
            or body:sub(1,#v1Marker+1) == v1Marker .. "\n")
end

local function validName(value)
    if private(value) or type(value) ~= "string" then return nil end
    value = value:gsub("^ +", ""):gsub(" +$", "")
    if #value == 0 or #value > maxNameLength or value:find("[%c%[%];|/]") then return nil end
    return value
end

function AT.GetTargetName()
    return AT.char and validName(AT.char.targetName)
end

function AT.IsPartialTarget()
    return AT.char and AT.char.targetPartial == true or false
end

local function matchesSaved(name)
    local saved = AT.GetTargetName()
    if name == saved then return true end
    if not name or not saved or not AT.IsPartialTarget() then return false end
    return name:lower():find(saved:lower(), 1, true) ~= nil
end

local function validPartial(name)
    if name:find("[%%*?]") then return false end
    -- /target can also interpret a unit token; a typed text query must not.
    local token = name:lower()
    while token:sub(-6)=="target" and token~="target" do token=token:sub(1,-7) end
    local reserved = {player=true, target=true, pet=true, focus=true, mouseover=true,
        vehicle=true, npc=true, none=true, softenemy=true, softfriend=true, softinteract=true}
    if reserved[token] then return false end
    for _,prefix in ipairs({"party","partypet","raid","raidpet","arena","arenapet","boss","nameplate","maintank","mainassist"}) do
        if token:match("^" .. prefix .. "%d+$") then return false end
    end
    return true
end

function AT.GetSafeTargetSearchLine()
    local saved=AT.GetTargetName()
    if not saved then return end
    local partial=AT.IsPartialTarget()
    if partial and not validPartial(saved) then return end
    return (partial and "/target " or "/targetexact ").."[noexists] "..saved
end

local function enabled()
    return not AT.db or AT.db.enabled ~= false
end

local targetStop = "/stopmacro [btn:2][dead]"
local targetConditional = "[nocombat,noharm][noexists] "
local compactConditional = "[noexists] "

-- For both option states, no existing living hostile or selected corpse
-- can be displaced by recall. An out-of-combat selection is learned first.
local function targetBody(name, compact)
    local lines = {marker, setupLine}
    if not enabled() then return table.concat(lines,"\n") end
    lines[#lines+1] = targetStop
    local safetyEnd = #lines
    if name then
        lines[#lines+1] = (AT.IsPartialTarget() and partialPrefix or recallPrefix)
            .. (compact and compactConditional or targetConditional) .. name
        lines[#lines+1] = cleanupLine
    end
    local left = 255 - #table.concat(lines,"\n")
    if left < 0 then return end
    -- A normal macro cannot branch on tap status. Do not send a blind marker or ping.
    if name and AT.db and AT.db.quietTarget and left >= #quietLine+1 then
        table.insert(lines,safetyEnd+1,quietLine)
        left = left-#quietLine-1
    end
    if name and left >= #tapLine+1 then lines[#lines+1]=tapLine end
    return table.concat(lines,"\n")
end

local bossMacroUntil,bossRefreshQueued=0,false
local function macroBody(name)
    if AT.GetBossTargetMacro then
        local prefix=marker.."\n/atmob [btn:2]e;h\n/stopmacro [btn:2][combat]\n"
        local active,body=AT.GetBossTargetMacro(true,nil,255-#prefix+#"/stopmacro [combat]\n")
        if active then
            if body then body=body:gsub("^/stopmacro %[combat%]\n","",1) end
            local out=prefix..(body or "/atmob b")
            if #out<=255 then return out end
            return marker.."\n/atmob [btn:2]e;b"
        end
    end
    return targetBody(name,false) or targetBody(name,true) or targetBody(nil,true)
end
function AT.GetMarkerPingNotice()
    if not (AT.db and AT.db.enabled and AT.db.pressSkull) then return end
    return "Smart Target marks only mobs your group can tag."
end

function AT.IsOwnTargetMacro(id)
    if private(id) or type(id) ~= "number" or not GetMacroInfo then return false end
    local limits = Constants and Constants.MacroConsts or {}
    local first = limits.MAX_ACCOUNT_MACROS or MAX_ACCOUNT_MACROS or 120
    if id <= first then return false end
    local _, _, body = GetMacroInfo(id)
    return ownedBody(body)
end

local function findMacro()
    local taken = {}
    local limits = Constants and Constants.MacroConsts or {}
    local bankStart = limits.MAX_ACCOUNT_MACROS or MAX_ACCOUNT_MACROS or 120
    local bankCount = limits.MAX_CHARACTER_MACROS or MAX_CHARACTER_MACROS or 18
    for i = 1, bankStart + bankCount do
        local name, _, body = GetMacroInfo(i)
        if name then
            taken[name] = true
            if i > bankStart and ownedBody(body) then
                return i, name, body
            end
        end
    end
    for _, name in ipairs(macroNames) do
        if not taken[name] then return nil, name end
    end
end

local function syncMacro(create)
    if InCombatLockdown() then return false, "The target macro can only be edited out of combat." end
    if not create and GetTime and GetTime()<bossMacroUntil then
        if not bossRefreshQueued and C_Timer and C_Timer.After then
            bossRefreshQueued=true
            C_Timer.After(math.max(.01,bossMacroUntil-GetTime()),function()
                bossRefreshQueued=false
                if AT.RefreshBossActionBar then AT.RefreshBossActionBar() end
            end)
        end
        return true
    end
    if not GetMacroInfo or not CreateMacro or not EditMacro then
        return false, "This client does not expose the macro editor."
    end
    local id, label, previous = findMacro()
    if not id and not create then return true end
    if not label then return false, "Both Auto Track macro names are already in use." end
    local body = macroBody(AT.GetTargetName())
    if #body > 255 then return false, "That name is too long for a WoW macro." end
    if id and previous == body then return true, nil, id end
    local ok, result
    if id then
        ok, result = pcall(EditMacro, id, label, nil, body)
    else
        ok, result = pcall(CreateMacro, label, icon, body, true)
    end
    if ok then
        local actualID, _, actualBody = findMacro()
        if actualID and actualBody == body then return true, nil, actualID end
    end
    if id and type(previous)=="string" and previous:find("/cleartarget [nocombat]", 1, true) then
        return false, "The old target macro still clears your target. Close Macros and /reload out of combat before using it."
    end
    return false, id and "WoW did not update the existing target macro. Close the Macros window and try again." or
        "WoW could not create the character macro. Check for a free character macro slot."
end

function AT.EnsureTargetMacro()
    return syncMacro(true)
end
function AT.RefreshBossActionBar()
    if not InCombatLockdown() then return syncMacro(false) end
end

function AT.PickupTargetMacro()
    local ok, err, id = AT.EnsureTargetMacro()
    if not ok then return false, err end
    if GetCursorInfo and GetCursorInfo() then return false, "Clear your cursor before picking up the macro." end
    local picked = pcall(PickupMacro, id)
    if not picked or (GetCursorInfo and GetCursorInfo() ~= "macro") then
        return false, "Open /macro and drag the Auto Track character macro to your bar."
    end
    return true
end

-- An independent native macro avoids modifier/keybind collisions and the name macro's byte budget.
local function findNativeMacro(header, labels)
    local limits = Constants and Constants.MacroConsts or {}
    local bankStart = limits.MAX_ACCOUNT_MACROS or MAX_ACCOUNT_MACROS or 120
    local bankCount = limits.MAX_CHARACTER_MACROS or MAX_CHARACTER_MACROS or 18
    local taken = {}
    for i = 1, bankStart + bankCount do
        local name, _, body = GetMacroInfo(i)
        if not private(name) and type(name) == "string" then taken[name] = true end
        if i > bankStart and not private(body) and type(body) == "string"
            and body:sub(1, #header + 1) == header .. "\n" then
            return i, name, body
        end
    end
    for _, name in ipairs(labels) do
        if not taken[name] then return nil, name end
    end
end

local function syncNative(header, labels, asset, command, create)
    if not (GetMacroInfo and CreateMacro and EditMacro) then return false, "WoW's macro editor is unavailable." end
    local id, name, previous = findNativeMacro(header, labels)
    if not id and not create then return true end
    if not name then return false, "Both names for this Auto Track macro are already in use." end
    local body = header .. "\n" .. command
    if previous ~= body then
        if id then pcall(EditMacro, id, name, nil, body)
        else pcall(CreateMacro, name, asset, body, true) end
        local updatedID, _, actual = findNativeMacro(header, labels)
        if not updatedID or actual ~= body then
            return false, "WoW did not save the macro. Close /macro and check for a free character macro slot."
        end
        id = updatedID
    end
    return true, nil, id, name
end

local function pickupNative(header, labels, asset, command)
    if InCombatLockdown() then return false, "Leave combat before setting up this macro." end
    if not PickupMacro then return false, "WoW's macro editor is unavailable." end
    if GetCursorInfo and GetCursorInfo() then return false, "Clear your cursor before picking up the macro." end
    local ready, why, id, name = syncNative(header, labels, asset, command, true)
    if not ready then return false, why end
    local ok = pcall(PickupMacro, id)
    if not ok or (GetCursorInfo and GetCursorInfo() ~= "macro") then
        return false, "Open /macro and drag the " .. name .. " character macro to an empty action-bar slot."
    end
    return true
end

local buffHeader, buffLabels = "# NQT:smart-buff:v1", {"NQT Smart Buff","NQT Buff"}
function AT.SyncSmartBuffAction(command,pickup)
    if InCombatLockdown and InCombatLockdown() then return false,"Leave combat before setting up Smart Buff." end
    if pickup then return pickupNative(buffHeader,buffLabels,134400,command) end
    return syncNative(buffHeader,buffLabels,134400,command,false)
end

local primaryHeader, primaryLabels = "# AutoTrack:skull:v1", {"AT Skull", "AutoTrack Skull"}
local secondaryHeader, secondaryLabels = "# AutoTrack:cross:v1", {"AT X", "AutoTrack X"}
local function primaryCommand()
    local command = markLine("harm,nodead")
    if AT.db and AT.db.pingWithMarker then command = command .. "\n" .. pingLine("harm,nodead") end
    return command
end
local function secondaryCommand()
    return "/tm [@mouseover,harm,nodead] ~" .. AT.GetSecondaryMarker()
end

function AT.PickupSkullMacro()
    return pickupNative(primaryHeader, primaryLabels, 132331, primaryCommand())
end

function AT.PickupPingMacro()
    return pickupNative("# AutoTrack:ping:v1", {"AT Ping", "AutoTrack Ping"}, 134400, "/ping [@mouseover,harm,nodead] Attack")
end

function AT.PickupCrossMacro()
    return pickupNative(secondaryHeader, secondaryLabels, 134400, secondaryCommand())
end
local needsRefresh = false
function AT.RefreshTargetMacro()
    if InCombatLockdown() then
        needsRefresh = true
        return false, "The action-bar macro will update when combat ends."
    end
    needsRefresh = false
    local ok, why = syncMacro(false)
    if not ok then return false, why end
    ok, why = syncNative(primaryHeader, primaryLabels, 132331, primaryCommand(), false)
    if not ok then return false, why end
    return syncNative(secondaryHeader, secondaryLabels, 134400, secondaryCommand(), false)
end

function AT.SetPrimaryMarker(id)
    if not AT.char then return false, "Character settings are not ready." end
    if InCombatLockdown() then return false, "Leave combat before changing raid markers." end
    if type(id) ~= "number" or not markerNames[id] then return false, "Choose one of the eight raid markers." end
    local previous = AT.char.primaryMarker
    AT.char.primaryMarker = id
    local ok, why = AT.RefreshTargetMacro()
    if not ok then
        AT.char.primaryMarker = previous
        AT.RefreshTargetMacro()
        return false, why
    end
    return true
end

function AT.SetMarkerPing(value)
    if not AT.db then return false, "Settings are not ready." end
    if InCombatLockdown() then return false, "Leave combat before changing marker pings." end
    local before = AT.db.pingWithMarker
    AT.db.pingWithMarker = value == true
    local ok, why = AT.RefreshTargetMacro()
    if not ok then
        AT.db.pingWithMarker = before
        AT.RefreshTargetMacro()
        return false, why
    end
    return true
end

local initialized, pendingEnemy, captureVersion = nil, nil, 0
local pendingCorpse = false

function AT.IsTargetNameLocked()
    return AT.char and AT.char.targetNameLocked == true or false
end

local function setName(value, partial, lock)
    if not AT.char then return false, "Character settings are not loaded yet." end
    if InCombatLockdown() then return false, "Leave combat before changing the saved target." end
    local name = validName(value)
    local clear = not private(value) and type(value) == "string" and value:match("^ *$") ~= nil
    if not name and not clear then return false, ("Enter a plain monster name (up to %d bytes)."):format(maxNameLength) end
    if name and partial and not validPartial(name) then return false, "Enter literal name text, not a unit token or wildcard." end
    local oldName, oldPartial, oldLock = AT.char.targetName, AT.char.targetPartial, AT.char.targetNameLocked
    local newLock = AT.IsTargetNameLocked()
    if lock ~= nil then newLock = lock == true end
    newLock = (name and newLock) and true or nil
    local newPartial = (name and partial == true) and true or nil
    if oldName == name and oldPartial == newPartial and oldLock == newLock then
        local ok, err = AT.EnsureTargetMacro()
        if ok and AT.RefreshPortrait then AT.RefreshPortrait() end
        return ok, err
    end
    AT.char.targetName, AT.char.targetPartial, AT.char.targetNameLocked = name, newPartial, newLock
    local ok, err = AT.EnsureTargetMacro()
    if not ok then AT.char.targetName, AT.char.targetPartial, AT.char.targetNameLocked = oldName, oldPartial, oldLock; return false, err end
    say(name and ("Target saved: " .. name .. (newPartial and " (partial match)" or "")) or "Saved target cleared.")
    if AT.RefreshOptions then AT.RefreshOptions() end
    if AT.RefreshPortrait then AT.RefreshPortrait() end
    return true
end

-- A Rank Quest click sets an exact saved name. It never acquires a unit,
-- marks it, pings it, or unlocks a manually locked target.
function AT.SetQuestMobTarget(value)
    if not enabled() then return false, "Auto Macro is disabled." end
    if AT.IsTargetNameLocked() then return false, "The saved target name is locked." end
    local name=validName(value)
    if not name or not validPartial(name) then return false, "No exact monster name is available." end
    local ok,why=setName(name,false)
    if not ok and why then say(why) end
    return ok,why
end

local editor, input, warning, lockCheck
function AT.OpenTargetEditor()
    if InCombatLockdown() then say("Leave combat before changing the saved target."); return end
    if not editor then
        editor = CreateFrame("Frame", "AutoTrackTargetEditor", UIParent, "BackdropTemplate")
        editor:SetSize(365, 224)
        editor:SetPoint("CENTER")
        editor:SetFrameStrata("DIALOG")
        editor:EnableMouse(true)
        editor:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = {left=2,right=2,top=2,bottom=2}})
        editor:SetBackdropColor(0.055, 0.07, 0.095, 0.99)
        local heading = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        heading:SetPoint("TOPLEFT", 18, -16)
        heading:SetText("Nexus Quest Tools | Saved monster")
        local help = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        help:SetPoint("TOPLEFT", 18, -43)
        help:SetText("Type part of a name (e.g. Rap), or save an exact name.")
        input = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
        input:SetSize(310, 28)
        input:SetPoint("TOPLEFT", 22, -62)
        input:SetMaxLetters(maxNameLength)
        input:SetAutoFocus(false)
        local useSelected = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
        useSelected:SetSize(163, 24)
        useSelected:SetPoint("TOPLEFT", 18, -98)
        useSelected:SetText("Save selected mob")
        useSelected:SetScript("OnClick", function()
            local ok, err = AT.SaveSelectedTarget()
            if ok then editor:Hide() else warning:SetText(err) end
        end)
        lockCheck = CreateFrame("CheckButton", nil, editor, "UICheckButtonTemplate")
        lockCheck:SetSize(24, 24)
        lockCheck:SetPoint("TOPLEFT", 18, -130)
        local lockLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lockLabel:SetPoint("LEFT", lockCheck, "RIGHT", 4, 0)
        lockLabel:SetText("Lock saved name (applies when you save)")
        warning = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        warning:SetPoint("TOPLEFT", 18, -158)
        warning:SetWidth(327)
        warning:SetJustifyH("LEFT")
        warning:SetTextColor(1, 0.65, 0.33)
        local function accept(partial)
            local ok, err = setName(input:GetText(), partial, lockCheck:GetChecked() and true or false)
            if ok then
                captureVersion = captureVersion + 1
                pendingEnemy, pendingCorpse = nil, false
                editor:Hide()
            else warning:SetText(err) end
        end
        local save = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
        save:SetSize(110, 23)
        save:SetPoint("BOTTOMRIGHT", -14, 12)
        save:SetText("Save partial")
        save:SetScript("OnClick", function() accept(true) end)
        local exact = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
        exact:SetSize(100, 23)
        exact:SetPoint("RIGHT", save, "LEFT", -8, 0)
        exact:SetText("Save exact")
        exact:SetScript("OnClick", function() accept(false) end)
        local cancel = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
        cancel:SetSize(85, 23)
        cancel:SetPoint("RIGHT", exact, "LEFT", -8, 0)
        cancel:SetText("Cancel")
        cancel:SetScript("OnClick", function() editor:Hide() end)
        input:SetScript("OnEnterPressed", function()
            accept(validName(input:GetText()) ~= AT.GetTargetName() or AT.IsPartialTarget())
        end)
        input:SetScript("OnEscapePressed", function() editor:Hide() end)
        editor:SetScript("OnHide", function() input:ClearFocus() end)
    end
    warning:SetText("")
    lockCheck:SetChecked(AT.IsTargetNameLocked())
    input:SetText(AT.GetTargetName() or "")
    editor:Show()
    input:SetFocus()
    input:HighlightText()
end

local function selectedHostile(allowCombat, allowCorpse)
    if InCombatLockdown() and not allowCombat then return nil end
    local ok, name, corpse = pcall(function()
        local attack, player, dead = UnitCanAttack("player", "target"), UnitIsPlayer("target"), UnitIsDeadOrGhost("target")
        if private(attack) or private(player) or private(dead) or player ~= false then return nil end
        if dead then
            if not allowCorpse or dead ~= true or type(UnitReaction) ~= "function" then return nil end
            -- Dead units may be nonattackable. Only definitely hostile NPCs qualify.
            if attack ~= true then
                local reaction = UnitReaction("player","target")
                if private(reaction) or type(reaction) ~= "number" or reaction < 1 or reaction > 3 then return nil end
            end
            if UnitPlayerControlled then
                local controlled = UnitPlayerControlled("target")
                if private(controlled) or controlled then return nil end
            end
            if UnitIsUnit then
                local same = UnitIsUnit("target", "pet")
                if private(same) or same then return nil end
            end
            return validName(UnitName("target")), true
        end
        if attack ~= true then return nil end
        if allowCombat and (attack ~= true or player ~= false or dead ~= false) then return nil end
        return validName(UnitName("target"))
    end)
    if ok then return name, corpse end
end

function AT.GetSelectedMobForSmartTarget()
    return selectedHostile(false, true)
end

function AT.MatchesSavedTarget(name)
    return matchesSaved(name)
end

function AT.SaveSelectedTarget()
    if AT.IsTargetNameLocked() then return false, "The saved name is locked. Uncheck Lock saved name and save to unlock it." end
    if InCombatLockdown() then return false, "Leave combat before saving a different mob." end
    local name = selectedHostile(false, true)
    if not name then return false, "Select a hostile mob (living or dead), or use Edit target name." end
    return setName(name)
end

local targetSounds = { 567453, 567520 }
local mutedSounds = {}
local muteGeneration = 0
function AT.MuteTargetMacroSounds()
    if not (AT.db and AT.db.quietTarget and C_Timer and C_Timer.After and MuteSoundFile and UnmuteSoundFile) then return end
    muteGeneration = muteGeneration + 1
    local generation = muteGeneration
    for _, sound in ipairs(targetSounds) do
        if not mutedSounds[sound] then
            local ok = pcall(MuteSoundFile, sound)
            if ok then mutedSounds[sound] = true end
        end
    end
    C_Timer.After(0.12, function()
        if generation ~= muteGeneration then return end
        for sound in pairs(mutedSounds) do
            pcall(UnmuteSoundFile, sound)
            mutedSounds[sound] = nil
        end
    end)
end

local lastTagHint = -math.huge
local function warnIfTagged(expected)
    if not expected or not UnitIsTapDenied or InCombatLockdown() then return end
    pcall(function()
        local current = selectedHostile()
        if not current or current:lower() ~= expected:lower() then return end
        local denied = UnitIsTapDenied("target")
        if private(denied) or not denied then return end
        local now = GetTime and GetTime() or 0
        if now - lastTagHint >= 3 then
            lastTagHint = now
            say("Tagged by another group. Use the slot keybind or the Smart Target key out of combat to skip tagged mobs.")
        end
    end)
end

local function rememberAfterCombat(name, corpse)
    if not (enabled() and AT.db and corpse) then return end
    pendingCorpse = corpse == true
    if matchesSaved(name) then
        if pendingEnemy then
            pendingEnemy = nil
            say("Kept " .. name .. " as the saved target.")
        end
    elseif pendingEnemy ~= name then
        pendingEnemy = name
        say("Will save " .. name .. " when combat ends.")
    end
end
function AT.InitTarget()
    if initialized then return end
    initialized = true
    SLASH_NQTTARGETDEBUG1 = "/nqttargetdebug"
    SlashCmdList.NQTTARGETDEBUG=function()
        say(AT.GetSmartTargetDiagnostic and AT.GetSmartTargetDiagnostic() or "Smart Target module did not load.")
    end
    SLASH_AUTOTRACKMOB1 = "/atmob"
    SlashCmdList.AUTOTRACKMOB = function(message)
        message = message or ""
        local parsed, command = true, message
        if SecureCmdOptionParse then parsed, command = pcall(SecureCmdOptionParse, message) end
        if not parsed or private(command) or type(command) ~= "string" then return end
        if command == "q" and enabled() then AT.MuteTargetMacroSounds(); return end
        if command=="z" then if AT.NoteSmartMacroExecuted then AT.NoteSmartMacroExecuted() end; return end
        if command == "m" and enabled() then
            if AT.NoteRecallMacroPress then AT.NoteRecallMacroPress() end
            warnIfTagged(AT.GetTargetName()); return
        end
        if command == "edit" or command == "e" then AT.OpenTargetEditor(); return end
        if command=="h" then
            if GetTime and AT.db and AT.db.bossAutoMark then bossMacroUntil=GetTime()+.09 end
            return
        end
        local recovery=command:match("^v(%d+)$")
        if recovery and AT.RememberBossRecovery then AT.RememberBossRecovery(tonumber(recovery)); return end
        local step=command:match("^p(%d+)$")
        if step and AT.ObserveBossSearch then AT.ObserveBossSearch(tonumber(step)); return end
        local finish,slot=command:match("^j([0-8]):(%d+)$")
        if finish and AT.FinishBossSearch then AT.FinishBossSearch(tonumber(finish),tonumber(slot)); return end
        if AT.ReserveBossMark then
            local index,plan=command:match("^k([0-8]):(%d+)$")
            if index then AT.ReserveBossMark(tonumber(index),tonumber(plan)); return end
            if command:match("^k[0-8]$") then AT.ReserveBossMark(tonumber(command:sub(2))); return end
        end
        if command == "f" and AT.AdvanceBossSearch then AT.AdvanceBossSearch(); return end
        if command == "b" then
            say("Boss mode: target an unmarked boss or turn on enemy nameplates, then press again.")
            return
        end
        if command == "a" then
            if enabled() and not InCombatLockdown() and AT.ShowNextMobHint then pcall(AT.ShowNextMobHint, AT.GetTargetName()) end
            return
        end
        if command == "s" then
            -- Reuse the game's read-only secure conditional evaluator in
            -- the same hardware macro. This does not execute a protected action.
            if not SecureCmdOptionParse then return end
            local known, shift = pcall(SecureCmdOptionParse,"[mod:shift] r;c")
            if not known or private(shift) or shift ~= "c" then return end
            command = "c"
        end
        if command == "recall" or command == "r" or not enabled() then return end
        if command ~= "capture" and command ~= "c" then return end
        local combat = InCombatLockdown()
        if AT.IsTargetNameLocked() then return end
        local captured, corpse = selectedHostile(combat, true)
        if combat and not corpse then return end
        if not captured then return end
        captureVersion = captureVersion + 1
        local version = captureVersion
        if combat then rememberAfterCombat(captured, corpse); return end
        if not corpse and AT.ShowNextMobHint then pcall(AT.ShowNextMobHint, captured) end
        pendingEnemy = nil
        if matchesSaved(captured) then return end
        local function save()
            if version ~= captureVersion or not enabled() or AT.IsTargetNameLocked() then return end
            if InCombatLockdown() then rememberAfterCombat(captured, corpse); return end
            local ok, err = setName(captured)
            if not ok then say(err) end
        end
        if C_Timer and C_Timer.After then C_Timer.After(0, save) else save() end
    end
    local watch = CreateFrame("Frame")
    watch:RegisterEvent("PLAYER_REGEN_ENABLED")
    watch:RegisterEvent("PLAYER_ENTERING_WORLD")
    watch:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_ENTERING_WORLD" then
            self:UnregisterEvent(event)
            local ok, why = AT.RefreshTargetMacro()
            if not ok and not InCombatLockdown() then say(why) end
        else
            local queued, queuedCorpse = pendingEnemy, pendingCorpse
            pendingEnemy = nil
            if queued and enabled() and AT.db and queuedCorpse and not AT.IsTargetNameLocked() then
                local ok, why = setName(queued)
                if not ok then say(why) end
            end
            if needsRefresh then AT.RefreshTargetMacro() end
        end
    end)
    AT.RefreshTargetMacro()
end