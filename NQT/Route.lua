local _, AT = ...
local frame, lines, caption, elapsed = nil, nil, nil, 0
local refreshPeriod, enterAreaYards, leaveAreaYards = 0.3, 35, 52
local previewYards, renderLimit, offPathYards = 90, 30, 24
local currentPath, cursor, projected, arrival, currentProjectionMap
local scopeQuest, scopeTurnIn, scopeGuide, scopeWaypoint, positionLost, routeStatus, statusQuest
local meter, metadata, travelDetail, measure, mapRoute
local bearing, bearingStatus, distanceSource, selectionSource, drawFailure

local function ordinary(value)
    return not issecretvalue or not issecretvalue(value)
end

local function finite(value)
    return ordinary(value) and type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b,c=pcall(fn,...)
    if ok then return a,b,c end
end

local function zoneChart(map,cache)
    local maps=C_Map
    if not (maps and CreateVector2D and finite(map)) then return end
    local a=cache.chart
    local now=not a and GetTime and GetTime() or 0
    if a==nil or a==false and cache.chartRetryAt and now>=cache.chartRetryAt then
        local info=call(maps.GetMapInfo,map)
        local zone=Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
        local chartWorld
        local function sample(u,v)
            local w,p=call(maps.GetWorldPosFromMapPos,map,CreateVector2D(u,v))
            if finite(w) and (not chartWorld or chartWorld==w) and ordinary(p) and p then
                chartWorld=w
                local x,y=call(p.GetXY,p)
                if finite(x) and finite(y) then return x,y end
            end
        end
        if ordinary(info) and type(info)=="table" and finite(info.mapType) and info.mapType==zone then
            local x,y=sample(.25,.25)
            local rx,ry=sample(.75,.25)
            local sx,sy=sample(.25,.75)
            local tx,ty=sample(.75,.75)
            local mx,my=sample(.5,.5)
            if x and rx and sx and tx and mx and math.abs(tx-rx-sx+x)<=.5 and math.abs(ty-ry-sy+y)<=.5
                and math.abs(mx-(rx+sx)/2)<=.5 and math.abs(my-(ry+sy)/2)<=.5 then
                local xx,xy,yx,yy=2*(rx-x),2*(ry-y),2*(sx-x),2*(sy-y)
                local det=xx*yy-xy*yx
                if finite(det) and math.abs(det)>1 then a={x,y,xx,xy,yx,yy,det,chartWorld,map} end
            end
        end
        cache.chart=a or false
        if not a then cache.chartRetryAt=now+2 end
    end
    if a and a[9]==map then return a end
end

-- The native inverse often refuses to return coordinates outside a zone's
-- bounds. For an already verified world route, validate the destination
-- chart's local transform before clipping a short cross-boundary segment.
function AT.ProjectRouteZoneBoundary(world,pos,map,cache)
    if not (finite(world) and ordinary(pos) and pos and finite(map)) then return end
    local wx,wy=call(pos.GetXY,pos)
    if not finite(wx) or not finite(wy) then return end
    local a=zoneChart(map,cache)
    if not a or a[8]~=world then return end
    local dx,dy=wx-a[1],wy-a[2]
    local u=.25+(dx*a[6]-dy*a[5])/a[7]
    local v=.25+(dy*a[3]-dx*a[4])/a[7]
    if not finite(u) or not finite(v) then return end
    local du,dv=u-math.max(0,math.min(1,u)),v-math.max(0,math.min(1,v))
    local ox,oy=du*a[3]+dv*a[5],du*a[4]+dv*a[6]
    if ox*ox+oy*oy<=650^2 then return u,v end
end

local function frac(x, y)
    return finite(x) and finite(y) and x >= 0 and x <= 1 and y >= 0 and y <= 1
end

local metricChart
local function routeMapSize(map)
    local w,h=call(C_Map.GetMapWorldSize,map)
    if finite(w) and finite(h) and w>0 and h>0 then return w,h end
    if not metricChart or metricChart.map~=map then metricChart={map=map} end
    local a=zoneChart(map,metricChart)
    if not a then return end
    -- Native world axes point north/west. Only a cardinal outdoor chart
    -- supports the scalar widths used by minimap rotation and route progress.
    if math.abs(a[3])>.05 or math.abs(a[6])>.05 or a[4]>=-1 or a[5]>=-1 then return end
    local now=GetTime and GetTime() or 0
    if not metricChart.confirmed then
        if metricChart.inverseRetry and now<metricChart.inverseRetry then return end
        local cx,cy=a[1]+(a[3]+a[5])*.25,a[2]+(a[4]+a[6])*.25
        local id,v=call(C_Map.GetMapPosFromWorldPos,a[8],CreateVector2D(cx,cy),map)
        local u,z
        if finite(id) and id==map and ordinary(v) and v then u,z=call(v.GetXY,v) end
        if not finite(u) or not finite(z) or math.abs(u-.5)*(-a[4])>.5 or math.abs(z-.5)*(-a[5])>.5 then
            metricChart.inverseRetry=now+2
            return
        end
        metricChart.confirmed=true
    end
    return -a[4],-a[5]
