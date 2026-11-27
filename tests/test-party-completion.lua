-- Actual party sync handlers in two independent addon instances.
local sender,wire,now,party,raid="Self-Realm",{},10,true,false
local callbacks={}
local function fire(frame,event,...) frame.events.OnEvent(frame,event,...) end
function CreateFrame()
    return {events={},RegisterEvent=function() end,SetScript=function(self,k,fn) self.events[k]=fn end}
end
C_Timer={After=function(_,fn) callbacks[#callbacks+1]=fn end}
local function drain()
    local todo=callbacks;callbacks={}
    for _,fn in ipairs(todo) do fn() end
end
function GetTime() return now end
function IsInGroup() return party end
function IsInRaid() return raid end
function GetNumSubgroupMembers() return 3 end
function GetNormalizedRealmName() return "Realm" end
local names={party1="Kara",party2="Mira",party3="Kara"}
local realms={party1="Realm",party2="Realm",party3="Other"}
function UnitFullName(u) return names[u],realms[u] end
function GetUnitName(u) return names[u] end
function UnitGUID(u) return "guid:"..u end
function UnitIsConnected() return true end
function UnitIsVisible() return false end
Enum={TooltipDataLineType={QuestTitle=1,QuestPlayer=2,QuestObjective=3},SendAddonMessageResult={Success=0}}
local report=true
C_TooltipInfo={GetQuestPartyProgress=function(q)
    if not report then return end
    local lines={{type=1,id=q}}
    for i=1,3 do
        lines[#lines+1]={type=2,guid="guid:party"..i}
        lines[#lines+1]={type=3,numFulfilled=i,numRequired=7}
    end
    return {lines=lines}
end}
local ready,held,regressed=false,true,false
local picked
C_QuestLog={
    GetNumQuestLogEntries=function() return held and 1 or 0 end,
    GetInfo=function() return {questID=5010} end,
    ReadyForTurnIn=function() return ready end,
    GetQuestObjectives=function()
        if picked~=nil then return {{text=tostring(picked).."/7 Pelts",numFulfilled=picked,numRequired=7,finished=picked==7}} end
        return {{finished=not regressed}}
    end,
}
C_ChatInfo={
    RegisterAddonMessagePrefix=function(p) assert(#p<=16);return true end,
    SendAddonMessage=function(p,m,channel)
        assert(channel=="PARTY")
        wire[#wire+1]={p,m,channel,sender}
        return 0
    end
}
local function loadAddon()
    local at={db={questPartyProgress=true,enabled=true},refreshes=0}
    at.RefreshQuestHUD=function() at.refreshes=at.refreshes+1 end
    assert(loadfile("NQT/PartyProgress.lua"))("NQT",at)
    local orig=CreateFrame
    local frame
    CreateFrame=function() frame=orig();return frame end
    at.InitQuestPartySync()
    CreateFrame=orig
    return at,frame
end
local remote,reader=loadAddon()
local _,writer=loadAddon()
local function send(name,event,...)
    sender=name;fire(writer,event,...)
    drain()
    local messages=wire;wire={}
    for _,m in ipairs(messages) do fire(reader,"CHAT_MSG_ADDON",unpack(m)) end
    drain()
    return #messages
end
local function snapshot() return assert(remote.GetQuestPartySnapshot(5010)) end
local function ownState(m) return snapshot().members[m].status end
assert(snapshot().verifiedPending)
picked=0
assert(send("Kara-Realm","BAG_UPDATE_DELAYED")==1)
assert(snapshot().members[1].counts[1].current==0)
picked=3
assert(send("Kara-Realm","BAG_UPDATE_DELAYED")==1)
assert(snapshot().members[1].counts[1].current==3 and snapshot().members[1].counts[1].total==7)
assert(snapshot().members[1].counts[1].desc=="Pelts")
assert(send("Kara-Realm","QUEST_LOG_UPDATE")==0,"unchanged counts should not rebroadcast")
picked=2
assert(send("Kara-Realm","QUEST_WATCH_UPDATE",5010)==1)
assert(snapshot().members[1].counts[1].current==2,"verified counts may decrease")
local prefix="NQTQuestState1"
fire(reader,"CHAT_MSG_ADDON",prefix,"P:5010:01:1/9/7,","PARTY","Kara-Realm")
fire(reader,"CHAT_MSG_ADDON",prefix,"P:5010:01:1/2/7,1/6/7,","PARTY","Kara-Realm")
fire(reader,"CHAT_MSG_ADDON",prefix,"P:5010:01:1/6/7,","PARTY","Kara-Unknown")
assert(snapshot().members[1].counts[1].current==2)
picked=nil
local priorRefreshes=remote.refreshes
ready=true
assert(send("Kara-Realm","QUEST_LOG_UPDATE")==1)
assert(ownState(1)=="Objectives complete" and ownState(3)==nil)
assert(snapshot().hasSharedResolution and snapshot().pending)
assert(remote.refreshes==priorRefreshes+1,"push must refresh without waiting for the ticker")
assert(send("Kara-Realm","QUEST_LOG_UPDATE")==0,"no duplicate on log event")
regressed=true;ready=false
assert(send("Kara-Realm","QUEST_LOG_UPDATE")==1)
assert(ownState(1)==nil and snapshot().verifiedPending)
local prefix="NQTQuestState1"
fire(reader,"CHAT_MSG_ADDON",prefix,"D:5010","PARTY","Kara-Unknown")
fire(reader,"CHAT_MSG_ADDON",prefix,"D:5010","WHISPER","Kara-Realm")
fire(reader,"CHAT_MSG_ADDON",prefix,"D:5010evil","PARTY","Kara-Realm")
assert(ownState(1)==nil)
-- Tooltip can vanish or continue reporting old counts after a turn-in.
report=false
assert(send("Kara-Realm","QUEST_REMOVED",5010)==1)
assert(ownState(1)=="No longer on this quest" and not snapshot().members[1].lastCounts)
assert(snapshot().pending,"other party members keep the quest")
fire(reader,"CHAT_MSG_ADDON",prefix,"D:5010","PARTY","Mira-Realm")
fire(reader,"CHAT_MSG_ADDON",prefix,"L:5010","PARTY","Kara-Other")
drain()
assert(not snapshot().pending,"last party completion must clear a retained row before remembered counts expire")
report=true
assert(not snapshot().pending,"stale native data must not resurrect the row")
held=true;ready=true
assert(send("Kara-Realm","QUEST_LOG_UPDATE")==0,"delayed stale local quest log may not overwrite removal")
ready=false
assert(send("Kara-Realm","QUEST_ACCEPTED",4,5010)==1)
assert(snapshot().pending and ownState(1)==nil)
party=false
fire(reader,"GROUP_ROSTER_UPDATE")
assert(remote.GetQuestPartySnapshot(5010)==nil)
party=true
assert(snapshot().verifiedPending and not snapshot().hasSharedResolution)
remote.db.questPartyProgress=false
fire(reader,"CHAT_MSG_ADDON",prefix,"D:5010","PARTY","Kara-Realm")
remote.db.questPartyProgress=true
assert(not snapshot().hasSharedResolution)
-- Explicit newer progress may reopen a completed quest. Do not reuse the pre-regression native complete row.
local nativeBase=C_TooltipInfo.GetQuestPartyProgress
local n1,n2=7,8
C_TooltipInfo.GetQuestPartyProgress=function(q)
    return {lines={{type=1,id=q},{type=2,guid="guid:party1"},{type=3,numFulfilled=n1,numRequired=n2}}}
end
fire(reader,"CHAT_MSG_ADDON",prefix,"P:5010:01:1/5/7,","PARTY","Kara-Realm")
assert(snapshot().members[1].counts[1].current==5,"a different total is not proof of completion")
n2=7
assert(remote.GetQuestPartySnapshot(5010,true).members[1].status=="Objectives complete")
fire(reader,"CHAT_MSG_ADDON",prefix,"P:5010:01:1/2/7,","PARTY","Kara-Realm")
assert(snapshot().members[1].counts[1].current==2,"explicit regression beats an old complete tooltip")
n1=2
assert(remote.GetQuestPartySnapshot(5010,true).verifiedPending)
n1=7
assert(remote.GetQuestPartySnapshot(5010,true).members[1].status=="Objectives complete","later completion still resolves")
C_TooltipInfo.GetQuestPartyProgress=nativeBase
remote.db.questPartyProgress=true
ready=true
assert(send("Kara-Realm","QUEST_COMPLETE")==1,"quest completion triggers a verified party notification")
print("PASS party completion sync: private to party, same-name realms, immediate stale-count override, no false sharing, reaccept, group and off toggle")