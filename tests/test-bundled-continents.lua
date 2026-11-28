local AT={}
local world,mid,spawnX,spawnY,spawnZ
local function vec(x,y) return {GetXY=function()return x,y end} end
local function point(x,y)
    return {map=world+100,x=(x-spawnX)/10000+.5,y=(y-spawnY)/10000+.5}
end
CreateVector2D=vec
C_Map={
 GetWorldPosFromMapPos=function(map,p)
    local x,y=p:GetXY();return map-100,vec(spawnX+(x-.5)*10000,spawnY+(y-.5)*10000)
 end,
 GetMapPosFromWorldPos=function(w,p,id)
    assert(w==world)
    local x,y=p:GetXY();local a=point(x,y);return id,vec(a.x,a.y)
 end
}
function UnitPosition() return spawnX,spawnY,spawnZ,world end
function GetBuildInfo()return "1.60.1","71139" end
function GetTime()return 100 end
local q={}
C_Timer={After=function(_,f)q[#q+1]=f end}
local function drain()
 local n=0
 while #q>0 do n=n+1;assert(n<400,"per-route frame limit");table.remove(q,1)() end
end
for _,name in ipairs({"NQTDB","NQTDBRouteWorld0","NQTDBRouteWorld1","NQTDBWalking"}) do
 assert(loadfile("NQT/"..name..".lua"))("NQT",AT)
end
local D=AT.NQTDB.RouteWorlds
local step=1600/3/67
local digits={};local b64="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
for i=1,#b64 do digits[b64:byte(i)]=i-1 end
-- Test independently reads NQT's documented packed data to select exact
-- fixture cells from real continent terrain rather than a synthetic mesh.
local function unpackTile(tile)
 local mask,z={},{}
 local idx,h,i=0,0,1
 while i<=#tile do
  local a,b,c=digits[tile:byte(i)],digits[tile:byte(i+1)],digits[tile:byte(i+2)]
  i=i+3
  if a==0 then idx=idx+b*64+c
  else
   if c==63 then
    local v=digits[tile:byte(i)]*4096+digits[tile:byte(i+1)]*64+digits[tile:byte(i+2)];i=i+3
    h=v%2==0 and v/2 or -(v+1)/2
   else h=h+c-31 end
   idx=idx+1;mask[idx]=(a-1)*64+b;z[idx]=h
  end
 end
 assert(idx==4489)
 return mask,z
end
for w=0,1 do
 world=w
 local d=D[w]
 local from,to
 for k=1,d.nx*d.ny do
    local tile=d.tiles[k]
    if tile and d.tiles[k+d.ny] then
      local m,z=unpackTile(tile)
      local right=unpackTile(d.tiles[k+d.ny])
      for j=1,67 do
       local a=m[66*67+j]
       if a and a%2==1 and right[j] and math.floor(right[j]/2)%2==1 then
          spawnX=(d.tx+math.floor((k-1)/d.ny))*1600/3+66.5*step
          spawnY=(d.ty+(k-1)%d.ny)*1600/3+(j-.5)*step
          spawnZ=z[66*67+j]
          from,to=point(spawnX,spawnY),point(spawnX+step,spawnY)
          break
       end
      end
    end
    if from then break end
 end
 assert(from and to)
 local api=assert(AT.GetBundledWalkingAPI(from),"terrain seam should resolve by continent")
 local cost,route
 assert(api.EstimateWalks("continent",from,{to,{map=101-w,x=.5,y=.5}},function(r)cost=r end));drain()
 assert(cost and math.abs(cost[1]-step)<.01 and cost[2]==false,"cross-world route rejected")
 assert(api.WalkPath("continent",from,to,function(r)route=r end));drain()
 assert(route and #route.waypoints==2 and math.abs(route.yards-step)<.01,"reciprocal seam path required")
 spawnZ=spawnZ+120
 assert(not AT.GetBundledWalkingAPI(from),"wrong height rejected")
 print("PASS real terrain seam and world isolation",w)
end

-- Deterministic 131-cell corridor forces multiple projection frames.
world=31
local function corridor(first,last)
 local rows={}
 for x=0,66 do
  for y=0,66 do
   local mask=0
   if y==5 then mask=(x==66 and last or 1)+(x==0 and first or 2) end
   rows[#rows+1]=string.char(mask,0,0)
  end
 end
 return table.concat(rows)
end
D[world]={world=world,cells=67,nx=2,ny=1,tx=0,ty=0,tiles={corridor(0,1),corridor(2,0)}}
spawnX,spawnY,spawnZ=.5*step,5.5*step,0
local start,goal=point(spawnX,spawnY),point(spawnX+130*step,spawnY)
local project,projectionCalls=C_Map.GetMapPosFromWorldPos,0
C_Map.GetMapPosFromWorldPos=function(...)
 projectionCalls=projectionCalls+1
 return project(...)
end
local api=assert(AT.GetBundledWalkingAPI(start))
local cancel=assert(api.WalkPath("project",start,goal,function()error("cancelled projection delivered")end))
table.remove(q,1)()
assert(projectionCalls==48 and #q==1,"48 projection calls maximum on first frame")
cancel();drain();assert(projectionCalls==48)
local route
assert(api.WalkPath("project",start,goal,function(r)route=r end));drain()
assert(route and #route.waypoints==131 and math.abs(route.yards-step*130)<.02)
assert(projectionCalls==179)
print("PASS 131-cell route projects in bounded frames and cancels cleanly mid-projection")

-- A cross-zone route may need the common continent map where the two zone
-- projections do not overlap. A stale returned coordinate must not be drawn.
local maps={[201]={world,0,440},[202]={world,680,1200},[203]={world,0,1200},[204]={world+1,0,1200}}
local brokenParent
C_Map.GetMapInfo=function(m)
 if m==201 or m==202 then return {parentMapID=brokenParent and 204 or 203} end
end
local function fromWorld(id,x,y)
 local r=maps[id]
 return {map=id,x=(x-r[2])/(r[3]-r[2]),y=y/1000}
end
C_Map.GetWorldPosFromMapPos=function(m,p)
 local r=maps[m];if not r then return end
 local x,y=p:GetXY()
 return r[1],vec(r[2]+x*(r[3]-r[2]),y*1000)
end
C_Map.GetMapPosFromWorldPos=function(w,p,hint)
 local x,y=p:GetXY();local m=maps[hint]
 if w~=m[1] then return hint,vec(.51,.5) end
 local v=fromWorld(hint,x,y)
 if v.x<0 or v.x>1 then return hint,vec(.5,.5) end -- misleading cached projection
 return hint,vec(v.x,v.y)
end
start,goal=fromWorld(201,spawnX,spawnY),fromWorld(202,spawnX+130*step,spawnY)
route=nil
assert(api.WalkPath("crosszone",start,goal,function(r)route=r end));drain()
assert(route and #route.waypoints==131 and route.waypoints[1].map==201)
local foundParent
for i,p in ipairs(route.waypoints) do
 local w,v=C_Map.GetWorldPosFromMapPos(p.map,vec(p.x,p.y));local x,y=v:GetXY()
 assert(w==world and math.abs(x-spawnX-(i-1)*step)<.01 and math.abs(y-spawnY)<.01)
 if p.map==203 then foundParent=true end
end
assert(foundParent,"fill gap using same-world parent instead of truncating path")
brokenParent=true
local err
assert(api.WalkPath("wrong parent",start,goal,function(r,e)assert(not r);err=e end));drain()
assert(err=="projection","do not draw routes via a mismatched parent world")
print("PASS cross-zone projections preserve every waypoint; bad world and stale cached projection rejected")
