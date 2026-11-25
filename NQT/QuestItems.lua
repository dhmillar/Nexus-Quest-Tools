local _,AT=...
local pool,targets={},{}
local viewport,verify,observer
local suspended=false
local elapsed=0

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
        GameTooltip:AddLine("Click to target, mark with a diamond, and ping",.54,.95,.73)
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
local function npcMacro(name)
    if not readable(name,"string") or #name==0 or #name>80 or name:match("^%s") or name:match("%s$")
        or name:find("[%c%[%];/|]") then return end
    -- Clear first so an unsuccessful lookup cannot mark the previous target.
    -- Let WoW enforce its own targeting, distance, and marker permissions.
    return "/cleartarget".."\n/targetexact "..name.."\n/tm [@target,exists,nodead] !3\n/ping [@target,exists,nodead] 4\n/targetlasttarget [noexists]"
end
AT.GetRankQuestNPCMacro=npcMacro

local function validate(b)
    if not b or not b.row or b.row.partyOnly or b.row.qid~=b.qid then return false end
    if b.kind=="macro" then
        if b.row.turnInLabel~=b.tile or b.row.turnInName~=b.name
            or not C_QuestLog or call(C_QuestLog.IsOnQuest,b.qid)~=true then return false end
        local _,_,_,name,npcOnly=call(AT.GetReadyQuestTurnInPoint,b.qid)
        return npcOnly==true and npcMacro(name)==b.token
    end
    return b.tile.link==b.link and itemToken(call(verify,b.qid,b.index))==b.token
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
    targets={}
    viewport,verify=scroll,callback
    for _,row in ipairs(rows or {}) do
        local tile=row.item
        if not row.partyOnly and row.qid and tile and tile.link then
            local token=itemToken(tile.link)
            if token then targets[#targets+1]={row=row,tile=tile,token=token,link=tile.link,qid=row.qid,index=tile.rankQuestIndex} end
        end
        if not row.partyOnly and row.qid and row.turnInLabel then
            local token=npcMacro(row.turnInName)
            if token then targets[#targets+1]={row=row,tile=row.turnInLabel,token=token,kind="macro",name=row.turnInName,qid=row.qid} end
        end
    end
    AT.SyncRankQuestItemButtons()
end
function AT.InitRankQuestItems()
    if observer or not CreateFrame then return end
    observer=CreateFrame("Frame")
    observer:SetScript("OnUpdate",function(_,dt)
        if #targets==0 then return end
        elapsed=elapsed+dt
        if elapsed<.075 then return end
        elapsed=0
        AT.SyncRankQuestItemButtons()
    end)
end
