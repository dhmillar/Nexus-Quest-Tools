local AT={char={},db={enabled=true,showQuestMapPins=true}}
local race,faction,map,level=96,"Horde",1412,10
local hidden={}
local native=false
function issecretvalue(v)return v==hidden end
function UnitRace()return "Test Race","TestRace",race end
function UnitFactionGroup()return faction end
function UnitClass()return "Hunter","HUNTER",3 end
function UnitLevel()return level end
function GetLocale()return "enUS" end
local zones={[1411]="Durotar",[1412]="Mulgore"}
C_Map={
 GetBestMapForUnit=function()return map end,
 GetMapInfo=function(i)if zones[i] then return {name=zones[i],mapType=3} end end,
 GetAreaInfo=function(i)if i==14 then return "Durotar" end end,
}
C_QuestLog={
 GetQuestsOnMap=function(i)if i==map and native then return {{questID=native,isQuestStart=true,x=.4,y=.5}} end return {} end,
 IsOnQuest=function()return false end,
 IsQuestFlaggedCompleted=function()return false end,
 GetAllCompletedQuestIDs=function()return {} end,
}
for _,f in ipairs({"ForeverQuestFacts","ForeverTownPins","QuestMapPins","LevelGuideData","NQTDB","LevelGuide"}) do
 assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
local function pin(q)
 for _,p in ipairs(AT.GetStandaloneMapPins(map)) do if p.kind=="start" and p.quest==q then return p end end
end
local function guide(q)
 for _,p in ipairs(AT.BuildLevelGuide(level,1).places) do
  for _,r in ipairs(p.quests) do if r.id==q then return r end end
 end
end
assert(pin(94911) and pin(94911).x==.3339 and guide(94911),"only Windshaper qualifies for this recorded offer")
race,faction=95,"Alliance"
assert(not pin(94911) and not guide(94911),"High Order skips the Windshaper-only fallback")
native=94911
assert(pin(94911).x==.4 and guide(94911).status=="Pick up","native offer overrides stale catalog inference")
native=false
map,level,race,faction=1411,40,2,"Horde"
assert(not pin(96989) and not guide(96989),"Orc does not inherit a Troll-only quest from the shared city")
race=8
assert(pin(96989) and pin(96989).x==.5519 and guide(96989),"Troll has a recorded starter and recommendation")
race=hidden
assert(pin(96989),"unreadable race alone does not suppress historically supported pins")
faction="Alliance"
assert(not pin(96989),"recorded Horde-only starts do not cross faction even when race is unreadable")
race=95
assert(not guide(96989),"known Alliance race does not qualify in the Guide")
local allows=AT.QuestCatalogRaceAllows
assert(allows("55155555b1354c4d",95,1) and not allows("55155555b1354c4d",96,2),"Alliance-wide catalog bits")
assert(allows("aa2aaaaa4e0ab3b2",96,2) and not allows("aa2aaaaa4e0ab3b2",95,1),"Horde-wide catalog bits")
for _,v in ipairs({"ffffffffffffffff","0000000000000000",""}) do
 assert(allows(v,95,1) and allows(v,96,2),"unrestricted catalog rows")
end
print("PASS actual Windshaper and Troll restrictions agree in Level Guide and recorded world-map pins, with native offer priority")
