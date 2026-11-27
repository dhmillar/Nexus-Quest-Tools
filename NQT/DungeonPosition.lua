local _, AT = ...
local panel, watcher, watchedMap
local shownKey, selectedFloor, sourceMode, pages, nativeID, renderedMap
local elapsed, leaving = 0, false
local journalDots, journalArmed, journalElapsed = nil, false, 0
local journalPins, panelPins = {}, {}
local journalLocation, journalGameMap, preferGame
local panelRoom, journalRoom, panelAtlas
local showCurrent,explicitMap
local stockZoneKnown,previousInstance,stockLandmark
local journalStock, panelStock, journalEntrance, panelEntrance, panelStockArt
-- Blizzard legacy texture file IDs for the 1002x668 Stockade floor (225),
-- corroborated by the Forever map inventory in OpenMap.
local stockTiles={455959,455963,455964,455965,455966,455967,455968,455969,455970,455960,455961,455962}
local stockBossEncounters={[2757]="Kam Deepfury",[2758]="Hamhock",
    [2759]="Dextren Ward",[2760]="Bazil Thredd"}
local nativePolicy, hideNativePins, showNativePins
local bossSighting

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

-- These are the public text values used by the game UI. A label is not
-- a coordinate and can be the same across an entire dungeon.
local function readableLabel(fn)
    local text=safe(fn)
    if not usable(text,"string") or #text>128 or text:find("[%c|]") then return end
    text=text:match("^%s*(.-)%s*$")
    if text~="" then return text end
end

local function dungeonLocationStatus(instanceName)
    local zone=readableLabel(GetZoneText)
    local subzone=readableLabel(GetSubZoneText)
    local minimap=readableLabel(GetMinimapZoneText)
    local base,main=normalized(instanceName),normalized(zone)
    local function distinct(text)
        local key=normalized(text)
        return key~="" and key~=base and key~=main
    end
    if distinct(subzone) then return "Approx. area: "..subzone,"subzone" end
    if distinct(minimap) then return "Approx. area: "..minimap,"minimap" end
    if subzone or minimap or zone then return "WoW reports only the zone, not a room." end
    return "WoW is not exposing a readable location label."
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
    if mapID(unitMap) and unitMap~=map then return end
    if not mapID(unitMap) then
        local _, id, kind=instance()
        -- This instance has one known floor. If the official position API
        -- answers on this exact map, an absent BestMap result is not a veto.
        if token~="player" or id~=34 or kind~="party" or map~=225 then return end
    end
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
    if type(entry)=="table" and type(entry.floors)=="table" and #entry.floors>0 then return entry.floors,journal,key end
end

-- Kept only for the current session. A marked boss is not a player position.
local function recordBossSighting(id, label)
    if not mapID(id) or not usable(label,"string") or #label>85 or label:find("[%c|]") then return end
    local at=safe(GetTime)
    if not num(at) then return end
    local close=safe(CheckInteractDistance,"target",3)
    bossSighting={id=id,label=label,at=at,close=usable(close,"boolean") and close==true}
end

local function currentSighting(id)
    if not (AT.db and AT.db.dungeonPositionEnabled~=false and AT.db.dungeonPositionShowSelf~=false) then return end
    if not bossSighting or bossSighting.id~=id then return end
    local t=safe(GetTime)
    if num(t) and t>=bossSighting.at and t-bossSighting.at<=30 then return bossSighting end
end

local function bossSightingPoint(name,id,map,sighting)
    if not sighting or not mapID(map) or nativePolicy(map)==false then return end
    local floors,journal,key=journalMaps(name,id)
    if not floors then return end
    local matches=0
    for _,floor in ipairs(floors) do
        if field(floor,"uiMapID")==map then matches=matches+1 end
    end
    if matches~=1 then return end
    local bosses=field(field(journal.DUNGEON_MAPS,key),"bosses")
    if not usable(bosses,"table") then return end
    local pin,expected=nil,normalized(sighting.label)
    for _,b in ipairs(bosses) do
        local boss=field(b,"name")
        local localized=safe(journal.LocalizeBossName,boss)
        if normalized(boss)==expected or normalized(localized)==expected then
            if pin or field(b,"alt")==true then return end
            pin=b
        end
    end
    local floor,x,y=field(pin,"floor"),field(pin,"x"),field(pin,"y")
    if floor==nil and #floors==1 then floor=1 end
    if mapID(floor) and field(floors[floor],"uiMapID")==map and num(x) and num(y) and x>0 and x<1 and y>0 and y<1 then
        return x,y
    end
end

local function bossSightingText(sighting)
    return (sighting.close and "Boss sighting (close): " or "Boss sighting: ")..sighting.label
        .." (not your position)"
end

-- Stockade has no named rooms. Use public portal/encounter events and the
-- installed Journal's landmarks. This is not a live coordinate or heading.
local function stockSignal(event,value,second)
    local _,id,kind=instance()
    if event=="PLAYER_ENTERING_WORLD" or event=="ZONE_CHANGED_NEW_AREA" or
        event=="PLAYER_DEAD" or event=="PLAYER_ALIVE" or event=="PLAYER_UNGHOST" then
        bossSighting=nil
    end
    if event=="PLAYER_ENTERING_WORLD" or event=="ZONE_CHANGED_NEW_AREA" then
        if id~=34 or kind~="party" then stockLandmark=nil end
        if event=="PLAYER_ENTERING_WORLD" and (value==true or second==true) then
            stockLandmark=nil
        elseif stockZoneKnown and not previousInstance and id==34 and kind=="party" then
            stockLandmark={at=safe(GetTime),entrance=true}
        end
        stockZoneKnown,previousInstance=true,id
    elseif event=="ENCOUNTER_START" and id==34 and kind=="party" and mapID(value) and stockBossEncounters[value] then
        stockLandmark={at=safe(GetTime),boss=stockBossEncounters[value]}
    elseif event=="PLAYER_DEAD" or event=="PLAYER_ALIVE" or event=="PLAYER_UNGHOST" then
        stockLandmark=nil
    end
end

local function stockPoint(name,id,map)
    if id~=34 or map~=225 or nativePolicy(map)==false or not stockLandmark then return end
    local time,at=safe(GetTime),stockLandmark.at
    if not num(time) or not num(at) or time<at or time-at>(stockLandmark.entrance and 12 or 25) then return end
    local floors,journal,key=journalMaps(name,id)
    if not floors or #floors~=1 or field(floors[1],"uiMapID")~=map then return end
    local data=field(journal.DUNGEON_MAPS,key)
    local loc
    if stockLandmark.entrance then
        loc=field(data,"entrance")
    else
        local bosses=field(data,"bosses")
        if not usable(bosses,"table") then return end
        local expected=normalized(stockLandmark.boss)
        for _,pin in ipairs(bosses) do
            if normalized(field(pin,"name"))==expected then
                if loc or field(pin,"alt")==true then return end
                loc=pin
            end
        end
    end
    local floor,x,y=field(loc,"floor"),field(loc,"x"),field(loc,"y")
    if (floor==nil or floor==1) and num(x) and num(y) and x>0 and x<1 and y>0 and y<1 then
        return x,y,stockLandmark.boss and ("Near "..stockLandmark.boss.." at pull") or "Entrance on arrival"
    end
end

local function updateStockLandmark(old,holder,map,name,id,hasExact)
    if old then old:Hide() end
    if not (holder and name and AT.db.dungeonPositionShowSelf~=false and not hasExact) then return old end
    local sighting=currentSighting(id)
    local x,y=bossSightingPoint(name,id,map,sighting)
    local label
    if x then label=bossSightingText(sighting) else x,y,label=stockPoint(name,id,map) end
    local w,h=safe(holder.GetWidth,holder),safe(holder.GetHeight,holder)
    if not x or not positive(w) or not positive(h) then return old end
    if not old or old:GetParent()~=holder then
        old=CreateFrame("Frame",nil,holder)
        old:EnableMouse(false)
        if holder.GetFrameLevel and old.SetFrameLevel then old:SetFrameLevel(holder:GetFrameLevel()+30) end
        old:SetSize(26,26)
        local mark=old:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        mark:SetPoint("CENTER");mark:SetTextColor(1,.83,.44,1)
        old.nqtLandmarkMark=mark
    end
    old:ClearAllPoints()
    old:SetPoint("CENTER",holder,"TOPLEFT",x*w,-y*h)
    old.nqtLandmarkMark:SetText(sighting and label==bossSightingText(sighting) and "!" or "~")
    old:Show()
    return old,label
end

-- Static floor landmark, not a player position or a recent arrival.
-- Matches the installed Forever Dungeon Journal's floor-1 entrance.
local function updateStockEntrance(old,holder)
    if old then old:Hide() end
    if not holder or nativePolicy(225)==false then return old end
    local w,h=safe(holder.GetWidth,holder),safe(holder.GetHeight,holder)
    if not positive(w) or not positive(h) then return old end
    if not old or old:GetParent()~=holder then
        old=CreateFrame("Frame",nil,holder)
        old:EnableMouse(false)
        if holder.GetFrameLevel and old.SetFrameLevel then old:SetFrameLevel(holder:GetFrameLevel()+8) end
        old:SetSize(74,20)
        local back=old:CreateTexture(nil,"BACKGROUND")
        back:SetAllPoints(old);back:SetColorTexture(.04,.09,.12,.90)
        local label=old:CreateFontString(nil,"OVERLAY","GameFontNormal")
        label:SetPoint("CENTER");label:SetTextColor(.67,.91,1,1);label:SetText("Entrance")
    end
    old:ClearAllPoints()
    old:SetPoint("TOP",holder,"TOPLEFT",.5*w,-.815*h-8)
    old:Show()
    return old
end

local function nativeArt(map,firstOnly)
    if not mapID(map) or not C_Map then return end
    local function legacyStock()
        local _,id,kind=instance()
        if map==225 and id==34 and kind=="party" then return stockTiles,1002,668,256,256 end
    end
    local layers=safe(C_Map.GetMapArtLayers,map)
    if not usable(layers,"table") then return legacyStock() end
    for i,layer in ipairs(layers) do
        if firstOnly and i~=1 then break end
        local w,h,tw,th=field(layer,"layerWidth"),field(layer,"layerHeight"),field(layer,"tileWidth"),field(layer,"tileHeight")
        if positive(w) and positive(h) and positive(tw) and positive(th) then
            local count=math.ceil(w/tw)*math.ceil(h/th)
            if count<=144 then
                local tiles=safe(C_Map.GetMapArtLayerTextures,map,i)
                if usable(tiles,"table") and #tiles==count then return tiles,w,h,tw,th end
            end
        end
    end
    return legacyStock()
end

