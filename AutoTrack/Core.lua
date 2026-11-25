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
    minimapAngle = 220,
    questHUDEnabled = false,
    dungeonPositionEnabled = true,
    dungeonPositionAutoOpen = true,
    dungeonPositionShowSelf = true,
    dungeonPositionShowParty = true,
    questPartyProgress = true,
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
        DEFAULT_CHAT_FRAME:AddMessage("|cff39dcceRankor Tools:|r " .. tostring(message))
    end
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
        safeInit("Dungeon Position", AT.InitDungeonPosition)
        safeInit("Settings", AT.InitOptions)
    end
end)
