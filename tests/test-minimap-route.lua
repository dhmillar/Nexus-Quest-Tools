local AT={db={enabled=true,showQuestRoute=true}}
local x,inside,t,active=.5,false,10,true
local frames={}
local function nothing() end
local function region()
    return {SetText=function(self,v) self.text=v end,SetPoint=nothing,ClearAllPoints=nothing,SetTextColor=nothing,
        SetThickness=nothing,SetColorTexture=nothing,SetStartPoint=nothing,SetEndPoint=nothing,
        Show=nothing,Hide=nothing}
end
function CreateFrame(_,_,parent)
    local f={parent=parent,shown=true,CreateTexture=region,CreateLine=region,SetAllPoints=nothing,
        SetSize=nothing,EnableMouse=nothing,SetFrameLevel=nothing,SetScript=nothing,ClearAllPoints=nothing}
    function f:SetPoint(a,b,c,dx,dy) self.anchor={a,b,c,dx,dy} end
    function f:CreateFontString() local l=region();self.label=l;return l end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false end
    frames[#frames+1]=f
    return f
end
Minimap={GetWidth=function()return 170 end,GetHeight=function()return 170 end,GetFrameLevel=function()return 1 end}
C_Map={GetBestMapForUnit=function()return 20 end,
    GetPlayerMapPosition=function()return {GetXY=function()return x,.5 end} end,
    GetMapWorldSize=function()return 1000,1000 end,
    GetMapInfo=function()return {mapType=3,name="Zone"} end}
function GetTime()return t end
function GetTaskInfo()return inside end
function AT.GetQuestNavigationID() if active then return 981,"test" end end
function AT.GetFocusedQuestRoutePoint()return 981,20,.75,.5 end
function AT.RenderWorldQuestRoute(state) AT.worldStatus=state end
assert(loadfile("NQT/Route.lua"))("NQT",AT)
AT.InitQuestRoute()
local meter,bearing
for _,f in ipairs(frames) do
    assert(not (f.parent==Minimap and f.anchor and f.anchor[1]=="TOP" and f.anchor[3]=="BOTTOM"),"never create the below-minimap panel")
    if f.label and f.label.text=="250 yd" then meter=f end
    if f.core then bearing=f end
end
assert(meter and meter.shown and bearing and bearing.shown,"keep yards and directional guidance")
x=.55;t=t+1;AT.RefreshQuestRoute()
assert(meter.label.text=="200 yd" and bearing.shown)
inside=true;t=t+1;AT.RefreshQuestRoute()
assert(not meter.shown and not bearing.shown and AT.worldStatus=="arrival","arrival still hides guidance")
inside=false;active=false;t=t+1;AT.RefreshQuestRoute()
assert(not meter.shown and not bearing.shown and AT.worldStatus=="no_quest")
print("PASS minimap quest panel removed; yard count, direction line, arrival and world-map callbacks preserved")
