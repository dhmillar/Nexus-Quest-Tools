local AT={db={},LevelGuideNPCServices={[20]={{3,0,.5,.5,"John Smith"},{6,0,.4,.4,"Serena"},{4,0,.3,.3,"Alda"}}}}
local npcs,plates,overlays,queue={},{},{},{}
local event
UIParent={}
local function no()end
local function texture()
    return {SetSize=function(self,w,h)self.w,self.h=w,h end,SetPoint=no,SetTexCoord=no,SetColorTexture=no,
        Show=function(self)self.shown=true end,Hide=function(self)self.shown=false end,
        SetTexture=function(self,value)self.texture=value end}
end
function CreateFrame(_,_,parent)
    local f={parent=parent,SetPoint=function(self,_,owner) if owner then self.anchor=owner;overlays[owner]=self end end,EnableMouse=no,SetFrameLevel=no,SetSize=no,arts={},RegisterEvent=no,
        Show=function(self)self.shown=true end,Hide=function(self)self.shown=false end,
        CreateTexture=function(self,_,kind)local t=texture();if kind=="ARTWORK" then self.arts[#self.arts+1]=t end;return t end,
        SetScript=function(self,_,script)self.event=script end}
    if not parent then event=f end
    return f
end
local function npc(id,name,title,flags)
    local token="nameplate"..id
    flags=flags or {}
    local unit={name=name,title=title,flags=flags}
    local plate={unitToken=token,IsForbidden=function()return flags.forbidden==true end,GetFrameLevel=function()return 5 end}
    npcs[token],plates[token]=unit,plate
    return token,plate,unit
end
function UnitExists(t)return npcs[t]~=nil end
function UnitIsPlayer(t)if not npcs[t].flags.legacy then return npcs[t].flags.player==true end end
function UnitIsDeadOrGhost(t)if not npcs[t].flags.legacy then return npcs[t].flags.dead==true end end
function UnitCanAttack(_,t)return npcs[t].flags.hostile==true end
function UnitPlayerControlled(t)return npcs[t].flags.playerPet==true end
function UnitReaction(t)return npcs[t].flags.hostile and 3 or 5 end
function UnitName(t)return npcs[t].name end
local SECRET={}
function issecretvalue(v)return v==SECRET end
function UnitGUID(t)
    local flag=npcs[t].flags
    return flag.secret and SECRET or flag.pet and "Pet-0-0-0-0-99-00001" or "Creature-0-0-0-0-88-00002"
end
C_TooltipInfo={GetUnit=function(token)
    local n=npcs[token]; if not n.title then return end
    return {lines={{leftText=n.name},{leftText=n.title},{leftText="Quest: vendor trainer repair"}}}
end}
C_NamePlate={GetNamePlateForUnit=function(t)return plates[t] end,GetNamePlates=function()
    local result={}
    for _,p in pairs(plates) do result[#result+1]=p end
    return result
end}
C_Timer={After=function(_,fn)queue[#queue+1]=fn end}
local function check(plate,icon,num)
    local f=overlays[plate];assert(f and f.shown,"no overlay")
    assert(f.parent==UIParent and f.anchor==plate,"must attach without inheriting nameplate opacity")
    local art=f.arts[num or 1]
    assert(art.shown and art.w==42 and art.texture:match(icon.."$"),art.texture or "texture missing")
end
local rem,p=npc(1,"Ruben","Trade Supplies")
local _,p2=npc(2,"Lynnia","Reagents & Repairs")
local _,p3=npc(3,"Ursula","|cffffffff<Hunter Trainer>|r")
local _,p4=npc(4,"Uriah","Engineering Trainer")
local _,p5=npc(5,"Berthan","Gunsmith")
local _,p6=npc(6,"Bernard","Bowyer")
local _,hidden=npc(7,"Vendor","General Goods",{forbidden=true})
local _,pet=npc(8,"Vendor","General Goods",{pet=true})
local _,hostile=npc(9,"Vendor","General Goods",{hostile=true})
local _,known=npc(10,"John Smith","")
local _,uncertain=npc(11,"Nobody","Level 20")
local retry,delayed,retryUnit=npc(12,"Yara",nil)
local _,pl=npc(13,"Player","General Goods",{player=true})
local _,sec=npc(14,"Malla","Alchemy Trainer",{secret=true})
local _,vendor=npc(15,"Serena",nil)
local _,class=npc(16,"Alda",nil)
local _,savanne=npc(17,"Savanne",nil,{legacy=true})
local _,harklane=npc(18,"Harklane",nil)
local _,recycled=npc(19,"Quiet Villager",nil)
harklane.unitFramePlater={ActorNameSpecial={GetText=function()return "Harklane" end},ActorTitleSpecial={GetText=function()return "<Fish Vendor>" end,IsShown=function()return true end}}
recycled.unitFramePlater=harklane.unitFramePlater
function C_TooltipInfo.GetHyperlink(link)
    if link=="unit:Creature-0-0-0-0-89-00003" then
        return {lines={{leftText="Savanne"},{leftText="Fishing Supplies"}}}
    end
end
local old=UnitGUID
function UnitGUID(t) if t=="nameplate17" then return "Creature-0-0-0-0-89-00003" end return old(t) end
assert(loadfile("NQT/VendorIcons.lua"))("NQT",AT)
AT.InitVendorIcons()
check(savanne,"Trade_Fishing");check(harklane,"INV_Misc_Fish_02");assert(not overlays[recycled])
check(p,"INV_Misc_Bag_10")
check(p2,"INV_Misc_Dust_02");check(p2,"Trade_BlackSmithing",2)
check(p3,"Ability_Hunter_AimedShot")
check(p4,"Trade_Engineering")
check(p5,"INV_Ammo_Bullet_01");check(p6,"INV_Ammo_Arrow_02")
check(known,"Trade_BlackSmithing");check(sec,"Trade_Alchemy")
check(vendor,"INV_Misc_Bag_10");check(class,"INV_Misc_Book_11")
for _,guarded in ipairs({hidden,pet,hostile,uncertain,pl,delayed}) do assert(not overlays[guarded]) end
retryUnit.title="Tailoring Trainer"
for _,fn in ipairs(queue) do fn() end
check(delayed,"Trade_Tailoring")
event:event("NAME_PLATE_UNIT_REMOVED",rem);assert(not overlays[p].shown)
event:event("NAME_PLATE_UNIT_ADDED",rem);check(p,"INV_Misc_Bag_10")
AT.db.vendorIcons=false;AT.RefreshVendorIcons()
for _,f in pairs(overlays) do assert(not f.shown) end
AT.db.vendorIcons=true;AT.RefreshVendorIcons()
check(p,"INV_Misc_Bag_10")
AT.db.enabled=false;AT.RefreshVendorIcons();assert(not overlays[p].shown)
print("PASS overhead vendor icons default on, service roles, plate visibility and recycling, per-option disable, protected frames ignored")
