-- NQT's independent, cooperative walking search for the bundled dry grid.
local _,AT=...
local dx,dy={1,-1,0,0,1,1,-1,-1},{0,0,1,-1,1,-1,1,-1}
local costs={1,1,1,1,1.414213562373,1.414213562373,1.414213562373,1.414213562373}
local powers={1,2,4,8,16,32,64,128}
local floor,abs,sqrt=math.floor,math.abs,math.sqrt
local TILE=1600/3
local MAX_VISITS=36000
local function finite(v) return (not issecretvalue or not issecretvalue(v)) and type(v)=="number" and v==v and abs(v)<math.huge end
local function call(f,...)
    if type(f)~="function" then return end
    local ok,a,b,c,d=pcall(f,...)
    if ok then return a,b,c,d end
end
local digits={}
do
    local chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    for i=1,#chars do digits[chars:byte(i)]=i-1 end
end
local tileCache,clock={},0
local function decoded(D,key,tile)
    if D.codec~="nq1" then return tile end
    local id=D.world*10000+key
    local old=tileCache[id]
    clock=clock+1
    if old then old.used=clock;return old.bytes end
    local chunks,size,p,z={},0,1,0
    local cap=D.cells*D.cells
    local function digit()
        local a=digits[tile:byte(p)]
        p=p+1
        return a
    end
    while p<=#tile do
        local a,b,c=digit(),digit(),digit()
        if not(a and b and c) then return end
        if a==0 then
            local n=b*64+c
            if n==0 or size+n>cap then return end
            chunks[#chunks+1]=string.rep(string.char(0),3*n)
            size=size+n
        else
            local mask=(a-1)*64+b
            if mask==0 or mask>255 or size>=cap then return end
            if c==63 then
                local d,e,f=digit(),digit(),digit()
                if not(d and e and f) then return end
                local n=d*4096+e*64+f
                z=n%2==0 and n/2 or -(n+1)/2
            else z=z+c-31 end
            if z < -32768 or z > 32767 then return end
            chunks[#chunks+1]=string.char(mask,z%256,floor(z/256)%256)
            size=size+1
        end
    end
    if size~=cap then return end
    local count,oldID,last=0
    for k,v in pairs(tileCache) do
        count=count+1
        if not last or v.used<last then oldID,last=k,v.used end
    end
    if count>=18 then tileCache[oldID]=nil end
    local bytes=table.concat(chunks)
    tileCache[id]={used=clock,bytes=bytes}
    return bytes
end
local function project(point)
    if not point or not finite(point.map) or not finite(point.x) or not finite(point.y)
        or not(CreateVector2D and C_Map) then return end
    local world,v=call(C_Map.GetWorldPosFromMapPos,point.map,CreateVector2D(point.x,point.y))
    if not finite(world) or not v or issecretvalue and issecretvalue(v) then return end
    local x,y=call(v.GetXY,v)
    if finite(x) and finite(y) then return world,x,y end
end
local function data(point)
    local world=project(point)
    local db=AT.NQTDB
    if not db or not world then return end
    if db.RouteWorlds and db.RouteWorlds[world] then return db.RouteWorlds[world] end
    if db.RouteTiles and db.RouteTiles.world==world then return db.RouteTiles end
end
local function bits(D,x,y)
    if x<0 or y<0 or x>=D.nx*D.cells or y>=D.ny*D.cells then return end
    local n=D.cells
    local key=floor(x/n)*D.ny+floor(y/n)+1
    local tile=D.tiles[key]
    if tile then tile=decoded(D,key,tile) end
    if not tile then return end
    local p=((x%n)*n+y%n)*3+1
    local mask,l,h=string.byte(tile,p,p+2)
    if not mask or mask==0 or not h then return end
    local z=l+256*h
    if z>=32768 then z=z-65536 end
    return mask,z
end
local function transform(D,point,checkHeight)
    local world,x,y=project(point)
    if not D or world~=D.world then return end
    local X,Y=floor(x/TILE*D.cells-D.tx*D.cells),floor(y/TILE*D.cells-D.ty*D.cells)
    local mask,z=bits(D,X,Y)
    if not mask then return end
    if checkHeight then
        local px,py,az,area=call(UnitPosition,"player")
        if not(finite(area) and area==world and finite(px) and finite(py) and finite(az)
            and (x-px)^2+(y-py)^2<=16 and abs(az-z)<=5) then return end
    end
    return X,Y
end
local function search(D,sx,sy,tx,ty,callback,estimateOnly,goals)
    local W=D.ny*D.cells
    local function encode(x,y)return x*W+y end
    local function unpackKey(k)return floor(k/W),k%W end
    local lowX,highX,lowY,highY=tx,tx,ty,ty
    local cells={}
    if goals then
        for _,g in ipairs(goals) do
            local x,y=g[1],g[2]
            local k=encode(x,y)
            if not cells[k] then cells[k]=g[3] end
            lowX=not lowX and x or math.min(lowX,x)
            highX=not highX and x or math.max(highX,x)
            lowY=not lowY and y or math.min(lowY,y)
            highY=not highY and y or math.max(highY,y)
        end
    else cells[encode(tx,ty)]=1 end
    -- The octile distance to the bounding box never exceeds the
    -- shortest route to any goal, even if some of the goals are isolated.
    local function heuristic(x,y)
        local X,Y=math.max(lowX-x,0,x-highX),math.max(lowY-y,0,y-highY)
        return math.max(X,Y)+.414213562373*math.min(X,Y)
    end
    local source=encode(sx,sy)
    local g,parents,heap={[source]=0},{},{}
    local function push(k,c,f)
        local i=#heap+1
        while i>1 do
            local p=floor(i/2);if heap[p][3]<=f then break end
            heap[i]=heap[p];i=p
        end
        heap[i]={k,c,f}
    end
    local function pop()
        local first,last=heap[1],table.remove(heap)
        if #heap>0 then
            local i=1
            while i*2<=#heap do
                local ch=i*2
                if heap[ch+1] and heap[ch+1][3]<heap[ch][3] then ch=ch+1 end
                if last[3]<=heap[ch][3] then break end
                heap[i]=heap[ch];i=ch
            end
            heap[i]=last
        end
        return first
    end
    push(source,0,heuristic(sx,sy))
    local done,cancelled,visits
    visits=0
    local function finish(a,b,c)
        done=true
        if not cancelled then callback(a,b,c) end
    end
    local function tick()
        if done or cancelled then return end
        for _=1,180 do
            if #heap==0 then return finish(nil,"unreachable") end
            if visits>=MAX_VISITS then return finish(nil,"budget") end
            local row=pop()
            local k,c=row[1],row[2]
            visits=visits+1
            if c==g[k] then
                local winner=cells[k]
                if winner then
                    if estimateOnly then return finish(true,c*TILE/D.cells) end
                    local keys={k}
                    local function trace()
                        if done or cancelled then return end
                        for step=1,512 do
                            local prev=parents[k]
                            if not prev then return finish(keys,c*TILE/D.cells,winner) end
                            keys[#keys+1]=prev;k=prev
                        end
                        C_Timer.After(0,trace)
                    end
                    return trace()
                end
                local x,y=unpackKey(k)
                local mask=bits(D,x,y)
                if mask then for d=1,8 do
                    if floor(mask/powers[d])%2==1 then
                        local X,Y=x+dx[d],y+dy[d]
                        if bits(D,X,Y) then
                            local nextKey,v=encode(X,Y),c+costs[d]
                            if g[nextKey]==nil or v<g[nextKey] then
                                g[nextKey]=v
                                if not estimateOnly then parents[nextKey]=k end
                                push(nextKey,v,v+heuristic(X,Y))
                            end
                        end
                    end
                end end
            end
        end
        C_Timer.After(0,tick)
    end
    C_Timer.After(0,tick)
    return function()cancelled=true end
end
local verified=setmetatable({},{__mode="k"})
local api={version=2,minor=7,NavVersion=function()return "NQTDB-dry-multiworld-1" end}
function api.EstimateWalks(_,from,targets,callback)
    local D=data(from)
    local sx,sy=transform(D,from,true)
    if not sx then return nil,"offmesh" end
    local now=call(GetTime)
    if finite(now) then verified[from]={sx,sy,now,D} end
    local result,i,stop,cancel={},0,nil,nil
    local function nextGoal()
        if stop then return end
        i=i+1
        local target=targets[i]
        if not target then callback(result);return end
        local x,y=transform(D,target,false)
        if not x then result[i]=false;C_Timer.After(0,nextGoal);return end
        cancel=search(D,sx,sy,x,y,function(keys,yards)
            if not keys and yards=="budget" then callback(nil,"budget");return end
            result[i]=keys and yards or false
            C_Timer.After(0,nextGoal)
        end,true)
    end
    C_Timer.After(0,nextGoal)
    return function()stop=true;if cancel then cancel()end end
end
local function mapCandidates(from,to)
    local out,seen={},{}
    local function add(map)
        if finite(map) and map>0 and not seen[map] then seen[map]=true;out[#out+1]=map end
    end
    add(from.map);add(to.map)
    -- Walk known map ancestors only. Never project through another continent.
    for _,p in ipairs({from,to}) do
        local map=p.map
        for _=1,5 do
            local info=call(C_Map.GetMapInfo,map)
            if not info or issecretvalue and issecretvalue(info) or type(info)~="table" then break end
            local up=info.parentMapID
            if not finite(up) or up<=0 or up==map then break end
            add(up);map=up
        end
    end
    return out
end
local function projectOut(world,x,y,hint)
    local map,p=call(C_Map.GetMapPosFromWorldPos,world,CreateVector2D(x,y),hint)
    if not finite(map) or map<1 or not p or issecretvalue and issecretvalue(p) then return end
    local u,v=call(p.GetXY,p)
    if not(finite(u) and finite(v) and u>=0 and u<=1 and v>=0 and v<=1) then return end
    local result={map=map,x=u,y=v}
    local w,rx,ry=project(result)
    if w==world and (rx-x)^2+(ry-y)^2<=1 then return result end
end
local function startCell(from)
    local D=data(from)
    local sx,sy=transform(D,from,true)
    local now=call(GetTime)
    local previous=verified[from]
    if D and not sx and previous and previous[4]==D and finite(now) and now-previous[3]>=0 and now-previous[3]<=35 then
        sx,sy=previous[1],previous[2]
    end
    verified[from]=nil
    return D,sx,sy
end
local function beginPath(D,sx,sy,tx,ty,from,targets,callback,goals)
    local stopped
    local cancel=search(D,sx,sy,tx,ty,function(keys,yards,winner)
        if not keys then callback(nil,yards);return end
        local to=targets[winner]
        local points={}
        local W=D.ny*D.cells
        local i=#keys
        local candidates=mapCandidates(from,to)
        local lastHint=candidates[1]
        local function projectBatch()
            if stopped then return end
            -- Small batches keep long multi-tile paths from blocking a frame.
            for _=1,48 do
                if i<1 then
                    callback({waypoints=points,yards=yards,navVersion=api.NavVersion(),roadAware=false,targetIndex=winner})
                    return
                end
                local k=keys[i]
                local nextIndex=i-1
                if #keys>512 and i>=3 then
                    -- Merge identical directions only, following already validated
                    -- edges. Keep periodic vertices and never skip a turn.
                    local delta=keys[i-1]-k
                    for j=i-2,math.max(1,i-48),-1 do
                        if keys[j]-keys[j+1]~=delta then break end
                        nextIndex=j
                    end
                end
                local x=(D.tx+(floor(k/W)+.5)/D.cells)*TILE
                local y=(D.ty+(k%W+.5)/D.cells)*TILE
                local point=projectOut(D.world,x,y,lastHint)
                if not point then
                    for _,hint in ipairs(candidates) do
                        if hint~=lastHint then
                            point=projectOut(D.world,x,y,hint)
                            if point then lastHint=hint;break end
                        end
                    end
                end
                if not point then callback(nil,"projection");return end
                points[#points+1]=point
                i=nextIndex
            end
            C_Timer.After(0,projectBatch)
        end
        projectBatch()
    end,false,goals)
    return function() stopped=true;cancel() end
end
function api.WalkPath(_,from,to,callback)
    local D,sx,sy=startCell(from)
    local tx,ty=transform(D,to,false)
    if not(sx and tx) then return nil,"offmesh" end
    return beginPath(D,sx,sy,tx,ty,from,{to},callback)
end
function api.WalkBestPath(_,from,targets,callback)
    local D,sx,sy=startCell(from)
    if not sx then return nil,"offmesh" end
    if #targets>256 then return nil,"budget" end
    local goals,i,cancel,stopped={},0
    local function collect()
        if stopped then return end
        for _=1,12 do
            i=i+1
            local target=targets[i]
            if not target then
                if #goals==0 then callback(nil,"offmesh");return end
                cancel=beginPath(D,sx,sy,nil,nil,from,targets,callback,goals)
                return
            end
            local x,y=transform(D,target,false)
            if x then goals[#goals+1]={x,y,i} end
        end
        C_Timer.After(0,collect)
    end
    C_Timer.After(0,collect)
    return function() stopped=true;if cancel then cancel() end end
end
function AT.GetBundledWalkingAPI(origin,snapshot)
    local D=data(origin)
    if not D or not C_Timer or type(C_Timer.After)~="function" or not C_Map or not C_Map.GetMapPosFromWorldPos then return end
    local _,build=call(GetBuildInfo)
    if not (build=="71037" or build=="71139") then return end
    if call(IsInInstance)==true or call(IsSwimming)==true
        or call(IsFlying)==true or call(UnitOnTaxi,"player")==true then return end
    -- The base grid has no reliable position on top of a second floor.
    if transform(D,origin,not snapshot) then return api end
end