-- Selected Deadmines geometry from Forever Dungeon Routes (Checkov23).
-- Normalized against the 1002x668 native atlas with the exact tile order below.
local deadminesRooms = {
    [291]={label="Mast Room",x=.4806,y=.8727,w=117,h=95.7,
        tiles={449591,449595,449596,449597,449598,449599,449600,449601,449602,449592,449593,449594}},
    [292]={label="Ironclad Cove",x=.5824,y=.3895,w=225,h=272.8,
        tiles={449603,449607,449608,449609,449610,449611,449612,449613,449614,449604,449605,449606}},
}
local function calibratedAtlas(map,tiles,w,h,tw,th)
    local d=deadminesRooms[map]
    if not (d and tiles and w==1002 and h==668 and tw==256 and th==256 and #tiles==12) then return end
    for i,expected in ipairs(d.tiles) do
        if not mapID(tiles[i]) or tiles[i]~=expected then return end
    end
    return true
end
local function namedDeadminesFloor(id)
    if id~=36 then return end
    local sub=normalized(readableLabel(GetSubZoneText))
    local mini=normalized(readableLabel(GetMinimapZoneText))
    local zone=normalized(readableLabel(GetZoneText))
    local function agrees(value, key)
        return value=="" or value==key or value=="deadmines" or value==zone
    end
    for map,d in pairs(deadminesRooms) do
        local key=normalized(d.label)
        if (sub==key or mini==key or zone==key) and agrees(sub,key) and agrees(mini,key) then
            local current=currentPlayerMap()
            local info=current and safe(C_Map and C_Map.GetMapInfo,current)
            local mt=field(info,"mapType")
            local types=Enum and Enum.UIMapType
            if current and current~=map and (deadminesRooms[current] or mt==(types and types.Dungeon or 4)
                or (mt==(types and types.Micro or 5) and field(info,"parentMapID")~=map)) then return end
            return map
        end
    end
end
local function calibratedFloor(id)
    local map=namedDeadminesFloor(id)
    if map and nativePolicy(map)~=false and calibratedAtlas(map,nativeArt(map,true)) then return map end
end

-- When the client doesn't name a current floor, the installed Journal can
-- still identify a single exact floor for this instance. Never select an
-- arbitrary floor of a multi-floor instance or override contrary map info.
local function resolveNativeMap(name,id,kind,floors)
    local map=calibratedFloor(id) or nativeMap(name,id,kind)
    if map then return map end
    local candidate=floors and #floors==1 and field(floors[1],"uiMapID")
    if not floors and not mapID(candidate) and id==34 and kind=="party" then candidate=225 end
    if not mapID(candidate) then return end
    local reported=currentPlayerMap()
    if reported and reported~=candidate then return end
    if id==34 and kind=="party" and candidate==225 and nativeArt(candidate,true) then return candidate end
    local info=safe(C_Map and C_Map.GetMapInfo,candidate)
    local dungeonType=Enum and Enum.UIMapType and Enum.UIMapType.Dungeon or 4
    if field(info,"mapType")==dungeonType and nativeArt(candidate,true) then return candidate end
end

local function makeButton(parent,label,right,y,width,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(width,22);b:SetPoint("TOPRIGHT",parent,"TOPRIGHT",right,y)
    b:SetText(label);b:SetScript("OnClick",fn)
    return b
end

local function setLocation(frame, value)
    if not frame then return end
    if value and frame.current~=value then frame.text:SetText(value);frame.current=value end
    frame:SetShown(value~=nil)
end

local function makeLocation(owner)
    local frame=CreateFrame("Frame",nil,owner)
    frame:SetPoint("TOPLEFT",owner,"TOPLEFT",10,-35)
    frame:SetPoint("RIGHT",owner,"RIGHT",-10,0)
    frame:SetHeight(28)
    frame:EnableMouse(false);frame:EnableMouseWheel(false)
    local text=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    text:SetPoint("TOPLEFT",frame,"TOPLEFT",7,-2)
    text:SetPoint("RIGHT",frame,"RIGHT",-7,0)
    text:SetJustifyH("LEFT");text:SetWordWrap(true)
    text:SetTextColor(.78,.94,1)
    frame.text=text
    frame:Hide()
    return frame
end

local function isDirectRoom(roomMap,floorMap)
    if not (mapID(roomMap) and mapID(floorMap) and roomMap~=floorMap and C_Map) then return end
    local room=safe(C_Map.GetMapInfo,roomMap)
    local micro=Enum and Enum.UIMapType and Enum.UIMapType.Micro or 5
    if field(room,"parentMapID")==floorMap and field(room,"mapType")==micro then return room end
end

-- Room containment, not coordinates of a player. Accept only a unique,
-- public label on a registered micro map directly under this exact floor.
local function clientRoomBounds(map,instanceName)
    if not C_Map or not mapID(map) or nativePolicy(map)==false then return end
    local sub,mini,zone=readableLabel(GetSubZoneText),readableLabel(GetMinimapZoneText),readableLabel(GetZoneText)
    local keys={}
    for _,label in pairs({sub,mini}) do
        local key=normalized(label)
        if key~="" and key~=normalized(instanceName) and key~=normalized(zone) then keys[key]=true end
    end
    if not next(keys) then return end
    local current=currentPlayerMap()
    if current and current~=map and not isDirectRoom(current,map) then return end
    local micro=Enum and Enum.UIMapType and Enum.UIMapType.Micro or 5
    local children=safe(C_Map.GetMapChildrenInfo,map,micro,false)
    local candidates={}
    if usable(children,"table") then
        for i,child in ipairs(children) do
            if i>100 then return end
            local id=field(child,"mapID")
            if mapID(id) then candidates[id]=true end
        end
    end
    if isDirectRoom(current,map) then candidates[current]=true end
    local found, label
    for id in pairs(candidates) do
        local room=isDirectRoom(id,map)
        local name=field(room,"name")
        if room and keys[normalized(name)] then
            if found then return end
            found,label=id,name
        end
    end
    if not found or (current and current~=map and current~=found)
        or type(C_Map.GetMapRectOnMap)~="function" then return end
    local ok,l,r,t,b=pcall(C_Map.GetMapRectOnMap,found,map)
    if not ok or not (num(l) and num(r) and num(t) and num(b)
        and l>=0 and r<=1 and t>=0 and b<=1 and l<r and t<b
        and (r-l)*(b-t)<.7) then return end
    return l,r,t,b,label
end

local function roomBounds(map,name,atlas)
    local l,r,t,b,label=clientRoomBounds(map,name)
    if l then return l,r,t,b,label end
    if not atlas or nativePolicy(map)==false then return end
    local _,id=instance()
    if namedDeadminesFloor(id)~=map then return end
    local d=deadminesRooms[map]
    if not d then return end
    -- The bounding rectangle highlights a room, not an exact player position.
    local c,s=math.cos(.01759),math.sin(.01759)
    local dx=(c*d.w+s*d.h)/2004
    local dy=(s*d.w+c*d.h)/1336
    return d.x-dx,d.x+dx,d.y-dy,d.y+dy,d.label
end

local function updateRoom(old,holder,map,name,hasExact,atlas)
    if old then old:Hide() end
    if not (holder and name and AT.db.dungeonPositionShowSelf~=false and not hasExact) then return old end
    local l,r,t,b,label=roomBounds(map,name,atlas)
    local w,h=safe(holder.GetWidth,holder),safe(holder.GetHeight,holder)
    if not l or not positive(w) or not positive(h) then return old end
    if not old or old:GetParent()~=holder then
        old=CreateFrame("Frame",nil,holder)
        old:EnableMouse(false)
        if holder.GetFrameLevel and old.SetFrameLevel then old:SetFrameLevel(holder:GetFrameLevel()+5) end
        local area=old:CreateTexture(nil,"OVERLAY")
        area:SetColorTexture(.95,.60,.17,.32)
        area:SetAllPoints(old)
        local mark=old:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        mark:SetPoint("CENTER",old,"CENTER",0,0)
        mark:SetTextColor(1,.82,.40,1)
        mark:SetText("~")
    end
    old:ClearAllPoints()
    old:SetPoint("TOPLEFT",holder,"TOPLEFT",l*w,-t*h)
    old:SetSize((r-l)*w,(b-t)*h)
    old:Show()
    return old,label
end

local function refreshDots()
    if not panel or not panel:IsShown() then return end
    local db=AT.db
    local total, possible,selfExact,missing=0,0,false,{}
    for i=1,5 do
        local icon=panel.dots[i]
        local allowed=(i==1 and db.dungeonPositionShowSelf~=false) or
            (i>1 and db.dungeonPositionShowParty~=false and safe(UnitExists,"party"..(i-1))==true)
        local x,y
        if allowed then
            possible=possible+1
            if renderedMap and nativePolicy(renderedMap)~=false then
                local token=i==1 and "player" or ("party"..(i-1))
                x,y=clientPoint(renderedMap,token)
                local reported=safe(C_Map.GetBestMapForUnit,token)
                if not x and (not mapID(reported) or reported==renderedMap) then missing[#missing+1]=token end
            end
        end
        if x then
            total=total+1
            if i==1 then selfExact=true end
            icon:ClearAllPoints()
            icon:SetPoint("CENTER",panel.art,"TOPLEFT",x*panel.art:GetWidth(),-y*panel.art:GetHeight())
            icon:Show()
        else icon:Hide() end
    end
    local nativeActive=showNativePins(panelPins,panel.art,renderedMap,missing)
    local name,id=instance()
    local roomLabel,stockLabel
    panelEntrance=updateStockEntrance(panelEntrance,id==34 and panelStockArt and panel.art)
    panelStock,stockLabel=updateStockLandmark(panelStock,panel.art,renderedMap,name,id,selfExact)
    panelRoom,roomLabel=updateRoom(panelRoom,panel.art,renderedMap,name,selfExact,panelAtlas)
    local area=name and db.dungeonPositionShowSelf~=false and not selfExact
        and (currentSighting(id) and bossSightingText(currentSighting(id)) or roomLabel and ("Approx. room: "..roomLabel)
            or stockLabel and ("Last known (approx.): "..stockLabel) or dungeonLocationStatus(name)) or nil
    setLocation(panel.location,area)
    if not panel.hasArt then return end
    if possible==0 then panel.status:SetText("Position icons are off or no party member is available.")
    elseif not renderedMap then panel.status:SetText("Live coordinates are not available for this artwork.")
    elseif nativePolicy(renderedMap)==false then panel.status:SetText("WoW hides position icons on this floor.")
    elseif nativeActive then panel.status:SetText("Live markers are drawn by WoW when available on this floor.")
    elseif total==0 then panel.status:SetText("WoW is not exposing live positions on this floor.")
    elseif total<possible then panel.status:SetText("Only positions WoW exposes on this floor are shown.")
    else panel.status:SetText("Green: you   |   Blue: party") end
end

local function paint()
    if not panel or not panel:IsShown() then return end
    for _,t in ipairs(panel.tiles) do t:Hide() end
    renderedMap,panelAtlas,panelStockArt=nil,nil,nil
    panel.hasArt=false
    local f=sourceMode=="journal" and pages and pages[selectedFloor]
    local map=f and f.uiMapID or (not f and nativeID)
    local tiles,w,h,tw,th=nativeArt(map)
    if explicitMap and map==225 then tiles,w,h,tw,th=stockTiles,1002,668,256,256 end
    local nativeAlignment=tiles~=nil
    local atlas=calibratedAtlas(map,tiles,w,h,tw,th)
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
            if ok and nativeAlignment then
                renderedMap,panelAtlas=map,atlas
                if map==225 and w==1002 and h==668 and tw==256 and th==256 and #tiles==#stockTiles then
                    panelStockArt=true
                    for i,file in ipairs(stockTiles) do
                        if file~=tiles[i] then panelStockArt=nil;break end
                    end
                end
            end
            if not ok then
                for _,t in ipairs(panel.tiles) do t:Hide() end
                local backup=f and journal and safe(journal.MapArtCopy,f)
                if not backup and explicitMap and map==225 and journal and pages and #pages==1
                    and field(pages[1],"uiMapID")==225 then
                    local copy=safe(journal.MapArtCopy,pages[1])
                    if copy=="Interface\\AddOns\\ForeverDungeonJournal\\Media\\Maps\\TheStockade1" then backup=copy end
                end
                if usable(backup,"string") then
                    local t=tile(1);t:SetAllPoints(panel.art);t:SetTexCoord(0,1002/1024,0,668/1024)
                    panel.hasArt=t:SetTexture(backup)~=false
                    if panel.hasArt then
                        t:Show()
                        if explicitMap and map==225 and backup=="Interface\\AddOns\\ForeverDungeonJournal\\Media\\Maps\\TheStockade1" then
                            renderedMap,panelStockArt=225,true
                        end
                    end
                end
            end
        end
    end
    local floorCount=pages and #pages or 0
    local multiple=sourceMode=="journal" and floorCount>1
    panel.prev:SetShown(multiple);panel.next:SetShown(multiple)
    panel.native:SetShown(not (explicitMap and map==225) and not preferGame and pages~=nil and nativeArt(nativeID)~=nil)
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

local function visibleJournal()
    local journal=_G.ForeverDungeonJournal_NS
    local frame=_G.ForeverDungeonJournalFrame
    local ui=frame and frame.dungeonMapPanel
    if type(journal)=="table" and ui and safe(ui.IsVisible,ui)==true then return frame end
end

local function journalOwnsWorldMap()
    local frame=visibleJournal()
    if not frame or not watchedMap then return false end
    local ui=frame.dungeonMapPanel
    for _=1,9 do
        ui=safe(ui.GetParent,ui)
        if not ui then return false end
        if ui==watchedMap then return true,frame end
    end
    return false
end

hideNativePins=function(state)
    if state.frame then state.frame:Hide() end
    state.key=nil
end

nativePolicy=function(map)
    if not mapID(map) then return end
    local getInfo=C_Map and C_Map.GetMapDisplayInfo
    if type(getInfo)~="function" then return nil end
    local ok,flag=pcall(getInfo,map)
    if not ok or not ordinary(flag) then return nil end
    if type(flag)=="boolean" then return not flag end
    if flag==nil then return nil,"no hide flag" end
end

-- Let WoW position the icons on a verified floor; never read back the
-- renderer's positions, intercept the minimap, or override its hide flag.
showNativePins=function(state,holder,map,units)
    local rule,detail=nativePolicy(map)
    local _,instanceID,kind=instance()
    -- A successful empty reply is distinct from a restricted or failed query.
    -- Test this only in Stockade, and only when the caller matched floor art.
    local stockadeDefault=map==225 and instanceID==34 and kind=="party" and detail=="no hide flag"
    if #units==0 or (rule~=true and not stockadeDefault) then
        hideNativePins(state)
        state.phase=not mapID(map) and "unmatched artwork"
            or (rule==false and "client hides icons" or (rule==nil and "unknown icon policy" or "no eligible units"))
        return false
    end
    local nativePins=state.frame
    if not nativePins then
        nativePins=safe(CreateFrame,"UnitPositionFrame",nil,holder)
        if not nativePins then state.phase="frame creation failed";return false end
        state.frame=nativePins
        nativePins:Hide()
        nativePins:EnableMouse(false)
        nativePins:EnableMouseWheel(false)
    end
    local key=map..":"..table.concat(units,",")
    if nativePins:GetParent()~=holder or state.key~=key then
        hideNativePins(state)
        local ok=pcall(function()
            if nativePins:GetParent()~=holder then nativePins:SetParent(holder) end
            nativePins:ClearAllPoints()
            nativePins:SetAllPoints(holder)
            if holder.GetFrameLevel and nativePins.SetFrameLevel then
                nativePins:SetFrameLevel(holder:GetFrameLevel()+10)
            end
            state.phase="set floor failed"
            nativePins:SetUiMapID(map)
            state.phase="unit registration failed"
            nativePins:ClearUnits()
            for _,unit in ipairs(units) do
                local player=unit=="player"
                if player then nativePins:AddUnit(unit,"UI-WorldMapArrow",18,18,.35,1,.61,1,7,true)
                else nativePins:AddUnit(unit,"WhiteCircle-RaidBlips",11,11,.38,.71,1,1,6,false) end
            end
            state.phase="finalize failed"
            nativePins:FinalizeUnits()
        end)
        if not ok then return false end
        state.key=key
    end
    nativePins:Show()
    state.phase="layer started (icon drawing not measurable)"
    return true
end

local function hideJournalDots()
    hideNativePins(journalPins)
    if journalRoom then journalRoom:Hide() end
    if journalStock then journalStock:Hide() end
    if journalEntrance then journalEntrance:Hide() end
    setLocation(journalLocation,nil)
    if journalGameMap then journalGameMap:Hide() end
    if journalDots then
        journalDots:Hide()
        for _,dot in ipairs(journalDots.dots) do dot:Hide() end
    end
end

local function stockAtlasMatches(frame,holder,displayed,floor)
    if frame.dungeonMapArtMissing or frame.dungeonMapFloor~=1 or field(floor,"uiMapID")~=225
        or field(floor,"tiles")~="Interface\\WorldMap\\TheStockade\\TheStockade1_" then return end
    local w,h=safe(holder.GetWidth,holder),safe(holder.GetHeight,holder)
    if not positive(w) or not positive(h) or math.abs(w/h-1.5)>.02 then return end
    if frame.dungeonMapArtCopy then
        local tex=displayed[1]
        local file=tex and safe(tex.GetTexture,tex)
        local expected="interface\\addons\\foreverdungeonjournal\\media\\maps\\thestockade1"
        if usable(file,"string") and file:lower():gsub("%.blp$","")==expected and
            safe(tex.GetParent,tex)==holder and safe(tex.IsVisible,tex)==true and
            (not displayed[2] or safe(displayed[2].IsVisible,displayed[2])~=true) then return true end
        return
    end
    for i,expected in ipairs(stockTiles) do
        local tex=displayed[i]
        if not tex or safe(tex.GetParent,tex)~=holder or safe(tex.IsVisible,tex)~=true then return end
        local fileID=safe(tex.GetTextureFileID,tex)
        if not mapID(fileID) or fileID~=expected then
            local file=safe(tex.GetTexture,tex)
            local path="interface\\worldmap\\thestockade\\thestockade1_"..i
            if not (usable(file,"string") and file:lower():gsub("%.blp$","")==path) then return end
        end
    end
    return true
end

local function journalAlignedArt(frame, name, id, kind)
    local floors,journal,key=journalMaps(name,id)
    if not floors or safe(journal.GetSelectedDungeon)~=key then return end
    local index=frame.dungeonMapFloor
    local floor=mapID(index) and floors[index]
    local map=field(floor,"uiMapID")
    local holder,displayed=frame.dungeonMapArtHolder,frame.dungeonMapArtTiles
    local reportedFloor=nativeMap(name,id,kind)
    if not holder or safe(holder.IsVisible,holder)~=true or type(displayed)~="table" or
        not mapID(map) or (reportedFloor and map~=reportedFloor and not isDirectRoom(reportedFloor,map)) or floor.texture or
        frame.dungeonMapArtMissing then return end
    if id==34 and map==225 and stockAtlasMatches(frame,holder,displayed,floor) then
        return map,holder,holder:GetWidth(),holder:GetHeight()
    end
    if frame.dungeonMapArtCopy then return end
    -- Journal 2.1.5 renders native art layer 1. Never use a different
    -- layer, a named legacy tile, replacement parchment, or copied map.
    local tiles,aw,ah,tw,th=nativeArt(map,true)
    if not tiles and deadminesRooms[map] then
        -- Journal's legacy path also uses the native atlas, but only trust it
        -- if all live texture file IDs match, not merely its filenames.
        tiles,aw,ah,tw,th=deadminesRooms[map].tiles,1002,668,256,256
    end
    if not tiles then return end
    for i,expected in ipairs(tiles) do
        local tile=displayed[i]
        if not mapID(expected) or not tile or safe(tile.IsVisible,tile)~=true or
            safe(tile.GetParent,tile)~=holder then return end
        local actual
        if type(tile.GetTextureFileID)=="function" then actual=safe(tile.GetTextureFileID,tile)
        end
        if not mapID(actual) then actual=safe(tile.GetTexture,tile) end
        if not mapID(actual) or actual~=expected then return end
    end
    local w,h=safe(holder.GetWidth,holder),safe(holder.GetHeight,holder)
    if positive(w) and positive(h) then return map,holder,w,h,calibratedAtlas(map,tiles,aw,ah,tw,th) end
end

-- This second alignment path is strictly for an approximate Journal
-- landmark. It does not enable native/player positions on legacy art.
local function stockJournalHolder(frame,name,id)
    if id~=34 or frame.dungeonMapArtMissing or frame.dungeonMapFloor~=1 then return end
    local floors,journal,key=journalMaps(name,id)
    if not floors or #floors~=1 or field(floors[1],"uiMapID")~=225
        or safe(journal.GetSelectedDungeon)~=key then return end
    local holder,tiles=frame.dungeonMapArtHolder,frame.dungeonMapArtTiles
    local w,h=holder and safe(holder.GetWidth,holder),holder and safe(holder.GetHeight,holder)
    if not positive(w) or not positive(h) or math.abs(w/h-1.5)>.02
        or safe(holder.IsVisible,holder)~=true or type(tiles)~="table" then return end
    local function texture(i)
        local t=tiles[i]
        if t and safe(t.GetParent,t)==holder and safe(t.IsVisible,t)==true then
            local actual=safe(t.GetTexture,t)
            if ordinary(actual) then return actual end
        end
    end
    if frame.dungeonMapArtCopy then
        local expected=safe(journal.MapArtCopy,floors[1])
        if usable(expected,"string") and texture(1)==expected and not texture(2) then return holder end
        return
    end
    local prefix=field(floors[1],"tiles")
    if prefix~="Interface\\WorldMap\\TheStockade\\TheStockade1_" then return end
    for i=1,12 do if texture(i)~=prefix..i then return end end
    return holder
end

local function refreshJournalDots(frame,name,id,kind,map,holder,w,h)
    if map and nativePolicy(map)==false then
        hideJournalDots();return "WoW's map settings hide position icons on this floor."
    end
    if not map then hideJournalDots();return "Live positions aren't available for this Dungeon Journal floor." end
    if not journalDots or journalDots:GetParent()~=holder then
        hideJournalDots()
        journalDots=CreateFrame("Frame",nil,holder)
        journalDots:SetAllPoints(holder)
        journalDots:EnableMouse(false)
        journalDots:EnableMouseWheel(false)
        journalDots.dots={}
        for i=1,5 do
            local dot=journalDots:CreateTexture(nil,"OVERLAY")
            dot:SetTexture("Interface\\Buttons\\WHITE8X8")
            dot:SetSize(i==1 and 11 or 8,i==1 and 11 or 8)
            if i==1 then dot:SetVertexColor(.25,1,.53) else dot:SetVertexColor(.28,.67,1) end
            dot:Hide();journalDots.dots[i]=dot
        end
    end
    local available,total,missing=0,0,{}
    for i,dot in ipairs(journalDots.dots) do
        local token=i==1 and "player" or "party"..(i-1)
        local allowed=(i==1 and AT.db.dungeonPositionShowSelf~=false) or
            (i>1 and AT.db.dungeonPositionShowParty~=false and safe(UnitExists,token)==true)
        local x,y
        if allowed then
            available=available+1;x,y=clientPoint(map,token)
            local reported=safe(C_Map.GetBestMapForUnit,token)
            if not x and (not mapID(reported) or reported==map) then missing[#missing+1]=token end
        end
        if x then
            total=total+1
            dot:ClearAllPoints()
            dot:SetPoint("CENTER",holder,"TOPLEFT",x*w,-y*h)
            dot:Show()
        else dot:Hide() end
    end
    journalDots:SetShown(total>0)
    if showNativePins(journalPins,holder,map,missing) then
        return "Using WoW's native position layer on this floor. It only draws markers the game makes available."
    end
    if available>0 and total==0 then return "WoW is not exposing live positions on this Dungeon Journal floor." end
end

local function updateJournalDots()
    if not (AT.db and AT.db.enabled~=false and AT.db.dungeonPositionEnabled~=false) then
        hideJournalDots();return
    end
    local owns,frame=journalOwnsWorldMap()
    if owns and (not journalArmed or preferGame) then hideJournalDots();return end
    if not owns then frame=visibleJournal() end
    if preferGame or explicitMap then hideJournalDots();return end
    local name,id,kind
    if frame then name,id,kind=instance() end
    if frame and name then
        local _,journal,key=journalMaps(name,id)
        if not key or safe(journal.GetSelectedDungeon)~=key then
            hideJournalDots();return
        end
        if owns and panel then panel:Hide() end
        local map,holder,w,h,atlas=journalAlignedArt(frame,name,id,kind)
        local status=refreshJournalDots(frame,name,id,kind,map,holder,w,h)
        local owner=frame.dungeonMapPanel
        if owner and (not journalLocation or journalLocation:GetParent()~=owner) then
            setLocation(journalLocation,nil)
            journalLocation=makeLocation(owner)
            journalLocation:ClearAllPoints()
            journalLocation:SetPoint("BOTTOMLEFT",owner,"BOTTOMLEFT",8,6)
            journalLocation:SetPoint("RIGHT",owner,"RIGHT",-8,0)
            if owner.GetFrameLevel and journalLocation.SetFrameLevel then journalLocation:SetFrameLevel(owner:GetFrameLevel()+40) end
            local back=journalLocation:CreateTexture(nil,"BACKGROUND")
            back:SetAllPoints();back:SetColorTexture(.03,.05,.07,.90)
        end
        if owner and (not journalGameMap or journalGameMap:GetParent()~=owner) then
            if journalGameMap then journalGameMap:Hide() end
            journalGameMap=makeButton(owner,"Game floor map",-12,-10,118,function()
                preferGame=true
                if not AT.OpenDungeonPositionMap() then preferGame=nil end
            end)
        end
        local nativeFloor=owner and resolveNativeMap(name,id,kind,journalMaps(name,id))
        if journalGameMap then
            local roomFloor=calibratedFloor(id)
            journalGameMap:SetShown(mapID(nativeFloor) and (not map or (roomFloor and roomFloor~=map)))
        end
        local ownDot=journalDots and journalDots.dots[1]
        local exact=ownDot and ownDot:IsShown()
        local roomLabel,stockLabel
        journalRoom,roomLabel=updateRoom(journalRoom,holder,map,name,exact,atlas)
        local stockHolder=(map==225 and holder) or stockJournalHolder(frame,name,id)
        local floor -- never trust map ID alone
        if map==225 and id==34 then
            local floors=journalMaps(name,id)
            floor=floors and floors[frame.dungeonMapFloor]
        end
        local entranceHolder=id==34 and ((floor and stockAtlasMatches(frame,holder,frame.dungeonMapArtTiles,floor) and holder)
            or stockJournalHolder(frame,name,id))
        journalEntrance=updateStockEntrance(journalEntrance,entranceHolder)
        journalStock,stockLabel=updateStockLandmark(journalStock,holder or stockHolder,map or (stockHolder and 225),name,id,exact)
        local area=owner and AT.db.dungeonPositionShowSelf~=false and not exact
            and (currentSighting(id) and bossSightingText(currentSighting(id)) or roomLabel and ("Approx. room: "..roomLabel)
            or stockLabel and ("Last known (approx.): "..stockLabel) or dungeonLocationStatus(name)) or nil
        setLocation(journalLocation,area)
        return status
    end
    hideJournalDots()
end

-- Journal retains its World Map choice across closes. On a new M
-- session only, use its own Dungeon Map button instead of building a
-- competing NQT panel. Respect the Journal's lock and manual toggle.
local journalOpenPending
local function journalMapProvider()
    local j=_G.ForeverDungeonJournal_NS
    if type(j)=="table" and type(j.IsWorldMapOverlayAttached)=="function" then return j end
end
local function reopenJournal()
    local j=journalMapProvider()
    if not (j and watchedMap and watchedMap:IsShown() and journalArmed and instance()) then return end
    if safe(j.IsWorldMapOverlayAttached)==true then return end
    local name=safe(j.CurrentDungeon)
    if not usable(name,"string") or safe(j.IsDungeonMapLocked,name)==true then return end
    local b=_G.ForeverDungeonJournalWorldMapToggle
    local label=safe(j.L,"WM_DUNGEON_MAP") or "Dungeon Map"
    if b and safe(b.IsShown,b)==true and safe(b.IsEnabled,b)~=false
        and safe(b.GetText,b)==label and safe(b.IsProtected,b)~=true
        and safe(InCombatLockdown)~=true and type(b.Click)=="function" then
        pcall(b.Click,b)
    end
end

showCurrent=function(notify)
    if not (AT.db and AT.db.enabled~=false and AT.db.dungeonPositionEnabled~=false) then return false end
    local name,id,kind=instance()
    if not name or not panel or not watchedMap or (not explicitMap and not watchedMap:IsShown()) then return false end
    -- When Dungeon Journal already supplies the map in this very window,
    -- leave its controls and view alone; never create competing overlays.
    journalArmed=true
    if not explicitMap and not preferGame and (journalMapProvider() or journalOwnsWorldMap()) then
        panel:Hide()
        local unavailable=updateJournalDots()
        if notify and unavailable and AT.Say then
            local diagnostic=AT.db.dungeonPositionShowSelf~=false and (" "..dungeonLocationStatus(name)) or ""
            AT.Say(unavailable..diagnostic)
        end
        return true
    end
    local key=id or name
    local refreshedPages=journalMaps(name,id)
    local nmap=resolveNativeMap(name,id,kind,refreshedPages)
    if shownKey~=key or (not pages and refreshedPages) or (not panel:IsShown() and calibratedFloor(id)) then
        selectedFloor,sourceMode=1,refreshedPages and "journal" or "native"
        for i,floor in ipairs(refreshedPages or {}) do
            if nmap and floor.uiMapID==nmap then selectedFloor=i;break end
        end
    end
    if not refreshedPages then sourceMode="native" end
    if selectedFloor>(refreshedPages and #refreshedPages or 1) then selectedFloor=1 end
    if explicitMap and id==34 and kind=="party" then nmap=225 end
    if preferGame or (explicitMap and nmap) then sourceMode="native";hideJournalDots() end
    shownKey,pages,nativeID=key,refreshedPages,nmap
    panel.title:SetText(name)
    panel:Show()
    paint()
    if notify and AT.db.dungeonPositionShowSelf~=false and not panel.dots[1]:IsShown() and AT.Say then
        AT.Say(dungeonLocationStatus(name))
    end
    return true
end

-- Dock the one real minimap for this map session. SexyMap owns its
-- parent; use its public anchor API rather than fighting its hooks.
local updateMinimapLayer
do
    local saved,failed,lastDockStatus
    local strata={BACKGROUND=1,LOW=2,MEDIUM=3,HIGH=4,DIALOG=5,FULLSCREEN=6,FULLSCREEN_DIALOG=7,TOOLTIP=8}
    local function points(m,api)
        local n=safe(m.GetNumPoints,m)
        if not num(n) or n<1 or n>8 then return end
        local result={}
        for i=1,n do
            local ok,a,b,c,x,y=pcall(m.GetPoint,m,i)
            if not ok or not usable(a,"string") or not ordinary(b) or not ordinary(c)
                or not ordinary(x) or not ordinary(y) then return end
            if not api then
                -- The stock Minimap XML uses a bare CENTER anchor inside
                -- MinimapContainer. Accept omitted fields, not restricted values.
                if c==nil then c=a end
                if x==nil then x=0 end
                if y==nil then y=0 end
            end
            if not usable(c,"string") or not num(x) or not num(y) then return end
            result[i]={a,b,c,x,y}
        end
        return result
    end
    local function anchor(m,api,list)
        if api then
            if #list~=1 then return false end
            return pcall(api.SetPoint,api,unpack(list[1],1,5))
        end
        if type(m.ClearAllPoints)~="function" or type(m.SetPoint)~="function" then return false end
        if not pcall(m.ClearAllPoints,m) then return false end
        for _,v in ipairs(list) do
            if not pcall(m.SetPoint,m,unpack(v,1,5)) then return false end
        end
        return true
    end
    local function setLayer(m,layer)
        if safe(m.GetFrameStrata,m)==layer then return true end
        local fixed=safe(m.HasFixedFrameStrata,m)
        if fixed==true then
            if type(m.SetFixedFrameStrata)~="function" or not pcall(m.SetFixedFrameStrata,m,false) then return false end
        end
        local ok=pcall(m.SetFrameStrata,m,layer) and safe(m.GetFrameStrata,m)==layer
        if fixed==true then
            local locked=pcall(m.SetFixedFrameStrata,m,true)
            ok=ok and locked and safe(m.HasFixedFrameStrata,m)==true
        end
        return ok
    end
    local hideHooks=setmetatable({},{__mode="k"})
    local function hideControl(s,v)
        if type(v.Hide)~="function" or type(v.Show)~="function"
            or type(v.HookScript)~="function" or type(v.IsShown)~="function" then return false end
        if not hideHooks[v] then
            local ok=pcall(v.HookScript,v,"OnShow",function(obj)
                if saved and saved.hidden[obj]~=nil and not saved.restoring
                    and safe(obj.IsProtected,obj)~=true then pcall(obj.Hide,obj) end
            end)
            if not ok then return false end
            hideHooks[v]=true
        end
        local shown=safe(v.IsShown,v)
        if type(shown)~="boolean" then return false end
        if s.hidden[v]==nil then s.hidden[v]=shown end
        if shown then pcall(v.Hide,v) end
        return true
    end
    local function hideChrome(s)
        if safe(InCombatLockdown)==true then return end
        local function mute(v)
            if not v or v==s.frame or not ordinary(v) then return end
            if safe(v.IsProtected,v)==true or hideControl(s,v) then return end
            local alpha=safe(v.GetAlpha,v)
            if not num(alpha) or alpha==0 or type(v.SetAlpha)~="function" or safe(v.IsProtected,v)==true then return end
            if s.chrome[v]==nil then s.chrome[v]=alpha end
            pcall(v.SetAlpha,v,0)
        end
        for _,name in ipairs({
            "MinimapBackdrop","MinimapBorder","MinimapBorderTop","MinimapZoneTextButton","MinimapZoneText",
            "MinimapZoomIn","MinimapZoomOut","MiniMapTracking","MiniMapTrackingButton","MiniMapMailFrame",
            "MiniMapWorldMapButton","GameTimeFrame","TimeManagerClockButton","AddonCompartmentFrame",
            "ExpansionLandingPageMinimapButton","SexyMapZoneTextButton","SexyMapCustomBackdrop","SexyMapCoordFrame",
            "SexyMapPingFrame","AutoTrackMinimapButton",
        }) do mute(_G[name]) end
        local m,c=s.frame,_G.MinimapCluster
        if not s.api then
            -- These are controls on the default UI; leave the terrain and
            -- native player arrow alone, and let Blizzard keep the parent.
            mute(m.ZoomHitArea)
        end
        for _,k in ipairs({"ZoomIn","ZoomOut","Tracking","IndicatorFrame","BorderTop","ZoneText","ZoneTextButton"}) do mute(m[k]);if c then mute(c[k]) end end
        if type(m.GetChildren)=="function" then
            local list={pcall(m.GetChildren,m)}
            if list[1] then
                for i=2,#list do
                    local v=list[i]
                    if safe(v.IsObjectType,v,"Button")==true then mute(v) end
                end
            end
        end
        if s.api and type(m.GetRegions)=="function" then
            local list={pcall(m.GetRegions,m)}
            if list[1] then
                for i=2,#list do
                    local v=list[i]
                    -- SexyMap's border textures carry this settings object.
                    -- Do not hide the native player arrow or terrain.
                    if usable(v.settings,"table") and safe(v.IsObjectType,v,"Texture")==true then mute(v) end
                end
            end
        end
    end
    local function restoreChrome(s)
        s.restoring=true
        for v,shown in pairs(s.hidden) do
            if shown and safe(v.IsProtected,v)~=true and safe(v.IsShown,v)==false then pcall(v.Show,v) end
        end
        s.hidden={}
        for v,alpha in pairs(s.chrome) do
            if safe(v.GetAlpha,v)==0 then pcall(v.SetAlpha,v,alpha) end
        end
        s.chrome={}
    end
    local function refreshTerrain(m)
        local z,n=safe(m.GetZoom,m),safe(m.GetZoomLevels,m)
        if not (num(z) and num(n) and n>1 and z>=0 and z<n and type(m.SetZoom)=="function") then return end
        -- Refresh the native map after the anchor changes. Restore the same
        -- zoom immediately; do not touch the mask, scale or CVar.
        pcall(m.SetZoom,m,z==0 and 1 or z-1)
        pcall(m.SetZoom,m,z)
        if type(m.UpdateBlips)=="function" then pcall(m.UpdateBlips,m) end
    end

    local grip, spots
    local function ctrl() return safe(IsControlKeyDown)==true end
    local function legalDrag(s)
        return s and not s.restoring and not s.rollback and safe(InCombatLockdown)~=true
            and safe(s.frame.IsProtected,s.frame)==false and safe(s.holder.IsVisible,s.holder)==true
    end
    local function bounds(s)
        local h,m=s.holder,s.frame
        local hs,ms=safe(h.GetEffectiveScale,h),safe(m.GetEffectiveScale,m)
        local x,y=safe(h.GetLeft,h),safe(h.GetBottom,h)
        local w,ht=safe(h.GetWidth,h),safe(h.GetHeight,h)
        local mw,mh=safe(m.GetWidth,m),safe(m.GetHeight,m)
        if not (positive(hs) and positive(ms) and num(x) and num(y) and positive(w)
            and positive(ht) and positive(mw) and positive(mh)) then return end
        local spanX,spanY=w-mw*ms/hs-16,ht-mh*ms/hs-16
        if spanX<0 or spanY<0 then return end
        return x*hs,y*hs,hs,spanX,spanY
    end
    local function fraction(n)
        if num(n) then return math.max(0,math.min(1,n)) end
    end
    local function place(s,u,v)
        local x,y,scale,w,h=bounds(s)
        u,v=fraction(u),fraction(v)
        if not w or not u or not v then return false end
        -- Never anchor the native renderer to a frame that hides or changes
        -- parent during the close animation. Follow the journal geometrically.
        local root=_G.UIParent
        local rs=root and safe(root.GetEffectiveScale,root)
        local rx,ry
        if positive(rs) then rx,ry=safe(root.GetLeft,root),safe(root.GetBottom,root) end
        local stable=positive(rs) and num(rx) and num(ry)
        local parent=stable and root or s.holder
        spots=spots or {}
        local spot=spots[parent]
        if not spot then
            spot=CreateFrame("Frame",nil,parent)
            spot:SetSize(1,1)
            spots[parent]=spot
        end
        spot:ClearAllPoints()
        local dx,dy=8+u*w,8+v*h
        if stable then dx,dy=(x+dx*scale)/rs-rx,(y+dy*scale)/rs-ry end
        spot:SetPoint("BOTTOMLEFT",parent,"BOTTOMLEFT",dx,dy)
        s.holderX,s.holderY,s.holderScale=x,y,scale
        if s.spot~=spot then
            if not anchor(s.frame,s.api,{{"BOTTOMLEFT",spot,"BOTTOMLEFT",0,0}}) then return false end
            local p=points(s.frame,s.api)
            if not (p and p[1][2]==spot) then return false end
            s.spot=spot
        end
        s.u,s.v,s.spanX,s.spanY=u,v,w,h
        return true
    end
    local function dragStep(s)
        local x,y,scale,w,h=bounds(s)
        local cx,cy=safe(GetCursorPosition)
        if not x or not (num(cx) and num(cy)) then return end
        local u=w>0 and ((cx-s.dragX-x)/scale-8)/w or 0
        local v=h>0 and ((cy-s.dragY-y)/scale-8)/h or 0
        if place(s,u,v) then s.didDrag=true end
    end
    local function stopDrag(s)
        if s and s.didDrag and AT.db then
            AT.db.dungeonMinimapDock={x=s.u,y=s.v}
        end
        if s then s.dragX,s.dragY,s.didDrag=nil,nil,nil end
    end
    local function showGrip(s)
        if type(IsControlKeyDown)~="function" or type(GetCursorPosition)~="function" then return end
        if not grip then
            grip=CreateFrame("Frame","NQTDungeonMinimapDragArea",s.frame)
            grip:SetAllPoints(s.frame)
            grip:SetScript("OnMouseDown",function(_,button)
                if button~="LeftButton" or not ctrl() or not legalDrag(saved) then return end
                local m=saved.frame
                local l,b,scale=safe(m.GetLeft,m),safe(m.GetBottom,m),safe(m.GetEffectiveScale,m)
                local cx,cy=safe(GetCursorPosition)
                if num(l) and num(b) and positive(scale) and num(cx) and num(cy) and bounds(saved) then
                    saved.dragX,saved.dragY=cx-l*scale,cy-b*scale
                end
            end)
            grip:SetScript("OnMouseUp",function(_,button)
                if button=="LeftButton" and saved and saved.dragX then stopDrag(saved) end
            end)
            grip:SetScript("OnUpdate",function(self)
                local on=legalDrag(saved) and ctrl()
                if self.mouseOn~=on then self:EnableMouse(on and true or false);self.mouseOn=on end
                if saved and saved.dragX then
                    if not on or safe(IsMouseButtonDown,"LeftButton")==false then stopDrag(saved)
                    else dragStep(saved) end
                end
            end)
        end
        grip:SetFrameStrata(safe(s.frame.GetFrameStrata,s.frame) or "DIALOG")
        grip:SetFrameLevel(math.min(10000,(safe(s.frame.GetFrameLevel,s.frame) or 0)+10))
        grip.mouseOn=nil;grip:EnableMouse(false);grip:Show()
    end
    local function hybridShown()
        local f=_G.HybridMinimap
        if not f then return false end
        return safe(f.IsShown,f)
    end
    local function restoreGround(s)
        local a=_G.C_Minimap
        if not a or not usable(s.ground,"boolean") or safe(InCombatLockdown)==true then return end
        local _,id=instance()
        local ui,hybrid=safe(a.GetUiMapID),hybridShown()
        if not ordinary(ui) or not ordinary(s.uiMap) or not usable(hybrid,"boolean") then return end
        if id~=s.instance or ui~=s.uiMap or hybrid~=s.hybrid then return end
        local draw=safe(a.GetDrawGroundTextures)
        if usable(draw,"boolean") and draw~=s.ground and type(a.SetDrawGroundTextures)=="function" then
            pcall(a.SetDrawGroundTextures,s.ground)
        end
        local f=_G.HybridMinimap
        if s.hybrid and f and type(f.UpdateZoom)=="function" then pcall(f.UpdateZoom,f) end
    end

    local lastRender
    local function sampleRender()
        local a,m,h=_G.C_Minimap,_G.Minimap,_G.HybridMinimap
        local function state(v) return usable(v,"boolean") and (v and "on" or "off") or "?" end
        local b=SexyMapCustomBackdrop
        local z=m and safe(m.GetZoom,m)
        local alpha=m and safe(m.GetEffectiveAlpha,m)
        return ("ground=%s hybrid=%s canvas=%s visible=%s z=%s a=%s backdrop=%s"):format(
            state(safe(a and a.GetDrawGroundTextures)),state(h and safe(h.IsShown,h) or false),
            state(h and h.MapCanvas and safe(h.MapCanvas.IsVisible,h.MapCanvas) or false),
            state(m and safe(m.IsVisible,m)), num(z) and tostring(z) or "?",
            num(alpha) and string.format("%.2f",alpha) or "?",state(b and safe(b.IsVisible,b) or false))
    end
    local function sexyMask()
        local db=_G.SexyMap2DB
        local name,surname=safe(UnitNameUnmodified,"player")
        if type(db)~="table" or not usable(name,"string") or name=="" then return end
        local key
        if safe(RegionalUniqueNamesEnabled)==true then
            if not usable(surname,"string") or surname=="" then return end
            key=name.." "..surname
        else
            local realm=safe(GetRealmName)
            if not usable(realm,"string") or realm=="" then return end
            key=name.."-"..realm
        end
        local p=db[key]
        if p=="global" then p=db.global end
        local mask=field(field(p,"core"),"shape")
        if positive(mask) or (usable(mask,"string") and #mask>0 and #mask<240 and not mask:find("[%c|]")) then return mask end
    end
    local function uncoverSexyMapTerrain(s)
        local b=_G.SexyMapCustomBackdrop
        if not s.api or not b or not s.opaqueBackdrop or safe(b.IsShown,b)~=true
            or type(b.GetBackdropColor)~="function" or type(b.SetBackdropColor)~="function"
            or safe(b.IsProtected,b)==true then return end
        local ok,r,g,blue,a=pcall(b.GetBackdropColor,b)
        if ok and num(r) and num(g) and num(blue) and positive(a) then
            -- The opaque fill can cover the restored native terrain after
            -- the frame changes strata. Keep its edge and saved preset intact.
            s.backdropUncovered=pcall(b.SetBackdropColor,b,r,g,blue,0)
        end
    end
    local function settleRender(s)
        if saved or _G.Minimap~=s.frame or safe(s.frame.IsVisible,s.frame)~=true
            or safe(s.frame.IsProtected,s.frame)~=false or safe(InCombatLockdown)==true then return end
        restoreGround(s)
        uncoverSexyMapTerrain(s)
        local currentMask=s.api and sexyMask()
        if currentMask and currentMask==s.mask and type(s.frame.SetMaskTexture)=="function" then
            -- Rebind the same terrain mask. Never invoke SexyMap's layout or
            -- hide/show hooks, and never rewrite the saved shape.
            s.maskRefresh=pcall(s.frame.SetMaskTexture,s.frame,currentMask)
        end
        s.settled=sampleRender()
    end
    AT.CheckDungeonMinimapRender=function()
        if not saved and lastDockStatus then return lastDockStatus end
        local s=saved or lastRender
        if not s then
            if AT.char and type(AT.char.lastDungeonMinimapRender)=="string" then return AT.char.lastDungeonMinimapRender end
            return "No dungeon minimap trace yet. Open M inside a dungeon with docking on, then close it."
        end
        return ("Minimap: before [%s]; docked [%s]; returned [%s]; now [%s]; mask refresh=%s; background uncovered=%s."):format(
            s.beforeRender or "?",s.dockRender or "?",s.settled or s.returnRender or "?",sampleRender(),
            s.maskRefresh and "yes" or "no",s.backdropUncovered and "yes" or "no")
    end
    local function restore()
        if not saved then return true end
        local s=saved
        if grip then grip:Hide() end
        stopDrag(s)
        if safe(s.frame.IsProtected,s.frame)~=false then return false end
        local a=anchor(s.frame,s.api,s.points)
        local actual=a and points(s.frame,s.api)
        if actual and #actual==#s.points then
            for i,want in ipairs(s.points) do
                for k=1,5 do
                    local expected,got=want[k],actual[i][k]
                    if not s.api and k==2 and (expected==nil or got==nil) then
                        local parent=safe(s.frame.GetParent,s.frame)
                        expected,got=expected or parent,got or parent
                    end
                    if (type(expected)=="number" and (not num(got) or math.abs(got-expected)>.05))
                        or (type(expected)~="number" and got~=expected) then a=false end
                end
            end
        else a=false end
        local b=setLayer(s.frame,s.layer)
        if s.fixed==true and safe(s.frame.HasFixedFrameStrata,s.frame)~=true then
            b=pcall(s.frame.SetFixedFrameStrata,s.frame,true) and b
        end
        if a and b then
            restoreChrome(s)
            uncoverSexyMapTerrain(s)
            restoreGround(s)
            refreshTerrain(s.frame)
            saved=nil;lastRender=s
            s.returnRender=sampleRender()
            if AT.char then AT.char.lastDungeonMinimapRender=AT.CheckDungeonMinimapRender() end
            if C_Timer and C_Timer.After then
                local frame=s.frame
                C_Timer.After(0,function()
                    -- Journal and WorldMap hide hooks can run after our hook.
                    if not saved and safe(frame.IsVisible,frame)==true and safe(frame.IsProtected,frame)==false then
                        restoreGround(s)
                        refreshTerrain(frame)
                        if lastRender==s then
                            settleRender(s)
                            if AT.char then AT.char.lastDungeonMinimapRender=AT.CheckDungeonMinimapRender() end
                        end
                    end
                end)
            end
            return true
        end
        return false
    end
    function updateMinimapLayer(holder)
        if not holder then failed=nil;restore();return end
        if saved then
            if saved.holder==holder and not saved.rollback then
                hideChrome(saved)
                if saved.spot and not saved.dragX then
                    local x,y,scale,w,h=bounds(saved)
                    if w and (w~=saved.spanX or h~=saved.spanY or x~=saved.holderX or y~=saved.holderY or scale~=saved.holderScale) then
                        place(saved,saved.u,saved.v)
                    end
                end
                return
            end
            if not restore() then return end
        end
        if failed==holder or safe(InCombatLockdown)==true then return end
        local m=_G.Minimap
        if not m or safe(m.IsVisible,m)~=true or safe(m.IsProtected,m)~=false then
            lastDockStatus="The minimap is hidden, unavailable, or protected."
            return
        end
        local layer,world,map=safe(m.GetFrameStrata,m),safe(watchedMap.GetFrameStrata,watchedMap),safe(holder.GetFrameStrata,holder)
        if not (usable(layer,"string") and usable(world,"string") and strata[layer] and strata[world]) then return end
        local top=math.max(strata[world],usable(map,"string") and strata[map] or 0)
        if top>=8 then return end
        local raised=strata[layer]>top and layer or (top<7 and "FULLSCREEN_DIALOG" or "TOOLTIP")
        local api=_G.SexyMap
        if not (type(api)=="table" and type(api.SetPoint)=="function") then
            if safe(C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded,"SexyMap")==true then return end
            api=nil
        end
        local before=points(m,api)
        if not before or (api and #before~=1) then
            lastDockStatus=(api and "SexyMap" or "Stock minimap")..": could not save the current anchor."
            return
        end
        saved={frame=m,api=api,points=before,layer=layer,fixed=safe(m.HasFixedFrameStrata,m),holder=holder,chrome={},hidden={}}
        local _,id=instance()
        saved.instance=id
        local bg=api and _G.SexyMapCustomBackdrop
        saved.opaqueBackdrop=bg and safe(bg.IsShown,bg)==true
        saved.mask=api and sexyMask()
        saved.beforeRender=sampleRender()
        saved.hybrid=hybridShown()
        saved.ground=safe(C_Minimap and C_Minimap.GetDrawGroundTextures)
        saved.uiMap=safe(C_Minimap and C_Minimap.GetUiMapID)
        local d=AT.db.dungeonMinimapDock
        local u,v=type(d)=="table" and fraction(d.x),type(d)=="table" and fraction(d.y)
        local applied=setLayer(m,raised)
        if applied then
            local _,_,_,w,h=bounds(saved)
            if w then
                applied=place(saved,u or (w>0 and math.max(0,1-16/w) or 0),v or (h>0 and math.min(1,28/h) or 0))
            else
                applied=anchor(m,api,{{"BOTTOMRIGHT",holder,"BOTTOMRIGHT",-24,36}})
                local now=applied and points(m,api)
                applied=now and #now==1 and now[1][2]==holder
            end
        end
        if not applied then
            lastDockStatus=(api and "SexyMap" or "Stock minimap")..": could not dock; reverting its layout.";saved.rollback=true;failed=holder;restore()
        else
            lastDockStatus=nil
            showGrip(saved)
            hideChrome(saved)
            refreshTerrain(m)
            saved.dockRender=sampleRender()
        end
    end
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
    panel.location=makeLocation(panel)
    panel.location:ClearAllPoints()
    panel.location:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",7,26)
    panel.location:SetPoint("RIGHT",panel,"RIGHT",-7,0)
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
    panel.back=makeButton(panel,"World Map",-9,-8,90,function()
        if explicitMap then
            explicitMap=nil
            panel:Hide()
            panel:SetParent(watchedMap)
            panel:ClearAllPoints()
            panel:SetPoint("TOPLEFT",watchedMap,"TOPLEFT",7,-33)
            panel:SetPoint("BOTTOMRIGHT",watchedMap,"BOTTOMRIGHT",-7,8)
            panel:SetFrameLevel(watchedMap:GetFrameLevel()+70)
            if panel.SetFrameStrata and watchedMap.GetFrameStrata then panel:SetFrameStrata(watchedMap:GetFrameStrata()) end
            panel.back:SetText("World Map")
            sourceMode=nil;shownKey=nil
        end
        preferGame=nil;panel:Hide();updateJournalDots()
    end)
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
    panel:SetScript("OnHide",function()
        hideNativePins(panelPins)
        if panelEntrance then panelEntrance:Hide() end
        if panelRoom then panelRoom:Hide() end
        if panelStock then panelStock:Hide() end
    end)
    panel:SetScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt
        if elapsed>=.23 then
            elapsed=0
            if not explicitMap and not preferGame and (journalMapProvider() or journalOwnsWorldMap()) then
        panel:Hide() panel:Hide();return end
            if sourceMode=="native" then
                local name,id,kind=instance()
                local m=explicitMap and id==34 and kind=="party" and 225 or name and resolveNativeMap(name,id,kind,pages)
                if m~=nativeID then nativeID=m;paint();return end
            end
            refreshDots()
        end
    end)
    map:HookScript("OnShow",function()
        if not explicitMap and not leaving and AT.db and AT.db.dungeonPositionAutoOpen~=false then
            journalOpenPending=showCurrent() and journalMapProvider() and true or nil
        end
    end)
    map:HookScript("OnHide",function()
        updateMinimapLayer(false);journalOpenPending=nil;journalArmed=false;preferGame=nil;hideJournalDots();if not explicitMap then panel:Hide() end
    end)
end

function AT.RefreshDungeonPosition()
    if not AT.db or AT.db.dungeonMapMinimap==false or AT.db.enabled==false or AT.db.dungeonPositionEnabled==false then updateMinimapLayer(false) end
    attach()
    if not panel then return end
    if not AT.db or AT.db.enabled==false or AT.db.dungeonPositionEnabled==false or not instance() then
        preferGame=nil;hideJournalDots();panel:Hide();return
    end
    if panel:IsShown() then showCurrent() else updateJournalDots() end
end

function AT.OpenDungeonPositionMap()
    if not (AT.db and AT.db.enabled~=false and AT.db.dungeonPositionEnabled~=false) then
        if AT.Say then AT.Say("Enable dungeon maps to open this map.") end
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
    return showCurrent(true)
end

local function checkDungeonMarker()
    local name,id,kind=instance()
    if not name then
        if AT.Say then AT.Say("Open the dungeon map inside the dungeon, then type /nqtdungeon.") end
        return
    end
    local owns,frame=journalOwnsWorldMap()
    if not frame then frame=visibleJournal() end
    local custom=panel and panel:IsVisible()
    local map=custom and renderedMap or nil
    local art,atlas
    if custom then art=sourceMode=="native" and "Game floor map" or "Nexus Journal floor"
    elseif frame then
        local matched,_,_,_,verified=journalAlignedArt(frame,name,id,kind)
        map,atlas,art=matched,verified,owns and "Dungeon Journal" or "Dungeon Journal standalone"
    else art="no dungeon map open" end
    local probeMap=map or (id==34 and kind=="party" and 225)
    local point=probeMap and nativePolicy(probeMap)~=false and clientPoint(probeMap,"player")
    local policy,policyDetail=nativePolicy(probeMap)
    local state=custom and panelPins or journalPins
    local phase=map and state.phase or "no verified aligned floor art"
    local journalFloor
    if frame then
        local floors=journalMaps(name,id)
        local index=frame.dungeonMapFloor
        if floors and mapID(index) then journalFloor=field(floors[index],"uiMapID") end
    end
    local function number(v) return mapID(v) and tostring(v) or "none" end
    local function cleanName(v)
        return usable(v,"string") and v:sub(1,84):gsub("[%c|]","") or "unknown"
    end
    local _,_,_,_,room=roomBounds(map,name,custom and panelAtlas or atlas)
    local line=("Dungeon marker check: %s (#%s); view %s; best floor=%s, Journal floor=%s, matched floor=%s; player point=%s; map icons=%s; Show my position=%s; room geometry=%s; %s.")
        :format(cleanName(name),number(id),art,number(currentPlayerMap()),number(journalFloor),number(map),
            point and "available" or "unavailable",policy==true and "allowed" or (policy==false and "hidden" or (policyDetail or "unknown")),
            AT.db and AT.db.dungeonPositionShowSelf==false and "off" or "on",room and cleanName(room) or "unavailable",phase or "native renderer not started")
    local _,_,stock=stockPoint(name,id,(map==225 or frame and stockJournalHolder(frame,name,id)) and 225 or map)
    if id==34 then
        local entrance=custom and panelEntrance or (not custom and journalEntrance)
        line=line.." Stockade coordinate check: floor 225"..(map==225 and " matched" or " not matched")
            .."; entrance label="..(entrance and entrance:IsVisible() and "shown" or "hidden")
            .."; last position estimate: "..(stock or "none recent").."."
    end
    line=line..(" Area labels: %s / %s / %s; calibrated Deadmines art=%s."):format(
        cleanName(readableLabel(GetZoneText)),cleanName(readableLabel(GetSubZoneText)),
        cleanName(readableLabel(GetMinimapZoneText)),(custom and panelAtlas or atlas) and "matched" or "not matched")
    local sighting=currentSighting(id)
    local stockHolder=not custom and frame and stockJournalHolder(frame,name,id)
    local bossMap=map or (stockHolder and 225)
    local bossFrame=custom and panelStock or journalStock
    local mapped=sighting and bossSightingPoint(name,id,bossMap,sighting)
    line=line.." Boss sighting: "..(sighting and (cleanName(sighting.label)..
        (mapped and (bossFrame and bossFrame:IsVisible() and " (landmark visible)" or " (matched floor, landmark not visible)")
            or " (no unambiguous landmark on this floor)")) or "none recent").."."
    -- Opt-in troubleshooting only. No coordinates, no player names, no external reporting.
    if AT.char then AT.char.lastDungeonMarkerCheck=line end
    if AT.Say then AT.Say(line) end
end

function AT.InitDungeonPosition()
    _G.SLASH_NQTMINIMAPCHECK1="/nqtminimapcheck"
    SlashCmdList.NQTMINIMAPCHECK=function()
        local result=AT.CheckDungeonMinimapRender()
        if AT.Say then AT.Say(result) end
    end
    SLASH_NEXUSOWNDUNGEONMAP1="/nqtmap"
    SlashCmdList.NEXUSOWNDUNGEONMAP=function(msg)
        if not (AT.db and AT.db.enabled~=false and AT.db.dungeonPositionEnabled~=false) then return end
        if not instance() then if AT.Say then AT.Say("Enter a dungeon to open the NQT map.") end;return end
        attach()
        if not panel or not UIParent or type(panel.SetParent)~="function" then return end
        explicitMap=true
        panel:SetParent(UIParent)
        panel:ClearAllPoints()
        panel:SetPoint("CENTER",UIParent,"CENTER",0,20)
        panel:SetSize(700,520)
        panel.art:Show()
        if panel.SetFrameStrata then panel:SetFrameStrata("DIALOG") end
        panel.back:SetText("Close")
        showCurrent()
    end
    SLASH_NEXUSDUNGEONMARKERCHECK1="/nqtdungeon"
    SlashCmdList.NEXUSDUNGEONMARKERCHECK=checkDungeonMarker
    SLASH_NEXUSBOSSSIGHTING1="/nqtsighting"
    SlashCmdList.NEXUSBOSSSIGHTING=function()
        local _,id=instance()
        local sighting=currentSighting(id)
        if AT.Say then AT.Say(sighting and bossSightingText(sighting) or "No recent boss sighting. Press your boss macro in the dungeon and check within 30 seconds.") end
    end
    attach()
    if watcher then return end
    if watchedMap and watchedMap:IsShown() and AT.db and AT.db.dungeonPositionAutoOpen~=false then journalOpenPending=showCurrent() and journalMapProvider() and true or nil end
    watcher=CreateFrame("Frame")
    watcher:SetScript("OnUpdate",function(_,dt)
        journalElapsed=journalElapsed+dt
        if journalElapsed>=.2 then
            journalElapsed=0
            if journalOpenPending then journalOpenPending=nil;reopenJournal() end
            if journalArmed or visibleJournal() or (journalLocation and journalLocation:IsShown())
                or (journalDots and journalDots:IsShown()) or (journalPins.frame and journalPins.frame:IsShown())
                or (journalRoom and journalRoom:IsShown()) or (journalStock and journalStock:IsShown()) then updateJournalDots() end
            local holder
            local dungeonView=AT.db and AT.db.dungeonMapMinimap~=false and watchedMap and watchedMap:IsShown() and not explicitMap and instance()
                and AT.db and AT.db.enabled~=false and AT.db.dungeonPositionEnabled~=false
            if dungeonView then
                local own,frame=journalOwnsWorldMap()
                if own and journalArmed and not preferGame then holder=frame.dungeonMapPanel
                elseif panel:IsVisible() and (panel.hasArt or not _G.SexyMap) then
                    -- Even a verified dungeon without overview art can show its live stock minimap.
                    holder=panel
                end
            end
            updateMinimapLayer(holder)
        end
    end)
    for _,event in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","ZONE_CHANGED_INDOORS","ZONE_CHANGED","PLAYER_MAP_CHANGED","GROUP_ROSTER_UPDATE","ENCOUNTER_START","PLAYER_DEAD","PLAYER_ALIVE","PLAYER_UNGHOST"}) do
        pcall(watcher.RegisterEvent,watcher,event)
    end
    watcher:SetScript("OnEvent",function(_,event,addon,second)
        stockSignal(event,addon,second)
        if event=="ADDON_LOADED" and addon~="Blizzard_WorldMap" and addon~="ForeverDungeonJournal" then return end
        attach()
        updateJournalDots()
        if not panel or (not explicitMap and not watchedMap:IsShown()) then return end
        local name,id=instance()
        if not name then
            if explicitMap then panel.back:GetScript("OnClick")() end
            preferGame=nil;hideJournalDots();panel:Hide();shownKey=nil;return
        end
        if panel:IsShown() or (event=="PLAYER_ENTERING_WORLD" and (id or name)~=shownKey and
            AT.db and AT.db.dungeonPositionAutoOpen~=false) then showCurrent() end
    end)
end
-- Read-only dungeon boss selection for the existing Smart Target hardware binding.
do
    local lastInstance
    local reservations = {}
    local raidOrder={8,7,4,6,3,1,5,2}
    local lastBossMarkNote,lastAttempt,lastPress
    local markRevision=0
    local plans,planIDs,planSerial={},{},0
    local lastTargetLabel,searchHit
    local searchSlots,searchDefault={}
    local function planFor(name)
        if not planIDs[name] then
            planSerial=planSerial+1
            plans[planSerial]=name
            planIDs[name]=planSerial
        end
        return planIDs[name]
    end
    local function validRaidIcon(index)
        return mapID(index) and index<=8
    end
    local stockade = {{1696,"Targorr the Dread"},{1717,"Hamhock"},{1666,"Kam Deepfury"},
        {1663,"Dextren Ward"},{1716,"Bazil Thredd"},{1720,"Bruegal Ironknuckle"}}
    local stockBatch=1
    local fallbackCount=0
    local tokens={"target","mouseover","focus","targettarget","player","pet"}
    for i=1,5 do tokens[#tokens+1]="boss"..i end
    for i=1,4 do
        tokens[#tokens+1]="party"..i
        tokens[#tokens+1]="party"..i.."target"
        tokens[#tokens+1]="partypet"..i
    end

    local function context()
        if not (AT.db and AT.db.enabled~=false and AT.db.bossAutoMark==true) then return end
        local name,id,kind=instance()
        if not name or not id or (kind~="party" and kind~="raid") then return end
        return name,id,kind
    end
    local function get(unit,fn)
        local ok,v=pcall(fn,unit)
        if ok and ordinary(v) then return v,true end
    end
    local function allowedToken(unit)
        return usable(unit,"string") and unit:match("^nameplate%d+$") and #unit<=13
    end
    local function factRoster(id)
        return (AT.GetForeverDungeonBossFacts and AT.GetForeverDungeonBossFacts(id))
            or (id==34 and stockade) or {}
    end
    local function bossIDs(name,id)
        local j=_G.ForeverDungeonJournal_NS
        if type(j)~="table" then j={} end
        local key=safe(j.CurrentDungeon) or (j.INSTANCE_ID_TO_DUNGEON and j.INSTANCE_ID_TO_DUNGEON[id])
            or safe(j.DungeonFromInstanceName,name)
        local data=key and type(j.DB)=="table" and j.DB[key]
        local ids,names={},{}
        local locale=safe(GetLocale)
        local english=not locale or locale=="enUS" or locale=="enGB"
        local fallback,unique={},{}
        local function addLabel(label)
            if usable(label,"string") and label~="" and #label<=85 and not label:find("[%c%[%];|/]") then
                local key=label:lower()
                names[key]=true
                if not unique[key] then fallback[#fallback+1]=label;unique[key]=true end
            end
        end
        for _,entry in ipairs(factRoster(id)) do
            if mapID(entry[1]) then ids[entry[1]]=true end
            if english then addLabel(entry[2])
            else
                local localized=safe(j.LocalizeBossName,entry[2])
                if localized~=entry[2] then addLabel(localized) end
            end
        end
        if type(data)=="table" and type(data.bosses)=="table" then
            for _,boss in pairs(data.bosses) do
                if type(boss)=="table" and not boss.trash and mapID(boss.npcID) and boss.npcID~=3864 then
                    ids[boss.npcID]=true
                    if mapID(boss.pairNpcID) then ids[boss.pairNpcID]=true end
                    if english then
                        if not boss.pairNpcID then addLabel(boss.name) end
                    else
                        local localized=safe(j.LocalizeBossName,boss.name)
                        if localized~=boss.name then addLabel(localized) end
                    end
                end
            end
        end
        return ids,names,fallback
    end
    local function observeReadableBossTarget(dungeon,id)
        if AT.db.dungeonPositionEnabled==false or AT.db.dungeonPositionShowSelf==false then return end
        if safe(InCombatLockdown)==true or safe(UnitExists,"target")~=true
            or safe(UnitCanAttack,"player","target")~=true
            or safe(UnitIsDeadOrGhost,"target")~=false then return end
        local label=safe(UnitName,"target")
        if not usable(label,"string") or label=="" then return end
        local guid=safe(UnitGUID,"target")
        local npc=usable(guid,"string") and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
        local ids,names=bossIDs(dungeon,id)
        if (npc and ids[npc]) or names[label:lower()] then recordBossSighting(id,label) end
    end
    local function scan(name,id,preview,ids,names)
        local seen,seenByName,occupied,candidates,units={},{},{},{},{}
        local byToken={}
        for _,unit in ipairs(tokens) do units[#units+1]=unit end
        if safe(IsInRaid)==true then
            local size=safe(GetNumGroupMembers)
            for i=1,(mapID(size) and math.min(size,40) or 0) do
                units[#units+1]="raid"..i
                units[#units+1]="raid"..i.."target"
                units[#units+1]="raidpet"..i
            end
        end
        local plates=safe(C_NamePlate and C_NamePlate.GetNamePlates)
        if usable(plates,"table") then
            for _,plate in ipairs(plates) do
                local unit=plate.namePlateUnitToken
                if allowedToken(unit) then units[#units+1]=unit end
            end
        end
        local unknowns={}
        local deadNames,livingNames,rosterName={},{},{}
        for _,entry in ipairs(factRoster(id)) do
            local key=entry[2]:lower()
            if names[key] then rosterName[entry[1]]=key end
        end
        local directOwner
        local candidateGUIDs={}
        for _,unit in ipairs(units) do
            local exists=safe(UnitExists,unit)
            if ordinary(exists) and exists==true then
                local guid=safe(UnitGUID,unit)
                if not usable(guid,"string") then guid=nil end
                local mark,readable=get(unit,GetRaidTargetIndex)
                if mark==0 then mark=nil end
                local dead,knownDead=get(unit,UnitIsDeadOrGhost)

                if validRaidIcon(mark) and dead~=true then
                    occupied[mark]=guid or true

                end

                local npc=safe(UnitCreatureID,unit)
                if not mapID(npc) then npc=guid and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")) end
                local label=safe(UnitName,unit)
                if not usable(label,"string") then label=nil end
                local proof={mark=mark,dead=dead,readable=readable,knownDead=knownDead,guid=guid}
                byToken[unit]=proof
                local nameKey=label and label:lower() or (unit=="target" and lastTargetLabel or nil)
                if unit=="target" then directOwner={guid=guid,name=nameKey,unit=unit} end
                if guid and (not seen[guid] or readable or dead==true) then seen[guid]=proof end
                if nameKey and (not seenByName[nameKey] or readable or dead==true) then seenByName[nameKey]=proof end
                if not readable and dead~=true then unknowns[#unknowns+1]={guid=guid,name=nameKey,unit=unit} end
                if validRaidIcon(mark) and dead~=true then
                    local prior=reservations[mark]
                    local same=prior and ((guid and prior.guid and prior.guid==guid)
                        or ((not guid or not prior.guid) and nameKey and nameKey==prior.name))
                    reservations[mark]={guid=guid or (same and prior.guid) or nil,
                        name=nameKey or (same and prior.name) or nil,confirmed=true,
                        token=unit,revision=markRevision}
                end
                local reachable=unit=="target" or unit=="mouseover" or allowedToken(unit) or unit:match("^boss%d$")
                local classification=safe(UnitClassification,unit)
                local boss=(npc and ids[npc]) or (not npc and label and names[label:lower()])
                    or (usable(classification,"string") and classification=="worldboss") or unit:match("^boss%d$")
                if boss and knownDead then
                    local evidence=dead==true and deadNames or (dead==false and livingNames or nil)
                    if evidence and nameKey then evidence[nameKey]=true end
                    -- An exact roster ID can prove death even if the client masks the name.
                    if evidence and npc and rosterName[npc] then evidence[rosterName[npc]]=true end
                end
                local key=guid or label
                local attack=safe(UnitCanAttack,"player",unit)
                if reachable and boss and key and not candidateGUIDs[key] and (not knownDead or dead~=true)
                    and ordinary(attack) and attack==true then
                    if label and label~="" then
                        local distance,checked=safe(UnitDistanceSquared,unit)
                        if checked~=true or not num(distance) or distance<0 then distance=nil end
                        local bucket
                        for i,interact in ipairs({3,2,4}) do
                            if safe(CheckInteractDistance,unit,interact)==true then bucket=i;break end
                        end
                        candidateGUIDs[key]=true
                        candidates[#candidates+1]={unit=unit,guid=guid,label=label,distance=distance,bucket=bucket,
                            marked=mark~=nil,canMark=dead~=true and mark==nil}
                    end
                end
            end
        end
        local function sameOwner(a,b)
            if a.guid and b.guid then return a.guid==b.guid end
            if a.unit and b.unit and a.unit==b.unit then return true end
            return a.name~=nil and a.name==b.name
        end
        -- A nil/stale read does not prove an icon is free. Reuse an
        -- uncertain icon ONLY on its previous owner, never on another mob.
        local retries={}
        for index,owner in pairs(reservations) do
            local direct=directOwner and sameOwner(owner,directOwner)
            local now=(owner.guid and seen[owner.guid]) or
                (owner.name and seenByName[owner.name])
            if now and owner.guid and now.guid and now.guid~=owner.guid then now=nil end
            if not occupied[index] and now and now.knownDead and now.dead==true then
                reservations[index]=nil
            else
                if not occupied[index] and now and now.readable and now.mark==nil and
                    ((owner.confirmed and (direct or markRevision>(owner.revision or markRevision)))
                        or (not owner.confirmed and direct and GetTime()-(owner.attemptedAt or GetTime())>=.8)) then
                    retries[index]=owner
                end
                occupied[index]=true
            end
        end
        local index
        for _,icon in ipairs(raidOrder) do
            if not occupied[icon] then index=icon;break end
        end
        local unresolved={}
        for _,u in ipairs(unknowns) do
            local elsewhere=u.guid and seen[u.guid] or (u.name and seenByName[u.name])
            local explained=elsewhere and (elsewhere.readable or elsewhere.dead==true)
            if not explained then
                for _,owner in pairs(reservations) do
                    if sameOwner(u,owner) then explained=true;break end
                end
            end
            if not explained then unresolved[#unresolved+1]=u end
        end
        for _,c in ipairs(candidates) do
            local ownerKey={guid=c.guid,name=c.label:lower(),unit=c.unit}
            for _,owner in pairs(reservations) do
                if sameOwner(owner,ownerKey) then c.canMark=false end
            end

            local proof=c.guid and seen[c.guid] or seenByName[ownerKey.name]
            if proof and validRaidIcon(proof.mark) then c.canMark=false end
            for _,other in ipairs(unresolved) do
                -- The secure set-unmarked action can check this selected
                -- boss itself. It cannot verify another unit's occupied icon.
                if not sameOwner(other,ownerKey) then c.canMark=false;break end
            end
        end
        local allMeasured=true
        for _,candidate in ipairs(candidates) do if candidate.distance==nil then allMeasured=false;break end end
        local pick
        for _,c in ipairs(candidates) do
            local preferred=index and c.canMark and not (pick and pick.canMark)
            local sameClass=pick and (not index or c.canMark==pick.canMark)


            if not pick or preferred or (sameClass and allMeasured and c.distance<pick.distance)
                or (sameClass and not allMeasured and (c.bucket or 4)<(pick.bucket or 4)) then pick=c end
        end
        if pick and pick.canMark then pick.index=index end
        if (not pick or not pick.index) and #unresolved==0 then
            for _,icon in ipairs(raidOrder) do
                local retryOwner=retries[icon]
                if retryOwner then
                    for _,c in ipairs(candidates) do
                        if sameOwner(retryOwner,{guid=c.guid,name=c.label:lower(),unit=c.unit}) then
                            c.index=icon;pick=c;break
                        end
                    end
                end
                if pick and pick.index then break end
            end
        end
        return pick,#unresolved==0 and index or nil,index~=nil and #unresolved>0,deadNames,livingNames
    end

    -- Only the bound Smart Target button builds its macro on each physical
    -- press. A cached action-bar macro must not assign the same free marker
    -- to different possible owners before its body has been refreshed.
    local function recentFallback(fallback)
        if not lastPress then return end
        for _,label in ipairs(fallback) do
            if label:lower()==lastPress.name then return label end
        end
    end

    local clearDead="\n/cleartarget [@target,dead]"

    local function reacquireTail(label,ping)
        if not label then return "" end
        return "\n/stopmacro [exists,nodead]\n/cleartarget\n/stopmacro [exists]"
            .."\n/targetexact [noexists] "..label.."\n/atmob k0:"..planFor(label:lower())..ping..clearDead
    end

    local function smartSearch(fallback,free)
        local reserved,freeNames={},{}
        for _,owner in pairs(reservations) do
            if owner.name then reserved[owner.name]=true end
        end
        for offset=0,#fallback-1 do
            local slot=(stockBatch+offset-1)%#fallback+1
            local label=fallback[slot]
            if not reserved[label:lower()] then freeNames[#freeNames+1]={label,slot} end
        end
        local recent=recentFallback(fallback)
        if #freeNames==0 and recent then
            -- Every known candidate already has a mark. Reacquire the
            -- last one rather than start over at an out-of-range entry.
            return "/stopmacro [combat]"..reacquireTail(recent,
                AT.db.bossMarkPing and "\n/ping [@target,exists,nodead] Attack" or ""):gsub("^\n/stopmacro %[exists,nodead%]", "", 1)
        end
        if #freeNames==0 then return end
        searchSlots,searchHit={},nil
        local body="/stopmacro [combat]\n/cleartarget\n/stopmacro [exists]"
        local ping=AT.db.bossMarkPing and "\n/ping [@target,exists,nodead] Attack" or ""
        local recover=recent and reacquireTail(recent,ping) or clearDead
        local mark=free and ("\n/tm [exists,nodead] ~"..free) or ""
        local tail,count,lastProbe
        for _,entry in ipairs(freeNames) do
            local name,slot=entry[1],entry[2]
            local plan=planFor(name:lower())
            local line="\n/targetexact [noexists][dead] "..name
            local nextTail=mark.."\n/atmob j"..(free or 0)..":"..slot..ping
            local compiled=body..(lastProbe or "")..line
            -- SecureActionButton macrotext uses RunMacroText, not a
            -- stored character macro. Stay below its engine limit.
            if #compiled+#nextTail+#recover>900 then break end
            searchSlots[plan],searchDefault=slot,plan
            body,tail,count=compiled,nextTail,(count or 0)+1
            -- The final name needs no separate callback: if no earlier
            -- probe succeeded and a live target exists, it's this name.
            lastProbe="\n/atmob p"..plan
        end
        if not count then return end
        lastBossMarkNote=("Prepared a native search of %d unmarked boss names."):format(count)
        return body..tail..recover
    end

    function AT.GetBossTargetMacro(preview,smart,maxBytes)
        local name,id,kind=context()
        if not name then return false end
        if id~=lastInstance then
            reservations,lastInstance,stockBatch,lastAttempt,lastPress={},id,1,nil,nil
            plans,planIDs,lastTargetLabel={},{},nil
        end
        if (kind=="raid" or safe(IsInRaid)==true) and safe(UnitIsGroupLeader,"player")~=true
            and safe(UnitIsGroupAssistant,"player")~=true then
            return true,nil,"You need raid marking permission."
        end
        local ids,names,fallback=bossIDs(name,id)
        local pick,free,unreadable,deadNames,livingNames=scan(name,id,preview,ids,names)
        local kept={}
        for _,label in ipairs(fallback) do
            local key=label:lower()
            if not deadNames[key] or livingNames[key] then kept[#kept+1]=label end
        end
        fallback,fallbackCount=kept,#kept
        if stockBatch>fallbackCount then stockBatch=1 end
        local labels={}
        if pick then
            local label=pick.label
            if #label>85 or label:find("[%c%[%];|/]") then return true,nil,"That boss name cannot be used safely in a macro." end
            labels[1]=label
        elseif fallbackCount>0 then
            if smart then
                local grouped=smartSearch(fallback,free)
                if grouped then return true,grouped end
                -- When only one unmarked roster boss remains, check it
                -- first instead of stopping on one of our marked bosses.
                local owned={}
                for _,owner in pairs(reservations) do if owner.name then owned[owner.name]=true end end
                for offset=0,fallbackCount-1 do
                    local slot=(stockBatch+offset-1)%fallbackCount+1
                    if not owned[fallback[slot]:lower()] then labels[1]=fallback[slot];break end
                end
            end
            -- The cached macro can try one undisclosed boss per press without
            -- letting a cached Skull line act on a different boss.
            if stockBatch>fallbackCount then stockBatch=1 end
            labels[1]=labels[1] or fallback[stockBatch]

        else
            return true,nil,"No boss detected."
        end
        local index=pick and pick.index or (not pick and free)
        if not pick then
            -- Native exact-name search still works when Lua has no readable
            -- nameplates. A prior owner may only retry its own icon.
            local nameKey=labels[1]:lower()
            for _,icon in ipairs(raidOrder) do
                local owner=reservations[icon]
                if owner and owner.name==nameKey then
                    index=free and icon or nil
                    break
                end
            end
        end
        lastBossMarkNote=index and ("Prepared icon "..index.." for "..labels[1]..".")
            or (unreadable and "Another unit has an unreadable mark; icons were left alone."
            or "No available icon for this boss.")
        -- Select the boss by exact name, not a recycled nameplate token. A
        -- failed selection performs no mark or ping.
        local body="/stopmacro [combat]\n/cleartarget\n/stopmacro [exists]"
        for i,label in ipairs(labels) do
            body=body.."\n/targetexact "..(i==1 and "" or "[noexists] ")..label

        end
        local ping=AT.db.bossMarkPing and "\n/ping [@target,exists,nodead] Attack" or ""
        body=body..(index and ("\n/tm [exists,nodead] ~"..index) or "")
            ..("\n/atmob k"..(index or 0)..":"..planFor(labels[1]:lower())..(not pick and "f" or ""))
        if not pick then
            if not smart then
                local recent=recentFallback(fallback)
                if recent and recent~=labels[1] then
                    -- After the one planned marker attempt, recover our
                    -- last target on a miss, without giving it a new icon.
                    local probe="\n/targetexact [noexists][dead] "..recent
                    local recover=probe.."\n/atmob v"..planFor(recent:lower())
                    local function fits(core,tail)
                        return not maxBytes or #core+#tail+#ping+#clearDead<=maxBytes
                    end
                    if fits(body,recover) then body=body..recover
                    else
                        local shorter=body:gsub("/targetexact %[noexists%] ","/targetexact ",1)
                        if fits(shorter,recover) then body=shorter..recover
                        -- This is already the last successful name; reporting
                        -- it again is optional when macro space is tight.
                        elseif fits(shorter,probe) then body=shorter..probe end
                    end
                end
            end
        end
        -- Exact-name targeting can pick a corpse, even if the scan saw
        -- a live boss when this macro was prepared. Guard marks and pings
        -- natively, then clear the corpse after all acquisition paths.
        if maxBytes and #body+#ping+#clearDead>maxBytes then ping="" end
        body=body..ping..clearDead
        if maxBytes and #body>maxBytes then return true,nil,"That boss name does not fit in the action-bar macro." end
        return true,body
    end

    -- This notification occurs only after the player's native macro searches
    -- one exact name and tries /tm. Never assign/reassign markers from Lua.
    function AT.ReserveBossMark(index,planID)
        if index~=0 and not validRaidIcon(index) then return end
        local dungeon,id=context()
        if not dungeon or safe(InCombatLockdown)==true then return end
        if safe(SecureCmdOptionParse,"[@target,exists,nodead] yes")~="yes" then return end
        local observed,readable=get("target",GetRaidTargetIndex)
        local guid=safe(UnitGUID,"target")
        local label=safe(UnitName,"target")
        local identity=usable(guid,"string") and guid or nil
        local name=usable(label,"string") and label:lower() or nil
        local planned=planID and plans[planID]
        -- Clear old target, stop if that fails, then one native /targetexact.
        -- A living target here identifies that planned exact name even when
        -- the client doesn't expose UnitName or UnitGUID to Lua.
        if planID and (not planned or (name and name~=planned)) then return end
        name=name or planned
        if AT.db.dungeonPositionEnabled~=false and name then safe(function()
            if planned then
                recordBossSighting(id,usable(label,"string") and label or planned)
            else
                local ids,names=bossIDs(dungeon,id)
                local npc=identity and tonumber(identity:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
                if (npc and ids[npc]) or names[name] then
                    recordBossSighting(id,usable(label,"string") and label or name)
                end
            end
        end) end
        lastTargetLabel=name
        lastPress={name=name or "unknown boss",icon=index,at=GetTime(),
            observed=validRaidIcon(observed) and observed or nil,readable=readable}
        if index==0 then return end

        -- Set-unmarked can refuse if the boss already has another icon.
        -- Such a refusal must not consume a second slot in our ledger.
        if readable and validRaidIcon(observed) and observed~=index then return end
        local prior=reservations[index]
        local function owns(owner)
            if identity and owner.guid then return identity==owner.guid end
            return name~=nil and name==owner.name
        end
        if prior and not owns(prior) then return end
        for other,owner in pairs(reservations) do
            if other~=index and owns(owner) and (not readable or observed~=index) then return end
        end
        if (identity or name) and (not prior or not prior.confirmed) then
            reservations[index]={guid=identity,name=name,confirmed=readable and observed==index,
                token="target",revision=markRevision,attemptedAt=GetTime()}
        end
        lastAttempt={guid=identity,name=name,icon=index,confirmed=readable and observed==index}
        if C_Timer and C_Timer.After and AT.RefreshBossActionBar then C_Timer.After(0,AT.RefreshBossActionBar) end
    end

    function AT.ObserveBossSearch(plan)
        if not searchHit and plans[plan] and context() and safe(InCombatLockdown)~=true
            and safe(SecureCmdOptionParse,"[@target,exists,nodead] yes")=="yes" then
            searchHit=plan
        end
    end

    function AT.FinishBossSearch(index,slot)
        if not context() or safe(InCombatLockdown)==true then return end
        if not searchHit and searchDefault then AT.ObserveBossSearch(searchDefault) end
        if searchHit then
            slot=searchSlots[searchHit] or slot
            AT.ReserveBossMark(index,searchHit)
        end
        searchHit=nil
        if fallbackCount>0 then stockBatch=slot%fallbackCount+1 end
    end

    function AT.RememberBossRecovery(plan)
        if lastTargetLabel then return end
        AT.ReserveBossMark(0,plan)
    end

    function AT.AdvanceBossSearch()
        local _,id=context()
        if not id or fallbackCount<1 then return end
        stockBatch=stockBatch%fallbackCount+1
        if C_Timer and C_Timer.After and AT.RefreshBossActionBar then C_Timer.After(0,AT.RefreshBossActionBar) end
    end

    function AT.InitBossTargetMarking()
        if type(SlashCmdList)=="table" then
            SLASH_NEXUSCHECKBOSSMARK1="/nqtboss"
            SlashCmdList.NEXUSCHECKBOSSMARK=function()
                local active,_,reason=AT.GetBossTargetMacro(true)
                if AT.Say then
                    local message=reason or (active and lastBossMarkNote) or "Boss Target Marking is not active here."
                    if active and lastPress then
                        message=message..(" Last press: %s; %s."):format(lastPress.name,
                            lastPress.icon==0 and "no marker command was sent" or ("requested icon "..lastPress.icon))
                        if lastPress.error then message=message.." Game: "..lastPress.error end
                    end
                    if active and lastAttempt and (not lastPress or lastPress.icon~=0) then
                        local icon,readable=get("target",GetRaidTargetIndex)
                        local guid=safe(UnitGUID,"target")
                        local label=safe(UnitName,"target")
                        local same=(lastAttempt.guid and usable(guid,"string") and lastAttempt.guid==guid)
                            or (not lastAttempt.guid and lastAttempt.name and usable(label,"string") and lastAttempt.name==label:lower())
                        message=message..(" Last attempt: icon %d; %s."):format(lastAttempt.icon,
                            same and readable and (validRaidIcon(icon) and ("target now has icon "..icon) or "target has no readable icon")
                            or "current target cannot verify it")
                    end
                    if active and safe(InCombatLockdown)==true then message="Boss macro paused in combat. "..message end
                    AT.Say(message)
                end
            end
        end
        local watcher=CreateFrame("Frame")
        for _,event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","NAME_PLATE_UNIT_ADDED",
            "NAME_PLATE_UNIT_REMOVED","PLAYER_TARGET_CHANGED","UPDATE_MOUSEOVER_UNIT",
            "RAID_TARGET_UPDATE","INSTANCE_ENCOUNTER_ENGAGE_UNIT","GROUP_ROSTER_UPDATE","UNIT_FLAGS","UNIT_HEALTH","UI_ERROR_MESSAGE"}) do
            pcall(watcher.RegisterEvent,watcher,event)
        end
        local queued
        watcher:SetScript("OnEvent",function(_,event,_,errorText)
            if event=="UI_ERROR_MESSAGE" then
                if lastPress and lastPress.icon~=0 and GetTime()-lastPress.at<1 and usable(errorText,"string") then
                    lastPress.error=errorText:sub(1,110):gsub("[%c|]","")
                end
                return
            end
            if event=="PLAYER_TARGET_CHANGED" then
                lastTargetLabel=nil
                local dungeon,id=context()
                if dungeon then safe(observeReadableBossTarget,dungeon,id) end
            end
            if event=="PLAYER_ENTERING_WORLD" then
                local _,id,kind=instance()
                if id~=lastInstance or (kind~="party" and kind~="raid") then
                    reservations,lastInstance,stockBatch,lastAttempt,lastPress={},nil,1,nil,nil
                    plans,planIDs,lastTargetLabel={},{},nil
                end
            end
            if not AT.db or not AT.db.bossAutoMark then return end
            if event=="RAID_TARGET_UPDATE" then markRevision=markRevision+1 end
            if event=="RAID_TARGET_UPDATE" and safe(InCombatLockdown)~=true then
                -- The action-bar body is prepared between presses. Rebuild
                -- on WoW's marker-change event, not the delayed scan timer.
                if AT.RefreshBossActionBar then AT.RefreshBossActionBar() end
                return
            end
            if queued then return end
            queued=true
            local function update()
                queued=nil
                if AT.RefreshBossActionBar then AT.RefreshBossActionBar() end
            end
            if C_Timer and C_Timer.After then C_Timer.After(.12,update) else update() end
        end)
        -- Range can change without nameplate events. Only compare the owned
        -- macro out of combat; its editor is a no-op if the body is unchanged.
        local elapsed=0
        watcher:SetScript("OnUpdate",function(_,dt)
            if not AT.db or not AT.db.bossAutoMark or safe(InCombatLockdown)==true then return end
            elapsed=elapsed+dt
            if elapsed<.45 then return end
            elapsed=0
            if instance() and AT.RefreshBossActionBar then AT.RefreshBossActionBar() end
        end)
    end
end
