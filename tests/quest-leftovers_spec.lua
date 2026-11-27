local AT={db={enabled=true,questLeftoverMarks=true},char={}}
local secret={}
function issecretvalue(v)return v==secret end
local log={}
local total
local owned={100,100,101,102,103,104,105,106,107,108}
AT.ForeverProtectedQuestItems={[101]=true,[106]=true}
AT.ForeverQuestFacts={[8]={0,0,{100,1}}}
AT.GetForeverObjectiveQuests=function(item)
    return ({[100]={[1]=true},[104]={[2]=true},[105]={[1]=true,[7]=true},[107]={[1]=true},[108]={[1]=true}})[item]
end
local done={[1]=true,[2]=true}
C_QuestLog={
    GetNumQuestLogEntries=function() return #log,total or #log end,
    GetInfo=function(index)return {questID=log[index],isHeader=false}end,
    IsOnQuest=function(q) for _,q2 in ipairs(log) do if q==q2 then return true end end return false end,
    IsRepeatableQuest=function(q)return q==2 end,
    GetQuestObjectives=function(q) if q==8 then return {{type="item",itemID=100}} elseif q==9 then return {} end end,
    IsQuestFlaggedCompleted=function(q)return done[q] or false end
}
C_Container={GetContainerItemID=function(_,slot)return owned[slot] end,
    GetContainerItemQuestInfo=function(_,slot)return {questID=slot==9 and secret or nil,isQuestItem=true,isActive=slot==8} end}
C_Item={GetItemInfoInstant=function(i)return i,nil,nil,nil,nil,(i==108 and 1 or 12)end}
function GetQuestLogSpecialItemInfo(i) if log[i]==9 then return "|Hitem:109|h[Tool]|h" end end
local now=100
function GetTime() return now end
local combat=false
function InCombatLockdown() return combat end
local buttons={}
for i=1,11 do
    buttons[i]={GetBagID=function()return 0 end,GetID=function()return i end,
        CreateTexture=function(self)
            assert(not combat)
            local t={SetSize=function()end,SetPoint=function()end,SetTexture=function(self,p)self.path=p end,
                Show=function(self)self.shown=true end,Hide=function(self)self.shown=false end}
            self.mark=t
            return t
        end}
end
ContainerFrameCombinedBags={IsShown=function()return true end,EnumerateValidItems=function()return ipairs(buttons)end}
local watcher,tipHook; local tipShows,tipScripts=0,{}; local solid
GameTooltip={SetBagItem=function()end,AddLine=function(self,line)self.text=(self.text or "")..line end}
function GameTooltip:Show() tipShows=tipShows+1 end
function GameTooltip:HookScript(event,cb) tipScripts[event]=cb end
function GameTooltip:CreateTexture()
    solid={SetPoint=function()end,SetColorTexture=function(_,r,g,b,a) assert(a>=.95) end,
        Show=function(self) self.visible=true end,Hide=function(self) self.visible=false end}
    return solid
end
function hooksecurefunc(_,key,fn) if key=="SetBagItem" then tipHook=fn end end
function CreateFrame() watcher={RegisterEvent=function()end,SetScript=function(_,_,cb)watcher.event=cb end};return watcher end
local deferred
C_Timer={After=function(_,cb)deferred=cb end}
assert(loadfile("NQT/QuestLeftovers.lua"))("NQT",AT)
AT.InitQuestLeftovers()
assert(buttons[1].mark.shown and buttons[2].mark.shown and buttons[1].mark.path:match("LeftoverTrash.tga"))
for i=3,10 do assert(not buttons[i].mark,"must not mark unverified or protected slot "..i) end
tipHook(GameTooltip,0,1);assert(GameTooltip.text:find("future quest",1,true) and tipShows==1 and solid.visible);tipScripts.OnTooltipCleared();assert(not solid.visible)
GameTooltip.text=nil;tipHook(GameTooltip,0,3);assert(not GameTooltip.text or not GameTooltip.text:find("leftover quest item",1,true))
log={8};watcher.event(nil,"QUEST_ACCEPTED",8);assert(not buttons[1].mark.shown);deferred();assert(not buttons[1].mark.shown)
log={};total=2;AT.RefreshQuestLeftovers();assert(buttons[1].mark.shown,"verified inactive exact backlink survives a collapsed log")
total=nil;log={234};AT.RefreshQuestLeftovers();assert(buttons[1].mark.shown,"exact inactive backlink still resolves if a different row lacks metadata")
log={};owned[1]=999;watcher.event(nil,"BAG_UPDATE_DELAYED");deferred();assert(not buttons[1].mark.shown and buttons[2].mark.shown)
log={9};owned[11]=109;AT.RefreshQuestLeftovers()
log={};now=101;AT.RefreshQuestLeftovers();done[9]=true;watcher.event(nil,"QUEST_TURNED_IN",9)
combat=true;deferred();assert(AT.GetLeftoverQuestBagHint(0,11)==9 and not buttons[11].mark)
combat=false;watcher.event(nil,"PLAYER_REGEN_ENABLED");deferred();assert(buttons[11].mark.shown)
-- With Questie absent, exact item backlinks and native inactive state
-- allow a turned-in item even when an unrelated row lacks metadata.
owned[1]=701;owned[2]=3898
AT.ForeverQuestFacts={[30]={0,0,{701,1}},[31]={0,0,{701,1}}}
AT.GetForeverObjectiveQuests=function(item) if item==701 then return {[30]=true,[31]=true} end end
log={234};done[30]=true;done[31]=false
AT.RefreshQuestLeftovers()
assert(not AT.GetLeftoverQuestBagHint(0,1),"do not trash an unmet known quest use")
done[31]=true
AT.RefreshQuestLeftovers()
assert(AT.GetLeftoverQuestBagHint(0,1)==30 and buttons[1].mark.shown)
assert(not AT.GetLeftoverQuestBagHint(0,2),"Library Scrip must not be tagged")
AT.ForeverProtectedQuestItems={[701]=true}
assert(not AT.GetLeftoverQuestBagHint(0,1),"known rewards and source items protected")
AT.ForeverProtectedQuestItems=nil
log={31};done[31]=false;AT.RefreshQuestLeftovers()
assert(not AT.GetLeftoverQuestBagHint(0,1),"held quest keeps item")
log={234};watcher.event(nil,"QUEST_REMOVED",31);deferred()
local nativeRepeatable=C_QuestLog.IsRepeatableQuest
C_QuestLog.IsRepeatableQuest=function(q) if q~=31 then return nativeRepeatable(q) end end
AT.RefreshQuestLeftovers()
local q,_,category=AT.GetLeftoverQuestBagHint(0,1)
assert(q==31 and category=="review","verified removal is amber even when the client omits repeatability")
assert(AT.char.leftoverQuestReleases[701]==31,"keep removal evidence in character data on reload")
log={31};AT.RefreshQuestLeftovers();assert(not AT.GetLeftoverQuestBagHint(0,1),"accepting the quest again clears the badge")
AT.db.questLeftoverMarks=false;AT.RefreshQuestLeftovers();assert(not buttons[11].mark.shown and not AT.GetLeftoverQuestBagHint(0,11))
print("PASS existing duplicates, native active/starter/secret, DB starter/reward/repeatable/active/missing locks, stale bag/log, verified observed turn-in, combat deferral and toggle")
