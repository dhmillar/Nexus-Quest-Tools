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
local pending, active, completeLog, scanned={}, {}, false, false
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
local function nativeObjectiveIDs(qid,set)
    local objectives=call(C_QuestLog and C_QuestLog.GetQuestObjectives,qid)
    if not isa(objectives,"table") then return false end
    for _,o in pairs(objectives) do
        if isa(o,"table") and field(o,"type")=="item" then
            add(set,field(o,"itemID"))
            local label=field(o,"text")
            if isa(label,"string") then
                for linked in label:gmatch("|Hitem:(%d+)") do add(set,tonumber(linked)) end
            end
        end
    end
end
local function eachCustomBagButton(fn)
    local q=_G.EnhanceQoL
    local bags=q and q.Bags
    local states=bags and bags.variables and bags.variables.state
    local grid=states and states.itemButtonsByBag
    if type(grid)~="table" then return end
    for bag=0,(NUM_BAG_SLOTS or 4) do
        if type(grid[bag])=="table" then
            for slot,button in pairs(grid[bag]) do
                -- Match EnhanceQoL's owned button to its real carried bag.
                if id(slot) and button and call(button.GetBagID,button)==bag and call(button.GetID,button)==slot then fn(button) end
            end
        end
    end
end
local function objectiveIDs(qid,index,db)
    local set={}
    if id(index) then
        local special=call(GetQuestLogSpecialItemInfo,index)
        if isa(special,"string") then add(set,tonumber(special:match("|Hitem:(%d+)"))) end
    end
    if index~=nil then nativeObjectiveIDs(qid,set) end
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
    active,completeLog,scanned={},false,false
    if not enabled() or not C_QuestLog then pending={};return end
    local shown,total=call(C_QuestLog.GetNumQuestLogEntries)
    if not isa(shown,"number") or shown<0 or shown>1000 or not isa(total,"number") or total<0 or total>1000 then return end
    local count,covered,db=0,true,questieDB()
    local seen={}
    local observed={}
    for i=1,shown do
        local row=call(C_QuestLog.GetInfo,i)
        if not isa(row,"table") then covered=false end
        local qid=field(row,"questID")
        if id(qid) and field(row,"isHeader")==false then
            count=count+1;seen[qid]=true
            local items,known=objectiveIDs(qid,i,db)
            observed[qid]=items
            if not known then covered=false end
            for item in pairs(items) do active[item]=true end
        end
    end
    -- Use only loaded, client-confirmed accepted quests to fill collapsed
    -- headers without changing anyone's quest-log expansion.
    if count<total and db and QuestieLoader then
        local aq=call(QuestieLoader.ImportModule,QuestieLoader,"ActiveQuests")
        local all=aq and call(aq.GetAll)
        if isa(all,"table") then
            for qid in pairs(all) do
                local on=call(C_QuestLog.IsOnQuest,qid)
                if id(qid) and not seen[qid] and clean(on) and on==true then
                    count=count+1;seen[qid]=true
                    local index=call(C_QuestLog.GetLogIndexForQuestID,qid)
                    if not id(index) or field(call(C_QuestLog.GetInfo,index),"questID")~=qid then index=false end
                    local items,known=objectiveIDs(qid,index,db)
                    observed[qid]=items
                    if not known then covered=false end
                    for item in pairs(items) do active[item]=true end
                end
            end
        end
    end
    -- Count mismatch includes collapsed/hidden quests. Never expand, guess,
    -- or use a partial log to tell a player an item can be discarded.
    completeLog=count==total and covered
    scanned=true
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
local function releasedQuest(item)
    local saved=AT.char and AT.char.leftoverQuestReleases
    return isa(saved,"table") and saved[item] or nil
end

