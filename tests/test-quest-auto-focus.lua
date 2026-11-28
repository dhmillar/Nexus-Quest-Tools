local AT={db={enabled=true,autoFocus=true,hideCompleted=true,questHUDEnabled=true},char={}}
local measured,ready,waypoints,inside,watch,cont,pois={},{},{},{},{},{},{}
local selected,map,instance=0,1,false
local ids={11,12,13,14}
C_QuestLog={
    GetQuestUiMapID=function() return map==2 and 1 or map end,
    GetNumQuestLogEntries=function() return #ids end,
    GetInfo=function(i) return {questID=ids[i]} end,
    IsOnQuest=function(id) for _,qid in ipairs(ids) do if id==qid then return true end end return false end,
    GetQuestWatchType=function(id) return watch[id] and 1 or nil end,
    GetNumQuestWatches=function() return 0 end,
    AddQuestWatch=function(id) watch[id]=true; return true end,
    RemoveQuestWatch=function(id) watch[id]=nil end,
    ReadyForTurnIn=function(id) return ready[id] end,
    GetDistanceSqToQuest=function(id) local d=measured[id]; return d and d*d,cont[id] end,
    GetQuestsOnMap=function(m) return pois[m] end,
    GetNextWaypointForMap=function(id,m)
        local p=waypoints[id]; if p and p[1]==m then return p[2],p[3] end
    end,
}
C_SuperTrack={
    SetSuperTrackedQuestID=function(id) selected=id end,
    GetSuperTrackedQuestID=function() return selected end,
}
C_Map={
    GetBestMapForUnit=function() return map end,
    GetMapInfo=function(id) return id==2 and {mapType=5,parentMapID=1} or {mapType=3} end,
    GetMapWorldSize=function(id) if id==1 then return 1000,1000 end end,
    GetPlayerMapPosition=function(id) if id==1 then return {GetXY=function() return .5,.5 end} end end,
}
C_Minimap={IsInsideQuestBlob=function(id) return inside[id] end}
IsInInstance=function() return instance,instance and "party" or "none" end
assert(loadfile("NQT/Quests.lua"))("NQT",AT)
local function expect(id)
    AT.RefreshQuests()
    assert(AT.GetFocusedQuestID()==id,debug.traceback("focus expected "..tostring(id)..", got "..tostring(AT.GetFocusedQuestID()),2))
    assert(selected==(id or 0),"native super tracking follows focus")
