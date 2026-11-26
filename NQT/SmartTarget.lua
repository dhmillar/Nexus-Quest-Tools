local _, AT = ...
local NAME = "AutoTrackSmartTargetButton"
local BINDING = "CLICK " .. NAME .. ":LeftButton"
BINDING_HEADER_AUTOTRACK = "Nexus Quest Tools"
_G["BINDING_NAME_" .. BINDING] = "Smart Target (out of combat)"

local smartButton
local lastPress="No Smart Target press since reload."
local pending
function AT.GetSmartTargetDiagnostic()
    return (smartButton and "Smart Target loaded. " or "Smart Target did not load. ")..lastPress
end
function AT.NoteRecallMacroPress()
    lastPress="The action-bar recall macro ran. It does not mark or ping regular mobs."
end
function AT.NoteSmartMacroExecuted()
    if pending then pending.ran=true end
end
function AT.RefreshSmartTargetButton()
    if not smartButton or InCombatLockdown() then return end
    if AT.db and AT.db.enabled~=false and AT.db.showSmartTargetButton~=false then
        smartButton:Show()
    else
        smartButton:Hide()
    end
end

-- Session-only redirect of stock bar keys whose current slot
-- contains the owned macro. It never changes saved game keybindings.
local routing
local stockBars={
    {"ActionButton","ACTIONBUTTON"}, {"MultiBarBottomLeftButton","MULTIACTIONBAR1BUTTON"},
    {"MultiBarBottomRightButton","MULTIACTIONBAR2BUTTON"}, {"MultiBarRightButton","MULTIACTIONBAR3BUTTON"},
    {"MultiBarLeftButton","MULTIACTIONBAR4BUTTON"}, {"MultiBar5Button","MULTIACTIONBAR5BUTTON"},
    {"MultiBar6Button","MULTIACTIONBAR6BUTTON"}, {"MultiBar7Button","MULTIACTIONBAR7BUTTON"},
}
local function refreshBarKeys()
    if not routing or InCombatLockdown() then return 0 end
    ClearOverrideBindings(routing)
    if not (AT.db and AT.db.enabled~=false and AT.char) then return 0 end
    local applied={}
    for _,bar in ipairs(stockBars) do
        for i=1,12 do
            local btn=_G[bar[1]..i]
            local action=btn and btn.action
            if type(action)=="number" and not (issecretvalue and issecretvalue(action)) then
                local kind,id=GetActionInfo(action)
                if kind=="macro" and AT.IsOwnTargetMacro(id) then
                    local command=bar[2]..i
                    local k1,k2=GetBindingKey(command)
                    for _,key in pairs({k1,k2}) do
                        if key and not applied[key] and GetBindingAction(key,true)==command then
                            SetOverrideBindingClick(routing,false,key,NAME,"LeftButton")
                            applied[key]=true
                        end
                    end
                end
            end
        end
    end
    local count=0
    for _ in pairs(applied) do count=count+1 end
    return count
end
function AT.RefreshSmartTargetBarKeys() return refreshBarKeys() end

local INERT = "/stopmacro"
local OOC = "/stopmacro [combat]"
local function readable(value)
    return not (issecretvalue and issecretvalue(value))
end

-- Only select a unit the client identifies as eligible on this hardware press.
-- A name search can't test tap status before choosing among duplicate names.
local function read(api, ...)
    if type(api) ~= "function" then return end
    local ok, first, second = pcall(api, ...)
    if ok and readable(first) then return first, readable(second) and second or nil end
end

local function candidate(unit)
    if read(UnitExists, unit) ~= true
        or read(UnitCanAttack, "player", unit) ~= true
        or read(UnitIsPlayer, unit) ~= false
        or read(UnitIsDeadOrGhost, unit) ~= false
        then return end
    local tapped=read(UnitIsTapDenied,unit)
    if tapped~=false then return nil, tapped==true and "tagged by another group" or "tap status unavailable" end
    local name = read(UnitName, unit)
    if type(name) ~= "string" then return end
    local range, known = read(UnitDistanceSquared, unit)
    local bucket = read(CheckInteractDistance, unit, 3) == true and 1
        or read(CheckInteractDistance, unit, 2) == true and 2
        or read(CheckInteractDistance, unit, 1) == true and 3 or 4
    return { unit=unit, name=name, range=known == true and type(range) == "number"
        and range >= 0 and range < math.huge and range or nil, bucket=bucket }
