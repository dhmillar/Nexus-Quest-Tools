-- Real observed Forever approach positions, Efficient Games, CC BY 4.0:
-- https://github.com/JIVESCORP/eg-link-output-wowf/tree/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf
-- Each pair was split across distinct 1.5.272 dry graph components.
local fixtures={
 [0]={
  {547.3,1593.1,518,1599.7},{1858.1,1601.8,1840,1625.8},
  {-51.5,-919.7,-21.4,-918.9},{516.1,1601.2,546.1,1603.9},
  {.4,-860.4,-24.1,-878},{-20,-910.4,-24.2,-880.5},
 },
 [1]={
  {-435.7,-2634.2,-409.3,-2648.8},{2307.3,-2553.3,2332.9,-2569.7},
  {-564.3,-4220.3,-592.7,-4232.2},{2339.6,-2563.8,2311.5,-2550.9},
 },
}
local AT={NQTDB={}}
local world,sx,sy
local function vec(x,y)return {GetXY=function()return x,y end}end
CreateVector2D=vec
local function mp(x,y)return {map=100+world,x=(x-sx)/42000+.5,y=(y-sy)/42000+.5}end
C_Map={
 GetWorldPosFromMapPos=function(m,p)local u,v=p:GetXY();return m-100,vec(sx+(u-.5)*42000,sy+(v-.5)*42000)end,
 GetMapPosFromWorldPos=function(w,p,id)local x,y=p:GetXY();local q=mp(x,y);return id,vec(q.x,q.y)end,
}
function GetBuildInfo()return "1.60.1","71139" end
function GetTime()return 10 end
function UnitPosition()return sx,sy,0,world end
local q={}
C_Timer={After=function(_,f)q[#q+1]=f end}
local function drain()
 local n=0 while #q>0 do n=n+1;assert(n<350);table.remove(q,1)()end
end
for _,s in ipairs({"NQTDBRouteWorld0","NQTDBRouteWorld1","NQTDBDryComponents","NQTDBWalking"})do
 assert(loadfile("NQT/"..s..".lua"))("NQT",AT)
end
for w=0,1 do
 world=w
 local hit=0
 for _,r in ipairs(fixtures[w]) do
  sx,sy=r[1],r[2]
  local from,to=mp(sx,sy),mp(r[3],r[4])
  local now=AT.GetBundledWalkingAPI(from)
  if now then
   local found
   now.WalkPath("real",from,to,function(route)found=route end);drain()
   if found then
    assert(found.yards>0 and #found.waypoints>1)
    hit=hit+1
   end
  end
 end
 assert(hit>0,"expected published cleared centerlines to reconnect at least one independently observed pair")
 print(("PASS %d previously disconnected observed dry route pairs on world %d"):format(hit,w))
end
