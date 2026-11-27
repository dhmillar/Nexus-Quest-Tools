local AT={db={enabled=true,autoFocus=true,hideCompleted=true,questHUDEnabled=false},char={}}
local held,ready,watch={[11]=true,[12]=true,[13]=true},{[12]=true,[13]=true},{}
local current=0
C_QuestLog={
    GetNumQuestLogEntries=function()return 3 end,
    GetInfo=function(i) return {questID=i+10} end,
    IsOnQuest=function(id)return held[id]==true end,
    ReadyForTurnIn=function(id)return ready[id] end,
    GetQuestWatchType=function(id) return watch[id] and 1 end,
    AddQuestWatch=function(id) watch[id]=true;return true end,
    RemoveQuestWatch=function(id) watch[id]=nil end,
    GetDistanceSqToQuest=function(id) if id==11 then return 49,true end end,
    GetQuestsOnMap=function() return {
        {questID=12,x=.1,y=.2,isQuestStart=false,inProgress=false},
        {questID=13,x=.3,y=.4,isQuestStart=false,inProgress=false},
    } end,
}
C_SuperTrack={
    GetSuperTrackedQuestID=function()return current end,
    SetSuperTrackedQuestID=function(id)current=id end,
}
C_Map={GetBestMapForUnit=function()return 1 end,GetMapInfo=function() return {mapType=3,name="Land"} end}
local frames={}
CreateFrame=function()
    local f={RegisterEvent=function()end,SetScript=function(self,_,cb)self.event=cb end}
    frames[#frames+1]=f;return f
end
local tasks={}
C_Timer={After=function(_,cb)tasks[#tasks+1]=cb end,NewTicker=function()end}
local function drain()
    while #tasks>0 do table.remove(tasks,1)() end
end
hooksecurefunc=function(o,k,after)
    if type(o)=="string" then o,k,after=_G,o,k end
    local original=o[k]
    o[k]=function(...) local out=original(...);after(...);return out end
end
local pins,enumerations={},0
local open=true
WorldMapFrame={
    GetMapID=function()return 1 end,
    IsShown=function()return open end,
    EnumeratePinsByTemplate=function(_,template)
        enumerations=enumerations+1
        local i=0
        return function()i=i+1;return (pins[template] or {})[i] end
    end,
    AcquirePin=function(_,template,id)
        local pin={owningMap=WorldMapFrame,questID=id,OnClick=function(self,key)
            if key=="LeftButton" then current=self.questID end
        end}
        pins[template]={pin};return pin
    end,
}
QuestPOIButton_OnClick=function(pin,key) if key=="LeftButton" then current=pin.questID end end
local ctrl,shift=false,false
IsControlKeyDown=function()return ctrl end
IsShiftKeyDown=function()return shift end
local row={questID=12,Checkbox={},Text={}}
function row:GetScript()return self.click end
function row:SetScript(_,cb)self.click=cb end
row.click=function(self,key) if key=="LeftButton" then current=self.questID end end
QuestScrollFrame={titleFramePool={EnumerateActive=function()return coroutine.wrap(function()coroutine.yield(row)end)end}}
assert(loadfile("NQT/Quests.lua"))("NQT",AT)
assert(loadfile("NQT/QuestMenu.lua"))("NQT",AT)
AT.InitQuests();AT.InitQuestMenus();drain()
local function normal() assert(AT.GetQuestNavigationID()==11 and current==11) end
normal()
local prior=enumerations
local pin
for _=1,40 do pin=WorldMapFrame:AcquirePin("QuestPinTemplate",12) end
assert(enumerations==prior,"map acquisition must not loop through the full pool on each pin")
drain()
assert(enumerations==prior+1,"map burst schedules one pool scan")
pin:OnClick("LeftButton")
assert(AT.GetQuestHUDManualFocus()==12 and not AT.ShouldHideCompletedQuest(12))
open=false;current=0 -- native map clears selection
assert(AT.GetQuestNavigationID()==12 and AT.IsQuestTurnInNavigation(12))
AT.RefreshQuests()
assert(current==12 and watch[12])
local id,map,x,y=AT.GetFocusedQuestRoutePoint()
assert(id==12 and map==1 and x==.1 and y==.2)
open=true
pin.questID=13 -- pooled pins change quest
pin:OnClick("RightButton")
assert(AT.GetQuestNavigationID()==12)
shift=true;pin:OnClick("LeftButton");shift=false
AT.RefreshQuests()
assert(AT.GetQuestHUDManualFocus()==12 and current==12)
QuestPOIButton_OnClick(pin,"LeftButton")
assert(AT.GetQuestHUDManualFocus()==13)
held[13]=nil;frames[1].event(frames[1],"QUEST_TURNED_IN",13);drain()
normal()
row.click(row,"LeftButton")
assert(AT.GetQuestHUDManualFocus()==12)
row.questID=11
row.click(row,"LeftButton")
assert(AT.GetQuestHUDManualFocus()==11)
ready[11]=true
AT.RefreshQuests()
assert(not AT.GetQuestHUDManualFocus())
print("PASS native world-map pin and log row preserve explicit turn-in tracking on map close; recycled pins, modifier clicks, replacements and cleanup")
