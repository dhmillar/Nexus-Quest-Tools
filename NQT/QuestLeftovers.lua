local _,AT=...
local function clean(v) return not issecretvalue or not issecretvalue(v) end
local function isa(v,t) return clean(v) and type(v)==t end
local function id(v) return isa(v,"number") and v>0 and v%1==0 end
local function field(v,k)
    if not isa(v,"table") then return end
    local a=v[k]; if clean(a) then return a end
end
local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b,c,d,e,f=pcall(fn,...)
    if ok then return a,b,c,d,e,f end
end
local pending, active, completeLog={}, {}, false
local painted=setmetatable({},{__mode="k"})
local turninLimit=250
local function enabled()
    return AT.db and AT.db.enabled~=false and AT.db.questLeftoverMarks==true and isa(AT.char,"table")
end
local function questieDB()
    if Questie and Questie.IsForever and Questie.API and Questie.API.isReady and QuestieLoader then
        return call(QuestieLoader.ImportModule,QuestieLoader,"QuestieDB")
    end
end
local function add(set,v) if id(v) then set[v]=true end end
local function objectiveIDs(qid,index,db)
    local set={}
    if id(index) then
        local special=call(GetQuestLogSpecialItemInfo,index)
        if isa(special,"string") then add(set,tonumber(special:match("|Hitem:(%d+)"))) end
    end
    local q=db and call(db.GetQuest,qid)
    local objectives=field(q,"ObjectiveData")
    if not isa(objectives,"table") then return set,false end
    for _,o in pairs(objectives) do
        if field(o,"Type")=="item" then add(set,field(o,"Id")) end
    end
    local required=field(q,"requiredSourceItems")
    if required~=nil then
        if not isa(required,"table") then return set,false end
        for _,item in pairs(required) do
            if not id(item) then return set,false end
            add(set,item)
        end
    end
    add(set,field(q,"sourceItemId"))
    local source=field(q,"sourceItemId")
    if source~=nil and not id(source) and source~=0 then return set,false end
    return set,true
end
local function scan()
    active,completeLog={},false
    if not enabled() or not C_QuestLog then pending={};return end
    local shown,total=call(C_QuestLog.GetNumQuestLogEntries)
    if not isa(shown,"number") or shown<0 or shown>1000 or not isa(total,"number") or total<0 or total>1000 then return end
    local count,covered,db=0,true,questieDB()
    local observed={}
    for i=1,shown do
        local row=call(C_QuestLog.GetInfo,i)
        if not isa(row,"table") then covered=false end
        local qid=field(row,"questID")
        if id(qid) and field(row,"isHeader")==false then
            count=count+1
            local items,known=objectiveIDs(qid,i,db)
            observed[qid]=items
            if not known then covered=false end
            for item in pairs(items) do active[item]=true end
        end
    end
    -- Count mismatch includes collapsed/hidden quests. Never expand, guess,
    -- or use a partial log to tell a player an item can be discarded.
    completeLog=count==total and covered
    local timestamp=call(GetTime)
    if isa(timestamp,"number") then
        for qid,entry in pairs(pending) do
            if not observed[qid] and timestamp-entry.time<=10 then observed[qid]=entry end
        end
        for qid,items in pairs(observed) do
            if not items.time then observed[qid]={items=items,time=timestamp} end
        end
        pending=observed
    else pending={} end
end
local function remember(qid)
    if not enabled() or not id(qid) then return end
    local entry=pending[qid]
    local items=entry and entry.items
    if not items or not next(items) then return end
    if not isa(AT.char.leftoverQuestTurnins,"table") then AT.char.leftoverQuestTurnins={} end
    local ledger=AT.char.leftoverQuestTurnins
    for item in pairs(items) do
        if not ledger[item] and (ledger.count or 0)<turninLimit then
            ledger[item]=qid;ledger.count=(ledger.count or 0)+1
        end
    end
end
function AT.GetLeftoverQuestBagHint(bag,slot)
    if not enabled() or not completeLog or not C_Container or not C_QuestLog or not C_Item
        or not isa(bag,"number") or bag<0 or bag>(NUM_BAG_SLOTS or 4) or bag%1~=0 or not id(slot) then return end
    local item=call(C_Container.GetContainerItemID,bag,slot)
    if not id(item) or active[item] then return end
    local info=call(C_Container.GetContainerItemQuestInfo,bag,slot)
    if not isa(info,"table") then return end
    local starter=info.questID
    if not clean(starter) or starter~=nil or field(info,"isActive")~=false then return end
    local ledger=AT.char.leftoverQuestTurnins
    local quest=isa(ledger,"table") and ledger[item]
    local db=questieDB()
    local data=db and call(db.GetItem,db,item)
    if isa(data,"table") then
        local starts=field(data,"startQuest")
        if starts~=nil and starts~=0 then return end
        local rewards=field(data,"questRewards")
        if rewards~=nil and (not isa(rewards,"table") or next(rewards)) then return end
        local related=field(data,"relatedQuests")
        if isa(related,"table") then
            for _,qid in pairs(related) do
                if not id(qid) then return end
                local isOn=call(C_QuestLog.IsOnQuest,qid)
                local repeatable=call(C_QuestLog.IsRepeatableQuest,qid)
                if not clean(isOn) or isOn~=false or not clean(repeatable) or repeatable~=false then return end
                local ids,known=objectiveIDs(qid,nil,db)
                local done=call(C_QuestLog.IsQuestFlaggedCompleted,qid)
                if known and ids[item] then
                    if not clean(done) or done~=true then return end
                    if not id(quest) then quest=qid end
                elseif not known then return end
            end
        end
    end
    if not id(quest) then return end
    local done=call(C_QuestLog.IsQuestFlaggedCompleted,quest)
    local isOn=call(C_QuestLog.IsOnQuest,quest)
    local repeatable=call(C_QuestLog.IsRepeatableQuest,quest)
    if not clean(done) or done~=true or not clean(isOn) or isOn~=false or not clean(repeatable) or repeatable~=false then return end
    local _,_,_,_,_,class=call(C_Item.GetItemInfoInstant,item)
    local questClass=Enum and Enum.ItemClass and Enum.ItemClass.Questitem or 12
    if not clean(class) or class~=questClass then return end
    return quest,item
