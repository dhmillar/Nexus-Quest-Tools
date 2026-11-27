local AT={db={enabled=true},char={}}
local faction,locale,held,ready="Alliance","enUS",true,true
local pins={}
Questie,QuestieLoader=nil,nil
function UnitFactionGroup()return faction end
function GetLocale()return locale end
function CreateFrame()return {RegisterEvent=function()end,SetScript=function()end}end
C_Timer={After=function()end}
C_Map={GetBestMapForUnit=function() return 11 end}
C_QuestLog={
    IsOnQuest=function()return held end,
    ReadyForTurnIn=function()return ready end,
    GetQuestsOnMap=function(map)return pins[map]end,
}
for _,f in ipairs({"Quests","ForeverTownPins","ForeverQuestFacts","ForeverVerifiedEndpoints"})do
    assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
local map,x,y,name,click,approx=AT.GetReadyQuestTurnInPoint(94843)
assert(map==2548 and x==.4113 and y==.6294 and name=="Halligan Turner" and click and approx,
    "Forever turn-in display resolves without Questie from explicit A-side interaction")
AT.db.questHUDEnabled=true
assert(AT.ToggleQuestHUDManualFocus(94843) and AT.IsQuestTurnInNavigation(94843))
assert(not AT.GetQuestTurnInPoint(94843),"observed interaction point is not native GPS")
pins[2548]={{questID=94843,isQuestStart=false,inProgress=false,x=.412,y=.630}}
map,x,y,name,click,approx=AT.GetReadyQuestTurnInPoint(94843,2548)
assert(map==2548 and x==.412 and y==.630 and name=="Halligan Turner" and click and not approx,
    "native live pin wins at matching location")
pins[2548]=nil
faction="Horde"
assert(not AT.GetReadyQuestTurnInPoint(94843),"never return Alliance-only row for Horde")
map,x,y,name,click,approx=AT.GetReadyQuestTurnInPoint(93971)
assert(map==2548 and x==.594 and y==.4573 and name=="Krom'rosh" and click and approx)
assert(AT.ToggleQuestHUDManualFocus(93971) and not AT.GetQuestTurnInPoint(93971),
    "recipient reference must not become a native GPS point")
map,x,y,name,click,approx=AT.GetReadyQuestTurnInPoint(702)
assert(map==1417 and name=="Gor'mul" and click and approx)
locale="frFR"
map,x,y,name,click=AT.GetReadyQuestTurnInPoint(702)
assert(map==1417 and not name and not click,"do not feed enUS names to another locale")
held=false
assert(not AT.GetReadyQuestTurnInPoint(702),"unheld quest cannot use fallback")
held=true;ready=false
assert(not AT.GetReadyQuestTurnInPoint(702),"unready quest cannot use fallback")
assert(not AT.ForeverVerifiedEndpointReferences[95454],"keep conflicting completion recipient unresolved")
print("PASS Forever turn-in observations: standalone display, factions, locale, live pin precedence, no guess and no reference GPS")

