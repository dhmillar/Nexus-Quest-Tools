
local _,AT=...
local floor,abs,sqrt,sin,cos=math.floor,math.abs,math.sqrt,math.sin,math.cos
local Q,M=C_QuestLog,C_Map
local world,mini,driver,coords
local worldButtons,miniButtons={},{}
local dirty=true
local miniZone,miniPoints
local ticker=.35
local service={ [1]="Innkeeper",[2]="Flight master",[3]="Mailbox",[4]="Observed quest giver" }
local symbols={
    start={"!",1,.77,.2}, objective={"•",.52,.86,1}, turnin={"?",1,.87,.37},
    [1]={"H",.65,1,.59},[2]={"F",.63,.85,1},[3]={"M",1,.79,.56},
    [4]={"!",.75,.75,.71}, [5]={"◆",.85,.7,1},
}
local worldTemplates={"QuestPinTemplate","QuestOfferPinTemplate","QuestBonusObjectivePinTemplate",
    "TaskPOIPinTemplate","WorldMap_WorldQuestPinTemplate"}
local poiByAtlas={
    ["poi-inn"]=1, ["innkeeper"]=1, ["poi-mailbox"]=3, ["mailbox"]=3,
    ["poi-meetingstone"]=5, ["meetingstone"]=5, ["poi-meeting-stone"]=5,
}
local function plain(v) return not issecretvalue or not issecretvalue(v) end
local function is(v,t) return plain(v) and type(v)==t end
local function num(x) return is(x,"number") and x==x and abs(x)<math.huge end
local function id(x) return num(x) and x>0 and floor(x)==x end
local function coord(x,y) return num(x) and num(y) and x>=0 and x<=1 and y>=0 and y<=1 and (x~=0 or y~=0) end
local function read(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b=pcall(fn,...)
    if ok then return plain(a) and a or nil,plain(b) and b or nil end
end
local function field(t,k)
    if is(t,"table") then local v=t[k];if plain(v) then return v end end
end
-- Explicit false matters for the game's quest-start/in-progress flags.
local function exact(fn,...)
    if type(fn)~="function" then return end
    local ok,a=pcall(fn,...);if ok and plain(a) then return a end
end
local function vec(v)
    if not is(v,"table") and not is(v,"userdata") then return end
    return read(v.GetXY,v)
end
local function questieLoaded()
    return read(C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded,"Questie")==true
        or Questie and Questie.IsForever==true and Questie.API and Questie.API.isReady==true
end
local function enabled()
    return AT.db and AT.db.enabled~=false and AT.db.showQuestMapPins~=false and not questieLoaded()
end
local function title(q)
    local label=read(Q and Q.GetTitleForQuestID,q)
    return is(label,"string") and label~="" and label or ("Quest #"..q)
end
local function defaultZone(q)
    return field(read(M and M.GetMapInfo,q),"mapType")==3
end

local function snapshot(map)
    local list,seen={},{}
    if not id(map) then return list end
    local fed={}
    local function add(kind,x,y,name,token,report)
        if not coord(x,y) or #list>=175 then return end
        local key=tostring(kind)..":"..(token or (floor(x*10000)..":"..floor(y*10000)))
        if seen[key] then return end
        seen[key]=true;list[#list+1]={kind=kind,x=x,y=y,title=name,quest=type(kind)=="string" and token or nil,report=report}
    end
    local quests=read(Q and Q.GetQuestsOnMap,map)
    if is(quests,"table") then
        for _,p in ipairs(quests) do
            local q=field(p,"questID")
            if id(q) then
                local x,y=field(p,"x"),field(p,"y")
                local held=exact(Q.IsOnQuest,q)
                if field(p,"isQuestStart")==true and held~=true and exact(Q.IsQuestFlaggedCompleted,q)~=true then
                    add("start",x,y,title(q),q)
                elseif held==true and field(p,"isQuestStart")==false then
                    local ready=exact(Q.ReadyForTurnIn,q)
                    if field(p,"inProgress")==true and ready~=true then
                        if coord(x,y) then fed[q]=true;add("objective",x,y,title(q),q) end
                    elseif field(p,"inProgress")==false and ready==true then
                        add("turnin",x,y,title(q),q)
                    end
                end
            end
        end
    end
    local entries=read(Q and Q.GetNumQuestLogEntries)
    if id(entries) then
        for i=1,math.min(entries,200) do
            local info=read(Q.GetInfo,i)
            local q=field(info,"questID")
            if id(q) and not fed[q] and field(info,"isHeader")==false and field(info,"isHidden")~=true
                and exact(Q.IsOnQuest,q)==true and exact(Q.ReadyForTurnIn,q)~=true then
                local x,y=read(Q.GetNextWaypointForMap,q,map)
                add("objective",x,y,title(q),q)
            end
        end
    end
    local taxiPoints={}
    local taxi=read(C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap,map)
    if is(taxi,"table") then
        for _,node in ipairs(taxi) do
            local x,y=vec(field(node,"position"))
            local label=field(node,"name")
            if coord(x,y) then
                taxiPoints[#taxiPoints+1]={x,y}
                add(2,x,y,is(label,"string") and label or service[2],field(node,"nodeID"))
            end
        end
    end
    local area=read(C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap,map)
    if is(area,"table") then
        for _,key in ipairs(area) do
            if id(key) then
                local p=read(C_AreaPoiInfo.GetAreaPOIInfo,map,key)
                local atlas=field(p,"atlasName")
                local kind=is(atlas,"string") and poiByAtlas[atlas:lower()]
                if kind then
                    local x,y=vec(field(p,"position"));local label=field(p,"name")
                    add(kind,x,y,is(label,"string") and label or service[kind] or "Meeting stone",key)
                end
            end
        end
    end
    local faction=read(UnitFactionGroup,"player")
    local side=faction=="Alliance" and 1 or faction=="Horde" and 2 or -1
    local pack=AT.ObservedTownPins
    for _,p in ipairs(pack and pack[map] or {}) do
        local kind,key,access,x,y=unpack(p)
        if (access==0 or access==side) and (kind~=4 or AT.db and AT.db.showObservedQuestGivers==true) then
            local nearby=false
            if kind==2 then
                for _,c in ipairs(taxiPoints) do
                    if abs(c[1]-x)<.015 and abs(c[2]-y)<.015 then nearby=true;break end
                end
            end
            if not nearby then
                add(kind,x,y,service[kind],key,"observed")
            end
        end
    end
    return list
end
AT.GetStandaloneMapPins=snapshot

local meanings={ start="Available quest", objective="Active objective", turnin="Ready to turn in",[5]="Meeting stone" }
local function hidePool(pool)
    for _,b in ipairs(pool) do b:Hide();b.atPin=nil end
end
local function makeButton(overlay,pool,i,mouse)
    local b=pool[i]
    if not b then
        b=CreateFrame("Frame",nil,overlay)
        b:SetSize(mouse and 18 or 14,mouse and 18 or 14)
        local base=b:CreateTexture(nil,"BACKGROUND");base:SetAllPoints();base:SetColorTexture(.1,.07,.05,.98)
        local rim=b:CreateTexture(nil,"ARTWORK")
        rim:SetPoint("TOPLEFT",b,"TOPLEFT",1,-1);rim:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",-1,1)
        b.rim=rim
        local center=b:CreateTexture(nil,"ARTWORK",nil,1)
        center:SetPoint("TOPLEFT",b,"TOPLEFT",2,-2);center:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",-2,2)
        center:SetColorTexture(.10,.083,.067,.98)
        b.glyph=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        b.glyph:SetPoint("CENTER",b,"CENTER",0,0)
        b:EnableMouse(mouse)
        if mouse then
            b:SetScript("OnEnter",function(self)
                local p=self.atPin
                if not p or not GameTooltip then return end
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(p.title)
                GameTooltip:AddLine((meanings[p.kind] or service[p.kind]) or "",.87,.79,.64)
                GameTooltip:AddLine(("%.1f, %.1f"):format(p.x*100,p.y*100),.82,.85,.9)
                if p.report then
                    GameTooltip:AddLine(p.kind==4 and "Previously observed here. Availability not verified." or "Approximate interaction location; access may vary.",.82,.85,.9,true)
                    GameTooltip:AddLine("Data from Efficient Games (https://efficient.games), CC BY 4.0.",.7,.8,.9,true)
                end
                GameTooltip:Show()
            end)
            local function dismiss(self)
                if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
            end
            b:SetScript("OnLeave",dismiss); b:SetScript("OnHide",dismiss)
        end
        pool[i]=b
    end
    return b
end
local function put(overlay,pool,i,p,anchor,dx,dy,mouse)
    local b=makeButton(overlay,pool,i,mouse)
    local s=symbols[p.kind]
    b.atPin=p
    b.glyph:SetText(s[1]);b.glyph:SetTextColor(s[2],s[3],s[4])
    b.rim:SetColorTexture(s[2]*.68,s[3]*.68,s[4]*.68,.95)
    b:ClearAllPoints();b:SetPoint("CENTER",overlay,anchor,dx,dy);b:Show()
end
local function mapCoordinates(map)
    local view=map and map.ScrollContainer
    if not view or exact(view.IsMouseOver,view)~=true then if coords then coords:Hide() end;return end
    local x,y=read(view.GetNormalizedCursorPosition,view)
    if not coord(x,y) then if coords then coords:Hide() end;return end
    if not coords then
        coords=CreateFrame("Frame",nil,view)
        coords:SetSize(112,19);coords:EnableMouse(false)
        coords:SetPoint("BOTTOM",view,"BOTTOM",0,5)
        coords:SetFrameLevel(view:GetFrameLevel()+35)
        local b=coords:CreateTexture(nil,"BACKGROUND");b:SetAllPoints();b:SetColorTexture(.08,.056,.036,.88)
        coords.label=coords:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        coords.label:SetPoint("CENTER")
    end
    coords.label:SetText(("Cursor: %.1f, %.1f"):format(x*100,y*100))
    coords:Show()
end
local function worldMapTick()
    local map=WorldMapFrame
    if not (enabled() and map and exact(map.IsVisible,map)==true) then
        if world then world:Hide() end
        if coords then coords:Hide() end
        return
    end
    local mapID=read(map.GetMapID,map)
    local canvas=read(map.GetCanvas,map)
    local w,h=canvas and read(canvas.GetWidth,canvas),canvas and read(canvas.GetHeight,canvas)
    local stitch=OpenMapAPI
    if not (id(mapID) and canvas and num(w) and num(h) and w>0 and h>0)
        or stitch and exact(stitch.IsStitched)==true then
        if world then world:Hide() end
        if coords then coords:Hide() end
        return
    end
    mapCoordinates(map)
    if world and not dirty and world.mapID==mapID and world.canvas==canvas and world.w==w and world.h==h and world:IsShown() then return end
    if not world then world=CreateFrame("Frame",nil,canvas);world:EnableMouse(false) end
    world:SetParent(canvas);world:ClearAllPoints();world:SetAllPoints(canvas)
    world:SetFrameLevel(canvas:GetFrameLevel()+17)
    world.mapID,world.canvas,world.w,world.h=mapID,canvas,w,h
    hidePool(worldButtons)
    local native={}
    if type(map.EnumeratePinsByTemplate)=="function" then
        pcall(function()
            for _,template in ipairs(worldTemplates) do
                local iter,state,first=map:EnumeratePinsByTemplate(template)
                if type(iter)=="function" then
                    for pin in iter,state,first do
                        local q=pin and (read(pin.GetQuestID,pin) or pin.questID)
                        if id(q) and exact(pin.IsShown,pin)==true then native[q]=true end
                    end
                end
            end
        end)
    end
    local n=0
    for _,p in ipairs(snapshot(mapID)) do
        if not p.quest or not native[p.quest] then
            n=n+1;put(world,worldButtons,n,p,"TOPLEFT",p.x*w,-p.y*h,true)
        end
    end
    world:Show()
end
local function miniMapTick()
    local m=Minimap
    if not (enabled() and m and exact(m.IsVisible,m)==true and not exact(IsInInstance)) then
        if mini then mini:Hide() end;miniPoints=nil;return
    end
    local map=read(M and M.GetBestMapForUnit,"player")
    local pos=id(map) and defaultZone(map) and read(M.GetPlayerMapPosition,map,"player")
    local x,y=vec(pos)
    local mw,mh=read(M and M.GetMapWorldSize,map)
    local range=read(C_Minimap and C_Minimap.GetViewRadius)
    local w,h=read(m.GetWidth,m),read(m.GetHeight,m)
    if not (coord(x,y) and num(mw) and num(mh) and mw>0 and mh>0 and num(range) and range>0
        and num(w) and num(h) and w>=42 and h>=42) then if mini then mini:Hide() end;return end
    local facing=0
    local rotating=exact(C_CVar and C_CVar.GetCVarBool or GetCVarBool,"rotateMinimap")
    if rotating==true and exact(C_Minimap and C_Minimap.IsRotateMinimapIgnored)~=true then
        facing=read(GetPlayerFacing)
        if not num(facing) then if mini then mini:Hide() end;return end
    end
    if dirty or miniZone~=map or not miniPoints then miniZone,miniPoints=map,snapshot(map) end
    if not mini then mini=CreateFrame("Frame",nil,m);mini:EnableMouse(false);mini:SetAllPoints(m);mini:SetFrameLevel(m:GetFrameLevel()+6) end
    hidePool(miniButtons)
    local n,scale=0,math.min(w,h)*.47/range
    local sine,cosine=sin(facing),cos(facing)
    for _,p in ipairs(miniPoints) do
        local east,north=(p.x-x)*mw,(y-p.y)*mh
        local d=sqrt(east*east+north*north)
        if d<range*.90 then
            n=n+1
            put(mini,miniButtons,n,p,"CENTER",(east*cosine+north*sine)*scale,(-east*sine+north*cosine)*scale,false)
            if n>=20 then break end
        end
    end
    if n>0 then mini:Show() else mini:Hide() end
end

function AT.RefreshQuestMapPins()
    dirty=true
end
function AT.InitQuestMapPins()
    if driver or not CreateFrame then return end
    driver=CreateFrame("Frame")
    for _,e in ipairs({"PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","QUEST_LOG_UPDATE","QUEST_ACCEPTED","QUEST_TURNED_IN","QUEST_REMOVED","ADDON_LOADED","TAXIMAP_OPENED"}) do
        pcall(driver.RegisterEvent,driver,e)
    end
    driver:SetScript("OnEvent",AT.RefreshQuestMapPins)
    local elapsed=0
    driver:SetScript("OnUpdate",function(_,t)
        elapsed=elapsed+t
        if elapsed<ticker then return end
        elapsed=0
        worldMapTick();miniMapTick();dirty=false
    end)
end
