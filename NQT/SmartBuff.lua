local _,AT=...
local catalog={
    mark={mode="unit",r={1126,5232,6756,5234,8907,9884,9885},alias={21849,21850}},
    thorns={mode="unit",r={467,782,1075,8914,9756,9910}},
    intellect={mode="unit",r={1459,1460,1461,10156,10157},alias={23028}},
    fortitude={mode="unit",r={1243,1244,1245,2791,10937,10938},alias={21562,21564}},
    spirit={mode="unit",r={14752,14818,14819,27841},alias={27681}},
    might={mode="unit",r={19740,19834,19835,19836,19837,19838,25291},alias={25782,25916}},
    wisdom={mode="unit",r={19742,19850,19852,19853,19854,25290},alias={25894,25918}},
    kings={mode="unit",r={20217},alias={25898}},
    light={mode="unit",r={19977,19978,19979},alias={25890}},
    sanctuary={mode="unit",r={20911,20912,20913,20914},alias={25899}},
    shout={mode="group",r={6673,5242,6192,11549,11550,11551,25289}},
    earth={mode="group",r={8075,8160,8161,10442,25361},totem=2},
    shield={mode="self",r={324,325,905,945,8134,10431,10432},alias={24398,33736,974}},
    hawk={mode="self",r={13165,14318,14319,14320,14321,14322},alias={13163,5118,13159,13161,20043,20190,13164}},
    trueshot={mode="group",r={19506,20905,20906}},
    demon={mode="self",r={687,696,706,1086,11733,11734,11735},alias={28176}},
    mageArmor={mode="self",r={6117,22782,22783},alias={168,7300,7301,7302,7320,10219,10220}},
    innerFire={mode="self",r={588,7128,602,1006,10951,10952}},
}
local plans={
    DRUID={"mark"}, MAGE={"intellect","mageArmor"}, PRIEST={"fortitude","spirit","innerFire"},
    WARRIOR={"shout"}, SHAMAN={"shield","earth"}, HUNTER={"hawk","trueshot"},
    WARLOCK={"demon"}, PALADIN={}, ROGUE={},
}
local classes={"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","SHAMAN","MAGE","WARLOCK","DRUID"}
local defaults={WARRIOR="might",PALADIN="kings",HUNTER="might",ROGUE="might",PRIEST="wisdom",
    SHAMAN="kings",MAGE="wisdom",WARLOCK="wisdom",DRUID="kings"}
local choices={"kings","might","wisdom","light","sanctuary","skip"}
local choiceLabels={kings="Blessing of Kings",might="Blessing of Might",wisdom="Blessing of Wisdom",
    light="Blessing of Light",sanctuary="Blessing of Sanctuary",skip="Skip"}
local overlay,preview,watcher,queued,nextAction,syncedBody
local function ordinary(v)
    return not issecretvalue or not issecretvalue(v)
end
-- Keep false distinct from an unavailable or restricted result.
local function safe(v) if ordinary(v) then return v end end
local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b,c,d,e,f=pcall(fn,...)
    if ok then return safe(a),safe(b),safe(c),safe(d),safe(e),safe(f) end
end
local function shortClass() local _,class=call(UnitClass,"player");return class end
function AT.IsSmartBuffPaladin() return shortClass()=="PALADIN" end
local function spellName(id)
    return call(C_Spell and C_Spell.GetSpellName,id) or call(GetSpellInfo,id)
end
local function known(id)
    return call(IsPlayerSpell,id)==true or call(IsSpellKnown,id)==true
        or call(C_SpellBook and C_SpellBook.IsSpellKnown,id,Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player)==true
end
local function spellFor(key)
    local def=catalog[key]
    if not def then return end
    local ids,names={},{}
    for _,list in ipairs({def.r,def.alias or {}}) do
        for _,id in ipairs(list) do
            ids[id]=true
            local name=spellName(id)
            if type(name)=="string" then names[name]=true end
        end
    end
    for i=#def.r,1,-1 do
        local id=def.r[i]
        local name=spellName(id)
        if known(id) and call(C_Spell and C_Spell.IsSpellPassive or IsPassiveSpell,id)~=true
            and type(name)=="string" and #name<=160 and not name:find("[%c%[%];/]") then
            local icon=call(C_Spell and C_Spell.GetSpellTexture or GetSpellTexture,id)
            return {id=id,name=name,icon=icon,mode=def.mode,totem=def.totem,ids=ids,names=names}
        end
    end
