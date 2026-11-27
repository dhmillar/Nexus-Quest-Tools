local AT={db={enabled=true,showQuestMapPins=true,showObservedQuestGivers=false}}
local hidden={}
function issecretvalue(v)return v==hidden end
local map, faction, questie, instance=1433,"Alliance",false,false
local excluded,ready={[11]=true,[16]=true},{[21]=true}
local requests=0
C_QuestLine={RequestQuestLinesForMap=function() requests=requests+1 end,
 GetAvailableQuestLines=function(m) if m==1433 then return {
 {questID=12,isQuestStart=true,x=.345,y=.43,startMapID=1433},
 {questID=13,isQuestStart=true,isHidden=true,x=.33,y=.445},
 {questID=14,isQuestStart=true,x=.33,y=.415,startMapID=900},
 } end end}
local custom={
    {questID=10,isQuestStart=true,x=.29,y=.41},
    {questID=11,isQuestStart=true,x=.2,y=.2},
    {questID=20,isQuestStart=false,inProgress=true,x=.31,y=.41},
    {questID=21,isQuestStart=false,inProgress=false,x=.32,y=.41},
    {questID=22,isQuestStart=false,inProgress=false,x=.33,y=.41},
    {questID=24,isQuestStart=hidden,inProgress=false,x=.2,y=.2},
}
C_QuestLog={
 GetQuestsOnMap=function(m)return m==1433 and custom or {} end,
 GetTitleForQuestID=function(q)return "Quest "..q end,
 IsOnQuest=function(q)return q>=20 end,
 IsQuestFlaggedCompleted=function(q)return excluded[q] or false end,
 ReadyForTurnIn=function(q)return ready[q] or false end,
 GetNumQuestLogEntries=function()return 1 end,
 GetInfo=function()return {questID=23,isHeader=false}end,
 GetNextWaypointForMap=function(q,m) if q==23 and m==1433 then return .34,.41 end end
}
function UnitFactionGroup()return faction end
local function v(x,y)return {GetXY=function()return x,y end}end
C_Map={GetBestMapForUnit=function()return map end,GetMapInfo=function()return {mapType=3} end,
 GetPlayerMapPosition=function()return v(.30,.41) end,GetMapWorldSize=function()return 1000,1000 end}
C_Minimap={GetViewRadius=function()return 100 end}
C_TaxiMap={GetTaxiNodesForMap=function(m)return m==1433 and {{nodeID=91,name="Live taxi",position=v(.25,.48)}} or {} end}
C_AreaPoiInfo={GetAreaPOIForMap=function()return {300,301} end, GetAreaPOIInfo=function(_,i)
 return {atlasName=i==300 and "Poi-MeetingStone" or "poi-town",name="Named place",position=v(.44,.45)}
end}
C_AddOns={IsAddOnLoaded=function()return questie end}
function IsInInstance()return instance end
assert(loadfile("NQT/ForeverTownPins.lua"))("NQT",AT)
local known=AT.ObservedTownPins
assert(known[1433] and #known[1433]>0,"ship licensed observed service pack")
assert(AT.ObservedQuestStarts[1434] and AT.ObservedQuestTurnIns[189],"ship known starter and finisher data")
assert(AT.ObservedQuestTurnIns[98209][1][7]=="Thundris Windweaver","Bloom of the Heavens uses the verified English creature name")
AT.ObservedQuestStarts={[1433]={{15,.27,.45,1},{16,.24,.45,1},{17,.26,.40,2},{18,.88,.88,0}}}
AT.ObservedTownPins={[1433]={{1,100,1,.35,.41},{1,200,2,.36,.41},{2,500,1,.251,.478},{3,600,0,.37,.41},{4,700,1,.38,.41}}}
local frames={}
local function make(parent)
 local z={parent=parent,shown=true,evt={}}
 for _,name in ipairs({"SetSize","SetAllPoints","SetFrameLevel","SetColorTexture","SetTextColor","SetText","ClearAllPoints","EnableMouse","RegisterEvent"}) do z[name]=function()end end
 function z:CreateFontString()return make()end
 function z:CreateTexture()return make()end
 function z:SetScript(k,f) self.evt[k]=f end
 function z:SetPoint(...) self.point={...} end
 function z:GetFrameLevel()return 3 end
 function z:GetWidth()return 300 end
 function z:GetHeight()return 220 end
 function z:IsVisible()return self.shown end
 function z:IsShown()return self.shown end
 function z:SetParent(p) self.parent=p end
 function z:Show()self.shown=true end
 function z:Hide()self.shown=false end
 return z
end
function CreateFrame(_,_,parent) local f=make(parent);frames[#frames+1]=f;return f end
local canvas=make()
WorldMapFrame=make();WorldMapFrame.GetCanvas=function()return canvas end;WorldMapFrame.GetMapID=function()return map end
local nativePin={questID=10,IsShown=function()return true end}
function WorldMapFrame:EnumeratePinsByTemplate(template)
 local consume=false
 return function() if not consume and template=="QuestPinTemplate" then consume=true;return nativePin end end
end
Minimap=make()
assert(loadfile("NQT/QuestMapPins.lua"))("NQT",AT)
local function expect(list,kind,quest)
 for _,p in ipairs(list)do if p.kind==kind and (not quest or p.quest==quest) then return p end end
end
local p=AT.GetStandaloneMapPins(1433)
assert(expect(p,"start",10) and not expect(p,"start",11))
assert(expect(p,"objective",20) and expect(p,"objective",23) and not expect(p,"objective",24))
assert(expect(p,"turnin",21) and not expect(p,"turnin",22))
assert(expect(p,1).x==.35 and expect(p,2).title=="Live taxi" and expect(p,3) and expect(p,5) and not expect(p,4))
local taxis=0;for _,a in ipairs(p)do if a.kind==2 then taxis=taxis+1 end end;assert(taxis==1,"avoid observed and native flight duplicates")
faction="Horde";assert(expect(AT.GetStandaloneMapPins(1433),1).x==.36);faction="Alliance"
AT.db.showObservedQuestGivers=true
assert(expect(AT.GetStandaloneMapPins(1433),4).report=="observed")
AT.InitQuestMapPins()
local driver=frames[1]
local function tick()driver.evt.OnUpdate(driver,.4)end
tick()
local world
for _,x in ipairs(frames) do if x.parent==canvas then world=x end end
assert(world and world.shown)
local marks={}
for _,x in ipairs(frames) do
 assert(x.parent~=Minimap,"no minimap pin frames should be created")
 if x.parent==world and x.atPin and x.atPin.quest then
  marks[x.atPin.quest]=true
 end
end
assert(not marks[10],"do not duplicate an existing stock pin")
assert(marks[12] and marks[15] and marks[18] and not marks[11] and not marks[13] and not marks[14] and not marks[16] and not marks[17])
assert(requests==1)
AT.ForeverQuestFacts={[15]={40,42}}
function UnitLevel()return 20 end
AT.RefreshQuestMapPins();tick()
for _,x in ipairs(frames) do assert(not x.atPin or x.atPin.quest~=15,"hide recorded starts below the known minimum level") end
questie=true;tick();assert(world.shown,"Questie loaded must not suppress NQT world map pins")
questie=false;AT.db.showQuestMapPins=false;tick();assert(not world.shown)
AT.db.showQuestMapPins=true;tick();assert(world.shown)
WorldMapFrame.shown=false;tick();assert(not world.shown)
print("PASS world-map-only starts and service pins, zero minimap frames, native dedupe, level, faction and completion filtering")