local function remember(qid,removed)
    if not enabled() or not id(qid) then return end
    local entry=pending[qid]
    local items={}
    for item in pairs(entry and entry.items or {}) do items[item]=true end
    local facts=AT.ForeverQuestFacts and AT.ForeverQuestFacts[qid]
    for i=3,#(facts or {}) do items[facts[i][1]]=true end
    if not next(items) then return end
    if removed then
        if not isa(AT.char.leftoverQuestReleases,"table") then AT.char.leftoverQuestReleases={} end
        local saved=AT.char.leftoverQuestReleases
        for item in pairs(items) do
            if saved[item] or (saved.count or 0)<turninLimit then
                if not saved[item] then saved.count=(saved.count or 0)+1 end
                saved[item]=qid
            end
        end
        return
    end
    if not isa(AT.char.leftoverQuestTurnins,"table") then AT.char.leftoverQuestTurnins={} end
    local ledger=AT.char.leftoverQuestTurnins
    for item in pairs(items) do
        if not ledger[item] and (ledger.count or 0)<turninLimit then
            ledger[item]=qid;ledger.count=(ledger.count or 0)+1
        end
    end
end
function AT.GetLeftoverQuestBagHint(bag,slot)
    if not enabled() or not scanned or not C_Container or not C_QuestLog or not C_Item
        or not isa(bag,"number") or bag<0 or bag>(NUM_BAG_SLOTS or 4) or bag%1~=0 or not id(slot) then return end
    local item=call(C_Container.GetContainerItemID,bag,slot)
    if not id(item) or active[item] or item==3898
        or AT.ForeverProtectedQuestItems and AT.ForeverProtectedQuestItems[item] then return end
    local info=call(C_Container.GetContainerItemQuestInfo,bag,slot)
    if not isa(info,"table") then return end
    local starter=info.questID
    if not clean(starter) or (starter~=nil and starter~=0) or field(info,"isActive")~=false then return end
    local ledger=AT.char.leftoverQuestTurnins
    local quest=isa(ledger,"table") and ledger[item]
    local direct=AT.GetForeverObjectiveQuests and AT.GetForeverObjectiveQuests(item)
    local removed=releasedQuest(item)
    local review
    -- Some Forever clients do not report repeatability for a removed quest.
    -- A positive removal record can still support amber review, never trash.
    if id(removed) and call(C_QuestLog.IsOnQuest,removed)==false
        and call(C_QuestLog.IsQuestFlaggedCompleted,removed)==false then
        local repeatable=call(C_QuestLog.IsRepeatableQuest,removed)
        if clean(repeatable) and repeatable~=true then review=removed end
    end
    for qid in pairs(direct or {}) do
        local on=call(C_QuestLog.IsOnQuest,qid)
        local repeatable=call(C_QuestLog.IsRepeatableQuest,qid)
        local done=call(C_QuestLog.IsQuestFlaggedCompleted,qid)
        if not clean(on) or on~=false or not clean(repeatable) or not clean(done)
            or repeatable~=false and not (review==qid and repeatable==nil) then return end
        if done==true then
            if not id(quest) or qid<quest then quest=qid end
        elseif done~=false or review~=qid then return end
    end
    -- Only exact standalone links can supplement incomplete metadata from
    -- Questie or hidden headers, and only when the bag API says inactive.
    if not completeLog and not review and not (direct and next(direct)) then return end
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
                if not clean(isOn) or isOn~=false or not clean(repeatable)
                    or repeatable~=false and not (review==qid and repeatable==nil) then return end
                local ids,known=objectiveIDs(qid,nil,db)
                local done=call(C_QuestLog.IsQuestFlaggedCompleted,qid)
                if known and ids[item] then
                    if not clean(done) then return end
                    if done==true then
                        if not id(quest) then quest=qid end
                    elseif done~=false or review~=qid then return end
                elseif not known then return end
            end
        end
    end
    local reviewOnly=id(review)
    if reviewOnly then quest=review end
    if not id(quest) then return end
    local done=call(C_QuestLog.IsQuestFlaggedCompleted,quest)
    local isOn=call(C_QuestLog.IsOnQuest,quest)
    local repeatable=call(C_QuestLog.IsRepeatableQuest,quest)
    if not clean(done) or (reviewOnly and done~=false or not reviewOnly and done~=true)
        or not clean(isOn) or isOn~=false or not clean(repeatable)
        or repeatable~=false and not (reviewOnly and repeatable==nil) then return end
    local _,_,_,_,_,class=call(C_Item.GetItemInfoInstant,item)
    local questClass=Enum and Enum.ItemClass and Enum.ItemClass.Questitem or 12
    if not clean(class) or class~=questClass then return end
    return quest,item,reviewOnly and "review" or "turned-in"
