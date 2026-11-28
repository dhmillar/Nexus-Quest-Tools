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
-- Exact Forever quest/item/merchant relationships. Not a general item-vendor
-- table: a vendor who merely resells an item is not necessarily a quest source.
local questVendors={
    [116]={[1939]={465,"Barkeep Dobbins",1},[1941]={277,"Roberto Pupellyverbos",1},[1942]={274,"Barkeep Hann",1}},
    [288]={[2594]={1464,"Innkeeper Helbrek",1}},
    [619]={[4595]={2832,"Nixxrax Fillamug",0}},
    [79236]={[4600]={2832,"Nixxrax Fillamug",0}},
    [81790]={[220168]={9499,"Plugger Spazzring",0}},
    [97583]={[278265]={4612,"Boyle",2}},
    [8928]={[21939]={16015,"Vi'el",0}},
    [95988]={
        [271657]={260487,"Gritta Chumwater",0},
        [271653]={260565,"Kor'gar",0},
        [271654]={260560,"Krikshank",0},
    },
}
local observedVendors={}
local function allowedVendor(v)
    return v[3]==0 or UnitFactionGroup and UnitFactionGroup("player")== (v[3]==1 and "Alliance" or "Horde")
end
function AT.GetQuestObjectiveVendor(qid,item)
    local locale=GetLocale and GetLocale()
    if locale~="enUS" and locale~="enGB" or not pos(qid) or not pos(item) then return end
    local vendors=questVendors[qid]
    local observed=observedVendors[qid]
    local v=observed and observed[item] or vendors and vendors[item]
    if not v or not allowedVendor(v) then return end
    local npc=mob(v[1])
    return v[2],v[1],npc and npc[5]
end
-- The live merchant inventory is stronger evidence than an incomplete vendor
-- database. Intersect stock with unfinished objectives by exact item ID.
local function value(fn,...)
    if type(fn)~="function" then return end
    local ok,v=pcall(fn,...)
    if ok and (not issecretvalue or not issecretvalue(v)) then return v end
