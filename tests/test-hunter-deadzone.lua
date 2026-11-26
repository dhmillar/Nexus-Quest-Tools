local class, combat, enemy, targetDead, playerDead, playerTarget = "MAGE", false, true, false, false, false
local exists, raptor, clip, autoShot, arcaneShot = true, true, nil, false, nil
local plate, frames, legacy, secrets = nil, {}, false, {}
issecretvalue = function(v) return v == secrets end
UIParent = {GetWidth=function() return 1600 end, GetHeight=function() return 900 end, GetEffectiveScale=function() return .8 end}
local api={}
function api:SetScript(k,v) self[k]=v end
function api:RegisterEvent(k) self.events[k]=true end
function api:SetSize(w,h) assert(w==45 and h==45) end
function api:SetFrameStrata(value) self.strata=value end
function api:EnableMouse(x) self.mouse=x end
function api:SetMovable(x) assert(x) end
function api:SetClampedToScreen(x) assert(x) end
function api:RegisterForDrag(button) assert(button=="LeftButton") end
function api:StartMoving() self.moving=true end
function api:StopMovingOrSizing() self.moving=false end
function api:GetCenter() return self.x or self.point[4],self.y or (self.point[5]+22.5) end
function api:CreateTexture()
 return {SetAllPoints=function() end,SetTexture=function(_,s) assert(s:match("HunterDeadzone%.tga$")) end}