end
-- Verified item relationship only. Do not feed this into the trash classifier:
-- a provided quest item is not evidence that every later use is known.
local verifiedQuestRefs={
    [5505]={[1023]="Raene's Cleansing"},
    -- Independently checked factual item requirements; see README.
    [723]={[22]="Goretusk Liver Pie"},
    [730]={[38]="Westfall Stew"},
}
local bagQuestLinks
local questItemBackdrops=setmetatable({},{__mode="k"})
local function showQuestItemBackdrop(tip)
    local texture=questItemBackdrops[tip]
    if not texture and type(tip.CreateTexture)=="function" and type(tip.HookScript)=="function" then
        local function hide()
            if texture then texture:Hide() end
        end
        local clears=pcall(tip.HookScript,tip,"OnTooltipCleared",hide)
        local closes=pcall(tip.HookScript,tip,"OnHide",hide)
        if clears and closes then
            texture=tip:CreateTexture(nil,"BACKGROUND",nil,-7)
            texture:SetPoint("TOPLEFT",tip,"TOPLEFT",3,-3)
            texture:SetPoint("BOTTOMRIGHT",tip,"BOTTOMRIGHT",-3,3)
            texture:SetColorTexture(.035,.027,.022,.98)
            questItemBackdrops[tip]=texture
        end
    end
    if texture then texture:Show() end
end

