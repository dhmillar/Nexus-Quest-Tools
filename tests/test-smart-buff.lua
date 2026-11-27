local AT={db={enabled=true},char={}}
local class="PALADIN"
local spells={[19740]="Blessing of Might",[19834]="Blessing of Might",[19742]="Blessing of Wisdom",
    [20217]="Blessing of Kings",[25898]="Greater Blessing of Kings",[1459]="Arcane Intellect",
    [23028]="Arcane Brilliance",[1126]="Mark of the Wild",[1243]="Power Word: Fortitude",
    [6673]="Battle Shout",[324]="Lightning Shield",[8075]="Strength of Earth Totem",
    [13165]="Aspect of the Hawk",[687]="Demon Skin"}
local knowns,members,auras,range={},{},{},{}
local locked=false
function IsPlayerSpell(id)return knowns[id]==true end
C_Spell={GetSpellName=function(i)return spells[i] end,IsSpellInRange=function(_,u)return range[u] end}
function GetNormalizedRealmName()return "Forever" end
function UnitClass(u) return nil,u=="player" and class or members[u] and members[u].class end
function UnitFullName(u) if u=="player" then return "Self","" end
    local m=members[u];if m then return m.name,m.realm end end
function UnitExists(u)return members[u]~=nil end
function UnitCanAssist(a,u)return members[u]~=nil end
function UnitIsConnected(u)return not (members[u] and members[u].offline) end
function UnitIsDeadOrGhost(u)return members[u] and members[u].dead or false end
local raid=false
function GetNumSubgroupMembers()return 3 end
function GetNumGroupMembers()return 3 end
function IsInRaid()return raid end
function GetRaidRosterInfo(i)return nil,nil,i==3 and 2 or 1 end
function UnitIsUnit(a,b)return raid and a=="raid1" and b=="player" end
function InCombatLockdown()return locked end
C_UnitAuras={GetAuraDataByIndex=function(u,i)
    local id=auras[u] and auras[u][i]
    if id then return {spellId=id,name=spells[id]} end
end}
local edits={}
AT.SyncSmartBuffAction=function(cmd,pickup)edits[#edits+1]={cmd,pickup};return true end
assert(loadfile("NQT/SmartBuff.lua"))("NQT",AT)
knowns={[19740]=true,[19834]=true,[19742]=true,[20217]=true}
members.party1={class="MAGE",name="Mira"}
members.party2={class="WARRIOR",name="Grom"}
members.party3={class="MAGE",name="Mira",realm="Another Realm"}
auras.player={25898}
local result=AT.GetSmartBuffPlan(class)
assert(#result==3 and result[1].id==19742 and result[2].id==19834 and result[3].id==19742)
assert(AT.SetSmartBuffAssignment("MAGE",nil,"kings"))
assert(AT.SetSmartBuffAssignment(nil,"mIrA","might"))
result=AT.GetSmartBuffPlan(class)
assert(result[1].id==19834 and result[1].unit=="party1" and result[3].id==20217,
    "character override beats class default and does not apply to a different realm")
assert(AT.SetSmartBuffAssignment(nil,"Mira-Another Realm","skip"))
assert(#AT.GetSmartBuffPlan(class)==2)
assert(AT.SetSmartBuffAssignment(nil,"Mira",nil) and not AT.GetSmartBuffAssignment(nil,"Mira"))
result=AT.GetSmartBuffPlan(class)
assert(#result==2 and result[1].id==20217)
range.party1=false;members.party2.dead=true
assert(#AT.GetSmartBuffPlan(class)==0)
range.party1=nil;members.party2.dead=nil
AT.db.smartBuffEnabled=true
assert(AT.PickupSmartBuffMacro())
assert(edits[#edits][2] and edits[#edits][1]:find("/cast [@party1,help,nodead,nocombat]",1,true))
locked=true
local previous=#edits
auras.party1={20217}
AT.RefreshSmartBuff()
assert(#edits==previous,"no macro edits while locked")
locked=false;AT.RefreshSmartBuff()
assert(edits[#edits][1]:find("@party2",1,true))
auras.party2={19740};AT.RefreshSmartBuff()
assert(edits[#edits][1]=="#showtooltip","no queued action after coverage is complete")
class="MAGE";knowns={[1459]=true};auras.player={23028};auras.party1={23028};auras.party2={}
result=AT.GetSmartBuffPlan(class)
assert(#result==2 and result[1].unit=="party2" and result[2].unit=="party3","generic spells ignore Paladin configuration")
assert(not AT.SetSmartBuffAssignment("MAGE",nil,"skip"))
class="WARRIOR";knowns={[6673]=true};raid=true
members.raid2={class="ROGUE",name="Rook"};members.raid3={class="MAGE",name="Tower"}
auras.player={6673};auras.raid2={6673}
assert(#AT.GetSmartBuffPlan(class)==0,"Battle Shout does not chase missing buffs in a different raid subgroup")
auras.raid2={};assert(AT.GetSmartBuffPlan(class)[1].unit=="player")
raid=false
members={}
for c,id in pairs({DRUID=1126,PRIEST=1243,SHAMAN=324,HUNTER=13165,WARLOCK=687}) do
    class=c;knowns={[id]=true};auras.player={}
    local plan=AT.GetSmartBuffPlan(c)
    assert(#plan==1 and plan[1].id==id,c)
    auras.player={id}
    assert(#AT.GetSmartBuffPlan(c)==0,c.." already buffed")
end
class="ROGUE"
function GetWeaponEnchantInfo()return false,0,0,0,true end
function UnitLevel()return 60 end
function GetInventoryItemID(_,slot)if slot==16 then return 4 end end
assert(AT.GetSmartBuffPlan(class)[1].name=="Apply main-hand poison")
assert(not AT.PickupSmartBuffMacro())
print("PASS Smart Buff plans for all nine classes, missing buffs, highest known rank, raid subgroup, Paladin defaults and exact named overrides, one safe cast per macro")
