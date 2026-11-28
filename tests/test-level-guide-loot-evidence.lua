local AT={}
local live
C_QuestLog={GetQuestObjectives=function()return live end}
GetLocale=function()return "enUS" end
for _,f in ipairs({"LevelGuideData","ForeverQuestFacts","EverlootDrops","NQTDB","LevelGuide"}) do
    assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
local function plan(q,party)
    return AT.ScoreLevelGuideQuest(q,AT.ForeverLevelGuideQuests[q],30,party,{status="In range"})
end
local function approx(a,b)
    return type(a)=="number" and math.abs(a-b)<.000001
end
assert(approx(plan(92551,1).lowRate,10/16))
assert(not approx(plan(92551,2).lowRate,10/16),"no solo sample reused by duo")
assert(not approx(plan(92551,3).lowRate,10/16),"no solo sample reused by trio")
assert(approx(plan(47,1).lowRate,.375) and approx(plan(47,2).lowRate,11/23),"solo corpse rate, duo recorded window")
assert(approx(plan(47,3).lowRate,11/23),"same published group cohort, different party pace")
assert(approx(plan(83,1).lowRate,13/21),"solo window evidence")
assert(approx(plan(97009,1).lowRate,(12/19)*(32/36)),"known empty corpses normalized in the actual recommendation")
-- A decoy may require the same item; don't pass the previous quest's evidence to it.
local isolated={}
for k,v in pairs(AT.ForeverLevelGuideQuests[92551]) do isolated[k]=v end
local x=AT.ScoreLevelGuideQuest(900000,isolated,30,1,{status="In range"})
assert(not approx(x.lowRate,10/16))
live={
    {type="monster",npcID=252068,numRequired=13,numFulfilled=1,text="Patrol defeated: 0/1"},
    {type="item",itemId=252760,numRequired=7,numFulfilled=4,text="Localized objective count unavailable"},
}
local held=AT.ScoreLevelGuideQuest(92551,AT.ForeverLevelGuideQuests[92551],30,1,{status="In log",held=true})
assert(held.kills==12 and held.items==3 and held.work==17 and approx(held.lowRate,10/16),
    "native objective counts and creature ID prevent charging twice for the same kills")
live[1].npcID=900000
local decoy=AT.ScoreLevelGuideQuest(92551,AT.ForeverLevelGuideQuests[92551],30,1,{status="In log",held=true})
assert(approx(decoy.work,17+3/(10/16)),"different NPC keeps independent collection work")
print("PASS Level Guide actual suggestions use exact Forever quest item rates; solo, duo and trio route-work modes do not conflate")

