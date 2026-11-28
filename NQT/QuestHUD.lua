local _, AT = ...
local Q,M=C_QuestLog,C_Map
local hud, refreshPending, currentZone, currentDungeon, viewedZone, model
local initialPaintPending
local ALL_ZONES,ALL_DUNGEONS={},{}
local popupOpen,completedView,toolbarOpen=false,false,false
local preferredCompleted,resolveStatusOnSelection=false,false
local visibleAutoTurnIn,renderedNavigationID
local selectedDungeon
local shareOpen,shareJob
local searchWords,searchOpen={},false
local itemSearchQuestID,settingItemSearch,itemSearchCollapsed
local observedObjectives, highlights={},{}
local partyRetained,partyTurnedIn={},{}
local removedQuests={}
local inlineParty=true
local questTooltip,tooltipTicker,hover
local themes={
    { name="Map", map=true, accent={.95,.76,.40}, ink={.90,.83,.64}, row={.20,.13,.067,.40},
      rail={.13,.085,.045,.92}, font="GameFontNormalLarge" },
    { name="Minimal", accent={1,.82,0}, ink={.95,.95,.95}, row={0,0,0,0},
      rail={0,0,0,.62}, font="GameFontNormal", minimal=true },
}
function AT.NormalizeQuestHUDTheme(db)
    -- In the old six-theme palette, 2 meant Astral and only 6 was Questie.
    -- Remember migration so a user's new Map/Minimal choice survives reload.
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
    local ok,a,b,c,d,e,f=pcall(fn,...); if ok then return a,b,c,d,e,f end
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
local function bundledOrigin(qid)
    local faction=call(UnitFactionGroup,"player")
    local side=faction=="Alliance" and 1 or faction=="Horde" and 2 or -1
    local found
    local verified=AT.LevelGuideQuestGivers and AT.LevelGuideQuestGivers[qid]
    local extra=AT.LevelGuideMoreOffers and AT.LevelGuideMoreOffers[qid]
    local function scan(rows)
        for _,p in ipairs(rows or {}) do
            if p[4]==0 or p[4]==side then
                local map=zone(p[1])
                if not map or found and found~=map then return false end
                found=map
            end
        end
        return true
    end
    if not scan(verified) then return end
    if not found and not scan(extra) then return end
    return found
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
local function dungeonFor(row,index,poiName,currentName)
    if call(AT.IsForeverOutdoorQuest,row.id)==true then return end
    -- Exact Forever quest IDs outrank generic client tags and pickup headers.
    local verified=call(AT.ForeverDungeonForQuest,row.id)
    if verified then return verified end
    local tag=field(call(Q.GetQuestTagInfo,row.id),"tagID")
    local tags=Enum and Enum.QuestTag
    if tags and (tag~=nil and (tag==tags.Raid or tag==tags.Raid10 or tag==tags.Raid25 or tag==tags.HeroicRaid)) then return end
    local function canonical(n) return call(AT.ForeverDungeonName,nil,n) or n end
    local known=is(row.header,"string") and index[row.header]
    if known then return canonical(known.name) end
    if currentName and canonical(row.header)==currentName and known~=false then return currentName end
    local _,destination=nativeDungeon(row.targetMap)
    if destination and index[destination]~=false then return canonical(destination) end
    -- Exact dungeon-map POIs are valid evidence; a generic dungeon tag is not.
    if poiName and index[poiName]~=false then return poiName end
    -- New instances can be absent from the native Dungeon UI-map index.
    -- An exact, known quest-log header still identifies the instance.
    if known~=false then return call(AT.ForeverDungeonName,nil,row.header) end
end

local logCache,logDirty
function AT.GetCachedRankQuestIDs()
    return logCache and logCache.rows
end
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
                if not id(row.level) then
                    local facts=AT.ForeverQuestFacts and AT.ForeverQuestFacts[qid]
                    if facts and id(facts[2]) then row.level=facts[2] end
                end
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
                local instance=dungeonFor(row,nameIndex,insidePOI[qid] and instanceName or nil,instanceName)
                if instance then
                    row.dungeon=instance
                    local bucket=result.dungeons[instance]
                    if not bucket then bucket={key=instance,name=instance,rows={}};result.dungeons[instance]=bucket end
                    bucket.rows[qid]={row=row,kind="dungeon"}
                end
                local accepted=origins[qid]
                local origin=not id(accepted) and bundledOrigin(qid)
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
        if not associated[row.id] and not row.dungeon then associate("at-other","Other quests",row,"unassigned") end
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
function AT.GetLevelGuideQuestLog() return model and model.rows end

local function shareNotice(message)
    local chat=DEFAULT_CHAT_FRAME
    if chat and chat.AddMessage then chat:AddMessage("Rank Quest: "..message)
    elseif print then print("Rank Quest: "..message) end
end

local function stopSharing(reason)
    local job=shareJob
    if not job then return end
    shareJob=nil
    if reason then shareNotice(reason.." ("..job.attempted.." attempted).")
    elseif job.attempted==0 then shareNotice("No shareable quests in that selection.")
    else
        shareNotice("Tried to share "..job.attempted..(job.attempted==1 and " quest." or " quests.")
            .." Party members must accept in WoW.")
    end
end

local Share={rejected={},pending={}}

function Share.value(fn,...)
    local result=call(fn,...)
    if ordinary(result) then return result end
end

