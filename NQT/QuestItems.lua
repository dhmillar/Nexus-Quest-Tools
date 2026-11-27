local _,AT=...
local pool,targets={},{}
local viewport,verify,observer
local suspended=false
local elapsed,cooldownElapsed=0,0

local function locked()
    return InCombatLockdown and InCombatLockdown()
end
local function readable(v,t)
    return (not issecretvalue or not issecretvalue(v)) and type(v)==t
end
local function finite(v)
    return readable(v,"number") and v==v and math.abs(v)<math.huge
end
local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b,c,d,e=pcall(fn,...)
    if ok then return a,b,c,d,e end
end
local function rect(frame)
    if not frame or not frame.IsVisible or not frame:IsVisible() then return end
    local l,b,w,h=call(frame.GetRect,frame)
    local scale=call(frame.GetEffectiveScale,frame)
    local rootScale=UIParent and call(UIParent.GetEffectiveScale,UIParent)
    if not (finite(l) and finite(b) and finite(w) and finite(h) and w>0 and h>0
        and finite(scale) and scale>0 and finite(rootScale) and rootScale>0) then return end
    local ratio=scale/rootScale
    return l*ratio,b*ratio,w*ratio,h*ratio
end
local function itemToken(link)
    if not readable(link,"string") then return end
    local number=link:match("|Hitem:(%d+)[:|]") or link:match("^item:(%d+)$")
    if number and #number<12 and tonumber(number)>0 then return "item:"..number end
end
AT.GetRankQuestItemToken=itemToken

local function clear(button)
    button.bound=nil
    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(button) then GameTooltip:Hide() end
    button:Hide()
    button:SetAttribute("type1",nil)
    button:SetAttribute("item1",nil)
    button:SetAttribute("macrotext1",nil)
end
local function tooltip(button)
    local binding=button.bound
    if not binding or not GameTooltip then return end
    GameTooltip:SetOwner(button,"ANCHOR_LEFT")
    if binding.kind=="macro" then
        GameTooltip:SetText(binding.name)
        GameTooltip:AddLine(binding.vendorItem and "Vendor (NPC) · Click to target, mark, and ping" or "Click to target, mark with a diamond, and ping",.54,.95,.73)
        GameTooltip:Show()
        return
    end
    if GameTooltip.SetHyperlink then pcall(GameTooltip.SetHyperlink,GameTooltip,binding.link) end
    GameTooltip:AddLine("Click to use",.54,.95,.73)
    GameTooltip:Show()
end
local function matchingRect(b)
    local l,y,w,h=rect(b.tile)
    local vl,vy,vw,vh=rect(viewport)
    if not (l and vl) then return end
    if b.kind=="macro" then
        local left,bottom=math.max(l,vl),math.max(y,vy)
        local right,top=math.min(l+w,vl+vw),math.min(y+h,vy+vh)
        if right>left and top>bottom then return left,bottom,right-left,top-bottom end
        return
    end
    if l>=vl-.01 and l+w<=vl+vw+.01 and y>=vy-.01 and y+h<=vy+vh+.01 then return l,y,w,h end
end
local function paintCooldown(tile,label)
    if not tile.cooldownText or tile.cooldownLabel==label then return end
    tile.cooldownLabel=label
    tile.cooldownText:SetText(label or "")
    tile.cooldownText:SetShown(label~=nil)
    tile.cooldownShade:SetShown(label~=nil)
end
local function remainingCooldown(now,start,duration,enabled)
    if not finite(start) or not finite(duration) or start<=0 or duration<=0
        or not readable(enabled,"number") and not readable(enabled,"boolean")
        or enabled==0 or enabled==false then return end
    local left=start+duration-now
    if finite(left) and left>0 then return math.ceil(left) end
end
local function cooldownFor(b,now)
    if b.row.qid~=b.qid or b.row.partyOnly or b.tile.link~=b.link then return end
    local q=C_QuestLog
    local index=q and call(q.GetLogIndexForQuestID,b.qid)
    if finite(index) and index>0 then
        local info=call(q.GetInfo,index)
        local id=readable(info,"table") and info.questID
        if finite(id) and id==b.qid and itemToken(call(GetQuestLogSpecialItemInfo,index))==b.token then
            local left=remainingCooldown(now,call(GetQuestLogSpecialItemCooldown,index))
            if left then return left end
        end
    end
    local item=tonumber(b.token:match("^item:(%d+)$"))
    local fn=C_Item and C_Item.GetItemCooldown or GetItemCooldown
    return remainingCooldown(now,call(fn,item))
