local AT={db={enabled=true,autoFocus=true,hideCompleted=true,questHUDEnabled=true},char={}}
local measured,ready,waypoints,inside,watch,cont,pois={},{},{},{},{},{},{}
local selected,map,instance=0,1,false
local ids={11,12,13,14}
C_QuestLog={
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
    assert(AT.GetFocusedQuestID()==id,"focus expected "..tostring(id)..", got "..tostring(AT.GetFocusedQuestID()))
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
ready[11]=true; measured[13]=0
map=2;waypoints[13]={1,.58,.5}; expect(13)
assert(AT.SampleQuestAreas({[13]=true},{})[13]=="near","parent zone resolves missing interior coordinates")
ready[13]=true;ready[11]=false; measured[11]=nil; waypoints[13]=nil
pois[1]={{questID=11,x=.5,y=.51,isQuestStart=true}}
map=1; expect(nil)
instance=true; measured[11]=49; expect(nil)
inside[11]=true; expect(11)
assert(AT.SampleQuestAreas({[11]=true},{})[11]=="inside")
ready[12]=false;AT.ToggleQuestTrackingOrder(12);expect(12)
assert(AT.ToggleQuestHUDManualFocus(11));expect(11)
ready[11]=true;expect(12)
AT.ResetTrackingOrder()
instance=false;cont[14]=true; measured[14]=440;expect(14)
AT.SetQuestExcluded(14,true);expect(12)
cont[12]=false;expect(nil)
print("PASS closest eligible quest follows movement inside and beyond highlight range; ties, exclusions, distances and manual completion work")
