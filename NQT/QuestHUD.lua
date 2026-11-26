local _, AT = ...
local Q,M=C_QuestLog,C_Map
local hud, refreshPending, currentZone, currentDungeon, viewedZone, model
local ALL_ZONES,ALL_DUNGEONS={},{}
local popupOpen,completedView,toolbarOpen=false,false,false
local preferredCompleted,resolveStatusOnSelection=false,false
local selectedDungeon,dungeonOpen
local searchWords,searchOpen={},false
local itemSearchQuestID,settingItemSearch,itemSearchCollapsed
local observedObjectives, highlights={},{}
local partyRetained,partyTurnedIn={},{}
local removedQuests={}
local inlineParty=false
local questTooltip,tooltipTicker,hover,addDropTooltip
local themes={
    { name="Map", map=true, accent={.95,.76,.40}, ink={.90,.83,.64}, row={.20,.13,.067,.40},
      rail={.13,.085,.045,.92}, font="GameFontNormalLarge" },
    { name="Minimal", accent={1,.82,0}, ink={.95,.95,.95}, row={0,0,0,0},
      rail={0,0,0,.62}, font="GameFontNormal", questie=true },
}
function AT.NormalizeQuestHUDTheme(db)
    -- In the old six-theme palette, 2 meant Astral and only 6 was Questie.
    -- Remember migration so a user's new Map/Questie choice survives reload.
    if db.questHUDThemeSchema~=2 then
        local old=db.questHUDTheme
        db.questHUDTheme=(type(old)~="number" or old==6) and 2 or 1
        db.questHUDThemeSchema=2
    elseif db.questHUDTheme~=1 and db.questHUDTheme~=2 then
        db.questHUDTheme=2
    end
end
local function ordinary(v) return not issecretvalue or not issecretvalue(v) end
local function is(v,t) return ordinary(v) and type(v)==t end
local function id(v) return is(v,"number") and v>0 and v<math.huge and v%1==0 end
local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b,c,d,e=pcall(fn,...); if ok then return a,b,c,d,e end
end
local function field(row,k)
    if is(row,"table") and ordinary(row[k]) then return row[k] end
end
local function zone(map)
    for _=1,8 do
        if not id(map) then return end
        local info=call(M and M.GetMapInfo,map)
        if field(info,"mapType")==3 then return map,field(info,"name") end
        local parent=field(info,"parentMapID")
        if not id(parent) or parent==map then return end
        map=parent
    end
end
local function playerZone()
    return zone(call(M and M.GetBestMapForUnit,"player"))
end
local function mapName(map)
    return field(call(M and M.GetMapInfo,map),"name")
end
local function module(name)
    if Questie and Questie.IsForever and Questie.API and Questie.API.isReady and QuestieLoader then
        return call(QuestieLoader.ImportModule,QuestieLoader,name)
    end
end
local function questieOrigin(qid,db,zones)
    if not (db and zones) then return end
    local quest=call(db.GetQuest,qid)
    local starts=field(quest,"Starts")
    if not is(starts,"table") then return end
    local unique, ambiguous, unresolved
    local function visit(units,get)
        if not is(units,"table") then return end
        for _,key in pairs(units) do
            if id(key) then
                local data=call(get,db,key)
                local spawns=field(data,"spawns") or field(data,"Spawns")
                local found
                if is(spawns,"table") then
                    for area,positions in pairs(spawns) do
                        if id(area) and is(positions,"table") and next(positions) then
                            local z=zone(call(zones.GetUiMapIdByAreaId,zones,area))
                            if z then
                                found=true
                                if not unique then unique=z elseif unique~=z then ambiguous=true end
                            end
                        end
                    end
                end
                if not found then unresolved=true end
            end
        end
    end
    visit(field(starts,"NPC"),db.GetNPC)
    visit(field(starts,"GameObject"),db.GetObject)
    if is(field(starts,"Item"),"table") and next(starts.Item) then unresolved=true end
    if not ambiguous and not unresolved then return unique end
end
local function nearbyPOIs(zoneID)
    local ids={}
    if not zoneID then return ids end
    local source=call(Q and Q.GetQuestsOnMap,zoneID)
    if is(source,"table") then
        for _,p in ipairs(source) do
            local qid,x,y=field(p,"questID"),field(p,"x"),field(p,"y")
            if id(qid) and is(x,"number") and is(y,"number") and x>=0 and x<=1 and y>=0 and y<=1
                and (x~=0 or y~=0) then ids[qid]=true end
        end
    end
    return ids
end
local dungeonIndex={}
local function nativeDungeon(map)
    local resolved,name
    local mapTypes=Enum and Enum.UIMapType
    local dungeonType=mapTypes and mapTypes.Dungeon or 4
    for _=1,9 do
        if not id(map) then break end
        local info=call(M and M.GetMapInfo,map)
        if field(info,"mapType")==dungeonType then
            local label=field(info,"name")
            if is(label,"string") and label~="" then resolved,name=map,label end
        elseif resolved then break end
        local parent=field(info,"parentMapID")
        if not id(parent) or parent==map then break end
        map=parent
    end
    return resolved,name
end
local function playerDungeon(rawMap)
    local inside,kind=call(IsInInstance)
    if ordinary(kind) and kind~=nil and kind~="party" then return end
    if ordinary(inside) and inside==false then return end
    local root,name=nativeDungeon(rawMap)
    if kind=="party" then
        local ok,label,_,_,_,_,_,_,instanceID
        if type(GetInstanceInfo)=="function" then
            ok,label,_,_,_,_,_,_,instanceID=pcall(GetInstanceInfo)
        end
        if ok then
            local official=call(AT.ForeverDungeonName,instanceID,label)
            if official then return root,official,true end
            if not name and is(label,"string") and label~="" then name=label end
        end
        return root,call(AT.ForeverDungeonName,nil,name) or name,true
    end
    if root then return root,name,true end
