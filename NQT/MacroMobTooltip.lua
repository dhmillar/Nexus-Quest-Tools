local _, AT = ...

local function readable(value)
    return not (issecretvalue and issecretvalue(value))
end

local function read(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b = pcall(fn, ...)
    if not ok then return end
    if not readable(a) then a = nil end
    if not readable(b) then b = nil end
    return a, b
end

local function plain(value)
    if readable(value) and type(value) == "string" and #value > 0 and #value <= 160
        and not value:find("[%c|]") and value:find("%S") then return value end
end

local function whole(value)
    if readable(value) and type(value) == "number" and value > 0 and value < 10000
        and value % 1 == 0 then return value end
end

local classificationText = {
    normal="Normal", elite="Elite", rare="Rare", rareelite="Rare elite",
    worldboss="Boss", boss="Boss", trivial="Trivial",
}

local function makeLines()
    local name = plain(read(AT.GetTargetName))
    if not name then return "Saved target: Not set", {} end
    local partial = read(AT.IsPartialTarget) == true
    local summary = "Saved target: " .. name .. (partial and " (partial match)" or "")
    local details = {}
    -- A partial name is a search query, not a verified creature identity.
    if partial then return summary, details end
    local profile = read(AT.GetQuestMobProfile, name)
    if type(profile) ~= "table" then return summary, details end
    local minLevel, maxLevel = whole(profile.minLevel), whole(profile.maxLevel)
    local kind = plain(profile.classification)
    kind = kind and classificationText[kind:lower()]
    if minLevel and maxLevel and maxLevel < minLevel then minLevel, maxLevel = nil, nil end
    local level
    if minLevel and maxLevel and minLevel ~= maxLevel then
        level = ("Observed level: %d–%d"):format(minLevel, maxLevel)
    elseif minLevel or maxLevel then
        level = ("Observed level: %d"):format(minLevel or maxLevel)
    end
    if level and kind then level = level .. "  ·  " .. kind end
    if level or kind then details[#details + 1] = level or ("Type: " .. kind) end
    local family = plain(profile.family)
    if family then details[#details + 1] = "Family: " .. family end
    local drops, seen = {}, {}
    if readable(profile.drops) and type(profile.drops) == "table" then
        for i = 1, math.min(16, #profile.drops) do
            local entry = profile.drops[i]
            if readable(entry) and type(entry) == "table" then entry = entry.name end
            local label = plain(entry)
            if label and not seen[label] then
                seen[label] = true
                drops[#drops + 1] = label
                if #drops == 4 then break end
            end
        end
    end
    if #drops > 0 then details[#details + 1] = "Known drops: " .. table.concat(drops, ", ") end
    return summary, details
end

local function alreadyHas(tooltip, summary, count)
    local tooltipName = plain(read(tooltip.GetName, tooltip))
    if not tooltipName then return false end
    -- Blizzard may refresh a tooltip in place. Check the rendered label, not
    -- only the last slot, because the same slot can be rebuilt after a page swap.
    for i = 1, count do
        local line = _G[tooltipName .. "TextLeft" .. i]
        if line and read(line.GetText, line) == summary then return true end
    end
    return false
end

local function onSetAction(tooltip, slot)
    if tooltip ~= GameTooltip or not whole(slot) then return end
    local actionType, macroID = read(GetActionInfo, slot)
    if actionType ~= "macro" or not whole(macroID)
        or read(AT.IsOwnTargetMacro, macroID) ~= true then return end
    local count = whole(read(tooltip.NumLines, tooltip))
    -- If stock has declined to build a tooltip, do not start one ourselves.
    if not count or type(tooltip.AddLine) ~= "function" then return end
    local summary, details = makeLines()
    if alreadyHas(tooltip, summary, count) then return end
    tooltip:AddLine(summary, 1, .82, .38, true)
    for _, line in ipairs(details) do tooltip:AddLine(line, .83, .90, .96, true) end
    if read(tooltip.IsShown, tooltip) == true and type(tooltip.Show) == "function" then
        tooltip:Show()
    end
end

local installed
local function install()
    if installed then return true end
    if not GameTooltip or type(GameTooltip.SetAction) ~= "function"
        or type(hooksecurefunc) ~= "function" then return false end
    -- No click, secure attribute, target, action slot, or native tooltip is
    -- replaced. This reads the slot only after Blizzard builds its tooltip.
    installed = pcall(hooksecurefunc, GameTooltip, "SetAction", onSetAction)
    return installed
end

if not install() and type(CreateFrame) == "function" then
    local listener = CreateFrame("Frame")
    listener:RegisterEvent("PLAYER_LOGIN")
    listener:SetScript("OnEvent", function(self)
        install()
        self:UnregisterEvent("PLAYER_LOGIN")
    end)
end
