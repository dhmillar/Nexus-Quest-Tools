local _,AT=...
-- Explorer's field guide for the Forever client. No quest selection, acceptance,
-- map change, or quest tracking state is mutated unless the user clicks View Map.
local Q,M=C_QuestLog,C_Map
local min,max,floor,ceil,abs,sqrt=math.min,math.max,math.floor,math.ceil,math.abs,math.sqrt
local function plain(v) return not issecretvalue or not issecretvalue(v) end
local function safe(f,...)
    if type(f)~="function" then return end
    local ok,a,b,c=pcall(f,...)
    if ok then
        if not plain(a) then a=nil end
        if not plain(b) then b=nil end
        if not plain(c) then c=nil end
        return a,b,c
    end
end
local function field(t,k)
    if type(t)=="table" and plain(t) then local v=t[k];if plain(v) then return v end end
end
local function number(n) return plain(n) and type(n)=="number" and n==n and n>=0 and n<100000000 end
local function positive(n) return number(n) and n>0 end
local function lower(s) return (strlower or string.lower)(s) end
local function key(s) return lower(s):gsub("’","'"):gsub("^the%s+",""):gsub("%s+$","") end
local function validName(s) return plain(s) and type(s)=="string" and #s>0 end
-- AreaTable ID, UI map ID, guide band, English fallback. The bands are
-- planning ranges, not access restrictions.
local classicZones={
 {14,1411,1,10,"Durotar"},{215,1412,1,10,"Mulgore"},{17,1413,10,25,"The Barrens"},
 {141,1438,1,10,"Teldrassil"},{148,1439,10,20,"Darkshore"},{331,1440,18,30,"Ashenvale"},
 {400,1441,25,35,"Thousand Needles"},{406,1442,15,27,"Stonetalon Mountains"},
 {405,1443,29,40,"Desolace"},{357,1444,40,50,"Feralas"},{15,1445,35,45,"Dustwallow Marsh"},
 {440,1446,40,50,"Tanaris"},{16,1447,45,55,"Azshara"},{361,1448,48,55,"Felwood"},
 {490,1449,48,55,"Un'Goro Crater"},{493,1450,50,60,"Moonglade"},
 {1377,1451,55,60,"Silithus"},{618,1452,55,60,"Winterspring"},
 {1,1426,1,10,"Dun Morogh"},{12,1429,1,10,"Elwynn Forest"},{38,1432,10,20,"Loch Modan"},
 {40,1436,10,20,"Westfall"},{44,1433,15,25,"Redridge Mountains"},{10,1431,18,30,"Duskwood"},
 {11,1437,20,30,"Wetlands"},{85,1420,1,10,"Tirisfal Glades"},
 {130,1421,10,20,"Silverpine Forest"},{267,1424,20,32,"Hillsbrad Foothills"},
 {36,1416,30,40,"Alterac Mountains"},{45,1417,30,40,"Arathi Highlands"},
 {47,1425,40,50,"The Hinterlands"},{33,1434,30,45,"Stranglethorn Vale"},
 {8,1435,35,45,"Swamp of Sorrows"},{3,1418,35,45,"Badlands"},
 {51,1427,43,53,"Searing Gorge"},{46,1428,50,58,"Burning Steppes"},
 {4,1419,45,55,"Blasted Lands"},{28,1422,50,58,"Western Plaguelands"},
 {139,1423,53,60,"Eastern Plaguelands"},{41,1430,55,60,"Deadwind Pass"},
 {1519,1453,1,60,"Stormwind City"},{1537,1455,1,60,"Ironforge"},{1657,1457,1,60,"Darnassus"},
 {1637,1454,1,60,"Orgrimmar"},{1638,1456,1,60,"Thunder Bluff"},{1497,1458,1,60,"Undercity"},
}
-- Legacy instance guide bands and AreaTable categories, followed by the nine
-- Forever launch ranges published by Blizzard (news.blizzard.com/article/24301455).
local instanceDefs={
 {2437,13,18,"Ragefire Chasm",1454},{1581,17,26,"Deadmines",1436},
 {718,17,25,"Wailing Caverns",1413},{209,22,30,"Shadowfang Keep",1421},
 {717,22,30,"Stockade",1453},{719,24,32,"Blackfathom Deeps",1439},
 {721,29,38,"Gnomeregan",1426},{491,30,40,"Razorfen Kraul",1413},
 {796,28,45,"Scarlet Monastery",1420},{722,37,46,"Razorfen Downs",1413},
 {1337,40,50,"Uldaman",1418},{1176,44,54,"Zul'Farrak",1446},
 {2100,45,55,"Maraudon",1443},{1477,49,58,"Sunken Temple",1435},
 {1584,52,60,"Blackrock Depths",1428},{1583,55,60,"Blackrock Spire",1428},
 {2557,55,60,"Dire Maul",1444},{2017,58,60,"Stratholme",1423},{2057,58,60,"Scholomance",1422},
 {0,13,18,"Hall of Thanes",1426,"Easier to reach from Alliance territory."},
 {0,15,20,"Ruins of Lordaeron",1420,"Easier to reach from Horde territory."},
 {0,24,29,"Excavation Site: Wetlands",1437},
 {0,28,33,"City of Dalaran",1416,"Attunement required. Start in Southshore (Alliance) or Tarren Mill (Horde)."},
 {0,35,40,"The Drowned City",1434,"Underwater entrance west of Grom'gol."},
 {0,40,45,"Krol'dok Stronghold",0,"Entrance in Riverglades."},
 {0,48,53,"Alcaz Prison",1445,"On Alcaz Island."},
 {0,55,60,"Blackmaw Hold",1447},
 {0,58,60,"Shaper's Terrace",1449},
}
local byAlias={["the stockade"]="stockade",["the deadmines"]="deadmines",
    ["the temple of atal'hakkar"]="sunken temple",["temple of atal'hakkar"]="sunken temple",
    ["lower blackrock spire"]="blackrock spire",["upper blackrock spire"]="blackrock spire",
    ["excavation site"]="excavation site: wetlands"}
local function dungeonKey(s) return byAlias[lower(s)] or key(s) end
local function mapInfo(map) return positive(map) and safe(M and M.GetMapInfo,map) end
local function outdoor(map)
    for _=1,10 do
        if not positive(map) then return end
        local i=mapInfo(map);local kind=field(i,"mapType")
        if kind==3 then return map,field(i,"name") end
        if kind==4 then return end
        local parent=field(i,"parentMapID")
        if parent==map then return end
        map=parent
    end
