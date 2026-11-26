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
-- Blizzard Nov. 17 hotfix explicitly removed dungeon membership.
function AT.IsForeverOutdoorQuest(questID)
    return questID==93604
end
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

-- Stock boss names/creature IDs from WoW Forever, cross-checked with DungeonJournal 2.1.5.
local bossFacts={
    [33]={{3914,"Rethilgore"},{3886,"Razorclaw the Butcher"},{3887,"Baron Silverlaine"},{4278,"Commander Springvale"},{4279,"Odo the Blindwatcher"},{3872,"Deathsworn Captain"},{4627,"Arugal's Voidwalker"},{4274,"Fenrus the Devourer"},{3927,"Wolf Master Nandos"},{4275,"Archmage Arugal"},},
    [34]={{1696,"Targorr the Dread"},{1717,"Hamhock"},{1666,"Kam Deepfury"},{1663,"Dextren Ward"},{1716,"Bazil Thredd"},{1720,"Bruegal Ironknuckle"},},
    [36]={{644,"Rhahk'Zor"},{3586,"Miner Johnson"},{642,"Sneed's Shredder"},{643,"Sneed"},{1763,"Gilnid"},{646,"Mr. Smite"},{647,"Captain Greenskin"},{639,"Edwin VanCleef"},{645,"Cookie"},},
    [43]={{3669,"Lord Cobrahn"},{3671,"Lady Anacondra"},{3653,"Kresh"},{3670,"Lord Pythas"},{3674,"Skum"},{3673,"Lord Serpentis"},{5775,"Verdan the Everliving"},{3654,"Mutanus the Devourer"},{5912,"Deviate Faerie Dragon"},},
    [47]={{6168,"Roogug"},{4424,"Aggem Thorncurse"},{4428,"Death Speaker Jargba"},{4420,"Overlord Ramtusk"},{4422,"Agathelos the Raging"},{4421,"Charlga Razorflank"},{4425,"Blind Hunter"},{4842,"Earthcaller Halmgar"},},
    [48]={{4887,"Ghamoo-ra"},{4831,"Lady Sarevess"},{6243,"Gelihast"},{12902,"Lorgus Jett"},{4830,"Old Serra'kis"},{4832,"Twilight Lord Kelris"},{4829,"Aku'mai"},},
    [70]={{6910,"Revelosh"},{6906,"The Lost Dwarves"},{7228,"Ironaya"},{7023,"Obsidian Sentinel"},{7206,"Ancient Stone Keeper"},{7291,"Galgann Firehammer"},{4854,"Grimlok"},{2748,"Archaedas"},},
    [90]={{7361,"Grubbis"},{7079,"Viscous Fallout"},{6235,"Electrocutioner 6000"},{6229,"Crowd Pummeler 9-60"},{7800,"Mekgineer Thermaplugg"},{6228,"Dark Iron Ambassador"},},
    [109]={{5713,"Gasher"},{5715,"Hukku"},{5714,"Loro"},{5717,"Mijan"},{5712,"Zolo"},{5716,"Zul'Lor"},{8580,"Atal'alarion"},{5719,"Morphaz"},{5722,"Hazzas"},{5710,"Jammal'an the Prophet"},{5711,"Ogom the Wretched"},{5721,"Dreamscythe"},{5720,"Weaver"},{5709,"Shade of Eranikus"},{8443,"Avatar of Hakkar"},},
    [129]={{7355,"Tuten'kash"},{7356,"Plaguemaw the Rotting"},{7357,"Mordresh Fire Eye"},{8567,"Glutton"},{7354,"Ragglesnout"},{7358,"Amnennar the Coldbringer"},},
    [189]={{3975,"Herod"},{4542,"High Inquisitor Fairbanks"},{3976,"Scarlet Commander Mograine"},{3977,"High Inquisitor Whitemane"},{3983,"Interrogator Vishas"},{6490,"Azshir the Sleepless"},{6488,"Fallen Champion"},{6489,"Ironspine"},{4543,"Bloodmage Thalnos"},{3974,"Houndmaster Loksey"},{6487,"Arcanist Doan"},},
    [209]={{7272,"Theka the Martyr"},{8127,"Antu'sul"},{7271,"Witch Doctor Zum'rah"},{7796,"Nekrum Gutchewer"},{7275,"Shadowpriest Sezz'ziz"},{7604,"Sergeant Bly"},{7795,"Hydromancer Velratha"},{7273,"Gahz'rilla"},{10082,"Zerillis"},{10080,"Sandarr Dunereaver"},{10081,"Dustwraith"},{7797,"Ruuzlu"},{7267,"Chief Ukorz Sandscalp"},},
    [229]={{9219,"Spirestone Butcher"},{9218,"Spirestone Battle Lord"},{9217,"Spirestone Lord Magus"},{9196,"Highlord Omokk"},{9236,"Shadow Hunter Vosh'gajin"},{9237,"War Master Voone"},{16080,"Mor Grayhoof"},{10596,"Mother Smolderweb"},{10376,"Crystal Fang"},{10584,"Urok Doomhowl"},{9596,"Bannok Grimaxe"},{10263,"Burning Felguard"},{9736,"Quartermaster Zigris"},{10220,"Halycon"},{10268,"Gizrul the Slavener"},{9718,"Ghok Bashguud"},{9568,"Overlord Wyrmthalak"},{9816,"Pyroguard Emberseer"},{10264,"Solakar Flamewreath"},{10509,"Jed Runewatcher"},{10899,"Goraluk Anvilcrack"},{10339,"Gyth"},{10429,"Warchief Rend Blackhand"},{10430,"The Beast"},{16042,"Lord Valthalak"},{10363,"General Drakkisath"},},
    [230]={{9018,"High Interrogator Gerstahn"},{9025,"Lord Roccor"},{9319,"Houndmaster Grebmar"},{9027,"Gorosh the Dervish"},{9028,"Grizzle"},{9029,"Eviscerator"},{9030,"Ok'thor the Breaker"},{9031,"Anub'shiah"},{9032,"Hedrum the Creeper"},{16059,"Theldren"},{9024,"Pyromancer Loregrain"},{9056,"Fineous Darkvire"},{9041,"Warder Stilgiss"},{9017,"Lord Incendius"},{9016,"Bael'Gar"},{9033,"General Angerforge"},{8983,"Golem Lord Argelmach"},{9537,"Hurley Blackbreath"},{9502,"Phalanx"},{9543,"Ribbly Screwspigot"},{9499,"Plugger Spazzring"},{9156,"Ambassador Flamelash"},{8923,"Panzor the Invincible"},{9039,"The Seven"},{9938,"Magmus"},{8929,"Princess Moira Bronzebeard"},{9019,"Emperor Dagran Thaurissan"},},
    [289]={{10506,"Kirtonos the Herald"},{10503,"Jandice Barov"},{11622,"Rattlegore"},{10433,"Marduk Blackpool"},{10432,"Vectus"},{10508,"Ras Frostwhisper"},{10505,"Instructor Malicia"},{11261,"Doctor Theolen Krastinov"},{10901,"Lorekeeper Polkelt"},{10507,"The Ravenian"},{10504,"Lord Alexei Barov"},{10502,"Lady Illucia Barov"},{1853,"Darkmaster Gandling"},{14516,"Death Knight Darkreaver"},{16118,"Kormok"},},
    [329]={{10393,"Skul"},{10558,"Hearthsinger Forresten"},{10516,"The Unforgiven"},{10808,"Timmy the Cruel"},{11032,"Malor the Zealous"},{11143,"Postmaster Malown"},{11058,"Ezra Grimm"},{10997,"Cannon Master Willey"},{10811,"Archivist Galford"},{10813,"Balnazzar"},{16101,"Jarien"},{16102,"Sothos"},{10809,"Stonespine"},{10437,"Nerub'enkan"},{10436,"Baroness Anastari"},{10438,"Maleki the Pallid"},{10435,"Magistrate Barthilas"},{10439,"Ramstein the Gorger"},{10440,"Baron Rivendare"},},
    [349]={{13282,"Noxxion"},{12258,"Razorlash"},{12236,"Lord Vyletongue"},{12237,"Meshlok the Harvester"},{12225,"Celebras the Cursed"},{12203,"Landslide"},{13601,"Tinkerer Gizlock"},{13596,"Rotgrip"},{12201,"Princess Theradras"},},
    [389]={{11517,"Oggleflint"},{11520,"Taragaman the Hungerer"},{11518,"Jergosh the Invoker"},{11519,"Bazzalan"},},
    [429]={{14354,"Pusillin"},{11490,"Zevrim Thornhoof"},{13280,"Hydrospawn"},{14327,"Lethtendris"},{11492,"Alzzin the Wildshaper"},{16097,"Isalien"},{14326,"Guard Mol'dar"},{14322,"Stomper Kreeg"},{14321,"Guard Fengus"},{14323,"Guard Slip'kik"},{14325,"Captain Kromcrush"},{14324,"Cho'Rush the Observer"},{11501,"King Gordok"},{11489,"Tendris Warpwood"},{11467,"Tsu'zee"},{11487,"Magister Kalendris"},{11488,"Illyanna Ravenoak"},{11496,"Immol'thar"},{14506,"Lord Hel'nurath"},{11486,"Prince Tortheldrin"},},
    [2959]={{247126,"Atrexis the Grave Knight"},{245999,"Arcane Anomaly"},{246003,"Fel Ancient"},{246017,"Unstable Sentinel"},{246008,"Mana Devourer"},{246016,"Arcanic Enigma"},{247032,"Lyn the Ignored"},{246020,"Shade of the Archmage"},},
    [2970]={{258905,"Zul'Alai"},{258924,"Var'Taka"},{260042,"Captain Dreadrise"},{0,"Deathless Marrow"},{264177,"Gill"},{264172,"Umbra"},{260468,"\"Pyromancer\" Braxton"},{260274,"Min'loth the Serpent"},},
    [2974]={{247206,"Impaan the Imprisoner"},{247198,"Bonesnout the Unbroken"},{269104,"Moontouched Wanderer"},{269111,"Gortek the Apprentice"},{250034,"Tunnelweb Matriarch"},{269151,"Sabella No-Eyes"},{247195,"Withermaw"},{247209,"Elder Shaman Bloodmane"},{247207,"Blackmaw Behemoth"},{247231,"Unbound Spirit"},{247234,"Varrox Bleakhoof"},},
    [2994]={{255391,"Overseer Wrex"},{256236,"The Questioner"},{255997,"Tidemistress Ca'zass"},{257016,"Katerina the Cleaner"},{255702,"Blazeroar"},},
    [2998]={{260322,"Saltspine"},{260325,"Shadetooth"},{260326,"Relic Guardian"},},
    [2999]={{250660,"The Baron"},{250483,"Witherfang"},{256035,"Viktor the Vile"},{250631,"The Abandoned"},{256097,"Bjork"},{250657,"Rath'mael"},{0,"Lordaeron Captain"},},
    [3001]={{253201,"Titanosaur"},{261813,"Venomridge"},{261812,"Thunderhoof"},{262127,"Direhorn Matriarch"},{261974,"Cinder"},{262081,"Bolt"},{262297,"Snowtalon"},{272561,"Vitrix"},{253218,"Izha'Rel"},{0,"Tor'Rel"},{261809,"Nanaya"},},
    [3039]={{258966,"Slavecrusher Grox"},{258972,"Twilight Commander Zarmok"},{259281,"War Handler Ashka"},{258964,"Nar'gurk"},{264773,"Bossman Toof"},{262716,"Kroog"},{258968,"Overlord Mugg"},},
    [3065]={{261306,"Faldrim Anvilmar"},{0,"Magmatus"},{261311,"Plunder"},{261319,"Durgen Dirgehammer"},},
}
function AT.GetForeverDungeonBossFacts(instanceID)
    return ordinary(instanceID) and bossFacts[instanceID] or nil
end
