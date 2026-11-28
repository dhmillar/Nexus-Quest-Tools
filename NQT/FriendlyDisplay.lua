local _,AT=...
local nameplate=C_NamePlate
local current,visual,mask={},{},setmetatable({},{__mode="k"})
local hooks=setmetatable({},{__mode="k"})
local pools=setmetatable({},{__mode="k"})
local eventFrame,elapsed,writing,leasing
local key="nameplateShowFriends"
local function plain(v) return not issecretvalue or not issecretvalue(v) end
local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b=pcall(fn,...)
    if ok then
        if not plain(a) then a=nil end
        if not plain(b) then b=nil end
        return a,b
    end
end
local function safe(fn,...)
    if type(fn)~="function" then return end
    local ok,a=pcall(fn,...)
    if ok and plain(a) then return a end
end
local function finite(v) return type(v)=="number" and v==v and v>-math.huge and v<math.huge end
local function on()
    local d=AT.db
    return d and d.enabled~=false and (d.friendlyNames==true or d.friendlyBars==true)
end
local function token(unit)
    return plain(unit) and type(unit)=="string" and unit:match("^nameplate%d+$")~=nil
end
local function outdoor() return safe(IsInInstance)==false end
local function modifiable(plate)
    return plain(plate) and type(plate)=="table" and safe(plate.IsForbidden,plate)==false
end
local function available(plate)
    return modifiable(plate) and (not plate.IsVisible or safe(plate.IsVisible,plate)==true)
end
local function friendly(u)
    return token(u) and safe(UnitExists,u)==true and safe(UnitIsPlayer,u)==true
        and safe(UnitIsUnit,u,"player")~=true and safe(UnitIsFriend,"player",u)==true
        and safe(UnitCanAttack,"player",u)~=true
end
local function setting()
    return safe(C_CVar and C_CVar.GetCVar or GetCVar,key)
end
local function syncVisibility(active)
    if writing or safe(InCombatLockdown)==true then return end
    local db=AT.db
    if not db then return end
    local old=setting()
    local value
    if active and not leasing and old=="0" then value="1"
    elseif not active and db.friendlyDisplayLease==true and old=="1" then value="0" end
    leasing=active
    if not value then
        if not active and old~="1" then db.friendlyDisplayLease=nil end
        return
    end
    writing=true
    safe(C_CVar and C_CVar.SetCVar or SetCVar,key,value)
    writing=nil
    if setting()==value then db.friendlyDisplayLease=(value=="1") or nil end
end
local applying
local function writeAlpha(region,alpha)
    applying=region
    safe(region.SetAlpha,region,alpha)
    applying=nil
end
local function unmask(region)
    local s=mask[region]
    if not s then return end
    mask[region]=nil
    if modifiable(s.plate) and (not region.IsForbidden or safe(region.IsForbidden,region)==false)
        and safe(region.GetAlpha,region)==0 then writeAlpha(region,s.alpha) end
end
local function hideArt(region,plate,u)
    if not plain(region) or type(region)~="table" or region==plate or not region.SetAlpha
        or region.IsForbidden and safe(region.IsForbidden,region)~=false then return end
    local old=mask[region]
    if old and old.u~=u then unmask(region);old=nil end
    local a=safe(region.GetAlpha,region)
    if not finite(a) then return end
    if old and a==0 then return end
    if not old and a==0 then
        -- An already invisible region may still be shown by a later stock update.
        if not hooksecurefunc then return end
    end
    mask[region]={u=u,alpha=a,plate=plate}
    if a~=0 then writeAlpha(region,0) end
    if hooksecurefunc and not hooks[region] then
        hooks[region]=true
        pcall(hooksecurefunc,region,"SetAlpha",function(self,alpha)
            local s=mask[self]
            if not s or applying==self or not plain(alpha) or not finite(alpha) or alpha<=0 then return end
            if not on() or not outdoor() or not friendly(s.u) or not available(s.plate)
                or safe(nameplate.GetNamePlateForUnit,s.u)~=s.plate then return end
            s.alpha=alpha;writeAlpha(self,0)
        end)
    end
