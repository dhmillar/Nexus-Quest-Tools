local AT={db={enabled=true,questHUDEnabled=true},char={}}
local faction,locale,held,ready,inside="Alliance","enUS",true,true,false
local pins={}
function UnitFactionGroup()return faction end
function GetLocale()return locale end
function IsInInstance()return inside,inside and "party" or "none" end
function CreateFrame()return {RegisterEvent=function()end,SetScript=function()end}end
C_Timer={After=function()end}
C_Map={GetBestMapForUnit=function()return 2548 end,
  GetMapInfo=function(m) if m==2548 then return {mapType=3,name="Riverglades"} end end}
C_QuestLog={
    IsOnQuest=function()return held end,
    ReadyForTurnIn=function()return ready end,
    GetQuestsOnMap=function(map)return pins[map]end,
}
for _,f in ipairs({"Quests","ForeverTownPins","ForeverQuestFacts","ForeverVerifiedEndpoints","NQTDB"})do
    assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
local db=AT.NQTDB.VerifiedCompletionTurnIns
local n=0
local fixtures={{93443,.7708,.5285,"Friz Frazzlespark"},{94617,.5493,.7298,"Benjy Wheeler"},
  {94928,.7708,.5285,"Friz Frazzlespark"},{95943,.6331,.8068,"Bertrand Ironbrow"},
  {95984,.5945,.6394,"Watcher Cornelius"}}
for _,e in ipairs(fixtures) do
    local id,dx,dy,recipient=unpack(e)
    assert(db[id][1][6]==1 and not AT.ObservedQuestTurnIns[id] and not AT.ForeverVerifiedEndpointReferences[id])
    assert(AT.ToggleQuestHUDManualFocus(id))
    local m,x,y,verified=AT.GetQuestTurnInPoint(id)
    assert(m==2548 and x==dx and y==dy and verified=="verified turn-in","expected newly navigable endpoint "..id)
    local dm,px,py,npc,target,approx=AT.GetReadyQuestTurnInPoint(id)
    assert(dm==m and px==x and py==y and npc==recipient and target==true and approx)
    inside=true
    assert(not AT.GetQuestTurnInPoint(id),"don't route to outdoor location in a dungeon")
    inside=false
    held=false
    assert(not AT.GetQuestTurnInPoint(id) and not AT.GetReadyQuestTurnInPoint(id))
    held=true;ready=false
    assert(not AT.GetQuestTurnInPoint(id) and not AT.GetReadyQuestTurnInPoint(id))
    ready=true;faction="Horde"
    assert(not AT.GetQuestTurnInPoint(id) and not AT.GetReadyQuestTurnInPoint(id))
    faction="Alliance";locale="frFR"
    local _,_,_,localName,localAction=AT.GetReadyQuestTurnInPoint(id)
    assert(not localName and not localAction,"non-localized names never enter NPC targeting")
    locale="enUS"
    pins[2548]={{questID=id,isQuestStart=false,inProgress=false,x=dx+.001,y=dy+.001}}
    m,x,y,verified=AT.GetQuestTurnInPoint(id,2548)
    assert(m==2548 and x==dx+.001 and y==dy+.001 and not verified,"native coordinates must win")
    pins[2548]=nil
end
for _ in pairs(db) do n=n+1 end
assert(n==#fixtures and not db[95982],"hold conflicting records or unmatched completions")
print("PASS five previously display-only Riverglades completions now route, with native, locale, ready and faction guards")
