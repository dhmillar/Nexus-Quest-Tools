local players={
    nameplate1={name="Orange Druid",class="DRUID",hp=65,friend=true,player=true},
    nameplate2={name="Enemy",class="MAGE",hp=99,attack=true,player=true},
    nameplate3={name="NPC",class="MAGE",hp=99,friend=true},
    nameplate4={name="Blocked",class="MAGE",hp=99,friend=true,player=true,blocked=true},
    nameplate5={name="Blue Mage",class="MAGE",hp=85,friend=true,player=true},
}
local secret={}
local function nilop() end
local frames,hooked={},{}
local function widget(parent)
    local w={parent=parent,alpha=1,shown=true, SetPoint=nilop,ClearAllPoints=nilop,EnableMouse=nilop,SetFrameStrata=nilop,SetFrameLevel=nilop,
        SetStatusBarTexture=nilop,SetMinMaxValues=nilop,SetJustifyH=nilop,SetColorTexture=nilop}
    function w:SetSize(x,y)self.width,self.height=x,y end
    function w:SetFont(_,n,outline)self.size,self.outline=n,outline end
    function w:SetText(text)self.text=text end
    function w:SetTextColor(r,g,b)self.color={r,g,b} end
    w.SetStatusBarColor=w.SetTextColor
    function w:SetValue(v)self.value=v end
    function w:SetScript(k,f)self[k]=f end
    function w:RegisterEvent()end
    function w:SetShown(v)self.shown=v end
    function w:Show()self.shown=true end
    function w:Hide()self.shown=false end
    function w:GetAlpha()return self.alpha end
    function w:IsForbidden()return false end
    function w:SetAlpha(a)self.alpha=a;if hooked[self] then hooked[self](self,a) end end
    function w:CreateTexture()return widget(self) end
    function w:CreateFontString()return widget(self) end
    return w
end
function hooksecurefunc(f,name,cb)assert(name=="SetAlpha");hooked[f]=cb end
function CreateFrame(_,_,parent) local f=widget(parent);frames[#frames+1]=f;return f end
UIParent={}
local plates={}
for u,p in pairs(players) do
    local frame=widget();frame.unitToken=u;frame.UnitFrame=widget(frame);frame.unitFramePlater=widget(frame);frame.ActorNameSpecial=widget(frame)
    function frame:IsForbidden()return p.blocked==true end
    function frame:IsVisible()return self.shown end
    plates[u]=frame
end
C_NamePlate={GetNamePlates=function()local p={};for _,f in pairs(plates) do p[#p+1]=f end;return p end, GetNamePlateForUnit=function(u)return plates[u]end}
local indoors,combat=false,false
function IsInInstance()return indoors end
function InCombatLockdown()return combat end
local live="0"
local writes=0
C_CVar={GetCVar=function(k)assert(k=="nameplateShowFriends");return live end,SetCVar=function(_,v)live=v;writes=writes+1 end}
function issecretvalue(v)return v==secret end
function UnitExists(u)return players[u]~=nil end
function UnitIsPlayer(u)return players[u].player==true end
function UnitIsFriend(_,u)return players[u].friend==true end
function UnitCanAttack(_,u)return players[u].attack==true end
function UnitIsUnit()return false end
function UnitClass(u)return "Class",players[u].class end
function UnitName(u)return players[u].name end
function UnitHealth(u)return players[u].hp end
function UnitHealthMax()return 100 end
RAID_CLASS_COLORS={DRUID={r=1,g=.49,b=.04},MAGE={r=.25,g=.78,b=.92}}
local AT={db={}}
assert(loadfile("NQT/FriendlyDisplay.lua"))("NQT",AT)
AT.InitFriendlyDisplay()
assert(#frames==1 and live=="0" and not AT.db.friendlyDisplayLease)
local event=frames[1]
AT.db.friendlyNames=true;AT.db.friendlyNameSize=21
AT.RefreshFriendlyDisplay()
assert(live=="1" and writes==1)
local function find(text)for _,f in ipairs(frames) do if f.name and f.name.text==text then return f end end end
local orange,blue=find("Orange Druid"),find("Blue Mage")
assert(orange.name.shown and orange.name.size==21 and orange.name.outline=="OUTLINE")
assert(orange.name.color[1]==1 and not orange.bar.shown and blue.name.color[3]==.92)
assert(not find("Enemy") and not find("NPC") and not find("Blocked"))
assert(plates.nameplate1.UnitFrame.alpha==0 and plates.nameplate1.unitFramePlater.alpha==0 and plates.nameplate1.ActorNameSpecial.alpha==0)
assert(plates.nameplate2.UnitFrame.alpha==1 and plates.nameplate3.UnitFrame.alpha==1 and plates.nameplate4.UnitFrame.alpha==1)
plates.nameplate1.unitFramePlater:SetAlpha(.8);assert(plates.nameplate1.unitFramePlater.alpha==0)
AT.db.friendlyBars=true;AT.db.friendlyBarScale=125;AT.RefreshFriendlyDisplay()
assert(orange.bar.shown and orange.bar.width==80 and orange.bar.value==.65 and orange.bar.color[2]==.49)
players.nameplate1.hp=42;event:OnEvent("UNIT_HEALTH","nameplate1")
assert(orange.bar.value==.42)
AT.db.friendlyNames=false;AT.RefreshFriendlyDisplay()
assert(not orange.name.shown and orange.bar.shown)
players.nameplate1.hp=secret;event:OnEvent("UNIT_HEALTH","nameplate1")
assert(not orange.shown and plates.nameplate1.unitFramePlater.alpha==.8)
players.nameplate1.hp=42;event:OnEvent("NAME_PLATE_UNIT_ADDED","nameplate1")
assert(orange.shown)
plates.nameplate1.shown=false
event:OnEvent("NAME_PLATE_UNIT_REMOVED","nameplate1")
assert(not orange.shown and plates.nameplate1.UnitFrame.alpha==1)
indoors=true;event:OnEvent("PLAYER_ENTERING_WORLD")
assert(live=="0" and not blue.shown and plates.nameplate5.UnitFrame.alpha==1)
assert(not AT.db.friendlyDisplayLease)
indoors=false;combat=true;event:OnEvent("PLAYER_ENTERING_WORLD")
assert(live=="0")
combat=false;event:OnEvent("PLAYER_REGEN_ENABLED")
assert(live=="1" and blue.shown)
AT.db.friendlyBars=false;AT.RefreshFriendlyDisplay()
assert(live=="0" and plates.nameplate5.UnitFrame.alpha==1)
print("PASS class-colored name and health bar, sizing, native and Plater art police, restore and exclusion, opt-in CVar and protected-state guards")

