local name, AT = ...
local defaults = {
    enabled = true,
    autoFocus = true,
    hideCompleted = true,
    quietTarget = false,
    pressSkull = true,
    pingWithMarker = false,
    nextMobHint = true,
    reacquireEachPress = false,
    showQuestRoute = true,
    hunterDeadzone = true,
    hunterDeadzoneX = 0,
    hunterDeadzoneY = 0,
    minimapAngle = 220,
    questHUDEnabled = false,
    dungeonPositionEnabled = true,
    dungeonPositionAutoOpen = true,
    dungeonMapMinimap = true,
    dungeonPositionShowSelf = true,
    dungeonPositionShowParty = true,
    bossAutoMark = false,
    bossMarkPing = false,
    questPartyProgress = true,
    showQuestMapPins = true,
    showObservedQuestGivers = false,
    rankQuestDropRates = true,
    questLeftoverMarks = false,
    questStartItemAlert = true,
    questHUDCollapsed = false,
    questHUDRailOpen = false,
    questHUDFontOffset = 0,
    questHUDWidth = 414,
    questHUDHeight = 395,
    questHUDX = -276,
    questHUDY = -255,
}

function AT.Say(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff39dcceNexus Quest Tools:|r " .. tostring(message))
    end
end

-- Opt-in runtime profiling; nothing is saved or transmitted.
local perf,perfUntil
local stamp=debugprofilestop
function AT.PerfBegin()
    if perf and stamp and GetTime and GetTime()<perfUntil then return stamp() end
end
function AT.PerfEnd(label,started)
    if not started or not perf then return end
    local ms=stamp()-started
    if ms<0 then return end
    local r=perf[label] or {n=0,total=0,peak=0,slow=0}
    r.n,r.total,r.peak=r.n+1,r.total+ms,math.max(r.peak,ms)
    if ms>=8 then r.slow=r.slow+1 end
    perf[label]=r
end
function AT.PerfCommand(command)
    if not stamp or not GetTime then AT.Say("Performance timing is unavailable on this client.");return end
    if command=="start" then
        perf,perfUntil={},GetTime()+60
        AT.Say("Recording local timings for 60 seconds. Play until you notice a stutter, then use /nqt perf stop.")
    elseif command=="stop" or command=="" then
        if not perf then AT.Say("Use /nqt perf start to capture a stutter.");return end
        if command=="stop" then perfUntil=0 end
        local rows={}
        for label,r in pairs(perf) do rows[#rows+1]={label=label,data=r} end
        table.sort(rows,function(a,b)return a.data.peak>b.data.peak end)
        if #rows==0 then AT.Say("No timed work recorded yet.");return end
        for _,row in ipairs(rows) do
            local r=row.data
            AT.Say(("%s: peak %.1f ms, mean %.2f ms, %d over 8 ms / %d calls"):format(row.label,r.peak,r.total/r.n,r.slow,r.n))
        end
    else AT.Say("Use /nqt perf start or /nqt perf stop.") end
end

local function safeInit(label, fn)
    if not fn then return end
    local ok, err = pcall(fn)
    if not ok then AT.Say(label .. " could not start: " .. tostring(err)) end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" and arg == name then
        self:UnregisterEvent("ADDON_LOADED")
        if type(AutoTrackDB) ~= "table" then AutoTrackDB = {} end
        if type(AutoTrackCharDB) ~= "table" then AutoTrackCharDB = {} end
        AT.db, AT.char = AutoTrackDB, AutoTrackCharDB
        AT.db.questHUDCompact = nil
        for k, v in pairs(defaults) do
            if type(AT.db[k]) ~= type(v) then AT.db[k] = v end
        end
        self:RegisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        safeInit("Quest tracking", AT.InitQuests)
        safeInit("Quest menus", AT.InitQuestMenus)
        safeInit("Target macro", AT.InitTarget)
        safeInit("Target portrait", AT.InitPortrait)
        safeInit("Minimap guidance", AT.InitQuestRoute)
        safeInit("Rank Quest", AT.InitQuestHUD)
        safeInit("Quest party sync", AT.InitQuestPartySync)
        safeInit("Standalone map pins", AT.InitQuestMapPins)
        safeInit("Quest leftover bag marks", AT.InitQuestLeftovers)
        safeInit("Bag quest links", AT.InitBagQuestLink)
        safeInit("Quest-starting item alerts", AT.InitQuestStartItemAlert)
        safeInit("Dungeons", AT.InitDungeonPosition)
        safeInit("Boss Target Marking", AT.InitBossTargetMarking)
        safeInit("Hunter Deadzone", AT.InitHunterDeadzone)
        safeInit("Settings", AT.InitOptions)
    end
end)
