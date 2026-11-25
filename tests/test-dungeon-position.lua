local function object(parent)
    local o={parent=parent,shown=false,width=660,height=480,children={},regions={},scripts={},hooks={}}
    if parent then parent.children[#parent.children+1]=o end
    function o:SetPoint(...) self.anchor={...} end
    function o:SetSize(w,h) self.width,self.height=w,h end
    function o:SetHeight(v) self.height=v end
    function o:GetWidth() return self.width end
    function o:GetHeight() return self.height end
    function o:SetWidth(w) self.width=w end
    function o:SetText(t) self.text=t end
    function o:SetScript(k,f) self.scripts[k]=f end
    function o:HookScript(k,f) self.hooks[k]=f end
    function o:Show() self.shown=true;if self.hooks.OnShow then self.hooks.OnShow(self) end end
    function o:Hide() local was=self.shown;self.shown=false;if was and self.scripts.OnHide then self.scripts.OnHide(self) end;if self.hooks.OnHide then self.hooks.OnHide(self) end end
    function o:SetShown(v) self.shown=v end
    function o:IsShown() return self.shown end
    function o:GetParent() return self.parent end
    function o:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function o:GetTexture() return self.texture end
    function o:GetTextureFileID() return type(self.texture)=="number" and self.texture end
    function o:GetFrameLevel() return self.level or 2 end
    function o:SetFrameLevel(v) self.level=v end
    function o:SetTexture(v) self.texture=v;return v~="broken" end
    function o:SetTexCoord(...) self.texcoord={...} end
    function o:ClearAllPoints() self.anchor=nil end
    for _,k in ipairs({"SetAllPoints","EnableMouse","EnableMouseWheel","SetColorTexture","SetVertexColor","SetJustifyH","SetWordWrap","SetTextColor","RegisterEvent"}) do
        o[k]=function()end
    end
    local function region(self)
        local r=object();r.parent=self
        self.regions[#self.regions+1]=r
        return r
    end
    o.CreateTexture,o.CreateFontString=region,region
    return o
end

SlashCmdList={}
local all={}
function CreateFrame(kind,_,parent)
    local frame=object(parent);all[#all+1]=frame
    if kind=="UnitPositionFrame" then
        frame.kind=kind
        function frame:SetParent(parent) self.parent=parent end
        function frame:SetUiMapID(map) self.map=map end
        function frame:ClearUnits() self.units={} end
        function frame:AddUnit(unit) self.units[#self.units+1]=unit end
        function frame:FinalizeUnits() self.ready=true end
    end
    return frame
end
local AT={db={enabled=true,dungeonPositionEnabled=true,dungeonPositionAutoOpen=true},
    ForeverDungeonName=function(id) if id==2970 then return "The Drowned City" end end}
WorldMapFrame=object()
local inside=true
local name,instanceID,kind="Localised Drowned City",2970,"party"
local best={player=44,party1=44,party2=45,party3=44,party4=44}
local secret={}
function issecretvalue(v) return v==secret end
function IsInInstance() return inside,kind end
function GetInstanceInfo() return name,kind,nil,nil,nil,nil,nil,instanceID end
function UnitExists(u) return best[u]~=nil end
local queryCount=0
C_Map={
    GetBestMapForUnit=function(u) return best[u] end,
    GetMapInfo=function(m) return {name="Floor "..m,mapType=4} end,
    GetMapArtLayers=function() return {{layerWidth=1000,layerHeight=500,tileWidth=500,tileHeight=500}} end,
    GetMapArtLayerTextures=function(m) return {m*100+1,m*100+2} end,
    GetPlayerMapPosition=function(m,u)
        queryCount=queryCount+1
        assert(best[u]==m)
        if u=="party3" then return secret end
        if u=="party4" then return {GetXY=function() return secret,.9 end} end
        return {GetXY=function() if u=="player" then return .25,.75 else return .5,.5 end end}
    end,
}
function ToggleWorldMap() WorldMapFrame:Show() end
local journalLock=false
ForeverDungeonJournal_NS={
    INSTANCE_ID_TO_DUNGEON={[2970]="The Drowned City"},
    DUNGEON_MAPS={["The Drowned City"]={floors={
        {texture="Interface\\AddOns\\ForeverDungeonJournal\\Media\\DrownedCityMap",label="City",texBottom=.67},
        {texture="Interface\\AddOns\\ForeverDungeonJournal\\Media\\DrownedCityAtalByzalMap",label="Atal'Byzal",texBottom=.67},
    }}},
    IsDungeonMapLocked=function() return journalLock end,
}
local base=debug.getinfo(1,"S").source:sub(2):match("^(.*[/\\])") or "./"
assert(loadfile(base.."../NQT/DungeonPosition.lua"))("NQT",AT)
AT.InitDungeonPosition()
local panel=assert(WorldMapFrame.children[1])
local watcher=all[#all]
assert(not panel:IsShown())
WorldMapFrame:Show()
assert(panel:IsShown() and panel.floor.text=="City" and panel.tiles[1].texture:find("DrownedCityMap",1,true))
assert(not panel.dots[1].shown and queryCount==0,"no projection on custom authors' art")
panel.next.scripts.OnClick()
assert(panel.floor.text=="Atal'Byzal" and panel.tiles[1].texture:find("AtalByzal",1,true))
panel.native.scripts.OnClick()
assert(panel.native.text=="Journal map" and panel.tiles[1].texture==4401)
assert(panel.dots[1].shown and panel.dots[2].shown and not panel.dots[3].shown and not panel.dots[4].shown and not panel.dots[5].shown)
assert(panel.dots[1].anchor[4]==panel.art:GetWidth()*.25 and panel.dots[1].anchor[5]==-panel.art:GetHeight()*.75)
AT.db.dungeonPositionShowParty=false;AT.RefreshDungeonPosition()
assert(panel.dots[1].shown and not panel.dots[2].shown)
AT.db.dungeonPositionShowSelf=false;AT.RefreshDungeonPosition()
assert(not panel.dots[1].shown)
AT.db.dungeonPositionShowSelf=true
panel.back.scripts.OnClick()
assert(not panel.shown and WorldMapFrame.shown,"World Map button preserves normal map")
WorldMapFrame:Hide();WorldMapFrame:Show()
assert(panel.shown,"dungeon first on each fresh open")
local journalPanel=object(WorldMapFrame);journalPanel:Show()
ForeverDungeonJournalFrame={dungeonMapPanel=journalPanel}
panel.scripts.OnUpdate(panel,1)
assert(not panel.shown and AT.OpenDungeonPositionMap() and not panel.shown,"existing Journal world-map overlay is not covered")
ForeverDungeonJournalFrame=nil
journalLock=true
assert(AT.OpenDungeonPositionMap())
AT.RefreshDungeonPosition()
assert(panel.tiles[1].texture==4401 and not panel.next.shown,"respect the Journal's map lock")
inside=false;watcher.scripts.OnEvent(watcher,"PLAYER_ENTERING_WORLD")
assert(not panel.shown and not AT.OpenDungeonPositionMap())
inside=true;journalLock=false;ForeverDungeonJournal_NS=nil
C_Map.GetPlayerMapPosition=function()return nil end
assert(AT.OpenDungeonPositionMap())
assert(panel.tiles[1].texture==4401 and not panel.dots[1].shown and panel.status.text:find("not exposing",1,true))
best.player=45;panel.scripts.OnUpdate(panel,1)
assert(panel.tiles[1].texture==4501 and not panel.dots[1].shown,"floor changes follow native map without stale pins")
C_Map.GetMapInfo=function()return {mapType=3,name="Unrelated outdoor zone"} end
AT.RefreshDungeonPosition()
assert(panel.missing.shown and not panel.tiles[1].shown and not panel.dots[1].shown)
AT.db.dungeonPositionAutoOpen=false;WorldMapFrame:Hide();WorldMapFrame:Show()
assert(not panel.shown)
assert(AT.OpenDungeonPositionMap())
AT.db.dungeonPositionEnabled=false;AT.RefreshDungeonPosition()
assert(not panel.shown and not AT.OpenDungeonPositionMap())
-- print("PASS Dungeon Position: world-map first open, World Map escape, Journal reuse/floors/RPG lock, native floor fallback, exact coordinates only, wrong-floor/secret/nil removal, settings")

-- Stockades: press the World Map shortcut, with Journal attaching after our OnShow.
AT.db.dungeonPositionEnabled=true
AT.db.dungeonPositionAutoOpen=true
AT.db.dungeonPositionShowParty=true
local notice
AT.Say=function(msg) notice=msg end
name,instanceID="The Stockade",34
best.player,best.party1,best.party2=225,225,224
C_Map.GetMapInfo=function(m) return {mapType=4,name="The Stockade"} end
C_Map.GetPlayerMapPosition=function(m,u)
    if u=="party3" then return secret end
    return {GetXY=function() return u=="player" and .25 or .5,.7 end}
end
local selected="The Stockade"
ForeverDungeonJournal_NS={
    INSTANCE_ID_TO_DUNGEON={[34]="The Stockade"},
    DUNGEON_MAPS={["The Stockade"]={floors={{uiMapID=225,tiles="Interface\\WorldMap\\TheStockade\\TheStockade1_"},
        {uiMapID=226}, {uiMapID=225,texture="custom"}}}},
    GetSelectedDungeon=function() return selected end,
}
local journal=object(WorldMapFrame)
local holder=object(journal)
holder:SetSize(520,300)
local t1,t2=holder:CreateTexture(),holder:CreateTexture()
local nativeTextures={22501,22502}
t1:SetTexture(nativeTextures[1]);t1:Show()
t2:SetTexture(nativeTextures[2]);t2:Show()
local jf={dungeonMapPanel=journal,dungeonMapArtHolder=holder,dungeonMapArtTiles={t1,t2},dungeonMapFloor=1}
ForeverDungeonJournalFrame=jf
WorldMapFrame:Hide(); ToggleWorldMap()
assert(panel.shown,"Auto Track starts normally before Journal attaches")
journal:Show();holder:Show()
local function tick() watcher.scripts.OnUpdate(watcher,.2) end
tick()
local overlay=assert(holder.children[1])
local self,party=overlay.regions[1],overlay.regions[2]
assert(overlay.shown and self.shown and party.shown and not overlay.regions[3].shown and not panel.shown,
    "World Map shortcut renders matching player/party on Journal floor, not the wrong floor")
assert(self.anchor[2]==holder and self.anchor[4]==130 and self.anchor[5]==-210)
holder:SetSize(1040,600);tick()
assert(self.anchor[4]==260 and self.anchor[5]==-420,"follows Journal zoom and pan via actual art holder")
jf.dungeonMapFloor=2;tick();assert(not overlay.shown,"different floor clears")
jf.dungeonMapFloor=3;tick();assert(not overlay.shown,"custom floor clears even with same id")
jf.dungeonMapFloor=1;tick();assert(self.shown)
selected="Other dungeon";tick();assert(not overlay.shown,"unrelated Journal selection clears")
selected="The Stockade";t2:Hide();tick();assert(not overlay.shown,"incomplete art clears including after resize")
t2:Show();t2:SetTexture(22503);tick();assert(not overlay.shown,"mismatched art clears")
t2:SetTexture(nativeTextures[2]);jf.dungeonMapArtCopy=true;tick();assert(not overlay.shown,"copied art clears despite matches")
t2.GetTextureFileID=nil; t2.GetTexture=function(self) return self.texture end
jf.dungeonMapArtCopy=false;tick();assert(overlay.shown,"numeric GetTexture proves ID if FileID API absent")
t2:SetTexture("Interface/legacy/named2");tick();assert(not overlay.shown,"legacy paths do not prove art identity")
t2:SetTexture(nativeTextures[2]);tick();assert(overlay.shown)
AT.db.dungeonPositionShowParty=false;AT.RefreshDungeonPosition()
assert(self.shown and not party.shown,"changing party option clears its dot immediately")
AT.db.dungeonPositionShowParty=true
AT.db.dungeonPositionShowSelf=false;AT.RefreshDungeonPosition()
assert(not self.shown and party.shown,"changing player option clears its dot immediately")
AT.db.dungeonPositionShowSelf=true
AT.db.dungeonPositionEnabled=false;AT.RefreshDungeonPosition();assert(not overlay.shown)
AT.db.dungeonPositionEnabled=true;AT.RefreshDungeonPosition();assert(overlay.shown)
C_Map.GetPlayerMapPosition=function() return nil end
tick();assert(not overlay.shown)
assert(AT.OpenDungeonPositionMap() and notice:find("not exposing",1,true),"manual command reports missing live coords")
C_Map.GetPlayerMapPosition=function() return {GetXY=function() return .3,.4 end} end
tick();assert(self.shown)
WorldMapFrame:Hide();assert(not overlay.shown and not self.shown,"closing the map clears all dots immediately")
AT.db.dungeonPositionAutoOpen=false;ToggleWorldMap();tick()
assert(not overlay.shown,"auto-open off never overlays an unsolicited map")
assert(AT.OpenDungeonPositionMap() and overlay.shown,"explicit open opts in for this map session")
inside=false;watcher.scripts.OnEvent(watcher,"PLAYER_ENTERING_WORLD")
assert(not overlay.shown,"leaving the instance drops all positions immediately")
print("PASS Dungeon Position: World Map open/close, source fallback, exact native-floor Journal dots, panning/zooming, no stale positions, settings")

-- A missing Lua point does not stop the engine rendering its own markers.
-- No screen/coordinate readback; same displayed floor, and hide policy honored.
inside=true;best.player=nil;best.party1=225
C_Map.GetPlayerMapPosition=function() return nil end
local hide=false
C_Map.GetMapDisplayInfo=function() return hide end
assert(AT.OpenDungeonPositionMap())
local pins; for _,f in ipairs(all) do if f.kind=="UnitPositionFrame" and f:GetParent()==holder then pins=f end end; assert(pins)
assert(pins.kind=="UnitPositionFrame" and pins.ready and pins.map==225 and pins.shown)
assert(pins.units[1]=="player" and pins.units[2]=="party1")
for _,unit in ipairs(pins.units) do assert(unit~="party2","other floor cannot appear") end
hide=true;tick();assert(not pins.shown and not overlay.shown)
assert(AT.OpenDungeonPositionMap() and notice:find("hide position",1,true))
hide=secret;tick();assert(not pins.shown)
hide=false;tick();assert(pins.shown)
jf.dungeonMapFloor=3;tick();assert(not pins.shown,"native renderer does not run on unverified art")
jf.dungeonMapFloor=1;tick();assert(pins.shown)
AT.db.dungeonPositionShowSelf=false;AT.RefreshDungeonPosition()
assert(pins.shown and pins.units[1]=="party1" and #pins.units==1)
WorldMapFrame:Hide();assert(not pins.shown,"close must clear the native layer")
print("PASS fallback to native player pins, ordinary hide flag, exact map and unit controls")AT.db.dungeonPositionShowSelf=true
GetZoneText=function() return "The Stockade" end
local subzone,minizone="Cell Block","The Stockade"
GetSubZoneText=function() return subzone end
GetMinimapZoneText=function() return minizone end
assert(AT.OpenDungeonPositionMap() and notice:find("Approx. area: Cell Block",1,true))
local label
for _,obj in ipairs(journal.children) do if type(obj.text)=="table" then label=obj end end
assert(label and label.shown and label.text.text=="Approx. area: Cell Block")
subzone="Guard Hall";tick()
assert(label.shown and label.text.text=="Approx. area: Guard Hall","persistent label updates without reopening")
subzone=secret;minizone="The Stockade";tick()
assert(label.text.text=="WoW reports only the zone, not a room.")
subzone="The Stockade";minizone="Corridor";tick()
assert(label.text.text=="Approx. area: Corridor")
best.player=225
C_Map.GetPlayerMapPosition=function(_,token)
    if token=="player" then return {GetXY=function() return .3,.4 end} end
end
tick();assert(self.shown and not label.shown,"exact matching pin takes precedence")
C_Map.GetPlayerMapPosition=function() return nil end
tick();assert(label.shown)
AT.db.dungeonPositionShowSelf=false;AT.RefreshDungeonPosition();assert(not label.shown)
WorldMapFrame:Hide();assert(not label.shown)
print("PASS persistent named area fallback, live text refresh, exact pin precedence, restricted/instance-wide labels not classified as rooms")


-- Known single-floor Journal custom art can offer a switch to actual native
-- floor art. The native layer runs even when public Lua coordinates are nil.
AT.db.dungeonPositionShowSelf=true
AT.db.dungeonPositionShowParty=true
best.player,best.party1,best.party2=nil,225,224
ForeverDungeonJournal_NS.DUNGEON_MAPS["The Stockade"].floors={{uiMapID=225}}
jf.dungeonMapFloor=1
t2:SetTexture("Journal-replacement")
assert(AT.OpenDungeonPositionMap())
local gameFloor
for _,child in ipairs(journal.children) do if child.text=="Game floor map" then gameFloor=child end end
assert(gameFloor and gameFloor.shown and not panel.shown)
gameFloor.scripts.OnClick()
assert(panel.shown and panel.tiles[1].texture==22501 and not gameFloor.shown)
local live
for _,child in ipairs(panel.art.children) do
    if child.kind=="UnitPositionFrame" then live=child;break end
end
assert(live)
assert(live.kind=="UnitPositionFrame" and live.map==225 and live.ready and live.shown)
assert(live.units[1]=="player" and live.units[2]=="party1" and #live.units==2)
assert(live:GetFrameLevel()>panel.art:GetFrameLevel())
tick();panel.scripts.OnUpdate(panel,.3)
assert(live.shown and panel.shown,"Journal timer cannot hide the game floor renderer")
hide=true;panel.scripts.OnUpdate(panel,.3);assert(not live.shown and not panel.dots[1].shown)
hide=false;panel.scripts.OnUpdate(panel,.3);assert(live.shown)
best.player=224
C_Map.GetMapInfo=function(m) return {mapType=m==225 and 4 or 3,name=m==225 and "The Stockade" or "Outside"} end
panel.scripts.OnUpdate(panel,.3);assert(not live.shown and not panel.dots[1].shown)
best.player=nil;panel.scripts.OnUpdate(panel,.3);assert(live.shown)
panel.back.scripts.OnClick()
assert(not live.shown and not panel.shown and gameFloor.shown)
ForeverDungeonJournal_NS.DUNGEON_MAPS["The Stockade"].floors={{uiMapID=225},{uiMapID=226}}
tick();assert(not gameFloor.shown,"multi-floor Journal can't guess which native floor applies")
WorldMapFrame:Hide()
print("PASS native game floor switch, stockade match when best floor is absent, visibility policy, live renderer and return to Journal")


-- Explicit diagnostic distinguishes a request from a visible engine marker.
AT.char={}
assert(SLASH_NEXUSDUNGEONMARKERCHECK1=="/nqtdungeon")
assert(AT.OpenDungeonPositionMap())
SlashCmdList.NEXUSDUNGEONMARKERCHECK()
assert(notice:find("Dungeon Journal",1,true) and notice:find("matched floor=none",1,true))
assert(AT.char.lastDungeonMarkerCheck==notice, "only the technical diagnostic is saved locally")
ForeverDungeonJournal_NS.DUNGEON_MAPS["The Stockade"].floors={{uiMapID=225}}
tick();gameFloor.scripts.OnClick()
SlashCmdList.NEXUSDUNGEONMARKERCHECK()
assert(notice:find("matched floor=225",1,true) and notice:find("player point=unavailable",1,true))
assert(notice:find("layer started",1,true) and notice:find("not measurable",1,true))
hide=true;panel.scripts.OnUpdate(panel,.3)
SlashCmdList.NEXUSDUNGEONMARKERCHECK()
assert(notice:find("map icons=hidden",1,true))
assert(not notice:find("layer started",1,true))
print("PASS in-client diagnostics distinguish floor, icon policy and renderer request, without claiming a visible pin")

-- Map-to-map geometry is public room data, not reconstructed unit coordinates.
hide=false
best.player=nil
subzone,minizone="Cell Block","The Stockade"
C_Map.GetMapInfo=function(m)
    if m==225 then return {mapType=4,name="The Stockade"} end
    if m==999 then return {mapType=5,parentMapID=225,name="Cell Block"} end
    if m==1000 then return {mapType=5,parentMapID=225,name="Guard Hall"} end
    if m==1001 then return {mapType=5,parentMapID=777,name="Different Floor"} end
end
C_Map.GetMapChildrenInfo=function(m,kind,desc)
    assert(m==225 and kind==5 and desc==false)
    return {{mapID=999},{mapID=1000},{mapID=1001}}
end
local invalid=false
C_Map.GetMapRectOnMap=function(child,parent)
    assert(parent==225)
    if child==999 then return .3,.5,.1,.3 end
    if invalid then return -1,0,0,5 end
    return .55,.7,.7,.9
end
panel.scripts.OnUpdate(panel,.3)
local roomOverlay=assert(panel.art.children[#panel.art.children])
assert(roomOverlay.shown and panel.location.text.text=="Approx. room: Cell Block")
assert(math.abs(roomOverlay.anchor[4]-.3*panel.art:GetWidth())<.01)
subzone="Guard Hall";panel.scripts.OnUpdate(panel,.3)
assert(roomOverlay.shown and panel.location.text.text=="Approx. room: Guard Hall")
assert(math.abs(roomOverlay.anchor[4]-.55*panel.art:GetWidth())<.01)
invalid=true;panel.scripts.OnUpdate(panel,.3);assert(not roomOverlay.shown)
invalid=false;minizone="Cell Block";panel.scripts.OnUpdate(panel,.3)
assert(not roomOverlay.shown,"conflicting named rooms are not guessed")
minizone="The Stockade";subzone="Unmapped hallway";panel.scripts.OnUpdate(panel,.3);assert(not roomOverlay.shown)
subzone="Guard Hall";hide=true;panel.scripts.OnUpdate(panel,.3);assert(not roomOverlay.shown)
hide=false;best.player=225
C_Map.GetPlayerMapPosition=function(_,token) if token=="player" then return {GetXY=function() return .5,.5 end} end end
panel.scripts.OnUpdate(panel,.3);assert(panel.dots[1].shown and not roomOverlay.shown)
C_Map.GetPlayerMapPosition=function()end
best.player=nil;panel.scripts.OnUpdate(panel,.3);assert(roomOverlay.shown)
WorldMapFrame:Hide();assert(not roomOverlay.shown)
print("PASS room estimate follows public labels on matched atlas only, rejects missing/secrets/overlaps/hidden icons and yields to exact position")

-- Calibrated fallback with only room labels and known native tiles.
name,instanceID,kind="The Deadmines",36,"party"
ForeverDungeonJournalFrame=nil
ForeverDungeonJournal_NS=nil
AT.db.dungeonPositionAutoOpen=true
AT.db.dungeonPositionShowSelf=true
C_Map.GetMapChildrenInfo=function() return {} end
C_Map.GetMapInfo=function(m)
    if m==291 or m==292 then return {mapType=4,name="Native floor"} end
    return {mapType=3,name="Outdoor map"}
end
C_Map.GetMapArtLayers=function() return {{layerWidth=1002,layerHeight=668,tileWidth=256,tileHeight=256}} end
local corrupt=false
C_Map.GetMapArtLayerTextures=function(m)
    if m==291 then return {449591,449595,449596,449597,449598,449599,449600,449601,449602,449592,449593,449594} end
    if m==292 then return {449603,449607,449608,449609,449610,449611,449612,449613,449614,449604,449605,corrupt and 1 or 449606} end
end
GetZoneText=function() return "The Deadmines" end
best.player=nil
subzone,minizone="Mast Room","The Deadmines"
WorldMapFrame:Show()
assert(panel.shown and panel.tiles[1].texture==449591)
assert(roomOverlay.shown and panel.location.text.text=="Approx. room: Mast Room")
SlashCmdList.NEXUSDUNGEONMARKERCHECK()
assert(notice:find("room geometry=Mast Room",1,true))
subzone="Ironclad Cove";watcher.scripts.OnEvent(watcher,"ZONE_CHANGED_INDOORS")
assert(panel.tiles[1].texture==449603 and roomOverlay.shown and panel.location.text.text=="Approx. room: Ironclad Cove")
minizone="Mast Room";panel.scripts.OnUpdate(panel,.3)
assert(not roomOverlay.shown,"conflicting room labels do not show an estimate")
minizone="The Deadmines";best.player=291;panel.scripts.OnUpdate(panel,.3)
assert(not roomOverlay.shown,"contrary recognized floor wins over room text")
best.player=nil;panel.scripts.OnUpdate(panel,.3)
assert(roomOverlay.shown)
corrupt=true;panel.scripts.OnUpdate(panel,.3)
assert(not roomOverlay.shown,"matching map ID insufficient without verified atlas")
corrupt=false;hide=true;panel.scripts.OnUpdate(panel,.3)
assert(not roomOverlay.shown,"respect client map icon policy")
hide=false;subzone="Goblin Foundry";panel.scripts.OnUpdate(panel,.3)
assert(not roomOverlay.shown,"do not guess ambiguous cross-floor room")
subzone="Mast Room";instanceID=225;panel.scripts.OnUpdate(panel,.3)
assert(not roomOverlay.shown,"do not carry calibration into different dungeon")
WorldMapFrame:Hide()
print("PASS Deadmines floor transitions and calibrated room geometry")

-- Journal's standalone map is visible without the Blizzard World Map.
inside=true;instanceID=36;best.player=nil;hide=false;subzone="Mast Room"
local root=object();root:Show()
local standalone=object(root);standalone:Show()
local floorArt=object(standalone);floorArt:Show()
local atlasTiles=C_Map.GetMapArtLayerTextures(291)
local regions={}
for i,file in ipairs(atlasTiles) do
    local tile=object(floorArt);tile:SetTexture(file);tile:Show();regions[i]=tile
end
ForeverDungeonJournalFrame={dungeonMapPanel=standalone,dungeonMapFloor=1,
    dungeonMapArtHolder=floorArt,dungeonMapArtTiles=regions}
ForeverDungeonJournal_NS={INSTANCE_ID_TO_DUNGEON={[36]="The Deadmines"},
    DUNGEON_MAPS={["The Deadmines"]={floors={{uiMapID=291},{uiMapID=292}}}},
    GetSelectedDungeon=function() return "The Deadmines" end}
C_Map.GetMapArtLayers=function() return nil end
watcher.scripts.OnUpdate(watcher,.25)
local estimated
for _,child in ipairs(floorArt.children) do
    if child.regions[2] and child.regions[2].text=="~" then estimated=child end
end
assert(estimated and estimated.shown and not WorldMapFrame:IsShown())
SlashCmdList.NEXUSDUNGEONMARKERCHECK()
assert(notice:find("Dungeon Journal standalone",1,true) and notice:find("Area labels:",1,true))
regions[12]:SetTexture(123)
watcher.scripts.OnUpdate(watcher,.25);assert(not estimated.shown,"reject a single substituted atlas tile")
regions[12]:SetTexture(atlasTiles[12])
watcher.scripts.OnUpdate(watcher,.25);assert(estimated.shown)
standalone:Hide();watcher.scripts.OnUpdate(watcher,.25);assert(not estimated.shown)
print("PASS standalone Dungeon Journal activation, exact legacy atlas identity, diagnostic and cleanup")

-- Stockade: no coordinates, no heading, and no named rooms. Match the
-- installed Journal's real legacy layout; mark only a recent event.
local t=100
function GetTime() return t end
instanceID,name=34,"The Stockade"
GetZoneText=function()return name end
subzone,minizone="","The Stockade"
local prefix="Interface\\WorldMap\\TheStockade\\TheStockade1_"
local stockFloor={uiMapID=225,tiles=prefix}
local stock={floors={stockFloor},entrance={x=.500,y=.815},bosses={
    {name="Hamhock",x=.780,y=.457},{name="Kam Deepfury",x=.692,y=.288},
    {name="Targorr the Dread",x=.440,y=.445},{name="Targorr the Dread",alt=true,x=.499,y=.205},
}}
ForeverDungeonJournal_NS={INSTANCE_ID_TO_DUNGEON={[34]=name},DUNGEON_MAPS={[name]=stock},
    GetSelectedDungeon=function()return "The Stockade" end,
    MapArtCopy=function()return "JournalStockadeCopy" end}
floorArt:SetSize(600,400)
for i,tex in ipairs(regions) do tex:SetTexture(prefix..i);tex:Show() end
standalone:Show()
local frame=ForeverDungeonJournalFrame
watcher.scripts.OnEvent(watcher,"PLAYER_ENTERING_WORLD",false,true)
local function activeEstimate()
    for _,child in ipairs(floorArt.children) do
        if child.shown and child.regions[1] and child.regions[1].text=="~" then return child end
    end
end
assert(not activeEstimate(),"reload inside is not a portal arrival")
inside=false;watcher.scripts.OnEvent(watcher,"PLAYER_ENTERING_WORLD",false,false)
inside=true;watcher.scripts.OnEvent(watcher,"PLAYER_ENTERING_WORLD",false,false)
local landmark=assert(activeEstimate(),"real portal arrival shows a landmark")
assert(landmark.anchor[4]==300 and landmark.anchor[5]==-.815*400)
t=t+13;watcher.scripts.OnUpdate(watcher,.25);assert(not activeEstimate())
watcher.scripts.OnEvent(watcher,"ENCOUNTER_START",2756)
assert(not activeEstimate(),"do not pretend to locate roaming Targorr")
watcher.scripts.OnEvent(watcher,"ENCOUNTER_START",2758)
assert(activeEstimate()==landmark and landmark.anchor[4]==.780*600)
watcher.scripts.OnEvent(watcher,"ENCOUNTER_START",2757)
assert(landmark.anchor[4]==.692*600)
regions[5]:SetTexture("unexpected");watcher.scripts.OnUpdate(watcher,.25);assert(not activeEstimate())
regions[5]:SetTexture(prefix..5);watcher.scripts.OnUpdate(watcher,.25);assert(activeEstimate())
frame.dungeonMapArtCopy=true
regions[1]:SetTexture("JournalStockadeCopy")
for i=2,12 do regions[i]:Hide() end
watcher.scripts.OnUpdate(watcher,.25);assert(activeEstimate(),"aligned Journal's own art copy works")
hide=true;watcher.scripts.OnUpdate(watcher,.25);assert(not activeEstimate(),"honor client's hide icons policy")
hide=false
SlashCmdList.NEXUSDUNGEONMARKERCHECK()
assert(notice:find("last position estimate: Near Kam Deepfury at pull",1,true))
AT.db.dungeonPositionShowSelf=false;watcher.scripts.OnUpdate(watcher,.25);assert(not activeEstimate())
AT.db.dungeonPositionShowSelf=true
watcher.scripts.OnEvent(watcher,"PLAYER_DEAD");assert(not activeEstimate())
watcher.scripts.OnEvent(watcher,"ENCOUNTER_START",2757);assert(activeEstimate())
t=t+26;watcher.scripts.OnUpdate(watcher,.25);assert(not activeEstimate(),"no stale boss landmark")
C_Map.GetPlayerMapPosition=function(map,token)
    assert(map==225 and token=="player")
    return {GetXY=function() return .39,.64 end}
end
assert(AT.GetDungeonPositionPoint(225,"player")==.39,"real point with unknown BestMap on sole trusted floor")
best.player=84
assert(not AT.GetDungeonPositionPoint(225,"player"),"cannot use a contrary explicit floor")
print("PASS Stockade legacy/copy alignment, portal vs reload, nearby fixed encounters, expiry, hide policy, and honest exact/approximate separation")

-- User screenshot: Dungeon Journal knows 225, but Blizzard reports no
-- best floor and no layers. File ID/path fingerprints still match the art.
best.player=nil
C_Map.GetMapArtLayers=function() return nil end
hide=false
frame.dungeonMapArtCopy=false
for i,tex in ipairs(regions) do tex:SetTexture(prefix..i);tex:Show() end
local xx,yy=.42,.55
C_Map.GetPlayerMapPosition=function(map,token)
    if map==225 and token=="player" then return {GetXY=function() return xx,yy end} end
end
watcher.scripts.OnUpdate(watcher,.25)
local layer,dot
for _,child in ipairs(floorArt.children) do
    if child.dots then layer=child end
end
dot=assert(layer and layer.dots[1],"legacy alignment enables drawing")
assert(layer.shown and dot.shown and dot.anchor[4]==xx*600 and dot.anchor[5]==-yy*400)
xx,yy=.44,.57
watcher.scripts.OnUpdate(watcher,.25)
assert(dot.shown and dot.anchor[4]==xx*600 and dot.anchor[5]==-yy*400,"render actual movement")
SlashCmdList.NEXUSDUNGEONMARKERCHECK()
assert(notice:find("matched floor=225",1,true) and notice:find("player point=available",1,true),notice)
regions[4]:SetTexture("unrecognized tile")
watcher.scripts.OnUpdate(watcher,.25)
assert(not dot.shown,"a wrong tile suppresses drawing")
SlashCmdList.NEXUSDUNGEONMARKERCHECK()
assert(notice:find("matched floor=none",1,true) and notice:find("player point=available",1,true),notice)
regions[4]:SetTexture(prefix..4)
frame.dungeonMapArtCopy=true
regions[1]:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\Maps\\TheStockade1")
for i=2,12 do regions[i]:Hide() end
watcher.scripts.OnUpdate(watcher,.25)
assert(dot.shown and dot.anchor[4]==xx*600)
C_Map.GetPlayerMapPosition=function() end
watcher.scripts.OnUpdate(watcher,.25)
assert(not dot.shown,"no position means no live point")
print("PASS screenshot path: missing native floor/layers with verified Stockade Journal artwork, exact moving dot, canonical copy, bad tile, honest diagnostic when no coordinates")

-- The Stockade preview distinguishes an ordinary empty reply
-- from a client restriction, and does not draw on other art or maps.
local function currentNative()
    for _,child in ipairs(all) do
        if child:GetParent()==floorArt and child.shown and child.ready and child.map==225 and child.units and child.units[1]=="player" then return child end
    end
end
local getDisplay=C_Map.GetMapDisplayInfo
C_Map.GetMapDisplayInfo=function() return nil end
watcher.scripts.OnUpdate(watcher,.25)
assert(currentNative(),"verified Stockade can try the native renderer after an empty policy reply")
assert(not dot.shown,"native registration must not fabricate a Lua coordinate")
SlashCmdList.NEXUSDUNGEONMARKERCHECK()
assert(notice:find("map icons=no hide flag",1,true) and notice:find("layer started",1,true),notice)
C_Map.GetMapDisplayInfo=function() return true end
watcher.scripts.OnUpdate(watcher,.25)
assert(not currentNative(),"must honor an explicit hide")
C_Map.GetMapDisplayInfo=function() error("position policy unavailable") end
watcher.scripts.OnUpdate(watcher,.25)
assert(not currentNative(),"an error is not an empty reply")
C_Map.GetMapDisplayInfo=function() return secret end
watcher.scripts.OnUpdate(watcher,.25)
assert(not currentNative(),"must not use a secret response")
C_Map.GetMapDisplayInfo=nil
watcher.scripts.OnUpdate(watcher,.25)
assert(not currentNative(),"missing API is not an empty reply")
C_Map.GetMapDisplayInfo=function() return nil end
regions[1]:SetTexture("wrong copy")
watcher.scripts.OnUpdate(watcher,.25)
assert(not currentNative(),"unmatched art must stop the native layer")
regions[1]:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\Maps\\TheStockade1")
watcher.scripts.OnUpdate(watcher,.25)
assert(currentNative(),"restore the layer when verified art returns")
standalone:Hide()
watcher.scripts.OnUpdate(watcher,.25)
assert(not currentNative(),"closing the map clears the layer")
C_Map.GetMapDisplayInfo=getDisplay
print("PASS Stockade native layer: ordinary nil, live renderer request, hide, errors, secrets, missing API, wrong art, close")
-- Independent entrance landmark survives a reload inside, does not appear as
-- a player position, follows the map art and hides when it closes.
standalone:Show()
watcher.scripts.OnEvent(watcher,"PLAYER_ENTERING_WORLD",false,true)
local function entranceLabel(holder)
    for _,child in ipairs(holder.children) do
        if child:IsVisible() and child.regions[2] and child.regions[2].text=="Entrance" then return child end
    end
end
local entrance=assert(entranceLabel(floorArt),"reload inside still shows the entrance")
assert(entrance.anchor[4]==300 and entrance.anchor[5]==-.815*400-8)
assert(not activeEstimate() and not dot.shown,"static label is not a position")
t=t+100;watcher.scripts.OnUpdate(watcher,.25)
assert(entranceLabel(floorArt)==entrance,"entrance stays after arrival estimate expires")
AT.db.dungeonPositionShowSelf=false;watcher.scripts.OnUpdate(watcher,.25)
assert(entranceLabel(floorArt)==entrance and not currentNative(),"static entrance does not depend on self marker")
regions[1]:SetTexture("wrong copy");watcher.scripts.OnUpdate(watcher,.25)
assert(not entranceLabel(floorArt),"unverified art has no entrance")
regions[1]:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\Maps\\TheStockade1")
watcher.scripts.OnUpdate(watcher,.25)
assert(entranceLabel(floorArt)==entrance)
standalone:Hide();watcher.scripts.OnUpdate(watcher,.25)
assert(not entrance:IsShown())
print("PASS permanent Stockade entrance label after reload, verified art, no fabricated position, close")
-- Observe the same callback that the hardware macro calls. Never display
-- a player point or a guess for a boss with several Journal landmarks.
AT.db.dungeonPositionShowSelf=true
AT.db.bossAutoMark=true
function InCombatLockdown() return false end
function SecureCmdOptionParse() return "yes" end
function GetRaidTargetIndex() return nil end
function CheckInteractDistance(unit,index) return unit=="target" and index==3 end
local targetName="Trash"
function UnitName() return targetName end
local function sightingPin()
    for _,child in ipairs(floorArt.children) do
        if child:IsVisible() and child.regions[1] and child.regions[1].text=="!" then return child end
    end
end
standalone:Show()
watcher.scripts.OnEvent(watcher,"PLAYER_ENTERING_WORLD",false,true)
AT.ReserveBossMark(0)
SlashCmdList.NEXUSBOSSSIGHTING()
assert(notice:find("No recent",1,true))
targetName="Hamhock"
AT.ReserveBossMark(0)
watcher.scripts.OnUpdate(watcher,.25)
SlashCmdList.NEXUSBOSSSIGHTING()
assert(notice=="Boss sighting (close): Hamhock (not your position)",notice)
local seen=assert(sightingPin(),"mapped sighting gets its own landmark glyph")
assert(seen.anchor[4]==.780*600 and not dot.shown)
targetName="Targorr the Dread"
AT.ReserveBossMark(0)
watcher.scripts.OnUpdate(watcher,.25)
SlashCmdList.NEXUSBOSSSIGHTING()
assert(notice:find(targetName,1,true) and not sightingPin())
targetName="Kam Deepfury"
AT.ReserveBossMark(0)
watcher.scripts.OnUpdate(watcher,.25)
assert(sightingPin())
t=t+31;watcher.scripts.OnUpdate(watcher,.25)
SlashCmdList.NEXUSBOSSSIGHTING()
assert(notice:find("No recent",1,true) and not sightingPin())
AT.ReserveBossMark(0)
watcher.scripts.OnEvent(watcher,"PLAYER_DEAD")
SlashCmdList.NEXUSBOSSSIGHTING()
assert(notice:find("No recent",1,true) and not sightingPin())
print("PASS boss macro observation: ignores trash; verified landmark; roaming ambiguity; expiry and death cleanup")

-- The passive fallback works even if the hardware slash callback is absent.
function UnitExists(unit) return unit=="target" end
function UnitCanAttack(_,unit) return unit=="target" end
local dead=false
function UnitIsDeadOrGhost() return dead end
function UnitGUID(unit) return unit=="target" and "Creature-0-1-34-1-1717-1" end
AT.InitBossTargetMarking()
local bossWatcher=all[#all]
targetName="Hamhock"
bossWatcher.scripts.OnEvent(bossWatcher,"PLAYER_TARGET_CHANGED")
watcher.scripts.OnUpdate(watcher,.25)
assert(sightingPin() and not dot.shown)
SlashCmdList.NEXUSDUNGEONMARKERCHECK()
assert(notice:find("Boss sighting: Hamhock (landmark visible)",1,true),notice)
watcher.scripts.OnEvent(watcher,"PLAYER_DEAD")
dead=true
bossWatcher.scripts.OnEvent(bossWatcher,"PLAYER_TARGET_CHANGED")
SlashCmdList.NEXUSBOSSSIGHTING()
assert(notice:find("No recent",1,true))
dead=false
targetName=secret
bossWatcher.scripts.OnEvent(bossWatcher,"PLAYER_TARGET_CHANGED")
SlashCmdList.NEXUSBOSSSIGHTING()
assert(notice:find("No recent",1,true))
print("PASS readable boss target fallback and diagnostics, dead/secret rejection")

-- Independent NQT panel works even when another addon owns the map key.
name,instanceID,kind="The Stockade",34,"party"
WorldMapFrame:Hide()
standalone:Hide()
UIParent=object();UIParent:Show()
function panel:SetParent(parent) self.parent=parent end
function panel:GetScript(key) return self.scripts[key] end
watcher.scripts.OnEvent(watcher,"PLAYER_ENTERING_WORLD",false,true)
SlashCmdList.NEXUSDUNGEONMARKERCHECK()
SlashCmdList.NEXUSOWNDUNGEONMAP("")
watcher.scripts.OnUpdate(watcher,.25)
panel.scripts.OnUpdate(panel,.25)
SlashCmdList.NEXUSDUNGEONMARKERCHECK()
assert(panel:IsVisible() and not WorldMapFrame:IsShown() and panel.back.text=="Close")
assert(notice:find("matched floor=225",1,true),notice)
panel.back.scripts.OnClick()
assert(not panel:IsShown() and panel:GetParent()==WorldMapFrame and panel.back.text=="World Map")
print("PASS independent dungeon panel on legacy art")

-- Normal M with stock minimap and with the installed SexyMap-style hooks.
local baseAnchor=UIParent
local calls,protected,combat=0,false,false
InCombatLockdown=function() return combat end
Minimap={
    points={{"BOTTOM",baseAnchor,"BOTTOM",-230.729,22.586}},strata="LOW",fixed=false,
    IsVisible=function() return true end,
    IsProtected=function() return protected end,
    HasFixedFrameStrata=function(self) return self.fixed end,
    SetFixedFrameStrata=function(self,v) self.fixed=v end,
    GetFrameStrata=function(self) return self.strata end,
    SetFrameStrata=function(self,v) if not self.fixed then self.strata=v end end,
    GetNumPoints=function(self) return #self.points end,
    GetPoint=function(self,i) return unpack(self.points[i],1,5) end,
    ClearAllPoints=function(self) self.points={} end,
    SetPoint=function(self,...) self.points[#self.points+1]={...} end,
}
local function restored()
    local a,b,c,x,y=Minimap:GetPoint(1)
    assert(#Minimap.points==1 and a=="BOTTOM" and b==baseAnchor and c=="BOTTOM" and x==-230.729 and y==22.586 and Minimap.strata=="LOW")
end
local function chrome(alpha,kind)
    return {alpha=alpha,kind=kind,
        SetAlpha=function(self,v) self.alpha=v end,
        GetAlpha=function(self) return self.alpha end,
        IsObjectType=function(self,k) return self.kind==k end}
end
local button,nativeArrow,decor,other=chrome(.85,"Button"),chrome(1,"Texture"),chrome(.74,"Texture"),chrome(.3,"Frame")
decor.settings={}
local function frameChrome(shown)
    local f=object()
    f.shown=shown;f.alpha=.8
    f.SetAlpha=function(self,v) self.alpha=v end
    f.GetAlpha=function(self) return self.alpha end
    f.IsObjectType=function(_,kind) return kind=="Button" end
    return f
end
local animated,alreadyHidden=frameChrome(true),frameChrome(false)
MinimapZoneText=chrome(.7,"FontString")
SexyMapZoneTextButton=chrome(.91,"Button")
SexyMapCustomBackdrop=chrome(.55,"Frame")
Minimap.GetChildren=function() return button,other,animated,alreadyHidden end
Minimap.GetRegions=function() return nativeArrow,decor end
local zoom,zseq,blips=2,{},0
Minimap.GetZoom=function() return zoom end
Minimap.GetZoomLevels=function() return 6 end
Minimap.SetZoom=function(_,v) zoom=v;zseq[#zseq+1]=v end
Minimap.UpdateBlips=function() blips=blips+1 end
WorldMapFrame.GetFrameStrata=function() return "FULLSCREEN" end
AT.db.dungeonMapMinimap=true
WorldMapFrame:Show();panel.scripts.OnUpdate(panel,.25);tick()
assert(Minimap.points[1][2]==panel and Minimap.strata=="FULLSCREEN_DIALOG")
assert(button.alpha==0 and MinimapZoneText.alpha==0 and nativeArrow.alpha==1 and other.alpha==.3)
assert(not animated.shown and not alreadyHidden.shown)
animated:SetAlpha(1);animated:Show();alreadyHidden:Show()
assert(not animated.shown and not alreadyHidden.shown,"no flash between ticks when another addon shows a button")
assert(zoom==2 and #zseq==2 and zseq[1]==1 and zseq[2]==2 and blips==1,"redraw without changing zoom")
WorldMapFrame:Hide();restored()
assert(button.alpha==.85 and MinimapZoneText.alpha==.7 and zoom==2 and animated.shown and not alreadyHidden.shown)
-- Reproduce the stock XML's bare CENTER anchor (no SexyMap, parent is the
-- native container). This is different from the fully expanded addon anchor.
local stockContainer=object()
local nativeSetPoint=Minimap.SetPoint
Minimap.GetParent=function() return stockContainer end
Minimap.SetPoint=function(self,a,b,c,x,y)
    -- Native bindings may return the actual parent after SetPoint used nil.
    return nativeSetPoint(self,a,b or stockContainer,c,x,y)
end
Minimap.ZoomHitArea=frameChrome(true)
Minimap.fixed=true
local function nativeAnchor() Minimap.points={{"CENTER"}} end
local function nativeRestored()
    local a,b,c,x,y=Minimap:GetPoint(1)
    assert(a=="CENTER" and b==stockContainer and c=="CENTER" and x==0 and y==0)
    assert(Minimap:GetParent()==stockContainer and Minimap.strata=="LOW" and Minimap.fixed)
    assert(Minimap.ZoomHitArea.shown and zoom==2,"restore stock mouse controls and zoom")
end
nativeAnchor()
WorldMapFrame:Show()
panel.hasArt=false
tick()
assert(Minimap.points[1][2]==panel and not Minimap.ZoomHitArea.shown and nativeArrow.alpha==1,
    "standalone live stock minimap still works if there is no overview art")
WorldMapFrame:Hide();nativeRestored()
nativeAnchor()
ForeverDungeonJournalFrame=jf
journal:Show()
WorldMapFrame:Show();tick()
assert(Minimap.points[1][2]==journal and Minimap:GetParent()==stockContainer and not Minimap.ZoomHitArea.shown,
    "stock default CENTER anchors also dock on the Journal map")
WorldMapFrame:Hide();nativeRestored()
Minimap.ZoomHitArea=nil; Minimap.GetParent=nil; Minimap.SetPoint=nativeSetPoint
Minimap.points={{"BOTTOM",baseAnchor,"BOTTOM",-230.729,22.586}}
print("PASS real stock XML anchor, parent verification, stock zoom hit area, dock without overview art and on Journal")
Minimap.fixed=true
Minimap.SetPoint=function() error("SexyMap would override native SetPoint") end
SexyMap={SetPoint=function(_,...) calls=calls+1;Minimap.points={{...}} end}
ForeverDungeonJournalFrame=jf
journal:Show()
WorldMapFrame:Show();tick()
assert(Minimap.points[1][2]==journal and Minimap.strata=="FULLSCREEN_DIALOG" and Minimap.fixed and calls==1,
    "the installed Journal's actual M path docks the live frame using SexyMap")
assert(decor.alpha==0 and SexyMapZoneTextButton.alpha==0 and SexyMapCustomBackdrop.alpha==0 and nativeArrow.alpha==1)
combat=true
WorldMapFrame:Hide();restored()
assert(button.alpha==.85 and MinimapZoneText.alpha==.7 and zoom==2 and animated.shown and not alreadyHidden.shown)
assert(Minimap.fixed and calls==2,"close restores even after entering combat on an unprotected frame")
assert(decor.alpha==.74 and SexyMapZoneTextButton.alpha==.91 and SexyMapCustomBackdrop.alpha==.55 and zoom==2)
WorldMapFrame:Show();tick()
assert(calls==2,"never dock during combat")
combat=false
protected=true;tick();assert(calls==2,"leave protected frame alone")
protected=false
AT.db.dungeonMapMinimap=false;tick();assert(calls==2)
AT.db.dungeonMapMinimap=true;tick();assert(calls==3 and Minimap.points[1][2]==journal)
AT.db.dungeonMapMinimap=false;AT.RefreshDungeonPosition();restored()
assert(calls==4 and Minimap.fixed,"off restores while M is open")
WorldMapFrame:Hide()
assert(not AT.NQTPreviewEstimate and not SlashCmdList.NQTINPUTCHECK)
print("PASS real minimap docking on M for stock and SexyMap, fixed layer restored, combat guards and toggle")
-- Installed Journal persists its "want World Map" choice across M sessions.
-- This mimics its OnShow/OnHide behavior and right-click detach.
local journalAttached,wantWorld,requests=false,false,0
local pendingRedraw={}
C_Timer={After=function(_,fn) pendingRedraw[#pendingRedraw+1]=fn end}
local function flushRedraw()
    local queue=pendingRedraw;pendingRedraw={}
    for _,fn in ipairs(queue) do fn() end
end
local function setJournalAttached(on)
    journalAttached=on
    if on then journal:Show() else journal:Hide() end
end
ForeverDungeonJournal_NS.CurrentDungeon=function() return "The Stockade" end
ForeverDungeonJournal_NS.L=function(k) return k=="WM_DUNGEON_MAP" and "Dungeon Map" or "World Map" end
ForeverDungeonJournal_NS.IsWorldMapOverlayAttached=function() return journalAttached end
ForeverDungeonJournalWorldMapToggle={
    IsShown=function() return WorldMapFrame:IsShown() end,
    IsEnabled=function() return true end,
    GetText=function() return wantWorld and "Dungeon Map" or "World Map" end,
    Click=function() requests=requests+1;wantWorld=not wantWorld;setJournalAttached(not wantWorld) end,
}
AT.db.dungeonMapMinimap=true
setJournalAttached(false)
WorldMapFrame:Show()
setJournalAttached(true);tick()
assert(requests==0 and not panel:IsShown() and Minimap.points[1][2]==journal)
-- Right-click detaches through the Journal, with WorldMapFrame still visible.
wantWorld=true;setJournalAttached(false);tick();restored()
assert(WorldMapFrame:IsShown() and not panel:IsShown() and not journalAttached and requests==0)
local beforeRedraw=blips
flushRedraw()
assert(blips==beforeRedraw+1,"refresh after other UI hide hooks settle")
tick()
assert(requests==0 and not journalAttached,"remain on world view until M is reopened")
WorldMapFrame:Hide()
WorldMapFrame:Show()
assert(not panel:IsShown(),"must never stack a second custom panel while Journal resets")
tick()
assert(journalAttached and requests==1 and not panel:IsShown() and Minimap.points[1][2]==journal)
WorldMapFrame:Hide();setJournalAttached(false);restored();flushRedraw()
print("PASS M reopen uses Journal switch; right-click restores minimap and leaves world view alone")

-- Ctrl drag on the actual M/Journal route, then close and reopen.
local control,leftDown=false,false
local cx,cy=860,220
IsControlKeyDown=function() return control end
IsMouseButtonDown=function(name) return name=="LeftButton" and leftDown end
GetCursorPosition=function() return cx,cy end
local originalCreate=CreateFrame
local grip
CreateFrame=function(kind,name,parent)
    if parent==Minimap then parent.children=parent.children or {} end
    local f=originalCreate(kind,name,parent)
    if name=="NQTDungeonMinimapDragArea" then grip=f;f.EnableMouse=function(self,v) self.mouse=v end;f.SetFrameStrata=function(self,v) self.strata=v end end
    return f
end
journal.GetLeft=function() return 100 end
journal.GetBottom=function() return 50 end
journal.GetEffectiveScale=function() return 1 end
journal:SetSize(900,650)
Minimap.GetLeft=function() return 800 end
Minimap.GetBottom=function() return 150 end
Minimap.GetWidth=function() return 140 end
Minimap.GetHeight=function() return 140 end
Minimap.GetEffectiveScale=function() return 1.5 end
local ground=true
C_Minimap={GetDrawGroundTextures=function()return ground end,SetDrawGroundTextures=function(v)ground=v end,GetUiMapID=function()return 225 end}
WorldMapFrame:Show();setJournalAttached(true);tick()
assert(grip and not grip.mouse,"normal click stays with minimap")
grip.scripts.OnMouseDown(grip,"LeftButton")
assert(not AT.db.dungeonMinimapDock)
leftDown=true;control=true
grip.scripts.OnUpdate(grip);assert(grip.mouse)
grip.scripts.OnMouseDown(grip,"LeftButton")
cx,cy=450,400
grip.scripts.OnUpdate(grip)
local spot=Minimap.points[1][2]
assert(spot~=journal and spot.parent==journal and spot.anchor[4]>8)
cx,cy=-2000,3000;grip.scripts.OnUpdate(grip)
grip.scripts.OnMouseUp(grip,"LeftButton")
assert(AT.db.dungeonMinimapDock.x==0 and AT.db.dungeonMinimapDock.y==1)
control=false;leftDown=false
grip.scripts.OnUpdate(grip);assert(not grip.mouse)
ground=false
WorldMapFrame:Hide();setJournalAttached(false);restored()
assert(ground and not grip.shown,"restore native ground and remove dock-only handler")
ground=false
flushRedraw()
assert(ground,"last hide hook must not leave ground disabled")
WorldMapFrame:Show();setJournalAttached(true);tick()
assert(Minimap.points[1][2]==spot and spot.anchor[4]==8 and spot.anchor[5]==432,"keep saved location on reopen")
journal:SetSize(700,500);tick()
assert(spot.anchor[4]==8 and spot.anchor[5]==282,"scaled and clamped when window changes")
HybridMinimap={IsShown=function() return true end}
ground=false
WorldMapFrame:Hide();setJournalAttached(false);flushRedraw();restored()
assert(ground==false,"do not change ground mode if Blizzard switched to Hybrid Minimap")
print("PASS Ctrl-drag, clamping, saved dock position, restore native ground, no Hybrid mode override")

-- The actual client's UIParent has screen geometry. Dock onto a
-- screen-root anchor that survives Journal closing before NQT runs.
UIParent.GetLeft=function() return 0 end
UIParent.GetBottom=function() return 0 end
UIParent.GetEffectiveScale=function() return .8 end
WorldMapFrame:Show();setJournalAttached(true);tick()
local pinned=Minimap.points[1][2]
assert(pinned.parent==UIParent and pinned.anchor[2]==UIParent,"safe anchor independent of Journal lifetime")
assert(math.abs(pinned.anchor[4]-135)<.01)
journal.GetLeft=function() return 180 end
tick();assert(math.abs(pinned.anchor[4]-235)<.01,"follow holder position changes")
wantWorld=true;setJournalAttached(false);tick()
restored()
WorldMapFrame:Hide();flushRedraw()
assert(AT.db.dungeonMinimapDock.x==0 and AT.db.dungeonMinimapDock.y==1,"drag placement unchanged")
print("PASS stable screen-root anchor, Journal detach restore, saved Ctrl-drag")

-- Exact active-profile shape only, after the native position is restored.
UnitNameUnmodified=function() return "Fixture","Player" end
RegionalUniqueNamesEnabled=function() return true end
SexyMap2DB={["Fixture Player"]="global",global={core={shape=130871}}}
local refreshes=0
Minimap.SetMaskTexture=function(_,id)
    assert(id==130871)
    restored()
    refreshes=refreshes+1
end
HybridMinimap=nil;ground=true
WorldMapFrame:Show();setJournalAttached(true);tick()
WorldMapFrame:Hide();setJournalAttached(false);flushRedraw()
assert(refreshes==1 and SexyMap2DB.global.core.shape==130871)
SlashCmdList.NQTMINIMAPCHECK()
assert(notice:find("mask refresh=yes",1,true) and notice:find("ground=on",1,true),notice)
WorldMapFrame:Show();setJournalAttached(true);tick()
SexyMap2DB.global.core.shape=130872
WorldMapFrame:Hide();setJournalAttached(false);flushRedraw()
assert(refreshes==1,"do not override a new shape")
print("PASS exact profile mask refresh after close, diagnostic report, no saved setting writes")

-- The opaque SexyMap background has a separate color from its frame edge.
local bgAlpha,edge=1,.9
SexyMapCustomBackdrop.IsShown=function() return true end
SexyMapCustomBackdrop.GetBackdropColor=function() return 0,0,0,bgAlpha end
SexyMapCustomBackdrop.SetBackdropColor=function(_,r,g,b,a)
    assert(r==0 and g==0 and b==0)
    bgAlpha=a
end
WorldMapFrame:Show();setJournalAttached(true);tick()
assert(SexyMapCustomBackdrop.alpha==0 and bgAlpha==1)
WorldMapFrame:Hide();setJournalAttached(false);flushRedraw();restored()
assert(SexyMapCustomBackdrop.alpha==.55 and bgAlpha==0 and edge==.9)
assert(SexyMap2DB.global.core.shape==130872,"saved profile unchanged")
SlashCmdList.NQTMINIMAPCHECK()
assert(notice:find("background uncovered=yes",1,true),notice)
print("PASS normal terrain uncovered without hiding frame edge or changing saved profile")