end

local function hide()
    if frame then frame:Hide() end
    if bearing then bearing:Hide() end
end

local function rotateEnabled()
    if C_Minimap and C_Minimap.IsRotateMinimapIgnored then
        local ok,ignored=pcall(C_Minimap.IsRotateMinimapIgnored)
        if ok and ordinary(ignored) and ignored==true then return false end
    end
    if C_CVar and C_CVar.GetCVarBool then return call(C_CVar.GetCVarBool,"rotateMinimap") end
    if GetCVarBool then return call(GetCVarBool,"rotateMinimap") end
    return false
end

local function data(quest)
    local maps = C_Map
    if not (maps and maps.GetBestMapForUnit and maps.GetPlayerMapPosition) then return nil,"position" end
    if not scopeTurnIn and not scopeGuide and not scopeWaypoint and type(GetTaskInfo) == "function" then
        local ok, inside = pcall(GetTaskInfo, quest)
        if ok and ordinary(inside) and inside == true then return {insideTaskArea=true} end
    end
    if not scopeTurnIn and not scopeGuide and not scopeWaypoint and C_Minimap and C_Minimap.IsInsideQuestBlob then
        local ok,inside=pcall(C_Minimap.IsInsideQuestBlob,quest)
        if ok and ordinary(inside) and inside==true then return {insideTaskArea=true} end
    end
    local playerMap = maps.GetBestMapForUnit("player")
    if not finite(playerMap) or playerMap <= 0 then return nil,"position" end
    -- Both planners accept 2D quest POIs. Without a reliable objective floor,
    -- avoid drawing outdoor routes through cave walls, dungeons, or floor maps.
    if IsIndoors and IsIndoors() then return nil,"interior" end
    local info = maps.GetMapInfo and maps.GetMapInfo(playerMap)
    if info and type(info.mapType)=="number" then
        local kinds=Enum and Enum.UIMapType
        if info.mapType==(kinds and kinds.Dungeon or 4) or info.mapType==(kinds and kinds.Micro or 5) then return nil,"interior" end
    end
    local player = maps.GetPlayerMapPosition(playerMap, "player")
    if not ordinary(player) or not player then return end
    local px, py = player:GetXY()
    local w, h = routeMapSize(playerMap)
    if not (frac(px, py) and (px ~= 0 or py ~= 0) and finite(w) and finite(h) and w > 0 and h > 0) then return end
    local rotating = rotateEnabled()
    local minimapProjection=ordinary(rotating) and type(rotating)=="boolean"
    local heading = 0
    if minimapProjection and rotating then
        heading = call(GetPlayerFacing)
        if not finite(heading) then minimapProjection,heading=false,0 end
    end
    local origin = {map=playerMap, x=px, y=py}
    local path, selected, why
    if AT.GetFocusedQuestWalkingPath then path, selected, why = AT.GetFocusedQuestWalkingPath(quest, origin, w, h) end
    return {quest=quest, origin=origin, w=w, h=h, cosine=math.cos(heading), sine=math.sin(heading),
        path=path, selected=selected, reason=why, minimapProjection=minimapProjection}
end

local function place(line, x1, y1, x2, y2)
    line:SetStartPoint("CENTER", frame, x1, y1)
    line:SetEndPoint("CENTER", frame, x2, y2)
    local glow=line.autoTrackGlow
    glow:SetStartPoint("CENTER",frame,x1,y1)
    glow:SetEndPoint("CENTER",frame,x2,y2)
end

local function lineFor(i)
    local line = lines[i]
    if not line then
        local glow=frame:CreateLine(nil,"ARTWORK")
        glow:SetThickness(4)

        line = frame:CreateLine(nil, "OVERLAY")
        line.autoTrackGlow=glow
        lines[i] = line
    end
    line:SetThickness(1.65)
    if scopeTurnIn then
        line:SetColorTexture(.27,1,.32,.96)
        line.autoTrackGlow:SetColorTexture(.17,.96,.24,.29)
    else
        line:SetColorTexture(1,.88,.19,.96)
        line.autoTrackGlow:SetColorTexture(1,.69,.10,.29)
    end
    if line.Show then line:Show(); line.autoTrackGlow:Show() end
    return line
end

local function clearLines(first)
    for i=first,#lines do if lines[i].Hide then lines[i]:Hide(); lines[i].autoTrackGlow:Hide() end end
end

local function relative(d, x, y)
    local east, north = (x-d.origin.x)*d.w, (d.origin.y-y)*d.h
    return east*d.cosine + north*d.sine, -east*d.sine + north*d.cosine
