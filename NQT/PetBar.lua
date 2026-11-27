local _,AT=...
local bar,events,listening,renderStatus,healthColorCurve,pendingLease

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

-- Undo only the old companion setting this addon explicitly leased.
-- The HUD itself never enables or reads nameplates.
local function releaseLegacyLease()
    local db=AT.db
    local key=db and db.petBarNameplateLease
    if key~="nameplateShowFriendlyPlayerPets" and key~="nameplateShowFriendlyPets" then
        pendingLease=nil
        return
    end
    if safe(InCombatLockdown)==true then pendingLease=true;return end
    local get=C_CVar and C_CVar.GetCVar or GetCVar
    local set=C_CVar and C_CVar.SetCVar or SetCVar
    if read(get,key,"string")=="1" then
        safe(set,key,"0")
        if read(get,key,"string")=="1" then pendingLease=true;return end
    end
    db.petBarNameplateLease=nil
    pendingLease=nil
end

local function createBar()
    local bar=CreateFrame("StatusBar",nil,UIParent)
    bar:SetFrameStrata("MEDIUM")
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
    local name=bar:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    name:SetPoint("BOTTOM",bar,"TOP",0,3)
    name:SetShadowOffset(1,-1)
    if face then name:SetFont(face,11,"OUTLINE") end
    bar.petName=name
    bar:Hide()
    return bar
end

local function paintNativeHealth()
    if type(UnitHealthPercent)~="function" or not CurveConstants or not CurveConstants.ScaleTo100 then return false end
    return pcall(function()
        if not healthColorCurve then
            local curve=C_CurveUtil.CreateColorCurve()
            curve:SetType(Enum.LuaCurveType.Step)
            curve:AddPoint(0,CreateColor(.79,.12,.16,1))
            curve:AddPoint(.5,CreateColor(.19,1,.20,1))
            healthColorCurve=curve
        end
        -- Use the client display surfaces without converting restricted values in Lua.
        local color=UnitHealthPercent("pet",false,healthColorCurve)
        local percent=UnitHealthPercent("pet",false,CurveConstants.ScaleTo100)
        bar:SetStatusBarColor(color:GetRGBA())
        bar:SetValue(percent)
        if not pcall(bar.label.SetFormattedText,bar.label,"%.0f%%",percent) then bar.label:SetText("") end
        local r,g,b,a=color:GetRGBA()
        for _,edge in ipairs(bar.edge) do pcall(edge.SetColorTexture,edge,r,g,b,a) end
    end)
end

function AT.RefreshPetBar()
    if not events then return end
    releaseLegacyLease()
    local enabled=AT.db and AT.db.enabled~=false and AT.db.petBarEnabled==true
    if not enabled then
        events:UnregisterAllEvents()
        if pendingLease then events:RegisterEvent("PLAYER_REGEN_ENABLED") end
        listening=nil
        if bar then bar:Hide() end
        return
    end
    if not listening then
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        events:RegisterUnitEvent("UNIT_PET","player")
        events:RegisterUnitEvent("UNIT_NAME_UPDATE","pet")
        events:RegisterUnitEvent("UNIT_HEALTH","pet")
        events:RegisterUnitEvent("UNIT_MAXHEALTH","pet")
        listening=true
    end
    if read(UnitExists,"pet","boolean")~=true then
        if bar then bar:Hide() end
        return
    end
    if not bar then
        local ok,made=pcall(createBar)
        if not ok then renderStatus="could not create the bar";return end
        bar=made
        bar:SetPoint("TOPLEFT",UIParent,"TOPLEFT",24,-158)
    end
    local health=read(UnitHealth,"pet","number")
    local maximum=read(UnitHealthMax,"pet","number")
    if finite(health) and finite(maximum) and maximum>0 then
        local percent=100*(math.max(0,math.min(maximum,health))/maximum)
        local low=percent<50
        if low then bar:SetStatusBarColor(.79,.12,.16)
        else bar:SetStatusBarColor(.19,1,.20) end
        for _,edge in ipairs(bar.edge) do
            if low then edge:SetColorTexture(.85,.26,.27,.95)
            else edge:SetColorTexture(.26,.51,.37,.95) end
        end
        bar:SetValue(percent)
        bar.label:SetText(("%d%%"):format(math.floor(percent)))
    elseif not paintNativeHealth() then
        bar:Hide()
        renderStatus="WoW did not supply a displayable pet health value"
        return
    end
    bar.petName:SetText(read(UnitName,"pet","string") or "")
    renderStatus=nil
    bar:Show()
end

local function statusText()
    if not AT.db or AT.db.enabled==false or AT.db.petBarEnabled~=true then return "off in Classes" end
    if read(UnitExists,"pet","boolean")~=true then return "no active pet" end
    if renderStatus then return renderStatus end
    return safe(bar and bar.IsShown,bar)==true and "visible at the upper left" or "pet health HUD not visible"
end

function AT.InitPetBar()
    if events or not CreateFrame or not UIParent then return end
    events=CreateFrame("Frame")
    events:SetScript("OnEvent",function(_,event,unit)
        if event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_REGEN_ENABLED"
            or event=="UNIT_PET" and unit=="player"
            or (event=="UNIT_HEALTH" or event=="UNIT_MAXHEALTH" or event=="UNIT_NAME_UPDATE") and unit=="pet" then
            AT.RefreshPetBar()
        end
    end)
    if type(SlashCmdList)=="table" then
        SLASH_NQTPETBAR1="/nqtpet"
        SlashCmdList.NQTPETBAR=function() print("NQT Pet Bar: "..statusText()) end
    end
    AT.RefreshPetBar()
end
