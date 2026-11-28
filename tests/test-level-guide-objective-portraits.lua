local catalogFiles={"LevelGuideData","ForeverQuestFacts","QuestMobData","EverlootDrops","ClassicQuestDropReferences","ClassicQuestMobReferences","NQTDB","QuestMobs","LevelGuide"}
GetLocale=function()return "enUS" end
C_Item={GetItemNameByID=function(i)return "Item "..i end,GetItemIconByID=function(i)return i*10 end}
local active={}
C_QuestLog={GetQuestObjectives=function(q)return active[q] end}
local function load(path)
    local a={}
    for _,f in ipairs(catalogFiles)do assert(loadfile(path.."/NQT/"..f..".lua"))("NQT",a) end
    return a
end
local AT=load(".")
local rows=AT.GetLevelGuideObjectiveRows(95108)
assert(rows[1].kind=="kill" and rows[1].mob=="Deadwood Death Mystic" and rows[1].display==1010,
    "actual NQTDB portrait available before accepting quest")
local collected
for _,r in ipairs(AT.GetLevelGuideObjectiveRows(93444))do if r.kind=="collect" and r.item==274162 then collected=r end end
assert(collected and collected.text=="Item 274162: 0/1" and collected.display==4269 and collected.npc==264867,
    "verified collection source portrait and exact item details")
active[93444]={{type="item",itemID=274162,text="Special live item: 0/1",finished=false}}
local live,yes=AT.GetLevelGuideObjectiveRows(93444)
assert(yes and live[1].text=="Special live item: 0/1" and live[1].display==4269)
active[93444]={{type="item",itemID=112233,text="Completely different item: 0/1",finished=false}}
live,yes=AT.GetLevelGuideObjectiveRows(93444)
assert(yes and not live[1].display and live[1].icon==1122330,"unknown or different things retain exact item art")
active={}
print("PASS real Level Guide objective rows resolve NQTDB kill/collection portraits and keep live text and item fallback")
if arg and arg[1] then
    local old=load(arg[1])
    for _,a in ipairs({old,AT})do
        local total={kill=0,collect=0}
        for q in pairs(a.ForeverLevelGuideQuests)do
            for _,r in ipairs(a.GetLevelGuideObjectiveRows(q))do
                if total[r.kind] and type(r.display)=="number" and r.display>0 then total[r.kind]=total[r.kind]+1 end
            end
        end
        print("Level Guide rows with portraits: kill="..total.kill.." collect="..total.collect)
    end
end
