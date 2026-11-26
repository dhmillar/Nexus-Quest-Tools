local name, partial, profile = "Murloc Tidehunter", false, {
    minLevel=18, maxLevel=20, classification="elite", family="Humanoid",
    drops={"Murloc Fin",{name="Fish Scale"},"Murloc Fin","|Hitem:1|h[Raw]|h"},
}
local macro = 121
local slotKind = "macro"
local queried = 0
local secret = {}
issecretvalue = function(v) return v == secret end
local AT = {
    GetTargetName=function() return name end,
    IsPartialTarget=function() return partial end,
    IsOwnTargetMacro=function(i) return i == 121 end,
    GetQuestMobProfile=function(n) assert(n==name); queried=queried+1; return profile end,
}
GetActionInfo = function(i) assert(i==7); return slotKind,macro end
local hook, installs = nil, 0
local shown, shows, lines = false, 0, 0
local function clean()
    for i=1,lines do _G["GameTooltipTextLeft"..i]=nil end
    lines=0
end
GameTooltip = {
    GetName=function() return "GameTooltip" end,
    NumLines=function() return lines end,
    AddLine=function(_, label)
        lines=lines+1
        _G["GameTooltipTextLeft"..lines]={GetText=function() return label end}
    end,
    IsShown=function() return shown end,
    Show=function() shows=shows+1 end,
}
GameTooltip.SetAction=function(self,slot)
    clean()
    self:AddLine("Stock line")
    if hook then hook(self,slot) end
end
hooksecurefunc=function(object,method,handler)
    assert(object==GameTooltip and method=="SetAction")
    installs=installs+1
    hook=handler
end
local function line(i)
    local region = _G["GameTooltipTextLeft"..i]
    return region and region:GetText()
end
local tip = GameTooltip
assert(loadfile("NQT/MacroMobTooltip.lua"))("NQT",AT)
assert(installs==1)
tip:SetAction(7)
assert(lines==5 and line(1)=="Stock line" and line(2)=="Saved target: Murloc Tidehunter")
assert(line(3)=="Observed level: 18–20  ·  Elite" and line(4)=="Family: Humanoid")
assert(line(5)=="Known drops: Murloc Fin, Fish Scale")
assert(shows==0,"posthook must not force a hidden tooltip to appear")
hook(tip,7)
assert(lines==5,"if stock refresh keeps existing lines, do not append duplicates")
shown=true
tip:SetAction(7)
assert(lines==5 and shows==1,"rebuild re-adds one set and resizes shown tooltip")

partial=true
local before=queried
tip:SetAction(7)
assert(lines==2 and line(2)=="Saved target: Murloc Tidehunter (partial match)" and queried==before)
partial=false; profile=nil
tip:SetAction(7)
assert(lines==2 and line(2)=="Saved target: Murloc Tidehunter")
name=nil; tip:SetAction(7)
assert(lines==2 and line(2)=="Saved target: Not set")
name=secret; tip:SetAction(7)
assert(lines==2 and line(2)=="Saved target: Not set")

for _,notOwned in ipairs({122,120,secret}) do
    macro=notOwned
    tip:SetAction(7)
    assert(lines==1,"only the target macro's owning ID can add details")
end
macro=121;slotKind="spell";tip:SetAction(7)
assert(lines==1)
slotKind=secret;tip:SetAction(7)
assert(lines==1)
slotKind="macro";tip:SetAction(secret)
assert(lines==1)
hook({},7)
assert(lines==1)
clean();hook(tip,7)
assert(lines==0,"never manufacture a tooltip when stock did not build one")

local callback, registration
GameTooltip=nil
CreateFrame=function(kind)
    assert(kind=="Frame")
    return {RegisterEvent=function(_,v) registration=v end,
        SetScript=function(_,key,fn) assert(key=="OnEvent");callback=fn end}
end
assert(loadfile("NQT/MacroMobTooltip.lua"))("NQT",AT)
assert(registration=="PLAYER_LOGIN" and installs==1)
GameTooltip=tip
callback({UnregisterEvent=function(_,e) assert(e=="PLAYER_LOGIN") end})
assert(installs==2,"if tooltip is loaded late, register the posthook at login")
print("PASS owned target macro tooltip: saved name, verified detail, partial and missing data, stock isolation, rebuilds, late loading")
