local _, AT = ...
local bags, quests = C_Container, C_QuestLog
local pending, offers, seen, accepted = {}, {}, {}, {}
local counts, button, observer, active, scheduled
local SIZE = 38

local function readable(v, kind)
    return (not issecretvalue or not issecretvalue(v)) and type(v) == kind
end
local function positive(v)
    return readable(v,"number") and v > 0 and v < math.huge and v % 1 == 0
end
local function call(fn,...)
    if type(fn) ~= "function" then return end
    local ok, result = pcall(fn,...)
    if ok and (not issecretvalue or not issecretvalue(result)) then return result end
end
local function field(t,k)
    if readable(t,"table") then
        local v=t[k]
        if not issecretvalue or not issecretvalue(v) then return v end
    end
end
local function locked() return InCombatLockdown and InCombatLockdown() end
local function enabled() return AT.db and AT.db.enabled and AT.db.questStartItemAlert ~= false end
local function questFor(bag,slot)
    local info=call(bags.GetContainerItemQuestInfo,bag,slot)
    local quest=field(info,"questID")
    if positive(quest) and not accepted[quest] and field(info,"isActive")~=true
        and call(quests.IsOnQuest,quest)~=true
        and call(quests.IsQuestFlaggedCompleted,quest)~=true then return quest end
end
local function snapshot(check)
    local totals, starters = {}, {}
    for bag=0,NUM_BAG_SLOTS or 4 do
        local size=call(bags.GetContainerNumSlots,bag)
        for slot=1,positive(size) and math.min(100,size) or 0 do
            local info=call(bags.GetContainerItemInfo,bag,slot)
            local item=field(info,"itemID") or call(bags.GetContainerItemID,bag,slot)
            if positive(item) then
                local qty=field(info,"stackCount")
                totals[item]=(totals[item] or 0)+(positive(qty) and qty or 1)
                if check and check(item) and not starters[item] then
                    local quest=questFor(bag,slot)
                    if quest then
                        starters[item]={item=item,quest=quest,texture=field(info,"iconFileID"),
                            link=field(info,"hyperlink"),bag=bag,slot=slot}
                    end
                end
            end
        end
    end
    return totals,starters
end
local function hide()
    active=nil
    button:SetAttribute("type1",nil)
    button:SetAttribute("item1",nil)
    button:Hide()
    if GameTooltip and call(GameTooltip.IsOwned,GameTooltip,button) then GameTooltip:Hide() end
end
local function playerPlatePoint()
    local p=C_NamePlate and call(C_NamePlate.GetNamePlateForUnit,"player")
    if not p and C_NamePlate then p=call(C_NamePlate.GetNamePlateForUnit,"nameplateplayer") end
    if not p or call(p.IsForbidden,p)==true or call(p.IsVisible,p)~=true then return end
    local x,y,scale=p:GetCenter(),p:GetTop(),p:GetEffectiveScale()
    local ratio=scale/UIParent:GetEffectiveScale()
    return x*ratio,y*ratio+9
end
local function position()
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    local ok,x,y=pcall(playerPlatePoint)
    if not ok or not readable(x,"number") or not readable(y,"number") or x<0 or x>w or y<0 or y>h then
        x,y=w/2,h*.62
    end
    x,y=math.max(SIZE/2,math.min(w-SIZE/2,x)),math.max(0,math.min(h-SIZE,y))
    button:ClearAllPoints()
    button:SetPoint("BOTTOM",UIParent,"BOTTOMLEFT",x,y)
end
local function render(starters)
    if locked() then return end
    while #offers>0 do
        local offer=offers[1]
        local entry=starters[offer.item]
        if entry and entry.quest==offer.quest then
            if not active or active.item~=entry.item or not button:IsShown() then
                button.icon:SetTexture(entry.texture or (C_Item and call(C_Item.GetItemIconByID,entry.item)) or 134400)
                button:SetAttribute("type1","item")
                button:SetAttribute("item1","item:"..entry.item)
                position()
                button:Show()
            end
            active=entry
            return
        end
        table.remove(offers,1)
    end
    if active or button:IsShown() then hide() end
end
local refresh
local function scheduleRetry()
    if scheduled or not C_Timer or not C_Timer.After then return end
    scheduled=true
    C_Timer.After(.5,function()
        scheduled=nil
        refresh()
    end)
