local _,AT=...
local function public(value,kind)
    return (not issecretvalue or not issecretvalue(value)) and type(value)==kind
end
local function pos(value)
    return public(value,"number") and value>0 and value%1==0
end
local function english()
    return GetLocale and GetLocale()=="enUS"
end
local function normalize(name)
    if not public(name,"string") then return end
    return (name:match("^%s*(.-)%s*$"):gsub("%s+"," "):lower())
end
local function cleanObjective(label)
    if not public(label,"string") then return end
    label=label:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
    label=label:gsub("^%s*%d+%s*/%s*%d+[%s:]+",""):gsub("[%s:(]*%d+%s*/%s*%d+%)?%s*$","")
    return normalize(label)
end
-- Corroborated exact NPC/item sources; a source name does not imply a rate.
local exactDropSources={[266148]=256952,[266252]=259258}
local function mob(id)
    local data=AT.QuestMobData
    return data and data.creatures[id]
end
local function killSubject(label)
    for _,verb in ipairs({"kill","slay","defeat","destroy"}) do
        local raw=label:match("^"..verb.." +(.+)$")
        if raw then return (raw:gsub("^%d+ +","")) end
    end
    for _,verb in ipairs({"slain","killed","defeated","destroyed"}) do
        local raw=label:match("^(.+) +"..verb.."[%.!]?$")
        if raw then return raw end
    end
end
local function matches(name,wanted)
    local n=normalize(name)
    if n==wanted then return true end
    if not n then return false end
    if n.."s"==wanted or n.."es"==wanted then return true end
    return n:gsub("([^aeiou])y$","%1ies")==wanted
end
local nameIndex, namesByKey, displaysByKey
local function indexed(wanted)
    if not nameIndex then
        nameIndex,namesByKey,displaysByKey={},{},{}
        for id,row in pairs(AT.QuestMobData and AT.QuestMobData.creatures or {}) do
            local name=normalize(row[1])
            if name then
                nameIndex[name]=nameIndex[name]==nil and id or false
                if namesByKey[name]==nil then namesByKey[name]=row[1]
                elseif namesByKey[name]~=row[1] then namesByKey[name]=false end
                local display=pos(row[5]) and row[5] or false
                if displaysByKey[name]==nil then displaysByKey[name]=display
                elseif displaysByKey[name]~=display then displaysByKey[name]=false end
            end
        end
    end
    return nameIndex[wanted] or nil
end
function AT.GetQuestKillMobName(qid,objective,label)
    if not english() or not pos(qid) or not public(objective,"table") then return end
    local kind=objective.type
    if not public(kind,"string") or (kind~="monster" and kind~="kill") then return end
    local line=cleanObjective(label)
    if not line or line=="" then return end
    local data=AT.QuestMobData
    local exact=data and data.killLabels[qid] and data.killLabels[qid][line]
    if exact then local e=mob(exact);return e and e[1] end
    local subject=killSubject(line) or (kind=="kill" and line)
    if not subject then return end
    local live
    for _,key in ipairs({"npcID","creatureID","monsterID"}) do
        local candidate=objective[key]
        if pos(candidate) then live=candidate;break end
    end
    if live then
        local e=mob(live)
        if e and matches(e[1],subject) then return e[1] end
        return
    end
    local names=data and data.questMobs[qid]
    local found
    for _,id in ipairs(names or {}) do
        local e=mob(id)
        if e and matches(e[1],subject) then
            if found and found~=e[1] then return end
            found=e[1]
        end
    end
    if found then return found end
    -- A live objective explicitly calling for a kill can safely use an
    -- exact unique database name. Never turn an unknown plural into a name.
    indexed(subject)
    return namesByKey[subject] or nil
end
function AT.GetKnownQuestDropItem(qid,label)
    if not pos(qid) or not public(label,"string") then return end
    local data=AT.QuestMobData
    local candidates=data and data.questItems and data.questItems[qid]
    if not candidates then return end
    local match
    for _,id in ipairs(candidates) do
        local name=C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
        if public(name,"string") and name==label then
            if match and match~=id then return end
            match=id
        end
    end
    -- Exact Forever catalog record plus observed corpse loot for this item.
    if not match and english() and qid==95789 and (label=="Voodoo-Infused Artifact" or label=="Voodoo Infused Artifact") then
        return 270333
    end
    return match
end
local itemNames,itemNamesPack,itemNamesData
function AT.GetQuestDropMobNames(item)
    if not english() or not pos(item) then return end
    local pack=AT.ObservedQuestDrops
    local data=AT.QuestMobData
    if itemNamesPack~=pack or itemNamesData~=data or not itemNames then
        itemNamesPack,itemNamesData,itemNames=pack,data,{}
    end
    if itemNames[item]~=nil then return itemNames[item] or nil end
    local rows=pack and pack.items and pack.items[item]
    local names,seen={},{}
    local function add(id)
        local npc=mob(id)
        local name=npc and npc[1]
        if name and not seen[name] then seen[name]=true;names[#names+1]=name end
    end
    for _,e in ipairs(rows or {}) do
        if e[6]==0 and pos(e[2]) then add(e[1]) end
    end
    for _,npc in ipairs(data and data.dropMobs and data.dropMobs[item] or {}) do add(npc) end
    if exactDropSources[item] then add(exactDropSources[item]) end
    table.sort(names)
    itemNames[item]=#names>0 and names or false
    return itemNames[item] or nil
end
function AT.GetQuestMobDisplayID(name,exactName)
    if not english() or (not exactName and AT.IsPartialTarget and AT.IsPartialTarget()) then return end
    local key=normalize(name)
    if not key then return end
    indexed(key)
    return displaysByKey[key] or nil
end
local dropCache,dropPack,dropKey
function AT.GetQuestMobProfile(name)
    if not english() then return end
    local key=normalize(name)
    local id=key and indexed(key)
    local e=id and mob(id)
    if not e then return end
    local pack=AT.ObservedQuestDrops
    if dropPack~=pack or dropKey~=id then
        dropPack,dropKey,dropCache=pack,id,{}
        for item,rows in pairs(pack and pack.items or {}) do
            for _,r in ipairs(rows) do
                if r[1]==id and r[6]==0 and pos(r[2]) then dropCache[#dropCache+1]=item;break end
            end
        end
        local seen={}
        for _,item in ipairs(dropCache) do seen[item]=true end
        local data=AT.QuestMobData
        for item,npcs in pairs(data and data.dropMobs or {}) do
            if not seen[item] then
                for _,npc in ipairs(npcs) do if npc==id then dropCache[#dropCache+1]=item;break end end
            end
        end
        table.sort(dropCache)
    end
    local drops={}
    for _,item in ipairs(dropCache) do
        local itemName=C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(item)
        if public(itemName,"string") and itemName~="" then drops[#drops+1]=itemName end
        if #drops==5 then break end
    end
    return {name=e[1],minLevel=pos(e[2]) and e[2] or nil,maxLevel=pos(e[3]) and e[3] or nil,
        classification=e[4]~="" and e[4] or nil,drops=#drops>0 and drops or nil}
end
