-- NQT's independent, cooperative walking search for the bundled dry grid.
local _,AT=...
local dx,dy={1,-1,0,0,1,1,-1,-1},{0,0,1,-1,1,-1,1,-1}
local costs={1,1,1,1,1.414213562373,1.414213562373,1.414213562373,1.414213562373}
local powers={1,2,4,8,16,32,64,128}
local floor,abs,sqrt=math.floor,math.abs,math.sqrt
local TILE=1600/3
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
local function search(D,sx,sy,tx,ty,callback)
    local W=D.ny*D.cells
    local function encode(x,y)return x*W+y end
    local function unpackKey(k)return floor(k/W),k%W end
    local function heuristic(x,y)
        local X,Y=abs(x-tx),abs(y-ty)
        return math.max(X,Y)+.414213562373*math.min(X,Y)
    end
    local source,target=encode(sx,sy),encode(tx,ty)
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
    local function finish(a,b)
        done=true
        if not cancelled then callback(a,b) end
    end
    local function tick()
        if done or cancelled then return end
        for _=1,180 do
            if #heap==0 or visits>=24000 then return finish(nil,"unreachable") end
            local row=pop()
            local k,c=row[1],row[2]
            visits=visits+1
            if c==g[k] then
                if k==target then
                    local keys={k}
                    while parents[k] do k=parents[k];keys[#keys+1]=k end
                    return finish(keys,c*TILE/D.cells)
                end
                local x,y=unpackKey(k)
                local mask=bits(D,x,y)
                if mask then for d=1,8 do
                    if floor(mask/powers[d])%2==1 then
                        local X,Y=x+dx[d],y+dy[d]
                        if bits(D,X,Y) then
                            local nextKey,v=encode(X,Y),c+costs[d]
                            if g[nextKey]==nil or v<g[nextKey] then
                                g[nextKey],parents[nextKey]=v,k
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
            result[i]=keys and yards or false
            C_Timer.After(0,nextGoal)
        end)
    end
    C_Timer.After(0,nextGoal)
    return function()stop=true;if cancel then cancel()end end
end
function api.WalkPath(_,from,to,callback)
    local D=data(from)
    local sx,sy=transform(D,from,true)
    local now=call(GetTime)
    local previous=verified[from]
    if D and not sx and previous and previous[4]==D and finite(now) and now-previous[3]>=0 and now-previous[3]<=35 then
        sx,sy=previous[1],previous[2]
    end
    verified[from]=nil
    local tx,ty=transform(D,to,false)
    if not(sx and tx) then return nil,"offmesh" end
    return search(D,sx,sy,tx,ty,function(keys,yards)
        if not keys then callback(nil,yards);return end
        local points={}
        local W=D.ny*D.cells
        for i=#keys,1,-1 do
            local k=keys[i]
            local x=(D.tx+(floor(k/W)+.5)/D.cells)*TILE
            local y=(D.ty+(k%W+.5)/D.cells)*TILE
            local map,p=call(C_Map.GetMapPosFromWorldPos,D.world,CreateVector2D(x,y),from.map)
            if not finite(map) or not p or issecretvalue and issecretvalue(p) then callback(nil,"projection");return end
            local u,v=call(p.GetXY,p)
            if not(finite(u) and finite(v) and u>=0 and u<=1 and v>=0 and v<=1) then callback(nil,"projection");return end
            points[#points+1]={map=map,x=u,y=v}
        end
        callback({waypoints=points,yards=yards,navVersion=api.NavVersion(),roadAware=false})
    end)
end
function AT.GetBundledWalkingAPI(origin,snapshot)
    local D=data(origin)
    if not D or not C_Timer or type(C_Timer.After)~="function" or not C_Map or not C_Map.GetMapPosFromWorldPos then return end
    local _,build=call(GetBuildInfo)
    if not (build=="71037" or build=="71139") then return end
    local indoors=call(IsIndoors)
    if indoors==true or call(IsInInstance)==true or call(IsSwimming)==true
        or call(IsFlying)==true or call(UnitOnTaxi,"player")==true then return end
    -- The base grid has no reliable position on top of a second floor.
    if transform(D,origin,not snapshot) then return api end
end
