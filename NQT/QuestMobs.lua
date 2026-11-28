local _,AT=...
local function public(value,kind)
    return (not issecretvalue or not issecretvalue(value)) and type(value)==kind
end
local function pos(value)
    return public(value,"number") and value>0 and value%1==0
end
local function english()
    local locale=GetLocale and GetLocale();return locale=="enUS" or locale=="enGB"
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
    local row=data and data.creatures[id]
    if row and pos(row[5]) then return row end
    local variants=AT.NQTDB and AT.NQTDB.CreaturePortraitVariants
    local native=variants and variants[id]
    if native and pos(native[2]) and (not row or normalize(row[1])==normalize(native[1])) then
        -- An actual variant for this Forever creature, not the model of another NPC.
        return row and {row[1],row[2],row[3],row[4],native[2]} or {native[1],0,0,"",native[2]}
    end
    local classic=AT.ClassicQuestCreatureProfiles
    local ref=classic and classic[id]
    if row and ref and normalize(row[1])==normalize(ref[1]) and pos(ref[5]) then
        -- Use the exact ID's model without changing the live name or level.
        return {row[1],row[2],row[3],row[4],ref[5]}
    end
    return row or ref
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
local function vendorValue(fn,...)
    if type(fn)~="function" then return end
    local ok,v=pcall(fn,...)
    if ok and (not issecretvalue or not issecretvalue(v)) then return v end
end
local function nearbyObservedVendor(qid,item)
    local db=AT.NQTDB
    local exact=db and db.VendorObjectives and db.VendorObjectives[qid]
    local rows=exact and exact[item] and db.ObjectiveVendors and db.ObjectiveVendors[item]
    local maps=C_Map
    local faction=vendorValue(UnitFactionGroup,"player")
    local side=faction=="Alliance" and 1 or faction=="Horde" and 2
    if not rows or not maps or not side then return end
    local map=vendorValue(maps.GetBestMapForUnit,"player")
    for _=1,4 do
        if not pos(map) then return end
        local p=vendorValue(maps.GetPlayerMapPosition,map,"player")
        local x,y
        if public(p,"table") then
            if p.GetXY then
                local ok,px,py=pcall(p.GetXY,p)
                if ok and public(px,"number") and public(py,"number") and px>=0 and py>=0 and px<=1 and py<=1 then
                    x,y=px,py
                end
            elseif public(p.x,"number") and public(p.y,"number") and p.x>=0 and p.y>=0 and p.x<=1 and p.y<=1 then
                x,y=p.x,p.y
            end
        end
        local best,r2,nMatches
        for _,r in ipairs(rows) do
            if r[4]==map and (r[3]==side or r[3]==0) then
                nMatches=(nMatches or 0)+1
                if x then
                    local d=(x-r[5])^2+(y-r[6])^2
                    if not r2 or d<r2 then best,r2=r,d end
                elseif not best then best=r end
            end
        end
        if best then
            if x or nMatches==1 then return best end
            return
        end
        local info=vendorValue(maps.GetMapInfo,map)
        map=public(info,"table") and info.parentMapID
    end
