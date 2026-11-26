local _, AT = ...

local icon, watcher
local elapsed = 0
local INTERVAL = 0.08
local ICON_SIZE = 45
local preview, dragX, dragY
local RAPTOR_STRIKE, WING_CLIP, AUTO_SHOT, ARCANE_SHOT = 2973, 2974, 75, 3044
local ownPlateUnit

local function readable(value, kind)
    return (not issecretvalue or not issecretvalue(value)) and type(value) == kind
end

local function boolean(value)
    if readable(value, "boolean") then return value end
    if readable(value, "number") then
        if value == 1 then return true elseif value == 0 then return false end
    end
end

local function call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
end

local function spellRange(id)
    local value = boolean(call(C_Spell and C_Spell.IsSpellInRange, id, "target"))
    if value ~= nil then return value end
    local name = call(C_Spell and C_Spell.GetSpellName, id)
    if not readable(name, "string") then name = call(GetSpellInfo, id) end
    if readable(name, "string") and name ~= "" then
        return boolean(call(IsSpellInRange, name, "target"))
    end
end

local function enabled()
    return AT.db and AT.db.enabled and AT.db.hunterDeadzone
end

local function fighting()
    return enabled() and boolean(call(UnitAffectingCombat, "player")) == true
        and boolean(call(UnitIsDeadOrGhost, "player")) == false
end

local function shouldShow()
    if boolean(call(UnitExists, "target")) ~= true
        or boolean(call(UnitCanAttack, "player", "target")) ~= true
        or boolean(call(UnitIsPlayer, "target")) ~= false
        or boolean(call(UnitIsDeadOrGhost, "target")) ~= false then return false end
    -- Use a positive Hunter melee probe, not a generic interact-range guess or a rejected shot.
    local melee = spellRange(RAPTOR_STRIKE)
    if melee == nil then melee = spellRange(WING_CLIP) end
    if melee ~= true then return false end
    local ranged = spellRange(AUTO_SHOT)
    if ranged == nil then ranged = spellRange(ARCANE_SHOT) end
    return ranged == false
end

local function platePoint(unit, width, height, uiScale)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or not plate.IsForbidden or plate:IsForbidden()
        or not plate.IsVisible or not plate:IsVisible() then return end
    local x = plate:GetCenter()
    local y = plate:GetTop()
    local scale = plate:GetEffectiveScale()
    if not (readable(x, "number") and readable(y, "number") and readable(scale, "number")
        and scale > 0 and uiScale > 0) then return end
    x, y = x * scale / uiScale, y * scale / uiScale + 5
    if x >= 0 and x <= width and y >= 0 and y <= height then return x, y end
end

local function anchor()
    local width, height, scale = UIParent:GetWidth(), UIParent:GetHeight(), UIParent:GetEffectiveScale()
    local x, y
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit and readable(scale, "number") then
        x, y = call(platePoint, ownPlateUnit or "player", width, height, scale)
        if not x and ownPlateUnit then x, y = call(platePoint, "player", width, height, scale) end
        if not x then x, y = call(platePoint, "nameplateplayer", width, height, scale) end
    end
    -- Only use player-relative screen coordinates the client makes available.
    return x or width / 2, y or (height / 2 + math.max(48, math.min(140, height * .10))), width, height
end

local function offset(key)
    local value = AT.db and AT.db[key]
    return readable(value, "number") and value == value and math.abs(value) < math.huge and value or 0
end

local function position()
    local x, y, width, height = anchor()
    local half = ICON_SIZE / 2
    x = math.max(half, math.min(width - half, x + offset("hunterDeadzoneX")))
    y = math.max(0, math.min(height - ICON_SIZE, y + offset("hunterDeadzoneY")))
    icon:ClearAllPoints()
    icon:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", x, y)
end

local function paint()
    if preview then return end
    if not shouldShow() then icon:Hide(); return end
    position()
    icon:Show()
end

local function endDrag()
    if not dragX then return end
    icon:StopMovingOrSizing()
    local x, y = icon:GetCenter()
    if AT.db and readable(x, "number") and readable(y, "number") then
        AT.db.hunterDeadzoneX = offset("hunterDeadzoneX") + x - dragX
        AT.db.hunterDeadzoneY = offset("hunterDeadzoneY") + y - dragY
    end
    dragX, dragY = nil, nil
end

local function tick(_, dt)
    elapsed = elapsed + dt
    if elapsed < INTERVAL then return end
    elapsed = 0
    if not fighting() then watcher:SetScript("OnUpdate", nil); if not preview then icon:Hide() end; return end
    paint()
end

function AT.RefreshHunterDeadzone()
    if not watcher then return end
    elapsed = 0
    if fighting() then
        watcher:SetScript("OnUpdate", tick)
        paint()
    else
        watcher:SetScript("OnUpdate", nil)
        if not preview then icon:Hide() end
    end
end

local function ensureIcon()
    if icon then return end
    icon = CreateFrame("Frame", nil, UIParent)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetMovable(true)
    icon:SetClampedToScreen(true)
    icon:RegisterForDrag("LeftButton")
    icon:SetScript("OnDragStart", function()
        if not preview then return end
        local x, y = icon:GetCenter()
        if not (readable(x, "number") and readable(y, "number")) then return end
        dragX, dragY = x, y
        icon:StartMoving()
    end)
    icon:SetScript("OnDragStop", endDrag)
    icon:SetFrameStrata("MEDIUM")
    icon:EnableMouse(false)
    local texture = icon:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    texture:SetTexture("Interface\\AddOns\\NQT\\HunterDeadzone.tga")
    icon:Hide()
end

function AT.IsHunterDeadzonePreview()
    return preview == true
end

function AT.SetHunterDeadzonePreview(on)
    if (on == true) == (preview == true) then return end
    ensureIcon()
    if on then
        preview = true
        icon:SetFrameStrata("TOOLTIP")
        icon:EnableMouse(true)
        position()
        icon:Show()
    else
        endDrag()
        preview = false
        icon:SetFrameStrata("MEDIUM")
        icon:EnableMouse(false)
        icon:Hide()
        AT.RefreshHunterDeadzone()
    end
end

function AT.InitHunterDeadzone()
    local _, class = call(UnitClass, "player")
    if class ~= "HUNTER" or watcher then return end
    ensureIcon()
    watcher = CreateFrame("Frame", nil, UIParent)
    for _, event in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "PLAYER_TARGET_CHANGED", "PLAYER_DEAD", "PLAYER_ALIVE", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED"}) do
        watcher:RegisterEvent(event)
    end
    watcher:SetScript("OnEvent", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" then
            if not readable(unit, "string") or boolean(call(UnitIsUnit, unit, "player")) ~= true then return end
            ownPlateUnit = unit
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            if not readable(unit, "string") or unit ~= ownPlateUnit then return end
            ownPlateUnit = nil
        elseif event == "PLAYER_ENTERING_WORLD" then
            ownPlateUnit = nil
        elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_DEAD" then
            watcher:SetScript("OnUpdate", nil)
            if not preview then icon:Hide() end
            return
        end
        AT.RefreshHunterDeadzone()
    end)
    AT.RefreshHunterDeadzone()
end