end
refresh=function(reset)
    if not button then return end
    if reset or not counts or not enabled() then
        counts,pending,offers=enabled() and snapshot() or nil,{},{}
        if not enabled() then seen={} end
        if not locked() then hide() end
        return
    end
    local queued={}
    for _,offer in ipairs(offers) do queued[offer.item]=true end
    local totals,starters=snapshot(function(item)
        return queued[item] or pending[item] or not counts[item] and not seen[item]
    end)
    local now=call(GetTime) or 0
    for item in pairs(totals) do
        if not seen[item] and not counts[item] then pending[item]=now+4 end
    end
    counts=totals
    local found={}
    for item,expires in pairs(pending) do
        local entry=starters[item]
        if entry then
            found[#found+1]=entry
            seen[item],pending[item]=true,nil
        elseif not totals[item] or now>=expires then pending[item]=nil end
    end
    table.sort(found,function(a,b)
        return a.bag==b.bag and a.slot<b.slot or a.bag<b.bag
    end)
    for _,entry in ipairs(found) do offers[#offers+1]=entry end
    if next(pending) then scheduleRetry() end
    render(starters)
end
function AT.RefreshQuestStartItemAlert()
    refresh()
end
function AT.InitQuestStartItemAlert()
    if observer or not bags or not quests or not UIParent or not RegisterStateDriver or locked() then return end
    button=CreateFrame("Button",nil,UIParent,"SecureActionButtonTemplate,SecureHandlerStateTemplate")
    button:SetSize(SIZE,SIZE)
    button:SetFrameStrata("HIGH")
    button:RegisterForClicks("LeftButtonUp","RightButtonUp")
    button:SetAttribute("useOnKeyDown",false)
    button.icon=button:CreateTexture(nil,"ARTWORK")
    button.icon:SetPoint("TOPLEFT",2,-2)
    button.icon:SetPoint("BOTTOMRIGHT",-2,2)
    button.icon:SetTexCoord(.06,.94,.06,.94)
    local rim=button:CreateTexture(nil,"BACKGROUND")
    rim:SetAllPoints()
    rim:SetColorTexture(.92,.71,.23,1)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
    button:SetAttribute("_onstate-startercombat",[[
        if newstate == "locked" then
            self:SetAttribute("type1",nil)
            self:SetAttribute("item1",nil)
            self:Hide()
        end
    ]])
    RegisterStateDriver(button,"startercombat","[combat] locked; free")
    button:SetScript("PreClick",function(_,key)
        if locked() then return end
        local offer=active
        if not offer then hide(); return end
        if key=="RightButton" then
            table.remove(offers,1)
            hide()
            return
        end
        local _,starters=snapshot(function(item) return item==offer.item end)
        local entry=starters[offer.item]
        if not enabled() or not entry or entry.quest~=offer.quest then hide() end
    end)
    button:SetScript("PostClick",function(_,key)
        if key=="RightButton" and not locked() then refresh() end
    end)
    button:SetScript("OnEnter",function(self)
        if not active or not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_TOP")
        if not active.link or type(GameTooltip.SetHyperlink)~="function"
            or not pcall(GameTooltip.SetHyperlink,GameTooltip,active.link) then
            GameTooltip:SetText("Quest-starting item")
        end
        GameTooltip:AddLine("Click to open the quest offer. Right-click to dismiss.",1,.85,.52,true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave",function(self)
        if GameTooltip and call(GameTooltip.IsOwned,GameTooltip,self) then GameTooltip:Hide() end
    end)
    local elapsed=0
    button:SetScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt
        if elapsed>=.12 and not locked() then elapsed=0;position() end
    end)
    observer=CreateFrame("Frame")
    for _,event in ipairs({"BAG_UPDATE_DELAYED","QUEST_ACCEPTED","QUEST_LOG_UPDATE","QUEST_DETAIL",
        "PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","UI_SCALE_CHANGED"}) do observer:RegisterEvent(event) end
    observer:SetScript("OnEvent",function(_,event,initial,reloaded)
        if event=="QUEST_ACCEPTED" then
            local quest=positive(reloaded) and reloaded or initial
            if positive(quest) then accepted[quest]=true end
        end
        if not enabled() then return end
        if event=="UI_SCALE_CHANGED" then
            if active and button:IsShown() and not locked() then position() end
            return
        end
        if event=="QUEST_LOG_UPDATE" or event=="QUEST_DETAIL" or event=="QUEST_ACCEPTED" or event=="PLAYER_REGEN_ENABLED" then
            if not next(pending) and #offers==0 then return end
        end
        refresh(event=="PLAYER_ENTERING_WORLD" and (initial or reloaded))
    end)
    refresh(true)
end

