local _, AT = ...
local panel, watcher, watchedMap
local shownKey, selectedFloor, sourceMode, pages, nativeID, renderedMap
local elapsed, leaving = 0, false

local function ordinary(v)
    return not issecretvalue or not issecretvalue(v)
end
local function usable(v, kind)
    return ordinary(v) and type(v) == kind
end
local function num(v)
    return usable(v, "number") and v == v and math.abs(v) < math.huge
end
local function positive(v)
    return num(v) and v > 0
end
local function mapID(v)
    return positive(v) and v % 1 == 0
end
local function safe(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end
local function field(t, key)
    local v = usable(t, "table") and t[key]
    if ordinary(v) then return v end
end
local function normalized(text)
    if not usable(text, "string") then return "" end
    return (strlower or string.lower)(text):gsub("’","'"):gsub("^the%s+","")
end

local function instance()
    local inside, kind = safe(IsInInstance)
    if not (usable(inside,"boolean") and inside == true and usable(kind,"string") and
        (kind == "party" or kind == "raid" or kind == "scenario" or kind == "pvp" or kind == "arena")) then return end
    if type(GetInstanceInfo) ~= "function" then return end
    local ok, name, _, _, _, _, _, _, instanceID = pcall(GetInstanceInfo)
    if not ok or not usable(name,"string") or name == "" then return end
    if not mapID(instanceID) then instanceID = nil end
    return name, instanceID, kind
end

local function currentPlayerMap()
    local m = safe(C_Map and C_Map.GetBestMapForUnit,"player")
    if mapID(m) then return m end
end

local function nativeMap(name, instanceID, kind)
    local map = currentPlayerMap()
    if not map then return end
    local info = safe(C_Map.GetMapInfo,map)
    local types = Enum and Enum.UIMapType
    local mt = field(info,"mapType")
    local label = field(info,"name")
    local canonical = safe(AT.ForeverDungeonName,instanceID,name) or name
    local dungeonType=types and types.Dungeon or 4
    local insideMap = mt == dungeonType
    if mt == (types and types.Micro or 5) then
        local parent=field(info,"parentMapID")
        while mapID(parent) and parent~=map do
            local parentInfo=safe(C_Map.GetMapInfo,parent)
            if field(parentInfo,"mapType")==dungeonType then insideMap=true;break end
            -- Do not walk into the outdoor hierarchy.
            break
        end
    end
    if not insideMap and mt == (types and types.Zone or 3) and
        (kind == "pvp" or kind == "arena" or normalized(label) == normalized(canonical)) then insideMap = true end
    if insideMap then return map end
end

local function clientPoint(map, token)
    if not mapID(map) or not C_Map then return end
    -- A different or unknown floor is not a projection onto this floor.
    local unitMap = safe(C_Map.GetBestMapForUnit, token)
    if not mapID(unitMap) or unitMap ~= map then return end
    -- Do not compare secret coordinates, guess a location, or send positions.
    local v = safe(C_Map.GetPlayerMapPosition,map,token)
    if not ordinary(v) or not v then return end
    local ok, x, y = pcall(function() return v:GetXY() end)
    if ok and num(x) and num(y) and x >= 0 and x <= 1 and y >= 0 and y <= 1 and (x~=0 or y~=0) then return x,y end
end
AT.GetDungeonPositionPoint = clientPoint

local function journalMaps(name, id)
    local journal = _G.ForeverDungeonJournal_NS
    if type(journal) ~= "table" or type(journal.DUNGEON_MAPS) ~= "table" then return end
    local scarlet
    if safe(journal.InScarletMonastery)==true then scarlet=safe(journal.ResolveScarletWing) end
    local key = scarlet or (journal.INSTANCE_ID_TO_DUNGEON and id and journal.INSTANCE_ID_TO_DUNGEON[id])
        or safe(journal.DungeonFromInstanceName,name) or safe(AT.ForeverDungeonName,id,name) or name
    local entry = journal.DUNGEON_MAPS[key]
    if not entry then
        local match
        for title in pairs(journal.DUNGEON_MAPS) do
            if normalized(title)==normalized(key) then
                if match then return end
                match=title
            end
        end
        if match then key=match;entry=journal.DUNGEON_MAPS[key] end
    end
    if safe(journal.IsDungeonLocked,key)==true or safe(journal.IsDungeonMapLocked,key)==true then return end
    if type(entry)=="table" and type(entry.floors)=="table" and #entry.floors>0 then return entry.floors,journal end
end

local function nativeArt(map)
    if not mapID(map) or not C_Map then return end
    local layers=safe(C_Map.GetMapArtLayers,map)
    if not usable(layers,"table") then return end
    for i,layer in ipairs(layers) do
        local w,h,tw,th=field(layer,"layerWidth"),field(layer,"layerHeight"),field(layer,"tileWidth"),field(layer,"tileHeight")
        if positive(w) and positive(h) and positive(tw) and positive(th) then
            local count=math.ceil(w/tw)*math.ceil(h/th)
            if count<=144 then
                local tiles=safe(C_Map.GetMapArtLayerTextures,map,i)
                if usable(tiles,"table") and #tiles==count then return tiles,w,h,tw,th end
            end
        end
    end
end

local function makeButton(parent,label,right,y,width,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(width,22);b:SetPoint("TOPRIGHT",parent,"TOPRIGHT",right,y)
    b:SetText(label);b:SetScript("OnClick",fn)
    return b
end

local function refreshDots()
    if not panel or not panel:IsShown() then return end
    local db=AT.db
    local total, possible=0,0
    for i=1,5 do
        local icon=panel.dots[i]
        local allowed=(i==1 and db.dungeonPositionShowSelf~=false) or
            (i>1 and db.dungeonPositionShowParty~=false and safe(UnitExists,"party"..(i-1))==true)
        local x,y
        if allowed then
            possible=possible+1
            if renderedMap then x,y=clientPoint(renderedMap,i==1 and "player" or ("party"..(i-1))) end
        end
        if x then
            total=total+1
            icon:ClearAllPoints()
            icon:SetPoint("CENTER",panel.art,"TOPLEFT",x*panel.art:GetWidth(),-y*panel.art:GetHeight())
            icon:Show()
        else icon:Hide() end
    end
    if not panel.hasArt then return end
    if possible==0 then panel.status:SetText("Position icons are off or no party member is available.")
    elseif not renderedMap then panel.status:SetText("Live coordinates are not available for this artwork.")
    elseif total==0 then panel.status:SetText("WoW is not exposing live positions on this floor.")
    elseif total<possible then panel.status:SetText("Only positions WoW exposes on this floor are shown.")
    else panel.status:SetText("Green: you   |   Blue: party") end
end

local function paint()
    if not panel or not panel:IsShown() then return end
    for _,t in ipairs(panel.tiles) do t:Hide() end
    renderedMap=nil
    panel.hasArt=false
    local f=sourceMode=="journal" and pages and pages[selectedFloor]
    local map=f and f.uiMapID or (not f and nativeID)
    local tiles,w,h,tw,th=nativeArt(map)
    local nativeAlignment=tiles~=nil
    local src,texRight,texBottom,aspect
    local journal=_G.ForeverDungeonJournal_NS
    if f and type(f.texture)=="string" then
        src,texRight,texBottom,aspect=f.texture,f.texRight or 1,f.texBottom or 1,f.aspect or 1.5
        tiles=nil
    elseif tiles then aspect=w/h
    elseif f and type(f.tiles)=="string" then
        tiles={}
        for i=1,12 do tiles[i]=f.tiles..i end
        w,h,tw,th,aspect=1002,668,256,256,1002/668
    elseif f then
        src=journal and safe(journal.MapArtCopy,f)
        if usable(src,"string") then texRight,texBottom,aspect=1002/1024,668/1024,1.5 end
    end
    local function tile(i)
        local t=panel.tiles[i]
        if not t then t=panel.art:CreateTexture(nil,"ARTWORK");panel.tiles[i]=t end
        t:ClearAllPoints()
        return t
    end
    if positive(aspect) then
        local aw=math.max(1,panel:GetWidth()-30)
        local ah=math.max(1,panel:GetHeight()-90)
        local width=math.min(aw,ah*aspect)
        panel.art:SetSize(width,width/aspect)
        if src then
            local t=tile(1)
            t:SetAllPoints(panel.art); t:SetTexCoord(0,texRight,0,texBottom)
            panel.hasArt=t:SetTexture(src)~=false
            if panel.hasArt then t:Show() end
        elseif tiles then
            local cols,ok=math.ceil(w/tw),true
            for i,file in ipairs(tiles) do
                local left,top=((i-1)%cols)*tw,math.floor((i-1)/cols)*th
                local cw,ch=math.min(tw,w-left),math.min(th,h-top)
                if cw<=0 or ch<=0 then break end
                local t=tile(i)
                t:SetPoint("TOPLEFT",panel.art,"TOPLEFT",left*width/w,-top*width/w)
                t:SetSize(cw*width/w,ch*width/w);t:SetTexCoord(0,cw/tw,0,ch/th)
                local valid=(usable(file,"string") or positive(file)) and t:SetTexture(file)~=false
                if valid then t:Show() else ok=false end
            end
            panel.hasArt=ok
            if ok and nativeAlignment then renderedMap=map end
            if not ok then
                for _,t in ipairs(panel.tiles) do t:Hide() end
                local backup=f and journal and safe(journal.MapArtCopy,f)
                if usable(backup,"string") then
                    local t=tile(1);t:SetAllPoints(panel.art);t:SetTexCoord(0,1002/1024,0,668/1024)
                    panel.hasArt=t:SetTexture(backup)~=false
                    if panel.hasArt then t:Show() end
                end
            end
        end
    end
    local floorCount=pages and #pages or 0
    local multiple=sourceMode=="journal" and floorCount>1
    panel.prev:SetShown(multiple);panel.next:SetShown(multiple)
    panel.native:SetShown(pages~=nil and nativeArt(nativeID)~=nil)
    panel.title:SetWidth(math.max(40,panel:GetWidth()-280))
    panel.native:SetText(sourceMode=="journal" and "Game map" or "Journal map")
    local caption = f and f.label
    if not usable(caption,"string") then caption=multiple and ("Floor "..selectedFloor.." / "..floorCount) or "" end
    panel.floor:SetText(caption)
    panel.missing:SetShown(not panel.hasArt)
    if not panel.hasArt then
        panel.missing:SetText("No floor map is available from this client.\nIf your Dungeon Journal has this map, enable it and reopen the map.")
        panel.status:SetText("No locations are shown without a matching floor map.")
    end
    refreshDots()
end

local function journalOwnsWorldMap()
    local journal=_G.ForeverDungeonJournal_NS
    local journalFrame=_G.ForeverDungeonJournalFrame
    if type(journal)~="table" or not journalFrame or not journalFrame.dungeonMapPanel then return false end
    local ui=journalFrame.dungeonMapPanel
    if safe(ui.IsVisible,ui)~=true then return false end
    for _=1,9 do
        ui=safe(ui.GetParent,ui)
        if not ui then return false end
        if ui==watchedMap then return true end
    end
    return false
end

local function showCurrent()
    if not (AT.db and AT.db.enabled~=false and AT.db.dungeonPositionEnabled~=false) then return false end
    local name,id,kind=instance()
    if not name or not panel or not watchedMap or not watchedMap:IsShown() then return false end
    -- When Dungeon Journal already supplies the map in this very window,
    -- leave its controls and view alone; never create competing overlays.
    if journalOwnsWorldMap() then panel:Hide();return true end
    local key=id or name
    local refreshedPages=journalMaps(name,id)
    local nmap=nativeMap(name,id,kind)
    if shownKey~=key or (not pages and refreshedPages) then
        selectedFloor,sourceMode=1,refreshedPages and "journal" or "native"
        for i,floor in ipairs(refreshedPages or {}) do
            if nmap and floor.uiMapID==nmap then selectedFloor=i;break end
        end
    end
    if not refreshedPages then sourceMode="native" end
    if selectedFloor>(refreshedPages and #refreshedPages or 1) then selectedFloor=1 end
    shownKey,pages,nativeID=key,refreshedPages,nmap
    panel.title:SetText(name)
    panel:Show()
    paint()
    return true
end

local function attach()
    local map=_G.WorldMapFrame
    if not map or watchedMap or type(map.HookScript)~="function" then return end
    watchedMap=map
    panel=CreateFrame("Frame",nil,map)
    panel:SetPoint("TOPLEFT",map,"TOPLEFT",7,-33)
    panel:SetPoint("BOTTOMRIGHT",map,"BOTTOMRIGHT",-7,8)
    panel:SetFrameLevel(map:GetFrameLevel()+70)
    panel:EnableMouse(true);panel:EnableMouseWheel(true);panel:Hide()
    local bg=panel:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(.035,.043,.053,1)
    panel.title=panel:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");panel.title:SetPoint("TOPLEFT",12,-10)
    panel.title:SetJustifyH("LEFT");panel.title:SetWordWrap(false)
    panel.floor=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");panel.floor:SetPoint("TOPLEFT",13,-36)
    panel.status=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");panel.status:SetPoint("BOTTOM",0,12)
    panel.art=CreateFrame("Frame",nil,panel);panel.art:SetSize(1,1);panel.art:SetPoint("CENTER",0,-9)
    panel.missing=panel:CreateFontString(nil,"OVERLAY","GameFontHighlight");panel.missing:SetPoint("CENTER")
    panel.missing:SetWidth(330);panel.missing:SetWordWrap(true)
    panel.tiles,panel.dots={},{}
    for i=1,5 do
        local dot=panel.art:CreateTexture(nil,"OVERLAY")
        dot:SetTexture("Interface\\Buttons\\WHITE8X8");dot:SetSize(i==1 and 11 or 8,i==1 and 11 or 8)
        if i==1 then dot:SetVertexColor(.25,1,.53) else dot:SetVertexColor(.28,.67,1) end
        dot:Hide();panel.dots[i]=dot
    end
    panel.back=makeButton(panel,"World Map",-9,-8,90,function() panel:Hide() end)
    panel.native=makeButton(panel,"Game map",-104,-8,92,function()
        sourceMode=sourceMode=="journal" and "native" or "journal";paint()
    end)
    panel.next=makeButton(panel,">",-201,-8,28,function()
        if pages then selectedFloor=selectedFloor%#pages+1;paint() end
    end)
    panel.prev=makeButton(panel,"<",-234,-8,28,function()
        if pages then selectedFloor=(selectedFloor-2)%#pages+1;paint() end
    end)
    panel:SetScript("OnSizeChanged",paint)
    panel:SetScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt
        if elapsed>=.23 then
            elapsed=0
            if journalOwnsWorldMap() then panel:Hide();return end
            if sourceMode=="native" then
                local name,id,kind=instance()
                local m=name and nativeMap(name,id,kind)
                if m~=nativeID then nativeID=m;paint();return end
            end
            refreshDots()
        end
    end)
    map:HookScript("OnShow",function()
        if not leaving and AT.db and AT.db.dungeonPositionAutoOpen~=false then showCurrent() end
    end)
    map:HookScript("OnHide",function() panel:Hide() end)
end

function AT.RefreshDungeonPosition()
    attach()
    if not panel then return end
    if not AT.db or AT.db.enabled==false or AT.db.dungeonPositionEnabled==false or not instance() then
        panel:Hide();return
    end
    if panel:IsShown() then showCurrent() end
end

function AT.OpenDungeonPositionMap()
    if not (AT.db and AT.db.enabled~=false and AT.db.dungeonPositionEnabled~=false) then
        if AT.Say then AT.Say("Enable Dungeon Position to open this map.") end
        return false
    end
    if not instance() then
        if AT.Say then AT.Say("Enter a dungeon or instance to open its map.") end
        return false
    end
    attach()
    if not watchedMap or not watchedMap:IsShown() then
        leaving=true
        safe(ToggleWorldMap)
        leaving=false
        attach()
    end
    return showCurrent()
end

function AT.InitDungeonPosition()
    attach()
    if watcher then return end
    if watchedMap and watchedMap:IsShown() and AT.db and AT.db.dungeonPositionAutoOpen~=false then showCurrent() end
    watcher=CreateFrame("Frame")
    for _,event in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","PLAYER_MAP_CHANGED","GROUP_ROSTER_UPDATE"}) do
        pcall(watcher.RegisterEvent,watcher,event)
    end
    watcher:SetScript("OnEvent",function(_,event,addon)
        if event=="ADDON_LOADED" and addon~="Blizzard_WorldMap" and addon~="ForeverDungeonJournal" then return end
        attach()
        if not panel or not watchedMap:IsShown() then return end
        local name,id=instance()
        if not name then panel:Hide();shownKey=nil;return end
        if panel:IsShown() or (event=="PLAYER_ENTERING_WORLD" and (id or name)~=shownKey and
            AT.db and AT.db.dungeonPositionAutoOpen~=false) then showCurrent() end
    end)
end