end
function AT.RefreshRankQuestItemCooldowns()
    local now=call(GetTime)
    for _,b in ipairs(targets) do
        if b.kind~="macro" and b.tile.cooldownText then
            local left
            if not suspended and finite(now) and matchingRect(b) then left=cooldownFor(b,now) end
            local label
            if left then
                if left>=3600 then label=math.ceil(left/3600).."h"
                elseif left>=60 then label=("%d:%02d"):format(math.floor(left/60),left%60)
                else label=tostring(left) end
            end
            paintCooldown(b.tile,label)
        end
    end
end
local function npcMacro(name,vendor)
    if not readable(name,"string") or #name==0 or #name>80 or name:match("^%s") or name:match("%s$")
        or name:find("[%c%[%];/|]") then return end
    -- Clear first so an unsuccessful lookup cannot mark the previous target.
    -- Let WoW enforce its own targeting, distance, and marker permissions.
    if vendor then
        -- Neutral NPCs may be neither assistable nor attackable. Test
        -- that the new target exists, is alive, and is not hostile.
        local condition="[@target,exists,noharm,nodead]"
        return "/cleartarget\n/targetexact "..name.."\n/tm "..condition.." !3\n/ping "..condition.." Assist\n/targetlasttarget [noexists][harm]"
    end
    return "/cleartarget".."\n/targetexact "..name.."\n/tm [@target,exists,nodead] !3\n/ping [@target,exists,nodead] 4\n/targetlasttarget [noexists]"
end
AT.GetRankQuestNPCMacro=npcMacro

local function validate(b)
    if not b or not b.row or b.row.partyOnly or b.row.qid~=b.qid then return false end
    if b.kind=="macro" then
        if b.vendorItem then
            if not C_QuestLog or call(C_QuestLog.IsOnQuest,b.qid)~=true
                or call(C_QuestLog.ReadyForTurnIn,b.qid)==true or b.tile.questId~=b.qid
                or b.tile.vendorItem~=b.vendorItem or b.tile.npcID~=b.npcID or b.tile.mobName~=b.name then return false end
            local name,npc=call(AT.GetQuestObjectiveVendor,b.qid,b.vendorItem)
            return npc==b.npcID and npcMacro(name,true)==b.token
        end
        if b.npcObjective then
            if not C_QuestLog or call(C_QuestLog.IsOnQuest,b.qid)~=true
                or call(C_QuestLog.ReadyForTurnIn,b.qid)==true or b.tile.questId~=b.qid
                or b.tile.npcObjective~=b.npcObjective or b.tile.npcID~=b.npcID or b.tile.mobName~=b.name then return false end
            local objectives=call(C_QuestLog.GetQuestObjectives,b.qid)
            local o=readable(objectives,"table") and objectives[b.npcObjective]
            if not readable(o,"table") or not readable(o.finished,"boolean") or o.finished then return false end
            local name,npc=call(AT.GetQuestObjectiveNPC,b.qid,o,o.text)
            return npc==b.npcID and npcMacro(name,true)==b.token
        end
        if b.row.turnInLabel~=b.tile or b.row.turnInName~=b.name
            or not C_QuestLog or call(C_QuestLog.IsOnQuest,b.qid)~=true then return false end
        local _,_,_,name,npcOnly=call(AT.GetReadyQuestTurnInPoint,b.qid)
        return npcOnly==true and npcMacro(name)==b.token
    end
    return b.tile.link==b.link and itemToken(call(verify,b.qid,b.index,b.token))==b.token
