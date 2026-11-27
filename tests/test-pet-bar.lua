local AT={db={enabled=true}}
local sample={health=100,maximum=100,present=true,name="Ember"}
local watcher,bar,created,reads=nil,nil,0,0
UIParent={}
UIParent.GetEffectiveScale=function()return 1 end
UIParent.GetWidth=function()return 800 end
UIParent.GetHeight=function()return 600 end
local function plate(token)
    return {namePlateUnitToken=token,IsForbidden=function(self)return self.forbidden==true end,
        IsVisible=function()return true end,GetFrameLevel=function()return 14 end}
end
local mine,other=plate("nameplate7"),plate("nameplate9")
local direct,listed,ownership=mine,{other,mine},"nameplate7"
C_NamePlate={
    GetNamePlateForUnit=function(token)
        if token=="pet" then return direct end
        for _,f in ipairs(listed) do if f.namePlateUnitToken==token then return f end end
    end,
    GetNamePlates=function()return listed end,
}
function UnitIsUnit(a,b)return a=="pet" and b==ownership end
local cv={nameplateShowFriendlyPlayerPets="0",nameplateShowFriendlyPlayers="0",nameplateShowFriendlyNpcs="0",nameplateShowFriends="0"}
local writes={}
local timers={}
C_Timer={After=function(delay,callback)timers[#timers+1]={delay,callback}end}
C_CVar={
    GetCVar=function(k)return cv[k] end,
    SetCVar=function(k,v) writes[#writes+1]=k;cv[k]=v end,
}
local combat,instance=false,false
function InCombatLockdown()return combat end
function IsInInstance()return instance end
function UnitGUID(u)
    if u=="pet" or u==ownership then return "Pet-0-0-0-0-19-FF" end
    if u=="nameplate9" or u=="nameplate10" then return "Pet-0-0-0-0-20-AA" end
    return "Creature-0-0-0-0-21-AB"
end
function UnitIsFriend(_,u)return u~="nameplate10" end
local function stock(alpha,forbidden)
    return {a=alpha,IsForbidden=function()return forbidden==true end,
        GetAlpha=function(self)return self.a end,SetAlpha=function(self,v)self.a=v end}
end
mine.UnitFrame,other.UnitFrame=stock(1),stock(.72)
mine.unitFramePlater,other.unitFramePlater=stock(.84),stock(.71)
mine.ActorNameSpecial,mine.ActorTitleSpecial,mine.unitName=stock(.91),stock(.88),stock(.93)
other.ActorTitleSpecial=stock(.67)
for _,font in ipairs({mine.ActorNameSpecial,mine.ActorTitleSpecial,mine.unitName}) do font.IsForbidden=nil; font.GetParent=function()return mine.unitFramePlater end end
local npc,enemy,protected=plate("nameplate11"),plate("nameplate10"),plate("nameplate12")
npc.UnitFrame,enemy.UnitFrame,protected.UnitFrame=stock(.8),stock(.9),stock(1,true)
listed={mine,other,npc,enemy,protected}
function UnitExists(unit) assert(unit=="pet");return sample.present end
function UnitHealth(unit) assert(unit=="pet");reads=reads+1;return sample.health end
function UnitHealthMax(unit) assert(unit=="pet");return sample.maximum end
function UnitName(unit) assert(unit=="pet");return sample.name,"Owner information" end
local function region()
    return {SetAllPoints=function()end,SetColorTexture=function()end,SetPoint=function(self,...)self.point={...} end,
        SetWidth=function()end,SetHeight=function()end,SetShadowOffset=function()end,GetFont=function()return "MockFont" end,SetFont=function()end,
        SetText=function(self,v)self.text=v end}
end
function CreateFrame(kind)
    created=created+1
    local f={events={},shown=true}
    function f:SetScript(k,fn)if k=="OnEvent" then self.onEvent=fn else self.onUpdate=fn end end
    function f:RegisterEvent(e)self.events[e]=true end
    function f:RegisterUnitEvent(e,u)self.events[e]=u end
    function f:UnregisterAllEvents()self.events={} end
    function f:Hide()self.shown=false end
    function f:Show()self.shown=true end
    function f:IsShown()return self.shown end
    if kind=="Frame" then watcher=f;return f end
    assert(kind=="StatusBar")
    bar=f;f.parent=UIParent
    f.SetFrameStrata=function()end
    f.SetSize=function(self,w,h)self.width,self.height=w,h end
    f.SetPoint=function(self,point,owner,anchor,x,y)self.point={point,owner,anchor,x,y} end
    f.ClearAllPoints=function(self)self.point=nil end
    f.SetParent=function(self,o)self.parent=o end
    f.SetFrameLevel=function(self,v)self.level=v end
    f.EnableMouse=function(self,v)self.interactive=v end
    f.SetMinMaxValues=function(self,m,x)self.range={m,x} end
    f.SetStatusBarTexture=function(self,v)assert(v=="Interface\\Buttons\\WHITE8X8")end
    f.CreateTexture=region
    f.CreateFontString=region
    f.SetStatusBarColor=function(self,r,g,b)self.red,self.green=r>g,g end
    f.SetValue=function(self,n)self.value=n end
    return f
end
assert(loadfile("NQT/PetBar.lua"))("NQT",AT)
AT.InitPetBar()
assert(not bar and reads==0 and not next(watcher.events) and #writes==0,"default off, no polling")
AT.db.petBarEnabled=true
AT.RefreshPetBar()
assert(bar.shown and bar.value==100 and bar.label.text=="100%" and bar.green==1 and not bar.red)
assert(bar.parent==UIParent and bar.point[2]==mine and bar.point[1]=="BOTTOM" and bar.point[3]=="TOP" and bar.point[5]>0)
assert(cv.nameplateShowFriendlyPlayerPets=="1" and cv.nameplateShowFriendlyPlayers=="0"
    and cv.nameplateShowFriendlyNpcs=="0" and cv.nameplateShowFriends=="0")
assert(other.UnitFrame.a==0 and mine.UnitFrame.a==0 and npc.UnitFrame.a==.8 and enemy.UnitFrame.a==.9 and protected.UnitFrame.a==1)
assert(mine.unitFramePlater.a==.84 and other.unitFramePlater.a==.71 and other.ActorTitleSpecial.a==.67,"leave both Plater frame opacities and other pets alone")
assert(mine.ActorNameSpecial.a==0 and mine.ActorTitleSpecial.a==0 and mine.unitName.a==0)
for _,opacity in ipairs({.12,1,.05,.84,1}) do
    mine.unitFramePlater.a=opacity
    watcher.onUpdate(watcher,.21)
    assert(mine.unitFramePlater.a==opacity and mine.ActorNameSpecial.a==0 and mine.ActorTitleSpecial.a==0,
        "Plater parent opacity can freely change without re-exposing either label")
end
assert(bar.height==8 and not bar.interactive and bar.range[1]==0 and bar.range[2]==100)
assert(watcher.events.UNIT_HEALTH=="pet" and watcher.events.UNIT_PET=="player" and watcher.events.UNIT_NAME_UPDATE=="pet")
assert(bar.petName.text=="Ember" and bar.petName.point[1]=="BOTTOM" and bar.petName.point[2]==bar and bar.petName.point[3]=="TOP")
sample.name="Cinder"
watcher.onEvent(watcher,"UNIT_NAME_UPDATE","target");assert(bar.petName.text=="Ember")
watcher.onEvent(watcher,"UNIT_NAME_UPDATE","pet");assert(bar.petName.text=="Cinder" and mine.UnitFrame.a==0)
sample.name=nil
watcher.onEvent(watcher,"UNIT_NAME_UPDATE","pet");assert(bar.petName.text=="" and bar.shown)
local function health(n,unit)
    sample.health=n
    watcher.onEvent(watcher,"UNIT_HEALTH",unit or "pet")
end
health(10,"target");assert(bar.value==100)
health(50);assert(bar.value==50 and not bar.red)
health(49.9);assert(bar.red and bar.label.text=="49%")
health(0);assert(bar.value==0 and bar.red and bar.label.text=="0%")
sample.maximum=50;sample.health=30
watcher.onEvent(watcher,"UNIT_MAXHEALTH","pet");assert(bar.value==60 and not bar.red)
sample.present=false
watcher.onEvent(watcher,"UNIT_PET","player");assert(not bar.shown and cv.nameplateShowFriendlyPlayerPets=="0" and other.UnitFrame.a==.72 and mine.unitFramePlater.a==1)
assert(mine.ActorNameSpecial.a==.91 and mine.ActorTitleSpecial.a==.88 and mine.unitName.a==.93,"restore original font alpha on dismissal")
sample.present=true
watcher.onEvent(watcher,"UNIT_PET","player");assert(bar.shown and created==2)
watcher.onEvent(watcher,"NAME_PLATE_UNIT_REMOVED","nameplate7")
assert(not bar.shown and bar.parent==UIParent and bar.point==nil,"no stale frame after native removal")
direct=nil;listed={other}
health(40);assert(not bar.shown,"no center fallback or wrong pet")
watcher.onEvent(watcher,"NAME_PLATE_UNIT_ADDED","nameplate9")
assert(not bar.shown,"ignore somebody else's nameplate")
local replacement=plate("nameplate8")
ownership,listed="nameplate8",{other,replacement}
watcher.onEvent(watcher,"NAME_PLATE_UNIT_ADDED","nameplate8")
assert(bar.shown and bar.parent==UIParent and bar.point[2]==replacement and not bar.red,"attach by exact event token")
replacement.forbidden=true
health(40);assert(not bar.shown,"never attach to protected nameplates")
replacement.forbidden=false
AT.RefreshPetBar();assert(bar.shown and bar.parent==UIParent and bar.point[2]==replacement,"recover a visible pet via nameplate enumeration")
local secret=123
issecretvalue=function(v)return v==secret end
health(secret);assert(not bar.shown,"hide if no supported API can display restricted values")
local secretPercent={}
issecretvalue=function(v)return v==secret or v==secretPercent end
CurveConstants={ScaleTo100={}}
Enum={LuaCurveType={Step=1}}
function CreateColor(...)local rgba={...};return {GetRGBA=function()return unpack(rgba) end} end
C_CurveUtil={CreateColorCurve=function()
    return {SetType=function(_,n)assert(n==1)end,AddPoint=function(self,x,c) self[x]=c end}
end}
function UnitHealthPercent(unit,predicted,curve)
    assert(unit=="pet" and not predicted)
    if curve==CurveConstants.ScaleTo100 then return secretPercent end
    assert(curve[.5] and curve[0])
    return curve[0]
end
function bar.label:SetFormattedText(fmt,value)assert(value==secretPercent and fmt=="%.0f%%");self.text="native" end
health(secret);assert(bar.shown and bar.value==secretPercent and bar.red and bar.label.text=="native")
replacement.GetCenter=function()return 345 end
replacement.GetTop=function()return 270 end
replacement.GetEffectiveScale=function()return 1 end
watcher.onEvent(watcher,"PLAYER_ENTERING_WORLD")
assert(bar.shown and bar.point[2]==UIParent and bar.point[4]==345)
replacement.GetCenter=function()return 367 end
watcher.onUpdate(watcher,.05)
assert(bar.point[4]==367,"follows exposed screen coordinates without reparenting")
issecretvalue=nil
sample.health=25
combat=true
AT.db.petBarEnabled=false
AT.RefreshPetBar();assert(not bar.shown and watcher.events.PLAYER_REGEN_ENABLED and cv.nameplateShowFriendlyPlayerPets=="1")
combat=false
watcher.onEvent(watcher,"PLAYER_REGEN_ENABLED")
assert(not next(watcher.events) and cv.nameplateShowFriendlyPlayerPets=="0","defer and restore the exact owned category")
AT.db.petBarEnabled=true;AT.db.enabled=false
AT.RefreshPetBar();assert(not bar.shown and not next(watcher.events))
AT.db.enabled=true;AT.db.petBarEnabled=true
cv.nameplateShowFriendlyPlayerPets="1"
AT.RefreshPetBar()
AT.db.petBarEnabled=false;AT.RefreshPetBar()
assert(cv.nameplateShowFriendlyPlayerPets=="1","do not restore a setting we didn't change")
cv.nameplateShowFriendlyPlayerPets="0"
AT.db.petBarEnabled=true;AT.RefreshPetBar()
instance=true;watcher.onEvent(watcher,"PLAYER_ENTERING_WORLD")
assert(cv.nameplateShowFriendlyPlayerPets=="0","never force exposure in instances")
instance=false; direct=nil; listed={}; timers={}
watcher.onEvent(watcher,"PLAYER_ENTERING_WORLD")
assert(not bar.shown and #timers==4,"saved toggle retries without a ready plate")
cv.nameplateShowFriendlyPlayerPets="0"
listed={replacement}
assert(timers[2][1]==.6);timers[2][2]()
assert(bar.shown and cv.nameplateShowFriendlyPlayerPets=="1","late Plater setting and plate are reconciled without toggling")
AT.db.petBarEnabled=false;AT.RefreshPetBar()
timers[4][2]();assert(not bar.shown and cv.nameplateShowFriendlyPlayerPets=="0","stale startup callback cannot re-enable disabled bar")
for _,key in ipairs(writes) do assert(key=="nameplateShowFriendlyPlayerPets") end
print("PASS Pet Bar: bright green and red threshold, exact pet anchor, pet-only category lease and restoration, confirmed friendly pet filtering and instance guards")
