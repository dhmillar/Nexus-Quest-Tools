local _, AT = ...
local overlay, canvas, pin, legend, lines
local projectedPath, projectedMap, points
local stitch,viewBounds,mapWise,mapWiseKey
local surfaces={}

local function clean(v)
    return not issecretvalue or not issecretvalue(v)
end
local function finite(v)
    return clean(v) and type(v)=="number" and v==v and math.abs(v)<math.huge
end
local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b,c=pcall(fn,...)
    if ok then return a,b,c end
end
-- MapWise replaces the world-map projection with its own terrain/paper
-- canvas. Reuse its exposed projection; do not change its current journey.
local function mapWiseSurface(map)
    local api=MapWiseAPI
    if not clean(api) or type(api)~="table" then return end
    local m=api.Map
    local r=api.RouteUI
    local db=api.db
    local ui=api.UI and api.UI.frame
    if not (m and m.view and m.canvas and m.container and r and type(r.Projection)=="function"
        and db and ui and call(ui.IsVisible,ui) and call(m.view.IsVisible,m.view)
        and (not api.Integration or not api.Integration.native or api.Integration.native==map)
        and not (api.Instances and api.Instances.active)) then return end
    return api,m,r,db
end
local function fraction(x,y)
    return finite(x) and finite(y) and x>=0 and x<=1 and y>=0 and y<=1 and (x~=0 or y~=0)
end
local function mapKind(id)
    local info=C_Map.GetMapInfo and C_Map.GetMapInfo(id)
    if clean(info) and type(info)=="table" and finite(info.mapType) then return info.mapType,info.parentMapID end
end
local function outdoor(id)
    local kind=mapKind(id)
    return kind==(Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3)
end
local function project(src,x,y,dst,allowSibling)
    if not finite(src) or not finite(x) or not finite(y) then return end
    if src==dst and not stitch and not mapWise then return x,y end
    if not (CreateVector2D and C_Map.GetWorldPosFromMapPos) then return end
    if mapWise then
        local world,vec=call(C_Map.GetWorldPosFromMapPos,src,CreateVector2D(x,y))
        if not finite(world) or not clean(vec) or not vec then return end
        local wx,wy=call(vec.GetXY,vec)
        if not finite(wx) or not finite(wy) then return end
        local a,b=call(mapWise.Projection,mapWise,{c=world,x=wx,y=wy})
        if finite(a) and finite(b) then return a,b end
        return
    end
    if stitch then
        local world,vec=C_Map.GetWorldPosFromMapPos(src,CreateVector2D(x,y))
        if not finite(world) or not clean(vec) or not vec then return end
        local wx,wy=vec:GetXY()
        if not finite(wx) or not finite(wy) then return end
        local a,b=stitch.CanvasFromWorldPos(world,wx,wy)
        if finite(a) and finite(b) then return a,b end
        return
    end
    if not C_Map.GetMapPosFromWorldPos then return end
    local srcKind,parent=mapKind(src)
    local dstKind=mapKind(dst)
    if srcKind~=3 or not (dstKind==1 or dstKind==2 or allowSibling and dstKind==3) then return end
    if dstKind~=3 then
        for _=1,8 do
            if parent==dst then break end
            if not finite(parent) or parent<1 then return end
            local _,ancestor=mapKind(parent)
            parent=ancestor
        end
        if parent~=dst then return end
    end
    local world, vec=C_Map.GetWorldPosFromMapPos(src,CreateVector2D(x,y))
    if not finite(world) or not clean(vec) or not vec then return end
    local id,dstVec=C_Map.GetMapPosFromWorldPos(world,vec,dst)
    if not finite(id) or id~=dst or not clean(dstVec) or not dstVec then return end
    local a,b=dstVec:GetXY()
    if finite(a) and finite(b) then return a,b end
end

-- Clip across visible map bounds without connecting missing or unsupported segments.
local function clip(ax,ay,bx,by)
    local lo,hi,dx,dy=0,1,bx-ax,by-ay
    local function edge(p,q)
        if p==0 then return q>=0 end
        local t=q/p
        if p<0 then lo=math.max(lo,t) else hi=math.min(hi,t) end
        return lo<hi
    end
    if edge(-dx,ax-viewBounds[1]) and edge(dx,viewBounds[2]-ax)
        and edge(-dy,ay-viewBounds[3]) and edge(dy,viewBounds[4]-ay) then
        return ax+dx*lo,ay+dy*lo,ax+dx*hi,ay+dy*hi
    end
