local _,AT=...
local base="Interface\\Icons\\"
local art={
    vendor="INV_Misc_Bag_10", reagent="INV_Misc_Dust_02", repair="Trade_BlackSmithing",
    ammo="INV_Ammo_Bullet_01", arrows="INV_Ammo_Arrow_02", weapon="INV_Sword_04",
    class="INV_Misc_Book_11", profession="INV_Misc_Gear_01",
    warrior="Ability_Warrior_BattleShout", paladin="Spell_Holy_HolyBolt",
    hunter="Ability_Hunter_AimedShot", rogue="Ability_Rogue_SliceDice",
    priest="Spell_Holy_PowerWordShield", shaman="Spell_Nature_BloodLust",
    mage="Spell_Frost_FrostBolt02", warlock="Spell_Shadow_DeathCoil",
    druid="Spell_Nature_Regeneration", ["death knight"]="Spell_Deathknight_ClassIcon",
    monk="ClassIcon_Monk", ["demon hunter"]="ClassIcon_DemonHunter", evoker="ClassIcon_Evoker",
    alchemy="Trade_Alchemy", blacksmithing="Trade_BlackSmithing", cooking="INV_Misc_Food_15",
    enchanting="Trade_Engraving", engineering="Trade_Engineering", ["first aid"]="Spell_Holy_SealOfSacrifice",
    fishing="Trade_Fishing", herbalism="Trade_Herbalism", leatherworking="Trade_LeatherWorking",
    mining="Trade_Mining", skinning="INV_Misc_Pelt_Wolf_01", tailoring="Trade_Tailoring",
    jewelcrafting="INV_Misc_Gem_01", inscription="INV_Inscription_Tradeskill01",
}
local classes={"death knight","demon hunter","warrior","paladin","hunter","rogue","priest","shaman","mage","warlock","druid","monk","evoker"}
local professions={"first aid","alchemy","blacksmithing","cooking","enchanting","engineering","fishing","herbalism","leatherworking","mining","skinning","tailoring","jewelcrafting","inscription"}
local function plain(v)
    return not issecretvalue or not issecretvalue(v)
end
local function safe(fn,...)
    if type(fn)~="function" then return end
    local ok,v=pcall(fn,...)
    if ok and plain(v) then return v end
end
local function field(v,k)
    if plain(v) and type(v)=="table" then local x=v[k]; if plain(x) then return x end end
end
local function clean(s)
    if not plain(s) or type(s)~="string" or #s>160 then return "" end
    return (s:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("^%s*<?%s*",""):gsub("%s*>?%s*$",""):lower())
end
local function word(s,key)
    return s:find("%f[%a]"..key.."%f[%A]")~=nil
end
local services
local function serviceNames()
    if services then return services end
    services={}
    local kinds={[3]="repair",[4]="class",[5]="profession",[6]="vendor",[11]="weapon"}
    for _,rows in pairs(AT.LevelGuideNPCServices or {}) do
        for _,r in ipairs(rows) do
            local kind,name=kinds[r[1]],clean(r[5])
            if kind and name~="" then
                services[name]=services[name] or {}
                services[name][kind]=true
            end
        end
    end
    return services