end
local function clear(u)
    current[u]=nil
    local f=visual[u]
    if f then if f.owner==u then f:Hide(); f.owner=nil end;visual[u]=nil end
    for region,s in pairs(mask) do if s.u==u then unmask(region) end end
end
local function fontSize(v)
    if not finite(v) then return 16 end
    return math.min(26,math.max(10,math.floor(v+.5)))
end
local function dimension(v,min,max,default)
    if not finite(v) then return default end
    return math.floor(math.min(max,math.max(min,v))+.5)
end
local function nameText(u)
    local first,last=call(UnitName,u)
    local full,ending=call(UnitFullName,u)
    local function named(s) return type(s)=="string" and s:find("%S")~=nil end
    -- The Forever client exposes a two-part name on ordinary unit queries.
    -- Never add a duplicate surname if one API returned the assembled name.
    if named(full) and full:find("%s") then return full end
    if named(first) and first:find("%s") then return first end
    if named(first) and named(last) and first~=last then return first.." "..last end
    if named(full) and named(ending) and full~=ending then return full.." "..ending end
    local shown=safe(GetUnitName,u,false)
    if named(shown) and shown:find("%s") then return shown end
    return first or full or shown
end
local function paintHealth(bar,u)
    local hp,max=safe(UnitHealth,u),safe(UnitHealthMax,u)
    if finite(hp) and finite(max) and max>0 then
        bar:SetMinMaxValues(0,1)
        bar:SetValue(math.max(0,math.min(1,hp/max)))
        return true
    end
    if type(UnitHealthPercent)~="function" or not CurveConstants or not CurveConstants.ScaleTo100 then return false end
    -- Use WoW's display API unchanged, just like Pet Bar. Never inspect or
    -- do any Lua arithmetic on a restricted health value.
    local success,painted=pcall(function()
        local v=UnitHealthPercent(u,false,CurveConstants.ScaleTo100)
        if plain(v) and not finite(v) then return false end
        bar:SetMinMaxValues(0,100)
        bar:SetValue(v)
        return true
    end)
    return success and painted==true
end
local function attach(plate)
    local f=pools[plate]
    if f then return f end
    f=CreateFrame("Frame",nil,UIParent)
    if not pcall(f.SetPoint,f,"BOTTOM",plate,"TOP",0,1) then f:Hide();return end
    f:SetSize(1,1);f:EnableMouse(false);f:SetFrameStrata("MEDIUM");f:SetFrameLevel(20)
    local bar=CreateFrame("StatusBar",nil,f)
    bar:EnableMouse(false)
    bar:SetPoint("BOTTOM",f,"BOTTOM",0,0)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetMinMaxValues(0,1)
    local backdrop=bar:CreateTexture(nil,"BACKGROUND")
    backdrop:SetPoint("TOPLEFT",-1,1);backdrop:SetPoint("BOTTOMRIGHT",1,-1)
    backdrop:SetColorTexture(.025,.022,.02,1)
    local name=f:CreateFontString(nil,"OVERLAY","GameFontNormal")
    name:SetJustifyH("CENTER")
    f.name,f.bar=name,bar
    f:Hide();pools[plate]=f
    return f
end
local function maskPlate(plate,u)
    -- Mask only this friendly player's unit art, never the native anchor,
    -- hitbox, NPC, pet, enemy, or another addon's global settings.
    for _,k in ipairs({"UnitFrame","unitFramePlater","unitFrame","ActorNameSpecial","ActorTitleSpecial","unitName","healthBar","HealthBar","nameText","castBar"}) do
        hideArt(plate[k],plate,u)
    end
    local function maskOwned(ok,...)
        if not ok then return end
        for i=1,math.min(32,select("#",...)) do hideArt((select(i,...)),plate,u) end
    end
    -- Attached third-party artwork can be safely attributed to this exact
    -- unit. Detached frames are left under their addon's control.
    if plate.GetChildren then maskOwned(pcall(plate.GetChildren,plate)) end
    if plate.GetRegions then maskOwned(pcall(plate.GetRegions,plate)) end
