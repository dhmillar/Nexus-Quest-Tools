local _, AT = ...
local OWNER = "AutoTrack.QuestWalking"
local BATCH_SIZE, SAMPLE_SECONDS, REPLAN_YARDS = 256, 0.70, 80
local candidateCache, state, currentTargets, lastPublished, lastGoodTargets
local lastRouteProgress
local providerBackoff=setmetatable({},{__mode="k"})
local NO_CANCEL = function() end

local function finite(n)
    return (not issecretvalue or not issecretvalue(n)) and type(n) == "number"
        and n == n and n > -math.huge and n < math.huge
end

local function goodPlace(p)
    return type(p) == "table" and finite(p.map) and p.map > 0 and p.map % 1 == 0
        and finite(p.x) and finite(p.y) and p.x >= 0 and p.x <= 1 and p.y >= 0 and p.y <= 1
end

local WAYPOINT_ID = -1 -- Internal navigation key; never passed to native quest APIs.
local function clean(v)
    return not issecretvalue or not issecretvalue(v)
end

function AT.GetSelectedUserWaypoint()
    local map,track=C_Map,C_SuperTrack
    if not (map and type(map.GetUserWaypoint)=="function" and track
        and type(track.IsSuperTrackingUserWaypoint)=="function") then return end
    local ok,id,x,y=pcall(function()
        local selected=track.IsSuperTrackingUserWaypoint()
        if not clean(selected) or selected~=true then return end
        local pin=map.GetUserWaypoint()
        if not clean(pin) or not pin then return end
        local pos=pin.position
        if not clean(pos) or not pos then return end
        local x,y=pos:GetXY()
        return pin.uiMapID,x,y
    end)
    local point={map=id,x=x,y=y}
    if ok and goodPlace(point) then return point end
end

function AT.GetWalkingNavigationID()
    local source=AT.GetQuestNavigationID or AT.GetFocusedQuestID
    local id,kind
    if source then id,kind=source() end
    if kind=="guide" then return id,kind end
    if AT.GetSelectedUserWaypoint() then return WAYPOINT_ID,"waypoint" end
    return id,kind
end

local function time()
    return GetTime and GetTime() or 0
end

local function isTurnIn(quest)
    return quest~=WAYPOINT_ID and AT.IsQuestTurnInNavigation and AT.IsQuestTurnInNavigation(quest)==true or false
end

local spatialFailure={offmesh=true,unreachable=true,projection=true,budget=true}
local function sameFailedStart(failure,from,key)
    if not spatialFailure[failure.reason] then return true end
    if key~=failure.key then return false end
    local dx=(from.x-failure.from.x)*failure.width
    local dy=(from.y-failure.from.y)*failure.height
    return dx*dx+dy*dy<=24^2
end

local function apiForWalking(from, quest, snapshot, key)
    local now=time()
    local lastFailure
    local function checked(api, road)
        if type(api) ~= "table" or api.version ~= 2 or not finite(api.minor) or api.minor < 7
            or type(api.EstimateWalks) ~= "function" or type(api.WalkPath) ~= "function"
            or type(api.NavVersion) ~= "function" then return end
        local failure=providerBackoff[api]
        if failure and failure.quest==quest and failure.map==from.map and failure.turnIn==isTurnIn(quest) and now<failure.untilTime and sameFailedStart(failure,from,key) then
            lastFailure=lastFailure or failure.reason
            return
        end
        local ok, nav = pcall(api.NavVersion)
        if ok and type(nav) == "string" and nav ~= "" then return api, nav, road end
    end
    local api,nav,road=checked(AT.GetBundledWalkingAPI and AT.GetBundledWalkingAPI(from,snapshot),false)
    if api then return api,nav,road end
    api,nav,road=checked(AT.GetRoadWalkingAPI and AT.GetRoadWalkingAPI(from),true)
    return api,nav,road,lastFailure
end

local function active(quest)
    return AT.db and AT.db.enabled ~= false and AT.db.showQuestRoute ~= false
        and AT.GetWalkingNavigationID()==quest
end

local function clear()
    local old = state
    state = nil
    if old and old.cancel then pcall(old.cancel) end
end

function AT.CancelQuestWalking()
    clear()
    candidateCache, lastGoodTargets, lastPublished, lastRouteProgress = nil, nil, nil, nil
end

function AT.NoteQuestWalkingProgress(path, from, yards, segment)
    if lastPublished and path==lastPublished.path and goodPlace(from) and finite(yards) and yards<=8 then
        lastRouteProgress={path=path, from=from, at=time(), segment=segment}
    else
        lastRouteProgress=nil
    end
