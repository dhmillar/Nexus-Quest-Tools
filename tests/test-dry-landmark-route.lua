-- Public observed Forever coordinates, Efficient Games CC BY 4.0.
-- https://github.com/JIVESCORP/eg-link-output-wowf/tree/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf
local AT={NQTDB={}}
local x,y=2203.7,1188
local gx,gy=-829.8,-559.3
local function vec(a,b)return {GetXY=function()return a,b end}end
CreateVector2D=vec
C_Map={
 GetWorldPosFromMapPos=function(_,p)local a,b=p:GetXY();return 0,vec(x+(a-.5)*50000,y+(b-.5)*50000)end,
 GetMapPosFromWorldPos=function(_,p,m)local a,b=p:GetXY();return m,vec((a-x)/50000+.5,(b-y)/50000+.5)end
}
function UnitPosition()return x,y,0,0 end
function GetBuildInfo()return "1.60.1","71139" end
local q={}
C_Timer={After=function(_,f) q[#q+1]=f end}
for _,f in ipairs({"NQTDBRouteWorld0","NQTDBDryComponents","NQTDBDryLandmarks","NQTDBWalking"}) do
 assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
local samples=AT.NQTDB.DryLandmarks
local from={map=100,x=.5,y=.5}
local goal={map=100,x=(gx-x)/50000+.5,y=(gy-y)/50000+.5}
local api=assert(AT.GetBundledWalkingAPI(from))
local function run(atlas)
 AT.NQTDB.DryLandmarks=atlas
 local got
 local n=0
 assert(api.WalkPath("real fixture",from,goal,function(x,e)assert(not e);got=x end))
 while #q>0 do n=n+1;assert(n<650);table.remove(q,1)() end
 assert(got and got.yards>4900 and #got.waypoints>=2)
 return got,n
end
local baseline,before=run(nil)
local result,after=run(samples)
assert(math.abs(baseline.yards-result.yards)<.01,"lower bound must not change the optimal path cost")
assert(after<before*.8,"representative long route should process at least 20% fewer timer slices")
print(("PASS %.0f yd real terrain route; unchanged optimal cost, %d → %d timer slices"):format(result.yards,before,after))
