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
do
    local function display()
        return {SetText=function(self,v)self.text=v end,SetShown=function(self,v)self.shown=v end}
    end
    a.cooldownText,a.cooldownShade=display(),display()
    b.cooldownText,b.cooldownShade=display(),display()
    local now=100
    local secret={}
    function issecretvalue(v)return v==secret end
    function GetTime()return now end
    C_QuestLog={GetLogIndexForQuestID=function(q)assert(q==617);return 3 end,
        GetInfo=function(i)assert(i==3);return {questID=617} end}
    function GetQuestLogSpecialItemInfo(i)assert(i==3);return "item:100" end
    function GetQuestLogSpecialItemCooldown(i)assert(i==3);return 95,70,1 end
    C_Item={GetItemCooldown=function(i)
        if i==100 then return 0,0,true end
        assert(i==200);return 98,12,true
    end}
    AT.SetRankQuestItemTargets({row},viewport,function(q,i,token)if q==617 and visible[token] then return token end end)
    assert(a.cooldownText.text=="1:05" and a.cooldownShade.shown and b.cooldownText.text=="10")
    locked=true;now=104.5
    AT.RefreshRankQuestItemCooldowns()
    assert(a.cooldownText.text=="1:01" and b.cooldownText.text=="6","visual countdown works in combat")
    now=165
    AT.RefreshRankQuestItemCooldowns()
    assert(not a.cooldownText.shown and not b.cooldownShade.shown,"clear when ready")
    now=105
    GetQuestLogSpecialItemCooldown=function()return secret,70,1 end
    AT.RefreshRankQuestItemCooldowns()
    assert(not a.cooldownText.shown and b.cooldownText.text=="5","ignore restricted values")
    viewport.GetRect=function()return 0,0,106,160 end
    AT.RefreshRankQuestItemCooldowns()
    assert(not b.cooldownText.shown,"clip offscreen countdown")
    viewport.GetRect=function()return 0,0,160,160 end
    a.link="item:999"
    AT.RefreshRankQuestItemCooldowns()
    assert(not a.cooldownText.shown and b.cooldownText.shown)
    a.link="item:100";locked=false
    AT.SetRankQuestItemTargets()
    assert(not b.cooldownText.shown,"clear recycled row")
    AT.SetRankQuestItemTargets({row},viewport,function(q,i,token)if q==617 and visible[token] then return token end end)
    C_Item,C_QuestLog,GetQuestLogSpecialItemInfo,GetQuestLogSpecialItemCooldown,GetTime,issecretvalue=nil,nil,nil,nil,nil,nil
    print("PASS clickable quest item cooldown: exact special item, bag fallback, live countdown, combat, expiry, clipping, secret data and row recycling")
end
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
    -- Run the emitted macro through a model of the secure conditions;
    -- importantly, neutral NPCs have neither help nor harm.
    local function execute(targetAfterLookup)
        local prior,target={harm=true},nil
        target=prior
        local marks,pings=0,0
        local function matches(opts)
            for key in opts:gmatch("[^,]+") do
                if key=="exists" and not target or key=="noexists" and target
                    or key=="noharm" and target and target.harm or key=="harm" and not (target and target.harm)
                    or key=="help" and not (target and target.help) or key=="nodead" and target and target.dead then return false end
            end
            return true
        end
        for line in macro:gmatch("[^\n]+") do
            if line=="/cleartarget" then target=nil
            elseif line:find("^/targetexact ") then target=targetAfterLookup
            elseif line:find("^/tm ") and matches(assert(line:match("%[(.-)%]"))) then
                assert(line:match(" !3$") and target==targetAfterLookup)
                marks=marks+1
            elseif line:find("^/ping ") and matches(assert(line:match("%[(.-)%]"))) then
                assert(line:match(" Assist$") and target==targetAfterLookup)
                pings=pings+1
            elseif line:find("^/targetlasttarget ") and (not target or target.harm) then target=prior end
        end
        return marks,pings,target==prior
    end
    for _,unit in ipairs({{}, {help=true}}) do
        local marks,pings,restored=execute(unit)
        assert(marks==1 and pings==1 and not restored,"neutral and friendly target must mark and ping on the same press")
    end
    local marks,pings,restored=execute(nil)
    assert(marks==0 and pings==0 and restored,"out of range: no action on old target")
    marks,pings,restored=execute({harm=true})
    assert(marks==0 and pings==0 and restored,"hostile match: no action")
    marks,pings=execute({dead=true})
    assert(marks==0 and pings==0,"dead vendor: no action")
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
    print("PASS exact vendor links, full-line hardware action, non-hostile marker/ping, stale row and combat guards")
