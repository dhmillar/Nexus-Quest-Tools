local _,AT=...
local bar,events,listening,anchoredPlate,anchoredToken
local tokenHint,removedPlate,recheck
local healthColorCurve,renderStatus,followElapsed
local masked={}
local settingMode,leasePending,writing
local modernPetCVar="nameplateShowFriendlyPlayerPets"
local legacyPetCVar="nameplateShowFriendlyPets"
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
local function getPetCVar(key)
    return read(C_CVar and C_CVar.GetCVar or GetCVar,key,"string")
end
local function isCombat()
    return safe(InCombatLockdown)==true
end
local function outdoor()
    return safe(IsInInstance)~=true
end
local function setPetCVar(key,value)
    if writing then return false end
    writing=true
    safe(C_CVar and C_CVar.SetCVar or SetCVar,key,value)
    writing=nil
    return getPetCVar(key)==value
end
local function syncPetCVar(wanted)
    local db=AT.db
    if not db or writing or wanted==settingMode and not leasePending then return end
    if isCombat() then
        leasePending=true
        if events then events:RegisterEvent("PLAYER_REGEN_ENABLED") end
        return
    end
    leasePending=nil
    settingMode=wanted
    local leased=db.petBarNameplateLease
    if (leased==modernPetCVar or leased==legacyPetCVar) and (not wanted or getPetCVar(leased)~="1") then
        if getPetCVar(leased)~="1" or setPetCVar(leased,"0") then db.petBarNameplateLease=nil end
    end
    if not wanted then return end
    -- Opt into only the companion category: do not change player/NPC plates
    -- or enable the old master switch on clients that require it.
    local key=getPetCVar(modernPetCVar)~=nil and modernPetCVar or legacyPetCVar
    if getPetCVar(key)=="0" and setPetCVar(key,"1") then db.petBarNameplateLease=key end
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
    local stock=frame.UnitFrame
    token=stock and stock.unit
    if (not issecretvalue or not issecretvalue(token)) and type(token)=="string" and token~="" then return token end
end
local function usable(plate)
    return plate and plate~=removedPlate and plate.IsForbidden and safe(plate.IsForbidden,plate)==false
        and safe(plate.IsVisible,plate)==true
end
local function restoreArt(frame)
    local state=masked[frame]
    if not state then return end
    masked[frame]=nil
    if safe(frame.GetAlpha,frame)==0 then safe(frame.SetAlpha,frame,state.alpha) end
end
local function restoreAllArt()
    for frame in pairs(masked) do restoreArt(frame) end
end
local function hideStockArt(plate,token)
    if not outdoor() or not usable(plate) then return end
    if type(token)~="string" or (issecretvalue and issecretvalue(token)) then return end
    local frame=plate.UnitFrame
    if frame and masked[frame] and masked[frame].token~=token then restoreArt(frame) end
    local own=ownsUnit(token)
    if not own then
        local guid=read(UnitGUID,token,"string")
        if not ((guid and guid:match("^Pet%-")) or safe(UnitIsOtherPlayersPet,token)==true)
            or safe(UnitIsFriend,"player",token)~=true then return end
    end
    if not frame or frame==plate or safe(frame.IsForbidden,frame)~=false then return end
    local alpha=safe(frame.GetAlpha,frame)
    if not finite(alpha) then return end
    if finite(alpha) and alpha~=0 then
        safe(frame.SetAlpha,frame,0)
        if safe(frame.GetAlpha,frame)==0 then masked[frame]={token=token,alpha=alpha} end
    end
end
local function filterExistingPlates()
    local list=C_NamePlate and safe(C_NamePlate.GetNamePlates)
    for _,plate in ipairs(type(list)=="table" and list or {}) do
        if usable(plate) then
            local token=plateToken(plate)
            if not ownsUnit(token) then hideStockArt(plate,token) end
        end
    end
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
        events:SetScript("OnUpdate",nil)
    end
    anchoredPlate,anchoredToken=nil,nil
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
local function screenAnchor(plate)
    if not usable(plate) then return false end
    local x,y=safe(plate.GetCenter,plate),safe(plate.GetTop,plate)
    local scale,root=safe(plate.GetEffectiveScale,plate),safe(UIParent.GetEffectiveScale,UIParent)
    local w,h=safe(UIParent.GetWidth,UIParent),safe(UIParent.GetHeight,UIParent)
    if not (finite(x) and finite(y) and finite(scale) and scale>0 and finite(root) and root>0
        and finite(w) and finite(h)) then return false end
    x,y=x*scale/root,y*scale/root+3
    if x<0 or x>w or y<0 or y>h then return false end
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOM",UIParent,"BOTTOMLEFT",x,y)
    return true