end
local function line(i,w,h,ax,ay,bx,by,isRoute,turnIn,artScale)
    local x,y,u,v=clip(ax,ay,bx,by)
    if not x or (math.abs(x-u)+math.abs(y-v))<.00001 then return false end
    local region=lines[i]
    if not region then
        local glow=overlay:CreateLine(nil,"ARTWORK")
        region=overlay:CreateLine(nil,"OVERLAY")
        region.autoTrackGlow=glow
        lines[i]=region
    end
    region:SetThickness(1.65/artScale)
    local glow=region.autoTrackGlow; glow:SetThickness(4/artScale)
    if isRoute then
        if turnIn then
            region:SetColorTexture(.32,1,.22,1)
            glow:SetColorTexture(.22,.85,.14,.29)
        else
            region:SetColorTexture(1,.85,.13,1)
            glow:SetColorTexture(1,.64,.08,.34)
        end
    else
        region:SetColorTexture(1,.66,.29,1)
        glow:SetColorTexture(1,.47,.12,.28)
    end
    glow:SetStartPoint("TOPLEFT",canvas,x*w,-y*h)
    glow:SetEndPoint("TOPLEFT",canvas,u*w,-v*h)
    glow:Show()
    region:SetStartPoint("TOPLEFT",canvas,x*w,-y*h)
    region:SetEndPoint("TOPLEFT",canvas,u*w,-v*h)
    region:Show()
    return true
end
local function setup(parent)
    if parent==canvas then return end
    if overlay then overlay:Hide() end
    canvas=parent
    local saved=surfaces[parent]
    if saved then overlay,lines,pin,legend=unpack(saved);return end
    overlay=CreateFrame("Frame",nil,canvas)
    lines={}
    overlay:SetAllPoints(canvas)
    overlay:EnableMouse(false)
    overlay:SetFrameLevel(canvas:GetFrameLevel()+15)
    pin=overlay:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    pin:SetShadowOffset(1,-1)
    pin:SetText("+")
    legend=overlay:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    legend:SetPoint("TOP",canvas,"TOP",0,-15)
    legend:SetShadowOffset(1,-1)
    surfaces[parent]={overlay,lines,pin,legend}
    overlay:Hide()
end

local function inView(x,y)
    return finite(x) and finite(y) and x>=viewBounds[1] and x<=viewBounds[2]
        and y>=viewBounds[3] and y<=viewBounds[4]
end

local function objective(quest,id)
    if AT.IsQuestTurnInNavigation and AT.IsQuestTurnInNavigation(quest) then
        local m,x,y,provenance=call(AT.GetQuestTurnInPoint,quest,id)
        if finite(m) and fraction(x,y) then
            local px,py=project(m,x,y,id,false)
            if finite(px) and finite(py) and (stitch or mapWise or fraction(px,py)) then return px,py,m,provenance end
        end
        return
    end
    -- Prefer the displayed map's native quest marker to stale coordinates
    -- when the user has opened the destination map from another zone.
    local q=C_QuestLog
    if not stitch and not mapWise and q and q.GetNextWaypointForMap then
        local x,y=call(q.GetNextWaypointForMap,quest,id)
        if fraction(x,y) then return x,y,id end
    end
    if not stitch and not mapWise and AT.GetNativeQuestRoutePointForMap then
        local x,y=AT.GetNativeQuestRoutePointForMap(quest,id)
        if fraction(x,y) then return x,y,id end
    end
    if AT.GetQuestRouteDisplayPoint or AT.GetFocusedQuestRoutePoint then
        local qid,m,x,y
        if AT.GetQuestRouteDisplayPoint then qid=quest; m,x,y=AT.GetQuestRouteDisplayPoint(quest)
        else qid,m,x,y=AT.GetFocusedQuestRoutePoint() end
        if finite(qid) and qid==quest and fraction(x,y) then
            x,y=project(m,x,y,id,false)
            if finite(x) and finite(y) and (stitch or mapWise or fraction(x,y)) then return x,y,m end
        end
    end
    if q and q.GetQuestsOnMap then
        local rows=call(q.GetQuestsOnMap,id)
        if clean(rows) and type(rows)=="table" then
            for _,p in ipairs(rows) do
                if clean(p) and type(p)=="table" and finite(p.questID) and p.questID==quest
                    and fraction(p.x,p.y) then
                    local x,y=project(id,p.x,p.y,id,false)
                    if finite(x) and finite(y) then return x,y,id end
                end
            end
        end
    end