end

local function closest()
    local candidates = {}
    local blockedMatch=false
    local function check(unit)
        local item, reason = candidate(unit)
        if item and AT.MatchesSavedTarget(item.name) then candidates[#candidates+1] = item
        elseif reason=="tagged by another group" and AT.MatchesSavedTarget(read(UnitName,unit)) then blockedMatch=true end
    end
    local seen={}
    local function scan(unit)
        if not readable(unit) or type(unit)~="string" or seen[unit] then return end
        seen[unit]=true
        check(unit)
    end
    scan("target")
    scan("mouseover")
    scan("focus")
    local plates=read(C_NamePlate and C_NamePlate.GetNamePlates)
    if type(plates)=="table" then
        for _,plate in ipairs(plates) do
            local ok,token=pcall(function() return plate.namePlateUnitToken end)
            if not ok then token=nil end
            if readable(token) and type(token)=="string" and token:match("^nameplate%d+$") then scan(token) end
        end
    end
    for i = 1, 40 do scan("nameplate"..i) end
    local exact = #candidates > 0
    for _, item in ipairs(candidates) do
        if not item.range then exact = false; break end
    end
    local best
    for _, item in ipairs(candidates) do
        if not best or (exact and item.range < best.range) or (not exact and item.bucket < best.bucket) then
            best = item
        end
    end
    return best, blockedMatch
end

local function action(item)
    if not item then return end
    local unit = item.unit
    local conditions = "[@"..unit..",exists,harm,nodead]"
    local body = OOC
    if unit ~= "target" then
        body = body .. "\n/target "..conditions.." "..unit
    end
    if AT.db.pressSkull then
        body = body .. "\n/tm "..conditions.." !"..AT.GetPrimaryMarker()
        if AT.db.pingWithMarker then body = body .. "\n/ping "..conditions.." Attack" end
    end
    if unit~="target" and read(UnitExists,"target")~=true then
        -- If the client can't select this readable token directly, still
        -- let its native exact-name lookup run. The fallback never marks.
        local search=AT.GetSafeTargetSearchLine and AT.GetSafeTargetSearchLine()
        local tail=search and "\n"..search.."\n/cleartarget [dead]"
        if tail and #body+#tail<=246 then body=body..tail end
    end
    return body, item
end

local function prepare()
    if not AT.db or AT.db.enabled==false then return end
    if AT.GetBossTargetMacro then
        local active,body,note=AT.GetBossTargetMacro(nil,true)
        if active then
            if note and AT.Say then AT.Say(note) end
            if body then return body end
            return nil,nil,note or "no boss found"
        end
    end
    local name, corpse=AT.GetSelectedMobForSmartTarget()
    if name and not AT.MatchesSavedTarget(name) then
        -- Keep the original select-then-press learning, including corpses.
        -- Learning a name doesn't authorize marking the selected mob.
        if AT.SaveSelectedTarget() then
            if corpse then return end
            return action(candidate("target") or closest())
        end
    end
    local found,blockedMatch=closest()
    if found then return action(found) end
    -- Without a readable unit token, native search can find the name, but
    -- its result cannot be tap-checked before native mark/ping in this press.
    -- Do not displace an existing hostile or mark an unchecked search result.
    local search=AT.GetSafeTargetSearchLine and AT.GetSafeTargetSearchLine()
    if search and not blockedMatch and read(UnitExists,"target")~=true then
        local body=OOC.."\n/stopmacro [exists]\n"..search.."\n/cleartarget [dead]"
        if #body<=255 then return body,nil,"search" end
    end
end

local function initialize()
    if InCombatLockdown() then return false end
    local button=CreateFrame("Button",NAME,UIParent,"UIPanelButtonTemplate,SecureActionButtonTemplate")
    button:Hide()
    button:SetSize(104,24)
    button:SetPoint("RIGHT",UIParent,"RIGHT",-14,0)
    button:SetText("Smart Target")
    button:RegisterForClicks("AnyUp")
    button:SetAttribute("useOnKeyDown",false)
    button:SetAttribute("type","macro")
    button:SetAttribute("*type1","macro")
    button:SetAttribute("macrotext",INERT)
    button:SetScript("PreClick",function(self,physicalButton,down)
        pending=nil
        if InCombatLockdown() then lastPress="Press was in combat; no safe target change was attempted."; return end
        self:SetAttribute("macrotext",INERT)
        self:SetAttribute("*macrotext1",INERT)
        if down or physicalButton~="LeftButton" then return end
        local ok,body,item,note=pcall(prepare)
        if not ok then lastPress="Could not prepare a secure action."; return end
        if not body then
            local _,reason=candidate("target")
            lastPress="No eligible action: "..(note or reason or "no matching living enemy was readable").."."
            return
        end
        if (item or note=="search") and AT.MuteTargetMacroSounds then AT.MuteTargetMacroSounds() end
        pending={ran=false, unit=item and item.unit, wantsMark=AT.db.pressSkull==true,
            wantsPing=AT.db.pressSkull==true and AT.db.pingWithMarker==true, search=note=="search"}
        lastPress="Prepared a secure action."
        if (item or pending.search) and #body+9<=255 then
            body=body.."\n/atmob z"
            pending.checkDispatch=true
        end
        self:SetAttribute("macrotext",body)
        self:SetAttribute("*macrotext1",body)
    end)
    button:SetScript("PostClick",function(self)
        if not InCombatLockdown() then
            self:SetAttribute("macrotext",INERT)
            self:SetAttribute("*macrotext1",INERT)
        end
        local press=pending
        if not press then return end
        local function report()
            if pending~=press then return end
            pending=nil
            if press.checkDispatch and not press.ran then
                lastPress="WoW did not reach the end of the secure macro."
            elseif press.search then
                local current=read(UnitName,"target")
                lastPress=current and AT.MatchesSavedTarget(current)
                    and "Saved mob found. Press again to check its tag and mark/ping."
                    or "Native name search did not find the saved mob."
            elseif not press.unit then
                lastPress="Boss macro dispatched."
            else
                local mark=read(GetRaidTargetIndex,press.unit)
                lastPress=(press.ran and "Secure macro ran. " or "Secure action dispatched. ")
                    ..(press.wantsMark and (mark==AT.GetPrimaryMarker() and "Marker confirmed. " or "Marker not confirmed. ") or "Marker disabled. ")
                    ..(press.wantsPing and "Attack ping requested." or "Ping disabled.")
            end
        end
        if C_Timer and C_Timer.After then C_Timer.After(.25,report) else report() end
    end)
    smartButton=button
    if RegisterStateDriver and SetOverrideBindingClick and ClearOverrideBindings
        and GetActionInfo and GetBindingKey and GetBindingAction then
        local owner=CreateFrame("Frame",nil,UIParent,"SecureHandlerStateTemplate")
        owner:SetAttribute("_onstate-nqtcombat", 'if newstate == "combat" then self:ClearBindings() end')
        local ok=pcall(RegisterStateDriver,owner,"nqtcombat","[combat] combat; peace")
        if ok then
            routing=owner
            for _,event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","ACTIONBAR_SLOT_CHANGED",
                "ACTIONBAR_PAGE_CHANGED","UPDATE_BINDINGS","UPDATE_MACROS","UPDATE_BONUS_ACTIONBAR",
                "UPDATE_OVERRIDE_ACTIONBAR","UPDATE_VEHICLE_ACTIONBAR"}) do
                pcall(owner.RegisterEvent,owner,event)
            end
            owner:SetScript("OnEvent",function()
                if C_Timer and C_Timer.After then C_Timer.After(0,refreshBarKeys) else refreshBarKeys() end
            end)
            refreshBarKeys()
        end
    end
    AT.RefreshSmartTargetButton()
    local visibility=CreateFrame("Frame")
    visibility:RegisterEvent("PLAYER_REGEN_ENABLED")
    visibility:SetScript("OnEvent", AT.RefreshSmartTargetButton)
    return true
end

local init=CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent",function(self,event)
    if initialize() then
        self:UnregisterEvent(event)
    elseif event=="PLAYER_LOGIN" then
        self:UnregisterEvent(event)
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
end)
