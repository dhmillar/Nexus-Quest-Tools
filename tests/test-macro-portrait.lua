local AT={db={enabled=true},char={}}
local saved,partial,live,combat,fail="Saltseer Manhunter",false,nil,false,false
GetLocale=function() return "enUS" end
function AT.GetTargetName() return saved end
function AT.IsPartialTarget() return partial end
function InCombatLockdown() return combat end
function UnitName() return live end
function UnitCanAttack() return live~=nil end
function UnitIsPlayer() return false end
function AT.IsOwnTargetMacro(id) return id==41 end
local owns=true
function GetActionInfo(slot) return "macro",slot==1 and owns and 41 or 72 end
local applications,liveCount=0,0
function SetPortraitTextureFromCreatureDisplayID(tex,id)
    applications=applications+1
    if fail then error("client could not render this display") end
    tex.value="display:"..id
end
function SetPortraitTexture(tex,unit)
    assert(unit=="target")
    liveCount=liveCount+1;tex.value="live:"..live
end
local function button(slot)
    local b={action=slot,icon={GetTexture=function() return 134400 end}}
    function b:CreateTexture()
        assert(not self.overlay)
        local t={}
        self.overlay=t
        function t:SetAllPoints() end
        function t:SetAlpha(a) self.alpha=a end
        function t:SetTexture(v) self.value=v end
        return t
    end
    return b
end
ActionButton1,ActionButton2=button(1),button(2)
assert(loadfile("NQT/QuestMobData.lua"))("NQT",AT)
assert(loadfile("NQT/QuestMobs.lua"))("NQT",AT)
assert(loadfile("NQT/Portrait.lua"))("NQT",AT)
AT.RefreshPortrait()
local tex=assert(ActionButton1.overlay)
assert(tex.value=="display:142131" and tex.alpha==1 and applications==1 and liveCount==0 and not ActionButton2.overlay)
AT.RefreshPortrait();assert(applications==1,"do not retry an applied portrait on each update")
live=saved;AT.RefreshPortrait();assert(tex.value=="live:Saltseer Manhunter" and liveCount==1)
live=nil;AT.RefreshPortrait();assert(tex.value=="live:Saltseer Manhunter")
saved="Saltseer Murderer";AT.RefreshPortrait();assert(tex.value=="display:142126" and applications==2)
saved="Unknown mob";AT.RefreshPortrait();assert(tex.value:find("MinimapAT",1,true) and tex.alpha==1)
saved="Saltseer Cultist";fail=true;AT.RefreshPortrait();assert(tex.value:find("MinimapAT",1,true))
fail=false;AT.RefreshPortrait();assert(tex.value=="display:142129")
saved="Saltseer Coroner";combat=true;AT.RefreshPortrait();assert(tex.value=="display:142129")
combat=false;partial=true;AT.RefreshPortrait();assert(tex.value:find("MinimapAT",1,true))
partial=false;AT.RefreshPortrait();assert(tex.value=="display:142401")
owns=false;AT.RefreshPortrait();assert(tex.alpha==0 and not ActionButton2.overlay)
print("PASS known quest mob portraits without target, cache, live precedence, fallback, combat and owned slot isolation")