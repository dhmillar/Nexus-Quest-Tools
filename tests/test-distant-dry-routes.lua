-- Same-world, publicly observed Forever coordinates, Efficient Games CC BY 4.0.
-- https://github.com/JIVESCORP/eg-link-output-wowf/tree/c1bf99bc2835bbe1b2dad82fb99f994c0cfffe33/data/wowf
local AT={NQTDB={}}
local w,x,y
local function vec(a,b)return {GetXY=function()return a,b end}end
CreateVector2D=vec
C_Map={
 GetWorldPosFromMapPos=function(_,p)local a,b=p:GetXY();return w,vec(x+(a-.5)*50000,y+(b-.5)*50000)end,
 GetMapPosFromWorldPos=function(_,p,m)local a,b=p:GetXY();return m,vec((a-x)/50000+.5,(b-y)/50000+.5)end
}
function UnitPosition()return x,y,0,w end
function GetBuildInfo()return "1.60.1","71139" end
local q={}
C_Timer={After=function(_,f) q[#q+1]=f end}
for _,f in ipairs({"NQTDBRouteWorld0","NQTDBRouteWorld1","NQTDBDryComponents","NQTDBDryLandmarks","NQTDBWalking"})do
 assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
local function check(world,sx,sy,gx,gy,expected)
 w,x,y=world,sx,sy
 local start={map=100+w,x=.5,y=.5}
 local goal={map=100+w,x=(gx-x)/50000+.5,y=(gy-y)/50000+.5}
 local api=assert(AT.GetBundledWalkingAPI(start))
 local result
 assert(api.WalkPath("known distant dry route",start,goal,function(path,why)
   assert(not why,why);result=path
 end))
 local n=0
 while #q>0 do n=n+1;assert(n<760,"extended exact search must remain bounded");table.remove(q,1)()end
 assert(result and math.abs(result.yards-expected)<1 and #result.waypoints>150)
 print(("PASS %.0f yd bounded exact walking path in %d timer slices on world %d"):format(result.yards,n,w))
end
check(0,-8869.4,-161.5,-10455.1,-3281.9,8079.5)
check(1,-1731.7,3184.7,-897.7,-3765.6,11317.5)