end
function AT.GetQuestObjectiveVendor(qid,item)
    local locale=GetLocale and GetLocale()
    if locale~="enUS" and locale~="enGB" or not pos(qid) or not pos(item) then return end
    local vendors=questVendors[qid]
    local observed=observedVendors[qid]
    local v=observed and observed[item] or vendors and vendors[item]
    if v and not allowedVendor(v) then v=nil end
    v=v or nearbyObservedVendor(qid,item)
    if not v then return end
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
                local profile=mob(id)
                local display=profile and pos(profile[5]) and profile[5] or false
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
local npcObjectiveKinds={monster=true,event=true,interact=true,npc=true,talk=true,talkTo=true,escort=true,object=true,area=true,progressbar=true}
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
    -- The client often gives only a role or story phrase (e.g. “the
    -- Innkeeper”) rather than the creature's exact target name.
    local facts=AT.NQTDB and AT.NQTDB.ExactInteractionObjectives
    local rawID=objective.objectiveID
    if public(rawID,"nil") then rawID=objective.objectiveId end
    for _,fact in ipairs(facts and facts[qid] or {}) do
        local exact=normalize(fact[3]):gsub("[%.!]+$","")
        if exact==line then
            if not public(rawID,"nil") and (not pos(rawID) or rawID~=fact[1]) then return end
            for _,field in ipairs({"npcID","creatureID","monsterID"}) do
                local v=objective[field]
                if not public(v,"nil") and (not pos(v) or v~=fact[2]) then return end
            end
            local row=mob(fact[2])
            if row then return row[1],fact[2],row[5] end
            return
        end
    end
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
    for _,verb in ipairs(npcPrefixes) do if line:find(verb.." ",1,true)==1 then return end end
    for _,verb in ipairs(npcSuffixes) do
        if line:match(" "..verb.."[%.!]?$") then return end
    end
    local data=AT.QuestMobData
    local subject=killSubject(line) or (kind=="kill" and line)
    for _,key in ipairs({"npcID","creatureID","monsterID"}) do
        local candidate=objective[key]
        if pos(candidate) then
            local e=mob(candidate)
            if subject then
                if e and matches(e[1],subject) then return e[1],candidate end
                return
            end
            local catalog=AT.ForeverLevelGuideQuests
            local quest=catalog and catalog[qid]
            for _,o in ipairs(quest and quest[10] or {}) do
                if o[1]==1 and o[2]==candidate and e then return e[1],candidate end
            end
            break
        end
    end
    local exact=data and data.killLabels[qid] and data.killLabels[qid][line]
    if exact then local e=mob(exact);return e and e[1],exact end
    if not subject then return end
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
    -- The exported Forever objectives name the precise target IDs even if
    -- the older label index has no entry for this quest.
    local live=AT.ForeverLevelGuideQuests and AT.ForeverLevelGuideQuests[qid]
    local checked={}
    local named,resolved
    for _,o in ipairs(live and live[10] or {}) do
        local npc=o[2]
        if o[1]==1 and pos(npc) and not checked[npc] then
            checked[npc]=true
            local e=mob(npc)
            if e and matches(e[1],subject) then
                if resolved and resolved~=npc then return end
                named,resolved=e[1],npc
            end
        end
    end
    if named then return named,resolved end
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
-- Object loot cannot be macro-targeted like an NPC. Only use an exact,
-- qualified current objective item and a single observed named object.
function AT.GetQuestLootObjectName(qid,item)
    if not english() or not pos(qid) or not pos(item) then return end
    local catalog=AT.NQTDB and AT.NQTDB.NamedObjectPickups
    local objectives=catalog and catalog[qid]
    local rows=objectives and objectives[item]
    local first=rows and rows[1]
    if not first then
        local witnesses=AT.NQTDB and AT.NQTDB.WitnessedObjectPickups
        local q=witnesses and witnesses[qid]
        local exact=q and q[item]
        if exact then return exact[2],pos(exact[1]) and exact[1] or nil end
        return
    end
    -- Multiple spawn templates can share one label. Report the label without
    -- implying a unique object ID, or suppress if the names differ.
    for i=2,#rows do if rows[i][2]~=first[2] then return end end
    return first[2],#rows==1 and first[1] or nil
end
local itemNames,itemSources,itemNamesPack,itemNamesData
function AT.GetQuestDropMobNames(item,qid)
    if not english() or not pos(item) then return end
    local pack=AT.ObservedQuestDrops
    local data=AT.QuestMobData
    if itemNamesPack~=pack or itemNamesData~=data or not itemNames then
        itemNamesPack,itemNamesData,itemNames,itemSources=pack,data,{},{}
    end
    local byQuest=pos(qid) and AT.ObservedQuestCorpseSources and AT.ObservedQuestCorpseSources[qid]
    local direct=byQuest and byQuest[item]
    local inferred=pos(qid) and AT.ClassicQuestCollectNPCs and AT.ClassicQuestCollectNPCs[qid]
    local classic=inferred and inferred[item]
    local key=(direct or classic) and qid..":"..item or item
    if itemNames[key]~=nil then return itemNames[key] or nil end
    local rows=pack and pack.items and pack.items[item]
    local names,seen={},{}
    itemSources[key]=seen
    local function add(id)
        local npc=mob(id)
        local name=npc and npc[1]
        if not name then return end
        if seen[name]==nil then seen[name]=id;names[#names+1]=name
        elseif seen[name]~=id then seen[name]=false end
    end
    for _,npc in ipairs(direct or {}) do add(npc) end
    if #names==0 then
        for _,e in ipairs(rows or {}) do
            if e[6]==0 and pos(e[2]) then add(e[1]) end
        end
        for _,npc in ipairs(data and data.dropMobs and data.dropMobs[item] or {}) do add(npc) end
        if exactDropSources[item] then add(exactDropSources[item]) end
    end
    if #names==0 then for _,npc in ipairs(classic or {}) do add(npc) end end
    table.sort(names)
    itemNames[key]=#names>0 and names or false
    return itemNames[key] or nil
end
function AT.GetQuestMobDisplayID(name,exactName,qid,sourceItem,explicitNPC)
    if not english() or (not exactName and AT.IsPartialTarget and AT.IsPartialTarget()) then return end
    local key=normalize(name)
    if not key then return end
    if pos(explicitNPC) then
        local e=mob(explicitNPC)
        if e and normalize(e[1])==key then return e[5],explicitNPC end
        return
    end
    if pos(sourceItem) then
        AT.GetQuestDropMobNames(sourceItem,qid)
        local indexed=itemSources and ((pos(qid) and itemSources[qid..":"..sourceItem]) or itemSources[sourceItem])
        local source=indexed and indexed[name]
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
