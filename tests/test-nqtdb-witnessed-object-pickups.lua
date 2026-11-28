local AT={}
local locale="enUS"
function GetLocale()return locale end
function CreateFrame()return {RegisterEvent=function()end,SetScript=function()end}end
for _,f in ipairs({"QuestMobData","NQTDB","QuestMobs"})do
 assert(loadfile("NQT/"..f..".lua"))("NQT",AT)
end
local expected={
 {94615,267223,625779,"Track"},
 {94923,266884,624202,"Hollow Clam Shell"},
 {95156,268536,629484,"Hay Bale"},
 {95426,274975,654618,"Rog'mar Supply Crate"},
 {95561,271431,645233,"Fresh Apple"},
 {95943,271620,645449,"Foreman's Crate"},
 {95975,271823,648994,"Wildflower"},
 {96009,271877,645516,"Bundle of Wood"},
 {77,8684,142191,"Horde Supply Crate"},
 {125,1309,32,"Sunken Chest"},
 {771,4808,2910,"Well Stone"},
 {771,4809,2912,"Ambercorn"},
 {868,5058,3685,"Silithid Mound"},
 {962,5339,13891,"Serpentbloom"},
 {1069,5570,nil,"Deepmoss Eggs"},
 {1197,5869,20807,"Ancient Brazier"},
 {1221,5880,21277,"Crate with Holes"},
 {1221,5897,21530,"Snufflenose Owner's Manual"},
 {1221,6684,68865,"Snufflenose Command Sticks"},
 {1370,6069,22245,"Sack of Meat"},
 {2641,8526,141853,"Violet Tragan"},
 {5062,12732,175928,"Incendia Agave"},
 {5501,13703,nil,"Kodo Bones"},
 {93041,255945,587276,"Accursed Skull"},
 {97291,281300,673933,"Blisterweed"},
 {97326,277952,nil,"Smooth Boulder"},
 {99127,286205,694772,"Fishing Trap"},
 {207,2008,54,"The Emperor's Tomb"},
 {1598,6785,83763,"Stolen Books"},
 {93160,257128,613238,"Zephyrseed Cone"},
 {94485,265105,619450,"Lady's Tear Moss"},
 {94896,266433,623295,"Abandoned Belongings"},
 {98197,279821,nil,"Khaz Modan Timber"},
 {98197,279822,670774,"Khaz Modan Iron"},
 {98208,279915,670962,"Nord'el"},
 {99130,286214,694855,"Overgrown Duskweed"},
 {99143,286209,694785,"Junk Pile"}
}
for _,r in ipairs(expected)do
 local q,i,id,name=table.unpack(r)
 local got,n=AT.GetQuestLootObjectName(q,i)
 assert(got==name and n==id)
 assert(not AT.GetQuestLootObjectName(1,i),"object source cannot be guessed just from an item ID")
 assert(not AT.GetQuestLootObjectName(q,1),"object source cannot be guessed just from a quest ID")
end
assert(not AT.GetQuestLootObjectName(99130,286215),"blood vial is a distinct objective")
assert(AT.GetQuestLootObjectName(207,2007)=="Fall of Gurubashi","existing sibling source stays intact")
local old=AT.NQTDB.NamedObjectPickups
old[94923]={[266884]={{123,"Existing independent source"}}}
assert(AT.GetQuestLootObjectName(94923,266884)=="Existing independent source")
old[94923][266884][2]={124,"Competing source"}
assert(not AT.GetQuestLootObjectName(94923,266884),"ambiguous existing facts cannot fall back to a single witness")
locale="frFR";assert(not AT.GetQuestLootObjectName(95561,271431))
print(("PASS all %d world-object loot labels through Rank Quest; exact quest+item, locale, multi-template identity, and old priority"):format(#expected))