end

local function projectedPoint(d, i)
    local cached = projected[i]
    if cached then return cached.x, cached.y end
    local pt = d.path.waypoints[i]
    if not pt then return end
    local x, y = pt.x, pt.y
    local map = d.origin.map
    if pt.map ~= map then
        local m = C_Map
        if not (CreateVector2D and m.GetWorldPosFromMapPos and m.GetMapPosFromWorldPos) then return end
        local world,pos=call(m.GetWorldPosFromMapPos,pt.map,CreateVector2D(x,y))
        if not finite(world) or not ordinary(pos) or not pos then return end
        local dstMap,dst=call(m.GetMapPosFromWorldPos,world,pos,map)
        if finite(dstMap) and dstMap==map and ordinary(dst) and dst then
            x,y=call(dst.GetXY,dst)
        else
            x,y=AT.ProjectRouteZoneBoundary(world,pos,map,projected)
        end
    end
    if not finite(x) or not finite(y) then return end
    projected[i] = {x=x,y=y}
    return x,y
end

local function offset(d, i)
    local x, y = projectedPoint(d, i)
    if x then return relative(d, x, y) end
end

local function clip(ax, ay, bx, by, yardRadius)
    local dx, dy = bx-ax, by-ay
    local aa = dx*dx + dy*dy
    if aa <= .01 then return end
    local bb = 2*(ax*dx + ay*dy)
    local cc = ax*ax + ay*ay - yardRadius*yardRadius
    local disc = bb*bb - 4*aa*cc
    if disc < 0 then return end
    local root = math.sqrt(disc)
    local low, high = math.max(0, (-bb-root)/(2*aa)), math.min(1, (-bb+root)/(2*aa))
    if low >= high then return end
    return ax+dx*low, ay+dy*low, ax+dx*high, ay+dy*high
end

local function insideObjectiveArea(d, x, y, distance)
    if not (finite(x) and finite(y) and finite(distance)) then return false end
    local same = arrival and arrival.quest == d.quest and arrival.map == d.origin.map
    if same then
        local dx, dy = (arrival.x-x)*d.w, (arrival.y-y)*d.h
        same = dx*dx + dy*dy <= 4
    end
    -- A turn-in NPC or waypoint is a point, not a 35-yard objective area.
    local limit = (scopeTurnIn or scopeWaypoint) and (same and 12 or 8) or (same and leaveAreaYards or enterAreaYards)
    if distance > limit then
        arrival = nil
        return false
    end
    arrival = {quest=d.quest, map=d.origin.map, x=x, y=y}
    return true
end

local function remainingWalkingYards(d, candidate, fraction, best, count)
    local endX, endY = offset(d, count)
    if not endX or endX*endX+endY*endY > leaveAreaYards*leaveAreaYards then return math.huge end
    local sum = math.sqrt(best)
    -- Arrival requires the last section of the actual route to be short.
    -- Bound work if a road/path loops, or has missing cross-map geometry.
    local ax, ay = offset(d, candidate)
    if not ax or count-candidate > 35 then return math.huge end
    for i=candidate+1,count do
        local bx, by = offset(d,i)
        if not bx then return math.huge end
        local dx, dy = bx-ax, by-ay
        sum = sum + (i==candidate+1 and (1-fraction) or 1)*math.sqrt(dx*dx+dy*dy)
        if sum > leaveAreaYards then return math.huge end
        ax, ay = bx, by
    end
    return sum
end
local function measureSome(d,count)
    if not measure then measure={next=count-1,suffix={[count]=0},leg={}} end
    local now=GetTime and GetTime() or 0
    if measure.retryAt and now<measure.retryAt then return end
    for _=1,256 do
        local i=measure.next
        if i<1 then return end
        local ax,ay=projectedPoint(d,i)
        local bx,by=projectedPoint(d,i+1)
        if ax and bx then
            local dx,dy=(bx-ax)*d.w,(by-ay)*d.h
            measure.leg[i]=math.sqrt(dx*dx+dy*dy)
            if measure.suffix[i+1] then measure.suffix[i]=measure.leg[i]+measure.suffix[i+1] end
        elseif measure.suffix[i+1] then
            -- An unreadable coordinate does not invalidate the route, and
            -- can recover while it is still selected. Retry only the first
            -- missing suffix segment, never an entire per-frame rebuild.
            if (measure.retries or 0)<3 then
                measure.retries=(measure.retries or 0)+1
                measure.retryAt=now+measure.retries*.5
                return
            end
            -- Earlier segments cannot form a complete suffix around a real
            -- hole. Local progress and arrival remain independent.
            measure.next=0
            return
        end
        measure.retries,measure.retryAt=nil,nil
        measure.next=i-1
    end