end
local function classify(title,name,known)
    local roles={}
    local function has(w)return word(title,w)end
    local function context(w)return has(w) or word(name,w)end
    local knownClass=known and known.class
    local knownProf=known and known.profession
    local weapon=has("weapon trainer") or has("weapon master") or known and known.weapon
    if weapon then roles[#roles+1]="weapon" end
    local trainer=has("trainer") or has("master")
    if trainer or knownClass or knownProf then
        local typed
        if not knownProf or knownClass then
            for _,k in ipairs(classes) do
                if context(k) then roles[#roles+1]=k;typed=true;break end
            end
        end
        if not typed and (not knownClass or knownProf) then
            for _,k in ipairs(professions) do
                if context(k) then roles[#roles+1]=k;typed=true;break end
            end
        end
        if not typed and not weapon then
            if knownProf or has("profession trainer") then roles[#roles+1]="profession"
            elseif knownClass or has("class trainer") then roles[#roles+1]="class"
            elseif has("trainer") then roles[#roles+1]="profession" end
        end
    end
    local reagent=context("reagent") or context("reagents")
    local bullets=context("ammunition") or context("ammo") or context("gunsmith") or context("gun merchant")
    local arrows=context("bowyer") or context("fletcher") or context("arrows") or context("quivers")
    local repair=context("repair") or context("repairs") or known and known.repair
    local vendor=has("vendor") or has("merchant") or has("supplies") or has("goods") or has("provisions")
        or has("quartermaster") or has("dealer") or known and known.vendor
    if reagent then roles[#roles+1]="reagent"
    elseif arrows then roles[#roles+1]="arrows"
    elseif bullets then roles[#roles+1]="ammo"
    elseif vendor and not repair then roles[#roles+1]="vendor" end
    if repair then roles[#roles+1]="repair" end
    return roles
end
local function active()
    return AT.db and AT.db.enabled~=false and AT.db.vendorIcons~=false
end
local overlays,epochs={},{}
local eventFrame
local function clear(token)
    epochs[token]=(epochs[token] or 0)+1
    local old=overlays[token]
    if old then old.frame:Hide();overlays[token]=nil end
end
local function tokenOK(token)
    return plain(token) and type(token)=="string" and token:match("^nameplate%d+$")~=nil
end
local function isNPC(token)
    if safe(UnitExists,token)~=true or safe(UnitIsPlayer,token)~=false
        or safe(UnitIsDeadOrGhost,token)~=false or safe(UnitCanAttack,"player",token)~=false then return false end
    local g=safe(UnitGUID,token)
    if type(g)=="string" then return g:match("^Creature%-") or g:match("^Vehicle%-") end
    -- The tooltip can still expose a role when identity is protected. Do not infer one from other units.
    local reaction=safe(UnitReaction,token,"player")
    return safe(UnitPlayerControlled,token)==false and type(reaction)=="number" and reaction>=4
end
local function labelRole(token)
    local info=safe(C_TooltipInfo and C_TooltipInfo.GetUnit,token)
    local lines=field(info,"lines")
    local first=field(field(lines,1),"leftText")
    local second=field(field(lines,2),"leftText")
    local name=clean(safe(UnitName,token))
    if name=="" then name=clean(first) end
    local localizedName=name~="" and serviceNames()[name]
    local subtitle=clean(second)
    if subtitle==name or subtitle:find("^level%s") then subtitle="" end
    return classify(subtitle,name,localizedName),type(lines)=="table" and subtitle~=""
end
local plateCache=setmetatable({},{__mode="k"})
local function frameFor(plate)
    local existing=plateCache[plate]
    if existing then return existing end
    local f=CreateFrame("Frame",nil,plate)
    f:SetPoint("BOTTOM",plate,"TOP",0,7)
    f:EnableMouse(false)
    f:SetFrameLevel(plate:GetFrameLevel()+6)
    f:Hide()
    local icons={}
    for i=1,3 do
        local border=f:CreateTexture(nil,"BACKGROUND")
        border:SetColorTexture(.12,.075,.02,.94)
        border:SetSize(46,46); border:SetPoint("LEFT",f,"LEFT",(i-1)*49,0)
        local icon=f:CreateTexture(nil,"ARTWORK")
        icon:SetSize(42,42);icon:SetPoint("CENTER",border)
        icon:SetTexCoord(.07,.93,.07,.93)
        icons[i]={border=border,icon=icon}
    end
    local item={frame=f,icons=icons}
    plateCache[plate]=item
    return item
end
local function update(token)
    if not active() or not tokenOK(token) or not isNPC(token) then return false end
    local plate=safe(C_NamePlate and C_NamePlate.GetNamePlateForUnit,token)
    if not plate or safe(plate.IsForbidden,plate)~=false then return false end
    local roles,evidence=labelRole(token)
    if #roles==0 then return evidence end
    local entry=frameFor(plate)
    local n=math.min(3,#roles)
    entry.frame:SetSize(46+(n-1)*49,46)
    for i,c in ipairs(entry.icons) do
        if i<=n then c.icon:SetTexture(base..art[roles[i]]);c.icon:Show();c.border:Show()
        else c.icon:Hide();c.border:Hide() end
    end
    overlays[token]=entry
    entry.frame:Show()
    return true
end
local function added(token)
    if not tokenOK(token) then return end
    clear(token)
    if not active() then return end
    local generation=epochs[token]
    if update(token) then return end
    if C_Timer and C_Timer.After then
        C_Timer.After(.35,function()
            if epochs[token]==generation and active() then update(token) end
        end)
    end
end
function AT.RefreshVendorIcons()
    for token in pairs(epochs) do clear(token) end
    if not active() or not C_NamePlate then return end
    for _,plate in ipairs(safe(C_NamePlate.GetNamePlates) or {}) do
        local token=plate.namePlateUnitToken
        if not tokenOK(token) then token=plate.unitToken end
        if not tokenOK(token) and plain(plate.UnitFrame) and plate.UnitFrame then token=plate.UnitFrame.unit end
        if tokenOK(token) then added(token) end
    end
end
function AT.InitVendorIcons()
    if eventFrame or not C_NamePlate or not CreateFrame then return end
    eventFrame=CreateFrame("Frame")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent",function(_,event,token)
        if event=="NAME_PLATE_UNIT_ADDED" then added(token)
        elseif event=="NAME_PLATE_UNIT_REMOVED" and tokenOK(token) then clear(token)
        elseif event=="PLAYER_ENTERING_WORLD" then AT.RefreshVendorIcons() end
    end)
    AT.RefreshVendorIcons()
end