end

function AT.HideWorldQuestRoute()
    if overlay then overlay:Hide() end
end

function AT.RenderWorldQuestRoute(status,quest,snapshot)
    local map=WorldMapFrame
    if not (CreateFrame and C_Map and finite(quest) and quest>0)
        or status=="arrival" or status=="disabled" or status=="no_quest" then
        AT.HideWorldQuestRoute()
        return
    end
    local mw,m,r,db=mapWiseSurface(map)
    local nativeVisible=map and call(map.IsVisible,map)
    if not mw and not nativeVisible then AT.HideWorldQuestRoute(); return end
    local id=map and call(map.GetMapID,map)
    if not finite(id) and m then id=call(C_Map.GetBestMapForUnit,"player") end
    local parent=m and m.view or (map and call(map.GetCanvas,map))
    if not finite(id) or not parent then AT.HideWorldQuestRoute(); return end
    local sizeHost=m and m.canvas or parent
    local w,h=sizeHost:GetWidth(),sizeHost:GetHeight()
    if not finite(w) or not finite(h) or w<1 or h<1 then AT.HideWorldQuestRoute(); return end
    setup(parent)
    local nextKey=m and (tostring(parent)..":"..tostring(db.map)..":"..tostring(db.mode)..":"..tostring(m.active)
        ..":"..tostring(mw.PaperAtlas and mw.PaperAtlas.state)..":"..tostring(mw.Seamless and mw.Seamless.state))
    if mapWise~=r or mapWiseKey~=nextKey then
        mapWise,mapWiseKey=r,nextKey
        projectedPath,projectedMap,points=nil,nil,nil
    end
    local api=not mapWise and OpenMapAPI
    local nextStitch=type(api)=="table" and api.major==1 and finite(api.version) and api.version>=2
        and type(api.IsStitched)=="function" and type(api.CanvasFromWorldPos)=="function" and api.IsStitched() and api or nil
    if stitch~=nextStitch then
        stitch=nextStitch
        projectedPath,projectedMap,points=nil,nil,nil
    end
    viewBounds={0,1,0,1}
    local port=map and map.ScrollContainer
    local level=canvas:GetFrameLevel()+15
    local artScale=1
    if m then
        local rect,scale=call(m.Viewport,m)
        local l,t,right,b
        if type(rect)=="table" then l,t,right,b=unpack(rect) end
        if finite(l) and finite(t) and finite(right) and finite(b) and right>l and b>t then
            viewBounds={l,right,t,b}
            if finite(scale) and scale>0 then artScale=math.max(1,scale) end
        end
    elseif stitch then
        local art=stitch.ArtTopLevel and stitch.ArtTopLevel()
        if finite(art) then level=math.max(level,art+2) end
        if port and port.GetRect and port.GetEffectiveScale and canvas.GetRect and canvas.GetEffectiveScale then
            local l,b,pw,ph=port:GetRect()
            local cl,cb,_,ch=canvas:GetRect()
            local ps,cs=port:GetEffectiveScale(),canvas:GetEffectiveScale()
            if finite(l) and finite(b) and finite(pw) and finite(ph) and pw>0 and ph>0
                and finite(cl) and finite(cb) and finite(ch) and finite(ps) and finite(cs) and cs>0 then
                local left,right=(l*ps-cl*cs)/(w*cs),((l+pw)*ps-cl*cs)/(w*cs)
                local top,bottom=((cb+ch)*cs-(b+ph)*ps)/(h*cs),((cb+ch)*cs-b*ps)/(h*cs)
                viewBounds={left,right,top,bottom}
            end
        end
    end
    if overlay.questRouteLevel~=level then
        overlay:SetFrameLevel(level)
        overlay.questRouteLevel=level
    end
    legend:ClearAllPoints()
    legend:SetPoint("TOP",canvas,"TOPLEFT",w*(viewBounds[1]+viewBounds[2])/2,-h*viewBounds[3]-15)
    local used,x,y,text=0
    local turnIn=AT.IsQuestTurnInNavigation and AT.IsQuestTurnInNavigation(quest)
    if snapshot and snapshot.quest==quest and (status=="routed" or status=="road") then
        local path=snapshot.path
        if path~=projectedPath or id~=projectedMap then
            projectedPath,projectedMap,points=path,id,{}
        end
        local function at(i)
            local p=points[i]
            if p==nil then
                local pt=path.waypoints[i]
                local u,v=project(pt.map,pt.x,pt.y,id,true)
                p=u and {u,v} or false
                if p or not mapWise then points[i]=p end
            end
            if p then return p[1],p[2] end
        end
        local first,last=snapshot.segment,#path.waypoints
        local a,b=at(first)
        for i=first,last-1 do
            local u,v=at(i+1)
            if a and u then
                local startX,startY=a,b
                if i==first then
                    startX=a+(u-a)*snapshot.fraction
                    startY=b+(v-b)*snapshot.fraction
                end
                if line(used+1,w,h,startX,startY,u,v,true,turnIn,artScale) then used=used+1 end
            end
            a,b=u,v
        end
        if used>0 then
            text=(status=="road" and "ROAD-AWARE WALK" or "WALKING ROUTE")
            if turnIn then
                local _,_,_,provenance=call(AT.GetQuestRouteDisplayPoint,quest)
                if provenance=="recorded NPC location" then text=text.."  |  RECORDED NPC" end
            end
            if snapshot.selected then
                local p=snapshot.selected
                x,y=project(p.map,p.x,p.y,id,false)
            else
                x,y=at(last)
            end
            if not inView(x,y) then x,y=nil,nil end
        end
    else
        projectedPath,projectedMap,points=nil,nil,nil
    end
    if used==0 and snapshot and snapshot.quest==quest and snapshot.bearing then
        local from,dst=snapshot.from,snapshot.target
        local ax,ay=project(from.map,from.x,from.y,id,true)
        local bx,by=project(dst.map,dst.x,dst.y,id,true)
        if ax and bx and line(1,w,h,ax,ay,bx,by,false,turnIn,artScale) then
            used,x,y,text=1,bx,by,"DIRECT BEARING ONLY  |  NO WALKING PATH"
        end
    end
    if used==0 then
        local source,provenance
        x,y,source,provenance=objective(quest,id)
        if x then
            text=(turnIn and (provenance=="recorded NPC location" and "RECORDED TURN-IN NPC" or "TURN-IN LOCATION") or "QUEST OBJECTIVE") .. "  |  NO WALKING LINE ON THIS MAP"
            local player=call(C_Map.GetBestMapForUnit,"player")
            local comparable=player==source
            -- A cross-zone turn-in may be visible on a shared parent map.
            -- Require both zones to actually project on that map.
            if not comparable and turnIn and finite(player) and outdoor(player) and outdoor(source) then
                local root=call(C_Map.GetMapInfo,id)
                local kinds=Enum and Enum.UIMapType
                comparable=mapWise~=nil or root and (root.mapType==(kinds and kinds.Continent or 2))
            end
            if status~="interior" and finite(player) and comparable and outdoor(player)
                and not (IsIndoors and IsIndoors()) and C_Map.GetPlayerMapPosition then
                local p=C_Map.GetPlayerMapPosition(player,"player")
                if clean(p) and p then
                    local px,py=p:GetXY()
                    if fraction(px,py) then px,py=project(player,px,py,id,false) else px,py=nil,nil end
                    if finite(px) and finite(py) then
                        if line(1,w,h,px,py,x,y,false,turnIn,artScale) then
                            used=1
                            text=provenance=="recorded NPC location" and "DIRECTION TO RECORDED NPC  |  NOT A WALKING ROUTE" or "ESTIMATED DIRECTION  |  NOT A WALKING ROUTE"
                        end
                    end
                end
            end
        end
    end
    for i=used+1,#lines do lines[i]:Hide(); lines[i].autoTrackGlow:Hide() end
    if inView(x,y) then
        pin:ClearAllPoints()
        pin:SetPoint("CENTER",canvas,"TOPLEFT",x*w,-y*h)
        if turnIn then pin:SetTextColor(.32,1,.22) else pin:SetTextColor(1,.85,.13) end
        pin:Show()
    else pin:Hide() end
    if text then
        legend:SetText(text)
        if text:find("DIRECT BEARING",1,true) or text:find("NOT A WALKING ROUTE",1,true) then
            legend:SetTextColor(1,.66,.29)
        elseif turnIn then legend:SetTextColor(.42,1,.38) else legend:SetTextColor(1,.85,.30) end
        overlay:Show()
    else
        overlay:Hide()
    end
end
