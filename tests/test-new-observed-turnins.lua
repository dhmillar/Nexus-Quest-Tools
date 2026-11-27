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
local map,x,y,name,click,approx=AT.GetReadyQuestTurnInPoint(86613)
assert(map==1432 and x==.6584 and y==.6545 and name=="Prospector Ironband" and click and not approx)
pins[1432]={{questID=86613,isQuestStart=false,inProgress=false,x=.659,y=.656}}
map,x,y,name,click=AT.GetReadyQuestTurnInPoint(86613,1432)
assert(map==1432 and x==.659 and y==.656 and name=="Prospector Ironband" and click)
pins[1432]=nil
map,x,y,name,click,approx=AT.GetReadyQuestTurnInPoint(94843)
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
map,x,y,name,click,approx=AT.GetReadyQuestTurnInPoint(94980)
assert(map==2548 and x==.644 and y==.820 and name=="Alphonse Dumas" and click and approx)
assert(AT.ToggleQuestHUDManualFocus(94980) and not AT.GetQuestTurnInPoint(94980),"approximate Alliance reference cannot drive GPS")
assert(not AT.GetReadyQuestTurnInPoint(94973),"Horde Moulding is distinct")
faction="Horde"
assert(not AT.GetReadyQuestTurnInPoint(94980),"Alliance Moulding is distinct")
map,x,y,name,click=AT.GetReadyQuestTurnInPoint(94973)
assert(map==2548 and name=="Kreza Darkthorn" and click,"keep the previously observed Horde hand-in")
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
held=true;ready=true;locale="enUS"
map,x,y,name,click,approx=AT.GetReadyQuestTurnInPoint(5529)
assert(map==1423 and x==.7158 and y==.4989 and name=="Betina Bigglezink" and click and approx)
assert(AT.ToggleQuestHUDManualFocus(5529) and not AT.GetQuestTurnInPoint(5529),"party field data cannot set native GPS")
local area,recipient,clickable=AT.GetReadyQuestTurnInArea(7463)
assert(area=="Dire Maul, the Athenaeum" and recipient=="Lorekeeper Lydros" and clickable and not AT.GetReadyQuestTurnInPoint(7463))
assert(not AT.ForeverVerifiedEndpointReferences[95454],"keep conflicting completion recipient unresolved")
for _,id in ipairs({2747,8893,5214,5251}) do
    local ref=assert(AT.ForeverVerifiedEndpointReferences[id])[1]
    faction=ref[6]==2 and "Horde" or "Alliance"
    local m,sx,sy,recipient,canTarget,estimated=AT.GetReadyQuestTurnInPoint(id)
    assert(m==ref[1] and sx==ref[2] and sy==ref[3] and recipient==ref[7] and estimated, "bad fallback "..id)
    assert((not not canTarget)==(ref[4]==1), "object or NPC action mismatch "..id)
    assert(AT.ToggleQuestHUDManualFocus(id) and not AT.GetQuestTurnInPoint(id), "observation is not native GPS "..id)
    if ref[6]~=0 then
        faction=faction=="Alliance" and "Horde" or "Alliance"
        assert(not AT.GetReadyQuestTurnInPoint(id), "opposite-faction fallback "..id)
    end
end
for _,id in ipairs({93443,94928}) do
    faction="Horde"
    assert(not AT.GetReadyQuestTurnInPoint(id),"neutral NPC is not a Horde hand-in "..id)
    faction="Alliance"
    local m,sx,sy,npc,action,estimated=AT.GetReadyQuestTurnInPoint(id)
    assert(m==2548 and sx==.7708 and sy==.5285 and npc=="Friz Frazzlespark" and action and estimated)
end
pins[2548]={{questID=93443,isQuestStart=false,inProgress=false,x=.771,y=.529}}
map,x,y,name,click,approx=AT.GetReadyQuestTurnInPoint(93443,2548)
assert(map==2548 and x==.771 and y==.529 and name=="Friz Frazzlespark" and click and not approx)
pins[2548]=nil
for _,id in ipairs({91900,91906}) do
    for _,expected in ipairs({{"Alliance",1433,"Marcy Baker"},{"Horde",1413,"Dokimi"}}) do
        faction=expected[1]
        local m,_,_,npc,action=AT.GetReadyQuestTurnInPoint(id)
        assert(m==expected[2] and npc==expected[3] and action, "wrong Sealed Crate faction "..id)
    end
end
faction="Alliance"
pins[1433]={{questID=91906,isQuestStart=false,inProgress=false,x=.097,y=.710}}
map,x,y,name,click=AT.GetReadyQuestTurnInPoint(91906)
assert(map==1433 and x==.097 and y==.710 and name=="Marcy Baker" and click)
pins[1433]=nil
faction="Alliance"
local camp,elaine,canTarget=AT.GetReadyQuestTurnInArea(95816)
assert(camp=="Three Corners trading camp, Redridge Mountains" and elaine=="Elaine Compton" and canTarget)
assert(not AT.GetReadyQuestTurnInPoint(95816))
faction="Horde"
assert(not AT.GetReadyQuestTurnInArea(95816))
for _,id in ipairs({95817,95818,95819,95820,95821}) do
    local ref=assert(AT.ForeverVerifiedEndpointReferences[id])[1]
    faction=ref[6]==1 and "Alliance" or "Horde"
    local m,px,py,npc,clickable,estimated=AT.GetReadyQuestTurnInPoint(id)
    assert(m==ref[1] and px==ref[2] and py==ref[3] and npc==ref[7] and clickable and estimated)
    assert(AT.ToggleQuestHUDManualFocus(id) and not AT.GetQuestTurnInPoint(id))
    faction=faction=="Alliance" and "Horde" or "Alliance"
    assert(not AT.GetReadyQuestTurnInPoint(id))
end
faction="Horde"
pins[1454]={{questID=95821,isQuestStart=false,inProgress=false,x=.630,y=.445}}
map,x,y,name,click,approx=AT.GetReadyQuestTurnInPoint(95821)
assert(map==1454 and x==.630 and y==.445 and name=="Karolek" and click and not approx)
print("PASS Forever turn-in observations: standalone display, factions, locale, live pin precedence, no guess and no reference GPS")
