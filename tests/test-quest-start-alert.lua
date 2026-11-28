local AT={db={enabled=true}}
local frames, timers, contents, finished, owned={},{},{},{},{}
local use,accepts,z,bagReads,questReads=0,0,0,0,0
local combat=false
local function object()
    local o={shown=true,scripts={},attrs={}}
    local noop=function()end
    return setmetatable(o,{__index={
        SetSize=noop,SetFrameStrata=noop,RegisterForClicks=noop,SetAllPoints=noop,
        SetPoint=function(self,...) self.point={...} end, ClearAllPoints=noop,SetTexCoord=noop,
        SetColorTexture=noop,SetHighlightTexture=noop,RegisterEvent=noop,
        CreateTexture=function()return object()end,
        SetTexture=function(self,t)self.texture=t end,
        SetScript=function(self,k,v)self.scripts[k]=v end,
        SetAttribute=function(self,k,v)self.attrs[k]=v end,
        Hide=function(self)self.shown=false end,
        Show=function(self)self.shown=true end,
        IsShown=function(self)return self.shown end,
    }})
end
UIParent={GetWidth=function()return 1000 end,GetHeight=function()return 600 end,GetEffectiveScale=function()return 1 end}
CreateFrame=function() local o=object();frames[#frames+1]=o;return o end
RegisterStateDriver=function(_,name,cond) assert(name=="startercombat" and cond=="[combat] locked; free") end
InCombatLockdown=function()return combat end
GetTime=function()return z end
C_Timer={After=function(_,fn)timers[#timers+1]=fn end}
C_QuestLog={IsOnQuest=function(id)return owned[id] end,IsQuestFlaggedCompleted=function(id)return finished[id] end}
AcceptQuest=function()accepts=accepts+1 end
C_Container={
    GetContainerNumSlots=function(bag)return bag==0 and 10 or 0 end,
    GetContainerItemInfo=function(_,slot)bagReads=bagReads+1;return contents[slot] end,
    GetContainerItemQuestInfo=function(_,slot)questReads=questReads+1;local info=contents[slot];return info and {questID=info.quest,isActive=info.active}end,
}
local function item(id,quest,icon,qty)
    return {itemID=id,quest=quest,iconFileID=icon,stackCount=qty or 1}
end
contents[1]=item(1,10,100)
assert(loadfile("NQT/QuestStartAlert.lua"))("NQT",AT)
AT.InitQuestStartItemAlert()
local b=frames[1];local obs=frames[2]
local function event(name,...)obs.scripts.OnEvent(obs,name,...)end
local function bag()event("BAG_UPDATE_DELAYED")end
local function click(key)
    b.scripts.PreClick(b,key)
    if key=="LeftButton" and b.attrs.type1=="item" then use=use+1 end
    b.scripts.PostClick(b,key)
end
assert(not b.shown)
event("PLAYER_ENTERING_WORLD",true,false)
local before=bagReads
for _=1,80 do event("QUEST_LOG_UPDATE") end
assert(bagReads==before and questReads==0,"unrelated progress must not scan bags or query starter metadata")
contents[8],contents[1]=contents[1],nil
bag();assert(not b.shown,"bag move isn't a new item")
contents[8].stackCount=2
bag();assert(not b.shown,"a pre-existing starter gaining quantity isn't a new item")
contents[2]=item(2,nil,200)
bag();assert(not b.shown)
contents[2].quest=20
z=z+.5;table.remove(timers,1)()
assert(b.shown and b.attrs.item1=="item:2" and b.icon.texture==200,"metadata arrives after inventory")
assert(b.point[4]==500 and b.point[5]==372,"above player screen position without a nameplate")
click("LeftButton")
assert(use==1 and accepts==0 and b.shown,"real button opens offer, never accepts")
contents[3]=item(3,30,300)
bag();assert(b.attrs.item1=="item:2","new item queues behind current")
event("QUEST_ACCEPTED",20) -- native log still stale
assert(b.attrs.item1=="item:3")
event("QUEST_ACCEPTED",3,30) -- legacy two-argument event
assert(not b.shown and use==1)
contents[9]=item(9,90,900);bag();assert(b.shown)
click("RightButton");assert(not b.shown and use==1)
bag();assert(not b.shown,"dismissed item doesn't reappear")
combat=true;contents[4]=item(4,40,400)
bag();assert(not b.shown)
combat=false;event("PLAYER_REGEN_ENABLED")
assert(b.shown and b.attrs.item1=="item:4")
contents[4]=nil
click("LeftButton");assert(not b.shown and b.attrs.item1==nil and use==1,"stale click cannot use an item")
finished[50]=true; contents[5]=item(5,50,500);bag();assert(not b.shown)
AT.db.questStartItemAlert=false;AT.RefreshQuestStartItemAlert()
contents[6]=item(6,60,600);bag();assert(not b.shown)
AT.db.questStartItemAlert=true;AT.RefreshQuestStartItemAlert()
assert(not b.shown,"not retroactive after re-enabling")
contents[7]=item(7,70,700)
bag();assert(b.shown and b.attrs.item1=="item:7")
AT.db.questStartItemAlert=false;AT.RefreshQuestStartItemAlert()
assert(not b.shown and b.attrs.item1==nil,"turning off clears a live offer")
print("PASS new eligible starter, delayed metadata, click vs accept, move/stack, dismissal, queue, combat, stale item, and toggle")
-- Existing bundled data contains a separately verified actual item starter.
-- Fall back only with authoritative public held and completion booleans.
assert(loadfile("NQT/NQTDB.lua"))("NQT",AT)
assert(AT.NQTDB.ItemStarterWitnesses[5582][1]==13920)
local shadow=AT.NQTDB.ItemStarterWitnesses
AT.db.questStartItemAlert=true;AT.RefreshQuestStartItemAlert()
contents[10]=item(13920,nil,139200);bag();assert(not b.shown,"unknown status cannot show")
owned[5582],finished[5582]=false,true
bag();assert(not b.shown,"previously completed quest")
owned[5582],finished[5582]=true,false
bag();assert(not b.shown,"held quest")
owned[5582]=false
local secret={}
function issecretvalue(v)return v==secret end
contents[10].quest=secret
bag();assert(not b.shown,"do not substitute for restricted native quest metadata")
contents[10].quest=nil
contents[10].active=true
bag();assert(not b.shown,"native active flag blocks")
contents[10].active=false
AT.NQTDB.ItemStarterWitnesses={[5582]=shadow[5582],[5583]=shadow[5582]}
bag();assert(not b.shown,"ambiguous standalone item evidence cannot show")
AT.NQTDB.ItemStarterWitnesses=shadow
bag();assert(b.shown and b.attrs.item1=="item:13920","exact published starter renders with no native ID")
contents[10].quest=5584
click("LeftButton")
assert(not b.shown and use==1,"new authoritative client ID invalidates a fallback click")
AT.db.questStartItemAlert=false;AT.RefreshQuestStartItemAlert();contents[10]=nil
AT.db.questStartItemAlert=true;AT.RefreshQuestStartItemAlert()
contents[10]=item(13920,nil,139200);bag()
assert(b.shown and b.attrs.item1=="item:13920")
click("LeftButton");assert(use==2 and accepts==0,"use held verified item, never auto-accept")
event("QUEST_ACCEPTED",5582);assert(not b.shown and not b.attrs.item1)
print("PASS exact NQTDB fallback reaches the real secure starter button only for an unheld, unfinished, unrestricted exact item")