end
local function hint(tip,bag,slot)
    local quest=AT.GetLeftoverQuestBagHint(bag,slot)
    if not quest or not tip or not tip.AddLine then return end
    tip:AddLine("Rank Quest: leftover quest item",1,.74,.32)
    tip:AddLine("Its recorded quest was turned in; no current quest in the checked log uses it. A future quest may still need it.",.9,.89,.86,true)
end
local function paint(button)
    if not button then return end
    local mark=painted[button]
    local bag,slot=call(button.GetBagID,button),call(button.GetID,button)
    if not AT.GetLeftoverQuestBagHint(bag,slot) then if mark then mark:Hide() end;return end
    if not mark then
        if not button.CreateTexture or (InCombatLockdown and InCombatLockdown()) then return end
        mark=button:CreateTexture(nil,"OVERLAY",nil,7)
        mark:SetSize(15,15);mark:SetPoint("TOPRIGHT",button,"TOPRIGHT",-1,-1)
        mark:SetTexture("Interface/AddOns/NQT/LeftoverTrash.tga")
        painted[button]=mark
    end
    mark:Show()
end
local function refreshButtons()
    for button in pairs(painted) do paint(button) end
    if not enabled() then return end
    local function each(frame)
        if not frame or not frame.IsShown or not frame:IsShown() then return end
        if type(frame.EnumerateValidItems)=="function" then
            for _,item in frame:EnumerateValidItems() do paint(item) end
        end
        local name=call(frame.GetName,frame)
        if isa(name,"string") then for i=1,160 do
            local item=_G[name.."Item"..i]
            if item then paint(item) end
        end end
    end
    each(_G.ContainerFrameCombinedBags)
    for i=1,(NUM_CONTAINER_FRAMES or 13) do each(_G["ContainerFrame"..i]) end
end
local hookedTooltips=setmetatable({},{__mode="k"})
local hookedFrames=setmetatable({},{__mode="k"})
local function hookBagFrame(frame)
    if not frame or hookedFrames[frame] then return end
    local callback=function()
        if not enabled() then return end
        if type(frame.EnumerateValidItems)=="function" then
            for _,item in frame:EnumerateValidItems() do paint(item) end
        end
    end
    local hooked=false
    if hooksecurefunc and type(frame.UpdateItems)=="function" then
        hooked=pcall(hooksecurefunc,frame,"UpdateItems",callback)
    end
    if type(frame.HookScript)=="function" and pcall(frame.HookScript,frame,"OnShow",callback) then hooked=true end
    if hooked then hookedFrames[frame]=true end
end
local hookedBags
local function installHooks()
    local tip=GameTooltip
    if hooksecurefunc and tip and type(tip.SetBagItem)=="function" and not hookedTooltips[tip] then
        hookedTooltips[tip]=pcall(hooksecurefunc,tip,"SetBagItem",hint)
    end
    hookBagFrame(_G.ContainerFrameCombinedBags)
    for i=1,(NUM_CONTAINER_FRAMES or 13) do hookBagFrame(_G["ContainerFrame"..i]) end
    local mixin=ContainerFrameItemButtonMixin
    if hooksecurefunc and mixin and not hookedBags and type(mixin.Update)=="function" then
        hookedBags=pcall(hooksecurefunc,mixin,"Update",paint)
    end
end
function AT.RefreshQuestLeftovers()
    scan();installHooks();refreshButtons()
end
function AT.InitQuestLeftovers()
    local frame=CreateFrame("Frame")
    for _,event in ipairs({"QUEST_LOG_UPDATE","QUEST_ACCEPTED","QUEST_REMOVED","QUEST_TURNED_IN","BAG_UPDATE_DELAYED",
        "BAG_OPEN","PLAYER_REGEN_ENABLED","PLAYER_ENTERING_WORLD","ADDON_LOADED"}) do pcall(frame.RegisterEvent,frame,event) end
    local scheduled
    local function refresh() scheduled=nil;AT.RefreshQuestLeftovers() end
    frame:SetScript("OnEvent",function(_,event,qid)
        if event=="QUEST_TURNED_IN" then remember(qid) end
        -- Hide every old badge immediately before the next inventory/log pass.
        for _,mark in pairs(painted) do mark:Hide() end
        completeLog=false
        if scheduled then return end
        scheduled=true
        if C_Timer and C_Timer.After then C_Timer.After(0,refresh) else refresh() end
    end)
    AT.RefreshQuestLeftovers()
end