end
local function detailedProgress(d,candidate,fraction,best,count,remain)
    local ax,ay=offset(d,candidate)
    if not ax then return end
    local total, toTurn, turn = math.sqrt(best), nil, nil
    local vx,vy
    for i=candidate+1,math.min(count,candidate+32) do
        local bx,by=offset(d,i)
        if not bx then return {remain=remain,turn=turn,toTurn=toTurn} end
        local dx,dy=bx-ax,by-ay
        local len=math.sqrt(dx*dx+dy*dy)
        if len>3 then
            if vx and not turn then
                local dot=vx*dx/len+vy*dy/len
                if dot<.88 then
                    local cross=vx*dy/len-vy*dx/len
                    turn=dot<-.85 and "Turn back" or (cross>0 and "Turn left" or "Turn right")
                    toTurn=total
                end
            end
            vx,vy=dx/len,dy/len
        end
        total=total+(i==candidate+1 and (1-fraction) or 1)*len
        ax,ay=bx,by
    end
    if not remain and measure and measure.suffix[candidate+1] and measure.leg[candidate] then
        remain=math.sqrt(best)+(1-fraction)*measure.leg[candidate]+measure.suffix[candidate+1]
    elseif not remain and count-candidate<=32 then remain=total end
    return {remain=remain,turn=turn,toTurn=toTurn}
end
local function walk(d, radius, yardRadius)
    if d.path ~= currentPath then currentPath,cursor,currentProjectionMap=d.path,1,nil end
    if currentProjectionMap~=d.origin.map then
        currentProjectionMap,projected,measure=d.origin.map,{},nil
    end
    local count = #d.path.waypoints
    if count < 2 then return 0 end
    local candidate, fraction, best
    local begin = math.max(1, cursor - 6)
    -- Limit lookahead so an intersection can't skip the intervening corners.
    for i=begin,math.min(cursor+7,count-1) do
        local ax, ay = offset(d, i)
        local bx, by = offset(d, i+1)
        if ax and bx then
            local dx, dy = bx-ax, by-ay
            local length = dx*dx + dy*dy
            local t = length > 0 and math.max(0, math.min(1, -(ax*dx+ay*dy)/length)) or 0
            local px, py = ax+t*dx, ay+t*dy
            local d2 = px*px+py*py
            if not best or d2 < best - .001 or (math.abs(d2-best)<=.001 and math.abs(i-cursor)<math.abs(candidate-cursor)) then
                candidate, fraction, best = i, t, d2
            end
        end
    end
    if not candidate then return end
    if best > offPathYards*offPathYards then
        if AT.ReplanQuestWalking then AT.ReplanQuestWalking(d.path)
        elseif AT.CancelQuestWalking then AT.CancelQuestWalking() end
        return
    end
    if AT.NoteQuestWalkingProgress then AT.NoteQuestWalkingProgress(d.path,d.origin,math.sqrt(best),candidate) end
    cursor = candidate
    local remain
    local costs,full=d.path.cumulativeYards,d.path.yards
    if ordinary(costs) and type(costs)=="table" and finite(full) and full>0 and #costs==count
        and finite(costs[1]) and costs[1]==0 and finite(costs[count]) and costs[count]==full then
        local a,b=costs[candidate],costs[candidate+1]
        if finite(a) and finite(b) and a>=0 and b>a and b<=full then
            remain=math.sqrt(best)+full-(a+(b-a)*fraction)
        end
    end
    if not remain then measureSome(d,count) end -- Existing provider or invalid/missing cost metadata.
    travelDetail = detailedProgress(d,candidate,fraction,best,count,remain)
    local targetX, targetY
    if d.selected and d.selected.map == d.origin.map and frac(d.selected.x,d.selected.y) then
        targetX,targetY = d.selected.x,d.selected.y
    else
        targetX,targetY = projectedPoint(d,count)
    end
    local remaining = remainingWalkingYards(d,candidate,fraction,best,count)
    if insideObjectiveArea(d,targetX,targetY,remaining) then return 0 end
    if not targetX or not targetY or remaining==math.huge then arrival = nil end
    mapRoute={path=d.path, selected=d.selected, segment=candidate, fraction=fraction, quest=d.quest}
    if not radius then return end -- World-map snapshot does not need a drawable minimap.
    local used, scale = 0, radius/yardRadius
    local ax,ay=offset(d,candidate)
    for i=candidate,math.min(count-1,candidate+renderLimit-1) do
        local bx,by=offset(d,i+1)
        if ax and bx then
            if i==candidate then ax,ay=ax+(bx-ax)*fraction,ay+(by-ay)*fraction end
            local x1,y1,x2,y2=clip(ax,ay,bx,by,yardRadius)
            if x1 then
                used=used+1
                place(lineFor(used),x1*scale,y1*scale,x2*scale,y2*scale)
            end
        end
        -- A bad projection breaks only its adjoining segments. Never join
        -- across it, but render later valid edges inside the minimap.
        ax,ay=bx,by
    end
    return used > 0 and used or nil