local function hint(tip,bag,slot)
    if not tip or not tip.AddLine or not AT.db or AT.db.enabled==false or not C_Container
        or not isa(bag,"number") or bag<0 or bag>(NUM_BAG_SLOTS or 4) or bag%1~=0 or not id(slot) then return end
    local added=false
    local function append(...)
        tip:AddLine(...)
        added=true
    end
    local quest,_,category=AT.GetLeftoverQuestBagHint(bag,slot)
    if category=="review" then
        append("Rank Quest: review before discarding",1,.74,.32)
        append("Its quest is no longer in your log and was not turned in. Keep this item if you plan to take that quest again.",.9,.89,.86,true)
    elseif quest then
        append("Rank Quest: leftover quest item",1,.74,.32)
        append("Its recorded quest was turned in; no current quest in the checked log uses it. A future quest may still need it.",.9,.89,.86,true)
    end
    if bagQuestLinks then
        local selected,refs,item=bagQuestLinks(bag,slot)
        if refs and next(refs) then
            append("Nexus Quest Tools: quest links",.40,.91,.83)
            local order={}
            for qid in pairs(refs) do order[#order+1]=qid end
            table.sort(order)
            for _,qid in ipairs(order) do
                local on=call(C_QuestLog.IsOnQuest,qid)
                local done=call(C_QuestLog.IsQuestFlaggedCompleted,qid)
                local status
                if not clean(on) then status="Status not available"
                elseif on==true then status="In your quest log"
                elseif on~=false or not clean(done) then status="Status not available"
                elseif done==true then status="Turned in"
                elseif done==false then status="Not in your quest log"
                else status="Status not available" end
                local title=call(C_QuestLog.GetTitleForQuestID,qid)
                if not isa(title,"string") or title=="" then
                    local english=call(GetLocale)
                    local knownTitle=item==3248 and qid==252 and (english=="enUS" or english=="enGB") and "Translation to Ello"
                    title=verifiedQuestRefs[item] and verifiedQuestRefs[item][qid] or knownTitle or ("Quest #"..qid)
                end
                local origins=AT.ForeverQuestItemOrigins and AT.ForeverQuestItemOrigins[item]
                local role=origins and origins[qid]
                local relation=role==1 and "Reward from " or role==2 and "Provided by " or ""
                append(relation..title.." (#"..qid.."): "..status,.88,.92,.93,true)
            end
            if selected and AT.SearchRankQuestItem then append("Ctrl-click to find this quest in Rank Quest.",.67,.85,.83,true) end
        elseif item then
            local info=call(C_Container.GetContainerItemQuestInfo,bag,slot)
            if field(info,"isQuestItem")==true then
                append("Nexus Quest Tools: quest link not verified",.68,.76,.78,true)
            end
        end
    end
    -- The native bag tooltip was laid out before the secure post-hook
    -- ran. Show again after adding lines so Blizzard resizes the actual
    -- tooltip and its backdrop, not a separate overlay label.
    if added then
        showQuestItemBackdrop(tip)
        if tip.Show then tip:Show() end
    end
end
local function paint(button)
    if not button then return end
    local mark=painted[button]
    local bag,slot=call(button.GetBagID,button),call(button.GetID,button)
    local quest,_,category=AT.GetLeftoverQuestBagHint(bag,slot)
    if not quest then if mark then mark:Hide() end;return end
    if not mark then
        if not button.CreateTexture or (InCombatLockdown and InCombatLockdown()) then return end
        mark=button:CreateTexture(nil,"OVERLAY",nil,7)
        mark:SetSize(15,15);mark:SetPoint("TOPRIGHT",button,"TOPRIGHT",-1,-1)
        mark:SetTexture("Interface/AddOns/NQT/LeftoverTrash.tga")
        painted[button]=mark
    end
    if mark.SetVertexColor then
        if category=="review" then mark:SetVertexColor(1,.65,.27) else mark:SetVertexColor(1,1,1) end
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
    eachCustomBagButton(paint)
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
function AT.GetQuestBagMarkStatus()
    local shown=0
    for button,mark in pairs(painted) do
        if call(button.IsVisible,button)==true and call(mark.IsShown,mark)==true then shown=shown+1 end
    end
    local covered=completeLog and "quest-log coverage verified" or "quest-log coverage not verified"
    return "Bag marks: "..(enabled() and "enabled" or "disabled").."; "..covered.."; "..shown.." visible badges."
end
function AT.InitQuestLeftovers()
    if type(SlashCmdList)=="table" then
        SLASH_NEXUSQUESTBAGDIAGNOSTICS1="/nqtbag"
        SlashCmdList.NEXUSQUESTBAGDIAGNOSTICS=function()
            AT.RefreshQuestLeftovers()
            if AT.Say then AT.Say(AT.GetQuestBagMarkStatus()) end
        end
    end
    local frame=CreateFrame("Frame")
    for _,event in ipairs({"QUEST_LOG_UPDATE","QUEST_ACCEPTED","QUEST_REMOVED","QUEST_TURNED_IN","BAG_UPDATE_DELAYED",
        "BAG_OPEN","PLAYER_REGEN_ENABLED","PLAYER_ENTERING_WORLD","ADDON_LOADED"}) do pcall(frame.RegisterEvent,frame,event) end
    local scheduled
    local function refresh() scheduled=nil;AT.RefreshQuestLeftovers() end
    frame:SetScript("OnEvent",function(_,event,qid,isReplay)
        if event=="QUEST_TURNED_IN" then remember(qid)
        elseif event=="QUEST_REMOVED" and not isReplay then remember(qid,true) end
        -- Hide every old badge immediately before the next inventory/log pass.
        for _,mark in pairs(painted) do mark:Hide() end
        completeLog,scanned=false,false
        if scheduled then return end
        scheduled=true
        if C_Timer and C_Timer.After then
            C_Timer.After(0,refresh)
            if event=="QUEST_REMOVED" or event=="QUEST_TURNED_IN" then
                -- The quest event can arrive before the bag's active-item bit changes.
                C_Timer.After(.3,refresh)
            end
        else refresh() end
    end)
    AT.RefreshQuestLeftovers()
end

-- Ctrl-click quest links for stock bags.
do
local _,AT=...
local function clean(v) return not issecretvalue or not issecretvalue(v) end
local function kind(v,t) return clean(v) and type(v)==t end
local function id(v) return kind(v,"number") and v>0 and v%1==0 end
local function field(t,k)
    if not kind(t,"table") then return end
    local v=t[k]
    if clean(v) then return v end
end
local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b=pcall(fn,...)
    if ok and clean(a) then return a,clean(b) and b or nil end
end
local function questieDB()
    if Questie and Questie.IsForever and Questie.API and Questie.API.isReady and QuestieLoader then
        return call(QuestieLoader.ImportModule,QuestieLoader,"QuestieDB")
    end
end
local function matchQuestie(q,item)
    if field(q,"sourceItemId")==item then return true end
    local required=field(q,"requiredSourceItems")
    if kind(required,"table") then
        for _,v in pairs(required) do if clean(v) and v==item then return true end end
    end
    local list=field(q,"ObjectiveData")
    if kind(list,"table") then
        for _,obj in pairs(list) do
            if field(obj,"Type")=="item" and field(obj,"Id")==item then return true end
        end
    end
end

-- Use localized live item/objective labels only when the objective has no
-- explicit ID or item link. These hints never feed the discard classifier.
local function matchesNativeLabel(itemName,qid)
    if not kind(itemName,"string") or itemName=="" then return end
    local objectives=call(C_QuestLog.GetQuestObjectives,qid)
    if not kind(objectives,"table") then return end
    for _,obj in pairs(objectives) do
        local label=field(obj,"text")
        if field(obj,"type")=="item" and not id(field(obj,"itemID"))
            and kind(label,"string") and not label:find("|Hitem:",1,true) then
            label=label:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
            label=label:gsub("^%s*%d+%s*/%s*%d+%s+","")
                :gsub("%s*[:(]?%s+%d+%s*/%s*%d+%)?%s*$","")
                :gsub("^%s+",""):gsub("%s+$","")
            if label==itemName then return true end
        end
    end
end


local function associatedQuest(bag,slot)
    if not C_Container or not C_QuestLog or not kind(bag,"number") or bag%1~=0 or bag<0
        or bag>(NUM_BAG_SLOTS or 4) or not id(slot) then return end
    local item=call(C_Container.GetContainerItemID,bag,slot)
    if not id(item) then return end
    local db=questieDB()
    local matched,seen=nil,{}
    local refs,heldRefs={},{}
    local info=call(C_Container.GetContainerItemQuestInfo,bag,slot)
    local questItem=field(info,"isQuestItem")==true
    local itemName=questItem and call(C_Item and C_Item.GetItemNameByID,item)
    local textMatches={}
    local function register(qid)
        refs[qid]=true
        heldRefs[qid]=true
        matched=qid
    end
    local function inspect(qid,index)
        if not id(qid) or seen[qid] or call(C_QuestLog.IsOnQuest,qid)~=true then return end
        seen[qid]=true
        if not id(index) then index=call(C_QuestLog.GetLogIndexForQuestID,qid) end
        if id(index) and field(call(C_QuestLog.GetInfo,index),"questID")==qid then
            local link=call(GetQuestLogSpecialItemInfo,index)
            if kind(link,"string") and tonumber(link:match("|Hitem:(%d+)"))==item then register(qid) end
        end
        local native={}
        nativeObjectiveIDs(qid,native)
        if native[item] then register(qid)
        elseif matchesNativeLabel(itemName,qid) then textMatches[qid]=true end
        if db and matchQuestie(call(db.GetQuest,qid),item) then register(qid) end
    end
    local shown,total=call(C_QuestLog.GetNumQuestLogEntries)
    if not kind(shown,"number") or shown<0 or shown>1000 then shown=0 end
    for i=1,shown do
        local row=call(C_QuestLog.GetInfo,i)
        if field(row,"isHeader")==false and field(row,"isHidden")~=true then inspect(field(row,"questID"),i) end
    end
    if db and QuestieLoader then
        local aq=call(QuestieLoader.ImportModule,QuestieLoader,"ActiveQuests")
        local loaded=aq and call(aq.GetAll)
        if kind(loaded,"table") then for qid in pairs(loaded) do inspect(qid) end end
    end
    -- A bag quest ID alone can be an item that starts a quest. Require both
    -- native active-item evidence and a quest actually in the player log.
    local linked=field(info,"questID")
    if questItem and field(info,"isActive")==true and id(linked)
        and call(C_QuestLog.IsOnQuest,linked)==true then register(linked) end
    local inspected=0
    for _ in pairs(seen) do inspected=inspected+1 end
    if kind(total,"number") and total==inspected and not matched then
        local nameOnly=next(textMatches)
        if nameOnly and not next(textMatches,nameOnly) then register(nameOnly) end
    end
    -- Exact backlinks also let us inspect held quests beneath collapsed headings.
    -- A backlink alone (especially a starter/reward) never authorizes opening.
    local related=field(db and call(db.GetItem,db,item),"relatedQuests")
    if kind(related,"table") then
        for _,qid in pairs(related) do
            if id(qid) and db and matchQuestie(call(db.GetQuest,qid),item) then refs[qid]=true end
            inspect(qid)
        end
    end
    -- Standalone typed objectives are positive backlinks, including quests
    -- under collapsed headers. They do not authorize any discard marker.
    for qid in pairs(AT.GetForeverObjectiveQuests and AT.GetForeverObjectiveQuests(item) or {}) do
        refs[qid]=true
        if call(C_QuestLog.IsOnQuest,qid)==true then register(qid) end
    end
    for qid in pairs(verifiedQuestRefs[item] or {}) do
        refs[qid]=true
        if call(C_QuestLog.IsOnQuest,qid)==true then register(qid) end
    end
    local origins=AT.ForeverQuestItemOrigins and AT.ForeverQuestItemOrigins[item]
    if questItem and kind(origins,"table") then
        for qid in pairs(origins) do
            refs[qid]=true
            if call(C_QuestLog.IsOnQuest,qid)==true then register(qid) end
        end
    end
    local firstHeld=next(heldRefs)
    if firstHeld and next(heldRefs,firstHeld) then return heldRefs,refs,item end
    return matched,refs,item
end

bagQuestLinks=associatedQuest
local hookedButtons=setmetatable({},{__mode="k"})
local hookedFrames=setmetatable({},{__mode="k"})
local function onClick(button,mouse,down)
    if mouse~="LeftButton" or down==true or not AT.db or AT.db.enabled==false
        or call(IsControlKeyDown)~=true or call(IsShiftKeyDown)==true or call(IsAltKeyDown)==true
        or call(InCombatLockdown)==true
        or call(CursorHasItem)==true or call(SpellIsTargeting)==true then return end
    local bag,slot=call(button.GetBagID,button),call(button.GetID,button)
    local quest,refs,item=associatedQuest(bag,slot)
    if quest and AT.SearchRankQuestItem then
        AT.SearchRankQuestItem(quest,call(C_Item and C_Item.GetItemNameByID,item))
    elseif refs and next(refs) and AT.Say then
        AT.Say("No linked quest is in your log. Hover the item to see the known quest links.")
    end
end
local function installButton(button)
    if not button or hookedButtons[button] or type(button.HookScript)~="function"
        or type(button.GetBagID)~="function" or type(button.GetID)~="function" then return end
    if pcall(button.HookScript,button,"OnClick",onClick) then hookedButtons[button]=true end
end
local function refreshFrame(frame)
    if not frame or call(InCombatLockdown)==true then return end
    if type(frame.EnumerateValidItems)=="function" then
        for _,button in frame:EnumerateValidItems() do installButton(button) end
    end
    local name=call(frame.GetName,frame)
    if kind(name,"string") then
        for i=1,160 do
            local button=_G[name.."Item"..i]
            if button then installButton(button) end
        end
    end
end
local function installFrame(frame)
    if not frame then return end
    if not hookedFrames[frame] then
        local hook=function() refreshFrame(frame) end
        local post=type(frame.HookScript)=="function" and pcall(frame.HookScript,frame,"OnShow",hook)
        if hooksecurefunc and type(frame.UpdateItems)=="function" then
            post=pcall(hooksecurefunc,frame,"UpdateItems",hook) or post
        end
        if post then hookedFrames[frame]=true end
    end
    refreshFrame(frame)
end
local function refresh()
    if call(InCombatLockdown)==true then return end
    eachCustomBagButton(installButton)
    installFrame(_G.ContainerFrameCombinedBags)
    for i=1,(NUM_CONTAINER_FRAMES or 13) do installFrame(_G["ContainerFrame"..i]) end
end
function AT.InitBagQuestLink()
    local frame=CreateFrame("Frame")
    for _,event in ipairs({"ADDON_LOADED","BAG_OPEN","BAG_UPDATE_DELAYED","PLAYER_REGEN_ENABLED","PLAYER_ENTERING_WORLD"}) do
        pcall(frame.RegisterEvent,frame,event)
    end
    frame:SetScript("OnEvent",refresh)
    refresh()
end

end
