local _, AT = ...
local previous, adapter
local STYLE = "balanced"

local function finite(n)
    return (not issecretvalue or not issecretvalue(n)) and type(n)=="number"
        and n==n and n>-math.huge and n<math.huge
end

local function transform(point)
    local continent, pos = C_Map.GetWorldPosFromMapPos(point.map, CreateVector2D(point.x, point.y))
    if not finite(continent) or not pos then return end
    local x,y = pos:GetXY()
    if not finite(x) or not finite(y) then return end
    return continent,{x=x,y=y}
end

local function normalized(continent, point, mapID)
    if point.map ~= continent or not finite(point.x) or not finite(point.y) then return end
    local v = CreateVector2D(point.x,point.y)
    local id,pos = C_Map.GetMapPosFromWorldPos(continent,v,mapID)
    if finite(id) and pos then
        local x,y=pos:GetXY()
        if finite(x) and finite(y) and x>=0 and x<=1 and y>=0 and y<=1 then return {map=id,x=x,y=y} end
    end
    id,pos = C_Map.GetMapPosFromWorldPos(continent,v)
    if finite(id) and pos then
        local x,y=pos:GetXY()
        if finite(x) and finite(y) and x>=0 and x<=1 and y>=0 and y<=1 then return {map=id,x=x,y=y} end
    end
end

local function authorizedVersion()
    local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata
    if not getMetadata then return end
    local version = getMetadata("Polestar_Nav","Version")
    if type(version) ~= "string" then return end
    local major,minor,patch,rev = version:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    if tonumber(major)==0 and tonumber(minor)==4 and tonumber(patch)
        and (tonumber(patch)>2 or (tonumber(patch)==2 and tonumber(rev)>=2)) then return version end
end

local function makeAdapter(engine, version)
    local nav = "PolestarNav:" .. version
    local function options()
        local faction = UnitFactionGroup and UnitFactionGroup("player")
        return {style=STYLE,profile=(faction=="Alliance" or faction=="Horde") and faction or nil}
    end
    local function jobCancel(job)
        if not job then return nil,"unavailable" end
        local cancelled
        return function() if not cancelled then cancelled=true; engine.Cancel(job) end end
    end
    local api = {version=2,minor=7,NavVersion=function() return nav end}
    function api.EstimateWalks(_,from,targets,callback)
        local continent,origin = transform(from)
        if not origin then return nil,"outside" end
        local goals={}
        for i,target in ipairs(targets) do
            local area,point=transform(target)
            if area~=continent or not point then return nil,"outside" end
            goals[i]=point
        end
        local job=engine.FindMany(continent,origin,goals,function(costs,why,result)
            if why or type(costs)~="table" or type(result)~="table" or type(result.yards)~="table" then
                callback(nil,why or "invalid"); return
            end
            local yards={}
            for i=1,#goals do
                if costs[i]==false then yards[i]=false
                elseif finite(costs[i]) and finite(result.yards[i]) and result.yards[i]>=0 then yards[i]=result.yards[i]
                else callback(nil,"invalid"); return end
            end
            callback(yards)
        end,options())
        return jobCancel(job)
    end
    function api.WalkPath(_,from,to,callback)
        local continent,origin = transform(from)
        local targetMap,target = transform(to)
        if not origin or continent~=targetMap or not target then return nil,"outside" end
        local job=engine.Find(continent,origin,target,function(points,cost,result)
            if type(points)~="table" or not finite(cost) or type(result)~="table" or not finite(result.yards) then
                callback(nil,type(cost)=="string" and cost or "invalid"); return
            end
            local path={waypoints={},yards=result.yards,navVersion=nav,roadAware=true}
            for i,pt in ipairs(points) do
                local mapPoint=normalized(continent,pt,from.map)
                if not mapPoint then callback(nil,"outside"); return end
                path.waypoints[i]=mapPoint
            end
            if #path.waypoints<2 then callback(nil,"invalid"); return end
            callback(path)
        end,options())
        return jobCancel(job)
    end
    return api
end

local triedLoad
local function loadEnabledRoadModule()
    if triedLoad or (InCombatLockdown and InCombatLockdown()) then return end
    local api=C_AddOns
    if not api or not api.DoesAddOnExist or not api.GetAddOnEnableState
        or not api.IsAddOnLoaded or not api.LoadAddOn then return end
    -- No installation, dependency enabling or settings changes. Only let the
    -- stock loader finish the supported module of an already enabled add-on.
    if not api.DoesAddOnExist("Polestar_Nav") or not api.IsAddOnLoaded("Polestar")
        or api.IsAddOnLoaded("Polestar_Nav") or not authorizedVersion() then return end
    local player=UnitName and UnitName("player")
    local enabled=api.GetAddOnEnableState("Polestar_Nav",player)
    if not finite(enabled) or enabled<=0 then return end
    triedLoad=true
    pcall(api.LoadAddOn,"Polestar_Nav")
end
function AT.GetRoadWalkingAPI(origin)
    if not Polestar_NavEngine then pcall(loadEnabledRoadModule) end
    local engine=Polestar_NavEngine
    if type(engine)~="table" or type(engine.Find)~="function" or type(engine.FindMany)~="function"
        or type(engine.Cancel)~="function" or type(engine.Available)~="function"
        or not C_Map or not C_Map.GetWorldPosFromMapPos or not C_Map.GetMapPosFromWorldPos
        or not CreateVector2D then return end
    local ok,version=pcall(authorizedVersion)
    if not ok or not version then return end
    local positionOK,world,position=pcall(transform,origin)
    if not positionOK or not position then return end
    local availabilityOK,available=pcall(engine.Available,world)
    if not availabilityOK or available~=true then return end
    if previous~=engine then previous,adapter=engine,makeAdapter(engine,version) end
    return adapter
end

