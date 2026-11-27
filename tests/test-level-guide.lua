local AT={char={}}
local playerLevel=20
local done={[104]=true}
local openToMap,requests
local activeWaypoint,waypointTracked
UnitLevel=function() return playerLevel end
UnitRace=function() return "Human","Human",1 end
UnitClass=function() return "Hunter","HUNTER",3 end
UnitFactionGroup=function() return "Alliance" end
local function levelRecord(level,area,name,objs,min,mask,tier)
    return {min or 1,level,area,0,mask or "ffffffffffffffff",tier or 5,1,0,name,objs or {}}
end
AT.ForeverLevelGuideQuests={
 [101]=levelRecord(20,40,"Westfall cull",{{1,500,8}}),
 [102]=levelRecord(20,44,"Redridge trinkets",{{2,111,8}}),
 [103]=levelRecord(20,44,"Redridge rations",{{2,112,8}}),
 [104]=levelRecord(20,40,"Already turned in",{{1,501,5}}),
 [105]=levelRecord(24,44,"Not high enough",{{1,500,8}},24),
 [106]=levelRecord(20,40,"Other faction",{{1,500,8}},1,"0000000000000002"),
 [107]=levelRecord(20,40,"Historical only",{{2,113,1}}),
 [108]=levelRecord(20,40,"Ready to report",{{1,502,10}}),
 [109]=levelRecord(18,1581,"Deadmines passage",{{1,503,8}}),
 [110]=levelRecord(25,44,"Next zone when leveled",{{1,500,8}},25),
 [111]=levelRecord(20,0,"Native qualifying area",{{1,510,8}}),
 [112]=levelRecord(20,40,"Party reminder, not held",{{1,510,8}}),
 [113]=levelRecord(20,0,"Outdoor errand with stale dungeon tag",{{1,510,8}}),
 [114]=levelRecord(25,1581,"Dungeon quest above your minimum",{{1,503,8}},24),
 [115]=levelRecord(20,40,"Catalog row missing objectives",{}),
 [116]=levelRecord(20,44,"Westfall kill counted even when finished",{{1,523,8}}),
 [117]=levelRecord(20,717,"Stockade package",{{2,112,1}}),
}
AT.GetLevelGuideQuestLog=function() return {[108]={title="Ready to report",complete=true,destination=1436},
    [112]={title="Party reminder, not held",partyOnly=true,destination=1436},
    [113]={title="Outdoor errand with stale dungeon tag",dungeon="Deadmines",destination=1436},
    [115]={title="Catalog row missing objectives",destination=1436},
    [116]={title="Finished but not turned in",complete=true,destination=1433}} end
AT.ObservedQuestStarts={[1436]={{107,.4,.4,1}}}
AT.LevelGuideQuestGivers={[101]={{1436,.45,.72,1,42,"Giver of Westfall"}},[109]={{1436,.31,.42,1,84,"Outside Dungeon Giver"}}}
UiMapPoint={CreateFromCoordinates=function(m,x,y) return {uiMapID=m,position={GetXY=function()return x,y end}} end}
C_SuperTrack={SetSuperTrackedUserWaypoint=function(v) waypointTracked=v end,
    IsSuperTrackingUserWaypoint=function() return waypointTracked==true end}
AT.ObservedQuestDrops={items={[111]={{500,1,10,0,0,0}},[112]={{501,5,10,0,0,0}}}}
AT.LevelGuideMapReveal={[7000]={["250:130:20:30"]="1001, 1002"}}
local names={[1436]="Westfall",[1433]="Redridge Mountains",[1431]="Duskwood",[6000]="Frontier",
    [6100]="Deadmines"}
