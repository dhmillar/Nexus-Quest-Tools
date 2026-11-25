local _, AT = ...

local function readable(value)
    return not issecretvalue or not issecretvalue(value)
end

local function validID(id)
    return readable(id) and type(id) == "number" and id > 0 and id % 1 == 0
end

local function textFor(id)
    if AT.IsQuestExcluded(id) then return "Nexus Quest Tools: Include quest again" end
    return "Nexus Quest Tools: Exclude this quest"
end

local function readFrame(frame, key)
    if not readable(frame) or not frame then return end
    local ok, result = pcall(function() return frame[key] end)
    if ok and readable(result) then return result end
end

local function invoke(frame, method)
    local fn = readFrame(frame, method)
    if type(fn) ~= "function" then return end
    local ok, result = pcall(fn, frame)
    if ok and readable(result) then return result end
end

local function changeOrder(id)
    local ok, result, position = AT.ToggleQuestTrackingOrder(id)
    if AT.Say then
        if ok and result == "added" then
            AT.Say(position and ("Quest added to tracking order #" .. position .. ".") or "Quest added to tracking order.")
        elseif ok then AT.Say("Quest removed from tracking order.")
        elseif result == "full" then AT.Say("Tracking order is full (10 quests). Ctrl-click a queued quest to remove it.")
        elseif result == "excluded" then AT.Say("Include this quest again before adding it to the order.")
        elseif result == "complete" then AT.Say("That quest is already complete.")
        else AT.Say("This quest could not be put in the tracking order.") end
    end
end

local function orderLabel(id)
    return AT.GetQuestOrderPosition(id) and "Remove from Tracking Order" or "Add to Tracking Order"
end

local function ctrlLeft(button, id)
    if button ~= "LeftButton" or not IsControlKeyDown or not IsControlKeyDown()
        or (IsShiftKeyDown and IsShiftKeyDown()) or (IsAltKeyDown and IsAltKeyDown())
        or not validID(id) then return false end
    changeOrder(id)
    return true
end
local function addOption(root, id)
    if not validID(id) or not AT.char then return end
    root:CreateButton(textFor(id), function() AT.ToggleQuestExcluded(id) end)
    root:CreateButton(orderLabel(id), function() changeOrder(id) end)
    if AT.GetTrackingOrderCount() > 0 then
        root:CreateButton("Reset Tracking Order", AT.ResetTrackingOrder)
    end
end

local function questFromFocus(predicate)
    local foci
    if GetMouseFoci then
        local ok, result = pcall(GetMouseFoci)
        if ok and readable(result) and type(result) == "table" then foci = result end
    end
    if not foci and GetMouseFocus then
        local ok, result = pcall(GetMouseFocus)
        if ok and readable(result) and result then foci = {result} end
    end
    if not foci then return end
    for _, initial in ipairs(foci) do
        local frame = initial
        for _ = 1, 10 do
            if not readable(frame) or not frame then break end
            local id = predicate(frame)
            if validID(id) then return id end
            local parent = invoke(frame, "GetParent")
            if parent == frame then break end
            frame = parent
        end
    end
end

local function directContextID(context)
    if validID(context) then return context end
    return readFrame(context, "questID")
end

local function trackerMenu(owner, root, context)
    local id = directContextID(context)
    if not validID(id) then
        id = questFromFocus(function(frame)
            local module = readFrame(frame, "parentModule")
            -- Forever sets menu owner to the tracker container, not the clicked row.
            if module and invoke(module, "GetContextMenuParent") == owner then
                return readFrame(frame, "id")
            end
        end)
    end
    addOption(root, id)
end

local function questLogMenu(owner, root, context)
    -- The log title button owns its right-click menu. The same tag is also
    -- used by user waypoints; those have no questID and get no addon entry.
    local id = directContextID(context)
    if not validID(id) then id = readFrame(owner, "questID") end
    addOption(root, id)
