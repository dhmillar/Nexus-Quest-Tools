-- An Enticing Offer has real observations for two exact item IDs. The
-- reordered rows are deliberately synthetic; they exercise the live join.
local AT={db={enabled=true},char={}}
local quest,map,native,ready=99130,1429,false,false
local SECRET={}
function issecretvalue(v)return v==SECRET end
local live
function CreateFrame()return {RegisterEvent=function()end,SetScript=function()end}end
function IsInInstance()return false,"none" end
C_Timer={After=function()end}
C_Map={GetBestMapForUnit=function()return map end,GetMapInfo=function()return {mapType=3}end,
 GetMapWorldSize=function()return 1000,1000 end,GetPlayerMapPosition=function()return {GetXY=function()return .5,.7 end}end}
C_QuestLog={IsOnQuest=function(x)return x==quest end,ReadyForTurnIn=function()return ready end,
 GetQuestObjectives=function()return live end,GetNextWaypointForMap=function()if native then return .42,.63 end end}
C_SuperTrack={GetSuperTrackedQuestID=function()return quest end}
for _,f in ipairs({"NQTDB","Quests"})do assert(loadfile("NQT/"..f..".lua"))("NQT",AT) end
local ref=AT.NQTDB.ObjectiveSpots[quest]
local function row(id,n,finished,text)
 return {type="item",itemID=id,numRequired=n,finished=finished or false,text=text}
end
local petal=row(286214,18)
local blood=row(286215,6)
live={petal,blood}
local function spots(n,first)
 local out=AT.GetObservedQuestObjectiveSpots(quest,map) or {}
 assert(#out==n,"unexpected approach count: "..#out.." vs "..n)
 if first then assert(out[1]==first) end
end
spots(12,ref[1][4][1])
native=true
local q,primary,backup=AT.GetFocusedQuestRouteTargets(map)
assert(q==quest and #primary==1 and primary[1].x==.42 and #backup==12)
native=false
blood.finished=true
spots(6,ref[2][4][1])
blood.finished=false
live={row(17,18),blood}
spots(6,ref[1][4][1])
live={row(SECRET,18),blood}
spots(6,ref[1][4][1])
petal.itemId=999
live={petal,blood}
spots(6,ref[1][4][1])
petal.itemId=nil
function AT.ResolveRankQuestObjectiveItem(qx,_,label)
 assert(qx==99130)
 return label=="localized exact petal" and 286214 or label=="conflicting item" and 17 or nil
end
live={row(nil,18,false,"localized exact petal"),blood}
spots(12)
live={row(nil,18,false,"conflicting item"),blood}
spots(6,ref[1][4][1])
live={row(nil,18),row(nil,6)}
spots(12)
live={row(nil,18),row(nil,18),row(nil,6)}
spots(6,ref[1][4][1])
live={petal,blood,blood}
spots(6,ref[2][4][1])
-- Disambiguation must be unique on both sides, not only among live rows.
local saved=ref[2][3]
ref[2][3]=6
live={row(nil,6)}
spots(0)
live={blood}
spots(6,ref[1][4][1])
ref[2][3]=saved
ready=true
spots(0)
print("PASS exact objective reordering, original native priority, completion, conflicts and ambiguity guards")