end

do
    AT.db={enabled=true}
    local open,merchant,owns,complete,finished=true,260487,true,false,false
    UnitGUID=function(unit)
        assert(unit=="npc","do not infer the merchant from the selected target")
        return "Creature-0-1-2-3-"..merchant.."-00"
    end
    C_QuestLog={
        IsOnQuest=function(q) return owns and q==95988 end,
        ReadyForTurnIn=function() return complete end,
        GetQuestObjectives=function()
            return {{type="item",itemID=271657,finished=finished},
                {type="item",itemID=271653,finished=false},
                {type="item",itemID=271650,finished=false}}
        end,
    }
    local hooks={}
    function hooksecurefunc(key,fn) hooks[key]=fn end
    MerchantFrame={IsShown=function() return open end,selectedTab=1,HookScript=function(_,k,fn) hooks[k]=fn end}
    MerchantFrame_UpdateMerchantInfo=function() end
    MerchantFrame_UpdateBuybackInfo=function() end
    MERCHANT_ITEMS_PER_PAGE=2
    GetMerchantNumItems=function() return 3 end
    local stock={271657,271653,271650}
    GetMerchantItemID=function(index) if index~=1 then return stock[index] end end
    GetMerchantItemLink=function(index) return "item:"..stock[index] end
    local function slot(index)
        local o={index=index,regions={}}
        function o:GetID() return self.index end
        function o:IsShown() return true end
        function o:art()
            local r={shown=false}
            for _,k in ipairs({"SetColorTexture","SetHeight","SetWidth","SetSize","SetDrawLayer","SetTextColor"}) do r[k]=function()end end
            function r:Show() self.shown=true end
            function r:Hide() self.shown=false end
            function r:SetPoint(...) self.anchor={...} end
            function r:SetText(s) self.text=s end
            self.regions[#self.regions+1]=r
            return r
        end
        o.CreateTexture=o.art
        o.CreateFontString=o.art
        return o
    end
    MerchantItem1ItemButton,MerchantItem2ItemButton=slot(1),slot(2)
    local originalFrame=CreateFrame
    CreateFrame=function(...)
        local f=originalFrame(...); f.RegisterEvent=function() end; return f
    end
    local pending={}
    C_Timer={After=function(_,fn) pending[#pending+1]=fn end}
    AT.InitRankQuestMerchantHighlights()
    local events=created[#created]
    local function event(e) events.scripts.OnEvent(events,e) end
    local function flush()
        while #pending>0 do table.remove(pending,1)() end
    end
    local a,b=MerchantItem1ItemButton,MerchantItem2ItemButton
    event("MERCHANT_SHOW");event("MERCHANT_UPDATE");assert(#pending==1);flush()
    assert(#a.regions==6 and a.regions[1].shown and #b.regions==0)
    assert(a.regions[5].anchor[1]=="BOTTOMRIGHT" and a.regions[6].text=="!")
    finished=true;event("BAG_UPDATE_DELAYED");flush()
    assert(not a.regions[1].shown,"already purchased")
    finished=false;a.index=3;hooks.MerchantFrame_UpdateMerchantInfo()
    assert(not a.regions[1].shown,"recycled page slot")
    a.index=1;hooks.MerchantFrame_UpdateMerchantInfo()
    assert(a.regions[1].shown and #a.regions==6,"reuses art across pages")
    MerchantFrame.selectedTab=2;hooks.MerchantFrame_UpdateBuybackInfo()
    assert(not a.regions[1].shown,"never highlight buyback")
    MerchantFrame.selectedTab=1;merchant=260565;event("MERCHANT_SHOW");flush()
    assert(not a.regions[1].shown and b.regions[1].shown,"matches current merchant id, not other vendor")
    complete=true;event("QUEST_LOG_UPDATE");flush()
    assert(not b.regions[1].shown,"ready quests no longer need items")
    complete=false;owns=false;event("QUEST_LOG_UPDATE");flush();assert(not b.regions[1].shown)
    owns=true;event("MERCHANT_UPDATE");flush();assert(b.regions[1].shown)
    open=false;hooks.OnHide();event("MERCHANT_CLOSED");assert(not b.regions[1].shown)
    print("PASS passive vendor box and bottom-right bang, exact live needs, paging, buyback, progress and close")
end
