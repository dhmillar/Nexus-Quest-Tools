local AT={}
local turnIn=false
AT.IsQuestTurnInNavigation=function() return turnIn end
local function nop() end
local function makeLayer(level)
    return {GetWidth=function()return 100 end,GetHeight=function()return 100 end,
        GetFrameLevel=function()return level end,IsVisible=function(self)return not self.hidden end}
end
local stock,terrain=makeLayer(2),makeLayer(12)
local overlays={}; local writes=0
CreateFrame=function(_,_,parent)
    local overlay={parent=parent,SetAllPoints=nop,EnableMouse=nop,
        SetFrameLevel=function(self,level)self.level=level end,parts={}}
    function overlay:CreateFontString()
        return {SetShadowOffset=nop,SetText=function(_,value) self.legendText=value end,SetTextColor=nop,SetPoint=nop,ClearAllPoints=nop,Show=nop,Hide=nop}
    end
    function overlay:CreateLine(_,layer)
        local line={SetThickness=function(self,n)writes=writes+1;self.thickness=n end,SetColorTexture=function(self,...)writes=writes+1;self.color={...}end,
            SetStartPoint=function(self,_,_,x,y)writes=writes+1;self.x=x;self.y=y end,
            SetEndPoint=function(self,_,_,x,y)writes=writes+1;self.endX=x;self.endY=y end,
            Show=function(self)writes=writes+1;self.shown=true end,Hide=function(self)writes=writes+1;self.shown=false end}
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
-- An independently visible MapWise canvas can render while the native frame is hidden.
WorldMapFrame.IsVisible=function()return false end
AT.RenderWorldQuestRoute("routed",20,route)
assert(overlay.shown and overlay.parts[1].shown,"visible MapWise must not depend on native frame visibility")
-- Bearings aimed outside the viewport continue as one solid segment to its edge.
AT.GetQuestTurnInPoint=function()return 121,.2,.35 end
C_Map.GetPlayerMapPosition=function()return CreateVector2D(.2,.2) end
AT.RenderWorldQuestRoute("planning",20,nil)
assert(overlay.shown and overlay.parts[1].shown and not overlay.parts[2].shown)
assert(math.abs(overlay.parts[1].endX-50)<.00001 and overlay.parts[1].color[2]==.66)
assert(overlay.legendText=="ESTIMATED DIRECTION  |  NOT A WALKING ROUTE")
AT.RenderWorldQuestRoute("no_quest",nil,nil)
assert(not overlay.shown)
print("PASS MapWise shares full NQT route, clips on the visible terrain, reprojects when switching map mode, and matches yellow/green stock colors")

-- Test the actual stock viewport as well, including offsets used for panning.
MapWiseAPI.UI.frame.hidden=true
WorldMapFrame.IsVisible=function()return true end
WorldMapFrame.ScrollContainer={GetRect=function()return 30,20,20,60 end,GetEffectiveScale=function()return 1 end}
stock.GetEffectiveScale=function()return 2 end
stock.GetRect=function()return 0,0,100,100 end
C_Map.GetMapPosFromWorldPos=function(_,vec,map)return map,vec end
route.path.waypoints={{map=120,x=.05,y=.7},{map=120,x=.2,y=.7},{map=120,x=.5,y=.7}}
route.fraction=0
AT.RenderWorldQuestRoute("routed",20,route)
local layer=overlays[stock]
assert(layer.shown and #layer.parts==2)
assert(math.abs(layer.parts[1].x-15)<.00001 and math.abs(layer.parts[2].endX-25)<.00001)
assert(layer.parts[1].thickness==.825,"retain readable screen-pixel line weight during stock zoom")
local previous=writes
AT.RenderWorldQuestRoute("routed",20,route)
assert(writes==previous,"unchanged view does not re-anchor or repaint native route lines")
route.fraction=.8
AT.RenderWorldQuestRoute("routed",20,route)
assert(writes-previous==2 and math.abs(layer.parts[1].x-17)<.00001,"route progress moves only its first glow and line anchor")
print("PASS native zoom/pan clipping, line weight, and redraw work bounded to changed native properties")