end

local function pointOK(map,x,y)
    return finite(map) and map>0 and frac(x,y) and (x~=0 or y~=0)
end

function AT.GetNativeQuestRoutePointForMap(quest,map)
    if not finite(quest) or not finite(map) or not C_SuperTrack or not C_Navigation then return end
    local selected=call(C_SuperTrack.GetSuperTrackedQuestID)
    local owns=call(C_SuperTrack.IsSuperTrackingQuest)
    if not (finite(selected) and selected==quest and ordinary(owns) and owns==true) then return end
    local kind=call(C_SuperTrack.GetHighestPrioritySuperTrackingType)
    local types=Enum and Enum.SuperTrackingType
    if types and types.Quest~=nil and (not ordinary(kind) or kind~=types.Quest) then return end
    for _,name in ipairs({"IsSuperTrackingCorpse","IsSuperTrackingUserWaypoint","IsSuperTrackingMapPin","IsSuperTrackingContent"}) do
        local other=call(C_SuperTrack[name])
        if not ordinary(other) or other==true then return end
    end
    local x,y=call(C_Navigation.GetNextWaypointForMap,map)
    if pointOK(map,x,y) then return x,y end
end

local function nativeOrParentPoint(quest)
    if not C_Map or not C_QuestLog then return end
    local map=call(C_Map.GetBestMapForUnit,"player")
    for _=1,4 do
        if not finite(map) or map<=0 then break end
        local x,y=AT.GetNativeQuestRoutePointForMap(quest,map)
        if pointOK(map,x,y) then return map,x,y,"native waypoint" end
        x,y=call(C_QuestLog.GetNextWaypointForMap,quest,map)
        if pointOK(map,x,y) then return map,x,y,"quest waypoint" end
        if _>1 then
            local rows=call(C_QuestLog.GetQuestsOnMap,map)
            if ordinary(rows) and type(rows)=="table" then
                for _,item in ipairs(rows) do
                    if ordinary(item) and type(item)=="table" and finite(item.questID) and item.questID==quest
                        and pointOK(map,item.x,item.y) then return map,item.x,item.y,"parent-map quest POI" end
                end
            end
        end
        local info=call(C_Map.GetMapInfo,map)
        if not ordinary(info) or type(info)~="table" or not finite(info.parentMapID) or info.parentMapID==map then break end
        map=info.parentMapID
    end
end

local function metaFor(quest)
    if scopeWaypoint and quest==scopeQuest then
        local p=AT.GetSelectedUserWaypoint and AT.GetSelectedUserWaypoint()
        return p and {map=p.map,x=p.x,y=p.y,source="native waypoint"} or {}
    end
    local now=GetTime and GetTime() or 0
    local turnIn=AT.IsQuestTurnInNavigation and AT.IsQuestTurnInNavigation(quest) or false
    if metadata and metadata.quest==quest and metadata.turnIn==turnIn and now-metadata.when<.5
        and (not turnIn or metadata.map) then return metadata end
    metadata={quest=quest,when=now,turnIn=turnIn}
    if AT.GetFocusedQuestRoutePoint then
        local ok,id,map,x,y,source=pcall(AT.GetFocusedQuestRoutePoint)
        if ok and id==quest and finite(map) and frac(x,y) then
            if pointOK(map,x,y) then metadata.map,metadata.x,metadata.y,metadata.source=map,x,y,(turnIn and (source or "verified turn-in") or "native quest coordinates") end
        end
    end
    if not metadata.map and not turnIn then metadata.map,metadata.x,metadata.y,metadata.source=nativeOrParentPoint(quest) end
    return metadata
end

function AT.GetQuestRouteDisplayPoint(quest)
    if not finite(quest) or quest<=0 then return end
    local m=metaFor(quest)
    return m.map,m.x,m.y,m.source
end