end
local function newButton()
    if locked() or not UIParent or type(RegisterStateDriver)~="function" then return end
    local btn=call(CreateFrame,"Button",nil,UIParent,"SecureActionButtonTemplate,SecureHandlerStateTemplate")
    if not btn then return end
    btn:Hide()
    btn:SetFrameStrata("MEDIUM")
    if btn.EnableMouse then btn:EnableMouse(true) end
    btn:RegisterForClicks("LeftButtonUp")
    btn:SetAttribute("useOnKeyDown",false)
    btn:SetAttribute("_onstate-rankquestcombat",[[
        if newstate == "locked" then
            self:SetAttribute("type1", nil)
            self:SetAttribute("item1", nil)
            self:SetAttribute("macrotext1", nil)
            self:Hide()
        end
    ]])
    local ok=pcall(RegisterStateDriver,btn,"rankquestcombat","[combat] locked; free")
    if not ok then return end
    btn:SetScript("PreClick",function(self)
        if locked() then return end
        local b=self.bound
        local l,y,w,h
        if b and not suspended then l,y,w,h=matchingRect(b) end
        if not (l and b.l==l and b.y==y and b.w==w and b.h==h and call(validate,b)==true) then clear(self) end
    end)
    btn:SetScript("OnEnter",tooltip)
    btn:SetScript("OnLeave",function(self)
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    return btn
end
function AT.InvalidateRankQuestItems()
    if locked() then return end
    for _,btn in ipairs(pool) do if btn.bound then clear(btn) end end
end
function AT.SuspendRankQuestItems(state)
    suspended=state and true or false
    if suspended then AT.InvalidateRankQuestItems() end
    AT.RefreshRankQuestItemCooldowns()
end
function AT.SyncRankQuestItemButtons()
    if locked() then return end
    if suspended or not viewport then AT.InvalidateRankQuestItems();return end
    local used=0
    for _,b in ipairs(targets) do
        local l,y,w,h=matchingRect(b)
        if l then
            used=used+1
            local btn=pool[used]
            if not btn then btn=newButton();pool[used]=btn end
            if btn then
                local active=btn.bound
                local attr=b.kind=="macro" and "macrotext1" or "item1"
                if active~=b or b.l~=l or b.y~=y or b.w~=w or b.h~=h
                    or not btn:IsShown() or btn:GetAttribute(attr)~=b.token then
                    clear(btn)
                    if call(validate,b)==true then
                        b.l,b.y,b.w,b.h=l,y,w,h
                        btn:ClearAllPoints()
                        btn:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",l,y)
                        btn:SetSize(w,h)
                        local level=call(b.tile.GetFrameLevel,b.tile) or call(b.row.GetFrameLevel,b.row)
                        if finite(level) then btn:SetFrameLevel(level+2) end
                        btn:SetAttribute("type1",b.kind or "item")
                        btn:SetAttribute(attr,b.token)
                        btn.bound=b
                        btn:Show()
                    end
                end
            end
        end
    end
    for i=used+1,#pool do if pool[i].bound then clear(pool[i]) end end
end
function AT.SetRankQuestItemTargets(rows,scroll,callback)
    AT.InvalidateRankQuestItems()
    for _,b in ipairs(targets) do if not b.kind then paintCooldown(b.tile,nil) end end
    targets={}
    viewport,verify=scroll,callback
    for _,row in ipairs(rows or {}) do
        if not row.partyOnly and row.qid then
            for _,tile in ipairs(row.itemTiles or {row.item}) do
                if tile.link then
                    local token=itemToken(tile.link)
                    if token then targets[#targets+1]={row=row,tile=tile,token=token,link=tile.link,qid=row.qid,index=tile.rankQuestIndex} end
                end
            end
        end
        if not row.partyOnly and row.qid then
            local function npcTargets(buttons)
                for _,tile in ipairs(buttons or {}) do
                    if tile.questId==row.qid and (tile.vendorItem or tile.npcObjective) then
                        local token=npcMacro(tile.mobName,true)
                        if token then
                            targets[#targets+1]={row=row,tile=tile,token=token,kind="macro",
                                name=tile.mobName,qid=row.qid,vendorItem=tile.vendorItem,npcObjective=tile.npcObjective,npcID=tile.npcID}
                        end
                    end
                end
            end
            npcTargets(row.objectiveMobHits)
        end
        if not row.partyOnly and row.qid and row.turnInLabel then
            local token=npcMacro(row.turnInName)
            if token then targets[#targets+1]={row=row,tile=row.turnInLabel,token=token,kind="macro",name=row.turnInName,qid=row.qid} end
        end
    end
    AT.SyncRankQuestItemButtons()
    AT.RefreshRankQuestItemCooldowns()
end

-- Stock merchant UI only. These are passive art regions, never click targets.
local merchantArt={}
local merchantHook,merchantBuybackHook,merchantFrameHook
local function clearMerchantArt()
    for _,regions in pairs(merchantArt) do
        for _,r in ipairs(regions) do r:Hide() end
    end
end
local function drawMerchantBox(button)
    local art=merchantArt[button]
    if not art then
        art={}
        local function edge(a,b,dimension)
            local t=button:CreateTexture(nil,"OVERLAY",nil,6)
            t:SetColorTexture(1,.75,.21,1)
            t:SetPoint(a,button,a)
            t:SetPoint(b,button,b)
            if dimension=="height" then t:SetHeight(2) else t:SetWidth(2) end
            art[#art+1]=t
        end
        edge("TOPLEFT","TOPRIGHT","height")
        edge("BOTTOMLEFT","BOTTOMRIGHT","height")
        edge("TOPLEFT","BOTTOMLEFT","width")
        edge("TOPRIGHT","BOTTOMRIGHT","width")
        local bg=button:CreateTexture(nil,"OVERLAY",nil,6)
        bg:SetColorTexture(.17,.11,.035,1)
        bg:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-1,1)
        bg:SetSize(12,15);art[#art+1]=bg
        local bang=button:CreateFontString(nil,"OVERLAY","GameFontNormal")
        bang:SetDrawLayer("OVERLAY",7)
        bang:SetPoint("CENTER",bg,"CENTER",0,0)
        bang:SetTextColor(1,.83,.27)
        bang:SetText("!");art[#art+1]=bang
        merchantArt[button]=art
    end
    for _,r in ipairs(art) do r:Show() end
end
local function refreshMerchantArt()
    clearMerchantArt()
    local frame=_G.MerchantFrame
    if not frame or not call(frame.IsShown,frame) or frame.selectedTab~=1
        or not AT.db or AT.db.enabled==false then return end
    local guid=call(UnitGUID,"npc")
    local npc=readable(guid,"string") and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    if not npc then return end
    local needed=call(AT.GetNeededQuestVendorItems,npc)
    if not needed or not next(needed) then return end
    local count=call(GetMerchantNumItems)
    if not finite(count) or count<1 then return end
    local perPage=MERCHANT_ITEMS_PER_PAGE
    if not finite(perPage) or perPage<1 or perPage>50 then return end
    for slot=1,perPage do
        local button=_G["MerchantItem"..slot.."ItemButton"]
        local index=button and call(button.GetID,button)
        if finite(index) and index>=1 and index<=count and call(button.IsShown,button) then
            local item=call(GetMerchantItemID,index)
            if not finite(item) or item<=0 then
                local token=itemToken(call(GetMerchantItemLink,index))
                item=token and tonumber(token:match("%d+"))
            end
            if item and needed[item] then drawMerchantBox(button) end
        end
    end
end
local function bindMerchantArt()
    if not merchantHook and type(_G.MerchantFrame_UpdateMerchantInfo)=="function" then
        hooksecurefunc("MerchantFrame_UpdateMerchantInfo",refreshMerchantArt)
        merchantHook=true
    end
    if not merchantBuybackHook and type(_G.MerchantFrame_UpdateBuybackInfo)=="function" then
        hooksecurefunc("MerchantFrame_UpdateBuybackInfo",clearMerchantArt)
        merchantBuybackHook=true
    end
    if not merchantFrameHook and _G.MerchantFrame then
        _G.MerchantFrame:HookScript("OnHide",clearMerchantArt)
        merchantFrameHook=true
    end
end
function AT.InitRankQuestMerchantHighlights()
    if type(CreateFrame)~="function" or type(hooksecurefunc)~="function" then return end
    local events=CreateFrame("Frame")
    for _,event in ipairs({"MERCHANT_SHOW","MERCHANT_CLOSED","MERCHANT_UPDATE",
        "QUEST_LOG_UPDATE","BAG_UPDATE_DELAYED","GET_ITEM_INFO_RECEIVED"}) do events:RegisterEvent(event) end
    local pending
    events:SetScript("OnEvent",function(_,event)
        if event=="MERCHANT_CLOSED" then clearMerchantArt();return end
        if event=="MERCHANT_SHOW" then bindMerchantArt() end
        if not _G.MerchantFrame or not call(_G.MerchantFrame.IsShown,_G.MerchantFrame) or pending then return end
        if C_Timer and C_Timer.After then
            pending=true
            C_Timer.After(0,function() pending=false;refreshMerchantArt() end)
        else refreshMerchantArt() end
    end)
end

function AT.InitRankQuestItems()
    if observer or not CreateFrame then return end
    observer=CreateFrame("Frame")
    AT.InitRankQuestMerchantHighlights()
    observer:SetScript("OnUpdate",function(_,dt)
        if #targets==0 then return end
        cooldownElapsed=cooldownElapsed+dt
        if cooldownElapsed>=.20 then
            cooldownElapsed=0
            AT.RefreshRankQuestItemCooldowns()
        end
        elapsed=elapsed+dt
        if elapsed<.075 then return end
        elapsed=0
        AT.SyncRankQuestItemButtons()
    end)
end
