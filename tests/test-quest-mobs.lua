local AT={}
GetLocale=function() return "enUS" end
local itemNames={[270333]="Voodoo-Infused Artifact"}
C_Item={GetItemNameByID=function(id) return itemNames[id] end}
assert(loadfile("NQT/QuestMobData.lua"))("NQT",AT)
assert(loadfile("NQT/EverlootDrops.lua"))("NQT",AT)
assert(loadfile("NQT/DungeonCatalog.lua"))("NQT",AT)
assert(loadfile("NQT/QuestMobs.lua"))("NQT",AT)
assert(AT.ForeverDungeonForQuest(95789)=="The Drowned City")
local item=AT.GetKnownQuestDropItem(95789,"Voodoo-Infused Artifact")
assert(item==270333)
assert(not AT.GetKnownQuestDropItem(95790,"Voodoo-Infused Artifact"))
assert(table.concat(AT.GetQuestDropMobNames(item),",")==
    "Saltseer Coroner,Saltseer Cultist,Saltseer Manhunter,Saltseer Murderer")
assert(AT.GetQuestDropMobNames(item)==AT.GetQuestDropMobNames(item),"repeated frames reuse cached names")
assert(AT.GetQuestKillMobName(95789,{type="monster",npcID=259987},"Saltseer Manhunters slain: 0/3")=="Saltseer Manhunter")
assert(not AT.GetQuestKillMobName(95789,{type="monster",npcID=259987},"Speak to Saltseer Manhunter: 0/1"))
assert(not AT.GetQuestKillMobName(95789,{type="monster",npcID=259981},"Saltseer Manhunters slain: 0/3"))
assert(not AT.GetQuestKillMobName(95789,{type="item",npcID=259987},"Saltseer Manhunters slain: 0/3"))
local kit=AT.GetQuestMobProfile("Saltseer Manhunter")
assert(kit and kit.name=="Saltseer Manhunter" and kit.drops[1]=="Voodoo-Infused Artifact")
assert(not AT.GetQuestMobProfile("Saltseer"))
assert(loadfile("NQT/LevelGuideData.lua"))("NQT",AT)
assert(AT.GetQuestMobDisplayID("Seeking Remnant",true,92457)==130224)
assert(AT.GetQuestMobDisplayID("Saturated Remnant",true,92457)==130223)
assert(AT.GetQuestMobDisplayID("Mana Echo",true,92457)==14272)
assert(AT.GetQuestMobDisplayID("Redridge Brute",true,94532)==609)
assert(AT.GetQuestMobDisplayID("Redridge Brute",true,94678)==609)
assert(not AT.GetQuestMobDisplayID("Redridge Brute",true),"do not pick a same-name model without quest context")
-- Verify the new portraits resolve cold from exact quest objective IDs, without a target.
for _,case in ipairs({
    {764,2978,"Venture Co. Worker",7247},
    {764,2979,"Venture Co. Supervisor",7245},
    {1012,3941,"Uthil Mooncall",4165},
    {1062,3989,"Venture Co. Logger",7228},
    {1071,3989,"Venture Co. Logger",7228},
    {1071,3991,"Venture Co. Deforester",7226},
    {1087,4057,"Son of Cenarius",2432},
    {1386,4632,"Kolkar Centaur",9447},
    {1386,4633,"Kolkar Scout",9445},
    {1434,4670,"Hatefury Rogue",6741},
    {97265,4670,"Hatefury Rogue",6741},
    {1434,4672,"Hatefury Felsworn",2014},
    {97265,4672,"Hatefury Felsworn",2014},
    {1434,4673,"Hatefury Betrayer",11331},
    {1434,4675,"Hatefury Hellcaller",2014},
    {97265,4675,"Hatefury Hellcaller",2014},
    {1487,3636,"Deviate Ravager",1747},
    {1487,5761,"Deviate Shambler",1084},
    {1487,5056,"Deviate Dreadfang",3006},
    {5581,11937,"Demon Portal Guardian",9017},
    {5728,11519,"Bazzalan",2007},
    {6143,4714,"Slitherblade Myrmidon",6748},
    {6143,4712,"Slitherblade Sorceress",11266},
    {8366,7855,"Southsea Pirate",6944},
    {8366,7856,"Southsea Freebooter",6948},
    {8424,6004,"Shadowsworn Cultist",7838},
    {81838,221333,"Doomkin",118604},
    {92463,251404,"Cirrusfly Queen",136996},
    {92465,251143,"Roiling Winds",137907},
    {92550,251662,"Living Lightning",137158},
    {97265,4674,"Hatefury Shadowstalker",11332},
}) do
    local qid,npc,name,display=case[1],case[2],case[3],case[4]
    local actual,source=AT.GetQuestMobDisplayID(name,true,qid)
    assert(actual==display and source==npc,"Bundled portrait: "..qid.."/"..name)
end
assert(not AT.GetQuestMobDisplayID("Shore Crawler",true,95988),"name alone has two models")
local display,creature=AT.GetQuestMobDisplayID("Shore Crawler",true,95988,271650)
assert(display==999 and creature==256807,"Crawler Spittle uses the Riverglades Shore Crawler")
local prior=AT.ObservedQuestDrops
AT.ObservedQuestDrops={items={[99999]={{259987,1,2,3,1,1}}}}
assert(not AT.GetQuestDropMobNames(99999),"object IDs must not become NPC names")
AT.ObservedQuestDrops=prior
GetLocale=function() return "deDE" end
assert(not AT.GetQuestDropMobNames(item) and not AT.GetQuestMobProfile("Saltseer Manhunter"))
print("PASS real Forever Shady Saltseers quest, four known droppers, exact item and NPC IDs, nonkill and object exclusions")