end

function AT.ReplanQuestWalking(path)
    -- Drop rejected published geometry, not a useful replacement already
    -- being calculated for the same navigation job.
    if not lastPublished or lastPublished.path~=path then return end
    lastPublished,lastRouteProgress=nil,nil
    if state and state.path==path then clear() end
end

local function valid(job)
    if state ~= job or not active(job.quest) or isTurnIn(job.quest)~=job.turnIn then return false end
    local api, nav = apiForWalking(job.from, job.quest,true,job.key)
    if api ~= job.api or nav ~= job.nav then return false end
    if C_Map and C_Map.GetBestMapForUnit then
        local ok, map = pcall(C_Map.GetBestMapForUnit, "player")
        if not ok or (finite(map) and map ~= job.from.map) then return false end
    end
    return true
end

local function fail(job, reason)
    job.cancel = nil
    job.failure = type(reason) == "string" and reason or "unavailable"
    job.retry = time() + ((reason == "loading" or reason == "combat") and 3 or 18)
    job.backoff={quest=job.quest,map=job.from.map,turnIn=job.turnIn,untilTime=job.retry,reason=job.failure,
        from=job.from,width=job.width,height=job.height,key=job.key}
    providerBackoff[job.api] = job.backoff
end

local function request(job, method, target, callback, refused)
    if not valid(job) then return end
    job.phase = job.phase + 1
    local phase = job.phase
    job.cancel = NO_CANCEL
    local ok, cancel, reason = pcall(method, OWNER, job.from, target, function(result, why)
        if not valid(job) or job.phase ~= phase then return end
        job.phase = job.phase + 1
        job.cancel = nil
        callback(result, why)
    end)
    if not valid(job) or job.phase ~= phase then
        if ok and type(cancel) == "function" then pcall(cancel) end
        return
    end
    if ok and type(cancel) == "function" then
        job.cancel = cancel
    else
        job.phase = job.phase + 1
        if not refused or not refused(reason) then fail(job, reason) end
    end
end

local function acceptPath(job,path,why)
        -- Quest progress can replace objective POIs without changing the quest ID.
        local latest = currentTargets(job.quest, job.from.map, true)
        if latest.key ~= job.key then clear(); return end
        if why or type(path) ~= "table" or type(path.waypoints) ~= "table"
            or #path.waypoints < 1 or not finite(path.yards) or path.yards < 0
            or path.navVersion ~= job.nav then fail(job, why); return end
        for _, point in ipairs(path.waypoints) do
            if not goodPlace(point) then fail(job, "invalid"); return end
        end
        path.roadAware = job.road == true and path.roadAware == true
        if job.usingBackup then
            if job.turnIn then path.verifiedTurnInApproach=true else path.observedApproach=true end
        end
        if latest.stale then job.waitingPath = path else job.path = path end
end
local function requestPath(job)
    if not job.best then fail(job, "unreachable"); return end
    request(job,job.api.WalkPath,job.best,function(path,why) acceptPath(job,path,why) end)
end

