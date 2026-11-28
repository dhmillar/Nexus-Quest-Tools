-- Standalone lookup used by the real Rank Quest render for unfinished rows.
local AT={}
local secret={}
function issecretvalue(v)return v==secret end
local english=true
function GetLocale()return english and "enUS" or "frFR" end
function CreateFrame()return {RegisterEvent=function()end,SetScript=function()end}end
for _,f in ipairs({"QuestMobData","NQTDB","QuestMobs"})do
 assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
local find=AT.GetQuestObjectiveNPC
local inn="Speak with the Innkeeper"
local n,id,art=find(92514,{type="event"},inn.." (0/1)")
assert(n=="Coriella Calmbreeze" and id==254089 and art and art>0)
n,id,art=find(95647,{type="talkTo",objectiveID=471712,creatureID=262681},"Learn what happened to Ardin Grassman")
assert(n=="Ardin Grassman" and id==262681 and art and art>0)
n,id=find(94887,{type="event"},"Marshal Ryan found")
assert(n=="Marshal Ryan" and id==257250)
assert(not find(92514,{type="event",objectiveID=464991},inn))
assert(not find(92514,{type="event",npcID=251902},inn))
assert(not find(92514,{type="event",objectiveID=secret},inn))
assert(not find(92514,{type="event",npcID=secret},inn))
assert(not find(92514,{type="item"},inn))
assert(not find(92514,{type=secret},inn))
assert(not find(92514,{type="event"},secret))
assert(not find(95647,{type="event"},inn))
english=false
assert(not find(92514,{type="event"},inn))
print("verified exact standalone talk-to NPCs and independent action guards")
