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
local ready={}
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
    GetTitleForQuestID=function(qid) return ({[508]="The Hills",[701]="Delivery",[702]="Exploration",[703]="Escort",[704]="Instant turn-in",[705]="Already ready",[706]="Final collection",[707]="Instant accept"})[qid] or "Patrol {star}" end,
    GetQuestObjectives=function(qid) return quests[qid] end,
    ReadyForTurnIn=function(qid) return ready[qid]==true end,
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
log={701,702,703,704,705,706,707};visible=#log
C_QuestLog.GetInfo=function(i) local qid=log[i];return {questID=qid,isHeader=false,title=C_QuestLog.GetTitleForQuestID(qid)} end
quests[701]=nil;quests[702]={{type="event",finished=false}};quests[703]={{type="progressbar",finished=false}}
quests[706]={item(7)};ready[705]=true
event("PLAYER_ENTERING_WORLD");event("QUEST_LOG_UPDATE");tick()
assert(#sent==4,"no replay for a quest already ready when entering")
ready[701],ready[702],ready[703],ready[706]=true,true,true,true
quests[706][1]=item(8)
event("QUEST_LOG_UPDATE");for i=1,5 do tick() end
for i,name in ipairs({"Delivery","Exploration","Escort","Final collection"}) do
    assert(sent[4+i]=="{rt7} ["..name.."] Quest complete!")
end
assert(#sent==8,"the final collection objective and quest completion are one message")
event("QUEST_REMOVED",704);event("QUEST_TURNED_IN",704);event("QUEST_TURNED_IN",704);tick()
assert(#sent==9 and sent[9]=="{rt7} [Instant turn-in] Quest complete!")
event("QUEST_TURNED_IN",701);event("QUEST_TURNED_IN",705);tick()
assert(#sent==9,"turn-in cannot duplicate already seen ready state")
ready[707]=true;event("QUEST_ACCEPTED",707);tick()
event("QUEST_TURNED_IN",707);tick()
assert(#sent==9,"a quest that is ready on acceptance stays quiet through turn-in")
log[#log+1]=708;visible=#log
event("QUEST_ACCEPTED",visible,708)
C_QuestLog.ReadyForTurnIn=function(qid) return ready[qid]==true end
ready[708]=true;event("QUEST_WATCH_UPDATE",708);event("QUEST_LOG_UPDATE");tick()
event("QUEST_REMOVED",708);event("QUEST_TURNED_IN",708);tick()
assert(#sent==9,"an acceptance-time client readiness update stays quiet")
event("QUEST_ACCEPTED",709);event("QUEST_REMOVED",709);event("QUEST_TURNED_IN",709);tick()
assert(#sent==9,"turn-in in the same acceptance window is quiet even before the log catches up")
log[#log+1]=710;visible=#log;quests[710]={item(7)}
event("QUEST_ACCEPTED",710);tick()
quests[710]={item(8)};ready[710]=true;event("QUEST_LOG_UPDATE");tick()
assert(#sent==10 and sent[10]=="{rt7} [Patrol star] Quest complete!","later completion still announces")
print("PASS party-only completion, instant-accept suppression, delayed readiness, turn-in fallback, marker, dedupe, milestones and roster changes")
