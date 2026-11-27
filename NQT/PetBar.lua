local _,AT=...
local bar,events,listening,anchoredPlate,anchoredToken
local tokenHint,removedPlate,recheck
local function read(fn,unit,kind)
    if type(fn)~="function" then return end
    local ok,value=pcall(fn,unit)
    if ok and (not issecretvalue or not issecretvalue(value)) and type(value)==kind then return value end
end
local function finite(value)
    return value~=nil and value==value and math.abs(value)<math.huge
end
local function safe(fn,...)
    if type(fn)~="function" then return end
    local ok,value=pcall(fn,...)
    if ok and (not issecretvalue or not issecretvalue(value)) then return value end
end
local function ownsUnit(unit)
    if issecretvalue and issecretvalue(unit) or type(unit)~="string" then return false end
    if safe(UnitIsUnit,"pet",unit)==true then return true end
    local pet=read(UnitGUID,"pet","string")
    return pet~=nil and pet==read(UnitGUID,unit,"string")
end
local function plateToken(frame)
    local token=frame.namePlateUnitToken
    if issecretvalue and issecretvalue(token) then return end
    if type(token)=="string" and token~="" then return token end
end
local function usable(plate)
    return plate and plate~=removedPlate and plate.IsForbidden and safe(plate.IsForbidden,plate)==false
        and safe(plate.IsVisible,plate)==true
end
local function petPlate()
    if not C_NamePlate then return end
    local plate=safe(C_NamePlate.GetNamePlateForUnit,"pet")
    if usable(plate) then
        local token=plateToken(plate)
        if not token or ownsUnit(token) then return plate,token or tokenHint end
    end
    if ownsUnit(tokenHint) then
        plate=safe(C_NamePlate.GetNamePlateForUnit,tokenHint)
        if usable(plate) then return plate,tokenHint end
    end
    local list=safe(C_NamePlate.GetNamePlates)
    for _,candidate in ipairs(type(list)=="table" and list or {}) do
        if usable(candidate) then
            local token=plateToken(candidate)
            if token and ownsUnit(token) then return candidate,token end
        end
    end
end
local function detach()
    if not bar then return end
    bar:Hide()
    if anchoredPlate then
        bar:ClearAllPoints()
        bar:SetParent(UIParent)
    end
    anchoredPlate,anchoredToken=nil,nil
end
local function createBar()
    bar=CreateFrame("StatusBar",nil,UIParent)
    bar:SetSize(74,8)
    bar:SetMinMaxValues(0,100)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:EnableMouse(false)
    local bg=bar:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints(bar);bg:SetColorTexture(.035,.045,.04,.88)
    bar.edge={}
    local function edge(a,b,horizontal)
        local line=bar:CreateTexture(nil,"OVERLAY")
        line:SetPoint(a,bar,a);line:SetPoint(b,bar,b)
        if horizontal then line:SetHeight(1) else line:SetWidth(1) end
        bar.edge[#bar.edge+1]=line
    end
    edge("TOPLEFT","TOPRIGHT",true)
    edge("BOTTOMLEFT","BOTTOMRIGHT",true)
    edge("TOPLEFT","BOTTOMLEFT",false)
    edge("TOPRIGHT","BOTTOMRIGHT",false)
    local label=bar:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    label:SetPoint("CENTER")
    label:SetShadowOffset(1,-1)
    local face=label:GetFont()
    if face then label:SetFont(face,8,"OUTLINE") end
    bar.label=label
    bar:Hide()
end
local function petEvent(_,event,unit)
    if event=="NAME_PLATE_UNIT_ADDED" then
        if not ownsUnit(unit) then return end
        tokenHint,removedPlate=unit,nil
        AT.RefreshPetBar()
        if not anchoredPlate and not recheck and C_Timer and C_Timer.After then
            recheck=true
            C_Timer.After(0,function() recheck=nil;AT.RefreshPetBar() end)
        end
    elseif event=="NAME_PLATE_UNIT_REMOVED" then
        if unit==anchoredToken or unit==tokenHint or ownsUnit(unit) then
            removedPlate,tokenHint=anchoredPlate,nil
            detach()
        end
    elseif event=="PLAYER_ENTERING_WORLD" or event=="UNIT_PET" and unit=="player" then
        tokenHint,removedPlate=nil,nil
        detach()
        AT.RefreshPetBar()
    elseif (event=="UNIT_HEALTH" or event=="UNIT_MAXHEALTH") and unit=="pet" then
        AT.RefreshPetBar()
    end
end
function AT.RefreshPetBar()
    if not events then return end
    local enabled=AT.db and AT.db.enabled~=false and AT.db.petBarEnabled==true
    if not enabled then
        if listening then events:UnregisterAllEvents();listening=nil end
        detach()
        tokenHint,removedPlate=nil,nil
        return
    end
    if not listening then
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
        events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
        events:RegisterUnitEvent("UNIT_PET","player")
        events:RegisterUnitEvent("UNIT_HEALTH","pet")
        events:RegisterUnitEvent("UNIT_MAXHEALTH","pet")
        listening=true
    end
    if read(UnitExists,"pet","boolean")~=true then
        detach()
        return
    end
    local plate,token=petPlate()
    if not plate then detach();return end
    local health=read(UnitHealth,"pet","number")
    local maximum=read(UnitHealthMax,"pet","number")
    if not finite(health) or not finite(maximum) or maximum<=0 then
        if bar then bar:Hide() end
        return
    end
    local percent=100*(math.max(0,math.min(maximum,health))/maximum)
    if not bar then createBar() end
    if anchoredPlate~=plate then
        detach()
        local ok=pcall(function()
            bar:SetParent(plate)
            bar:ClearAllPoints()
            bar:SetPoint("BOTTOM",plate,"TOP",0,2)
            bar:SetFrameLevel(plate:GetFrameLevel()+6)
        end)
        if not ok then
            bar:Hide()
            bar:ClearAllPoints()
            bar:SetParent(UIParent)
            return
        end
        anchoredPlate=plate
    end
    anchoredToken=token
    local low=percent<50
    if low then bar:SetStatusBarColor(.79,.12,.16)
    else bar:SetStatusBarColor(.19,1,.20) end
    for _,edge in ipairs(bar.edge) do
        if low then edge:SetColorTexture(.85,.26,.27,.95)
        else edge:SetColorTexture(.26,.51,.37,.95) end
    end
    bar:SetValue(percent)
    bar.label:SetText(("%d%%"):format(math.floor(percent)))
    bar:Show()
end
function AT.InitPetBar()
    if events or not CreateFrame or not UIParent then return end
    events=CreateFrame("Frame")
    events:SetScript("OnEvent",petEvent)
    AT.RefreshPetBar()
end
