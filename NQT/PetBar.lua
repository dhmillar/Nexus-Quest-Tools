local _,AT=...
local bar,events,listening
local function read(fn,unit,kind)
    if type(fn)~="function" then return end
    local ok,value=pcall(fn,unit)
    if ok and (not issecretvalue or not issecretvalue(value)) and type(value)==kind then return value end
end
local function finite(value)
    return value~=nil and value==value and math.abs(value)<math.huge
end
local function createBar()
    bar=CreateFrame("StatusBar",nil,UIParent)
    bar:SetFrameStrata("MEDIUM")
    bar:SetSize(152,13)
    bar:SetPoint("CENTER",UIParent,"CENTER",0,-116)
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
    bar.label=label
    bar:Hide()
end
local function petEvent(_,event,unit)
    if event=="PLAYER_ENTERING_WORLD" or event=="UNIT_PET" and unit=="player"
        or (event=="UNIT_HEALTH" or event=="UNIT_MAXHEALTH") and unit=="pet" then
        AT.RefreshPetBar()
    end
end
function AT.RefreshPetBar()
    if not events then return end
    local enabled=AT.db and AT.db.enabled~=false and AT.db.petBarEnabled==true
    if not enabled then
        if listening then events:UnregisterAllEvents();listening=nil end
        if bar then bar:Hide() end
        return
    end
    if not listening then
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
        events:RegisterUnitEvent("UNIT_PET","player")
        events:RegisterUnitEvent("UNIT_HEALTH","pet")
        events:RegisterUnitEvent("UNIT_MAXHEALTH","pet")
        listening=true
    end
    if read(UnitExists,"pet","boolean")~=true then
        if bar then bar:Hide() end
        return
    end
    local health=read(UnitHealth,"pet","number")
    local maximum=read(UnitHealthMax,"pet","number")
    if not finite(health) or not finite(maximum) or maximum<=0 then
        if bar then bar:Hide() end
        return
    end
    local percent=100*(math.max(0,math.min(maximum,health))/maximum)
    if not bar then createBar() end
    local low=percent<50
    if low then bar:SetStatusBarColor(.79,.12,.16)
    else bar:SetStatusBarColor(.15,.67,.35) end
    for _,edge in ipairs(bar.edge) do
        if low then edge:SetColorTexture(.85,.26,.27,.95)
        else edge:SetColorTexture(.26,.51,.37,.95) end
    end
    bar:SetValue(percent)
    bar.label:SetText(("Pet %d%%"):format(math.floor(percent)))
    bar:Show()
end
function AT.InitPetBar()
    if events or not CreateFrame or not UIParent then return end
    events=CreateFrame("Frame")
    events:SetScript("OnEvent",petEvent)
    AT.RefreshPetBar()
end