end
local function update(u)
    if not on() or not outdoor() or not friendly(u) then clear(u);return end
    local plate=safe(nameplate.GetNamePlateForUnit,u)
    if not available(plate) then clear(u);return end
    local previous=pools[plate]
    if previous and previous.owner and previous.owner~=u then clear(previous.owner) end
    local klass=select(2,call(UnitClass,u))
    local c=type(klass)=="string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[klass]
    if type(c)~="table" or not finite(c.r) or not finite(c.g) or not finite(c.b) then clear(u);return end
    local d=AT.db
    local n=d.friendlyNames==true and nameText(u)
    local names=type(n)=="string" and n~=""
    if not names and d.friendlyBars~=true then clear(u);return end
    local f=attach(plate)
    if not f then clear(u);return end
    local bars=d.friendlyBars==true and paintHealth(f.bar,u)
    if not names and not bars then clear(u);return end
    if visual[u] and visual[u]~=f then clear(u) end
    visual[u],current[u],f.owner=f,true,u
    if names then
        f.name:SetFont(STANDARD_TEXT_FONT or "Fonts\\ARIALN.TTF",fontSize(d.friendlyNameSize),"OUTLINE")
        f.name:SetText(n);f.name:SetTextColor(c.r,c.g,c.b)
        f.name:ClearAllPoints()
        f.name:SetPoint("BOTTOM",bars and f.bar or f,bars and "TOP" or "BOTTOM",0,bars and 2 or 0)
    end
    if bars then
        f.bar:SetSize(dimension(d.friendlyBarWidth,32,160,64),dimension(d.friendlyBarHeight,4,26,9))
        f.bar:SetStatusBarColor(c.r,c.g,c.b)
    end
    f.name:SetShown(names);f.bar:SetShown(bars);f:Show()
    maskPlate(plate,u)
end
function AT.RefreshFriendlyDisplay()
    if not eventFrame then return end
    local show=on() and outdoor()
    syncVisibility(show)
    if not show then
        for u in pairs(current) do clear(u) end
        for region in pairs(mask) do unmask(region) end
        return
    end
    for u in pairs(current) do update(u) end
    -- A bounded refresh handles existing stock plates with missing Lua unit fields.
    local plates=safe(nameplate.GetNamePlates)
    if type(plates)~="table" or not next(plates) then return end
    local seen={}
    for _,p in ipairs(plates) do
        if available(p) then
            local u=p.namePlateUnitToken or p.unitToken or (p.UnitFrame and p.UnitFrame.unit)
            if token(u) and safe(nameplate.GetNamePlateForUnit,u)==p then update(u)
            else seen[p]=true end
        end
    end
    if next(seen) then
        for i=1,60 do
            local u="nameplate"..i
            local p=safe(nameplate.GetNamePlateForUnit,u)
            if p and seen[p] then update(u);seen[p]=nil;if not next(seen) then break end end
        end
    end
end
function AT.InitFriendlyDisplay()
    if eventFrame or not nameplate or not CreateFrame then return end
    eventFrame=CreateFrame("Frame")
    for _,e in ipairs({"NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED","UNIT_HEALTH","UNIT_MAXHEALTH",
        "UNIT_NAME_UPDATE","UNIT_FACTION","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED"}) do pcall(eventFrame.RegisterEvent,eventFrame,e) end
    eventFrame:SetScript("OnEvent",function(_,e,u)
        if e=="PLAYER_ENTERING_WORLD" or e=="PLAYER_REGEN_ENABLED" then AT.RefreshFriendlyDisplay();return end
        if not token(u) then return end
        if e=="NAME_PLATE_UNIT_REMOVED" then clear(u);return end
        if e=="NAME_PLATE_UNIT_ADDED" then clear(u);update(u)
        elseif current[u] or e=="UNIT_NAME_UPDATE" or e=="UNIT_FACTION" then update(u) end
    end)
    eventFrame:SetScript("OnUpdate",function(_,delta)
        if not next(current) then return end
        elapsed=(elapsed or 0)+delta
        if elapsed<.5 then return end
        elapsed=0
        for u in pairs(current) do
            local f=visual[u]
            local p=safe(nameplate.GetNamePlateForUnit,u)
            if not on() or not outdoor() or not friendly(u) or not available(p) or pools[p]~=f then clear(u)
            else maskPlate(p,u) end
        end
    end)
    AT.RefreshFriendlyDisplay()
end