local function estimateNext(job, first)
    if first > #job.targets then requestPath(job); return end
    local batch, final = {}, first-1
    local targetMap=job.targets[first].map
    for i=first,math.min(first+BATCH_SIZE-1,#job.targets) do
        if job.targets[i].map~=targetMap then break end
        final=i
        batch[#batch+1]=job.targets[i]
    end
    local function skipCrossMap(why)
        if targetMap ~= job.from.map and (why=="invalid" or why=="outside" or why=="nodata" or why=="offmesh") then
            estimateNext(job,final+1)
            return true
        end
    end
    request(job, job.api.EstimateWalks, batch, function(costs, why)
        if why or type(costs) ~= "table" then
            if not skipCrossMap(why) then fail(job,why) end
            return
        end
        for i, target in ipairs(batch) do
            local yards = costs[i]
            if yards ~= false and (not finite(yards) or yards < 0) then fail(job, "invalid"); return end
            if finite(yards) and (not job.cost or yards < job.cost) then
                job.best, job.cost = target, yards
            end
        end
        estimateNext(job, final + 1)
    end, skipCrossMap)
end

local function chooseWalkingPath(job)
    local function retry(why)
        if not job.usingBackup and #job.backups>0
            and (why=="offmesh" or why=="unreachable" or why=="projection") then
            job.usingBackup=true
            job.targets=job.backups
            job.best,job.cost=nil,nil
            chooseWalkingPath(job)
            return true
        end
        return false
    end
    local function budget(why)
        if why~="budget" then return false end
        estimateNext(job,1)
        return true
    end
    request(job,job.api.WalkBestPath,job.targets,function(path,why)
        if budget(why) or retry(why) then return end
        if type(path)=="table" and finite(path.targetIndex) then job.best=job.targets[path.targetIndex] end
        if not job.best then fail(job,why);return end
        acceptPath(job,path,why)
    end,function(why) return budget(why) or retry(why) end)
end

currentTargets = function(quest, map, force)
    if quest==WAYPOINT_ID then
        -- Read on every waypoint job validation so replacement/clear never
        -- publishes geometry for the previous pin or reuses quest POIs.
        local p=AT.GetSelectedUserWaypoint()
        if p and IsInInstance then
            local ok,inInstance=pcall(IsInInstance)
            if not ok or not clean(inInstance) or inInstance==true then p=nil end
        end
        if p and C_Map.GetMapInfo then
            local ok,info=pcall(C_Map.GetMapInfo,p.map)
            local kind=ok and clean(info) and info and info.mapType
            local types=Enum and Enum.UIMapType
            if not finite(kind) or kind==(types and types.Dungeon or 4)
                or kind==(types and types.Micro or 5) or kind==(types and types.Orphan or 6) then p=nil end
        end
        local key=p and ("W:"..p.map..":"..p.x..":"..p.y) or "W:"
        return {quest=quest,map=map,turnIn=false,points=p and {p} or {},backups={},key=key}
    end
    local turnIn=isTurnIn(quest)
    -- The same quest ID (even at identical coordinates) can change stage
    -- while a path is being calculated. Never show the old objective route.
    if not force and candidateCache and candidateCache.turnIn==turnIn and candidateCache.quest == quest and candidateCache.map == map
        and time() < candidateCache.at + SAMPLE_SECONDS then return candidateCache end
    local ok,id,points,backup = pcall(AT.GetFocusedQuestRouteTargets,map)
    if not ok or id~=quest or type(points)~="table" then points,backup={},nil end
    local list,signature,backups={},{turnIn and "turn-in" or "objective"},{}
    for _, point in ipairs(points) do
        if goodPlace(point) then
            list[#list+1] = point
            signature[#signature+1] = point.map .. ":" .. point.x .. ":" .. point.y
        end
    end
    for _,point in ipairs(type(backup)=="table" and backup or {}) do
        if goodPlace(point) then
            backups[#backups+1]=point
            signature[#signature+1]="B:"..point.map..":"..point.x..":"..point.y
        end
    end
    local now=time()
    if #list==0 and lastGoodTargets and lastGoodTargets.quest==quest and lastGoodTargets.map==map and lastGoodTargets.turnIn==turnIn
        and now-lastGoodTargets.at < 2 then
        candidateCache={quest=quest,map=map,at=now,turnIn=turnIn,points=lastGoodTargets.points,backups=lastGoodTargets.backups,key=lastGoodTargets.key,stale=true}
        return candidateCache
    end
    candidateCache = {quest=quest, map=map, at=now, turnIn=turnIn, points=list, backups=backups, key=table.concat(signature, "|")}
    if #list>0 then lastGoodTargets=candidateCache end
    return candidateCache
end

local function carryCenterline(quest,from,width,height)
    local saved=lastPublished
    if not saved or saved.quest~=quest or saved.map~=from.map
        or not AT.CanCarryBundledCenterline or not AT.CanCarryBundledCenterline(from) then return end
    local c=currentTargets(quest,from.map)
    if c.stale or c.key~=saved.key then return end
    local points=saved.path.waypoints
    local function nearby(first,last)
        for i=first,last do
            local a,b=points[i],points[i+1]
            if a.map==from.map and b.map==from.map then
                local px,py=(from.x-a.x)*width,(from.y-a.y)*height
                local vx,vy=(b.x-a.x)*width,(b.y-a.y)*height
                local length=vx*vx+vy*vy
                if length>0 then
                    local t=math.max(0,math.min(1,(px*vx+py*vy)/length))
                    if (px-t*vx)^2+(py-t*vy)^2<=3.5^2 then
                        saved.centerlineIndex=i
                        return saved.path,saved.target,"routed"
                    end
                end
            end
        end
    end
    if saved.centerlineIndex then
        return nearby(math.max(1,saved.centerlineIndex-8),math.min(#points-1,saved.centerlineIndex+20))
    end
    return nearby(1,math.min(#points-1,1600))
end

local function canCarryRouteBoundary(from,now)
    local recent=lastRouteProgress
    if not recent or recent.path~=lastPublished.path or recent.from.map~=lastPublished.map
        or now<recent.at or now-recent.at>1.2 or not finite(recent.segment) then return false end
    local function world(p)
        if not CreateVector2D or not C_Map or not C_Map.GetWorldPosFromMapPos then return end
        local ok,w,x,y=pcall(function()
            local w,v=C_Map.GetWorldPosFromMapPos(p.map,CreateVector2D(p.x,p.y))
            if not clean(v) or not v then return end
            local x,y=v:GetXY()
            return w,x,y
        end)
        if ok and finite(w) and finite(x) and finite(y) then return w,x,y end
    end
    local w,x,y=world(from)
    local old,px,py=world(recent.from)
    if not w or w~=old or (x-px)^2+(y-py)^2>18^2 then return false end
    local points=lastPublished.path.waypoints
    for i=recent.segment,math.min(#points-1,recent.segment+7) do
        local a,ax,ay=world(points[i])
        local b,bx,by=world(points[i+1])
        if a==w and b==w then
            local dx,dy=bx-ax,by-ay
            local squared=dx*dx+dy*dy
            if squared>0 then
                local t=math.max(0,math.min(1,((x-ax)*dx+(y-ay)*dy)/squared))
                if (x-ax-t*dx)^2+(y-ay-t*dy)^2<=8^2 then return true end
            end
        end
    end
    return false
end

function AT.GetFocusedQuestWalkingPath(quest, from, width, height)
    if not active(quest) or not goodPlace(from) or not (finite(width) and width > 0 and finite(height) and height > 0)
        or (quest~=WAYPOINT_ID and not AT.GetFocusedQuestRouteTargets) then
        AT.CancelQuestWalking()
        return nil,nil,"position"
    end
    local cache = currentTargets(quest, from.map)
    local api, nav, road, why = apiForWalking(from, quest,nil,cache.key)
    if not api then
        local carried,target,status=carryCenterline(quest,from,width,height)
        if carried then return carried,target,status end
        clear()
        lastPublished=nil
        return nil,nil,why or "provider_missing"
    end
    if #cache.points == 0 then
        clear()
        lastPublished=nil
        return nil,nil,"objective_missing"
    end
    local now = time()
    if lastPublished and (lastPublished.quest~=quest
        or lastPublished.key~=cache.key or lastPublished.api~=api or lastPublished.nav~=nav) then lastPublished=nil end
    if lastPublished and lastPublished.map~=from.map then
        if not road and state and state.path==lastPublished.path
            and not state.cancel and canCarryRouteBoundary(from,now) then
            -- A verified dry origin and unchanged destination can keep its
            -- already-planned suffix when only the UI map changes.
            state.from,state.width,state.height=from,width,height
            lastPublished.map=from.map
        else
            lastPublished=nil
        end
    end
    if state then
        local old = state.from
        local dx, dy = (from.x-old.x)*width, (from.y-old.y)*height
        local limit = state.cancel and 160 or REPLAN_YARDS
        local moved=dx*dx+dy*dy>limit*limit
        local recent=lastRouteProgress
        if moved and state.path and recent and recent.path==state.path
            and recent.from.map==from.map and now>=recent.at and now-recent.at<=1.2 then
            local px,py=(from.x-recent.from.x)*width,(from.y-recent.from.y)*height
            if px*px+py*py<=18^2 then moved=false end
        end
        if state.quest ~= quest or old.map ~= from.map or state.api ~= api or state.nav ~= nav
            or state.key ~= cache.key or moved
            or (state.cancel and now - state.started > 35)
            or (state.retry and (now >= state.retry or not sameFailedStart(state.backoff,from,cache.key))) then clear() end
    end
    if not state and not cache.stale then
        local turnIn=cache.turnIn
        state = {quest=quest, from=from, api=api, nav=nav, targets=cache.points, backups=cache.backups, key=cache.key, turnIn=turnIn,
            started=now, phase=0, road=road,width=width,height=height}
        if #cache.points==1 and (turnIn or quest==WAYPOINT_ID) and (#cache.backups==0 or type(api.WalkBestPath)~="function") then
            state.best=cache.points[1]
            requestPath(state)
        elseif type(api.WalkBestPath)=="function" then
            chooseWalkingPath(state)
        else
            estimateNext(state, 1)
        end
    end
    if state and state.waitingPath and not cache.stale then
        state.path,state.waitingPath=state.waitingPath,nil
    end
    if state and state.path and (not lastPublished or lastPublished.path~=state.path) then
        lastPublished={path=state.path,target=state.best,quest=quest,map=from.map,key=cache.key,api=api,nav=nav}
    end
    if lastPublished then return lastPublished.path,lastPublished.target,"routed" end
    return nil,nil,state and state.failure or "planning"
end


