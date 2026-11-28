-- Synthetic reciprocal snake forces a deterministic number of visited cells.
local AT={NQTDB={RouteWorlds={}}}
local step=1600/3/67
local sx,sy,world,map=.5*step,.5*step,99,701
local function vec(x,y)return {GetXY=function()return x,y end}end
CreateVector2D=vec
function GetBuildInfo()return "1.60.1","71139" end
function GetTime()return 100 end
function UnitPosition()return sx,sy,0,world end
C_Map={
 GetWorldPosFromMapPos=function(m,p)local x,y=p:GetXY();assert(m==map);return world,vec(x*5000,y*5000)end,
 GetMapPosFromWorldPos=function(w,p,m)local x,y=p:GetXY();assert(w==world);return m,vec(x/5000,y/5000)end,
}
local queue={}
C_Timer={After=function(_,f)queue[#queue+1]=f end}
local function drain()
 local n=0
 while #queue>0 do n=n+1;assert(n<350,"per-frame work or callback loop regressed");table.remove(queue,1)()end
end
local function point(x,y)return {map=map,x=(x+.5)*step/5000,y=(y+.5)*step/5000}end
local function install(rows)
 local masks={}
 local function add(x,y,X,Y,a,b)
  local p,P=x*268+y,X*268+Y
  masks[p]=(masks[p] or 0)+a;masks[P]=(masks[P] or 0)+b
 end
 for row=0,rows-1 do
  local y=row*2
  for x=0,298 do add(x,y,x+1,y,1,2)end
  if row<rows-1 then
   local x=row%2==0 and 299 or 0
   add(x,y,x,y+1,4,8);add(x,y+1,x,y+2,4,8)
  end
 end
 add(350,0,351,0,1,2)  -- disconnected but walkable control
 local D={world=world,cells=67,nx=6,ny=4,tx=0,ty=0,tiles={}}
 for X=0,5 do for Y=0,3 do
  local bytes={}
  for x=0,66 do for y=0,66 do
   bytes[#bytes+1]=string.char(masks[(X*67+x)*268+Y*67+y] or 0,0,0)
  end end
  D.tiles[X*4+Y+1]=table.concat(bytes)
 end end
 AT.NQTDB.RouteWorlds[world]=D
 return point(rows%2==0 and 0 or 299,(rows-1)*2)
end
assert(loadfile("NQT/NQTDBWalking.lua"))("NQT",AT)
local start,goal=point(0,0),install(100)
local api=assert(AT.GetBundledWalkingAPI(start))
local walked,err
assert(api.WalkPath("long",start,goal,function(r,e)walked,err=r,e end));drain()
assert(walked and not err and math.abs(walked.yards-30098*step)<.02,"connected path past old 24,000-pop ceiling")
assert(#walked.waypoints<1000 and #walked.waypoints>200,"long straight spans merged without removing turns")
for i=2,#walked.waypoints do
 local a,b=walked.waypoints[i-1],walked.waypoints[i]
 assert(math.abs(a.x-b.x)<.000001 or math.abs(a.y-b.y)<.000001,"no diagonal through a serpentine wall")
end
assert(api.WalkPath("disconnected",start,point(350,0),function(r,e)assert(not r);err=e end));drain()
assert(err=="unreachable","an empty frontier is genuinely unreachable")
goal=install(130)
assert(api.WalkPath("budget",start,goal,function(r,e)assert(not r);err=e end));drain()
assert(err=="budget","do not report a capped connected path as unreachable")
assert(api.EstimateWalks("budget",start,{goal},function(r,e)assert(not r);err=e end));drain()
assert(err=="budget","do not rank an unfinished route as a known unreachable candidate")
print("PASS 30,099-cell snake, geometry-preserving compression, disconnected control, and truthful search-budget propagation")

-- Treat exact compiled connected-component labels as a proof of disjoint
-- dry terrain, without throwing away candidates when the index is absent.
local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function num(n,count)
 local s=""
 for _=1,count do
  local x=n%64;n=math.floor(n/64);s=alphabet:sub(x+1,x+1)..s
 end
 return s
end
local function span(n,id)return num(n,2)..num(id,3)end
local disconnectedTile=math.floor(350/67)*4+1
AT.NQTDB.DryComponents={[world]={
 [1]=span(1,1)..span(4095,0)..span(393,0),
 [disconnectedTile]=span(1005,0)..span(1,2)..span(3483,0),
}}
local unreach,reason=api.WalkPath("component disjoint",start,point(350,0),function()error("should be immediately disconnected")end)
assert(not unreach and reason=="unreachable" and #queue==0)
assert(api.WalkBestPath("component disjoint",start,{point(350,0)},function(r,e)assert(not r);err=e end))
assert(#queue==1);table.remove(queue,1)()
assert(err=="unreachable" and #queue==0,"multi-goal avoids expanding an impossible component")
print("PASS packaged component format makes provably disconnected pins fail without search")

-- A known reachable route is allowed a longer scan than unknown geometry.
AT.NQTDB.DryComponents[world][4]=span(57,0)..span(1,1)..span(4095,0)..span(336,0)
walked,err=nil,nil
assert(api.WalkPath("known long",start,goal,function(r,e)walked,err=r,e end));drain()
assert(walked and not err and math.abs(walked.yards-39128*step)<.05)
-- Simulate the client timing budget. One slice yields rather than consume
-- all the nominal expansion allowance when a frame is already expensive.
local checks=0
debugprofilestop=function()checks=checks+1;return checks*2 end
local delayed
local abort=api.WalkPath("slow frame",start,point(50,0),function(r)delayed=r end)
assert(abort and #queue==1)
table.remove(queue,1)()
assert(not delayed and #queue==1 and checks>=2)
abort();drain();debugprofilestop=nil
print("PASS known long connected route, time-budgeted slices and cancellable slow frames")

-- A pair of alternate approaches can surround the player with a very
-- large bounding box even though neither approach is close.
AT.NQTDB.DryComponents=nil
local D={world=world,cells=67,nx=2,ny=2,tx=0,ty=0,tiles={}}
local tile=string.rep(string.char(255,0,0),67*67)
for i=1,4 do D.tiles[i]=tile end
AT.NQTDB.RouteWorlds[world]=D
sx,sy=50.5*step,50.5*step
local start,near,far=point(50,50),point(10,10),point(111,111)
local result,count
assert(api.WalkBestPath("widely spaced",start,{far,near},function(r,e)assert(not e);result=r end))
count=0
while #queue>0 do count=count+1;assert(count<100);table.remove(queue,1)() end
assert(result and result.targetIndex==2,"closest actual approach wins, not first list entry")
assert(math.abs(result.yards-40*step*math.sqrt(2))<.01,"route cost still exact")
assert(count<=8,"small alternate-destination searches should not fill the whole goal box")
print(("PASS %.0f yd alternate approach in %d timer slices"):format(result.yards,count))