end
local function ownRealm()
    return call(GetNormalizedRealmName) or call(GetRealmName)
end
local function nameKey(name,realm)
    if type(name)~="string" then return end
    name=name:match("^%s*(.-)%s*$")
    if #name==0 or #name>96 or name:find("[%c%[%];/|]") then return end
    local char,suffix=name:match("^([^%-]+)%-(.+)$")
    char=char or name
    realm=suffix or (type(realm)=="string" and realm~="" and realm) or ownRealm()
    if char:find("[%s%-]") or type(realm)~="string" or realm=="" then return end
    local lower=strlower or string.lower
    local shown=char.."-"..realm:gsub("[%s%-]","")
    return lower(shown),shown
end
local function config(create)
    if not AT.char then return end
    local cfg=AT.char.smartBuffAssignments
    if type(cfg)~="table" and create then cfg={}; AT.char.smartBuffAssignments=cfg end
    return type(cfg)=="table" and cfg or nil
end
function AT.GetSmartBuffAssignment(class,name)
    local cfg=config()
    if name then
        local k=nameKey(name)
        local v=k and cfg and cfg.names and cfg.names[k]
        return type(v)=="table" and choiceLabels[v.key] and v.key or nil
    end
    return cfg and cfg.classes and choiceLabels[cfg.classes[class]] and cfg.classes[class] or defaults[class]
end
function AT.SetSmartBuffAssignment(class,name,key)
    if not AT.IsSmartBuffPaladin() or (key and not choiceLabels[key]) then return false end
    local cfg=config(true)
    if not cfg then return false end
    if name then
        local k,shown=nameKey(name)
        if not k then return false end
        if type(cfg.names)~="table" then cfg.names={} end
        if key and not cfg.names[k] then
            local n=0;for _ in pairs(cfg.names) do n=n+1 end
            if n>=100 then return false end
        end
        cfg.names[k]=key and {name=shown,key=key} or nil
    elseif defaults[class] then
        if type(cfg.classes)~="table" then cfg.classes={} end
        cfg.classes[class]=key
    else return false end
    AT.RefreshSmartBuff()
    return true
end
local function choiceLabel(key)
    local def=catalog[key]
    return def and spellName(def.r[1]) or choiceLabels[key] or "Class default"
end
local function eligible(unit)
    if unit=="player" then return call(UnitIsDeadOrGhost,unit)~=true end
    return call(UnitExists,unit)==true and call(UnitIsConnected,unit)~=false
        and call(UnitIsDeadOrGhost,unit)~=true and call(UnitCanAssist,"player",unit)==true