local function yardEstimate(meta)
    if not meta.map or (IsIndoors and IsIndoors()) or not C_Map then return end
    local source=C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not finite(source) then return end
    local function outdoor(map)
        local info=C_Map.GetMapInfo and C_Map.GetMapInfo(map)
        if not C_Map.GetMapInfo then return source==meta.map end
        return info and ordinary(info.mapType) and info.mapType==(Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3)
    end
    if not outdoor(source) then return end
    local targetInfo=C_Map.GetMapInfo and C_Map.GetMapInfo(meta.map)
    local kind=targetInfo and targetInfo.mapType
    if not outdoor(meta.map) and not (source~=meta.map and (kind==1 or kind==2)) then return end
    local pos=C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(source,"player")
    if not ordinary(pos) or not pos then return end
    local px,py=pos:GetXY()
    if not frac(px,py) or (px==0 and py==0) then return end
    local dx,dy
    if source==meta.map then
        local w,h=routeMapSize(source)
        if not (finite(w) and finite(h) and w>0 and h>0) then return end
        dx,dy=(meta.x-px)*w,(meta.y-py)*h
    elseif CreateVector2D and C_Map.GetWorldPosFromMapPos then
        local a,ap=C_Map.GetWorldPosFromMapPos(source,CreateVector2D(px,py))
        local b,bp=C_Map.GetWorldPosFromMapPos(meta.map,CreateVector2D(meta.x,meta.y))
        if not finite(a) or not finite(b) or a~=b or not ordinary(ap) or not ordinary(bp) or not ap or not bp then return end
        -- C_Map world X points north and world Y points west.
        local ax,ay=ap:GetXY()
        local bx,by=bp:GetXY()
        if not (finite(ax) and finite(ay) and finite(bx) and finite(by)) then return end
        dx,dy=ay-by,ax-bx
    else
        return
    end
    return math.sqrt(dx*dx+dy*dy),dx,dy,{map=source,x=px,y=py}
end
local function setHudLabel(region,text)
    if region.lastATText~=text then region:SetText(text);region.lastATText=text end
end

local function distanceStatus()
    if not statusQuest or routeStatus=="disabled" or routeStatus=="no_quest" or routeStatus=="interior" then return end
    if routeStatus=="arrival" then return end
    if (routeStatus=="routed" or routeStatus=="road") and travelDetail and finite(travelDetail.remain) then
        distanceSource="walking path"; return travelDetail.remain,false
    end
    local ok,yards=pcall(yardEstimate,metaFor(statusQuest))
    if ok and finite(yards) then distanceSource="map coordinates"; return yards,true end
    if not scopeTurnIn and not scopeWaypoint and not (IsIndoors and IsIndoors()) and C_QuestLog then
        local sq,same=call(C_QuestLog.GetDistanceSqToQuest,statusQuest)
        if finite(sq) and sq>0 and ordinary(same) and same==true then
            distanceSource="native quest distance"
            return math.sqrt(sq),true
        end
    end
end

local function meterOffset()
    local clock=TimeManagerClockButton
    if not (clock and clock.IsVisible and clock:IsVisible() and clock.GetTop and clock.GetCenter
        and clock.GetEffectiveScale and Minimap.GetBottom and Minimap.GetCenter and Minimap.GetEffectiveScale) then return 5 end
    local top,center=clock:GetTop(),clock:GetCenter()
    local bottom,mapCenter=Minimap:GetBottom(),Minimap:GetCenter()
    local cScale,mScale=clock:GetEffectiveScale(),Minimap:GetEffectiveScale()
    local w,h=Minimap:GetWidth(),Minimap:GetHeight()
    if not (finite(top) and finite(center) and finite(bottom) and finite(mapCenter)
        and finite(cScale) and finite(mScale) and mScale>0 and finite(w) and finite(h)) then return 5 end
    local scale=cScale/mScale
    local clockOffset=top*scale-bottom
    if math.abs(center*scale-mapCenter)>w*.27 or clockOffset< -24 or clockOffset>h*.25 then return 5 end
    return math.max(2,clockOffset+2)
end

local function drawMeter(yards)
    if not meter then return end
    if not finite(yards) then meter:Hide(); return end
    local ok,offset=pcall(meterOffset)
    if not ok then offset=5 end
    if meter.atOffset~=offset then
        meter:ClearAllPoints()
        meter:SetPoint("BOTTOM",Minimap,"BOTTOM",0,offset)
        meter.atOffset=offset
    end
    setHudLabel(meter.label,math.floor(yards+.5) .. " yd")
    meter:Show()
end

local function makeMeter()
    -- Keep the distance inside the minimap. No solid background.
    local labelFrame=CreateFrame("Frame",nil,Minimap)
    labelFrame:SetSize(86,14)
    labelFrame:SetPoint("BOTTOM",Minimap,"BOTTOM",0,5)
    if labelFrame.SetFrameStrata then labelFrame:SetFrameStrata("HIGH") end
    labelFrame:SetFrameLevel(Minimap:GetFrameLevel()+12)
    labelFrame:EnableMouse(false)
    local label=labelFrame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    label:SetPoint("CENTER",labelFrame,"CENTER",0,0)
    label:SetTextColor(1,1,1)
    if label.SetShadowColor then label:SetShadowColor(0,0,0,1) end
    if label.SetShadowOffset then label:SetShadowOffset(1,-1) end
    labelFrame.label=label
    labelFrame:Hide()
    meter=labelFrame
end

local function viewYards()
    if C_Minimap and C_Minimap.GetViewRadius then
        local ok,yards=pcall(C_Minimap.GetViewRadius)
        if ok and finite(yards) and yards>0 then return yards end
    end
    return previewYards
end

