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
local prior=AT.ObservedQuestDrops
AT.ObservedQuestDrops={items={[99999]={{259987,1,2,3,1,1}}}}
assert(not AT.GetQuestDropMobNames(99999),"object IDs must not become NPC names")
AT.ObservedQuestDrops=prior
GetLocale=function() return "deDE" end
assert(not AT.GetQuestDropMobNames(item) and not AT.GetQuestMobProfile("Saltseer Manhunter"))
print("PASS real Forever Shady Saltseers quest, four known droppers, exact item and NPC IDs, nonkill and object exclusions")
