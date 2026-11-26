local AT={db={enabled=true,questLeftoverMarks=false},char={}}
local rows,held,total,objs={}, {}, 0, {}
local secret={}
function issecretvalue(x) return x==secret end
Questie=nil
QuestieLoader=nil
local bagItem,info,itemName=123,{isQuestItem=true},"Test Crystal"
C_Item={GetItemNameByID=function() return itemName end}
local ready={[595]=true}
local pins={}
C_Map={GetBestMapForUnit=function() return 11 end}
C_Container={
 GetContainerItemID=function() return bagItem end,
 GetContainerItemQuestInfo=function() return info end,
}
C_QuestLog={
 GetInfo=function(i)return rows[i] end,
 GetNumQuestLogEntries=function()return #rows,total end,
 IsOnQuest=function(id)return held[id]==true end,
 GetQuestObjectives=function(id)return objs[id] end,
 ReadyForTurnIn=function(id)return ready[id]==true end,
 GetQuestsOnMap=function(map)return pins[map] end,
}
function CreateFrame() return {RegisterEvent=function()end,SetScript=function()end} end
C_Timer={After=function()end}
local tooltip=nil
GameTooltip={SetBagItem=function()end,AddLine=function(self,t) self.out=(self.out or "")..t.."\n" end}
function hooksecurefunc(_,key,cb) if key=="SetBagItem" then tooltip=cb end end
local click,chosen
local bagbtn={GetBagID=function() return 0 end,GetID=function()return 1 end,HookScript=function(_,_,fn)click=fn end}
ContainerFrameCombinedBags={EnumerateValidItems=function()return ipairs({bagbtn}) end}
function IsControlKeyDown()return true end
function IsModifiedClick()return true end
function InCombatLockdown()return false end
AT.SearchRankQuestItem=function(id)chosen=id end
assert(loadfile("NQT/QuestLeftovers.lua"))("NQT",AT)
AT.InitBagQuestLink()
AT.InitQuestLeftovers()
local function press(expected)
 chosen=nil; click(bagbtn,"LeftButton",false)
 assert(chosen==expected,("wanted %s got %s"):format(tostring(expected),tostring(chosen)))
end
held[44]=true; info={isQuestItem=true,isActive=true,questID=44}
press(44)
info.isActive=false;press(nil)
info.isActive=true;info.questID=secret;press(nil)
info={isQuestItem=true};rows={{isHeader=false,questID=44}};total=1
objs[44]={{type="item",text="2/5 Test Crystal"}}
press(44)
total=2;press(nil)
rows[2]={isHeader=false,questID=45};held[45]=true
objs[45]={{type="item",text="Test Crystal: 1/9"}}
press(nil)
objs[45]={{type="item",text="Test Crystal: 1/9",itemID=999}}
press(44)
objs[44]={{type="monster",text="2/5 Test Crystal"}}
press(nil)
bagItem=723;held[22]=true;press(22)
if tooltip then tooltip(GameTooltip,0,1); assert(GameTooltip.out:find("Goretusk Liver Pie",1,true)) end
held[22]=false;press(nil)
bagItem=730;held[38]=true;press(38)
assert(not AT.GetLeftoverQuestBagHint(0,1),"bundle never authorizes a discard classification")
assert(loadfile("NQT/Quests.lua"))("NQT",AT)
held[595]=true
pins[42]={{questID=595,isQuestStart=false,inProgress=false,x=.273,y=.695}}
local m,x,y=AT.GetReadyQuestTurnInPoint(595,42)
assert(m==42 and x==.273 and y==.695)
assert(AT.GetReadyQuestTurnInPoint(595)==42,"look up remembered native map after closing the displayed map")
pins[42][1].x=.280
m,x=AT.GetReadyQuestTurnInPoint(595)
assert(m==42 and x==.280,"always re-query live coordinates")
pins[42]=nil
assert(not AT.GetReadyQuestTurnInPoint(595),"do not re-use a stale pin")
pins[42]={{questID=595,isQuestStart=true,inProgress=false,x=.273,y=.695}}
assert(not AT.GetReadyQuestTurnInPoint(595),"start pin is not a turn-in")
pins[42][1].isQuestStart=false
AT.ForgetRemovedQuest(595)
assert(not AT.GetReadyQuestTurnInPoint(595),"forget the remembered map when a quest is removed")
assert(AT.GetReadyQuestTurnInPoint(595,42)==42)
held[595]=false
assert(not AT.GetReadyQuestTurnInPoint(595),"never route a quest that is no longer held")
print("PASS Questie-free live bag links, ambiguity guards, selective Forever reference links and verified turn-in map re-query")