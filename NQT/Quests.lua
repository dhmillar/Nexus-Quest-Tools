local _, AT = ...
local Q, M, S = C_QuestLog, C_Map, C_SuperTrack
local ENTER_YARDS, EXIT_YARDS, ORDER_LIMIT = 100, 125, 10
local focus, ownedWatch, ownedSuper, lastNear, focusFromOrder, running, queued, initialized
local manualHUDQuest, manualWasReady, retiringManual, manualFromMap
local focusTurnIn, observedTurnIn, resolveTurnInPoint, recordedTurnInPoint

local function ordinary(v)
    return not issecretvalue or not issecretvalue(v)
end

local function isType(v, t)
    return ordinary(v) and type(v) == t
end

local function field(value, key)
    if not isType(value, "table") then return end
    local ok, result = pcall(function() return value[key] end)
    if ok and ordinary(result) then return result end
end

local function call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c = pcall(fn, ...)
    if ok then
        if not ordinary(a) then a = nil end
        if not ordinary(b) then b = nil end
        if not ordinary(c) then c = nil end
        return a, b, c
    end
end

local function validID(id)
    return isType(id, "number") and id > 0 and id % 1 == 0
end

function AT.IsQuestExcluded(id)
    local excluded = type(AT.char) == "table" and AT.char.excludedQuests
    return validID(id) and type(excluded) == "table" and excluded[id] == true or false
end

function AT.SetQuestExcluded(id, value)
    if not validID(id) or type(AT.char) ~= "table" then return false end
    if type(AT.char.excludedQuests) ~= "table" then AT.char.excludedQuests = {} end
    AT.char.excludedQuests[id] = value == true and true or nil
    AT.RefreshQuests()
    return true
end

function AT.ToggleQuestExcluded(id)
    return AT.SetQuestExcluded(id, not AT.IsQuestExcluded(id))
end
local function finite(n)
    return isType(n, "number") and n == n and n > -math.huge and n < math.huge
end

local function watched(id)
    return isType(call(Q.GetQuestWatchType, id), "number")
end

local function completed(id)
    if not Q or not validID(id) then return false end
    local ready = call(Q.ReadyForTurnIn, id)
    if ready == true or ready == 1 then return true end
    local state = call(Q.IsComplete, id)
    if state == true or state == 1 then return true end
    -- Some Forever quests appear Ready in the quest log before the dedicated
    -- query updates. Trust only a current log row for this exact quest.
    local index=call(Q.GetLogIndexForQuestID,id)
    if not validID(index) then return false end
    local info=call(Q.GetInfo,index)
    if field(info,"questID")~=id then return false end
    local logState=field(info,"isComplete")
    return logState==true or logState==1
end

AT.IsQuestReadyForTurnIn = completed

function AT.ShouldHideCompletedQuest(id)
    local db=AT.db
    return db and db.enabled and db.hideCompleted and not AT.IsQuestExcluded(id) and manualHUDQuest~=id and not (focus==id and focusTurnIn) and completed(id) or false
end

local function trackingOrder()
    if type(AT.char) ~= "table" then return end
    if type(AT.char.trackingOrder) ~= "table" then AT.char.trackingOrder = {} end
    return AT.char.trackingOrder
end

