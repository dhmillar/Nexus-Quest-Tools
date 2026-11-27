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
for _,id in ipairs({2747,8893,5214,5251,98423,94886,94888,94889,96015,95957,95975,95059,5212,5213,5582,5382,5515,5384}) do
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
for _,id in ipairs({95817,95818,95819,95820,95821,94892,94907,94926,94982,94984,94992,95315,95912,96009,96081,96082,84400}) do
    local ref=assert(AT.ForeverVerifiedEndpointReferences[id])[1]
    faction=ref[6]==1 and "Alliance" or "Horde"
    local m,px,py,npc,clickable,estimated=AT.GetReadyQuestTurnInPoint(id)
    assert(m==ref[1] and px==ref[2] and py==ref[3] and npc==ref[7] and clickable and estimated, "fallback mismatch "..id.." ("..tostring(m)..","..tostring(px)..","..tostring(py)..","..tostring(npc)..","..tostring(estimated)..")")
    assert(AT.ToggleQuestHUDManualFocus(id) and not AT.GetQuestTurnInPoint(id))
    faction=faction=="Alliance" and "Horde" or "Alliance"
    assert(not AT.GetReadyQuestTurnInPoint(id))
end
faction="Horde"
pins[1454]={{questID=95821,isQuestStart=false,inProgress=false,x=.630,y=.445}}
map,x,y,name,click,approx=AT.GetReadyQuestTurnInPoint(95821)
assert(map==1454 and x==.630 and y==.445 and name=="Karolek" and click and not approx)
local beach,chest,targetable=AT.GetReadyQuestTurnInArea(2882)
assert(beach=="Land's End Beach, Tanaris" and chest=="Pirate's Treasure!" and not targetable and not AT.GetReadyQuestTurnInPoint(2882))
print("PASS Forever turn-in observations: standalone display, factions, locale, live pin precedence, no guess and no reference GPS")


-- Reported Riverglades Completed pane: names and coordinates without Questie or native pins.
faction="Alliance";pins={}
for _,e in ipairs({
    {95799,1455,.7754,.1182,"Historian Karnik"},
    {1360,1455,.7419,.0939,"Krom Stoutarm"},
    {95219,1444,.3104,.4312,"Mardrack Greenwell"},
    {94983,2548,.3066,.4902,"Sergeant Riftan"},
    {94894,1453,.8021,.3835,"Highlord Bolvar Fordragon"},
    {94893,1453,.5012,.5155,"Abigail Lawson"},
}) do
    local m,px,py,npc,action=AT.GetReadyQuestTurnInPoint(e[1],2548)
    assert(m==e[2] and math.abs(px-e[3])<.002 and math.abs(py-e[4])<.003 and npc==e[5] and action,"wrong screenshot recipient "..e[1].." "..tostring(npc))
end
local dig,baelog,canTarget=AT.GetReadyQuestTurnInArea(2398)
assert(dig=="Dig Two, Uldaman" and baelog=="Baelog" and canTarget and not AT.GetReadyQuestTurnInPoint(2398))
local audited={1948,1952,1954,1955,2748,2750,2853,3445,3568,3642,4771,5243,5262,5263,5503,5538,6026,6041,6361,78124,78127,78146,79951,84394,94265,96075}
for _,id in ipairs(audited) do
    local ref=assert(AT.ForeverVerifiedEndpointReferences[id])[1]
    faction=ref[6]==2 and "Horde" or "Alliance"
    local m,px,py,npc,action=AT.GetReadyQuestTurnInPoint(id)
    assert(m==ref[1] and px==ref[2] and py==ref[3] and npc==ref[7] and action,"bad audited turn-in "..id)
end
faction="Horde"
assert(not AT.GetReadyQuestTurnInPoint(1360) and not AT.GetReadyQuestTurnInArea(2398))
map,x,y,name,click=AT.GetReadyQuestTurnInPoint(2342)
assert(map==1458 and name=="Patrick Garrett" and click)
print("PASS all seven missing screenshot turn-ins, same-title faction variants, and 26 separately corroborated endpoint locations")


