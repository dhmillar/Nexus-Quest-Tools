local _, AT = ...
local buttonGroups = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button",
    "MultiBar6Button", "MultiBar7Button",
}
local portraits, scheduled = {}, false

local function ordinary(value)
    return not issecretvalue or not issecretvalue(value)
end

local function matchingTarget(name)
    if not (name and UnitName and UnitCanAttack and UnitIsPlayer) then return false end
    local ok, matches = pcall(function()
        local current = UnitName("target")
        local hostile = UnitCanAttack("player", "target")
        local player = UnitIsPlayer("target")
        return ordinary(current) and ordinary(hostile) and ordinary(player) and
            current == name and hostile and not player
    end)
    return ok and matches
end

local function slotHasOurMacro(button)
    local slot = button.action
    if not ordinary(slot) or type(slot) ~= "number" or slot < 1 then return false end
    local actionType, id = GetActionInfo(slot)
    return ordinary(actionType) and ordinary(id) and actionType == "macro" and type(id) == "number"
        and AT.IsOwnTargetMacro(id)
end

local function hideAll()
    for _, portrait in pairs(portraits) do
        -- SetAlpha on an existing visual texture is not a protected frame mutation.
        portrait.texture:SetAlpha(0)
    end
end

function AT.RefreshPortrait()
    if InCombatLockdown() then return end
    if not (SetPortraitTexture and GetActionInfo and AT.IsOwnTargetMacro) then return end
    local name = AT.GetTargetName()
    if AT.db and AT.db.enabled == false then name = nil end
    local takePortrait = matchingTarget(name)
    for _, prefix in ipairs(buttonGroups) do
        for index = 1, 12 do
            local button = _G[prefix .. index]
            if button then
                local portrait = portraits[button]
                if name and slotHasOurMacro(button) then
                    local icon = button.icon or button.Icon
                    if not portrait and takePortrait and icon then
                        local texture = button:CreateTexture(nil, "ARTWORK", nil, 7)
                        texture:SetAllPoints(icon)
                        texture:SetAlpha(0)
                        portrait = { texture=texture }
                        portraits[button] = portrait
                    end
                    if portrait then
                        if portrait.name ~= name then
                            portrait.name = nil
                            portrait.texture:SetTexture(nil)
                        end
                        if takePortrait then
                            local ok = pcall(SetPortraitTexture, portrait.texture, "target", true)
                            if ok then portrait.name = name end
                        end
                        portrait.texture:SetAlpha(portrait.name and 1 or 0)
                    end
                elseif portrait then
                    if portrait.name ~= name then
                        portrait.name = nil
                        portrait.texture:SetTexture(nil)
                    end
                    portrait.texture:SetAlpha(0)
                end
            end
        end
    end
end

local function queue()
    if InCombatLockdown() then return end
    if scheduled then return end
    if C_Timer and C_Timer.After then
        scheduled = true
        C_Timer.After(0, function()
            scheduled = false
            AT.RefreshPortrait()
        end)
    else
        AT.RefreshPortrait()
    end
end

local barChanges = {
    ACTIONBAR_SLOT_CHANGED=true, ACTIONBAR_PAGE_CHANGED=true, UPDATE_BONUS_ACTIONBAR=true,
    UPDATE_MACROS=true, UPDATE_SHAPESHIFT_FORM=true, UPDATE_OVERRIDE_ACTIONBAR=true,
    UPDATE_VEHICLE_ACTIONBAR=true, UPDATE_POSSESS_BAR=true,
}

local initialized
function AT.InitPortrait()
    if initialized then return end
    initialized = true
    local events = CreateFrame("Frame")
    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED",
        "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "UPDATE_MACROS",
        "UPDATE_SHAPESHIFT_FORM", "UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR", "UPDATE_POSSESS_BAR",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    }) do pcall(events.RegisterEvent, events, event) end
    events:SetScript("OnEvent", function(_, event, unit)
        if InCombatLockdown() then
            if barChanges[event] then hideAll() end
            return
        end
        if (event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED") and (not ordinary(unit) or (unit and unit ~= "target")) then
            return
        end
        queue()
    end)
    queue()
end
