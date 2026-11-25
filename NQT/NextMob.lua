local _, AT = ...
local MAX_VISIBLE = 40
local DISPLAY_SECONDS = 4.0
local ui, active, remaining, accumulator
local request = 0

local function usable(value, kind)
    return (not issecretvalue or not issecretvalue(value)) and type(value) == kind
end

local function numeric(value)
    return usable(value, "number") and value == value and value > -math.huge and value < math.huge
end

local function known(value, expected)
    return usable(value, "boolean") and value == expected
end

local function readableUnit(unit, name, guid)
    if not known(UnitExists(unit),true) then return end
    local hostile, player, dead, blocked =
        UnitCanAttack("player", unit), UnitIsPlayer(unit), UnitIsDeadOrGhost(unit), UnitIsTapDenied(unit)
    if not (known(hostile,true) and known(player,false)
        and known(dead,false) and known(blocked,false)) then return end
    local candidateName, candidateGUID = UnitName(unit), UnitGUID(unit)
    if not usable(candidateName,"string") or candidateName ~= name
        or not usable(candidateGUID,"string") or candidateGUID == "" or candidateGUID == guid then return end
    return candidateGUID
end

local function pointForPlate(unit)
    local frame = C_NamePlate.GetNamePlateForUnit(unit)
    if not frame or not frame.IsForbidden or not known(frame:IsForbidden(),false) or not known(frame:IsVisible(),true) then return end
    local x,y = frame:GetCenter()
    local sourceScale, uiScale = frame:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if not (numeric(x) and numeric(y) and numeric(sourceScale) and numeric(uiScale) and sourceScale > 0 and uiScale > 0) then return end
    local scale = sourceScale/uiScale
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    if not (numeric(width) and numeric(height) and width > 0 and height > 0) then return end
    x, y = x*scale, y*scale
    if x < 0 or y < 0 or x > width or y > height-17 then return end
    return x, y, (x-width*.5)^2 + (y-height*.5)^2
end

local function conceal()
    active = nil
    if ui then ui:Hide() end
end

local function drawAt(x, y)
    ui:ClearAllPoints()
    ui:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", x, y + 13)
    ui:Show()
end

local function update(_, dt)
    if not active then return end
    remaining = remaining - dt
    if remaining <= 0 or not AT.db or not AT.db.enabled then conceal(); return end
    accumulator = accumulator + dt
    if accumulator < .08 then return end
    accumulator = 0
    local ok, x, y = pcall(function()
        local selected = UnitGUID("target")
        if not (usable(selected,"nil") or usable(selected,"string")) then return end
        local guid = readableUnit(active.unit, active.name, selected)
        if guid ~= active.guid then return end
        return pointForPlate(active.unit)
    end)
    if not ok or not x then conceal(); return end
    drawAt(x,y)
end

local function ensureHint()
    if ui then return end
    ui = CreateFrame("Frame", nil, UIParent)
    ui:SetSize(56, 17)
    ui:SetFrameStrata("HIGH")
    ui:EnableMouse(false)
    local background = ui:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(.015,.035,.045,.96)
    local label = ui:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    label:SetText("NEXT")
    label:SetTextColor(.35,1,.82)
    ui:SetScript("OnUpdate", update)
    ui:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    ui:RegisterEvent("PLAYER_ENTERING_WORLD")
    ui:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_ENTERING_WORLD" or active and usable(unit,"string") and unit == active.unit then conceal() end
    end)
    ui:Hide()
end

local function renderCandidates(name, currentGUID)
    local best,bestX,bestY,bestScore
    for i=1,MAX_VISIBLE do
        local unit = "nameplate" .. i
        local ok, guid, x, y, score = pcall(function()
            local candidate = readableUnit(unit,name,currentGUID)
            if not candidate then return end
            local sx,sy,rank=pointForPlate(unit)
            if sx then return candidate,sx,sy,rank end
        end)
        if ok and guid and (not bestScore or score<bestScore) then
            best,bestX,bestY,bestScore={unit=unit,name=name,guid=guid},x,y,score
        end
    end
    if not best then return end
    ensureHint()
    active,remaining,accumulator = best,DISPLAY_SECONDS,0
    drawAt(bestX,bestY)
end

function AT.ShowNextMobHint(name)
    request = request + 1
    local generation = request
    conceal()
    if not (AT.db and AT.db.enabled and AT.db.nextMobHint ~= false and
        C_NamePlate and C_NamePlate.GetNamePlateForUnit and UnitIsTapDenied and UnitGUID and
        usable(name,"string")) then return end
    local currentName, tapped, currentGUID = UnitName("target"), UnitIsTapDenied("target"), UnitGUID("target")
    if not (usable(currentName,"string") and currentName==name and usable(tapped,"boolean")
        and usable(currentGUID,"string") and currentGUID~="") then return end
    if not tapped then
        local currentMark = GetRaidTargetIndex and GetRaidTargetIndex("target")
        if not usable(currentMark,"number") or currentMark ~= (AT.GetPrimaryMarker and AT.GetPrimaryMarker() or 8) then return end
    end
    local function deferred()
        if generation ~= request or not AT.db or not AT.db.enabled or AT.db.nextMobHint == false then return end
        local latest = UnitGUID("target")
        if not usable(latest,"string") or latest ~= currentGUID then return end
        renderCandidates(name, currentGUID)
    end
    -- Capture pre-press marker/tag status above; scan only once the native macro completes.
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function() pcall(deferred) end)
    else
        pcall(deferred)
    end
end