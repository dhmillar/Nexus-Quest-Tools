-- Actual Riverglades catalog and recorded starts. No Questie or native POIs
-- until explicitly added; check both in-game map snapshots and guide lists.
local AT={}
local map,a,b,c=2548,95603,95613,95615
local complete,offers,held={},{},{}
local secret={}
function issecretvalue(v)return rawequal(v,secret) end
function UnitLevel()return 38 end
local faction="Alliance"
function UnitFactionGroup()return faction end
function UnitRace()if faction=="Horde" then return "Orc","Orc",2 end;return "Human","Human",1 end
function GetLocale()return "enUS" end
C_Map={GetBestMapForUnit=function()return map end,
    GetMapInfo=function(m)if m==map then return {name="Riverglades",mapType=3,mapID=map} end end}
C_QuestLog={
    IsQuestFlaggedCompleted=function(q)
        if complete[q]~=nil then return complete[q] end
        return false
    end,
    IsOnQuest=function(q)return held[q]~=nil end,
    GetAllCompletedQuestIDs=function()return {} end,
    GetQuestsOnMap=function(m)return m==map and offers or {} end,
    GetTitleForQuestID=function(q)return ({[a]="Bats in the Belfry",[b]="Keeping the Light On",[c]="In Memoriam"})[q] end,
}
AT.GetLevelGuideQuestLog=function()return held end
for _,f in ipairs({"QuestMapPins","LevelGuideData","ForeverQuestFacts","ForeverTownPins","LevelGuideGivers","NQTDB","LevelGuideZoneRanges","LevelGuide"})do
    assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
local function inspect()
    local pins,guide={},{}
    for _,v in ipairs(AT.GetStandaloneMapPins(map)) do
        if v.kind=="start" then pins[v.quest]=v end
    end
    for _,p in ipairs(AT.BuildLevelGuide(38,1).places)do
        if p.map==map then
            for _,v in ipairs(p.quests)do guide[v.id]=v end
        end
    end
    return pins,guide
end
local function assertOnly(q)
    local p,g=inspect()
    for _,id in ipairs({a,b,c}) do
        assert((p[id]~=nil)==(id==q) and (g[id]~=nil)==(id==q),
            "unexpected recorded eligibility for "..id.." when expecting "..tostring(q).." pin "..tostring(p[id]).." guide "..tostring(g[id]).." complete "..tostring(complete[id]))
    end
end
assertOnly(a)
complete[a]=true; assertOnly(b)
complete[b]=true; assertOnly(c)
complete[c]=true; assertOnly(nil)
complete[a]=secret; complete[b]=false;complete[c]=false
local p,g=inspect()
assert(not p[b] and not p[c] and not g[b] and not g[c],"protected prerequisite is unknown, not complete")
AT.char={levelGuideTurnIns={[a]=true}}
p,g=inspect()
assert(p[b] and g[b] and not p[c] and not g[c],"character's witnessed turn-in unlocks the next fallback")
AT.char=nil
offers={{questID=b,isQuestStart=true,x=.6,y=.8}}
p,g=inspect()
assert(p[b] and p[b].report~="known-start" and g[b].status=="Pick up",
    "readable native offers win despite an unreadable prerequisite")
offers={};held[b]={title="Keeping the Light On",level=38,destination=map}
p,g=inspect()
assert(not p[b] and g[b].status=="In log" and not p[c] and not g[c],
    "the player's active quest wins in the guide, not as a start pin or completed prerequisite")
local apple,princess,stepped=95561,95913,95961
local _,rg=inspect()
assert(not rg[princess] and not rg[stepped])
complete[apple]=true;_,rg=inspect()
assert(rg[princess] and not rg[stepped])
complete[princess]=true;_,rg=inspect()
assert(rg[stepped] and not rg[princess])
local legends,lost,drowned=95748,95770,95775
faction="Horde"
local function startsInStranglethorn()
    local starts={}
    for _,pin in ipairs(AT.GetStandaloneMapPins(1434)) do
        if pin.kind=="start" then starts[pin.quest]=true end
    end
    return starts
end
p=startsInStranglethorn();assert(not p[lost] and not p[drowned])
complete[legends]=true;p=startsInStranglethorn();assert(p[lost] and not p[drowned])
complete[lost]=true;p=startsInStranglethorn();assert(not p[lost] and p[drowned])
print("PASS Tessa Dawnbright's guide entries and Stranglethorn's Drowned City lead-in follow verified prerequisites")
print("PASS the Riverglades chain unlocks recorded starts one step at a time on both surfaces; native offers and held quests win")
