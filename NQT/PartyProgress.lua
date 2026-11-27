local _,AT=...
local cache,pending={},{}
local LAST_KNOWN_SECONDS=45
local function ordinary(v) return not issecretvalue or not issecretvalue(v) end
local function is(v,t) return ordinary(v) and type(v)==t end
local function field(t,k)
    if is(t,"table") then local v=t[k];if ordinary(v) then return v end end
end
local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b=pcall(fn,...);if ok then return a,b end
end
local function number(v)
    return is(v,"number") and v>=0 and v<math.huge
end
local function eq(a,v)
    return ordinary(a) and a==v
end
function AT.IsQuestPartyProgressActive()
    return (not AT.db or AT.db.questPartyProgress~=false) and eq(call(IsInGroup),true) and not eq(call(IsInRaid),true)
end

local function partyRoster()
    local roster={}
    if not AT.IsQuestPartyProgressActive() then return roster end
    local count=call(GetNumSubgroupMembers)
    if not number(count) then return roster end
    for i=1,math.min(count,4) do
        local unit="party"..i
        local guid=call(UnitGUID,unit)
        local name=call(GetUnitName,unit,true)
        if not is(name,"string") then name=call(UnitName,unit) end
        if is(guid,"string") and is(name,"string") and guid~="" and name~="" then
            local member={unit=unit,guid=guid,name=name,offline=eq(call(UnitIsConnected,unit),false)}
            roster[#roster+1]=member
        end
    end
    return roster
end

local function plain(v)
    if not is(v,"string") then return end
    return v:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):match("^%s*(.-)%s*$")
end

-- Some native tooltip rows report their progress in the displayed columns.
-- Only accept an unambiguous integer current/total on a typed quest objective.
local function objective(line)
    local current,total=field(line,"numFulfilled"),field(line,"numRequired")
    local desc=plain(field(line,"leftText")) or plain(field(line,"text"))
    if number(current) and number(total) and total>0 and current<=total then
        return current,total,desc
    end
    local right=plain(field(line,"rightText"))
    local label,a,b
    if right then a,b=right:match("^(%d+)%s*/%s*(%d+)$") end
    local la,lb
    if desc then
        label,la,lb=desc:match("^(.-)%s*%((%d+)%s*/%s*(%d+)%)$")
        if not la then label,la,lb=desc:match("^(.-)[%s:](%d+)%s*/%s*(%d+)$") end
        if not la then la,lb=desc:match("^(%d+)%s*/%s*(%d+)$");if la then label="" end end
        if label and (label:find("%d%s*/%s*%d") or label:find("/%s*$")) then return end
    end
    if a and la and (tonumber(a)~=tonumber(la) or tonumber(b)~=tonumber(lb)) then return end
    current,total=tonumber(a or la),tonumber(b or lb)
    if number(current) and number(total) and total>0 and current<=total then
        if la then desc=label:gsub("[%s:(]+$","") end
        return current,total,desc
    end
end

