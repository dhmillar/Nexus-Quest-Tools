local AT={char={}}
local locale="enUS"
function GetLocale()return locale end
function UnitLevel()return 60 end
function UnitRace()return "Human","Human",1 end
function UnitFactionGroup()return "Alliance" end
function UnitClass()return "Hunter","HUNTER",3 end
C_Map={GetBestMapForUnit=function()return 1422 end,
 GetMapInfo=function(m)if m==1422 then return {name="Western Plaguelands",mapType=3} end end}
C_QuestLog={IsQuestFlaggedCompleted=function()return false end, GetAllCompletedQuestIDs=function()return {} end}
C_Item={GetItemNameByID=function(i)if i==13920 then return "Healthy Dragon Scale" end end}
for _,f in ipairs({"LevelGuideData","ForeverQuestFacts","LevelGuideGivers","NQTDB","LevelGuide"}) do
    assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
local expected="Pickup: Healthy Dragon Scale from Plagued Hatchling  |  Scholomance"
assert(AT.GetShareQuestStart(5582,nil,true)==expected)
assert(AT.GetShareQuestStart(5582,1422,true)==expected,"outdoor origin hint cannot override the source dungeon")
local catalog=AT.BuildLevelGuide(60,1)
local count=0
for _,p in ipairs(catalog.places) do
    for _,q in ipairs(p.quests) do
        if q.id==5582 then
            count=count+1
            local g=q.giver
            assert(g.pickup and g.source==10678 and g.sourceArea=="Scholomance")
            assert(not g.map and not g.x and not g.y and #g.areas==0,
                "no fictional map, pin, or entrance waypoint")
        end
    end
end
assert(count>=1,"actual guide resolves matched Scholomance quest")
locale="deDE"
local localized=AT.GetShareQuestStart(5582,nil,true)
assert(localized and not localized:find("Plagued Hatchling",1,true))
locale="enUS"
AT.LevelGuideQuestGivers[5582]={{1422,.5,.5,1,123,"Stronger Native Offer"}}
assert(AT.GetShareQuestStart(5582,1422,false):find("Stronger Native Offer",1,true),
    "do not replace an existing known giver")
assert(not AT.NQTDB.ItemStarterWitnesses[4451],"an unconfirmed drop does not name an item starter")
print("PASS Healthy Dragon Scale verified instance pickup, actual guide and Share Verify, no fabricated map")
