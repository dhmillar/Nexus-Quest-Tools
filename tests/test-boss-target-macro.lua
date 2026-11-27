
local AT={db={enabled=true,bossAutoMark=false,bossMarkPing=false}}
local ui={}
UIParent={}
function CreateFrame(kind,_,parent,template)
    local f={kind=kind,parent=parent,template=template,attrs={},scripts={},shown=true}
    for _,n in ipairs({"SetAlpha","EnableMouse","SetSize","SetPoint","SetFrameStrata","SetAllPoints","RegisterForClicks","RegisterEvent"}) do f[n]=function()end end
    function f:UnregisterEvent() end
    function f:SetScript(k,v) self.scripts[k]=v end
    function f:SetAttribute(k,v) self.attrs[k]=v end
    function f:SetShown(v) self.shown=v end
    function f:Hide() self.shown=false end
    function f:Show() self.shown=true end
    function f:SetText(v) self.text=v end
    ui[#ui+1]=f;return f
end
function RegisterStateDriver(f,state,rule) f.driver=state..":"..rule end
local combat,raid,leader=false,false,false
local when=0
local kind="party"
local current=36
function IsInInstance() return true,kind end
function IsInRaid() return raid end
function UnitIsGroupLeader()return leader end
function UnitIsGroupAssistant()return false end
function GetInstanceInfo() return "The Deadmines",kind,nil,nil,nil,nil,nil,current end
function InCombatLockdown() return combat end
function GetTime() return when end
local units={}
function UnitExists(unit) return units[unit]~=nil end
function UnitGUID(unit) return units[unit].guid end
function GetRaidTargetIndex(unit) return units[unit].mark end
function UnitIsDeadOrGhost(unit) return units[unit].dead==true end
function UnitCanAttack(_,unit) return not units[unit].friendly and not units[unit].attackFlagPending end
function UnitClassification(unit) return units[unit].classification or "elite" end
function UnitName(unit) return units[unit].name end
function CanBeRaidTarget(unit) return not units[unit].immune end
function SetRaidTarget() error("never call protected marker from Lua") end
local secret={}
function issecretvalue(v) return v==secret end
C_Ping={SendMacroPing=function()error("never ping through Lua")end}
C_NamePlate={GetNamePlates=function()
    local r={}
    for unit in pairs(units) do if unit:match("^nameplate") then r[#r+1]={namePlateUnitToken=unit} end end
    table.sort(r,function(a,b)return a.namePlateUnitToken<b.namePlateUnitToken end)
    return r
end}
local function mob(id,serial,name,mark)
    return {guid="Creature-0-1-36-1-"..id.."-"..serial, name=name,mark=mark}
end
ForeverDungeonJournal_NS={INSTANCE_ID_TO_DUNGEON={[36]="The Deadmines"},DB={
    ["The Deadmines"]={bosses={{npcID=644},{npcID=639},{npcID=645}}}
}}

function UnitDistanceSquared(unit) return units[unit].dist, units[unit].dist~=nil end
function CheckInteractDistance(unit,index) return units[unit].interact==index end
local saved="Raptor"
local function noLearn() error("boss mode may not touch the saved mob") end
AT.GetTargetName=function() return saved end
AT.IsPartialTarget=function() return false end
AT.GetSelectedMobForSmartTarget=function() if AT.db.bossAutoMark and kind=="party" then return noLearn() end end
AT.MatchesSavedTarget=function(name) return name==saved end
function UnitIsPlayer() return false end
function UnitIsTapDenied() return false end
AT.SaveSelectedTarget=noLearn
AT.Say=function(note) AT.note=note end
assert(loadfile("NQT/DungeonPosition.lua"))("NQT",AT)
AT.InitBossTargetMarking()
assert(loadfile("NQT/SmartTarget.lua"))("NQT",AT)
ui[2].scripts.OnEvent(ui[2],"PLAYER_LOGIN")
local b=ui[3]
assert(b.attrs.type=="macro" and b.attrs.macrotext=="/stopmacro")
local function press()
    when=when+.3
    b.scripts.PreClick(b,"LeftButton",false)
    local body=b.attrs.macrotext
    b.scripts.PostClick(b)
    assert(b.attrs.macrotext=="/stopmacro","the old action is never left armed")
    return body
end
units.mouseover={name="Raptor"}; assert(press():find("/target [@mouseover",1,true)); units.mouseover=nil
AT.db.bossAutoMark=true
units.nameplate1=mob(644,101,"Boss A")
units.nameplate1.dist=144
units.nameplate2=mob(639,102,"Boss B")
units.nameplate2.dist=81
units.nameplate3=mob(648,103,"Trash")
units.nameplate3.dist=1
units.target=units.nameplate1
assert(press()=="/stopmacro [combat]\n/cleartarget\n/stopmacro [exists]\n/targetexact Boss B\n/tm [nodead] ~8\n/atmob k8:1\n/cleartarget [@target,dead]")
units.nameplate2.mark=8
AT.db.bossMarkPing=true
assert(press()=="/stopmacro [combat]\n/cleartarget\n/stopmacro [exists]\n/targetexact Boss A\n/tm [nodead] ~7\n/atmob k7:2\n/cleartarget [@target,dead]\n/stopmacro [noexists]\n/ping [@target] Attack")
units.nameplate1.mark=7
units.nameplate4=mob(645,104,"Boss C")
assert(press():find("~4",1,true),"third boss gets Triangle")
local old=units.nameplate2
units.nameplate2=nil
assert(press():find("~4",1,true),"remember an offscreen living boss with Skull")
units.nameplate2=old;old.dead=true
assert(press():find("Boss C",1,true))
when=when+1
units.nameplate4=nil
units.nameplate1.mark=nil
units.nameplate1.dist=nil
units.target=nil
units.nameplate2=mob(639,201,"Boss B new")
units.nameplate2.interact=3
assert(press():find("Boss B new",1,true),"documented range brackets are a fallback")
raid=true
assert(press()=="/stopmacro" and AT.note:find("permission",1,true))
leader=true
combat=true
assert(press()=="/stopmacro","combat cannot mutate or run an old boss macro")
combat=false
units.target=nil
kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
units.mouseover={name="Raptor"}; assert(press():find("/target [@mouseover",1,true),"outside dungeons verified saved-mob behavior remains"); units.mouseover=nil
print("PASS Smart Target real PreClick route: default/instance exit, nearest detected, range fallback, Skull/X, optional ping, no learned mob, permissions, combat and marker preservation")
-- The owned action-bar macro also switches modes. Stockade built-in IDs
-- work without Journal, even for an elite not classified as "worldboss".
kind="party";current=34;raid=false
ForeverDungeonJournal_NS=nil
units={nameplate1=mob(1717,321,"Hamhock"),nameplate2=mob(9999,456,"Trash")}
MAX_ACCOUNT_MACROS=120; MAX_CHARACTER_MACROS=18
local body="#AT4\n/atmob [btn:2]e;c"
function GetMacroInfo(i) if i==121 then return "Auto Track",134400,body end end
function CreateMacro() error("existing macro only") end
function EditMacro(i,n,icon,b)
    assert(i==121 and n=="Auto Track" and #b<=255)
    body=b;return i
end
assert(loadfile("NQT/Target.lua"))("NQT",AT)
assert(AT.RefreshBossActionBar())
assert(body:find("/targetexact Hamhock",1,true) and body:find("/ping [@target] Attack",1,true))
assert(not body:find("/atmob [btn:2]e;c",1,true),"does not capture the secondary target")
units.nameplate1.mark=8
units.nameplate3=mob(1716,789,"Bazil Thredd")
ui[1].scripts.OnEvent(ui[1],"RAID_TARGET_UPDATE")
assert(body:find("Bazil Thredd",1,true) and body:find("~7",1,true))
kind="none"
ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
assert(body:find("/atmob [btn:2]e;c",1,true) and not body:find("Bazil Thredd",1,true))
print("PASS owned action-bar macro selects known Stockade bosses, switches to X, pings and restores saved-mob mode")

-- Reproduce the report: Targorr's nameplate is visible, but the client
-- may hide the GUID and marker API data from Lua.
kind="party";current=34;raid=false
local hidden={}
local oldGuid=UnitGUID
function UnitGUID(unit)
    if unit=="nameplate1" then return hidden end
    return oldGuid(unit)
end
function issecretvalue(v) return v==secret or v==hidden end
units={nameplate1=mob(1696,773,"Targorr the Dread"),nameplate2=mob(648,205,"Defias Prisoner")}
assert(AT.RefreshBossActionBar())
assert(body:find("Targorr the Dread",1,true) and not body:find("Defias Prisoner",1,true))
assert(body:find("/tm [nodead] ~8",1,true))
units.nameplate2.mark=hidden
assert(AT.RefreshBossActionBar())
assert(body:find("Targorr the Dread",1,true) and not body:find("/tm",1,true),"an unreadable unrelated mark does not prevent targeting")
units={}
assert(AT.RefreshBossActionBar())
assert(#body<=255 and body:find("Targorr the Dread",1,true) and not body:find("Hamhock",1,true),"single-name native search when no Lua plates are readable")
AT.AdvanceBossSearch();assert(AT.RefreshBossActionBar())
assert(#body<=255 and body:find("Hamhock",1,true))
AT.AdvanceBossSearch();assert(AT.RefreshBossActionBar())
assert(#body<=255 and body:find("Kam Deepfury",1,true) and body:find("/ping",1,true))
print("PASS screenshot regression: exact Targorr match without GUID, safe unreadable mark handling, and bounded native Stockade search with ping")

-- Drive native line order through the real owned macro, including the addon
-- reservation callback after a mark; exposed GUID and marker reads can lag.
SlashCmdList={}
local pings, actual, priorTarget = {}, {}, nil
function SecureCmdOptionParse(s)
    if s=="[@target,exists,nodead] yes" then
        return units.target and not units.target.dead and "yes"
    end
    if s=="[@target,harm,nodead] yes" then
        local t=units.target
        return t and not t.dead and not t.friendly and not t.attackFlagPending and "yes"
    end
    if s=="[btn:2]e" then return nil end
    return s
end
AT.InitTarget()
local function native(text,lookup,refuse)
    for line in text:gmatch("[^\n]+") do
        local target=units.target
        local live=target and not target.dead
        local hostile=live and not target.friendly and not target.attackFlagPending
        local action,token=line:match("^/(%a+) %[@([%w]+),harm,nodead%]")
        if action then
            local chosen=units[token]
            if chosen and not chosen.dead and not chosen.friendly and not chosen.attackFlagPending then
                if action=="stopmacro" then return
                elseif action=="target" then units.target=chosen
                elseif action=="ping" then pings[#pings+1]=chosen
                elseif action=="tm" and not actual[chosen] then
                    local index=tonumber(line:match("~(%d)$"))
                    for u,mark in pairs(actual) do if mark==index then actual[u]=nil end end
                    actual[chosen]=index
                end
            end
        elseif line=="/stopmacro [combat]" or line=="/stopmacro [btn:2][combat]" then
            if combat then return end
        elseif line=="/cleartarget" then
            if not refuse then priorTarget,target=target,nil; units.target=target end
        elseif line=="/stopmacro [exists,nodead]" then
            if live then return end
        elseif line=="/stopmacro [noexists]" then
            if not target then return end
        elseif line=="/stopmacro [exists]" then
            if target then return end
        elseif line:find("^/targetexact") then
            local name=line:match("^/targetexact %[noexists%]%[dead%] (.*)$")
                or line:match("^/targetexact %[noexists%] (.*)$") or line:match("^/targetexact ([^%[].*)$")
            if not target or (target.dead and line:find("[dead]",1,true)) then
                local hit=lookup[name]
                if hit then units.target=hit;ui[1].scripts.OnEvent(ui[1],"PLAYER_TARGET_CHANGED") end
            end
        elseif line:find("^/tm ") and (line:find("[nodead]",1,true) and live or hostile) then
            local index=tonumber(line:match("~(%d)$")); assert(index)
            if not actual[target] then
                for unit,mark in pairs(actual) do if mark==index then actual[unit]=nil end end
                actual[target]=index
            end
        elseif line:find("^/ping ") then
            assert(live and line=="/ping [@target] Attack","native guard must prevent pinging a corpse or the ground")
            pings[#pings+1]=target
        elseif line:find("^/atmob ") then
            SlashCmdList.AUTOTRACKMOB(line:sub(8))
        elseif line=="/cleartarget [@target,dead]" and target and target.dead then
            units.target=nil
        elseif line=="/targetlasttarget [noexists]" and not target then
            units.target=priorTarget
        end
    end
end
local targorr=mob(1696,101,"Targorr the Dread")
local kam=mob(1666,102,"Kam Deepfury")
-- Run once from the Blizzard action-bar path and once from Smart Target
-- PreClick, deliberately without any client mark acknowledgement.
for _,useSmart in ipairs({false,true}) do
    units={}; pings={}; actual={}
    kind="none"; ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    kind="party"; ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    assert(AT.RefreshBossActionBar())
    local first=useSmart and press() or body
    assert(first:find("Targorr the Dread",1,true) and (useSmart or not first:find("Hamhock",1,true)))
    native(first,{[targorr.name]=targorr},false)
    assert(actual[targorr]==8 and pings[1]==targorr)
    -- Issue another action before any delayed RAID_TARGET_UPDATE; Targorr
    -- can be offscreen and Lua cannot read its marker or inspect a GUID.
    when=when+12
    units={nameplate1=kam,nameplate2=targorr} -- Targorr API mark stays nil forever.
    ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD") -- same-instance loading screen
    assert(AT.RefreshBossActionBar())
    local second=useSmart and press() or body
    assert(second:find("Kam Deepfury",1,true) and second:find("~7",1,true) and not second:find("~8",1,true))
    native(second,{[kam.name]=kam},false)
    assert(actual[targorr]==8 and actual[kam]==7 and pings[2]==kam)
    assert(#second<=(useSmart and 900 or 255) and #first<=(useSmart and 900 or 255))
    local previousPings=#pings
    units.target=targorr
    native(second,{[kam.name]=kam},true)
    assert(units.target==targorr and #pings==previousPings)
    native(second,{},false)
    assert(units.target==nil and #pings==previousPings)
end
print("PASS exact screenshot repro through both macro entry points: Targorr keeps Skull, Kam gets X before delayed confirmation, explicit unit pings, failed clear/search cannot mark or ping")

-- Instance-scoped stock coverage, without the optional DungeonJournal.
assert(loadfile("NQT/DungeonCatalog.lua"))("NQT",AT)
local ids={33,34,36,43,47,48,70,90,109,129,189,209,229,230,289,329,349,389,429,
    2959,2970,2974,2994,2998,2999,3001,3039,3065}
local count=0
function UnitGUID(unit) return oldGuid(unit) end
function UnitCreatureID(unit) return units[unit].npc end
for _,id in ipairs(ids) do
    current=id
    local roster=assert(AT.GetForeverDungeonBossFacts(id))
    assert(#roster>0)
    units={}
    for i,record in ipairs(roster) do
        assert(record[2]~="Trash Drops" and record[2]~="")
        count=count+1
        if record[1]>0 then
            units.nameplate1=mob(record[1],909,record[2])
            units.nameplate1.npc=record[1]
            assert(AT.RefreshBossActionBar())
            assert(body:find(id==3039 and "/target [@nameplate1,harm,nodead]" or "/targetexact "..record[2],1,true),
                "missing boss '"..record[2].."' in instance "..id..": "..body)
            assert(#body<=255)
        end
    end
end
assert(count==292)
print("PASS 292 boss records across 28 instance IDs / 35 dungeon-wing tables; native selection for every verified creature ID")

-- Assign all eight markers while deliberately hiding confirmation from
-- Lua, then prove exhaustion and safe reuse on confirmed death.
for _,useSmart in ipairs({false,true}) do
    kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    kind="party";current=230;ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    units={};actual={};pings={}
    local roster=AT.GetForeverDungeonBossFacts(current)
    local bosses={}
    for i=1,9 do
        local b=mob(roster[i][1],400+i,roster[i][2]);b.npc=roster[i][1];b.dist=i
        bosses[i]=b; units["nameplate"..i]=b
    end
    local lookup={}
    for _,b in ipairs(bosses) do lookup[b.name]=b end
    local order={8,7,4,6,3,1,5,2}
    for i=1,8 do
        assert(AT.RefreshBossActionBar())
        local text=useSmart and press() or body
        assert(text:find("/targetexact "..bosses[i].name,1,true))
        assert(text:find("~"..order[i],1,true) and #text<=255)
        native(text,lookup,false)
        for n=1,i do assert(actual[bosses[n]]==order[n],"keep each previous boss's icon") end
    end
    assert(AT.RefreshBossActionBar())
    assert(not (useSmart and press() or body):find("/tm",1,true),"out of icons, never overwrite")
    bosses[1].dead=true
    assert(AT.RefreshBossActionBar())
    local text=useSmart and press() or body
    assert(text:find("/targetexact "..bosses[9].name,1,true))
    assert(text:find("~8",1,true),"confirmed death resets priority to Skull")
    native(text,lookup,false)
    assert(actual[bosses[9]]==8 and actual[bosses[1]]==nil and actual[bosses[2]]==7 and actual[bosses[3]]==4)
end
print("PASS all eight raid icons in order, exhaustion without replacing living owners, and confirmed-death reuse through both entry points")

-- Reproduce the third-boss problem: a duplicate token or a known marked
-- owner can have an unreadable marker without locking out the third mark.
kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
kind="party";current=34;ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
local aa=mob(1696,601,"Targorr the Dread",8)
local bb=mob(1666,602,"Kam Deepfury",7)
local cc=mob(1717,603,"Hamhock")
actual={[aa]=8,[bb]=7};pings={}
units={nameplate1=aa,nameplate2=bb,target=aa}
AT.RefreshBossActionBar()
aa.mark=secret
cc.mark=secret
units.nameplate3=cc
assert(AT.RefreshBossActionBar())
assert(body:find("Hamhock",1,true) and body:find("~4",1,true),"hidden known-owner and selected icon states no longer block Triangle")
native(body,{Hamhock=cc},false)
assert(actual[aa]==8 and actual[bb]==7 and actual[cc]==4 and pings[1]==cc)
print("PASS third boss gets Triangle and ping when prior boss or its own marker read is restricted")

-- A manually removed mark must re-arm a verified selected boss, while
-- a nil mark from an off-screen nameplate alone must not free anything.
for _,useSmart in ipairs({false,true}) do
    units={}
    kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    kind="party";current=34;ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    local a=mob(1696,801,"Targorr the Dread",8);a.dist=100
    local b=mob(1666,802,"Kam Deepfury");b.dist=25
    units={target=a,nameplate1=a,nameplate2=b};actual={[a]=8};pings={}
    assert(AT.RefreshBossActionBar())
    a.mark=nil
    units.target=nil
    assert(AT.RefreshBossActionBar())
    assert(body:find("~7",1,true),"a nameplate reading nil cannot clear a live Skull: "..body)
    units.target=a;actual[a]=nil;units.nameplate2=nil
    assert(AT.RefreshBossActionBar())
    assert(AT.RefreshBossActionBar())
    local text=useSmart and press() or body
    assert(text:find("Targorr the Dread",1,true) and text:find("~8",1,true),
        "confirmed manual clear re-arms selected boss with highest free icon")
    native(text,{[a.name]=a,[b.name]=b},false)
    assert(actual[a]==8 and not actual[b] and pings[1]==a)
end
print("PASS confirmed manual removal, repeated preview refreshes and same-boss re-mark via both press paths")

-- A repeated manual clear and immediate action-bar press must not rely on
-- any delay expiring or an update from the periodic scan.
for _,useSmart in ipairs({false,true}) do
    units={};kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    kind="party";current=34;ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    local a=mob(1696,911,"Targorr the Dread",8)
    local other=mob(1666,912,"Kam Deepfury",7)
    local t=a
    units={nameplate1=a,nameplate2=other}
    actual={[a]=8,[other]=7};pings={}
    assert(AT.RefreshBossActionBar()) -- confirmation comes from nameplate, not target
    units.target=a
    for i=1,3 do
        actual[a]=nil
        a.mark=nil
        local delayed={}
        C_Timer={After=function(_,callback) delayed[#delayed+1]=callback end}
        ui[1].scripts.OnEvent(ui[1],"UNIT_HEALTH") -- unrelated refresh already queued
        ui[1].scripts.OnEvent(ui[1],"RAID_TARGET_UPDATE")
        local text=useSmart and press() or body
        assert(text:find("Targorr the Dread",1,true) and text:find("~8",1,true))
        native(text,{[a.name]=a,[other.name]=other},false)
        assert(actual[a]==8 and actual[other]==7)
        a.mark=8
        ui[1].scripts.OnEvent(ui[1],"RAID_TARGET_UPDATE")
        for _,callback in ipairs(delayed) do callback() end
        C_Timer=nil
    end
end
print("PASS three immediate manual clears per entry point, nameplate-only prior confirmation, and refresh even with an older timer pending")

for _,useSmart in ipairs({false,true}) do
    units={};kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    kind="party";current=34;ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    local a=mob(1696,991,"Targorr the Dread",8)
    local b2=mob(1666,992,"Kam Deepfury",7)
    local c=mob(1717,993,"Hamhock")
    units={nameplate1=a,nameplate2=b2,nameplate3=c};actual={[a]=8,[b2]=7};pings={}
    assert(AT.RefreshBossActionBar())
    local first=useSmart and press() or body
    assert(first:find("~4",1,true) and first:find("/cleartarget [@target,dead]",1,true))
    units.target=c;SlashCmdList.AUTOTRACKMOB("k4") -- server failed to apply the first request
    when=when+1
    assert(AT.RefreshBossActionBar())
    local retry=useSmart and press() or body
    assert(retry:find("Hamhock",1,true) and retry:find("~4",1,true),"retry the same provisional owner after a rejected mark")
    native(retry,{Hamhock=c},false)
    assert(actual[c]==4 and actual[a]==8 and actual[b2]==7)
    c.mark=4;ui[1].scripts.OnEvent(ui[1],"RAID_TARGET_UPDATE")
    units.target=nil
    a.mark,b2.mark,c.mark=nil,nil,nil;actual={}
    ui[1].scripts.OnEvent(ui[1],"RAID_TARGET_UPDATE")
    when=when+.2;AT.RefreshBossActionBar()
    local next=useSmart and press() or body
    assert(next:find("~8",1,true),"clearing several visible marks with no target recovers Skull")
end
print("PASS retries a refused third mark, keeps dead-target cleanup after mark and ping, and re-arms after clearing all visible boss marks without a selected target")

-- A native marker event may run while the same hardware press is executing.
-- Never rewrite the action-bar macro body until that execution unwinds.
units={};kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
kind="party";current=34;ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
local one=mob(1696,1991,"Targorr the Dread");one.npc=1696
local two=mob(1666,1992,"Kam Deepfury");two.npc=1666
units={nameplate1=one};AT.RefreshBossActionBar()
local oldBody=body
assert(oldBody:find(";h",1,true) and not oldBody:find("targetlasttarget",1,true))
local callbacks={}
C_Timer={After=function(_,fn) callbacks[#callbacks+1]=fn end}
SlashCmdList.AUTOTRACKMOB("h")
units={target=one,nameplate1=one,nameplate2=two}
one.mark=8
ui[1].scripts.OnEvent(ui[1],"RAID_TARGET_UPDATE")
assert(body==oldBody,"raid marker event cannot rewrite a running macro")
when=when+.2
for _,fn in ipairs(callbacks) do fn() end
assert(body~=oldBody and body:find("~7",1,true) and body:find("Kam Deepfury",1,true))
C_Timer=nil
print("PASS raid-marker event during an action-bar macro defers EditMacro until after the press")

-- A stale press targeting an already marked boss must not consume the
-- third (or any remaining) slot even when repeated on both entry paths.
for _,useSmart in ipairs({false,true}) do
    units={};kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    kind="party";current=34;ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    local a=mob(1696,2111,"Targorr the Dread",8)
    local b2=mob(1666,2112,"Kam Deepfury",7)
    local c=mob(1717,2113,"Hamhock")
    units={target=a,nameplate1=a,nameplate2=b2,nameplate3=c}
    actual={[a]=8,[b2]=7};pings={}
    for _,k in ipairs({4,6,3,1,5,2}) do SlashCmdList.AUTOTRACKMOB("k"..k) end
    assert(AT.RefreshBossActionBar())
    local text=useSmart and press() or body
    assert(text:find("Hamhock",1,true) and text:find("~4",1,true))
    native(text,{Hamhock=c},false)
    assert(actual[a]==8 and actual[b2]==7 and actual[c]==4 and pings[1]==c)
end
SlashCmdList.AUTOTRACKMOB("k0")
AT.InitBossTargetMarking()
SlashCmdList.NEXUSCHECKBOSSMARK()
assert(AT.note:find("no marker command was sent",1,true))
print("PASS repeated stale requests cannot consume free icons; third boss still gets Triangle; diagnostic distinguishes ping-only press")

-- The game can expose a nil marker on a still-marked selected boss.
-- Simulate that read, then a rapid press before and after the marker event.
for _,useSmart in ipairs({false,true}) do
    units={};kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    kind="party";current=34;ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    local a=mob(1696,3101,"Targorr the Dread",8)
    local b2=mob(1666,3102,"Kam Deepfury",7)
    local c=mob(1717,3103,"Hamhock")
    units={target=a,nameplate1=a,nameplate2=b2}
    actual={[a]=8,[b2]=7};pings={}
    AT.RefreshBossActionBar()
    a.mark=nil
    units.nameplate3=c
    ui[1].scripts.OnEvent(ui[1],"RAID_TARGET_UPDATE")
    for i=1,5 do
        AT.RefreshBossActionBar()
        local text=useSmart and press() or body
        if i==1 then assert(text:find("Hamhock",1,true) and text:find("~4",1,true),
            "live but unreported Skull still belongs to Targorr: "..text) end
        native(text,{[a.name]=a,[b2.name]=b2,[c.name]=c},false)
        assert(actual[a]==8 and actual[b2]==7 and actual[c]==4)
    end
end
print("PASS selected boss with false nil read keeps Skull, X stays on second boss, third gets Triangle and five repeated presses preserve them")

-- Live screenshot path: native targeting sees names, while Lua gets no
-- nameplate tokens and secret name/GUID/marker reads on the acquired target.
local prevName,prevGUID,prevMark=UnitName,UnitGUID,GetRaidTargetIndex
function UnitName(unit) if unit=="target" then return secret end return prevName(unit) end
function UnitGUID(unit) if unit=="target" then return secret end return prevGUID(unit) end
function GetRaidTargetIndex(unit) if unit=="target" then return secret end return prevMark(unit) end
for _,useSmart in ipairs({false,true}) do
    units={};kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    kind="party";current=34;ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    local first=mob(1696,4101,"Targorr the Dread")
    local second=mob(1717,4102,"Hamhock")
    local third=mob(1666,4103,"Kam Deepfury")
    actual={};pings={}
    local lookup={[first.name]=first,[second.name]=second,[third.name]=third}
    local order={8,7,4}
    for n,boss in ipairs({first,second,third}) do
        assert(AT.RefreshBossActionBar())
        local text=useSmart and press() or body
        assert(text:find(boss.name,1,true) and text:find("~"..order[n],1,true)
            and (text:find("/atmob k"..order[n]..":",1,true) or text:find("/atmob j"..order[n]..":",1,true)),text)
        native(text,lookup,false)
        assert(actual[boss]==order[n] and pings[n]==boss)
    end
    for i=1,10 do
        AT.RefreshBossActionBar()
        native(useSmart and press() or body,lookup,false)
        assert(actual[first]==8 and actual[second]==7 and actual[third]==4)
    end
    SlashCmdList.NEXUSCHECKBOSSMARK()
    assert(not AT.note:find("unknown boss",1,true),AT.note)
end
UnitName,UnitGUID,GetRaidTargetIndex=prevName,prevGUID,prevMark
print("PASS screenshot path: no plates, hidden names/GUIDs/markers, consecutive native presses mark and ping all three without moving Skull")

-- A single Smart Target keypress can skip two native name misses even
-- when Lua cannot see a single boss. The next presses prefer fresh bosses.
units={};kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
kind="party";current=34;ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
function UnitName(unit) if unit=="target" then return secret end return prevName(unit) end
function UnitGUID(unit) if unit=="target" then return secret end return prevGUID(unit) end
function GetRaidTargetIndex(unit) if unit=="target" then return secret end return prevMark(unit) end
local k=mob(1666,6101,"Kam Deepfury")
local d=mob(1663,6102,"Dextren Ward")
local b3=mob(1716,6103,"Bazil Thredd")
actual={};pings={}
local first=press()
assert(#first>255 and #first<=900 and first:find("Targorr the Dread",1,true) and first:find("Hamhock",1,true)
    and first:find("Kam Deepfury",1,true),first)
native(first,{[k.name]=k},false)
assert(actual[k]==8 and pings[1]==k,"one physical press skips two missing names")
local second=press()
native(second,{[k.name]=k,[d.name]=d},false)
assert(actual[k]==8 and actual[d]==7 and pings[2]==d,"next press marks a different boss")
local third=press()
native(third,{[k.name]=k,[d.name]=d,[b3.name]=b3},false)
assert(actual[k]==8 and actual[d]==7 and actual[b3]==4 and pings[3]==b3,"third press finds and marks another fresh boss")
UnitName,UnitGUID,GetRaidTargetIndex=prevName,prevGUID,prevMark
print("PASS native multi-name Smart Target keypress skips misses and cycles Skull/X/Triangle on repeated presses when names are hidden")

-- Real user regression: a first successful mark must not cause the next
-- press to cycle through missing names when that same boss is still near.
for _,useSmart in ipairs({false,true}) do
    units={};kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    kind="party";current=34;ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    function UnitName(unit) if unit=="target" then return secret end return prevName(unit) end
    function UnitGUID(unit) if unit=="target" then return secret end return prevGUID(unit) end
    function GetRaidTargetIndex(unit) if unit=="target" then return secret end return prevMark(unit) end
    local a=mob(1696,7101,"Targorr the Dread")
    local last=mob(1720,7102,"Bruegal Ironknuckle")
    actual={};pings={}
    AT.RefreshBossActionBar()
    native(useSmart and press() or body,{[a.name]=a},false)
    assert(actual[a]==8 and #pings==1)
    -- Only Targorr is reachable. Reacquire on the very next press even
    -- with live plate and target identity hidden from addon Lua.
    AT.RefreshBossActionBar()
    local next=useSmart and press() or body
    native(next,{[a.name]=a},false)
    assert(units.target==a and #pings==2 and actual[a]==8,next)
    if useSmart then
        -- A later boss has come into native targeting range; same press
        -- tries the whole Stockade roster before falling back to Targorr.
        native(press(),{[a.name]=a,[last.name]=last},false)
        assert(actual[a]==8 and actual[last]==7 and units.target==last and #pings==3)
    else
        assert(#next<=255,"stored action bar macro must fit")
    end
    UnitName,UnitGUID,GetRaidTargetIndex=prevName,prevGUID,prevMark
end
print("PASS immediate same-boss reacquisition on both entry points, no duplicate pings, and last roster boss gets X on the next Smart Target press")

-- The native exact search can return a corpse even when Lua had no
-- nameplate for it or its previously live action-bar body is cached.
for _,useSmart in ipairs({false,true}) do
    units={};kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    kind="party";current=34;ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    local a=mob(1696,8201,"Targorr the Dread")
    local b2=mob(1717,8202,"Hamhock")
    actual={};pings={}
    assert(AT.RefreshBossActionBar())
    local first=useSmart and press() or body
    a.dead=true
    native(first,{[a.name]=a},false)
    assert(units.target==nil and next(actual)==nil and #pings==0,"a corpse never stays selected, is marked, or is pinged")
    if useSmart then
        -- Restart with the corpse first, then a living boss on the same press.
        units={};kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
        kind="party";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
        native(press(),{[a.name]=a,[b2.name]=b2},false)
        assert(units.target==b2 and actual[b2]==8 and pings[1]==b2 and not actual[a])
    end

    units={};kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    kind="party";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    a.dead=false;actual={};pings={}
    assert(AT.RefreshBossActionBar())
    native(useSmart and press() or body,{[a.name]=a},false)
    assert(units.target==a and #pings==1 and actual[a]==8)
    a.dead=true
    units={}
    assert(AT.RefreshBossActionBar())
    local recovery=useSmart and press() or body
    assert(recovery:find(a.name,1,true),"recent exact-name fallback remains present")
    native(recovery,{[a.name]=a},false)
    assert(units.target==nil and #pings==1 and actual[a]==8,
        "recovering the last boss must not leave its corpse targeted or send another ping")
end

-- A long name may lose its optional ping, but must keep targeting, marking,
-- the combat/miss guards, and terminal corpse cleanup within 255 bytes.
units={};kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
kind="party";current=34;ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
local long=mob(1696,8234,("B"):rep(85))
units.nameplate1=long;assert(AT.RefreshBossActionBar())
assert(#body<=255 and body:find(long.name,1,true) and body:find("~8",1,true) and body:sub(-27)=="/cleartarget [@target,dead]")
long.dead=true;actual={};pings={}
native(body,{[long.name]=long},false)
assert(units.target==nil and next(actual)==nil and #pings==0)
print("PASS both macro entry points clear corpses, including stale and recovery results; Smart Target continues to a living boss and long names fit")

-- Krol'dok has no blind named probes when the client cannot certify life.
for _,smart in ipairs({false,true}) do
    units={};kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    kind="party";current=3039;ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    local grox=mob(258966,9201,"Slavecrusher Grox")
    local z=mob(258972,9202,"Twilight Commander Zarmok")
    grox.dead=true;units.target=grox
    actual={};pings={}
    assert(AT.RefreshBossActionBar())
    local miss=smart and press() or body
    assert(not miss:find("exists",1,true))
    native(miss,{[grox.name]=grox},false)
    assert(not units.target and next(actual)==nil and #pings==0)
    units.nameplate1=z
    assert(AT.RefreshBossActionBar())
    local action=smart and press() or body
    assert(action:find("/target [@nameplate1,harm,nodead]",1,true) and not action:find("exists",1,true))
    native(action,{},false)
    assert(units.target==z and actual[z]==8 and pings[1]==z)
    local before=#pings
    z.dead=true
    native(action,{},false)
    assert(not units.target and #pings==before,"cached macro must not retarget a boss after it dies")
    z.dead=false
    local old=UnitIsDeadOrGhost
    UnitIsDeadOrGhost=function()return secret end
    assert(AT.RefreshBossActionBar())
    assert(not (smart and press() or body):find("/target ",1,true),"unknown death status must use native guarded search, not a direct unit token")
    UnitIsDeadOrGhost=old
end
do
    units={};kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    kind="party";current=3039;ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    local z=mob(258972,9501,"Twilight Commander Zarmok");units.target=z
    local run={closed=false}
    local reportedMap=3039
    local old=ForeverDungeonJournal_NS
    ForeverDungeonJournal_NS={
        RunLog={InsideMap=function()return reportedMap end,Current=function()return run end},
        RunLogKilledThisVisit=function(r,name)return r==run and name==z.name end
    }
    assert(AT.RefreshBossActionBar())
    assert(not body:find(z.name,1,true) and not press():find(z.name,1,true),"same-run Journal evidence wins over stale live metadata")
    reportedMap=2970
    assert(press():find("/ping [@target,harm,nodead]",1,true),"unrelated Journal map must not suppress a live boss")
    ForeverDungeonJournal_NS=old
end
print("PASS Krol'dok: both buttons target and act only on a verified living unit, skip missing/hidden/dead and then reject a stale cached boss that died")

-- A client can expose a plate only through its event or alternate public
-- frame field. A party target can identify a boss without a readable name.
for _,smart in ipairs({false,true}) do
    units={};kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    kind="party";current=3039;ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    local grox=mob(258966,9601,"Slavecrusher Grox");grox.dead=true
    local mugg=mob(258968,9602,"Overlord Mugg");mugg.dist=400
    local z=mob(258972,9603,secret);z.dist=625
    local ashka=mob(259281,9604,"War Handler Ashka");ashka.dist=900
    local trash=mob(999,9605,"Trash");trash.dist=1
    local original=C_NamePlate.GetNamePlates
    C_NamePlate.GetNamePlates=function()return {{unitToken="nameplate8"}} end
    units.target=grox;units.boss1=trash;units.nameplate5=mugg
    units.party1target=z;units.nameplate8=ashka
    ui[1].scripts.OnEvent(ui[1],"NAME_PLATE_UNIT_ADDED","nameplate5")
    actual={};pings={}
    assert(AT.RefreshBossActionBar())
    local first=smart and press() or body
    assert(first:find("/target [@nameplate5,harm,nodead]",1,true),first)
    native(first,{},false)
    assert(units.target==mugg and actual[mugg]==8 and pings[1]==mugg)
    mugg.mark=8
    ui[1].scripts.OnEvent(ui[1],"RAID_TARGET_UPDATE")
    local second=smart and press() or body
    assert(second:find("/target [@party1target,harm,nodead]",1,true),second)
    native(second,{},false)
    assert(units.target==z and actual[z]==7 and pings[2]==z and not actual[grox] and not actual[trash])
    z.mark=7
    ui[1].scripts.OnEvent(ui[1],"RAID_TARGET_UPDATE")
    local third=smart and press() or body
    assert(third:find("/target [@nameplate8,harm,nodead]",1,true),third)
    native(third,{},false)
    assert(units.target==ashka and actual[ashka]==4 and pings[3]==ashka)
    units.target=grox;units.nameplate5=trash;units.party1target=nil;units.nameplate8=nil
    ui[1].scripts.OnEvent(ui[1],"NAME_PLATE_UNIT_REMOVED","nameplate5")
    local gone=smart and press() or body
    native(gone,{},false)
    assert(units.target==nil and #pings==3 and not actual[trash])
    C_NamePlate.GetNamePlates=original
end
print("PASS Krol'dok dynamic event plates, alternate frame field, name-masked party targets, three unique markers, and corpse/recycled-token removal")


-- A press still cycles through all living bosses when no marker is free or
-- when the visible bosses already have marks. A sole boss is not re-pinged.
for _,smart in ipairs({false,true}) do
    units={};kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    kind="party";current=3039;ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    local a=mob(258964,9701,"Nar'gurk",8);a.dist=100
    local b2=mob(258966,9702,"Slavecrusher Grox",7);b2.dist=225
    local c=mob(258972,9703,"Twilight Commander Zarmok",4);c.dist=400
    local corpse=mob(258968,9704,"Overlord Mugg");corpse.dead=true;corpse.dist=1
    units.nameplate1=a;units.nameplate2=b2;units.nameplate3=c;units.nameplate4=corpse
    actual={[a]=8,[b2]=7,[c]=4};pings={}
    local queued={}
    local savedTimer=C_Timer
    C_Timer={After=function(_,fn)queued[#queued+1]=fn end}
    local function flush()
        local batch=queued;queued={}
        for _,fn in ipairs(batch) do fn() end
    end
    assert(AT.RefreshBossActionBar())
    for i,want in ipairs({a,b2,c,a,b2,c}) do
        local action=smart and press() or body
        assert(not action:find("/tm ",1,true))
        native(action,{},false)
        assert(units.target==want and pings[i]==want and #pings==i)
        flush()
    end
    assert(actual[a]==8 and actual[b2]==7 and actual[c]==4 and not actual[corpse])
    units.nameplate1=nil;units.nameplate2=nil
    ui[1].scripts.OnEvent(ui[1],"NAME_PLATE_UNIT_REMOVED","nameplate1")
    local last=smart and press() or body
    assert(not last:find("/targetexact "..c.name.."\n/ping ",1,true))
    native(last,{},false)
    assert((not units.target or units.target==c) and #pings==6)
    C_Timer=savedTimer
end
print("PASS Krol'dok: both buttons cycle three marked bosses without repeating, keep their markers, skip corpses, and suppress lone-boss ping spam")

-- Repro from the actual client: Ashka is alive and hostile, but both
-- identifying fields read as hidden. Only native exact-name search sees her.
for _,smart in ipairs({false,true}) do
    units={};kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    kind="party";current=3039;ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    local g=mob(258966,9801,"Slavecrusher Grox");g.dead=true
    local a=mob(259281,9802,"War Handler Ashka")
    local z=mob(258972,9803,"Twilight Commander Zarmok")
    local trash=mob(1234,9804,"Trash")
    local names={[g.name]=g,[a.name]=a}
    local oldName,oldGUID=UnitName,UnitGUID
    UnitName=function(u)if units[u]==a or units[u]==z then return secret end return oldName(u) end
    UnitGUID=function(u)if units[u]==a or units[u]==z then return secret end return oldGUID(u) end
    units.target=a;pings={};actual={}
    assert(AT.RefreshBossActionBar())
    local first=smart and press() or body
    assert(first:find("[@target,harm,nodead]",1,true) and not first:find("exists",1,true))
    units.target=trash
    native(first,names,true)
    assert(units.target==trash and #pings==0 and not actual[trash],"failed clear must abort the probe")
    units.target=a
    if smart then
        native(first,names,false)
    else
        for i=1,14 do
            assert(AT.RefreshBossActionBar())
            assert(#body<=255)
            native(body,names,false)
            if actual[a] then break end
            assert(not units.target and #pings==0)
        end
    end
    assert(units.target==a and actual[a]==8 and pings[1]==a and #pings==1 and not actual[g])
    a.mark=8
    names[z.name]=z
    for i=1,14 do
        assert(AT.RefreshBossActionBar())
        native(smart and press() or body,names,false)
        if actual[z] then break end
    end
    assert(actual[a]==8 and actual[z]==7 and pings[2]==z and not actual[g])
    UnitName,UnitGUID=oldName,oldGUID
end
print("PASS Krol'dok native hidden-identity fallback: Ashka, second living boss, unchanged raid icon, no exists predicates, misses and corpse cleanup")


-- A readable Toof must not monopolize selection when the next boss is
-- hidden from Lua. Removing that second boss's marker must re-arm the same
-- icon and ping without moving Toof's existing Skull.
for _,smart in ipairs({false,true}) do
    units={};kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    kind="party";current=3039;ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    local toof=mob(264773,9901,"Bossman Toof")
    local ashka=mob(259281,9902,"War Handler Ashka")
    local names={[toof.name]=toof,[ashka.name]=ashka}
    local oldName,oldGUID=UnitName,UnitGUID
    UnitName=function(u)if units[u]==ashka then return secret end return oldName(u) end
    UnitGUID=function(u)if units[u]==ashka then return secret end return oldGUID(u) end
    units.nameplate7=toof
    actual={};pings={}
    assert(AT.RefreshBossActionBar())
    native(smart and press() or body,names,false)
    assert(units.target==toof and actual[toof]==8 and pings[1]==toof)
    toof.mark=8
    ui[1].scripts.OnEvent(ui[1],"RAID_TARGET_UPDATE")
    for i=1,14 do
        assert(AT.RefreshBossActionBar())
        native(smart and press() or body,names,false)
        if actual[ashka] then break end
    end
    assert(units.target==ashka and actual[ashka]==7 and actual[toof]==8 and pings[2]==ashka and #pings==2)
    ashka.mark=7
    ui[1].scripts.OnEvent(ui[1],"RAID_TARGET_UPDATE")
    ashka.mark=nil;actual[ashka]=nil
    ui[1].scripts.OnEvent(ui[1],"RAID_TARGET_UPDATE")
    -- The scanner knows Toof is visible and Ashka's icon was cleared,
    -- so the next press should retry Ashka instead of retargeting Toof.
    assert(AT.RefreshBossActionBar())
    local rearm=smart and press() or body
    native(rearm,names,false)
    assert(actual[toof]==8 and actual[ashka]==7 and pings[3]==ashka,rearm)
    UnitName,UnitGUID=oldName,oldGUID
end
print("PASS repeat Krol'dok marks: visible Toof does not block hidden Ashka, confirmed clear re-arms Ashka's marker and ping")


-- A defeated hidden boss can disappear before its raid marker can be read.
-- The confirmed encounter kill should release its icon for the next boss.
do
    units={};kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    kind="party";current=3039;ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    local g=mob(258966,9991,"Slavecrusher Grox")
    local a=mob(259281,9992,"War Handler Ashka")
    local oldName,oldGUID=UnitName,UnitGUID
    UnitName=function()return secret end
    UnitGUID=function()return secret end
    actual={};pings={}
    native(press(),{[g.name]=g},false)
    assert(actual[g]==8 and pings[1]==g)
    g.dead=true;units={}
    ui[1].scripts.OnEvent(ui[1],"ENCOUNTER_END",3450,"Slavecrusher Grox",1,5,1)
    native(press(),{[g.name]=g,[a.name]=a},false)
    assert(units.target==a and actual[a]==8 and pings[2]==a)
    UnitName,UnitGUID=oldName,oldGUID
end
print("PASS confirmed Grox defeat retires the hidden reservation and frees Skull for Ashka")


-- Regression: one valid boss, six missable/dead names. Every search
-- must recover that boss (or arm recovery on the short action-bar path).
for _,smart in ipairs({false,true}) do
    units={};kind="none";ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    kind="party";current=3039;ui[1].scripts.OnEvent(ui[1],"PLAYER_ENTERING_WORLD")
    local toof=mob(264773,10001,"Bossman Toof")
    local corpse=mob(258966,10002,"Slavecrusher Grox");corpse.dead=true
    local lookup={[toof.name]=toof,[corpse.name]=corpse}
    local oldName,oldGUID=UnitName,UnitGUID
    UnitName=function()return secret end
    UnitGUID=function()return secret end
    units.nameplate1=toof;actual={};pings={}
    for i=1,14 do
        assert(AT.RefreshBossActionBar())
        native(smart and press() or body,lookup,false)
        if actual[toof] then break end
    end
    assert(units.target==toof and pings[1]==toof and actual[toof]==8)
    toof.mark=8
    for i=1,6 do
        units.target=nil
        assert(AT.RefreshBossActionBar())
        native(smart and press() or body,lookup,false)
        if not units.target and not smart then
            assert(AT.RefreshBossActionBar())
            native(body,lookup,false)
        end
        assert(units.target==toof and #pings==1 and actual[toof]==8 and not actual[corpse],
            "repeated searches must reacquire Toof without additional pings or corpse selection")
    end
    local a=mob(259281,10003,"War Handler Ashka");lookup[a.name]=a
    for i=1,14 do
        assert(AT.RefreshBossActionBar())
        native(smart and press() or body,lookup,false)
        if actual[a] then break end
    end
    assert(units.target==a and pings[2]==a and actual[a]==7 and actual[toof]==8)
    UnitName,UnitGUID=oldName,oldGUID
end
print("PASS solo living Toof is reacquired after repeated misses on both macro paths, then a newly available Ashka gets X")