end
local hookedQuestie
local function hookQuestie()
    if hookedQuestie or not QuestieLoader or not hooksecurefunc then return end
    local ok, tracker = pcall(QuestieLoader.ImportModule, QuestieLoader, "TrackerMenu")
    if not ok or type(tracker) ~= "table" or type(tracker.minMaxQuestOption) ~= "function" then return end
    hookedQuestie = pcall(hooksecurefunc, tracker, "minMaxQuestOption", function(list, quest)
        local id = readFrame(quest, "Id")
        if type(list) ~= "table" or not validID(id) or not AT.char then return end
        list[#list + 1] = { text = textFor(id), func = function() AT.ToggleQuestExcluded(id) end }
        list[#list + 1] = { text = orderLabel(id), func = function() changeOrder(id) end }
        if AT.GetTrackingOrderCount() > 0 then
            list[#list + 1] = { text = "Reset Tracking Order", func = AT.ResetTrackingOrder }
        end
    end)
end

local rows = setmetatable({}, {__mode="k"})
local attachedScrollBoxes = setmetatable({}, {__mode="k"})
local function nativeLogID(row)
    if readFrame(row, "Checkbox") then return readFrame(row, "questID") end
end

local function questieLineID(row)
    if readFrame(row, "mode") == "quest" then return readFrame(readFrame(row, "Quest"), "Id") end
end

local function trackerBlockID(block)
    local module = readFrame(block, "parentModule")
    if module and (module == QuestObjectiveTracker or module == CampaignQuestObjectiveTracker) then
        return readFrame(block, "id")
    end
end

local function nativeLogObjectiveID(row)
    return readFrame(row, "questID")
end

local function questieObjectiveID(line)
    if readFrame(line, "mode") == "objective" then return readFrame(readFrame(line, "Quest"), "Id") end
end

local function redrawInline(row, data, index)
    local label = readFrame(row, data.label)
    if not label or type(label.GetText) ~= "function" or type(label.SetText) ~= "function" then return false end
    local text = label:GetText()
    if not readable(text) or type(text) ~= "string" then return true end
    local previous = data.prefix
    local original = text
    if previous and text:sub(1, #previous) == previous then original = text:sub(#previous + 1) end
    local prefix = index and original ~= "" and ("|cff4af2db" .. index .. ".|r ") or nil
    local wanted = (prefix or "") .. original
    if wanted ~= text then label:SetText(wanted) end
    data.prefix = prefix
    return true
end
local function fullMapOpen()
    return invoke(WorldMapFrame, "IsMaximized") == true
        and invoke(WorldMapFrame, "IsShown") ~= false
end
local function redraw(row, data)
    local index = not (data.hideOnMax and fullMapOpen()) and AT.GetQuestOrderPosition(data.getID(row))
    if data.inline and redrawInline(row, data, index) then return end
    if index then
        if not data.badge then
            local label = readFrame(row, data.label)
            if not label or not row.CreateFontString then return end
            data.badge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            data.badge:SetPoint("TOPRIGHT", label, "TOPLEFT", -4, 0)
            data.badge:SetTextColor(0.3, 0.95, 0.82)
        end
        if data.last ~= index then data.badge:SetText(tostring(index)) end
        data.badge:Show()
    elseif data.badge then
        data.badge:Hide()
    end
    data.last = index
end

local function attachClick(row, data, intercept, strict)
    if data.clickAttached then return end
    if intercept and type(row.GetScript) == "function" and type(row.SetScript) == "function" then
        -- The Blizzard title template's XML installs an ordinary OnClick
        -- script. Consume only Ctrl+left; keep its original for all other clicks.
        if InCombatLockdown and InCombatLockdown() then return end
        local protected = row.IsProtected and row:IsProtected()
        if not protected then
            local original = row:GetScript("OnClick")
            if type(original) == "function" then
                local ok = pcall(row.SetScript, row, "OnClick", function(self, button, ...)
                    if ctrlLeft(button, data.getID(self)) then return end
                    return original(self, button, ...)
                end)
                if ok then data.clickAttached = true; return end
            end
        end
    end
    if not strict and type(row.HookScript) == "function" then
        data.clickAttached = pcall(row.HookScript, row, "OnClick", function(self, button)
            ctrlLeft(button, data.getID(self))
        end)
    end
end
local function observe(row, getID, label, hookClick, intercept, inline, hideOnMax)
    if not row then return end
    local data = rows[row]
    if not data then
        data = {getID=getID, label=label, inline=inline, hideOnMax=hideOnMax}
        rows[row] = data
    end
    if hookClick then attachClick(row, data, intercept) end
    redraw(row, data)
end

local function logRow(row)
    if not row then return end
    if rows[row] or (validID(nativeLogID(row)) and readFrame(row, "Text")) then
        observe(row, nativeLogID, "Text", true, true, false, true)
    end
end

local hookedLogUpdate, scanMapCircles
local function scanLog()
    local scrollFrame = QuestScrollFrame
    if not scrollFrame and QuestMapFrame and QuestMapFrame.QuestsFrame then
        scrollFrame = QuestMapFrame.QuestsFrame.ScrollFrame
    end
    if not hookedLogUpdate and type(QuestLogQuests_Update) == "function" and hooksecurefunc then
        -- Refreshing the log releases and repopulates its title pool.
        hookedLogUpdate = pcall(hooksecurefunc, "QuestLogQuests_Update", function() pcall(scanLog) end)
    end
    local pool = scrollFrame and scrollFrame.titleFramePool
    if pool and type(pool.EnumerateActive) == "function" then
        -- Forever uses a standard scroll frame with pooled quest title buttons.
        for row in pool:EnumerateActive() do logRow(row) end
        local objectives = scrollFrame.objectiveFramePool
        if objectives and type(objectives.EnumerateActive) == "function" then
            for row in objectives:EnumerateActive() do
                if validID(nativeLogObjectiveID(row)) and readFrame(row, "Text") then
                    observe(row, nativeLogObjectiveID, "Text", false, false, true, true)
                end
            end
        end
        if scanMapCircles then scanMapCircles(scrollFrame) end
        return
    end
    local box = scrollFrame and scrollFrame.ScrollBox
    if box and box.ForEachFrame then
        local events = ScrollBoxListMixin and ScrollBoxListMixin.Event
        if not attachedScrollBoxes[box] and events and events.OnDataRangeChanged and box.RegisterCallback then
            attachedScrollBoxes[box] = true
            box:RegisterCallback(events.OnDataRangeChanged, function() box:ForEachFrame(logRow) end, AT)
        end
        if not scrollFrame.IsVisible or scrollFrame:IsVisible() then box:ForEachFrame(logRow) end
    end
end

local poiVisuals = setmetatable({}, {__mode="k"})
local blockCircle = setmetatable({}, {__mode="k"})
local blockCircleHooks = setmetatable({}, {__mode="k"})
local circleSizes = setmetatable({}, {__mode="k"})

local function hideCircle(poi, owner)
    local visual = poi and poiVisuals[poi]
    if not visual or visual.owner ~= owner then return end
    visual.overlay:Hide()
    visual.owner = nil
end

local function drawCircle(poi, block, id, size)
    local index = AT.GetQuestOrderPosition(id)
    local poiID = invoke(poi, "GetQuestID")
    if not index or not poi or (validID(poiID) and poiID ~= id)
        or (poi.IsShown and not poi:IsShown()) then
        local visual = poi and poiVisuals[poi]
        local owner = validID(poiID) and poiID == id and visual and visual.owner or block
        hideCircle(poi, owner)
        return false
    end
    local visual = poiVisuals[poi]
    if not visual then
        -- Draw above all of the POI button's native textures without
        -- adding any mouse target or changing the underlying circle.
        local overlay = CreateFrame("Frame", nil, poi)
        overlay:SetPoint("CENTER", poi, "CENTER", -1, 0)
        overlay:SetSize(24, 24)
        overlay:SetFrameLevel(poi:GetFrameLevel() + 4)
        overlay:EnableMouse(false)
        local backing = overlay:CreateTexture(nil, "ARTWORK")
        backing:SetAllPoints(overlay)
        backing:SetTexture("Interface/AddOns/NQT/QueueBadge.tga")
        local number = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        number:SetPoint("CENTER", overlay, "CENTER", 0, 0)
        number:SetTextColor(1, 1, 1)
        number:SetShadowColor(0, 0, 0, 1)
        number:SetShadowOffset(1, -1)
        visual = {overlay=overlay, number=number}
        poiVisuals[poi] = visual
    end
    visual.owner = block
    size = size or 24
    if visual.index ~= index or visual.size ~= size then
        visual.overlay:SetSize(size, size)
        visual.number:SetText(tostring(index))
        -- Fit even the two-digit tenth entry entirely inside the dark disc.
        visual.number:SetFont(STANDARD_TEXT_FONT or "Fonts/FRIZQT__.TTF", math.floor(size * (index == 10 and .58 or .72) + .5), "OUTLINE")
        visual.index, visual.size = index, size
    end
    visual.overlay:Show()
    return true
end

local function drawBlockCircle(block)
    local poi = readFrame(block, "poiButton")
    local previous = blockCircle[block]
    if previous and previous ~= poi then hideCircle(previous, block) end
    if drawCircle(poi, block, trackerBlockID(block), circleSizes[block]) then
        blockCircle[block] = poi
    else
        blockCircle[block] = nil
    end
end
local function observeBlockCircle(block)
    if not blockCircleHooks[block] and hooksecurefunc then
        blockCircleHooks[block] = true
        if type(block.AddPOIButton) == "function" then
            pcall(hooksecurefunc, block, "AddPOIButton", drawBlockCircle)
        end
        if type(block.CheckAndReleasePOIButton) == "function" then
            pcall(hooksecurefunc, block, "CheckAndReleasePOIButton", function(self)
                hideCircle(blockCircle[self], self)
                blockCircle[self] = nil
            end)
        end
    end
    drawBlockCircle(block)
end
local function layoutSize(list)
    local sizes, positions = {}, {}
    for _, pair in ipairs(list) do
        local owner, poi = pair.owner, pair.poi
        sizes[owner] = 24
        if poi and type(poi.GetCenter)=="function" then
            local x,y = poi:GetCenter()
            if readable(x) and readable(y) and type(x)=="number" and type(y)=="number" then
                positions[#positions+1] = {block=owner, x=x, y=y}
                local left = invoke(readFrame(owner,pair.label), "GetLeft")
                if type(left)=="number" and left>x then
                    sizes[owner] = math.min(24, math.max(12, 2*(left-x-1)))
                end
            end
        end
    end
    table.sort(positions,function(a,b) return a.y>b.y end)
    for i=2,#positions do
        local a,b=positions[i-1],positions[i]
        if math.abs(a.x-b.x)<12 then
            local fit=math.max(12, math.floor(a.y-b.y-2))
            sizes[a.block] = math.min(fit,sizes[a.block])
            sizes[b.block] = math.min(fit,sizes[b.block])
        end
    end
    return sizes
end

local presses = setmetatable({}, {__mode="k"})
local function installPreciseClick(button, getID)
    if not button then return end
    local data = presses[button]
    if not data then data={getID=getID}; presses[button]=data end
    attachClick(button,data,true,true)
end

local function idForHeader(button)
    return trackerBlockID(invoke(button,"GetParent"))
end
local function idForTrackerPOI(button)
    local block = invoke(button,"GetParent")
    if readFrame(block,"poiButton") == button then return trackerBlockID(block) end
end

local mapCircles = setmetatable({}, {__mode="k"})
local function idForMapPOI(button)
    if not fullMapOpen() then return end
    local id = nativeLogID(readFrame(button,"parent"))
    if id == invoke(button,"GetQuestID") then return id end
end
scanMapCircles = function(scrollFrame)
    local pool = readFrame(readFrame(scrollFrame,"Contents"),"buttonPool")
    local seen, displayed={},{}
    if fullMapOpen() and pool and type(pool.EnumerateActive) == "function" then
        for poi in pool:EnumerateActive() do
            local row = readFrame(poi,"parent")
            local id = idForMapPOI(poi)
            if validID(id) then
                displayed[#displayed+1]={owner=row,poi=poi,id=id,label="Text"}
                installPreciseClick(poi,idForMapPOI)
            end
        end
        local sizes=layoutSize(displayed)
        for _,pair in ipairs(displayed) do
            if drawCircle(pair.poi,pair.owner,pair.id,sizes[pair.owner]) then seen[pair.poi]=pair.owner end
        end
    end
    for poi, owner in pairs(mapCircles) do
        if seen[poi] ~= owner then hideCircle(poi, owner); mapCircles[poi]=nil end
    end
    for poi, owner in pairs(seen) do mapCircles[poi]=owner end
end

local function scanNativeTracker(module)
    if not module or not module.EnumerateActiveBlocks then return end
    local active={}
    module:EnumerateActiveBlocks(function(block)
        if not validID(trackerBlockID(block)) then return end
        local poi = readFrame(block,"poiButton")
        active[#active+1] = {owner=block,poi=poi,label="HeaderText"}
        installPreciseClick(readFrame(block,"HeaderButton"),idForHeader)
        installPreciseClick(poi,idForTrackerPOI)
    end)
    local sizes=layoutSize(active)
    for _, pair in ipairs(active) do
        circleSizes[pair.owner] = sizes[pair.owner]
        observeBlockCircle(pair.owner)
    end
end
local function scanQuestie()
    if not QuestieLoader or not Questie or not Questie.IsForever then return end
    local ok, pool = pcall(QuestieLoader.ImportModule, QuestieLoader, "TrackerLinePool")
    if ok and pool and pool.ForEachQuestTitleLine then
        pool.ForEachQuestTitleLine(function(row)
            observe(row, questieLineID, "label", true, false, true)
        end)
        if type(pool.UpdateObjectiveLines) == "function" then
            pool.UpdateObjectiveLines(function(row)
                if validID(questieObjectiveID(row)) then
                    observe(row, questieObjectiveID, "label", false, false, true)
                end
            end)
        end
    end
end

function AT.RefreshQuestOrderBadges()
    -- Each integration is independent: an optional incompatible tracker
    -- must not interfere with the other surfaces or the quest engine.
    pcall(scanLog)
    pcall(scanNativeTracker, QuestObjectiveTracker)
    pcall(scanNativeTracker, CampaignQuestObjectiveTracker)
    pcall(scanQuestie)
    for block in pairs(blockCircle) do pcall(drawBlockCircle, block) end
    for row, data in pairs(rows) do
        if data.badge or data.inline then pcall(redraw, row, data) end
    end
end
local initialized
function AT.InitQuestMenus()
    if initialized then return end
    initialized = true
    if Menu and type(Menu.ModifyMenu) == "function" then
        Menu.ModifyMenu("MENU_QUEST_OBJECTIVE_TRACKER", trackerMenu)
        Menu.ModifyMenu("MENU_QUEST_MAP_LOG_TITLE", questLogMenu)
    end
    hookQuestie()
    AT.RefreshQuestOrderBadges()
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(0.4, AT.RefreshQuestOrderBadges)
    end
    if not hookedQuestie and CreateFrame then
        local listener = CreateFrame("Frame")
        listener:RegisterEvent("ADDON_LOADED")
        listener:SetScript("OnEvent", function(self, _, addon)
            if addon == "Questie" then
                hookQuestie()
                if hookedQuestie then self:UnregisterEvent("ADDON_LOADED") end
            end
        end)
    end
end












-- Rank Quest owns its menu and confirmation. Questie can supply its optional
-- map integrations, but is not required for native quest actions.
local function menuCall(fn,...)
    if type(fn)~="function" then return end
    local ok,v=pcall(fn,...)
    if ok and readable(v) then return v end
end

local function questLogEntry(id)
    local q=C_QuestLog
    if not q or not validID(id) or menuCall(q.IsOnQuest,id)==false then return end
    local index=menuCall(q.GetLogIndexForQuestID,id)
    local info=validID(index) and menuCall(q.GetInfo,index)
    if readFrame(info,"questID")==id and not readFrame(info,"isHeader") and not readFrame(info,"isHidden") then return info end
end

local function rankEnabled()
    return AT.db and AT.db.enabled and AT.db.questHUDEnabled and not AT.db.questHUDCollapsed
end
local function combat()
    return InCombatLockdown and InCombatLockdown()
end

local function withSelectedQuest(id,action)
    local q=C_QuestLog
    if combat() or not questLogEntry(id) or not q.GetSelectedQuest or not q.SetSelectedQuest then return end
    local prior=menuCall(q.GetSelectedQuest)
    menuCall(q.SetSelectedQuest,id)
    if menuCall(q.GetSelectedQuest)~=id then return end
    local ok,result=pcall(action,q)
    if (validID(prior) or prior==0) and prior~=id and menuCall(q.GetSelectedQuest)==id then
        menuCall(q.SetSelectedQuest,prior)
    end
    return ok and result
end

local abandonKey="AUTOTRACK_RANK_QUEST_ABANDON"
local pendingAbandon
function AT.InvalidateRankQuestAbandon(id)
    if pendingAbandon and pendingAbandon.id==id then pendingAbandon=nil end
end
local function canAbandon(id)
    local q=C_QuestLog
    return q and questLogEntry(id) and q.GetSelectedQuest and q.SetSelectedQuest and q.GetAbandonQuest
        and (q.SetAbandonQuest or SetAbandonQuest) and (q.AbandonQuest or AbandonQuest)
        and (not q.CanAbandonQuest or menuCall(q.CanAbandonQuest,id)==true)
end
local function requestAbandon(id)
    if combat() or not rankEnabled() or not canAbandon(id) or not StaticPopup_Show or not StaticPopupDialogs then return end
    local entry=questLogEntry(id)
    local title=readFrame(entry,"title") or menuCall(C_QuestLog.GetTitleForQuestID,id)
    if type(title)~="string" then return end
    if not StaticPopupDialogs[abandonKey] then
        StaticPopupDialogs[abandonKey]={
            text='Abandon "%s"? You will lose quest progress and may lose quest items.',
            button1="Abandon Quest",button2=CANCEL or "Cancel",
            timeout=0,hideOnEscape=true,whileDead=true,
            OnCancel=function(_,data)
                if data==pendingAbandon then pendingAbandon=nil end
            end,
            OnAccept=function(_,data)
                if not data or data~=pendingAbandon then return end
                pendingAbandon=nil
                local id=data.id
                if not rankEnabled() or combat() or not canAbandon(id) then return end
                local currentTitle=readFrame(questLogEntry(id),"title") or menuCall(C_QuestLog.GetTitleForQuestID,id)
                if currentTitle~=data.title then return end
                local done=withSelectedQuest(id,function(q)
                    local stage=q.SetAbandonQuest or SetAbandonQuest
                    local abandon=q.AbandonQuest or AbandonQuest
                    if not pcall(stage) or menuCall(q.GetAbandonQuest)~=id then return end
                    return pcall(abandon)
                end)
                if done then
                    if AT.RefreshRankQuestAfterAbandon then AT.RefreshRankQuestAfterAbandon(id) end
                elseif AT.Say then AT.Say("WoW did not let Rank Quest abandon that quest.") end
            end,
        }
    end
    if pendingAbandon and StaticPopup_Hide then StaticPopup_Hide(abandonKey) end
    local data={id=id,title=title}
    pendingAbandon=data
    if not StaticPopup_Show(abandonKey,title,nil,data) and pendingAbandon==data then pendingAbandon=nil end
end

local function openDetails(id)
    local fn=QuestMapFrame_OpenToQuestDetails or (QuestUtil and QuestUtil.OpenQuestDetails)
    if not combat() then menuCall(fn,id) end
end

local function openQuestURL(id)
    if combat() or not StaticPopupDialogs or not StaticPopup_Show then return end
    local key="AUTOTRACK_RANK_QUEST_URL"
    StaticPopupDialogs[key]=StaticPopupDialogs[key] or {
        text="Wowhead Quest URL",button1=CLOSE or "Close",hasEditBox=true,editBoxWidth=285,timeout=0,hideOnEscape=true,
        OnShow=function(self,data)
            local box=(self.GetEditBox and self:GetEditBox()) or self.editBox or self.EditBox
            if box and data then box:SetText(data);box:HighlightText() end
        end,
    }
    StaticPopup_Show(key,nil,nil,"https://www.wowhead.com/forever/quest="..id)
end

local function questieMenuFor(id)
    if not QuestieLoader or not Questie or not Questie.API or not Questie.API.isReady then return end
    local function import(key) return menuCall(QuestieLoader.ImportModule,QuestieLoader,key) end
    local tracker,data,translate=import("TrackerMenu"),import("TrackerData"),import("l10n")
    local quest=menuCall(readFrame(data,"GetQuest"),id)
    if readFrame(quest,"Id")~=id then return end
    local list=menuCall(readFrame(tracker,"GetMenuForQuest"),tracker,quest)
    if type(list)~="table" then return end
    return list,translate
end

local function cleanLabel(s)
    if type(s)=="string" and readable(s) then return (s:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):lower()) end
end

function AT.OpenRankQuestMenu(owner,id,controls)
    if not rankEnabled() or not questLogEntry(id) or not MenuUtil or not MenuUtil.CreateContextMenu then return end
    local q=C_QuestLog
    local function live(fn)
        return function()
            if rankEnabled() and questLogEntry(id) then fn() end
        end
    end
    local function questieAction(fn)
        return live(function() if not combat() then menuCall(fn) end end)
    end
    local list,translate=questieMenuFor(id)
    local function key(label)
        local ok,value=pcall(function() return translate and translate(label) end)
        return cleanLabel(ok and value or label) or cleanLabel(label)
    end
    local allowed={}
    for _,label in ipairs({"Objectives","Show on Map","Hide Icons","Show Icons","Set |cFF54e33bTomTom|r Target","WoWHead URL","Show in Quest Log"}) do
        allowed[key(label)]=true
    end
    local function put(root,entry,depth)
        local label=readFrame(entry,"text")
        if not cleanLabel(label) then return end
        local submenu=readFrame(entry,"menuList")
        local fn=readFrame(entry,"func")
        if type(submenu)=="table" and depth<3 then
            local node=root:CreateButton(label)
            for _,child in ipairs(submenu) do put(node,child,depth+1) end
        elseif type(fn)=="function" then
            root:CreateButton(label,questieAction(fn))
        end
    end
    MenuUtil.CreateContextMenu(owner,function(_,root)
        local title=readFrame(questLogEntry(id),"title") or ("Quest #"..id)
        local shown={}
        for _,entry in ipairs(list or {}) do
            if entry.isTitle and cleanLabel(entry.text) then title=entry.text;break end
        end
        root:CreateTitle(title)
        for _,entry in ipairs(list or {}) do
            local label=cleanLabel(entry.text)
            if not entry.isTitle and allowed[label] and not shown[label] then
                put(root,entry,0);shown[label]=true
            end
        end
        if not shown[key("Show on Map")] then root:CreateButton("Show on Map",live(function() openDetails(id) end)) end
        if not shown[key("Show in Quest Log")] then root:CreateButton("Show in Quest Log",live(function() openDetails(id) end)) end
        if not shown[key("WoWHead URL")] then root:CreateButton("Wowhead URL",live(function() openQuestURL(id) end)) end
        if IsInGroup and IsInGroup() and menuCall(q.IsPushableQuest,id)==true and (QuestLogPushQuest or q.QuestLogPushQuest) then
            root:CreateButton("Share Quest",live(function()
                if IsInGroup() and menuCall(q.IsPushableQuest,id)==true then
                    withSelectedQuest(id,function() return pcall(QuestLogPushQuest or q.QuestLogPushQuest) end)
                end
            end))
        end
        local getLink=q.GetQuestLink or GetQuestLink
        if menuCall(getLink,id) then
            root:CreateButton("Link Quest to chat",live(function()
                local link=menuCall(getLink,id)
                if type(link)~="string" then return end
                if ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() and ChatEdit_InsertLink then ChatEdit_InsertLink(link)
                elseif ChatFrame_OpenChat then ChatFrame_OpenChat(link) end
            end))
        end
        if root.CreateDivider then root:CreateDivider() end
        local excluded=AT.IsQuestExcluded(id)
        local pinned=AT.GetQuestHUDManualFocus and AT.GetQuestHUDManualFocus()==id
        if not excluded and AT.ToggleQuestHUDManualFocus then
            root:CreateButton(pinned and "Unfocus" or "Focus Quest",live(function()
                if (AT.GetQuestHUDManualFocus()==id)==pinned then AT.ToggleQuestHUDManualFocus(id);controls.refresh() end
            end))
        end
        root:CreateButton(controls.minimized and "Maximize Quest" or "Minimize Quest",live(controls.toggleMinimized))
        root:CreateButton(controls.locked and "Unlock Tracker" or "Lock Tracker",live(controls.toggleLock))
        if not excluded then
            root:CreateButton("Untrack Quest",live(function()
                if combat() or AT.IsQuestExcluded(id) then return end
                if AT.GetQuestHUDManualFocus and AT.GetQuestHUDManualFocus()==id then AT.ToggleQuestHUDManualFocus(id) end
                menuCall(q.RemoveQuestWatch,id)
                if AT.SetQuestExcluded then AT.SetQuestExcluded(id,true) else AT.ToggleQuestExcluded(id) end
                controls.refresh()
            end))
        end
        root:CreateButton(textFor(id),live(function() AT.ToggleQuestExcluded(id);controls.refresh() end))
        if AT.GetQuestOrderPosition(id) or (not excluded and not menuCall(AT.IsQuestReadyForTurnIn,id)) then
            root:CreateButton(orderLabel(id),live(function() changeOrder(id);controls.refresh() end))
        end
        if AT.GetTrackingOrderCount()>0 then
            root:CreateButton("Reset Tracking Order",live(function() AT.ResetTrackingOrder();controls.refresh() end))
        end
        if root.CreateDivider then root:CreateDivider() end
        if canAbandon(id) then
            local entry=root:CreateButton("Abandon Quest",live(function() requestAbandon(id) end))
            if combat() and entry and entry.SetEnabled then entry:SetEnabled(false) end
        end
        root:CreateButton(CANCEL or "Cancel",function() end)
    end)
end