function Share.roster()
    local members={}
    if Share.value(IsInGroup)~=true or Share.value(IsInRaid)==true then return members end
    local n=Share.value(GetNumSubgroupMembers)
    for i=1,id(n) and math.min(n,4) or 0 do
        local unit="party"..i
        local guid=Share.value(UnitGUID,unit)
        local name=Share.value(GetUnitName,unit,true)
        if not is(name,"string") then name=Share.value(UnitName,unit) end
        if is(guid,"string") and is(name,"string") and name~="" then
            members[#members+1]={unit=unit,guid=guid,name=name}
        end
    end
    return members
end

function Share.key(roster)
    local keys={}
    for _,m in ipairs(roster) do keys[#keys+1]=m.guid end
    table.sort(keys)
    return table.concat(keys,"|")
end

function Share.missing(q,members)
    local missing,unknown,offered={},false,{}
    local rejected=Share.rejected[q]
    local pending=Share.pending[q]
    local now=Share.value(GetTime)
    if pending and is(now,"number") and now>=pending.expires then
        Share.pending[q]=nil;pending=nil
    end
    for _,m in ipairs(members) do
        if not rejected or not rejected[m.guid] then
            local has=Share.value(Q.IsUnitOnQuest,m.unit,q)
            if not ordinary(has) then has=nil end
            if has==true then
                if pending then pending.members[m.guid]=nil end
            elseif pending and pending.members[m.guid] then
                offered[#offered+1]=m
            elseif has==false and Share.value(UnitIsVisible,m.unit)==true and Share.value(UnitIsConnected,m.unit)==true then
                missing[#missing+1]=m
            else
                unknown=true
            end
        end
    end
    if pending and not next(pending.members) then Share.pending[q]=nil end
    return missing,unknown,offered
end

function Share.lookup(message,template,members)
    if not is(message,"string") or not is(template,"string") then return end
    local first,last=template:find("%%1%$s")
    if not first then first,last=template:find("%%s") end
    if not first then return end
    local function literal(str) return (str:gsub("([^%w])","%%%1")) end
    local name=message:match("^"..literal(template:sub(1,first-1)).."(.+)"..literal(template:sub(last+1)).."$")
    if not name then return end
    name=name:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
    name=name:match("|h%[([^%]]+)%]|h") or name
    name=name:gsub("^%[",""):gsub("%]$","")
    local result
    for _,m in ipairs(members) do
        local exact=m.name==name
        local short=not name:find("-",1,true) and m.name:match("^[^-]+")==name
        if exact or short then
            if result then return end -- do not guess between identical short names
            result=m
        end
    end
    return result
end

function Share.feedback(message)
    local f=Share.feedbackFor
    if not f then return end
    local now=Share.value(GetTime)
    if not is(now,"number") or now>f.untilAt then return end
    local match=Share.lookup(message,ERR_QUEST_PUSH_ALREADY_DONE_S,f.roster)
    local reason=match and "already completed this quest."
    if not match then
        match=Share.lookup(message,ERR_QUEST_PUSH_INVALID_S,f.roster)
        reason=match and "is not eligible for this quest."
    end
    if not match or not f.recipients[match.guid] then return end
    local rejects=Share.rejected[f.q] or {}
    if rejects[match.guid] then return end
    Share.rejected[f.q]=rejects;rejects[match.guid]=true
    f.recipients[match.guid]=nil
    shareNotice(f.title..": "..match.name.." "..reason)
    if Share.refresh then Share.refresh() end
    if AT.RefreshQuestHUD then AT.RefreshQuestHUD() end
end

function Share.attempt(q,title,memberGUID)
    if not Q or not (AT.db and AT.db.enabled and AT.db.questHUDEnabled)
        or Share.value(IsInGroup)~=true or Share.value(InCombatLockdown)==true then return "stopped" end
    local push=QuestLogPushQuest or Q.QuestLogPushQuest
    local prior=Share.value(Q.GetSelectedQuest)
    if not push or not (id(prior) or prior==0) or removedQuests[q] or Share.value(Q.IsOnQuest,q)==false
        or Share.value(Q.IsPushableQuest,q)~=true then return end
    local roster=Share.roster()
    local key=Share.key(roster)
    if Share.groupKey and key~=Share.groupKey then
        Share.groupKey=key;Share.pending={};Share.rejected={};Share.feedbackFor=nil
        return "stopped"
    end
    Share.groupKey=key
    local missing,_,offered=Share.missing(q,roster)
    if #offered>0 then return "pending" end -- WoW can only make a group offer
    if #missing==0 then return end
    if memberGUID then
        local stillMissing=false
        for _,m in ipairs(missing) do if m.guid==memberGUID then stillMissing=true;break end end
        if not stillMissing then return end
    end
    local now=Share.value(GetTime)
    if not is(now,"number") then return end
    if Share.lastOffer and now<Share.lastOffer+4 then return "wait" end
    Share.value(Q.SetSelectedQuest,q)
    if Share.value(Q.GetSelectedQuest)~=q then return end
    local recipients={}
    for _,m in ipairs(missing) do recipients[m.guid]=true end
    Share.feedbackFor={q=q,title=title,untilAt=now+2.5,roster=roster,recipients=recipients}
    Share.pending[q]={members=recipients,expires=now+20}
    Share.lastOffer=now
    local ok,result=pcall(push)
    if prior~=q and Share.value(Q.GetSelectedQuest)==q then Share.value(Q.SetSelectedQuest,prior) end
    if not ok or ordinary(result) and result==false then
        Share.pending[q],Share.feedbackFor=nil,nil
        return "blocked"
    end
    return "attempted"
end

function Share.snapshot(scope,includePending)
    local z,name=playerZone()
    if logCache and not logCache.full then logDirty=true end
    local snapshot=build(z,name)
    local bucket=snapshot.currentDungeon or snapshot.zones[z]
    local roster,rows,unknown=Share.roster(),{},false
    for q,row in pairs(snapshot.rows) do
        local matches=scope=="all" or scope=="dungeons" and row.dungeon or scope=="zone" and bucket and bucket.rows[q]
        if matches and not row.partyOnly and Share.value(Q.IsPushableQuest,q)==true then
            local missing,uncertain,offered=Share.missing(q,roster)
            unknown=unknown or uncertain
            if (#missing>0 and #offered==0) or (includePending and #offered>0) then
                rows[#rows+1]={qid=q,title=row.title,order=row.logIndex or 0,missing=missing,offered=offered,
                    level=row.level,origin=row.origin,recorded=row.recorded,dungeon=row.dungeon,header=row.header,
                    destination=row.destination}
            end
        end
    end
    table.sort(rows,function(a,b) return a.order==b.order and a.qid<b.qid or a.order<b.order end)
    return rows,unknown,#roster
end

local function shareQuests(scope)
    if shareJob then shareNotice("A share batch is already running.");return end
    if Share.value(IsInGroup)~=true or Share.value(IsInRaid)==true then shareNotice("Join a party to share quests.");return end
    if Share.value(InCombatLockdown)==true then shareNotice("Share quests after combat.");return end
    if not (Q and Q.IsUnitOnQuest and Q.IsPushableQuest and C_Timer and C_Timer.After) then
        shareNotice("Bulk quest verification is unavailable on this client.");return
    end
    local rows=Share.snapshot(scope)
    local job={attempted=0,next=1}
    shareJob=job
    local function step()
        if shareJob~=job then return end
        while job.next<=#rows do
            local row=rows[job.next]
            local result=Share.attempt(row.qid,row.title)
            if result=="wait" then C_Timer.After(4,step);return end
            job.next=job.next+1
            if result=="stopped" then stopSharing("Sharing stopped");return end
            if result=="blocked" then stopSharing("WoW blocked a share; the rest of the batch was stopped");return end
            if result=="attempted" then
                job.attempted=job.attempted+1
                if Share.refresh then Share.refresh() end
                if job.next<=#rows then C_Timer.After(4,step) else stopSharing() end
                return
            end
        end
        stopSharing()
    end
    step()
end


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
        if not row.partyOnly and call(AT.IsQuestExcluded,qid)~=true then
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
        if not row or row.partyOnly or call(AT.IsQuestExcluded,qid)==true then
            area,watch=nil,nil
        elseif row.complete then
            area,watch=area=="near" and "near" or nil,nil
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
local function wheelFrame(parent,step,questItems)
    -- Use the native scroll viewport, not UIPanelScrollFrameTemplate:
    -- the latter creates a visible slider and arrow buttons.
    local f=CreateFrame("ScrollFrame",nil,parent)
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel",function(self,delta)
        if questItems and call(AT.IsRankQuestItemLayoutLocked) then return end
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

function Share.source(data)
    local known=call(AT.GetShareQuestStart,data.qid,data.origin,data.dungeon)
    if is(known,"string") and known~="" then return known end
    local origin=id(data.origin) and mapName(data.origin)
    if is(origin,"string") and origin~="" then
        return (data.recorded and "Accepted in: " or "Starts in: ")..origin
    end
    -- A dungeon, objective waypoint or quest-log header is context, not a
    -- verified origin. Never relabel a destination as the pickup location.
    local context=data.dungeon and ("Dungeon: "..data.dungeon)
    if not context and id(data.destination) then
        local destination=mapName(data.destination)
        if destination then context="Objective: "..destination end
    end
    if not context and is(data.header,"string") and data.header~="" then context="Quest log: "..data.header end
    return "Start location unknown"..(context and ("  |  "..context) or "")
end

function Share.refresh()
    local f=Share.window
    if not f or not f:IsShown() then return end
    local rows,unknown,members=Share.snapshot("all",true)
    local status
    if members==0 then status="Join a party to verify quests."
    elseif #rows==0 then status="No verified quests to share right now."
    else
        local available=0
        for _,data in ipairs(rows) do if #data.offered==0 then available=available+1 end end
        status=available.." ready to share  |  "..(#rows-available).." pending"
    end
    if unknown then status=status.." Some party progress is unavailable." end
    f.summary:SetText(status)
    local offset=0
    for i,data in ipairs(rows) do
        local row=f.rows[i]
        if not row then
            row=CreateFrame("Frame",nil,f.content)
            row:SetSize(438,62)
            local fill=box(row);fill:SetAllPoints(row);color(fill,.14,.19,.18,.50)
            row.title=text(row,"GameFontNormal");row.title:SetPoint("TOPLEFT",10,-7);row.title:SetWidth(347)
            row.title:SetJustifyH("LEFT");row.title:SetWordWrap(false)
            row.source=text(row,"GameFontHighlightSmall");row.source:SetPoint("TOPLEFT",10,-25)
            row.source:SetWidth(347);row.source:SetJustifyH("LEFT");row.source:SetWordWrap(true)
            row.source:SetTextColor(.87,.83,.66)
            row.detail=text(row,"GameFontHighlightSmall");row.detail:SetWidth(347)
            row.detail:SetJustifyH("LEFT");row.detail:SetWordWrap(true)
            row.action=button(row,"Share",0,0,58,25,function()
                if not row.qid or row.offerPending or not f:IsShown() then return end
                if shareJob then shareNotice("Stop or finish the bulk share first.");return end
                local chosen,title=row.qid,row.questTitle
                local result=Share.attempt(chosen,title)
                if result=="attempted" then shareNotice("Offer attempted: "..title)
                elseif result=="wait" then shareNotice("Wait a moment before sending another offer.")
                elseif result=="pending" then shareNotice("A group offer for this quest is still pending.")
                elseif result=="stopped" then shareNotice("Sharing is unavailable during combat or outside a party.")
                elseif result=="blocked" then shareNotice("WoW blocked that share.")
                else shareNotice("No verified recipient still needs that quest.") end
                Share.refresh()
            end)
            row.action:ClearAllPoints();row.action:SetPoint("RIGHT",row,"RIGHT",-8,0)
            row.action:RegisterForClicks("LeftButtonUp")
            f.rows[i]=row
        end
        local names,pendingNames={},{}
        for _,m in ipairs(data.missing) do names[#names+1]=m.name end
        for _,m in ipairs(data.offered) do pendingNames[#pendingNames+1]=m.name end
        row.qid,row.questTitle=data.qid,data.title
        row.title:SetText(id(data.level) and ("["..data.level.."] "..data.title) or data.title)
        row.source:SetText(Share.source(data))
        local detail=#names>0 and ("Not in log: "..table.concat(names,", ")) or ""
        if #pendingNames>0 then detail=detail..(#names>0 and "\n" or "").."Offer pending: "..table.concat(pendingNames,", ") end
        row.detail:SetText(detail)
        row.offerPending=#pendingNames>0
        row.action.label:SetText(row.offerPending and "Pending" or "Share")
        if row.action.SetEnabled then row.action:SetEnabled(not row.offerPending) end
        local sourceH=math.max(12,call(row.source.GetStringHeight,row.source) or 12)
        local detailH=math.max(12,call(row.detail.GetStringHeight,row.detail) or 12)
        row.detail:ClearAllPoints();row.detail:SetPoint("TOPLEFT",10,-29-sourceH)
        row:SetHeight(math.max(61,38+sourceH+detailH))
        row:ClearAllPoints();row:SetPoint("TOPLEFT",f.content,"TOPLEFT",0,-offset)
        offset=offset+row:GetHeight()+3
        row:Show()
    end
    for i=#rows+1,#f.rows do f.rows[i].qid=nil; f.rows[i]:Hide() end
    setExtent(f.scroll,f.content,offset)
end

function Share.open()
    if not Share.window then
        local f=CreateFrame("Frame","NQTShareVerify",UIParent)
        f:SetSize(474,407);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG")
        f:SetClampedToScreen(true);f:EnableMouse(true);f:SetMovable(true)
        local back=box(f);back:SetAllPoints(f);color(back,.042,.065,.061,.99)
        local rule=box(f,"ARTWORK");rule:SetHeight(2);rule:SetPoint("TOPLEFT",12,-36)
        rule:SetPoint("TOPRIGHT",-12,-36);color(rule,.34,.68,.40,.8)
        local title=text(f,"GameFontNormalLarge");title:SetPoint("TOPLEFT",16,-12);title:SetText("Share Verify")
        f.summary=text(f,"GameFontHighlightSmall");f.summary:SetPoint("TOPLEFT",16,-47)
        f.summary:SetWidth(442);f.summary:SetHeight(31);f.summary:SetWordWrap(true);f.summary:SetJustifyH("LEFT")
        local close=button(f,"X",0,0,24,22,function() f:Hide() end)
        close:ClearAllPoints();close:SetPoint("TOPRIGHT",-10,-9);close:RegisterForClicks("LeftButtonUp")
        local drag=CreateFrame("Frame",nil,f);drag:SetPoint("TOPLEFT");drag:SetPoint("TOPRIGHT",-44,0);drag:SetHeight(36)
        drag:EnableMouse(true);drag:SetScript("OnMouseDown",function(_,key)
            if key=="LeftButton" and f.StartMoving then f:StartMoving() end
        end)
        drag:SetScript("OnMouseUp",function() if f.StopMovingOrSizing then f:StopMovingOrSizing() end end)
        f.scroll=wheelFrame(f,65);f.scroll:SetPoint("TOPLEFT",16,-83);f.scroll:SetPoint("BOTTOMRIGHT",-16,16)
        f.content=CreateFrame("Frame",nil,f.scroll);f.content:SetSize(438,2)
        f.scroll:SetScrollChild(f.content)
        f.rows={}
        Share.window=f
        if type(UISpecialFrames)=="table" then UISpecialFrames[#UISpecialFrames+1]="NQTShareVerify" end
    end
    Share.window:Show()
    Share.refresh()
end



local function pushRefresh()
    if refreshPending then return end
    refreshPending=true
    local function run() refreshPending,initialPaintPending=nil,nil; AT.RefreshQuestHUD() end
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
    local rendered=model and model.rows[state.qid]
    if rendered and rendered.partyPending~=(snapshot and snapshot.pending or false) then pushRefresh() end
    local usingStock=false
    if snapshot and not snapshot.hasSharedResolution and not row.partyOnly and tip.SetQuestPartyProgress and C_TooltipInfo
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

local function makeQuestItemTile(b,n)
    local item=CreateFrame("Button",nil,b)
    item:SetSize(30,30);item:SetPoint("TOPRIGHT",-12,-28-(n-1)*33)
    item.icon=box(item,"ARTWORK");item.icon:SetAllPoints(item)
    item.border=box(item,"BACKGROUND");item.border:SetPoint("TOPLEFT",-1,1);item.border:SetPoint("BOTTOMRIGHT",1,-1)
    item.count=text(item,"GameFontNormalSmall");item.count:SetPoint("BOTTOMRIGHT",-2,0)
    item.cooldownShade=box(item,"OVERLAY")
    item.cooldownShade:SetAllPoints(item);color(item.cooldownShade,0,0,0,.64);item.cooldownShade:Hide()
    item.cooldownText=text(item,"GameFontNormal")
    item.cooldownText:SetPoint("CENTER",item,"CENTER",0,1)
    item.cooldownText:SetFont(STANDARD_TEXT_FONT or "Fonts/FRIZQT__.TTF",11,"OUTLINE")
    item.cooldownText:SetTextColor(1,.93,.66);item.cooldownText:Hide()
    if item.cooldownText.SetDrawLayer then item.cooldownText:SetDrawLayer("OVERLAY",3) end
    if item.count.SetDrawLayer then item.count:SetDrawLayer("OVERLAY",2) end
    item:SetScript("OnEnter",function(self)
        if GameTooltip and self.link then
            GameTooltip:SetOwner(self,"ANCHOR_LEFT")
            if GameTooltip.SetHyperlink then pcall(GameTooltip.SetHyperlink,GameTooltip,self.link) end
            if InCombatLockdown and InCombatLockdown() then GameTooltip:AddLine("If this item was not visible before combat, use it from your bags.",1,.79,.39,true) end
            GameTooltip:Show()
        end
    end)
    item:SetScript("OnLeave",function(self)
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    item:Hide()
    return item
end

local function addRow(n)
    local b=CreateFrame("Button",nil,hud.content)
    b:RegisterForClicks("RightButtonUp")
    b.fill=box(b);b.fill:SetAllPoints(b)
    b.mark=box(b,"ARTWORK");b.mark:SetPoint("TOPLEFT");b.mark:SetPoint("BOTTOMLEFT");b.mark:SetWidth(2)
    b.title=text(b);b.title:SetPoint("TOPLEFT",12,-9);b.title:SetWordWrap(false)
    b.detail=text(b,"GameFontHighlightSmall");b.detail:SetPoint("TOPLEFT",12,-29);b.detail:SetWordWrap(false)
    b.objectives={}
    b.objectiveMobIcons,b.objectiveMobHits={},{}
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
    local item=makeQuestItemTile(b,1)
    b.itemTiles={item}
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
local function questItemID(link)
    if not is(link,"string") then return end
    return tonumber(link:match("|Hitem:(%d+)") or link:match("^item:(%d+)$"))
end


local questBagActions, pendingItemData
local function requestRankQuestItemData(item)
    if not id(item) or not (C_Item and C_Item.RequestLoadItemDataByID) then return end
    pendingItemData=pendingItemData or {}
    if not pendingItemData[item] then
        pendingItemData[item]=true
        call(C_Item.RequestLoadItemDataByID,item)
    end
end

-- Build the live index once per bag/log invalidation, not once per quest row.
-- An item must be owned, explicitly linked to an active quest by the game,
-- and have an on-use spell. Collection items and quest starters do not count
-- from a matching name, a generic quest flag or an item-source backlink.
local function liveQuestBagActions()
    if questBagActions then return questBagActions end
    questBagActions={}
    local bags=C_Container
    if not (bags and bags.GetContainerItemQuestInfo and bags.GetContainerItemID and bags.GetContainerNumSlots) then return questBagActions end
    for bag=0,NUM_BAG_SLOTS or 4 do
        local slots=call(bags.GetContainerNumSlots,bag)
        if id(slots) and slots<=200 then
            for slot=1,slots do
                local info=call(bags.GetContainerItemQuestInfo,bag,slot)
                local quest=field(info,"questID")
                if id(quest) and field(info,"isQuestItem")==true and field(info,"isActive")==true then
                    local item=call(bags.GetContainerItemID,bag,slot)
                    if id(item) then
                        local _,spell=call(C_Item and C_Item.GetItemSpell or GetItemSpell,item)
                        if id(spell) then
                            local list=questBagActions[quest] or {}
                            questBagActions[quest]=list
                            if not list[item] then
                                list[item]=call(bags.GetContainerItemLink,bag,slot) or ("item:"..item)
                            end
                        else
                            requestRankQuestItemData(item)
                        end
                    end
                end
            end
        end
    end
    return questBagActions
end

local function questItemList(qid,index)
    local results,seen={},{}
    if not Q then return results end
    local liveIndex=call(Q.GetLogIndexForQuestID,qid)
    if not id(liveIndex) or field(call(Q.GetInfo,liveIndex),"questID")~=qid then liveIndex=index end
    local function add(link,icon,count)
        local item=questItemID(link)
        if not id(item) or seen[item] then return end
        if not is(icon,"number") and not is(icon,"string") then
            icon=call(C_Item and C_Item.GetItemIconByID or GetItemIcon,item)
        end
        if not is(icon,"number") and not is(icon,"string") then icon=134400 end
        seen[item]=true
        results[#results+1]={link=link,icon=icon,count=count,token="item:"..item}
    end
    if id(liveIndex) and field(call(Q.GetInfo,liveIndex),"questID")==qid then
        add(call(GetQuestLogSpecialItemInfo,liveIndex))
    end
    local active=call(Q.IsOnQuest,qid)
    local confirmed=id(liveIndex) and field(call(Q.GetInfo,liveIndex),"questID")==qid
    if not ordinary(active) then return results end
    if (active~=true and (active==false or not confirmed)) or call(AT.IsQuestReadyForTurnIn or Q.ReadyForTurnIn,qid)==true then return results end
    local function addVerifiedUses(pack)
        for _,record in ipairs(pack and pack[qid] or {}) do
            local item,expectedSpell=unpack(record)
            if not seen[item] then
                local count=call(C_Item and C_Item.GetItemCount or GetItemCount,item,false,false)
                if id(count) then
                    local _,spell=call(C_Item and C_Item.GetItemSpell or GetItemSpell,item)
                    if id(spell) and spell==expectedSpell then add("item:"..item,nil,count) elseif not id(spell) then requestRankQuestItemData(item) end
                end
            end
        end
    end
    addVerifiedUses(AT.ForeverObservedQuestUses)
    addVerifiedUses(AT.ForeverProvidedQuestUses)
    addVerifiedUses(AT.ForeverInstructedQuestUses)
    local held=liveQuestBagActions()[qid]
    if held then
        local ids={}
        for item in pairs(held) do ids[#ids+1]=item end
        table.sort(ids)
        for _,item in ipairs(ids) do
            if not seen[item] then
                local count=call(C_Item and C_Item.GetItemCount or GetItemCount,item,false,false)
                if id(count) then add(held[item],nil,count) end
            end
        end
    end
    return results
end

local function verifiedQuestItem(qid,index,token)
    for _,r in ipairs(questItemList(qid,index)) do
        if not token or r.token==token then return r.link,r.icon,r.count end
    end
end

local function fontOffset()
    local n=AT.db.questHUDFontOffset
    if not is(n,"number") or n~=n then return 0 end
    return math.max(-2,math.min(5,math.floor(n)))
end
local function applyTypography(region,theme,size,template,useRequestedSize)
    if not region or not region.SetFont then return end
    local offset=fontOffset()
    local style=(theme.minimal and "Minimal" or template)..":"..size..":"..offset..(useRequestedSize and ":fixed" or "")
    if region.autoTrackFontStyle==style then return end
    local file,flags
    local base=_G[template]
    if theme.minimal then file=STANDARD_TEXT_FONT or "Fonts/FRIZQT__.TTF"; flags=""
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
    return text:gsub("%s+"," "):match("^%s*(.-)%s*$")
end
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

end



local function factDropItem(qid,objective,wanted)
    local facts=AT.ForeverQuestFacts and AT.ForeverQuestFacts[qid]
    if not facts then return end
    local required=field(objective,"numRequired")
    local named,possible,unresolved
    local locale=call(GetLocale)
    local enUS=locale=="enUS" or locale=="enGB"
    local bundled=enUS and AT.ForeverQuestItemNames
    for i=3,#facts do
        local item,amount=unpack(facts[i])
        local name=call(C_Item and C_Item.GetItemNameByID,item)
        local known=bundled and bundled[item]
        if is(name,"string") and name~="" or is(known,"string") then
            if dropName(name)==wanted or dropName(known)==wanted then
                if named and named~=item then return nil,true end
                named=item
            end
        elseif id(required) and required==amount then
            requestRankQuestItemData(item)
            if possible and possible~=item then unresolved=true end
            possible=item
        end
    end
    if named then return named end
    -- Cold cache: only map by quantity when the quest has one known item
    -- objective. Never guess a mapping among multiple same-count items.
    if #facts==3 and not unresolved then return possible end
end

local function objectiveDropItem(qid,objective,label)
    if field(objective,"type")~="item" then return end
    local exact=field(objective,"itemID")
    if not id(exact) then exact=field(objective,"itemId") end
    if id(exact) then return exact end
    local linked
    for raw in label:gmatch("|Hitem:(%d+)") do
        local item=tonumber(raw)
        if linked and linked~=item then return end
        linked=item
    end
    if id(linked) then return linked end
    -- Match localized text against exact item names rather than objective order.
    local wanted=dropName(label)
    if not wanted or wanted=="" then return end
    local fact,uncertain=factDropItem(qid,objective,wanted)
    if uncertain then return end
    if fact then return fact end
    return observedDropItem(qid,wanted) or call(AT.GetKnownQuestDropItem,qid,wanted)
end
AT.ResolveRankQuestObjectiveItem=objectiveDropItem
local function fmtDrop(value) return ("%d%%"):format(math.ceil(value-1e-10)) end

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
    if low then return low,high end
end

local function objectiveDropSuffix(qid,item)
    if not id(item) then return "" end
    local grouped=call(IsInGroup)==true
    local pack=AT.ForeverQuestDropSamples
    if grouped then pack=AT.ForeverGroupedQuestDropSamples end
    local samples=pack and pack[qid]
    local rows=samples and samples[item]
    local openedWindows=grouped
    if not rows and not grouped then
        local solo=AT.ForeverSoloQuestWindowSamples and AT.ForeverSoloQuestWindowSamples[qid]
        rows=solo and solo[item]
        openedWindows=rows~=nil
    end
    if rows then
        local low,high
        for _,row in ipairs(rows) do
            local rate=openedWindows and row[2]/row[3]*100 or row[2]/100
            low=not low and rate or math.min(low,rate)
            high=not high and rate or math.max(high,rate)
        end
        if low then
            local a,b=fmtDrop(low),fmtDrop(high)
            return " ("..(a==b and a or a.."\226\128\147"..b)..")",rows,grouped and "eg-group" or (openedWindows and "eg-solo-window" or "eg")
        end
    end
    local early=AT.ForeverEarlyDropSamples and AT.ForeverEarlyDropSamples[qid]
    local function earlyRate(mode)
        local best
        for _,e in ipairs(early or {}) do
            if e[1]==item and e[7]==mode and (not best or e[4]>best[4]
                or e[4]==best[4] and e[2]<best[2]) then best=e end
        end
        if best then return " ("..fmtDrop(best[3]/best[4]*100)..", "..(mode==1 and "party" or "solo")
            .." sample: "..best[4].." loots)" end
    end
    local currentMode=grouped and 1 or 0
    local estimate=earlyRate(currentMode)
    if not estimate then
        local localRates=AT.ForeverPublicDropWindows and AT.ForeverPublicDropWindows[qid]
        local record=localRates and localRates[item]
        local window=record and record[currentMode]
        if window then
            local a,b=fmtDrop(window[1]*100),fmtDrop(window[2]*100)
            estimate=" ("..(a==b and a or a.."\226\128\147"..b)..")"
        end
    end
    if estimate then return estimate end
    if AT.ForeverRivergladesDropComparison and AT.ForeverRivergladesDropComparison[qid] then
        local other
        if grouped then other=AT.ForeverQuestDropSamples else other=AT.ForeverGroupedQuestDropSamples end
        local list=other and other[qid] and other[qid][item]
        if list then
            local low,high
            for _,e in ipairs(list) do
                local rate=grouped and e[2]/100 or e[2]/e[3]*100
                low=not low and rate or math.min(low,rate)
                high=not high and rate or math.max(high,rate)
            end
            if low then
                local a,b=fmtDrop(low),fmtDrop(high)
                return " ("..(grouped and "solo: " or "party: ")..(a==b and a or a.."\226\128\147"..b)..")"
            end
        end
    end
    local low,high=observedRecord(item)
    if not low then
        local estimate=earlyRate(1-currentMode)
        if estimate then return estimate end
        local ref=AT.ForeverReportedQuestDropReferences and AT.ForeverReportedQuestDropReferences[qid]
        local row=ref and ref[item]
        if row then return " ("..fmtDrop(row[2]/100)..")" end
        return ""
    end
    local a,b=fmtDrop(low),fmtDrop(high)
    return " ("..(a==b and a or a.."\226\128\147"..b)..")"
end

local objectiveMobTip
local function liveMobPortrait(owner,texture)
    if not is(owner.mobName,"string") or not SetPortraitTexture then return false end
    local liveName=call(UnitName,"target")
    if not is(liveName,"string") or liveName~=owner.mobName then return false end
    local isPlayer=call(UnitIsPlayer,"target")
    if not is(isPlayer,"boolean") or isPlayer then return false end
    local matches
    if owner.vendorItem or owner.npcObjective then
        matches=call(UnitIsFriend,"player","target")
    else
        matches=call(UnitCanAttack,"player","target")
    end
    if not is(matches,"boolean") or not matches then return false end
    if owner.npcID then
        local guid=call(UnitGUID,"target")
        local npc=is(guid,"string") and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
        if (npc or owner.vendorItem or owner.npcObjective or owner.dropItem) and npc~=owner.npcID then return false end
    end
    local ok,result=pcall(SetPortraitTexture,texture,"target",true)
    return ok and ordinary(result) and result~=false
end
local function bundledMobPortrait(owner,texture)
    texture:SetTexture(132094)
    if id(owner.displayID) and SetPortraitTextureFromCreatureDisplayID then
        local ok,result=pcall(SetPortraitTextureFromCreatureDisplayID,texture,owner.displayID)
        if not ok or result==false then texture:SetTexture(132094) end
    end
end
local function paintMobIcon(icon,tryLive)
    if not icon.mobName or icon.overflow then return end
    local key=icon.questId..":"..icon.mobName..((icon.vendorItem or icon.npcObjective or icon.dropItem) and (":"..tostring(icon.vendorItem or icon.npcObjective or icon.dropItem)..":"..tostring(icon.npcID)) or "")
    local fixed=key..":"..tostring(icon.displayID)
    if (tryLive or icon.renderKey~=fixed and icon.renderKey~="live:"..key)
        and liveMobPortrait(icon,icon.image) then icon.renderKey="live:"..key;return end
    if icon.renderKey=="live:"..key then return end
    if icon.renderKey~=fixed then bundledMobPortrait(icon,icon.image);icon.renderKey=fixed end
end
function AT.RefreshRankQuestMobPortraits()
    if not hud or not hud.rows or not hud:IsShown() or AT.db.questHUDCollapsed then return end
    for _,row in ipairs(hud.rows) do
        if row.qid and row:IsShown() then
            for _,icon in ipairs(row.objectiveMobIcons) do
                if icon.questId==row.qid and icon:IsShown() then paintMobIcon(icon,true) end
            end
        end
    end
    local tip=objectiveMobTip
    if tip and tip.owner and tip:IsShown() then liveMobPortrait(tip.owner,tip.portrait) end
end
local function hideObjectiveMobTip(self)
    if objectiveMobTip and objectiveMobTip.owner==self then
        objectiveMobTip.owner=nil
        objectiveMobTip:Hide()
    end
    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end
local function showObjectiveMobTip(owner)
    local name=owner.mobName
    if not name then
        if GameTooltip then
            GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
            GameTooltip:SetText("More mobs that drop this item")
            GameTooltip:Show()
        end
        return
    end
    if not objectiveMobTip then
        local tip=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
        tip:SetFrameStrata("TOOLTIP")
        tip:SetClampedToScreen(true)
        tip:EnableMouse(false)
        if tip.SetBackdrop then
            tip:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
            tip:SetBackdropColor(.035,.037,.042,.97)
            tip:SetBackdropBorderColor(.76,.64,.40,.95)
        end
        tip.portrait=box(tip,"ARTWORK")
        tip.portrait:SetSize(48,48);tip.portrait:SetPoint("TOPLEFT",tip,"TOPLEFT",9,-9)
        tip.mob=text(tip,"GameFontNormal")
        tip.mob:SetPoint("TOPLEFT",tip,"TOPLEFT",66,-15)
        tip.mob:SetWordWrap(true)
        tip.instruction=text(tip,"GameFontHighlightSmall")
        tip.instruction:SetPoint("TOPLEFT",tip.mob,"BOTTOMLEFT",0,-5)
        tip.instruction:SetText("Click to set Auto Macro")
        objectiveMobTip=tip
    end
    local tip=objectiveMobTip
    tip.owner=owner
    tip:ClearAllPoints();tip:SetPoint("BOTTOMLEFT",owner,"TOPRIGHT",6,6)
    tip.mob:SetText(name)
    tip.instruction:SetText(owner.vendorItem and "Vendor (NPC) · Click to target, mark, and ping out of combat" or owner.npcObjective and "Quest NPC - Click to target, mark, and ping out of combat" or "Click to set Auto Macro")
    local pixels=call(tip.mob.GetUnboundedStringWidth,tip.mob)
    local labelWidth=math.max(120,math.min(225,is(pixels,"number") and pixels or 175))
    tip.mob:SetWidth(labelWidth)
    local labelHeight=call(tip.mob.GetStringHeight,tip.mob)
    tip:SetSize(77+labelWidth,math.max(66,35+(is(labelHeight,"number") and labelHeight or 14)))
    if not liveMobPortrait(owner,tip.portrait) then bundledMobPortrait(owner,tip.portrait) end
    tip:Show()
end
local function chooseQuestMob(name)
    if not AT.SetQuestMobTarget then return end
    local ok,why=AT.SetQuestMobTarget(name)
    if not ok and why and UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(why,1,.3,.3,1)
    end
end
local function objectiveMobIsCurrent(self,b)
    return self.questId and self.questId==b.qid and (not self.IsVisible or self:IsVisible())
end
local function wireObjectiveMobHover(button,b)
    button:SetScript("OnEnter",function(self)
        if not objectiveMobIsCurrent(self,b) then return end
        stopQuestHover()
        showObjectiveMobTip(self)
    end)
    button:SetScript("OnLeave",hideObjectiveMobTip)
    button:SetScript("OnHide",hideObjectiveMobTip)
end
local function setObjectiveMob(button,qid,name,overflow,vendor,sourceItem)
    local display,npc
    if vendor then display,npc=vendor.display,vendor.npc
    elseif name then display,npc=call(AT.GetQuestMobDisplayID,name,true,qid,sourceItem) end
    if button.questId~=qid or button.mobName~=name or button.displayID~=display
        or button.vendorItem~=(vendor and vendor.item) or button.npcObjective~=(vendor and vendor.objective) or button.npcID~=npc or button.dropItem~=sourceItem then
        hideObjectiveMobTip(button)
    end
    button.questId,button.mobName,button.overflow,button.displayID,button.npcID=qid,name,overflow,display,npc
    button.vendorItem,button.npcObjective,button.dropItem=vendor and vendor.item,vendor and vendor.objective,sourceItem
end
local function resetObjectiveMobButtons(buttons,first)
    for i=first or 1,#buttons do
        local button=buttons[i]
        hideObjectiveMobTip(button)
        button.questId,button.mobName,button.overflow,button.displayID,button.npcID,button.vendorItem,button.npcObjective,button.dropItem=nil,nil,nil,nil,nil,nil,nil,nil
        button:Hide()
    end
end

local function renderObjectives(b,row,width,theme,hasItem,hasDetail)
    local ready=row.complete and not row.partyOnly
    local list=not ready and not row.partyOnly and call(Q.GetQuestObjectives,row.id)
    local offset=math.max(0,fontOffset())
    local top=hasDetail and 42 or 24
    local used,height,iconsUsed,hitsUsed=0,top+2*offset,0,0
    local function add(label,indent,r,g,blue)
        used=used+1
        local f=b.objectives[used]
        if not f then f=text(b,"GameFontHighlightSmall"); f:SetWordWrap(true);b.objectives[used]=f end
        local lineTop=height
        f:ClearAllPoints()
        f:SetWordWrap(true)
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
    local inlineMobSize=18
    local function addObjectiveMobIcon(name,overflow,x,y,vendor,sourceItem)
        iconsUsed=iconsUsed+1
        local icon=b.objectiveMobIcons[iconsUsed]
        if not icon then
            icon=CreateFrame("Button",nil,b)
            icon:SetSize(inlineMobSize,inlineMobSize)
            icon:RegisterForClicks("LeftButtonUp")
            icon:EnableMouse(true)
            icon:SetFrameLevel(b:GetFrameLevel()+2)
            icon.image=box(icon,"ARTWORK");icon.image:SetAllPoints(icon)
            icon.count=text(icon,"GameFontNormalSmall")
            icon.count:SetPoint("CENTER")
            wireObjectiveMobHover(icon,b)
            icon:SetScript("OnClick",function(self)
                if not objectiveMobIsCurrent(self,b) then return end
                hideObjectiveMobTip(self)
                if self.mobName and not self.vendorItem and not self.npcObjective then chooseQuestMob(self.mobName)
                elseif self.overflow and MenuUtil and MenuUtil.CreateContextMenu then
                    local qid,overflow=self.questId,self.overflow
                    MenuUtil.CreateContextMenu(self,function(_,root)
                        for _,mobName in ipairs(overflow) do
                            local exact=mobName
                            root:CreateButton(exact,function()
                                if b.qid==qid and (not b.IsVisible or b:IsVisible()) then chooseQuestMob(exact) end
                            end)
                        end
                    end)
                end
            end)
            b.objectiveMobIcons[iconsUsed]=icon
        end
        setObjectiveMob(icon,row.id,name,overflow,vendor,sourceItem)
        icon:ClearAllPoints();icon:SetPoint("TOPLEFT",b,"TOPLEFT",x,-y)
        icon.count:SetShown(overflow~=nil)
        if overflow then
            icon.count:SetText("+"..#overflow)
            if icon.renderKey~="more" then icon.image:SetColorTexture(.17,.22,.24,.96);icon.renderKey="more" end
            icon:SetWidth(#overflow>=10 and 22 or 18)
        else
            icon:SetWidth(inlineMobSize)
            paintMobIcon(icon,false)
        end
        icon:Show()
    end
    local function addObjectiveMobHit(label,name,indent,y,h,vendor,sourceItem)
        hitsUsed=hitsUsed+1
        local hit=b.objectiveMobHits[hitsUsed]
        if not hit then
            hit=CreateFrame("Button",nil,b)
            hit:RegisterForClicks("LeftButtonUp","RightButtonUp")
            hit:EnableMouse(true)
            hit:SetFrameLevel(b:GetFrameLevel()+2)
            wireObjectiveMobHover(hit,b)
            hit:SetScript("OnClick",function(self,key)
                if not objectiveMobIsCurrent(self,b) then return end
                hideObjectiveMobTip(self)
                if key=="RightButton" then openRowMenu(b)
                elseif self.mobName and not self.vendorItem and not self.npcObjective then chooseQuestMob(self.mobName) end
            end)
            b.objectiveMobHits[hitsUsed]=hit
        end
        setObjectiveMob(hit,row.id,name,nil,vendor,sourceItem)
        local cap=label:GetWidth()
        local pixels=call(label.GetStringWidth,label) or call(label.GetUnboundedStringWidth,label)
        local hitWidth=is(pixels,"number") and pixels>0 and math.min(cap,pixels+3) or cap
        hit:ClearAllPoints()
        hit:SetPoint("TOPLEFT",b,"TOPLEFT",vendor and 12 or 12+indent,-y)
        hit:SetSize(vendor and cap+indent or hitWidth,vendor and math.max(h,inlineMobSize) or h)
        hit:Show()
    end
    local function addObjectiveWithMobs(label,names,done,sourceItem)
        local stride=inlineMobSize+3
        local cap=math.max(90,width-(hasItem and 62 or 24))
        local cols=math.max(1,math.min(4,math.floor((cap-95)/stride)))
        local direct=#names
        local overflow
        if #names>math.min(3,cols) and cols>1 and MenuUtil and MenuUtil.CreateContextMenu then
            direct=math.min(3,cols-1)
            overflow={}
            for i=direct+1,#names do overflow[#overflow+1]=names[i] end
        end
        local units=direct+(overflow and 1 or 0)
        local indent=5+math.min(cols,units)*stride+(overflow and (#overflow>=10 and 7 or 3) or 0)
        local objective,y,h
        if done then objective,y,h=add(label,indent,.64,.78,.68)
        else objective,y,h=add(label,indent) end
        addObjectiveMobHit(objective,names[1],indent,y,h,nil,sourceItem)
        for i=1,direct do
            addObjectiveMobIcon(names[i],nil,12+(i-1)%cols*stride,y+math.floor((i-1)/cols)*stride,nil,sourceItem)
        end
        if overflow then addObjectiveMobIcon(nil,overflow,12+direct*stride,y) end
        height=math.max(height,y+math.ceil(units/cols)*stride+2)
    end
    local function addObjectiveWithNPC(label,name,npc,display,item,done,objectiveIndex)
        local indent=inlineMobSize+7
        local f,y,h
        label="(NPC)  "..label
        if done then f,y,h=add(label,indent,.64,.78,.68)
        else f,y,h=add(label,indent) end
        local vendor={item=item,npc=npc,display=display,objective=objectiveIndex}
        addObjectiveMobIcon(name,nil,12,y,vendor)
        addObjectiveMobHit(f,name,indent,y,h,vendor)
        height=math.max(height,y+inlineMobSize+3)
    end
    if ready then
        local map,x,y,npc,npcOnly=call(AT.GetReadyQuestTurnInPoint,row.id)
        local area,coords
        if id(map) and is(x,"number") and x>=0 and x<=1 and is(y,"number") and y>=0 and y<=1 then
            area=mapName(map)
            coords=string.format("%.1f, %.1f",x*100,y*100)
        end
        if not is(area,"string") or area=="" then area=nil end
        if not coords then area,npc,npcOnly=call(AT.GetReadyQuestTurnInArea,row.id) end
        if area or coords then add(area and coords and (area.."  |  "..coords) or area or coords,0) end
        if is(npc,"string") and npc~="" then
            local token=npcOnly==true and call(AT.GetRankQuestNPCMacro,npc)
            local label,lineTop,lineHeight=add(npc,0,.93,.74,.38)
            if npcOnly==true then
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
    local showParty=partyEnabled and inlineParty
    local missing,missingGUIDs,offered={}, {}, {}
    if showParty and not row.partyOnly and Share.value(Q.IsPushableQuest,row.id)==true then
        local uncertain
        missing,uncertain,offered=Share.missing(row.id,Share.roster())
        for _,member in ipairs(missing) do missingGUIDs[member.guid]=true end
        for _,member in ipairs(offered) do missingGUIDs[member.guid]=true end
    end
    local function partyLine(line,indent)
        if theme.minimal then add(line,indent,.56,.90,.87)
        else add(line,indent,.12,.35,.32) end
    end
    if is(list,"table") then
        for objectiveIndex,o in ipairs(list) do
            local label=field(o,"text")
            if is(label,"string") and label~="" then
                local kill=call(AT.GetQuestKillMobName,row.id,o,label)
                local item=objectiveDropItem(row.id,o,label)
                local vendor,npc,display=call(AT.GetQuestObjectiveVendor,row.id,item)
                if not vendor and AT.db.rankQuestDropRates~=false and item then
                    label=label..objectiveDropSuffix(row.id,item)
                end
                local done=field(o,"finished")==true
                local bullet=done and not theme.minimal and "|cff8bd1a2+|r " or ""
                local names=call(AT.GetQuestDropMobNames,item)
                local findNpc,findId,findDisplay
                if not item and not done then findNpc,findId,findDisplay=call(AT.GetQuestObjectiveNPC,row.id,o,label) end
                if vendor then addObjectiveWithNPC(label,vendor,npc,display,item,done)
                elseif findNpc then addObjectiveWithNPC(label,findNpc,findId,findDisplay,nil,done,objectiveIndex)
                elseif kill then addObjectiveWithMobs(bullet..label,{kill},done)
                elseif names and #names>0 then addObjectiveWithMobs(bullet..label,names,done,item)
                elseif done then add(bullet..label,0,.64,.78,.68)
                else add(bullet..label,0) end
            end
        end
    end
    if showParty and row.partyPending then
        for _,member in ipairs(row.party and row.party.members or {}) do
            local counts=member.counts or member.lastCounts
            local current,total=0,0
            for _,o in ipairs(counts or {}) do current,total=current+o.current,total+o.total end
            if total>current and not missingGUIDs[member.guid] then
                local qualifier=member.lastCounts and " (last reported)" or member.countsPartial and " (reported objectives)" or ""
                partyLine(member.name.."  "..current.."/"..total..qualifier,0)
            end
        end
    end
    for _,member in ipairs(offered) do partyLine(member.name.."  -  Offer pending",0) end
    if #offered>0 then
        for _,member in ipairs(missing) do add(member.name.."  -  Not on quest",0,1,.31,.29) end
        missing={} -- no group-wide retry while a prior recipient is deciding
    end
    b.partyShareButtons=b.partyShareButtons or {}
    for i,member in ipairs(missing) do
        local label,lineTop,lineHeight=add(member.name.."  -  Not on quest",0,1,.31,.29)
        if not theme.minimal then label:SetTextColor(.72,.16,.12) end
        label:SetWordWrap(false)
        local cap=math.max(70,label:GetWidth()-22)
        label:SetWidth(cap)
        local labelWidth=call(label.GetUnboundedStringWidth,label) or cap
        if not is(labelWidth,"number") then labelWidth=cap end
        local arrow=b.partyShareButtons[i]
        if not arrow then
            arrow=CreateFrame("Button",nil,b)
            arrow:RegisterForClicks("LeftButtonUp");arrow:EnableMouse(true)
            arrow:SetSize(18,18);arrow:SetFrameLevel(b:GetFrameLevel()+3)
            local icon=box(arrow,"ARTWORK");icon:SetAllPoints(arrow)
            icon:SetTexture("Interface\\AddOns\\NQT\\ShareArrow.tga")
            arrow:SetScript("OnEnter",function(self)
                if not self.memberName or not GameTooltip then return end
                GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:SetText("Offer quest to "..self.memberName)
                GameTooltip:AddLine("WoW shares with eligible party members.",.8,.88,.85,true);GameTooltip:Show()
            end)
            arrow:SetScript("OnLeave",function(self)
                if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
            end)
            arrow:SetScript("OnClick",function(self)
                if not (inlineParty and AT.db and AT.db.questPartyProgress~=false and self.questID==b.qid
                    and self.memberGUID and self:IsVisible()) then return end
                if shareJob then shareNotice("Stop or finish the bulk share first.");return end
                local title,name=self.questTitle,self.memberName
                local result=Share.attempt(self.questID,title,self.memberGUID)
                if result=="attempted" then shareNotice("Group offer attempted: "..title)
                elseif result=="wait" then shareNotice("Wait a moment before sending another offer.")
                elseif result=="pending" then shareNotice("A group offer for this quest is still pending.")
                elseif result=="stopped" then shareNotice("Sharing is unavailable during combat or outside a party.")
                elseif result=="blocked" then shareNotice("WoW blocked that share.")
                else shareNotice(name.." is no longer a verified recipient.") end
                AT.RefreshQuestHUD()
                Share.refresh()
            end)
            b.partyShareButtons[i]=arrow
        end
        arrow.questID,arrow.questTitle,arrow.memberGUID,arrow.memberName=row.id,row.title,member.guid,member.name
        arrow:ClearAllPoints()
        arrow:SetPoint("LEFT",label,"LEFT",math.min(cap,labelWidth)+4,0)
        arrow:Show()
        height=math.max(height,lineTop+math.max(18,lineHeight)+2)
    end
    for i=#missing+1,#b.partyShareButtons do
        local arrow=b.partyShareButtons[i]
        arrow.questID,arrow.questTitle,arrow.memberGUID,arrow.memberName=nil,nil,nil,nil
        if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(arrow) then GameTooltip:Hide() end
        arrow:Hide()
    end
    for i=used+1,#b.objectives do
        b.objectives[i]:Hide()
        b.objectives[i]:SetText("")
    end
    resetObjectiveMobButtons(b.objectiveMobIcons,iconsUsed+1)
    resetObjectiveMobButtons(b.objectiveMobHits,hitsUsed+1)
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
    local r,g,b=unpack(theme.minimal and theme.accent or theme.ink)
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

local function applyAtlas(region,atlas,useNativeSize)
    if not region.SetAtlas then return false end
    if C_Texture and C_Texture.GetAtlasInfo and not call(C_Texture.GetAtlasInfo,atlas) then return false end
    local ok,result=pcall(region.SetAtlas,region,atlas,useNativeSize)
    return ok and result~=false
end

local zoneMenuLayout={buttonFromTop=35,buttonHeight=20,gap=3,bottom=3}
local function arrangeZonesMenu(theme,offset,allZones)
    local menu=hud.zoneMenu
    menu:SetShown(popupOpen)
    if not popupOpen then
        for _,option in ipairs(hud.scopeRows) do option:Hide() end
        for _,option in ipairs(hud.zoneRows) do option:Hide() end
        return
    end
    local step=26+math.max(0,offset)
    local inner=214
    local function style(option,chosen,count)
        if not option.questCount then
            option.questCount=text(option,"GameFontNormalSmall")
            option.questCount:SetPoint("RIGHT",option,"RIGHT",-9,0)
            option.questCount:SetJustifyH("RIGHT")
            option.questCount:SetWordWrap(false)
        end
        applyTypography(option.questCount,theme,10,"GameFontHighlightSmall")
        option.questCount:SetTextColor(unpack(theme.accent))
        option.questCount:SetText(tostring(count))
        local measured=call(option.questCount.GetUnboundedStringWidth,option.questCount)
        local countWidth=math.max(28,is(measured,"number") and math.ceil(measured) or 0)
        option.questCount:SetWidth(countWidth)
        option.label:SetWidth(inner-26-countWidth)
        applyTypography(option.label,theme,10,"GameFontHighlightSmall")
        option.label:SetTextColor(unpack(theme.ink))
        color(option.fill,chosen and .28 or .13,chosen and .37 or .17,chosen and .31 or .21,.96)
        option:Show()
    end
    -- Match the quest-log total: count your held quests in both statuses,
    -- not party-only reminders. Deduplicate quest IDs across dungeon buckets.
    local function ownedCount(bucket,seen)
        local count=0
        for qid,entry in pairs(bucket and bucket.rows or {}) do
            if not entry.row.partyOnly and (not seen or not seen[qid]) then
                count=count+1
                if seen then seen[qid]=true end
            end
        end
        return count
    end
    local allDungeonCount,seenDungeons=0,{}
    for _,bucket in pairs(model.dungeons) do
        allDungeonCount=allDungeonCount+ownedCount(bucket,seenDungeons)
    end
    local counts={ownedCount(model.currentDungeon or model.zones[model.current]),model.total,allDungeonCount}
    local choices={not selectedDungeon and not viewedZone,allZones,selectedDungeon==ALL_DUNGEONS}
    for i,option in ipairs(hud.scopeRows) do
        option:ClearAllPoints()
        option:SetPoint("TOPLEFT",menu,"TOPLEFT",6,-6-(i-1)*step)
        option:SetSize(inner,step-3)
        style(option,choices[i],counts[i])
    end
    local zones,dungeons={},{}
    for key,bucket in pairs(model.zones) do
        if key~=model.current and next(bucket.rows) then zones[#zones+1]={key=key,name=bucket.name,count=ownedCount(bucket)} end
    end
    for key,bucket in pairs(model.dungeons) do
        if next(bucket.rows) then dungeons[#dungeons+1]={key=key,name=bucket.name,count=ownedCount(bucket)} end
    end
    local function alphabetical(a,b) return a.name==b.name and tostring(a.key)<tostring(b.key) or a.name<b.name end
    table.sort(zones,alphabetical)
    table.sort(dungeons,alphabetical)
    local y,used=0,0
    local function section(title,list,dungeon)
        title:ClearAllPoints();title:SetPoint("TOPLEFT",hud.zoneMenuContent,"TOPLEFT",7,-y-2)
        applyTypography(title,theme,10,"GameFontNormalSmall")
        title:SetTextColor(unpack(theme.accent));title:Show()
        y=y+step
        if #list==0 then
            local empty=dungeon and hud.noDungeons or hud.noZones
            empty:ClearAllPoints();empty:SetPoint("TOPLEFT",hud.zoneMenuContent,"TOPLEFT",12,-y-1)
            applyTypography(empty,theme,10,"GameFontDisableSmall");empty:Show()
            y=y+step
        end
        for _,entry in ipairs(list) do
            used=used+1
            local option=hud.zoneRows[used]
            if not option then
                option=button(hud.zoneMenuContent,"",0,0,inner,step-3,function(self)
                    if not popupOpen or self.choice==nil then return end
                    if self.isDungeon then hud.selectDungeon(self.choice)
                    elseif AT.BrowseQuestHUD then AT.BrowseQuestHUD(self.choice) end
                end)
                option.label:ClearAllPoints()
                option.label:SetPoint("LEFT",9,0);option.label:SetWordWrap(false)
                hud.zoneRows[used]=option
            end
            option.choice,option.isDungeon=entry.key,dungeon
            option:ClearAllPoints();option:SetPoint("TOPLEFT",hud.zoneMenuContent,"TOPLEFT",0,-y)
            option:SetSize(inner,step-3)
            option.label:SetText(entry.name)
            style(option,(dungeon and selectedDungeon or viewedZone)==entry.key,entry.count)
            y=y+step
        end
    end
    hud.noZones:Hide();hud.noDungeons:Hide()
    section(hud.zonesHeading,zones,false)
    section(hud.dungeonsHeading,dungeons,true)
    for i=used+1,#hud.zoneRows do local row=hud.zoneRows[i];row.choice=nil;row:Hide() end
    local top=12+3*step
    -- The menu is anchored just below Zones. Use only the available panel
    -- height; short lists end at their last row instead of leaving empty space.
    local menuInset=zoneMenuLayout.buttonFromTop+zoneMenuLayout.buttonHeight+zoneMenuLayout.gap
    local available=hud:GetHeight()-menuInset-zoneMenuLayout.bottom-top-6
    local height=math.max(1,math.min(y,available))
    hud.zoneMenuScroll:ClearAllPoints()
    hud.zoneMenuScroll:SetPoint("TOPLEFT",menu,"TOPLEFT",6,-top)
    hud.zoneMenuScroll:SetSize(inner,height)
    menu:SetHeight(top+height+6)
    setExtent(hud.zoneMenuScroll,hud.zoneMenuContent,y)
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
            local exactDungeon=prefix=="dungeon" and call(AT.ForeverDungeonForQuest,qid)==name
            local old=best[qid]
            if not old or exactDungeon and not old.exactDungeon
                or exactDungeon==old.exactDungeon and (hits>old.hits or (hits==old.hits and
                (rank>old.rank or (rank==old.rank and key<old.key)))) then
                best[qid]={key=key,name=name,hits=hits,rank=rank,exactDungeon=exactDungeon}
            end
        end
    end
    if scope~="all-dungeons" then
        for _,bucket in pairs(result.zones) do consider(bucket,"zone") end
    end
    for _,bucket in pairs(result.dungeons) do
        consider(bucket,"dungeon",50)
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
    if not hud or not model or call(AT.IsRankQuestItemLayoutLocked) then return end
    local activeID,source=call(AT.GetQuestNavigationID)
    local automaticTurnIn=source=="nearby-turn-in" and activeID or nil
    renderedNavigationID=activeID
    if automaticTurnIn~=visibleAutoTurnIn then
        completedView=automaticTurnIn~=nil
        resolveStatusOnSelection=false
        visibleAutoTurnIn=automaticTurnIn
    end
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
    hud.eyebrow:SetTextColor(unpack(a.accent))
    hud.eyebrow:SetText("Rank Quest")
    applyTypography(hud.zoneName,a,12,a.font)
    applyTypography(hud.search,a,12,a.font)
    applyTypography(hud.searchHint,a,12,a.font)
    local _,headerPoints=call(hud.zoneName.GetFont,hud.zoneName)
    local searchPoints=is(headerPoints,"number") and headerPoints or 12+fontOffset()
    hud.search:SetHeight(math.max(28,math.ceil(searchPoints)+12))
    if a.minimal then hud.searchHint:SetTextColor(.68,.73,.76)
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
    for _,control in ipairs({hud.palette,hud.statusFilter,hud.collapse,hud.smaller,hud.larger,hud.zoneButton,hud.guideButton,hud.tab}) do
        applyTypography(control.label,a,10,"GameFontHighlightSmall")
    end
    local paletteWidth=call(hud.palette.label.GetUnboundedStringWidth,hud.palette.label)
    hud.palette:SetWidth(is(paletteWidth,"number") and math.max(52,math.ceil(paletteWidth+14)) or (54+offset*4))
    local statusWidth=call(hud.statusFilter.label.GetUnboundedStringWidth,hud.statusFilter.label)
    local minimum=82+offset*4
    hud.statusFilter:SetWidth(is(statusWidth,"number") and math.max(minimum,math.ceil(statusWidth+14)) or minimum)
    local partyEnabled=not AT.db or AT.db.questPartyProgress~=false
    for _,control in ipairs({hud.palette,hud.statusFilter,hud.smaller,hud.larger,hud.zoneButton,hud.guideButton,hud.shareButton}) do
        control:SetShown(toolbarOpen)
    end
    hud.shareMenu:SetShown(toolbarOpen and shareOpen==true)
    if shareOpen then
        hud.cancelShares:SetShown(shareJob~=nil)
        hud.shareMenu:SetHeight(shareJob and 123 or 99)
    end
    hud.collapse:Show()
    hud.partyToggle:SetShown(toolbarOpen and partyEnabled)
    local titleWidth=hud:GetWidth()-13-10-24-8-hud.palette:GetWidth()-hud.statusFilter:GetWidth()
        -(partyEnabled and (hud.partyToggle:GetWidth()+4) or 0)-6
    local labelWidth=math.max(1,toolbarOpen and titleWidth or hud:GetWidth()-50)
    hud.eyebrow:SetWidth(labelWidth)
    -- When expanded, the drag/toggle surface ends before the first button.
    hud.header:SetWidth(labelWidth+13)
    color(hud.partyToggle.fill,inlineParty and .095 or .11,inlineParty and .45 or .17,inlineParty and .39 or .21,.96)
    hud.partyToggle.icon:SetAlpha(inlineParty and 1 or .67)
    applyTypography(hud.eyebrow,a,toolbarOpen and 10 or 18,toolbarOpen and "GameFontHighlightSmall" or a.font,not toolbarOpen)
    applyTypography(hud.count,a,10,"GameFontDisableSmall")
    applyTypography(hud.empty,a,10,"GameFontHighlightSmall")
    color(hud.zoneButton.fill,popupOpen and .23 or .11,popupOpen and .33 or .17,.21,.96)
    hud.scroll:ClearAllPoints()
    hud.scroll:SetPoint("TOPLEFT",hud.body,"TOPLEFT",13,-102+contentShift)
    hud.scroll:SetPoint("BOTTOMRIGHT",hud.body,"BOTTOMRIGHT",-13,15)
    local entries={}
    if itemSearchQuestID then
        for qid in pairs(itemSearchQuestID) do
            local row=model.rows[qid]
            if row and not row.partyOnly then entries[#entries+1]={row=row,kind="unassigned"} end
        end
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
    if automaticTurnIn and completedView and not searching and not viewedZone and not selectedDungeon then
        local row=model.rows[automaticTurnIn]
        if row and readyToTurnIn(row) and not (selected and selected.rows[automaticTurnIn]) then
            entries[#entries+1]={row=row,kind="unassigned"}
        end
    end
    table.sort(entries,function(a,b)
        local qa,qb=a.row,b.row
        local pa,pb=questSortPriority(qa,activeID),questSortPriority(qb,activeID)
        if pa~=pb then return pa<pb end
        local la,lb=questSortLevel(qa),questSortLevel(qb)
        if la~=lb then return la<lb end
        return qa.title==qb.title and qa.id<qb.id or qa.title<qb.title
    end)
    hud.shownZone=not allZones and selected and selected.key
    hud.zoneName:SetText(searching and "Search Results" or allZones and "All Zones" or (selected and selected.name or "Finding your zone"))
    local groupWord=(selectedDungeon or currentDungeonView) and "dungeon" or "zone"
    local emptyLabel=completedView and "No quests ready to turn in" or "No quests in progress"
    hud.empty:SetText(searching and "No matching quests." or (emptyLabel .. (allZones and "." or (" for this " .. groupWord .. "."))))
    hud.empty:SetShown(#entries==0)
    hud.empty:ClearAllPoints()
    hud.empty:SetPoint("TOPLEFT",hud.scroll,"TOPLEFT",11,-16)
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
            local keepInDungeonBranch=groupScope=="all-zones" and g.key:sub(1,8)=="dungeon:"
            for _,e in ipairs(g.entries) do
                if not keepInDungeonBranch and questSortPriority(e.row,activeID)<2 and not itemSearchQuestID then
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
            if groupScope=="all-zones" then
                local ap=a.entries[1] and questSortPriority(a.entries[1].row,activeID) or 2
                local bp=b.entries[1] and questSortPriority(b.entries[1].row,activeID) or 2
                if ap~=bp then return ap<bp end
            end
            local al=a.entries[1] and questSortLevel(a.entries[1].row) or math.huge
            local bl=b.entries[1] and questSortLevel(b.entries[1].row) or math.huge
            if al~=bl then return al<bl end
            local l,r=lowerSearch(a.name),lowerSearch(b.name)
            return l==r and a.key<b.key or l<r
        end)
        for _,g in ipairs(groups) do
            if #g.entries>0 then
                local key=groupScope..":"..g.key
                local isClosed=(itemSearchQuestID and itemSearchCollapsed and itemSearchCollapsed[key]==true)
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
                        itemSearchCollapsed[self.branchKey]=not itemSearchCollapsed[self.branchKey]
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
            local items=not q.partyOnly and questItemList(q.id,q.logIndex) or {}
            for i=1,math.max(#items,#b.itemTiles) do
                local tile=b.itemTiles[i] or makeQuestItemTile(b,i)
                b.itemTiles[i]=tile
                local selected=items[i]
                tile.link,tile.rankQuestIndex=selected and selected.link,q.logIndex
                tile:SetShown(selected~=nil)
                if selected then
                    tile.icon:SetTexture(selected.icon)
                    color(tile.border,unpack(a.accent))
                    applyTypography(tile.count,a,10,"GameFontNormalSmall")
                    tile.count:SetText(id(selected.count) and selected.count>1 and tostring(selected.count) or "")
                end
            end
            local link=b.item.link
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
            local marker=not q.partyOnly and highlights[q.id]
            if marker and marker.progress then
                color(b.fill,.26,.16,.035,.85)
            elseif marker and marker.area then
                color(b.fill,.035,.25,.23,.77)
            else color(b.fill,unpack(a.row)) end
            b.mark:SetShown(marker~=nil or not a.minimal)
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
                if marker.area=="near" and not q.complete then detail="Near an objective" end
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
                resetObjectiveMobButtons(b.objectiveMobIcons)
                resetObjectiveMobButtons(b.objectiveMobHits)
                for _,objective in ipairs(b.objectives) do objective:Hide();objective:SetText("") end
                rowHeight=link and 66 or (detail and 49 or 30+offset)
            else rowHeight=renderObjectives(b,q,width,a,link~=nil,detail~=nil) end
            if #items>0 then rowHeight=math.max(rowHeight,64+(#items-1)*33) end
            b:SetSize(width,rowHeight)
            yOffset=yOffset+rowHeight+3
            b:Show()
        end
    end
    hud.count:SetText(("%d/%d Quests"):format(shownOwned,model.total))
    for n=shownRows+1,#hud.rows do hud.rows[n].qid=nil;hud.rows[n].item.link=nil;hud.rows[n]:Hide() end
    for n=shownGroups+1,#hud.branches do hud.branches[n].branchKey=nil;hud.branches[n]:Hide() end
    setExtent(hud.scroll,hud.content,yOffset)
    arrangeZonesMenu(a,offset,allZones)
    if AT.SetRankQuestItemTargets then AT.SetRankQuestItemTargets(hud.rows,hud.scroll,verifiedQuestItem) end
end
local function browse(z)
    resolveStatusOnSelection=true
    viewedZone=z
    selectedDungeon=nil
    popupOpen=false
    if hud and not call(AT.IsRankQuestItemLayoutLocked) then hud.scroll:SetVerticalScroll(0) end
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

local partyPollCursor=0
local function countsChanged(a,b)
    if a==b then return false end
    if not a or not b or #a~=#b then return true end
    for i,o in ipairs(a) do
        local n=b[i]
        if o.current~=n.current or o.total~=n.total or o.desc~=n.desc then return true end
    end
    return false
end
local function partySnapshotChanged(a,b)
    if a==b then return false end
    if not a or not b or a.pending~=b.pending then return true end
    local am,bm=a.members or {},b.members or {}
    if #am~=#bm then return true end
    local previous={}
    for _,m in ipairs(am) do previous[m.guid or m.name or m.unit or false]=m end
    for _,m in ipairs(bm) do
        local p=previous[m.guid or m.name or m.unit or false]
        if not p or p.name~=m.name or p.status~=m.status or p.countsPartial~=m.countsPartial
            or countsChanged(p.counts,m.counts) or countsChanged(p.lastCounts,m.lastCounts) then return true end
    end
    return false
end
local function pollPartyChanges()
    if not AT.GetQuestPartySnapshot or call(AT.IsQuestPartyProgressActive)~=true then return false end
    local batch={}
    for qid,row in pairs(model.rows) do
        -- Already-complete rows need quick reconciliation when a teammate
        -- finishes. Poll ordinary in-progress rows in small rotating batches.
        if row.partyPending and (row.complete or row.partyOnly) then
            if partySnapshotChanged(row.party,call(AT.GetQuestPartySnapshot,qid)) then return true end
        else batch[#batch+1]=qid end
    end
    if #batch==0 then partyPollCursor=0;return false end
    table.sort(batch)
    for _=1,math.min(#batch,5) do
        partyPollCursor=partyPollCursor%#batch+1
        local qid=batch[partyPollCursor]
        if partySnapshotChanged(model.rows[qid].party,call(AT.GetQuestPartySnapshot,qid)) then return true end
    end
    return false
end

function AT.RefreshQuestHUD()
    if initialPaintPending or call(AT.IsRankQuestItemLayoutLocked) then return end
    if not hud then return end
    if not AT.db or not AT.db.enabled or not AT.db.questHUDEnabled then
        if AT.SetRankQuestItemTargets then AT.SetRankQuestItemTargets() end
        hud.search:ClearFocus()
        popupOpen,toolbarOpen,shareOpen=false,false,false; stopSharing(); if Share.window then Share.window:Hide() end; selectedDungeon=nil; hud:Hide(); observedObjectives,highlights,partyRetained,partyTurnedIn={},{},{},{}; stopQuestHover(); AT.SyncBlizzardQuestHUD(); return
    end
    local wasShown=hud:IsShown()
    local pos,name=playerZone()
    local _,dungeon,insideDungeon=playerDungeon(call(M and M.GetBestMapForUnit,"player"))
    local instanceKey=insideDungeon and (dungeon or true)
    if pos~=currentZone or instanceKey~=currentDungeon then
        currentZone,currentDungeon=pos,instanceKey
        if viewedZone~=ALL_ZONES then viewedZone=nil end
        popupOpen=false
        hud.zoneMenuScroll:SetVerticalScroll(0)
        hud.scroll:SetVerticalScroll(0)
    end
    local perf=AT.PerfBegin and AT.PerfBegin()
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
        popupOpen,toolbarOpen,shareOpen=false,false,false;stopQuestHover()
    end
    if not wasShown then
        hud:Show()
        if AT.SyncRankQuestItemButtons then AT.SyncRankQuestItemButtons() end
    end
    AT.SyncBlizzardQuestHUD()
    if perf then AT.PerfEnd("Rank Quest redraw",perf) end
end

function AT.SearchRankQuestItem(qid,itemLabel)
    if call(AT.IsRankQuestItemLayoutLocked) then return false end
    if not (hud and AT.db and AT.db.enabled~=false and AT.db.questHUDEnabled) then return false end
    local targets,count,only={},0,nil
    local list=id(qid) and {[qid]=true} or qid
    if not is(list,"table") then return false end
    for quest in pairs(list) do
        if id(quest) then targets[quest]=true;count=count+1;only=quest end
    end
    if count==0 then return false end
    local title
    if count==1 then
        local row=model and model.rows[only]
        title=call(Q and Q.GetTitleForQuestID,only)
        if not is(title,"string") or title=="" then title=row and row.title or ("Quest #"..only) end
    else
        title=is(itemLabel,"string") and itemLabel~="" and itemLabel or "Linked quests"
    end
    local search=hud.search
    AT.db.questHUDCollapsed=false
    itemSearchQuestID,settingItemSearch,itemSearchCollapsed=targets,true,{}
    search:SetText(title)
    settingItemSearch=nil
    search:ClearFocus()
    searchOpen=true
    popupOpen=false
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
        or (hud.zoneMenu:IsShown() and pointerOver(hud.zoneMenu))
        or (hud.shareMenu:IsShown() and pointerOver(hud.shareMenu))
    if toolbarOpen and not inside then
        toolbarOpen,popupOpen,shareOpen=false,false,false
        arrange()
    elseif popupOpen and not (containsMouse(hud.zoneMenu,target) or pointerOver(hud.zoneMenu)
        or containsMouse(hud.zoneButton,target) or pointerOver(hud.zoneButton)) then
        popupOpen=false
        arrange()
    end
    if shareOpen and not (containsMouse(hud.shareMenu,target) or pointerOver(hud.shareMenu)
        or containsMouse(hud.shareButton,target) or pointerOver(hud.shareButton)) then
        shareOpen=false;arrange()
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
    local function hideHeaderTip(self)
        if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end
    header:SetScript("OnEnter",function(self)
        if toolbarOpen or not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_CURSOR")
        GameTooltip:SetText("Click to show Settings")
        GameTooltip:Show()
    end)
    header:SetScript("OnLeave",hideHeaderTip)
    header:SetScript("OnHide",hideHeaderTip)
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
        if toolbarOpen then hideHeaderTip(header) end
        if not toolbarOpen then popupOpen,shareOpen=false,false end
        arrange()
    end)
    header:SetScript("OnDragStart",function()
        hideHeaderTip(header)
        dragged=true
        if AT.db.rankQuestLocked or call(AT.IsRankQuestItemLayoutLocked) then return end
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
        popupOpen=false
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
        popupOpen=false
        if hud.scroll and not call(AT.IsRankQuestItemLayoutLocked) then hud.scroll:SetVerticalScroll(0);arrange() end
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
        if call(AT.IsRankQuestItemLayoutLocked) then return end
        AT.db.questHUDCollapsed=not AT.db.questHUDCollapsed
        AT.RefreshQuestHUD()
    end
    local collapse=button(body,"−",0,0,24,20,toggle)
    collapse:ClearAllPoints();collapse:SetPoint("TOPRIGHT",-10,-12)
    hud.collapse=collapse
    local palette=button(body,"Map",0,0,68,20,function()
        local t=AT.db.questHUDTheme or 2
        AT.db.questHUDTheme=t%#themes+1
        popupOpen=false
        arrange()
    end)
    palette:ClearAllPoints();palette:SetPoint("RIGHT",collapse,"LEFT",-4,0)
    hud.palette=palette
    local statusFilter=button(body,"In Progress",0,0,82,20,function()
        completedView=not completedView
        preferredCompleted=completedView
        resolveStatusOnSelection=false
        if not call(AT.IsRankQuestItemLayoutLocked) then hud.scroll:SetVerticalScroll(0) end
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
        tip:SetText(inlineParty and "Hide party counts" or "Show party counts")
        tip:AddLine("Toggles compact counts on quest rows. Hover a quest for details.",.78,.89,.90,true)
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
    local zoneButton=button(body,"Zones",0,0,78,zoneMenuLayout.buttonHeight,function()
        popupOpen=not popupOpen
        shareOpen=false
        if popupOpen then
            if logCache and not logCache.full then logDirty=true end
            hud.zoneMenuScroll:SetVerticalScroll(0)
            AT.RefreshQuestHUD()
        else arrange() end
    end)
    zoneButton:ClearAllPoints();zoneButton:SetPoint("TOPRIGHT",body,"TOPRIGHT",-13,-zoneMenuLayout.buttonFromTop)
    zoneButton.label:ClearAllPoints();zoneButton.label:SetPoint("CENTER",-6,0)
    local chevron=text(zoneButton,"GameFontHighlightSmall")
    chevron:SetPoint("RIGHT",-7,0);chevron:SetText("▾")
    hud.zoneButton=zoneButton
    local guideButton=button(body,"",0,0,22,20,function()
        if popupOpen or shareOpen then popupOpen,shareOpen=false,false;arrange() end
        call(AT.ToggleLevelGuide)
    end)
    guideButton:ClearAllPoints();guideButton:SetPoint("RIGHT",zoneButton,"LEFT",-5,0)
    local guideIcon=guideButton:CreateTexture(nil,"ARTWORK")
    guideIcon:SetSize(15,15);guideIcon:SetPoint("CENTER")
    guideIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    guideIcon:SetTexCoord(.07,.93,.07,.93)
    guideButton:SetScript("OnEnter",function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_TOP")
        GameTooltip:SetText("Level Guide")
        GameTooltip:AddLine("Questing recommendations, zone levels and dungeons.",.83,.87,.86,true)
        GameTooltip:Show()
    end)
    guideButton:SetScript("OnLeave",function(self)
        if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    hud.guideButton=guideButton
    local shareButton=button(body,"",0,0,22,20,function()
        if not toolbarOpen then return end
        shareOpen=not shareOpen
        popupOpen=false
        arrange()
    end)
    shareButton:ClearAllPoints();shareButton:SetPoint("RIGHT",guideButton,"LEFT",-4,0)
    local shareIcon=shareButton:CreateTexture(nil,"ARTWORK")
    shareIcon:SetSize(17,17);shareIcon:SetPoint("CENTER")
    shareIcon:SetTexture("Interface\\AddOns\\NQT\\ShareArrow.tga")
    shareButton:SetScript("OnEnter",function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:SetText("Share Quests")
        GameTooltip:AddLine("Offer quests to your current party.",.82,.89,.83,true);GameTooltip:Show()
    end)
    shareButton:SetScript("OnLeave",function(self)
        if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    hud.shareButton=shareButton
    local shareMenu=CreateFrame("Frame",nil,body)
    shareMenu:SetSize(192,99);shareMenu:SetPoint("TOPRIGHT",shareButton,"BOTTOMRIGHT",0,-3)
    shareMenu:SetClampedToScreen(true);shareMenu:EnableMouse(true);shareMenu:SetFrameStrata("HIGH")
    if shareMenu.SetFrameLevel and body.GetFrameLevel then shareMenu:SetFrameLevel(body:GetFrameLevel()+14) end
    local shareBack=box(shareMenu);shareBack:SetAllPoints(shareMenu);color(shareBack,.033,.043,.048,.98)
    hud.shareMenu=shareMenu
    local function shareChoice(title,y,action)
        local choice=button(shareMenu,title,5,y,182,20,function()
            if not shareOpen then return end
            shareOpen=false;arrange()
            action()
        end)
        choice:RegisterForClicks("LeftButtonUp")
        choice.label:ClearAllPoints();choice.label:SetPoint("LEFT",9,0)
        return choice
    end
    shareChoice("Share All Quests",-5,function() shareQuests("all") end)
    shareChoice("Share Zone Quests",-28,function() shareQuests("zone") end)
    shareChoice("Share All Dungeon Quests",-51,function() shareQuests("dungeons") end)
    shareChoice("Share Verify",-74,Share.open)
    hud.cancelShares=shareChoice("Stop Sharing",-97,function() stopSharing("Sharing cancelled") end)
    shareMenu:Hide()
    more:ClearAllPoints();more:SetPoint("RIGHT",shareButton,"LEFT",-4,0)
    less:ClearAllPoints();less:SetPoint("RIGHT",more,"LEFT",-4,0)
    for _,control in ipairs({collapse,palette,statusFilter,partyToggle,less,more,shareButton,guideButton,zoneButton}) do
        control:RegisterForClicks("LeftButtonUp")
        if control.SetFrameLevel and header.GetFrameLevel then control:SetFrameLevel(header:GetFrameLevel()+2) end
    end
    local menu=CreateFrame("Frame",nil,body)
    menu:SetSize(226,120);menu:SetPoint("TOPRIGHT",zoneButton,"BOTTOMRIGHT",0,-zoneMenuLayout.gap)
    menu:EnableMouse(true)
    menu:SetClampedToScreen(true)
    menu:SetFrameStrata("HIGH")
    if menu.SetFrameLevel and body.GetFrameLevel then menu:SetFrameLevel(body:GetFrameLevel()+13) end
    local menuBack=box(menu);menuBack:SetAllPoints(menu);color(menuBack,.033,.043,.048,.98)
    local menuScroll=wheelFrame(menu,48)
    local menuContent=CreateFrame("Frame",nil,menuScroll)
    menuContent:SetSize(214,2);menuScroll:SetScrollChild(menuContent)
    hud.zoneMenu,hud.zoneMenuScroll,hud.zoneMenuContent,hud.zoneRows=menu,menuScroll,menuContent,{}
    hud.selectDungeon=function(key)
        viewedZone,selectedDungeon,popupOpen=nil,key,false
        resolveStatusOnSelection=true
        if not call(AT.IsRankQuestItemLayoutLocked) then hud.scroll:SetVerticalScroll(0) end
        arrange()
    end
    hud.scopeRows={}
    local function scope(i,title,callback)
        local row=button(menu,title,6,-6,214,23,callback)
        row.label:ClearAllPoints();row.label:SetPoint("LEFT",9,0);row.label:SetWordWrap(false)
        row:Hide()
        hud.scopeRows[i]=row
    end
    scope(1,"Current Zone",function() if popupOpen then browse(nil) end end)
    scope(2,"All Zones",function() if popupOpen then browse(ALL_ZONES) end end)
    scope(3,"All Dungeons",function() if popupOpen then hud.selectDungeon(ALL_DUNGEONS) end end)
    hud.zonesHeading=text(menuContent,"GameFontNormalSmall");hud.zonesHeading:SetText("ZONES")
    hud.dungeonsHeading=text(menuContent,"GameFontNormalSmall");hud.dungeonsHeading:SetText("DUNGEONS")
    hud.noZones=text(menuContent,"GameFontDisableSmall");hud.noZones:SetText("No other zones")
    hud.noDungeons=text(menuContent,"GameFontDisableSmall");hud.noDungeons:SetText("No dungeon quests")
    menu:Hide()
    hud.tab=button(hud,"Rank Quest  +",0,0,116,24,toggle)
    hud.tab:ClearAllPoints();hud.tab:SetPoint("TOPRIGHT",hud,"TOPRIGHT",0,0)
    hud.scroll=wheelFrame(body,66,true)
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
        if AT.db.rankQuestLocked or call(AT.IsRankQuestItemLayoutLocked) then return end
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
        "QUEST_WATCH_UPDATE","BAG_UPDATE_DELAYED","GET_ITEM_INFO_RECEIVED","ITEM_DATA_LOAD_RESULT","GROUP_ROSTER_UPDATE","QUEST_DATA_LOAD_RESULT","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","PLAYER_LEVEL_UP","PLAYER_MAP_CHANGED","ZONE_CHANGED","ZONE_CHANGED_INDOORS","ZONE_CHANGED_NEW_AREA","SUPER_TRACKING_CHANGED","GLOBAL_MOUSE_DOWN","CHAT_MSG_SYSTEM","UI_ERROR_MESSAGE","UNIT_QUEST_LOG_CHANGED","PLAYER_TARGET_CHANGED","UNIT_PORTRAIT_UPDATE"}) do
        pcall(watcher.RegisterEvent,watcher,event)
    end
    watcher:SetScript("OnEvent",function(_,event,first,second)
        if event=="PLAYER_TARGET_CHANGED" or event=="UNIT_PORTRAIT_UPDATE" then
            if event=="PLAYER_TARGET_CHANGED" or (ordinary(first) and first=="target") then AT.RefreshRankQuestMobPortraits() end
            return
        end
        if event=="GLOBAL_MOUSE_DOWN" then releaseOnOutsideClick();return end
        if event=="ITEM_DATA_LOAD_RESULT" and (not id(first) or not pendingItemData or not pendingItemData[first]) then return end
        if event=="BAG_UPDATE_DELAYED" or event=="GET_ITEM_INFO_RECEIVED" or event=="ITEM_DATA_LOAD_RESULT"
            or event=="QUEST_LOG_UPDATE" or event=="QUEST_ACCEPTED" or event=="QUEST_REMOVED"
            or event=="QUEST_TURNED_IN" or event=="PLAYER_ENTERING_WORLD" then
            questBagActions=nil
        end
        if event=="CHAT_MSG_SYSTEM" or event=="UI_ERROR_MESSAGE" then
            Share.feedback(event=="CHAT_MSG_SYSTEM" and first or second);return
        end
        if event=="GROUP_ROSTER_UPDATE" then
            local key=Share.key(Share.roster())
            if key~=Share.groupKey then
                Share.groupKey=key;Share.pending={};Share.rejected={};Share.feedbackFor=nil
                stopSharing("Sharing stopped because the party changed")
            end
        elseif event=="PLAYER_REGEN_DISABLED" or event=="PLAYER_ENTERING_WORLD" then
            Share.feedbackFor=nil;stopSharing("Sharing stopped because combat started or the instance changed")
        end
        if event=="GROUP_ROSTER_UPDATE" or event=="UNIT_QUEST_LOG_CHANGED" then Share.refresh() end
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
            AT.char.zoneQuestOrigins[first]=nil
        end
        pushRefresh()
    end)
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(1.4,function()
            if not AT.db or not AT.db.enabled or not AT.db.questHUDEnabled or not model then return end
            Share.refresh()
            local _,dungeon,insideDungeon=playerDungeon(call(M and M.GetBestMapForUnit,"player"))
            if playerZone()~=currentZone or (insideDungeon and (dungeon or true))~=currentDungeon
                or pollPartyChanges() then AT.RefreshQuestHUD()
            elseif not AT.db.questHUDCollapsed then
                local changed=refreshHighlights(false)
                local activeID,source=call(AT.GetQuestNavigationID)
                if changed or renderedNavigationID~=activeID or visibleAutoTurnIn~=(source=="nearby-turn-in" and activeID or nil) then arrange() end
            end
        end)
    end
    -- Coalesce the initial layout with the login event burst instead of
    -- repeatedly repainting partially loaded data on unconditional timers.
    initialPaintPending=true
    AT.SyncBlizzardQuestHUD()
    pushRefresh()
end
