-- NQT's independent, cooperative walking search for the bundled dry grid.
local _,AT=...
local dx,dy={1,-1,0,0,1,1,-1,-1},{0,0,1,-1,1,-1,1,-1}
local UNIT,DIAG=1000000,1414214
local costs={UNIT,UNIT,UNIT,UNIT,DIAG,DIAG,DIAG,DIAG}
local powers={1,2,4,8,16,32,64,128}
local floor,abs,sqrt=math.floor,math.abs,math.sqrt
local TILE=1600/3
local MAX_VISITS,KNOWN_CONNECTED_VISITS,DISTANT_CONNECTED_VISITS=36000,90000,132000
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
    if D.endpointFlags2 then
        local flags=z%4
        return mask,(z-flags)/2,flags%2==1,flags>=2
    end
    local layerFlag=D.layerTransit and z%2 or 0
    return mask,z-layerFlag,layerFlag==1,false
end
local function component(D,x,y)
    local groups=AT.NQTDB and AT.NQTDB.DryComponents
    local data=groups and groups[D.world]
    if not data then return end
    local n=D.cells
    local key=floor(x/n)*D.ny+floor(y/n)+1
    local row=data[key]
    if type(row)~="string" or #row%5~=0 then return end
    local at=(x%n)*n+y%n
    for i=1,#row,5 do
        local a,b,c,d,e=row:byte(i,i+4)
        a,b,c,d,e=digits[a],digits[b],digits[c],digits[d],digits[e]
        if not(a and b and c and d and e) then return end
        local span=a*64+b
        if span<=0 then return end
        if at<span then
            local id=c*4096+d*64+e
            if id>0 then return id end
            return
        end
        at=at-span
    end
end
local function differentComponent(D,sx,sy,tx,ty)
    local a,b=component(D,sx,sy),component(D,tx,ty)
    return a and b and a~=b
end
local function confirmOrigin(world,x,y,z,map)
    local px,py,az,area=call(UnitPosition,"player")
    if finite(area) and area~=world then return false end
    -- Forever can return a placeholder 0, or not disclose height at all.
    -- The caller has already excluded water, stacked cells and instances.
    -- A meaningful but contradictory height still disqualifies the origin.
    if finite(az) and az~=0 and abs(az-z)>5 then return false end
    if finite(px) and finite(py) and finite(area) then
        return (x-px)^2+(y-py)^2<=16
    end
    -- Use only independent, currently readable player-map inputs. Do not
    -- try to interpret the hidden values or infer a particular stacked floor.
    local current=call(C_Map.GetBestMapForUnit,"player")
    if not finite(current) or current~=map then return false end
    local position=call(C_Map.GetPlayerMapPosition,map,"player")
    if not position or issecretvalue and issecretvalue(position) then return false end
    local u,v=call(position.GetXY,position)
    if not(finite(u) and finite(v) and u>=0 and u<=1 and v>=0 and v<=1) then return false end
    local w,X,Y=project({map=map,x=u,y=v})
    return w==world and (X-x)^2+(Y-y)^2<=16