end
local function recipients()
    local list={{unit="player",subgroup=true}}
    if call(IsInRaid)==true then
        local groups={}
        local n=math.min(40,tonumber(call(GetNumGroupMembers)) or 0)
        local mine
        for i=1,n do
            local _,_,group=call(GetRaidRosterInfo,i)
            local unit="raid"..i
            groups[i]=group
            if call(UnitIsUnit,unit,"player")==true then mine=group end
        end
        for i=1,n do
            local unit="raid"..i
            if call(UnitIsUnit,unit,"player")~=true then
                list[#list+1]={unit=unit,subgroup=mine~=nil and mine==groups[i]}
            end
        end
    else
        local n=math.min(4,tonumber(call(GetNumSubgroupMembers)) or 0)
        for i=1,n do list[#list+1]={unit="party"..i,subgroup=true} end
    end
    return list
end
local function inRange(spell,unit)
    if unit=="player" then return true end
    if spell and spell.mode=="unit" then
        local r=call(C_Spell and C_Spell.IsSpellInRange,spell.id,unit)
        if r==nil then r=call(IsSpellInRange,spell.name,unit) end
        if r==true or r==1 then return true end
        if r==false or r==0 then return false end
    end
    local r,checked=call(UnitInRange,unit)
    return checked~=true or r~=false
end
local function auraSnapshot(unit)
    local ids,names={},{}
    local api=C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not api and type(UnitBuff)~="function" then return end
    for i=1,80 do
        local name,id
        if api then
            local ok,a=pcall(api,unit,i,"HELPFUL")
            if not ok or not ordinary(a) then return end
            if a==nil then return {ids=ids,names=names} end
            if type(a)~="table" then return end
            name,id=safe(a.name),safe(a.spellId)
        else
            local ok,n,_,_,_,_,_,_,_,_,spell=pcall(UnitBuff,unit,i)
            if not ok or not ordinary(n) then return end
            if not n then return {ids=ids,names=names} end
            name,id=n,safe(spell)
        end
        if type(id)~="number" and type(name)~="string" then return end
        if type(id)=="number" then ids[id]=true end
        if type(name)=="string" then names[name]=true end
    end
end
local function hasAura(snapshot,spell)
    if not snapshot then return nil end
    for id in pairs(spell.ids) do if snapshot.ids[id] then return true end end
    for name in pairs(spell.names) do if snapshot.names[name] then return true end end
    return false
end
local function currentName(unit)
    local n,r=call(UnitFullName,unit)
    if not n then n,r=call(UnitName,unit) end
    return n,r
end
local function makePlan(class)
    if not plans[class] then return {} end
    if class=="ROGUE" then
        local main,_,_,_,off=call(GetWeaponEnchantInfo)
        if call(IsPlayerSpell,2842)==true or (tonumber(call(UnitLevel,"player")) or 0)>=20 then
            if main==false and call(GetInventoryItemID,"player",16) then return {{name="Apply main-hand poison",who="Use a poison from your bags."}} end
            if off==false and call(GetInventoryItemID,"player",17) then return {{name="Apply off-hand poison",who="Use a poison from your bags."}} end
        end
        return {}
    end
    local list,spells,units,snapshots={}, {}, recipients(),{}
    local function get(key)
        if spells[key]==nil then spells[key]=spellFor(key) or false end
        return spells[key] or nil
    end
    local function check(key,r)
        local unit=r.unit
        local spell=get(key)
        if not spell or spell.mode=="self" and unit~="player" or spell.mode=="group" and not r.subgroup
            or spell.totem and call(GetTotemInfo,spell.totem)==true or not inRange(spell,unit) then return end
        if snapshots[unit]==nil then snapshots[unit]=auraSnapshot(unit) or false end
        if hasAura(snapshots[unit],spell)==false then
            local name=currentName(unit)
            local castUnit=(spell.mode=="unit" and unit or "player")
            list[#list+1]={id=spell.id,name=spell.name,icon=spell.icon,unit=castUnit,
                who=spell.mode=="group" and "Nearby party" or name or "You"}
            return true
        end
    end
    if class=="PALADIN" then
        local cfg=config()
        for _,r in ipairs(units) do
            if eligible(r.unit) then
                local _,classToken=call(UnitClass,r.unit)
                local n,realm=currentName(r.unit)
                local k=nameKey(n,realm)
                local entry=k and cfg and cfg.names and cfg.names[k]
                local explicit=type(entry)=="table" and choiceLabels[entry.key] and entry.key
                local assigned=cfg and cfg.classes and choiceLabels[cfg.classes[classToken]] and cfg.classes[classToken]
                local key=explicit or assigned or defaults[classToken]
                if key and key~="skip" then
                    if not explicit and not assigned and not get(key) then
                        for _,fallback in ipairs({"kings","might","wisdom"}) do
                            if get(fallback) then key=fallback;break end
                        end
                    end
                    check(key,r)
                end
            end
        end
    else
        for _,key in ipairs(plans[class]) do
            local spell=get(key)
            if spell then
                for _,r in ipairs(units) do
                    if eligible(r.unit) and check(key,r) and spell.mode=="group" then break end
                end
            end
        end
    end
    return list
end
AT.GetSmartBuffPlan=makePlan

local function draw(plan)
    if not overlay then return end
    local entry=plan and plan[1]
    if preview then
        overlay.text:SetText("Buff reminder")
        overlay.detail:SetText("Drag to place  |  Click Done Moving")
        overlay.icon:SetTexture(135987)
    elseif entry then
        overlay.text:SetText(entry.name)
        overlay.detail:SetText(entry.who..(#plan>1 and ("  |  "..#plan.." missing") or ""))
        overlay.icon:SetTexture(entry.icon or 135987)
    end
    overlay:EnableMouse(preview==true)
    overlay:SetShown(preview==true or entry~=nil)
end
local function body(entry)
    if not entry or not entry.unit then return "#showtooltip" end
    return "#showtooltip\n/cast [@"..entry.unit..",help,nodead,nocombat] "..entry.name
end
function AT.RefreshSmartBuff()
    if not AT.db or not AT.char then return end
    local enabled=AT.db.enabled~=false and AT.db.smartBuffEnabled==true
    local plan=enabled and makePlan(shortClass()) or nil
    nextAction=plan and plan[1]
    draw(plan)
    if call(InCombatLockdown)==true then return end
    local command=body(nextAction)
    if AT.SyncSmartBuffAction and syncedBody~=command then
        if AT.SyncSmartBuffAction(command,false) then syncedBody=command end
    end
end
function AT.PickupSmartBuffMacro()
    if not AT.db or AT.db.enabled==false or AT.db.smartBuffEnabled~=true then return false,"Enable Smart Buff in Classes first." end
    if shortClass()=="ROGUE" then return false,"Rogue poison reminders do not apply or choose poisons for you." end
    if not plans[shortClass()] then return false,"No supported buff spells for this class." end
    AT.RefreshSmartBuff()
    if AT.SyncSmartBuffAction then return AT.SyncSmartBuffAction(body(nextAction),true) end
    return false,"WoW's macro editor is unavailable."
end
function AT.IsSmartBuffPreview() return preview==true end
function AT.SetSmartBuffPreview(state)
    if not overlay then return end
    if not state and overlay.isMoving then overlay.finishDrag() end
    preview=state==true
    AT.RefreshSmartBuff()
end
local function createOverlay()
    local f=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
    f:SetSize(257,52);f:SetFrameStrata("HIGH");f:SetClampedToScreen(true);f:SetMovable(true)
    f:SetBackdrop({bgFile="Interface/Buttons/WHITE8X8",edgeFile="Interface/Tooltips/UI-Tooltip-Border",
        edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
    f:SetBackdropColor(.024,.049,.064,.97);f:SetBackdropBorderColor(.29,.74,.68,1)
    local pos=AT.char.smartBuffPosition
    local x,y=type(pos)=="table" and tonumber(pos.x),type(pos)=="table" and tonumber(pos.y)
    f:SetPoint("CENTER",UIParent,"CENTER",x or 0,y or -190)
    f.icon=f:CreateTexture(nil,"ARTWORK");f.icon:SetSize(33,33);f.icon:SetPoint("LEFT",10,0)
    f.text=f:CreateFontString(nil,"OVERLAY","GameFontNormal");f.text:SetPoint("TOPLEFT",52,-9);f.text:SetPoint("RIGHT",-8,0)
    f.text:SetJustifyH("LEFT");f.text:SetWordWrap(false)
    f.detail=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");f.detail:SetPoint("BOTTOMLEFT",52,9)
    f.detail:SetPoint("RIGHT",-8,0);f.detail:SetJustifyH("LEFT");f.detail:SetWordWrap(false)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function() if preview then f.isMoving=true;f:StartMoving() end end)
    f.finishDrag=function()
        if not f.isMoving then return end
        f:StopMovingOrSizing();f.isMoving=nil
        local cx,cy=f:GetCenter()
        local rx,ry=UIParent:GetCenter()
        if cx and cy and rx and ry then
            AT.char.smartBuffPosition={x=cx-rx,y=cy-ry}
            f:ClearAllPoints();f:SetPoint("CENTER",UIParent,"CENTER",cx-rx,cy-ry)
        end
    end
    f:SetScript("OnDragStop",f.finishDrag)
    f:Hide()
    return f
end

local setup
function AT.OpenSmartBuffSetup()
    if not AT.IsSmartBuffPaladin() then return false,"Your class uses the same buff rules for everyone." end
    if type(MenuUtil)~="table" or not MenuUtil.CreateContextMenu then return false,"WoW's dropdown API is unavailable." end
    if not setup then
        setup=CreateFrame("Frame","NQTBlessingSetup",UIParent,"BackdropTemplate")
        setup:SetSize(385,374); setup:SetPoint("CENTER"); setup:SetFrameStrata("FULLSCREEN_DIALOG")
        setup:SetBackdrop({bgFile="Interface/Buttons/WHITE8X8",edgeFile="Interface/Tooltips/UI-Tooltip-Border",
            edgeSize=14,insets={left=4,right=4,top=4,bottom=4}})
        setup:SetBackdropColor(.027,.048,.059,.985);setup:SetBackdropBorderColor(.28,.67,.65,1)
        if UISpecialFrames then table.insert(UISpecialFrames,"NQTBlessingSetup") end
        local close=CreateFrame("Button",nil,setup,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-4,-4)
        local function line(txt,x,y,style)
            local l=setup:CreateFontString(nil,"OVERLAY",style or "GameFontHighlightSmall")
            l:SetPoint("TOPLEFT",x,y);l:SetText(txt);return l
        end
        local function btn(label,width,x,y,fn)
            local b=CreateFrame("Button",nil,setup,"UIPanelButtonTemplate");b:SetSize(width,22)
            b:SetPoint("TOPLEFT",x,y);b:SetText(label);b:SetScript("OnClick",fn);return b
        end
        local function selectBlessing(owner,title,set)
            MenuUtil.CreateContextMenu(owner,function(_,root)
                root:CreateTitle(title)
                root:CreateButton("Reset to default",function()set(nil) end)
                for _,key in ipairs(choices) do
                    local value=key
                    root:CreateButton(choiceLabel(value),function()set(value) end)
                end
            end)
        end
        line("Paladin blessing assignments",17,-15,"GameFontNormalLarge")
        line("Class defaults",17,-43,"GameFontNormal")
        for i,code in ipairs(classes) do
            local class=code
            local y=-61-(i-1)*24
            local label=LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class
            line(label,22,y-4)
            local function refresh(b) b:SetText(choiceLabel(AT.GetSmartBuffAssignment(class))) end
            local b=btn("",215,145,y,function(self)
                selectBlessing(self,label,function(key) AT.SetSmartBuffAssignment(class,nil,key);refresh(self) end)
            end)
            b:HookScript("OnShow",function(self) refresh(self) end);refresh(b)
        end
        line("Named overrides  |  take priority over class",17,-282,"GameFontNormal")
        local input=CreateFrame("EditBox",nil,setup,"InputBoxTemplate")
        input:SetSize(192,24);input:SetPoint("TOPLEFT",25,-303);input:SetAutoFocus(false);input:SetMaxLetters(96)
        line("Character or Character-Realm",25,-334)
        local message=line("",25,-351)
        btn("Assign",68,224,-304,function(self)
            local raw=input:GetText()
            local k,shown=nameKey(raw)
            if not k then message:SetText("Enter a valid character name.");return end
            input:ClearFocus()
            selectBlessing(self,shown,function(key)
                if AT.SetSmartBuffAssignment(nil,raw,key) then message:SetText(shown..": "..choiceLabel(key))
                else message:SetText("Could not save the override.") end
            end)
        end)
        btn("Saved",67,296,-304,function(self)
            MenuUtil.CreateContextMenu(self,function(_,root)
                root:CreateTitle("Saved overrides")
                local cfg=config()
                local entries={}
                for _,v in pairs(cfg and cfg.names or {}) do entries[#entries+1]=v end
                table.sort(entries,function(a,b) return a.name<b.name end)
                for _,v in ipairs(entries) do
                    local name=v.name
                    root:CreateButton(name.."  |  "..choiceLabel(v.key),function()
                        input:SetText(name);message:SetText("Choose Assign to change or reset.")
                    end)
                end
            end)
        end)
    end
    setup:SetShown(not setup:IsShown())
    return true
end
function AT.InitSmartBuff()
    if watcher or not CreateFrame then return end
    overlay=createOverlay()
    watcher=CreateFrame("Frame")
    for _,event in ipairs({"PLAYER_ENTERING_WORLD","GROUP_ROSTER_UPDATE","SPELLS_CHANGED",
        "UNIT_AURA","UNIT_SPELLCAST_SUCCEEDED","UNIT_CONNECTION","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","UPDATE_INVENTORY_ALERTS","UNIT_INVENTORY_CHANGED"}) do
        pcall(watcher.RegisterEvent,watcher,event)
    end
    watcher:SetScript("OnEvent",function(_,event,unit)
        if event=="UNIT_SPELLCAST_SUCCEEDED" and unit~="player" then return end
        if event=="UNIT_AURA" and (type(unit)~="string" or not (unit=="player" or unit:match("^party%d+$") or unit:match("^raid%d+$"))) then return end
        if event=="PLAYER_REGEN_ENABLED" or event=="GROUP_ROSTER_UPDATE" then AT.RefreshSmartBuff();return end
        if not AT.db.smartBuffEnabled or queued or not (C_Timer and C_Timer.After) then return end
        queued=true
        C_Timer.After(.3,function() queued=nil;AT.RefreshSmartBuff() end)
    end)
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(2,function() if AT.db.smartBuffEnabled then AT.RefreshSmartBuff() end end)
    end
    AT.RefreshSmartBuff()
end