end
local function nativeDungeonIndex()
    local map=call(M and M.GetBestMapForUnit,"player")
    local root
    for _=1,9 do
        if not id(map) then break end
        root=map
        local parent=field(call(M and M.GetMapInfo,map),"parentMapID")
        if not id(parent) or parent==map then break end
        map=parent
    end
    if not root then return {} end
    if dungeonIndex[root] then return dungeonIndex[root] end
    local names,raidNames={},{}
    local mapTypes=Enum and Enum.UIMapType
    local children=call(M and M.GetMapChildrenInfo,root,mapTypes and mapTypes.Dungeon or 4,true)
    if is(children,"table") then
        for i=1,math.min(1500,#children) do
            local item=children[i]
            local name,uiMapID=field(item,"name"),field(item,"mapID")
            local canonical,preferred=nativeDungeon(uiMapID)
            if canonical and is(name,"string") then
                local previous=names[name]
                if previous and previous.map~=canonical then names[name]=false
                elseif previous==nil then names[name]={map=canonical,name=preferred} end
            end
        end
    end
    -- An optional Encounter Journal (where available) identifies exact raid
    -- names without trying to infer raid status from size or difficulty.
    if type(EJ_GetInstanceByIndex)=="function" then
        for i=1,180 do
            local raidID,raidName=call(EJ_GetInstanceByIndex,i,true)
            if not id(raidID) then break end
            if is(raidName,"string") then raidNames[raidName]=true end
        end
    end
    for label,loc in pairs(names) do
        if loc and (raidNames[label] or raidNames[loc.name]) then names[label]=false end
    end
    if next(names) then dungeonIndex[root]=names end
    return names
end
local function dungeonFor(row,index,db,zones,poiName,currentName)
    local tag=field(call(Q.GetQuestTagInfo,row.id),"tagID")
    local tags=Enum and Enum.QuestTag
    if tags and (tag~=nil and (tag==tags.Raid or tag==tags.Raid10 or tag==tags.Raid25 or tag==tags.HeroicRaid)) then return end
    local verified=call(AT.ForeverDungeonForQuest,row.id)
    if verified then return verified end
    local function canonical(n) return call(AT.ForeverDungeonName,nil,n) or n end
    local name
    if zones then
        local quest=db and call(db.GetQuest,row.id)
        local area=field(quest,"zoneOrSort")
        local function localDungeon(candidate)
            if id(candidate) and call(zones.IsDungeonZone,candidate)==true then
                local n=call(zones.GetLocalizedDungeonName,zones,candidate)
                if is(n,"string") and n~="" then return n end
            end
        end
        if is(row.header,"string") then
            local header=call(zones.GetAreaIdByName,zones,row.header)
            name=localDungeon(header)
        end
        if not name then name=localDungeon(area) end
    end
    local known=is(row.header,"string") and index[row.header]
    if known then return canonical(known.name) end
    if currentName and canonical(row.header)==currentName and known~=false then return currentName end
    if is(row.header,"string") and index[row.header]==false and name==row.header then name=nil end
    local _,destination=nativeDungeon(row.targetMap)
    if destination and index[destination]~=false then return canonical(destination) end
    if name and index[name]~=false then return canonical(name) end
    -- A quest on the current native dungeon map is exact point evidence;
    -- do not turn a generic dungeon tag into a fabricated dungeon name.
    if poiName and index[poiName]~=false then return poiName end
    -- New instances can be absent from the native Dungeon UI-map index.
    -- An exact, known quest-log header still identifies the instance.
    if known~=false then return call(AT.ForeverDungeonName,nil,row.header) end
end

local logCache,logDirty
local function visibleQuestLog()
    local all,headers={},{}
    local shown,total=call(Q.GetNumQuestLogEntries)
    if not is(shown,"number") or shown<0 then return all,headers,nil,false end
    local header
    for i=1,math.min(shown,500) do
        local info=call(Q.GetInfo,i)
        if field(info,"isHeader")==true then
            header=field(info,"title")
            if field(info,"isCollapsed")==true then
                headers[#headers+1]=field(info,"questLogIndex") or i
            end
        else
            local qid=field(info,"questID")
            if id(qid) and field(info,"isHidden")~=true then
                all[qid]={info=info,header=header,index=i}
            end
        end
    end
    return all,headers,(is(total,"number") and total>=0 and total<math.huge and total%1==0 and total or nil),true
end

local function allQuestLog()
    local visible,headers,total,ready=visibleQuestLog()
    if not ready then return logCache and logCache.rows or visible,logCache and logCache.total end
    local found=0
    for _ in pairs(visible) do found=found+1 end
    if #headers==0 then
        local full=not total or found>=total
        logCache={rows=visible,total=total,full=full,attempted=full};logDirty=nil
        return visible,total
    end
    local missing=not total or found<total
    local scan=missing and (not logCache or not logCache.attempted or logDirty or logCache.total~=total)
        and type(ExpandQuestHeader)=="function" and type(CollapseQuestHeader)=="function"
        and not (InCombatLockdown and InCombatLockdown())
    if scan then
        local native=QuestMapFrame
        local prior=native and native.ignoreQuestLogUpdate
        local opened={}
        -- Match Blizzard's own quest-log search: suppress redraw while
        -- inspecting collapsed sections, and restore in the same call.
        if native then native.ignoreQuestLogUpdate=true end
        local ok,rows,remaining=pcall(function()
            for i=#headers,1,-1 do
                local index=headers[i]
                if pcall(ExpandQuestHeader,index) then opened[index]=true end
            end
            return visibleQuestLog()
        end)
        local restored=pcall(function()
            -- Re-collapse ascending: earlier expansions have already been
            -- restored, so each original displayed index is exact again.
            for _,index in ipairs(headers) do
                if opened[index] then CollapseQuestHeader(index) end
            end
        end)
        if native then native.ignoreQuestLogUpdate=prior end
        if ok and restored and is(rows,"table") then
            local full=is(remaining,"table") and #remaining==0
            logCache={rows=rows,total=total,full=full,attempted=true}
            logDirty=nil
        end
    end
    if logCache then
        for qid,item in pairs(logCache.rows) do
            if not visible[qid] and call(Q.IsOnQuest,qid)~=false then visible[qid]=item end
        end
    end
    return visible,total
end

local namedZoneCache={}
local function nativeZoneNames()
    local root,map
    map=call(M and M.GetBestMapForUnit,"player")
    for _=1,9 do
        if not id(map) then break end
        root=map
        local parent=field(call(M.GetMapInfo,map),"parentMapID")
        if not id(parent) or parent==map then break end
        map=parent
    end
    if not root then return {} end
    if namedZoneCache[root] then return namedZoneCache[root] end
    local names={}
    local maps=Enum and Enum.UIMapType
    local rows=call(M.GetMapChildrenInfo,root,maps and maps.Zone or 3,true)
    if is(rows,"table") then
        for i=1,math.min(#rows,1600) do
            local n,k=field(rows[i],"name"),field(rows[i],"mapID")
            if is(n,"string") and id(k) then
                if names[n]==nil then names[n]=k elseif names[n]~=k then names[n]=false end
            end
        end
    end
    if next(names) then namedZoneCache[root]=names end
    return names
end

local starterMemo={}
local function build(zoneID,zoneName)
    local result={zones={},rows={},dungeons={},current=zoneID,total=0}
    if not Q then return result end
    local zonesByName,associated={},{}
    local party=call(AT.IsQuestPartyProgressActive)==true
    if not party then
        if next(partyRetained) and AT.ClearRankQuestPartyProgress then AT.ClearRankQuestPartyProgress() end
        partyRetained,partyTurnedIn={},{}
    end
    for key,value in pairs(nativeZoneNames()) do zonesByName[key]=value end
    local poi=nearbyPOIs(zoneID)
    local db,zones=module("QuestieDB"),module("ZoneDB")
    local nameIndex=nativeDungeonIndex()
    local rawMap=call(M and M.GetBestMapForUnit,"player")
    local instanceMap,instanceName,insideDungeon=playerDungeon(rawMap)
    local insidePOI=instanceMap and nearbyPOIs(instanceMap) or {}
    if instanceMap and id(rawMap) and rawMap~=instanceMap then
        for qid,point in pairs(nearbyPOIs(rawMap)) do insidePOI[qid]=point end
    end
    local origins=AT.char and AT.char.zoneQuestOrigins
    if not is(origins,"table") then origins={} end
    local function group(z,name)
        local existing=result.zones[z]
        if not existing then
            existing={key=z,name=name or mapName(z) or "Zone",rows={}}
            result.zones[z]=existing
        end
        return existing
    end
    if zoneID then group(zoneID,zoneName); if zoneName then zonesByName[zoneName]=zoneID end end
    local function associate(z,name,row,kind)
        if not z then return end
        associated[row.id]=true
        local bucket=group(z,name)
        local existing=bucket.rows[row.id]
        if not existing then
            bucket.rows[row.id]={row=row,kind=kind}
        elseif kind=="origin" or (kind=="recorded" and existing.kind=="category") then
            existing.kind=kind
        end
    end
    local ownLog,nativeTotal=allQuestLog()
    for qid,source in pairs(ownLog) do
        local entry,header,i=source.info,source.header,source.index
        local title=field(entry,"title") or call(Q.GetTitleForQuestID,qid)
        if id(qid) and not removedQuests[qid] then
            if not is(title,"string") or title=="" then title="Quest #"..qid end
                local row={id=qid,title=title,header=header,
                    complete=call(AT.IsQuestReadyForTurnIn or Q.ReadyForTurnIn,qid), order=call(AT.GetQuestOrderPosition,qid), logIndex=i,
                    level=field(entry,"level")}
                row.complete=ordinary(row.complete) and row.complete==true
                if party then
                    row.party=call(AT.GetQuestPartySnapshot,qid)
                    row.partyPending=row.party and row.party.pending or false
                end
                if not id(row.level) then row.level=call(Q.GetQuestDifficultyLevel,qid) end
                local suggested=field(entry,"suggestedGroup")
                if not id(suggested) or suggested<=1 then suggested=call(Q.GetSuggestedGroupSize,qid) end
                if id(suggested) and suggested>1 then
                    row.group=true; row.groupSize=suggested
                else
                    local tags=Enum and Enum.QuestTag
                    local info=tags and tags.Group~=nil and call(Q.GetQuestTagInfo,qid)
                    row.group=info and field(info,"tagID")==tags.Group or false
                end
                local target=call(Q.GetNextWaypoint,qid)
                row.destination=zone(target)
                row.targetMap=target
                local instance=dungeonFor(row,nameIndex,db,zones,insidePOI[qid] and instanceName or nil,instanceName)
                if instance then
                    local bucket=result.dungeons[instance]
                    if not bucket then bucket={key=instance,name=instance,rows={}};result.dungeons[instance]=bucket end
                    bucket.rows[qid]={row=row,kind="dungeon"}
                end
                local accepted=origins[qid]
                local origin=starterMemo[qid]
                if origin==nil and db and zones then
                    origin=questieOrigin(qid,db,zones)
                    starterMemo[qid]=origin or false
                end
                if id(origin) then row.origin=origin
                elseif id(accepted) then row.origin=accepted; row.recorded=true end
                result.rows[qid]=row
                result.total=result.total+1
                if row.origin then associate(row.origin,nil,row,row.recorded and "recorded" or "origin") end
                if row.destination then associate(row.destination,nil,row,"destination") end
                if zoneID and poi[qid] then associate(zoneID,zoneName,row,"destination") end
        end
    end
    -- The native total accounts for quests under collapsed log headers.
    -- Fall back to unique player-owned rows if the API omits the total.
    result.total=math.max(result.total,nativeTotal or 0)
    for key,bucket in pairs(result.zones) do
        if is(bucket.name,"string") and bucket.name~="Zone" then
            local previous=zonesByName[bucket.name]
            if previous==nil then zonesByName[bucket.name]=key
            elseif previous~=key then zonesByName[bucket.name]=false end
        end
    end
    for _,row in pairs(result.rows) do
        -- Exact, unambiguous native zone section is membership evidence, not proof of start NPC.
        if is(row.header,"string") and zonesByName[row.header] then
            associate(zonesByName[row.header],row.header,row,"category")
        end
        if not associated[row.id] then associate("at-other","Other quests",row,"unassigned") end
    end
    if party then
        local nextRetention,keep={},{}
        for qid,row in pairs(result.rows) do
            keep[qid]=true
            if row.partyPending then
                local memberships={}
                for key,bucket in pairs(result.zones) do
                    if bucket.rows[qid] then memberships[key]={name=bucket.name,kind=bucket.rows[qid].kind} end
                end
                local instance
                for name,bucket in pairs(result.dungeons) do if bucket.rows[qid] then instance=name; break end end
                nextRetention[qid]={row=row,memberships=memberships,instance=instance}
            end
        end
        for qid,held in pairs(partyRetained) do
            if not result.rows[qid] and partyTurnedIn[qid] and (removedQuests[qid] or call(Q.IsOnQuest,qid)==false) then
                local status=call(AT.GetQuestPartySnapshot,qid)
                if status and status.pending then
                    local row={}
                    for k,v in pairs(held.row) do row[k]=v end
                    row.partyOnly=true;row.partyPending=true;row.party=status;row.order=nil
                    row.turnedIn=partyTurnedIn[qid]==true
                    result.rows[qid]=row
                    for key,membership in pairs(held.memberships) do associate(key,membership.name,row,membership.kind) end
                    if held.instance then
                        local name=held.instance
                        local bucket=result.dungeons[name]
                        if not bucket then bucket={key=name,name=name,rows={}};result.dungeons[name]=bucket end
                        bucket.rows[qid]={row=row,kind="dungeon"}
                    end
                    keep[qid]=true
                    nextRetention[qid]=held
                end
            end
        end
        partyRetained=nextRetention
        for qid in pairs(partyTurnedIn) do if not keep[qid] then partyTurnedIn[qid]=nil end end
        if AT.TrimRankQuestPartyProgress then AT.TrimRankQuestPartyProgress(keep) end
    end
    if insideDungeon then
        result.currentDungeon=(instanceName and result.dungeons[instanceName]) or {name=instanceName or "Dungeon",rows={}}
    end
    return result
end
AT.BuildQuestHUDModel=build

local function progressChanged(qid)
    local current=Q and call(Q.GetQuestObjectives,qid)
    if not is(current,"table") then return false end
    local before=observedObjectives[qid]
    local after,changed={},false
    for index=1,math.min(#current,24) do
        local o=current[index]
        local description=field(o,"text")
        local count=field(o,"numFulfilled")
        local required=field(o,"numRequired")
        local finished=field(o,"finished")
        if is(description,"string") or is(count,"number") or is(finished,"boolean") then
            after[index]={description=description,count=count,required=required,finished=finished}
            local old=before and before[index]
            if old then
                if finished==true and old.finished==false then changed=true
                elseif is(count,"number") and is(old.count,"number") and count~=old.count then changed=true
                elseif not (is(count,"number") and is(old.count,"number")) and is(description,"string")
                    and is(old.description,"string") and description~=old.description then changed=true end
            end
        end
    end
    -- Don't reset a known baseline just because objectives are loading.
    if next(after) then observedObjectives[qid]=after end
    return changed
end

local function refreshHighlights(inspectProgress)
    if not model then return false end
    local zone=model.current
    local ids,previous,progress={},{},{}
    -- Zone assignment describes where the quest was picked up or grouped,
    -- not necessarily where the player can work on its current objective.
    for qid,row in pairs(model.rows) do
        if not row.complete and not row.partyOnly and call(AT.IsQuestExcluded,qid)~=true then
            ids[qid]=true
        end
    end
    for qid,state in pairs(highlights) do
        ids[qid]=true; previous[qid]=state.area
    end
    if inspectProgress then
        for qid,row in pairs(model.rows) do
            if not row.partyOnly and not row.complete and call(AT.IsQuestExcluded,qid)~=true and progressChanged(qid) then
                ids[qid]=true; progress[qid]=true
            end
        end
        for qid in pairs(observedObjectives) do
            if not model.rows[qid] or model.rows[qid].complete then observedObjectives[qid]=nil end
        end
    end
    local areas=call(AT.SampleQuestAreas,ids,previous) or {}
    local changed=false
    for qid in pairs(ids) do
        local row=model.rows[qid]
        local old=highlights[qid]
        local area=areas[qid]
        local watch=old and old.progress
        local missed
        if not row or row.complete or row.partyOnly or call(AT.IsQuestExcluded,qid)==true then
            area,watch=nil,nil
        elseif area=="inside" or area=="near" then
            if progress[qid] then watch=zone or true end
        elseif area=="outside" then
            area,watch=nil,nil
        elseif area=="possible_exit" and old and old.zone==zone and not old.missed then
            missed=true
            area=old.area
        elseif area=="possible_exit" then
            area,watch=nil,nil
        else
            -- Location can disappear briefly. Keep established state in the
            -- same zone, but do not label an unverified update “in area.”
            if old and old.zone==zone then area=old.area end
            if progress[qid] then watch=zone or true end
            if watch and watch~=(zone or true) then watch=nil end
        end
        if area or watch then highlights[qid]={area=area,progress=watch,zone=zone,missed=missed}
        else highlights[qid]=nil end
        if area~=(old and old.area) or watch~=(old and old.progress) then changed=true end
    end
    return changed
end

function AT.GetRankQuestHighlight(qid)
    local state=highlights[qid]
    return state and state.area, state and state.progress~=nil
end

local function color(region,r,g,b,a) region:SetColorTexture(r,g,b,a or 1) end
local function text(parent,template)
    local f=parent:CreateFontString(nil,"OVERLAY",template or "GameFontHighlight")
    f:SetJustifyH("LEFT")
    return f
end
local function box(parent,layer)
    local r=parent:CreateTexture(nil,layer or "BACKGROUND")
    return r
end
local function button(parent,value,x,y,w,h,onclick)
    local b=CreateFrame("Button",nil,parent)
    b:SetSize(w,h); b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    b.fill=box(b);b.fill:SetAllPoints(b); color(b.fill,.11,.17,.21,.9)
    b.label=text(b,"GameFontHighlightSmall");b.label:SetPoint("CENTER");b.label:SetText(value)
    b:SetScript("OnEnter",function() b.fill:SetAlpha(.63) end)
    b:SetScript("OnLeave",function() b.fill:SetAlpha(1) end)
    b:SetScript("OnClick",onclick)
    return b
end
local function wheelFrame(parent,step)
    -- Use the native scroll viewport, not UIPanelScrollFrameTemplate:
    -- the latter creates a visible slider and arrow buttons.
    local f=CreateFrame("ScrollFrame",nil,parent)
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel",function(self,delta)
        if not is(delta,"number") or delta~=delta then return end
        local height=self:GetHeight()
        if not is(height,"number") or height<1 then return end
        local range=math.max(0,(self.contentHeight or 0)-height)
        local current=self:GetVerticalScroll()
        self:SetVerticalScroll(math.max(0,math.min(range,current-delta*step)))
    end)
    return f
end
local function setExtent(scroll,child,height)
    local extent=math.max(2,height)
    child:SetHeight(extent)
    scroll.contentHeight=extent
    local visible=scroll:GetHeight()
    if not is(visible,"number") or visible<1 then return end
    local current=scroll:GetVerticalScroll()
    local limit=math.max(0,extent-visible)
    if current>limit then scroll:SetVerticalScroll(limit) end
end

local function pushRefresh()
    if refreshPending then return end
    refreshPending=true
    local function run() refreshPending=nil; AT.RefreshQuestHUD() end
    if C_Timer and C_Timer.After then C_Timer.After(.12,run) else run() end
end
local function noteRemoval(qid)
    removedQuests[qid]=true
    if logCache then logCache.rows[qid]=nil end
    logDirty=true
end
function AT.RefreshRankQuestAfterAbandon(qid)
    local function reconcile()
        if call(Q.IsOnQuest,qid)==false then
            noteRemoval(qid)
            if AT.ForgetRemovedQuest then AT.ForgetRemovedQuest(qid) end
        end
        pushRefresh()
    end
    reconcile()
    if not removedQuests[qid] and C_Timer and C_Timer.After then C_Timer.After(.35,reconcile) end
end
local function openQuest(qid)
    if type(QuestMapFrame_OpenToQuestDetails)=="function" then call(QuestMapFrame_OpenToQuestDetails,qid)
    elseif QuestUtil then call(QuestUtil.OpenQuestDetails,qid) end
end
local function stopQuestHover()
    hover=nil
    if tooltipTicker then tooltipTicker:Cancel();tooltipTicker=nil end
    if questTooltip then questTooltip:Hide() end
end
local function addPartyTooltip(tip,snapshot,stock)
    if not snapshot or #snapshot.members==0 then return end
    if not stock then tip:AddLine("Party progress",.48,.91,.82) end
    for _,member in ipairs(snapshot.members) do
        local counts=member.lastCounts or member.counts
        if not stock or not member.counts then
            tip:AddLine(member.name .. (member.status and (": "..member.status) or ""),.78,.92,.91,true)
        end
        if counts and (not stock or member.lastCounts) then
            for _,o in ipairs(counts) do
                local summary=o.current.."/"..o.total
                local desc=o.desc
                if is(desc,"string") and desc~="" and not desc:find(summary,1,true) then summary=desc.."  |  "..summary
                elseif is(desc,"string") and desc~="" then summary=desc end
                local left=o.total-o.current
                if left>0 then summary=summary.."  ("..left.." remaining)" end
                tip:AddLine(summary,.86,.90,.96,true)
            end
        end
    end
end
local function drawQuestHover()
    local state=hover
    local row=state and state.row
    if not (row and state.qid==row.qid and (not row.IsVisible or row:IsVisible())
        and (not row.IsMouseOver or row:IsMouseOver())) then stopQuestHover();return end
    if not questTooltip then
        questTooltip=call(CreateFrame,"GameTooltip","AutoTrackRankQuestTooltip",UIParent,"GameTooltipTemplate")
        if not questTooltip then return end
        questTooltip:Hide()
    end
    local tip=questTooltip
    tip:SetOwner(row,"ANCHOR_LEFT")
    if tip.ClearLines then tip:ClearLines() end
    local snapshot=call(AT.GetQuestPartySnapshot,state.qid,true)
    local usingStock=false
    if snapshot and not row.partyOnly and tip.SetQuestPartyProgress and C_TooltipInfo
        and C_TooltipInfo.GetQuestPartyProgress then
        usingStock=call(tip.SetQuestPartyProgress,tip,state.qid,false,false)==true
    end
    if not usingStock then
        tip:SetText(row.title:GetText())
        if not row.partyOnly then
            local objectives=Q and call(Q.GetQuestObjectives,state.qid)
            if is(objectives,"table") then
                for _,o in ipairs(objectives) do
                    local line=field(o,"text")
                    if is(line,"string") then tip:AddLine(line,.8,.88,.91,true) end
                end
            end
        end
    end
    if row.isGroupQuest then
        local description=row.groupSize and ("Group quest  |  "..row.groupSize.." players recommended") or "Group quest"
        tip:AddLine(description,1,.76,.38,true)
    end
    addPartyTooltip(tip,snapshot,usingStock)
    if not row.partyOnly and addDropTooltip then addDropTooltip(tip,state.qid) end
    if not row.partyOnly then
        tip:AddLine("Click: open on map  |  Ctrl-click: queue  |  Right-click: exclude",.48,.91,.82,true)
    end
    tip:Show()
end
local function startQuestHover(row)
    stopQuestHover()
    if not row.qid then return end
    hover={row=row,qid=row.qid}
    drawQuestHover()
    if hover and C_Timer and C_Timer.NewTicker and call(AT.IsQuestPartyProgressActive)==true then
        tooltipTicker=C_Timer.NewTicker(.55,drawQuestHover)
    end
end

local function openRowMenu(row)
    local qid=row.qid
    if not qid or row.partyOnly or not AT.char or not AT.OpenRankQuestMenu then return end
    stopQuestHover()
    AT.OpenRankQuestMenu(row,qid,{
        minimized=AT.char.rankQuestMinimized and AT.char.rankQuestMinimized[qid],
        locked=AT.db.rankQuestLocked,
        refresh=pushRefresh,
        toggleMinimized=function()
            local state=AT.char.rankQuestMinimized or {}
            state[qid]=not state[qid] or nil
            AT.char.rankQuestMinimized=state
            pushRefresh()
        end,
        toggleLock=function() AT.db.rankQuestLocked=not AT.db.rankQuestLocked end,
    })
end

local function addRow(n)
    local b=CreateFrame("Button",nil,hud.content)
    b:RegisterForClicks("RightButtonUp")
    b.fill=box(b);b.fill:SetAllPoints(b)
    b.mark=box(b,"ARTWORK");b.mark:SetPoint("TOPLEFT");b.mark:SetPoint("BOTTOMLEFT");b.mark:SetWidth(2)
    b.title=text(b);b.title:SetPoint("TOPLEFT",12,-9);b.title:SetWordWrap(false)
    b.detail=text(b,"GameFontHighlightSmall");b.detail:SetPoint("TOPLEFT",12,-29);b.detail:SetWordWrap(false)
    b.objectives={}
    -- Use actual mouse-enabled frames. A FontString has no frame level and
    -- cannot reliably act as a secure overlay's geometry/input target.
    local titleHit=CreateFrame("Button",nil,b)
    titleHit:RegisterForClicks("LeftButtonUp","RightButtonUp")
    titleHit:EnableMouse(true)
    b.titleHit=titleHit
    local npcHit=CreateFrame("Button",nil,b)
    npcHit:RegisterForClicks("LeftButtonUp")
    npcHit:EnableMouse(true)
    -- Absorb clicks when the secure layer is unavailable, without opening
    -- the quest, invoking a protected Lua call, or changing the target.
    npcHit:SetScript("OnClick",function() end)
    npcHit:Hide()
    b.npcHit=npcHit
    local item=CreateFrame("Button",nil,b)
    item:SetSize(30,30);item:SetPoint("TOPRIGHT",-12,-28)
    item.icon=box(item,"ARTWORK");item.icon:SetAllPoints(item)
    item.border=box(item,"BACKGROUND");item.border:SetPoint("TOPLEFT",-1,1);item.border:SetPoint("BOTTOMRIGHT",1,-1)
    item.count=text(item,"GameFontNormalSmall");item.count:SetPoint("BOTTOMRIGHT",-2,0)
    item:SetScript("OnEnter",function(self)
        if GameTooltip and self.link then
            GameTooltip:SetOwner(self,"ANCHOR_LEFT")
            if GameTooltip.SetHyperlink then pcall(GameTooltip.SetHyperlink,GameTooltip,self.link) end
            if InCombatLockdown and InCombatLockdown() then GameTooltip:AddLine("Use this item from your bags during combat.",1,.79,.39,true) end
            GameTooltip:Show()
        end
    end)
    item:SetScript("OnLeave",function(self)
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    item:Hide()
    b.item=item
    b.badge=text(b,"GameFontNormalSmall");b.badge:SetPoint("TOPLEFT",11,-9)
    b.groupIcon=box(b,"ARTWORK")
    b.groupIcon:SetTexture("Interface/TargetingFrame/UI-RaidTargetingIcon_8")
    b.groupIcon:Hide()
    local circle=CreateFrame("Button",nil,b)
    circle:SetSize(21,21);circle:SetPoint("TOPLEFT",b,"TOPLEFT",9,-7)
    circle:RegisterForClicks("LeftButtonUp","RightButtonUp")
    circle.icon=box(circle,"ARTWORK")
    circle.icon:SetAllPoints(circle)
    circle.icon:SetTexture("Interface/AddOns/NQT/QueueBadge.tga")
    circle.dot=text(circle,"GameFontNormalSmall");circle.dot:SetPoint("CENTER");circle.dot:SetText("•")
    circle:SetScript("OnClick",function(self,key)
        if key=="RightButton" then openRowMenu(b);return end
        if not self.available or not b.qid or not AT.ToggleQuestHUDManualFocus then return end
        AT.ToggleQuestHUDManualFocus(b.qid)
        pushRefresh()
    end)
    circle:SetScript("OnEnter",function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_LEFT")
        GameTooltip:SetText(self.available and (self.pinned and "Resume automatic tracking" or (self.turnin and "Track turn-in location" or "Track this quest")) or "This quest cannot be tracked")
        GameTooltip:Show()
    end)
    circle:SetScript("OnLeave",function(self)
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    b.circle=circle
    b:SetScript("OnClick",function(self,key)
        if key=="RightButton" then openRowMenu(self) end
    end)
    titleHit:SetScript("OnClick",function(_,key)
        local qid=b.qid
        if not qid or b.partyOnly then return end
        if key=="RightButton" then openRowMenu(b);return end
        if IsControlKeyDown and IsControlKeyDown() and AT.ToggleQuestTrackingOrder then
            local ok,msg=AT.ToggleQuestTrackingOrder(qid)
            if not ok and msg then AT.Say(msg) end
        else
            openQuest(qid)
        end
        pushRefresh()
    end)
    local function onQuestEnter()
        b.fill:SetAlpha(.55)
        startQuestHover(b)
    end
    local function onQuestLeave()
        b.fill:SetAlpha(1)
        if hover and hover.row==b then stopQuestHover() end
    end
    b:SetScript("OnEnter",onQuestEnter)
    b:SetScript("OnLeave",onQuestLeave)
    titleHit:SetScript("OnEnter",onQuestEnter)
    titleHit:SetScript("OnLeave",onQuestLeave)
    hud.rows[n]=b
    return b
end
local function describe(e)
    local row=e.row
    if row.complete and not row.partyOnly then return "Ready to turn in" end
    if row.partyOnly then return row.turnedIn and "Turned in by you" or "Not in your quest log" end

    local kind=e.kind
    if kind=="dungeon" or kind=="unassigned" then return nil end
    if kind=="origin" or kind=="recorded" or kind=="category" then
        local zoneHere=hud.shownZone
        if id(row.destination) and row.destination~=zoneHere then
            local name=mapName(row.destination)
            return name and ("Leads to " .. name) or "Leads outside this zone"
        end
        return nil
    end
end
local function verifiedQuestItem(qid,index)
    local qt=Q and Q.GetLogIndexForQuestID
    local liveIndex=call(qt,qid) or index
    if not id(liveIndex) or not Q then return end
    local entry=call(Q.GetInfo,liveIndex)
    if field(entry,"questID")~=qid then return end
    local link,icon,count=call(GetQuestLogSpecialItemInfo,liveIndex)
    if is(link,"string") and (is(icon,"number") or is(icon,"string")) then return link,icon,count end
end
local function questItem(row)
    if not row.partyOnly then return verifiedQuestItem(row.id,row.logIndex) end
end

local function fontOffset()
    local n=AT.db.questHUDFontOffset
    if not is(n,"number") or n~=n then return 0 end
    return math.max(-2,math.min(5,math.floor(n)))
end
local function applyTypography(region,theme,size,template,useRequestedSize)
    if not region or not region.SetFont then return end
    local offset=fontOffset()
    local style=(theme.questie and "Questie" or template)..":"..size..":"..offset..(useRequestedSize and ":fixed" or "")
    if region.autoTrackFontStyle==style then return end
    local file,flags
    local base=_G[template]
    if theme.questie then file=STANDARD_TEXT_FONT or "Fonts/FRIZQT__.TTF"; flags=""
    elseif base and base.GetFont then
        local name,points,outline=base:GetFont()
        file,flags=name,outline
        if not useRequestedSize and is(points,"number") and points>0 then size=points end
    end
    region:SetFont(file or STANDARD_TEXT_FONT or "Fonts/FRIZQT__.TTF",math.max(8,size+offset),flags or "")
    region.autoTrackFontStyle=style
end
local function dropName(text)
    if not is(text,"string") then return end
    text=text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
    text=text:gsub("^%s*%d+%s*/%s*%d+[%s:]+",""):gsub("%s*[(:]?%s*%d+%s*/%s*%d+%)?%s*$","")
    return text:match("^%s*(.-)%s*$")
end
local dropIndex,dropIndexAt
local function observedDropItem(qid,label)
    local items=AT.ObservedQuestDrops and AT.ObservedQuestDrops.items
    if not items then return end
    local name,link=call(C_Item and C_Item.GetItemInfo,label)
    if not is(name,"string") then name,link=call(GetItemInfo,label) end
    if is(name,"string") and name==label and is(link,"string") then
        local item=tonumber(link:match("|Hitem:(%d+)"))
        if id(item) then return item end
    end
    -- For cold item caches, two exact Forever quest/item mappings are verified.
    local known=(qid==22 and 723) or (qid==38 and 730)
    if known and items[known] then
        local client=call(C_Item and C_Item.GetItemNameByID,known)
        if is(client,"string") and client==label or call(GetLocale)=="enUS" and
            ((known==723 and label=="Goretusk Liver") or (known==730 and label=="Murloc Eye")) then
            return known
        end
    end
    -- Index only names the client already knows. Never download item data
    -- for every ID, and only refresh if unresolved text actually needs it.
    local now=call(GetTime)
    if not dropIndex or is(now,"number") and dropIndexAt and now-dropIndexAt>=8 then
        dropIndex,dropIndexAt={},is(now,"number") and now or nil
        for item in pairs(items) do
            local n=call(C_Item and C_Item.GetItemNameByID,item)
            if is(n,"string") and n~="" then
                if dropIndex[n]~=nil and dropIndex[n]~=item then dropIndex[n]=false
                else dropIndex[n]=item end
            end
        end
    end
    return dropIndex[label] or nil
end


-- QuestieDB can run without the Questie tracker UI. Read only this
-- quest's item objectives, and require an exact, unambiguous name match.
local function standaloneProviderDropItem(qid,wanted)
    local provider=_G.LibQuestieDB
    if not provider or field(field(provider,"flavor"),"key")~="Forever" and
        field(field(provider,"flavor"),"id")~="Forever" and
        call(C_AddOns and C_AddOns.GetAddOnMetadata,"QuestieDB","X-Flavor")~="Forever" then return end
    local objectives=call(field(field(provider,"Quest"),"Get"),qid,"objectives")
    local candidates=field(objectives,3)
    if not is(candidates,"table") then return end
    local match
    for _,entry in pairs(candidates) do
        local item=field(entry,1)
        if id(item) then
            local name=call(C_Item and C_Item.GetItemNameByID,item)
            if (not is(name,"string") or name=="") and call(GetLocale)=="enUS" then
                name=call(field(field(provider,"Item"),"Get"),item,"name")
            end
            if is(name,"string") and name==wanted then
                if match and match~=item then return nil,true end
                match=item
            end
        end
    end
    return match
end

local function objectiveDropItem(db,qid,objective,label)
    if field(objective,"type")~="item" then return end
    local exact=field(objective,"itemID")
    if id(exact) then return exact end
    local linked
    for raw in label:gmatch("|Hitem:(%d+)") do
        local item=tonumber(raw)
        if linked and linked~=item then return end
        linked=item
    end
    if id(linked) then return linked end
    -- The native objective often only exposes localized text. Never assume
    -- Questie item ordering matches the quest log; compare exact item names.
    local wanted=dropName(label)
    if not wanted or wanted=="" then return end
    local objectives=field(db and call(db.GetQuest,qid),"ObjectiveData")
    if not is(objectives,"table") then
        local match,ambiguous=standaloneProviderDropItem(qid,wanted)
        if ambiguous then return end
        return match or observedDropItem(qid,wanted)
    end
    local match
    for _,entry in pairs(objectives) do
        local item=field(entry,"Id")
        if field(entry,"Type")=="item" and id(item) then
            local name=call(C_Item and C_Item.GetItemNameByID,item)
            if not is(name,"string") or name=="" then name=field(call(db.GetItem,db,item),"name") end
            if is(name,"string") and name==wanted then
                if match and match~=item then return end
                match=item
            end
        end
    end
    return match or observedDropItem(qid,wanted)
end
local function fmtDrop(value) return ("%d%%"):format(math.ceil(value-1e-10)) end
local function questieDropRange(db,item)
    if not db then return end
    -- Questie returns {percentage, source}; count only NPC records.
    local npcDrops=field(call(db.GetItem,db,item),"npcDrops")
    if not is(npcDrops,"table") then return end
    local lo,hi,seen=nil,nil,{}
    for _,npc in pairs(npcDrops) do
        if id(npc) and not seen[npc] then
            seen[npc]=true
            local rate=field(call(db.GetItemDroprate,item,npc),1)
            if is(rate,"number") and rate>0 and rate<=100 then
                lo=not lo and rate or math.min(lo,rate)
                hi=not hi and rate or math.max(hi,rate)
            end
        end
    end
    return lo,hi
end

local function observedRecord(item)
    local pack=AT.ObservedQuestDrops
    local rows=pack and pack.items[item]
    if not rows then return end
    local low,high
    for _,e in ipairs(rows) do
        local pct=e[2]/e[3]*100
        low=not low and pct or math.min(low,pct)
        high=not high and pct or math.max(high,pct)
    end
    if low then return low,high,rows end
end

local function objectiveDropSuffix(db,qid,objective,label)
    local item=objectiveDropItem(db,qid,objective,label)
    if not id(item) then return "" end
    local lo,hi=questieDropRange(db,item)
    if lo then
        local a,b=fmtDrop(lo),fmtDrop(hi)
        return " ("..(a==b and a or a.."\226\128\147"..b)..")"
    end
    local low,high,rows=observedRecord(item)
    if not low then return "" end
    local a,b=fmtDrop(low),fmtDrop(high)
    return " ("..(a==b and a or a.."\226\128\147"..b)..")",rows
end

addDropTooltip=function(tip,qid)
    if not (AT.db.rankQuestDropRates~=false and AT.ObservedQuestDrops) then return end
    local objectives=call(Q.GetQuestObjectives,qid)
    if not is(objectives,"table") then return end
    local db=module("QuestieDB")
    local credited=false
    for _,o in ipairs(objectives) do
        local label=field(o,"text")
        if is(label,"string") then
            local _,rows=objectiveDropSuffix(db,qid,o,label)
            if rows then
                if not credited then
                    tip:AddLine("Data from Everloot (https://everloot.app), CC BY-SA 4.0.",.70,.83,.93,true)
                    tip:AddLine("Observed rates per eligible loot window; not guaranteed.",.70,.83,.93,true)
                    credited=true
                end
                tip:AddLine(dropName(label),.86,.92,.95,true)
                for _,e in ipairs(rows) do
                    tip:AddLine(("%s #%d: %d/%d windows, %d installs (%s)"):format(
                        e[6]==1 and "Object" or "NPC",e[1],e[2],e[3],e[4],AT.ObservedQuestDrops.dates[e[5]]),.70,.83,.93,true)
                end
            end
        end
    end
end


local function renderObjectives(b,row,width,theme,hasItem,hasDetail)
    local ready=row.complete and not row.partyOnly
    local list=not ready and not row.partyOnly and call(Q.GetQuestObjectives,row.id)
    local offset=math.max(0,fontOffset())
    local top=hasDetail and 42 or 24
    local used,height=0,top+2*offset
    local function add(label,indent,r,g,blue)
        used=used+1
        local f=b.objectives[used]
        if not f then f=text(b,"GameFontHighlightSmall"); f:SetWordWrap(true);b.objectives[used]=f end
        local lineTop=height
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT",12+indent,-lineTop)
        f:SetWidth(math.max(90,width-(hasItem and 62 or 24)-indent))
        applyTypography(f,theme,10,"GameFontHighlightSmall")
        f:SetText(label)
        if r then f:SetTextColor(r,g,blue) else f:SetTextColor(unpack(theme.ink)) end
        f:Show()
        local rendered=f.GetStringHeight and f:GetStringHeight() or 12
        if not is(rendered,"number") or rendered<1 then rendered=12 end
        local lineHeight=math.max(12+fontOffset(),rendered)
        height=height+lineHeight+2
        return f,lineTop,lineHeight
    end
    if ready then
        local map,x,y,npc,npcOnly=call(AT.GetReadyQuestTurnInPoint,row.id)
        if id(map) and is(x,"number") and x>=0 and x<=1 and is(y,"number") and y>=0 and y<=1 then
            local area=mapName(map)
            local coords=string.format("%.1f, %.1f",x*100,y*100)
            if not is(area,"string") or area=="" then area=nil end
            if not is(npc,"string") or npc=="" then npc=nil end
            add(area and (area.."  |  "..coords) or coords,0)
            if npc then
                local token=npcOnly==true and call(AT.GetRankQuestNPCMacro,npc)
                local label,lineTop,lineHeight=add(npc,0,.93,.74,.38)
                local cap=math.max(90,width-(hasItem and 62 or 24))
                local pixels=call(label.GetUnboundedStringWidth,label) or call(label.GetStringWidth,label)
                local hitWidth=is(pixels,"number") and pixels>0 and math.min(cap,pixels+4) or cap
                b.npcHit:ClearAllPoints()
                b.npcHit:SetPoint("TOPLEFT",b,"TOPLEFT",12,-lineTop)
                b.npcHit:SetSize(hitWidth,lineHeight)
                b.npcHit:Show()
                if token then b.turnInLabel,b.turnInName=b.npcHit,npc end
            end
        end
    end
    local partyEnabled=AT.db.questPartyProgress~=false
    local showParty=partyEnabled and (row.partyPending or inlineParty and not ready)
    local showBreakdown=showParty and (inlineParty or ready or row.partyOnly)
    local function partyLine(line,indent)
        if theme.questie then add(line,indent,.56,.90,.87)
        else add(line,indent,.12,.35,.32) end
    end
    if showBreakdown and not row.partyOnly and is(list,"table") and #list>0 then
        partyLine("Your objectives",0)
    end
    if is(list,"table") then
        local db=AT.db.rankQuestDropRates~=false and module("QuestieDB")
        for _,o in ipairs(list) do
            local label=field(o,"text")
            if is(label,"string") and label~="" then
                if AT.db.rankQuestDropRates~=false and (db or AT.ObservedQuestDrops) then
                    label=label..objectiveDropSuffix(db,row.id,o,label)
                end
                local done=field(o,"finished")==true
                local bullet=theme.questie and " - " or (done and "|cff8bd1a2+|r " or "|cffb4bbbd- |r")
                if done then add(bullet..label,0,.64,.78,.68) else add(bullet..label,0) end
            end
        end
    end
    if showParty then
        local wroteParty=false
        for _,member in ipairs(row.party and row.party.members or {}) do
            local counts=member.counts or member.lastCounts
            local current,total=0,0
            for _,o in ipairs(counts or {}) do current,total=current+o.current,total+o.total end
            if total>current then
                if not wroteParty and showBreakdown then partyLine("Party objectives",0) end
                wroteParty=true
                local qualifier=member.lastCounts and " (last reported)" or member.countsPartial and " (reported objectives)" or ""
                partyLine(member.name.."  "..current.."/"..total..qualifier,showBreakdown and 7 or 0)
                if showBreakdown then
                    for i,o in ipairs(counts or {}) do
                        local left=o.total-o.current
                        if left>0 then
                            local label=(is(o.desc,"string") and o.desc~="" and o.desc) or ("Objective "..i)
                            partyLine(left.." remaining - "..label,17)
                        end
                    end
                end
            end
        end
        if not wroteParty and inlineParty then
            local unavailable=false
            for _,m in ipairs(row.party and row.party.members or {}) do
                if m.status=="Progress unavailable" then unavailable=true;break end
            end
            if not row.party then partyLine("Party objectives: no party data",0)
            elseif unavailable then partyLine("Party objectives: exact counts unavailable",0)
            else partyLine("Party objectives: no remaining counts reported",0) end
        end
    end
    for i=used+1,#b.objectives do
        b.objectives[i]:Hide()
        b.objectives[i]:SetText("")
    end
    local minimum=hasItem and 66 or (hasDetail and 49 or 30+offset)
    return math.max(height+3,minimum)
end

local difficultyColors={
    {"Trivial",.60,.60,.60}, {"Easy",.34,.82,.38}, {"Fair",1,.89,.20},
    {"Difficult",1,.49,.19}, {"Impossible",1,.26,.22},
}
local function difficulty(row)
    local enum=Enum and Enum.RelativeContentDifficulty
    if enum and C_PlayerInfo and (not HaveQuestData or call(HaveQuestData,row.id)==true) then
        local kind=call(C_PlayerInfo.GetContentDifficultyQuestForPlayer,row.id)
        if is(kind,"number") then
            for _,info in ipairs(difficultyColors) do
                if enum[info[1]]==kind then return info[2],info[3],info[4] end
            end
        end
    end
    local native=call(GetQuestDifficultyColor,row.level)
    return field(native,"r"),field(native,"g"),field(native,"b")
end

local function displayTitle(label,row,theme)
    local r,g,b=unpack(theme.questie and theme.accent or theme.ink)
    local title=row.title
    if id(row.level) then
        title=("["..row.level.."] ")..title
        local nr,ng,nb=difficulty(row)
        if is(nr,"number") and is(ng,"number") and is(nb,"number")
            and nr>=0 and nr<=1 and ng>=0 and ng<=1 and nb>=0 and nb<=1 then
            r,g,b=nr,ng,nb
        end
    end
    label:SetText(title)
    label:SetTextColor(r,g,b)
end

local function railButton(n)
    local b=button(hud.railContent,"",0,-(n-1)*26,99,23,function(self)
        if AT.BrowseQuestHUD then AT.BrowseQuestHUD(self.zoneKey) end
    end)
    b.label:ClearAllPoints();b.label:SetPoint("LEFT",7,0);b.label:SetWidth(85);b.label:SetWordWrap(false)
    hud.rail[n]=b
    return b
end
local function applyAtlas(region,atlas,useNativeSize)
    if not region.SetAtlas then return false end
    if C_Texture and C_Texture.GetAtlasInfo and not call(C_Texture.GetAtlasInfo,atlas) then return false end
    local ok,result=pcall(region.SetAtlas,region,atlas,useNativeSize)
    return ok and result~=false
end

local function arrangeDungeonMenu(theme,offset)
    hud.dungeonFrame:SetShown(dungeonOpen and true or false)
    if not dungeonOpen then return end
    local list={}
    for key in pairs(model.dungeons) do list[#list+1]=key end
    table.sort(list)
    local step=26+offset
    local total=#list+1
    for i=1,total do
        local option=hud.dungeonRows[i]
        if not option then
            option=button(hud.dungeonContent,"",0,0,204,23,function(self)
                selectedDungeon,dungeonOpen=self.dungeonKey,false
                resolveStatusOnSelection=true
                hud.scroll:SetVerticalScroll(0)
                AT.RefreshQuestHUD()
            end)
            option.label:ClearAllPoints()
            option.label:SetPoint("LEFT",7,0);option.label:SetWidth(189);option.label:SetWordWrap(false)
            hud.dungeonRows[i]=option
        end
        option.dungeonKey=list[i-1] or ALL_DUNGEONS
        option:ClearAllPoints();option:SetPoint("TOPLEFT",hud.dungeonContent,"TOPLEFT",0,-(i-1)*step)
        option:SetSize(204,step-3)
        option.label:SetText(option.dungeonKey==ALL_DUNGEONS and "All Dungeons" or option.dungeonKey)
        applyTypography(option.label,theme,10,"GameFontHighlightSmall")
        local chosen=option.dungeonKey==selectedDungeon
        color(option.fill,chosen and .24 or .11,chosen and .30 or .17,.21,.9)
        option:Show()
    end
    for i=total+1,#hud.dungeonRows do hud.dungeonRows[i]:Hide() end
    hud.dungeonFrame:SetHeight(math.max(37,math.min(245,12+total*step)))
    setExtent(hud.dungeonScroll,hud.dungeonContent,total*step)
end

local function lowerSearch(value)
    return (strlower or string.lower)(value)
end

local function questSearchIndex(result)
    if result.searchIndex then return result.searchIndex end
    local parts={}
    local function add(list,value)
        if is(value,"string") and value~="" then list[#list+1]=lowerSearch(value) end
    end
    for qid,row in pairs(result.rows) do
        if not row.partyOnly then
            local list={lowerSearch(row.title),tostring(qid),row.complete and "completed ready to turn in" or "in progress"}
            add(list,row.header)
            local objectives=call(Q and Q.GetQuestObjectives,qid)
            if is(objectives,"table") then
                for _,objective in ipairs(objectives) do add(list,field(objective,"text")) end
            end
            parts[qid]=list
        end
    end
    for _,buckets in ipairs({result.zones,result.dungeons}) do
        for _,bucket in pairs(buckets) do
            for qid in pairs(bucket.rows) do
                if parts[qid] then add(parts[qid],bucket.name) end
            end
        end
    end
    local index={}
    for qid,list in pairs(parts) do index[qid]=table.concat(list,"\n") end
    result.searchIndex=index
    return index
end

local function matchesSearch(haystack)
    for _,word in ipairs(searchWords) do
        if not haystack:find(word,1,true) then return false end
    end
    return true
end

local zoneBranchPriority={origin=40,recorded=30,category=20,destination=10,unassigned=0}
local function questSortPriority(row,activeID)
    if not row.partyOnly and row.id==activeID then return 0 end
    local state=highlights[row.id]
    return state and (state.area=="inside" or state.area=="near") and 1 or 2
end
local function questSortLevel(row)
    return id(row.level) and row.level or math.huge
end
local function groupQuestEntries(result,entries,scope)
    local best={}
    local function consider(bucket,prefix,priority)
        local name=bucket.name
        local key=prefix..":"..tostring(bucket.key)
        local hits=0
        if scope=="search" then
            local folded=lowerSearch(name)
            for _,term in ipairs(searchWords) do
                if folded:find(term,1,true) then hits=hits+1 end
            end
        end
        for qid,e in pairs(bucket.rows) do
            local rank=priority or (zoneBranchPriority[e.kind] or 0)
            local old=best[qid]
            if not old or hits>old.hits or (hits==old.hits and
                (rank>old.rank or (rank==old.rank and key<old.key))) then
                best[qid]={key=key,name=name,hits=hits,rank=rank}
            end
        end
    end
    if scope~="all-dungeons" then
        for _,bucket in pairs(result.zones) do consider(bucket,"zone") end
    end
    for _,bucket in pairs(result.dungeons) do
        consider(bucket,"dungeon",scope=="all-zones" and 5 or 50)
    end
    local byKey,groups={},{}
    for _,e in ipairs(entries) do
        local match=best[e.row.id]
        local key,name
        if match then key,name=match.key,match.name else key,name="zone:at-other","Other quests" end
        local group=byKey[key]
        if not group then
            group={key=key,name=name,entries={}}
            byKey[key]=group
            groups[#groups+1]=group
        end
        group.entries[#group.entries+1]=e
    end
    return groups
end

local function arrange()
    if not hud or not model then return end
    if AT.InvalidateRankQuestItems then AT.InvalidateRankQuestItems() end
    local a=themes[AT.db.questHUDTheme] or themes[2]

    local offset=math.max(0,fontOffset())
    local searching=itemSearchQuestID~=nil or #searchWords>0
    local nativeArt=false
    if a.map then
        -- Same client atlases as the actual Forever world-map quest-log pane.
        nativeArt=applyAtlas(hud.back,"QuestLog-main-background",false)
        if not nativeArt then color(hud.back,.16,.105,.057,.98) end
        local border=applyAtlas(hud.mapBorder,"questlog-frame",false)
        local trim=applyAtlas(hud.mapTrim,"questlog-frame-filigree",true)
        hud.mapBorder:SetShown(border);hud.mapTrim:SetShown(trim)
        hud.back:Show()
    else
        hud.back:Hide();hud.mapBorder:Hide();hud.mapTrim:Hide()
    end
    hud.rule:SetShown(a.map and not nativeArt or false)
    color(hud.rule,unpack(a.accent))
    color(hud.railBack,unpack(a.rail))
    hud.eyebrow:SetTextColor(unpack(a.accent))
    hud.eyebrow:SetText("Rank Quest")
    applyTypography(hud.zoneName,a,12,a.font)
    applyTypography(hud.search,a,12,a.font)
    applyTypography(hud.searchHint,a,12,a.font)
    local _,headerPoints=call(hud.zoneName.GetFont,hud.zoneName)
    local searchPoints=is(headerPoints,"number") and headerPoints or 12+fontOffset()
    hud.search:SetHeight(math.max(28,math.ceil(searchPoints)+12))
    if a.questie then hud.searchHint:SetTextColor(.68,.73,.76)
    else hud.searchHint:SetTextColor(.79,.70,.54) end
    hud.zoneName:SetTextColor(unpack(a.ink))


    if selectedDungeon and selectedDungeon~=ALL_DUNGEONS and not model.dungeons[selectedDungeon] then selectedDungeon=nil end
    local allZones=not selectedDungeon and viewedZone==ALL_ZONES
    local currentDungeonView=not selectedDungeon and not viewedZone and model.currentDungeon
    local selected=selectedDungeon and model.dungeons[selectedDungeon] or currentDungeonView or model.zones[viewedZone] or model.zones[model.current]
    if selectedDungeon==ALL_DUNGEONS then
        selected={key=ALL_DUNGEONS,name="All Dungeons",rows={}}
        for _,dungeon in pairs(model.dungeons) do
            for questID,entry in pairs(dungeon.rows) do selected.rows[questID]=entry end
        end
    end
    local function inProgress(row) return not row.complete or row.partyPending end
    local function readyToTurnIn(row) return row.complete and not row.partyOnly end
    if resolveStatusOnSelection then
        resolveStatusOnSelection=false
        local anyProgress,anyReady=false,false
        for _,value in pairs(allZones and model.rows or (selected and selected.rows) or {}) do
            local row=allZones and value or value.row
            anyProgress=anyProgress or inProgress(row)
            anyReady=anyReady or readyToTurnIn(row)
            if anyProgress and anyReady then break end
        end
        completedView=preferredCompleted or (not anyProgress and anyReady)
    end
    local function includes(row)
        return (completedView and readyToTurnIn(row)) or (not completedView and inProgress(row))
    end
    hud.eyebrow:SetWordWrap(false)
    hud.palette.label:SetText(a.name)
    hud.statusFilter.label:SetText(completedView and "Completed" or "In Progress")
    local hasText=(hud.search:GetText() or "")~=""
    hud.search:SetShown(searchOpen)
    hud.searchToggle:SetShown(not searchOpen)
    hud.searchToggle:SetHeight(hud.search:GetHeight())
    hud.searchClear:SetShown(searchOpen and hasText)
    hud.searchHint:SetShown(not hasText)
    local r,g,b=unpack(a.ink)
    hud.searchToggle.icon:SetVertexColor(r,g,b)
    color(hud.searchToggle.fill,a.map and .22 or .10,a.map and .14 or .15,a.map and .075 or .18,.96)
    color(hud.searchClear.fill,a.map and .22 or .10,a.map and .14 or .15,a.map and .075 or .18,.96)
    -- The label owns the header row. The expanded input gets its own row below.
    local searchSpace=searchOpen and (hud.search:GetHeight()+6) or 0
    local headerSpace=toolbarOpen and 0 or 22
    local contentShift=headerSpace-searchSpace
    local titleGutter=searchOpen and 0 or hud.searchToggle:GetWidth()+6
    hud.zoneName:SetWidth(math.max(1,hud:GetWidth()-26-titleGutter))
    hud.zoneName:ClearAllPoints()
    hud.zoneName:SetPoint("TOPLEFT",hud.body,"TOPLEFT",13,-58+headerSpace)
    hud.searchToggle:ClearAllPoints()
    hud.searchToggle:SetPoint("TOPRIGHT",hud.body,"TOPRIGHT",-13,-57+headerSpace)
    hud.search:ClearAllPoints()
    hud.search:SetPoint("TOPLEFT",hud.body,"TOPLEFT",13,-82+headerSpace)
    hud.search:SetPoint("TOPRIGHT",hud.body,"TOPRIGHT",-13,-82+headerSpace)
    hud.count:ClearAllPoints()
    hud.count:SetPoint("TOPLEFT",hud.body,"TOPLEFT",13,-82+contentShift)
    color(hud.searchBack,a.map and .10 or .045,a.map and .065 or .055,a.map and .035 or .065,.94)
    for _,control in ipairs({hud.palette,hud.statusFilter,hud.collapse,hud.smaller,hud.larger,hud.zoneButton,hud.dungeonButton,hud.tab,hud.drawer}) do
        applyTypography(control.label,a,10,"GameFontHighlightSmall")
    end
    local paletteWidth=call(hud.palette.label.GetUnboundedStringWidth,hud.palette.label)
    hud.palette:SetWidth(is(paletteWidth,"number") and math.max(52,math.ceil(paletteWidth+14)) or (54+offset*4))
    local statusWidth=call(hud.statusFilter.label.GetUnboundedStringWidth,hud.statusFilter.label)
    local minimum=82+offset*4
    hud.statusFilter:SetWidth(is(statusWidth,"number") and math.max(minimum,math.ceil(statusWidth+14)) or minimum)
    local partyEnabled=not AT.db or AT.db.questPartyProgress~=false
    for _,control in ipairs({hud.collapse,hud.palette,hud.statusFilter,hud.smaller,hud.larger,hud.zoneButton,hud.dungeonButton}) do
        control:SetShown(toolbarOpen)
    end
    hud.partyToggle:SetShown(toolbarOpen and partyEnabled)
    local titleWidth=hud:GetWidth()-13-10-24-8-hud.palette:GetWidth()-hud.statusFilter:GetWidth()
        -(partyEnabled and (hud.partyToggle:GetWidth()+4) or 0)-6
    local labelWidth=math.max(1,toolbarOpen and titleWidth or hud:GetWidth()-26)
    hud.eyebrow:SetWidth(labelWidth)
    -- When expanded, the drag/toggle surface ends before the first button.
    hud.header:SetWidth(toolbarOpen and labelWidth+13 or hud:GetWidth())
    color(hud.partyToggle.fill,inlineParty and .095 or .11,inlineParty and .45 or .17,inlineParty and .39 or .21,.96)
    hud.partyToggle.icon:SetAlpha(inlineParty and 1 or .67)
    applyTypography(hud.eyebrow,a,toolbarOpen and 10 or 18,toolbarOpen and "GameFontHighlightSmall" or a.font,not toolbarOpen)
    applyTypography(hud.count,a,10,"GameFontDisableSmall")
    applyTypography(hud.empty,a,10,"GameFontHighlightSmall")
    applyTypography(hud.localTab.label,a,10,"GameFontHighlightSmall")
    applyTypography(hud.allTab.label,a,10,"GameFontHighlightSmall")

    hud.dungeonButton.label:SetText("Dungeons")
    color(hud.dungeonButton.fill,selectedDungeon and .19 or .11, selectedDungeon and .28 or .17,.21,.9)
    hud.drawer:SetShown(not a.questie)
    local expanded=not a.questie and AT.db.questHUDRailOpen~=false
    hud.railFrame:SetShown(expanded or (a.questie and popupOpen))
    hud.drawer.label:SetText(expanded and "<" or ">")
    hud.scroll:ClearAllPoints()
    hud.scroll:SetPoint("TOPLEFT",hud.body,"TOPLEFT",expanded and 144 or (a.questie and 13 or 31),-102+contentShift)
    hud.scroll:SetPoint("BOTTOMRIGHT",hud.body,"BOTTOMRIGHT",-13,15)
    local entries,others={},{}
    if itemSearchQuestID then
        local row=model.rows[itemSearchQuestID]
        if row then entries[1]={row=row,kind="unassigned"} end
    elseif searching then
        for qid,haystack in pairs(questSearchIndex(model)) do
            if matchesSearch(haystack) then entries[#entries+1]={row=model.rows[qid],kind="unassigned"} end
        end
    elseif allZones then
        -- Quest IDs can belong to several zones. Use the unique log rows.
        for _,row in pairs(model.rows) do
            if includes(row) then entries[#entries+1]={row=row,kind="unassigned"} end
        end
    elseif selected then
        for _,e in pairs(selected.rows) do
            if includes(e.row) then entries[#entries+1]=e end
        end
    end
    local activeID=call(AT.GetQuestNavigationID)
    table.sort(entries,function(a,b)
        local qa,qb=a.row,b.row
        local pa,pb=questSortPriority(qa,activeID),questSortPriority(qb,activeID)
        if pa~=pb then return pa<pb end
        local la,lb=questSortLevel(qa),questSortLevel(qb)
        if la~=lb then return la<lb end
        return qa.title==qb.title and qa.id<qb.id or qa.title<qb.title
    end)
    for key,bucket in pairs(model.zones) do
        if key~=model.current and next(bucket.rows) then others[#others+1]=bucket end
    end
    table.sort(others,function(a,b) return a.name==b.name and tostring(a.key)<tostring(b.key) or a.name<b.name end)
    local railWidth=a.questie and 170 or 119
    local buttonWidth=railWidth-8
    local railGap=26+offset
    hud.railFrame:ClearAllPoints()
    hud.railFrame:SetWidth(railWidth)
    if a.questie then
        hud.railFrame:SetPoint("TOPRIGHT",hud.zoneButton,"BOTTOMRIGHT",0,-3)
        hud.railFrame:SetHeight(math.min(245,82+#others*railGap))
        color(hud.railBack,.035,.035,.042,.96)
    else
        hud.railFrame:SetPoint("TOPLEFT",hud.body,"TOPLEFT",20,-94+contentShift)
        hud.drawer:ClearAllPoints()
        hud.drawer:SetPoint("TOPLEFT",hud.body,"TOPLEFT",0,-94+contentShift)
        hud.drawer:SetPoint("BOTTOMLEFT",hud.body,"BOTTOMLEFT",0,3)
        hud.railFrame:SetPoint("BOTTOMLEFT",hud.body,"BOTTOMLEFT",20,3)
    end
    hud.railContent:SetWidth(buttonWidth)
    hud.localTab:SetSize(buttonWidth,23)
    hud.allTab:SetSize(buttonWidth,23)
    hud.shownZone=not allZones and selected and selected.key
    hud.zoneName:SetText(searching and "Search Results" or allZones and "All Zones" or (selected and selected.name or "Finding your zone"))
    local groupWord=(selectedDungeon or currentDungeonView) and "dungeon" or "zone"
    local emptyLabel=completedView and "No quests ready to turn in" or "No quests in progress"
    hud.empty:SetText(searching and "No matching quests." or (emptyLabel .. (allZones and "." or (" for this " .. groupWord .. "."))))
    hud.empty:SetShown(#entries==0)
    hud.empty:ClearAllPoints()
    hud.empty:SetPoint("TOPLEFT",hud.scroll,"TOPLEFT",11,-16)
    hud.localTab.label:SetText("CURRENT ZONE")
    if viewedZone or selectedDungeon then color(hud.localTab.fill,unpack(a.row))
    else color(hud.localTab.fill, a.accent[1]*.30,a.accent[2]*.30,a.accent[3]*.30,1) end
    if allZones then color(hud.allTab.fill,a.accent[1]*.30,a.accent[2]*.30,a.accent[3]*.30,1)
    else color(hud.allTab.fill,unpack(a.row)) end
    for n,bucket in ipairs(others) do
        local b=hud.rail[n] or railButton(n)
        b.zoneKey=bucket.key
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT",hud.railContent,"TOPLEFT",0,-(n-1)*railGap)
        b:SetSize(buttonWidth,railGap-3)
        b.label:SetWidth(buttonWidth-14)
        applyTypography(b.label,a,10,"GameFontHighlightSmall")
        b.label:SetText(bucket.name)
        if b.zoneKey==viewedZone then color(b.fill,a.accent[1]*.30,a.accent[2]*.30,a.accent[3]*.30,1)
        else color(b.fill,unpack(a.row)) end
        b:Show()
    end
    for n=#others+1,#hud.rail do hud.rail[n]:Hide() end
    setExtent(hud.railScroll,hud.railContent,#others*railGap)
    local pinnedID=call(AT.GetQuestHUDManualFocus)
    local width=math.max(180,hud.scroll:GetWidth()-8)
    hud.content:SetWidth(width)
    local yOffset,shownRows,shownGroups,shownOwned=0,0,0,0
    local outerWidth=width
    local groupScope=searching and "search" or (allZones and "all-zones")
        or (selectedDungeon==ALL_DUNGEONS and "all-dungeons")
    local visual={}
    if groupScope then
        local closed=AT.char and AT.char.rankQuestClosedBranches
        local groups=groupQuestEntries(model,entries,groupScope)
        local priorityGroups={}
        -- Lift only matching rows into the top of the current view. The rest
        -- stay in their collapsible branches. Don't duplicate promoted rows.
        for _,g in ipairs(groups) do
            local remaining={}
            for _,e in ipairs(g.entries) do
                if questSortPriority(e.row,activeID)<2 and not itemSearchQuestID then
                    priorityGroups[e]=g.name
                else
                    remaining[#remaining+1]=e
                end
            end
            g.entries=remaining
        end
        for _,e in ipairs(entries) do
            if priorityGroups[e] then
                visual[#visual+1]={row=e.row,kind=e.kind,priorityGroup=priorityGroups[e]}
            end
        end
        table.sort(groups,function(a,b)
            local al=a.entries[1] and questSortLevel(a.entries[1].row) or math.huge
            local bl=b.entries[1] and questSortLevel(b.entries[1].row) or math.huge
            if al~=bl then return al<bl end
            local l,r=lowerSearch(a.name),lowerSearch(b.name)
            return l==r and a.key<b.key or l<r
        end)
        for _,g in ipairs(groups) do
            if #g.entries>0 then
                local key=groupScope..":"..g.key
                local isClosed=(itemSearchQuestID and itemSearchCollapsed==true)
                    or (not itemSearchQuestID and is(closed,"table") and closed[key]==true)
                visual[#visual+1]={group=g,stateKey=key,closed=isClosed}
                if not isClosed then
                    for _,e in ipairs(g.entries) do visual[#visual+1]=e end
                end
            end
        end
    else
        visual=entries
    end
    for _,e in ipairs(visual) do
        if e.group then
            shownGroups=shownGroups+1
            local branch=hud.branches[shownGroups]
            if not branch then
                branch=button(hud.content,"",0,0,outerWidth,23,function(self)
                    if not self.branchKey then return end
                    if itemSearchQuestID then
                        itemSearchCollapsed=not itemSearchCollapsed
                        stopQuestHover()
                        arrange()
                        return
                    end
                    if not AT.char then return end
                    if not is(AT.char.rankQuestClosedBranches,"table") then AT.char.rankQuestClosedBranches={} end
                    local state=AT.char.rankQuestClosedBranches
                    state[self.branchKey]=not state[self.branchKey] or nil
                    stopQuestHover()
                    arrange()
                end)
                branch:RegisterForClicks("LeftButtonUp")
                branch.label:ClearAllPoints();branch.label:SetPoint("LEFT",9,0);branch.label:SetWordWrap(false)
                branch.total=text(branch,"GameFontDisableSmall");branch.total:SetPoint("RIGHT",-8,0)
                hud.branches[shownGroups]=branch
            end
            branch.branchKey=e.stateKey
            branch:ClearAllPoints();branch:SetPoint("TOPLEFT",hud.content,"TOPLEFT",0,-yOffset)
            branch:SetSize(outerWidth,23+offset)
            branch.label:SetWidth(math.max(60,outerWidth-52))
            branch.label:SetText((e.closed and "+  " or "-  ")..e.group.name)
            branch.label:SetTextColor(unpack(a.accent))
            branch.total:SetText(tostring(#e.group.entries))
            applyTypography(branch.label,a,10,"GameFontHighlightSmall")
            applyTypography(branch.total,a,10,"GameFontDisableSmall")
            if a.map then color(branch.fill,.30,.19,.085,.93) else color(branch.fill,.075,.10,.12,.82) end
            branch:Show()
            yOffset=yOffset+26+offset
        else
            shownRows=shownRows+1
            local indent=groupScope and not e.priorityGroup and 12 or 0
            width=outerWidth-indent
            local q=e.row
            if not q.partyOnly then shownOwned=shownOwned+1 end
            local b=hud.rows[shownRows] or addRow(shownRows)
            b.qid,b.partyOnly=q.id,q.partyOnly
            b.turnInLabel,b.turnInName=nil,nil
            b.npcHit:Hide()
            b:ClearAllPoints();b:SetPoint("TOPLEFT",hud.content,"TOPLEFT",indent,-yOffset)
            local link,icon,count=questItem(q)
            b.item.link,b.item.rankQuestIndex=link,q.logIndex
            b.item:SetShown(link~=nil)
            if link then
                b.item.icon:SetTexture(icon)
                color(b.item.border,unpack(a.accent))
                applyTypography(b.item.count,a,10,"GameFontNormalSmall")
                b.item.count:SetText(id(count) and count>1 and tostring(count) or "")
            end
            local excluded=call(AT.IsQuestExcluded,q.id)==true
            local statusTag=q.order and ("#" .. q.order) or (excluded and "OFF" or "")
            local circle=b.circle
            circle.available=not q.partyOnly and not excluded
            circle.pinned=pinnedID==q.id;circle.turnin=q.complete and not q.partyOnly
            local active=activeID==q.id and not q.partyOnly
            circle.icon:SetAlpha(active and 1 or (circle.available and .44 or .18))
            circle.dot:SetShown(active)
            circle.dot:SetTextColor(1,.97,.82)
            if circle.icon.SetDesaturated then circle.icon:SetDesaturated(not active) end
            circle:SetShown(true)
            b.badge:ClearAllPoints();b.badge:SetPoint("TOPLEFT",36,-9)
            local left=statusTag~="" and (65+offset*2) or 35
            b.isGroupQuest,b.groupSize=q.group,q.groupSize
            b.groupIcon:SetShown(q.group and true or false)
            if q.group then
                local iconSize=14+offset
                b.groupIcon:ClearAllPoints()
                b.groupIcon:SetPoint("TOPLEFT",b,"TOPLEFT",left,-8)
                b.groupIcon:SetSize(iconSize,iconSize)
                left=left+iconSize+5
            end
            b.title:ClearAllPoints();b.title:SetPoint("TOPLEFT",left,-9)
            b.title:SetWidth(math.max(80,width-left-12))
            b.badge:SetShown(statusTag~="")
            b.detail:ClearAllPoints();b.detail:SetPoint("TOPLEFT",12,-(29+offset));b.detail:SetWidth(width-(link and 62 or 24))
            applyTypography(b.badge,a,10,"GameFontNormalSmall")
            local marker=not q.complete and highlights[q.id]
            if marker and marker.progress then
                color(b.fill,.26,.16,.035,.85)
            elseif marker and marker.area then
                color(b.fill,.035,.25,.23,.77)
            else color(b.fill,unpack(a.row)) end
            b.mark:SetShown(marker~=nil or not a.questie)
            applyTypography(b.title,a,10,"GameFontHighlight")
            applyTypography(b.detail,a,10,"GameFontHighlightSmall")
            displayTitle(b.title,q,a)
            local titleCap=math.max(80,width-left-12)
            local titlePixels=call(b.title.GetUnboundedStringWidth,b.title)
            b.titleHit:ClearAllPoints()
            b.titleHit:SetPoint("TOPLEFT",b,"TOPLEFT",left,-7)
            b.titleHit:SetSize(is(titlePixels,"number") and titlePixels>0 and math.min(titleCap,titlePixels+3) or titleCap,16+offset)
            local detail=describe(e)
            if marker and marker.progress then
                color(b.mark,1,.71,.26,1)
                detail=detail and ("Progress updated  |  "..detail) or "Progress updated"
                b.detail:SetTextColor(1,.78,.40)
            elseif marker and marker.area then
                color(b.mark,.30,.96,.78,1)
                if marker.area=="near" then detail="Near an objective" end
                b.detail:SetTextColor(.52,.97,.85)
            else
                color(b.mark,a.accent[1],a.accent[2],a.accent[3],q.complete and .95 or .62)
                b.detail:SetTextColor(.63,.79,.82)
            end
            if e.priorityGroup then detail=detail and (detail.."  |  "..e.priorityGroup) or e.priorityGroup end
            b.detail:SetText(detail or "")
            b.detail:SetShown(detail~=nil)
            b.badge:SetText(statusTag)
            b.badge:SetTextColor(unpack(a.accent))
            local minimized=AT.char and AT.char.rankQuestMinimized and AT.char.rankQuestMinimized[q.id]
            local rowHeight
            if minimized then
                for _,objective in ipairs(b.objectives) do objective:Hide();objective:SetText("") end
                rowHeight=link and 66 or (detail and 49 or 30+offset)
            else rowHeight=renderObjectives(b,q,width,a,link~=nil,detail~=nil) end
            b:SetSize(width,rowHeight)
            yOffset=yOffset+rowHeight+3
            b:Show()
        end
    end
    hud.count:SetText(("%d/%d Quests"):format(shownOwned,model.total))
    for n=shownRows+1,#hud.rows do hud.rows[n].qid=nil;hud.rows[n].item.link=nil;hud.rows[n]:Hide() end
    for n=shownGroups+1,#hud.branches do hud.branches[n].branchKey=nil;hud.branches[n]:Hide() end
    setExtent(hud.scroll,hud.content,yOffset)
    arrangeDungeonMenu(a,offset)
    if AT.SetRankQuestItemTargets then AT.SetRankQuestItemTargets(hud.rows,hud.scroll,verifiedQuestItem) end
end
local function browse(z)
    resolveStatusOnSelection=true
    viewedZone=z
    selectedDungeon,dungeonOpen=nil,false
    popupOpen=false
    if hud then hud.scroll:SetVerticalScroll(0) end
    arrange()
end

AT.BrowseQuestHUD=browse

-- Only own the visibility we changed. Native watch/focus state, the game's
-- current module layout, and all third-party trackers are untouched.
local hiddenStock,stockHooked,stockOpacity,applyingOpacity={},{},{},{}
local syncPending, syncing
local function nativeContents(frame)
    local height=frame and call(frame.GetContentsHeight,frame)
    if is(height,"number") then return height>0 end
    if frame and frame.HasContents then
        local has=call(frame.HasContents,frame)
        if is(has,"boolean") then return has end
    end
end
local function setStockAlpha(frame,alpha)
    if not frame or not frame.SetAlpha then return end
    applyingOpacity[frame]=true
    local ok=pcall(frame.SetAlpha,frame,alpha)
    applyingOpacity[frame]=nil
    return ok
end
local function stockAlpha(frame,suppress)
    if not frame then return end
    local old=stockOpacity[frame]
    local alpha=call(frame.GetAlpha,frame)
    if suppress then
        if not is(alpha,"number") then return end
        if old==nil then stockOpacity[frame]=alpha end
        if alpha~=0 then setStockAlpha(frame,0) end
    elseif old~=nil then
        if alpha==old or setStockAlpha(frame,old) then stockOpacity[frame]=nil end
    end
end

local function stockHide(frame)
    if frame and call(frame.IsShown,frame)==true and type(frame.Hide)=="function" then
        if pcall(frame.Hide,frame) and call(frame.IsShown,frame)==false then hiddenStock[frame]=true end
    end
end
local function stockRestore(frame,displayable)
    if not frame or not hiddenStock[frame] then return end
    hiddenStock[frame]=nil
    if displayable~=false and call(frame.IsShown,frame)==false and type(frame.Show)=="function" then
        pcall(frame.Show,frame)
    end
end
local function deferNativeSync()
    if syncing or syncPending or not (C_Timer and C_Timer.After) then return end
    syncPending=true
    C_Timer.After(0,function()
        syncPending=false
        if AT.SyncBlizzardQuestHUD then AT.SyncBlizzardQuestHUD() end
    end)
end
local function stockUpdate()
    if AT.SyncBlizzardQuestHUD then AT.SyncBlizzardQuestHUD(true) end
    deferNativeSync()
end
local function observeStock(frame,layout)
    if not frame or stockHooked[frame] then return end
    stockHooked[frame]=true
    if frame.HookScript then pcall(frame.HookScript,frame,"OnShow",stockUpdate) end
    if hooksecurefunc then
        if layout and type(frame.Update)=="function" then pcall(hooksecurefunc,frame,"Update",stockUpdate) end
        if type(frame.SetAlpha)=="function" then
            pcall(hooksecurefunc,frame,"SetAlpha",function(self,alpha)
                if self~=frame or applyingOpacity[frame] or stockOpacity[frame]==nil then return end
                if not is(alpha,"number") or alpha<0 or alpha>1 then return end
                stockOpacity[frame]=alpha
                if alpha~=0 then setStockAlpha(frame,0) end
            end)
        end
    end
end
function AT.SyncBlizzardQuestHUD(presentationOnly)
    if syncing then return end
    local canChangeVisibility=not presentationOnly and not (InCombatLockdown and InCombatLockdown())
    local questFrame,container=QuestObjectiveTracker,ObjectiveTrackerFrame
    if not questFrame or not container then return end
    syncing=true
    observeStock(questFrame)
    observeStock(container,true)
    local active=AT.db and AT.db.enabled and AT.db.questHUDEnabled and hud
    local edit=EditModeManagerFrame and call(EditModeManagerFrame.IsEditModeActive,EditModeManagerFrame)==true
    local isCollapsed=call(container.IsCollapsed,container)==true
    local hasQuest=nativeContents(questFrame)
    local other=false
    local known=false
    -- The shared native wrapper may host achievement, scenario, or other
    -- sections. Hide the outer header only when it is exclusively quest UI.
    if is(container.modules,"table") then
        known=true
        for _,module in ipairs(container.modules) do
            if module~=questFrame then
                local present=nativeContents(module)
                if present~=false then other=true; break end
            end
        end
    end
    if active and not edit then
        local hideOuter=known and not other and not isCollapsed
        -- Blizzard may re-show its module during the very layout pass that
        -- Ctrl-click queue updates trigger. Clear pixels in that same pass,
        -- then reconcile frame visibility outside combat when it is safe.
        stockAlpha(questFrame,true)
        stockAlpha(container,hideOuter)
        if canChangeVisibility then
            stockHide(questFrame)
            if hideOuter then stockHide(container)
            elseif other then stockRestore(container,true) end
        end
    else
        stockAlpha(questFrame,false)
        stockAlpha(container,false)
        if canChangeVisibility then
            stockRestore(questFrame,not isCollapsed and hasQuest~=false)
            stockRestore(container,isCollapsed or hasQuest~=false or other)
        end
    end
    syncing=false
end

function AT.RefreshQuestHUD()
    if not hud then return end
    if not AT.db or not AT.db.enabled or not AT.db.questHUDEnabled then
        if AT.SetRankQuestItemTargets then AT.SetRankQuestItemTargets() end
        hud.search:ClearFocus()
        popupOpen,toolbarOpen=false,false; selectedDungeon,dungeonOpen=nil,false; hud:Hide(); observedObjectives,highlights,partyRetained,partyTurnedIn={},{},{},{}; stopQuestHover(); AT.SyncBlizzardQuestHUD(); return
    end
    hud:Show()
    local pos,name=playerZone()
    local _,dungeon,insideDungeon=playerDungeon(call(M and M.GetBestMapForUnit,"player"))
    local instanceKey=insideDungeon and (dungeon or true)
    if pos~=currentZone or instanceKey~=currentDungeon then
        currentZone,currentDungeon=pos,instanceKey
        if viewedZone~=ALL_ZONES then viewedZone=nil end
        popupOpen=false
        hud.railScroll:SetVerticalScroll(0)
        hud.scroll:SetVerticalScroll(0)
    end
    model=build(pos,name)
    if hover and tooltipTicker and call(AT.IsQuestPartyProgressActive)~=true then stopQuestHover() end
    refreshHighlights(true)
    hud.body:SetShown(not AT.db.questHUDCollapsed)
    hud.tab:SetShown(AT.db.questHUDCollapsed)
    if AT.db.questHUDCollapsed then
        hud.search:ClearFocus()
        applyTypography(hud.tab.label,themes[AT.db.questHUDTheme] or themes[2],10,"GameFontHighlightSmall")
    end
    if not AT.db.questHUDCollapsed then arrange() else
        if AT.SetRankQuestItemTargets then AT.SetRankQuestItemTargets() end
        popupOpen,dungeonOpen,toolbarOpen=false,false,false;stopQuestHover()
    end
    AT.SyncBlizzardQuestHUD()
end

function AT.SearchRankQuestItem(qid)
    if not (hud and AT.db and AT.db.enabled~=false and AT.db.questHUDEnabled
        and is(qid,"number") and qid>0 and qid%1==0) then return false end
    local title=call(Q and Q.GetTitleForQuestID,qid)
    if not is(title,"string") or title=="" then
        local row=model and model.rows[qid]
        title=row and row.title
    end
    if not is(title,"string") or title=="" then return false end
    local search=hud.search
    AT.db.questHUDCollapsed=false
    itemSearchQuestID,settingItemSearch,itemSearchCollapsed=qid,true,false
    search:SetText(title)
    settingItemSearch=nil
    search:ClearFocus()
    searchOpen=true
    popupOpen,dungeonOpen=false,false
    hud.scroll:SetVerticalScroll(0)
    AT.RefreshQuestHUD()
    return true
end

local function dismissEmptySearch(search)
    if not searchOpen or (search:GetText() or "")~="" then return end
    searchOpen=false
    arrange()
end

local function containsMouse(parent,target)
    for _=1,32 do
        if not ordinary(target) then break end
        if target==parent then return true end
        if type(target)~="table" and type(target)~="userdata" then break end
        local nextParent=call(target.GetParent,target)
        if nextParent==target then break end
        target=nextParent
    end
    return false
end

local function pointerOver(frame)
    return call(frame.IsVisible,frame)~=false and call(frame.IsMouseOver,frame)==true
end

local function releaseOnOutsideClick()
    if not hud or not (toolbarOpen or searchOpen) then return end
    local foci=call(GetMouseFoci)
    local target=field(foci,1)
    if not target then
        if containsMouse(hud,foci) then target=foci
        else target=call(GetMouseFocus) end
    end
    -- GLOBAL_MOUSE_DOWN can arrive with no button focus yet, before the
    -- button's own mouse-up click. Use the displayed HUD hit area as well.
    local inside=containsMouse(hud,target) or pointerOver(hud.body)
        or (hud.railFrame:IsShown() and pointerOver(hud.railFrame))
        or (hud.dungeonFrame:IsShown() and pointerOver(hud.dungeonFrame))
    if toolbarOpen and not inside then
        toolbarOpen,popupOpen,dungeonOpen=false,false,false
        arrange()
    end
    local search=hud.search
    if searchOpen and not (containsMouse(search,target) or pointerOver(search)) then
        if call(search.HasFocus,search)==true then search:ClearFocus() end
        dismissEmptySearch(search)
    end
end

function AT.InitQuestHUD()
    if hud or not CreateFrame or not UIParent then return end
    AT.NormalizeQuestHUDTheme(AT.db)
    hud=CreateFrame("Frame",nil,UIParent)
    hud:SetSize(math.max(358,math.min(630,AT.db.questHUDWidth)),math.max(275,math.min(700,AT.db.questHUDHeight)))
    hud:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",AT.db.questHUDX,AT.db.questHUDY)
    hud:SetFrameStrata("MEDIUM")
    if AT.InitRankQuestItems then AT.InitRankQuestItems() end
    hud:SetMovable(true);hud:SetResizable(true);hud:SetClampedToScreen(true)
    if hud.SetResizeBounds then hud:SetResizeBounds(358,275,630,700) end
    hud:Hide()
    local body=CreateFrame("Frame",nil,hud);body:SetAllPoints(hud);hud.body=body
    hud.back=box(body);hud.back:SetAllPoints(body)
    hud.mapBorder=box(body,"BORDER");hud.mapBorder:SetAllPoints(body)
    hud.mapTrim=box(body,"ARTWORK");hud.mapTrim:SetPoint("TOP",body,"TOP",0,3)
    hud.rule=box(body,"ARTWORK");hud.rule:SetPoint("TOPLEFT");hud.rule:SetPoint("TOPRIGHT");hud.rule:SetHeight(2)
    local header=CreateFrame("Frame",nil,body)
    hud.header=header
    header:SetPoint("TOPLEFT",body,"TOPLEFT",0,0)
    header:SetSize(hud:GetWidth(),34);header:EnableMouse(true);header:RegisterForDrag("LeftButton")
    local armed,dragged,moving
    header:SetScript("OnMouseDown",function(_,mouseButton)
        armed=mouseButton=="LeftButton"
        dragged=false
    end)
    header:SetScript("OnMouseUp",function(_,mouseButton)
        if mouseButton~="LeftButton" then return end
        local clicked=armed and not dragged
        armed=false
        if not clicked or not pointerOver(header) then return end
        toolbarOpen=not toolbarOpen
        if not toolbarOpen then popupOpen,dungeonOpen=false,false end
        arrange()
    end)
    header:SetScript("OnDragStart",function()
        dragged=true
        if AT.db.rankQuestLocked then return end
        if AT.SuspendRankQuestItems then AT.SuspendRankQuestItems(true) end
        moving=true
        hud:StartMoving()
    end)
    header:SetScript("OnDragStop",function()
        if not moving then return end
        moving=false
        hud:StopMovingOrSizing()
        if AT.SuspendRankQuestItems then AT.SuspendRankQuestItems(false) end
        local left,top=hud:GetRight(),hud:GetTop()
        if is(left,"number") and is(top,"number") then
            AT.db.questHUDX=left-UIParent:GetWidth(); AT.db.questHUDY=top-UIParent:GetHeight()
        end
    end)
    hud.eyebrow=text(header,"GameFontHighlightSmall");hud.eyebrow:SetPoint("TOPLEFT",13,-10);hud.eyebrow:SetText("Rank Quest")
    local search=CreateFrame("EditBox",nil,body)
    search:SetHeight(28)
    search:SetPoint("TOPLEFT",body,"TOPLEFT",13,-82)
    search:SetPoint("TOPRIGHT",body,"TOPRIGHT",-13,-82)
    search:SetAutoFocus(false);search:SetMaxLetters(128)
    search:SetFontObject(GameFontNormalLarge);search:SetTextInsets(8,37,0,0)
    if search.SetFrameLevel and header.GetFrameLevel then search:SetFrameLevel(header:GetFrameLevel()+2) end
    hud.search=search
    hud.searchBack=box(search,"BACKGROUND");hud.searchBack:SetAllPoints(search)
    hud.searchHint=text(search,"GameFontNormalLarge");hud.searchHint:SetPoint("LEFT",8,0)
    hud.searchHint:SetText("Search all quests")
    local openSearch=button(body,"",0,0,30,28,function(self)
        if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        searchOpen=true
        popupOpen,dungeonOpen=false,false
        arrange()
        search:SetFocus()
    end)
    openSearch:ClearAllPoints();openSearch:SetPoint("TOPRIGHT",body,"TOPRIGHT",-13,-57)
    local glass=openSearch:CreateTexture(nil,"ARTWORK")
    glass:SetSize(17,17);glass:SetPoint("CENTER")
    if not applyAtlas(glass,"common-search-magnifyingglass",false) then
        glass:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    end
    openSearch.icon=glass
    openSearch:SetScript("OnEnter",function(self)
        self.fill:SetAlpha(.72)
        if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_BOTTOM");GameTooltip:SetText("Search all quests");GameTooltip:Show() end
    end)
    openSearch:SetScript("OnLeave",function(self)
        self.fill:SetAlpha(1)
        if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    local clearSearch=button(search,"X",0,0,25,23,function() search:SetText("") end)
    clearSearch:ClearAllPoints();clearSearch:SetPoint("RIGHT",search,"RIGHT",-3,0)
    for _,control in ipairs({openSearch,clearSearch}) do
        control:RegisterForClicks("LeftButtonUp")
        if control.SetFrameLevel and search.GetFrameLevel then control:SetFrameLevel(search:GetFrameLevel()+1) end
    end
    hud.searchToggle,hud.searchClear=openSearch,clearSearch
    search:Hide();clearSearch:Hide()
    search:SetScript("OnTextChanged",function(self)
        if not settingItemSearch then itemSearchQuestID=nil end
        searchWords={}
        local query=self:GetText() or ""
        searchOpen=query~=""
        if not searchOpen then self:ClearFocus() end
        for token in lowerSearch(query):gmatch("%S+") do searchWords[#searchWords+1]=token end
        popupOpen,dungeonOpen=false,false
        if hud.scroll then hud.scroll:SetVerticalScroll(0);arrange() end
    end)
    search:SetScript("OnEditFocusLost",dismissEmptySearch)
    search:SetScript("OnEscapePressed",function(self)
        self:SetText("");self:ClearFocus();dismissEmptySearch(self)
    end)
    search:SetScript("OnEnterPressed",function(self) self:ClearFocus();dismissEmptySearch(self) end)
    hud.zoneName=text(header,"GameFontNormalLarge");hud.zoneName:SetPoint("TOPLEFT",13,-58)
    hud.zoneName:SetWordWrap(false)
    hud.count=text(body,"GameFontDisableSmall");hud.count:SetPoint("TOPLEFT",13,-82)
    local function toggle()
        AT.db.questHUDCollapsed=not AT.db.questHUDCollapsed
        AT.RefreshQuestHUD()
    end
    local collapse=button(body,"−",0,0,24,20,toggle)
    collapse:ClearAllPoints();collapse:SetPoint("TOPRIGHT",-10,-12)
    hud.collapse=collapse
    local palette=button(body,"Map",0,0,68,20,function()
        local t=AT.db.questHUDTheme or 2
        AT.db.questHUDTheme=t%#themes+1
        popupOpen,dungeonOpen=false,false
        arrange()
    end)
    palette:ClearAllPoints();palette:SetPoint("RIGHT",collapse,"LEFT",-4,0)
    hud.palette=palette
    local statusFilter=button(body,"In Progress",0,0,82,20,function()
        completedView=not completedView
        preferredCompleted=completedView
        resolveStatusOnSelection=false
        hud.scroll:SetVerticalScroll(0)
        arrange()
    end)
    statusFilter:ClearAllPoints();statusFilter:SetPoint("RIGHT",palette,"LEFT",-4,0)
    hud.statusFilter=statusFilter
    local partyToggle=button(body,"",0,0,23,20,function()
        if AT.db.questPartyProgress==false then return end
        inlineParty=not inlineParty
        arrange()
    end)
    partyToggle:ClearAllPoints();partyToggle:SetPoint("RIGHT",statusFilter,"LEFT",-4,0)
    partyToggle:RegisterForClicks("LeftButtonUp")
    -- The transparent title drag frame overlaps the toggle at narrow widths.
    if partyToggle.SetFrameLevel and header.GetFrameLevel then partyToggle:SetFrameLevel(header:GetFrameLevel()+2) end
    local icon=partyToggle:CreateTexture(nil,"ARTWORK")
    icon:SetSize(16,16);icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\AddOns\\NQT\\PartyPerson.tga")
    partyToggle.icon=icon
    partyToggle:SetScript("OnEnter",function(self)
        self.fill:SetAlpha(.78)
        local tip=GameTooltip
        if not tip then return end
        tip:SetOwner(self,"ANCHOR_BOTTOM")
        tip:SetText(inlineParty and "Hide inline party progress" or "Show inline party progress")
        tip:AddLine("Shows remaining objectives WoW reports for other party members.",.78,.89,.90,true)
        tip:Show()
    end)
    partyToggle:SetScript("OnLeave",function(self)
        self.fill:SetAlpha(1)
        if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    hud.partyToggle=partyToggle
    local function changeFont(delta)
        AT.db.questHUDFontOffset=math.max(-2,math.min(5,fontOffset()+delta))
        arrange()
    end
    local less=button(body,"-",0,0,22,20,function() changeFont(-1) end)

    local more=button(body,"+",0,0,22,20,function() changeFont(1) end)

    hud.smaller,hud.larger=less,more
    local zoneButton=button(body,"Zones",0,0,68,20,function()
        selectedDungeon,dungeonOpen=nil,false
        if logCache and not logCache.full then logDirty=true end
        local theme=themes[AT.db.questHUDTheme] or themes[2]
        if theme.questie then popupOpen=not popupOpen
        else AT.db.questHUDRailOpen=AT.db.questHUDRailOpen==false end
        AT.RefreshQuestHUD()
    end)
    zoneButton:ClearAllPoints();zoneButton:SetPoint("TOPRIGHT",body,"TOPRIGHT",-13,-35)
    hud.zoneButton=zoneButton
    local dungeonButton=button(body,"Dungeons",0,0,88,20,function()
        dungeonOpen=not dungeonOpen
        popupOpen=false
        if dungeonOpen then hud.dungeonScroll:SetVerticalScroll(0) end
        arrange()
    end)
    dungeonButton:ClearAllPoints();dungeonButton:SetPoint("RIGHT",zoneButton,"LEFT",-4,0)
    hud.dungeonButton=dungeonButton
    more:ClearAllPoints();more:SetPoint("RIGHT",dungeonButton,"LEFT",-5,0)
    less:ClearAllPoints();less:SetPoint("RIGHT",more,"LEFT",-4,0)
    -- The title drag hit area extends behind this row. Keep all controls above it.
    for _,control in ipairs({collapse,palette,statusFilter,partyToggle,less,more,dungeonButton,zoneButton}) do
        control:RegisterForClicks("LeftButtonUp")
        if control.SetFrameLevel and header.GetFrameLevel then control:SetFrameLevel(header:GetFrameLevel()+2) end
    end
    local dungeonFrame=CreateFrame("Frame",nil,body)
    dungeonFrame:SetSize(216,37)
    dungeonFrame:SetPoint("TOPRIGHT",dungeonButton,"BOTTOMRIGHT",0,-3)
    if dungeonFrame.SetFrameLevel and body.GetFrameLevel then dungeonFrame:SetFrameLevel(body:GetFrameLevel()+13) end
    local dungeonBack=box(dungeonFrame);dungeonBack:SetAllPoints(dungeonFrame);color(dungeonBack,.033,.043,.048,.97)
    local dungeonScroll=wheelFrame(dungeonFrame,48)
    dungeonScroll:SetPoint("TOPLEFT",dungeonFrame,"TOPLEFT",6,-6)
    dungeonScroll:SetPoint("BOTTOMRIGHT",dungeonFrame,"BOTTOMRIGHT",-6,6)
    local dungeonContent=CreateFrame("Frame",nil,dungeonScroll)
    dungeonContent:SetSize(204,2)
    dungeonScroll:SetScrollChild(dungeonContent)
    hud.dungeonFrame,hud.dungeonScroll,hud.dungeonContent,hud.dungeonRows=dungeonFrame,dungeonScroll,dungeonContent,{}
    dungeonFrame:Hide()
    hud.tab=button(hud,"Rank Quest  +",0,0,116,24,toggle)
    hud.tab:ClearAllPoints();hud.tab:SetPoint("TOPRIGHT",hud,"TOPRIGHT",0,0)
    local drawer=button(body,">",0,-94,19,80,function()
        selectedDungeon,dungeonOpen=nil,false
        AT.db.questHUDRailOpen=AT.db.questHUDRailOpen==false
        arrange()
    end)
    drawer:SetPoint("BOTTOMLEFT",body,"BOTTOMLEFT",0,3)
    hud.drawer=drawer
    local rail=CreateFrame("Frame",nil,body)
    rail:SetPoint("TOPLEFT",body,"TOPLEFT",20,-68)
    rail:SetPoint("BOTTOMLEFT",body,"BOTTOMLEFT",20,3); rail:SetWidth(119)
    hud.railFrame=rail
    if rail.SetFrameLevel and body.GetFrameLevel then rail:SetFrameLevel(body:GetFrameLevel()+12) end
    hud.railBack=box(rail);hud.railBack:SetAllPoints(rail)
    hud.localTab=button(rail,"CURRENT ZONE",3,-4,111,23,function() browse(nil) end)
    hud.allTab=button(rail,"ALL ZONES",3,-30,111,23,function() browse(ALL_ZONES) end)
    hud.rail={}
    hud.railScroll=wheelFrame(rail,48)
    hud.railScroll:SetPoint("TOPLEFT",rail,"TOPLEFT",3,-57)
    hud.railScroll:SetPoint("BOTTOMRIGHT",rail,"BOTTOMRIGHT",-4,4)
    hud.railContent=CreateFrame("Frame",nil,hud.railScroll)
    hud.railContent:SetSize(99,2)
    hud.railScroll:SetScrollChild(hud.railContent)
    hud.scroll=wheelFrame(body,66)
    if hud.scroll.HookScript and AT.InvalidateRankQuestItems then hud.scroll:HookScript("OnVerticalScroll",AT.InvalidateRankQuestItems) end
    hud.scroll:SetPoint("TOPLEFT",body,"TOPLEFT",115,-72)
    hud.scroll:SetPoint("BOTTOMRIGHT",body,"BOTTOMRIGHT",-13,15)
    hud.content=CreateFrame("Frame",nil,hud.scroll)
    hud.content:SetSize(200,2); hud.scroll:SetScrollChild(hud.content)
    hud.rows={};hud.branches={}
    hud.empty=text(body,"GameFontHighlightSmall");hud.empty:SetWidth(205);hud.empty:SetWordWrap(true)
    hud.empty:SetPoint("TOPLEFT",body,"TOPLEFT",126,-94);hud.empty:SetText("No active quests identified for this zone.")
    local resize=button(body,"/",0,0,14,14,function() end)
    resize:ClearAllPoints();resize:SetPoint("BOTTOMRIGHT",-3,3)
    resize:SetScript("OnMouseDown",function()
        if AT.db.rankQuestLocked then return end
        if AT.SuspendRankQuestItems then AT.SuspendRankQuestItems(true) end
        hud:StartSizing("BOTTOMRIGHT")
    end)
    resize:SetScript("OnMouseUp",function()
        hud:StopMovingOrSizing()
        AT.db.questHUDWidth=hud:GetWidth();AT.db.questHUDHeight=hud:GetHeight()
        if AT.SuspendRankQuestItems then AT.SuspendRankQuestItems(false) end
    end)
    hud:SetScript("OnSizeChanged",pushRefresh)
    local watcher=CreateFrame("Frame")
    for _,event in ipairs({"PLAYER_ENTERING_WORLD","QUEST_ACCEPTED","QUEST_REMOVED","QUEST_COMPLETE","QUEST_TURNED_IN","QUEST_LOG_UPDATE",
        "QUEST_WATCH_UPDATE","GROUP_ROSTER_UPDATE","QUEST_DATA_LOAD_RESULT","PLAYER_REGEN_ENABLED","PLAYER_LEVEL_UP","PLAYER_MAP_CHANGED","ZONE_CHANGED","ZONE_CHANGED_INDOORS","ZONE_CHANGED_NEW_AREA","SUPER_TRACKING_CHANGED","GLOBAL_MOUSE_DOWN"}) do
        pcall(watcher.RegisterEvent,watcher,event)
    end
    watcher:SetScript("OnEvent",function(_,event,first,second)
        if event=="GLOBAL_MOUSE_DOWN" then releaseOnOutsideClick();return end
        if not AT.char then return end
        if event=="QUEST_ACCEPTED" or event=="QUEST_REMOVED" or event=="QUEST_TURNED_IN" then logDirty=true end
        if (event=="QUEST_REMOVED" or event=="QUEST_TURNED_IN") and id(first) then
            noteRemoval(first)
            if AT.char.rankQuestMinimized then AT.char.rankQuestMinimized[first]=nil end
            if AT.InvalidateRankQuestAbandon then AT.InvalidateRankQuestAbandon(first) end
        end
        if event=="QUEST_TURNED_IN" and id(first) and partyRetained[first] then partyTurnedIn[first]=true end
        if event=="QUEST_ACCEPTED" and AT.db.questHUDEnabled then
            local qid=id(second) and second or first
            if id(qid) then partyTurnedIn[qid]=nil;removedQuests[qid]=nil end
            local z=playerZone()
            if id(qid) and id(z) then
                if not is(AT.char.zoneQuestOrigins,"table") then AT.char.zoneQuestOrigins={} end
                AT.char.zoneQuestOrigins[qid]=z
            end
        elseif (event=="QUEST_REMOVED" or event=="QUEST_TURNED_IN") and id(first) and is(AT.char.zoneQuestOrigins,"table") then
            AT.char.zoneQuestOrigins[first]=nil;starterMemo[first]=nil
        end
        pushRefresh()
    end)
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(1.4,function()
            if not AT.db or not AT.db.enabled or not AT.db.questHUDEnabled or not model then return end
            local _,dungeon,insideDungeon=playerDungeon(call(M and M.GetBestMapForUnit,"player"))
            if playerZone()~=currentZone or (insideDungeon and (dungeon or true))~=currentDungeon
                or next(partyRetained) or call(AT.IsQuestPartyProgressActive)==true then AT.RefreshQuestHUD()
            elseif refreshHighlights(false) and not AT.db.questHUDCollapsed then arrange() end
        end)
    end
    if C_Timer and C_Timer.After then
        for _,delay in ipairs({.4,1.3,3.5}) do
            C_Timer.After(delay,function()
                if AT.db and AT.db.questHUDEnabled then AT.RefreshQuestHUD() end
            end)
        end
    end
    AT.RefreshQuestHUD()
end