local function makeBearing()
    local dotFrame=CreateFrame("Frame",nil,Minimap)
    dotFrame:SetAllPoints(Minimap)
    if dotFrame.SetFrameStrata then dotFrame:SetFrameStrata("HIGH") end
    dotFrame:SetFrameLevel(Minimap:GetFrameLevel()+13)
    dotFrame:EnableMouse(false)
    dotFrame.glow=dotFrame:CreateLine(nil,"ARTWORK")
    dotFrame.glow:SetThickness(3)
    dotFrame.core=dotFrame:CreateLine(nil,"OVERLAY")
    dotFrame.core:SetThickness(1.4)
    dotFrame:Hide()
    if dotFrame.CreateFontString then
        local label=dotFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        label:SetPoint("BOTTOM",dotFrame,"BOTTOM",0,17)
        label:SetTextColor(1,.66,.29,.96)
        label:SetText("DIRECT BEARING ONLY")
    end
    bearing=dotFrame
end

local function drawBearing()
    if bearing then bearing:Hide() end
    bearingStatus="hidden (" .. (routeStatus or "no status") .. ")"
    if scopeWaypoint or routeStatus=="arrival" or routeStatus=="interior" or routeStatus=="disabled"
        or routeStatus=="routed" or routeStatus=="road" or not finite(statusQuest) then return end
    local m=metaFor(statusQuest)
    if not m.map then bearingStatus="no objective coordinates"; return end
    local distance,dx,dy,origin=yardEstimate(m)
    if not finite(distance) or distance<=0 then bearingStatus="no shared outdoor map position"; return end
    mapRoute={quest=statusQuest,bearing=true,from=origin,target={map=m.map,x=m.x,y=m.y}}
    if not bearing then bearingStatus="overlay unavailable"; return end
    local rotating=rotateEnabled()
    if not ordinary(rotating) or type(rotating)~="boolean" then bearingStatus="rotation setting unavailable"; return end
    local heading=0
    if rotating then
        heading=call(GetPlayerFacing)
        if not finite(heading) then
            bearingStatus="facing unavailable"
            return
        end
    end
    local w,h=Minimap:GetWidth(),Minimap:GetHeight()
    if not finite(w) or not finite(h) or math.min(w,h)<42 then return end
    local r=math.min(w,h)*.42
    local display=math.min(.93*r, math.max(6,distance/viewYards()*r))
    local east,north=dx,-dy
    local vx=(east*math.cos(heading)+north*math.sin(heading))/distance
    local vy=(-east*math.sin(heading)+north*math.cos(heading))/distance
    -- Keep estimates distinct by color/diagnostics, not by breaking the line.
    local px,py=display*vx,display*vy
    for i,region in ipairs({bearing.glow,bearing.core}) do
        local alpha=i==1 and .22 or .84
        region:SetColorTexture(1,.66,.29,alpha)
        region:SetStartPoint("CENTER",bearing,0,0)
        region:SetEndPoint("CENTER",bearing,px,py)
        region:Show()
    end
    bearingStatus="direct bearing only"
    bearing:Show()
end

