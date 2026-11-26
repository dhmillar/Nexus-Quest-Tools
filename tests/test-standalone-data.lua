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
assert(loadfile("NQT/ForeverQuestFacts.lua"))("NQT",AT)
bagItem=16305;held[2]=true
assert(AT.ForeverQuestFacts[2][1]==20 and AT.ForeverQuestFacts[2][2]==30)
assert(AT.GetForeverObjectiveQuests(bagItem)[2])
press(2) -- numeric backlink under a collapsed header; no Questie and no item cache
assert(not AT.GetLeftoverQuestBagHint(0,1),"positive objective data cannot authorize discarding")
local originalLookup=AT.GetForeverObjectiveQuests
AT.GetForeverObjectiveQuests=function(item) if item==16305 then return {[2]=true,[3]=true,[4]=true} end end
held[3]=true;held[4]=false
chosen=nil;click(bagbtn,"LeftButton",false)
assert(type(chosen)=="table" and chosen[2] and chosen[3] and not chosen[4],"all verified held matches should reach Rank Quest")
held[3]=false;AT.GetForeverObjectiveQuests=originalLookup
held[2]=false;press(nil)
bagItem=3248
assert(AT.ForeverQuestItemOrigins[3248][252]==1 and AT.ForeverProtectedQuestItems[3248])
GameTooltip.out=nil;tooltip(GameTooltip,0,1)
assert(GameTooltip.out:find("Reward from Quest #252",1,true))
assert(not GameTooltip.out:find("quest link not verified",1,true))
press(nil)
assert(loadfile("NQT/Quests.lua"))("NQT",AT)
held[595]=true
pins[42]={{questID=595,isQuestStart=false,inProgress=false,x=.273,y=.695}}
function UnitFactionGroup() return "Alliance" end
function GetLocale() return "enUS" end
ready[623]=true;held[623]=true
local dust,gx,gy,finisher,clickable,approx=AT.GetReadyQuestTurnInPoint(623)
assert(dust==1445 and gx==.688 and gy==.532 and finisher=="Privateer Groy" and clickable and approx)
pins[1445]={{questID=623,isQuestStart=false,inProgress=false,x=.68,y=.53}}
local _,nx,_,knownName,_,nativeApprox=AT.GetReadyQuestTurnInPoint(623,1445)
assert(nx==.68 and knownName=="Privateer Groy" and not nativeApprox,"real game coordinates take priority")
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
assert(loadfile("NQT/ForeverVerifiedEndpoints.lua"))("NQT",AT)
held[274]=true;ready[274]=true
local em,ex,ey,en,act,estimated=AT.GetReadyQuestTurnInPoint(274)
assert(em==1432 and ex==.4601 and ey==.136 and en=="Chief Engineer Hinderweir VII" and act and estimated)
AT.db.questHUDEnabled=true
assert(AT.ToggleQuestHUDManualFocus(274))
assert(AT.IsQuestTurnInNavigation(274),"test exercises focused completed quest")
assert(not AT.GetQuestTurnInPoint(274), "a reference must not route without a native point")
pins[1432]={{questID=274,isQuestStart=false,inProgress=false,x=.462,y=.137}}
local gm,gy=AT.GetQuestTurnInPoint(274)
assert(gm==1432 and gy==.462,"known map should find the live turn-in before opening the map")
pins[1432]=nil
function UnitFactionGroup() return "Horde" end
assert(not AT.GetReadyQuestTurnInPoint(274),"supplemental turn-in must respect faction")
function UnitFactionGroup() return "Alliance" end
held[306]=true; ready[306]=true
local tm,tx,ty,tn,tc,ta=AT.GetReadyQuestTurnInPoint(306)
assert(tm==1437 and tx==.1143 and ty==.523 and tn=="Tarrel Rockweaver" and tc and ta)
print("PASS Questie-free live bag links, ambiguity guards, selective Forever reference links and verified turn-in map re-query")local function checkArea(q,area,npc,works)
    ready[q]=true;held[q]=true
    local a,n,c=AT.GetReadyQuestTurnInArea(q)
    assert(a==area and n==npc and c==works)
    assert(not AT.GetReadyQuestTurnInPoint(q),"area is not coordinates")
end
function UnitFactionGroup() return "Horde" end
checkArea(1098,"Shadowfang Keep","Deathstalker Vincent",true)
checkArea(3446,"Temple of Atal'Hakkar","Altar of Hakkar",false)
checkArea(1144,"Razorfen Kraul","Willix the Importer",true)
function UnitFactionGroup() return "Alliance" end
assert(not AT.GetReadyQuestTurnInArea(1098),"faction gates named reference")
function GetLocale() return "frFR" end
assert(not AT.GetReadyQuestTurnInArea(1144),"do not expose untranslated macro name")
function GetLocale() return "enUS" end
ready[1144]=false
assert(not AT.GetReadyQuestTurnInArea(1144),"must be ready for turn-in")
ready[1144]=true;held[1144]=false
assert(not AT.GetReadyQuestTurnInArea(1144),"must still hold the quest")
print("PASS area-only native-client turn-in fallback, object vs NPC, faction and locale safety")
function UnitFactionGroup() return "Horde" end
checkArea(95309,"Alcaz Prison","Commander Folkar",true)
checkArea(96335,"Alcaz Prison","Mason Connery",true)
checkArea(96369,"Alcaz Prison","Commander Folkar",true)
checkArea(2953,"Gnomeregan","The Sparklematic 5200",false)
checkArea(4603,"Gnomeregan","The Sparklematic 5200",false)
assert(not AT.GetReadyQuestTurnInArea(95454),"do not infer whether the note or Folkar ends this quest")
assert(loadfile("NQT/EverlootDrops.lua"))("NQT",AT)
local jaw=assert(AT.ObservedQuestDrops.items[6166],"latest snapshot supplies exact item ID")
local dated=false
for _,v in ipairs(jaw) do
    assert(v[2]>0 and v[2]<=v[3] and v[4]>=3)
    if AT.ObservedQuestDrops.dates[v[5]]=="2026-11-26 09:00 UTC" then dated=true end
end
assert(dated)