end
local function canUseRace(mask,race)
    if not positive(race) or race>64 or type(mask)~="string" or mask=="" then return true end
    if not mask:find("[^0]") then return true end
    local nibble=floor((race-1)/4)
    if #mask<=nibble then return false end
    local bit=(race-1)%4
    local d=tonumber(mask:sub(#mask-nibble,#mask-nibble),16)
    return d~=nil and floor(d/2^bit)%2==1
end
local function maskHas(mask,id)
    local usable=plain(mask) and type(mask)=="number" and mask>0 and mask<2^53
    return not usable or not positive(id) or id>53 or floor(mask/2^(id-1))%2==1
end
local function probability(q,item,size)
    local sample=AT.ForeverQuestDropSamples and AT.ForeverQuestDropSamples[q]
    local best,mob
    for _,r in ipairs(sample and sample[item] or {}) do
        if positive(r[2]) then
            local p=min(1,r[2]/10000)
            if not best or p>best then best,mob=p,r[1] end
        end
    end
    if best then return best,mob end
    local pack=AT.ObservedQuestDrops
    for _,r in ipairs(pack and pack.items and pack.items[item] or {}) do
        -- An individually inspected creature kill, not a grouped loot window.
        if r[6]==0 and positive(r[2]) and positive(r[3]) and r[3]>=5 and r[2]<=r[3] then
            local p=r[2]/r[3]
            if not best or p>best then best,mob=p,r[1] end
        end
    end
    return best,mob
end
local areaLabels={}
local function optionalDatabase()
    local lib=_G.LibQuestieDB
    local flavor=field(field(lib,"flavor"),"key")
    if flavor=="Forever" or flavor=="WoWForever" then return field(lib,"Quest") end
end
local function questField(db,q,k) return safe(db and db.Get,q,k) end
local function objectiveType(ty,line)
    if ty=="item" then return 2 end
    if ty=="monster" or ty=="killcredit" then
        if validName(line) then
            local l=lower(line)
            if l:match("^rescue%s") or l:match("^speak%s") or l:match("^free%s") or l:match("^interact%s")
                or l:match("^escort%s") or l:match("^use%s") or l:match("^capture%s") or l:match("^report%s")
                or l:match("%srescued[%s:]") or l:match("%sfreed[%s:]") or l:match("%ssubdued[%s:]")
                or l:match("%sescorted[%s:]") or l:match("%stamed[%s:]") then return 3 end
        end
        return 1
    end
    return 3
end
local function readObjectives(q,data,held,db)
    local catalog=data and data[10] or {}
    local out,seen={},{}
    local byKind={{},{},{}}
    for _,r in ipairs(catalog) do local k=r[1];if byKind[k] then byKind[k][#byKind[k]+1]=r end end
    local live=held and safe(Q and Q.GetQuestObjectives,q)
    local function add(kind,id,amount,remaining)
        out[#out+1]={kind,id,amount,remaining}
    end
    if type(live)=="table" and #live>0 then
        local ordinal={0,0,0}
        for _,o in ipairs(live) do
            local line=field(o,"text")
            local ty=field(o,"type")
            local kind=objectiveType(ty,line)
            ordinal[kind]=ordinal[kind]+1
            local backup=byKind[kind][ordinal[kind]]
            local a,b
            if validName(line) then a,b=line:match("(%d+)%s*/%s*(%d+)") end
            local amount=tonumber(b) or (backup and backup[3]) or 1
            local id=kind==2 and (field(o,"itemID") or field(o,"objectID")) or field(o,"objectID")
            if kind==2 and not positive(id) and validName(line) then
                id=safe(AT.GetKnownQuestDropItem,q,line)
            end
            if not positive(id) and backup and #byKind[kind]==1 then id=backup[2] end
            local remaining=field(o,"finished")==true and 0 or max(0,amount-(tonumber(a) or 0))
            add(kind,id or 0,amount,remaining)
        end
        return out
    end
    for _,r in ipairs(catalog) do
        add(r[1],r[2],r[3],r[3])
        seen[r[1]..":"..r[2]]=true
    end
    if #catalog==0 then
        local os=questField(db,q,"objectives")
        for _,idx in ipairs({1,2,3,5,6}) do
            local list=field(os,idx)
            local kind=idx==1 and 1 or idx==3 and 2 or 3
            if type(list)=="table" then for _,o in ipairs(list) do
                local oid,line=field(o,1),field(o,2)
                local typ=kind==1 and objectiveType("monster",line) or kind
                if positive(oid) and not seen[typ..":"..oid] then
                    seen[typ..":"..oid]=true
                    add(typ,oid,1,typ==2 and 3 or typ==1 and 5 or 1)
                end
            end end
        end
    end
    return out
end
local tierWeight={[0]=.15,.30,.48,.65,.82,1,1.12,1.25,1.40,1.55,1.7}
-- Blizzard Nov. 13/17 shared the specific quest-item drops with party members.
-- Do not infer a drop rate, or mark every item from those quests as shared.
local partyDrops={[94617]={[265738]=true},[99257]={[286647]=true}}
function AT.ScoreLevelGuideQuest(q,data,level,size,info)
    local qLevel=(positive(info.level) and info.level) or data and data[2] or level
    local kills,items,other,unknown,collectionWork=0,0,0,0,0
    local speed=({1,1.55,1.9})[size] or 1
    local personalLoot=({1,1.65,2.20})[size] or 1
    local shared=partyDrops[q]
    local killByMob,collectByMob={},{}
    local slowest,someKills,someItems
    for _,ob in ipairs(readObjectives(q,data,info.held,info.database)) do
        local kind,item,_,n=unpack(ob)
        if kind==1 then
            someKills=true;kills=kills+n
            if positive(item) then killByMob[item]=(killByMob[item] or 0)+n end
        elseif kind==2 then
            someItems=true;items=items+n
            if n>0 then
                local p,mob=probability(q,item,size)
                local perParty=shared and shared[item] and 1 or personalLoot
                if p then
                    slowest=min(slowest or 1,p)
                    local expected=n/max(.01,p)*perParty
                    if positive(mob) then collectByMob[mob]=(collectByMob[mob] or 0)+expected
                    else collectionWork=collectionWork+expected end
                else unknown=unknown+1;collectionWork=collectionWork+n*2.5*perParty end
            end
        else other=other+min(n,3) end
    end
    local category=someKills and (someItems and "mixed" or "kill") or someItems and "collect" or "other"
    local work=5+kills/speed+collectionWork/speed+other*5
    for mob,expected in pairs(collectByMob) do
        -- Share credit with a kill objective for the same verified source.
        work=work+max(0,expected-(killByMob[mob] or 0))/speed
    end
    if info.status=="Turn in" then work=2 end
    local delta=level-qLevel
    local scale=delta<=3 and 1 or max(.16,1-(delta-3)*.15)
    local apiXP=info.status~="In range" and safe(Q and Q.GetQuestRewardXP,q)
    local relative=(qLevel+7)^1.25*(data and tierWeight[data[6]] or .77)*(data and data[7] or 1)*scale
    -- The first-time quest with the same name (#1707) still gives XP.
    if q==1878 then relative,apiXP=0,nil end
    return {kind=category,work=work,potential=relative,exactXP=positive(apiXP) and apiXP or nil,
        lowRate=slowest,unknown=unknown>0,kills=kills,items=items,level=qLevel}
end
local function mapSet()
    local places,zones,categories,dungeonAreas,dungeons,dungeonMaps={},{},{},{},{},{}
    local function addMap(id,name,lo,hi)
        if zones[id] then return zones[id] end
        if not positive(id) or not validName(name) then return end
        if AT.LevelGuideZoneRanges then
            local published=AT.LevelGuideZoneRanges[id]
            lo,hi=published and published[1],published and published[2]
        end
        local p={id="zone:"..id,map=id,name=name,lo=lo,hi=hi,kind="zone",quests={},rangeKnown=positive(lo) and positive(hi)}
        zones[id]=p;places[#places+1]=p
        return p
    end
    for _,d in ipairs(classicZones) do
        local n=field(mapInfo(d[2]),"name") or d[5]
        categories[d[1]]=addMap(d[2],n,d[3],d[4])
    end
    local additionalNames={[2548]="Riverglades",[2521]="Zephras Isle"}
    for map in pairs(AT.LevelGuideZoneRanges or {}) do
        addMap(map,field(mapInfo(map),"name") or additionalNames[map])
    end
    for m in pairs(AT.ObservedQuestStarts or {}) do
        local id,n=outdoor(m)
        if id then addMap(id,n) end
    end
    local current=safe(M and M.GetBestMapForUnit,"player")
    local map,n=outdoor(current)
    if map then addMap(map,n) end
    -- Add actual continent children to browse new unobserved outdoor zones, without requesting map data.
    local areasByName={}
    for id,p in pairs(zones) do areasByName[key(p.name)]=id end
    for _,continent in ipairs({1414,1415}) do
        local list=safe(M and M.GetMapChildrenInfo,continent,3,false)
        if type(list)=="table" then
            for _,entry in ipairs(list) do
                local id,name=field(entry,"mapID"),field(entry,"name")
                if positive(id) and validName(name) then
                    local prior=areasByName[key(name)]
                    if prior and prior~=id then areasByName[key(name)]=false
                    elseif prior==nil then areasByName[key(name)]=id end
                    addMap(id,name)
                end
            end
        end
    end
    for _,v in ipairs(instanceDefs) do
        local p={id="dungeon:"..key(v[4]),name=v[4],lo=v[2],hi=v[3],
            map=positive(v[5]) and v[5] or areasByName.riverglades,kind="dungeon",note=v[6],quests={},rangeKnown=true}
        places[#places+1]=p;dungeons[key(v[4])]=p
        if positive(v[1]) then dungeonAreas[v[1]]=p end
    end
    for _,continent in ipairs({1414,1415}) do
        local list=safe(M and M.GetMapChildrenInfo,continent,4,true)
        if type(list)=="table" then
            for _,entry in ipairs(list) do
                local id,n=field(entry,"mapID"),field(entry,"name")
                local p=validName(n) and dungeons[dungeonKey(n)]
                if positive(id) and p then
                    dungeonMaps[id]=p
                    if not p.artMap or id<p.artMap then p.artMap=id end
                end
            end
        end
    end
    return places,zones,categories,dungeonAreas,dungeons,map,areasByName,dungeonMaps
end
local function validPoint(x,y)
    return number(x) and number(y) and x<=1 and y<=1 and (x>0 or y>0)
end
local function dungeonGiverFromProvider(q,side,database,categories)
    if not database then return end
    local npcs=field(_G.LibQuestieDB,"Npc")
    local starts=field(questField(database,q,"startedBy"),1)
    if type(starts)~="table" or not npcs then return end
    local zoneDB
    if Questie and Questie.IsForever and Questie.API and Questie.API.isReady and QuestieLoader then
        zoneDB=safe(QuestieLoader.ImportModule,QuestieLoader,"ZoneDB")
    end
    local found
    for _,npc in ipairs(starts) do
        if positive(npc) then
            local f=questField(npcs,npc,"friendlyToFaction")
            local name=questField(npcs,npc,"name")
            if validName(name) and (f=="AH" or f=="A" and side==1 or f=="H" and side==2) then
                local spawns=questField(npcs,npc,"spawns")
                for area,points in pairs(type(spawns)=="table" and spawns or {}) do
                    local place=categories[area]
                    local map=place and place.map or safe(zoneDB and zoneDB.GetUiMapIdByAreaId,zoneDB,area)
                    if positive(map) and mapInfo(map) and type(points)=="table" then
                        for _,xy in ipairs(points) do
                            local x,y=field(xy,1),field(xy,2)
                            if number(x) and number(y) and validPoint(x/100,y/100) then
                                x,y=x/100,y/100
                                if found and (found.npc~=npc or found.map~=map or abs(found.x-x)+abs(found.y-y)>.015) then return end
                                found=found or {map=map,x=x,y=y,name=name,npc=npc}
                            end
                        end
                    end
                end
            end
        end
    end
    return found
end
local function chooseItemStart(q,p)
    local r=AT.LevelGuideItemStarts and AT.LevelGuideItemStarts[q]
    if not r then return end
    local best,bestRank
    for _,a in ipairs(r[2]) do
        local map=a[1]
        local rank=positive(map) and ((map==p.artMap or map==p.map or positive(p.map) and outdoor(map)==p.map) and 3 or 2) or 1
        if not bestRank or rank>bestRank then best,bestRank=a,rank end
    end
    return {item=r[1],map=best and best[1],x=best and best[2],y=best and best[3],radius=best and best[4],
        sourceKind=best and best[5],source=best and best[6],sourceName=best and best[7],pickup=true}
end
local function chooseGiver(q,p,side,fallback,database,categories)
    local known
    local ambiguous=false
    local function consider(rows)
        for _,r in ipairs(rows or {}) do
            if (r[4]==0 or r[4]==side) and positive(r[1]) and validPoint(r[2],r[3]) then
                local zoneID=outdoor(r[1]) or r[1]
                local mapFit=zoneID==p.map or r[1]==p.artMap
                if not known or mapFit and not known.mapFit then
                    known={map=r[1],x=r[2],y=r[3],name=r[6],npc=r[7]~=1 and r[5] or nil,entity=r[5],mapFit=mapFit}
                    ambiguous=false
                elseif mapFit==known.mapFit and r[5]~=known.entity then
                    ambiguous=true
                end
            end
        end
    end
    consider(AT.LevelGuideQuestGivers and AT.LevelGuideQuestGivers[q])
    if not known or ambiguous then
        local prior,wasAmbiguous=known,ambiguous
        known,ambiguous=nil,false
        consider(AT.LevelGuideMoreOffers and AT.LevelGuideMoreOffers[q])
        if not known then known,ambiguous=prior,wasAmbiguous end
    end
    if known and not ambiguous then return known end
    if p.kind=="dungeon" then
        local alternate=dungeonGiverFromProvider(q,side,database,categories)
        if alternate then return alternate end
    end
    local pickup=chooseItemStart(q,p)
    if pickup then return pickup end
    -- A live offer may be available even without an NPC identity.
    if fallback and positive(fallback.map) and validPoint(fallback.x,fallback.y) then return fallback end
end
function AT.BuildLevelGuide(playerLevel,size)
    local reported=safe(UnitLevel,"player")
    local level=positive(playerLevel) and min(60,floor(playerLevel)) or positive(reported) and min(60,floor(reported)) or 1
    size=positive(size) and max(1,min(3,floor(size))) or 1
    local _,_,race=safe(UnitRace,"player")
    local _,_,class=safe(UnitClass,"player")
    local faction=safe(UnitFactionGroup,"player")
    local side=faction=="Alliance" and 1 or faction=="Horde" and 2 or -1
    local journal=field(_G.ForeverDungeonJournal_NS,"DB")
    local dungeonFaction={}
    for _,entry in pairs(type(journal)=="table" and journal or {}) do
        local quests=field(entry,"quests")
        for _,quest in ipairs(type(quests)=="table" and quests or {}) do
            local id,f=field(quest,"id"),field(quest,"faction")
            if positive(id) and (f=="Horde" or f=="Alliance" or f=="Both") then
                local old=dungeonFaction[id]
                dungeonFaction[id]=(old and old~=f) and "Both" or f
            end
        end
    end
    local data=AT.ForeverLevelGuideQuests or {}
    local places,zones,categories,dungeonAreas,dungeons,current,areaNames,dungeonMaps=mapSet()
    local completed,known,live,held,ready,candidates,nativeStarts={},{},{},{},{},{},{}
    local database=optionalDatabase()
    local all=safe(Q and Q.GetAllCompletedQuestIDs)
    if type(all)=="table" then for _,qid in ipairs(all) do if positive(qid) then completed[qid]=true end end end
    local function done(q)
        if completed[q]~=nil then return completed[q] end
        local ledger=AT.char and AT.char.levelGuideTurnIns
        local result=ledger and ledger[q]==true or safe(Q and Q.IsQuestFlaggedCompleted,q)
        if result==nil and type(all)=="table" then result=false end
        completed[q]=result
        return result
    end
    local function pin(q,p,seen)
        if not positive(q) or not p then return end
        if seen[q]==nil then seen[q]={} end
        seen[q][p.id]=p
        candidates[q]=true
    end
    local observedStarts={}
    local function pinStarts(list,p,questLines,nativeMap)
        if type(list)~="table" then return end
        for _,v in ipairs(list) do
            local q=field(v,"questID")
            local actual=field(v,"startMapID")
            if field(v,"isQuestStart")==true and field(v,"isHidden")~=true and field(v,"inProgress")~=true
                and (not questLines or not positive(actual) or actual==p.map) then
                pin(q,p,live)
                local x,y=field(v,"x"),field(v,"y")
                if positive(q) and positive(nativeMap) and validPoint(x,y) and not nativeStarts[q] then
                    nativeStarts[q]={map=nativeMap,x=x,y=y,name=field(v,"questGiverName")}
                end
            end
        end
    end
    for map,p in pairs(zones) do
        pinStarts(safe(Q and Q.GetQuestsOnMap,map),p,false,map)
        pinStarts(safe(C_QuestLine and C_QuestLine.GetAvailableQuestLines,map),p,true,map)
    end
    for map,p in pairs(dungeonMaps) do
        pinStarts(safe(Q and Q.GetQuestsOnMap,map),p,false,map)
    end
    for map,starts in pairs(AT.ObservedQuestStarts or {}) do
        local root=outdoor(map) or (zones[map] and map)
        local p=zones[root] or dungeonMaps[map]
        for _,r in ipairs(starts) do
            if (r[4]==0 or r[4]==side) and positive(r[1]) then
                pin(r[1],p,known)
                if validPoint(r[2],r[3]) then
                    local previous=observedStarts[r[1]]
                    if previous==nil then observedStarts[r[1]]={map=map,x=r[2],y=r[3]}
                    elseif previous and (previous.map~=map or abs(previous.x-r[2])+abs(previous.y-r[3])>.02) then
                        observedStarts[r[1]]=false
                    end
                end
            end
        end
    end
    local rows=safe(AT.GetLevelGuideQuestLog)
    if type(rows)=="table" then
        for q,r in pairs(rows) do
            if not r.partyOnly then
                held[q]=r;candidates[q]=true
                if r.complete==true then ready[q]=true end
            end
        end
    end
    local maxEntries=safe(Q and Q.GetNumQuestLogEntries)
    if positive(maxEntries) then
        for i=1,min(512,maxEntries) do
            local v=safe(Q.GetInfo,i);local q=field(v,"questID")
            if positive(q) and field(v,"isHidden")~=true and field(v,"isHeader")~=true then
                held[q]=held[q] or {title=field(v,"title"),level=field(v,"level")}
                candidates[q]=true
            end
        end
    end
    for q in pairs(data) do candidates[q]=true end
    local ids=safe(database and database.GetAllIds)
    if type(ids)=="table" then for _,q in ipairs(ids) do if positive(q) then candidates[q]=true end end end
    local function blocked(q)
        if safe(Q and Q.IsQuestDisabledForSession,q)==true then return true end
        if not database then return false end
        local function has(a)
            return positive(a) and done(a)==true or type(a)=="number" and a<0 and held[-a]~=nil
        end
        local before=questField(database,q,"preQuestGroup")
        for _,a in ipairs(type(before)=="table" and before or {}) do if not has(a) then return true end end
        local any=questField(database,q,"preQuestSingle")
        if type(any)=="table" and #any>0 then
            local met=false
            for _,a in ipairs(any) do if has(a) then met=true;break end end
            if not met then return true end
        end
        local started=questField(database,q,"availableStartingWith")
        if positive(started) and not (held[started] or has(started)) then return true end
        local ended=questField(database,q,"availableUntilCompleted")
        if positive(ended) and has(ended) then return true end
        local conflicts=questField(database,q,"exclusiveTo")
        for _,other in ipairs(type(conflicts)=="table" and conflicts or {}) do
            if positive(other) and (held[other] or has(other)) then return true end
        end
        local skill=questField(database,q,"requiredSkill")
        local loRep=questField(database,q,"requiredMinRep")
        local hiRep=questField(database,q,"requiredMaxRep")
        if positive(field(skill,1)) then return true end
        for i=1,2 do
            local rep=i==1 and loRep or hiRep
            local id,amount=field(rep,1),field(rep,2)
            if positive(id) and type(amount)=="number" then
                local actual=field(safe(C_Reputation and C_Reputation.GetFactionDataByID,id),"currentStanding")
                if type(actual)~="number" or (i==1 and actual<amount or i==2 and actual>amount) then return true end
            end
        end
        return false
    end
    local tags=Enum and Enum.QuestTag
    for q in pairs(candidates) do
        local d,h=data[q],held[q]
        local liveStart=live[q]
        local qLevel=h and h.level or d and d[2] or questField(database,q,"questLevel")
        if not positive(qLevel) and (h or liveStart) then
            qLevel=safe(Q and Q.GetQuestDifficultyLevel,q)
        end
        local req=questField(database,q,"requiredLevel")
        local minLevel=positive(req) and req or d and d[1] or 0
        if q==97290 and side==2 then minLevel=15 end
        local area=d and d[3]
        if not positive(area) then area=questField(database,q,"zoneOrSort") end
        local p,tag
        if d then tag=d[4] end
        local outdoors=safe(AT.IsForeverOutdoorQuest,q)==true
        local dungeon=not outdoors and safe(AT.ForeverDungeonForQuest,q)
        if validName(dungeon) then p=dungeons[dungeonKey(dungeon)] end
        if not p and positive(area) then
            p=not outdoors and dungeonAreas[area]
            if not p and categories[area]==nil then
                local n=areaLabels[area]
                if n==nil then n=safe(M and M.GetAreaInfo,area);areaLabels[area]=n or false end
                local zoneID=validName(n) and areaNames[key(n)]
                categories[area]=zones[zoneID] or false
            end
        end
        local raidOrPvP=tag==62 or tag==41 or tag==83 or tag==84 or tag==85 or tag==88 or tag==89
        if tags and (h or liveStart) and not p then
            local lt=field(safe(Q and Q.GetQuestTagInfo,q),"tagID")
            raidOrPvP=raidOrPvP or lt~=nil and (lt==tags.Raid or lt==tags.Raid10 or lt==tags.Raid25 or lt==tags.PvP)
        end
        if not raidOrPvP then
            local function choose(locations)
                if locations then
                    if area and categories[area] and locations[categories[area].id] then return categories[area] end
                    local first
                    for _,loc in pairs(locations) do
                        -- Pickup location or a generic log heading is not dungeon membership.
                        if loc.kind=="zone" and (not first or loc.id<first.id) then first=loc end
                    end
                    return first
                end
            end
            p=p or choose(liveStart) or area and categories[area] or choose(known[q]) or h and zones[h.destination]
            if p and (positive(qLevel) or h or liveStart) then
                if not p.rangeKnown and positive(qLevel) then
                    p.lo=min(p.lo or qLevel,qLevel);p.hi=max(p.hi or qLevel,qLevel)
                end
                local isDone=done(q)
                local dbRace,dbClass=questField(database,q,"requiredRaces"),questField(database,q,"requiredClasses")
                local cap=questField(database,q,"requiredMaxLevel")
                local raceOkay=(not d or canUseRace(d[5],race) and maskHas(d[8],class))
                    and maskHas(dbRace,race) and maskHas(dbClass,class)
                -- Explicit dungeon faction data and the full Forever faction masks
                -- also work when UnitRace cannot supply a usable bit index.
                local mask=d and d[5]
                if (side==1 and mask=="aa2aaaaa4e0ab3b2") or (side==2 and mask=="55155555b1354c4d") then raceOkay=false end
                local factionRule=dungeonFaction[q]
                if factionRule and factionRule~="Both" and factionRule~=faction and side>0 then raceOkay=false end
                local eligible=not (positive(cap) and level>cap) and not blocked(q)
                local dev=d and lower(d[9])
                local plausible=not dev or not (dev:match("^test quest") or dev:match("^qa[%s:_]") or dev:match("^unused[:%s]")
                    or dev:match("^deprecated[:%s]") or q<=3)
                if isDone~=true and raceOkay and (h or liveStart or eligible and plausible) then
                    local status=h and ((ready[q] or safe(Q and Q.ReadyForTurnIn,q)==true) and "Turn in" or "In log")
                        or liveStart and "Pick up" or "In range"
                    local qname=h and h.title or liveStart and safe(Q and Q.GetTitleForQuestID,q)
                    if not validName(qname) then qname=d and d[9] or questField(database,q,"name") or "Quest #"..q end
                    local score=AT.ScoreLevelGuideQuest(q,d,level,size,{held=h~=nil,status=status,level=qLevel,database=database})
                    score.id=q;score.name=qname;score.status=status;score.min=minLevel
                    score.giver=chooseGiver(q,p,side,nativeStarts[q] or observedStarts[q],database,categories)
                    if d then
                        local ids,seen={},{}
                        for _,item in ipairs(d[10] or {}) do
                            if (item[1]==1 or item[1]==2) and positive(item[2]) then
                                local part=item[1]..":"..item[2]
                                if not seen[part] then ids[#ids+1]=part;seen[part]=true end
                            end
                        end
                        if #ids>0 and q~=1878 and q~=1707 then
                            table.sort(ids)
                            score.variantKey=lower(qname):gsub("%s+"," ")..":"..table.concat(ids,",")
                        end
                    end
                    score.confirmed=h~=nil or liveStart~=nil
                    score.eligible=isDone==false or score.confirmed
                    score.verifiedLevel=positive(qLevel)
                    local trivial=level==reported and safe(Q and Q.IsQuestTrivial,q)==true
                    local xpTooLow=trivial or (score.verifiedLevel and score.level<=level-6) or q==1878
                    score.lowXP=xpTooLow
                    score.availableHere=not xpTooLow and score.eligible and (h~=nil or level>=minLevel
                        and (liveStart~=nil or minLevel>0 or score.verifiedLevel and score.level<=level))
                    score.fits=not xpTooLow and score.verifiedLevel and (h~=nil or level>=minLevel)
                        and (status=="Turn in" or score.level>=level-6 and score.level<=level+size+2)
                    if p.kind=="dungeon" then score.fits=score.availableHere and (p.inBand or level>=p.lo and level<=p.hi) end
                    score.efficiency=score.potential/sqrt(score.work)
                    p.quests[#p.quests+1]=score
                end
            end
        end
    end
    local function better(a,b)
        if a.confirmed~=b.confirmed then return a.confirmed end
        if a.fits~=b.fits then return a.fits end
        if a.efficiency~=b.efficiency then return a.efficiency>b.efficiency end
        return a.id<b.id
    end
    for _,p in ipairs(places) do
        local unique,variants={},{}
        local priority={["Turn in"]=4,["In log"]=3,["Pick up"]=2,["In range"]=1}
        for _,q in ipairs(p.quests) do
            local v=q.variantKey
            local n=v and variants[v]
            if not n then
                unique[#unique+1]=q
                if v then variants[v]=#unique end
            else
                local old=unique[n]
                local a,b=priority[q.status] or 0,priority[old.status] or 0
                local gap,oldGap=abs(level-q.level),abs(level-old.level)
                if (q.fits and not old.fits) or (q.fits==old.fits and (a>b or
                    a==b and (gap<oldGap or gap==oldGap and (q.efficiency>old.efficiency or
                    q.efficiency==old.efficiency and q.id<old.id)))) then unique[n]=q end
            end
        end
        p.quests=unique
    end
    -- Calibrate reported XP against the estimate for this character when
    -- enough rewards are present; never add a raw XP value to a relative score.
    local exactSum,relativeSum,exactCount=0,0,0
    for _,p in ipairs(places) do
        for _,q in ipairs(p.quests) do
            if q.fits and q.confirmed and q.exactXP then
                exactSum=exactSum+q.exactXP;relativeSum=relativeSum+q.potential;exactCount=exactCount+1
            end
        end
    end
    local ratio=exactCount>=3 and relativeSum>0 and exactSum/relativeSum
    for _,p in ipairs(places) do
        p.count,p.leads,p.xpPotential,p.score,p.available,p.leadScore=0,0,0,0,0,0
        p.exactXP,p.xpKnown=0,0
        p.mix={kill=0,collect=0,mixed=0,other=0,turnin=0}
        p.leadMix={kill=0,collect=0,mixed=0,other=0,turnin=0}
        if ratio then for _,q in ipairs(p.quests) do
            if q.exactXP then q.potential=q.exactXP/ratio;q.efficiency=q.potential/sqrt(q.work) end
        end end
        p.lowDrops=0
        p.here=p.map==current
        p.inBand=not p.lo or level>=p.lo and level<=p.hi
        table.sort(p.quests,better)
        for _,q in ipairs(p.quests) do
            if q.fits then
                if q.confirmed then
                    p.count=p.count+1
                    if q.status=="Pick up" then p.available=p.available+1 end
                    p.mix[q.kind]=p.mix[q.kind]+1
                    if q.status=="Turn in" then p.mix.turnin=p.mix.turnin+1 end
                    if q.lowRate and q.lowRate<=.3 then p.lowDrops=p.lowDrops+1 end
                    if q.exactXP then p.exactXP=p.exactXP+q.exactXP;p.xpKnown=p.xpKnown+1 end
                    p.xpPotential=p.xpPotential+q.potential
                    p.score=p.score+q.efficiency
                elseif q.eligible then
                    p.leads=p.leads+1
                    p.leadMix[q.kind]=p.leadMix[q.kind]+1
                    p.leadScore=p.leadScore+q.efficiency+q.potential*.10
                end
            end
        end
        -- Reward both volume and speed. Travel and the party wait are not measured.
        p.score=p.score+p.xpPotential*.10+p.leadScore*.72
        p.total=p.count+p.leads
        if p.kind=="dungeon" and not p.inBand then p.score=0 end
    end
    table.sort(places,function(a,b)
        if a.score~=b.score then return a.score>b.score end
        if a.here~=b.here then return a.here end
        if a.leadScore~=b.leadScore then return a.leadScore>b.leadScore end
        if a.leads~=b.leads then return a.leads>b.leads end
        return a.name<b.name
    end)
    return {level=level,size=size,places=places}
end


local GUIDE_MAP="Interface\\Icons\\INV_Misc_Map_01"
local GUIDE_BOOK="Interface\\Icons\\INV_Misc_Book_09"
local GUIDE_DUNGEON="Interface\\Icons\\INV_Misc_Head_Dragon_01"
local guide,refreshQueued
local trackedGiver,settingWaypoint
local palette={
    gold={.94,.76,.43},dim={.71,.66,.57},ink={.95,.91,.82},
    teal={.51,.86,.78},muted={.56,.57,.56},orange={.96,.61,.38},
    base={.053,.061,.068,.99},edge={.54,.37,.20,1},
}
local function fill(parent,layer,rgba)
    local t=parent:CreateTexture(nil,layer or "BACKGROUND")
    t:SetColorTexture(unpack(rgba))
    return t
end
local function label(parent,font,value,col)
    local t=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlight")
    t:SetJustifyH("LEFT")
    t:SetTextColor(unpack(col or palette.ink))
    t:SetText(value or "")
    return t
end
local function rect(parent,layer,p,x,y,w,h)
    local t=fill(parent,layer,p);t:SetPoint("TOPLEFT",x,y);t:SetSize(w,h);return t
end
local function button(parent,name,w,h,x,y,onclick)
    local b=CreateFrame("Button",nil,parent)
    b:SetPoint("TOPLEFT",x,y);b:SetSize(w,h);b:RegisterForClicks("LeftButtonUp")
    b.bg=fill(b,nil,{.11,.12,.13,1});b.bg:SetAllPoints()
    b.wash=fill(b,"HIGHLIGHT",{.97,.72,.35,.15});b.wash:SetAllPoints()
    b.caption=label(b,"GameFontHighlightSmall",name)
    b.caption:SetPoint("CENTER")
    b:SetScript("OnClick",onclick)
    return b
end
local function active(b,selected)
    b.bg:SetColorTexture(selected and .28 or .115,selected and .205 or .121,selected and .124 or .127,1)
    b.caption:SetTextColor(unpack(selected and palette.gold or palette.ink))
end
local function setIcon(tex,path)
    tex:SetTexture(path);tex:SetTexCoord(.075,.925,.075,.925)
end
-- Reveal entries describe larger patches split into ordinary client map tiles.
local function appendMapReveal(src, artID)
    local pieces=positive(artID) and AT.LevelGuideMapReveal and AT.LevelGuideMapReveal[artID]
    if not pieces then return end
    local function padded(n)
        local size=1
        while size<n do size=size*2 end
        return size
    end
    local keys={}
    for k in pairs(pieces) do keys[#keys+1]=k end
    table.sort(keys)
    for _,k in ipairs(keys) do
        local w,h,x,y=k:match("^(%d+):(%d+):(%d+):(%d+)$")
        w,h,x,y=tonumber(w),tonumber(h),tonumber(x),tonumber(y)
        if positive(w) and positive(h) and x<src.w and y<src.h then
            local cols,rows=ceil(w/src.tw),ceil(h/src.th)
            local files={}
            for id in pieces[k]:gmatch("%d+") do files[#files+1]=tonumber(id) end
            if #files==cols*rows and #src.tiles+#files<=512 then
                for i,file in ipairs(files) do
                    local dx,dy=((i-1)%cols)*src.tw,floor((i-1)/cols)*src.th
                    local pw,ph=min(src.tw,w-dx),min(src.th,h-dy)
                    src.tiles[#src.tiles+1]={file=file,x=x+dx,y=y+dy,w=pw,h=ph,
                        tw=pw==src.tw and pw or padded(pw),th=ph==src.th and ph or padded(ph),detail=true}
                end
            end
        end
    end
end
local npcIcons={
    {"Flight Paths","F","Interface\\Icons\\Ability_Mount_Gryphon_01"},
    {"Innkeepers","I","Interface\\Icons\\INV_Misc_Key_03"},
    {"Repair","R","Interface\\Icons\\Trade_BlackSmithing"},
    {"Class Trainers","C","Interface\\Icons\\INV_Misc_Book_11"},
    {"Profession Trainers","P","Interface\\Icons\\INV_Misc_Gear_01"},
    {"Vendors","V","Interface\\Icons\\INV_Misc_Coin_02"},
    {"Mailboxes","M","Interface\\Icons\\INV_Letter_15"},
    {"Bankers","B","Interface\\Icons\\INV_Misc_Bag_10"},
    {"Auctioneers","A","Interface\\Icons\\INV_Misc_Coin_01"},
    {"Stable Masters","S","Interface\\Icons\\Ability_Hunter_BeastCall"},
    {"Weapon Trainers","W","Interface\\Icons\\INV_Sword_04"},
    {"Meeting Stones","D","Interface\\Icons\\Spell_Arcane_PortalStormWind"},
    {"Spirit Healers","H","Interface\\Icons\\Spell_Holy_Resurrection"},
    {"Guild Banks","G","Interface\\Icons\\INV_Misc_Bag_07"},
    {"Transmogrifiers","T","Interface\\Icons\\INV_Misc_PocketWatch_01"},
}
local function guideServicePoints(map,options)
    local list,seen={},{}
    if not positive(map) then return list end
    local function add(kind,x,y,name)
        if options[kind]~=true or not validPoint(x,y) or #list>=280 then return end
        local token=kind..":"..floor(x*115)..":"..floor(y*115)
        if seen[token] then return end
        seen[token]=true
        list[#list+1]={kind=kind,x=x,y=y,name=validName(name) and name or npcIcons[kind][1]}
    end
    local faction=safe(UnitFactionGroup,"player")
    local side=faction=="Alliance" and 1 or faction=="Horde" and 2 or -1
    for _,r in ipairs(AT.ObservedTownPins and AT.ObservedTownPins[map] or {}) do
        if r[3]==0 or r[3]==side then
            local kind=r[1]==1 and 2 or r[1]==2 and 1 or r[1]==3 and 7
            local row=AT.QuestMobData and AT.QuestMobData.creatures and AT.QuestMobData.creatures[r[2]]
            if kind then add(kind,r[4],r[5],row and row[1]) end
        end
    end
    for _,r in ipairs(AT.LevelGuideNPCServices and AT.LevelGuideNPCServices[map] or {}) do
        if r[2]==0 or r[2]==side then add(r[1],r[3],r[4],r[5]) end
    end
    if options[1] then
        local nodes=safe(C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap,map)
        for _,node in ipairs(type(nodes)=="table" and nodes or {}) do
            local vec=field(node,"position")
            local x,y=safe(vec and vec.GetXY,vec)
            add(1,x,y,field(node,"name"))
        end
    end
    if options[2] or options[7] or options[12] then
        local api=C_AreaPoiInfo
        local keys=safe(api and api.GetAreaPOIForMap,map)
        for _,id in ipairs(type(keys)=="table" and keys or {}) do
            local poi=safe(api.GetAreaPOIInfo,map,id)
            local atlas=field(poi,"atlasName")
            if validName(atlas) then
                atlas=atlas:lower():gsub("%-","")
                local kind=(atlas=="poiinn" or atlas=="innkeeper") and 2 or (atlas=="poimailbox" or atlas=="mailbox") and 7
                    or (atlas=="poimeetingstone" or atlas=="meetingstone") and 12
                if kind then
                    local vec=field(poi,"position")
                    local x,y=safe(vec and vec.GetXY,vec)
                    add(kind,x,y,field(poi,"name"))
                end
            end
        end
    end
    return list
end
local function drawGuideMap(frame)
    local fw,fh=frame:GetWidth(),frame:GetHeight()
    if not positive(fw) or not positive(fh) then return end
    local src=frame.baseArt
    frame.pin:Hide()
    for _,pin in ipairs(frame.startMarks) do pin:Hide() end
    for _,pin in pairs(frame.serviceMarks) do pin:Hide() end
    for _,dot in pairs(frame.areaRing) do dot:Hide() end
    frame.fallback:SetShown(not src)
    for _,t in pairs(frame.tiles) do t:Hide() end
    frame.zoomIn:SetShown(src~=nil)
    frame.zoomOut:SetShown(src~=nil)
    if not src then return end
    local scale=min((fw-8)/src.w,(fh-8)/src.h)*(frame.zoom or 1)
    local imgW,imgH=src.w*scale,src.h*scale
    local function origin(screen,extent,center)
        if extent<=screen then return (screen-extent)*.5 end
        return max(screen-extent,min(0,screen*.5-extent*(center or .5)))
    end
    local x0,y0=origin(fw,imgW,frame.centerX),origin(fh,imgH,frame.centerY)
    frame.mapGeometry={w=imgW,h=imgH,x=x0,y=y0}
    for i,piece in ipairs(src.tiles) do
        local left,top=x0+piece.x*scale,y0+piece.y*scale
        local right=left+min(src.w-piece.x,piece.w)*scale
        local bottom=top+min(src.h-piece.y,piece.h)*scale
        local xl,yt,xr,yb=max(0,left),max(0,top),min(fw,right),min(fh,bottom)
        if xr>xl and yb>yt then
            local t=frame.tiles[i] or frame:CreateTexture(nil,"ARTWORK")
            frame.tiles[i]=t
            t:SetDrawLayer("ARTWORK",piece.detail and 1 or 0)
            t:ClearAllPoints();t:SetPoint("TOPLEFT",xl,-yt)
            t:SetSize(xr-xl,yb-yt)
            t:SetTexCoord((xl-left)/(piece.tw*scale),(xr-left)/(piece.tw*scale),
                (yt-top)/(piece.th*scale),(yb-top)/(piece.th*scale))
            if t.guideFile~=piece.file then t:SetTexture(piece.file);t.guideFile=piece.file end
            t:Show()
        end
    end
    local destination=frame.destination
    local seen={}
    local count=0
    for _,g in ipairs(frame.starts or {}) do
        local x,y=x0+g.x*imgW,y0+g.y*imgH
        if x>=5 and x<=fw-5 and y>=10 and y<=fh and (not destination
            or abs(destination.x-g.x)+abs(destination.y-g.y)>.004) then
            local cell=floor(x/8)..":"..floor(y/9)
            if not seen[cell] and count<320 then
                seen[cell]=true;count=count+1
                local mark=frame.startMarks[count]
                if not mark then
                    mark=frame:CreateTexture(nil,"OVERLAY",nil,2)
                    mark:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
                    mark:SetSize(12,14);mark:SetAlpha(.74)
                    frame.startMarks[count]=mark
                end
                mark:ClearAllPoints();mark:SetPoint("BOTTOM",frame,"TOPLEFT",x,-y+1);mark:Show()
            end
        end
    end
    for i,g in ipairs(frame.services or {}) do
        local x,y=x0+g.x*imgW,y0+g.y*imgH
        if x>=9 and x<=fw-9 and y>=9 and y<=fh-9 then
            local icon=frame.serviceMarks[i]
            if not icon then
                icon=CreateFrame("Frame",nil,frame)
                icon:SetFrameLevel(frame:GetFrameLevel()+1)
                icon:SetSize(17,17);icon:EnableMouse(true)
                local border=icon:CreateTexture(nil,"BACKGROUND");border:SetAllPoints();border:SetColorTexture(.10,.14,.16,1)
                icon.picture=icon:CreateTexture(nil,"ARTWORK");icon.picture:SetPoint("CENTER");icon.picture:SetSize(14,14)
                icon:SetScript("OnEnter",function(self)
                    if not GameTooltip or not self.service then return end
                    GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                    GameTooltip:SetText(self.service.name);GameTooltip:AddLine(npcIcons[self.service.kind][1]);GameTooltip:Show()
                end)
                icon:SetScript("OnLeave",function(self)
                    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
                end)
                icon:EnableMouseWheel(true)
                if icon.SetPropagateMouseWheel then icon:SetPropagateMouseWheel(false) end
                icon:SetScript("OnMouseWheel",function(_,d) frame:GetScript("OnMouseWheel")(frame,d) end)
                frame.serviceMarks[i]=icon
            end
            icon.service=g;icon.picture:SetTexture(npcIcons[g.kind][3])
            icon:ClearAllPoints();icon:SetPoint("CENTER",frame,"TOPLEFT",x,-y);icon:Show()
        end
    end
    if destination then
        local x,y=x0+destination.x*imgW,y0+destination.y*imgH
        if destination.pickup then
            local radius=destination.radius
            for j=1,36 do
                local phase=j*math.pi/18
                local px,py=x+math.cos(phase)*max(12,radius*imgW),y+math.sin(phase)*max(12,radius*imgH)
                if px>=3 and px<=fw-3 and py>=3 and py<=fh-3 then
                    local dot=frame.areaRing[j]
                    if not dot then
                        dot=frame:CreateTexture(nil,"OVERLAY",nil,4)
                        dot:SetColorTexture(1,.72,.27,.91);dot:SetSize(4,4);frame.areaRing[j]=dot
                    end
                    dot:ClearAllPoints();dot:SetPoint("CENTER",frame,"TOPLEFT",px,-py);dot:Show()
                end
            end
        end
        if x>=8 and x<=fw-8 and y>=12 and y<=fh then
            frame.pin:ClearAllPoints();frame.pin:SetPoint("BOTTOM",frame,"TOPLEFT",x,-y+1)
            frame.pin:Show()
        end
    end
end
local function art(frame,map,dungeon,pin,key)
    local id=tostring(map)..":"..tostring(dungeon)
    local changed=frame.artKey~=id
    if changed then
        frame.artKey,frame.baseArt,frame.mapGeometry=id,nil,nil
        setIcon(frame.fallback,dungeon and GUIDE_DUNGEON or GUIDE_MAP)
        if positive(map) then
            -- Native base art plus exploration detail independent of personal discoveries.
            local layer=field(safe(M and M.GetMapArtLayers,map),1)
            local w,h,tw,th=field(layer,"layerWidth"),field(layer,"layerHeight"),field(layer,"tileWidth"),field(layer,"tileHeight")
            if positive(w) and positive(h) and positive(tw) and positive(th) then
                local cols,rows=ceil(w/tw),ceil(h/th)
                if cols*rows<=144 then
                    local ids=safe(M.GetMapArtLayerTextures,map,1)
                    if type(ids)=="table" and #ids==cols*rows then
                        local src={tiles={},w=w,h=h,tw=tw,th=th}
                        for i=1,#ids do
                            local file=field(ids,i)
                            if not positive(file) then break end
                            local x,y=((i-1)%cols)*tw,floor((i-1)/cols)*th
                            src.tiles[i]={file=file,x=x,y=y,w=min(tw,w-x),h=min(th,h-y),tw=tw,th=th}
                        end
                        if #src.tiles==#ids then
                            appendMapReveal(src,safe(M.GetMapArtID,map))
                            frame.baseArt=src
                        end
                    end
                end
            end
        end
    end
    if changed or frame.pinKey~=key then
        frame.pinKey=key
        if changed then frame.zoom=1 end
        frame.centerX,frame.centerY=pin and pin.x or .5,pin and pin.y or .5
    end
    frame.destination=pin
    drawGuideMap(frame)
end
local function zoomGuideMap(frame,steps)
    if not frame.baseArt or not plain(steps) or type(steps)~="number" or steps~=steps or abs(steps)>100 then return end
    if (frame.zoom or 1)==1 and steps>0 and frame.destination then
        frame.centerX,frame.centerY=frame.destination.x,frame.destination.y
    end
    frame.zoom=max(1,min(6,(frame.zoom or 1)*1.3^steps))
    if frame.zoom==1 then frame.centerX,frame.centerY=.5,.5 end
    drawGuideMap(frame)
end
local function rangeEntry(parent,x,y,width,limit,numeric)
    local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
    e:SetSize(width,24);e:SetPoint("TOPLEFT",x,y);e:SetAutoFocus(false)
    e:SetMaxLetters(limit)
    if numeric then e:SetNumeric(true) end
    e:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    return e
end
local function range(p)
    if p.rangeKnown and p.lo then return ("%d-%d"):format(p.lo,p.hi or p.lo) end
end
local function contains(text,search)
    return lower(text):find(lower(search or ""),1,true)~=nil
end
function AT.FilterLevelGuide(result,mode,name,lo,hi)
    lo=positive(lo) and min(60,lo) or 1
    hi=positive(hi) and min(60,hi) or 60
    if lo>hi then lo,hi=hi,lo end
    local rows={}
    for _,p in ipairs(result.places) do
        local allowed=mode=="forYou" and p.kind=="zone" and p.total>0
            or mode=="zones" and p.kind=="zone" or mode=="dungeons" and p.kind=="dungeon"
        if allowed and (mode=="forYou" or contains(p.name,name) and ((not p.lo and lo==1 and hi==60)
            or p.lo and (p.hi or p.lo)>=lo and p.lo<=hi)) then rows[#rows+1]=p end
    end
    if mode~="forYou" then
        table.sort(rows,function(a,b)
            if mode=="dungeons" and a.inBand~=b.inBand then return a.inBand end
            if mode=="dungeons" and a.inBand and a.score~=b.score then return a.score>b.score end
            if mode=="dungeons" and a.inBand and a.leadScore~=b.leadScore then return a.leadScore>b.leadScore end
            if (a.lo or 61)~=(b.lo or 61) then return (a.lo or 61)<(b.lo or 61) end
            return a.name<b.name
        end)
    end
    return rows
end
local function openMap(map)
    if not positive(map) then return end
    local f=_G.WorldMapFrame
    if not f then
        local loader=C_AddOns and C_AddOns.LoadAddOn or _G.LoadAddOn
        safe(loader,"Blizzard_WorldMap")
        f=_G.WorldMapFrame
    end
    if f then
        local w=guide
        if w then
            local strata=safe(f.GetFrameStrata,f)
            if strata=="BACKGROUND" or not strata then w:SetFrameStrata("BACKGROUND") else w:SetFrameStrata("LOW") end
            if strata=="LOW" then w:SetFrameStrata("BACKGROUND") end
            if not f.nqtLevelGuideRestore and f.HookScript then
                f:HookScript("OnHide",function()
                    if guide then guide:SetFrameStrata("FULLSCREEN_DIALOG") end
                end)
                f.nqtLevelGuideRestore=true
            end
        end
        if ShowUIPanel then safe(ShowUIPanel,f) elseif f.Show then safe(f.Show,f) end
        safe(f.SetMapID,f,map)
        safe(f.Raise,f)
        if w and safe(f.IsShown,f)==false then w:SetFrameStrata("FULLSCREEN_DIALOG") end
    end
end
local render
local function sameWaypoint(giver)
    local waypoint=safe(M and M.GetUserWaypoint)
    local pos=field(waypoint,"position")
    local x,y=safe(pos and pos.GetXY,pos)
    return field(waypoint,"uiMapID")==giver.map and validPoint(x,y)
        and abs(x-giver.x)<.0001 and abs(y-giver.y)<.0001
end
local function refreshRoute()
    safe(AT.RefreshQuestRoute)
    safe(AT.RefreshWorldRoute)
end
local function stopGiver(clear)
    local previous=trackedGiver
    trackedGiver=nil
    if previous and clear and previous.native and sameWaypoint(previous) then safe(M and M.ClearUserWaypoint) end
    refreshRoute()
    if render then render() end
end
function AT.GetLevelGuideRoutePoint()
    local g=trackedGiver
    if not g or g.pickup then return end
    return g.id,g.map,g.x,g.y,g.name
end
function AT.TrackLevelGuideGiver(q)
    local g=q and q.giver
    if not g or not positive(g.map) or not validPoint(g.x,g.y) then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    if trackedGiver and trackedGiver.id==q.id then stopGiver(true);return true end
    if trackedGiver and trackedGiver.native and sameWaypoint(trackedGiver) then safe(M and M.ClearUserWaypoint) end
    if g.pickup then
        trackedGiver={id=q.id,pickup=true}
        if guide then
            guide.selectedQuest=q.id
            guide.art.pinKey=nil
            guide.art.zoom=1
        end
        refreshRoute()
        if render then render() end
        return true
    end
    local pointAPI=_G.UiMapPoint or _G.MapPoint
    local native
    settingWaypoint=true
    if safe(M and M.CanSetUserWaypointOnMap,g.map)~=false then
        local point=safe(pointAPI and pointAPI.CreateFromCoordinates,g.map,g.x,g.y)
        if point and M and M.SetUserWaypoint then
            safe(M.SetUserWaypoint,point)
            native=sameWaypoint(g)
            if native then safe(C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint,true) end
        end
    end
    trackedGiver={id=q.id,map=g.map,x=g.x,y=g.y,name=g.name,native=native,
        prior=safe(C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID)}
    settingWaypoint=nil
    refreshRoute()
    if render then render() end
    return true
end
local function navigate(direction,which)
    if which=="area" then guide.areaPage=max(1,guide.areaPage+direction)
    else guide.questPage=max(1,guide.questPage+direction) end
    render()
end
local function guideWheel(frame,action)
    frame:EnableMouseWheel(true)
    if frame.SetPropagateMouseWheel then frame:SetPropagateMouseWheel(false) end
    frame:SetScript("OnMouseWheel",function(self,delta)
        if not guide or not guide:IsShown() or not plain(delta) or type(delta)~="number" or delta==0 then return end
        action(self,delta)
    end)
end
local function listWheel(which)
    return function(_,delta) navigate(delta>0 and -1 or 1,which) end
end
local function pageText(pages,current) return ("%d / %d"):format(current,pages) end
local badges={
    {"kill","Kill", "Interface\\Icons\\INV_Sword_04", {.92,.62,.43}},
    {"collect","Collect", "Interface\\Icons\\INV_Misc_Bag_10", {.53,.83,.76}},
    {"mixed","Mixed", "Interface\\Icons\\INV_Misc_Book_09", {.71,.64,.91}},
    {"other","Other", "Interface\\Icons\\INV_Misc_Map_01", {.68,.75,.92}},
}
local function suggestion(p)
    if not p then return "Pick a different area or adjust your filters." end
    if p.mix.turnin>0 then return ("Turn in %d quest%s first, then pick up the next batch."):format(p.mix.turnin,p.mix.turnin==1 and "" or "s") end
    if p.available>0 then return ("Start with %d quest%s ready to pick up."):format(p.available,p.available==1 and "" or "s") end
    if p.leadMix.kill>=3 and p.leadMix.kill>=p.leadMix.collect then return "Start with the kill quests and group them by route." end
    if p.total>0 then return "Start with short quests; save slow drops for last." end
    return p.kind=="dungeon" and "No dungeon quests to pick up at your level." or "No matching unfinished quests at your level."
end
local caption={kill="Kill",collect="Collect",mixed="Mixed",other="Other"}
local function rateLine(q)
    if q.lowRate then return ("  |  %d%% slowest known drop"):format(ceil(q.lowRate*100-1e-8)) end
    if q.unknown and (q.kind=="collect" or q.kind=="mixed") then return "  |  Drop rate unknown" end
    return ""
end
local requestedItems={}
function AT.GetLevelGuideObjectiveText(qid)
    local lines={}
    local live=safe(Q and Q.GetQuestObjectives,qid)
    if type(live)=="table" then
        for _,objective in ipairs(live) do
            local value=field(objective,"text")
            if validName(value) then lines[#lines+1]=value end
        end
    end
    if #lines>0 then return table.concat(lines,"\n"),true end
    local row=AT.ForeverLevelGuideQuests and AT.ForeverLevelGuideQuests[qid]
    local locale=safe(GetLocale)
    local english=not locale or locale=="enUS" or locale=="enGB"
    local catalog=AT.QuestMobData and AT.QuestMobData.creatures
    local lib=optionalDatabase() and _G.LibQuestieDB
    for _,o in ipairs(row and row[10] or {}) do
        local kind,id,n=unpack(o)
        if (kind==1 or kind==2) and positive(n) then
            local name
            if kind==1 and positive(id) then
                local entry=english and catalog and catalog[id]
                name=safe(C_CreatureInfo and C_CreatureInfo.GetCreatureName,id)
                    or questField(field(lib,"Npc"),id,"name") or entry and entry[1]
            elseif kind==2 and positive(id) then
                name=safe(C_Item and C_Item.GetItemNameByID,id) or safe(GetItemInfo,id)
                    or questField(field(lib,"Item"),id,"name")
                if not name and not requestedItems[id] then
                    requestedItems[id]=true
                    safe(C_Item and C_Item.RequestLoadItemDataByID,id)
                end
            end
            lines[#lines+1]=("%s: 0/%d"):format(validName(name) and name or kind==1 and "Kills" or "Collect",n)
        end
    end
    local summary=english and AT.LevelGuideObjectiveSummaries and AT.LevelGuideObjectiveSummaries[qid]
    if validName(summary) then lines[#lines+1]=summary end
    return #lines>0 and table.concat(lines,"\n") or nil,false
end
local function startDescription(g)
    if not g then return "" end
    local mapName=positive(g.map) and field(mapInfo(g.map),"name")
    if g.pickup then
        local item=safe(C_Item and C_Item.GetItemNameByID,g.item) or safe(GetItemInfo,g.item)
        if not validName(item) and not requestedItems[g.item] then
            requestedItems[g.item]=true;safe(C_Item and C_Item.RequestLoadItemDataByID,g.item)
        end
        local what=validName(item) and item or ("item #"..g.item)
        if validName(g.sourceName) then
            return (g.sourceKind==2 and "Loot " or "Drop: ")..what.." from "..g.sourceName..(mapName and ("  |  "..mapName) or "")
        end
        return g.source and ("Drop: "..what)..(mapName and ("  |  "..mapName) or "") or ("Starts with "..what)
    end
    return ("%s  |  %s %.1f, %.1f"):format(validName(g.name) and g.name or "Quest start",mapName or "Map",g.x*100,g.y*100)
end
local function currentQuestView(p,mode,hideHeld)
    local out={}
    for _,q in ipairs(p.quests) do
        if not (hideHeld and (q.status=="In log" or q.status=="Turn in"))
            and (mode=="forYou" and q.fits or mode~="forYou" and q.availableHere) then out[#out+1]=q end
    end
    return out
end
render=function()
    local w=guide
    if not w or not w:IsShown() or not w.result then return end
    local result=w.result
    for mode,b in pairs(w.tabs) do active(b,mode==w.mode) end
    for i,b in ipairs(w.group) do active(b,i==w.size) end
    w.partyChoice.caption:SetText(w.size==1 and "Solo  v" or (w.size.." players  v"))
    local manual=w.mode~="forYou"
    for _,f in ipairs(w.filters) do f:SetShown(manual) end
    local entries=AT.FilterLevelGuide(result,w.mode,w.search:GetText(),tonumber(w.low:GetText()),tonumber(w.high:GetText()))
    local views,visibleScores,originalOrder,tabsByPlace={},{},{},{}
    for i=#entries,1,-1 do
        local p=entries[i]
        local all=currentQuestView(p,w.mode,w.hideHeld)
        tabsByPlace[p.id]=all
        if w.questKind then
            local relevant={}
            for _,q in ipairs(all) do if q.kind==w.questKind then relevant[#relevant+1]=q end end
            views[p.id]=relevant
        else views[p.id]=all end
        originalOrder[p.id]=i
        local score=p.score
        if w.hideHeld or w.questKind then
            score=0
            for _,q in ipairs(views[p.id]) do score=score+(q.efficiency+q.potential*.10)*(q.confirmed and 1 or .72) end
        end
        visibleScores[p.id]=score
        if w.mode=="forYou" and #all==0 then table.remove(entries,i) end
    end
    if (w.hideHeld or w.questKind) and w.mode=="forYou" then
        table.sort(entries,function(a,b)
            local x,y=visibleScores[a.id],visibleScores[b.id]
            if x~=y then return x>y end
            return originalOrder[a.id]<originalOrder[b.id]
        end)
    end
    local top=entries[1]
    local chosen,where
    for i,p in ipairs(entries) do if p.id==w.selection then chosen,where=p,i;break end end
    if chosen==nil then chosen,where=top,1 end
    w.renderedPlaceID=chosen and chosen.id
    local areaLimit,questLimit=w.areaLimit or 5,w.questLimit or 6
    local areaPages=max(1,ceil(#entries/areaLimit))
    w.areaPage=max(1,min(areaPages,w.areaPage))
    if where and w.followSelection then w.areaPage=ceil(where/areaLimit) end
    w.followSelection=nil
    w.areaPages:SetText(pageText(areaPages,w.areaPage))
    w.areaPrev:SetShown(w.areaPage>1);w.areaNext:SetShown(w.areaPage<areaPages)
    w.headerSub:SetText(("Level %d"):format(result.level))
    w.heroTop:SetText(w.mode=="zones" and "EXPLORE A ZONE" or w.mode=="dungeons" and "PLAN A DUNGEON RUN" or "")
    w.heroName:SetText(chosen and chosen.name or "No matching areas")
    local band=chosen and range(chosen)
    local here=chosen and chosen.here and chosen.kind=="zone"
    w.heroBand:SetText((band and ("LEVELS  "..band) or "")..(here and (band and "   /   YOU ARE HERE" or "YOU ARE HERE") or ""))
    local list=chosen and views[chosen.id] or {}
    local total,offers,turnIns=0,0,0
    local mix={kill=0,collect=0,mixed=0,other=0}
    local selectedQuest
    for _,q in ipairs(list) do
        total=total+1
        if q.status=="Pick up" then offers=offers+1 end
        if q.status=="Turn in" then turnIns=turnIns+1 end
        if q.id==w.selectedQuest then selectedQuest=q end
    end
    for _,q in ipairs(chosen and tabsByPlace[chosen.id] or {}) do mix[q.kind]=mix[q.kind]+1 end
    if not selectedQuest then w.selectedQuest=nil end
    w.heroFact:SetText((chosen and (w.questKind and ("%d matching quests"):format(total) or ("%d quests at your level"):format(total)) or "")..
        (offers>0 and ("  |  %d ready to pick up"):format(offers) or ""))
    local selectedStart=selectedQuest and selectedQuest.giver
    local dest=selectedStart and positive(selectedStart.map) and validPoint(selectedStart.x,selectedStart.y) and selectedStart or nil
    if selectedQuest then
        w.heroAction:SetText(startDescription(selectedStart))
    else
        w.heroAction:SetText(not chosen and suggestion(chosen) or turnIns>0 and ("Turn in %d first, then pick up the next batch."):format(turnIns)
            or offers>0 and ("Start with %d ready to pick up."):format(offers)
            or total>0 and (mix.kill>=mix.collect and "Start with the kill quests; group them by route." or "Start with the fastest quests; save slow drops for last.")
            or suggestion(nil))
    end
    w.heroNote:SetText(chosen and chosen.note or "")
    for _,badge in ipairs(w.badges) do
        local value=mix[badge.key]
        badge.label:SetText(value.." "..badge.typeLabel)
        badge.bg:SetColorTexture(w.questKind==badge.key and .27 or .08,w.questKind==badge.key and .195 or .095,.10,1)
        badge.indicator:SetShown(w.questKind==badge.key)
        badge.bar:SetWidth(max(1,value/max(1,total)*badge.barWidth))
        badge.bar:SetShown(value>0)
        badge:SetShown(chosen~=nil)
    end
    w.objectives:SetShown(selectedQuest~=nil)
    if selectedQuest then
        w.objectives.title:SetText(selectedQuest.name)
        local body=AT.GetLevelGuideObjectiveText(selectedQuest.id)
        if w.objectives.questID~=selectedQuest.id then w.objectives.scroll:SetVerticalScroll(0) end
        w.objectives.questID=selectedQuest.id
        w.objectives.text:SetText(body or "No objective details are available.")
        w.objectivesContent:SetHeight(max(2,(safe(w.objectives.text.GetStringHeight,w.objectives.text) or 40)+8))
    end
    w.art:SetHeight(w.mapHeight-(selectedQuest and w.detailsHeight+8 or 0))
    local map=dest and dest.map or chosen and (chosen.artMap or chosen.map)
    w.mapButton:SetShown(positive(map))
    w.mapButton.map=map
    local starts,considered={},{}
    if positive(map) then
        for _,p in ipairs(result.places) do
            for _,q in ipairs(currentQuestView(p,w.mode,w.hideHeld)) do
                local g=q.giver
                if not considered[q.id] and g and g.map==map and validPoint(g.x,g.y) then
                    considered[q.id]=true;starts[#starts+1]=g
                end
            end
        end
    end
    w.art.starts=starts
    local serviceKey=map or false
    if w.art.serviceMap~=serviceKey then
        w.art.serviceMap=serviceKey
        w.art.services=guideServicePoints(map,w.npcOptions)
    end
    art(w.art,map,chosen and chosen.kind=="dungeon",dest,selectedQuest and selectedQuest.id)
    for i,row in ipairs(w.areas) do
        local idx=(w.areaPage-1)*areaLimit+i
        local p=i<=areaLimit and entries[idx] or nil;row.place=p;row:SetShown(p~=nil)
        if p then
            row.name:SetText(p.name)
            local areaBand=range(p)
            local here=p.here and p.kind=="zone"
            row.detail:SetText((areaBand and ("Levels "..areaBand) or "")..(here and (areaBand and "   |   Here now" or "Here now") or ""))
                        row.index:SetText(w.mode=="forYou" and ("%02d"):format(idx) or "")
            local inset=w.mode=="forYou" and 25 or 8
            row.name:ClearAllPoints();row.name:SetPoint("TOPLEFT",inset,-2)
            row.name:SetWidth(w.areaWidth-inset-42)
            row.detail:ClearAllPoints();row.detail:SetPoint("TOPLEFT",inset,-14)
            row.detail:SetWidth(w.areaWidth-inset-21);row.detail:SetWordWrap(false)
            row.total:SetText(tostring(#views[p.id]))
            local relative=(entries[1] and visibleScores[entries[1].id] or 0)
            row.bar:SetWidth(max(1,min(1,visibleScores[p.id]/max(1,relative))*(w.areaWidth-42)))
            row.bar:SetShown(visibleScores[p.id]>0)
            row.isSelected=p==chosen
            row.bg:SetColorTexture(row.isSelected and .215 or .09,row.isSelected and .18 or .10,row.isSelected and .13 or .11,1)
        end
    end
    local pages=max(1,ceil(#list/questLimit))
    w.questPage=max(1,min(pages,w.questPage))
    w.questPages:SetText(pageText(pages,w.questPage));w.questPrev:SetShown(w.questPage>1);w.questNext:SetShown(w.questPage<pages)
    w.questEmpty:SetText(w.questKind and "No quests match this type." or "No unfinished quests found here.")
    w.questEmpty:SetShown(#list==0)
    for i,row in ipairs(w.quests) do
        local q=i<=questLimit and list[(w.questPage-1)*questLimit+i] or nil
        row:SetShown(q~=nil)
        row.record=q
        if q then
            local picked=selectedQuest==q
            row.back:SetColorTexture(picked and .25 or .078,picked and .18 or .091,picked and .105 or .10,1)
            row.icon:SetTexture(q.kind=="kill" and "Interface\\Icons\\INV_Sword_04" or q.kind=="collect" and "Interface\\Icons\\INV_Misc_Bag_10" or GUIDE_BOOK)
            row.name:SetText((q.verifiedLevel and ("[%d] "):format(q.level) or "")..q.name)
            row.detail:SetText((caption[q.kind] or "Quest")..rateLine(q)..
                (q.min>result.level and ("  |  Requires level "..q.min) or not q.fits and "  |  Outside leveling band" or ""))
            local g=q.giver
            local canTrack=g and positive(g.map) and validPoint(g.x,g.y)
            row.waypoint:SetShown(canTrack and true or false)
            if g then row.detail:SetText(startDescription(g)) end
            local selected=canTrack and trackedGiver and trackedGiver.id==q.id
            row.waypoint.caption:SetText(selected and "Stop" or "Track")
            active(row.waypoint,selected)
            row.name:SetWidth(w.questWidth-(canTrack and 88 or 32))
            row.detail:SetWidth(w.questWidth-(canTrack and 88 or 32))
            local status=q.status=="In range" and not q.fits and w.mode~="dungeons" and "Later" or q.status
            row.status:SetText(status)
            row.status:Hide()
            row.name:SetTextColor(unpack(status=="Pick up" and palette.teal or status=="Turn in" and palette.gold or palette.ink))
            row.status:SetTextColor(unpack(status=="Turn in" and palette.gold or status=="Pick up" and palette.teal or palette.dim))
        end
    end
end
local function update()
    if not guide or not guide:IsShown() then return end
    guide.result=AT.BuildLevelGuide(nil,guide.size)
    render()
end
local function queueRefresh(force)
    if not guide or not guide:IsShown() then return end
    if force or not (C_Timer and C_Timer.After) then update();return end
    if refreshQueued then return end
    refreshQueued=true
    C_Timer.After(.23,function() refreshQueued=nil;update() end)
end
function AT.RefreshLevelGuide()
    queueRefresh()
end
local function buildWindow()
    if not CreateFrame or not UIParent then return end
    local w=CreateFrame("Frame","NQTLevelGuide",UIParent,"BackdropTemplate")
    guide=w
    local savedSize=tonumber(AT.char and AT.char.levelGuidePartySize) or 1
    w.mode,w.size,w.areaPage,w.questPage="forYou",min(3,max(1,floor(savedSize))),1,1
    w:SetFrameStrata("FULLSCREEN_DIALOG")
    w:SetClampedToScreen(true);w:SetMovable(true);w:SetResizable(true);w:EnableMouse(true)
    w:SetPoint("CENTER",UIParent,"CENTER")
    local sw,sh=safe(UIParent.GetWidth,UIParent),safe(UIParent.GetHeight,UIParent)
    local scale=positive(sw) and positive(sh) and max(.4,min(1,(sw-28)/750,(sh-36)/526)) or 1
    w:SetScale(scale)
    local maxW=positive(sw) and max(750,floor((sw-8)/scale)) or 1250
    local maxH=positive(sh) and max(526,floor((sh-8)/scale)) or 860
    if w.SetResizeBounds then w:SetResizeBounds(750,526,maxW,maxH)
    elseif w.SetMinResize then w:SetMinResize(750,526);w:SetMaxResize(maxW,maxH) end
    local pref=AT.db or AT.char or {}
    w:SetSize(min(maxW,max(750,tonumber(pref.levelGuideWidth) or 870)),
        min(maxH,max(526,tonumber(pref.levelGuideHeight) or 642)))
    local canvas=CreateFrame("Frame",nil,w,"BackdropTemplate")
    w.canvas=canvas
    canvas:SetPoint("TOPLEFT",w,"TOPLEFT")
    if canvas.SetBackdrop then
        canvas:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize=14,insets={left=4,right=4,top=4,bottom=4}})
        canvas:SetBackdropColor(unpack(palette.base));canvas:SetBackdropBorderColor(unpack(palette.edge))
    end
    w.hideHeld=pref.levelGuideHideHeld~=false
    w.npcOptions=type(pref.levelGuideNPCIcons)=="table" and pref.levelGuideNPCIcons or {}
    pref.levelGuideNPCIcons=w.npcOptions
    local mast=CreateFrame("Frame",nil,canvas)
    mast:SetPoint("TOPLEFT",9,-8);mast:SetPoint("TOPRIGHT",-9,-8);mast:SetHeight(44)
    mast:EnableMouse(true);mast:RegisterForDrag("LeftButton")
    mast:SetScript("OnDragStart",function() if not w.maximized then w:StartMoving() end end)
    mast:SetScript("OnDragStop",function() w:StopMovingOrSizing() end)
    local mastBG=fill(mast,nil,{.103,.098,.085,1});mastBG:SetAllPoints()
    w.mastRule=rect(canvas,"BORDER",palette.edge,16,-53,838,1)
    local crest=mast:CreateTexture(nil,"ARTWORK")
    crest:SetSize(30,30);crest:SetPoint("TOPLEFT",12,-7);setIcon(crest,GUIDE_BOOK)
    local title=label(mast,"GameFontNormalLarge","NQT Level Guide",palette.gold);title:SetPoint("TOPLEFT",53,-5)
    w.headerSub=label(mast,"GameFontHighlightSmall","",palette.dim);w.headerSub:SetPoint("TOPLEFT",54,-27)
    local close=CreateFrame("Button",nil,canvas,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",-6,-6)
    close:SetFrameLevel(mast:GetFrameLevel()+4)
    close:SetScript("OnClick",function() w:Hide() end)
    local maximize=CreateFrame("Button",nil,canvas)
    w.maximizeButton=maximize
    maximize:SetSize(32,32)
    maximize:SetPoint("RIGHT",close,"LEFT",5,0)
    -- The movable mast occupies this same screen region. Keep both actions
    -- above its mouse-enabled drag surface, regardless of creation order.
    maximize:SetFrameLevel(close:GetFrameLevel())
    maximize:EnableMouse(true)
    maximize:RegisterForClicks("LeftButtonUp")
    if maximize.SetHitRectInsets then maximize:SetHitRectInsets(3,3,3,3) end
    maximize:SetScript("OnClick",function(_,mouseButton)
        if mouseButton==nil or mouseButton=="LeftButton" then w.toggleMaximize() end
    end)
    local sprite="Interface\\AddOns\\NQT\\LevelGuideWindowControls.tga"
    maximize:SetNormalTexture(sprite)
    maximize:SetPushedTexture(sprite)
    maximize:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
    local function updateMaximizeArt()
        local left=w.maximized and .5 or 0
        maximize:GetNormalTexture():SetTexCoord(left,left+.25,0,1)
        maximize:GetPushedTexture():SetTexCoord(left+.25,left+.5,0,1)
    end
    updateMaximizeArt()
    maximize:SetScript("OnEnter",function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_BOTTOM")
        GameTooltip:SetText(w.maximized and "Restore window" or "Maximize Level Guide")
        GameTooltip:Show()
    end)
    maximize:SetScript("OnLeave",function(self)
        if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    local check=CreateFrame("CheckButton",nil,canvas,"UICheckButtonTemplate")
    w.inQuestLog=check
    check:SetSize(24,24);check:SetPoint("TOPRIGHT",-173,-12)
    check:SetFrameLevel(close:GetFrameLevel())
    check:EnableMouse(true);check:SetChecked(w.hideHeld)
    local checkText=label(check,"GameFontHighlightSmall","In Quest Log",palette.ink)
    checkText:SetPoint("LEFT",check,"RIGHT",2,0)
    if check.SetHitRectInsets then check:SetHitRectInsets(0,-83,0,0) end
    check:SetScript("OnClick",function(self)
        w.hideHeld=self:GetChecked() and true or false
        pref.levelGuideHideHeld=w.hideHeld
        w.questPage=1;render()
    end)
    check:SetScript("OnEnter",function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_BOTTOM")
        GameTooltip:SetText("In Quest Log")
        GameTooltip:AddLine("Checked: hide quests already in your quest log.",.88,.88,.88,true)
        GameTooltip:Show()
    end)
    check:SetScript("OnLeave",function(self)
        if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    if UISpecialFrames then
        local found
        for _,frameName in ipairs(UISpecialFrames) do if frameName=="NQTLevelGuide" then found=true end end
        if not found then UISpecialFrames[#UISpecialFrames+1]="NQTLevelGuide" end
    end
    w.tabs={}
    local tabs={{"forYou","For You",64},{"zones","Zones",58},{"dungeons","Dungeons",73}}
    local offset=17
    for _,d in ipairs(tabs) do
        local mode=d[1]
        w.tabs[mode]=button(canvas,d[2],d[3],21,offset,-59,function()
            w.mode,w.areaPage,w.questPage,w.selection,w.selectedQuest=mode,1,1,nil,nil
            if w.partyMenu then w.partyMenu:Hide() end
            w.search:ClearFocus();w.low:ClearFocus();w.high:ClearFocus()
            if w.layout then w.layout() end
            render()
        end)
        offset=offset+d[3]+5
    end
    w.group={}
    local menu=CreateFrame("Frame",nil,canvas)
    w.partyMenu=menu
    menu:SetSize(94,70);menu:SetPoint("TOPRIGHT",-203,-39)
    menu:SetFrameLevel(close:GetFrameLevel()+15)
    menu:EnableMouse(true)
    local menuBg=fill(menu,nil,{.10,.10,.093,1});menuBg:SetAllPoints()
    menu:Hide()
    w.partyChoice=button(canvas,"Solo  v",94,23,0,0,function() menu:SetShown(not menu:IsShown()) end)
    w.partyChoice:ClearAllPoints();w.partyChoice:SetPoint("TOPRIGHT",-203,-12)
    w.partyChoice:SetFrameLevel(close:GetFrameLevel())
    for i,n in ipairs({"Solo","2 players","3 players"}) do
        local size=i
        w.group[i]=button(menu,n,90,21,2,-2-(i-1)*22,function()
            menu:Hide();w.size=size
            if AT.char then AT.char.levelGuidePartySize=size end
            w.areaPage,w.questPage,w.selection,w.selectedQuest=1,1,nil,nil;queueRefresh(true)
        end)
    end
    local rule=rect(canvas,nil,{.31,.25,.18,1},17,-114,836,1);w.filterRule=rule
    local filterTitle=label(canvas,"GameFontHighlightSmall","FIND",palette.gold);filterTitle:SetPoint("TOPLEFT",19,-93)
    w.search=rangeEntry(canvas,70,-85,197,54)
    local at=label(canvas,"GameFontHighlightSmall","LEVELS",palette.dim);at:SetPoint("TOPLEFT",285,-93)
    w.low=rangeEntry(canvas,339,-85,34,2,true)
    local sep=label(canvas,"GameFontHighlight","-",palette.dim);sep:SetPoint("TOPLEFT",378,-91)
    w.high=rangeEntry(canvas,395,-85,34,2,true)
    local filterChange=function()
        if w.batch then return end
        w.areaPage,w.questPage,w.selection=1,1,nil
        render()
    end
    for _,e in ipairs({w.search,w.low,w.high}) do e:SetScript("OnTextChanged",filterChange) end
    local mine=button(canvas,"Around my level",118,24,449,-85,function()
        local level=w.result and w.result.level or 1
        w.batch=true;w.low:SetText(tostring(max(1,level-3)));w.high:SetText(tostring(min(60,level+3)));w.batch=nil
        filterChange()
    end)
    local clear=button(canvas,"Clear filters",100,24,574,-85,function()
        w.batch=true;w.search:SetText("");w.low:SetText("");w.high:SetText("");w.batch=nil
        filterChange()
    end)
    w.filters={filterTitle,w.search,at,w.low,sep,w.high,mine,clear,rule}
    local hero=CreateFrame("Frame",nil,canvas)
    w.hero=hero
    hero:SetSize(836,176);hero:SetPoint("TOPLEFT",17,-149)
    local background=fill(hero,nil,{.11,.123,.126,1});background:SetAllPoints()
    w.heroEdge=rect(hero,"ARTWORK",{.65,.44,.22,1},0,0,2,176)
    w.art=CreateFrame("Frame",nil,canvas)
    w.art:SetSize(215,150);w.art:SetPoint("TOPRIGHT",0,0)
    w.art.tiles,w.art.startMarks,w.art.areaRing,w.art.serviceMarks={},{},{},{}
    local artBack=fill(w.art,nil,{.075,.089,.095,1});artBack:SetAllPoints()
    w.art.fallback=w.art:CreateTexture(nil,"ARTWORK");w.art.fallback:SetSize(82,82);w.art.fallback:SetPoint("CENTER")
    local tint=fill(w.art,"OVERLAY",{.12,.14,.15,.1});tint:SetAllPoints()
    w.mapHeading=label(w.art,"GameFontHighlightSmall","QUEST MAP",palette.gold)
    w.mapHeading:SetPoint("BOTTOMLEFT",5,5)
    w.heroTop=label(hero,"GameFontHighlightSmall","",palette.teal);w.heroTop:SetPoint("TOPLEFT",16,-11)
    w.heroName=label(hero,"GameFontNormalHuge","",palette.gold);w.heroName:SetPoint("TOPLEFT",15,-27);w.heroName:SetWidth(594);w.heroName:SetWordWrap(false)
    w.heroBand=label(hero,"GameFontHighlightSmall","",palette.gold);w.heroBand:SetPoint("TOPLEFT",16,-57)
    w.heroFact=label(hero,"GameFontHighlight","",palette.ink);w.heroFact:SetPoint("TOPLEFT",16,-76)
    w.heroAction=label(hero,"GameFontHighlightSmall","",palette.teal);w.heroAction:SetPoint("TOPLEFT",16,-90);w.heroAction:SetWordWrap(false)
    w.heroNote=label(hero,"GameFontHighlightSmall","",palette.dim);w.heroNote:SetPoint("TOPLEFT",16,-101);w.heroNote:SetWordWrap(false)
    w.badges={}
    for i,meta in ipairs(badges) do
        local kind=meta[1]
        local tile=button(hero,"",74,24,16+(i-1)*79,-113,function()
            w.selection=w.renderedPlaceID or w.selection
            w.questKind=w.questKind~=kind and kind or nil
            w.questPage=1
            render()
        end)
        tile:EnableMouse(true)
        tile.indicator=rect(tile,"ARTWORK",{.86,.68,.39,1},0,-24,74,1)
        local icon=tile:CreateTexture(nil,"ARTWORK");icon:SetSize(14,14);icon:SetPoint("LEFT",4,0);setIcon(icon,meta[3])
        tile.label=label(tile,"GameFontHighlightSmall","",meta[4]);tile.label:SetPoint("LEFT",21,0)
        tile.bar=rect(tile,"ARTWORK",{meta[4][1],meta[4][2],meta[4][3],.65},4,-21,1,1)
        tile.key,tile.typeLabel,tile.barWidth=meta[1],meta[2],66
        w.badges[i]=tile
    end
    w.mapButton=button(w.art,"View map",72,21,0,0,function(self) openMap(self.map) end)
    w.mapButton:ClearAllPoints();w.mapButton:SetPoint("BOTTOMRIGHT",-10,9)
    w.mapButton:SetFrameLevel(w.art:GetFrameLevel()+2)
    local preview=w.art
    preview:EnableMouse(true)
    guideWheel(preview,function(self,delta) zoomGuideMap(self,delta) end)
    preview.zoomIn=button(preview,"+",20,20,0,0,function() zoomGuideMap(preview,1) end)
    preview.zoomOut=button(preview,"-",20,20,0,0,function() zoomGuideMap(preview,-1) end)
    for i,control in ipairs({preview.zoomOut,preview.zoomIn}) do
        control:ClearAllPoints();control:SetPoint("TOPRIGHT",-5-(2-i)*23,-5)
        control:SetFrameLevel(preview:GetFrameLevel()+4)
    end
    local optionsPanel=CreateFrame("Frame",nil,preview)
    w.npcMenu=optionsPanel
    optionsPanel:SetSize(155,12+#npcIcons*19);optionsPanel:SetPoint("TOPLEFT",5,-28)
    optionsPanel:SetFrameLevel(preview:GetFrameLevel()+12);optionsPanel:EnableMouse(true)
    local panelBg=fill(optionsPanel,nil,{.095,.095,.078,.99});panelBg:SetAllPoints()
    optionsPanel:Hide()
    w.npcButton=button(preview,"NPC Icons",76,20,5,-5,function()
        optionsPanel:SetShown(not optionsPanel:IsShown())
        if w.partyMenu then w.partyMenu:Hide() end
    end)
    w.npcButton:SetFrameLevel(preview:GetFrameLevel()+5)
    guideWheel(w.npcButton,function(_,d) zoomGuideMap(preview,d) end)
    guideWheel(optionsPanel,function() end)
    w.npcChecks={}
    for i,option in ipairs(npcIcons) do
        local key=i
        local check=CreateFrame("CheckButton",nil,optionsPanel,"UICheckButtonTemplate")
        w.npcChecks[i]=check
        check:SetSize(18,18);check:SetPoint("TOPLEFT",7,-5-(i-1)*19)
        if check.SetHitRectInsets then check:SetHitRectInsets(0,-122,0,0) end
        check:SetChecked(w.npcOptions[i]==true)
        local title=label(check,"GameFontHighlightSmall",option[1],palette.ink);title:SetPoint("LEFT",check,"RIGHT",4,0)
        guideWheel(check,function() end)
        check:SetScript("OnClick",function(self)
            w.npcOptions[key]=self:GetChecked() and true or nil
            preview.serviceMap=nil;render()
        end)
    end
    local pin=CreateFrame("Frame",nil,preview)
    preview.pin=pin
    pin:SetSize(23,26);pin:SetFrameLevel(preview:GetFrameLevel()+2);pin:EnableMouse(true)
    local mark=pin:CreateTexture(nil,"ARTWORK")
    mark:SetSize(23,24);mark:SetPoint("CENTER")
    mark:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    local highlight=pin:CreateTexture(nil,"BACKGROUND")
    highlight:SetSize(37,37);highlight:SetPoint("CENTER")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetVertexColor(1,.69,.25,.85)
    highlight:SetBlendMode("ADD")
    pin:Hide()
    guideWheel(pin,function(_,delta) zoomGuideMap(preview,delta) end)
    guideWheel(w.mapButton,function(_,delta) zoomGuideMap(preview,delta) end)
    for _,control in ipairs({preview.zoomOut,preview.zoomIn}) do
        guideWheel(control,function(_,delta) zoomGuideMap(preview,delta) end)
    end
    pin:SetScript("OnEnter",function(self)
        local g=preview.destination
        if not g or not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_LEFT")
        GameTooltip:SetText(g.pickup and "Item pickup area" or g.name or "Quest start")
        GameTooltip:AddLine(startDescription(g),.88,.88,.88,true)
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave",function(self)
        if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    preview:SetScript("OnMouseDown",function(self,mouse)
        if mouse~="LeftButton" or not self.mapGeometry or (self.zoom or 1)<=1 then return end
        local x,y=safe(GetCursorPosition)
        if x and y then self.panning={x=x,y=y} end
    end)
    preview:SetScript("OnMouseUp",function(self) self.panning=nil end)
    preview:SetScript("OnHide",function(self) self.panning=nil end)
    preview:SetScript("OnUpdate",function(self)
        local drag,g=self.panning,self.mapGeometry
        if not drag or not g then return end
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then self.panning=nil;return end
        local x,y=safe(GetCursorPosition)
        if not x or not y or (x==drag.x and y==drag.y) then return end
        local scale=safe(self.GetEffectiveScale,self) or 1
        self.centerX=max(0,min(1,(preview:GetWidth()/2-g.x-(x-drag.x)/scale)/g.w))
        self.centerY=max(0,min(1,(preview:GetHeight()/2-g.y+(y-drag.y)/scale)/g.h))
        drag.x,drag.y=x,y
        drawGuideMap(self)
    end)
    local details=CreateFrame("Frame",nil,canvas)
    w.objectives=details
    local detailsBG=fill(details,nil,{.085,.077,.065,1});detailsBG:SetAllPoints()
    details.rule=rect(details,"ARTWORK",{.58,.42,.25,1},0,0,310,1)
    details.title=label(details,"GameFontNormal","",palette.gold)
    details.title:SetPoint("TOPLEFT",9,-8);details.title:SetWordWrap(false)
    local scroll=CreateFrame("ScrollFrame",nil,details)
    details.scroll=scroll
    scroll:SetPoint("TOPLEFT",9,-29);scroll:SetPoint("BOTTOMRIGHT",-9,6)
     local content=CreateFrame("Frame",nil,scroll)
    w.objectivesContent=content
    content:SetSize(310,2)
    scroll:SetScrollChild(content)
    guideWheel(scroll,function(self,delta)
        local limit=max(0,content:GetHeight()-self:GetHeight())
        self:SetVerticalScroll(max(0,min(limit,self:GetVerticalScroll()-delta*24)))
    end)
    details.text=label(content,"GameFontHighlightSmall","",palette.ink)
    details.text:SetPoint("TOPLEFT",0,-1);details.text:SetWordWrap(true)
    details:Hide()
    w.areaTitle=label(canvas,"GameFontNormal","WHERE TO GO",palette.gold)
    w.questTitle=label(canvas,"GameFontNormal","QUESTS TO DO",palette.gold)
    w.areaRule=rect(canvas,"BORDER",{.33,.27,.19,1},17,-335,286,1)
    w.questRule=rect(canvas,"BORDER",{.33,.27,.19,1},316,-335,537,1)
    w.areaSurface=CreateFrame("Frame",nil,canvas)
    w.questSurface=CreateFrame("Frame",nil,canvas)
    guideWheel(w.areaSurface,listWheel("area"));guideWheel(w.questSurface,listWheel("quest"))
    guideWheel(w,listWheel("quest"))
    guideWheel(canvas,listWheel("quest"))
    guideWheel(menu,function() end)
    guideWheel(w.partyChoice,function() end)
    for _,child in ipairs({mast,hero,details,check,close,maximize}) do guideWheel(child,listWheel("quest")) end
    w.areas={}
    for i=1,22 do
        local row=button(canvas,"",286,32,17,-342-(i-1)*34,function(self)
            if not self.place then return end
            menu:Hide();w.selection=self.place.id;w.questPage=1;w.selectedQuest=nil;render()
        end)
        row.index=label(row,"GameFontHighlightSmall","",palette.gold);row.index:SetPoint("LEFT",8,0)
        row.name=label(row,"GameFontHighlight","");row.name:SetPoint("TOPLEFT",30,-4);row.name:SetWidth(247);row.name:SetWordWrap(false)
        row.detail=label(row,"GameFontHighlightSmall","",palette.dim);row.detail:SetPoint("TOPLEFT",30,-18)
        row.total=label(row,"GameFontNormal","",palette.teal);row.total:SetPoint("RIGHT",-10,0);row.total:SetJustifyH("RIGHT")
        row.bar=rect(row,"ARTWORK",{.63,.49,.30,.5},30,-31,1,2)
        guideWheel(row,listWheel("area"))
        w.areas[i]=row
    end
    w.quests={}
    for i=1,24 do
        local row=CreateFrame("Button",nil,canvas)
        row:EnableMouse(true);row:RegisterForClicks("LeftButtonUp")
        row:SetScript("OnClick",function(self)
            if not self.record then return end
            menu:Hide();w.selectedQuest=self.record.id;render()
        end)
        row:SetSize(537,28);row:SetPoint("TOPLEFT",316,-342-(i-1)*30)
        row.back=fill(row,nil,{.078,.091,.10,1});row.back:SetAllPoints()
        row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("LEFT",5,0);row.icon:SetSize(17,17)
        row.name=label(row,"GameFontHighlight","");row.name:SetPoint("TOPLEFT",29,-3);row.name:SetWidth(400);row.name:SetWordWrap(false)
        row.detail=label(row,"GameFontHighlightSmall","",palette.dim);row.detail:SetPoint("TOPLEFT",29,-16)
        row.status=label(row,"GameFontHighlightSmall","",palette.teal);row.status:SetPoint("TOPRIGHT",-90,-4);row.status:SetJustifyH("RIGHT")
        row.waypoint=button(row,"Track",53,20,0,0,function() AT.TrackLevelGuideGiver(row.record) end)
        local trackIcon=row.waypoint:CreateTexture(nil,"ARTWORK")
        trackIcon:SetSize(12,12);trackIcon:SetPoint("LEFT",4,0)
        if not safe(function()
            if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("Waypoint-MapPin-Untracked") then
                trackIcon:SetAtlas("Waypoint-MapPin-Untracked");return true
            end
        end) then trackIcon:SetTexture("Interface\\Minimap\\POIIcons");trackIcon:SetTexCoord(.5,.5625,0,.0625) end
        row.waypoint.caption:ClearAllPoints();row.waypoint.caption:SetPoint("CENTER",6,0)
        row.waypoint:ClearAllPoints();row.waypoint:SetPoint("RIGHT",-4,0)
        row.waypoint:SetFrameLevel(row:GetFrameLevel()+2)
        row.waypoint:SetScript("OnEnter",function(self)
            local q=row.record;local g=q and q.giver
            if not g or not GameTooltip then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetText(g.pickup and "Track pickup area" or "Track quest start")
            GameTooltip:AddLine(startDescription(g),.88,.88,.88,true)
            GameTooltip:AddLine(g.pickup and "Highlights the recorded drop area." or "Sets a waypoint to the quest start.",.85,.85,.85,true)
            GameTooltip:Show()
        end)
        row.waypoint:SetScript("OnLeave",function(self)
            if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
        guideWheel(row,listWheel("quest"));guideWheel(row.waypoint,listWheel("quest"))
        w.quests[i]=row
    end
    w.questEmpty=label(canvas,"GameFontHighlight","No unfinished quests found here for this view.",palette.dim);w.questEmpty:SetPoint("TOPLEFT",326,-356)
    w.areaPages=label(canvas,"GameFontHighlightSmall","",palette.dim);w.areaPages:SetPoint("TOPLEFT",129,-586)
    w.questPages=label(canvas,"GameFontHighlightSmall","",palette.dim);w.questPages:SetPoint("TOPLEFT",568,-586)
    w.areaPrev=button(canvas,"<",30,20,86,-580,function() navigate(-1,"area") end)
    w.areaNext=button(canvas,">",30,20,192,-580,function() navigate(1,"area") end)
    w.questPrev=button(canvas,"<",30,20,523,-580,function() navigate(-1,"quest") end)
    w.questNext=button(canvas,">",30,20,624,-580,function() navigate(1,"quest") end)
    for _,child in ipairs({w.areaPrev,w.areaNext}) do guideWheel(child,listWheel("area")) end
    for _,child in ipairs({w.questPrev,w.questNext,w.search,w.low,w.high,mine,clear}) do guideWheel(child,listWheel("quest")) end
    for _,child in pairs(w.tabs) do guideWheel(child,listWheel("quest")) end
    for _,child in ipairs(w.badges) do guideWheel(child,listWheel("quest")) end
    for _,child in ipairs(w.group) do guideWheel(child,function() end) end
    local legend=label(canvas,"GameFontHighlightSmall","Pick up = shown by the game. In range = fits your level and known unlocks.",palette.dim)
    legend:SetPoint("BOTTOMLEFT",20,14)
    local grip=CreateFrame("Button",nil,w)
    w.grip=grip
    grip:SetSize(19,19);grip:SetPoint("BOTTOMRIGHT",-4,4)
    local t=grip:CreateTexture(nil,"ARTWORK");t:SetAllPoints()
    t:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetScript("OnMouseDown",function(_,key)
        if key~="LeftButton" or w.maximized then return end
        w.resizing=true;w:StartSizing("BOTTOMRIGHT")
    end)
    local function finishResize()
        if not w.resizing then return end
        w.resizing=false;w:StopMovingOrSizing()
        pref.levelGuideWidth,pref.levelGuideHeight=floor(w:GetWidth()+.5),floor(w:GetHeight()+.5)
    end
    grip:SetScript("OnMouseUp",finishResize)
    local function anchor(o,x,y)
        o:ClearAllPoints();o:SetPoint("TOPLEFT",canvas,"TOPLEFT",x,y)
    end
    local function layout()
        local width,height=w:GetWidth(),w:GetHeight()
        if not positive(width) or not positive(height) then return end
        -- Extra screen space buys rows and map area, not oversized labels.
        local zoom=min(w.maximized and 1.12 or 1.23,width/750,height/526,sqrt(width/870*height/642))
        local ww,hh=width/zoom,height/zoom
        canvas:SetScale(zoom);canvas:SetSize(ww,hh)
        grip:SetSize(19*zoom,19*zoom);w.contentZoom=zoom
        local top=w.mode=="forYou" and 86 or 120
        local mapWidth=floor(ww*.465)-16
        local leftW=ww-46-mapWidth
        local mapX=29+leftW
        local heroH=81
        w.hero:SetSize(leftW,heroH);anchor(w.hero,17,-top)
        w.heroEdge:SetHeight(heroH)
        w.heroTop:Hide();w.heroNote:Hide()
        local function heroLabel(f,x,y) f:ClearAllPoints();f:SetPoint("TOPLEFT",w.hero,"TOPLEFT",x,y) end
        heroLabel(w.heroName,11,-5)
        heroLabel(w.heroBand,12,-26)
        heroLabel(w.heroFact,12,-39)
        heroLabel(w.heroAction,12,-53)
        w.mapHeight=hh-top-28
        w.detailsHeight=min(168,max(104,floor(w.mapHeight*.34)))
        anchor(w.art,mapX,-top);w.art:SetSize(mapWidth,w.mapHeight)
        anchor(w.objectives,mapX,-hh+28+w.detailsHeight)
        w.objectives:SetSize(mapWidth,w.detailsHeight)
        w.objectives.rule:SetWidth(mapWidth)
        w.objectives.title:SetWidth(mapWidth-18)
        w.objectivesContent:SetWidth(mapWidth-18)
        w.objectives.text:SetWidth(mapWidth-18)
        local wide=leftW>=568
        if wide then
            for _,x in ipairs({w.heroName,w.heroAction}) do x:SetWidth(leftW-291) end
        else
            w.heroName:SetWidth(leftW-24);w.heroAction:SetWidth(leftW-24)
        end
        local badgeW=wide and 64 or min(72,floor((leftW-24-12)/4))
        if not wide then heroH=100;w.hero:SetHeight(heroH);w.heroEdge:SetHeight(heroH) end
        for i,b in ipairs(w.badges) do
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT",w.hero,"TOPLEFT",wide and leftW-12-4*(badgeW+4)+(i-1)*(badgeW+4) or 12+(i-1)*(badgeW+4),wide and -27 or -72)
            b:SetSize(badgeW,22);b.barWidth=badgeW-8;b.indicator:SetWidth(badgeW)
        end
        w.mastRule:SetWidth(ww-32);w.filterRule:SetWidth(ww-34)
        local areaW=max(135,min(320,floor(leftW*.32)))
        local questW=leftW-areaW-9
        local areaX,questX=17,17+areaW+9
        local first=top+heroH+29
        local stride=27
        if hh-28-first<270 then stride=25 end
        local available=floor((hh-28-first)/stride)
        w.areaLimit=min(#w.areas,max(1,available))
        w.questLimit=min(#w.quests,max(1,available))
        w.areaWidth,w.questWidth=areaW,questW
        anchor(w.areaTitle,areaX+4,-first+21)
        anchor(w.questTitle,questX+4,-first+21)
        anchor(w.areaRule,areaX,-first+3);w.areaRule:SetWidth(areaW)
        anchor(w.questRule,questX,-first+3);w.questRule:SetWidth(questW)
        anchor(w.areaSurface,areaX,-first);w.areaSurface:SetSize(areaW,stride*w.areaLimit)
        anchor(w.questSurface,questX,-first);w.questSurface:SetSize(questW,stride*w.questLimit)
        for i,row in ipairs(w.areas) do
            anchor(row,areaX,-first-(i-1)*stride)
            row:SetSize(areaW,stride-2)
            row.bar:ClearAllPoints();row.bar:SetPoint("TOPLEFT",4,-stride+3)
        end
        for i,row in ipairs(w.quests) do
            anchor(row,questX,-first-(i-1)*stride)
            row:SetSize(questW,stride-2);row.detail:SetWordWrap(false)
            row.name:ClearAllPoints();row.name:SetPoint("TOPLEFT",27,-1)
            row.detail:ClearAllPoints();row.detail:SetPoint("TOPLEFT",27,-14)
        end
        anchor(w.questEmpty,questX+5,-first-9)
        -- Paginate below each column, leaving the headings readable at narrow widths.
        local pagerY=-hh+25
        for _,pair in ipairs({{areaX,areaW,w.areaPrev,w.areaPages,w.areaNext},{questX,questW,w.questPrev,w.questPages,w.questNext}}) do
            local middle=pair[1]+floor(pair[2]/2)
            anchor(pair[3],middle-65,pagerY);anchor(pair[4],middle-21,pagerY-3);anchor(pair[5],middle+35,pagerY)
        end
        legend:Hide()
    end
    w.layout=layout
    local function refreshLayout()
        layout();render()
    end
    w:SetScript("OnSizeChanged",refreshLayout)
    w.toggleMaximize=function()
        finishResize()
        local currentW=safe(UIParent.GetWidth,UIParent) or sw or 1258
        local currentH=safe(UIParent.GetHeight,UIParent) or sh or 868
        if not w.maximized then
            local point,relative,relativePoint,x,y
            if w.GetPoint then point,relative,relativePoint,x,y=w:GetPoint(1) end
            w.restoreWindow={width=w:GetWidth(),height=w:GetHeight(),p=point,r=relative,rp=relativePoint,x=x,y=y}
            w.maximized=true
            w:ClearAllPoints();w:SetPoint("CENTER",UIParent,"CENTER")
            local sizeW=max(750,floor((currentW-8)/scale))
            local sizeH=max(526,floor((currentH-8)/scale))
            if w.SetResizeBounds then w:SetResizeBounds(750,526,sizeW,sizeH)
            elseif w.SetMaxResize then w:SetMaxResize(sizeW,sizeH) end
            w:SetSize(sizeW,sizeH)
        else
            local previous=w.restoreWindow
            w.maximized,w.restoreWindow=false,nil
            w:ClearAllPoints()
            w:SetPoint(previous.p or "CENTER",previous.r or UIParent,previous.rp or "CENTER",previous.x or 0,previous.y or 0)
            w:SetSize(previous.width,previous.height)
        end
        grip:SetShown(not w.maximized)
        updateMaximizeArt()
        refreshLayout()
    end
    w:SetScript("OnHide",function()
        finishResize();menu:Hide();optionsPanel:Hide();w:SetFrameStrata("FULLSCREEN_DIALOG");w.search:ClearFocus();w.low:ClearFocus();w.high:ClearFocus()
    end)
    w:SetScript("OnEvent",function(_,event,qid,second)
        if event=="GET_ITEM_INFO_RECEIVED" then
            if requestedItems[qid] then render() end
            return
        end
        local tracking=trackedGiver
        if tracking and not settingWaypoint then
            if (event=="QUEST_ACCEPTED" and ((positive(second) and second or qid)==tracking.id))
                or (event=="QUEST_TURNED_IN" and qid==tracking.id) then stopGiver(true)
            elseif event=="USER_WAYPOINT_UPDATED" and tracking.native and not sameWaypoint(tracking) then stopGiver(false)
            elseif event=="SUPER_TRACKING_CHANGED" then
                local selected=safe(C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID)
                if tracking.native and safe(C_SuperTrack and C_SuperTrack.IsSuperTrackingUserWaypoint)==false
                    or positive(selected) and selected~=tracking.prior then stopGiver(false) end
            end
        end
        if event=="QUEST_TURNED_IN" and positive(qid) and AT.char then
            AT.char.levelGuideTurnIns=AT.char.levelGuideTurnIns or {}
            AT.char.levelGuideTurnIns[qid]=true
        end
        queueRefresh()
    end)
    layout()
    for _,e in ipairs({"PLAYER_LEVEL_UP","QUEST_LOG_UPDATE","QUEST_ACCEPTED","QUEST_REMOVED","QUEST_TURNED_IN",
        "QUEST_COMPLETE","QUEST_DATA_LOAD_RESULT","QUESTLINE_UPDATE","ZONE_CHANGED_NEW_AREA","GROUP_ROSTER_UPDATE","UNIT_FACTION","UPDATE_FACTION","USER_WAYPOINT_UPDATED","SUPER_TRACKING_CHANGED","GET_ITEM_INFO_RECEIVED","QUEST_WATCH_UPDATE"}) do
        pcall(w.RegisterEvent,w,e)
    end
    return w
end
function AT.ToggleLevelGuide()
    if guide and guide:IsShown() then guide:Hide();return end
    local w=guide or buildWindow()
    if w then w:Show();queueRefresh(true) end
end