local function draw()
    travelDetail,mapRoute=nil,nil
    if not (frame and Minimap and AT.db and AT.db.enabled ~= false and AT.db.showQuestRoute ~= false) then
        if AT.CancelQuestWalking then AT.CancelQuestWalking() end
        arrival,scopeQuest,scopeTurnIn,scopeGuide,scopeWaypoint,positionLost = nil,nil,nil,nil,nil,nil
        routeStatus,statusQuest = "disabled",nil
        hide(); return
    end
    local source=AT.GetWalkingNavigationID or AT.GetQuestNavigationID or AT.GetFocusedQuestID
    local quest,origin=call(source)
    selectionSource=origin
    if not finite(quest) then quest=nil end
    local waypoint=origin=="waypoint"
    local turnIn=not waypoint and quest and AT.IsQuestTurnInNavigation and AT.IsQuestTurnInNavigation(quest) or false
    local guide=origin=="guide"
    if quest~=scopeQuest or turnIn~=scopeTurnIn or guide~=scopeGuide or waypoint~=scopeWaypoint then
        if AT.CancelQuestWalking then AT.CancelQuestWalking() end
        arrival,scopeQuest,scopeTurnIn,scopeGuide,scopeWaypoint,positionLost = nil,quest,turnIn,guide,waypoint,nil
    end
    statusQuest=quest
    if not waypoint and (not finite(quest) or quest<=0) then routeStatus="no_quest"; hide(); return end
    local ok,d,reason=pcall(data,quest)
    if not ok or not d then
        routeStatus=reason or "position"
        if routeStatus=="interior" then
            if AT.CancelQuestWalking then AT.CancelQuestWalking() end
            arrival,positionLost=nil,nil
        else
            -- Quest and map are unchanged. Hide until we know where we are;
            -- a brief API gap should not throw away a valid route or async job.
            local now=GetTime and GetTime() or 0
            positionLost=positionLost or now
            if now-positionLost>3 and AT.CancelQuestWalking then AT.CancelQuestWalking() end
        end
        hide(); return
    end
    positionLost=nil
    if d.insideTaskArea then
        if AT.CancelQuestWalking then AT.CancelQuestWalking() end
        arrival=nil
        routeStatus="arrival"
        hide(); return
    end
    if arrival and (arrival.quest~=d.quest or arrival.map~=d.origin.map) then arrival=nil end
    local width,height=call(Minimap.GetWidth,Minimap),call(Minimap.GetHeight,Minimap)
    local radius=d.minimapProjection and finite(width) and finite(height) and math.min(width,height)*.43
    if not radius or radius<18 then radius=nil end
    -- No route, no geometry. Do not draw a compass bearing through a wall.
    if not d.path then
        -- A single display POI can be absent even when the walking planner
        -- found an exact or verified alternate hand-in. Only label it
        -- missing when the planner also has no objective. A short bearing
        -- across a wall is not enough to prove arrival while planning.
        routeStatus=d.reason or "planning"
        if turnIn and (d.reason=="objective_missing" or not AT.GetFocusedQuestWalkingPath)
            and not metaFor(quest).map then routeStatus="turnin_missing" end
        hide(); return
    end
    local count=walk(d,radius,viewYards())
    if not count or count==0 then routeStatus=count==0 and "arrival" or (mapRoute and (d.path.roadAware and "road" or "routed") or "replan"); hide(); return end
    routeStatus=d.path.roadAware and "road" or "routed"
    clearLines(count+1)
    if caption then
        caption:SetText(scopeWaypoint and "WALK TO WAYPOINT" or d.path.roadAware and "ROAD-AWARE WALK" or "WALK ROUTE")
        if scopeTurnIn then caption:SetTextColor(.31,1,.35,.9) else caption:SetTextColor(1,.88,.19,.9) end
    end
    frame:Show()
end

function AT.GetQuestRouteStatus()
    local m=scopeWaypoint and metaFor(statusQuest) or metadata and metadata.quest==statusQuest and metadata or nil
    local details=string.format("quest source: %s; location: %s; distance: %s; minimap: %s%s",
        selectionSource or "none",m and m.source or "unavailable",distanceSource or "unavailable",
        bearingStatus or "unavailable",drawFailure and ("; rendering error: " .. drawFailure) or "")
    return routeStatus,not scopeWaypoint and statusQuest or nil,details,selectionSource
end
local function refresh()
    local perf=AT.PerfBegin and AT.PerfBegin()
    distanceSource,drawFailure=nil,nil
    local ok,err = pcall(draw)
    if not ok then
        if ordinary(err) and type(err)=="string" then drawFailure=err:sub(1,140) end
        routeStatus,mapRoute="position",nil; hide()
    end
    local distanceOK,yards=pcall(distanceStatus)
    if not distanceOK then yards=nil end
    pcall(drawMeter,yards)
    local directionOK,why=pcall(drawBearing)
    if not directionOK then
        if bearing then bearing:Hide() end
        bearingStatus="bearing render error"
        if ordinary(why) and type(why)=="string" then drawFailure=why:sub(1,140) end
    end
    if AT.RenderWorldQuestRoute then
        local mapOK,mapError=pcall(AT.RenderWorldQuestRoute, routeStatus, statusQuest, mapRoute)
        if not mapOK and ordinary(mapError) and type(mapError)=="string" then
            drawFailure="world map: " .. mapError:sub(1,125)
        end
        if not mapOK and AT.HideWorldQuestRoute then pcall(AT.HideWorldQuestRoute) end
    end
    if perf then AT.PerfEnd("Quest route",perf) end
end

function AT.RefreshQuestRoute()
    refresh()
end

function AT.InitQuestRoute()
    if frame or not Minimap or not CreateFrame then return end
    local overlay = CreateFrame("Frame", nil, Minimap)
    if not overlay.CreateLine then overlay:Hide(); return end
    overlay:SetAllPoints(Minimap)
    overlay:EnableMouse(false)
    overlay:SetFrameLevel(Minimap:GetFrameLevel()+1)
    frame, lines = overlay, {}
    if overlay.CreateFontString then
        caption = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        caption:SetPoint("BOTTOM", overlay, "BOTTOM", 0, 10)
    end
    pcall(makeMeter)
    pcall(makeBearing)
    local observer = CreateFrame("Frame")
    observer:SetScript("OnUpdate", function(_, dt)
        if not AT.db or AT.db.enabled==false or AT.db.showQuestRoute==false then
            if routeStatus~="disabled" then refresh() end
            return
        end
        elapsed = elapsed + dt
        if elapsed < refreshPeriod then return end
        elapsed = 0
        refresh()
    end)
    refresh()
end