function AT.GetQuestOrderPosition(id)
    local order = trackingOrder()
    if not order or not validID(id) then return end
    for i = 1, math.min(#order, ORDER_LIMIT) do
        if order[i] == id then return i end
    end
end

function AT.GetTrackingOrderCount()
    local order = trackingOrder()
    return order and math.min(#order, ORDER_LIMIT) or 0
end

local function orderChanged()
    if AT.RefreshQuestOrderBadges then AT.RefreshQuestOrderBadges() end
end

function AT.ResetTrackingOrder()
    if type(AT.char) ~= "table" then return false end
    AT.char.trackingOrder = {}
    AT.RefreshQuests()
    orderChanged()
    return true
end

function AT.ToggleQuestTrackingOrder(id)
    local order = trackingOrder()
    if not order or not validID(id) then return false, "invalid" end
    local position = AT.GetQuestOrderPosition(id)
    if position then
        table.remove(order, position)
        AT.RefreshQuests()
        orderChanged()
        return true, "removed"
    end
    if AT.IsQuestExcluded(id) then return false, "excluded" end
    if completed(id) then return false, "complete" end
    if call(Q and Q.IsOnQuest, id) == false then return false, "invalid" end
    if #order >= ORDER_LIMIT then return false, "full" end
    order[#order + 1] = id
    AT.RefreshQuests()
    orderChanged()
    return true, "added", AT.GetQuestOrderPosition(id)
end

local function nextOrderedQuest()
    local order = trackingOrder()
    if not order then return end
    local changed
    for i = math.min(#order, ORDER_LIMIT), 1, -1 do
        local id = order[i]
        if not validID(id) or AT.IsQuestExcluded(id) or completed(id)
            or call(Q.IsOnQuest, id) == false then
            table.remove(order, i)
            changed = true
        end
    end
    if changed then orderChanged() end
    return order[1]
end
local function getSuper()
    return S and call(S.GetSuperTrackedQuestID)
end

local function save()
    if type(AT.char) ~= "table" then return end
    AT.char.questFocus = focus
    AT.char.questWatchOwned = ownedWatch
    AT.char.questSuperOwned = ownedSuper
    AT.char.questLastNear = lastNear
    AT.char.questFocusFromOrder = focusFromOrder
end

local function release()
    local id = focus
    if not id then return end
    if ownedSuper == id and S and getSuper() == id then
        call(S.SetSuperTrackedQuestID, 0)
    end
    if ownedWatch == id and watched(id) then
        call(Q.RemoveQuestWatch, id)
    end
    focus, ownedWatch, ownedSuper, lastNear, focusFromOrder, focusTurnIn = nil, nil, nil, nil, nil, nil
    save()
end

local function acquire(id,turnIn)
    local added = not watched(id)
    if added then
        local result = call(Q.AddQuestWatch, id)
        if result ~= true and not watched(id) and turnIn then
            -- Some clients need a watch before accepting native super-tracking;
            -- others reject watches on completed quests. Keep local focus either way.
            added=false
        elseif result ~= true and not watched(id) then
            -- A full native tracker can block an otherwise valid switch.
            -- Only free the previous watch if this addon added that watch.
            local old = focus
            if not old or ownedWatch ~= old or not watched(old) then return false end
            local previousSuper = getSuper()
            call(Q.RemoveQuestWatch, old)
            if watched(old) then return false end
            result = call(Q.AddQuestWatch, id)
            if result ~= true and not watched(id) then
                local restored = call(Q.AddQuestWatch, old)
                if restored == true or watched(old) then
                    if S and previousSuper == old and getSuper() ~= old then
                        call(S.SetSuperTrackedQuestID, old)
                    end
                else
                    -- Native state no longer has our previous watch. Rescan on the next tick.
                    release()
                end
                return false
            end
        end
    end
    release()
    focus, focusTurnIn = id, turnIn
    ownedWatch = added and id or nil
    if S then
        local before = getSuper()
        if before ~= id then
            call(S.SetSuperTrackedQuestID, id)
            if getSuper() == id then ownedSuper = id end
        elseif added then
            -- AddQuestWatch itself may select the new watch.
            ownedSuper = id
        end
    end
    save()
    return true
end

local function xyValid(x, y)
    return finite(x) and finite(y) and x >= 0 and x <= 1 and y >= 0 and y <= 1
        and (x ~= 0 or y ~= 0)
end

local function mapContext()
    if not M then return end
    local id = call(M.GetBestMapForUnit, "player")
    if not validID(id) then return end
    local ctx = { id = id }
    local points = call(Q.GetQuestsOnMap, id)
    if isType(points, "table") then ctx.points = points end
    return ctx
end

local function mapPlayer(ctx)
    if ctx.playerChecked then return ctx.px, ctx.py end
    ctx.playerChecked = true
    local w, h = call(M.GetMapWorldSize, ctx.id)
    if not finite(w) or not finite(h) or w <= 0 or h <= 0 then return end
    local pos = call(M.GetPlayerMapPosition, ctx.id, "player")
    local ok, x, y = pcall(function() return pos:GetXY() end)
    if ok and xyValid(x, y) then
        ctx.px, ctx.py, ctx.w, ctx.h = x, y, w, h
        return x, y
    end
end

-- Zone proof is only used when a quest previously had measurable distance
-- and suddenly has none. Child maps and dungeon floors aren't new zones.
local function zoneID(id)
    if not M then return end
    local mapTypes = Enum and Enum.UIMapType
    local zoneType = mapTypes and mapTypes.Zone or 3
    local dungeonType = mapTypes and mapTypes.Dungeon or 4
    for _ = 1, 12 do
        if not validID(id) then return end
        local info = call(M.GetMapInfo, id)
        local kind = field(info, "mapType")
        if kind == zoneType then return id end
        if kind == dungeonType then return end
        id = field(info, "parentMapID")
    end
end

local function worldPosition(mapID, x, y)
    if not M or not CreateVector2D then return end
    local vector = call(CreateVector2D, x, y)
    if not vector then return end
    local world, pos = call(M.GetWorldPosFromMapPos, mapID, vector)
    if not finite(world) or not pos then return end
    local ok, wx, wy = pcall(function() return pos:GetXY() end)
    if ok and finite(wx) and finite(wy) then return world, wx, wy end
end

local function getPlayerWorld(ctx)
    if not ctx then return end
    if not ctx.worldChecked then
        ctx.worldChecked = true
        local position = call(M.GetPlayerMapPosition, ctx.id, "player")
        if position then
            local ok, x, y = pcall(function() return position:GetXY() end)
            if ok and xyValid(x, y) then
                ctx.world, ctx.wx, ctx.wy = worldPosition(ctx.id, x, y)
            end
        end
    end
    return ctx.world, ctx.wx, ctx.wy
end

local rectCache = {}
local function worldRect(mapID)
    if rectCache[mapID] then return rectCache[mapID] end
    local box = {minX=math.huge, minY=math.huge, maxX=-math.huge, maxY=-math.huge}
    for x = 0, 1 do
        for y = 0, 1 do
            local world, wx, wy = worldPosition(mapID, x, y)
            if world == nil or (box.world ~= nil and world ~= box.world) then return end
            box.world = world
            box.minX, box.maxX = math.min(box.minX, wx), math.max(box.maxX, wx)
            box.minY, box.maxY = math.min(box.minY, wy), math.max(box.maxY, wy)
        end
    end
    if box.minX >= box.maxX or box.minY >= box.maxY then return end
    rectCache[mapID] = box
    return box
end

local function noteNear(id, ctx, d2)
    if not ctx then return end
    local zone = zoneID(ctx.id)
    if not zone then return end
    local world, x, y = getPlayerWorld(ctx)
    if world == nil then return end
    lastNear = {id=id, zone=zone, world=world, x=x, y=y, d2=d2}
    save()
end

local function nativeDistance(id, ctx, poi)
    local d, continent = call(Q.GetDistanceSqToQuest, id)
    local native = finite(d) and d>0 and continent==true and d or nil
    if ctx then
        local x, y = call(Q.GetNextWaypointForMap, id, ctx.id)
        local otherMap, otherX, otherY
        if not xyValid(x, y) then
            local mapID, wx, wy = call(Q.GetNextWaypoint, id)
            if mapID == ctx.id then
                x, y = wx, wy
            elseif validID(mapID) and xyValid(wx, wy) then
                otherMap, otherX, otherY = mapID, wx, wy
            end
        end
        if not xyValid(x, y) and poi and field(poi,"isQuestStart")~=true
            and field(poi,"inProgress")~=false then
            x, y = field(poi, "x"), field(poi, "y")
        end
        if xyValid(x, y) then
            local px, py = mapPlayer(ctx)
            if px then
                local world, wx, wy=worldPosition(ctx.id,x,y)
                local playerWorld, playerX, playerY=getPlayerWorld(ctx)
                if world~=nil and world==playerWorld then
                    local dx,dy=playerX-wx,playerY-wy
                    return dx*dx+dy*dy
                end
                local dx,dy=(px-x)*ctx.w,(py-y)*ctx.h
                return dx*dx+dy*dy
            end
        end
        -- A real waypoint on another map is more precise than inferring
        -- range from the player's last zone, including right at a border.
        if otherMap then
            local eventWorld, eventX, eventY = worldPosition(otherMap, otherX, otherY)
            local playerWorld, playerX, playerY = getPlayerWorld(ctx)
            if eventWorld ~= nil and playerWorld ~= nil then
                if eventWorld ~= playerWorld then return math.huge end
                local dx, dy = playerX - eventX, playerY - eventY
                return dx * dx + dy * dy
            end
        end
    end
    if continent == false then return math.huge end
    return native
end

local function distance(id, ctx, poi)
    return nativeDistance(id, ctx, poi)
end
local function proximityContext()
    local ctx=mapContext()
    local points={}
    if ctx then
        for _,poi in ipairs(ctx.points or {}) do
            local id=field(poi,"questID")
            if validID(id) then points[id]=poi end
        end
    end
    -- A roof or cave is not an instance: a valid outdoor zone still
    -- provides quest geometry. Never apply open-world distances in a dungeon.
    local inInstance, instanceKind=call(IsInInstance)
    local parentZone=ctx and zoneID(ctx.id)
    local kind=ctx and field(call(M.GetMapInfo,ctx.id),"mapType")
    local blocked=inInstance==true and instanceKind~="none" or kind==4 or kind==5 and not parentZone
        or not ctx and call(IsIndoors)==true
    local parent
    if not blocked and parentZone and parentZone~=ctx.id then
        parent={id=parentZone}
        local parentPOIs=call(Q.GetQuestsOnMap,parentZone)
        parent.list=parentPOIs
        for _,poi in ipairs(isType(parentPOIs,"table") and parentPOIs or {}) do
            local id=field(poi,"questID")
            if validID(id) then
                parent.points=parent.points or {}
                parent.points[id]=poi
            end
        end
    end
    return ctx,points,parent,blocked
end

local function turnInPin(p)
    return field(p,"isQuestStart")~=true and field(p,"inProgress")==false
end

local function matchesTurnInReference(id,map,x,y)
    local refs=(AT.ForeverVerifiedEndpointReferences and AT.ForeverVerifiedEndpointReferences[id])
        or (AT.ForeverSupplementalTurnInReferences and AT.ForeverSupplementalTurnInReferences[id])
    if not refs then return true end
    local faction=call(UnitFactionGroup,"player")
    local side=faction=="Alliance" and 1 or faction=="Horde" and 2 or -1
    local comparable
    for _,r in ipairs(refs) do
        if r[6]==0 or r[6]==side then
            if r[1]==map then
                comparable=true
                if math.abs(r[2]-x)<=.018 and math.abs(r[3]-y)<=.018 then return true end
            else
                local rw,rx,ry=worldPosition(r[1],r[2],r[3])
                local pw,px,py=worldPosition(map,x,y)
                if rw and pw then
                    comparable=true
                    if rw==pw and (rx-px)^2+(ry-py)^2<=80^2 then return true end
                end
            end
        end
    end
    -- Some native POIs look ready but still point to the old objective.
    -- When we can compare against the known NPC, reject a clear mismatch.
    return not comparable
end

local function turnInDistance(id,ctx,poi,parent,blocked,lookup,onlyZone)
    local function pointDistance(map,x,y,knownContext)
        if not xyValid(x,y) or onlyZone and zoneID(map)~=onlyZone then return end
        -- Use the same yard coordinate system for both local and cross-zone
        -- endpoints when available; indoor and legacy clients still get local geometry.
        if not blocked then
            local world,wx,wy=worldPosition(map,x,y)
            local playerWorld,playerX,playerY=getPlayerWorld(ctx)
            if playerWorld==nil and parent then playerWorld,playerX,playerY=getPlayerWorld(parent) end
            if world~=nil and playerWorld~=nil then
                if world~=playerWorld then return math.huge end
                local dx,dy=wx-playerX,wy-playerY
                return dx*dx+dy*dy,{map,x,y}
            end
        end
        if knownContext then
            local px,py=mapPlayer(knownContext)
            if px then
                local dx,dy=(px-x)*knownContext.w,(py-y)*knownContext.h
                return dx*dx+dy*dy,{map,x,y}
            end
        end
    end
    local function nativePoint(c,p)
        if c and turnInPin(p) then
            local x,y=field(p,"x"),field(p,"y")
            if xyValid(x,y) and matchesTurnInReference(id,c.id,x,y) then return pointDistance(c.id,x,y,c) end
        end
    end
    local d,point=nativePoint(ctx,poi)
    if d then return d,point end
    d,point=nativePoint(parent,parent and parent.points and parent.points[id])
    if d then return d,point end
    -- Generic objective waypoints, blobs and reference-only coordinates
    -- cannot establish that a completed quest is near its actual finisher.
    local map,x,y=observedTurnIn(id,nil,nil,nil,false,true)
    if map and ctx and (not blocked or map==ctx.id) then
        d,point=pointDistance(map,x,y,map==ctx.id and ctx or parent and map==parent.id and parent or nil)
        if d then return d,point end
    end
    if lookup and ctx and not blocked then
        map,x,y=resolveTurnInPoint(id,ctx.id,false,lookup)
        if map then
            d,point=pointDistance(map,x,y,map==ctx.id and ctx or parent and map==parent.id and parent or nil)
            if d or onlyZone and zoneID(map)~=onlyZone then return d,point end
        end
        -- A cross-checked endpoint can inform ranking without masquerading
        -- as a native GPS destination. Ignore ambiguous or wrong-faction rows.
        map,x,y=observedTurnIn(id,nil,nil,nil,"verified",true)
        if not map then map,x,y=observedTurnIn(id,nil,nil,nil,true,true) end
        if map then
            d=pointDistance(map,x,y,map==ctx.id and ctx or parent and map==parent.id and parent or nil)
            if d then return d,{} end
        end
    end
    if onlyZone then return end
    -- Native same-continent distance can describe a ready quest without a
    -- pin, unless the map still advertises it as an unfinished objective.
    -- No coordinates are inferred from this distance.
    local parentPOI=parent and parent.points and parent.points[id]
    if not blocked and field(poi,"inProgress")~=true and field(parentPOI,"inProgress")~=true then
        local native,localWorld=call(Q.GetDistanceSqToQuest,id)
        if finite(native) and native>0 and localWorld==true then return native,{},true end
    end
end

-- Require evidence about where the current objective is, not where it was
-- accepted. Prefer exact waypoint maps; GetQuestUiMapID is a fallback for
-- an incomplete quest when the client supplies only a numeric distance.
local function progressInZone(id,ctx,poi,parent,zone)
    if not zone or not ctx then return end
    local function localPoint(context,row)
        if not context or zoneID(context.id)~=zone then return false end
        local x,y=call(Q.GetNextWaypointForMap,id,context.id)
        return xyValid(x,y) or (field(row,"isQuestStart")~=true and field(row,"inProgress")~=false
            and xyValid(field(row,"x"),field(row,"y")))
    end
    if localPoint(ctx,poi) or parent and localPoint(parent,parent.points and parent.points[id]) then return true end
    local map,x,y=call(Q.GetNextWaypoint,id)
    if validID(map) and xyValid(x,y) then return zoneID(map)==zone end
    local known=zoneID(call(Q.GetQuestUiMapID,id,false))
    if known then return known==zone end
end

local function measureProximity(id,ctx,poi,parent,blocked,limit,forFocus)
    local task=call(GetTaskInfo,id)
    local blob=C_Minimap and call(C_Minimap.IsInsideQuestBlob,id)
    if not forFocus and (task==true or blob==true) then return 0,"inside" end
    if not blocked then
        local dist=distance(id,ctx,poi)
        if parent and (not limit or not dist or dist>limit*limit) then
            local other=distance(id,parent,parent.points and parent.points[id])
            if other and (not dist or other<dist) then dist=other end
        end
        if dist then return dist,limit and dist<=limit*limit and "near" or "outside" end
    end
    if task==true or blob==true then return 0,"inside" end
    if task==false or blob==false then return nil,"possible_exit" end
end

-- Read-only proximity query for Rank Quest's visual highlights. It does
-- not change order, focus, watches, or the navigation destination.
local lastInsideByQuest={}
local function currentAreaPosition(ctx,parent)
    if not ctx then return end
    local world,x,y=getPlayerWorld(ctx)
    local usable=ctx
    local px,py=mapPlayer(usable)
    if not px and parent then usable=parent;px,py=mapPlayer(usable) end
    if px or world~=nil then
        return {world=world,x=x,y=y,map=px and usable.id,px=px and px*usable.w,py=py and py*usable.h}
    end
end
local function distanceFromAreaSample(a,b)
    if not a or not b then return end
    local dx,dy
    if a.world~=nil and b.world~=nil then
        if a.world~=b.world then return math.huge end
        dx,dy=a.x-b.x,a.y-b.y
    elseif a.map and a.map==b.map then
        dx,dy=a.px-b.px,a.py-b.py
    end
    if dx then return dx*dx+dy*dy end
end
function AT.SampleQuestAreas(ids,previous)
    local result={}
    if not Q then return result end
    local ctx,points,parent,blocked=proximityContext()
    for id in pairs(lastInsideByQuest) do if not ids[id] then lastInsideByQuest[id]=nil end end
    local position,checkedPosition
    local radius2=ENTER_YARDS^2+1e-6
    for id in pairs(ids) do
        if validID(id) then
            if blocked or completed(id) or call(Q.IsOnQuest,id)==false then lastInsideByQuest[id]=nil end
            if completed(id) then
                local d=turnInDistance(id,ctx,points[id],parent,blocked)
                if d then result[id]=d<=ENTER_YARDS^2+1e-6 and "near" or "outside" end
            else
                local limit=not lastInsideByQuest[id] and previous and previous[id] and EXIT_YARDS or ENTER_YARDS
                local _,area=measureProximity(id,ctx,points[id],parent,blocked,limit)
                if not blocked and (area=="inside" or lastInsideByQuest[id]) then
                    if not checkedPosition then
                        checkedPosition=true
                        position=currentAreaPosition(ctx,parent)
                    end
                    if area=="inside" then
                        -- Save the last confirmed point inside the objective, not the
                        -- map pin (which can be hundreds of yards from its edge).
                        if position then lastInsideByQuest[id]=position end
                    else
                        local d=distanceFromAreaSample(lastInsideByQuest[id],position)
                        if d and d<=radius2 then area="near"
                        elseif d and area~="near" then area="outside" end
                        if d==math.huge then lastInsideByQuest[id]=nil end
                    end
                end
                if area~="possible_exit" or previous and previous[id]=="inside" then result[id]=area end
            end
        end
    end
    return result
end

local function snapshot()
    local ids = {}
    local shown = call(Q.GetNumQuestLogEntries)
    local size = finite(shown) and math.min(1000, math.max(0, shown)) or 0
    for i = 1, size do
        local info = call(Q.GetInfo, i)
        local id = field(info, "questID")
        if validID(id) and not field(info, "isHeader") and not field(info, "isHidden") then ids[id] = true end
    end
    if AT.GetCachedRankQuestIDs then
        for id in pairs(AT.GetCachedRankQuestIDs() or {}) do
            if validID(id) and call(Q.IsOnQuest,id)==true then ids[id]=true end
        end
    end
    local watches = call(Q.GetNumQuestWatches)
    local count = finite(watches) and math.min(1000, math.max(0, watches)) or 0
    local watchedIDs = {}
    for i = 1, count do
        local id = call(Q.GetQuestIDForQuestWatchIndex, i)
        if validID(id) then
            ids[id] = true
            watchedIDs[#watchedIDs + 1] = id
        end
    end
    return ids, watchedIDs
end

local function activeQuest(id, ids)
    local isOnQuest = call(Q.IsOnQuest, id)
    if isOnQuest ~= nil then return isOnQuest == true end
    local index = call(Q.GetLogIndexForQuestID, id)
    return validID(index) or ids[id] == true
end

local function manualEligible(id, fromMap)
    if not Q or not AT.db or not AT.db.enabled or (not fromMap and not AT.db.questHUDEnabled)
        or not validID(id) or AT.IsQuestExcluded(id) then return false end

    local native=call(Q.IsOnQuest,id)
    if native~=nil then return native==true end
    if validID(call(Q.GetLogIndexForQuestID,id)) then return true end
    local shown=call(Q.GetNumQuestLogEntries)
    for i=1,finite(shown) and math.min(shown,1000) or 0 do
        local info=call(Q.GetInfo,i)
        if field(info,"questID")==id and not field(info,"isHeader") and not field(info,"isHidden") then return true end
    end
    return false
end
function AT.GetQuestHUDManualFocus()
    if manualEligible(manualHUDQuest,manualFromMap) and (manualWasReady or not completed(manualHUDQuest)) then
        return manualHUDQuest
    end
end
local function yieldNativeWaypoint()
    if S and AT.GetSelectedUserWaypoint and AT.GetSelectedUserWaypoint() then
        -- Selecting a quest is explicit. Keep the placed pin, but stop
        -- super-tracking it so the quest selection takes effect at once.
        call(S.SetSuperTrackedUserWaypoint,false)
    end
end
function AT.ToggleQuestHUDManualFocus(id)
    if manualHUDQuest==id and validID(id) then
        retiringManual,manualHUDQuest,manualWasReady,manualFromMap=manualHUDQuest,nil,nil,nil
    elseif manualEligible(id) then
        manualHUDQuest,manualWasReady,manualFromMap=id,completed(id),nil
        yieldNativeWaypoint()
    else return false end
    AT.RefreshQuests()
    if AT.RefreshQuestRoute then AT.RefreshQuestRoute() end
    return true
end

-- Record actual map clicks separately from Blizzard's transient map details
-- selection; closing the map must not cancel explicit navigation.
function AT.FocusQuestFromWorldMap(id)
    if not manualEligible(id,true) then return false end
    yieldNativeWaypoint()
    if manualHUDQuest==id and manualFromMap and AT.GetQuestHUDManualFocus() then
        if AT.RefreshQuestRoute then AT.RefreshQuestRoute() end
        return true
    end
    manualHUDQuest,manualWasReady,manualFromMap=id,completed(id),true
    AT.RefreshQuests()
    if AT.RefreshQuestRoute then AT.RefreshQuestRoute() end
    return true
end

local function run()
    local db = AT.db
    if not db or not Q or (InCombatLockdown and InCombatLockdown()) then return end
    if not db.enabled then manualHUDQuest,manualWasReady,retiringManual,manualFromMap=nil,nil,nil,nil; release(); return end
    if AT.GetSelectedUserWaypoint and AT.GetSelectedUserWaypoint() then return end
    if AT.GetLevelGuideRoutePoint and call(AT.GetLevelGuideRoutePoint)
        and not (manualFromMap and AT.GetQuestHUDManualFocus()) then return end
    if manualHUDQuest and not AT.GetQuestHUDManualFocus() then
        retiringManual,manualHUDQuest,manualWasReady,manualFromMap=manualHUDQuest,nil,nil,nil
    end
    local ids, watchedIDs = snapshot()
    if db.hideCompleted then
        for _, id in ipairs(watchedIDs) do
            if AT.ShouldHideCompletedQuest(id) then call(Q.RemoveQuestWatch, id) end
        end
    end
    if focus and (AT.IsQuestExcluded(focus) or (completed(focus) and focus~=manualHUDQuest and not focusTurnIn) or not activeQuest(focus, ids)) then
        -- Leave a qualifying completed watch alone if that option is disabled.
        if not db.hideCompleted and completed(focus) then ownedWatch = nil end
        release()
    end
    if retiringManual then
        if focus==retiringManual and focus~=manualHUDQuest then release() end
        retiringManual=nil
    end
    if manualHUDQuest then
        if focus~=manualHUDQuest then acquire(manualHUDQuest) end
        if focus==manualHUDQuest then
            focusTurnIn=nil
            if focusFromOrder then focusFromOrder=nil;save() end
            if S and manualFromMap then
                if getSuper()~=focus then call(S.SetSuperTrackedQuestID,focus) end
                if getSuper()==focus and ownedSuper~=focus then ownedSuper=focus;save() end
            end
        end
        -- Explicit intent remains the GPS destination even when a full
        -- native watch list or combat temporarily prevents adding a watch.
        return
    end
    local ordered = nextOrderedQuest()
    if ordered then
        if focus == ordered then
            if not focusFromOrder then focusFromOrder = true; save() end
        elseif acquire(ordered) then
            focusFromOrder = true
            save()
        end
        -- An ordered head remains prioritized out of range, without POIs,
        -- or while the native tracker cannot add another watch.
        return
    elseif focusFromOrder then
        release()
    end
    if not db.autoFocus then release(); return end
    local ctx,poiByID,parent,blocked=proximityContext()
    for id in pairs(poiByID) do
        if activeQuest(id,ids) then ids[id]=true end
    end
    local best,bestDist,bestTurnIn,areaFallback
    local currentZone=not blocked and ctx and zoneID(ctx.id)
    local mapLists,remaining={},24
    if ctx then mapLists[ctx.id]=ctx.points or false end
    if parent then mapLists[parent.id]=parent.list or false end
    local function lookup(map)
        if mapLists[map]==nil and remaining>0 then
            remaining=remaining-1
            mapLists[map]=call(Q.GetQuestsOnMap,map) or false
        end
        return mapLists[map]
    end
    local function consider(id,d,point)
        if finite(d) and d>=0 and (not bestDist or d<bestDist
            or d==bestDist and (id==focus or best~=focus and id<best)) then
            best,bestDist,bestTurnIn=id,d,point
        end
    end
    for id in pairs(ids) do
        if not AT.IsQuestExcluded(id) then
            local d,turnIn
            if completed(id) then
                if currentZone and activeQuest(id,ids) then
                    d,turnIn=turnInDistance(id,ctx,poiByID[id],parent,blocked,lookup,currentZone)
                    consider(id,d,turnIn)
                end
            else
                local localObjective=progressInZone(id,ctx,poiByID[id],parent,currentZone)
                local dist,how=measureProximity(id,ctx,poiByID[id],parent,blocked or not localObjective,nil,true)
                if how=="inside" and localObjective~=false then
                    -- Being inside a broad objective area is not a measured
                    -- zero-yard route and must not outrank a measured hand-in.
                    if not areaFallback or id==focus or areaFallback~=focus and id<areaFallback then areaFallback=id end
                elseif localObjective then
                    consider(id,dist)
                end
            end
        end
    end

    best=best or areaFallback
    if best then
        if best==focus or acquire(best,bestTurnIn) then
            focusTurnIn=bestTurnIn
            noteNear(best,ctx,bestDist)
        end
    elseif focus then
        release()
    end
end

-- Navigation follows the first eligible order entry even if Blizzard's quest
-- watch list is full or the UI watch API has not caught up with the queue.
function AT.GetQuestNavigationID()
    if not Q or not AT.db or not AT.db.enabled then return end
    local mapManual=manualFromMap and AT.GetQuestHUDManualFocus()
    if mapManual then return mapManual,"hud" end
    local guideQuest=call(AT.GetLevelGuideRoutePoint)
    if validID(guideQuest) then return guideQuest,"guide" end
    local manual=AT.GetQuestHUDManualFocus()
    if manual then return manual,"hud" end
    local order = trackingOrder()
    for i=1,order and math.min(#order, ORDER_LIMIT) or 0 do
        local id = order[i]
        if validID(id) and not AT.IsQuestExcluded(id) and not completed(id)
            and call(Q.IsOnQuest,id) ~= false then return id,"order" end
    end
    if AT.db.autoFocus and focusTurnIn and completed(focus) and not AT.IsQuestExcluded(focus)
        and call(Q.IsOnQuest,focus)~=false then return focus,"nearby-turn-in" end
    -- Explicitly selecting a quest in the stock UI also drives the HUD;
    -- it is not necessary to have Auto Track's nearest-focus mode enabled.
    local selected = S and call(S.GetSuperTrackedQuestID)
    if validID(selected) and not AT.IsQuestExcluded(selected) then
        if completed(selected) then
            if selected~=ownedSuper and call(Q.IsOnQuest,selected)==true then return selected,"turn-in" end
        elseif call(Q.IsOnQuest,selected) ~= false or (C_TaskQuest and call(C_TaskQuest.IsActive,selected) == true) then
            return selected,"selected"
        end
    end
    if AT.db.autoFocus and focus and not focusFromOrder
        and not completed(focus) and not AT.IsQuestExcluded(focus) and call(Q.IsOnQuest,focus)~=false then return focus,"nearby" end
    -- With no explicit selection and exactly one normal quest being watched,
    -- it is unambiguous which quest the player has asked to track.
    if call(Q.GetNumQuestWatches)==1 then
        local id = call(Q.GetQuestIDForQuestWatchIndex,1)
        if validID(id) and not AT.IsQuestExcluded(id) then
            local held=call(Q.IsOnQuest,id)
            local ctx,poiByID,parent,blocked=proximityContext()
            local zone=not blocked and ctx and zoneID(ctx.id)
            if completed(id) then
                if held==true and zone then
                    local m=resolveTurnInPoint(id,ctx.id,false)
                    if not m then m=recordedTurnInPoint(id) end
                    if zoneID(m)==zone then return id,"turn-in" end
                end
            elseif held~=false and progressInZone(id,ctx,poiByID[id],parent,zone) then
                return id,"watched"
            end
        end
    end
end
function AT.IsQuestTurnInNavigation(id)
    if not validID(id) or not completed(id) then return false end
    local active,source=AT.GetQuestNavigationID()
    return active==id and (source=="hud" or source=="turn-in" or source=="nearby-turn-in")
end

local function nativeTurnIn(id,map,lookup)
    if not validID(map) then return end
    local points
    if lookup then points=lookup(map) else points=call(Q.GetQuestsOnMap,map) end
    if not isType(points,"table") then return end
    for _,p in ipairs(points) do
        -- The Forever quest POI API distinguishes starts and in-progress pins.
        if field(p,"questID")==id and turnInPin(p) then
            local x,y=field(p,"x"),field(p,"y")
            if xyValid(x,y) and matchesTurnInReference(id,map,x,y) then return map,x,y end
        end
    end
end

-- Keep a small session-local index of maps where the client has already
-- exposed real ready-for-turn-in POIs. Keep the map IDs, never coordinates:
-- always re-query the native pin so changed phasing does not reuse stale data.
local nativeTurnInMaps={}
local turnInMapCount=0
local function rememberTurnInMap(quest,map)
    if call(Q.IsOnQuest,quest)~=true then return end
    if nativeTurnInMaps[quest]==nil then
        if turnInMapCount>=64 then return end
        turnInMapCount=turnInMapCount+1
    end
    nativeTurnInMaps[quest]=map
end
local function forgetTurnInMap(quest)
    if validID(quest) and nativeTurnInMaps[quest] then
        nativeTurnInMaps[quest]=nil
        turnInMapCount=turnInMapCount-1
    end
end


-- EG Link records actual turn-in offers. Do not guess a destination from a
-- generic waypoint or choose between two distinct recorded finishers.
-- Independently checked reference turn-ins; never route to these without a
-- native pin. For 26 and 161 the exact quest names the NPC, whose position is
-- independently observed in Forever by Efficient Games on other quests.
-- https://www.wowhead.com/forever/quest=26/a-lesson-to-learn
-- https://www.wowhead.com/forever/quest=161/a-dark-threat-looms
-- Data from Efficient Games (https://efficient.games), licensed under CC BY 4.0.
-- Westfall 103/104/140 coordinates adapted from AllTheThings (MIT).
-- https://github.com/ATTWoWAddon/AllTheThings ; license notice in README.
local referenceTurnIns={
    [26]={{1450,.5622,.305,1,11802,0,"Dendrite Starblaze"}},
    [103]={{1436,.300,.860,1,392,0,"Captain Grayson"}},
    [104]={{1436,.300,.860,1,392,0,"Captain Grayson"}},
    [140]={{1436,.2597,.1690,2,33,0,"Locked Chest"}},
    [161]={{1437,.5014,.1827,1,1073,1,"Ashlan Stonesmirk"}},
    [623]={{1445,.688,.532,1,2616,1,"Privateer Groy"}},
}
observedTurnIn=function(id,map,x,y,reference,skipName)
    local source
    local verifiedCompletion=AT.NQTDB and AT.NQTDB.VerifiedCompletionTurnIns
    local fresh=verifiedCompletion and verifiedCompletion[id]
    if reference=="verified" then
        source=fresh or (AT.ForeverVerifiedEndpointReferences and AT.ForeverVerifiedEndpointReferences[id])
    elseif reference then
        source=fresh or referenceTurnIns[id] or (AT.ForeverQuestNPCReferences and AT.ForeverQuestNPCReferences[id])
            or (AT.ForeverATTQuestNPCReferences and AT.ForeverATTQuestNPCReferences[id])
            or (AT.ForeverVerifiedEndpointReferences and AT.ForeverVerifiedEndpointReferences[id])
            or (AT.ForeverSupplementalTurnInReferences and AT.ForeverSupplementalTurnInReferences[id])
            or (AT.NQTDB and AT.NQTDB.TurnIns and AT.NQTDB.TurnIns[id])
            or (AT.NQTDB and AT.NQTDB.CorroboratedTurnInLabels and AT.NQTDB.CorroboratedTurnInLabels[id])
    else
        source=AT.ObservedQuestTurnIns and AT.ObservedQuestTurnIns[id]
    end
    if not isType(source,"table") then return end
    local faction=call(UnitFactionGroup,"player")
    local side=faction=="Alliance" and 1 or faction=="Horde" and 2 or -1
    local found
    for _,p in ipairs(source) do
        local m,px,py,kind,entity,access=unpack(p)
        if validID(m) and xyValid(px,py) and (access==0 or access==side)
            and (not map or map==m and math.abs(x-px)<=.012 and math.abs(y-py)<=.012) then
            if not found then found=p
            elseif found[1]~=m or found[4]~=kind or found[5]~=entity
                or math.abs(found[2]-px)>.012 or math.abs(found[3]-py)>.012 then return end
        end
    end
    if not found then return end
    local m,px,py,kind,entity,_,name=unpack(found)
    if skipName then return m,px,py end
    if kind==1 then
        local locale=call(GetLocale)
        if locale~="enUS" and locale~="enGB" then
            name=nil
        elseif not reference and (not isType(name,"string") or name=="") then
            local names=AT.NQTDB and AT.NQTDB.ObservedTurnInNames
            local exact=names and names[id]
            if exact and exact[1]==entity then name=exact[2] end
        end
        for _,unit in ipairs({"npc","target","mouseover"}) do
            local guid=call(UnitGUID,unit)
            local npc=isType(guid,"string") and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
            if npc==entity then
                local actual=call(UnitName,unit)
                if isType(actual,"string") and actual~="" then name=actual;break end
            end
        end
    end
    if not isType(name,"string") or name=="" then name=nil end
    return m,px,py,name,kind==1 and name~=nil
end

local function roamingTurnIn(id)
    local identities=AT.NQTDB and AT.NQTDB.RoamingTurnInIdentities
    return identities and identities[id]
end

local function roamingLabel(id,row)
    if not row or call(Q.IsOnQuest,id)~=true then return end
    local faction=call(UnitFactionGroup,"player")
    local side=faction=="Alliance" and 1 or faction=="Horde" and 2 or -1
    if row[5]~=0 and row[5]~=side then return end
    local seen=0
    for _,p in ipairs(AT.ObservedQuestTurnIns and AT.ObservedQuestTurnIns[id] or {}) do
        if p[6]==0 or p[6]==side then
            if p[1]~=row[1] or p[4]~=1 or p[5]~=row[2] then return end
            seen=seen+1
        end
    end
    if seen<2 then return end
    for _,unit in ipairs({"npc","target","mouseover"}) do
        local guid=call(UnitGUID,unit)
        local npc=isType(guid,"string") and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
        if npc==row[2] then
            local name=call(UnitName,unit)
            if isType(name,"string") and name~="" then return name,row[4] end
        end
    end
    local locale=call(GetLocale)
    if locale=="enUS" or locale=="enGB" then return row[3],row[4] end
end

resolveTurnInPoint=function(id,viewMap,wantName,lookup)
    local visited={}
    local function chain(map)
        for _=1,4 do
            if not validID(map) or visited[map] then break end
            visited[map]=true
            local m,x,y=nativeTurnIn(id,map,lookup)
            if m then return m,x,y end
            local info=M and call(M.GetMapInfo,map)
            map=field(info,"parentMapID")
        end
    end
    -- A generic waypoint can suggest which map to inspect, but never becomes
    -- a destination by itself: it may still point to the last objective.
    local m,x,y
    if validID(viewMap) then
        m,x,y=nativeTurnIn(id,viewMap,lookup)
        visited[viewMap]=true
    end
    local hint=call(Q.GetNextWaypoint,id)
    if not m then m,x,y=chain(hint) end
    if not m then m,x,y=chain(M and call(M.GetBestMapForUnit,"player")) end
    if not m then m,x,y=chain(call(Q.GetMapForQuestPOIs)) end
    if not m and WorldMapFrame then m,x,y=chain(call(WorldMapFrame.GetMapID,WorldMapFrame)) end
    local origins=AT.char and AT.char.zoneQuestOrigins
    if not m then m,x,y=chain(field(origins,id)) end
    if not m then m,x,y=chain(nativeTurnInMaps[id]) end
    -- A reference may tell us where to ask the client, not where to route.
    if not m then
        local faction=call(UnitFactionGroup,"player")
        local side=faction=="Alliance" and 1 or faction=="Horde" and 2 or -1
        local budget=8
        local function queryHints(pack)
            for _,p in ipairs(pack and pack[id] or {}) do
                local map,access=p[1],p[6]
                if validID(map) and not visited[map] and (access==0 or access==side) then
                    visited[map]=true
                    budget=budget-1
                    m,x,y=nativeTurnIn(id,map,lookup)
                    if m or budget==0 then return true end
                end
            end
        end
        if not queryHints(AT.ObservedQuestTurnIns) and not queryHints(AT.NQTDB and AT.NQTDB.VerifiedCompletionTurnIns)
            and not queryHints(referenceTurnIns) and not queryHints(AT.ForeverQuestNPCReferences) and not queryHints(AT.ForeverATTQuestNPCReferences) then
            if not queryHints(AT.ForeverVerifiedEndpointReferences) and not queryHints(AT.ForeverSupplementalTurnInReferences) then
                if not queryHints(AT.NQTDB and AT.NQTDB.TurnIns) then
                    queryHints(AT.NQTDB and AT.NQTDB.CorroboratedTurnInLabels)
                end
            end
        end
    end
    if m then rememberTurnInMap(id,m) end
    if m and not wantName then return m,x,y end
    local roaming=roamingTurnIn(id)
    if roaming then
        local name
        if m==roaming[1] and wantName then name=roamingLabel(id,roaming) end
        return m,x,y,name,name~=nil
    end
    local knownMap,kx,ky,label,npcOnly=observedTurnIn(id,m,x,y)
    if knownMap then
        return m or knownMap,x or kx,y or ky,wantName and label or nil,wantName and npcOnly or nil
    end
    if wantName then
        local ref,rx,ry,npc,clickable=observedTurnIn(id,m,x,y,true)
        if ref then return m or ref,x or rx,y or ry,npc,clickable,not m end
    end
    return m,x,y
end

recordedTurnInPoint=function(id)
    -- Never paper over a conflicting observation, or route to a
    -- floor placeholder, a quest giver, or a previous objective.
    if roamingTurnIn(id) or call(Q.IsOnQuest,id)~=true or (AT.ObservedQuestTurnIns and AT.ObservedQuestTurnIns[id]) then return end
    local inside,kind=call(IsInInstance)
    if inside==true and kind~="none" then return end
    local m,x,y=observedTurnIn(id,nil,nil,nil,"verified",true)
    if m and zoneID(m)==m then return m,x,y,"verified turn-in" end
    local rows=(AT.ForeverSupplementalTurnInReferences and AT.ForeverSupplementalTurnInReferences[id])
        or (AT.NQTDB and AT.NQTDB.TurnIns[id])
    if not isType(rows,"table") or #rows~=1 then return end
    local r=rows[1]
    local faction=call(UnitFactionGroup,"player")
    local side=faction=="Alliance" and 1 or faction=="Horde" and 2 or -1
    if r[4]==1 and validID(r[5]) and isType(r[7],"string") and r[7]~=""
        and (r[6]==0 or r[6]==side) and xyValid(r[2],r[3]) and validID(r[1]) and zoneID(r[1])==r[1] then
        return r[1],r[2],r[3],"recorded NPC location"
    end
end

function AT.GetQuestTurnInPoint(id,viewMap)
    if not AT.IsQuestTurnInNavigation(id) then return end
    if focus==id and focusTurnIn and focusTurnIn[1] and not AT.GetQuestHUDManualFocus() then return unpack(focusTurnIn) end
    local m,x,y=resolveTurnInPoint(id,viewMap,false)
    if m then return m,x,y end
    return recordedTurnInPoint(id)
end

-- Displaying a destination should never select the quest, watch it, or change GPS.
-- This reference can label a ready quest even if no floor pin is available.
-- Never return it as a waypoint or expose untranslated macro target names.
function AT.GetReadyQuestTurnInArea(id)
    if not completed(id) or call(Q.IsOnQuest,id)==false then return end
    local locale=call(GetLocale)
    if locale~="enUS" and locale~="enGB" then return end
    local roaming=roamingTurnIn(id)
    if roaming then
        local name,area=roamingLabel(id,roaming)
        if name then return area,name,true end
        return
    end
    local row=AT.ForeverTurnInAreaReferences and AT.ForeverTurnInAreaReferences[id]
    if not row then return end
    local faction=call(UnitFactionGroup,"player")
    local side=faction=="Alliance" and 1 or faction=="Horde" and 2 or -1
    if row[4]==0 or row[4]==side then return row[1],row[2],row[3] end
end

function AT.GetReadyQuestTurnInPoint(id,viewMap)
    if not completed(id) or call(Q.IsOnQuest,id)==false then return end
    return resolveTurnInPoint(id,viewMap,true)
end

-- A routing backend compares all verified, currently available points on
-- this UI map. Quest choice remains with the tracker or the ordered queue.
-- Match the live quest by objective identity, not by catalog display order.
local observedObjectiveIDs={
    item={"itemID","itemId"},
    monster={"npcID","creatureID","monsterID"},
    object={"objectID","objectId"},
}
local function liveObjectiveID(id,o,kind)
    local found
    for _,key in ipairs(observedObjectiveIDs[kind]) do
        local ok,v=pcall(function()return o[key] end)
        if not ok or not ordinary(v) then return nil,true end
        if v~=nil then
            if not validID(v) or found and found~=v then return nil,true end
            found=v
        end
    end
    if not found and kind=="item" then
        local label=field(o,"text")
        if isType(label,"string") and label~="" then
            found=call(AT.ResolveRankQuestObjectiveItem,id,o,label)
        end
    end
    return validID(found) and found or nil,false
end

function AT.GetObservedQuestObjectiveSpots(id,map)
    local db=AT.NQTDB
    local refs=db and db.ObjectiveSpots and db.ObjectiveSpots[id]
    local objects=db and db.ObjectPickupApproaches and db.ObjectPickupApproaches[id]
    local uses=db and db.TargetedItemApproaches and db.TargetedItemApproaches[id]
    local sameCount=db and db.ExactDuplicateApproaches and db.ExactDuplicateApproaches[id]
    if not (refs or objects or uses or sameCount) or call(Q.IsOnQuest,id)~=true or completed(id) then return end
    local inside,kind=call(IsInInstance)
    if inside==true and kind~="none" or zoneID(map)~=map then return end
    local live=call(Q.GetQuestObjectives,id)
    if not isType(live,"table") then return end

    local rows,counts,buckets={}, {}, {}
    local function signature(typ,required)
        return observedObjectiveIDs[typ] and validID(required) and typ..":"..required or nil
    end
    local function remember(observations,fallback,requiresItem,requireIdentity)
        for index,r in pairs(observations or {}) do
            local key=signature(r[1],r[3])
            local available=true
            if requiresItem then
                local count=validID(r[5]) and call(C_Item and C_Item.GetItemCount or GetItemCount,r[5],false,false)
                available=validID(count) and not (objects and objects[index])
            end
            if key and available and (not fallback or not (refs and refs[index])) and
                (not requireIdentity or not (objects and objects[index] or uses and uses[index])) then
                rows[#rows+1]={index=index,record=r,key=key,requireIdentity=requireIdentity}
                counts[key]=(counts[key] or 0)+1
            end
        end
    end
    remember(refs,false)
    remember(objects,true)
    remember(uses,true,true)
    remember(sameCount,true,false,true)
    table.sort(rows,function(a,b)return a.index<b.index end)
    for _,o in ipairs(live) do
        local typ=field(o,"type")
        if typ=="gameObject" then typ="object" end
        local key=signature(typ,field(o,"numRequired"))
        if key and counts[key] then
            local typed,blocked=liveObjectiveID(id,o,typ)
            local b=buckets[key]
            if not b then b={};buckets[key]=b end
            b[#b+1]={typed=typed,blocked=blocked,unfinished=field(o,"finished")==false}
        end
    end
    local points={}
    for _,entry in ipairs(rows) do
        local r,key=entry.record,entry.key
        local b=buckets[key]
        if b then
            local exact,matches
            for _,o in ipairs(b) do
                if not o.blocked and o.typed==r[2] then
                    exact=o
                    matches=(matches or 0)+1
                end
            end
            local only=b[1]
            if matches==1 and exact.unfinished
                or not entry.requireIdentity and not matches and #b==1 and counts[key]==1 and not only.blocked and not only.typed and only.unfinished then
                for _,p in ipairs(r[4]) do
                    if p[1]==map and xyValid(p[2],p[3]) then points[#points+1]=p end
                end
            end
        end
    end
    return points
end

function AT.GetFocusedQuestRouteTargets(mapID)
    local id,source = AT.GetQuestNavigationID()
    if not id then return end
    local ctx = mapContext()
    if not ctx or ctx.id ~= mapID then return id end
    local targets, seen, backups = {}, {}, {}
    local function capture(x, y, otherMap, into)
        if not xyValid(x, y) then return end
        local useMap = otherMap or mapID
        if useMap ~= mapID then
            -- Accept only a known neighboring outdoor map in this walking world.
            if zoneID(useMap) ~= useMap then return end
            local world = getPlayerWorld(ctx)
            local targetWorld = worldPosition(useMap, x, y)
            if world == nil or targetWorld ~= world then return end
        end
        local key = useMap .. ":" .. x .. ":" .. y
        if seen[key] then return end
        seen[key] = true
        into=into or targets
        into[#into+1] = {map=useMap, x=x, y=y}
    end
    -- An explicitly tracked Level Guide giver is a distinct destination.
    -- Never walk to a native objective for an unaccepted guide quest.
    if source=="guide" then
        local ok,q,m,x,y=pcall(AT.GetLevelGuideRoutePoint)
        if ok and validID(q) and q==id and validID(m) and zoneID(m)==m and zoneID(mapID)==mapID and call(IsInInstance)~=true then
            capture(x,y,m)
        end
        return id,targets,backups
    end
    if AT.IsQuestTurnInNavigation(id) then
        local m,x,y=AT.GetQuestTurnInPoint(id,mapID)
        if m then capture(x,y,m) end
        -- Only an independently verified same-quest turn-in near the native
        -- destination can back up a hand-in. Never substitute an objective.
        if #targets>0 and not roamingTurnIn(id) and completed(id) and call(Q.IsOnQuest,id)==true
            and call(IsInInstance)~=true and zoneID(m)==m then
            local world,wx,wy=worldPosition(m,x,y)
            if world~=nil then
                for _,mode in ipairs({"observed","verified"}) do
                    local reference=mode=="verified" and "verified" or nil
                    local hit,hx,hy=observedTurnIn(id,m,x,y,reference,true)
                    if hit==m then
                        local w,px,py=worldPosition(m,hx,hy)
                        if w==world and (wx-px)^2+(wy-py)^2<=30*30 then capture(hx,hy,m,backups) end
                    end
                end
            end
        end
        return id,targets,backups
    end
    if AT.GetNativeQuestRoutePointForMap then
        local nx,ny=call(AT.GetNativeQuestRoutePointForMap,id,mapID)
        capture(nx,ny)
    end
    local ox,oy=call(Q.GetNextWaypointForMap,id,mapID)
    capture(ox,oy)
    local waypointMap, x, y = call(Q.GetNextWaypoint, id)
    if validID(waypointMap) then capture(x,y,waypointMap) end
    for _, poi in ipairs(ctx.points or {}) do
        if field(poi, "questID") == id then capture(field(poi, "x"), field(poi, "y")) end
    end
    local into=#targets==0 and targets or backups
    for _,p in ipairs(AT.GetObservedQuestObjectiveSpots(id,mapID) or {}) do capture(p[2],p[3],p[1],into) end
    local function rank(a,b)
        if a.map~=b.map then
            if a.map==mapID then return true end
            if b.map==mapID then return false end
            return a.map<b.map
        end
        return a.x==b.x and a.y<b.y or a.x<b.x
    end
    table.sort(targets,rank)
    table.sort(backups,rank)
    return id,targets,backups
end
function AT.GetFocusedQuestRoutePoint()
    local focus,source = AT.GetQuestNavigationID()
    if source=="guide" then return AT.GetLevelGuideRoutePoint() end
    if not focus then return end
    if AT.IsQuestTurnInNavigation(focus) then
        return focus, AT.GetQuestTurnInPoint(focus)
    end
    local ctx = mapContext()
    local waypointMap, waypointX, waypointY = call(Q.GetNextWaypoint, focus)
    if ctx then
        local x, y = call(Q.GetNextWaypointForMap, focus, ctx.id)
        if xyValid(x, y) then return focus, ctx.id, x, y end
        if waypointMap == ctx.id and xyValid(waypointX, waypointY) then
            return focus, ctx.id, waypointX, waypointY
        end
        for _, poi in ipairs(ctx.points or {}) do
            if field(poi, "questID") == focus then
                x, y = field(poi, "x"), field(poi, "y")
                if xyValid(x, y) then return focus, ctx.id, x, y end
            end
        end
    end
    if validID(waypointMap) and xyValid(waypointX, waypointY) then
        return focus, waypointMap, waypointX, waypointY
    end
    if ctx then
        local px,py=mapPlayer(ctx)
        local best,cost
        if xyValid(px,py) then
            for _,p in ipairs(AT.GetObservedQuestObjectiveSpots(focus,ctx.id) or {}) do
                local d=(p[2]-px)^2+(p[3]-py)^2
                if not cost or d<cost then best,cost=p,d end
            end
        end
        if best then return focus,best[1],best[2],best[3],"observed objective area" end
    end
    return focus
end
function AT.GetFocusedQuestID()
    return focus
end

function AT.RefreshQuests()
    if running then return end
    running = true
    local perf=AT.PerfBegin and AT.PerfBegin()
    local ok, err = pcall(run)
    if perf then AT.PerfEnd("Quest focus",perf) end
    running = nil
    if not ok and AT.db and AT.db.debug then
        local handler = geterrorhandler and geterrorhandler()
        if handler then handler(err) end
    end
end

local function schedule(delay)
    if queued then return end
    queued = true
    C_Timer.After(delay or 0, function()
        queued = nil
        AT.RefreshQuests()
    end)
end

function AT.ForgetRemovedQuest(id)
    forgetTurnInMap(id)
    if not validID(id) then return end
    local changed
    local order=trackingOrder()
    if order then
        for i=#order,1,-1 do
            if order[i]==id then table.remove(order,i);changed=true end
        end
    end
    if id==manualHUDQuest then
        retiringManual,manualHUDQuest,manualWasReady,manualFromMap=manualHUDQuest,nil,nil,nil
        changed=true
    end
    if changed and AT.RefreshQuestRoute then AT.RefreshQuestRoute() end
    if changed then orderChanged() end
    schedule()
end

-- Inspect the same candidates as auto-focus without changing the active watch.
function AT.ReportRankQuestTurnIns()
    if not Q or not AT.Say then return end
    local ctx,pois,parent,blocked=proximityContext()
    local ids=snapshot()
    for id in pairs(pois) do if activeQuest(id,ids) then ids[id]=true end end
    local lists,budget={},24
    if ctx then lists[ctx.id]=ctx.points or false end
    if parent then lists[parent.id]=parent.list or false end
    local function lookup(map)
        if lists[map]==nil and budget>0 then
            budget=budget-1;lists[map]=call(Q.GetQuestsOnMap,map) or false
        end
        return lists[map]
    end
    local rows={}
    for id in pairs(ids) do
        if activeQuest(id,ids) and completed(id) then
            local d,point,estimated=turnInDistance(id,ctx,pois[id],parent,blocked,lookup)
            rows[#rows+1]={id=id,d=finite(d) and d or math.huge,estimated=estimated,point=point}
        end
    end
    table.sort(rows,function(a,b) if a.d~=b.d then return a.d<b.d end return a.id<b.id end)
    local chosen,source=AT.GetQuestNavigationID()
    AT.Say(("Ready quests: %d | map %s | focus %s (%s)"):format(#rows,ctx and ctx.id or "unknown",chosen or "none",source or "none"))
    for i=1,math.min(10,#rows) do
        local r=rows[i]
        local title=call(Q.GetTitleForQuestID,r.id)
        if not isType(title,"string") then title="Quest" end
        local detail=r.d==math.huge and "no comparable distance"
            or ((r.estimated and "~" or "")..math.floor(math.sqrt(r.d)+.5).." yd")
        if AT.IsQuestExcluded(r.id) then detail=detail.."; excluded" end
        AT.Say(("%s (#%d): %s"):format(title,r.id,detail))
    end
end

function AT.InitQuests()
    if initialized then return end
    initialized = true
    if type(SlashCmdList)=="table" then
        SLASH_NQTTURNINS1="/nqtturnins"
        SlashCmdList.NQTTURNINS=AT.ReportRankQuestTurnIns
    end
    if type(AT.char) == "table" and validID(AT.char.questFocus) then
        focus = AT.char.questFocus
        ownedWatch = AT.char.questWatchOwned == focus and focus or nil
        ownedSuper = AT.char.questSuperOwned == focus and focus or nil
        focusFromOrder = AT.char.questFocusFromOrder == true and true or nil
        local origin = AT.char.questLastNear
        if type(origin) == "table" and origin.id == focus and validID(origin.zone)
            and finite(origin.world) and finite(origin.x) and finite(origin.y)
            and finite(origin.d2) and origin.d2 >= 0 then
            lastNear = origin
        end
    end
    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent",function(_,event,id)
        if event=="QUEST_TURNED_IN" or event=="QUEST_REMOVED" then AT.ForgetRemovedQuest(id)
        else
            if event=="QUEST_ACCEPTED" then forgetTurnInMap(id) end
            -- The native log can emit a burst of updates per combat or loot
            -- action. Coalesce routine updates into one proximity scan.
            local routine=event=="QUEST_LOG_UPDATE" or event=="QUEST_WATCH_UPDATE" or event=="QUEST_WATCH_LIST_CHANGED"
            schedule(routine and .22 or 0)
        end
    end)
    local events = {
        "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_MAP_CHANGED",
        "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
        "QUEST_ACCEPTED", "QUEST_COMPLETE", "QUEST_FINISHED", "QUEST_LOG_UPDATE",
        "QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_WATCH_UPDATE", "QUEST_WATCH_LIST_CHANGED",
    }
    for _, e in ipairs(events) do pcall(frame.RegisterEvent, frame, e) end
    C_Timer.NewTicker(1.5, AT.RefreshQuests)
    schedule()
end