local function parse(qid,roster)
    local types=Enum and Enum.TooltipDataLineType
    if not types or not C_TooltipInfo then return {} end
    local byGUID,byName={},{}
    for _,m in ipairs(roster) do
        byGUID[m.guid]=m
        byName[m.name]=byName[m.name]==nil and m or false
    end
    -- Use the same mode as the stock hover and ignore the local row by GUID.
    local myGUID=call(UnitGUID,"player")
    local data=call(C_TooltipInfo.GetQuestPartyProgress,qid,false,false)
    local lines=field(data,"lines")
    local parsed,active={},nil
    if not is(lines,"table") then return parsed end
    local sameQuest=true -- response already scoped to this quest ID
    for i=1,math.min(#lines,160) do
        local line=lines[i]
        local kind=field(line,"type")
        if kind==nil then active=nil
        else
            if kind==types.QuestTitle then
                local namedID=field(line,"id")
                sameQuest=namedID==nil or namedID==qid
                active=nil
            elseif kind==types.QuestPlayer then
                local guid=field(line,"guid")
                active=nil
                local member
                if is(guid,"string") and guid~="" then
                    member=byGUID[guid]
                elseif not is(myGUID,"string") or not eq(field(line,"guid"),myGUID) then
                    local name=plain(field(line,"leftText"))
                    if name then member=byName[name] end
                end
                if sameQuest and member then
                    active=parsed[member.guid] or {counts={},hasUnknown=false}
                    parsed[member.guid]=active
                end
            elseif sameQuest and kind==types.QuestObjective and active then
                local current,total,desc=objective(line)
                if number(current) and number(total) and total>0 and current<=total then
                    active.counts[#active.counts+1]={current=current,total=total,desc=is(desc,"string") and desc or nil}
                    if current<total then active.needs=true end
                else
                    active.hasUnknown=true
                end
            end
        end
    end
    if active and #lines>160 then active.hasUnknown=true end
    return parsed
end


local PREFIX="NQTQuestState1"
local remote,outbound,departed={},{},{}
local nativeDone,waitingForNativeReset={},{}
local sentFor,queuedRefresh,queuedBagScan,queuedCompleteScan
local function questID(v) return number(v) and v>0 and v<=99999999 and v%1==0 end

local function groupChannel()
    if LE_PARTY_CATEGORY_INSTANCE and eq(call(IsInGroup,LE_PARTY_CATEGORY_INSTANCE),true) then
        return "INSTANCE_CHAT"
    end
    return "PARTY"
end

local function senderKey(name,realm)
    if not is(name,"string") or name=="" then return end
    if not name:find("-",1,true) then
        if not is(realm,"string") or realm=="" then realm=call(GetNormalizedRealmName) end
        if is(realm,"string") and realm~="" then name=name.."-"..realm end
    end
    return name:gsub("%s",""):lower()
end

local function refreshAfterMessage()
    if queuedRefresh then return end
    local function refresh()
        queuedRefresh=nil
        if AT.RefreshQuestHUD then AT.RefreshQuestHUD() end
    end
    if C_Timer and C_Timer.After then queuedRefresh=true;C_Timer.After(0,refresh)
    else refresh() end
end

local function activeSync()
    return AT.IsQuestPartyProgressActive() and (not AT.db or AT.db.enabled~=false)
end

-- P carries only objective slots and counts; never send names or chat text.
local function decodeProgress(payload)
    local raw,partial,needs,entries=payload:match("^P:(%d+):([01])([01]):([%d/,]+)$")
    local qid=tonumber(raw)
    if not questID(qid) then return end
    local counts,previous={},0
    for index,a,b in entries:gmatch("(%d+)/(%d+)/(%d+),") do
        index,a,b=tonumber(index),tonumber(a),tonumber(b)
        if index<=previous or index>12 or b<1 or b>100000 or a>b or (a<b and needs=="0") then return end
        counts[#counts+1]={index=index,current=a,total=b}
        previous=index
    end
    if #counts==0 then return end
    local canonical={}
    for i,o in ipairs(counts) do canonical[i]=o.index.."/"..o.current.."/"..o.total.."," end
    if table.concat(canonical)~=entries then return end
    return qid,{counts=counts,hasUnknown=partial=="1",needs=needs=="1"}
end

local function completeReport(data)
    return data and not data.needs and not data.hasUnknown and #data.counts>0
end

local function coversSharedObjectives(data,shared)
    if not completeReport(data) or #data.counts<#shared.counts then return false end
    if shared.hasUnknown and #data.counts<=#shared.counts then return false end
    for _,o in ipairs(shared.counts) do
        local row=data.counts[o.index]
        if not row or row.total~=o.total then return false end
    end
    return true
end

local function receive(payload,channel,sender)
    if not activeSync() or not is(payload,"string") or #payload>220 or not eq(channel,groupChannel()) then return end
    local state,raw=payload:match("^([DLO]):(%d+)$")
    local qid=tonumber(raw)
    if not state then qid,state=decodeProgress(payload) end
    if not state or not questID(qid) then return end
    local incoming=senderKey(sender)
    if not incoming then return end
    local match
    for _,member in ipairs(partyRoster()) do
        local name,realm=call(UnitFullName,member.unit)
        if not member.offline and senderKey(is(name,"string") and name or member.name,realm)==incoming then
            if match then return end
            match=member
        end
    end
    if not match then return end
    local guid=match.guid
    local states=remote[guid]
    local previous=states and states[qid]
    if is(state,"table") then
        if is(previous,"table") and previous.wire==payload then return end
        state.wire=payload
    end
    local seenDone=nativeDone[guid]
    if state=="O" or is(state,"table") then
        -- Explicit restart/regression beats a completed native snapshot from the previous pass.
        if previous=="D" or previous=="L" or (seenDone and seenDone[qid]) then
            if not waitingForNativeReset[guid] then waitingForNativeReset[guid]={} end
            waitingForNativeReset[guid][qid]=true
        end
        if seenDone then seenDone[qid]=nil end
    end
    if state=="O" then
        if states then states[qid]=nil end
    else
        if not states then states={};remote[guid]=states end
        if states[qid]==nil then
            local n=0;for _ in pairs(states) do n=n+1 end
            if n>=128 then return end
        end
        states[qid]=state
    end
    if pending[qid] then pending[qid][guid]=nil end
    cache[qid]=nil
    refreshAfterMessage()
end

local function announce(qid,state,progress)
    if not questID(qid) then return end
    local payload=state..":"..qid..(progress and (":"..progress) or "")
    if #payload>220 or outbound[qid]==payload then return end
    local result=call(C_ChatInfo.SendAddonMessage,PREFIX,payload,groupChannel())
    local success=Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success
    if eq(result,true) or eq(result,0) or (success~=nil and eq(result,success)) then outbound[qid]=payload end
end

local function encodeProgress(objectives)
    if not is(objectives,"table") then return end
    local counts,partial,needs={},#objectives>12,false
    for i=1,math.min(#objectives,12) do
        local entry=objectives[i]
        local current,total=objective(entry)
        if eq(field(entry,"finished"),false) then needs=true end
        if number(current) and number(total) and current%1==0 and total%1==0 and total<=100000 then
            counts[#counts+1]=i.."/"..current.."/"..total..","
            if current<total then needs=true end
        else
            partial=true
        end
    end
    if #counts>0 then return (partial and "1" or "0")..(needs and "1" or "0")..":"..table.concat(counts) end
end

local function rosterChanged()
    local seen,keys={},{}
    for _,member in ipairs(partyRoster()) do
        if not member.offline then seen[member.guid]=true;keys[#keys+1]=member.guid end
    end
    for _,store in ipairs({remote,nativeDone,waitingForNativeReset}) do
        for guid in pairs(store) do if not seen[guid] then store[guid]=nil end end
    end
    for qid,states in pairs(pending) do
        for guid in pairs(states) do if not seen[guid] then states[guid]=nil end end
        if not next(states) then pending[qid]=nil end
    end
    table.sort(keys)
    local signature=groupChannel().."|"..table.concat(keys,"|")
    if signature~=sentFor then
        sentFor=signature
        outbound={}
        cache={}
    end
end

local function scanLocal(specificQuest)
    local q=C_QuestLog
    if not q then return end
    local function check(qid)
        if questID(qid) and not departed[qid] then
            local ready=call(AT.IsQuestReadyForTurnIn or q.ReadyForTurnIn,qid)
            if eq(ready,true) or eq(ready,1) then
                announce(qid,"D")
            else
                local objectives=call(q.GetQuestObjectives,qid)
                local progress=encodeProgress(objectives)
                if progress and progress:sub(2,2)=="1" then
                    announce(qid,"P",progress)
                elseif outbound[qid]=="D:"..qid and is(objectives,"table") then
                    -- A previously complete objective can regress even without numeric progress.
                    for _,entry in ipairs(objectives) do
                        if eq(field(entry,"finished"),false) then announce(qid,"O");break end
                    end
                end
            end
        end
    end
    if questID(specificQuest) then check(specificQuest);return end
    local count=call(q.GetNumQuestLogEntries)
    if not number(count) then return end
    for i=1,math.min(count,1000) do
        local info=call(q.GetInfo,i)
        if not eq(field(info,"isHeader"),true) then check(field(info,"questID")) end
    end
end

local function onSyncEvent(_,event,a,b,c,d)
    if not activeSync() then
        AT.ClearRankQuestPartyProgress()
        return
    end
    if event=="CHAT_MSG_ADDON" then
        if eq(a,PREFIX) then receive(b,c,d) end
    elseif event=="QUEST_TURNED_IN" or event=="QUEST_REMOVED" then
        if questID(a) then departed[a]=true;announce(a,"L") end
    elseif event=="QUEST_ACCEPTED" then
        local qid=questID(b) and b or a
        if questID(qid) then departed[qid]=nil;announce(qid,"O") end
    elseif event=="QUEST_COMPLETE" then
        -- This event can be a quest dialog; only announce after the quest log confirms ready.
        scanLocal()
        if not queuedCompleteScan and C_Timer and C_Timer.After then
            queuedCompleteScan=true
            C_Timer.After(.2,function()
                queuedCompleteScan=nil
                if activeSync() then scanLocal() end
            end)
        end
    elseif event=="BAG_UPDATE_DELAYED" and C_Timer and C_Timer.After then
        -- Allow the quest log to catch up with the changed bag contents.
        if not queuedBagScan then
            queuedBagScan=true
            C_Timer.After(.2,function()
                queuedBagScan=nil
                if activeSync() then scanLocal() end
            end)
        end
    else
        if event=="PLAYER_ENTERING_WORLD" or event=="GROUP_ROSTER_UPDATE" then rosterChanged() end
        scanLocal(event=="QUEST_WATCH_UPDATE" and a or nil)
    end
end

function AT.InitQuestPartySync()
    if not C_ChatInfo or type(C_ChatInfo.SendAddonMessage)~="function"
        or not eq(call(C_ChatInfo.RegisterAddonMessagePrefix,PREFIX),true) then return end
    local frame=CreateFrame("Frame")
    for _,event in ipairs({"CHAT_MSG_ADDON","GROUP_ROSTER_UPDATE","PLAYER_ENTERING_WORLD",
        "QUEST_LOG_UPDATE","QUEST_WATCH_UPDATE","BAG_UPDATE_DELAYED","QUEST_COMPLETE","QUEST_TURNED_IN","QUEST_REMOVED","QUEST_ACCEPTED"}) do
        pcall(frame.RegisterEvent,frame,event)
    end
    frame:SetScript("OnEvent",onSyncEvent)
    onSyncEvent(frame,"GROUP_ROSTER_UPDATE")
end

function AT.ClearRankQuestPartyProgress()
    cache,pending,remote,outbound,departed={},{},{},{},{}
    nativeDone,waitingForNativeReset={},{}
    sentFor=nil
end

function AT.GetQuestPartySnapshot(qid,force)
    if not number(qid) or qid<=0 then return end
    local roster=partyRoster()
    if #roster==0 then AT.ClearRankQuestPartyProgress(); return end
    local keys={}
    for i,m in ipairs(roster) do keys[i]=m.guid..(m.offline and "-" or "+") end
    local membership=table.concat(keys,"|")
    local now=call(GetTime)
    local oldCache=cache[qid]
    if not force and number(now) and oldCache and oldCache.membership==membership and now-oldCache.time<.55 then return oldCache.value end
    local reported=parse(qid,roster)
    local remembered=pending[qid] or {}
    local nextPending={}
    local snapshot={members=roster}
    local localObjectives
    for _,member in ipairs(roster) do
        local shared=remote[member.guid] and remote[member.guid][qid]
        local liveCounts=is(shared,"table")
        local native=reported[member.guid]
        local seenDone=nativeDone[member.guid]
        local blocked=waitingForNativeReset[member.guid]
        if blocked and blocked[qid] and native and native.needs then blocked[qid]=nil end
        local mayUseNative=not (blocked and blocked[qid])
        local nativeCompletes=liveCounts and mayUseNative and coversSharedObjectives(native,shared)
        if nativeCompletes and not member.offline then
            if not seenDone then seenDone={};nativeDone[member.guid]=seenDone end
            seenDone[qid]=true
        end
        local data=liveCounts and shared or (mayUseNative and native or nil)
        if member.offline then
            member.status="Offline"
        elseif not liveCounts and shared then
            snapshot.hasSharedResolution=true
            member.status=shared=="D" and "Objectives complete" or "No longer on this quest"
        elseif liveCounts and seenDone and seenDone[qid] then
            -- An old addon progress packet must not hold the HUD after the client sees completion.
            snapshot.hasSharedResolution=true
            member.counts=nativeCompletes and native.counts or nil
            member.status="Objectives complete"
        elseif data and data.needs then
            if liveCounts then
                snapshot.hasSharedResolution=true -- render fresh rows, not the stock tooltip
                if localObjectives==nil then
                    localObjectives=(C_QuestLog and call(C_QuestLog.GetQuestObjectives,qid)) or false
                end
                local counts={}
                for i,o in ipairs(data.counts) do
                    local entry=field(localObjectives,o.index)
                    local _,total,desc=objective(entry)
                    if desc then
                        -- Do not copy the receiver's own count into another player's label.
                        desc=desc:gsub("^%s*%d+%s*/%s*%d+[%s:]+","")
                            :gsub("[%s:]+%d+%s*/%s*%d+%s*$","")
                        if desc=="" or desc:match("^%d+%s*/%s*%d+$") then desc=nil end
                    end
                    counts[i]={current=o.current,total=o.total,
                        desc=total==o.total and desc or "Objective "..o.index}
                end
                data={counts=counts,hasUnknown=data.hasUnknown}
            end
            member.counts=data.counts
            member.countsPartial=data.hasUnknown
            if number(now) then nextPending[member.guid]={counts=data.counts,partial=data.hasUnknown,at=now} end
            snapshot.verifiedPending=true
        elseif data and #data.counts>0 and not data.hasUnknown then
            member.counts=data.counts
            member.status="Objectives complete"
        else
            local onQuest=C_QuestLog and call(C_QuestLog.IsUnitOnQuest,member.unit,qid)
            local visible=eq(call(UnitIsVisible,member.unit),true)
            if eq(onQuest,false) and visible then
                member.status="Not on this quest"
            elseif remembered[member.guid] and number(now) and now-remembered[member.guid].at<=LAST_KNOWN_SECONDS then
                member.lastCounts=remembered[member.guid].counts
                member.countsPartial=remembered[member.guid].partial
                nextPending[member.guid]=remembered[member.guid]
                snapshot.lastPending=true
                member.status="Current progress unavailable; last reported:"
            else
                member.status="Progress unavailable"
            end
        end
    end
    pending[qid]=next(nextPending) and nextPending or nil
    snapshot.pending=snapshot.verifiedPending or snapshot.lastPending or false
    if number(now) then cache[qid]={time=now,membership=membership,value=snapshot} end
    return snapshot
end

function AT.TrimRankQuestPartyProgress(held)
    for qid in pairs(cache) do if not held[qid] then cache[qid]=nil end end
    for qid in pairs(pending) do if not held[qid] then pending[qid]=nil end end
    for _,store in ipairs({nativeDone,waitingForNativeReset}) do
        for guid,entries in pairs(store) do
            for qid in pairs(entries) do if not held[qid] and not (remote[guid] and remote[guid][qid]) then entries[qid]=nil end end
            if not next(entries) then store[guid]=nil end
        end
    end
end

-- Visible party announcements are independent of the addon-to-addon sync.
do
    local Q=C_QuestLog
    local prior,departed,queue={},{},{}
    local active,scanPending,sendPending
    local function id(v) return number(v) and v>0 and v%1==0 end
    local function partyChat()
        if not AT.db or AT.db.enabled==false or AT.db.rankQuestPartyAnnouncements~=true
            or not eq(call(IsInGroup),true) or not eq(call(IsInRaid),false) then return nil end
        return C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    end
    local function cleanChatText(text)
        if not is(text,"string") then return end
        text=text:gsub("|H.-|h(.-)|h","%1"):gsub("|[TA].-|[ta]","")
            :gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
            :gsub("[%c|{}]"," "):gsub("%s+"," "):match("^%s*(.-)%s*$")
        if text~="" then return text end
    end
    local function clip(text,max)
        if #text<=max then return text end
        local cut=max-3
        while cut>0 and text:byte(cut+1)>=128 and text:byte(cut+1)<192 do cut=cut-1 end
        return text:sub(1,cut).."..."
    end
    local function reset()
        prior,departed,queue={},{},{}
        active,scanPending,sendPending=nil,nil,nil
    end
    local function sendNext()
        local send=partyChat()
        if type(send)~="function" then reset();return end
        local message=table.remove(queue,1)
        if not message then return end
        call(send,message,"PARTY")
        -- Space out simultaneous completions; never resend an attempted message.
        if C_Timer and C_Timer.After and not sendPending then
            local ticket={}
            sendPending=ticket
            C_Timer.After(1,function()
                if sendPending~=ticket then return end
                sendPending=nil;sendNext()
            end)
        end
    end
    local function observe(qid,allow,title)
        if not id(qid) or departed[qid] or eq(call(Q.IsOnQuest,qid),false) then return end
        local list=call(Q.GetQuestObjectives,qid)
        if not is(list,"table") then return end
        local rows=prior[qid] or {}
        prior[qid]=rows
        for i=1,math.min(#list,32) do
            local row=list[i]
            local kind,total,count=field(row,"type"),field(row,"numRequired"),field(row,"numFulfilled")
            local finished=field(row,"finished")
            if (kind=="item" or kind=="monster") and id(total) and number(count) and count%1==0 then
                local complete=finished==true or count>=total
                local previous=rows[i]
                if not previous or previous.kind~=kind or previous.total~=total then
                    rows[i]={kind=kind,total=total,completed=complete}
                elseif complete and not previous.completed then
                    previous.completed=true
                    if allow and #queue<12 then
                        local label=cleanChatText(field(row,"text"))
                        if label then
                            label=label:gsub("%s*[(]?%s*%d+%s*/%s*%d+%s*[)]?%s*$",""):gsub("[%s:]+$","")
                        end
                        if not label or label=="" then label=kind=="item" and "Collection" or "Kills" end
                        label=clip(label,120)..": "..total.."/"..total
                        local quest=title or cleanChatText(call(Q.GetTitleForQuestID,qid)) or ("Quest #"..qid)
                        local mark=call(AT.GetPrimaryMarker)
                        if not id(mark) or mark>8 then mark=8 end
                        queue[#queue+1]=("{rt%d} [%s] %s (complete)"):format(mark,clip(quest,85),clip(label,138))
                    end
                end
            end
        end
    end
    local function activeQuestScan(allow)
        if not Q then return end
        local count=call(Q.GetNumQuestLogEntries)
        if not number(count) then return end
        local seen={}
        for i=1,math.min(count,512) do
            local row=call(Q.GetInfo,i)
            local qid=field(row,"questID")
            if field(row,"isHeader")==false and id(qid) then
                seen[qid]=true
                observe(qid,allow,cleanChatText(field(row,"title")))
            end
        end
        -- Preserve previously observed quests hidden by collapsed headers.
        for qid in pairs(prior) do
            if not seen[qid] then
                if eq(call(Q.IsOnQuest,qid),true) then observe(qid,allow)
                else prior[qid]=nil end
            end
        end
        if not sendPending then sendNext() end
    end
    function AT.RefreshRankQuestAnnouncements()
        reset()
        if type(partyChat())=="function" then active=true;activeQuestScan(false) end
    end
    local function onEvent(_,event,a,b)
        if type(partyChat())~="function" then reset();return end
        if not active or event=="PLAYER_ENTERING_WORLD" then AT.RefreshRankQuestAnnouncements();return end
        if event=="GROUP_ROSTER_UPDATE" then
            queue={} -- do not replay pending chat to a changed roster
            scanPending=nil
            activeQuestScan(false)
            return
        end
        if event=="QUEST_REMOVED" or event=="QUEST_TURNED_IN" then
            if id(a) then departed[a]=true;prior[a]=nil end
            return
        end
        if event=="QUEST_ACCEPTED" then
            local qid=id(b) and b or a
            if id(qid) then
                departed[qid],prior[qid]=nil,nil
                observe(qid,false)
            end
        elseif event=="QUEST_WATCH_UPDATE" and id(a) and eq(call(Q.IsOnQuest,a),true) then
            observe(a,true)
            if not sendPending then sendNext() end
        end
        if scanPending then return end
        if not (C_Timer and C_Timer.After) then activeQuestScan(true);return end
        local ticket={}
        scanPending=ticket
        C_Timer.After(.2,function()
            if scanPending~=ticket then return end
            scanPending=nil
            if type(partyChat())=="function" then activeQuestScan(true) else reset() end
        end)
    end
    function AT.InitRankQuestAnnouncements()
        if not Q or type(Q.GetQuestObjectives)~="function" then return end
        local f=CreateFrame("Frame")
        for _,event in ipairs({"PLAYER_ENTERING_WORLD","GROUP_ROSTER_UPDATE","QUEST_LOG_UPDATE","QUEST_WATCH_UPDATE",
            "QUEST_ACCEPTED","QUEST_REMOVED","QUEST_TURNED_IN","QUEST_COMPLETE","BAG_UPDATE_DELAYED"}) do
            pcall(f.RegisterEvent,f,event)
        end
        f:SetScript("OnEvent",onEvent)
        AT.RefreshRankQuestAnnouncements()
    end
end