end
local function transform(D,point,checkHeight,asOrigin)
    local world,x,y=project(point)
    if not D or world~=D.world then return end
    local X,Y=floor(x/TILE*D.cells-D.tx*D.cells),floor(y/TILE*D.cells-D.ty*D.cells)
    local mask,z,layered,narrow=bits(D,X,Y)
    -- Transit-only cells can carry a proven dry edge, not a guessed endpoint.
    if not mask or layered then return end
    if narrow then
        -- The tile bake only certifies the centerline. Reserve that point
        -- for a live origin close to it, never a guessed quest destination.
        if not asOrigin then return end
        local cx=(D.tx+(X+.5)/D.cells)*TILE
        local cy=(D.ty+(Y+.5)/D.cells)*TILE
        if (x-cx)^2+(y-cy)^2>1.5^2 then return end
    end
    if checkHeight and not confirmOrigin(world,x,y,z,point.map) then return end
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
    local limit=MAX_VISITS
    local group=component(D,sx,sy)
    if group then
        if goals then
            for _,g in ipairs(goals) do
                if component(D,g[1],g[2])==group then limit=KNOWN_CONNECTED_VISITS;break end
            end
        elseif component(D,tx,ty)==group then limit=KNOWN_CONNECTED_VISITS end
    end
    local atlas=AT.NQTDB and AT.NQTDB.DryLandmarks
    atlas=atlas and atlas[D.world]
    local destinations,regionScores={},{}
    -- With a few goals, keep their intervals separate. The union can
    -- bridge an entire watershed and remove useful bounds in between.
    local perGoal=goals and #goals>=2 and #goals<=4 and {} or nil
    local function region(x,y)
        return floor(x/atlas.step)*atlas.groups+floor(y/atlas.step)+1
    end
    local function rangeAt(index)
        local r=atlas.ranges[index]
        if type(r)=="table" then return r end
        if atlas.codec~="b64x4" or type(r)~="string" or #r~=32 then return end
        local out={}
        for i=1,32,4 do
            local a,b,c,d=r:byte(i,i+3)
            if not (digits[a] and digits[b] and digits[c] and digits[d]) then return end
            out[#out+1]=((digits[a]*64+digits[b])*64+digits[c])*64+digits[d]
        end
        return out
    end
    if atlas and group==atlas.component then
        local function include(x,y)
            if component(D,x,y)~=group then atlas=nil;return end
            local r=rangeAt(region(x,y))
            if not r then atlas=nil;return end
            if perGoal then perGoal[#perGoal+1]=r;return end
            for i=1,#r,2 do
                destinations[i]=destinations[i] and math.min(destinations[i],r[i]) or r[i]
                destinations[i+1]=destinations[i+1] and math.max(destinations[i+1],r[i+1]) or r[i+1]
            end
        end
        if goals then for _,g in ipairs(goals) do
            include(g[1],g[2]);if not atlas then break end
        end
        else include(tx,ty) end
    else atlas=nil end
    local function intervalBound(a,b)
        local best=0
        if a and b then for i=1,#b,2 do
            best=math.max(best,b[i]-a[i+1],a[i]-b[i+1])
        end end
        return best*1000
    end
    local function lowerBound(x,y)
        if not atlas then return 0 end
        local k=region(x,y)
        if regionScores[k] then return regionScores[k] end
        local r=rangeAt(k)
        -- Distances were computed with no greater costs; interval
        -- separation cannot exceed the true cost to any accepted goal.
        local bound
        if perGoal then
            bound={}
            for i=1,#perGoal do bound[i]=intervalBound(r,perGoal[i]) end
        else bound=intervalBound(r,destinations) end
        regionScores[k]=bound
        return bound
    end
    -- A wide box between a few alternate destinations can have a zero
    -- lower bound even when every actual destination is far away. For
    -- small goal sets use the nearest actual cell in the relaxed grid.
    -- Keep the constant-work bounding box for large search sets.
    local max,min=math.max,math.min
    local function octile(X,Y)
        return UNIT*max(X,Y)+(DIAG-UNIT)*min(X,Y)
    end
    local function heuristic(x,y)
        local geometric
        if perGoal then
            local bounds=atlas and lowerBound(x,y)
            geometric=math.huge
            for i=1,#goals do
                local dest=goals[i]
                local v=octile(abs(dest[1]-x),abs(dest[2]-y))
                if bounds then v=max(v,bounds[i]) end
                if v<geometric then geometric=v end
            end
            return geometric
        else
            geometric=octile(max(lowX-x,0,x-highX),max(lowY-y,0,y-highY))
        end
        return max(lowerBound(x,y),geometric)
    end
    local source=encode(sx,sy)
    local g,parents,heap,queued={[source]=0},{},{},{}
    local function better(f,c,b) return f<b[3] or (f==b[3] and c>b[2]) end
    local function push(k,c,f)
        -- Each queued cell has one heap row. Improving a tentative route
        -- decreases its key in place rather than keeping stale entries
        -- that later consume the frame and visit budgets.
        local i=queued[k] or #heap+1
        local entry=heap[i]
        if entry then entry[2],entry[3]=c,f else entry={k,c,f} end
        while i>1 do
            local p=floor(i/2)
            local parent=heap[p]
            if not better(f,c,parent) then break end
            heap[i]=parent;queued[parent[1]]=i;i=p
        end
        heap[i]=entry;queued[k]=i
    end
    local function pop()
        local first,last=heap[1],table.remove(heap)
        queued[first[1]]=nil
        if #heap>0 then
            local i=1
            while i*2<=#heap do
                local ch=i*2
                if heap[ch+1] and better(heap[ch+1][3],heap[ch+1][2],heap[ch]) then ch=ch+1 end
                local child=heap[ch]
                if not better(child[3],child[2],last) then break end
                heap[i]=child;queued[child[1]]=i;i=ch
            end
            heap[i]=last;queued[last[1]]=i
        end
        return first
    end
    local initial=heuristic(sx,sy)
    -- A long route in a proven connected component can need more search.
    -- Keep the original frame budget, and never extend a speculative search.
    if limit==KNOWN_CONNECTED_VISITS and initial/UNIT*TILE/D.cells>=3000 then
        limit=DISTANT_CONNECTED_VISITS
    end
    push(source,0,initial)
    local done,cancelled,visits
    visits=0
    local function finish(a,b,c)
        done=true
        if not cancelled then callback(a,b,c) end
    end
    local function tick()
        if done or cancelled then return end
        local start=call(debugprofilestop)
        for i=1,180 do
            if i%24==0 and finite(start) then
                local now=call(debugprofilestop)
                if finite(now) and now-start>1.5 then break end
            end
            if #heap==0 then return finish(nil,"unreachable") end
            if visits>=limit then return finish(nil,"budget") end
            local row=pop()
            local k,c=row[1],row[2]
            visits=visits+1
            if c==g[k] then
                local winner=cells[k]
                if winner then
                    if estimateOnly then return finish(true,c/UNIT*TILE/D.cells) end
                    local keys={k}
                    local function trace()
                        if done or cancelled then return end
                        for step=1,512 do
                            local prev=parents[k]
                            if not prev then return finish(keys,c/UNIT*TILE/D.cells,winner) end
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
                        local nextKey,v=encode(X,Y),c+costs[d]
                        local old=g[nextKey]
                        -- Reject already dominated relaxations before reading
                        -- the terrain tile; improving moves still check it.
                        if (old==nil or v<old) and bits(D,X,Y) then
                            g[nextKey]=v
                            if not estimateOnly then parents[nextKey]=k end
                            push(nextKey,v,v+heuristic(X,Y))
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
    local sx,sy=transform(D,from,true,true)
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
        if not x or differentComponent(D,sx,sy,x,y) then result[i]=false;C_Timer.After(0,nextGoal);return end
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
    local sx,sy=transform(D,from,true,true)
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
    if differentComponent(D,sx,sy,tx,ty) then return nil,"unreachable" end
    return beginPath(D,sx,sy,tx,ty,from,{to},callback)
end
function api.WalkBestPath(_,from,targets,callback)
    local D,sx,sy=startCell(from)
    if not sx then return nil,"offmesh" end
    if #targets>256 then return nil,"budget" end
    local goals,i,cancel,stopped,projectable={},0
    local function collect()
        if stopped then return end
        for _=1,12 do
            i=i+1
            local target=targets[i]
            if not target then
                if #goals==0 then callback(nil,projectable and "unreachable" or "offmesh");return end
                cancel=beginPath(D,sx,sy,nil,nil,from,targets,callback,goals)
                return
            end
            local x,y=transform(D,target,false)
            if x then
                projectable=true
                if not differentComponent(D,sx,sy,x,y) then goals[#goals+1]={x,y,i} end
            end
        end
        C_Timer.After(0,collect)
    end
    C_Timer.After(0,collect)
    return function() stopped=true;if cancel then cancel() end end
end
local function eligible(origin)
    local D=data(origin)
    if not D or not C_Timer or type(C_Timer.After)~="function" or not C_Map or not C_Map.GetMapPosFromWorldPos then return end
    local _,build=call(GetBuildInfo)
    if not (build=="71037" or build=="71139") then return end
    if call(IsInInstance)==true or call(IsSwimming)==true
        or call(IsFlying)==true or call(UnitOnTaxi,"player")==true then return end
    return D
end
function AT.GetBundledWalkingAPI(origin,snapshot)
    local D=eligible(origin)
    -- Layered cells never pass endpoint validation, even with readable X/Y.
    if D and transform(D,origin,not snapshot,true) then return api end
end
function AT.CanCarryBundledCenterline(origin)
    local D=eligible(origin)
    if not D or not D.endpointFlags2 then return false end
    local w,x,y=project(origin)
    if w~=D.world then return false end
    local X,Y=floor(x/TILE*D.cells-D.tx*D.cells),floor(y/TILE*D.cells-D.ty*D.cells)
    local mask,z,stacked,narrow=bits(D,X,Y)
    if not mask or stacked or not narrow then return false end
    return confirmOrigin(w,x,y,z,origin.map)
end
