local buttons, action, body, units={},nil,nil,{}
local AT={db={enabled=true,pressSkull=true,pingWithMarker=true},char={targetName="Raptor"}}
UIParent={}
SlashCmdList={}
local secret={}
function issecretvalue(v) return v==secret end
local combat=false
function InCombatLockdown() return combat end
function CreateFrame(_,name,_,template)
    local f={script={},attr={},template=template}
    function f:SetScript(k,v) self.script[k]=v end
    function f:SetAttribute(k,v) self.attr[k]=v end
    function f:Hide() self.shown=false end
    function f:Show() self.shown=true end
    function f:SetSize() end
    function f:SetPoint() self.anchored=true end
    function f:SetAlpha(v) self.alpha=v end
    function f:EnableMouse(v) self.mouse=v end
    function f:SetText(text) self.label=text end
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
do
    local original=body
    assert(AT.SetQuestMobTarget("Raptor"))
    assert(AT.SetQuestMobTarget("Durotar Tiger") and body:find("Durotar Tiger",1,true))
    AT.char.targetNameLocked=true
    assert(not AT.SetQuestMobTarget("Other Boss") and AT.GetTargetName()=="Durotar Tiger")
    AT.char.targetNameLocked=nil
    combat=true
    assert(not AT.SetQuestMobTarget("Other Boss") and AT.GetTargetName()=="Durotar Tiger")
    combat=false
    assert(not AT.SetQuestMobTarget("target") and not AT.SetQuestMobTarget("x;/ping") and not AT.SetQuestMobTarget(""))
    assert(AT.SetQuestMobTarget("Raptor") and body==original)
end
local owner,overrides,actionKind=nil,{},"macro"
ActionButton1={action=1}
ActionButton2={action=2}
function GetActionInfo(slot) if slot==1 then return actionKind,121 else return "macro",123 end end
function GetBindingKey(command) if command=="ACTIONBUTTON1" then return "1","SHIFT-1" else return "2" end end
function GetBindingAction(key) return (key=="1" or key=="SHIFT-1") and "ACTIONBUTTON1" or "ACTIONBUTTON2" end
function RegisterStateDriver(frame,attribute,conditional)
    owner=frame
    assert(attribute=="nqtcombat" and conditional=="[combat] combat; peace")
    assert(frame.attr["_onstate-nqtcombat"]:find("ClearBindings",1,true))
end
function ClearOverrideBindings(frame) assert(frame==owner);overrides={} end
function SetOverrideBindingClick(frame,priority,key,name,button)
    assert(frame==owner and priority==false and name=="AutoTrackSmartTargetButton" and button=="LeftButton")
    overrides[key]=true
end
AT.Say=function() end
assert(loadfile("NQT/SmartTarget.lua"))("NQT",AT)
last.script.OnEvent(last,"PLAYER_LOGIN")
local btn=assert(buttons.AutoTrackSmartTargetButton)
assert(btn.shown and btn.template=="SecureActionButtonTemplate" and btn.alpha==0 and btn.mouse==false and not btn.label and not btn.anchored)
assert(owner and overrides["1"] and overrides["SHIFT-1"] and not overrides["2"],"automatically reuse only the owned slot shortcuts")
actionKind="spell";owner.script.OnEvent();assert(not next(overrides),"page or slot changes restore unmodified bindings")
actionKind="macro";owner.script.OnEvent();assert(overrides["1"])
AT.db.enabled=false;AT.RefreshSmartTargetBarKeys();assert(not next(overrides));AT.db.enabled=true;AT.RefreshSmartTargetBarKeys()
AT.db.showSmartTargetButton=false; AT.RefreshSmartTargetButton(); assert(btn.shown and btn.alpha==0)
AT.db.showSmartTargetButton=true; AT.RefreshSmartTargetButton(); assert(btn.shown and btn.alpha==0 and not btn.anchored)
AT.db.enabled=false; AT.RefreshSmartTargetButton(); assert(not btn.shown)
AT.db.enabled=true; AT.RefreshSmartTargetButton(); assert(btn.shown and btn.mouse==false)
local function press()
    btn.script.PreClick(btn,"LeftButton",false)
    action=btn.attr.macrotext
    if action:find("/atmob z",1,true) then SlashCmdList.AUTOTRACKMOB("z") end
    btn.script.PostClick(btn)
    assert(btn.attr.macrotext=="/stopmacro")
    return action
