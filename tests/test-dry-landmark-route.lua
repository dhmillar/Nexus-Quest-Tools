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
local originalByte=string.byte
local function run(atlas)
 AT.NQTDB.DryLandmarks=atlas
 local got
 local n,reads=0,0
 string.byte=function(s,i,j)
   if i and j==i+2 then reads=reads+1 end
   return originalByte(s,i,j)
 end
 assert(api.WalkPath("real fixture",from,goal,function(x,e)assert(not e);got=x end))
 while #q>0 do n=n+1;assert(n<650);table.remove(q,1)() end
 assert(got and got.yards>4900 and #got.waypoints>=2)
 string.byte=originalByte
 return got,n,reads
end
local baseline,before=run(nil)
local result,after,reads=run(samples)
assert(math.abs(baseline.yards-result.yards)<.01,"lower bound must not change the optimal path cost")
assert(after<before*.9,"landmarks should still reduce work with a unique-entry frontier")
assert(after<=130,"packed fine-grained bounds must beat the old 205-slice schedule")
print(("PASS %.0f yd real terrain route; unchanged optimal cost, %d → %d timer slices"):format(result.yards,before,after))

assert(reads<56000,"tighter landmark intervals should avoid revisiting the broad terrain fringe")
print(("PASS %d terrain reads in the fixed 4983 yd route (was 288859)"):format(reads))


-- Nearby-looking alternatives can be separated by a real terrain detour.
-- Keep the best objective and exact cost without searching the collapsed
-- interval between two destinations. Coordinates below are mesh probes.
local function multi(otherX,otherY,expected,cost,ceiling)
 local target={map=100,x=(otherX-x)/50000+.5,y=(otherY-y)/50000+.5}
 local got
 assert(api.WalkBestPath("paired terrain probes",from,{goal,target},function(p,e)assert(not e);got=p end))
 local n=0
 while #q>0 do n=n+1;assert(n<500);table.remove(q,1)()end
 assert(got and got.targetIndex==expected and math.abs(got.yards-cost)<.01,"independent bounds changed the winning route")
 assert(n<=ceiling,"intervals of alternative destinations were collapsed")
 return n
end
local n1=multi(-436,-843,1,4983.159,125)
local n2=multi(1838,2166,2,1565.622,38)
print(("PASS exact real-terrain multi-goal routes with separate landmark intervals: 259 to %d and 51 to %d timer slices"):format(n1,n2))
