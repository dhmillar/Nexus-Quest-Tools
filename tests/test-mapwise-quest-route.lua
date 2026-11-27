local AT={}
local turnIn=false
AT.IsQuestTurnInNavigation=function() return turnIn end
local function nop() end
local function makeLayer(level)
    return {GetWidth=function()return 100 end,GetHeight=function()return 100 end,
        GetFrameLevel=function()return level end,IsVisible=function(self)return not self.hidden end}
end
local stock,terrain=makeLayer(2),makeLayer(12)
local overlays={}
CreateFrame=function(_,_,parent)
    local overlay={parent=parent,SetAllPoints=nop,EnableMouse=nop,
        SetFrameLevel=function(self,level)self.level=level end,parts={}}
    function overlay:CreateFontString()
        return {SetShadowOffset=nop,SetText=nop,SetTextColor=nop,SetPoint=nop,ClearAllPoints=nop,Show=nop,Hide=nop}
    end
    function overlay:CreateLine(_,layer)
        local line={SetThickness=nop,SetColorTexture=function(self,...)self.color={...}end,
            SetStartPoint=function(self,_,_,x,y)self.x=x;self.y=y end,
            SetEndPoint=function(self,_,_,x,y)self.endX=x;self.endY=y end,
            Show=function(self)self.shown=true end,Hide=function(self)self.shown=false end}
        if layer=="OVERLAY" then self.parts[#self.parts+1]=line end
        return line
    end
    function overlay:Hide() self.shown=false end
    function overlay:Show() self.shown=true end
    overlays[parent]=overlay
    return overlay
end
WorldMapFrame={IsVisible=function()return true end,GetMapID=function()return 120 end,GetCanvas=function()return stock end}
CreateVector2D=function(x,y)
    return {GetXY=function()return x,y end}
end
C_Map={
    GetBestMapForUnit=function()return 120 end,
    GetMapInfo=function()return {mapType=3}end,
    GetWorldPosFromMapPos=function(map,p)
        local x,y=p:GetXY();return 0,CreateVector2D(x+(map==121 and .5 or 0),y)
    end
}
local mapWiseDB={map="riverglades",mode="terrain"}
local state={canvas=stock,view=terrain,container={},active=true}
local viewRight=1
state.Viewport=function()return {-.2,0,viewRight,1},2 end
MapWiseAPI={Map=state,UI={frame=makeLayer(5)},Integration={native=WorldMapFrame},db=mapWiseDB,RouteUI={}}
local projectCount=0
MapWiseAPI.RouteUI.Projection=function(_,p)
    assert(p.c==0)
    projectCount=projectCount+1
    return p.x-(mapWiseDB.mode=="paper" and .1 or 0),p.y+.1
end
assert(loadfile("NQT/WorldRoute.lua"))("NQT",AT)
local route={quest=20, path={waypoints={{map=120,x=.1,y=.15},{map=120,x=.4,y=.15},{map=121,x=.2,y=.35}}},
    segment=1,fraction=.5,selected={map=121,x=.2,y=.35}}
AT.RenderWorldQuestRoute("routed",20,route)
local overlay=assert(overlays[terrain])
assert(overlay.shown and not overlays[stock] and overlay.level>12 and projectCount>=3)
assert(#overlay.parts==2 and math.abs(overlay.parts[1].x-25)<.00001)
assert(math.abs(overlay.parts[2].endX-70)<.00001 and math.abs(overlay.parts[2].endY+45)<.00001)
assert(overlay.parts[1].color[1]==1 and overlay.parts[1].color[2]==.85,"in-progress is yellow")
turnIn=true
AT.RenderWorldQuestRoute("routed",20,route)
assert(overlay.parts[1].color[2]==1 and overlay.parts[1].color[1]==.32,"ready turn-in is green")
mapWiseDB.mode="paper"
viewRight=.5
AT.RenderWorldQuestRoute("routed",20,route)
assert(math.abs(overlay.parts[1].x-15)<.00001,"display-mode changes invalidate projection cache")
assert(math.abs(overlay.parts[2].endX-50)<.00001,"continue to edge of visible area, not beyond it")
MapWiseAPI.UI.frame.hidden=true
AT.RenderWorldQuestRoute("routed",20,route)
assert(not overlay.shown and overlays[stock].shown and overlays[stock].parts[1].color[2]==1)
MapWiseAPI.UI.frame.hidden=false
AT.RenderWorldQuestRoute("routed",20,route)
assert(overlays[terrain]==overlay and not overlays[stock].shown and overlay.shown,"switching surfaces reuses the inert overlay")
AT.RenderWorldQuestRoute("no_quest",nil,nil)
assert(not overlay.shown)
print("PASS MapWise shares full NQT route, clips on the visible terrain, reprojects when switching map mode, and matches yellow/green stock colors")