end
function AT.GetNeededQuestVendorItems(stock,npcID,npcName)
    local needed,changed={},false
    local q=C_QuestLog
    if not q or not public(stock,"table") or not next(stock) then return needed end
    local rows=value(q.GetNumQuestLogEntries)
    if not pos(rows) or rows>500 then return needed end
    local mayLearn=pos(npcID) and public(npcName,"string") and #npcName>0 and #npcName<=100
        and not npcName:find("[%c;%[%]|]")
    for index=1,rows do
        local info=value(q.GetInfo,index)
        if public(info,"table") and public(info.isHeader,"boolean") and not info.isHeader
            and pos(info.questID) and value(q.ReadyForTurnIn,info.questID)~=true then
            local qid=info.questID
            local list=value(q.GetQuestObjectives,qid)
            for _,o in ipairs(public(list,"table") and list or {}) do
                if public(o,"table") and public(o.type,"string") and o.type=="item"
                    and public(o.finished,"boolean") and not o.finished then
                    local item=public(o.itemID,"number") and o.itemID or public(o.itemId,"number") and o.itemId
                    if not pos(item) and public(o.text,"string") then
                        item=value(AT.ResolveRankQuestObjectiveItem,qid,o,o.text)
                    end
                    if pos(item) and stock[item]==true then
                        needed[item]=true
                        if mayLearn then
                            local current=observedVendors[qid]
                            if not current then current={};observedVendors[qid]=current end
                            local row=current[item]
                            if not row or row[1]~=npcID or row[2]~=npcName then
                                current[item]={npcID,npcName,0};changed=true
                            end
                        end
                    end
                end
            end
        end
    end
    return needed,changed
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
-- Only explicit interaction objectives whose subject resolves to a creature.
-- Do not use giver/turn-in names or zone text to infer an objective NPC.
local npcObjectiveOverrides={[94887]={["marshal ryan"]=257250}}
local npcObjectiveKinds={monster=true,event=true,interact=true,npc=true,talk=true,escort=true,object=true,area=true,progressbar=true}
local npcPrefixes={"find","found","locate","located","seek out","meet","speak to","speak with","talk to","talk with","report to","return to","rescue","free","escort","protect","aid","help","interact with","check on"}
local npcSuffixes={"found","located","met","spoken to","talked to","reported to","rescued","freed","escorted","protected","helped","aided","interacted with","checked on"}
function AT.GetQuestObjectiveNPC(qid,objective,label)
    local locale=GetLocale and GetLocale()
    if (locale~="enUS" and locale~="enGB") or not pos(qid) or not public(objective,"table") then return end
    local kind=objective.type
    if not public(kind,"string") or not npcObjectiveKinds[kind] then return end
    local line=cleanObjective(label)
    if not line or line=="" then return end
    line=line:gsub("[%.!]+$","")
    local subject
    for _,verb in ipairs(npcSuffixes) do
        subject=line:match("^(.+) +"..verb.."$")
        if subject then break end
    end
    if not subject then
        for _,verb in ipairs(npcPrefixes) do
            subject=line:match("^"..verb.." +(.+)$")
            if subject then break end
        end
    end
    if not subject then return end
    local explicit
    for _,field in ipairs({"npcID","creatureID","monsterID"}) do
        local v=objective[field]
        if pos(v) then explicit=v;break end
    end
    local function resolve(wanted)
        local override=npcObjectiveOverrides[qid]
        local exact=override and override[wanted]
        local id=explicit or exact or indexed(wanted)
        if exact and explicit and exact~=explicit then return end
        local row=id and mob(id)
        if row and normalize(row[1])==wanted then return row[1],id,row[5] end
    end
    local name,id,display=resolve(subject)
    if name then return name,id,display end
    for _,prep in ipairs({" within "," at "," in "," near "," to "}) do
        local bare=subject:match("^(.+)"..prep..".+$")
        if bare then
            local n,i,d=resolve(bare)
            if n then return n,i,d end
        end
    end
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
local itemNames,itemSources,itemNamesPack,itemNamesData
function AT.GetQuestDropMobNames(item)
    if not english() or not pos(item) then return end
    local pack=AT.ObservedQuestDrops
    local data=AT.QuestMobData
    if itemNamesPack~=pack or itemNamesData~=data or not itemNames then
        itemNamesPack,itemNamesData,itemNames,itemSources=pack,data,{},{}
    end
    if itemNames[item]~=nil then return itemNames[item] or nil end
    local rows=pack and pack.items and pack.items[item]
    local names,seen={},{}
    itemSources[item]=seen
    local function add(id)
        local npc=mob(id)
        local name=npc and npc[1]
        if not name then return end
        if seen[name]==nil then seen[name]=id;names[#names+1]=name
        elseif seen[name]~=id then seen[name]=false end
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
function AT.GetQuestMobDisplayID(name,exactName,qid,sourceItem)
    if not english() or (not exactName and AT.IsPartialTarget and AT.IsPartialTarget()) then return end
    local key=normalize(name)
    if not key then return end
    if pos(sourceItem) then
        AT.GetQuestDropMobNames(sourceItem)
        local source=itemSources and itemSources[sourceItem] and itemSources[sourceItem][name]
        if source==false then return end
        if source then
            local row=mob(source)
            return row and row[5],source
        end
    end
    local catalog=AT.ForeverLevelGuideQuests
    local q=pos(qid) and catalog and catalog[qid]
    local display,npc
    for _,objective in ipairs(q and q[10] or {}) do
        if objective[1]==1 then
            local row=mob(objective[2])
            if row and normalize(row[1])==key and pos(row[5]) then
                if display and display~=row[5] then return end
                display,npc=row[5],objective[2]
            end
        end
    end
    if display then return display,npc end
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
