local AT={db={enabled=true,questHUDEnabled=true},char={}}
local map,id=1443,7067
local held,ready,locale=true,true,"enUS"
local pins
function GetLocale()return locale end
function UnitFactionGroup()return "Horde" end
function IsInInstance()return false,"none" end
function CreateFrame()return {RegisterEvent=function()end,SetScript=function()end}end
function CreateVector2D(x,y)return {GetXY=function()return x,y end}end
C_Timer={After=function()end}
C_Map={GetBestMapForUnit=function()return map end,
 GetWorldPosFromMapPos=function(_,p)local x,y=p:GetXY();return 1,CreateVector2D(x*5000,y*5000)end,
 GetPlayerMapPosition=function()return CreateVector2D(.51,.8)end,
 GetMapInfo=function(m)if m==map then return {mapType=3,name="Desolace"} end end}
C_QuestLog={
 IsOnQuest=function()return held end,ReadyForTurnIn=function()return ready end,
 GetQuestsOnMap=function(m)if m==map then return pins end end,
}
for _,f in ipairs({"Quests","ForeverTownPins","ForeverQuestFacts","ForeverVerifiedEndpoints","NQTDB"})do
 assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
assert(AT.ToggleQuestHUDManualFocus(id))
local area,npc,click=AT.GetReadyQuestTurnInArea(id)
assert(area=="Southern Desolace" and npc=="Centaur Pariah" and click==true)
assert(not AT.GetReadyQuestTurnInPoint(id) and not AT.GetQuestTurnInPoint(id),"the patrol has no fixed point")
local q,primary,backup=AT.GetFocusedQuestRouteTargets(map)
assert(q==id and #primary==0 and #backup==0,"do not ask walking engine to route to an old sighting")
pins={{questID=id,isQuestStart=false,inProgress=false,x=.476,y=.867}}
local m,x,y,name,action=AT.GetReadyQuestTurnInPoint(id)
assert(m==map and x==.476 and y==.867 and name=="Centaur Pariah" and action)
q,primary,backup=AT.GetFocusedQuestRouteTargets(map)
assert(q==id and #primary==1 and primary[1].x==x and #backup==0,"never replace the live point with a patrol snapshot")
AT.ObservedQuestTurnIns[id][2][5]=9999
assert(not AT.GetReadyQuestTurnInArea(id),"different observed NPC identity suppresses the extra label")
m,x,y,name=AT.GetReadyQuestTurnInPoint(id)
assert(m==map and x==.476 and not name,"a verified native pin survives contradictory label evidence")
AT.ObservedQuestTurnIns[id][2][5]=13717
locale="frFR"
assert(not AT.GetReadyQuestTurnInArea(id))
local _,_,_,notEnglish=AT.GetReadyQuestTurnInPoint(id)
assert(not notEnglish,"an untranslated macro name must stay hidden")
function UnitGUID(u)if u=="target" then return "Creature-0-0-0-0-13717-1" end end
function UnitName(u)if u=="target" then return "Paria centaure" end end
local _,_,_,localized=AT.GetReadyQuestTurnInPoint(id)
assert(localized=="Paria centaure","a readable exact live NPC name still wins")
locale="enUS";held=false
assert(not AT.GetReadyQuestTurnInArea(id))
held=true;ready=false
assert(not AT.GetReadyQuestTurnInArea(id))
print("PASS moving Centaur Pariah is named in Rank Quest without a guessed pin; native point, conflicts and ready-state protected")
