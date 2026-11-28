local AT={db={enabled=true},char={}}
local q,map,ready,inInstance=3362,1446,false,false
local SECRET={}
function issecretvalue(v)return v==SECRET end
local live
function CreateFrame()return {RegisterEvent=function()end,SetScript=function()end}end
function IsInInstance()return inInstance,inInstance and "party" or "none" end
C_Timer={After=function()end}
C_Map={GetBestMapForUnit=function()return map end,GetMapInfo=function()return {mapType=3}end,
 GetMapWorldSize=function()return 1000,1000 end,GetPlayerMapPosition=function()return {GetXY=function()return .3,.67 end}end}
C_QuestLog={IsOnQuest=function(x)return x==q end,ReadyForTurnIn=function()return ready end,
 GetQuestObjectives=function()return live end}
C_SuperTrack={GetSuperTrackedQuestID=function()return q end}
for _,f in ipairs({"NQTDB","Quests"})do assert(loadfile("NQT/"..f..".lua"))("NQT",AT) end
local ref=AT.NQTDB.ExactDuplicateApproaches[3362]
local counts={}
for _,rs in pairs(AT.NQTDB.ExactDuplicateApproaches)do
 for _,r in pairs(rs)do counts[#counts+1]=#r[4] end
end
local spots=0; for _,n in ipairs(counts)do spots=spots+n end
assert(#counts==12 and spots==74)
local function row(id,finished)return {type="monster",npcID=id,numRequired=8,finished=finished or false}end
local function get(m)return AT.GetObservedQuestObjectiveSpots(3362,m or map) or {}end
live={row(5485),row(5490,true)}
local pts=get();assert(#pts==#ref[2][4] and pts[1]==ref[2][4][1],"reordered equal-count objectives must join by exact ID")
live={row(5490),row(5485,true)}
pts=get();assert(#pts==#ref[1][4] and pts[1]==ref[1][4][1],"finished sibling is no longer a destination")
live={row(nil)};assert(#get()==0,"exact routes never infer identity from partial anonymous rows")
live={row(SECRET)};assert(#get()==0,"hidden ID remains hidden")
live={row(5490),row(5490)};assert(#get()==0,"duplicate exact live rows are ambiguous")
live={row(5490)};assert(#get()==#ref[1][4])
assert(#get(1445)==0,"map must match")
inInstance=true;assert(#get()==0,"not outdoor");inInstance=false
ready=true;assert(#get()==0,"ready quests navigate to turn-in instead");ready=false
q=0;assert(#get()==0,"must currently hold the quest")
print("PASS 12 exact objective approaches, real same-count reorder, hidden, completed, and out of map guards")
