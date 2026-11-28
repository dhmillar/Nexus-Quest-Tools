-- Lua 5.1, run from the repo root. Audits displayed coverage, not private input tables.
-- Pass a path for gap TSV output, or omit for the summary only. An optional second argument overrides only the Everloot pack for comparisons.
local AT={db={rankQuestLegacyDropRates=true}}
local grouped=false
function IsInGroup()return grouped end
function GetLocale()return "enUS" end
for _,name in ipairs({"LevelGuideData","ForeverQuestFacts","QuestMobData","EverlootDrops",
    "ClassicQuestDropReferences","ClassicQuestMobReferences","NQTDB","QuestMobs","QuestHUD"}) do
    local path=(name=="EverlootDrops" and arg and arg[2]~="" and arg[2]) or ("NQT/"..name..".lua")
    assert(loadfile(path))("NQT",AT)
end
local output=arg and arg[1] and assert(io.open(arg[1],"w"))
if output then
    output:write("quest_id\tobjective_item_id\tmob_source\tobject_witness\tknown_vendor\tshown_solo_without_classic\tshown_party_without_classic\tclassic_fallback\n")
end
local baseline=arg and arg[3]=="baseline"
local totals={quests=0,items=0,mobs=0,objects=0,merchants=0,solo=0,group=0,classicOnly=0,unresolvedSource=0,unresolvedRate=0}
local ordered={}
for q in pairs(AT.ForeverLevelGuideQuests) do ordered[#ordered+1]=q end
table.sort(ordered)
for _,q in ipairs(ordered) do
    totals.quests=totals.quests+1
    local items={}
    for _,o in ipairs(AT.ForeverLevelGuideQuests[q][10] or {}) do
        if o[1]==2 and o[2]>0 then items[o[2]]=true end
    end
    local facts=AT.ForeverQuestFacts[q] or {}
    for n=3,#facts do if facts[n][1]>0 then items[facts[n][1]]=true end end
    local ids={}
    for item in pairs(items) do ids[#ids+1]=item end
    table.sort(ids)
    for _,item in ipairs(ids) do
        totals.items=totals.items+1
        local mob=AT.GetQuestDropMobNames(item,q)~=nil
        local object=false
        for _,o in ipairs(AT.ObservedQuestDrops.items[item] or {}) do
            if o[6]==1 then object=true end
        end
        if not baseline and AT.GetQuestLootObjectName and AT.GetQuestLootObjectName(q,item) then object=true end
        local merchants=AT.NQTDB.VendorObjectives and AT.NQTDB.VendorObjectives[q]
        local vendor=merchants and merchants[item] or false
        AT.db.rankQuestLegacyDropRates=false
        grouped=false
        local solo=AT.GetRankQuestDropRateSuffix(q,item)~=""
        grouped=true
        local party=AT.GetRankQuestDropRateSuffix(q,item)~=""
        AT.db.rankQuestLegacyDropRates=true;grouped=false
        local classic=not solo and AT.GetRankQuestDropRateSuffix(q,item)~=""
        if mob then totals.mobs=totals.mobs+1 end
        if object then totals.objects=totals.objects+1 end
        if vendor then totals.merchants=totals.merchants+1 end
        if solo then totals.solo=totals.solo+1 end
        if party then totals.group=totals.group+1 end
        if classic then totals.classicOnly=totals.classicOnly+1 end
        local unresolvedSource=not mob and not object and not vendor
        local unresolvedRate=not solo and not party and not classic
        if unresolvedSource then totals.unresolvedSource=totals.unresolvedSource+1 end
        if unresolvedRate then totals.unresolvedRate=totals.unresolvedRate+1 end
        if output and (unresolvedSource or unresolvedRate) then
            output:write(q,"\t",item,"\t",mob and 1 or 0,"\t",object and 1 or 0,"\t",
                vendor and 1 or 0,"\t",solo and 1 or 0,"\t",party and 1 or 0,"\t",classic and 1 or 0,"\n")
        end
    end
end
if output then output:close() end
for _,key in ipairs({"quests","items","mobs","objects","merchants","solo","group","classicOnly","unresolvedSource","unresolvedRate"}) do
    print(key.."="..totals[key])
end
print("Unresolved coverage is a review queue; some objectives are purchased, crafted, handed out, or looted from objects.")
