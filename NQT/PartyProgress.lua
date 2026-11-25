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
    local desc=plain(field(line,"leftText"))
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

function AT.ClearRankQuestPartyProgress()
    cache,pending={},{}
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
    for _,member in ipairs(roster) do
        local data=reported[member.guid]
        if member.offline then
            member.status="Offline"
        elseif data and data.needs then
            member.counts=data.counts
            if number(now) then nextPending[member.guid]={counts=data.counts,at=now} end
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
end
