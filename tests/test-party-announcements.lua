local frames={}
function CreateFrame()
    local f={events={}}
    function f:RegisterEvent(event) self.events[event]=true end
    function f:UnregisterEvent(event) self.events[event]=nil end
    function f:SetScript(_,cb) self.run=cb end
    frames[#frames+1]=f
    return f
end
local pending={}
C_Timer={After=function(secs,fn) pending[#pending+1]={secs,fn} end}
local function tick()
    local old=pending;pending={}
    table.sort(old,function(a,b) return a[1]<b[1] end)
    for _,timer in ipairs(old) do timer[2]() end
end
local sent={}
C_ChatInfo={SendChatMessage=function(message,channel)
    assert(channel=="PARTY")
    sent[#sent+1]=message
end}
local party,raid=true,false
function IsInGroup() return party end
function IsInRaid() return raid end
local log={294,508}
local visible=2
local function item(n)
    return {type="item",numRequired=8,numFulfilled=n,finished=n==8,
        text="|cff44ffff|Hitem:2|h[Scout Insignia]|h|r: "..n.."/8"}
end
local function kill(n)
    return {type="monster",numRequired=3,numFulfilled=n,finished=n==3,text="Scouts slain: "..n.."/3"}
end
local quests={[294]={item(7),kill(3),{type="event",numRequired=1,numFulfilled=0}},
    [508]={kill(1)}}
C_QuestLog={
    GetNumQuestLogEntries=function() return visible,#log end,
    GetInfo=function(i) return {questID=log[i],isHeader=false,title=i==1 and "Patrol {star}" or "The Hills"} end,
    GetTitleForQuestID=function(qid) return qid==508 and "The Hills" or "Patrol {star}" end,
    GetQuestObjectives=function(qid) return quests[qid] end,
    IsOnQuest=function(qid) for _,id in ipairs(log) do if id==qid then return true end end return false end,
}
local AT={GetPrimaryMarker=function() return 7 end}
assert(loadfile("NQT/Core.lua"))("NQT",AT)
assert(loadfile("NQT/PartyProgress.lua"))("NQT",AT)
local loader=frames[1]
loader.run(loader,"ADDON_LOADED","NQT")
assert(AT.db.rankQuestPartyAnnouncements==true, "new and upgraded profiles default on")
assert(AT.db.questHUDEnabled==false)
loader.run(loader,"PLAYER_LOGIN")
local frame=frames[#frames]
local function event(name,...) assert(frame.events[name]);frame.run(frame,name,...) end
assert(#sent==0,"do not replay completed objectives on login")
quests[294][1]=item(8)
quests[294][3].numFulfilled=1;quests[294][3].finished=true
event("QUEST_WATCH_UPDATE",294);event("QUEST_LOG_UPDATE");event("BAG_UPDATE_DELAYED");tick();tick()
assert(#sent==1 and sent[1]=="{rt7} [Patrol star] [Scout Insignia]: 8/8 (complete)")
visible=1
quests[508][1]=kill(3)
event("QUEST_LOG_UPDATE");tick();tick()
assert(#sent==2 and sent[2]=="{rt7} [The Hills] Scouts slain: 3/3 (complete)","kill updates while log header is collapsed")
event("QUEST_COMPLETE");tick()
assert(#sent==2,"quest dialogs and repeated updates cannot duplicate any announcements")
AT.db.rankQuestPartyAnnouncements=false
AT.RefreshRankQuestAnnouncements()
quests[294][4]=kill(1);event("QUEST_LOG_UPDATE");tick()
quests[294][4]=kill(3);event("QUEST_LOG_UPDATE");tick()
assert(#sent==2)
AT.db.rankQuestPartyAnnouncements=true
AT.RefreshRankQuestAnnouncements()
event("QUEST_LOG_UPDATE");tick();assert(#sent==2,"no backlog on re-enable")
party=false;event("GROUP_ROSTER_UPDATE")
quests[294][5]=kill(1);event("QUEST_LOG_UPDATE")
quests[294][5]=kill(3);event("QUEST_LOG_UPDATE");tick();assert(#sent==2)
party=true;raid=true;event("GROUP_ROSTER_UPDATE")
quests[294][6]=kill(1);event("QUEST_LOG_UPDATE")
quests[294][6]=kill(3);event("QUEST_LOG_UPDATE");tick();assert(#sent==2)
raid=false;event("GROUP_ROSTER_UPDATE")
quests[294][1]=item(7)
event("QUEST_REMOVED",294);event("QUEST_ACCEPTED",294)
event("QUEST_LOG_UPDATE");tick()
quests[294][1]=item(8);event("QUEST_LOG_UPDATE");tick()
assert(#sent==3,"a genuinely reaccepted quest may complete again")
quests[294][7]=kill(1);quests[294][8]=kill(1)
event("QUEST_LOG_UPDATE");tick()
quests[294][7]=kill(3);quests[294][8]=kill(3)
event("QUEST_LOG_UPDATE");tick()
assert(#sent==4,"simultaneous messages are spaced")
event("GROUP_ROSTER_UPDATE");tick()
assert(#sent==4,"queued chat never crosses a roster change")
print("PASS default-on party-only kill and collection announcements, custom raid marker, debounce, no duplicates or backlog, collapsed logs and roster changes")