-- Full imported set: test real lookup for each quest, not just table count.
-- The localized client keeps native authority, and references alone cannot route.
local imported=0
local beforeF,beforeHeld,beforeLocale=faction,held,locale
pins={};held=true;locale="enUS"
for id,rows in pairs(AT.ForeverSupplementalTurnInReferences) do
    imported=imported+1
    assert(#rows==1 and not AT.ForeverVerifiedEndpointReferences[id] and not AT.ForeverTurnInAreaReferences[id])
    local r=rows[1]
    faction=r[6]==2 and "Horde" or "Alliance"
    local m,px,py,npc,action,estimated=AT.GetReadyQuestTurnInPoint(id)
    assert(m==r[1] and px==r[2] and py==r[3] and npc==r[7] and estimated,"bad Questie fact "..id)
    assert((not not action)==(r[4]==1),"wrong role "..id)
    assert(r[2]>0 and r[2]<1 and r[3]>0 and r[3]<1)
    if r[6]~=0 then
        faction=r[6]==2 and "Alliance" or "Horde"
        assert(not AT.GetReadyQuestTurnInPoint(id),"wrong faction imported "..id)
    end
end
assert(imported==2343)
faction="Horde"
assert(AT.ToggleQuestHUDManualFocus(98325) and not AT.GetQuestTurnInPoint(98325),"reference alone is not native GPS")
local row=AT.ForeverSupplementalTurnInReferences[98325][1]
local decoy={questID=98325,isQuestStart=false,inProgress=false,x=.1,y=.1}
pins[row[1]]={decoy}
assert(not AT.GetQuestTurnInPoint(98325),"old objective mislabeled as ready must not become GPS")
pins[row[1]]={decoy,{questID=98325,isQuestStart=false,inProgress=false,x=row[2]+.001,y=row[3]}}
map,x,y,name,click,approx=AT.GetReadyQuestTurnInPoint(98325)
assert(map==row[1] and x==row[2]+.001 and name=="Warlord Goretooth" and click and not approx)
assert(AT.GetQuestTurnInPoint(98325)==row[1],"verified native pin found through the imported map hint")
locale="deDE"; assert(select(4,AT.GetReadyQuestTurnInPoint(98325))==nil)
held=false; assert(not AT.GetReadyQuestTurnInPoint(98325))
faction,held,locale=beforeF,beforeHeld,beforeLocale
print("PASS all 2343 QuestieDB gap imports resolve without the addon, guard factions, prefer native pins and do not create speculative GPS")

-- A tracked completed quest can now use a unique, faction-safe NPC record
-- on an actual outdoor zone when WoW provides no compatible hand-in pin.
faction="Horde";locale="enUS";held=true;ready=true
function C_Map.GetMapInfo(id)
    if id==row[1] then return {mapType=3,parentMapID=1415} end
end
pins[row[1]]={decoy}
local dst,dx,dy,origin=AT.GetQuestTurnInPoint(98325)
assert(dst==row[1] and dx==row[2] and dy==row[3] and origin=="recorded NPC location",
    "ready quest GPS must use the known NPC, not an objective pin falsely marked as finished")
local nav,m,rX,rY,source=AT.GetFocusedQuestRoutePoint()
assert(nav==98325 and m==dst and rX==dx and rY==dy and source==origin,"shared route uses the recorded NPC")
faction="Alliance";pins={}
assert(not AT.GetQuestTurnInPoint(98325),"wrong faction cannot route to a fallback NPC")
faction="Horde"
function IsInInstance()return true,"party" end
assert(not AT.GetQuestTurnInPoint(98325),"no outdoor fallback route while inside a dungeon")
function IsInInstance()return false,"none" end
AT.ForeverSupplementalTurnInReferences[98325]={{row[1],row[2],row[3],2,row[5],row[6],row[7]}}
assert(not AT.GetQuestTurnInPoint(98325),"no speculative route to an object reference")
print("PASS recorded ready turn-ins route to the exact NPC across both route consumers; decoy, faction, object and instance protection")