end
cont[11],cont[12],cont[13],cont[14]=true,true,true,false
measured[11],measured[12],measured[13],measured[14]=220,0,1000,5
expect(11)
assert(AT.SampleQuestAreas({[11]=true,[12]=true},{})[11]=="outside")
assert(AT.SampleQuestAreas({[12]=true},{})[12]==nil,"unknown native zero is not a near quest")
measured[11],measured[12]=83,50; expect(12)
assert(not watch[11] and watch[12])
measured[11]=50; expect(12)
measured[11]=49; expect(11)
assert(AT.SampleQuestAreas({[11]=true},{})[11]=="near")
assert(AT.ToggleQuestHUDManualFocus(12)); expect(12)
assert(AT.GetQuestNavigationID()==12)
measured[11],measured[12]=30,900
expect(12)
ready[12]=true; expect(11)
assert(not AT.GetQuestHUDManualFocus() and AT.GetQuestNavigationID()==11)
assert(AT.ToggleQuestHUDManualFocus(12)); expect(12)
assert(AT.IsQuestTurnInNavigation(12))
assert(AT.ToggleQuestHUDManualFocus(12)); expect(11)
cont[12]=false; ready[11]=true; measured[11]=200; measured[13]=0
map=2;waypoints[13]={1,.58,.5}; expect(13)
assert(AT.SampleQuestAreas({[13]=true},{})[13]=="near","parent zone resolves missing interior coordinates")
ready[13]=true;ready[11]=false; measured[11]=nil; waypoints[13]=nil
pois[1]={{questID=11,x=.5,y=.51,isQuestStart=true}}
map=1; expect(nil)
instance=true; measured[11]=49; expect(nil)
inside[11]=true; expect(11)
assert(AT.SampleQuestAreas({[11]=true},{})[11]=="inside")
ready[12]=false;cont[12]=true;AT.ToggleQuestTrackingOrder(12);expect(12)
assert(AT.ToggleQuestHUDManualFocus(11));expect(11)
ready[11]=true;expect(12)
AT.ResetTrackingOrder()
instance=false;measured[11]=nil;cont[14]=true; measured[14]=440;expect(14)
AT.SetQuestExcluded(14,true);expect(12)
cont[12]=false;expect(nil)
print("PASS closest eligible quest follows movement inside and beyond highlight range; ties, exclusions, distances and manual completion work")
-- Ready quests use the real hand-in pin (not last objective/blobs).
AT.SetQuestExcluded(14,false);cont[14]=true;measured[14]=250
ready[11]=true;inside[11]=true
pois[1]={{questID=11,x=.6,y=.5,isQuestStart=false,inProgress=false}}
expect(11)
assert(AT.IsQuestTurnInNavigation(11) and select(2,AT.GetQuestNavigationID())=="nearby-turn-in")
local current,m,x,y=AT.GetFocusedQuestRoutePoint()
assert(current==11 and m==1 and x==.6 and y==.5)
assert(watch[11] and not AT.ShouldHideCompletedQuest(11),"the current nearby turn-in watch is temporary")
assert(AT.SampleQuestAreas({[11]=true},{})[11]=="near","inclusive 100-yard hand-in boundary")
measured[14]=50;expect(14);assert(not watch[11],"closer progress wins even inside 100 yards")
measured[14]=250
pois[1][1].x=.601;expect(11);assert(watch[11])
assert(AT.SampleQuestAreas({[11]=true},{[11]="near"})[11]=="outside","outside the 100-yard turn-in range")
measured[14]=100;expect(14)
measured[14]=250;expect(11)
-- A 400-yard hand-in beats an in-progress quest a zone away. The reverse
-- remains true when the in-progress quest is actually closer.
pois[1][1].x=.9;measured[14]=1750;expect(11)
assert(AT.IsQuestTurnInNavigation(11) and select(3,AT.GetFocusedQuestRoutePoint())==.9)
measured[14]=399;expect(14)
AT.db.autoFocus=false;expect(nil)
AT.db.autoFocus=true;measured[14]=1750;expect(11)
measured[14]=250
pois[1][1].x=.51;pois[1][1].inProgress=true;expect(14)
assert(AT.SampleQuestAreas({[11]=true},{[11]="near"})[11]==nil,"stale objective pins and blobs cannot locate turn-in")
pois[1][1].inProgress=false;map=2;expect(11);map=1
assert(AT.ToggleQuestHUDManualFocus(14));expect(14)
assert(AT.ToggleQuestHUDManualFocus(14));expect(11)
AT.ToggleQuestTrackingOrder(14);expect(14)
AT.ResetTrackingOrder();expect(11)
AT.SetQuestExcluded(11,true);expect(14)
AT.SetQuestExcluded(11,false);expect(11)
table.remove(ids,1);expect(14)
ids[#ids+1]=11;pois[1]=nil
AT.ObservedQuestTurnIns={[11]={{1,.55,.5,1,123,0,"Finisher"}}}
expect(11)
assert(select(3,AT.GetFocusedQuestRoutePoint())==.55)
AT.ObservedQuestTurnIns={[11]={{1,.55,.5,1,123,0,"Finisher"},{1,.52,.5,1,124,0,"Alternate"}}}
expect(14)
print("PASS unified distance ranking, GPS, exclusions, manual/queue priority, and completed watch safety")
-- A collapsed log and a native distance without a map pin can still switch.
AT.ObservedQuestTurnIns=nil
local baseLog=C_QuestLog.GetNumQuestLogEntries
C_QuestLog.GetNumQuestLogEntries=function() return 1,#ids end
C_QuestLog.GetInfo=function() return {questID=14} end
AT.GetCachedRankQuestIDs=function() return {[11]=true,[99999]=true} end
measured[11],cont[11]=34,true
inside[14]=true;measured[14]=90
local stockTrack=C_SuperTrack.SetSuperTrackedQuestID
C_SuperTrack.SetSuperTrackedQuestID=function(id)
    if id~=11 or watch[11] then stockTrack(id) end
end
expect(14)
assert(not watch[11],"unknown turn-in location cannot auto-track on same-continent distance alone")
measured[14]=20;expect(14)
inside[14]=nil;measured[14]=nil;expect(nil)
measured[11]=101;measured[14]=90;expect(14)
inside[14]=nil;measured[14]=300;expect(14)
measured[14]=50;expect(14)
inside[14]=nil;measured[14]=200
measured[11]=nil
pois[1]={{questID=11,x=.54,y=.5,inProgress=false}}
expect(11)
assert(select(3,AT.GetFocusedQuestRoutePoint())==.54,"the native ready pin need not repeat isQuestStart=false")
map=2;waypoints[14]={1,.52,.5};expect(14)
waypoints[14]=nil;map=1;expect(11)
-- A hand-in in the neighboring zone is not advertised on the player's map.
C_QuestLog.GetNextWaypoint=function(q) if q==11 then return 3,.57,.5 end end
CreateVector2D=function(x,y) return {GetXY=function()return x,y end} end
C_Map.GetWorldPosFromMapPos=function(m,pos)
    local px,py=pos:GetXY()
    return 1,CreateVector2D(1000*px,1000*py)
end
pois[1]=nil;pois[3]={{questID=11,x=.57,y=.5,inProgress=false}}
expect(14)
assert(AT.ToggleQuestHUDManualFocus(11));expect(11)
assert(select(2,AT.GetFocusedQuestRoutePoint())==3)
assert(AT.ToggleQuestHUDManualFocus(11));expect(14)
ready[13]=true
AT.GetCachedRankQuestIDs=function()return {[11]=true,[13]=true} end
pois[3][2]={questID=13,x=.53,y=.5,inProgress=false}
local count=0
local oldPoints=C_QuestLog.GetQuestsOnMap
C_QuestLog.GetQuestsOnMap=function(m) if m==3 then count=count+1 end;return oldPoints(m) end
AT.char.zoneQuestOrigins={[13]=3}
expect(14);assert(count==1,"shared turn-in map fetched once per focus scan")
table.remove(ids,2);expect(14)
assert(AT.ToggleQuestHUDManualFocus(14));expect(14)
assert(AT.ToggleQuestHUDManualFocus(14));expect(14)
C_QuestLog.GetQuestsOnMap=oldPoints
C_QuestLog.GetNextWaypoint=nil;pois[3]=nil
measured[14]=100
C_QuestLog.GetNumQuestLogEntries=baseLog
C_QuestLog.GetInfo=function(i)return {questID=ids[i]} end
do
    local savedRefs=AT.ForeverQuestNPCReferences
    local savedWorld=C_Map.GetWorldPosFromMapPos
    local savedMap=C_Map.GetPlayerMapPosition
    ready[13]=true;ids[#ids+1]=13
    local playerX=.5
    C_Map.GetPlayerMapPosition=function(m)
        if m==1 then return CreateVector2D(playerX,.5) end
    end
    C_Map.GetWorldPosFromMapPos=function(m,pos)
        local x,y=pos:GetXY()
        return m==4 and 2 or 1,CreateVector2D((m==3 and 1200 or 0)+1400*x,1400*y)
    end
    -- A nearby stale objective distance must not beat the actual hand-in.
    measured[11],cont[11]=10,true
    pois[1]={{questID=13,x=.5+400/1400,y=.5,inProgress=false}}
    inside[14]=nil;measured[14]=2500
    expect(13)
    -- The closer hand-in exists only as a bundled, displayable NPC point.
    AT.ForeverQuestNPCReferences={[11]={{1,.55,.5,1,123,0,"Closer finisher"}}}
    expect(11)
    assert(select(2,AT.GetFocusedQuestRoutePoint())==nil,"reference is not a GPS waypoint")
    playerX=.72;expect(13)
    -- A closer hand-in on another map still loses automatic zone selection.
    playerX=.5;pois[1][1].x=.8
    pois[3]={{questID=11,x=.02,y=.5,inProgress=false}}
    C_QuestLog.GetNextWaypoint=function(q) if q==11 then return 3,.02,.5 end end
    C_Map.GetWorldPosFromMapPos=function(m,pos)
        local x,y=pos:GetXY()
        return m==4 and 2 or 1,CreateVector2D((m==3 and 1052 or 0)+1400*x,1400*y)
    end
    expect(13)
    -- A genuine foreign-world pin must not fall back to the old 10-yard number.
    pois[4]=pois[3];pois[3]=nil
    C_QuestLog.GetNextWaypoint=function(q) if q==11 then return 4,.02,.5 end end
    expect(13)
    C_QuestLog.GetNextWaypoint=nil
    AT.ForeverQuestNPCReferences=savedRefs;C_Map.GetWorldPosFromMapPos=savedWorld
    C_Map.GetPlayerMapPosition=savedMap;pois[1],pois[4]=nil,nil
    table.remove(ids);measured[11]=nil;measured[14]=100;inside[14]=true
    print("PASS nearest of multiple ready turn-ins, display-only endpoints, movement, common yard scale, and stale/foreign evidence")
end
print("PASS ready quest without native pin, hidden rows, stock watch required, broad blob ranking, distance-only GPS safety and omitted POI flags")

do
    local id=ids[1]
    assert(id)
    ready[id],inside[id],measured[id],cont[id]=false,true,380,true
    map,instance=1,false
    local x=.5
    local oldPos=C_Map.GetPlayerMapPosition
    C_Map.GetPlayerMapPosition=function()
        return {GetXY=function() return x,.5 end}
    end
    local samples={[id]=true}
    assert(AT.SampleQuestAreas(samples,{})[id]=="inside")
    inside[id]=false
    x=.51
    assert(AT.SampleQuestAreas(samples,{[id]="inside"})[id]=="near","far POI does not override verified objective edge")
    measured[id]=nil
    x=.60
    assert(AT.SampleQuestAreas(samples,{[id]="near"})[id]=="near","highlight stays at 100 yards even without a POI")
    x=.601
    assert(AT.SampleQuestAreas(samples,{[id]="near"})[id]=="outside","clear past 100 yards")
    x=.55
    assert(AT.SampleQuestAreas(samples,{})[id]=="near","reenter the nearby band without touching the blob")
    instance=true
    assert(AT.SampleQuestAreas(samples,{})[id]~="near","do not carry outdoor samples into an instance")
    instance=false
    assert(AT.SampleQuestAreas(samples,{})[id]~="near","old samples do not return after zoning out of an instance")
    C_Map.GetPlayerMapPosition=oldPos
    print("PASS Rank Quest preserves area highlights at the edge and up to 100 yards beyond; same-map measurement; instance reset")
end

do
    assert(loadfile("NQT/ForeverVerifiedEndpoints.lua"))("NQT",AT)
    function UnitFactionGroup() return "Alliance" end
    map=2548;ids={1360,96084,77}
    visibleReady={}
    C_QuestLog.GetLogIndexForQuestID=function(q)
        for i,v in ipairs(ids) do if v==q then return i end end
    end
    C_QuestLog.GetInfo=function(i) return {questID=ids[i],isComplete=visibleReady[ids[i]]} end
    C_Map.GetPlayerMapPosition=function() return CreateVector2D(.6111,.8401) end
    C_Map.GetWorldPosFromMapPos=function(m,p)
        local x,y=p:GetXY();return 0,CreateVector2D(x*5500,y*5500)
    end
    visibleReady[96084]=1
    ready[96084]=false
    measured[1360],cont[1360]=3463,true
    measured[77],cont[77]=150,true
    assert(AT.IsQuestReadyForTurnIn(96084))
    expect(96084)
    assert(select(2,AT.GetQuestNavigationID())=="nearby-turn-in")
    measured[77]=20;expect(77)
    assert(AT.ToggleQuestHUDManualFocus(1360));expect(1360)
    ready[1360]=true;expect(77)
    assert(not AT.GetQuestHUDManualFocus(),"completion resumes closest-quest auto mode")
    measured[77]=150;expect(96084)
    local lines={}
    AT.Say=function(line) lines[#lines+1]=line end
    C_QuestLog.GetTitleForQuestID=function(id) return id==96084 and "Something's in the Water" end
    AT.ReportRankQuestTurnIns()
    assert(lines[2]:find("#96084",1,true) and lines[2]:find(" yd",1,true) and selected==96084)
    local targetID,targets=AT.GetFocusedQuestRouteTargets(2548)
    assert(targetID==96084 and #targets==1 and targets[1].x==.6178 and targets[1].y==.8318,
        "route to the cross-checked Sister Rowland hand-in without a native pin")
    local _,m,x,y=AT.GetFocusedQuestRoutePoint()
    assert(m==2548 and x==.6178 and y==.8318)
    inside[77]=true;measured[77]=nil
    expect(96084)
    assert(AT.SampleQuestAreas({[77]=true},{})[77]=="inside","area fallback still highlights but does not beat the measured hand-in")
    assert(AT.ToggleQuestHUDManualFocus(96084))
    targetID,targets=AT.GetFocusedQuestRouteTargets(2548)
    assert(targetID==96084 and #targets==1 and targets[1].x==.6178)
    -- Old kill-zone points never become completed-quest routing destinations.
    C_QuestLog.GetNextWaypoint=function() return 2548,.2,.2 end
    pois[2548]={{questID=96084,x=.2,y=.2,isQuestStart=false,inProgress=true}}
    assert(select(3,AT.GetFocusedQuestRoutePoint())==.6178)
    pois[2548][1].inProgress=false
    assert(select(3,AT.GetFocusedQuestRoutePoint())==.6178,"an old kill-zone pin flagged as ready must not beat the known hand-in")
    pois[2548][1].x=.618;pois[2548][1].y=.832
    assert(select(3,AT.GetFocusedQuestRoutePoint())==.618,"a consistent client hand-in pin remains preferred")
    pois[2548]=nil
    function UnitFactionGroup() return "Horde" end
    assert(select(2,AT.GetFocusedQuestRoutePoint())==nil,"don't route to another faction's finisher")
    function UnitFactionGroup() return "Alliance" end
    AT.ObservedQuestTurnIns={[96084]={{2548,.6178,.8318,1,262031,1,"Sister Rowland"},
        {2548,.4,.3,1,1,1,"Conflicting finisher"}}}
    assert(select(2,AT.GetFocusedQuestRoutePoint())==nil,"do not paper over conflicting observed hand-ins")
    AT.ObservedQuestTurnIns=nil
    assert(AT.ToggleQuestHUDManualFocus(96084))
    AT.db.autoFocus=false;selected=0
    C_QuestLog.GetNumQuestWatches=function() return 1 end
    C_QuestLog.GetQuestIDForQuestWatchIndex=function() return 96084 end
    assert(AT.GetQuestNavigationID()==96084 and AT.IsQuestTurnInNavigation(96084))
    assert(select(3,AT.GetFocusedQuestRoutePoint())==.6178)
    print("PASS ready-quest GPS: auto, manual and single watch; verified coordinates; stale pin, faction and conflicting evidence guards")
    print("PASS Farholde screenshot coordinates, exact hand-in fallback, closer unfinished quest, and manual completion reset")
end


do
    -- Screenshot: in Riverglades, manually select the Stranglethorn hand-in.
    map=2548;ids={206,77};ready[206]=true;visibleReady={};ready[77]=false
    AT.db.autoFocus=true;selected=0
    pois[2548]=nil
    local oldZone=C_QuestLog.GetQuestUiMapID
    C_QuestLog.GetQuestUiMapID=function(id) return id==77 and 1434 or oldZone(id) end
    C_QuestLog.GetNextWaypoint=function(id) if id==77 then return 1434,.28,.08 end end
    inside[77]=true;measured[77]=4;cont[77]=true
    C_Map.GetMapWorldSize=function() return 5500,5500 end
    C_Map.GetPlayerMapPosition=function() return CreateVector2D(.6337,.3930) end
    C_Map.GetWorldPosFromMapPos=function(m,p)
        local x,y=p:GetXY();return 0,CreateVector2D(x*5500+(m==1434 and 5200 or 0),y*5500)
    end
    C_QuestLog.GetNumQuestWatches=function()return 1 end
    C_QuestLog.GetQuestIDForQuestWatchIndex=function()return 206 end
    expect(nil)
    assert(AT.GetQuestNavigationID()==nil,"a leftover nonlocal watch must not produce a line")
    assert(AT.ToggleQuestHUDManualFocus(206));expect(206)
    local id,goals=AT.GetFocusedQuestRouteTargets(2548)
    assert(id==206 and #goals==1 and goals[1].map==1434 and goals[1].x==.378 and goals[1].y==.036)
    local bundled={
        version=2,minor=13,NavVersion=function()return "test-route"end,
        EstimateWalks=function()error("a verified single hand-in does not need an estimate pass")end,
        WalkPath=function(_,from,to,reply)
            assert(from.map==2548 and to.map==1434 and to.x==.378 and to.y==.036)
            reply({navVersion="test-route",yards=6400,waypoints={from,to}})
            return function()end
        end
    }
    AT.GetBundledWalkingAPI=function()return bundled end
    assert(loadfile("NQT/Walking.lua"))("NQT",AT)
    local walking,handIn=AT.GetFocusedQuestWalkingPath(206,{map=2548,x=.6337,y=.3930},5500,5500)
    assert(walking and handIn.map==1434,"verified manual turn-in is sent across zones to the walking solver")
    assert(AT.ToggleQuestHUDManualFocus(206));expect(nil)
    ids[#ids+1]=96085;ready[96085]=true
    C_Map.GetPlayerMapPosition=function() return CreateVector2D(.6163,.8442) end
    expect(96085)
    assert(select(2,AT.GetFocusedQuestRoutePoint())==2548 and select(3,AT.GetFocusedQuestRoutePoint())==.6178,
        "Farholde screenshot: prefer the local ready quest at Sister Rowland")
    assert(AT.ToggleQuestHUDManualFocus(206));expect(206)
    assert(AT.ToggleQuestHUDManualFocus(206));expect(96085)
    print("PASS Riverglades: no automatic route out of zone, manual Mai'Zoth routes to Brother Nimetz in Stranglethorn")
end