end
local function pick(token)
    local line=press()
    assert(line:find("/target [@"..token..",exists,harm,nodead] "..token,1,true),line)
    assert(line:find("/tm [@"..token..",exists,harm,nodead] !8",1,true),line)
    assert(line:find("/ping [@"..token..",exists,harm,nodead] Attack",1,true),line)
    assert(not line:find("/cleartarget [nocombat]",1,true)); if units.target then assert(not line:find("/targetexact",1,true)) end
end
local denied={name="Raptor",tap=true,distance=4}
local allowed={name="Raptor",tap=false,distance=50}
units={target=denied,nameplate1=denied,nameplate2=allowed,nameplate3={name="Raptor",tap=false,distance=90}}
pick("nameplate2")
assert(AT.GetSmartTargetDiagnostic():find("Secure macro ran",1,true))
SlashCmdList.AUTOTRACKMOB("m"); assert(AT.GetSmartTargetDiagnostic():find("action-bar recall macro ran",1,true))
AT.db.pingWithMarker=false; local mark=press(); assert(mark:find("/tm ",1,true) and not mark:find("/ping ",1,true)); AT.db.pingWithMarker=true
units.target=allowed
units.nameplate3.distance=40
pick("nameplate3")
units.nameplate4={name="Raptor",tap=false}
pick("nameplate3") -- unknown extra plate must not discard measured distances
local nativeDistance=UnitDistanceSquared
function UnitDistanceSquared() return nil,false end
function UnitPosition(u)
    if u=="player" then return 0,0,0,1 end
    if u=="nameplate3" then return 6,0,0,1 end
    if u=="nameplate4" then return 1,0,0,2 end -- different instance
    if u=="target" or u=="nameplate2" then return 10,0,0,1 end
end
pick("nameplate3")
UnitPosition=nil
LibStub=function(name) if name=="LibRangeCheck-3.0" then
    return {GetRange=function(_,u)
        if u=="nameplate3" then return 5,8 end
        if u=="target" or u=="nameplate2" then return 10,15 end
    end}
end end
pick("nameplate3")
LibStub=nil;UnitDistanceSquared=nativeDistance
units.nameplate4=nil
units.nameplate2=nil;units.nameplate3=nil
assert(press():find("/tm [@target,exists,harm,nodead]",1,true))
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
C_NamePlate={GetNamePlates=function() return {{namePlateUnitToken="nameplate77"}} end}
units={nameplate77={name="Jungle Raptor",tap=false}}
pick("nameplate77")
units={nameplate77={name="Jungle Raptor",tap=true}}
assert(press()=="/stopmacro","do not recall a known denied match")
units={nameplate77={name="Jungle Raptor"}} -- unreadable tap off-target
local search=press()
assert(search:find("/target [noexists] Rap",1,true) and not search:find("/tm",1,true) and not search:find("/ping",1,true))
AT.char.targetName="Raptor";AT.char.targetPartial=false
assert(press():find("/targetexact [noexists] Raptor",1,true))
units.target={name="Raptor",tap=false}
assert(press():find("/tm [@target,exists,harm,nodead] !8",1,true))
AT.db.pressSkull=false
units={nameplate77={name="Raptor",tap=false}}
local plain=press()
assert(plain:find("/target",1,true) and not plain:find("/tm",1,true) and not plain:find("/ping",1,true))
local muted,restored,timers=0,0,{}
function MuteSoundFile() muted=muted+1 end
function UnmuteSoundFile() restored=restored+1 end
C_Timer={After=function(t,fn) timers[#timers+1]={t,fn} end}
AT.db.quietTarget=true
units={};press()
assert(muted==2,"the real Smart Target PreClick must mute before issuing native recall")
for _,timer in ipairs(timers) do timer[2]() end
assert(restored==2,"restore only the target sounds briefly muted")
AT.db.quietTarget=false
press()
assert(muted==2,"do not mute when disabled")
C_Timer=nil
combat=true
assert(press()=="/stopmacro")
print("PASS hardware Smart Target rejects denied/unknown, uses eligible units only, and owned normal macro cannot send blind marks/pings")
