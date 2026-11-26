local _, AT = ...
local NAME = "AutoTrackSmartTargetButton"
local BINDING = "CLICK " .. NAME .. ":LeftButton"
BINDING_HEADER_AUTOTRACK = "Nexus Quest Tools"
_G["BINDING_NAME_" .. BINDING] = "Smart Target (out of combat)"

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
        or read(UnitIsTapDenied, unit) ~= false then return end
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
    local function check(unit)
        local item = candidate(unit)
        if item and AT.MatchesSavedTarget(item.name) then candidates[#candidates+1] = item end
    end
    check("target")
    check("mouseover")
    for i = 1, 40 do check("nameplate"..i) end
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
    return best
end

local function action(item)
    if not item then return end
    local unit = item.unit
    local conditions = "[@"..unit..",harm,nodead]"
    local body = OOC
    if unit ~= "target" then
        body = body .. "\n/target "..conditions.." "..unit
    end
    if AT.db.pressSkull then
        body = body .. "\n/tm "..conditions.." !"..AT.GetPrimaryMarker()
        if AT.db.pingWithMarker then body = body .. "\n/ping "..conditions.." Attack" end
    end
    return body
end

local function prepare()
    if not AT.db or AT.db.enabled==false then return end
    if AT.GetBossTargetMacro then
        local active,body,note=AT.GetBossTargetMacro(nil,true)
        if active then
            if note and AT.Say then AT.Say(note) end
            return body
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
    return action(closest())
end

local function initialize()
    if InCombatLockdown() then return false end
    local button=CreateFrame("Button",NAME,UIParent,"SecureActionButtonTemplate")
    button:Hide()
    button:RegisterForClicks("AnyUp")
    button:SetAttribute("useOnKeyDown",false)
    button:SetAttribute("type","macro")
    button:SetAttribute("macrotext",INERT)
    button:SetScript("PreClick",function(self,physicalButton,down)
        if InCombatLockdown() then return end
        self:SetAttribute("macrotext",INERT)
        if down or physicalButton~="LeftButton" then return end
        local ok,body=pcall(prepare)
        if ok and body then self:SetAttribute("macrotext",body) end
    end)
    button:SetScript("PostClick",function(self)
        if not InCombatLockdown() then self:SetAttribute("macrotext",INERT) end
    end)
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
