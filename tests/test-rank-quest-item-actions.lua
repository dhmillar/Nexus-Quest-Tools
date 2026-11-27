local AT={}
local created={}
local locked=false
function InCombatLockdown() return locked end
function RegisterStateDriver() end
local function frame(x)
 return {
  GetRect=function()return x,30,24,24 end,GetEffectiveScale=function()return 1 end,
  GetFrameLevel=function()return 2 end,IsVisible=function()return true end}
end
UIParent=frame(0)
local viewport=frame(0)
viewport.GetRect=function()return 0,0,160,160 end
function CreateFrame()
 local f={attrs={},scripts={}}
 function f:SetAttribute(k,v) self.attrs[k]=v end
 function f:GetAttribute(k) return self.attrs[k] end
 function f:SetScript(k,v) self.scripts[k]=v end
 function f:IsShown() return self.shown end
 function f:Show() self.shown=true end
 function f:Hide() self.shown=false end
 for _,k in ipairs({"SetFrameStrata","EnableMouse","RegisterForClicks","ClearAllPoints","SetPoint","SetSize","SetFrameLevel"}) do f[k]=function()end end
 created[#created+1]=f
 return f
end
assert(loadfile("NQT/QuestItems.lua"))("NQT",AT)
local a,b=frame(60),frame(90)
a.link,b.link="item:100","item:200"
local visible={["item:100"]=true,["item:200"]=true}
local row={qid=617,item=a,itemTiles={a,b}}
AT.SetRankQuestItemTargets({row},viewport,function(q,i,token)if q==617 and visible[token] then return token end end)
assert(#created==2 and created[1]:GetAttribute("item1")=="item:100" and created[2]:GetAttribute("item1")=="item:200")
assert(created[1]:GetAttribute("type1")=="item" and created[2].shown)
visible["item:200"]=false
created[2].scripts.PreClick(created[2])
assert(not created[2].shown and not created[2]:GetAttribute("item1"),"spent item cannot be used by stale click")
row.qid=623
created[1].scripts.PreClick(created[1])
assert(not created[1].shown and not created[1]:GetAttribute("item1"),"recycled quest row cannot use previous item")
print("PASS actual secure item binding accepts two item tiles and rejects stale inventory/recycled rows")
do
    local faction="Alliance"
    GetLocale=function()return "enUS" end
    UnitFactionGroup=function()return faction end
    assert(loadfile("NQT/QuestMobData.lua"))("NQT",AT)
    assert(loadfile("NQT/QuestMobs.lua"))("NQT",AT)
    local name,npc,display=AT.GetQuestObjectiveVendor(95988,271657)
    assert(name=="Gritta Chumwater" and npc==260487 and display)
    assert(AT.GetQuestObjectiveVendor(95988,271653)=="Kor'gar")
    assert(AT.GetQuestObjectiveVendor(95988,271654)=="Krikshank")
    assert(not AT.GetQuestObjectiveVendor(95988,271650),"do not relabel Crawler Spittle as vendor loot")
    assert(not AT.GetQuestObjectiveVendor(95987,271657),"must be exact quest plus item")
    assert(AT.GetQuestObjectiveVendor(288,2594)=="Innkeeper Helbrek")
    faction="Horde"
    assert(not AT.GetQuestObjectiveVendor(288,2594))
    assert(AT.GetQuestObjectiveVendor(8928,21939)=="Vi'el")
    local ready=false
    C_QuestLog={IsOnQuest=function(q)return q==95988 end,ReadyForTurnIn=function()return ready end}
    local tile=frame(15)
    tile.mobName,tile.npcID,tile.vendorItem,tile.questId=name,npc,271657,95988
    local vr={qid=95988,itemTiles={},objectiveMobHits={tile}}
    AT.SetRankQuestItemTargets({vr},viewport)
    local button=created[1]
    local macro=button:GetAttribute("macrotext1")
    assert(button.shown and button:GetAttribute("type1")=="macro")
    assert(macro:find("/targetexact Gritta Chumwater",1,true))
    assert(macro:find("/tm [@target,help,nodead] !3",1,true) and macro:find("/ping [@target,help,nodead] 4",1,true))
    assert(macro:find("/targetlasttarget [noexists][harm]",1,true))
    tile.vendorItem=271654
    button.scripts.PreClick(button)
    assert(not button.shown and not button:GetAttribute("macrotext1"),"recycled vendor line cannot target the previous vendor")
    tile.vendorItem=271657;AT.SetRankQuestItemTargets({vr},viewport)
    assert(button.shown)
    ready=true;button.scripts.PreClick(button)
    assert(not button.shown and not button:GetAttribute("macrotext1"),"ready turn-ins cannot use an old buy objective")
    ready=false;locked=true;AT.SetRankQuestItemTargets({vr},viewport);assert(not button.shown)
    locked=false;AT.SyncRankQuestItemButtons();assert(button.shown)
    print("PASS exact vendor links, full-line hardware action, friendly-only marker/ping, stale row and combat guards")
end
