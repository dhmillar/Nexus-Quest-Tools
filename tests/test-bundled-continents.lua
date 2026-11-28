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
