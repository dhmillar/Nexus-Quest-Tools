local _,AT=...
-- The nine Forever launch dungeons. Instance IDs are not UI-map IDs.
-- Quest membership was audited against the installed DungeonJournal 2.1.5
-- (including updates) and QuestieDB 1.1.6. Store identifiers only.
local catalog={
    [3065]={"Hall of Thanes",{96393,96394,96395,96403,98423}},
    [2999]={"Ruins of Lordaeron",{92401,92415,92421,92422,95189,95195,95204,95216,95250,97288}},
    [2998]={"Excavation Site: Wetlands",{95646,95647,95682,95697,95772,95795,95809,98815,98823,98824}},
    [2959]={"City of Dalaran",{92456,92457,92458,92489,96984,96986,96987,96988}},
    [2970]={"The Drowned City",{95775,95776,95787,95788,95789,95791,95798,95799,96078,96774,97130}},
    [3039]={"Krol'dok Stronghold",{94968,94972,94974,94975,94981,94982,94983,94984,94998,96771}},
    [2994]={"Alcaz Prison",{95262,95263,95309,95454,95483,96332,96334,96335,96337,96376,96377,96381,96772}},
    [2974]={"Blackmaw Hold",{92065,92066,92067,92069,92070,92343,92344,96246,97173,97198,97327,99187}},
    [3001]={"Shaper's Terrace",{95790,95924,95925,95926,95928,97049}},
}
local quests,names={},{}
local function ordinary(value)
    return not issecretvalue or not issecretvalue(value)
end
local function key(name)
    if not ordinary(name) or type(name)~="string" then return end
    return (strlower or string.lower)(name):gsub("’","'"):gsub("^%s+",""):gsub("%s+$",""):gsub("^the%s+","")
end
for _,entry in pairs(catalog) do
    names[key(entry[1])]=entry[1]
    for _,qid in ipairs(entry[2]) do
        if quests[qid]==nil then quests[qid]=entry[1]
        elseif quests[qid]~=entry[1] then quests[qid]=false end
    end
end
names["excavation site"]="Excavation Site: Wetlands"

function AT.ForeverDungeonName(instanceID,name)
    local entry=ordinary(instanceID) and catalog[instanceID]
    return entry and entry[1] or names[key(name)]
end
function AT.ForeverDungeonForQuest(questID)
    if ordinary(questID) then return quests[questID] or nil end
end
