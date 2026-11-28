local AT={db={enabled=true,questHUDEnabled=true},char={}}
local map,side,locale=1446,"Alliance","enUS"
local held,ready,native=true,true
function UnitFactionGroup()return side end
function GetLocale()return locale end
function IsInInstance()return false,"none" end
function CreateFrame()return {RegisterEvent=function()end,SetScript=function()end}end
C_Timer={After=function()end}
C_Map={GetBestMapForUnit=function()return map end,GetMapInfo=function()return {mapType=3}end}
C_QuestLog={IsOnQuest=function()return held end,ReadyForTurnIn=function()return ready end,
 GetQuestsOnMap=function()return native end}
for _,f in ipairs({"Quests","ForeverTownPins","ForeverQuestFacts","ForeverVerifiedEndpoints","NQTDB"})do
 assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
local facts=AT.NQTDB.ObservedTurnInNames
local seen=0
for q,v in pairs(facts)do
 local spot=AT.ObservedQuestTurnIns[q][1]
 local m,x,y,kind,id,faction,name=table.unpack(spot)
 assert(kind==1 and id==v[1] and name=="")
 side=faction==2 and "Horde" or "Alliance";map=m
 local a,b,c,s,click=AT.GetReadyQuestTurnInPoint(q)
 assert(a==m and b==x and c==y and s==v[2] and click,"ready row exact NPC "..q)
 AT.NQTDB.ObservedTurnInNames=nil
 local aa,bb,cc,before,oldClick=AT.GetReadyQuestTurnInPoint(q)
 assert(not before and not oldClick and a==aa and b==bb and c==cc,"name and action only, existing position remains "..q)
 AT.NQTDB.ObservedTurnInNames=facts
 seen=seen+1
end
assert(seen==21)
map,side=1446,"Alliance"
native={{questID=351,isQuestStart=false,inProgress=false,x=.603,y=.646}}
local m,x,y,n,click=AT.GetReadyQuestTurnInPoint(351,1446)
assert(m==1446 and x==.603 and y==.646 and n=="Homing Robot OOX-17/TN" and click)
locale="deDE";assert(not select(4,AT.GetReadyQuestTurnInPoint(351,1446)))
locale="enUS";facts[351]={999,"Wrong NPC"};assert(not select(4,AT.GetReadyQuestTurnInPoint(351,1446)))
facts[351]={7784,"Homing Robot OOX-17/TN"};ready=false;assert(not AT.GetReadyQuestTurnInPoint(351,1446))
ready=true;held=false;assert(not AT.GetReadyQuestTurnInPoint(351,1446))
print("PASS 21 formerly unnamed ready rows now show exact targetable NPCs; native position, live identity, locale and status guards")
