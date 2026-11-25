local _, AT = ...
local NAME = "AutoTrackSmartTargetButton"
local BINDING = "CLICK " .. NAME .. ":LeftButton"
BINDING_HEADER_AUTOTRACK = "Nexus Quest Tools"
_G["BINDING_NAME_" .. BINDING] = "Smart Target (out of combat)"

local INERT = "/stopmacro"
local OOC = "/stopmacro [combat]"
local MISSCHECK = "/stopmacro [exists]"
local LIVING = "/stopmacro [noharm][dead]"
local function readable(value)
    return not (issecretvalue and issecretvalue(value))
end

local function markerTail()
    if not AT.db.pressSkull then return "" end
    return "\n"..LIVING.."\n/tm !"..AT.GetPrimaryMarker()
        .. (AT.db.pingWithMarker and "\n/ping [@target] Attack" or "")
end
local function recall(name, clear)
    if not name then return end
    local parts = {OOC}
    if clear then
        parts[#parts+1] = "/cleartarget"
        parts[#parts+1] = MISSCHECK
    end
    parts[#parts+1] = (AT.IsPartialTarget() and "/target " or "/targetexact ") .. name
    parts[#parts+1] = "/cleartarget [dead]"
    local core=table.concat(parts,"\n")
    local marked=core..markerTail()
    return #marked<=255 and marked or #core<=255 and core or nil
end

-- Read the target on this physical press, not an earlier target-change event.
-- Unknown identity/marker state never arms a destructive clear.
local function prepare()
    if not AT.db or AT.db.enabled==false then return end
    local exists=UnitExists("target")
    if not readable(exists) then return end
    if not exists then return recall(AT.GetTargetName(),false) end
    local name, corpse=AT.GetSelectedMobForSmartTarget()
    if not name then return end
    if not AT.MatchesSavedTarget(name) then
        if AT.SaveSelectedTarget() and not corpse then return OOC..markerTail() end
        return
    end
    if corpse then return end
    if not AT.db.pressSkull then
        -- With no marker, the saved name is the explicit repeat signal.
        return recall(AT.GetTargetName(),true)
    end
    if not GetRaidTargetIndex then return end
    local mark=GetRaidTargetIndex("target")
    if not readable(mark) or (mark~=nil and type(mark)~="number") then return end
    if mark==AT.GetPrimaryMarker() then return recall(AT.GetTargetName(),true) end
    return OOC..markerTail()
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
