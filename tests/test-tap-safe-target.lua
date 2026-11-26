local buttons, action, body, units={},nil,nil,{}
local AT={db={enabled=true,pressSkull=true,pingWithMarker=true},char={targetName="Raptor"}}
UIParent={}
SlashCmdList={}
local secret={}
function issecretvalue(v) return v==secret end
local combat=false
function InCombatLockdown() return combat end
function CreateFrame(_,name)
    local f={script={},attr={}}
    function f:SetScript(k,v) self.script[k]=v end
    function f:SetAttribute(k,v) self.attr[k]=v end
    function f:Hide() end
    function f:RegisterEvent() end
    function f:UnregisterEvent() end
    function f:RegisterForClicks() end
    if name then buttons[name]=f end
    return f
end
local create=CreateFrame
local last
function CreateFrame(...) last=create(...); return last end
function UnitExists(u) return units[u]~=nil end
function UnitCanAttack(_,u) return not units[u].friendly end
function UnitReaction() return 2 end
function UnitIsPlayer(u) return units[u].player==true end
function UnitIsDeadOrGhost(u) return units[u].dead==true end
function UnitName(u) return units[u].name end
function UnitIsTapDenied(u) return units[u].tap end
function UnitDistanceSquared(u) return units[u].distance, units[u].distance~=nil end
function GetMacroInfo(i)
    if i==121 then return "Auto Track",134400,body end
end
function EditMacro(id,_,_,value) body=value;return id end
function GetNumMacros() return 0,1 end
function CreateMacro() error("must reuse the existing macro") end
MAX_ACCOUNT_MACROS=120
MAX_CHARACTER_MACROS=18
body="#AT4\n/atmob [btn:2]e;c\n/tm !8\n/ping [@target] Attack"
assert(loadfile("NQT/Target.lua"))("NQT",AT)
AT.InitTarget()
assert(not body:find("/tm",1,true) and not body:find("/ping",1,true),"existing owned action-slot macro must be rewritten")
assert(body:find("/targetexact",1,true) and body:find("/atmob m",1,true),"slot keeps native recall without blind marking/pinging")
assert(loadfile("NQT/SmartTarget.lua"))("NQT",AT)
last.script.OnEvent(last,"PLAYER_LOGIN")
local btn=assert(buttons.AutoTrackSmartTargetButton)
local function press()
    btn.script.PreClick(btn,"LeftButton",false)
    action=btn.attr.macrotext
    btn.script.PostClick(btn)
    assert(btn.attr.macrotext=="/stopmacro")
    return action
end
local function pick(token)
    local line=press()
    assert(line:find("/target [@"..token..",harm,nodead] "..token,1,true),line)
    assert(line:find("/tm [@"..token..",harm,nodead] !8",1,true),line)
    assert(line:find("/ping [@"..token..",harm,nodead] Attack",1,true),line)
    assert(not line:find("/cleartarget",1,true) and not line:find("/targetexact",1,true))
end
local denied={name="Raptor",tap=true,distance=4}
local allowed={name="Raptor",tap=false,distance=50}
units={target=denied,nameplate1=denied,nameplate2=allowed,nameplate3={name="Raptor",tap=false,distance=90}}
pick("nameplate2")
units.target=allowed
units.nameplate3.distance=40
pick("nameplate3")
units.nameplate2=nil;units.nameplate3=nil
assert(press():find("/tm [@target,harm,nodead]",1,true))
units.target=denied
for _,tap in ipairs({true,secret,"false",0}) do
    units.nameplate2={name="Raptor",tap=tap}
    assert(press()=="/stopmacro","no action for unknown or denied taps")
end
units.nameplate2={name="Raptor"}
assert(press()=="/stopmacro","nil is not permission")
local readableTap=UnitIsTapDenied
function UnitIsTapDenied() error("restricted") end
assert(press()=="/stopmacro")
UnitIsTapDenied=readableTap
units.target={name="Panther",tap=true}
units.nameplate2={name="Panther",tap=false}
pick("nameplate2")
assert(AT.char.targetName=="Panther","normal press learns a new name before seeking an eligible match")
units.target={name="Troll",tap=false,dead=true}
assert(press()=="/stopmacro" and AT.char.targetName=="Troll","corpse can teach name but cannot act")
AT.char.targetName="Rap"; AT.char.targetPartial=true
units={mouseover={name="Jungle Raptor",tap=false}}
pick("mouseover")
AT.db.pressSkull=false
local plain=press()
assert(plain:find("/target",1,true) and not plain:find("/tm",1,true) and not plain:find("/ping",1,true))
combat=true
assert(press()=="/stopmacro")
print("PASS hardware Smart Target rejects denied/unknown, uses eligible units only, and owned normal macro cannot send blind marks/pings")