end
function api:SetPoint(...) self.point={...} end
function api:ClearAllPoints() self.point=nil end
function api:Show() self.shown=true end
function api:Hide() self.shown=false end
function CreateFrame()
 local f=setmetatable({events={}}, {__index=api})
 frames[#frames+1]=f
 return f
end
UnitClass=function() return "class", class end
UnitAffectingCombat=function() return combat end
UnitExists=function() return exists end
UnitCanAttack=function() return enemy end
UnitIsPlayer=function() return playerTarget end
UnitIsDeadOrGhost=function(u) if u=="player" then return playerDead end return targetDead end
UnitIsUnit=function(u,v) return u=="nameplate2" and v=="player" end
local names={[2973]="Raptor",[2974]="Clip",[75]="Auto",[3044]="Arcane"}
local function rangeValue(n)
 if n=="Raptor" then return raptor elseif n=="Clip" then return clip elseif n=="Auto" then return autoShot elseif n=="Arcane" then return arcaneShot end
end
C_Spell={GetSpellName=function(id) return names[id] end,IsSpellInRange=function(id,u) assert(u=="target");if not legacy then return rangeValue(names[id]) end end}
GetSpellInfo=C_Spell.GetSpellName
IsSpellInRange=function(n,u) assert(u=="target");if not legacy then return nil end
 local v=rangeValue(n);if v==true then return 1 elseif v==false then return 0 end end
C_NamePlate={GetNamePlateForUnit=function(unit) if unit=="nameplate2" then return plate end end}
local AT={db={enabled=true,hunterDeadzone=true}}
assert(loadfile("NQT/HunterDeadzone.lua"))("NQT",AT)
AT.InitHunterDeadzone();assert(#frames==0,"other classes create no watcher")
class="HUNTER";AT.InitHunterDeadzone()
local icon,watcher=frames[1],frames[2]
local function event(e,u) assert(watcher.events[e]);watcher:OnEvent(e,u) end
local function update() watcher:OnUpdate(.085) end
assert(not icon.shown and not watcher.OnUpdate)
combat=true;event("PLAYER_REGEN_DISABLED");assert(icon.shown and icon.point[3]=="BOTTOMLEFT" and icon.point[4]==800)
assert(icon.point[5]==540)
autoShot=true;update();assert(not icon.shown,"already in ranged weapon range")
autoShot=false;raptor=false;update();assert(not icon.shown,"too far for melee")
raptor=nil;clip=true;update();assert(icon.shown,"Wing Clip fallback")
autoShot=nil;arcaneShot=true;update();assert(not icon.shown,"Arcane Shot fallback")
arcaneShot=nil;update();assert(not icon.shown,"unknown ranged range is not treated as blocked")
autoShot=false;arcaneShot=nil;raptor=true;legacy=true;update();assert(icon.shown,"classic localized spell/1-0 fallback")
legacy=false;raptor=secrets;clip=nil;update();assert(not icon.shown,"unknown melee is not treated as close")
raptor=true
targetDead=true;event("PLAYER_TARGET_CHANGED");assert(not icon.shown)
targetDead=false;exists=false;update();assert(not icon.shown)
exists=true;enemy=false;update();assert(not icon.shown)
enemy=true;playerTarget=true;update();assert(not icon.shown)
playerTarget=false;playerDead=true;event("PLAYER_DEAD");assert(not icon.shown and not watcher.OnUpdate)
playerDead=false;event("PLAYER_ALIVE");assert(icon.shown)
plate={IsForbidden=function() return false end,IsVisible=function() return true end,GetCenter=function() return 200 end,
 GetTop=function() return 300 end,GetEffectiveScale=function() return 1.2 end}
event("NAME_PLATE_UNIT_ADDED","nameplate2")
assert(icon.shown and icon.point[3]=="BOTTOMLEFT")
assert(math.abs(icon.point[4]-300)<.01 and math.abs(icon.point[5]-455)<.01)
plate.IsForbidden=function() return true end;update();assert(icon.shown and icon.point[3]=="BOTTOMLEFT" and icon.point[4]==800)
event("NAME_PLATE_UNIT_REMOVED","nameplate2");assert(icon.shown and icon.point[3]=="BOTTOMLEFT" and icon.point[4]==800)
AT.db.hunterDeadzone=false;AT.RefreshHunterDeadzone();assert(not icon.shown and not watcher.OnUpdate)
AT.db.hunterDeadzone=true;AT.RefreshHunterDeadzone();assert(icon.shown)
AT.db.enabled=false;AT.RefreshHunterDeadzone();assert(not icon.shown and not watcher.OnUpdate)
AT.db.enabled=true;AT.RefreshHunterDeadzone();assert(icon.shown)
combat=false;event("PLAYER_REGEN_ENABLED");assert(not icon.shown and not watcher.OnUpdate)
AT.InitHunterDeadzone();assert(#frames==2)
assert(not icon.mouse)
AT.db.hunterDeadzone=false
AT.SetHunterDeadzonePreview(true)
assert(icon.shown and icon.mouse and icon.strata=="TOOLTIP" and AT.IsHunterDeadzonePreview())
icon:OnDragStart()
assert(icon.moving)
icon.x,icon.y=862,610.5
event("PLAYER_REGEN_ENABLED")
assert(icon.shown and icon.moving,"preview stays visible independently of combat")
icon:OnDragStop()
assert(not icon.moving and AT.db.hunterDeadzoneX==62 and AT.db.hunterDeadzoneY==48)
icon.x,icon.y=nil,nil
AT.SetHunterDeadzonePreview(false)
assert(not icon.shown and not icon.mouse and not AT.IsHunterDeadzonePreview())
AT.SetHunterDeadzonePreview(true)
assert(icon.point[4]==862 and icon.point[5]==588,"preview restores saved position")
AT.SetHunterDeadzonePreview(false)
AT.db.hunterDeadzone=true
combat=true;event("PLAYER_REGEN_DISABLED")
assert(icon.shown and not icon.mouse and icon.point[4]==862 and icon.point[5]==588,"combat cue uses saved offset")
AT.SetHunterDeadzonePreview(true)
icon:OnDragStart()
icon.x,icon.y=850,630.5
AT.SetHunterDeadzonePreview(false)
assert(not icon.moving and AT.db.hunterDeadzoneX==50 and AT.db.hunterDeadzoneY==68,"closing preview commits drag and releases mouse")
print("Hunter Deadzone: combat, NPC eligibility, range, 45px preview and saved drag offsets passed")
