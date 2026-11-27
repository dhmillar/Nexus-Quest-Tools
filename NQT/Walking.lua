local _, AT = ...
local OWNER = "AutoTrack.QuestWalking"
local BATCH_SIZE, SAMPLE_SECONDS, REPLAN_YARDS = 256, 0.70, 80
local candidateCache, state, currentTargets, lastPublished, lastGoodTargets
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

local function time()
    return GetTime and GetTime() or 0
end

local function apiForWalking(from, quest)
    local now=time()
    local lastFailure
    local function checked(api, road)
        if type(api) ~= "table" or api.version ~= 2 or not finite(api.minor) or api.minor < 7
            or type(api.EstimateWalks) ~= "function" or type(api.WalkPath) ~= "function"
            or type(api.NavVersion) ~= "function" then return end
        local failure=providerBackoff[api]
        if failure and failure.quest==quest and failure.map==from.map and now<failure.untilTime then
            lastFailure=lastFailure or failure.reason
            return
        end
        local ok, nav = pcall(api.NavVersion)
        if ok and type(nav) == "string" and nav ~= "" then return api, nav, road end
    end
    -- Use SPF's public walking solver first. Do not start, stop, or replace
    -- the player's own journey; NQT owns a separate request and both overlays.
    local api,nav,road=checked(ShortestPathForever and ShortestPathForever.API,false)
    if api then return api,nav,road end
    api,nav,road=checked(AT.GetRoadWalkingAPI and AT.GetRoadWalkingAPI(from),true)
    return api,nav,road,lastFailure
end

local function active(quest)
    return AT.db and AT.db.enabled ~= false and AT.db.showQuestRoute ~= false
        and (AT.GetQuestNavigationID or AT.GetFocusedQuestID)
        and (AT.GetQuestNavigationID or AT.GetFocusedQuestID)() == quest
end

local function clear()
    local old = state
    state = nil
    if old and old.cancel then pcall(old.cancel) end
end

function AT.CancelQuestWalking()
    clear()
    candidateCache, lastGoodTargets, lastPublished = nil, nil, nil
end

local function valid(job)
    if state ~= job or not active(job.quest) then return false end
    local api, nav = apiForWalking(job.from, job.quest)
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
    providerBackoff[job.api] = {quest=job.quest,map=job.from.map,untilTime=job.retry,reason=job.failure}
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

local function requestPath(job)
    if not job.best then fail(job, "unreachable"); return end
    request(job, job.api.WalkPath, job.best, function(path, why)
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
        if latest.stale then job.waitingPath = path else job.path = path end
    end)
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

currentTargets = function(quest, map, force)
    if not force and candidateCache and candidateCache.quest == quest and candidateCache.map == map
        and time() < candidateCache.at + SAMPLE_SECONDS then return candidateCache end
    local ok, id, points = pcall(AT.GetFocusedQuestRouteTargets, map)
    if not ok or id ~= quest or type(points) ~= "table" then points = {} end
    local list, signature = {}, {}
    for _, point in ipairs(points) do
        if goodPlace(point) then
            list[#list+1] = point
            signature[#signature+1] = point.map .. ":" .. point.x .. ":" .. point.y
        end
    end
    local now=time()
    if #list==0 and lastGoodTargets and lastGoodTargets.quest==quest and lastGoodTargets.map==map
        and now-lastGoodTargets.at < 2 then
        candidateCache={quest=quest,map=map,at=now,points=lastGoodTargets.points,key=lastGoodTargets.key,stale=true}
        return candidateCache
    end
    candidateCache = {quest=quest, map=map, at=now, points=list, key=table.concat(signature, "|")}
    if #list>0 then lastGoodTargets=candidateCache end
    return candidateCache
end

function AT.GetFocusedQuestWalkingPath(quest, from, width, height)
    if not active(quest) or not goodPlace(from) or not (finite(width) and width > 0 and finite(height) and height > 0)
        or not AT.GetFocusedQuestRouteTargets then
        AT.CancelQuestWalking()
        return nil,nil,"position"
    end
    local api, nav, road, why = apiForWalking(from, quest)
    if not api then
        AT.CancelQuestWalking()
        return nil,nil,why or "provider_missing"
    end
    local cache = currentTargets(quest, from.map)
    if #cache.points == 0 then
        clear()
        lastPublished=nil
        return nil,nil,"objective_missing"
    end
    local now = time()
    if lastPublished and (lastPublished.quest~=quest or lastPublished.map~=from.map
        or lastPublished.key~=cache.key or lastPublished.api~=api or lastPublished.nav~=nav) then lastPublished=nil end
    if state then
        local old = state.from
        local dx, dy = (from.x-old.x)*width, (from.y-old.y)*height
        local limit = state.cancel and 160 or REPLAN_YARDS
        if state.quest ~= quest or old.map ~= from.map or state.api ~= api or state.nav ~= nav
            or state.key ~= cache.key or dx*dx + dy*dy > limit*limit
            or (state.cancel and now - state.started > 35)
            or (state.retry and now >= state.retry) then clear() end
    end
    if not state and not cache.stale then
        state = {quest=quest, from=from, api=api, nav=nav, targets=cache.points, key=cache.key,
            started=now, phase=0, road=road}
        if #cache.points==1 and AT.IsQuestTurnInNavigation and AT.IsQuestTurnInNavigation(quest) then
            state.best=cache.points[1]
            requestPath(state)
        else
            estimateNext(state, 1)
        end
    end
    if state and state.waitingPath and not cache.stale then
        state.path,state.waitingPath=state.waitingPath,nil
    end
    if state and state.path then
        lastPublished={path=state.path,target=state.best,quest=quest,map=from.map,key=cache.key,api=api,nav=nav}
    end
    if lastPublished then return lastPublished.path,lastPublished.target,"routed" end
    return nil,nil,state and state.failure or "planning"
end