end
local function bindToPlate(plate,token)
    if anchoredPlate==plate then anchoredToken=token;return true end
    detach()
    -- A UIParent child cannot inherit the stock nameplate's hidden art.
    local followsCoordinates=screenAnchor(plate)
    if not followsCoordinates and not pcall(bar.SetPoint,bar,"BOTTOM",plate,"TOP",0,2) then return false end
    followElapsed=0
    events:SetScript("OnUpdate",function(_,dt)
        followElapsed=followElapsed+dt
        if followElapsed<.04 then return end
        followElapsed=0
        local currentToken=usable(plate) and plateToken(plate)
        if not usable(plate) or (currentToken and not ownsUnit(currentToken)) then
            bar:Hide()
        elseif not followsCoordinates or screenAnchor(plate) then bar:Show()
        else bar:Hide() end
    end)
    anchoredPlate,anchoredToken=plate,token
    return true
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
local function petEvent(_,event,unit)
    if event=="PLAYER_LOGOUT" then
        syncPetCVar(false)
        restoreAllArt()
        return
    elseif event=="PLAYER_REGEN_ENABLED" then
        AT.RefreshPetBar()
        return
    elseif event=="NAME_PLATE_UNIT_ADDED" then
        if not ownsUnit(unit) then
            if C_NamePlate and read(UnitExists,"pet","boolean")==true then
                hideStockArt(safe(C_NamePlate.GetNamePlateForUnit,unit),unit)
            end
            return
        end
        tokenHint,removedPlate=unit,nil
        AT.RefreshPetBar()
        if not anchoredPlate and not recheck and C_Timer and C_Timer.After then
            recheck=true
            C_Timer.After(0,function() recheck=nil;AT.RefreshPetBar() end)
        end
    elseif event=="NAME_PLATE_UNIT_REMOVED" then
        for frame,state in pairs(masked) do if state.token==unit then restoreArt(frame) end end
        if unit==anchoredToken or unit==tokenHint or ownsUnit(unit) then
            removedPlate,tokenHint=anchoredPlate,nil
            detach()
        end
    elseif event=="PLAYER_ENTERING_WORLD" or event=="UNIT_PET" and unit=="player" then
        tokenHint,removedPlate=nil,nil
        detach()
        restoreAllArt()
        AT.RefreshPetBar()
        if outdoor() and read(UnitExists,"pet","boolean")==true then filterExistingPlates() end
    elseif (event=="UNIT_HEALTH" or event=="UNIT_MAXHEALTH" or event=="UNIT_NAME_UPDATE") and unit=="pet" then
        AT.RefreshPetBar()
    end
end
function AT.RefreshPetBar()
    if not events or writing then return end
    local enabled=AT.db and AT.db.enabled~=false and AT.db.petBarEnabled==true
    local wanted=enabled and outdoor() and read(UnitExists,"pet","boolean")==true or false
    syncPetCVar(wanted)
    if not wanted then restoreAllArt() end
    if not enabled then
        if not leasePending then events:UnregisterAllEvents();listening=nil end
        detach()
        tokenHint,removedPlate=nil,nil
        return
    end
    if not listening then
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
        events:RegisterEvent("PLAYER_LOGOUT")
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
        events:RegisterUnitEvent("UNIT_PET","player")
        events:RegisterUnitEvent("UNIT_NAME_UPDATE","pet")
        events:RegisterUnitEvent("UNIT_HEALTH","pet")
        events:RegisterUnitEvent("UNIT_MAXHEALTH","pet")
        listening=true
        if wanted then filterExistingPlates() end
    end
    if read(UnitExists,"pet","boolean")~=true then
        detach()
        return
    end
    local plate,token=petPlate()
    if not plate then detach();return end
    local health=read(UnitHealth,"pet","number")
    local maximum=read(UnitHealthMax,"pet","number")
    if not bar then
        local ok,made=pcall(createBar)
        if not ok then renderStatus="could not create the bar";return end
        bar=made
    end
    if not bindToPlate(plate,token) then renderStatus="could not position the bar";return end
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
        detach()
        renderStatus="WoW did not supply a displayable health value"
        return
    end
    bar.petName:SetText(read(UnitName,"pet","string") or "")
    hideStockArt(plate,token or "pet")
    renderStatus=nil
    bar:Show()
end
local function statusText()
    if not AT.db or AT.db.enabled==false or AT.db.petBarEnabled~=true then return "off in General" end
    if read(UnitExists,"pet","boolean")~=true then return "no active pet" end
    if not outdoor() then return "instance: WoW may restrict friendly plates" end
    local category=getPetCVar(modernPetCVar) or getPetCVar(legacyPetCVar)
    local plate=petPlate()
    if not plate then
        return "friendly pet category: "..(category or "not exposed").."; no usable pet nameplate"
    end
    if renderStatus then return "pet nameplate found; "..renderStatus end
    return safe(bar and bar.IsVisible,bar)==true and "visible" or "pet nameplate found; bar not visible"
end
function AT.InitPetBar()
    if events or not CreateFrame or not UIParent then return end
    events=CreateFrame("Frame")
    events:SetScript("OnEvent",petEvent)
    if type(SlashCmdList)=="table" then
        SLASH_NQTPETBAR1="/nqtpet"
        SlashCmdList.NQTPETBAR=function() print("NQT Pet Bar: "..statusText()) end
    end
    AT.RefreshPetBar()
end
