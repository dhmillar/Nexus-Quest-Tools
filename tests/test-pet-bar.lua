local AT={db={enabled=true}}
local sample={health=100,maximum=100,present=true,name="Ember"}
local watcher,bar,created,reads=nil,nil,0,0
local cv={nameplateShowFriendlyPlayerPets="0",nameplateShowFriendlyPets="0"}
local writes={}
UIParent={}
C_NamePlate=setmetatable({},{__index=function()error("HUD must not use any nameplate API")end})
C_CVar={
    GetCVar=function(k)return cv[k] end,
    SetCVar=function(k,v) writes[#writes+1]={k,v};cv[k]=v end,
}
local combat=false
function InCombatLockdown()return combat end
function UnitExists(unit) assert(unit=="pet");return sample.present end
function UnitHealth(unit) assert(unit=="pet");reads=reads+1;return sample.health end
function UnitHealthMax(unit) assert(unit=="pet");return sample.maximum end
function UnitName(unit) assert(unit=="pet");return sample.name,"Owner information" end
local function region()
    return {SetAllPoints=function()end,SetColorTexture=function()end,SetPoint=function(self,...)self.point={...} end,
        SetWidth=function()end,SetHeight=function()end,SetShadowOffset=function()end,GetFont=function()return "MockFont" end,
        SetFont=function()end,SetText=function(self,v)self.text=v end}
end
function CreateFrame(kind,_,parent)
    created=created+1
    local f={events={},shown=true,parent=parent}
    function f:SetScript(k,fn) assert(k=="OnEvent","no polling");self.onEvent=fn end
    function f:RegisterEvent(e)assert(not e:find("NAME_PLATE"));self.events[e]=true end
    function f:RegisterUnitEvent(e,u)self.events[e]=u end
    function f:UnregisterAllEvents()self.events={} end
    function f:Hide()self.shown=false end
    function f:Show()self.shown=true end
    function f:IsShown()return self.shown end
    if kind=="Frame" then watcher=f;return f end
    assert(kind=="StatusBar")
    bar=f
    f.SetFrameStrata=function()end
    f.SetSize=function(self,w,h)self.width,self.height=w,h end
    f.SetPoint=function(self,...)self.point={...} end
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
assert(not bar and reads==0 and not next(watcher.events) and #writes==0,"default off")
AT.db.petBarEnabled=true;AT.RefreshPetBar()
assert(bar.shown and bar.value==100 and bar.label.text=="100%" and bar.green==1 and not bar.red)
assert(bar.parent==UIParent and bar.point[2]==UIParent and bar.point[1]=="TOPLEFT")
assert(bar.height==8 and not bar.interactive and bar.range[1]==0 and bar.range[2]==100)
assert(watcher.events.UNIT_HEALTH=="pet" and watcher.events.UNIT_PET=="player" and watcher.events.UNIT_NAME_UPDATE=="pet")
assert(bar.petName.text=="Ember" and bar.petName.point[1]=="BOTTOM" and bar.petName.point[2]==bar)
local anchor=bar.point
sample.name="Cinder"
watcher.onEvent(watcher,"UNIT_NAME_UPDATE","target");assert(bar.petName.text=="Ember")
watcher.onEvent(watcher,"UNIT_NAME_UPDATE","pet");assert(bar.petName.text=="Cinder")
local function health(n,unit)
    sample.health=n
    watcher.onEvent(watcher,"UNIT_HEALTH",unit or "pet")
end
health(10,"target");assert(bar.value==100)
health(50);assert(bar.value==50 and not bar.red)
health(49.9);assert(bar.red and bar.label.text=="49%")
health(0);assert(bar.value==0 and bar.red)
sample.maximum=50;sample.health=30
watcher.onEvent(watcher,"UNIT_MAXHEALTH","pet");assert(bar.value==60 and not bar.red)
sample.present=false;watcher.onEvent(watcher,"UNIT_PET","player");assert(not bar.shown)
sample.present=true;watcher.onEvent(watcher,"UNIT_PET","player");assert(bar.shown and created==2)
watcher.onEvent(watcher,"PLAYER_ENTERING_WORLD")
assert(bar.shown and bar.point==anchor,"dungeon zone changes cannot move or hide the HUD")
combat=true;health(20)
assert(bar.shown and bar.point==anchor and bar.red and #writes==0)
local secret=123
local secretPercent={}
issecretvalue=function(v)return v==secret or v==secretPercent end
health(secret);assert(not bar.shown,"unknown health does not leave a stale bar")
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
-- Migrate only the setting this addon previously owned, never other CVars.
AT.db.petBarNameplateLease="nameplateShowFriendlyPlayerPets";cv.nameplateShowFriendlyPlayerPets="1"
AT.db.petBarEnabled=false
AT.RefreshPetBar()
assert(not bar.shown and watcher.events.PLAYER_REGEN_ENABLED and #writes==0)
combat=false;watcher.onEvent(watcher,"PLAYER_REGEN_ENABLED")
assert(not next(watcher.events) and not AT.db.petBarNameplateLease and #writes==1)
assert(writes[1][1]=="nameplateShowFriendlyPlayerPets" and writes[1][2]=="0")
cv.nameplateShowFriendlyPlayerPets="1"
AT.db.petBarEnabled=true;AT.RefreshPetBar()
assert(bar.shown and bar.point==anchor and cv.nameplateShowFriendlyPlayerPets=="1" and #writes==1)
AT.db.enabled=false;AT.RefreshPetBar();assert(not bar.shown and not next(watcher.events))
print("PASS Pet Bar HUD: health watches, instance/combat persistence, zero nameplate API calls, native restricted-health rendering and one-time legacy restoration")