C_Map={
 GetBestMapForUnit=function() return 1436 end,
 GetMapInfo=function(id) return names[id] and {name=names[id],mapType=id==6100 and 4 or 3} end,
 GetMapChildrenInfo=function(id,ty)
    if id~=1415 then return {} end
    if ty==3 then return {{mapID=6000,name=names[6000]}} end
    return {{mapID=6100,name=names[6100]}}
 end,
 GetMapArtLayers=function(id)
    if id==1436 then return {{layerWidth=300,layerHeight=200,tileWidth=200,tileHeight=200}} end
 end,
 GetMapArtID=function(id) if id==1436 then return 7000 end end,
 GetMapArtLayerTextures=function() return {8,9} end,
 SetUserWaypoint=function(p) activeWaypoint=p end,
 GetUserWaypoint=function() return activeWaypoint end,
 ClearUserWaypoint=function() activeWaypoint=nil;waypointTracked=false end,
}
local offers={[1436]={101,104,106},[1433]={102,103,105,110},[6000]={111},[6100]={109}}
-- The wrong-faction historical quest is not a native offer.
table.remove(offers[1436],3)
C_QuestLog={
 GetQuestsOnMap=function(id)
    local list={}
    for _,q in ipairs(offers[id] or {}) do list[#list+1]={questID=q,isQuestStart=true} end
    return list
 end,
 GetQuestRewardXP=function(id) if id==101 then return 375 end end,
 IsQuestFlaggedCompleted=function(id) return done[id]==true end,
 GetAllCompletedQuestIDs=function()return {} end, -- per-quest flag must still win
 GetQuestObjectives=function(id)
    if id==115 then return {{type="item",itemID=111,text="Acorns: 2/7"},
        {type="monster",text="Rescue trapped guards: 0/2"}} end
    if id==116 then return {{type="monster",text="Wild cats slain: 8/8",finished=true}} end
    return {}
 end,
}
assert(loadfile("NQT/LevelGuide.lua"))("NQT",AT)
local function place(r,name)
    for _,p in ipairs(r.places)do if p.name==name then return p end end
    error(name)
end
local solo=AT.BuildLevelGuide()
local west=place(solo,"Westfall");local red=place(solo,"Redridge Mountains")
assert(west.count==4 and west.available==1 and west.leads==2 and west.total==6,"include quests outside log without calling party reminders held")
assert(west.mix.kill==3 and west.mix.collect==1 and west.mix.turnin==1 and west.xpKnown==1 and west.exactXP==375)
assert(red.count==3 and red.mix.collect==2 and red.mix.kill==1 and red.mix.turnin==1 and red.lowDrops==1 and red.score<west.score)
assert(place(solo,"Frontier").count==1 and place(solo,"Frontier").lo==20)
local dungeon=place(solo,"Deadmines")
assert(dungeon.count==1 and dungeon.artMap==6100)
for _,q in ipairs(dungeon.quests) do assert(q.id~=113 and q.id~=117) end
assert(dungeon.quests[1].id==109 and not dungeon.quests[2].availableHere)
assert(place(solo,"Stockade").quests[1].id==117)
local sparseScore=AT.ScoreLevelGuideQuest(115,AT.ForeverLevelGuideQuests[115],20,1,{status="In log",held=true})
assert(sparseScore.kind=="collect" and sparseScore.items==5 and sparseScore.kills==0 and sparseScore.lowRate==.1)
local shadowScore=AT.ScoreLevelGuideQuest(116,AT.ForeverLevelGuideQuests[116],20,1,{status="Turn in",held=true})
assert(shadowScore.kind=="kill" and shadowScore.kills==0 and shadowScore.work==2)
local questieReads=0
LibQuestieDB=setmetatable({},{__index=function() questieReads=questieReads+1; error("external provider read") end})
local independent=place(AT.BuildLevelGuide(),"Westfall")
assert(independent.total==west.total and questieReads==0)
LibQuestieDB=nil
for _,q in ipairs(west.quests) do assert(q.id~=104 and q.id~=106) end
local duo=AT.BuildLevelGuide(20,2)
local trio=AT.BuildLevelGuide(20,3)
assert(place(trio,"Westfall").score>place(duo,"Westfall").score and place(duo,"Westfall").score>west.score)
assert(AT.ScoreLevelGuideQuest(102,AT.ForeverLevelGuideQuests[102],20,3,{status="Pick up"}).work > AT.ScoreLevelGuideQuest(102,AT.ForeverLevelGuideQuests[102],20,1,{status="Pick up"}).work)
done[101]=true;playerLevel=25
local leveled=AT.BuildLevelGuide()
assert(place(leveled,"Westfall").count==3 and place(leveled,"Redridge Mountains").count==5)
assert(AT.FilterLevelGuide(solo,"dungeons","drowned",35,40)[1].name=="The Drowned City")
assert(#AT.FilterLevelGuide(solo,"dungeons","drowned",13,19)==0)
assert(AT.FilterLevelGuide(solo,"zones","red",30,15)[1].name=="Redridge Mountains")
assert(#AT.FilterLevelGuide(solo,"zones","duskwood",20,20)==1)
print("PASS recommendations: completion, level-ups, owned progress, availability, party pace, XP, drop rates, dungeons, and manual filters")

local env={}
local function object()
 local obj={shown=true,scripts={},events={},texture=nil}
 for _,k in ipairs({"SetSize","SetPoint","SetAllPoints","SetColorTexture","SetTexCoord","SetJustifyH",
 "SetTextColor","SetWordWrap","SetWidth","SetHeight","SetFrameStrata","SetMovable","EnableMouse",
 "SetClampedToScreen","SetScale","SetResizable","SetResizeBounds","SetBackdrop","SetBackdropColor","SetBackdropBorderColor","SetAutoFocus",
 "SetMaxLetters","SetNumeric","ClearFocus","RegisterForDrag","RegisterForClicks","SetFrameLevel",
 "ClearAllPoints","StartMoving","StopMovingOrSizing"}) do obj[k]=function() end end
 function obj:GetFrameLevel() return self.frameLevel or (self.parent and self.parent:GetFrameLevel()+1 or 9) end
 function obj:SetFrameLevel(level) self.frameLevel=level end
 function obj:EnableMouse(value) self.mouseEnabled=value end
 function obj:RegisterForClicks(...) self.clicks={...} end
 function obj:SetPoint(...) self.point={...} end
 function obj:SetVertexColor() end
 function obj:SetBlendMode() end
 function obj:SetAlpha(v) self.alpha=v end
 function obj:GetFont() return "Fonts/FRIZQT__.TTF",self.fontSize or 14 end
 function obj:SetFont(_,size) self.fontSize=size;return true end
 function obj:GetUnboundedStringWidth() return #(self.text or "")*(self.fontSize or 14)*.53 end
 function obj:GetScript(k) return self.scripts[k] end
 function obj:SetPropagateMouseWheel(v) self.wheelPropagates=v end
 function obj:SetFrameStrata(v) self.strata=v end
 function obj:HookScript(k,f) self:SetScript(k,f) end
 function obj:SetDrawLayer(layer,sub) self.sublevel=sub end
 function obj:SetTexCoord(...) self.texCoord={...} end
 function obj:SetOrientation(v) self.orientation=v end
 function obj:SetThumbTexture(v) self.thumb=object();self.thumb.texture=v end
 function obj:GetThumbTexture() return self.thumb end
 function obj:SetMinMaxValues(a,b) self.minimum,self.maximum=a,b end
 function obj:SetValueStep(v) self.step=v end
 function obj:SetValue(v) self.value=v;if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v) end end
 function obj:SetNormalTexture(asset) self.normal=object();self.normal.texture=asset end
 function obj:SetPushedTexture(asset) self.pushed=object();self.pushed.texture=asset end
 function obj:SetHighlightTexture() end
 function obj:SetChecked(v) self.checked=v end
 function obj:GetChecked() return self.checked end
 function obj:EnableMouseWheel(v) self.mouseWheel=v end
 function obj:SetScrollChild(child) self.scrollChild=child end
 function obj:SetVerticalScroll(v) self.verticalScroll=v end
 function obj:GetVerticalScroll() return self.verticalScroll or 0 end
 function obj:GetNormalTexture() return self.normal end
 function obj:GetPushedTexture() return self.pushed end
 function obj:SetSize(w,h) self.width,self.height=w,h end
 function obj:SetWidth(w) self.width=w end
 function obj:SetHeight(h) self.height=h end
 function obj:GetWidth() return self.width or 1920 end
 function obj:GetHeight() return self.height or 1080 end
 function obj:StartSizing(where) self.started=where end
 function obj:StopMovingOrSizing() self.stopped=true end
 function obj:Show() self.shown=true end
 function obj:Hide() self.shown=false;if self.scripts.OnHide then self.scripts.OnHide() end end
 function obj:IsShown() return self.shown end
 function obj:SetShown(v) self.shown=v end
 function obj:SetTexture(t) self.texture=t end
 function obj:CreateTexture() return object() end
 function obj:CreateFontString() return object() end
 function obj:SetText(t) self.text=t;if self.scripts.OnTextChanged then self.scripts.OnTextChanged() end end
 function obj:GetText() return self.text or "" end
 function obj:SetScript(k,fn) self.scripts[k]=fn end
 function obj:RegisterEvent(e) self.events[e]=true end
 return obj
end
local frames={}
function CreateFrame(kind,name,parent,template)
 local o=object();o.kind,o.parent,o.template=kind,parent,template
 frames[#frames+1]=o
 if name then env[name]=o;_G[name]=o end
 return o
end
UIParent=object();UISpecialFrames={}
WorldMapFrame=object();WorldMapFrame:Hide();WorldMapFrame:SetFrameStrata("HIGH")
function WorldMapFrame:GetFrameStrata() return self.strata end
function WorldMapFrame:SetMapID(id) openToMap=id end
function WorldMapFrame:Show() self.shown=true;requests=true end
function WorldMapFrame:Raise() self.raised=true end
done[101]=false;playerLevel=20
AT.ToggleLevelGuide()
local g=assert(env.NQTLevelGuide)
assert(g:IsShown() and g.heroName.text=="Westfall")
assert(g.heroTop.text=="" and g.headerSub.text:find("Level 20",1,true))
assert(g.inQuestLog:GetChecked() and g.hideHeld)
assert(g.badges[1].label.text=="2 Kill" and g.heroFact.text:find("3 quests",1,true))
for _,row in ipairs(g.quests) do
    assert(not row.record or row.record.status~="In log" and row.record.status~="Turn in")
end
g.inQuestLog:SetChecked(false);g.inQuestLog.scripts.OnClick(g.inQuestLog)
assert(not g.hideHeld and AT.char.levelGuideHideHeld==false)
assert(g.badges[1].label.text=="4 Kill" and g.heroFact.text:find("6 quests",1,true))
assert(math.abs(g.art:GetWidth()/g.canvas:GetWidth()-.50)<.03 and g.art:GetHeight()>300)
assert(g.badges[1]:GetWidth()>=77 and g.badges[1]:GetHeight()==28 and not g.badges[1].indicator and not g.badges[1].bar)
assert(g.quests[1].mouseWheel and not g.quests[1].wheelPropagates and g.areas[1].mouseWheel and not g.areas[1].wheelPropagates)
assert(not g.art.wheelPropagates and not g.objectives.scroll.wheelPropagates)
assert(not g.npcMenu:IsShown() and #g.npcChecks==15)
for _,c in ipairs(g.npcChecks) do assert(not c:GetChecked()) end
AT.LevelGuideNPCServices={[1436]={{3,1,.4,.5,"Test repair"},{3,2,.2,.6,"Other faction repair"}}}
g.npcButton.scripts.OnClick();assert(g.npcMenu:IsShown())
g.npcChecks[3]:SetChecked(true);g.npcChecks[3].scripts.OnClick(g.npcChecks[3]);assert(#g.art.services==1 and g.art.serviceMarks[1].shown)
assert(g.npcCheckLabels[3].text=="Repair (1)" and g.art.serviceStatus.text=="1 NPC icon")
assert(g.art.serviceMarks[1]:GetFrameLevel()>g.art:GetFrameLevel()+4)
g.npcChecks[3]:SetChecked(false);g.npcChecks[3].scripts.OnClick(g.npcChecks[3]);assert(#g.art.services==0 and not g.art.serviceMarks[1].shown)
g.npcChecks[15]:SetChecked(true);g.npcChecks[15].scripts.OnClick(g.npcChecks[15]);assert(g.art.serviceStatus.text=="No enabled NPC services recorded here")
g.npcChecks[15]:SetChecked(false);g.npcChecks[15].scripts.OnClick(g.npcChecks[15])
g.npcButton.scripts.OnClick()
g.badges[1].scripts.OnClick()
assert(g.questKind=="kill" and g.heroName.text=="Westfall" and g.heroFact.text:find("4 matching",1,true))
for _,row in ipairs(g.quests) do if row.record then assert(row.record.kind=="kill") end end
g.badges[1].scripts.OnClick()
assert(not g.questKind and g.heroFact.text:find("6 quests",1,true))
assert(g.art.startMarks[1] and g.art.startMarks[1].shown)
assert(#g.art.tiles==4 and not g.art.fallback.shown and g.art.tiles[2].texture==9 and not openToMap)
local detail=g.art.tiles[4]
assert(detail.shown and detail.texture==1002 and detail.sublevel==1
    and math.abs(detail.texCoord[2]-50/64)<.0001 and math.abs(detail.texCoord[4]-130/256)<.0001
    and g.art.tiles[2].sublevel==0,"unexplored detail is painted above native terrain with cropped edge UVs")
local giverRow
for _,row in ipairs(g.quests) do if row.record and row.record.id==101 then giverRow=row end end
assert(giverRow and giverRow.waypoint.shown and giverRow.detail.text:find("Giver of Westfall",1,true))
assert(giverRow.detail.text:find("Westfall 45.0, 72.0",1,true))
giverRow.scripts.OnClick(giverRow,"LeftButton")
assert(g.selectedQuest==101 and g.art.pin.shown and not activeWaypoint and not AT.GetLevelGuideRoutePoint())
assert(g.objectives.shown and g.objectives.title.text=="Westfall cull" and g.objectives.rows[1].text.text=="Kills: 0/8")
assert(g.objectives.start.text:find("Giver of Westfall  |  Westfall 45.0, 72.0",1,true))
AT.QuestMobData={creatures={[500]={"Gnoll Scout",2,3,"normal",435}}}
SetPortraitTextureFromCreatureDisplayID=function(texture,id) texture.display=id end
C_Item={GetItemNameByID=function(id) if id==111 then return "Acorns" end end,GetItemIconByID=function(id) if id==111 then return 133999 end end}
g.scripts.OnEvent(g,"QUEST_LOG_UPDATE")
assert(g.objectives.rows[1].icon.display==435 and g.objectives.rows[1].text.text=="Gnoll Scout: 0/8")
local itemRows,live=AT.GetLevelGuideObjectiveRows(115)
assert(live and itemRows[1].text=="Acorns: 2/7" and itemRows[1].icon==133999 and itemRows[2].kind=="other")
local pickup,offLog=AT.GetLevelGuideObjectiveRows(102)
assert(not offLog and pickup[1].text=="Acorns: 0/8" and pickup[1].icon==133999)
assert(giverRow.waypoint.caption.text=="Track")
assert(g.art.pin.shown and g.art.pin.marker:GetWidth()==12 and g.art.pin.ring)
local pointer=g.art.pin
pointer.scripts.OnUpdate(pointer,1.1);assert(pointer.marker.alpha<.35 and pointer.ring.alpha>=.68)
pointer.scripts.OnUpdate(pointer,1.1);assert(pointer.marker.alpha>.95 and pointer.marker:GetWidth()==12)

local native,nativeText=AT.GetLevelGuideObjectiveText(115)
assert(nativeText and native=="Acorns: 2/7\nRescue trapped guards: 0/2")
local beforeWidth=g.art.mapGeometry.w
g.art.zoomIn.scripts.OnClick(g.art.zoomIn)
assert(g.art.zoom>1 and g.art.mapGeometry.w>beforeWidth and g.art.pin.shown)
g.art.scripts.OnMouseWheel(g.art,3)
assert(g.art.zoom>2 and g.art.pin.shown)
for _,tile in ipairs(g.art.tiles) do
    if tile.shown then assert(tile:GetWidth()<=g.art:GetWidth() and tile:GetHeight()<=g.art:GetHeight()) end
end
g.art.scripts.OnMouseWheel(g.art,-20)
assert(g.art.zoom==1 and g.art.mapGeometry.w==beforeWidth)
giverRow.waypoint.scripts.OnClick()
assert(waypointTracked and activeWaypoint.uiMapID==1436 and AT.GetLevelGuideRoutePoint()==101)
g.scripts.OnEvent(g,"QUEST_ACCEPTED",5,101)
assert(not activeWaypoint and not AT.GetLevelGuideRoutePoint() and g.art.pin.shown)
g.mapButton.scripts.OnClick(g.mapButton)
assert(openToMap==1436 and requests and WorldMapFrame.raised and g.strata=="LOW")
WorldMapFrame:Hide();assert(g.strata=="FULLSCREEN_DIALOG")
C_Map.GetMapArtID=function() return 1 end
g.art.artKey=nil
g.scripts.OnEvent(g,"QUEST_LOG_UPDATE")
assert(not detail.shown,"stale detail must hide when a map has no compatible art ID")
C_Map.GetMapArtID=function() return 7000 end
g.art.artKey=nil
g.scripts.OnEvent(g,"QUEST_LOG_UPDATE")
assert(g.partyChoice.caption.text=="Solo")
assert(not g.partyMenu:IsShown());g.partyChoice.scripts.OnClick();assert(g.partyMenu:IsShown())
g.group[3].scripts.OnClick(g.group[3]);assert(not g.partyMenu:IsShown())
assert(g.size==3 and AT.char.levelGuidePartySize==3)
g.tabs.dungeons.scripts.OnClick()
g.search:SetText("Deadmines")
assert(g.quests[1].shown and g.quests[1].name.text:find("Deadmines passage",1,true) and not g.quests[2].shown)
assert(g.areas[1].index.text=="")
assert(g.quests[1].waypoint.shown and g.quests[1].detail.text:find("Outside Dungeon Giver",1,true))
g.quests[1].scripts.OnClick(g.quests[1],"LeftButton")
assert(g.art.pin.shown and g.art.destination.map==1436 and not activeWaypoint)
assert(g.objectives.start.text:find("Outside Dungeon Giver  |  Westfall 31.0, 42.0",1,true))
local savedGiver=AT.LevelGuideQuestGivers[109];AT.LevelGuideQuestGivers[109]=nil
_G.ForeverDungeonJournal_NS={QUEST_START_MAPS={[109]={mapID=1436,x=.32,y=.43,label="Journal Giver - Westfall"}},ARROW_NPC_IDS={["Journal Giver"]=84}}
g.scripts.OnEvent(g,"QUEST_LOG_UPDATE")
assert(g.quests[1].detail.text:find("Journal Giver",1,true) and g.objectives.start.text:find("Westfall 32.0, 43.0",1,true))
AT.LevelGuideQuestGivers[109]=savedGiver;_G.ForeverDungeonJournal_NS=nil
g.scripts.OnEvent(g,"QUEST_LOG_UPDATE")
g.quests[1].waypoint.scripts.OnClick()
local qid,giverMap=AT.GetLevelGuideRoutePoint()
assert(qid==109 and giverMap==1436)
g.quests[1].waypoint.scripts.OnClick()
assert(not activeWaypoint)
-- Item route without a fake exact waypoint. Current and browsing modes use the same start data.
AT.LevelGuideItemStarts={[109]={30001,{{1436,.4,.55,.08,1,501,"Crate Raider"},{1436,.62,.60,.05,1,501,"Crate Raider"},{1433,.55,.50,.04,1,501,"Crate Raider"}}}}
local original=AT.LevelGuideQuestGivers[109];AT.LevelGuideQuestGivers[109]=nil
g.scripts.OnEvent(g,"QUEST_LOG_UPDATE")
local q=g.quests[1]
assert(q.record.giver.pickup and q.waypoint.shown and q.detail.text:find("Crate Raider",1,true))
q.scripts.OnClick(q,"LeftButton")
local areaOnSelection=false;for _,circle in pairs(g.art.areaRing) do if circle.shown then areaOnSelection=true end end
assert(areaOnSelection and g.art.destination.pickup and not AT.GetLevelGuideRoutePoint(),"selecting an item-start quest highlights its area without Track")
assert(#g.art.destination.areas==2 and g.art.areaRing[55].shown,"show separate pickups on the selected map, not the other map")
q.waypoint.scripts.OnClick()
assert(g.art.destination.pickup and g.art.pin.shown and not activeWaypoint and not AT.GetLevelGuideRoutePoint())
local dots=0;for _,d in pairs(g.art.areaRing) do if d.shown then dots=dots+1 end end
assert(dots>=16 and q.waypoint.caption.text=="Stop")
q.waypoint.scripts.OnClick()
assert(q.waypoint.caption.text=="Track")
AT.LevelGuideItemStarts[109]={30001,{}}
g.scripts.OnEvent(g,"QUEST_LOG_UPDATE")
assert(not g.quests[1].waypoint.shown and g.quests[1].detail.text:find("Starts with item #30001",1,true))
assert(not g.art.pin.shown)
AT.LevelGuideQuestGivers[109]=original
AT.LevelGuideItemStarts=nil
local rawNoArea=AT.ForeverLevelGuideQuests[118]
AT.ForeverLevelGuideQuests[118]=levelRecord(20,0,"Unclassified item quest",{{2,30002,1}})
AT.LevelGuideItemStarts={[118]={30002,{{1436,.4,.55,.08,2,601,"Loot barrel"}}}}
local function found(id,name)
    for _,v in ipairs(place(AT.BuildLevelGuide(),name).quests) do if v.id==id then return v end end
end
assert(found(118,"Westfall").giver.pickup,"an item quest missing zone metadata must remain discoverable in its one observed start zone")
AT.LevelGuideItemStarts[118][2][2]={1433,.4,.55,.08,2,602,"Alternate loot barrel"}
assert(not found(118,"Westfall"),"cannot put an uncategorized quest into an arbitrary zone on a multi-zone item")
AT.ForeverLevelGuideQuests[118]=levelRecord(20,40,"Neutral turn-in is not its start",{{2,30002,1}})
AT.LevelGuideItemStarts=nil
AT.ForeverVerifiedEndpointReferences={[118]={{1436,.45,.55,1,602,0,"Only Accepts Turn-in"}}}
local turnIn=found(118,"Westfall")
assert(turnIn and not turnIn.giver,"neutral turn-ins are not Alliance quest starts")
AT.ForeverVerifiedEndpointReferences=nil
AT.ForeverLevelGuideQuests[118]=rawNoArea
g.search:SetText("Drowned City")
assert(g.heroName.text=="The Drowned City")
g.high:SetText("18");assert(g.heroName.text=="No matching areas")
g.high:SetText("")
g.tabs.zones.scripts.OnClick()
g.search:SetText("redridge")
assert(g.heroName.text=="Redridge Mountains")
g.tabs.forYou.scripts.OnClick()
playerLevel=25;done[101]=true;g.scripts.OnEvent(g,"PLAYER_LEVEL_UP")
assert(g.headerSub.text:find("Level 25",1,true))
local last=place(g.result,"Redridge Mountains");assert(last.count==5)
local before=g.questLimit
g.grip.scripts.OnMouseDown(g.grip,"LeftButton");assert(g.started=="BOTTOMRIGHT")
g:SetSize(1100,800);g.scripts.OnSizeChanged()
g.grip.scripts.OnMouseUp(g.grip,"LeftButton")
assert(g.stopped and AT.char.levelGuideWidth==1100 and AT.char.levelGuideHeight==800 and g.contentZoom>1.03 and g.canvas:GetWidth()<1100)
local maximize=g.maximizeButton
local mast
for _,f in ipairs(frames) do if f.parent==g.canvas and f.scripts.OnDragStart then mast=f end end
assert(mast and mast.mouseEnabled and maximize.mouseEnabled)
assert(maximize:GetWidth()==g.closeButton:GetWidth() and maximize:GetHeight()==g.closeButton:GetHeight() and maximize.clicks[1]=="LeftButtonUp")
assert(g.inQuestLog.point[2]<g.scaleButton.point[2] and g.scaleButton.point[2]<g.partyChoice.point[2])
assert(g.scaleButton:GetWidth()==g.partyChoice:GetWidth() and g.scaleButton:GetHeight()==g.partyChoice:GetHeight())
assert(maximize:GetFrameLevel()>mast:GetFrameLevel(),"drag surface must not intercept the click")
assert(maximize.point[2].template=="UIPanelCloseButton" and maximize.point[2]:GetFrameLevel()==maximize:GetFrameLevel())
assert(maximize.normal.texture:find("LevelGuideWindowControls",1,true) and maximize.normal.texCoord[1]==0)
local function clickTitleControl()
    local target=maximize:GetFrameLevel()>mast:GetFrameLevel() and maximize or mast
    assert(target.scripts.OnClick)
    target.scripts.OnClick(target,"LeftButton")
end
clickTitleControl()
assert(maximize.normal.texCoord[1]==.25)
assert(not g.scaleMenu:IsShown() and g.scaleSlider.value==100 and g.scaleSlider.minimum==70 and g.scaleSlider.maximum==160)
g.scaleButton.scripts.OnClick()
assert(g.scaleMenu:IsShown() and not g.partyMenu:IsShown() and g.scaleMenu.parent==g and g.scaleButton.caption.text=="Scale")
local sliderWidth=g.scaleSlider:GetWidth()
local menuPoint=g.scaleMenu.point
local normalZoom=g.contentZoom
g.scaleSlider:SetValue(80)
assert(g.contentZoom<normalZoom and AT.char.levelGuideScale==80 and g.scaleLabel.text=="80%")
g.scaleSlider:SetValue(70)
assert(g.areaLimit>20 and g.questLimit==20,"minimum scale shows 20 rows")
assert(g.scaleSlider:GetWidth()==sliderWidth and g.scaleMenu.point==menuPoint,"slider geometry must not follow canvas scale")
g.scaleSlider:SetValue(160)
assert(g.contentZoom>normalZoom and g.areaLimit>g.questLimit and g.questLimit<=10)
g.scaleSlider:SetValue(100)
g.tabs.zones.scripts.OnClick()
assert(g.areaLimit>g.questLimit and g.questLimit==10,"100% shows ten rows with the zone search toolbar present")
assert(g.areas[1].point[4]+g.areas[1]:GetWidth()<g.art.point[4] and g.art.point[4]+g.art:GetWidth()<g.quests[1].point[4])
assert(g.objectives.point[4]==g.quests[1].point[4] and g.objectives.point[5]<g.quests[g.questLimit].point[5])
local railW=g.areaPanel:GetWidth()+g.art:GetWidth()+g.questPanel:GetWidth()
assert(math.abs(g.areaPanel:GetWidth()/railW-.20)<.006 and math.abs(g.art:GetWidth()/railW-.52)<.006 and math.abs(g.questPanel:GetWidth()/railW-.28)<.006)
assert(g.areaPanel.point[5]==g.art.point[5] and g.areaPanel:GetHeight()==g.art:GetHeight())
assert(g.questPanel.point[5]==g.art.point[5] and math.abs(g.questPanel:GetHeight()/(g.questPanel:GetHeight()+g.objectives:GetHeight())-.70)<.006)
assert(g.objectives.point[5]-g.objectives:GetHeight()==g.art.point[5]-g.art:GetHeight())
assert(g.objectives.shown and g.objectives.empty.shown and not g.objectives.scroll.shown)
assert(g.areaTitle.text=="Location" and g.questTitle.text=="Quests")
assert(g.quests[1].point[5]-g.quests[2].point[5]>=32)
g.tabs.forYou.scripts.OnClick()
g.scaleSlider:SetValue(100)
g.scaleButton.scripts.OnClick()
assert(not g.scaleMenu:IsShown())
local qp=g.questOffset
 g.quests[1].scripts.OnMouseWheel(g.quests[1],-1)
 assert(g.questOffset>=qp)
 assert(not g.areaPrev and not g.areaNext and not g.questPrev and not g.questNext and not g.areaPages and not g.questPages)
 assert(g.areaSurface:GetHeight()==g.areaPanel:GetHeight())
assert(g.areaLimit>g.questLimit and g.questLimit==10 and g.areas[1].point[4]<g.quests[1].point[4]
   and g.areas[1].point[5]==g.quests[1].point[5] and g.detailsHeight>=104)
assert(g.maximized and not g.grip.shown and g:GetWidth()==1912 and g:GetHeight()==1072 and g.contentZoom>1.38)
clickTitleControl()
assert(maximize.normal.texCoord[1]==0)
assert(not g.maximized and g.grip.shown and g:GetWidth()==1100 and g:GetHeight()==800)
assert(AT.char.levelGuideWidth==1100 and AT.char.levelGuideHeight==800)
g.scripts.OnEvent(g,"QUEST_TURNED_IN",115)
assert(AT.char.levelGuideTurnIns[115] and place(g.result,"Westfall").count==2)
g.scaleSlider:SetValue(125)
AT.ToggleLevelGuide();assert(not g:IsShown() and not g.scaleMenu:IsShown())
assert(loadfile("NQT/LevelGuide.lua"))("NQT",AT)
AT.ToggleLevelGuide()
assert(env.NQTLevelGuide:GetWidth()==1100 and env.NQTLevelGuide:GetHeight()==800 and not env.NQTLevelGuide.inQuestLog:GetChecked())
assert(env.NQTLevelGuide.scaleSlider.value==125 and AT.char.levelGuideScale==125,"interface scale survives guide recreation")
assert(UISpecialFrames[1]=="NQTLevelGuide")
print("PASS compact tabs and lists; ten-plus maximized rows; wheel capture; stock map in front; opt-in service pins")
print("PASS illustrated window: launch, real map tiles, selection, filters, group toggle, level event, and close")

local real={}
assert(loadfile("NQT/LevelGuideData.lua"))("NQT",real)
assert(loadfile("NQT/LevelGuideGivers.lua"))("NQT",real)
assert(real.LevelGuideItemStarts[2][1]==16305 and real.LevelGuideItemStarts[2][2][1][7]=="Sharptalon")
assert(real.LevelGuideItemStarts[2][2][1][1]==1440 and next(real.LevelGuideNPCServices))
for id,expect in pairs({[819]={4926,1413,3238},[2978]={9370,1444,143980},[4722]={12289,1439,176189},[4728]={12242,1439,175207},[4730]={12242,1439,175207},[4732]={12289,1439,176189},[4733]={12242,1439,175207}}) do
    local item=real.LevelGuideItemStarts[id];local first=item[2][1]
    assert(item[1]==expect[1] and first[1]==expect[2] and first[5]==2 and first[6]==expect[3]
        and first[2]>0 and first[2]<1 and first[3]>0 and first[3]<1 and first[4]>0)
end
assert(#real.LevelGuideItemStarts[819][2]==3,"do not average separated keg spawn areas into a fictitious center")
assert(real.LevelGuideItemStarts[551][2][1][6]==1765 and not real.LevelGuideItemStarts[554],
    "a recovery item is not a second quest starter")
for _,pair in ipairs({{94973,267137},{94980,267138}}) do
    local r=real.LevelGuideItemStarts[pair[1]]
    assert(r[1]==pair[2] and r[2][1][6]==259256 and r[2][1][1]==0)
end
for id,expected in pairs({[95385]={217161,1434,1564,4},[95534]={213421,1416,2319,1},[95884]={271343,1421,1973,2}}) do
    local r=real.LevelGuideItemStarts[id]
    assert(r[1]==expected[1] and r[2][1][1]==expected[2] and r[2][1][6]==expected[3] and #r[2]==expected[4])
end
assert(real.LevelGuideItemStarts[97288][2][1][1]==0,"a dungeon boss source without a map observation must not acquire a guessed floor")
assert(real.LevelGuideQuestGivers[97290][1][5]==271613,"part three must retain its directly recorded quest giver")
assert(loadfile("NQT/DungeonCatalog.lua"))("NQT",real)
local count=0
for id,r in pairs(real.ForeverLevelGuideQuests) do
    assert(type(r[9])=="string" and r[2]>0 and r[1]>=0)
    count=count+1
end
assert(count==5600 and real.ForeverLevelGuideQuests[96393][9]=="Old Ironforge Incursion")
assert(real.ForeverDungeonForQuest(95789)=="The Drowned City")
print("PASS standalone catalog: 5,600 quest records; named Forever dungeon reference")

assert(loadfile("NQT/LevelGuide.lua"))("NQT",real)
local offline=real.BuildLevelGuide(36,1)
local drowned=place(offline,"The Drowned City")
assert(drowned.leads>=3 and drowned.count==0)
for _,q in ipairs(drowned.quests) do
    assert(real.ForeverDungeonForQuest(q.id)=="The Drowned City")
end
local routes=real.FilterLevelGuide(offline,"forYou")
assert(#routes>8 and routes[1].total>=8 and routes[1].leads>0,
    "a standalone, empty-log character must see and rank full-catalog options")
print("PASS real catalog with no active quests or Questie: ranked zones, eligible dungeon coverage, and strict membership")
assert(real.IsForeverOutdoorQuest(93604)==true)
local razorfen=place(real.BuildLevelGuide(43,1),"Razorfen Downs")
for _,q in ipairs(razorfen.quests) do assert(q.id~=93604) end
for _,qid in ipairs({94617,99257}) do
    local d=real.ForeverLevelGuideQuests[qid]
    local soloScore=real.ScoreLevelGuideQuest(qid,d,40,1,{status="In range"})
    local partyScore=real.ScoreLevelGuideQuest(qid,d,40,3,{status="In range"})
    assert(soloScore.kind=="collect" and partyScore.kind=="collect" and partyScore.work<soloScore.work)
end
assert(real.ScoreLevelGuideQuest(1878,real.ForeverLevelGuideQuests[1878],44,1,{status="Pick up"}).potential==0)
assert(real.ScoreLevelGuideQuest(1707,real.ForeverLevelGuideQuests[1707],44,1,{status="Pick up"}).potential>0)
print("PASS Blizzard hotfix cases: outdoor quest, exact shared-loot items, exact zero-XP repeatable")
assert(loadfile("NQT/LevelGuideGivers.lua"))("NQT",real)
local n=0
for _,rows in pairs(real.LevelGuideQuestGivers) do
    n=n+1;assert(#rows>0 and rows[1][1]>0 and type(rows[1][6])=="string")
end
assert(n>=1900)
-- Alternates match on identity, not just name. Native trivial status also overrides levels.
AT.ForeverLevelGuideQuests[121]=levelRecord(25,40,"Westfall cull",{{1,500,14}})
AT.ForeverLevelGuideQuests[122]=levelRecord(22,40,"Westfall cull",{{1,505,14}})
AT.ForeverLevelGuideQuests[123]=levelRecord(20,40,"Gray by client",{{1,507,2}})
AT.ForeverLevelGuideQuests[124]=levelRecord(20,40,"Wrong faction native offer",{{1,508,2}},1,"aa2aaaaa4e0ab3b2")
playerLevel,done[101]=20,false
offers[1436][#offers[1436]+1]=124
C_QuestLog.IsQuestTrivial=function(id) return id==123 end
assert(loadfile("NQT/LevelGuide.lua"))("NQT",AT)
local w=place(AT.BuildLevelGuide(20,1),"Westfall")
local seen={}
for _,q in ipairs(w.quests) do seen[q.id]=q end
assert(seen[101] and not seen[121] and seen[122] and seen[123] and not seen[123].fits and not seen[123].availableHere and not seen[124])
print("PASS giver data, native tracking lifecycle, alternate-level dedup, faction and native gray filtering")
names[1453]="Stormwind City"
local savedGivers=AT.LevelGuideQuestGivers
AT.LevelGuideQuestGivers={[117]={{1453,.5,.6,1,711,"Stormwind Quest Giver",0}}}
local stock=place(AT.BuildLevelGuide(24,1),"Stockade")
assert(stock.quests[1].giver.name=="Stormwind Quest Giver" and stock.quests[1].giver.map==1453)
AT.LevelGuideQuestGivers[117][2]={1453,.3,.2,1,712,"Different Quest Giver",0}
local other=place(AT.BuildLevelGuide(24,1),"Stockade").quests[1].giver
assert(not other or other.name~="Stormwind Quest Giver","ambiguous bundled giver is not chosen")
AT.LevelGuideQuestGivers=savedGivers
print("PASS half-window map, click filters, outdoor dungeon starter waypoint, and bundled giver ambiguity guard")
assert(loadfile("NQT/LevelGuideZoneRanges.lua"))("NQT",real)
assert(loadfile("NQT/LevelGuideObjectiveText.lua"))("NQT",real)
local imported=0
for _ in pairs(real.LevelGuideZoneRanges) do imported=imported+1 end
assert(imported==42 and real.LevelGuideZoneRanges[2548][1]==35 and real.LevelGuideZoneRanges[2548][2]==45)
local river=place(real.BuildLevelGuide(36,1),"Riverglades")
assert(river.rangeKnown and river.lo==35 and river.hi==45)
local previousFaction,previousRace=UnitFactionGroup,UnitRace
UnitFactionGroup=function() return "Horde" end
UnitRace=function() return "Orc","Orc",2 end
local hordeRiver=place(real.BuildLevelGuide(45,1),"Riverglades")
local report
for _,q in ipairs(hordeRiver.quests) do if q.id==93971 then report=q end end
assert(report and report.giver.pickup and report.giver.map==2548 and report.giver.source==257079)
assert(#report.giver.areas==2 and report.giver.areas[1].x==0.57 and report.giver.areas[2].y==0.75)
assert(real.TrackLevelGuideGiver(report) and not real.GetLevelGuideRoutePoint(),
    "patrol areas must not become precise GPS destinations")
assert(real.TrackLevelGuideGiver(report))
UnitFactionGroup,UnitRace=previousFaction,previousRace
local interaction,liveInteraction=real.GetLevelGuideObjectiveRows(553)
assert(not liveInteraction)
local flames={}
for _,r in ipairs(interaction) do
 if r.kind=="other" then flames[r.text]=true end
end
assert(flames["Flame of Azel charged: 0/1"] and flames["Flame of Veraz charged: 0/1"] and flames["Flame of Uzel charged: 0/1"])
local oldLocale=GetLocale
GetLocale=function()return "deDE" end
local translated=real.GetLevelGuideObjectiveText(553) or ""
assert(not translated:find("Flame of Azel charged",1,true))
GetLocale=oldLocale
local oldObjectives=C_QuestLog.GetQuestObjectives
C_QuestLog.GetQuestObjectives=function(q)
 if q==553 then return {{type="object",text="Flame of Azel charged: 1/1",finished=true}} end
 return oldObjectives(q)
end
local activeQuest,liveQuest=real.GetLevelGuideObjectiveRows(553)
assert(liveQuest and #activeQuest==1 and activeQuest[1].done and activeQuest[1].text=="Flame of Azel charged: 1/1")
C_QuestLog.GetQuestObjectives=oldObjectives
local full=real.GetLevelGuideObjectiveText(387)
assert(full:find("0/10",1,true) and full:find("0/8",1,true) and #full>40)
print("PASS OpenMap independent zone ranges; bundled unheld counts and authentic live objective lines")

-- Exercise visible markers with real Riverglades records rather than just test fixtures.
local mockLayer=C_Map.GetMapArtLayers
C_Map.GetMapArtLayers=function(id) return mockLayer(id==2548 and 1436 or id) end
names[2548]="Riverglades"
local originalFaction=UnitFactionGroup
UnitFactionGroup=function() return "Alliance" end
playerLevel=41
real.ToggleLevelGuide()
local rv=assert(env.NQTLevelGuide)
rv.tabs.zones.scripts.OnClick();rv.search:SetText("Riverglades")
assert(rv.mapHeading.text:find("Riverglades",1,true))
for _,kind in ipairs({1,2,3}) do local box=rv.npcChecks[kind];box:SetChecked(true);box.scripts.OnClick(box) end
local rendered={}
for _,mark in pairs(rv.art.serviceMarks) do if mark.shown then rendered[mark.service.name]=true end end
assert(rendered["Gretchen Mayberry"] and rendered["Innkeeper Zizplink"] and not rendered["Grakna"])
assert(rv.art.serviceStatus.shown and #rv.art.services>=3)
UnitFactionGroup=originalFaction
print("PASS real Riverglades service pins: Alliance flight path, neutral inn, no Horde path, category coverage and status")

rv.search:SetText("")
assert(rv.areas[2].place)
local nextPlace=rv.areas[2].place.id
rv.areaSurface.scripts.OnMouseWheel(rv.areaSurface,-1)
assert(rv.areas[1].place.id==nextPlace,"Location wheel should move one row")
local samplePlace=place(rv.result,"Riverglades")
for idx=1,24 do
  samplePlace.quests[idx]={id=600000+idx,name="Fixture quest "..idx,kind="kill",min=35,potential=1,efficiency=1,fits=true,availableHere=true,status="In range"}
end
rv.search:SetText("Riverglades")
assert(rv.quests[2].record)
local nextQuest=rv.quests[2].record.id
rv.questSurface.scripts.OnMouseWheel(rv.questSurface,-1)
assert(rv.quests[1].record.id==nextQuest,"Quest wheel should move one row")
print("PASS independent one-row scroll in both full-height guide lists")

-- Cross-lane check: each exact starter has a map area, including sourced dungeon floor data.
for id, expected in pairs({[123]={1307,1429,478},[136]={1357,1436,515},[184]={1972,1429,474},[361]={2839,1420,1523},[594]={4098,1434,2560},[830]={4881,1411,3239},[4881]={12564,1441,10617},[78823]={211269,1418,2893},[87494]={280459,1449,9162},[91741]={247834,1429,6},[93568]={259461,2652,255207},[93574]={259893,2652,253394},[93644]={260347,2652,11559},[94885]={266427,2548,256798},[95328]={268812,1420,260396},[95384]={213127,1434,780},[96294]={273658,1412,264082},[97236]={277190,1438,1994},[97281]={277661,1411,3118},[98424]={281031,1412,3051}}) do
    local row=assert(real.LevelGuideItemStarts[id])
    local spot=row[2][1]
    assert(row[1]==expected[1] and spot[1]==expected[2] and spot[6]==expected[3] and spot[4]>0 and spot[7]~="")
end
assert(real.LevelGuideItemStarts[830][1]==4881 and real.LevelGuideItemStarts[830][2][1][5]==2)
assert(real.LevelGuideItemStarts[86613][1]==278049 and real.LevelGuideItemStarts[86613][2][1][1]==1432)
local damp=assert(real.LevelGuideItemStarts[6564])
assert(damp[1]==16790 and damp[2][1][1]==1440 and damp[2][1][6]==4802 and damp[2][1][4]>0)
for q,i in pairs({[95189]=268579,[95204]=275521}) do
    local a=assert(real.LevelGuideItemStarts[q])
    assert(a[1]==i and a[2][1][1]==0 and a[2][1][5]==2 and a[2][1][8]=="Ruins of Lordaeron")
    assert(not real.TrackLevelGuideGiver({id=q,giver={pickup=true,map=0,x=0,y=0}}),"no invented pin from room text")
end
local rg=place(real.BuildLevelGuide(40,1),"Riverglades")
local log
for _,row in ipairs(rg.quests) do if row.id==94885 then log=row end end
assert(log and log.giver.pickup and log.giver.sourceName=="Twilight Neophyte")
assert(real.TrackLevelGuideGiver(log) and not real.GetLevelGuideRoutePoint())
for quest,item in pairs({[178]=1962,[637]=4433,[781]=4851,[95816]=270888,[95819]=270887}) do
    local packed=real.LevelGuideItemStarts[quest]
    assert(packed[1]==item,"exact quest-starting item")
    if quest==178 then assert(#packed[2]==2 and packed[2][1][6]==434 and packed[2][2][6]==579,"two exact Redridge creatures")
    else assert(#packed[2]==1 and packed[2][1][4]>0,"real pickup area") end
end
print("PASS exact Forever starter areas, including chest, dungeon, corrected starter items and real Riverglades tracking")
do
    local initialSide,initialLocale=UnitFactionGroup,GetLocale
    GetLocale=function() return "enUS" end
    UnitFactionGroup=function() return "Alliance" end
    assert(real.GetShareQuestStart(637,1417):find("Waterlogged Letter",1,true))
    assert(real.GetShareQuestStart(95816,1433):find("Tamelyn Aldridge",1,true))
    assert(not real.GetShareQuestStart(95819,1413):find("Gishah",1,true))
    assert(real.GetShareQuestStart(178,1433):find("Near Stonewatch Keep",1,true))
    UnitFactionGroup=function() return "Horde" end
    assert(real.GetShareQuestStart(781,1412):find("Brambleblade Ravine",1,true))
    assert(real.GetShareQuestStart(95819,1413):find("Gishah",1,true))
    assert(not real.GetShareQuestStart(178,1433):find("Shadowhide",1,true))
    assert(not real.GetShareQuestStart(95816,1433):find("Tamelyn Aldridge",1,true))
    assert(real.GetShareQuestStart(95820,1413):find("Jornah",1,true))
    assert(real.GetShareQuestStart(95821,1454):find("Karolek",1,true))
    assert(not (real.GetShareQuestStart(95818,1455) or ""):find("Rotgath",1,true))
    UnitFactionGroup=function() return "Alliance" end
    assert(real.GetShareQuestStart(95818,1455):find("Rotgath Stonebeard",1,true))
    assert(not (real.GetShareQuestStart(95821,1454) or ""):find("Karolek",1,true))
    assert(not real.LevelGuideQuestGivers[95817],"do not pin conflicting Elaine locations")
    UnitFactionGroup,GetLocale=initialSide,initialLocale
    local prior=AT.LevelGuideItemStarts
    AT.LevelGuideItemStarts={[717001]={4881,{{1436,.4,.5,.035,2,3239,"Benedict's Chest","Guard tower"}}}}
    UnitFactionGroup=function() return "Alliance" end
    GetLocale=function() return "enUS" end
    assert(AT.GetShareQuestStart(101,1436)=="Starts at: Giver of Westfall  |  Westfall 45.0, 72.0")
    assert(AT.GetShareQuestStart(109,1436,"Deadmines"):find("Westfall",1,true),"outdoor giver for a dungeon quest")
    local pickup=assert(AT.GetShareQuestStart(717001,nil))
    assert(pickup:find("Benedict's Chest",1,true) and pickup:find("Guard tower",1,true) and pickup:find("Westfall",1,true))
    assert(not pickup:find("40.0",1,true),"approximate item areas must never gain exact coordinates")
    GetLocale=function() return "frFR" end
    assert(AT.GetShareQuestStart(101,1436)=="Starts at: Westfall 45.0, 72.0")
    UnitFactionGroup=function() return "Horde" end
    assert(not AT.GetShareQuestStart(101,1436))
    assert(not AT.GetShareQuestStart(999999,nil),"unknown source remains unknown")
    AT.LevelGuideItemStarts,UnitFactionGroup,GetLocale=prior,initialSide,initialLocale
    print("PASS Share Verify source lookup: exact giver, outdoor dungeon start, approximate item area, faction and locale")
end
