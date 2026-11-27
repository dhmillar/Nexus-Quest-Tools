local AT={db={enabled=true}}
local sample={health=100,maximum=100,present=true}
local watcher,bar,created,reads=nil,nil,0,0
UIParent={}
function UnitExists(unit) assert(unit=="pet");return sample.present end
function UnitHealth(unit) assert(unit=="pet");reads=reads+1;return sample.health end
function UnitHealthMax(unit) assert(unit=="pet");return sample.maximum end
local function region()
    return {SetAllPoints=function()end,SetColorTexture=function()end,SetPoint=function()end,
        SetWidth=function()end,SetHeight=function()end,SetShadowOffset=function()end,
        SetText=function(self,v)self.text=v end}
end
function CreateFrame(kind)
    created=created+1
    local f={events={},shown=true}
    function f:SetScript(_,fn)self.onEvent=fn end
    function f:RegisterEvent(e)self.events[e]=true end
    function f:RegisterUnitEvent(e,u)self.events[e]=u end
    function f:UnregisterAllEvents()self.events={} end
    function f:Hide()self.shown=false end
    function f:Show()self.shown=true end
    if kind=="Frame" then watcher=f;return f end
    assert(kind=="StatusBar")
    bar=f
    f.SetFrameStrata=function()end
    f.SetSize=function(self,w,h)self.width,self.height=w,h end
    f.SetPoint=function()end
    f.EnableMouse=function(self,v)self.interactive=v end
    f.SetMinMaxValues=function(self,m,x)self.range={m,x} end
    f.SetStatusBarTexture=function(self,v)assert(v=="Interface\\Buttons\\WHITE8X8")end
    f.CreateTexture=region
    f.CreateFontString=region
    f.SetStatusBarColor=function(self,r,g,b)self.red=r>g end
    f.SetValue=function(self,n)self.value=n end
    return f
end
assert(loadfile("NQT/PetBar.lua"))("NQT",AT)
AT.InitPetBar()
assert(not bar and reads==0 and not next(watcher.events),"default off, no polling")
AT.db.petBarEnabled=true
AT.RefreshPetBar()
assert(bar.shown and bar.value==100 and bar.label.text=="Pet 100%" and not bar.red)
assert(bar.height==13 and not bar.interactive and bar.range[1]==0 and bar.range[2]==100)
assert(watcher.events.UNIT_HEALTH=="pet" and watcher.events.UNIT_PET=="player")
local function health(n,unit)
    sample.health=n
    watcher.onEvent(watcher,"UNIT_HEALTH",unit or "pet")
end
health(10,"target");assert(bar.value==100)
health(50);assert(bar.value==50 and not bar.red)
health(49.9);assert(bar.red and bar.label.text=="Pet 49%")
health(0);assert(bar.value==0 and bar.red and bar.label.text=="Pet 0%")
sample.maximum=50;sample.health=30
watcher.onEvent(watcher,"UNIT_MAXHEALTH","pet");assert(bar.value==60 and not bar.red)
sample.present=false
watcher.onEvent(watcher,"UNIT_PET","player");assert(not bar.shown)
sample.present=true
watcher.onEvent(watcher,"UNIT_PET","player");assert(bar.shown and created==2)
local secret=123
issecretvalue=function(v)return v==secret end
health(secret);assert(not bar.shown,"do not expose restricted data")
issecretvalue=nil
AT.db.petBarEnabled=false
AT.RefreshPetBar();assert(not bar.shown and not next(watcher.events))
AT.db.petBarEnabled=true;AT.db.enabled=false
AT.RefreshPetBar();assert(not bar.shown and not next(watcher.events))
print("PASS Pet Bar default off, exact red/green boundary, 0–100, pet changes, safe hide, event-only updates")
