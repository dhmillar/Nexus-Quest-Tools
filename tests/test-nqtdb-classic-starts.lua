local AT={}
local function load(f) assert(loadfile("NQT/"..f..".lua"))("NQT",AT) end
C_Map={GetMapInfo=function(m) if m==1429 then return {name="Elwynn Forest",mapType=3} end end}
function GetLocale() return "enUS" end
local faction="Alliance"
function UnitFactionGroup() return faction end
load("ForeverTownPins")
load("LevelGuideData")
load("LevelGuideGivers")
load("NQTDB")
load("LevelGuide")
local expected="Likely starts at: Gerard Tiller  |  Elwynn Forest 43.1, 85.5"
assert(AT.GetShareQuestStart(16,1429,false)==expected,AT.GetShareQuestStart(16,1429,false))
faction="Horde"
assert(not AT.GetShareQuestStart(16,1429,false),"do not suggest an opposite-faction NPC")
assert(not AT.NQTDB.ClassicStarts[26] and not AT.NQTDB.ClassicStarts[566],"conflicted trainer and duplicate board omitted")
faction="Alliance"
AT.LevelGuideQuestGivers[16]={{1429,.5,.3,1,255,"Native example",0}}
assert(AT.GetShareQuestStart(16,1429,false):find("Starts at: Native example",1,true),"existing exact giver wins")
local count=0
for id,rows in pairs(AT.NQTDB.ClassicStarts) do
  assert(AT.ForeverLevelGuideQuests[id] and #rows==1)
  local r=rows[1]
  assert(r[1]>=1400 and r[2]>0 and r[2]<1 and r[3]>0 and r[3]<1)
  assert(r[4]==0 or r[4]==1 or r[4]==2)
  assert(r[5]>0 and r[6]~="" and (r[7]==0 or r[7]==1))
  assert(not AT.LevelGuideQuestGivers[id] or id==16)
  count=count+1
end
assert(count==301)
print("PASS 301 exact Classic ID/title/level starter leads with observed Forever entity coordinates and safe priority")
